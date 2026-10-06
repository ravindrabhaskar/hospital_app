import { stripGovernanceMarkers } from '../../lib/governance.js';
import { randomUUID } from 'node:crypto';
import { and, desc, eq, ilike, inArray, or } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { careEpisodes, homeVisits, labOrders, labPackages, labTests, payments, prescriptions } from '../../db/schema.js';
import { assertCanActForPatient, listActablePatients, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR } from '../../lib/context.js';
import { AppError, errors } from '../../lib/errors.js';
import { envelope, list, pageFromQuery } from '../../lib/pagination.js';
import { parse, zAddress, zIso, zUuid } from '../../lib/validate.js';
import { firstDelivery, parseJsonBuffer, rawBodyParsers, verifyHmacHeader } from '../../lib/webhooks.js';
import { requireRoles } from '../../plugins/auth.js';
import { ACTIVE_STATUSES, addEvent, createEpisode, settleEpisodeAfterBookingEnded } from '../episodes/service.js';
import { findZoneForPincode, timelineAdd } from '../homevisits/service.js';
import { toPayment } from '../payments/service.js';
import { zCouponCode, zRefundTo } from '../wallet/routes.js';
import { completeLabOrder, timelinePush, toLabOrders, toLabTest } from './service.js';

const READ: Perm[] = ['book', 'view_records', 'manage_care', 'staff_ops'];

/** Contract section 44: lab tests at home. */
export async function labRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/lab/tests', async (req) => {
    const q = parse(z.object({ q: z.string().max(100).optional(), category: z.string().max(40).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const conds = [eq(labTests.active, true)];
    if (q.q) conds.push(or(ilike(labTests.name, `%${q.q}%`), ilike(labTests.code, `%${q.q}%`))!);
    if (q.category) conds.push(eq(labTests.category, q.category));
    const rows = await db.select().from(labTests).where(and(...conds)).orderBy(labTests.name).limit(page.limit + 1).offset(page.offset);
    return envelope(rows.map(toLabTest), page);
  });

  app.get('/lab/packages', async () => {
    const rows = await db.select().from(labPackages).where(eq(labPackages.active, true)).orderBy(labPackages.price);
    return list(rows.map((p) => ({ id: p.id, code: p.code, name: p.name, testIds: p.testIds, price: p.price, mrp: p.mrp, description: stripGovernanceMarkers(p.description) })));
  });

  app.post('/lab/orders', { config: { idempotent: true } }, async (req, reply) => {
    const body = parse(
      z.object({
        patientId: zUuid,
        testIds: z.array(zUuid).max(40).default([]),
        packageIds: z.array(zUuid).max(10).optional(),
        address: zAddress,
        preferredStart: zIso,
        preferredEnd: zIso,
        prescriptionId: zUuid.optional(),
        careEpisodeId: zUuid.optional(),
        couponCode: zCouponCode.optional(),
        useWallet: z.boolean().optional(),
      }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, body.patientId, 'book', 'lab_order.create');
    if (svc.partners.lab.name === 'disabled') throw errors.dependency('Lab tests at home are not available yet');
    const packageIds = [...new Set(body.packageIds ?? [])];
    const testIds = [...new Set(body.testIds)];
    if (!testIds.length && !packageIds.length) throw errors.validation('Choose at least one test or package');
    const start = new Date(body.preferredStart);
    const end = new Date(body.preferredEnd);
    if (!(end > start)) throw errors.validation('preferredEnd must be after preferredStart');
    if (end <= new Date()) throw errors.validation('Preferred window is in the past');
    const zone = await findZoneForPincode(db, body.address.pincode);
    if (!zone) throw new AppError('NOT_SERVICEABLE', 'Home sample collection is not available at this pincode', { pincode: body.address.pincode });
    const pkgs = packageIds.length ? await db.select().from(labPackages).where(and(inArray(labPackages.id, packageIds), eq(labPackages.active, true))) : [];
    if (pkgs.length !== packageIds.length) throw errors.validation('Unknown package', { field: 'packageIds' });
    const direct = testIds.length ? await db.select().from(labTests).where(and(inArray(labTests.id, testIds), eq(labTests.active, true))) : [];
    if (direct.length !== testIds.length) throw errors.validation('Unknown test', { field: 'testIds' });
    const pkgTestIds = new Set(pkgs.flatMap((p) => p.testIds));
    const allIds = [...new Set([...pkgTestIds, ...testIds])];
    const allTests = await db.select().from(labTests).where(inArray(labTests.id, allIds));
    // Price: packages at package price, plus individually chosen tests that no package already covers.
    const total = pkgs.reduce((s, p) => s + p.price, 0) + direct.filter((t) => !pkgTestIds.has(t.id)).reduce((s, t) => s + t.price, 0);
    if (body.prescriptionId) {
      const [rx] = await db.select({ patientId: prescriptions.patientId }).from(prescriptions).where(eq(prescriptions.id, body.prescriptionId));
      if (!rx || rx.patientId !== body.patientId) throw errors.validation('prescriptionId must be a prescription of this patient', { field: 'prescriptionId' });
    }
    const result = await db.transaction(async (tx) => {
      let episodeId = body.careEpisodeId;
      if (episodeId) {
        const [ep] = await tx.select().from(careEpisodes).where(eq(careEpisodes.id, episodeId));
        if (!ep || ep.patientId !== body.patientId) throw errors.validation('careEpisodeId does not belong to this patient');
        if (!ACTIVE_STATUSES.includes(ep.status as never)) throw errors.conflict('Care episode is closed', { status: ep.status });
      } else {
        episodeId = (await createEpisode(tx, { patientId: body.patientId, title: 'Lab tests at home', concern: allTests.map((t) => t.name).join(', '), actor: req.ctx.actor })).id;
      }
      const id = randomUUID();
      const payment = await svc.payments.create(tx, {
        purpose: 'lab_order',
        refId: id,
        patientId: body.patientId,
        amount: total,
        userId: req.ctx.user.id,
        couponCode: body.couponCode,
        useWallet: body.useWallet,
        actor: req.ctx.actor,
      });
      const [order] = await tx
        .insert(labOrders)
        .values({
          id,
          patientId: body.patientId,
          tests: allTests.map((t) => ({ id: t.id, name: t.name })),
          packageIds,
          total,
          discount: payment.discount,
          address: body.address,
          preferredStart: start,
          preferredEnd: end,
          partnerName: svc.partners.lab.displayName,
          timeline: [{ status: 'pending_payment', at: new Date().toISOString() }],
          careEpisodeId: episodeId,
          prescriptionId: body.prescriptionId ?? null,
          createdByUserId: req.ctx.user.id,
        })
        .returning();
      await addEvent(tx, episodeId, 'lab_order_created', 'Lab tests at home ordered', req.ctx.actor, { labOrderId: id });
      await audit(tx, req.ctx.actor, { action: 'lab_order.create', entityType: 'lab_order', entityId: id, metadata: { testCount: allTests.length } });
      return { order, payment };
    });
    const payment = await svc.payments.settleIfCovered(result.payment, req.ctx.actor);
    const [order] = await db.select().from(labOrders).where(eq(labOrders.id, result.order.id));
    return reply.code(201).send({ order: (await toLabOrders(db, [order]))[0], payment: toPayment(payment) });
  });

  app.get('/lab/orders', async (req) => {
    const q = parse(z.object({ patientId: zUuid.optional() }), req.query);
    const page = pageFromQuery(req.query);
    let ids: string[];
    if (q.patientId) {
      await assertCanActForPatient(db, req.ctx, q.patientId, READ, 'lab_order.list');
      ids = [q.patientId];
    } else {
      ids = (await listActablePatients(db, req.ctx.user)).filter((p) => p.permissions.some((x) => x !== 'receive_alerts')).map((p) => p.patientId);
    }
    if (!ids.length) return { items: [], nextCursor: null };
    const rows = await db.select().from(labOrders).where(inArray(labOrders.patientId, ids)).orderBy(desc(labOrders.createdAt)).limit(page.limit + 1).offset(page.offset);
    return envelope(await toLabOrders(db, rows), page);
  });

  const load = async (id: string) => {
    const [o] = await db.select().from(labOrders).where(eq(labOrders.id, id));
    if (!o) throw errors.notFound('Lab order');
    return o;
  };

  app.get('/lab/orders/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const o = await load(id);
    await assertCanActForPatient(db, req.ctx, o.patientId, READ, 'lab_order.read');
    return (await toLabOrders(db, [o]))[0];
  });

  app.post('/lab/orders/:id/cancel', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ reason: z.string().trim().min(1).max(500), refundTo: zRefundTo.optional() }), req.body);
    const o = await load(id);
    await assertCanActForPatient(db, req.ctx, o.patientId, 'book', 'lab_order.cancel');
    if (!['pending_payment', 'scheduled'].includes(o.status)) throw errors.invalidTransition(o.status, 'cancelled');
    const [pay] = await db.select().from(payments).where(and(eq(payments.purpose, 'lab_order'), eq(payments.refId, o.id)));
    const row = await db.transaction(async (tx) => {
      const [r] = await tx
        .update(labOrders)
        .set({ status: 'cancelled', cancelReason: body.reason, timeline: timelinePush(o, 'cancelled'), updatedAt: new Date() })
        .where(eq(labOrders.id, o.id))
        .returning();
      if (o.collectionVisitId) {
        const [v] = await tx.select().from(homeVisits).where(eq(homeVisits.id, o.collectionVisitId));
        if (v && !['completed', 'cancelled', 'in_progress'].includes(v.status)) {
          await tx.update(homeVisits).set({ status: 'cancelled', cancelReason: 'lab_order_cancelled', timeline: timelineAdd(v, 'cancelled', 'Lab order cancelled'), updatedAt: new Date() }).where(eq(homeVisits.id, v.id));
        }
      }
      if (pay?.status === 'pending') await svc.payments.voidPending(tx, pay.id);
      await addEvent(tx, o.careEpisodeId, 'lab_order_cancelled', 'Lab order cancelled', req.ctx.actor, { labOrderId: o.id });
      await settleEpisodeAfterBookingEnded(tx, o.careEpisodeId, 'cancelled', req.ctx.actor);
      await audit(tx, req.ctx.actor, { action: 'lab_order.cancel', entityType: 'lab_order', entityId: o.id });
      return r;
    });
    if (pay?.status === 'succeeded') await svc.payments.refund(pay.id, { reason: 'lab_order_cancelled', actor: req.ctx.actor, toWallet: body.refundTo === 'wallet' });
    return (await toLabOrders(db, [row]))[0];
  });

  app.get('/ops/lab-orders', { preHandler: requireRoles(svc, 'coordinator', 'ops_admin', 'super_admin') }, async (req) => {
    const q = parse(z.object({ status: z.string().max(30).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db
      .select()
      .from(labOrders)
      .where(q.status ? eq(labOrders.status, q.status) : undefined)
      .orderBy(desc(labOrders.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toLabOrders(db, rows), page);
  });
}

/**
 * Public lab partner webhook (HMAC X-Lab-Signature over the raw body with LAB_WEBHOOK_SECRET). Payload:
 * { eventId, partnerOrderId, status: "processing"|"report_ready", reportPdfBase64?, results?: [{name,value,unit,range}] }
 */
export async function labWebhookRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  rawBodyParsers(app);
  app.post('/webhooks/lab/:partner', { bodyLimit: 20 * 1024 * 1024 }, async (req, reply) => {
    const { partner } = parse(z.object({ partner: z.string().regex(/^[a-z0-9_-]{2,40}$/) }), req.params);
    const actor = { ...SYSTEM_ACTOR, name: `lab-partner:${partner}`, role: 'webhook', ip: req.ip, correlationId: req.correlationId };
    if (!Buffer.isBuffer(req.body) || !verifyHmacHeader(svc.config.LAB_WEBHOOK_SECRET, req.body, req.headers['x-lab-signature'])) {
      await audit(svc.db, actor, { action: 'lab.webhook', entityType: 'webhook', outcome: 'denied', metadata: { reason: 'bad_signature', partner } });
      throw errors.unauthenticated('Invalid webhook signature');
    }
    const b = parse(
      z.object({
        eventId: z.string().min(1).max(200),
        partnerOrderId: z.string().min(1).max(100),
        status: z.enum(['processing', 'report_ready']),
        reportPdfBase64: z.string().max(20 * 1024 * 1024).optional(),
        results: z.array(z.object({ name: z.string().max(200), value: z.string().max(60), unit: z.string().max(40), range: z.string().max(60) })).max(100).optional(),
      }),
      parseJsonBuffer(req.body),
    );
    if (!(await firstDelivery(svc.db, `lab:${partner}`, b.eventId))) return reply.code(200).send({ received: true, duplicate: true });
    const [o] = await svc.db.select().from(labOrders).where(eq(labOrders.partnerOrderId, b.partnerOrderId));
    if (!o) return reply.code(200).send({ received: true, unknownOrder: true });
    if (b.status === 'processing' && o.status === 'sample_collected') {
      await svc.db.update(labOrders).set({ status: 'processing', processingAt: new Date(), timeline: timelinePush(o, 'processing'), updatedAt: new Date() }).where(eq(labOrders.id, o.id));
      await audit(svc.db, actor, { action: 'lab_order.processing', entityType: 'lab_order', entityId: o.id });
    }
    if (b.status === 'report_ready') {
      const pdf = b.reportPdfBase64 ? Buffer.from(b.reportPdfBase64, 'base64') : undefined;
      if (pdf && pdf.subarray(0, 4).toString('latin1') !== '%PDF') throw errors.validation('reportPdfBase64 must be a PDF');
      await completeLabOrder(svc, o.id, { pdf, results: b.results, sample: svc.partners.lab.name === 'mock' }, actor);
    }
    return reply.code(200).send({ received: true });
  });
}

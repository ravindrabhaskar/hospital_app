import { randomUUID } from 'node:crypto';
import { and, desc, eq, inArray, notInArray } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { careEpisodes, homeVisitServices, homeVisits, payments, providerZones, providers, vitals } from '../../db/schema.js';
import { assertCanActForPatient, listActablePatients } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, hasRole } from '../../lib/context.js';
import { randomDigits, safeEqual } from '../../lib/crypto.js';
import { AppError, errors } from '../../lib/errors.js';
import { list, envelope, pageFromQuery } from '../../lib/pagination.js';
import { istDate } from '../../lib/time.js';
import { parse, zAddress, zIso, zUuid, zVitalType } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { ACTIVE_STATUSES, addEvent, advanceEpisode, createEpisode } from '../episodes/service.js';
import { clinicalContext } from '../patients/service.js';
import { toPayment } from '../payments/service.js';
import { zCouponCode, zRefundTo } from '../wallet/routes.js';
import { onCollectionVisitCompleted } from '../lab/service.js';
import { evaluateVitals } from '../programs/service.js';
import { storeRecord } from '../records/service.js';
import { homeVisitDiscount } from '../subscriptions/service.js';
import { autoAssign, findZoneForPincode, providerEligible, timelineAdd, toHomeVisit, toHomeVisits, visitViewFor, type HomeVisitRow } from './service.js';

export async function homeVisitRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/home-visit/services', async () => {
    const rows = await db.select().from(homeVisitServices).orderBy(homeVisitServices.price);
    return list(rows.map((s) => ({ code: s.code, name: s.name, description: s.description, price: s.price, durationMins: s.durationMins, icon: s.icon })));
  });

  app.post('/home-visit/serviceability', async (req) => {
    const body = parse(z.object({ pincode: z.string().regex(/^\d{6}$/), lat: z.number().optional(), lng: z.number().optional() }), req.body);
    const zone = await findZoneForPincode(db, body.pincode);
    return {
      serviceable: !!zone,
      zoneId: zone?.id ?? null,
      zoneName: zone?.name ?? null,
      message: zone ? `Home visits are available in ${zone.name}.` : 'Sorry, home visits are not available at this pincode yet.',
    };
  });

  app.post('/home-visits', { config: { idempotent: true } }, async (req, reply) => {
    const body = parse(
      z.object({
        patientId: zUuid,
        serviceCode: z.string().min(1).max(40),
        address: zAddress,
        preferredStart: zIso,
        preferredEnd: zIso,
        reason: z.string().trim().min(1).max(500),
        careEpisodeId: zUuid.optional(),
        couponCode: zCouponCode.optional(),
        useWallet: z.boolean().optional(),
      }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, body.patientId, 'book', 'home_visit.create');
    const [service] = await db.select().from(homeVisitServices).where(eq(homeVisitServices.code, body.serviceCode));
    if (!service) throw errors.validation('Unknown serviceCode');
    const start = new Date(body.preferredStart);
    const end = new Date(body.preferredEnd);
    if (!(end > start)) throw errors.validation('preferredEnd must be after preferredStart');
    if (end <= new Date()) throw errors.validation('Preferred window is in the past');
    const zone = await findZoneForPincode(db, body.address.pincode);
    if (!zone) throw new AppError('NOT_SERVICEABLE', 'Home visits are not available at this pincode', { pincode: body.address.pincode });
    // Family Care Plan benefit (contract section 37): discount for the subscriber's own and managed patients.
    const discount = await homeVisitDiscount(db, body.patientId, service.price);
    const price = service.price - discount;

    const result = await db.transaction(async (tx) => {
      let episodeId = body.careEpisodeId;
      if (episodeId) {
        const [ep] = await tx.select().from(careEpisodes).where(eq(careEpisodes.id, episodeId));
        if (!ep || ep.patientId !== body.patientId) throw errors.validation('careEpisodeId does not belong to this patient');
        if (!ACTIVE_STATUSES.includes(ep.status as never)) throw errors.conflict('Care episode is closed', { status: ep.status });
      } else {
        episodeId = (await createEpisode(tx, { patientId: body.patientId, title: `${service.name}: ${body.reason}`, concern: body.reason, actor: req.ctx.actor })).id;
      }
      const [visit] = await tx
        .insert(homeVisits)
        .values({
          id: randomUUID(),
          patientId: body.patientId,
          serviceCode: service.code,
          price,
          discountApplied: discount,
          reason: body.reason,
          address: body.address,
          preferredStart: start,
          preferredEnd: end,
          careEpisodeId: episodeId,
          visitCode: randomDigits(4),
          zoneId: zone.id,
          timeline: [{ status: 'requested', at: new Date().toISOString(), note: null }],
          createdByUserId: req.ctx.user.id,
        })
        .returning();
      const assigned = await autoAssign(tx, visit, req.ctx.actor);
      const payment = await svc.payments.create(tx, {
        purpose: 'home_visit',
        refId: visit.id,
        patientId: body.patientId,
        amount: price,
        userId: req.ctx.user.id,
        couponCode: body.couponCode,
        useWallet: body.useWallet,
        actor: req.ctx.actor,
      });
      await addEvent(tx, episodeId, 'home_visit_requested', `${service.name} home visit requested`, req.ctx.actor, { homeVisitId: visit.id });
      await audit(tx, req.ctx.actor, { action: 'home_visit.create', entityType: 'home_visit', entityId: visit.id, metadata: { patientId: body.patientId } });
      return { visit: assigned, payment };
    });
    await notifyProviderAssigned(result.visit);
    const payment = await svc.payments.settleIfCovered(result.payment, req.ctx.actor);
    return reply.code(201).send({ homeVisit: await toHomeVisit(db, payment === result.payment ? result.visit : await load(result.visit.id), 'family'), payment: toPayment(payment) });
  });

  async function notifyProviderAssigned(v: HomeVisitRow) {
    if (v.status !== 'assigned' || !v.providerId) return;
    const [p] = await db.select({ userId: providers.userId }).from(providers).where(eq(providers.id, v.providerId));
    if (p) {
      await svc.notify.notifyUsers([p.userId], {
        template: 'home_visit_update',
        params: { status: 'assigned' },
        category: 'home_visit',
        deepLink: `/provider/visits/${v.id}`,
        dedupeKey: `hv_assigned:${v.id}:${v.providerId}`,
      });
    }
  }

  app.get('/home-visits', async (req) => {
    const q = parse(z.object({ patientId: zUuid.optional(), status: z.string().max(30).optional(), scope: z.enum(['active', 'past']).optional() }), req.query);
    const page = pageFromQuery(req.query);
    let patientIds: string[];
    if (q.patientId) {
      await assertCanActForPatient(db, req.ctx, q.patientId, ['book', 'view_records', 'manage_care'], 'home_visit.list');
      patientIds = [q.patientId];
    } else {
      patientIds = (await listActablePatients(db, req.ctx.user))
        .filter((p) => p.permissions.some((x) => x !== 'receive_alerts'))
        .map((p) => p.patientId);
    }
    if (!patientIds.length) return { items: [], nextCursor: null };
    const conds = [inArray(homeVisits.patientId, patientIds)];
    if (q.status) conds.push(eq(homeVisits.status, q.status));
    if (q.scope === 'active') conds.push(notInArray(homeVisits.status, ['completed', 'cancelled']));
    if (q.scope === 'past') conds.push(inArray(homeVisits.status, ['completed', 'cancelled']));
    const rows = await db
      .select()
      .from(homeVisits)
      .where(and(...conds))
      .orderBy(desc(homeVisits.preferredStart))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toHomeVisits(db, rows, () => 'family'), page);
  });

  const load = async (id: string): Promise<HomeVisitRow> => {
    const [v] = await db.select().from(homeVisits).where(eq(homeVisits.id, id));
    if (!v) throw errors.notFound('Home visit');
    return v;
  };

  app.get('/home-visits/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const v = await load(id);
    const view = await visitViewFor(db, req.ctx, v);
    await audit(db, req.ctx.actor, { action: 'home_visit.read', entityType: 'home_visit', entityId: id, metadata: { view } });
    return toHomeVisit(db, v, view);
  });

  app.post('/home-visits/:id/cancel', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ reason: z.string().trim().min(1).max(500), refundTo: zRefundTo.optional() }), req.body);
    const v = await load(id);
    await assertCanActForPatient(db, req.ctx, v.patientId, 'book', 'home_visit.cancel');
    if (!['requested', 'unassigned', 'assigned', 'accepted', 'en_route'].includes(v.status)) throw errors.invalidTransition(v.status, 'cancelled');
    const [pay] = await db.select().from(payments).where(and(eq(payments.purpose, 'home_visit'), eq(payments.refId, v.id)));
    const row = await db.transaction(async (tx) => {
      const [r] = await tx
        .update(homeVisits)
        .set({ status: 'cancelled', cancelReason: body.reason, timeline: timelineAdd(v, 'cancelled', null), updatedAt: new Date() })
        .where(eq(homeVisits.id, id))
        .returning();
      if (pay?.status === 'pending') await svc.payments.voidPending(tx, pay.id);
      await addEvent(tx, v.careEpisodeId, 'home_visit_cancelled', 'Home visit cancelled', req.ctx.actor, { homeVisitId: id });
      await audit(tx, req.ctx.actor, { action: 'home_visit.cancel', entityType: 'home_visit', entityId: id });
      return r;
    });
    if (pay?.status === 'succeeded') await svc.payments.refund(pay.id, { reason: 'home_visit_cancelled', actor: req.ctx.actor, toWallet: body.refundTo === 'wallet' });
    return toHomeVisit(db, row, 'family');
  });

  // ---------------------------------------------------------------- provider actions
  const providerGuard = requireRoles(svc, 'provider');

  async function loadAssigned(req: FastifyRequest, id: string, allowed: string[], action: string): Promise<HomeVisitRow> {
    const v = await load(id);
    if (!req.ctx.user.providerId || v.providerId !== req.ctx.user.providerId) {
      await audit(db, req.ctx.actor, { action, entityType: 'home_visit', entityId: id, outcome: 'denied' });
      throw errors.forbidden('This visit is not assigned to you');
    }
    if (!allowed.includes(v.status)) throw errors.invalidTransition(v.status, action.split('.').pop() ?? action);
    return v;
  }

  async function update(v: HomeVisitRow, patch: Partial<HomeVisitRow>, status: string | null, note: string | null, action: string, req: FastifyRequest) {
    const row = await db.transaction(async (tx) => {
      const [r] = await tx
        .update(homeVisits)
        .set({ ...patch, ...(status ? { status, timeline: timelineAdd(v, status, note) } : {}), updatedAt: new Date() })
        .where(eq(homeVisits.id, v.id))
        .returning();
      await audit(tx, req.ctx.actor, { action, entityType: 'home_visit', entityId: v.id, metadata: status ? { status } : {} });
      return r;
    });
    if (status) {
      await svc.notify.notifyPatient(v.patientId, {
        template: 'home_visit_update',
        params: { status: status.replace('_', ' ') },
        category: 'home_visit',
        deepLink: `/home-visits/${v.id}`,
        dedupeKey: `hv:${v.id}:${status}:${row.timeline.length}`,
      });
    }
    return row;
  }

  app.post('/home-visits/:id/accept', { preHandler: providerGuard }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const v = await loadAssigned(req, id, ['assigned'], 'home_visit.accept');
    const row = await update(v, {}, 'accepted', null, 'home_visit.accept', req);
    return toHomeVisit(db, row, 'provider');
  });

  app.post('/home-visits/:id/reject', { preHandler: providerGuard }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ reason: z.string().trim().min(1).max(500) }), req.body);
    const v = await loadAssigned(req, id, ['assigned', 'accepted'], 'home_visit.reject');
    const row = await db.transaction(async (tx) => {
      const [r] = await tx
        .update(homeVisits)
        .set({
          status: 'unassigned',
          providerId: null,
          assignedAt: null,
          rejectedProviderIds: [...v.rejectedProviderIds, v.providerId!],
          timeline: timelineAdd(v, 'unassigned', 'Provider declined'),
          updatedAt: new Date(),
        })
        .where(eq(homeVisits.id, id))
        .returning();
      await audit(tx, req.ctx.actor, { action: 'home_visit.reject', entityType: 'home_visit', entityId: id, metadata: { reasonLength: body.reason.length } });
      return autoAssign(tx, r, SYSTEM_ACTOR);
    });
    await notifyProviderAssigned(row);
    // The rejecting provider no longer has access: return their last view without patient context.
    const out = await toHomeVisit(db, row, 'ops');
    return out;
  });

  app.post('/home-visits/:id/en-route', { preHandler: providerGuard }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ etaMinutes: z.number().int().min(0).max(600) }), req.body);
    const v = await loadAssigned(req, id, ['accepted'], 'home_visit.en_route');
    const row = await update(v, { etaMinutes: body.etaMinutes }, 'en_route', `ETA ${body.etaMinutes} min`, 'home_visit.en_route', req);
    return toHomeVisit(db, row, 'provider');
  });

  app.post('/home-visits/:id/arrived', { preHandler: providerGuard }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const v = await loadAssigned(req, id, ['en_route'], 'home_visit.arrived');
    const row = await update(v, { arrivedAt: new Date(), etaMinutes: 0 }, 'arrived', null, 'home_visit.arrived', req);
    return toHomeVisit(db, row, 'provider');
  });

  app.post('/home-visits/:id/verify-identity', { preHandler: providerGuard }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ visitCode: z.string().regex(/^\d{4}$/), consentConfirmed: z.boolean() }), req.body);
    const v = await loadAssigned(req, id, ['arrived'], 'home_visit.verify_identity');
    if (!body.consentConfirmed) throw errors.validation('Patient consent must be confirmed before starting the visit');
    if (v.verifyAttempts >= 5) throw new AppError('RATE_LIMITED', 'Too many incorrect visit codes. Contact operations.');
    if (!safeEqual(body.visitCode, v.visitCode)) {
      await db.update(homeVisits).set({ verifyAttempts: v.verifyAttempts + 1 }).where(eq(homeVisits.id, id));
      await audit(db, req.ctx.actor, { action: 'home_visit.verify_identity', entityType: 'home_visit', entityId: id, outcome: 'denied' });
      throw errors.validation('Visit code does not match', { attemptsRemaining: Math.max(0, 4 - v.verifyAttempts) });
    }
    const row = await update(v, { identityVerifiedAt: new Date() }, 'in_progress', 'Identity verified, consent confirmed', 'home_visit.verify_identity', req);
    await db.transaction(async (tx) => {
      await advanceEpisode(tx, v.careEpisodeId, ['UNDER_CARE'], 'Home visit started', req.ctx.actor);
      await addEvent(tx, v.careEpisodeId, 'home_visit_started', 'Home visit started', req.ctx.actor, { homeVisitId: id });
    });
    return toHomeVisit(db, row, 'provider');
  });

  app.post('/home-visits/:id/vitals', { preHandler: providerGuard, config: { idempotent: true } }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(
      z.object({
        measurements: z
          .array(z.object({ type: zVitalType, value: z.number().finite(), unit: z.string().min(1).max(20), measuredAt: zIso }))
          .min(1)
          .max(20),
      }),
      req.body,
    );
    const v = await loadAssigned(req, id, ['in_progress', 'escalated'], 'home_visit.vitals');
    const inserted = await db.transaction(async (tx) => {
      const out = [];
      for (const m of body.measurements) {
        const [row] = await tx.insert(vitals).values({
          patientId: v.patientId,
          type: m.type,
          value: m.value,
          unit: m.unit,
          measuredAt: new Date(m.measuredAt),
          source: 'home_visit',
          recordedByUserId: req.ctx.user.id,
          recordedByName: req.ctx.user.name,
          homeVisitId: id,
        }).returning();
        out.push(row);
      }
      await audit(tx, req.ctx.actor, { action: 'home_visit.vitals', entityType: 'home_visit', entityId: id, metadata: { count: body.measurements.length } });
      return out;
    });
    await evaluateVitals(svc, v.patientId, inserted);
    // Deterministic safety engine on the recorded vitals.
    const ctx = await clinicalContext(db, v.patientId);
    const safety = await svc.safety.evaluate({ vitals: body.measurements.map((m) => ({ type: m.type, value: m.value })), ageYears: ctx.age });
    if (safety.level === 'urgent' || safety.level === 'emergency') {
      await raiseVisitSafety(v, safety.level, safety.triggeredRules, safety.rulePackVersion, req);
    }
    return toHomeVisit(db, await load(id), 'provider');
  });

  async function raiseVisitSafety(
    v: HomeVisitRow,
    level: 'urgent' | 'emergency',
    rules: Array<{ ruleId: string; title: string }>,
    rulePackVersion: string | null,
    req: FastifyRequest,
  ) {
    await db.transaction(async (tx) => {
      await svc.safety.recordEvent(tx, { patientId: v.patientId, careEpisodeId: v.careEpisodeId, level, source: 'home_visit', rules, rulePackVersion });
      await advanceEpisode(tx, v.careEpisodeId, [level === 'emergency' ? 'EMERGENCY' : 'ESCALATED'], 'Safety rule triggered during home visit', req.ctx.actor, {
        priority: level,
      });
    });
    await svc.notify.notifyPatient(v.patientId, {
      template: 'safety_alert',
      params: { patient: 'your family member' },
      category: 'safety',
      critical: true,
      deepLink: `/home-visits/${v.id}`,
    });
  }

  app.post('/home-visits/:id/observations', { preHandler: providerGuard }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(
      z.object({ notes: z.string().max(4000), checklist: z.record(z.string().max(60), z.union([z.boolean(), z.string().max(200)])) }),
      req.body,
    );
    const v = await loadAssigned(req, id, ['in_progress', 'escalated'], 'home_visit.observations');
    const row = await update(v, { observations: body }, null, null, 'home_visit.observations', req);
    return toHomeVisit(db, row, 'provider');
  });

  app.post('/home-visits/:id/escalate', { preHandler: providerGuard }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ reason: z.string().trim().min(1).max(1000), severity: z.enum(['urgent', 'emergency']) }), req.body);
    const v = await loadAssigned(req, id, ['arrived', 'in_progress'], 'home_visit.escalate');
    const at = new Date().toISOString();
    const row = await update(v, { escalation: { reason: body.reason, severity: body.severity, at } }, 'escalated', null, 'home_visit.escalate', req);
    await raiseVisitSafety(v, body.severity, [{ ruleId: 'provider.escalation', title: 'Escalated by home-care provider' }], null, req);
    return toHomeVisit(db, row, 'provider');
  });

  app.post('/home-visits/:id/complete', { preHandler: providerGuard }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ summary: z.string().trim().min(1).max(8000) }), req.body);
    const v = await loadAssigned(req, id, ['in_progress', 'escalated'], 'home_visit.complete');
    const [service] = await db.select().from(homeVisitServices).where(eq(homeVisitServices.code, v.serviceCode));
    const row = await db.transaction(async (tx) => {
      const [r] = await tx
        .update(homeVisits)
        .set({ status: 'completed', summary: body.summary, completedAt: new Date(), timeline: timelineAdd(v, 'completed', null), updatedAt: new Date() })
        .where(eq(homeVisits.id, id))
        .returning();
      const text = [
        `Home visit summary: ${service?.name ?? v.serviceCode}`,
        `Date: ${istDate()}`,
        `Provider: ${req.ctx.user.name ?? 'Home-care provider'}`,
        '',
        body.summary,
      ].join('\n');
      const record = await storeRecord(tx, svc.storage, {
        patientId: v.patientId,
        type: 'visit_summary',
        title: `Home visit summary - ${service?.name ?? v.serviceCode}`,
        recordDate: istDate(),
        source: 'home_visit',
        uploadedByUserId: req.ctx.user.id,
        uploadedByName: req.ctx.user.name,
        fileName: `visit-summary-${id.slice(0, 8)}.txt`,
        mimeType: 'text/plain',
        data: Buffer.from(text, 'utf8'),
        homeVisitId: id,
      });
      await advanceEpisode(tx, v.careEpisodeId, ['FOLLOW_UP', 'UNDER_CARE'], 'Home visit completed', req.ctx.actor, { nextAction: 'Review home visit summary' });
      await addEvent(tx, v.careEpisodeId, 'home_visit_completed', 'Home visit completed; summary added to records', req.ctx.actor, {
        homeVisitId: id,
        recordId: record.id,
      });
      await audit(tx, req.ctx.actor, { action: 'home_visit.complete', entityType: 'home_visit', entityId: id, metadata: { recordId: record.id } });
      return r;
    });
    await svc.notify.notifyPatient(v.patientId, {
      template: 'home_visit_completed',
      category: 'home_visit',
      deepLink: `/home-visits/${id}`,
      dedupeKey: `hv_completed:${id}`,
    });
    // Contract section 44: a completed sample-collection visit moves its lab order on.
    if (v.serviceCode === 'sample_collection') await onCollectionVisitCompleted(svc, id, req.ctx.actor);
    return toHomeVisit(db, row, 'provider');
  });

  // ---------------------------------------------------------------- ops assignment
  app.post('/home-visits/:id/assign', { preHandler: requireRoles(svc, 'coordinator', 'ops_admin', 'super_admin') }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ providerId: zUuid }), req.body);
    const v = await load(id);
    if (!['requested', 'unassigned', 'assigned', 'accepted'].includes(v.status)) throw errors.invalidTransition(v.status, 'assigned');
    const [p] = await db.select().from(providers).where(eq(providers.id, body.providerId));
    if (!p || !providerEligible(p)) throw errors.conflict('Provider is not eligible (must be a verified field provider with a valid credential)');
    if (!p.capabilities.includes(v.serviceCode)) throw errors.conflict('Provider does not have this service capability');
    if (v.zoneId) {
      const [z1] = await db.select().from(providerZones).where(and(eq(providerZones.providerId, p.id), eq(providerZones.zoneId, v.zoneId)));
      if (!z1) throw errors.conflict('Provider does not serve this zone');
    }
    const [row] = await db
      .update(homeVisits)
      .set({ status: 'assigned', providerId: p.id, assignedAt: new Date(), timeline: timelineAdd(v, 'assigned', 'Assigned by operations'), updatedAt: new Date() })
      .where(eq(homeVisits.id, id))
      .returning();
    await audit(db, req.ctx.actor, { action: 'home_visit.assign', entityType: 'home_visit', entityId: id, metadata: { providerId: p.id } });
    await notifyProviderAssigned(row);
    return toHomeVisit(db, row, hasRole(req.ctx.user, 'coordinator', 'ops_admin', 'super_admin') ? 'ops' : 'family');
  });
}

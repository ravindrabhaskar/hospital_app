import { randomUUID } from 'node:crypto';
import { and, desc, eq, inArray, isNull, lte } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Db, DbOrTx } from '../../db/client.js';
import { medicalRecords, patients, providers, recordShares, secondOpinionPricing, secondOpinions, specialties } from '../../db/schema.js';
import { assertCanActForPatient, listActablePatients, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { list, pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { PdfBuilder, pdfDate } from '../../lib/pdf.js';
import { ageFromDob, istDate, iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import type { NotificationService } from '../notifications/service.js';
import { toPayment, type PaymentEffects, type PaymentRow } from '../payments/service.js';
import { storeRecord } from '../records/service.js';
import { usersWithRoles } from '../safety/alerts.js';
import { zCouponCode } from '../wallet/routes.js';
import type { Services } from '../../services.js';

/** Contract section 49: specialist second opinion. */
type SoRow = typeof secondOpinions.$inferSelect;
const READ: Perm[] = ['book', 'view_records', 'manage_care', 'staff_ops'];
const SHARE_DAYS = 30;

export async function toSecondOpinions(db: DbOrTx, rows: SoRow[]) {
  if (!rows.length) return [];
  const pats = await db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, [...new Set(rows.map((r) => r.patientId))]));
  const pn = new Map(pats.map((p) => [p.id, p.name]));
  const recIds = [...new Set(rows.flatMap((r) => r.recordIds))];
  const recs = recIds.length ? await db.select({ id: medicalRecords.id, title: medicalRecords.title }).from(medicalRecords).where(inArray(medicalRecords.id, recIds)) : [];
  const rm = new Map(recs.map((r) => [r.id, r.title]));
  const docIds = [...new Set(rows.map((r) => r.doctorId).filter((x): x is string => !!x))];
  const docs = docIds.length ? await db.select({ id: providers.id, name: providers.name }).from(providers).where(inArray(providers.id, docIds)) : [];
  const dm = new Map(docs.map((d) => [d.id, d.name]));
  return rows.map((r) => ({
    id: r.id,
    patientId: r.patientId,
    patientName: pn.get(r.patientId) ?? null,
    specialty: r.specialty,
    question: r.question,
    records: r.recordIds.map((id) => ({ id, title: rm.get(id) ?? 'Record' })),
    status: r.status,
    price: r.price,
    doctorName: r.doctorId ? (dm.get(r.doctorId) ?? null) : null,
    opinion: r.opinion,
    recommendations: r.recommendations,
    opinionRecordId: r.opinionRecordId,
    dueAt: iso(r.dueAt),
    createdAt: iso(r.createdAt),
    answeredAt: iso(r.answeredAt),
  }));
}

async function doctorUsersOfSpecialty(db: DbOrTx, specialty: string): Promise<string[]> {
  const rows = await db.select({ userId: providers.userId }).from(providers).where(and(eq(providers.kind, 'doctor'), eq(providers.specialty, specialty), eq(providers.verificationStatus, 'verified')));
  return rows.map((r) => r.userId);
}

export function secondOpinionPaymentEffects(notify: NotificationService): PaymentEffects {
  return {
    async onSucceeded(db: Db, p: PaymentRow) {
      const [s] = await db.select().from(secondOpinions).where(eq(secondOpinions.id, p.refId));
      if (!s || s.status !== 'pending_payment') return;
      const dueAt = new Date(Date.now() + s.turnaroundHours * 3600_000);
      await db.update(secondOpinions).set({ status: 'open', dueAt, updatedAt: new Date() }).where(and(eq(secondOpinions.id, s.id), eq(secondOpinions.status, 'pending_payment')));
      await audit(db, SYSTEM_ACTOR, { action: 'second_opinion.open', entityType: 'second_opinion', entityId: s.id });
      await notify.notifyUsers(await doctorUsersOfSpecialty(db, s.specialty), {
        template: 'second_opinion_open',
        category: 'record',
        deepLink: `/clinician/second-opinions/${s.id}`,
        dedupeKey: `so_open:${s.id}`,
      });
    },
    async onFailed(db: Db, p: PaymentRow) {
      await db.update(secondOpinions).set({ status: 'cancelled', updatedAt: new Date() }).where(and(eq(secondOpinions.id, p.refId), eq(secondOpinions.status, 'pending_payment')));
    },
    async onRetry(tx, p: PaymentRow) {
      await tx.update(secondOpinions).set({ status: 'pending_payment', updatedAt: new Date() }).where(and(eq(secondOpinions.id, p.refId), eq(secondOpinions.status, 'cancelled'), isNull(secondOpinions.doctorId)));
    },
  };
}

export async function renderOpinionPdf(p: { so: SoRow; patient: { name: string | null; dob: string | null; gender: string }; doctor: { name: string; qualification: string; registrationNumber: string }; specialtyName: string; opinion: string; recommendations: string[]; suggestTeleconsult: boolean; now: Date }) {
  const b = new PdfBuilder('Specialist second opinion', `${p.specialtyName}  |  ${pdfDate(p.now)}`, { author: p.doctor.name, subject: 'Second opinion' });
  b.infoBoxes([
    { title: 'Specialist', rows: [['Name', p.doctor.name], ['Qualifications', p.doctor.qualification], ['Reg. No.', p.doctor.registrationNumber]] },
    { title: 'Patient', rows: [['Name', p.patient.name ?? 'Patient'], ['Age / Gender', `${ageFromDob(p.patient.dob) ?? '-'} / ${p.patient.gender}`], ['Date', pdfDate(p.now)]] },
  ]);
  b.heading('Question');
  b.paragraph(p.so.question);
  b.heading('Opinion');
  b.paragraph(p.opinion);
  if (p.recommendations.length) {
    b.heading('Recommendations');
    b.paragraph(p.recommendations.map((r, i) => `${i + 1}. ${r}`).join('\n'));
  }
  if (p.suggestTeleconsult) b.paragraph('The specialist suggests a teleconsultation to discuss this further.', { bold: true });
  b.paragraph('This opinion is based only on the records shared and does not replace an in-person examination. In an emergency call 108.', { size: 8.5, color: '#6B7280' });
  b.signature([p.doctor.name, `Reg. No. ${p.doctor.registrationNumber}`, 'Digitally generated', '[REQUIRES LEGAL REVIEW: e-signature rules]']);
  return b.finish([`Second opinion ${p.so.id.slice(0, 8).toUpperCase()} generated by CareCompanion on ${pdfDate(p.now)}.`]);
}

/** Worker: an unanswered request past `dueAt` alerts ops (once). */
export async function secondOpinionOverdue(svc: Services, now: Date): Promise<number> {
  const due = await svc.db
    .update(secondOpinions)
    .set({ overdueAlertedAt: now })
    .where(and(inArray(secondOpinions.status, ['open', 'claimed']), lte(secondOpinions.dueAt, now), isNull(secondOpinions.overdueAlertedAt)))
    .returning();
  if (!due.length) return 0;
  const ops = await usersWithRoles(svc.db, ['coordinator', 'ops_admin']);
  for (const s of due) {
    await svc.notify.notifyUsers(ops, { template: 'second_opinion_overdue', category: 'system', deepLink: `/ops/second-opinions/${s.id}`, dedupeKey: `so_overdue:${s.id}` });
    await audit(svc.db, SYSTEM_ACTOR, { action: 'second_opinion.overdue', entityType: 'second_opinion', entityId: s.id });
  }
  return due.length;
}

export async function secondOpinionRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/second-opinions/pricing', async () => {
    const rows = await db.select().from(secondOpinionPricing).where(eq(secondOpinionPricing.active, true)).orderBy(secondOpinionPricing.specialty);
    return list(rows.map((r) => ({ specialty: r.specialty, price: r.price, turnaroundHours: r.turnaroundHours })));
  });

  app.post('/second-opinions', { config: { idempotent: true } }, async (req, reply) => {
    const body = parse(
      z.object({
        patientId: zUuid,
        specialty: z.string().min(1).max(40),
        question: z.string().trim().min(10).max(4000),
        recordIds: z.array(zUuid).min(1).max(20),
        couponCode: zCouponCode.optional(),
        useWallet: z.boolean().optional(),
      }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, body.patientId, 'book', 'second_opinion.create');
    const [pricing] = await db.select().from(secondOpinionPricing).where(and(eq(secondOpinionPricing.specialty, body.specialty), eq(secondOpinionPricing.active, true)));
    if (!pricing) throw errors.validation('Second opinions are not offered for this specialty', { field: 'specialty' });
    const recordIds = [...new Set(body.recordIds)];
    const recs = await db.select({ id: medicalRecords.id, patientId: medicalRecords.patientId }).from(medicalRecords).where(inArray(medicalRecords.id, recordIds));
    if (recs.length !== recordIds.length || recs.some((r) => r.patientId !== body.patientId)) throw errors.validation('recordIds must be records of this patient', { field: 'recordIds' });
    const id = randomUUID();
    const result = await db.transaction(async (tx) => {
      const payment = await svc.payments.create(tx, {
        purpose: 'second_opinion',
        refId: id,
        patientId: body.patientId,
        amount: pricing.price,
        userId: req.ctx.user.id,
        couponCode: body.couponCode,
        useWallet: body.useWallet,
        actor: req.ctx.actor,
      });
      await tx.insert(secondOpinions).values({
        id,
        patientId: body.patientId,
        specialty: body.specialty,
        question: body.question,
        recordIds,
        price: pricing.price,
        turnaroundHours: pricing.turnaroundHours,
        createdByUserId: req.ctx.user.id,
      });
      await audit(tx, req.ctx.actor, { action: 'second_opinion.create', entityType: 'second_opinion', entityId: id, metadata: { specialty: body.specialty, records: recordIds.length } });
      return { payment };
    });
    const payment = await svc.payments.settleIfCovered(result.payment, req.ctx.actor);
    const [row] = await db.select().from(secondOpinions).where(eq(secondOpinions.id, id));
    return reply.code(201).send({ request: (await toSecondOpinions(db, [row]))[0], payment: toPayment(payment) });
  });

  app.get('/second-opinions', async (req) => {
    const q = parse(z.object({ patientId: zUuid.optional() }), req.query);
    const page = pageFromQuery(req.query);
    let ids: string[];
    if (q.patientId) {
      await assertCanActForPatient(db, req.ctx, q.patientId, READ, 'second_opinion.list');
      ids = [q.patientId];
    } else {
      ids = (await listActablePatients(db, req.ctx.user)).filter((p) => p.permissions.some((x) => x !== 'receive_alerts')).map((p) => p.patientId);
    }
    if (!ids.length) return { items: [], nextCursor: null };
    const rows = await db.select().from(secondOpinions).where(inArray(secondOpinions.patientId, ids)).orderBy(desc(secondOpinions.createdAt));
    return paginateArray(await toSecondOpinions(db, rows), page);
  });

  const load = async (id: string) => {
    const [s] = await db.select().from(secondOpinions).where(eq(secondOpinions.id, id));
    if (!s) throw errors.notFound('Second opinion');
    return s;
  };

  app.get('/second-opinions/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const s = await load(id);
    const mine = req.ctx.user.providerId && s.doctorId === req.ctx.user.providerId;
    if (!mine) await assertCanActForPatient(db, req.ctx, s.patientId, READ, 'second_opinion.read');
    return (await toSecondOpinions(db, [s]))[0];
  });

  // ---------------------------------------------------------------- clinician side
  const doctorOnly = requireRoles(svc, 'doctor');
  const myDoctor = async (providerId: string | null) => {
    if (!providerId) throw errors.forbidden('Doctor profile required');
    const [d] = await db.select().from(providers).where(eq(providers.id, providerId));
    if (!d || d.kind !== 'doctor') throw errors.forbidden('Doctor profile required');
    return d;
  };

  app.get('/clinician/second-opinions', { preHandler: doctorOnly }, async (req) => {
    const q = parse(z.object({ scope: z.enum(['open', 'mine']).default('open') }), req.query);
    const page = pageFromQuery(req.query);
    const d = await myDoctor(req.ctx.user.providerId);
    const rows =
      q.scope === 'open'
        ? await db.select().from(secondOpinions).where(and(eq(secondOpinions.status, 'open'), eq(secondOpinions.specialty, d.specialty ?? '__none__'))).orderBy(secondOpinions.dueAt)
        : await db.select().from(secondOpinions).where(eq(secondOpinions.doctorId, d.id)).orderBy(desc(secondOpinions.updatedAt));
    return paginateArray(await toSecondOpinions(db, rows), page);
  });

  app.post('/clinician/second-opinions/:id/claim', { preHandler: doctorOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const d = await myDoctor(req.ctx.user.providerId);
    const s = await load(id);
    if (s.specialty !== d.specialty) {
      await audit(db, req.ctx.actor, { action: 'second_opinion.claim', entityType: 'second_opinion', entityId: id, outcome: 'denied' });
      throw errors.forbidden('This request is for another specialty');
    }
    const row = await db.transaction(async (tx) => {
      const [r] = await tx
        .update(secondOpinions)
        .set({ status: 'claimed', doctorId: d.id, claimedAt: new Date(), updatedAt: new Date() })
        .where(and(eq(secondOpinions.id, id), eq(secondOpinions.status, 'open')))
        .returning();
      if (!r) throw errors.conflict('This request is no longer open', { status: s.status });
      // The records are shared read-only with the claiming doctor (audited).
      const expiresAt = new Date(Date.now() + SHARE_DAYS * 86400_000);
      for (const recordId of r.recordIds) await tx.insert(recordShares).values({ recordId, doctorId: d.id, expiresAt, createdByUserId: req.ctx.user.id });
      await audit(tx, req.ctx.actor, { action: 'second_opinion.claim', entityType: 'second_opinion', entityId: id, metadata: { sharedRecords: r.recordIds.length } });
      return r;
    });
    return (await toSecondOpinions(db, [row]))[0];
  });

  app.post('/clinician/second-opinions/:id/respond', { preHandler: doctorOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ opinion: z.string().trim().min(10).max(8000), recommendations: z.array(z.string().trim().min(1).max(500)).max(20), suggestTeleconsult: z.boolean() }), req.body);
    const d = await myDoctor(req.ctx.user.providerId);
    const s = await load(id);
    if (s.doctorId !== d.id) {
      await audit(db, req.ctx.actor, { action: 'second_opinion.respond', entityType: 'second_opinion', entityId: id, outcome: 'denied' });
      throw errors.forbidden('Only the claiming doctor can respond');
    }
    if (s.status !== 'claimed') throw errors.invalidTransition(s.status, 'answered');
    const [p] = await db.select().from(patients).where(eq(patients.id, s.patientId));
    const [sp] = await db.select({ name: specialties.name }).from(specialties).where(eq(specialties.code, s.specialty));
    const now = new Date();
    const pdf = await renderOpinionPdf({ so: s, patient: { name: p?.name ?? null, dob: p?.dob ?? null, gender: p?.gender ?? 'other' }, doctor: d, specialtyName: sp?.name ?? s.specialty, opinion: body.opinion, recommendations: body.recommendations, suggestTeleconsult: body.suggestTeleconsult, now });
    const row = await db.transaction(async (tx) => {
      const rec = await storeRecord(tx, svc.storage, {
        patientId: s.patientId,
        type: 'other',
        title: `Second opinion - ${sp?.name ?? s.specialty}`,
        recordDate: istDate(now),
        source: 'clinician_verified',
        uploadedByUserId: req.ctx.user.id,
        uploadedByName: d.name,
        fileName: `second-opinion-${id.slice(0, 8)}.pdf`,
        mimeType: 'application/pdf',
        data: pdf,
      });
      const [r] = await tx
        .update(secondOpinions)
        .set({ status: 'answered', opinion: body.opinion, recommendations: body.recommendations, suggestTeleconsult: body.suggestTeleconsult, opinionRecordId: rec.id, answeredAt: now, updatedAt: now })
        .where(and(eq(secondOpinions.id, id), eq(secondOpinions.status, 'claimed')))
        .returning();
      if (!r) throw errors.conflict('This request changed concurrently');
      await audit(tx, req.ctx.actor, { action: 'second_opinion.respond', entityType: 'second_opinion', entityId: id, metadata: { recordId: rec.id } });
      return r;
    });
    await svc.notify.notifyPatient(s.patientId, { template: 'second_opinion_answered', category: 'record', deepLink: `/second-opinions/${id}`, dedupeKey: `so_answered:${id}` });
    return (await toSecondOpinions(db, [row]))[0];
  });
}

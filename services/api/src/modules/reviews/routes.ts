import { and, desc, eq, gte, inArray, isNotNull, sql } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { appointments, familyAccessGrants, homeVisitServices, homeVisits, patients, providers, reviews } from '../../db/schema.js';
import { listActablePatients } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import type { RequestCtx } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { envelope, pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { specialtyNames } from '../doctors/routes.js';

type ReviewRow = typeof reviews.$inferSelect;
const REVIEW_WINDOW_DAYS = 30;

export const toReview = (r: ReviewRow) => ({
  id: r.id,
  targetType: r.targetType,
  targetId: r.targetId,
  doctorId: r.doctorId,
  providerId: r.providerId,
  subjectName: r.subjectName,
  rating: r.rating,
  text: r.text,
  status: r.status,
  authorLabel: 'Verified patient' as const,
  moderationNote: r.moderationNote,
  createdAt: iso(r.createdAt),
});

/**
 * Published rating = (imported baseline + published reviews) averaged, 1 decimal.
 * Called whenever a review enters or leaves the `published` state.
 */
export async function recalcRating(db: DbOrTx, providerId: string): Promise<void> {
  const [agg] = await db
    .select({ n: sql<number>`count(*)::int`, s: sql<number>`coalesce(sum(${reviews.rating}), 0)::float8` })
    .from(reviews)
    .where(and(eq(reviews.status, 'published'), sql`(${reviews.doctorId} = ${providerId} or ${reviews.providerId} = ${providerId})`));
  const [p] = await db.select({ baseSum: providers.ratingBaselineSum, baseCount: providers.ratingBaselineCount }).from(providers).where(eq(providers.id, providerId));
  if (!p) return;
  const count = p.baseCount + Number(agg?.n ?? 0);
  const sum = p.baseSum + Number(agg?.s ?? 0);
  await db
    .update(providers)
    .set({ ratingCount: count, rating: count ? Math.round((sum / count) * 10) / 10 : null })
    .where(eq(providers.id, providerId));
}

/** Only the patient themself, their managing guardian, or family with an active manage_care grant (not clinicians/ops). */
async function canReviewFor(db: DbOrTx, userId: string, patientId: string): Promise<boolean> {
  const [p] = await db.select({ userId: patients.userId, ownerUserId: patients.ownerUserId }).from(patients).where(eq(patients.id, patientId));
  if (!p) throw errors.notFound('Patient');
  if (p.userId === userId || p.ownerUserId === userId) return true;
  const grants = await db
    .select({ permissions: familyAccessGrants.permissions })
    .from(familyAccessGrants)
    .where(and(eq(familyAccessGrants.patientId, patientId), eq(familyAccessGrants.granteeUserId, userId), eq(familyAccessGrants.status, 'active')));
  return grants.some((g) => g.permissions.includes('manage_care'));
}

async function assertCanReview(db: DbOrTx, ctx: RequestCtx, patientId: string, action: string): Promise<void> {
  if (await canReviewFor(db, ctx.user.id, patientId)) return;
  await audit(db, ctx.actor, { action, entityType: 'patient', entityId: patientId, outcome: 'denied', metadata: { required: ['self', 'manage_care'] } });
  throw errors.forbidden();
}

/** Contract section 33: ratings & reviews. */
export async function reviewRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/reviews/pending', async (req) => {
    const q = parse(z.object({ patientId: zUuid.optional() }), req.query);
    const page = pageFromQuery(req.query);
    let ids: string[];
    if (q.patientId) {
      await assertCanReview(db, req.ctx, q.patientId, 'review.pending');
      ids = [q.patientId];
    } else {
      ids = (await listActablePatients(db, req.ctx.user)).filter((p) => p.permissions.includes('manage_care')).map((p) => p.patientId);
    }
    if (!ids.length) return { items: [], nextCursor: null };
    const since = new Date(Date.now() - REVIEW_WINDOW_DAYS * 86400_000);
    const [appts, visits, names] = await Promise.all([
      db
        .select({ a: appointments, doctor: providers })
        .from(appointments)
        .innerJoin(providers, eq(providers.id, appointments.doctorId))
        .where(and(inArray(appointments.patientId, ids), eq(appointments.status, 'completed'), gte(sql`coalesce(${appointments.completedAt}, ${appointments.endAt})`, since))),
      db
        .select({ v: homeVisits, prov: providers, service: homeVisitServices.name })
        .from(homeVisits)
        .innerJoin(providers, eq(providers.id, homeVisits.providerId))
        .innerJoin(homeVisitServices, eq(homeVisitServices.code, homeVisits.serviceCode))
        .where(and(inArray(homeVisits.patientId, ids), eq(homeVisits.status, 'completed'), isNotNull(homeVisits.completedAt), gte(homeVisits.completedAt, since))),
      specialtyNames(db),
    ]);
    const targetIds = [...appts.map((x) => x.a.id), ...visits.map((x) => x.v.id)];
    const done = targetIds.length ? await db.select({ id: reviews.targetId }).from(reviews).where(inArray(reviews.targetId, targetIds)) : [];
    const reviewed = new Set(done.map((d) => d.id));
    const items = [
      ...appts
        .filter((x) => !reviewed.has(x.a.id))
        .map((x) => ({
          targetType: 'appointment' as const,
          targetId: x.a.id,
          title: `Consultation with ${x.doctor.name}`,
          subtitle: names.get(x.doctor.specialty ?? '') ?? 'Doctor consultation',
          completedAt: iso(x.a.completedAt ?? x.a.endAt),
        })),
      ...visits
        .filter((x) => !reviewed.has(x.v.id))
        .map((x) => ({ targetType: 'home_visit' as const, targetId: x.v.id, title: `Home visit: ${x.service}`, subtitle: x.prov.name, completedAt: iso(x.v.completedAt) })),
    ].sort((a, b) => (b.completedAt ?? '').localeCompare(a.completedAt ?? ''));
    return paginateArray(items, page);
  });

  app.post('/reviews', async (req, reply) => {
    const body = parse(
      z.object({
        targetType: z.enum(['appointment', 'home_visit']),
        targetId: zUuid,
        rating: z.number().int().min(1).max(5),
        text: z.string().trim().max(1000).optional(),
      }),
      req.body,
    );
    let patientId: string;
    let completed: boolean;
    let subject: { doctorId: string | null; providerId: string | null; name: string };
    if (body.targetType === 'appointment') {
      const [x] = await db
        .select({ a: appointments, name: providers.name })
        .from(appointments)
        .innerJoin(providers, eq(providers.id, appointments.doctorId))
        .where(eq(appointments.id, body.targetId));
      if (!x) throw errors.notFound('Appointment');
      patientId = x.a.patientId;
      completed = x.a.status === 'completed';
      subject = { doctorId: x.a.doctorId, providerId: null, name: x.name };
    } else {
      const [v] = await db.select().from(homeVisits).where(eq(homeVisits.id, body.targetId));
      if (!v) throw errors.notFound('Home visit');
      patientId = v.patientId;
      completed = v.status === 'completed' && !!v.providerId;
      const [p] = v.providerId ? await db.select({ name: providers.name }).from(providers).where(eq(providers.id, v.providerId)) : [];
      subject = { doctorId: null, providerId: v.providerId, name: p?.name ?? 'Home-care provider' };
    }
    await assertCanReview(db, req.ctx, patientId, 'review.create');
    if (!completed) throw errors.conflict('Only completed services can be reviewed');
    const text = body.text ? body.text : null;
    const status = text ? 'pending' : 'published';
    const row = await db
      .transaction(async (tx) => {
        const [r] = await tx
          .insert(reviews)
          .values({
            targetType: body.targetType,
            targetId: body.targetId,
            doctorId: subject.doctorId,
            providerId: subject.providerId,
            subjectName: subject.name,
            patientId,
            authorUserId: req.ctx.user.id,
            rating: body.rating,
            text,
            status,
          })
          .onConflictDoNothing()
          .returning();
        if (!r) throw errors.conflict('This service has already been reviewed');
        if (status === 'published') await recalcRating(tx, (subject.doctorId ?? subject.providerId)!);
        await audit(tx, req.ctx.actor, { action: 'review.create', entityType: 'review', entityId: r.id, metadata: { targetType: body.targetType, rating: body.rating, status } });
        return r;
      });
    return reply.code(201).send(toReview(row));
  });

  const moderators = requireRoles(svc, 'coordinator', 'ops_admin', 'super_admin');

  app.get('/ops/reviews', { preHandler: moderators }, async (req) => {
    const q = parse(z.object({ status: z.enum(['pending', 'published', 'rejected']).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db
      .select()
      .from(reviews)
      .where(q.status ? eq(reviews.status, q.status) : undefined)
      .orderBy(desc(reviews.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toReview), page);
  });

  app.post('/ops/reviews/:id/moderate', { preHandler: moderators }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ status: z.enum(['published', 'rejected']), note: z.string().trim().max(1000).optional() }), req.body);
    const row = await db.transaction(async (tx) => {
      const [before] = await tx.select().from(reviews).where(eq(reviews.id, id));
      if (!before) throw errors.notFound('Review');
      const [r] = await tx
        .update(reviews)
        .set({ status: body.status, moderationNote: body.note ?? null, moderatedByUserId: req.ctx.user.id, moderatedAt: new Date() })
        .where(eq(reviews.id, id))
        .returning();
      const subjectId = r.doctorId ?? r.providerId;
      if (subjectId && (before.status === 'published' || r.status === 'published')) await recalcRating(tx, subjectId);
      await audit(tx, req.ctx.actor, { action: 'review.moderate', entityType: 'review', entityId: id, metadata: { from: before.status, to: body.status } });
      return r;
    });
    return toReview(row);
  });
}

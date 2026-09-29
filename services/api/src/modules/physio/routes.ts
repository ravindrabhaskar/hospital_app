import { and, desc, eq, inArray, ne } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { careEpisodes, exercisePlans, exercises, exerciseSessions, homeVisits, providers } from '../../db/schema.js';
import { assertCanActForPatient, resolvePatientAccess, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { hasRole, type RequestCtx } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { addDays, istDate, iso } from '../../lib/time.js';
import { parse, zDate, zUuid } from '../../lib/validate.js';

/** Contract section 53: physiotherapy & exercise programs. */
const READ: Perm[] = ['view_records', 'manage_care', 'staff_ops'];

/**
 * Plan authors (sections 53/54): a doctor with a care relationship, or a verified field provider of the given type
 * (physiotherapist / dietitian) who has a home visit with the patient. Denials are audited.
 */
export async function assertPlanAuthor(db: DbOrTx, ctx: RequestCtx, patientId: string, providerType: 'physiotherapist' | 'dietitian', action: string): Promise<{ name: string; role: string }> {
  if (hasRole(ctx.user, 'doctor') && ctx.user.providerId) {
    const access = await resolvePatientAccess(db, ctx.user, patientId);
    if (!access) throw errors.notFound('Patient');
    if (access.via.includes('doctor')) {
      const [d] = await db.select({ name: providers.name }).from(providers).where(eq(providers.id, ctx.user.providerId));
      return { name: d?.name ?? ctx.user.name ?? 'Doctor', role: 'doctor' };
    }
  }
  if (hasRole(ctx.user, 'provider') && ctx.user.providerId) {
    const [p] = await db.select().from(providers).where(eq(providers.id, ctx.user.providerId));
    if (p?.type === providerType && p.verificationStatus === 'verified') {
      const [v] = await db
        .select({ id: homeVisits.id })
        .from(homeVisits)
        .where(and(eq(homeVisits.patientId, patientId), eq(homeVisits.providerId, p.id), ne(homeVisits.status, 'cancelled')))
        .limit(1);
      if (v) return { name: p.name, role: providerType };
    }
  }
  await audit(db, ctx.actor, { action, entityType: 'patient', entityId: patientId, outcome: 'denied', metadata: { requires: `doctor or ${providerType}` } });
  throw errors.forbidden(`Only the patient's doctor or ${providerType} can do this`);
}

/** Read access: the care circle (view_records/manage_care), ops, or the plan's author. */
export async function assertPlanReader(db: DbOrTx, req: FastifyRequest, patientId: string, authorUserId: string | null, action: string) {
  if (authorUserId && authorUserId === req.ctx.user.id) return;
  await assertCanActForPatient(db, req.ctx, patientId, READ, action);
}

type PlanRow = typeof exercisePlans.$inferSelect;
const toPlan = (p: PlanRow) => ({
  id: p.id,
  patientId: p.patientId,
  careEpisodeId: p.careEpisodeId,
  authorName: p.authorName,
  authorRole: p.authorRole,
  items: p.items,
  startDate: p.startDate,
  endDate: p.endDate,
  weeks: p.weeks,
  status: p.endDate < istDate() ? ('completed' as const) : ('active' as const),
  createdAt: iso(p.createdAt),
});

export async function physioRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/exercise-library', async (req) => {
    const q = parse(z.object({ bodyArea: z.string().max(40).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db
      .select()
      .from(exercises)
      .where(q.bodyArea ? eq(exercises.bodyArea, q.bodyArea) : undefined)
      .orderBy(exercises.bodyArea, exercises.title);
    return paginateArray(
      rows.map((e) => ({ id: e.id, title: e.title, bodyArea: e.bodyArea, level: e.level, durationSecs: e.durationSecs, videoUrl: e.videoUrl, imageUrl: e.imageUrl, instructions: e.instructions, precautions: e.precautions })),
      page,
    );
  });

  app.post('/exercise-plans', async (req, reply) => {
    const body = parse(
      z.object({
        patientId: zUuid,
        careEpisodeId: zUuid.optional(),
        items: z
          .array(z.object({ exerciseId: zUuid, sets: z.number().int().min(1).max(10), reps: z.number().int().min(1).max(100), holdSecs: z.number().int().min(0).max(300).optional(), perDay: z.number().int().min(1).max(6), notes: z.string().trim().max(300).optional() }))
          .min(1)
          .max(20),
        startDate: zDate,
        weeks: z.number().int().min(1).max(52),
      }),
      req.body,
    );
    const author = await assertPlanAuthor(db, req.ctx, body.patientId, 'physiotherapist', 'exercise_plan.create');
    const lib = await db.select().from(exercises).where(inArray(exercises.id, [...new Set(body.items.map((i) => i.exerciseId))]));
    const lm = new Map(lib.map((e) => [e.id, e]));
    if (body.items.some((i) => !lm.has(i.exerciseId))) throw errors.validation('Unknown exerciseId', { field: 'items' });
    if (body.careEpisodeId) {
      const [ep] = await db.select({ patientId: careEpisodes.patientId }).from(careEpisodes).where(eq(careEpisodes.id, body.careEpisodeId));
      if (!ep || ep.patientId !== body.patientId) throw errors.validation('careEpisodeId does not belong to this patient');
    }
    const [row] = await db
      .insert(exercisePlans)
      .values({
        patientId: body.patientId,
        careEpisodeId: body.careEpisodeId ?? null,
        authorUserId: req.ctx.user.id,
        authorName: author.name,
        authorRole: author.role,
        items: body.items.map((i) => ({ exerciseId: i.exerciseId, title: lm.get(i.exerciseId)!.title, sets: i.sets, reps: i.reps, holdSecs: i.holdSecs ?? null, perDay: i.perDay, notes: i.notes ?? null })),
        startDate: body.startDate,
        endDate: addDays(body.startDate, body.weeks * 7 - 1),
        weeks: body.weeks,
      })
      .returning();
    await audit(db, req.ctx.actor, { action: 'exercise_plan.create', entityType: 'exercise_plan', entityId: row.id, metadata: { patientId: body.patientId, items: body.items.length } });
    return reply.code(201).send(toPlan(row));
  });

  app.get('/exercise-plans', async (req) => {
    const q = parse(z.object({ patientId: zUuid }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(exercisePlans).where(eq(exercisePlans.patientId, q.patientId)).orderBy(desc(exercisePlans.createdAt));
    const authored = rows.length > 0 && rows.every((r) => r.authorUserId === req.ctx.user.id);
    if (!authored) await assertCanActForPatient(db, req.ctx, q.patientId, READ, 'exercise_plan.list');
    return paginateArray(rows.map(toPlan), page);
  });

  const load = async (id: string) => {
    const [p] = await db.select().from(exercisePlans).where(eq(exercisePlans.id, id));
    if (!p) throw errors.notFound('Exercise plan');
    return p;
  };

  app.post('/exercise-plans/:id/sessions', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ completedExerciseIds: z.array(zUuid).max(20), painScore: z.number().int().min(0).max(10), note: z.string().trim().max(500).optional() }), req.body);
    const p = await load(id);
    await assertCanActForPatient(db, req.ctx, p.patientId, 'manage_care', 'exercise_session.create');
    const allowed = new Set(p.items.map((i) => i.exerciseId));
    if (body.completedExerciseIds.some((e) => !allowed.has(e))) throw errors.validation('completedExerciseIds must be exercises of this plan');
    const [row] = await db
      .insert(exerciseSessions)
      .values({ planId: id, completedExerciseIds: [...new Set(body.completedExerciseIds)], painScore: body.painScore, note: body.note ?? null, createdByUserId: req.ctx.user.id })
      .returning();
    await audit(db, req.ctx.actor, { action: 'exercise_session.create', entityType: 'exercise_plan', entityId: id, metadata: { painScore: body.painScore } });
    if (body.painScore >= 8) {
      await svc.notify.notifyUsers([p.authorUserId], {
        template: 'exercise_pain',
        params: { score: body.painScore },
        category: 'care_plan',
        deepLink: `/exercise-plans/${id}`,
        dedupeKey: `exercise_pain:${row.id}`,
      });
    }
    return reply.code(201).send({ id: row.id, planId: id, at: iso(row.at), completedExerciseIds: row.completedExerciseIds, painScore: row.painScore, note: row.note });
  });

  app.get('/exercise-plans/:id/progress', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const p = await load(id);
    await assertPlanReader(db, req, p.patientId, p.authorUserId, 'exercise_plan.progress');
    const sessions = await db.select().from(exerciseSessions).where(eq(exerciseSessions.planId, id)).orderBy(exerciseSessions.at);
    const today = istDate();
    const lastDay = p.endDate < today ? p.endDate : today;
    const days = lastDay < p.startDate ? 0 : Math.round((new Date(`${lastDay}T00:00:00Z`).getTime() - new Date(`${p.startDate}T00:00:00Z`).getTime()) / 86400_000) + 1;
    const perDay = Math.max(1, ...p.items.map((i) => i.perDay));
    const planned = days * perDay;
    return {
      sessionsPlanned: planned,
      sessionsDone: sessions.length,
      adherencePct: planned ? Math.min(100, Math.round((sessions.length / planned) * 100)) : null,
      painTrend: sessions.map((s) => ({ date: istDate(s.at), painScore: s.painScore })),
    };
  });
}

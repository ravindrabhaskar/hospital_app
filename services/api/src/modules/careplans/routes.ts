import { and, desc, eq, inArray } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { careEpisodes, carePlans, careTasks, medications, providers } from '../../db/schema.js';
import { assertCanActForPatient, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { parse, zDate, zIso, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { ACTIVE_STATUSES, addEvent } from '../episodes/service.js';
import { toCarePlans, toCareTask } from './service.js';

const READ: Perm[] = ['view_records', 'manage_care', 'receive_alerts'];
const zTime = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Expected HH:MM');

export const zMedicationInput = z.object({
  name: z.string().trim().min(1).max(100),
  dose: z.string().trim().min(1).max(60),
  frequency: z.string().trim().min(1).max(60),
  times: z.array(zTime).min(1).max(8),
  startDate: zDate,
  endDate: zDate.optional(),
  instructions: z.string().max(500).optional(),
});

export async function carePlanRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const grace = svc.config.DOSE_MISSED_GRACE_MIN;

  app.get('/care-plans', async (req) => {
    const q = parse(z.object({ patientId: zUuid.optional(), careEpisodeId: zUuid.optional() }), req.query);
    const page = pageFromQuery(req.query);
    let patientId = q.patientId;
    if (q.careEpisodeId) {
      const [ep] = await db.select().from(careEpisodes).where(eq(careEpisodes.id, q.careEpisodeId));
      if (!ep) throw errors.notFound('Care episode');
      if (patientId && patientId !== ep.patientId) throw errors.validation('careEpisodeId does not belong to patientId');
      patientId = ep.patientId;
    }
    if (!patientId) throw errors.validation('patientId or careEpisodeId is required');
    await assertCanActForPatient(db, req.ctx, patientId, READ, 'care_plan.list');
    const conds = [eq(carePlans.patientId, patientId)];
    if (q.careEpisodeId) conds.push(eq(carePlans.careEpisodeId, q.careEpisodeId));
    const rows = await db
      .select()
      .from(carePlans)
      .where(and(...conds))
      .orderBy(desc(carePlans.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toCarePlans(db, rows, grace), page);
  });

  app.post('/care-plans', { preHandler: requireRoles(svc, 'doctor') }, async (req, reply) => {
    const body = parse(
      z.object({
        careEpisodeId: zUuid,
        summary: z.string().trim().min(1).max(4000),
        instructions: z.string().trim().max(8000),
        tasks: z
          .array(
            z.object({
              type: z.enum(['medication', 'test', 'follow_up', 'lifestyle', 'monitoring', 'general']),
              title: z.string().trim().min(1).max(200),
              description: z.string().max(1000).optional(),
              dueAt: zIso.optional(),
              owner: z.enum(['patient', 'caregiver', 'provider']),
            }),
          )
          .max(50),
        medications: z.array(zMedicationInput).max(30),
        followUp: z.object({ afterDays: z.number().int().min(1).max(365), mode: z.enum(['video', 'in_clinic', 'home_visit']) }).nullable(),
      }),
      req.body,
    );
    const [ep] = await db.select().from(careEpisodes).where(eq(careEpisodes.id, body.careEpisodeId));
    if (!ep) throw errors.notFound('Care episode');
    await assertCanActForPatient(db, req.ctx, ep.patientId, 'manage_care', 'care_plan.create');
    if (!ACTIVE_STATUSES.includes(ep.status as never)) throw errors.conflict('Care episode is closed', { status: ep.status });
    const providerId = req.ctx.user.providerId;
    if (!providerId) throw errors.forbidden('Doctor profile required');
    const [doc] = await db.select().from(providers).where(eq(providers.id, providerId));
    const plan = await db.transaction(async (tx) => {
      const previous = await tx.select().from(carePlans).where(and(eq(carePlans.careEpisodeId, ep.id), eq(carePlans.status, 'active')));
      if (previous.length) {
        const ids = previous.map((p) => p.id);
        await tx.update(carePlans).set({ status: 'superseded' }).where(inArray(carePlans.id, ids));
        await tx.update(medications).set({ active: false }).where(inArray(medications.carePlanId, ids));
        await tx
          .update(careTasks)
          .set({ status: 'cancelled' })
          .where(and(inArray(careTasks.carePlanId, ids), inArray(careTasks.status, ['open', 'overdue'])));
      }
      const [p] = await tx
        .insert(carePlans)
        .values({
          careEpisodeId: ep.id,
          patientId: ep.patientId,
          doctorId: providerId,
          summary: body.summary,
          instructions: body.instructions,
          followUp: body.followUp,
          followUpDueAt: body.followUp ? new Date(Date.now() + body.followUp.afterDays * 86400_000) : null,
        })
        .returning();
      for (const t of body.tasks) {
        await tx.insert(careTasks).values({
          carePlanId: p.id,
          patientId: ep.patientId,
          type: t.type,
          title: t.title,
          description: t.description ?? null,
          dueAt: t.dueAt ? new Date(t.dueAt) : null,
          owner: t.owner,
        });
      }
      if (body.followUp) {
        await tx.insert(careTasks).values({
          carePlanId: p.id,
          patientId: ep.patientId,
          type: 'follow_up',
          title: `Follow-up (${body.followUp.mode.replace('_', ' ')})`,
          description: null,
          dueAt: p.followUpDueAt,
          owner: 'patient',
        });
      }
      for (const m of body.medications) {
        await tx.insert(medications).values({
          patientId: ep.patientId,
          carePlanId: p.id,
          name: m.name,
          dose: m.dose,
          frequency: m.frequency,
          times: m.times,
          startDate: m.startDate,
          endDate: m.endDate ?? null,
          instructions: m.instructions ?? null,
          source: 'clinician_verified',
          prescribedByName: doc?.name ?? req.ctx.user.name,
        });
      }
      if (!ep.ownerUserId) await tx.update(careEpisodes).set({ ownerUserId: req.ctx.user.id, updatedAt: new Date() }).where(eq(careEpisodes.id, ep.id));
      await addEvent(tx, ep.id, 'care_plan_created', 'Care plan created', req.ctx.actor, { carePlanId: p.id, supersedes: previous.map((x) => x.id) });
      await audit(tx, req.ctx.actor, { action: 'care_plan.create', entityType: 'care_plan', entityId: p.id, metadata: { careEpisodeId: ep.id } });
      return p;
    });
    await svc.notify.notifyPatient(ep.patientId, {
      template: 'care_plan',
      params: { doctor: doc?.name ?? 'Your doctor' },
      category: 'care_plan',
      deepLink: `/care-plans/${plan.id}`,
    });
    return reply.code(201).send((await toCarePlans(db, [plan], grace))[0]);
  });

  app.get('/care-plans/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [p] = await db.select().from(carePlans).where(eq(carePlans.id, id));
    if (!p) throw errors.notFound('Care plan');
    await assertCanActForPatient(db, req.ctx, p.patientId, READ, 'care_plan.read');
    return (await toCarePlans(db, [p], grace))[0];
  });

  app.get('/care-tasks', async (req) => {
    const q = parse(z.object({ patientId: zUuid, status: z.enum(['open', 'done', 'overdue']).optional() }), req.query);
    const page = pageFromQuery(req.query);
    await assertCanActForPatient(db, req.ctx, q.patientId, READ, 'care_task.list');
    const conds = [eq(careTasks.patientId, q.patientId)];
    if (q.status) conds.push(eq(careTasks.status, q.status));
    const rows = await db
      .select()
      .from(careTasks)
      .where(and(...conds))
      .orderBy(careTasks.dueAt)
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toCareTask), page);
  });

  app.post('/care-tasks/:id/complete', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ note: z.string().max(1000).optional() }), req.body);
    const [task] = await db.select().from(careTasks).where(eq(careTasks.id, id));
    if (!task) throw errors.notFound('Care task');
    await assertCanActForPatient(db, req.ctx, task.patientId, 'manage_care', 'care_task.complete');
    if (task.status === 'done') return toCareTask(task);
    if (task.status === 'cancelled') throw errors.invalidTransition('cancelled', 'done');
    const [plan] = await db.select().from(carePlans).where(eq(carePlans.id, task.carePlanId));
    const row = await db.transaction(async (tx) => {
      const [r] = await tx
        .update(careTasks)
        .set({ status: 'done', completedAt: new Date(), completedByUserId: req.ctx.user.id, completedByName: req.ctx.user.name, note: body.note ?? null })
        .where(eq(careTasks.id, id))
        .returning();
      if (plan) await addEvent(tx, plan.careEpisodeId, 'task_completed', `Task completed: ${task.title}`, req.ctx.actor, { taskId: id });
      await audit(tx, req.ctx.actor, { action: 'care_task.complete', entityType: 'care_task', entityId: id });
      return r;
    });
    return toCareTask(row);
  });

}

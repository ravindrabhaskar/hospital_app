import { and, count, desc, eq, gte, inArray, lt, max, sql } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { careEpisodes, carePlans, careTasks, contactLogs, doseLogs, medications, patients, safetyEvents, users } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, hasRole, type Actor } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray, envelope } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zIso, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import type { NotificationService } from '../notifications/service.js';
import { ACTIVE_STATUSES, addEvent, toCareEpisode, toCareEpisodes } from '../episodes/service.js';
import { toPatientSummary } from '../patients/service.js';

/** Contract section 35: care coordinator workspace. */
type ContactRow = typeof contactLogs.$inferSelect;
const COORDINATOR_VIEW = { relation: 'patient', isSelf: false, permissions: [] };

export const toContactLog = (c: ContactRow) => ({
  id: c.id,
  patientId: c.patientId,
  careEpisodeId: c.careEpisodeId,
  channel: c.channel,
  outcome: c.outcome,
  note: c.note,
  followUpAt: iso(c.followUpAt),
  coordinatorName: c.coordinatorName,
  createdAt: iso(c.createdAt),
});

export async function assignCoordinator(db: DbOrTx, episodeId: string, coordinatorUserId: string, actor: Actor): Promise<typeof careEpisodes.$inferSelect> {
  const [u] = await db.select({ name: users.name }).from(users).where(eq(users.id, coordinatorUserId));
  const [row] = await db.update(careEpisodes).set({ coordinatorUserId, updatedAt: new Date() }).where(eq(careEpisodes.id, episodeId)).returning();
  await addEvent(db, episodeId, 'coordinator_assigned', `Care coordinator assigned: ${u?.name ?? 'Care coordinator'}`, actor, { coordinatorUserId });
  await audit(db, actor, { action: 'episode.assign_coordinator', entityType: 'care_episode', entityId: episodeId, metadata: { coordinatorUserId } });
  return row;
}

/** Active coordinator with the fewest active assigned episodes (ties: oldest account), or null. */
export async function pickAvailableCoordinator(db: DbOrTx): Promise<string | null> {
  const coords = await db
    .select({ id: users.id, createdAt: users.createdAt })
    .from(users)
    .where(and(eq(users.status, 'active'), sql`${users.roles} @> '["coordinator"]'::jsonb`));
  if (!coords.length) return null;
  const load = await db
    .select({ id: careEpisodes.coordinatorUserId, n: count() })
    .from(careEpisodes)
    .where(and(inArray(careEpisodes.coordinatorUserId, coords.map((c) => c.id)), inArray(careEpisodes.status, ACTIVE_STATUSES)))
    .groupBy(careEpisodes.coordinatorUserId);
  const n = new Map(load.map((l) => [l.id, Number(l.n)]));
  coords.sort((a, b) => (n.get(a.id) ?? 0) - (n.get(b.id) ?? 0) || a.createdAt.getTime() - b.createdAt.getTime());
  return coords[0].id;
}

/** Family Care Plan benefit: assign a coordinator to every active, unassigned episode of the given patients. */
export async function autoAssignCoordinators(db: DbOrTx, patientIds: string[], notify: NotificationService | null): Promise<number> {
  if (!patientIds.length) return 0;
  const eps = await db
    .select()
    .from(careEpisodes)
    .where(and(inArray(careEpisodes.patientId, patientIds), inArray(careEpisodes.status, ACTIVE_STATUSES), sql`${careEpisodes.coordinatorUserId} is null`));
  let n = 0;
  for (const ep of eps) {
    const coordinatorId = await pickAvailableCoordinator(db);
    if (!coordinatorId) break;
    await assignCoordinator(db, ep.id, coordinatorId, { ...SYSTEM_ACTOR, name: 'care-plan-benefit' });
    n++;
    if (notify) {
      const [c] = await db.select({ name: users.name }).from(users).where(eq(users.id, coordinatorId));
      await notify.notifyPatient(ep.patientId, {
        template: 'coordinator_assigned',
        params: { coordinator: c?.name ?? 'A care coordinator' },
        category: 'system',
        deepLink: `/care-episodes/${ep.id}`,
        dedupeKey: `coordinator:${ep.id}:${coordinatorId}`,
      });
    }
  }
  return n;
}

export async function coordinatorRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const opsGuard = requireRoles(svc, 'coordinator', 'ops_admin', 'super_admin');

  app.post('/ops/care-episodes/:id/assign-coordinator', { preHandler: opsGuard }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ userId: zUuid }), req.body);
    const isAdmin = hasRole(req.ctx.user, 'ops_admin', 'super_admin');
    if (!isAdmin && body.userId !== req.ctx.user.id) {
      await audit(db, req.ctx.actor, { action: 'episode.assign_coordinator', entityType: 'care_episode', entityId: id, outcome: 'denied', metadata: { reason: 'not_self' } });
      throw errors.forbidden('Coordinators can only assign themselves');
    }
    const [ep] = await db.select().from(careEpisodes).where(eq(careEpisodes.id, id));
    if (!ep) throw errors.notFound('Care episode');
    const [target] = await db.select().from(users).where(eq(users.id, body.userId));
    if (!target || target.status !== 'active' || !target.roles.includes('coordinator')) throw errors.validation('userId must be an active user with the coordinator role');
    const row = await db.transaction((tx) => assignCoordinator(tx, id, body.userId, req.ctx.actor));
    return toCareEpisode(db, row);
  });

  app.get('/coordinator/caseload', { preHandler: requireRoles(svc, 'coordinator') }, async (req) => {
    const page = pageFromQuery(req.query);
    const eps = await db
      .select()
      .from(careEpisodes)
      .where(and(eq(careEpisodes.coordinatorUserId, req.ctx.user.id), inArray(careEpisodes.status, ACTIVE_STATUSES)))
      .orderBy(desc(careEpisodes.updatedAt));
    if (!eps.length) return { items: [], nextCursor: null };
    const pids = [...new Set(eps.map((e) => e.patientId))];
    const now = new Date();
    const weekAgo = new Date(now.getTime() - 7 * 86400_000);
    const [pats, tasks, contacts, followUps, plans, safety, missed, mapped] = await Promise.all([
      db.select().from(patients).where(inArray(patients.id, pids)),
      db.select({ patientId: careTasks.patientId, status: careTasks.status, dueAt: careTasks.dueAt }).from(careTasks).where(and(inArray(careTasks.patientId, pids), inArray(careTasks.status, ['open', 'overdue']))),
      db.select({ patientId: contactLogs.patientId, last: max(contactLogs.createdAt) }).from(contactLogs).where(inArray(contactLogs.patientId, pids)).groupBy(contactLogs.patientId),
      db.select({ patientId: contactLogs.patientId, at: contactLogs.followUpAt }).from(contactLogs).where(and(inArray(contactLogs.patientId, pids), gte(contactLogs.followUpAt, now))),
      db.select({ patientId: carePlans.patientId, at: carePlans.followUpDueAt }).from(carePlans).where(and(inArray(carePlans.patientId, pids), eq(carePlans.status, 'active'), gte(carePlans.followUpDueAt, now))),
      db.select({ patientId: safetyEvents.patientId }).from(safetyEvents).where(and(inArray(safetyEvents.patientId, pids), inArray(safetyEvents.status, ['open', 'acknowledged']))),
      db
        .selectDistinct({ patientId: medications.patientId })
        .from(doseLogs)
        .innerJoin(medications, eq(medications.id, doseLogs.medicationId))
        .where(and(inArray(medications.patientId, pids), eq(doseLogs.status, 'missed'), gte(doseLogs.scheduledAt, weekAgo), lt(doseLogs.scheduledAt, now))),
      toCareEpisodes(db, eps),
    ]);
    const lastContact = new Map(contacts.map((c) => [c.patientId, c.last ? new Date(c.last as unknown as string) : null]));
    const items = pats
      .map((p) => {
        const pt = tasks.filter((x) => x.patientId === p.id);
        const overdueTasks = pt.filter((x) => x.status === 'overdue' || (x.dueAt && x.dueAt < now)).length;
        const openTasks = pt.filter((x) => x.status === 'open').length;
        const next = [...followUps.filter((f) => f.patientId === p.id).map((f) => f.at), ...plans.filter((f) => f.patientId === p.id).map((f) => f.at)]
          .filter((d): d is Date => !!d)
          .sort((a, b) => a.getTime() - b.getTime())[0];
        const last = lastContact.get(p.id) ?? null;
        const flags: string[] = [];
        if (overdueTasks > 0) flags.push('overdue_tasks');
        if (missed.some((m) => m.patientId === p.id)) flags.push('missed_doses');
        if (safety.some((s) => s.patientId === p.id)) flags.push('open_safety_event');
        if (!last || last < weekAgo) flags.push('no_contact_7d');
        return {
          patient: toPatientSummary(p, COORDINATOR_VIEW),
          episodes: mapped.filter((e) => e.patientId === p.id),
          openTasks,
          overdueTasks,
          nextFollowUpAt: iso(next ?? null),
          lastContactAt: iso(last),
          flags,
        };
      })
      .sort((a, b) => b.flags.length - a.flags.length || a.patient.name.localeCompare(b.patient.name));
    return paginateArray(items, page);
  });

  app.post('/coordinator/contacts', { preHandler: opsGuard }, async (req, reply) => {
    const body = parse(
      z.object({
        patientId: zUuid,
        careEpisodeId: zUuid.optional(),
        channel: z.enum(['call', 'whatsapp', 'sms', 'home_visit', 'in_app']),
        outcome: z.enum(['reached', 'no_answer', 'callback_requested', 'escalated']),
        note: z.string().trim().min(1).max(2000),
        followUpAt: zIso.optional(),
      }),
      req.body,
    );
    const [p] = await db.select({ id: patients.id }).from(patients).where(eq(patients.id, body.patientId));
    if (!p) throw errors.notFound('Patient');
    if (body.careEpisodeId) {
      const [ep] = await db.select({ patientId: careEpisodes.patientId }).from(careEpisodes).where(eq(careEpisodes.id, body.careEpisodeId));
      if (!ep || ep.patientId !== body.patientId) throw errors.validation('careEpisodeId does not belong to this patient', { field: 'careEpisodeId' });
    }
    const row = await db.transaction(async (tx) => {
      const [c] = await tx
        .insert(contactLogs)
        .values({
          patientId: body.patientId,
          careEpisodeId: body.careEpisodeId ?? null,
          coordinatorUserId: req.ctx.user.id,
          coordinatorName: req.ctx.user.name ?? 'Care coordinator',
          channel: body.channel,
          outcome: body.outcome,
          note: body.note,
          followUpAt: body.followUpAt ? new Date(body.followUpAt) : null,
        })
        .returning();
      if (body.careEpisodeId) {
        await addEvent(tx, body.careEpisodeId, 'coordinator_contact', `Coordinator contact (${body.channel}): ${body.outcome.replace('_', ' ')}`, req.ctx.actor, {
          contactLogId: c.id,
          channel: body.channel,
          outcome: body.outcome,
        });
      }
      await audit(tx, req.ctx.actor, { action: 'coordinator.contact', entityType: 'patient', entityId: body.patientId, metadata: { channel: body.channel, outcome: body.outcome } });
      return c;
    });
    return reply.code(201).send(toContactLog(row));
  });

  app.get('/coordinator/contacts', { preHandler: opsGuard }, async (req) => {
    const q = parse(z.object({ patientId: zUuid.optional() }), req.query);
    const page = pageFromQuery(req.query);
    if (q.patientId) await assertCanActForPatient(db, req.ctx, q.patientId, 'staff_ops', 'coordinator.contacts');
    const rows = await db
      .select()
      .from(contactLogs)
      .where(q.patientId ? eq(contactLogs.patientId, q.patientId) : eq(contactLogs.coordinatorUserId, req.ctx.user.id))
      .orderBy(desc(contactLogs.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toContactLog), page);
  });
}

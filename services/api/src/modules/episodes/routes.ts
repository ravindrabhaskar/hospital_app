import { and, asc, desc, eq, inArray } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { appointments, careEpisodes, carePlans, episodeEvents, homeVisits, safetyEvents } from '../../db/schema.js';
import { assertCanActForPatient, listActablePatients, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { parse, zBoolQuery, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { toAppointments } from '../appointments/service.js';
import { toCarePlans } from '../careplans/service.js';
import { toHomeVisits, visitViewFor } from '../homevisits/service.js';
import { toSafetyEvents } from '../safety/service.js';
import { ACTIVE_STATUSES, EPISODE_STATUSES, addEvent, createEpisode, toCareEpisode, toCareEpisodes, toEvent, transitionEpisode } from './service.js';

const READ: Perm[] = ['view_records', 'manage_care', 'staff_ops'];

export async function episodeRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/care-episodes', async (req) => {
    const q = parse(
      z.object({ patientId: zUuid.optional(), status: z.enum(EPISODE_STATUSES).optional(), active: zBoolQuery.optional() }),
      req.query,
    );
    const page = pageFromQuery(req.query);
    let patientIds: string[];
    if (q.patientId) {
      await assertCanActForPatient(db, req.ctx, q.patientId, READ, 'episode.list');
      patientIds = [q.patientId];
    } else {
      patientIds = (await listActablePatients(db, req.ctx.user))
        .filter((p) => p.permissions.includes('view_records') || p.permissions.includes('manage_care'))
        .map((p) => p.patientId);
    }
    if (!patientIds.length) return { items: [], nextCursor: null };
    const conds = [inArray(careEpisodes.patientId, patientIds)];
    if (q.status) conds.push(eq(careEpisodes.status, q.status));
    if (q.active) conds.push(inArray(careEpisodes.status, ACTIVE_STATUSES));
    const rows = await db
      .select()
      .from(careEpisodes)
      .where(and(...conds))
      .orderBy(desc(careEpisodes.updatedAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toCareEpisodes(db, rows), page);
  });

  app.post('/care-episodes', { config: { idempotent: true } }, async (req, reply) => {
    const body = parse(
      z.object({ patientId: zUuid, title: z.string().trim().min(1).max(200), concern: z.string().trim().min(1).max(2000) }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, body.patientId, 'manage_care', 'episode.create');
    const row = await db.transaction((tx) => createEpisode(tx, { ...body, actor: req.ctx.actor }));
    return reply.code(201).send(await toCareEpisode(db, row));
  });

  app.get('/care-episodes/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [ep] = await db.select().from(careEpisodes).where(eq(careEpisodes.id, id));
    if (!ep) throw errors.notFound('Care episode');
    await assertCanActForPatient(db, req.ctx, ep.patientId, READ, 'episode.read');
    const [events, appts, visits, plans, safety] = await Promise.all([
      db.select().from(episodeEvents).where(eq(episodeEvents.episodeId, id)).orderBy(asc(episodeEvents.createdAt)),
      db.select().from(appointments).where(eq(appointments.careEpisodeId, id)).orderBy(desc(appointments.startAt)),
      db.select().from(homeVisits).where(eq(homeVisits.careEpisodeId, id)).orderBy(desc(homeVisits.preferredStart)),
      db.select().from(carePlans).where(eq(carePlans.careEpisodeId, id)).orderBy(desc(carePlans.createdAt)),
      db.select().from(safetyEvents).where(eq(safetyEvents.careEpisodeId, id)).orderBy(desc(safetyEvents.createdAt)),
    ]);
    const views = new Map<string, Awaited<ReturnType<typeof visitViewFor>>>();
    for (const v of visits) views.set(v.id, await visitViewFor(db, req.ctx, v));
    await audit(db, req.ctx.actor, { action: 'episode.read', entityType: 'care_episode', entityId: id });
    return {
      ...(await toCareEpisode(db, ep)),
      events: events.map(toEvent),
      appointments: await toAppointments(db, appts),
      homeVisits: await toHomeVisits(db, visits, (v) => views.get(v.id) ?? 'ops'),
      carePlans: await toCarePlans(db, plans, svc.config.DOSE_MISSED_GRACE_MIN),
      safetyEvents: await toSafetyEvents(db, safety),
    };
  });

  app.post('/care-episodes/:id/transition', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ to: z.enum(EPISODE_STATUSES), reason: z.string().trim().min(1).max(500) }), req.body);
    const [ep] = await db.select().from(careEpisodes).where(eq(careEpisodes.id, id));
    if (!ep) throw errors.notFound('Care episode');
    await assertCanActForPatient(db, req.ctx, ep.patientId, ['manage_care', 'staff_ops'], 'episode.transition');
    const extra = body.to === 'EMERGENCY' ? { priority: 'emergency' } : body.to === 'ESCALATED' && ep.priority === 'routine' ? { priority: 'urgent' } : {};
    const row = await db.transaction((tx) => transitionEpisode(tx, id, body.to, body.reason, req.ctx.actor, req.ctx.user.roles, extra));
    return toCareEpisode(db, row);
  });

  app.post('/care-episodes/:id/notes', { preHandler: requireRoles(svc, 'doctor') }, async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ text: z.string().trim().min(1).max(8000) }), req.body);
    const [ep] = await db.select().from(careEpisodes).where(eq(careEpisodes.id, id));
    if (!ep) throw errors.notFound('Care episode');
    await assertCanActForPatient(db, req.ctx, ep.patientId, 'manage_care', 'episode.note');
    const ev = await db.transaction(async (tx) => {
      const e = await addEvent(tx, id, 'note_added', 'Clinician note added', req.ctx.actor, { text: body.text });
      await audit(tx, req.ctx.actor, { action: 'episode.note', entityType: 'care_episode', entityId: id });
      return e;
    });
    return reply.code(201).send(toEvent(ev));
  });
}

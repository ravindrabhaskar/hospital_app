import { and, count, desc, eq, gte, inArray, lt, sql } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import {
  appointments,
  careEpisodes,
  careTasks,
  episodeEvents,
  homeVisits,
  incidents,
  patients,
  payments,
  providers,
  safetyEvents,
  users,
} from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { envelope, pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { istDate, istDayBounds, iso, median, minutesBetween } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { ACTIVE_STATUSES, EPISODE_STATUSES, toCareEpisodes, toEvent } from '../episodes/service.js';
import { LIVE_PROVIDER_STATUSES, toHomeVisits, type HomeVisitRow } from '../homevisits/service.js';
import { toCareTask } from '../careplans/service.js';
import { toPaymentsWithPatient } from '../payments/service.js';
import { effectiveVerificationStatus, providerZonesOf } from '../provider-app/routes.js';
import { toSafetyEvents } from '../safety/service.js';

type IncidentRow = typeof incidents.$inferSelect;

const toIncident = async (db: DbOrTx, rows: IncidentRow[]) => {
  const ids = [...new Set(rows.map((r) => r.patientId).filter((x): x is string => !!x))];
  const ps = ids.length ? await db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, ids)) : [];
  const pm = new Map(ps.map((p) => [p.id, p.name]));
  return rows.map((i) => ({
    id: i.id,
    type: i.type,
    title: i.title,
    description: i.description,
    severity: i.severity,
    status: i.status,
    patientId: i.patientId,
    patientName: i.patientId ? (pm.get(i.patientId) ?? null) : null,
    reportedByName: i.reportedByName,
    notes: i.notes,
    createdAt: iso(i.createdAt),
    updatedAt: iso(i.updatedAt),
  }));
};

export function slaBreached(v: HomeVisitRow, slaMin: number, now = new Date()): boolean {
  if (v.slaBreachedAt) return true;
  return ['requested', 'unassigned'].includes(v.status) && minutesBetween(v.createdAt, now) > slaMin;
}

export async function opsProviders(db: DbOrTx, rows: Array<typeof providers.$inferSelect>) {
  const { start, end } = istDayBounds(istDate());
  const out = [];
  for (const p of rows) {
    const [u] = await db.select({ phone: users.phone }).from(users).where(eq(users.id, p.userId));
    const active = await db
      .select({ id: homeVisits.id, status: homeVisits.status })
      .from(homeVisits)
      .where(and(eq(homeVisits.providerId, p.id), inArray(homeVisits.status, ['en_route', 'arrived', 'in_progress', 'escalated'])))
      .limit(1);
    const [today] = await db
      .select({ n: count() })
      .from(homeVisits)
      .where(and(eq(homeVisits.providerId, p.id), gte(homeVisits.preferredStart, start), lt(homeVisits.preferredStart, end)));
    out.push({
      id: p.id,
      name: p.name,
      type: p.type,
      phone: u?.phone ?? '',
      qualification: p.qualification,
      verificationStatus: effectiveVerificationStatus(p),
      credentialExpiresAt: iso(p.credentialExpiresAt),
      onDuty: p.onDuty,
      status: active.length ? 'on_visit' : p.onDuty ? 'available' : 'offline',
      activeVisitId: active[0]?.id ?? null,
      zones: (await providerZonesOf(db, p.id)).map((z) => z.name),
      visitsToday: Number(today?.n ?? 0),
      rating: p.rating,
    });
  }
  return out;
}

export async function opsRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const sla = svc.config.VISIT_ASSIGN_SLA_MIN;
  app.addHook('preHandler', requireRoles(svc, 'coordinator', 'ops_admin', 'super_admin'));

  app.get('/ops/overview', async () => {
    const now = new Date();
    const { start, end } = istDayBounds(istDate());
    const n = async (q: Promise<Array<{ n: number }>>) => Number((await q)[0]?.n ?? 0);
    const counts = {
      activeEpisodes: await n(db.select({ n: count() }).from(careEpisodes).where(inArray(careEpisodes.status, ACTIVE_STATUSES))),
      openSafetyEvents: await n(db.select({ n: count() }).from(safetyEvents).where(eq(safetyEvents.status, 'open'))),
      unassignedVisits: await n(db.select({ n: count() }).from(homeVisits).where(inArray(homeVisits.status, ['requested', 'unassigned']))),
      lateVisits: await n(
        db
          .select({ n: count() })
          .from(homeVisits)
          .where(and(inArray(homeVisits.status, ['requested', 'unassigned', 'assigned', 'accepted', 'en_route']), lt(homeVisits.preferredEnd, now))),
      ),
      activeVisits: await n(db.select({ n: count() }).from(homeVisits).where(inArray(homeVisits.status, LIVE_PROVIDER_STATUSES))),
      overdueTasks: await n(db.select({ n: count() }).from(careTasks).where(eq(careTasks.status, 'overdue'))),
      todaysAppointments: await n(
        db
          .select({ n: count() })
          .from(appointments)
          .where(and(gte(appointments.startAt, start), lt(appointments.startAt, end), sql`${appointments.status} <> 'cancelled'`)),
      ),
      pendingPayments: await n(db.select({ n: count() }).from(payments).where(eq(payments.status, 'pending'))),
      openIncidents: await n(db.select({ n: count() }).from(incidents).where(inArray(incidents.status, ['open', 'investigating']))),
      providersOnDuty: await n(db.select({ n: count() }).from(providers).where(and(eq(providers.kind, 'field'), eq(providers.onDuty, true)))),
    };
    const since = new Date(now.getTime() - 30 * 86400_000);
    const visits = await db.select().from(homeVisits).where(gte(homeVisits.createdAt, since));
    const assignMins = visits.filter((v) => v.assignedAt).map((v) => minutesBetween(v.createdAt, v.assignedAt!));
    const arrived = visits.filter((v) => v.arrivedAt);
    const safety = await db.select().from(safetyEvents).where(gte(safetyEvents.createdAt, since));
    const ackMins = safety.filter((s) => s.acknowledgedAt).map((s) => minutesBetween(s.createdAt, s.acknowledgedAt!));
    const recent = await db.select().from(episodeEvents).orderBy(desc(episodeEvents.createdAt)).limit(20);
    return {
      counts,
      sla: {
        visitAssignmentMedianMins: median(assignMins),
        visitOnTimeRate: arrived.length ? Math.round((arrived.filter((v) => v.arrivedAt! <= v.preferredEnd).length / arrived.length) * 100) / 100 : null,
        safetyAckMedianMins: median(ackMins),
      },
      recentEvents: recent.map(toEvent),
    };
  });

  app.get('/ops/home-visits', async (req) => {
    const q = parse(z.object({ status: z.string().max(30).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db
      .select()
      .from(homeVisits)
      .where(q.status ? eq(homeVisits.status, q.status) : undefined)
      .orderBy(desc(homeVisits.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    const mapped = await toHomeVisits(db, rows, () => 'ops');
    const now = new Date();
    return envelope(
      mapped.map((m, i) => ({ ...m, slaBreached: slaBreached(rows[i], sla, now) })),
      page,
    );
  });

  app.get('/ops/providers', async (req) => {
    const q = parse(z.object({ status: z.string().max(30).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(providers).where(eq(providers.kind, 'field')).orderBy(providers.name);
    let items = await opsProviders(db, rows);
    if (q.status) items = items.filter((p) => p.status === q.status || p.verificationStatus === q.status);
    return paginateArray(items, page);
  });

  app.post('/ops/providers/:id/verification', { preHandler: requireRoles(svc, 'ops_admin', 'super_admin') }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ status: z.enum(['verified', 'rejected', 'suspended']), note: z.string().max(1000) }), req.body);
    const [p] = await db.select().from(providers).where(eq(providers.id, id));
    if (!p) throw errors.notFound('Provider');
    if (body.status === 'verified' && p.credentialExpiresAt <= new Date()) {
      throw errors.conflict('Credential has expired; update credentialExpiresAt before verifying');
    }
    const [row] = await db
      .update(providers)
      .set({ verificationStatus: body.status, verificationNote: body.note, ...(body.status !== 'verified' ? { onDuty: false } : {}) })
      .where(eq(providers.id, id))
      .returning();
    await audit(db, req.ctx.actor, { action: 'provider.verification', entityType: 'provider', entityId: id, metadata: { status: body.status } });
    return (await opsProviders(db, [row]))[0];
  });

  app.get('/ops/safety-events', async (req) => {
    const q = parse(z.object({ status: z.enum(['open', 'acknowledged', 'resolved']).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db
      .select()
      .from(safetyEvents)
      .where(q.status ? eq(safetyEvents.status, q.status) : undefined)
      .orderBy(desc(safetyEvents.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toSafetyEvents(db, rows), page);
  });

  app.post('/ops/safety-events/:id/acknowledge', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [e] = await db.select().from(safetyEvents).where(eq(safetyEvents.id, id));
    if (!e) throw errors.notFound('Safety event');
    if (e.status !== 'open') throw errors.invalidTransition(e.status, 'acknowledged');
    const [row] = await db
      .update(safetyEvents)
      .set({ status: 'acknowledged', acknowledgedAt: new Date(), assignedToUserId: req.ctx.user.id, assignedToName: req.ctx.user.name })
      .where(eq(safetyEvents.id, id))
      .returning();
    await audit(db, req.ctx.actor, { action: 'safety_event.acknowledge', entityType: 'safety_event', entityId: id });
    return (await toSafetyEvents(db, [row]))[0];
  });

  app.post('/ops/safety-events/:id/resolve', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ note: z.string().trim().min(1).max(2000) }), req.body);
    const [e] = await db.select().from(safetyEvents).where(eq(safetyEvents.id, id));
    if (!e) throw errors.notFound('Safety event');
    if (e.status === 'resolved') throw errors.invalidTransition(e.status, 'resolved');
    const [row] = await db
      .update(safetyEvents)
      .set({
        status: 'resolved',
        resolvedAt: new Date(),
        note: body.note,
        acknowledgedAt: e.acknowledgedAt ?? new Date(),
        assignedToUserId: e.assignedToUserId ?? req.ctx.user.id,
        assignedToName: e.assignedToName ?? req.ctx.user.name,
      })
      .where(eq(safetyEvents.id, id))
      .returning();
    await audit(db, req.ctx.actor, { action: 'safety_event.resolve', entityType: 'safety_event', entityId: id });
    return (await toSafetyEvents(db, [row]))[0];
  });

  app.get('/ops/care-episodes', async (req) => {
    const q = parse(z.object({ status: z.enum(EPISODE_STATUSES).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db
      .select()
      .from(careEpisodes)
      .where(q.status ? eq(careEpisodes.status, q.status) : undefined)
      .orderBy(desc(careEpisodes.updatedAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toCareEpisodes(db, rows), page);
  });

  app.get('/ops/overdue-tasks', async (req) => {
    const page = pageFromQuery(req.query);
    const rows = await db
      .select({ t: careTasks, patientName: patients.name })
      .from(careTasks)
      .innerJoin(patients, eq(patients.id, careTasks.patientId))
      .where(eq(careTasks.status, 'overdue'))
      .orderBy(careTasks.dueAt)
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(
      rows.map((r) => ({ ...toCareTask(r.t), patientName: r.patientName })),
      page,
    );
  });

  app.get('/ops/incidents', async (req) => {
    const q = parse(z.object({ status: z.enum(['open', 'investigating', 'resolved', 'closed']).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db
      .select()
      .from(incidents)
      .where(q.status ? eq(incidents.status, q.status) : undefined)
      .orderBy(desc(incidents.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toIncident(db, rows), page);
  });

  app.post('/ops/incidents', async (req, reply) => {
    const body = parse(
      z.object({
        type: z.enum(['complaint', 'incident', 'clinical_incident']),
        title: z.string().trim().min(1).max(200),
        description: z.string().trim().min(1).max(4000),
        severity: z.enum(['low', 'medium', 'high', 'critical']),
        patientId: zUuid.optional(),
        refType: z.string().max(40).optional(),
        refId: z.string().max(100).optional(),
      }),
      req.body,
    );
    const [row] = await db
      .insert(incidents)
      .values({
        ...body,
        patientId: body.patientId ?? null,
        refType: body.refType ?? null,
        refId: body.refId ?? null,
        reportedByUserId: req.ctx.user.id,
        reportedByName: req.ctx.user.name ?? 'Operations',
      })
      .returning();
    await audit(db, req.ctx.actor, { action: 'incident.create', entityType: 'incident', entityId: row.id, metadata: { severity: body.severity } });
    return reply.code(201).send((await toIncident(db, [row]))[0]);
  });

  app.patch('/ops/incidents/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ status: z.enum(['open', 'investigating', 'resolved', 'closed']).optional(), note: z.string().trim().min(1).max(2000).optional() }), req.body);
    const [i] = await db.select().from(incidents).where(eq(incidents.id, id));
    if (!i) throw errors.notFound('Incident');
    const notes = body.note ? [...i.notes, { text: body.note, authorName: req.ctx.user.name ?? 'Operations', at: new Date().toISOString() }] : i.notes;
    const [row] = await db
      .update(incidents)
      .set({ status: body.status ?? i.status, notes, updatedAt: new Date() })
      .where(eq(incidents.id, id))
      .returning();
    await audit(db, req.ctx.actor, { action: 'incident.update', entityType: 'incident', entityId: id, metadata: { status: row.status } });
    return (await toIncident(db, [row]))[0];
  });

  app.get('/ops/payments', async (req) => {
    const q = parse(z.object({ status: z.string().max(30).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db
      .select()
      .from(payments)
      .where(q.status ? eq(payments.status, q.status) : undefined)
      .orderBy(desc(payments.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toPaymentsWithPatient(db, rows), page);
  });
}

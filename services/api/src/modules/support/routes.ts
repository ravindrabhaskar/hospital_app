import { and, asc, count, desc, eq, inArray, isNotNull, isNull, lte, sql } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { medicalRecords, supportTickets, ticketMessages, users } from '../../db/schema.js';
import { resolvePatientAccess } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { SUPPORT_ROLES, SYSTEM_ACTOR, hasRole, type Actor } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import type { Services } from '../../services.js';
import { raiseAlert, usersWithRoles } from '../safety/alerts.js';

/** Contract section 61: support desk. Internal notes are never returned to customers. */
type TicketRow = typeof supportTickets.$inferSelect;
export const CATEGORIES = ['booking', 'payment', 'refund', 'app_issue', 'clinical_concern', 'other'] as const;
const PRIORITIES = ['low', 'normal', 'high', 'urgent'] as const;
export const ticketNumber = (seq: number) => `T-${String(seq).padStart(6, '0')}`;
export const slaMinutes = (priority: string) => (priority === 'urgent' || priority === 'high' ? 30 : 240);

export async function toTickets(db: DbOrTx, rows: TicketRow[], view: 'customer' | 'agent') {
  if (!rows.length) return [];
  const ids = rows.map((r) => r.id);
  const msgs = await db
    .select()
    .from(ticketMessages)
    .where(view === 'agent' ? inArray(ticketMessages.ticketId, ids) : and(inArray(ticketMessages.ticketId, ids), eq(ticketMessages.internal, false)))
    .orderBy(asc(ticketMessages.createdAt));
  const uids = [...new Set(rows.flatMap((r) => [r.userId, r.assignedToUserId]).filter((x): x is string => !!x))];
  const us = uids.length ? await db.select({ id: users.id, name: users.name }).from(users).where(inArray(users.id, uids)) : [];
  const um = new Map(us.map((u) => [u.id, u.name]));
  return rows.map((t) => ({
    id: t.id,
    number: ticketNumber(t.seq),
    userId: t.userId,
    userName: um.get(t.userId) ?? null,
    subject: t.subject,
    category: t.category,
    status: t.status,
    priority: t.priority,
    assignedToName: t.assignedToUserId ? (um.get(t.assignedToUserId) ?? null) : null,
    refType: t.refType,
    refId: t.refId,
    messages: msgs.filter((m) => m.ticketId === t.id).map(toMessage),
    rating: t.ratingScore ? { score: t.ratingScore, comment: t.ratingComment } : null,
    slaDueAt: iso(t.slaDueAt),
    createdAt: iso(t.createdAt),
    updatedAt: iso(t.updatedAt),
  }));
}

const toMessage = (m: typeof ticketMessages.$inferSelect) => ({
  id: m.id,
  ticketId: m.ticketId,
  authorName: m.authorName,
  authorRole: m.authorRole,
  text: m.text,
  internal: m.internal,
  at: iso(m.createdAt),
});

/**
 * Create a ticket (app, IVR call-back, etc.). `clinical_concern` tickets also open a SafetyEvent review (never handled
 * by support alone); the safety engine runs on the text and an emergency is raised as such.
 */
export async function createTicket(
  svc: Services,
  p: { userId: string; userName: string | null; patientId: string | null; subject: string; category: (typeof CATEGORIES)[number]; message: string; refType?: string | null; refId?: string | null; attachmentRecordId?: string | null; priority?: (typeof PRIORITIES)[number]; source?: 'app' | 'ivr' | 'whatsapp'; actor: Actor },
): Promise<TicketRow> {
  const now = new Date();
  let priority = p.priority ?? (p.category === 'clinical_concern' ? 'high' : 'normal');
  let safety: Awaited<ReturnType<Services['safety']['evaluate']>> | null = null;
  if (p.category === 'clinical_concern') {
    safety = await svc.safety.evaluate({ text: `${p.subject}. ${p.message}` });
    if (safety.level === 'emergency') priority = 'urgent';
  }
  const ticket = await svc.db.transaction(async (tx) => {
    const [t] = await tx
      .insert(supportTickets)
      .values({
        userId: p.userId,
        subject: p.subject,
        category: p.category,
        priority,
        refType: p.refType ?? null,
        refId: p.refId ?? null,
        attachmentRecordId: p.attachmentRecordId ?? null,
        patientId: p.patientId,
        slaDueAt: new Date(now.getTime() + slaMinutes(priority) * 60_000),
        source: p.source ?? 'app',
      })
      .returning();
    await tx.insert(ticketMessages).values({ ticketId: t.id, authorUserId: p.userId, authorName: p.userName ?? 'Customer', authorRole: 'customer', text: p.message });
    await audit(tx, p.actor, { action: 'support.ticket_create', entityType: 'support_ticket', entityId: t.id, metadata: { category: p.category, priority } });
    return t;
  });
  if (p.category === 'clinical_concern' && p.patientId) {
    const event = await raiseAlert(svc, {
      patientId: p.patientId,
      level: safety?.level === 'emergency' ? 'emergency' : 'urgent',
      source: 'message',
      rules: safety?.triggeredRules.length ? safety.triggeredRules : [{ ruleId: 'support.clinical_concern', title: 'Clinical concern raised via support' }],
      note: `Support ticket ${ticketNumber(ticket.seq)}: clinical review required`,
      notifyFamily: safety?.level === 'emergency',
    });
    await svc.db.update(supportTickets).set({ safetyEventId: event.id }).where(eq(supportTickets.id, ticket.id));
    await svc.db.insert(ticketMessages).values({
      ticketId: ticket.id,
      authorName: 'CareCompanion',
      authorRole: 'system',
      text: 'A clinician will review this concern. If this is an emergency, call 108 now.',
    });
  }
  await svc.notify.notifyUsers(await usersWithRoles(svc.db, ['support_agent']), {
    template: 'support_new',
    params: { number: ticketNumber(ticket.seq), priority },
    category: 'support',
    deepLink: `/ops/support/tickets/${ticket.id}`,
    dedupeKey: `support_new:${ticket.id}`,
  });
  const [fresh] = await svc.db.select().from(supportTickets).where(eq(supportTickets.id, ticket.id));
  return fresh;
}

/** Worker: first-response SLA breach alerts ops (once per ticket). */
export async function supportSla(svc: Services, now: Date): Promise<number> {
  const due = await svc.db
    .update(supportTickets)
    .set({ slaBreachedAt: now })
    .where(and(isNull(supportTickets.firstResponseAt), isNull(supportTickets.slaBreachedAt), lte(supportTickets.slaDueAt, now), inArray(supportTickets.status, ['open', 'pending_customer'])))
    .returning();
  if (!due.length) return 0;
  const ops = await usersWithRoles(svc.db, ['support_agent', 'ops_admin']);
  for (const t of due) {
    await svc.notify.notifyUsers(ops, { template: 'support_sla', params: { number: ticketNumber(t.seq) }, category: 'support', deepLink: `/ops/support/tickets/${t.id}`, dedupeKey: `support_sla:${t.id}` });
    await audit(svc.db, SYSTEM_ACTOR, { action: 'support.sla_breach', entityType: 'support_ticket', entityId: t.id });
  }
  return due.length;
}

export async function supportRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const agentOnly = requireRoles(svc, ...SUPPORT_ROLES);
  const isAgent = (req: FastifyRequest) => hasRole(req.ctx.user, ...SUPPORT_ROLES);

  const load = async (id: string) => {
    const [t] = await db.select().from(supportTickets).where(eq(supportTickets.id, id));
    if (!t) throw errors.notFound('Ticket');
    return t;
  };
  const loadOwn = async (req: FastifyRequest, id: string, action: string) => {
    const t = await load(id);
    if (t.userId !== req.ctx.user.id) {
      await audit(db, req.ctx.actor, { action, entityType: 'support_ticket', entityId: id, outcome: 'denied' });
      throw errors.notFound('Ticket');
    }
    return t;
  };

  app.post('/support/tickets', async (req, reply) => {
    const body = parse(
      z.object({
        subject: z.string().trim().min(3).max(200),
        category: z.enum(CATEGORIES),
        message: z.string().trim().min(1).max(4000),
        refType: z.string().max(40).optional(),
        refId: z.string().max(100).optional(),
        attachmentRecordId: zUuid.optional(),
      }),
      req.body,
    );
    if (body.attachmentRecordId) {
      const [r] = await db.select({ patientId: medicalRecords.patientId }).from(medicalRecords).where(eq(medicalRecords.id, body.attachmentRecordId));
      const access = r ? await resolvePatientAccess(db, req.ctx.user, r.patientId) : null;
      if (!access || !access.permissions.has('view_records')) throw errors.validation('attachmentRecordId must be one of your records', { field: 'attachmentRecordId' });
    }
    const t = await createTicket(svc, { userId: req.ctx.user.id, userName: req.ctx.user.name, patientId: req.ctx.user.selfPatientId, ...body, actor: req.ctx.actor });
    return reply.code(201).send((await toTickets(db, [t], 'customer'))[0]);
  });

  app.get('/support/tickets', async (req) => {
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(supportTickets).where(eq(supportTickets.userId, req.ctx.user.id)).orderBy(desc(supportTickets.createdAt));
    return paginateArray(await toTickets(db, rows, 'customer'), page);
  });

  app.get('/support/tickets/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const t = await load(id);
    if (t.userId === req.ctx.user.id) return (await toTickets(db, [t], 'customer'))[0];
    if (isAgent(req)) return (await toTickets(db, [t], 'agent'))[0];
    await audit(db, req.ctx.actor, { action: 'support.ticket_read', entityType: 'support_ticket', entityId: id, outcome: 'denied' });
    throw errors.notFound('Ticket');
  });

  app.post('/support/tickets/:id/messages', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ text: z.string().trim().min(1).max(4000) }), req.body);
    const t = await loadOwn(req, id, 'support.message');
    if (t.status === 'closed') throw errors.conflict('This ticket is closed; please open a new one');
    const [m] = await db.insert(ticketMessages).values({ ticketId: id, authorUserId: req.ctx.user.id, authorName: req.ctx.user.name ?? 'Customer', authorRole: 'customer', text: body.text }).returning();
    await db.update(supportTickets).set({ status: t.status === 'pending_customer' || t.status === 'resolved' ? 'open' : t.status, updatedAt: new Date() }).where(eq(supportTickets.id, id));
    await audit(db, req.ctx.actor, { action: 'support.message', entityType: 'support_ticket', entityId: id });
    return reply.code(201).send(toMessage(m));
  });

  app.post('/support/tickets/:id/rating', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ score: z.number().int().min(1).max(5), comment: z.string().trim().max(1000).optional() }), req.body);
    const t = await loadOwn(req, id, 'support.rating');
    if (t.status !== 'resolved' && t.status !== 'closed') throw errors.conflict('Tickets can be rated after they are resolved', { status: t.status });
    const [row] = await db.update(supportTickets).set({ ratingScore: body.score, ratingComment: body.comment ?? null, updatedAt: new Date() }).where(eq(supportTickets.id, id)).returning();
    await audit(db, req.ctx.actor, { action: 'support.rating', entityType: 'support_ticket', entityId: id, metadata: { score: body.score } });
    return (await toTickets(db, [row], 'customer'))[0];
  });

  // ---------------------------------------------------------------- agent side
  app.get('/ops/support/tickets', { preHandler: agentOnly }, async (req) => {
    const q = parse(z.object({ status: z.enum(['open', 'pending_customer', 'resolved', 'closed']).optional(), assignedTo: z.literal('me').optional() }), req.query);
    const page = pageFromQuery(req.query);
    const conds = [];
    if (q.status) conds.push(eq(supportTickets.status, q.status));
    if (q.assignedTo === 'me') conds.push(eq(supportTickets.assignedToUserId, req.ctx.user.id));
    const rows = await db.select().from(supportTickets).where(conds.length ? and(...conds) : undefined).orderBy(asc(supportTickets.slaDueAt));
    return paginateArray(await toTickets(db, rows, 'agent'), page);
  });

  app.post('/ops/support/tickets/:id/assign', { preHandler: agentOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ userId: zUuid }), req.body);
    await load(id);
    const [u] = await db.select({ roles: users.roles, status: users.status }).from(users).where(eq(users.id, body.userId));
    if (!u || u.status !== 'active' || !hasRole({ roles: u.roles }, ...SUPPORT_ROLES)) throw errors.validation('The assignee must be an active support agent, coordinator or ops admin', { field: 'userId' });
    const [row] = await db.update(supportTickets).set({ assignedToUserId: body.userId, updatedAt: new Date() }).where(eq(supportTickets.id, id)).returning();
    await audit(db, req.ctx.actor, { action: 'support.assign', entityType: 'support_ticket', entityId: id, metadata: { assignee: body.userId } });
    return (await toTickets(db, [row], 'agent'))[0];
  });

  app.post('/ops/support/tickets/:id/reply', { preHandler: agentOnly }, async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ text: z.string().trim().min(1).max(4000), internal: z.boolean().optional() }), req.body);
    const t = await load(id);
    const internal = body.internal ?? false;
    const [m] = await db.insert(ticketMessages).values({ ticketId: id, authorUserId: req.ctx.user.id, authorName: req.ctx.user.name ?? 'Support', authorRole: 'agent', text: body.text, internal }).returning();
    if (!internal) {
      await db
        .update(supportTickets)
        .set({ firstResponseAt: t.firstResponseAt ?? new Date(), status: t.status === 'open' ? 'pending_customer' : t.status, assignedToUserId: t.assignedToUserId ?? req.ctx.user.id, updatedAt: new Date() })
        .where(eq(supportTickets.id, id));
      await svc.notify.notifyUsers([t.userId], { template: 'support_reply', params: { number: ticketNumber(t.seq) }, category: 'support', deepLink: `/support/tickets/${id}`, dedupeKey: `support_reply:${m.id}` });
    }
    await audit(db, req.ctx.actor, { action: internal ? 'support.internal_note' : 'support.reply', entityType: 'support_ticket', entityId: id });
    return reply.code(201).send(toMessage(m));
  });

  app.patch('/ops/support/tickets/:id', { preHandler: agentOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ status: z.enum(['open', 'pending_customer', 'resolved', 'closed']).optional(), priority: z.enum(PRIORITIES).optional() }), req.body);
    const t = await load(id);
    const patch: Partial<TicketRow> = { updatedAt: new Date() };
    if (body.status) {
      patch.status = body.status;
      if (body.status === 'resolved' || body.status === 'closed') patch.resolvedAt = t.resolvedAt ?? new Date();
      if (body.status === 'open') patch.resolvedAt = null;
    }
    if (body.priority) {
      patch.priority = body.priority;
      if (!t.firstResponseAt) patch.slaDueAt = new Date(t.createdAt.getTime() + slaMinutes(body.priority) * 60_000);
    }
    const [row] = await db.update(supportTickets).set(patch).where(eq(supportTickets.id, id)).returning();
    await audit(db, req.ctx.actor, { action: 'support.update', entityType: 'support_ticket', entityId: id, metadata: body });
    return (await toTickets(db, [row], 'agent'))[0];
  });

  app.get('/ops/support/metrics', { preHandler: agentOnly }, async () => {
    const [{ open }] = await db.select({ open: count() }).from(supportTickets).where(inArray(supportTickets.status, ['open', 'pending_customer']));
    const [fr] = await db
      .select({ v: sql<number | null>`avg(extract(epoch from (${supportTickets.firstResponseAt} - ${supportTickets.createdAt})) / 60)` })
      .from(supportTickets)
      .where(isNotNull(supportTickets.firstResponseAt));
    const [rs] = await db
      .select({ v: sql<number | null>`avg(extract(epoch from (${supportTickets.resolvedAt} - ${supportTickets.createdAt})) / 3600)` })
      .from(supportTickets)
      .where(isNotNull(supportTickets.resolvedAt));
    const [cs] = await db.select({ v: sql<number | null>`avg(${supportTickets.ratingScore})` }).from(supportTickets).where(isNotNull(supportTickets.ratingScore));
    const cats = await db.select({ c: supportTickets.category, n: count() }).from(supportTickets).groupBy(supportTickets.category);
    const r1 = (v: unknown) => (v === null || v === undefined ? null : Math.round(Number(v) * 10) / 10);
    return {
      open: Number(open),
      avgFirstResponseMins: r1(fr?.v),
      avgResolutionHours: r1(rs?.v),
      csatAvg: r1(cs?.v),
      byCategory: Object.fromEntries(cats.map((c) => [c.c, Number(c.n)])),
    };
  });
}

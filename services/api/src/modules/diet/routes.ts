import { stripGovernanceMarkers } from '../../lib/governance.js';
import { and, desc, eq, gte } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { dietLogs, dietPlans, dietTemplates } from '../../db/schema.js';
import { assertCanActForPatient, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { list, pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { addDays, istDate, iso } from '../../lib/time.js';
import { parse, zDate, zUuid } from '../../lib/validate.js';
import { assertPlanAuthor, assertPlanReader } from '../physio/routes.js';

/** Contract section 54: diet plans. */
export const MEAL_SLOTS = ['early_morning', 'breakfast', 'mid_morning', 'lunch', 'evening', 'dinner', 'bedtime'] as const;
const READ: Perm[] = ['view_records', 'manage_care', 'staff_ops'];
type PlanRow = typeof dietPlans.$inferSelect;

const toPlan = (p: PlanRow) => ({
  id: p.id,
  patientId: p.patientId,
  templateCode: p.templateCode,
  authorName: p.authorName,
  authorRole: p.authorRole,
  conditions: p.conditions,
  calorieTarget: p.calorieTarget,
  meals: p.meals,
  avoid: p.avoid,
  notes: stripGovernanceMarkers(p.notes),
  validUntil: p.validUntil,
  status: p.validUntil < istDate() ? ('expired' as const) : ('active' as const),
  createdAt: iso(p.createdAt),
});

export async function dietRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const usable = (status: string) => svc.config.NODE_ENV !== 'production' || status === 'approved';

  app.get('/diet-templates', async () => {
    const rows = (await db.select().from(dietTemplates).orderBy(dietTemplates.code)).filter((t) => usable(t.status));
    return list(rows.map((t) => ({ code: t.code, name: t.name, conditions: t.conditions, status: t.status, version: t.version, calorieTarget: t.calorieTarget, meals: t.meals, avoid: t.avoid, notes: t.notes })));
  });

  app.post('/diet-plans', async (req, reply) => {
    const body = parse(
      z.object({
        patientId: zUuid,
        templateCode: z.string().max(40).optional(),
        conditions: z.array(z.string().trim().min(1).max(100)).max(20),
        calorieTarget: z.number().int().min(600).max(5000).optional(),
        meals: z.array(z.object({ slot: z.enum(MEAL_SLOTS), items: z.array(z.string().trim().min(1).max(200)).min(1).max(20), notes: z.string().trim().max(300).optional() })).min(1).max(7),
        avoid: z.array(z.string().trim().min(1).max(200)).max(30),
        notes: z.string().trim().max(2000).optional(),
        validUntil: zDate,
      }),
      req.body,
    );
    const author = await assertPlanAuthor(db, req.ctx, body.patientId, 'dietitian', 'diet_plan.create');
    if (body.templateCode) {
      const [t] = await db.select().from(dietTemplates).where(eq(dietTemplates.code, body.templateCode));
      if (!t || !usable(t.status)) throw errors.validation('Unknown or unapproved diet template', { field: 'templateCode' });
    }
    if (body.validUntil < istDate()) throw errors.validation('validUntil must be today or later', { field: 'validUntil' });
    if (new Set(body.meals.map((m) => m.slot)).size !== body.meals.length) throw errors.validation('Each meal slot can appear once', { field: 'meals' });
    const [row] = await db
      .insert(dietPlans)
      .values({
        patientId: body.patientId,
        templateCode: body.templateCode ?? null,
        authorUserId: req.ctx.user.id,
        authorName: author.name,
        authorRole: author.role,
        conditions: body.conditions,
        calorieTarget: body.calorieTarget ?? null,
        meals: body.meals.map((m) => ({ slot: m.slot, items: m.items, notes: m.notes ?? null })),
        avoid: body.avoid,
        notes: body.notes ?? null,
        validUntil: body.validUntil,
      })
      .returning();
    await audit(db, req.ctx.actor, { action: 'diet_plan.create', entityType: 'diet_plan', entityId: row.id, metadata: { patientId: body.patientId } });
    return reply.code(201).send(toPlan(row));
  });

  app.get('/diet-plans', async (req) => {
    const q = parse(z.object({ patientId: zUuid }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(dietPlans).where(eq(dietPlans.patientId, q.patientId)).orderBy(desc(dietPlans.createdAt));
    const authored = rows.length > 0 && rows.every((r) => r.authorUserId === req.ctx.user.id);
    if (!authored) await assertCanActForPatient(db, req.ctx, q.patientId, READ, 'diet_plan.list');
    return paginateArray(rows.map(toPlan), page);
  });

  const load = async (id: string) => {
    const [p] = await db.select().from(dietPlans).where(eq(dietPlans.id, id));
    if (!p) throw errors.notFound('Diet plan');
    return p;
  };

  app.post('/diet-plans/:id/logs', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ date: zDate, slot: z.enum(MEAL_SLOTS), followed: z.boolean(), note: z.string().trim().max(300).optional() }), req.body);
    const p = await load(id);
    await assertCanActForPatient(db, req.ctx, p.patientId, 'manage_care', 'diet_log.create');
    if (body.date > istDate()) throw errors.validation('date cannot be in the future');
    const [row] = await db
      .insert(dietLogs)
      .values({ planId: id, date: body.date, slot: body.slot, followed: body.followed, note: body.note ?? null, createdByUserId: req.ctx.user.id })
      .onConflictDoUpdate({ target: [dietLogs.planId, dietLogs.date, dietLogs.slot], set: { followed: body.followed, note: body.note ?? null } })
      .returning();
    await audit(db, req.ctx.actor, { action: 'diet_log.create', entityType: 'diet_plan', entityId: id });
    return reply.code(201).send({ id: row.id });
  });

  app.get('/diet-plans/:id/logs', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const q = parse(z.object({ date: zDate.optional() }), req.query);
    const p = await load(id);
    await assertPlanReader(db, req, p.patientId, p.authorUserId, 'diet_log.list');
    const rows = await db
      .select()
      .from(dietLogs)
      .where(q.date ? and(eq(dietLogs.planId, id), eq(dietLogs.date, q.date)) : eq(dietLogs.planId, id))
      .orderBy(desc(dietLogs.date), dietLogs.slot);
    return list(rows.map((l) => ({ id: l.id, date: l.date, slot: l.slot, followed: l.followed, note: l.note })));
  });

  app.get('/diet-plans/:id/adherence', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const q = parse(z.object({ days: z.coerce.number().int().min(1).max(90).default(14) }), req.query);
    const p = await load(id);
    await assertPlanReader(db, req, p.patientId, p.authorUserId, 'diet_plan.adherence');
    const today = istDate();
    const from = addDays(today, -(q.days - 1));
    const logs = await db.select().from(dietLogs).where(and(eq(dietLogs.planId, id), gte(dietLogs.date, from)));
    const days = [];
    let logged = 0;
    let followed = 0;
    for (let i = q.days - 1; i >= 0; i--) {
      const date = addDays(today, -i);
      const ls = logs.filter((l) => l.date === date);
      const f = ls.filter((l) => l.followed).length;
      logged += ls.length;
      followed += f;
      days.push({ date, slotsLogged: ls.length, slotsFollowed: f });
    }
    return { days, adherencePct: logged ? Math.round((followed / logged) * 100) : null };
  });
}

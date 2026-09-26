import { desc, eq, ne } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { safetyRulePacks } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { parse, zUuid, zVitalType } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { toPack } from './service.js';

export const zSafetyRule = z.object({
  id: z.string().min(1).max(100),
  title: z.string().min(1).max(200),
  description: z.string().min(1).max(2000),
  when: z
    .object({
      anyKeywords: z.array(z.string().min(1).max(100)).max(200).optional(),
      allKeywords: z.array(z.string().min(1).max(100)).max(50).optional(),
      minSeverity: z.number().int().min(0).max(10).optional(),
      vital: z.object({ type: zVitalType, op: z.enum(['lt', 'gt']), value: z.number() }).optional(),
      ageGte: z.number().int().min(0).max(130).optional(),
    })
    .refine((w) => Object.values(w).some((v) => v !== undefined), 'A rule needs at least one condition'),
  level: z.enum(['routine', 'urgent', 'emergency']),
  action: z.enum(['show_emergency', 'escalate_clinician', 'suggest_doctor', 'suggest_home_visit']),
});

/** Admin management of versioned safety rule packs (super_admin). */
export async function safetyAdminRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  app.addHook('preHandler', requireRoles(svc, 'super_admin'));

  app.get('/admin/safety-rule-packs', async (req) => {
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(safetyRulePacks).orderBy(desc(safetyRulePacks.createdAt));
    return paginateArray(rows.map(toPack), page);
  });

  app.post('/admin/safety-rule-packs', async (req, reply) => {
    const body = parse(z.object({ version: z.string().trim().min(1).max(40), rules: z.array(zSafetyRule).min(1).max(500) }), req.body);
    const ids = new Set(body.rules.map((r) => r.id));
    if (ids.size !== body.rules.length) throw errors.validation('Rule ids must be unique');
    const [existing] = await db.select({ id: safetyRulePacks.id }).from(safetyRulePacks).where(eq(safetyRulePacks.version, body.version));
    if (existing) throw errors.conflict('A pack with this version already exists');
    const [row] = await db.insert(safetyRulePacks).values({ version: body.version, rules: body.rules, status: 'draft' }).returning();
    await audit(db, req.ctx.actor, { action: 'safety_pack.create', entityType: 'safety_rule_pack', entityId: row.id, metadata: { version: body.version, ruleCount: body.rules.length } });
    return reply.code(201).send(toPack(row));
  });

  app.post('/admin/safety-rule-packs/:id/approve', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ approverName: z.string().trim().min(2).max(100), approverRegistration: z.string().trim().min(2).max(60) }), req.body);
    const [p] = await db.select().from(safetyRulePacks).where(eq(safetyRulePacks.id, id));
    if (!p) throw errors.notFound('Rule pack');
    if (p.status === 'retired') throw errors.invalidTransition(p.status, 'approved');
    if (p.rules.some((r) => /FIXTURE/i.test(r.description))) {
      throw errors.conflict('Pack contains FIXTURE rules; replace them with clinician-approved rules before approval');
    }
    const [row] = await db
      .update(safetyRulePacks)
      .set({ status: 'approved', approvedBy: body.approverName, approverRegistration: body.approverRegistration, approvedAt: new Date() })
      .where(eq(safetyRulePacks.id, id))
      .returning();
    await audit(db, req.ctx.actor, { action: 'safety_pack.approve', entityType: 'safety_rule_pack', entityId: id, metadata: { version: p.version } });
    return toPack(row);
  });

  app.post('/admin/safety-rule-packs/:id/activate', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [p] = await db.select().from(safetyRulePacks).where(eq(safetyRulePacks.id, id));
    if (!p) throw errors.notFound('Rule pack');
    const allowed = svc.config.NODE_ENV === 'production' ? ['approved'] : ['approved', 'fixture_unapproved'];
    if (!allowed.includes(p.status)) {
      throw errors.conflict(
        svc.config.NODE_ENV === 'production' ? 'Only clinician-approved packs can be activated in production' : 'Pack must be approved (or a fixture in dev) to activate',
        { status: p.status },
      );
    }
    const row = await db.transaction(async (tx) => {
      await tx.update(safetyRulePacks).set({ active: false }).where(ne(safetyRulePacks.id, id));
      const [r] = await tx.update(safetyRulePacks).set({ active: true }).where(eq(safetyRulePacks.id, id)).returning();
      await audit(tx, req.ctx.actor, { action: 'safety_pack.activate', entityType: 'safety_rule_pack', entityId: id, metadata: { version: p.version } });
      return r;
    });
    return toPack(row);
  });
}

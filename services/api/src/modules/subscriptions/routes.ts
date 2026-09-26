import { asc, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { subscriptionPlans, subscriptions } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { list } from '../../lib/pagination.js';
import { parse } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { toPayment } from '../payments/service.js';
import { activeSubscriptionOf, cancelPending, latestSubscriptionOf, subscriptionView, toPlan } from './service.js';

const zCode = z.string().trim().regex(/^[a-z0-9_]{2,40}$/, 'lowercase letters, digits and _ only');
const zPlanFields = z.object({
  name: z.string().trim().min(1).max(100),
  description: z.string().trim().max(1000),
  priceMonthly: z.number().int().min(0).max(1_000_000),
  priceYearly: z.number().int().min(0).max(10_000_000),
  benefits: z.array(z.string().trim().min(1).max(200)).max(20),
  maxMembers: z.number().int().min(1).max(20),
  coordinatorIncluded: z.boolean(),
  homeVisitDiscountPct: z.number().int().min(0).max(100),
  active: z.boolean(),
});

/** Contract section 37: Family Care Plan subscriptions + admin plan management. */
export async function subscriptionRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/subscription-plans', async () => {
    const rows = await db.select().from(subscriptionPlans).where(eq(subscriptionPlans.active, true)).orderBy(asc(subscriptionPlans.priceMonthly));
    return list(rows.map(toPlan));
  });

  app.get('/subscriptions/me', async (req) => {
    const s = await latestSubscriptionOf(db, req.ctx.user.id);
    if (!s) throw errors.notFound('Subscription');
    return subscriptionView(db, s);
  });

  app.post('/subscriptions', { config: { idempotent: true } }, async (req, reply) => {
    const body = parse(z.object({ planCode: zCode, billing: z.enum(['monthly', 'yearly']) }), req.body);
    const [plan] = await db.select().from(subscriptionPlans).where(eq(subscriptionPlans.code, body.planCode));
    if (!plan || !plan.active) throw errors.validation('Unknown or inactive plan', { field: 'planCode' });
    const patientId = req.ctx.user.selfPatientId;
    if (!patientId) throw errors.conflict('A personal patient profile is required to subscribe');
    if (await activeSubscriptionOf(db, req.ctx.user.id)) throw errors.conflict('You already have an active Family Care Plan');
    const amount = body.billing === 'yearly' ? plan.priceYearly : plan.priceMonthly;
    const result = await db.transaction(async (tx) => {
      await cancelPending(tx, req.ctx.user.id);
      const [s] = await tx.insert(subscriptions).values({ userId: req.ctx.user.id, planCode: plan.code, billing: body.billing, status: 'pending' }).returning();
      const payment = await svc.payments.create(tx, { purpose: 'subscription', refId: s.id, patientId, amount, userId: req.ctx.user.id });
      await audit(tx, req.ctx.actor, { action: 'subscription.create', entityType: 'subscription', entityId: s.id, metadata: { planCode: plan.code, billing: body.billing } });
      return { s, payment };
    });
    return reply.code(201).send({ subscription: await subscriptionView(db, result.s), payment: toPayment(result.payment) });
  });

  app.post('/subscriptions/me/cancel', async (req) => {
    const s = await latestSubscriptionOf(db, req.ctx.user.id);
    if (!s || (s.status !== 'active' && s.status !== 'pending')) throw errors.notFound('Subscription');
    const row = await db.transaction(async (tx) => {
      let r;
      if (s.status === 'pending') {
        await cancelPending(tx, req.ctx.user.id);
        [r] = await tx.select().from(subscriptions).where(eq(subscriptions.id, s.id));
      } else {
        [r] = await tx.update(subscriptions).set({ cancelAtPeriodEnd: true, updatedAt: new Date() }).where(eq(subscriptions.id, s.id)).returning();
      }
      await audit(tx, req.ctx.actor, { action: 'subscription.cancel', entityType: 'subscription', entityId: s.id, metadata: { status: s.status } });
      return r;
    });
    return subscriptionView(db, row);
  });

  // ---------------------------------------------------------------- admin plans (super_admin)
  const superOnly = requireRoles(svc, 'super_admin');

  app.get('/admin/subscription-plans', { preHandler: superOnly }, async () => {
    const rows = await db.select().from(subscriptionPlans).orderBy(asc(subscriptionPlans.priceMonthly));
    return list(rows.map(toPlan));
  });

  app.post('/admin/subscription-plans', { preHandler: superOnly }, async (req, reply) => {
    const body = parse(zPlanFields.extend({ code: zCode }), req.body);
    const [row] = await db.insert(subscriptionPlans).values(body).onConflictDoNothing().returning();
    if (!row) throw errors.conflict('A plan with this code already exists');
    await audit(db, req.ctx.actor, { action: 'subscription_plan.create', entityType: 'subscription_plan', entityId: row.code });
    return reply.code(201).send(toPlan(row));
  });

  app.patch('/admin/subscription-plans/:code', { preHandler: superOnly }, async (req) => {
    const { code } = parse(z.object({ code: zCode }), req.params);
    const body = parse(zPlanFields.partial(), req.body);
    const [row] = await db.update(subscriptionPlans).set({ ...body, updatedAt: new Date() }).where(eq(subscriptionPlans.code, code)).returning();
    if (!row) throw errors.notFound('Plan');
    await audit(db, req.ctx.actor, { action: 'subscription_plan.update', entityType: 'subscription_plan', entityId: code, metadata: { fields: Object.keys(body) } });
    return toPlan(row);
  });

}

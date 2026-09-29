import { and, count, desc, eq, sql } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { coupons, inviteRedemptions, users, walletTransactions } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { parse, zIso, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { PAYMENT_PURPOSES, checkCoupon, ensureInviteCode, normaliseCode, toCoupon, walletView } from './service.js';

export const zCouponCode = z.string().trim().min(2).max(40);
export const zRefundTo = z.enum(['original', 'wallet']);

const zCouponFields = z.object({
  code: z.string().trim().regex(/^[A-Za-z0-9_-]{2,40}$/, 'letters, digits, _ and - only'),
  description: z.string().trim().min(1).max(300),
  type: z.enum(['percent', 'flat']),
  value: z.number().int().positive().max(1_000_000),
  maxDiscount: z.number().int().positive().nullable().optional(),
  minAmount: z.number().int().min(0).nullable().optional(),
  appliesTo: z.array(z.enum(PAYMENT_PURPOSES)).min(1),
  validFrom: zIso,
  validTo: zIso,
  usageLimit: z.number().int().positive().nullable().optional(),
  perUserLimit: z.number().int().positive().max(1000),
  active: z.boolean(),
});

/** Contract section 60: offers, wallet & invites. */
export async function walletRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const superOnly = requireRoles(svc, 'super_admin');

  app.get('/admin/coupons', { preHandler: superOnly }, async (req) => {
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(coupons).orderBy(desc(coupons.createdAt));
    return paginateArray(rows.map(toCoupon), page);
  });

  app.post('/admin/coupons', { preHandler: superOnly }, async (req, reply) => {
    const body = parse(zCouponFields, req.body);
    if (new Date(body.validTo) <= new Date(body.validFrom)) throw errors.validation('validTo must be after validFrom');
    if (body.type === 'percent' && body.value > 100) throw errors.validation('A percent coupon value must be at most 100');
    const [row] = await db
      .insert(coupons)
      .values({ ...body, code: normaliseCode(body.code), validFrom: new Date(body.validFrom), validTo: new Date(body.validTo), maxDiscount: body.maxDiscount ?? null, minAmount: body.minAmount ?? null, usageLimit: body.usageLimit ?? null })
      .onConflictDoNothing()
      .returning();
    if (!row) throw errors.conflict('A coupon with this code already exists');
    await audit(db, req.ctx.actor, { action: 'coupon.create', entityType: 'coupon', entityId: row.id, metadata: { code: row.code } });
    return reply.code(201).send(toCoupon(row));
  });

  app.patch('/admin/coupons/:id', { preHandler: superOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(zCouponFields.omit({ code: true }).partial(), req.body);
    const patch: Partial<typeof coupons.$inferInsert> = { ...body, validFrom: undefined, validTo: undefined, updatedAt: new Date() };
    if (body.validFrom) patch.validFrom = new Date(body.validFrom);
    if (body.validTo) patch.validTo = new Date(body.validTo);
    const [row] = await db.update(coupons).set(patch).where(eq(coupons.id, id)).returning();
    if (!row) throw errors.notFound('Coupon');
    await audit(db, req.ctx.actor, { action: 'coupon.update', entityType: 'coupon', entityId: id, metadata: { fields: Object.keys(body) } });
    return toCoupon(row);
  });

  app.post('/coupons/validate', async (req) => {
    const body = parse(z.object({ code: zCouponCode, purpose: z.enum(PAYMENT_PURPOSES), amount: z.number().int().min(0).max(10_000_000) }), req.body);
    const r = await checkCoupon(db, { code: body.code, purpose: body.purpose, amount: body.amount, userId: req.ctx.user.id });
    return { valid: r.valid, discount: r.discount, finalAmount: r.finalAmount, message: r.message };
  });

  app.get('/wallet', async (req) => walletView(db, req.ctx.user.id));

  app.get('/me/invite', async (req) => {
    const code = await ensureInviteCode(db, req.ctx.user.id);
    const [{ n }] = await db.select({ n: count() }).from(inviteRedemptions).where(eq(inviteRedemptions.inviterUserId, req.ctx.user.id));
    const [{ s }] = await db
      .select({ s: sql<number>`coalesce(sum(${walletTransactions.amount}), 0)::int` })
      .from(walletTransactions)
      .where(and(eq(walletTransactions.userId, req.ctx.user.id), eq(walletTransactions.type, 'credit'), eq(walletTransactions.reason, 'invite_reward')));
    const invitee = svc.config.INVITE_REWARD_INVITEE;
    return {
      code,
      shareText: `Join me on CareCompanion for doctor consultations, home visits and family care. Use my invite code ${code} when you sign up and get ₹${invitee} wallet credit after your first paid service. ${svc.config.APP_DEEP_LINK_BASE}/invite/${code}`,
      invitedCount: Number(n),
      rewardsEarned: Number(s),
    };
  });

  app.post('/me/invite/redeem', async (req) => {
    const body = parse(z.object({ code: zCouponCode }), req.body);
    const code = normaliseCode(body.code);
    const [me] = await db.select().from(users).where(eq(users.id, req.ctx.user.id));
    if (Date.now() - me.createdAt.getTime() > svc.config.INVITE_REDEEM_WINDOW_DAYS * 86400_000) {
      throw errors.conflict(`Invite codes can only be used within ${svc.config.INVITE_REDEEM_WINDOW_DAYS} days of signing up`);
    }
    const [inviter] = await db.select({ id: users.id }).from(users).where(eq(users.inviteCode, code));
    if (!inviter) throw errors.validation('This invite code is not valid', { field: 'code' });
    if (inviter.id === me.id) throw errors.validation('You cannot use your own invite code', { field: 'code' });
    const [row] = await db.insert(inviteRedemptions).values({ inviterUserId: inviter.id, inviteeUserId: me.id, code }).onConflictDoNothing().returning();
    if (!row) throw errors.conflict('You have already used an invite code');
    await audit(db, req.ctx.actor, { action: 'invite.redeem', entityType: 'invite_redemption', entityId: row.id });
    return { ok: true };
  });
}

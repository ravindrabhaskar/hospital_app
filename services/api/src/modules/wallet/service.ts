import { randomBytes } from 'node:crypto';
import { and, asc, count, desc, eq, gt, inArray, isNull, lte, or, sql } from 'drizzle-orm';
import type { Config } from '../../config.js';
import type { Db, DbOrTx } from '../../db/client.js';
import {
  appointments,
  couponRedemptions,
  coupons,
  homeVisits,
  inviteRedemptions,
  labOrders,
  payments,
  secondOpinions,
  users,
  walletTransactions,
} from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, type Actor } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { iso } from '../../lib/time.js';

/**
 * Contract section 60: coupons, a non-withdrawable wallet and invites.
 * Wallet credit expires after WALLET_CREDIT_EXPIRY_DAYS (default 365) [REQUIRES LEGAL REVIEW: RBI PPI rules].
 */
export type CouponRow = typeof coupons.$inferSelect;
export const PAYMENT_PURPOSES = ['appointment', 'home_visit', 'pharmacy_order', 'subscription', 'lab_order', 'second_opinion', 'ambulance'] as const;

export const toCoupon = (c: CouponRow) => ({
  id: c.id,
  code: c.code,
  description: c.description,
  type: c.type,
  value: c.value,
  maxDiscount: c.maxDiscount,
  minAmount: c.minAmount,
  appliesTo: c.appliesTo,
  validFrom: iso(c.validFrom),
  validTo: iso(c.validTo),
  usageLimit: c.usageLimit,
  perUserLimit: c.perUserLimit,
  active: c.active,
  createdAt: iso(c.createdAt),
});

export const normaliseCode = (code: string): string => code.trim().toUpperCase();

export interface CouponCheck {
  valid: boolean;
  discount: number;
  finalAmount: number;
  message: string;
  coupon: CouponRow | null;
}

/** Discount for an amount (never more than the amount). */
export function couponDiscount(c: Pick<CouponRow, 'type' | 'value' | 'maxDiscount'>, amount: number): number {
  let d = c.type === 'percent' ? Math.floor((amount * c.value) / 100) : c.value;
  if (c.maxDiscount !== null && c.maxDiscount !== undefined) d = Math.min(d, c.maxDiscount);
  return Math.max(0, Math.min(d, amount));
}

/** Validate a coupon for a user, purpose and amount (rupees). Never throws for business-rule failures. */
export async function checkCoupon(db: DbOrTx, p: { code: string; purpose: string; amount: number; userId: string; now?: Date }): Promise<CouponCheck> {
  const now = p.now ?? new Date();
  const invalid = (message: string, coupon: CouponRow | null = null): CouponCheck => ({ valid: false, discount: 0, finalAmount: p.amount, message, coupon });
  const [c] = await db.select().from(coupons).where(eq(coupons.code, normaliseCode(p.code)));
  if (!c || !c.active) return invalid('This coupon code is not valid.');
  if (now < c.validFrom) return invalid('This coupon is not active yet.', c);
  if (now > c.validTo) return invalid('This coupon has expired.', c);
  if (!c.appliesTo.includes(p.purpose)) return invalid('This coupon does not apply to this service.', c);
  if (c.minAmount !== null && p.amount < c.minAmount) return invalid(`This coupon needs a minimum amount of ₹${c.minAmount}.`, c);
  if (c.usageLimit !== null) {
    const [{ n }] = await db.select({ n: count() }).from(couponRedemptions).where(and(eq(couponRedemptions.couponId, c.id), eq(couponRedemptions.status, 'active')));
    if (Number(n) >= c.usageLimit) return invalid('This coupon has reached its usage limit.', c);
  }
  const [{ mine }] = await db
    .select({ mine: count() })
    .from(couponRedemptions)
    .where(and(eq(couponRedemptions.couponId, c.id), eq(couponRedemptions.userId, p.userId), eq(couponRedemptions.status, 'active')));
  if (Number(mine) >= c.perUserLimit) return invalid('You have already used this coupon.', c);
  const discount = couponDiscount(c, p.amount);
  if (discount <= 0) return invalid('This coupon gives no discount on this amount.', c);
  return { valid: true, discount, finalAmount: p.amount - discount, message: `Coupon applied: you save ₹${discount}.`, coupon: c };
}

// ---------------------------------------------------------------- wallet ledger

/** Spendable balance: remaining amount of unexpired credits. */
export async function walletBalance(db: DbOrTx, userId: string, now = new Date()): Promise<number> {
  const [r] = await db
    .select({ s: sql<number>`coalesce(sum(${walletTransactions.remaining}), 0)::int` })
    .from(walletTransactions)
    .where(
      and(
        eq(walletTransactions.userId, userId),
        eq(walletTransactions.type, 'credit'),
        gt(walletTransactions.remaining, 0),
        or(isNull(walletTransactions.expiresAt), gt(walletTransactions.expiresAt, now)),
      ),
    );
  return Number(r?.s ?? 0);
}

export async function creditWallet(
  db: DbOrTx,
  config: Config,
  p: { userId: string; amount: number; reason: string; refType?: string | null; refId?: string | null; now?: Date },
): Promise<void> {
  if (p.amount <= 0) return;
  const now = p.now ?? new Date();
  await db.insert(walletTransactions).values({
    userId: p.userId,
    type: 'credit',
    amount: p.amount,
    remaining: p.amount,
    reason: p.reason,
    refType: p.refType ?? null,
    refId: p.refId ?? null,
    expiresAt: new Date(now.getTime() + config.WALLET_CREDIT_EXPIRY_DAYS * 86400_000),
    createdAt: now,
  });
}

/**
 * Debit up to `amount` (FIFO by earliest expiry; the credit rows are locked). Returns the amount debited, which is
 * less than requested when the balance is lower.
 */
export async function debitWallet(
  db: DbOrTx,
  p: { userId: string; amount: number; reason: string; refType?: string | null; refId?: string | null; now?: Date },
): Promise<number> {
  if (p.amount <= 0) return 0;
  const now = p.now ?? new Date();
  const credits = await db
    .select()
    .from(walletTransactions)
    .where(
      and(
        eq(walletTransactions.userId, p.userId),
        eq(walletTransactions.type, 'credit'),
        gt(walletTransactions.remaining, 0),
        or(isNull(walletTransactions.expiresAt), gt(walletTransactions.expiresAt, now)),
      ),
    )
    .orderBy(asc(walletTransactions.expiresAt), asc(walletTransactions.createdAt))
    .for('update');
  let need = p.amount;
  for (const c of credits) {
    if (need <= 0) break;
    const take = Math.min(c.remaining, need);
    await db.update(walletTransactions).set({ remaining: c.remaining - take }).where(eq(walletTransactions.id, c.id));
    need -= take;
  }
  const debited = p.amount - need;
  if (debited > 0) {
    await db.insert(walletTransactions).values({
      userId: p.userId,
      type: 'debit',
      amount: debited,
      remaining: 0,
      reason: p.reason,
      refType: p.refType ?? null,
      refId: p.refId ?? null,
      createdAt: now,
    });
  }
  return debited;
}

/** Worker: expire credits past their expiry date (one debit row per expired credit). */
export async function expireWalletCredits(db: Db, now: Date): Promise<number> {
  const due = await db
    .select()
    .from(walletTransactions)
    .where(and(eq(walletTransactions.type, 'credit'), gt(walletTransactions.remaining, 0), lte(walletTransactions.expiresAt, now)));
  let n = 0;
  for (const c of due) {
    const done = await db.transaction(async (tx) => {
      const [row] = await tx
        .update(walletTransactions)
        .set({ remaining: 0 })
        .where(and(eq(walletTransactions.id, c.id), gt(walletTransactions.remaining, 0)))
        .returning();
      if (!row) return false;
      await tx.insert(walletTransactions).values({ userId: c.userId, type: 'debit', amount: c.remaining, reason: 'credit_expired', refType: 'wallet_credit', refId: c.id, createdAt: now });
      await audit(tx, SYSTEM_ACTOR, { action: 'wallet.expire', entityType: 'wallet_credit', entityId: c.id, metadata: { amount: c.remaining } });
      return true;
    });
    if (done) n++;
  }
  return n;
}

export async function walletView(db: DbOrTx, userId: string) {
  const rows = await db.select().from(walletTransactions).where(eq(walletTransactions.userId, userId)).orderBy(desc(walletTransactions.createdAt)).limit(100);
  return {
    balance: await walletBalance(db, userId),
    transactions: rows.map((r) => ({ id: r.id, type: r.type, amount: r.amount, reason: r.reason, refType: r.refType, refId: r.refId, at: iso(r.createdAt) })),
  };
}

// ---------------------------------------------------------------- invites

const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function randomCode(len: number): string {
  const bytes = randomBytes(len);
  return Array.from(bytes, (b) => INVITE_ALPHABET[b % INVITE_ALPHABET.length]).join('');
}

/** The user's personal invite code, created on first use. */
export async function ensureInviteCode(db: DbOrTx, userId: string): Promise<string> {
  const [u] = await db.select({ code: users.inviteCode }).from(users).where(eq(users.id, userId));
  if (u?.code) return u.code;
  for (let i = 0; i < 5; i++) {
    const code = `CC${randomCode(6)}`;
    const rows = await db
      .update(users)
      .set({ inviteCode: code })
      .where(and(eq(users.id, userId), isNull(users.inviteCode)))
      .returning({ code: users.inviteCode })
      .catch(() => []);
    if (rows.length) return rows[0].code!;
    const [again] = await db.select({ code: users.inviteCode }).from(users).where(eq(users.id, userId));
    if (again?.code) return again.code;
  }
  throw errors.conflict('Could not create an invite code; please retry');
}

/**
 * Has the user completed a paid service? Paid = a succeeded (or partly refunded) payment with money charged, created
 * by the user, whose service completed (consultation completed, home visit completed, lab report ready, second opinion answered).
 */
export async function hasCompletedPaidService(db: DbOrTx, userId: string): Promise<boolean> {
  const paid = await db
    .select({ purpose: payments.purpose, refId: payments.refId })
    .from(payments)
    .where(and(eq(payments.createdByUserId, userId), inArray(payments.status, ['succeeded', 'partially_refunded']), gt(payments.amount, 0)));
  if (!paid.length) return false;
  const ids = (purpose: string) => paid.filter((p) => p.purpose === purpose).map((p) => p.refId);
  const checks: Array<Promise<unknown[]>> = [];
  if (ids('appointment').length) checks.push(db.select({ id: appointments.id }).from(appointments).where(and(inArray(appointments.id, ids('appointment')), eq(appointments.status, 'completed'))).limit(1));
  if (ids('home_visit').length) checks.push(db.select({ id: homeVisits.id }).from(homeVisits).where(and(inArray(homeVisits.id, ids('home_visit')), eq(homeVisits.status, 'completed'))).limit(1));
  if (ids('lab_order').length) checks.push(db.select({ id: labOrders.id }).from(labOrders).where(and(inArray(labOrders.id, ids('lab_order')), eq(labOrders.status, 'report_ready'))).limit(1));
  if (ids('second_opinion').length)
    checks.push(db.select({ id: secondOpinions.id }).from(secondOpinions).where(and(inArray(secondOpinions.id, ids('second_opinion')), eq(secondOpinions.status, 'answered'))).limit(1));
  for (const rows of await Promise.all(checks)) if (rows.length) return true;
  return false;
}

/** Worker: credit invite rewards once the invitee's first paid service has completed. */
export async function processInviteRewards(db: Db, config: Config, now: Date, onRewarded?: (inviterId: string, inviteeId: string) => Promise<void>): Promise<number> {
  const pending = await db.select().from(inviteRedemptions).where(eq(inviteRedemptions.status, 'pending'));
  let n = 0;
  for (const r of pending) {
    if (!(await hasCompletedPaidService(db, r.inviteeUserId))) continue;
    const done = await db.transaction(async (tx) => {
      const [row] = await tx
        .update(inviteRedemptions)
        .set({ status: 'rewarded', rewardedAt: now })
        .where(and(eq(inviteRedemptions.id, r.id), eq(inviteRedemptions.status, 'pending')))
        .returning();
      if (!row) return false;
      await creditWallet(tx, config, { userId: r.inviterUserId, amount: config.INVITE_REWARD_INVITER, reason: 'invite_reward', refType: 'invite', refId: r.id, now });
      await creditWallet(tx, config, { userId: r.inviteeUserId, amount: config.INVITE_REWARD_INVITEE, reason: 'invite_welcome_reward', refType: 'invite', refId: r.id, now });
      await audit(tx, SYSTEM_ACTOR, { action: 'invite.reward', entityType: 'invite_redemption', entityId: r.id });
      return true;
    });
    if (done) {
      n++;
      await onRewarded?.(r.inviterUserId, r.inviteeUserId);
    }
  }
  return n;
}

// ---------------------------------------------------------------- pricing (used by PaymentService.create)

export interface AppliedPricing {
  gross: number;
  discount: number;
  walletUsed: number;
  charge: number;
  coupon: CouponRow | null;
}

/**
 * Apply a coupon and/or wallet credit to a gross amount inside the booking transaction. An invalid coupon is a
 * VALIDATION_ERROR (details.couponCode + message). The wallet is debited here; the caller records the payment.
 */
export async function applyPricing(
  tx: DbOrTx,
  p: { userId: string | null; purpose: string; gross: number; couponCode?: string | null; useWallet?: boolean; paymentId: string },
  actor: Actor,
): Promise<AppliedPricing> {
  let discount = 0;
  let coupon: CouponRow | null = null;
  if (p.couponCode) {
    if (!p.userId) throw errors.validation('Coupons need a signed-in user');
    const check = await checkCoupon(tx, { code: p.couponCode, purpose: p.purpose, amount: p.gross, userId: p.userId });
    if (!check.valid || !check.coupon) throw errors.validation(check.message, { field: 'couponCode', couponCode: normaliseCode(p.couponCode) });
    discount = check.discount;
    coupon = check.coupon;
    await tx.insert(couponRedemptions).values({ couponId: coupon.id, userId: p.userId, paymentId: p.paymentId, discount });
  }
  let walletUsed = 0;
  if (p.useWallet && p.userId && p.gross - discount > 0) {
    walletUsed = await debitWallet(tx, { userId: p.userId, amount: p.gross - discount, reason: `payment:${p.purpose}`, refType: 'payment', refId: p.paymentId });
  }
  if (coupon || walletUsed) {
    await audit(tx, actor, { action: 'payment.pricing', entityType: 'payment', entityId: p.paymentId, metadata: { coupon: coupon?.code ?? null, discount, walletUsed } });
  }
  return { gross: p.gross, discount, walletUsed, charge: p.gross - discount - walletUsed, coupon };
}

/** Give back the wallet part and release the coupon of a payment that will not complete (void / failure). */
export async function releasePricing(tx: DbOrTx, config: Config, pay: typeof payments.$inferSelect): Promise<{ walletReturned: number }> {
  const back = pay.walletUsed - pay.walletRefunded;
  if (back > 0 && pay.createdByUserId) {
    await creditWallet(tx, config, { userId: pay.createdByUserId, amount: back, reason: 'payment_released', refType: 'payment', refId: pay.id });
    await tx.update(payments).set({ walletRefunded: pay.walletUsed }).where(eq(payments.id, pay.id));
  }
  await tx.update(couponRedemptions).set({ status: 'released' }).where(and(eq(couponRedemptions.paymentId, pay.id), eq(couponRedemptions.status, 'active')));
  return { walletReturned: Math.max(0, back) };
}

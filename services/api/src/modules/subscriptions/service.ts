import { and, desc, eq, inArray, isNull, lte, sql } from 'drizzle-orm';
import type { Db, DbOrTx } from '../../db/client.js';
import { patients, payments, subscriptionPlans, subscriptions } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { iso } from '../../lib/time.js';
import { autoAssignCoordinators } from '../coordinator/routes.js';
import type { NotificationService } from '../notifications/service.js';
import type { PaymentEffects, PaymentRow } from '../payments/service.js';

/** Contract section 37: Family Care Plan subscriptions. */
export type PlanRow = typeof subscriptionPlans.$inferSelect;
export type SubscriptionRow = typeof subscriptions.$inferSelect;

export const RENEWAL_REMINDER_DAYS = 7;

export const toPlan = (p: PlanRow) => ({
  code: p.code,
  name: p.name,
  description: p.description,
  priceMonthly: p.priceMonthly,
  priceYearly: p.priceYearly,
  benefits: p.benefits,
  maxMembers: p.maxMembers,
  coordinatorIncluded: p.coordinatorIncluded,
  homeVisitDiscountPct: p.homeVisitDiscountPct,
  active: p.active,
});

export const toSubscription = (s: SubscriptionRow, plan: PlanRow) => ({
  id: s.id,
  planCode: s.planCode,
  planName: plan.name,
  status: s.status,
  billing: s.billing,
  currentPeriodStart: iso(s.currentPeriodStart),
  currentPeriodEnd: iso(s.currentPeriodEnd),
  cancelAtPeriodEnd: s.cancelAtPeriodEnd,
  benefits: plan.benefits,
  createdAt: iso(s.createdAt),
});

export async function subscriptionView(db: DbOrTx, s: SubscriptionRow) {
  const [plan] = await db.select().from(subscriptionPlans).where(eq(subscriptionPlans.code, s.planCode));
  return toSubscription(s, plan);
}

/** Calendar-month arithmetic in UTC (clamped to the last day of the target month). */
export function addMonths(d: Date, months: number): Date {
  const r = new Date(d.getTime());
  const day = r.getUTCDate();
  r.setUTCDate(1);
  r.setUTCMonth(r.getUTCMonth() + months);
  const last = new Date(Date.UTC(r.getUTCFullYear(), r.getUTCMonth() + 1, 0)).getUTCDate();
  r.setUTCDate(Math.min(day, last));
  return r;
}

export async function activeSubscriptionOf(db: DbOrTx, userId: string, now = new Date()): Promise<{ sub: SubscriptionRow; plan: PlanRow } | null> {
  const [row] = await db
    .select({ sub: subscriptions, plan: subscriptionPlans })
    .from(subscriptions)
    .innerJoin(subscriptionPlans, eq(subscriptionPlans.code, subscriptions.planCode))
    .where(and(eq(subscriptions.userId, userId), eq(subscriptions.status, 'active'), sql`${subscriptions.currentPeriodEnd} > ${now}`))
    .limit(1);
  return row ?? null;
}

/**
 * Home-visit discount for a patient: the subscription of the patient's managing user (self profile or guardian)
 * applies to their own and managed patients. Returns rupees to deduct.
 */
export async function homeVisitDiscount(db: DbOrTx, patientId: string, price: number): Promise<number> {
  const [p] = await db.select({ ownerUserId: patients.ownerUserId, userId: patients.userId }).from(patients).where(eq(patients.id, patientId));
  const owner = p?.ownerUserId ?? p?.userId;
  if (!owner) return 0;
  const active = await activeSubscriptionOf(db, owner);
  if (!active || active.plan.homeVisitDiscountPct <= 0) return 0;
  return Math.min(price, Math.round((price * active.plan.homeVisitDiscountPct) / 100));
}

/** Patients covered by a subscriber: their self profile and managed dependents. */
export async function coveredPatientIds(db: DbOrTx, userId: string): Promise<string[]> {
  const rows = await db.select({ id: patients.id }).from(patients).where(sql`${patients.userId} = ${userId} or ${patients.ownerUserId} = ${userId}`);
  return rows.map((r) => r.id);
}

export function subscriptionPaymentEffects(notify: NotificationService): PaymentEffects {
  return {
    async onSucceeded(db: Db, p: PaymentRow) {
      const activated = await db.transaction(async (tx) => {
        const [s] = await tx.select().from(subscriptions).where(eq(subscriptions.id, p.refId));
        if (!s || s.status !== 'pending') return null;
        // A second paid plan while one is active: the newest payment wins, the previous one ends now.
        await tx
          .update(subscriptions)
          .set({ status: 'cancelled', cancelAtPeriodEnd: true, currentPeriodEnd: new Date(), updatedAt: new Date() })
          .where(and(eq(subscriptions.userId, s.userId), eq(subscriptions.status, 'active')));
        const start = new Date();
        const end = addMonths(start, s.billing === 'yearly' ? 12 : 1);
        const [row] = await tx
          .update(subscriptions)
          .set({ status: 'active', currentPeriodStart: start, currentPeriodEnd: end, cancelAtPeriodEnd: false, renewalReminderSentAt: null, updatedAt: new Date() })
          .where(and(eq(subscriptions.id, s.id), eq(subscriptions.status, 'pending')))
          .returning();
        if (row) await audit(tx, SYSTEM_ACTOR, { action: 'subscription.activate', entityType: 'subscription', entityId: s.id, metadata: { planCode: s.planCode } });
        return row ?? null;
      });
      if (!activated) return;
      const [plan] = await db.select().from(subscriptionPlans).where(eq(subscriptionPlans.code, activated.planCode));
      await notify.notifyUsers([activated.userId], {
        template: 'subscription_active',
        params: { plan: plan?.name ?? 'Family Care Plan', until: activated.currentPeriodEnd!.toISOString().slice(0, 10) },
        category: 'payment',
        deepLink: '/subscriptions/me',
        dedupeKey: `subscription_active:${activated.id}`,
      });
      if (plan?.coordinatorIncluded) {
        await db.transaction(async (tx) => autoAssignCoordinators(tx, await coveredPatientIds(tx, activated.userId), null));
      }
    },
    async onFailed() {
      // The subscription stays `pending`; the payment can be retried (POST /payments/:id/retry).
    },
    async onRetry(tx, p: PaymentRow) {
      const [s] = await tx.select().from(subscriptions).where(eq(subscriptions.id, p.refId));
      if (!s) throw errors.notFound('Subscription');
      if (s.status !== 'pending') throw errors.conflict('This subscription can no longer be paid for', { status: s.status });
    },
  };
}

/**
 * Worker: end subscriptions whose prepaid period is over (`cancelled` when cancel-at-period-end was requested,
 * otherwise `expired`) and send one renewal reminder RENEWAL_REMINDER_DAYS before the period ends.
 */
export async function subscriptionLifecycle(db: Db, notify: NotificationService, now: Date): Promise<number> {
  let n = 0;
  const ended = await db
    .update(subscriptions)
    .set({ status: sql`case when ${subscriptions.cancelAtPeriodEnd} then 'cancelled' else 'expired' end`, updatedAt: now })
    .where(and(eq(subscriptions.status, 'active'), lte(subscriptions.currentPeriodEnd, now)))
    .returning();
  for (const s of ended) {
    n++;
    const [plan] = await db.select({ name: subscriptionPlans.name }).from(subscriptionPlans).where(eq(subscriptionPlans.code, s.planCode));
    await audit(db, SYSTEM_ACTOR, { action: `subscription.${s.status}`, entityType: 'subscription', entityId: s.id });
    await notify.notifyUsers([s.userId], {
      template: 'subscription_ended',
      params: { plan: plan?.name ?? 'Family Care Plan' },
      category: 'payment',
      deepLink: '/subscriptions/me',
      dedupeKey: `subscription_ended:${s.id}`,
    });
  }
  const soon = new Date(now.getTime() + RENEWAL_REMINDER_DAYS * 86400_000);
  const due = await db
    .update(subscriptions)
    .set({ renewalReminderSentAt: now })
    .where(
      and(
        eq(subscriptions.status, 'active'),
        eq(subscriptions.cancelAtPeriodEnd, false),
        isNull(subscriptions.renewalReminderSentAt),
        lte(subscriptions.currentPeriodEnd, soon),
      ),
    )
    .returning();
  for (const s of due) {
    n++;
    const [plan] = await db.select({ name: subscriptionPlans.name }).from(subscriptionPlans).where(eq(subscriptionPlans.code, s.planCode));
    await notify.notifyUsers([s.userId], {
      template: 'subscription_renewal',
      params: { plan: plan?.name ?? 'Family Care Plan', until: s.currentPeriodEnd!.toISOString().slice(0, 10) },
      category: 'payment',
      deepLink: '/subscriptions/me',
      dedupeKey: `subscription_renewal:${s.id}:${s.currentPeriodEnd!.toISOString()}`,
    });
  }
  return n;
}

/** Cancel stale pending subscriptions of a user (and void their pending payments). */
export async function cancelPending(tx: DbOrTx, userId: string): Promise<void> {
  const pending = await tx.select({ id: subscriptions.id }).from(subscriptions).where(and(eq(subscriptions.userId, userId), eq(subscriptions.status, 'pending')));
  if (!pending.length) return;
  const ids = pending.map((p) => p.id);
  await tx.update(subscriptions).set({ status: 'cancelled', updatedAt: new Date() }).where(inArray(subscriptions.id, ids));
  await tx
    .update(payments)
    .set({ status: 'failed', updatedAt: new Date() })
    .where(and(eq(payments.purpose, 'subscription'), inArray(payments.refId, ids), eq(payments.status, 'pending')));
}

export async function latestSubscriptionOf(db: DbOrTx, userId: string): Promise<SubscriptionRow | null> {
  const [row] = await db.select().from(subscriptions).where(eq(subscriptions.userId, userId)).orderBy(desc(subscriptions.createdAt)).limit(1);
  return row ?? null;
}

/** Users with an active subscription whose plan includes a coordinator. */
export async function activeCoordinatorPlanSubscribers(db: DbOrTx, now = new Date()): Promise<string[]> {
  const rows = await db
    .select({ userId: subscriptions.userId })
    .from(subscriptions)
    .innerJoin(subscriptionPlans, eq(subscriptionPlans.code, subscriptions.planCode))
    .where(and(eq(subscriptions.status, 'active'), eq(subscriptionPlans.coordinatorIncluded, true), sql`${subscriptions.currentPeriodEnd} > ${now}`));
  return rows.map((r) => r.userId);
}

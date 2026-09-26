import { randomUUID } from 'node:crypto';
import { and, eq, inArray } from 'drizzle-orm';
import type { Db, DbOrTx } from '../../db/client.js';
import { paymentEvents, payments, patients, refunds, settlementLedger, users, type PaymentCheckoutJson } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import type { Actor } from '../../lib/context.js';
import { AppError, errors } from '../../lib/errors.js';
import { iso } from '../../lib/time.js';
import type { NotificationService } from '../notifications/service.js';
import { toPaise, type GatewayEvent, type PaymentGateway, type PaymentGatewayEvent, type RefundGatewayEvent } from './gateway.js';

export type PaymentRow = typeof payments.$inferSelect;
export type PaymentPurpose = 'appointment' | 'home_visit' | 'pharmacy_order' | 'subscription';

export interface PaymentEffects {
  onSucceeded(db: Db, p: PaymentRow): Promise<void>;
  onFailed(db: Db, p: PaymentRow): Promise<void>;
  /**
   * Called (inside a transaction) before a failed payment is retried: re-open the underlying booking
   * or throw (e.g. SLOT_UNAVAILABLE / CONFLICT) when it can no longer be paid for.
   */
  onRetry?(tx: DbOrTx, p: PaymentRow): Promise<void>;
}

const PURPOSE_LABEL: Record<PaymentPurpose, string> = {
  appointment: 'Doctor consultation',
  home_visit: 'Home visit',
  pharmacy_order: 'Pharmacy order',
  subscription: 'Family Care Plan',
};

export class PaymentService {
  readonly effects: Partial<Record<PaymentPurpose, PaymentEffects>> = {};
  /** Purpose-independent hooks after a payment succeeded (e.g. invoice issuing). Failures are logged, never thrown. */
  readonly afterSucceeded: Array<(p: PaymentRow) => Promise<void>> = [];
  onHookError: ((err: unknown) => void) | null = null;

  constructor(
    private readonly db: Db,
    readonly gateway: PaymentGateway,
    private readonly notify: NotificationService,
  ) {}

  async create(
    tx: DbOrTx,
    p: { purpose: PaymentPurpose; refId: string; patientId: string; amount: number; userId: string | null },
  ): Promise<PaymentRow> {
    const id = randomUUID();
    const { orderId } = await this.gateway.createOrder({ amountPaise: toPaise(p.amount), receipt: id, notes: { paymentId: id, purpose: p.purpose } });
    const checkout = await this.buildCheckout(tx, { purpose: p.purpose, amount: p.amount, orderId, userId: p.userId });
    const [row] = await tx
      .insert(payments)
      .values({
        id,
        purpose: p.purpose,
        refId: p.refId,
        patientId: p.patientId,
        amount: p.amount,
        gateway: this.gateway.name,
        gatewayOrderId: orderId,
        checkout,
        createdByUserId: p.userId,
      })
      .returning();
    return row;
  }

  /** Razorpay Checkout options (contract section 25); null for the mock gateway. */
  private async buildCheckout(
    db: DbOrTx,
    p: { purpose: PaymentPurpose; amount: number; orderId: string; userId: string | null },
  ): Promise<PaymentCheckoutJson | null> {
    if (this.gateway.name !== 'razorpay' || !this.gateway.keyId) return null;
    const [u] = p.userId ? await db.select({ phone: users.phone, name: users.name }).from(users).where(eq(users.id, p.userId)) : [];
    return {
      gateway: 'razorpay',
      keyId: this.gateway.keyId,
      orderId: p.orderId,
      amountPaise: toPaise(p.amount),
      currency: 'INR',
      name: 'CareCompanion',
      description: PURPOSE_LABEL[p.purpose] ?? 'CareCompanion payment',
      prefill: { contact: u?.phone ?? null, name: u?.name ?? null },
    };
  }

  /**
   * Checkout callback (contract section 25): verify HMAC-SHA256(`order_id|payment_id`, key secret) and capture.
   * A payment that already succeeded is returned unchanged.
   */
  async verifyCheckout(
    paymentId: string,
    body: { razorpayPaymentId: string; razorpayOrderId: string; razorpaySignature: string },
    actor: Actor,
  ): Promise<PaymentRow> {
    const [pay] = await this.db.select().from(payments).where(eq(payments.id, paymentId));
    if (!pay) throw errors.notFound('Payment');
    if (pay.gateway !== 'razorpay' || this.gateway.name !== 'razorpay' || !this.gateway.verifyPaymentSignature) {
      throw errors.conflict('This payment does not use Razorpay checkout', { gateway: pay.gateway });
    }
    const valid =
      body.razorpayOrderId === pay.gatewayOrderId &&
      this.gateway.verifyPaymentSignature(body.razorpayOrderId, body.razorpayPaymentId, body.razorpaySignature);
    if (!valid) {
      await audit(this.db, actor, { action: 'payment.verify', entityType: 'payment', entityId: pay.id, outcome: 'denied', metadata: { reason: 'bad_signature' } });
      throw errors.validation('Payment signature verification failed');
    }
    if (pay.status === 'succeeded' || pay.status === 'refunded' || pay.status === 'partially_refunded') return pay;
    await this.applyEvent(
      { eventId: `verify_${body.razorpayPaymentId}`, type: 'payment.captured', orderId: pay.gatewayOrderId, gatewayPaymentId: body.razorpayPaymentId },
      actor,
    );
    const [fresh] = await this.db.select().from(payments).where(eq(payments.id, pay.id));
    return fresh;
  }

  /** New gateway order for a pending/failed payment (contract section 25). Mock: resets to pending. */
  async retry(paymentId: string, actor: Actor): Promise<PaymentRow> {
    const [pay] = await this.db.select().from(payments).where(eq(payments.id, paymentId));
    if (!pay) throw errors.notFound('Payment');
    if (pay.status !== 'pending' && pay.status !== 'failed') throw errors.conflict('Only pending or failed payments can be retried', { status: pay.status });
    const { orderId } = await this.gateway.createOrder({ amountPaise: toPaise(pay.amount), receipt: pay.id, notes: { paymentId: pay.id, retry: 'true' } });
    return this.db.transaction(async (tx) => {
      if (pay.status === 'failed') await this.effects[pay.purpose as PaymentPurpose]?.onRetry?.(tx, pay);
      const checkout = await this.buildCheckout(tx, {
        purpose: pay.purpose as PaymentPurpose,
        amount: pay.amount,
        orderId,
        userId: actor.userId ?? pay.createdByUserId,
      });
      const [row] = await tx
        .update(payments)
        .set({ status: 'pending', gateway: this.gateway.name, gatewayOrderId: orderId, gatewayPaymentId: null, checkout, updatedAt: new Date() })
        .where(and(eq(payments.id, pay.id), eq(payments.status, pay.status)))
        .returning();
      if (!row) throw errors.conflict('Payment changed concurrently; please retry');
      await audit(tx, actor, { action: 'payment.retry', entityType: 'payment', entityId: pay.id, metadata: { previousStatus: pay.status } });
      return row;
    });
  }

  /**
   * Apply a gateway event exactly once (idempotent on gateway event id).
   * Returns applied=false for duplicates.
   */
  async applyEvent(ev: GatewayEvent, actor: Actor): Promise<{ applied: boolean; payment: PaymentRow | null }> {
    if (ev.type === 'refund.processed') return this.applyRefundProcessed(ev, actor);
    return this.applyPaymentEvent(ev, actor);
  }

  private async applyPaymentEvent(ev: PaymentGatewayEvent, actor: Actor): Promise<{ applied: boolean; payment: PaymentRow | null }> {
    const result = await this.db.transaction(async (tx) => {
      const [pay] = await tx.select().from(payments).where(eq(payments.gatewayOrderId, ev.orderId)).limit(1);
      const inserted = await tx
        .insert(paymentEvents)
        .values({ gatewayEventId: ev.eventId, paymentId: pay?.id ?? null, type: ev.type, outcome: pay ? 'received' : 'unknown_order' })
        .onConflictDoNothing()
        .returning({ id: paymentEvents.id });
      if (!inserted.length) return { applied: false, payment: pay ?? null, changed: false };
      if (!pay) return { applied: true, payment: null, changed: false };
      if (pay.status !== 'pending') return { applied: true, payment: pay, changed: false };
      const status = ev.type === 'payment.captured' ? 'succeeded' : 'failed';
      const [updated] = await tx
        .update(payments)
        .set({ status, gatewayPaymentId: ev.gatewayPaymentId, updatedAt: new Date() })
        .where(eq(payments.id, pay.id))
        .returning();
      if (status === 'succeeded') {
        await tx.insert(settlementLedger).values({ paymentId: pay.id, entryType: 'capture', amount: pay.amount });
      }
      await audit(tx, actor, { action: `payment.${status}`, entityType: 'payment', entityId: pay.id, metadata: { eventId: ev.eventId } });
      return { applied: true, payment: updated, changed: true };
    });
    if (result.changed && result.payment) {
      const p = result.payment;
      const fx = this.effects[p.purpose as PaymentPurpose];
      if (p.status === 'succeeded') {
        await fx?.onSucceeded(this.db, p);
        for (const hook of this.afterSucceeded) {
          try {
            await hook(p);
          } catch (err) {
            this.onHookError?.(err);
          }
        }
        await this.notify.notifyPatient(p.patientId, {
          template: 'payment_succeeded',
          params: { amount: p.amount },
          category: 'payment',
          deepLink: `/payments/${p.id}`,
          dedupeKey: `payment_succeeded:${p.id}`,
        });
      } else {
        await fx?.onFailed(this.db, p);
        await this.notify.notifyPatient(p.patientId, {
          template: 'payment_failed',
          params: { amount: p.amount },
          category: 'payment',
          deepLink: `/payments/${p.id}`,
          dedupeKey: `payment_failed:${p.id}`,
        });
      }
    }
    return { applied: result.applied, payment: result.payment };
  }

  /**
   * `refund.processed` webhook: marks our refund row processed. A refund initiated outside the API
   * (e.g. from the Razorpay dashboard) is recorded here so the ledger stays reconciled.
   */
  private async applyRefundProcessed(ev: RefundGatewayEvent, actor: Actor): Promise<{ applied: boolean; payment: PaymentRow | null }> {
    return this.db.transaction(async (tx) => {
      const [pay] = await tx.select().from(payments).where(eq(payments.gatewayPaymentId, ev.gatewayPaymentId)).limit(1);
      const inserted = await tx
        .insert(paymentEvents)
        .values({ gatewayEventId: ev.eventId, paymentId: pay?.id ?? null, type: ev.type, outcome: pay ? 'received' : 'unknown_payment' })
        .onConflictDoNothing()
        .returning({ id: paymentEvents.id });
      if (!inserted.length) return { applied: false, payment: pay ?? null };
      if (!pay) return { applied: true, payment: null };
      const [existing] = await tx.select().from(refunds).where(eq(refunds.gatewayRefundId, ev.refundId));
      if (existing) {
        if (existing.status !== 'processed') await tx.update(refunds).set({ status: 'processed' }).where(eq(refunds.id, existing.id));
        await audit(tx, actor, { action: 'payment.refund_processed', entityType: 'payment', entityId: pay.id, metadata: { eventId: ev.eventId } });
        return { applied: true, payment: pay };
      }
      const amount = ev.amountPaise !== null ? Math.round(ev.amountPaise / 100) : pay.amount - pay.refundedAmount;
      const refundable = Math.min(amount, pay.amount - pay.refundedAmount);
      if (refundable <= 0) return { applied: true, payment: pay };
      await tx.insert(refunds).values({ paymentId: pay.id, amount: refundable, reason: 'gateway_initiated', status: 'processed', gatewayRefundId: ev.refundId });
      await tx.insert(settlementLedger).values({ paymentId: pay.id, entryType: 'refund', amount: -refundable });
      const refunded = pay.refundedAmount + refundable;
      const [row] = await tx
        .update(payments)
        .set({ refundedAmount: refunded, status: refunded >= pay.amount ? 'refunded' : 'partially_refunded', updatedAt: new Date() })
        .where(eq(payments.id, pay.id))
        .returning();
      await audit(tx, actor, { action: 'payment.refund_external', entityType: 'payment', entityId: pay.id, metadata: { eventId: ev.eventId, amount: refundable } });
      return { applied: true, payment: row };
    });
  }

  /** Refund (full by default). Creates refund + negative ledger row. */
  async refund(paymentId: string, opts: { amount?: number; reason: string; actor: Actor }): Promise<PaymentRow> {
    const [pay] = await this.db.select().from(payments).where(eq(payments.id, paymentId));
    if (!pay) throw errors.notFound('Payment');
    if (pay.status !== 'succeeded' && pay.status !== 'partially_refunded') {
      throw errors.conflict('Only successful payments can be refunded', { status: pay.status });
    }
    const remaining = pay.amount - pay.refundedAmount;
    const amount = opts.amount ?? remaining;
    if (!Number.isInteger(amount) || amount <= 0 || amount > remaining) {
      throw errors.validation('Invalid refund amount', { remaining });
    }
    if (this.gateway.name !== pay.gateway) throw new AppError('CONFLICT', `Payment was taken with the ${pay.gateway} gateway, which is not active`);
    const { refundId, status: refundStatus } = await this.gateway.refund({
      orderId: pay.gatewayOrderId,
      gatewayPaymentId: pay.gatewayPaymentId,
      amountPaise: toPaise(amount),
      notes: { paymentId: pay.id },
    });
    const updated = await this.db.transaction(async (tx) => {
      await tx.insert(refunds).values({ paymentId, amount, reason: opts.reason, status: refundStatus, gatewayRefundId: refundId, createdByUserId: opts.actor.userId });
      await tx.insert(settlementLedger).values({ paymentId, entryType: 'refund', amount: -amount });
      const refunded = pay.refundedAmount + amount;
      const [row] = await tx
        .update(payments)
        .set({ refundedAmount: refunded, status: refunded >= pay.amount ? 'refunded' : 'partially_refunded', updatedAt: new Date() })
        .where(eq(payments.id, paymentId))
        .returning();
      await audit(tx, opts.actor, { action: 'payment.refund', entityType: 'payment', entityId: paymentId, metadata: { amount } });
      return row;
    });
    await this.notify.notifyPatient(pay.patientId, {
      template: 'refund',
      params: { amount },
      category: 'payment',
      deepLink: `/payments/${pay.id}`,
    });
    return updated;
  }

  /** Mark a pending payment as failed/voided (e.g. booking cancelled before payment). */
  async voidPending(db: DbOrTx, paymentId: string): Promise<void> {
    await db.update(payments).set({ status: 'failed', updatedAt: new Date() }).where(eq(payments.id, paymentId));
  }
}

export function toPayment(p: PaymentRow) {
  return {
    id: p.id,
    purpose: p.purpose,
    refId: p.refId,
    patientId: p.patientId,
    amount: p.amount,
    currency: 'INR' as const,
    status: p.status,
    gateway: p.gateway,
    gatewayOrderId: p.gatewayOrderId,
    refundedAmount: p.refundedAmount,
    checkout: p.status === 'pending' ? (p.checkout ?? null) : null,
    createdAt: iso(p.createdAt),
  };
}

export async function toPaymentsWithPatient(db: DbOrTx, rows: PaymentRow[]) {
  const ids = [...new Set(rows.map((r) => r.patientId))];
  const names = ids.length ? await db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, ids)) : [];
  const m = new Map(names.map((n) => [n.id, n.name]));
  return rows.map((r) => ({ ...toPayment(r), patientName: m.get(r.patientId) ?? null }));
}

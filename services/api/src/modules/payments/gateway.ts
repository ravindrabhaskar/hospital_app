import { randomUUID } from 'node:crypto';
import { hmacHex, safeEqual } from '../../lib/crypto.js';
import { AppError } from '../../lib/errors.js';
import { HttpError, basicAuth, defaultFetch, requestJson, type FetchLike } from '../../lib/http.js';

/** Gateway abstraction. Amounts cross this boundary in PAISE (API payloads use rupees). */
export interface PaymentGateway {
  readonly name: 'mock' | 'razorpay';
  /** Public key id for client checkout (Razorpay only). */
  readonly keyId?: string | null;
  createOrder(p: { amountPaise: number; receipt: string; notes?: Record<string, string> }): Promise<{ orderId: string }>;
  refund(p: { orderId: string; gatewayPaymentId: string | null; amountPaise: number; notes?: Record<string, string> }): Promise<{
    refundId: string;
    status: 'pending' | 'processed';
  }>;
  /** Checkout signature check: HMAC-SHA256(`${orderId}|${paymentId}`, key secret). */
  verifyPaymentSignature?(orderId: string, paymentId: string, signature: string): boolean;
}

export const toPaise = (rupees: number): number => Math.round(rupees * 100);

export class MockGateway implements PaymentGateway {
  readonly name = 'mock' as const;
  readonly keyId = null;
  async createOrder(): Promise<{ orderId: string }> {
    return { orderId: `order_mock_${randomUUID().replace(/-/g, '').slice(0, 16)}` };
  }
  async refund(): Promise<{ refundId: string; status: 'processed' }> {
    return { refundId: `rfnd_mock_${randomUUID().replace(/-/g, '').slice(0, 16)}`, status: 'processed' };
  }
}

/**
 * Razorpay REST adapter (Orders + Refunds APIs, HTTP basic auth with key id / key secret).
 * https://razorpay.com/docs/api/orders/create/ and https://razorpay.com/docs/api/refunds/create-normal/
 */
export class RazorpayGateway implements PaymentGateway {
  readonly name = 'razorpay' as const;
  constructor(
    readonly keyId: string | undefined,
    private readonly keySecret: string | undefined,
    private readonly opts: { baseUrl?: string; timeoutMs?: number } = {},
    private readonly fetchImpl: FetchLike = defaultFetch,
  ) {}

  private creds(): { id: string; secret: string } {
    if (!this.keyId || !this.keySecret) throw new AppError('DEPENDENCY_UNAVAILABLE', 'Payment gateway is not configured');
    return { id: this.keyId, secret: this.keySecret };
  }

  private async call<T>(path: string, body: Record<string, unknown>): Promise<T> {
    const { id, secret } = this.creds();
    const url = `${(this.opts.baseUrl ?? 'https://api.razorpay.com').replace(/\/$/, '')}${path}`;
    try {
      return await requestJson<T>(this.fetchImpl, url, {
        method: 'POST',
        timeoutMs: this.opts.timeoutMs ?? 10_000,
        headers: { authorization: basicAuth(id, secret), 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
    } catch (err) {
      const status = err instanceof HttpError ? err.status : null;
      const code = err instanceof HttpError ? ((err.body as any)?.error?.code ?? null) : null;
      throw new AppError('DEPENDENCY_UNAVAILABLE', 'Payment gateway is temporarily unavailable', { gateway: 'razorpay', status, code });
    }
  }

  async createOrder(p: { amountPaise: number; receipt: string; notes?: Record<string, string> }): Promise<{ orderId: string }> {
    const res = await this.call<{ id?: string }>('/v1/orders', {
      amount: p.amountPaise,
      currency: 'INR',
      receipt: p.receipt.slice(0, 40),
      notes: p.notes ?? {},
    });
    if (!res?.id) throw new AppError('DEPENDENCY_UNAVAILABLE', 'Payment gateway returned no order id');
    return { orderId: res.id };
  }

  async refund(p: { gatewayPaymentId: string | null; amountPaise: number; notes?: Record<string, string> }): Promise<{
    refundId: string;
    status: 'pending' | 'processed';
  }> {
    if (!p.gatewayPaymentId) throw new AppError('CONFLICT', 'Payment has no gateway payment id; cannot refund');
    const res = await this.call<{ id?: string; status?: string }>(`/v1/payments/${encodeURIComponent(p.gatewayPaymentId)}/refund`, {
      amount: p.amountPaise,
      speed: 'normal',
      notes: p.notes ?? {},
    });
    if (!res?.id) throw new AppError('DEPENDENCY_UNAVAILABLE', 'Payment gateway returned no refund id');
    return { refundId: res.id, status: res.status === 'processed' ? 'processed' : 'pending' };
  }

  verifyPaymentSignature(orderId: string, paymentId: string, signature: string): boolean {
    const { secret } = this.creds();
    if (!/^[0-9a-f]{64}$/i.test(signature)) return false;
    return safeEqual(hmacHex(secret, `${orderId}|${paymentId}`), signature.toLowerCase());
  }
}

/** X-Signature: hex(HMAC-SHA256(rawBody, PAYMENT_WEBHOOK_SECRET)) */
export function verifyWebhookSignature(secret: string, rawBody: Buffer | string, signature: string | undefined): boolean {
  if (!signature || !/^[0-9a-f]{64}$/i.test(signature)) return false;
  return safeEqual(hmacHex(secret, rawBody), signature.toLowerCase());
}

/**
 * Normalised webhook event. Accepted payloads (Razorpay-shaped):
 * { "id"?: "evt_...", "event": "payment.captured" | "payment.failed",
 *   "payload": { "payment": { "entity": { "id": "pay_...", "order_id": "order_...", "amount": 49900 } } } }
 * { "event": "refund.processed", "payload": { "refund": { "entity": { "id": "rfnd_...", "payment_id": "pay_...", "amount": 49900 } } } }
 * Razorpay puts the event id in the `X-Razorpay-Event-Id` header; `X-Event-Id` is also accepted.
 */
export type GatewayEvent =
  | { eventId: string; type: 'payment.captured' | 'payment.failed'; orderId: string; gatewayPaymentId: string | null }
  | { eventId: string; type: 'refund.processed'; refundId: string; gatewayPaymentId: string; amountPaise: number | null };

export type PaymentGatewayEvent = Extract<GatewayEvent, { type: 'payment.captured' | 'payment.failed' }>;
export type RefundGatewayEvent = Extract<GatewayEvent, { type: 'refund.processed' }>;

export function parseWebhookEvent(body: unknown, headerEventId: string | undefined): GatewayEvent | null {
  if (!body || typeof body !== 'object') return null;
  const b = body as Record<string, any>;
  const eventId = (typeof b.id === 'string' && b.id) || headerEventId;
  if (!eventId) return null;
  const type = b.event;
  if (type === 'payment.captured' || type === 'payment.failed') {
    const entity = b.payload?.payment?.entity;
    if (typeof entity?.order_id !== 'string') return null;
    return { eventId, type, orderId: entity.order_id, gatewayPaymentId: typeof entity.id === 'string' ? entity.id : null };
  }
  if (type === 'refund.processed') {
    const r = b.payload?.refund?.entity;
    if (typeof r?.id !== 'string' || typeof r?.payment_id !== 'string') return null;
    return { eventId, type, refundId: r.id, gatewayPaymentId: r.payment_id, amountPaise: typeof r.amount === 'number' ? r.amount : null };
  }
  return null;
}

import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { refunds, users } from '../src/db/schema.js';
import { hmacHex } from '../src/lib/crypto.js';
import { RazorpayGateway } from '../src/modules/payments/gateway.js';
import { fakeFetch } from './fakes.js';
import { SEED_PHONES, firstAvailableSlot, idem, rameshId, setup, type TestCtx } from './helpers.js';

const KEY_ID = 'rzp_test_KEYID123';
const KEY_SECRET = 'rzp_test_secret_value';
const WEBHOOK_SECRET = 'rzp_webhook_secret_value';

let orderSeq = 0;
let refundStatus: 'processed' | 'pending' = 'pending';
const rzp = fakeFetch((c) => {
  if (c.url.endsWith('/v1/orders')) return { body: { id: `order_T${++orderSeq}`, entity: 'order', status: 'created', amount: JSON.parse(c.body).amount } };
  const m = /\/v1\/payments\/([^/]+)\/refund$/.exec(c.url);
  if (m) return { body: { id: `rfnd_T${orderSeq}_${m[1]}`, entity: 'refund', status: refundStatus, amount: JSON.parse(c.body).amount } };
  return { status: 404, body: { error: { code: 'BAD_REQUEST_ERROR' } } };
});

let t: TestCtx;
let vaibhav: string;
let ramesh: string;
let doctorId: string;
let opsToken: string;
let skip = 0;

beforeAll(async () => {
  t = await setup({
    fetchImpl: rzp.fetch,
    config: { PAYMENT_GATEWAY: 'razorpay', RAZORPAY_KEY_ID: KEY_ID, RAZORPAY_KEY_SECRET: KEY_SECRET, RAZORPAY_WEBHOOK_SECRET: WEBHOOK_SECRET },
  });
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  opsToken = (await t.login(SEED_PHONES.ops)).accessToken;
  ramesh = await rameshId(t, vaibhav);
  const docs = await t.req(vaibhav, 'GET', '/doctors?specialty=general_physician');
  doctorId = docs.body.items.find((d: any) => d.name === 'Dr. Ananya Rao').id;
});
afterAll(async () => t.close());

async function book() {
  const slot = await firstAvailableSlot(t, vaibhav, doctorId, skip++);
  const r = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId, slotId: slot.id, mode: 'video', reason: 'Follow-up' }, idem());
  expect(r.status).toBe(201);
  return r.body as { appointment: any; payment: any };
}
const sig = (orderId: string, paymentId: string) => hmacHex(KEY_SECRET, `${orderId}|${paymentId}`);
const webhook = (payload: unknown, eventId: string, secret = WEBHOOK_SECRET) => {
  const raw = JSON.stringify(payload);
  return t.req(null, 'POST', '/webhooks/payments', raw, {
    'content-type': 'application/json',
    'x-razorpay-signature': hmacHex(secret, raw),
    'x-razorpay-event-id': eventId,
  });
};

describe('Razorpay gateway adapter', () => {
  it('creates orders in paise with basic auth', async () => {
    const f = fakeFetch(() => ({ body: { id: 'order_X' } }));
    const gw = new RazorpayGateway('key', 'secret', { baseUrl: 'https://api.razorpay.com' }, f.fetch);
    expect(await gw.createOrder({ amountPaise: 49900, receipt: 'r'.repeat(50) })).toEqual({ orderId: 'order_X' });
    const c = f.calls[0];
    expect(c.url).toBe('https://api.razorpay.com/v1/orders');
    expect(c.headers.authorization).toBe(`Basic ${Buffer.from('key:secret').toString('base64')}`);
    expect(JSON.parse(c.body)).toMatchObject({ amount: 49900, currency: 'INR', receipt: 'r'.repeat(40) });
  });

  it('maps API errors to DEPENDENCY_UNAVAILABLE and requires credentials', async () => {
    const gw = new RazorpayGateway('key', 'secret', {}, fakeFetch(() => ({ status: 401, body: { error: { code: 'BAD_REQUEST_ERROR' } } })).fetch);
    await expect(gw.createOrder({ amountPaise: 100, receipt: 'x' })).rejects.toMatchObject({ code: 'DEPENDENCY_UNAVAILABLE', details: { status: 401 } });
    await expect(new RazorpayGateway(undefined, undefined).createOrder({ amountPaise: 100, receipt: 'x' })).rejects.toMatchObject({ code: 'DEPENDENCY_UNAVAILABLE' });
  });

  it('verifies checkout signatures (HMAC of order_id|payment_id)', () => {
    const gw = new RazorpayGateway(KEY_ID, KEY_SECRET);
    expect(gw.verifyPaymentSignature('order_1', 'pay_1', sig('order_1', 'pay_1'))).toBe(true);
    expect(gw.verifyPaymentSignature('order_1', 'pay_2', sig('order_1', 'pay_1'))).toBe(false);
    expect(gw.verifyPaymentSignature('order_1', 'pay_1', 'nothex')).toBe(false);
  });
});

describe('Razorpay checkout flow', () => {
  it('booking creates a real order and returns the checkout object', async () => {
    const { payment } = await book();
    expect(payment).toMatchObject({ gateway: 'razorpay', status: 'pending', amount: 499 });
    expect(payment.gatewayOrderId).toMatch(/^order_T\d+$/);
    expect(payment.checkout).toEqual({
      gateway: 'razorpay',
      keyId: KEY_ID,
      orderId: payment.gatewayOrderId,
      amountPaise: 49900,
      currency: 'INR',
      name: 'CareCompanion',
      description: 'Doctor consultation',
      prefill: { contact: SEED_PHONES.vaibhav, name: 'Vaibhav Kumar' },
    });
    const pub = await t.req(null, 'GET', '/config/public');
    expect(pub.body.payment).toEqual({ gateway: 'razorpay', razorpayKeyId: KEY_ID });
  });

  it('verify: bad signature -> 400; good signature -> succeeded + appointment confirmed; idempotent duplicate', async () => {
    const { appointment, payment } = await book();
    const bad = await t.req(
      vaibhav,
      'POST',
      `/payments/${payment.id}/verify`,
      { razorpayPaymentId: 'pay_A1', razorpayOrderId: payment.gatewayOrderId, razorpaySignature: sig(payment.gatewayOrderId, 'pay_OTHER') },
      idem(),
    );
    expect(bad.status).toBe(400);
    expect(bad.body.error.code).toBe('VALIDATION_ERROR');

    const body = { razorpayPaymentId: 'pay_A1', razorpayOrderId: payment.gatewayOrderId, razorpaySignature: sig(payment.gatewayOrderId, 'pay_A1') };
    const h = idem();
    const ok = await t.req(vaibhav, 'POST', `/payments/${payment.id}/verify`, body, h);
    expect(ok.status).toBe(200);
    expect(ok.body.status).toBe('succeeded');
    expect(ok.body.checkout).toBeNull();
    const dup = await t.req(vaibhav, 'POST', `/payments/${payment.id}/verify`, body, h);
    expect(dup.status).toBe(200);
    expect(dup.headers['idempotent-replayed']).toBe('true');
    expect(dup.body).toEqual(ok.body);
    const appt = await t.req(vaibhav, 'GET', `/appointments/${appointment.id}`);
    expect(appt.body.status).toBe('confirmed');

    // Razorpay's own payment.captured webhook afterwards is harmless.
    const wh = await webhook({ event: 'payment.captured', payload: { payment: { entity: { id: 'pay_A1', order_id: payment.gatewayOrderId, amount: 49900 } } } }, 'evt_cap_A1');
    expect(wh.status).toBe(200);
    expect(wh.body.duplicate).toBe(false);
    const again = await webhook({ event: 'payment.captured', payload: { payment: { entity: { id: 'pay_A1', order_id: payment.gatewayOrderId } } } }, 'evt_cap_A1');
    expect(again.body.duplicate).toBe(true);
  });

  it('verify requires an Idempotency-Key and the book permission', async () => {
    const { payment } = await book();
    const noKey = await t.req(vaibhav, 'POST', `/payments/${payment.id}/verify`, { razorpayPaymentId: 'p', razorpayOrderId: 'o', razorpaySignature: 's' });
    expect(noKey.status).toBe(400);
    const lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken; // view_records only
    const denied = await t.req(lakshmi, 'POST', `/payments/${payment.id}/verify`, { razorpayPaymentId: 'p', razorpayOrderId: 'o', razorpaySignature: 's' }, idem());
    expect(denied.status).toBe(403);
  });

  it('webhook: signature is checked; payment.failed cancels; retry re-holds the slot with a fresh order', async () => {
    const { appointment, payment } = await book();
    const payload = { event: 'payment.failed', payload: { payment: { entity: { id: 'pay_F1', order_id: payment.gatewayOrderId } } } };
    const forged = await webhook(payload, 'evt_fail_1', 'wrong-secret');
    expect(forged.status).toBe(401);
    const r = await webhook(payload, 'evt_fail_1');
    expect(r.status).toBe(200);
    expect((await t.req(vaibhav, 'GET', `/payments/${payment.id}`)).body.status).toBe('failed');
    expect((await t.req(vaibhav, 'GET', `/appointments/${appointment.id}`)).body.status).toBe('cancelled');

    const retry = await t.req(vaibhav, 'POST', `/payments/${payment.id}/retry`, undefined, idem());
    expect(retry.status).toBe(200);
    expect(retry.body.status).toBe('pending');
    expect(retry.body.gatewayOrderId).not.toBe(payment.gatewayOrderId);
    expect(retry.body.checkout.orderId).toBe(retry.body.gatewayOrderId);
    expect((await t.req(vaibhav, 'GET', `/appointments/${appointment.id}`)).body.status).toBe('pending_payment');

    const newOrder = retry.body.gatewayOrderId;
    const cap = await webhook({ event: 'payment.captured', payload: { payment: { entity: { id: 'pay_F2', order_id: newOrder } } } }, 'evt_cap_F2');
    expect(cap.status).toBe(200);
    expect((await t.req(vaibhav, 'GET', `/appointments/${appointment.id}`)).body.status).toBe('confirmed');
    const notAllowed = await t.req(vaibhav, 'POST', `/payments/${payment.id}/retry`, undefined, idem());
    expect(notAllowed.status).toBe(409);
  });

  it('refund calls the Refunds API; refund.processed marks it processed; idempotent refund request', async () => {
    refundStatus = 'pending';
    const { payment } = await book();
    await t.req(
      vaibhav,
      'POST',
      `/payments/${payment.id}/verify`,
      { razorpayPaymentId: 'pay_R1', razorpayOrderId: payment.gatewayOrderId, razorpaySignature: sig(payment.gatewayOrderId, 'pay_R1') },
      idem(),
    );
    const before = rzp.calls.length;
    const h = idem();
    const r1 = await t.req(opsToken, 'POST', `/payments/${payment.id}/refund`, { reason: 'Doctor unavailable', amount: 200 }, h);
    expect(r1.status).toBe(200);
    expect(r1.body).toMatchObject({ status: 'partially_refunded', refundedAmount: 200 });
    const r2 = await t.req(opsToken, 'POST', `/payments/${payment.id}/refund`, { reason: 'Doctor unavailable', amount: 200 }, h);
    expect(r2.headers['idempotent-replayed']).toBe('true');
    const refundCalls = rzp.calls.slice(before).filter((c) => c.url.includes('/refund'));
    expect(refundCalls).toHaveLength(1);
    expect(refundCalls[0].url).toBe('https://api.razorpay.com/v1/payments/pay_R1/refund');
    expect(JSON.parse(refundCalls[0].body)).toMatchObject({ amount: 20000, speed: 'normal' });

    const [row] = await t.svc.db.select().from(refunds).where(eq(refunds.paymentId, payment.id));
    expect(row.status).toBe('pending');
    const wh = await webhook(
      { event: 'refund.processed', payload: { refund: { entity: { id: row.gatewayRefundId, payment_id: 'pay_R1', amount: 20000 } } } },
      'evt_rf_1',
    );
    expect(wh.status).toBe(200);
    const [after] = await t.svc.db.select().from(refunds).where(eq(refunds.paymentId, payment.id));
    expect(after.status).toBe('processed');

    // A refund made in the Razorpay dashboard is reconciled from the webhook.
    const ext = await webhook({ event: 'refund.processed', payload: { refund: { entity: { id: 'rfnd_dash', payment_id: 'pay_R1', amount: 29900 } } } }, 'evt_rf_2');
    expect(ext.status).toBe(200);
    const p = await t.req(vaibhav, 'GET', `/payments/${payment.id}`);
    expect(p.body).toMatchObject({ status: 'refunded', refundedAmount: 499 });
  });

  it('mock-only confirm is refused while Razorpay is active; X-Signature webhooks keep working', async () => {
    const { payment } = await book();
    const r = await t.req(vaibhav, 'POST', `/payments/${payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    expect(r.status).toBe(403);
    const raw = JSON.stringify({ id: 'evt_legacy_1', event: 'payment.captured', payload: { payment: { entity: { id: 'pay_L', order_id: payment.gatewayOrderId } } } });
    const legacy = await t.req(null, 'POST', '/webhooks/payments', raw, { 'content-type': 'application/json', 'x-signature': hmacHex(t.svc.config.PAYMENT_WEBHOOK_SECRET, raw) });
    expect(legacy.status).toBe(200);
    const [u] = await t.svc.db.select().from(users).where(eq(users.phone, SEED_PHONES.vaibhav));
    expect(u).toBeTruthy();
  });
});

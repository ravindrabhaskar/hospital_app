import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { hmacHex } from '../src/lib/crypto.js';
import { SEED_PHONES, firstAvailableSlot, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let ramesh: string;
let doctorId: string;
beforeAll(async () => {
  t = await setup();
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  ramesh = await rameshId(t, vaibhav);
  const docs = await t.req(vaibhav, 'GET', '/doctors?specialty=general_physician');
  doctorId = docs.body.items.find((d: any) => d.name === 'Dr. Ananya Rao').id;
});
afterAll(async () => t.close());

const book = (slotId: string, headers = idem(), extra: Record<string, unknown> = {}) =>
  t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId, slotId, mode: 'video', reason: 'BP review', ...extra }, headers);

const sign = (body: string) => hmacHex(t.svc.config.PAYMENT_WEBHOOK_SECRET, body);

describe('doctors', () => {
  it('lists only verified doctors with explainable ranking', async () => {
    const r = await t.req(vaibhav, 'GET', '/doctors');
    expect(r.body.items).toHaveLength(4);
    const a = r.body.items.find((d: any) => d.name === 'Dr. Ananya Rao');
    expect(a).toMatchObject({ fees: { video: 499, audio: 499, chat: 399 }, rating: 4.8, ratingCount: 320, verified: true, specialtyName: 'General Physician' });
    expect(Array.isArray(a.rankingFactors)).toBe(true);
    const te = await t.req(vaibhav, 'GET', '/doctors?language=te');
    expect(te.body.items.map((d: any) => d.name)).toContain('Dr. Arjun Reddy');
    const detail = await t.req(vaibhav, 'GET', `/doctors/${doctorId}`);
    expect(detail.body.reviews[0].source).toBe('verified_patient');
  });
});

describe('appointments', () => {
  it('requires Idempotency-Key', async () => {
    const slot = await firstAvailableSlot(t, vaibhav, doctorId);
    const r = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId, slotId: slot.id, mode: 'video', reason: 'x' });
    expect(r.status).toBe(400);
  });

  it('concurrent double booking of one slot: exactly one succeeds', async () => {
    const slot = await firstAvailableSlot(t, vaibhav, doctorId, 3);
    const results = await Promise.all([book(slot.id), book(slot.id), book(slot.id)]);
    const ok = results.filter((r) => r.status === 201);
    const conflicts = results.filter((r) => r.status === 409);
    expect(ok).toHaveLength(1);
    expect(conflicts).toHaveLength(2);
    for (const c of conflicts) expect(c.body.error.code).toBe('SLOT_UNAVAILABLE');
  });

  it('idempotent retry returns the same appointment; mismatched body is rejected', async () => {
    const slot = await firstAvailableSlot(t, vaibhav, doctorId, 5);
    const h = idem();
    const a = await book(slot.id, h);
    const b = await book(slot.id, h);
    expect(a.status).toBe(201);
    expect(b.status).toBe(201);
    expect(b.body).toEqual(a.body);
    expect(b.headers['idempotent-replayed']).toBe('true');
    const c = await book(slot.id, h, { reason: 'different' });
    expect(c.status).toBe(422);
    expect(c.body.error.code).toBe('IDEMPOTENCY_MISMATCH');
  });

  it('booking -> mock payment -> confirmed, episode CARE_SCHEDULED; cancel refunds', async () => {
    const slot = await firstAvailableSlot(t, vaibhav, doctorId, 7);
    const r = await book(slot.id);
    expect(r.status).toBe(201);
    expect(r.body.appointment).toMatchObject({ status: 'pending_payment', fee: 499, doctorName: 'Dr. Ananya Rao', mode: 'video' });
    expect(r.body.payment).toMatchObject({ status: 'pending', amount: 499, currency: 'INR', gateway: 'mock', purpose: 'appointment' });
    const slots = await t.req(vaibhav, 'GET', `/doctors/${doctorId}/slots?date=${slot.startAt.slice(0, 10)}`);
    const held = slots.body.items.find((s: any) => s.id === slot.id);
    if (held) expect(held.status).toBe('held');

    const pay = await t.req(vaibhav, 'POST', `/payments/${r.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    expect(pay.status).toBe(200);
    expect(pay.body.status).toBe('succeeded');
    const appt = await t.req(vaibhav, 'GET', `/appointments/${r.body.appointment.id}`);
    expect(appt.body.status).toBe('confirmed');
    expect(appt.body.videoRoomUrl).toBeTruthy();
    const ep = await t.req(vaibhav, 'GET', `/care-episodes/${appt.body.careEpisodeId}`);
    expect(ep.body.status).toBe('CARE_SCHEDULED');
    expect(ep.body.events.map((e: any) => e.type)).toContain('appointment_booked');

    // doctor queue shows it
    const ananya = (await t.login(SEED_PHONES.ananya)).accessToken;
    const q = await t.req(ananya, 'GET', `/clinician/queue?date=${slot.startAt ? new Date(new Date(slot.startAt).getTime() + 330 * 60_000).toISOString().slice(0, 10) : ''}`);
    expect(q.body.items.some((i: any) => i.id === r.body.appointment.id && i.patientAge === 68)).toBe(true);

    const cancel = await t.req(vaibhav, 'POST', `/appointments/${r.body.appointment.id}/cancel`, { reason: 'Feeling better' });
    expect(cancel.status).toBe(200);
    expect(cancel.body.status).toBe('cancelled');
    const p2 = await t.req(vaibhav, 'GET', `/payments/${r.body.payment.id}`);
    expect(p2.body).toMatchObject({ status: 'refunded', refundedAmount: 499 });
    // slot is bookable again
    const again = await book(slot.id);
    expect(again.status).toBe(201);
  });

  it('reschedule moves to a new slot', async () => {
    const s1 = await firstAvailableSlot(t, vaibhav, doctorId, 9);
    const s2 = await firstAvailableSlot(t, vaibhav, doctorId, 10);
    const r = await book(s1.id);
    const rs = await t.req(vaibhav, 'POST', `/appointments/${r.body.appointment.id}/reschedule`, { slotId: s2.id });
    expect(rs.status).toBe(200);
    expect(rs.body.startAt).toBe(s2.startAt);
    expect((await book(s1.id)).status).toBe(201);
  });
});

describe('payments & webhooks', () => {
  it('webhook: bad signature rejected, duplicate does not double-apply', async () => {
    const slot = await firstAvailableSlot(t, vaibhav, doctorId, 12);
    const r = await book(slot.id);
    const orderId = r.body.payment.gatewayOrderId;
    const payload = JSON.stringify({ id: 'evt_test_1', event: 'payment.captured', payload: { payment: { entity: { id: 'pay_1', order_id: orderId, amount: 49900 } } } });

    const bad = await t.req(null, 'POST', '/webhooks/payments', payload, { 'content-type': 'application/json', 'x-signature': 'f'.repeat(64) });
    expect(bad.status).toBe(401);
    expect((await t.req(vaibhav, 'GET', `/payments/${r.body.payment.id}`)).body.status).toBe('pending');

    const ok1 = await t.req(null, 'POST', '/webhooks/payments', payload, { 'content-type': 'application/json', 'x-signature': sign(payload) });
    expect(ok1.status).toBe(200);
    expect(ok1.body.duplicate).toBe(false);
    const ok2 = await t.req(null, 'POST', '/webhooks/payments', payload, { 'content-type': 'application/json', 'x-signature': sign(payload) });
    expect(ok2.status).toBe(200);
    expect(ok2.body.duplicate).toBe(true);

    const { settlementLedger } = await import('../src/db/schema.js');
    const { eq } = await import('drizzle-orm');
    const ledger = await t.svc.db.select().from(settlementLedger).where(eq(settlementLedger.paymentId, r.body.payment.id));
    expect(ledger).toHaveLength(1);
    const notifs = await t.req(vaibhav, 'GET', '/notifications');
    expect(notifs.body.items.filter((n: any) => n.deepLink === `/appointments/${r.body.appointment.id}` && n.title === 'Appointment confirmed')).toHaveLength(1);
  });

  it('failed payment releases the slot; ops refund requires ops_admin', async () => {
    const slot = await firstAvailableSlot(t, vaibhav, doctorId, 14);
    const r = await book(slot.id);
    const fail = await t.req(vaibhav, 'POST', `/payments/${r.body.payment.id}/confirm-mock`, { outcome: 'failure' }, idem());
    expect(fail.body.status).toBe('failed');
    expect((await t.req(vaibhav, 'GET', `/appointments/${r.body.appointment.id}`)).body.status).toBe('cancelled');
    expect((await book(slot.id)).status).toBe(201);

    const s2 = await firstAvailableSlot(t, vaibhav, doctorId, 16);
    const r2 = await book(s2.id);
    await t.req(vaibhav, 'POST', `/payments/${r2.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    const meera = (await t.login(SEED_PHONES.meera)).accessToken;
    expect((await t.req(meera, 'POST', `/payments/${r2.body.payment.id}/refund`, { reason: 'x' })).status).toBe(403);
    const ops = (await t.login(SEED_PHONES.ops)).accessToken;
    const partial = await t.req(ops, 'POST', `/payments/${r2.body.payment.id}/refund`, { reason: 'goodwill', amount: 100 });
    expect(partial.body).toMatchObject({ status: 'partially_refunded', refundedAmount: 100 });
  });
});

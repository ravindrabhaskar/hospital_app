import { and, eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { users, walletTransactions } from '../src/db/schema.js';
import { creditWallet, expireWalletCredits, processInviteRewards, walletBalance } from '../src/modules/wallet/service.js';
import { SEED_PHONES, firstAvailableSlot, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let admin: string;
let ananya: string;
let ramesh: string;
let vaibhavId: string;
let doctorId: string;
let slotSkip = 0;

const address = { line1: 'Flat 302, Sai Residency', city: 'Hyderabad', pincode: '500034', lat: 17.4126, lng: 78.4392 };
const window = () => {
  const s = new Date(Date.now() + 26 * 3600_000);
  return { preferredStart: s.toISOString(), preferredEnd: new Date(s.getTime() + 2 * 3600_000).toISOString() };
};
const bookVisit = (token: string, extra: Record<string, unknown> = {}, key = idem()) =>
  t.req(token, 'POST', '/home-visits', { patientId: ramesh, serviceCode: 'vitals_check', address, reason: 'BP check', ...window(), ...extra }, key);

beforeAll(async () => {
  t = await setup();
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  admin = (await t.login(SEED_PHONES.admin)).accessToken;
  const a = await t.login(SEED_PHONES.ananya);
  ananya = a.accessToken;
  doctorId = a.user.providerId;
  ramesh = await rameshId(t, vaibhav);
  vaibhavId = (await t.svc.db.select({ id: users.id }).from(users).where(eq(users.phone, SEED_PHONES.vaibhav)))[0].id;
});
afterAll(async () => t.close());

const bookAppointment = async (token: string, patientId: string, extra: Record<string, unknown> = {}, key = idem()) => {
  const slot = await firstAvailableSlot(t, token, doctorId, slotSkip++);
  return t.req(token, 'POST', '/appointments', { patientId, doctorId, slotId: slot.id, mode: 'video', reason: 'Check-up', ...extra }, key);
};

describe('coupons (section 60)', () => {
  it('validate: success, purpose mismatch, minimum amount, unknown code', async () => {
    const ok = await t.req(vaibhav, 'POST', '/coupons/validate', { code: 'welcome100', purpose: 'home_visit', amount: 499 });
    expect(ok.body).toEqual({ valid: true, discount: 100, finalAmount: 399, message: expect.any(String) });
    const purpose = await t.req(vaibhav, 'POST', '/coupons/validate', { code: 'WELCOME100', purpose: 'lab_order', amount: 499 });
    expect(purpose.body).toMatchObject({ valid: false, discount: 0, finalAmount: 499 });
    const min = await t.req(vaibhav, 'POST', '/coupons/validate', { code: 'WELCOME100', purpose: 'home_visit', amount: 200 });
    expect(min.body.valid).toBe(false);
    expect(min.body.message).toMatch(/minimum/i);
    expect((await t.req(vaibhav, 'POST', '/coupons/validate', { code: 'NOPE', purpose: 'home_visit', amount: 499 })).body.valid).toBe(false);
  });

  it('percent coupon with a cap (CARE10 on lab orders)', async () => {
    const small = await t.req(vaibhav, 'POST', '/coupons/validate', { code: 'CARE10', purpose: 'lab_order', amount: 999 });
    expect(small.body).toMatchObject({ valid: true, discount: 99, finalAmount: 900 });
    const big = await t.req(vaibhav, 'POST', '/coupons/validate', { code: 'CARE10', purpose: 'lab_order', amount: 5000 });
    expect(big.body).toMatchObject({ valid: true, discount: 200, finalAmount: 4800 });
  });

  it('expired coupons and admin CRUD (super_admin only, PATCH by id)', async () => {
    const past = { code: 'OLD50', description: 'Expired', type: 'flat', value: 50, appliesTo: ['home_visit'], validFrom: new Date(Date.now() - 10 * 86400_000).toISOString(), validTo: new Date(Date.now() - 86400_000).toISOString(), perUserLimit: 1, active: true };
    expect((await t.req(vaibhav, 'POST', '/admin/coupons', past)).status).toBe(403);
    const c = await t.req(admin, 'POST', '/admin/coupons', past);
    expect(c.status).toBe(201);
    expect((await t.req(admin, 'POST', '/admin/coupons', past)).status).toBe(409);
    const v = await t.req(vaibhav, 'POST', '/coupons/validate', { code: 'OLD50', purpose: 'home_visit', amount: 499 });
    expect(v.body.valid).toBe(false);
    expect(v.body.message).toMatch(/expired/i);
    const p = await t.req(admin, 'PATCH', `/admin/coupons/${c.body.id}`, { validTo: new Date(Date.now() + 86400_000).toISOString() });
    expect(p.status).toBe(200);
    expect((await t.req(vaibhav, 'POST', '/coupons/validate', { code: 'OLD50', purpose: 'home_visit', amount: 499 })).body.valid).toBe(true);
    await t.req(admin, 'PATCH', `/admin/coupons/${c.body.id}`, { active: false });
    expect((await t.req(vaibhav, 'POST', '/coupons/validate', { code: 'OLD50', purpose: 'home_visit', amount: 499 })).body.valid).toBe(false);
    expect((await t.req(admin, 'GET', '/admin/coupons')).body.items.length).toBeGreaterThanOrEqual(3);
  });

  it('an invalid coupon on a booking is a 400; a used coupon hits the per-user limit; a failed payment releases coupon and wallet', async () => {
    const bad = await bookVisit(vaibhav, { couponCode: 'CARE10' });
    expect(bad.status).toBe(400);
    expect(bad.body.error.details.couponCode).toBe('CARE10');
    await creditWallet(t.svc.db, t.svc.config, { userId: vaibhavId, amount: 150, reason: 'test_credit' });
    const r = await bookVisit(vaibhav, { couponCode: 'WELCOME100', useWallet: true });
    expect(r.status).toBe(201);
    expect(r.body.payment).toMatchObject({ discount: 100, walletUsed: 150, amount: 249, status: 'pending', couponCode: 'WELCOME100' });
    expect(await walletBalance(t.svc.db, vaibhavId)).toBe(0);
    const w = await t.req(vaibhav, 'GET', '/wallet');
    expect(w.body.balance).toBe(0);
    expect(w.body.transactions.some((x: any) => x.type === 'debit' && x.amount === 150 && x.refType === 'payment')).toBe(true);
    // per-user limit (1) reached
    const used = await t.req(vaibhav, 'POST', '/coupons/validate', { code: 'WELCOME100', purpose: 'home_visit', amount: 499 });
    expect(used.body.valid).toBe(false);
    // payment failure -> wallet back, coupon released
    const fail = await t.req(vaibhav, 'POST', `/payments/${r.body.payment.id}/confirm-mock`, { outcome: 'failure' }, idem());
    expect(fail.body.status).toBe('failed');
    expect(await walletBalance(t.svc.db, vaibhavId)).toBe(150);
    expect((await t.req(vaibhav, 'POST', '/coupons/validate', { code: 'WELCOME100', purpose: 'home_visit', amount: 499 })).body.valid).toBe(true);
  });
});

describe('wallet (section 60)', () => {
  it('a fully covered payment succeeds immediately, confirms the booking and replays idempotently; cancelling refunds to the wallet', async () => {
    await creditWallet(t.svc.db, t.svc.config, { userId: vaibhavId, amount: 1000, reason: 'test_credit' });
    const before = await walletBalance(t.svc.db, vaibhavId);
    const key = idem();
    const r = await bookAppointment(vaibhav, ramesh, { useWallet: true }, key);
    expect(r.status).toBe(201);
    expect(r.body.payment).toMatchObject({ status: 'succeeded', amount: 0, walletUsed: 499, discount: 0, checkout: null });
    expect(r.body.appointment.status).toBe('confirmed');
    expect(await walletBalance(t.svc.db, vaibhavId)).toBe(before - 499);
    const replay = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId, slotId: '00000000-0000-0000-0000-000000000000', mode: 'video', reason: 'x' }, key);
    expect(replay.status).toBe(422); // a different body with the same key is rejected (never double-charged)
    const cancel = await t.req(vaibhav, 'POST', `/appointments/${r.body.appointment.id}/cancel`, { reason: 'Plans changed' });
    expect(cancel.body.status).toBe('cancelled');
    expect(await walletBalance(t.svc.db, vaibhavId)).toBe(before);
    const pay = await t.req(vaibhav, 'GET', `/payments/${r.body.payment.id}`);
    expect(pay.body.status).toBe('refunded');
  });

  it('same Idempotency-Key and body returns the original response without charging twice', async () => {
    await creditWallet(t.svc.db, t.svc.config, { userId: vaibhavId, amount: 499, reason: 'test_credit' });
    const bal = await walletBalance(t.svc.db, vaibhavId);
    const slot = await firstAvailableSlot(t, vaibhav, doctorId, slotSkip++);
    const body = { patientId: ramesh, doctorId, slotId: slot.id, mode: 'video', reason: 'Follow-up', useWallet: true };
    const key = idem();
    const a = await t.req(vaibhav, 'POST', '/appointments', body, key);
    const b = await t.req(vaibhav, 'POST', '/appointments', body, key);
    expect(b.status).toBe(a.status);
    expect(b.headers['idempotent-replayed']).toBe('true');
    expect(b.body.payment.id).toBe(a.body.payment.id);
    expect(await walletBalance(t.svc.db, vaibhavId)).toBe(bal - 499);
  });

  it('refund to the wallet on cancellation when the user chooses it', async () => {
    const bal = await walletBalance(t.svc.db, vaibhavId);
    const r = await bookVisit(vaibhav);
    await t.req(vaibhav, 'POST', `/payments/${r.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    const c = await t.req(vaibhav, 'POST', `/home-visits/${r.body.homeVisit.id}/cancel`, { reason: 'Not needed', refundTo: 'wallet' });
    expect(c.status).toBe(200);
    expect(await walletBalance(t.svc.db, vaibhavId)).toBe(bal + r.body.payment.amount);
  });

  it('credits expire (365 days by default)', async () => {
    const [row] = await t.svc.db
      .insert(walletTransactions)
      .values({ userId: vaibhavId, type: 'credit', amount: 70, remaining: 70, reason: 'old_promo', expiresAt: new Date(Date.now() - 1000) })
      .returning();
    const bal = await walletBalance(t.svc.db, vaibhavId);
    expect(await expireWalletCredits(t.svc.db, new Date())).toBeGreaterThanOrEqual(1);
    expect(await walletBalance(t.svc.db, vaibhavId)).toBe(bal);
    const deb = await t.svc.db.select().from(walletTransactions).where(and(eq(walletTransactions.refId, row.id), eq(walletTransactions.reason, 'credit_expired')));
    expect(deb[0].amount).toBe(70);
    const w = await t.svc.db.select().from(walletTransactions).where(eq(walletTransactions.userId, vaibhavId));
    expect(w.every((x) => x.remaining >= 0)).toBe(true);
    expect(t.svc.config.WALLET_CREDIT_EXPIRY_DAYS).toBe(365);
  });
});

describe('invites (section 60)', () => {
  it('invite code, redeem rules and the reward after the first completed paid service', async () => {
    const inv = await t.req(vaibhav, 'GET', '/me/invite');
    expect(inv.status).toBe(200);
    expect(inv.body.code).toMatch(/^CC[A-Z0-9]{6}$/);
    expect(inv.body.shareText).toContain(inv.body.code);
    expect((await t.req(vaibhav, 'GET', '/me/invite')).body.code).toBe(inv.body.code);
    expect((await t.req(vaibhav, 'POST', '/me/invite/redeem', { code: inv.body.code })).status).toBeGreaterThanOrEqual(400); // own code / old account
    const s = await t.login('+919855500001');
    const newbie = s.accessToken;
    expect((await t.req(newbie, 'POST', '/me/invite/redeem', { code: 'CCNOTREAL' })).status).toBe(400);
    expect((await t.req(newbie, 'POST', '/me/invite/redeem', { code: inv.body.code })).body).toEqual({ ok: true });
    expect((await t.req(newbie, 'POST', '/me/invite/redeem', { code: inv.body.code })).status).toBe(409);
    const newbieId = s.user.id;
    expect(await processInviteRewards(t.svc.db, t.svc.config, new Date())).toBe(0);
    // first paid service: an appointment, paid and completed
    const a = await bookAppointment(newbie, s.user.selfPatientId);
    expect(a.status).toBe(201);
    await t.req(newbie, 'POST', `/payments/${a.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    expect(await processInviteRewards(t.svc.db, t.svc.config, new Date())).toBe(0); // not completed yet
    await t.req(ananya, 'POST', `/clinician/appointments/${a.body.appointment.id}/start`);
    const done = await t.req(ananya, 'POST', `/clinician/appointments/${a.body.appointment.id}/complete`, { notes: 'OK', outcome: 'resolved' });
    expect(done.status).toBe(200);
    const vBefore = await walletBalance(t.svc.db, vaibhavId);
    expect(await processInviteRewards(t.svc.db, t.svc.config, new Date())).toBe(1);
    expect(await walletBalance(t.svc.db, vaibhavId)).toBe(vBefore + 100);
    expect(await walletBalance(t.svc.db, newbieId)).toBe(100);
    expect(await processInviteRewards(t.svc.db, t.svc.config, new Date())).toBe(0);
    const again = await t.req(vaibhav, 'GET', '/me/invite');
    expect(again.body).toMatchObject({ invitedCount: 1, rewardsEarned: 100 });
  });

  it('redeeming is only possible within 7 days of signup', async () => {
    const s = await t.login('+919855500002');
    await t.svc.db.update(users).set({ createdAt: new Date(Date.now() - 8 * 86400_000) }).where(eq(users.id, s.user.id));
    const code = (await t.req(vaibhav, 'GET', '/me/invite')).body.code;
    expect((await t.req(s.accessToken, 'POST', '/me/invite/redeem', { code })).status).toBe(409);
  });
});

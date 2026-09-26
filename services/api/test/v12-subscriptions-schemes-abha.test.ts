import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { careEpisodes, subscriptions, vitals } from '../src/db/schema.js';
import { hmacHex } from '../src/lib/crypto.js';
import { addDays, istDate, istToUtc } from '../src/lib/time.js';
import { subscriptionLifecycle } from '../src/modules/subscriptions/service.js';
import { fakeFetch } from './fakes.js';
import { SEED_PHONES, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let lakshmi: string;
let lakshmiId: string;
let admin: string;
let ops: string;
let ramesh: string;

beforeAll(async () => {
  t = await setup();
  const v = await t.login(SEED_PHONES.vaibhav);
  vaibhav = v.accessToken;
  const l = await t.login(SEED_PHONES.lakshmi);
  lakshmi = l.accessToken;
  lakshmiId = l.user.id;
  admin = (await t.login(SEED_PHONES.admin)).accessToken;
  ops = (await t.login(SEED_PHONES.ops)).accessToken;
  ramesh = await rameshId(t, vaibhav);
});
afterAll(async () => t.close());

const visitBody = (patientId: string) => {
  const day = addDays(istDate(), 2);
  return {
    patientId,
    serviceCode: 'vitals_check',
    reason: 'BP check',
    address: { line1: 'Flat 302', city: 'Hyderabad', pincode: '500034' },
    preferredStart: istToUtc(day, '10:00').toISOString(),
    preferredEnd: istToUtc(day, '12:00').toISOString(),
  };
};

describe('Family Care Plan subscriptions (section 37)', () => {
  it('plans are listed; no subscription yet', async () => {
    const p = await t.req(vaibhav, 'GET', '/subscription-plans');
    expect(p.body.items.map((x: any) => x.code)).toEqual(['family_basic', 'family_plus']);
    expect(p.body.items[1]).toMatchObject({ priceMonthly: 699, priceYearly: 6999, maxMembers: 6, coordinatorIncluded: true, homeVisitDiscountPct: 15, active: true });
    expect((await t.req(vaibhav, 'GET', '/subscriptions/me')).status).toBe(404);
  });

  it('subscribe (pending) -> payment success activates, applies the home-visit discount and assigns a coordinator', async () => {
    const full = await t.req(vaibhav, 'POST', '/home-visits', visitBody(ramesh), idem());
    expect(full.body.homeVisit).toMatchObject({ price: 499, discountApplied: 0 });
    // an active episode without a coordinator
    const ep = await t.req(vaibhav, 'POST', '/care-episodes', { patientId: ramesh, title: 'Knee pain', concern: 'Knee pain while walking' }, idem());
    expect(ep.body.coordinatorUserId).toBeNull();

    expect((await t.req(vaibhav, 'POST', '/subscriptions', { planCode: 'family_plus', billing: 'monthly' })).status).toBe(400); // Idempotency-Key required
    expect((await t.req(vaibhav, 'POST', '/subscriptions', { planCode: 'nope', billing: 'monthly' }, idem())).status).toBe(400);
    const s = await t.req(vaibhav, 'POST', '/subscriptions', { planCode: 'family_plus', billing: 'monthly' }, idem());
    expect(s.status).toBe(201);
    expect(s.body.subscription).toMatchObject({ planCode: 'family_plus', planName: 'Family Plus', status: 'pending', billing: 'monthly', currentPeriodStart: null, cancelAtPeriodEnd: false });
    expect(s.body.payment).toMatchObject({ purpose: 'subscription', amount: 699, status: 'pending', refId: s.body.subscription.id });
    // A pending subscription gives no discount yet.
    expect((await t.req(vaibhav, 'POST', '/home-visits', visitBody(ramesh), idem())).body.homeVisit.discountApplied).toBe(0);

    const paid = await t.req(vaibhav, 'POST', `/payments/${s.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    expect(paid.body.status).toBe('succeeded');
    const me = await t.req(vaibhav, 'GET', '/subscriptions/me');
    expect(me.body).toMatchObject({ status: 'active', cancelAtPeriodEnd: false });
    expect(me.body.benefits).toContain('Dedicated care coordinator');
    const days = (Date.parse(me.body.currentPeriodEnd) - Date.parse(me.body.currentPeriodStart)) / 86400_000;
    expect(days).toBeGreaterThanOrEqual(28);
    expect(days).toBeLessThanOrEqual(31);

    const hv = await t.req(vaibhav, 'POST', '/home-visits', visitBody(ramesh), idem());
    expect(hv.body.homeVisit).toMatchObject({ price: 424, discountApplied: 75 });
    expect(hv.body.payment.amount).toBe(424);
    // Family grantees do not inherit the subscriber's discount for their own profile.
    const lSelf = (await t.req(lakshmi, 'GET', '/patients')).body.items.find((p: any) => p.isSelf).id;
    expect((await t.req(lakshmi, 'POST', '/home-visits', visitBody(lSelf), idem())).body.homeVisit.discountApplied).toBe(0);

    const [assigned] = await t.svc.db.select().from(careEpisodes).where(eq(careEpisodes.id, ep.body.id));
    expect(assigned.coordinatorUserId).not.toBeNull();
    const inv = await t.req(vaibhav, 'GET', `/payments/${s.body.payment.id}/invoice`);
    expect(inv.body.lines[0].description).toBe('Family Care Plan: Family Plus (monthly)');
    expect((await t.req(vaibhav, 'POST', '/subscriptions', { planCode: 'family_basic', billing: 'yearly' }, idem())).status).toBe(409);
  });

  it('cancel keeps benefits until period end; the worker ends it and sends renewal reminders', async () => {
    const c = await t.req(vaibhav, 'POST', '/subscriptions/me/cancel');
    expect(c.body).toMatchObject({ status: 'active', cancelAtPeriodEnd: true });
    // Lakshmi subscribes yearly to Family Basic.
    const s = await t.req(lakshmi, 'POST', '/subscriptions', { planCode: 'family_basic', billing: 'yearly' }, idem());
    expect(s.body.payment.amount).toBe(2999);
    await t.req(lakshmi, 'POST', `/payments/${s.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    const lsub = (await t.req(lakshmi, 'GET', '/subscriptions/me')).body;
    expect(lsub.status).toBe('active');
    const end = Date.parse(lsub.currentPeriodEnd);
    // 3 days before the end: one renewal reminder (not for Vaibhav, who cancelled).
    await subscriptionLifecycle(t.svc.db, t.svc.notify, new Date(end - 3 * 86400_000));
    await subscriptionLifecycle(t.svc.db, t.svc.notify, new Date(end - 2 * 86400_000));
    const ln = (await t.req(lakshmi, 'GET', '/notifications')).body.items.filter((n: any) => n.title === 'Family Care Plan renewal');
    expect(ln).toHaveLength(1);
    expect((await t.req(vaibhav, 'GET', '/notifications')).body.items.some((n: any) => n.title === 'Family Care Plan renewal')).toBe(false);
    // After the period: Vaibhav -> cancelled (requested), Lakshmi -> expired.
    await subscriptionLifecycle(t.svc.db, t.svc.notify, new Date(end + 60_000));
    expect((await t.req(vaibhav, 'GET', '/subscriptions/me')).body.status).toBe('cancelled');
    expect((await t.req(lakshmi, 'GET', '/subscriptions/me')).body.status).toBe('expired');
    const [row] = await t.svc.db.select().from(subscriptions).where(eq(subscriptions.userId, lakshmiId));
    expect(row.status).toBe('expired');
  });

  it('cancelling a pending subscription voids its payment; admin plan CRUD', async () => {
    const x = await t.login('+919855500001');
    const s = await t.req(x.accessToken, 'POST', '/subscriptions', { planCode: 'family_basic', billing: 'monthly' }, idem());
    const c = await t.req(x.accessToken, 'POST', '/subscriptions/me/cancel');
    expect(c.body.status).toBe('cancelled');
    expect((await t.req(x.accessToken, 'GET', `/payments/${s.body.payment.id}`)).body.status).toBe('failed');
    expect((await t.req(x.accessToken, 'POST', '/subscriptions/me/cancel')).status).toBe(404);

    const plan = { code: 'senior_care', name: 'Senior Care', description: 'Pilot', priceMonthly: 999, priceYearly: 9999, benefits: ['Weekly nurse call'], maxMembers: 2, coordinatorIncluded: true, homeVisitDiscountPct: 20, active: false };
    expect((await t.req(ops, 'POST', '/admin/subscription-plans', plan)).status).toBe(403);
    const cr = await t.req(admin, 'POST', '/admin/subscription-plans', plan);
    expect(cr.status).toBe(201);
    expect((await t.req(admin, 'POST', '/admin/subscription-plans', plan)).status).toBe(409);
    expect((await t.req(vaibhav, 'GET', '/subscription-plans')).body.items.map((p: any) => p.code)).not.toContain('senior_care');
    expect((await t.req(admin, 'GET', '/admin/subscription-plans')).body.items.map((p: any) => p.code)).toContain('senior_care');
    const up = await t.req(admin, 'PATCH', '/admin/subscription-plans/senior_care', { active: true, priceMonthly: 899 });
    expect(up.body).toMatchObject({ active: true, priceMonthly: 899 });
    expect((await t.req(vaibhav, 'GET', '/subscription-plans')).body.items.map((p: any) => p.code)).toContain('senior_care');
    expect((await t.req(admin, 'PATCH', '/admin/subscription-plans/unknown_plan', { active: true })).status).toBe(404);
  });
});

describe('subscriptions with the Razorpay gateway (section 37)', () => {
  const KEY_ID = 'rzp_test_SUBS';
  const KEY_SECRET = 'rzp_test_subs_secret';
  let seq = 0;
  const rzp = fakeFetch((c) => (c.url.endsWith('/v1/orders') ? { body: { id: `order_S${++seq}` } } : { status: 404, body: {} }));
  let r: TestCtx;
  beforeAll(async () => {
    r = await setup({ fetchImpl: rzp.fetch, config: { PAYMENT_GATEWAY: 'razorpay', RAZORPAY_KEY_ID: KEY_ID, RAZORPAY_KEY_SECRET: KEY_SECRET, RAZORPAY_WEBHOOK_SECRET: 'whsec_subs_0123456789' } });
  });
  afterAll(async () => r.close());

  it('creates a Razorpay order with checkout options and activates on verified payment', async () => {
    const v = (await r.login(SEED_PHONES.vaibhav)).accessToken;
    const s = await r.req(v, 'POST', '/subscriptions', { planCode: 'family_basic', billing: 'monthly' }, idem());
    expect(s.status).toBe(201);
    expect(s.body.payment).toMatchObject({ gateway: 'razorpay', amount: 299 });
    expect(s.body.payment.checkout).toMatchObject({ gateway: 'razorpay', keyId: KEY_ID, amountPaise: 29900, description: 'Family Care Plan' });
    const orderId = s.body.payment.gatewayOrderId;
    const ok = await r.req(v, 'POST', `/payments/${s.body.payment.id}/verify`, { razorpayOrderId: orderId, razorpayPaymentId: 'pay_SUB1', razorpaySignature: hmacHex(KEY_SECRET, `${orderId}|pay_SUB1`) }, idem());
    expect(ok.body.status).toBe('succeeded');
    expect((await r.req(v, 'GET', '/subscriptions/me')).body.status).toBe('active');
  });
});

describe('government schemes (section 38)', () => {
  it('published schemes only, with state filtering and no admin notes', async () => {
    const all = await t.req(vaibhav, 'GET', '/schemes');
    expect(all.status).toBe(200);
    expect(all.body.items).toHaveLength(3);
    for (const s of all.body.items) {
      expect(s.officialUrl).toMatch(/^https:\/\//);
      expect(s.disclaimer).toMatch(/does not decide or confirm eligibility/);
      expect(s).not.toHaveProperty('internalNote');
      expect(s.status).toBe('published');
    }
    expect(all.body.items.map((s: any) => s.officialUrl).sort()).toEqual(['https://cghs.mohfw.gov.in', 'https://pmjay.gov.in', 'https://www.aarogyasri.telangana.gov.in']);
    expect((await t.req(vaibhav, 'GET', '/schemes?state=telangana')).body.items).toHaveLength(3);
    const ka = await t.req(vaibhav, 'GET', '/schemes?state=Karnataka');
    expect(ka.body.items.every((s: any) => s.level === 'central')).toBe(true);
    expect(ka.body.items).toHaveLength(2);
  });

  it('drafts are admin-only; admin sees the content-review note', async () => {
    const adm = await t.req(admin, 'GET', '/admin/schemes');
    expect(adm.body.items.every((s: any) => s.internalNote?.includes('[REQUIRES CONTENT REVIEW]'))).toBe(true);
    const draft = await t.req(admin, 'POST', '/admin/schemes', {
      name: 'Draft State Scheme',
      authority: 'State Health Department',
      level: 'state',
      state: 'Telangana',
      summary: 'Draft summary.',
      benefits: [],
      eligibilityHints: [],
      documentsTypicallyNeeded: [],
      officialUrl: 'https://example.gov.in',
      helpline: null,
      status: 'draft',
    });
    expect(draft.status).toBe(201);
    expect(draft.body.disclaimer).toMatch(/Information only/);
    expect((await t.req(vaibhav, 'GET', `/schemes/${draft.body.id}`)).status).toBe(404);
    expect((await t.req(vaibhav, 'GET', '/schemes')).body.items.map((s: any) => s.id)).not.toContain(draft.body.id);
    expect((await t.req(admin, 'POST', '/admin/schemes', { ...draft.body, id: undefined, officialUrl: 'http://insecure.example' })).status).toBe(400);
    const pub = await t.req(admin, 'PATCH', `/admin/schemes/${draft.body.id}`, { status: 'published' });
    expect(pub.body.status).toBe('published');
    expect((await t.req(vaibhav, 'GET', `/schemes/${draft.body.id}`)).status).toBe(200);
    expect((await t.req(admin, 'PATCH', `/admin/schemes/${draft.body.id}`, { state: null })).status).toBe(400);
    expect((await t.req(ops, 'GET', '/admin/schemes')).status).toBe(403);
  });

  it('govt_schemes flag defaults on and gates the endpoints', async () => {
    expect((await t.req(null, 'GET', '/config/public')).body.flags.govt_schemes).toBe(true);
    await t.req(admin, 'PUT', '/admin/feature-flags/govt_schemes', { enabled: false });
    expect((await t.req(vaibhav, 'GET', '/schemes')).status).toBe(403);
    await t.req(admin, 'PUT', '/admin/feature-flags/govt_schemes', { enabled: true });
    expect((await t.req(vaibhav, 'GET', '/schemes')).status).toBe(200);
  });
});

describe('ABHA (section 39)', () => {
  it('validates and normalises ABHA number/address; changes reset verification', async () => {
    const r = await t.req(vaibhav, 'PATCH', `/patients/${ramesh}`, { abhaNumber: '91 2345 6789 0123', abhaAddress: 'Ramesh.Kumar@SBX' });
    expect(r.status).toBe(200);
    expect(r.body.abha).toEqual({ number: '91-2345-6789-0123', address: 'ramesh.kumar@sbx', status: 'unverified' });
    expect((await t.req(vaibhav, 'PATCH', `/patients/${ramesh}`, { abhaNumber: '1234' })).status).toBe(400);
    expect((await t.req(vaibhav, 'PATCH', `/patients/${ramesh}`, { abhaAddress: 'ramesh@gmail.com' })).status).toBe(400);
    expect((await t.req(lakshmi, 'PATCH', `/patients/${ramesh}`, { abhaNumber: '12345678901234' })).status).toBe(403);
    expect((await t.req(lakshmi, 'GET', `/patients/${ramesh}`)).body.abha.number).toBe('91-2345-6789-0123');
    const cleared = await t.req(vaibhav, 'PATCH', `/patients/${ramesh}`, { abhaNumber: null, abhaAddress: null });
    expect(cleared.body.abha).toBeNull();
    const self = (await t.req(vaibhav, 'GET', '/patients')).body.items.find((p: any) => p.isSelf).id;
    expect((await t.req(vaibhav, 'GET', `/patients/${self}`)).body.abha).toBeNull();
  });

  it('verify returns 503 DEPENDENCY_UNAVAILABLE until ABDM is certified', async () => {
    await t.req(vaibhav, 'PATCH', `/patients/${ramesh}`, { abhaNumber: '12345678901234' });
    const r = await t.req(vaibhav, 'POST', `/patients/${ramesh}/abha/verify`);
    expect(r.status).toBe(503);
    expect(r.body.error).toMatchObject({ code: 'DEPENDENCY_UNAVAILABLE', message: 'ABDM integration pending sandbox certification' });
    expect((await t.req(lakshmi, 'POST', `/patients/${ramesh}/abha/verify`)).status).toBe(403);
    const enabled = await setup({ config: { ABDM_ENABLED: true } });
    try {
      const v = (await enabled.login(SEED_PHONES.vaibhav)).accessToken;
      const rid = await rameshId(enabled, v);
      await enabled.req(v, 'PATCH', `/patients/${rid}`, { abhaAddress: 'ramesh@abdm' });
      expect((await enabled.req(v, 'POST', `/patients/${rid}/abha/verify`)).status).toBe(503);
    } finally {
      await enabled.close();
    }
  });
});

describe('device features (section 40): Health Connect / Apple Health sync', () => {
  it('accepts health_connect and apple_health connections and all synced types', async () => {
    for (const provider of ['health_connect', 'apple_health']) {
      const c = await t.req(vaibhav, 'POST', '/wearables/connections', { patientId: ramesh, provider });
      expect([200, 201]).toContain(c.status);
      const at = new Date(Date.now() - 3600_000).toISOString();
      const s = await t.req(vaibhav, 'POST', '/wearables/sync', {
        patientId: ramesh,
        provider,
        measurements: [
          { type: 'steps', value: 4200, unit: 'count', measuredAt: at },
          { type: 'pulse', value: 72, unit: 'bpm', measuredAt: at },
          { type: 'sleep_minutes', value: 410, unit: 'min', measuredAt: at },
          { type: 'spo2', value: 97, unit: '%', measuredAt: at },
          { type: 'bp_systolic', value: 128, unit: 'mmHg', measuredAt: at },
          { type: 'bp_diastolic', value: 82, unit: 'mmHg', measuredAt: at },
          { type: 'blood_glucose', value: 118, unit: 'mg/dL', measuredAt: at },
          { type: 'weight', value: 73.5, unit: 'kg', measuredAt: at },
        ],
      });
      expect(s.body).toEqual({ accepted: 8 });
    }
    const rows = await t.svc.db.select().from(vitals).where(eq(vitals.patientId, ramesh));
    expect(rows.filter((x) => x.source === 'device' && x.type === 'steps').length).toBeGreaterThanOrEqual(2);
  });

  it('a resent reading replaces the earlier one from the same provider (no duplicate totals)', async () => {
    await t.req(vaibhav, 'POST', '/wearables/connections', { patientId: ramesh, provider: 'health_connect' });
    const at = new Date(Date.now() - 7200_000).toISOString();
    for (const value of [1000, 2500, 3100]) {
      const s = await t.req(vaibhav, 'POST', '/wearables/sync', {
        patientId: ramesh,
        provider: 'health_connect',
        measurements: [{ type: 'steps', value, unit: 'count', measuredAt: at }, { type: 'steps', value, unit: 'count', measuredAt: at }],
      });
      expect(s.status).toBe(200);
    }
    const rows = await t.svc.db.select().from(vitals).where(eq(vitals.patientId, ramesh));
    const same = rows.filter((x) => x.source === 'device' && x.type === 'steps' && x.measuredAt.toISOString() === at);
    expect(same.map((x) => x.value)).toEqual([3100]);
  });
});

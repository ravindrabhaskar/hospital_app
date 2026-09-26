import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { SEED_PHONES, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());

describe('system', () => {
  it('health and ready', async () => {
    const h = await t.req(null, 'GET', '/api/v1/health');
    expect(h.status).toBe(200);
    expect(h.body).toEqual({ status: 'ok', version: '1.0.0' });
    const r = await t.req(null, 'GET', '/api/v1/ready');
    expect(r.status).toBe(200);
    expect(r.body.checks).toEqual({ db: 'ok', ai: 'ok', safetyRules: 'fixture', storage: 'ok', worker: 'disabled' }); // v1.1 §28
  });

  it('echoes correlation id and uses the error envelope', async () => {
    const r = await t.req(null, 'GET', '/me', undefined, { 'x-correlation-id': 'abc-123' });
    expect(r.status).toBe(401);
    expect(r.headers['x-correlation-id']).toBe('abc-123');
    expect(r.body.error).toMatchObject({ code: 'UNAUTHENTICATED', correlationId: 'abc-123' });
  });
});

describe('auth', () => {
  it('OTP flow returns a session and Me', async () => {
    const r1 = await t.req(null, 'POST', '/auth/otp/request', { phone: SEED_PHONES.vaibhav });
    expect(r1.status).toBe(200);
    expect(r1.body.devOtp).toBe('123456');
    const r2 = await t.req(null, 'POST', '/auth/otp/verify', { phone: SEED_PHONES.vaibhav, otp: '123456', deviceName: 'test' });
    expect(r2.status).toBe(200);
    expect(r2.body.expiresIn).toBe(900);
    expect(r2.body.user).toMatchObject({ phone: SEED_PHONES.vaibhav, roles: ['patient'], onboardingComplete: true, mfaRequired: false, providerId: null });
    const me = await t.req(r2.body.accessToken, 'GET', '/me');
    expect(me.status).toBe(200);
    expect(me.body.selfPatientId).toBeTruthy();
  });

  it('new phone auto-registers as patient with onboarding incomplete', async () => {
    const s = await t.login('+919811111111');
    expect(s.user.roles).toEqual(['patient']);
    expect(s.user.onboardingComplete).toBe(false);
    expect(s.user.selfPatientId).toBeTruthy();
    const patients = await t.req(s.accessToken, 'GET', '/patients');
    expect(patients.body.items).toHaveLength(1);
    expect(patients.body.items[0]).toMatchObject({ isSelf: true, relation: 'self' });
    for (const purpose of ['terms', 'privacy', 'health_data_processing']) {
      const c = await t.req(s.accessToken, 'POST', '/consents', { purpose, version: '1.0' });
      expect(c.status).toBe(201);
    }
    const me = await t.req(s.accessToken, 'PATCH', '/me', { name: 'Test User' });
    expect(me.body.onboardingComplete).toBe(true);
  });

  it('staff get mfaRequired and providerId', async () => {
    const s = await t.login(SEED_PHONES.ananya);
    expect(s.user.mfaRequired).toBe(true);
    expect(s.user.providerId).toBeTruthy();
  });

  it('wrong OTP is rejected and attempts are limited', async () => {
    const phone = '+919822222222';
    await t.req(null, 'POST', '/auth/otp/request', { phone });
    for (let i = 0; i < 5; i++) {
      const r = await t.req(null, 'POST', '/auth/otp/verify', { phone, otp: '000000' });
      expect(r.status).toBe(401);
      expect(r.body.error.code).toBe('UNAUTHENTICATED');
    }
    const locked = await t.req(null, 'POST', '/auth/otp/verify', { phone, otp: '123456' });
    expect(locked.status).toBe(429);
    expect(locked.body.error.code).toBe('RATE_LIMITED');
  });

  it('OTP request is rate limited per phone', async () => {
    const t2 = await setup({ config: { OTP_MAX_REQUESTS: 5 } });
    try {
      const phone = '+919833333333';
      for (let i = 0; i < 5; i++) expect((await t2.req(null, 'POST', '/auth/otp/request', { phone })).status).toBe(200);
      const r = await t2.req(null, 'POST', '/auth/otp/request', { phone });
      expect(r.status).toBe(429);
      expect(r.body.error.code).toBe('RATE_LIMITED');
    } finally {
      await t2.close();
    }
  });

  it('refresh rotates; reused and revoked refresh tokens fail', async () => {
    const s = await t.login(SEED_PHONES.lakshmi);
    const r1 = await t.req(null, 'POST', '/auth/refresh', { refreshToken: s.refreshToken });
    expect(r1.status).toBe(200);
    expect(r1.body.refreshToken).not.toBe(s.refreshToken);
    // reuse of the old token -> rejected and whole session revoked
    const reuse = await t.req(null, 'POST', '/auth/refresh', { refreshToken: s.refreshToken });
    expect(reuse.status).toBe(401);
    const afterReuse = await t.req(null, 'POST', '/auth/refresh', { refreshToken: r1.body.refreshToken });
    expect(afterReuse.status).toBe(401);

    const s2 = await t.login(SEED_PHONES.lakshmi);
    const out = await t.req(null, 'POST', '/auth/logout', { refreshToken: s2.refreshToken });
    expect(out.status).toBe(204);
    const revoked = await t.req(null, 'POST', '/auth/refresh', { refreshToken: s2.refreshToken });
    expect(revoked.status).toBe(401);
    // access token of a logged-out session is rejected too
    const me = await t.req(s2.accessToken, 'GET', '/me');
    expect(me.status).toBe(401);
  });
});

describe('role boundaries', () => {
  it('patient cannot reach /clinician, /ops, /admin', async () => {
    const { accessToken } = await t.login(SEED_PHONES.vaibhav);
    for (const url of ['/clinician/queue', '/ops/overview', '/admin/users', '/admin/audit-logs', '/admin/feature-flags', '/provider/me']) {
      const r = await t.req(accessToken, 'GET', url);
      expect(r.status, url).toBe(403);
      expect(r.body.error.code).toBe('FORBIDDEN');
    }
  });

  it('coordinator can read ops but cannot write admin', async () => {
    const { accessToken } = await t.login(SEED_PHONES.meera);
    expect((await t.req(accessToken, 'GET', '/ops/overview')).status).toBe(200);
    const w1 = await t.req(accessToken, 'PUT', '/admin/feature-flags/ai_assistant', { enabled: false });
    expect(w1.status).toBe(403);
    const w2 = await t.req(accessToken, 'POST', '/admin/staff', { phone: '+919844444444', name: 'X', roles: ['doctor'] });
    expect(w2.status).toBe(403);
    const w3 = await t.req(accessToken, 'POST', '/admin/safety-rule-packs', { version: 'x', rules: [] });
    expect(w3.status).toBe(403);
  });

  it('doctor cannot read an unrelated patient snapshot (and denial is audited)', async () => {
    const vaibhav = await t.login(SEED_PHONES.vaibhav);
    const rid = await rameshId(t, vaibhav.accessToken);
    const priya = await t.login(SEED_PHONES.priya); // no relationship with Ramesh
    const r = await t.req(priya.accessToken, 'GET', `/clinician/patients/${rid}/snapshot`);
    expect(r.status).toBe(403);
    const ananya = await t.login(SEED_PHONES.ananya); // treating doctor
    const ok = await t.req(ananya.accessToken, 'GET', `/clinician/patients/${rid}/snapshot`);
    expect(ok.status).toBe(200);
    expect(ok.body.patient.name).toBe('Ramesh Kumar');
    expect(ok.body.aiSummary.advisory).toBe(true);
    expect(ok.body.aiSummary.claims.length).toBeGreaterThan(0);

    const admin = await t.login(SEED_PHONES.admin);
    const logs = await t.req(admin.accessToken, 'GET', `/admin/audit-logs?entityId=${rid}&action=clinician.snapshot`);
    expect(logs.body.items.some((l: any) => l.outcome === 'denied')).toBe(true);
    expect(logs.body.items.some((l: any) => l.outcome === 'success')).toBe(true);
  });

  it('ops_admin reads audit logs; admin disables a user and sessions die', async () => {
    const ops = await t.login(SEED_PHONES.ops);
    expect((await t.req(ops.accessToken, 'GET', '/admin/audit-logs')).status).toBe(200);
    expect((await t.req(ops.accessToken, 'GET', '/admin/analytics')).status).toBe(200);
    expect((await t.req(ops.accessToken, 'GET', '/admin/users')).status).toBe(403);

    const victim = await t.login('+919855555555');
    const admin = await t.login(SEED_PHONES.admin);
    const d = await t.req(admin.accessToken, 'POST', `/admin/users/${victim.user.id}/disable`);
    expect(d.status).toBe(200);
    expect(d.body.status).toBe('disabled');
    expect((await t.req(victim.accessToken, 'GET', '/me')).status).toBe(401);
    expect((await t.req(null, 'POST', '/auth/refresh', { refreshToken: victim.refreshToken })).status).toBe(401);
  });

  it('audit log is append-only at the database level', async () => {
    const { sql } = await import('drizzle-orm');
    await expect(t.svc.db.execute(sql`delete from audit_logs`)).rejects.toThrow();
    await expect(t.svc.db.execute(sql`update episode_events set description = 'x'`)).rejects.toThrow();
  });
});

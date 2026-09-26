import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createDb, type DbHandle } from '../src/db/client.js';
import { users } from '../src/db/schema.js';
import { SEED_PHONES, idem, setup, type TestCtx } from './helpers.js';

/** Production-mode safety guarantees (PGlite handle injected; DATABASE_URL only satisfies config validation). */
let t: TestCtx;
let handle: DbHandle;
let token: string;
beforeAll(async () => {
  handle = await createDb({ pgliteDir: 'memory://' });
  t = await setup({
    dbHandle: handle,
    config: { NODE_ENV: 'production', DATABASE_URL: 'postgres://injected-for-test', JWT_SECRET: 'p'.repeat(48), PAYMENT_WEBHOOK_SECRET: 'w'.repeat(32) },
  });
  const [u] = await t.svc.db.select().from(users).where(eq(users.phone, SEED_PHONES.vaibhav));
  token = (await t.svc.auth.issueSession(u.id, 'test')).accessToken;
});
afterAll(async () => {
  await t.close();
  await handle.close();
});

describe('production mode', () => {
  it('never returns devOtp', async () => {
    const r = await t.req(null, 'POST', '/auth/otp/request', { phone: '+919877777777' });
    expect(r.status).toBe(200);
    expect(r.body.devOtp).toBeUndefined();
  });

  it('refuses to serve the unapproved fixture pack (fail safe -> consult a doctor)', async () => {
    const ready = await t.req(null, 'GET', '/api/v1/ready');
    expect(ready.status).toBe(503);
    expect(ready.body.checks.safetyRules).toBe('unavailable');
    const res = await t.svc.safety.evaluate({ text: 'mild cough' });
    expect(res.level).toBe('urgent');
    expect(res.triggeredRules[0].action).toBe('suggest_doctor');
    const e = await t.svc.safety.evaluate({ text: 'chest pain' });
    expect(e.level).not.toBe('none');
  });

  it('refuses to activate an unapproved pack', async () => {
    const [admin] = await t.svc.db.select().from(users).where(eq(users.phone, SEED_PHONES.admin));
    const at = (await t.svc.auth.issueSession(admin.id, null)).accessToken;
    const packs = await t.req(at, 'GET', '/admin/safety-rule-packs');
    const fixture = packs.body.items[0];
    const r = await t.req(at, 'POST', `/admin/safety-rule-packs/${fixture.id}/activate`);
    expect(r.status).toBe(409);
    const ap = await t.req(at, 'POST', `/admin/safety-rule-packs/${fixture.id}/approve`, { approverName: 'Dr X', approverRegistration: 'REG1' });
    expect(ap.status).toBe(409); // FIXTURE rules cannot be approved
  });

  it('confirm-mock is disabled', async () => {
    const r = await t.req(token, 'POST', '/payments/00000000-0000-4000-8000-000000000000/confirm-mock', { outcome: 'success' }, idem());
    expect(r.status).toBe(403);
  });
});

import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { sessions, users } from '../src/db/schema.js';
import { base32Encode, decryptSecret, encryptSecret } from '../src/lib/crypto.js';
import { hotp, totp, verifyTotp } from '../src/modules/auth/totp.js';
import { SEED_PHONES, setup, type TestCtx } from './helpers.js';

describe('TOTP primitives', () => {
  it('matches the RFC 6238 SHA-1 test vectors', () => {
    const secret = base32Encode(Buffer.from('12345678901234567890'));
    // RFC 6238 Appendix B (8 digits) -> last 6 digits
    expect(totp(secret, 59_000)).toBe('287082');
    expect(totp(secret, 1111111109_000)).toBe('081804');
    expect(totp(secret, 1234567890_000)).toBe('005924');
    expect(totp(secret, 2000000000_000)).toBe('279037');
    expect(hotp(secret, 0)).toBe('755224'); // RFC 4226
  });

  it('accepts +/-1 step, rejects replays and garbage', () => {
    const secret = base32Encode(Buffer.from('12345678901234567890'));
    const now = 1_700_000_000_000;
    const step = verifyTotp(secret, totp(secret, now - 30_000), { timeMs: now });
    expect(step).toBe(Math.floor(now / 30_000) - 1);
    expect(verifyTotp(secret, totp(secret, now - 90_000), { timeMs: now })).toBeNull();
    expect(verifyTotp(secret, totp(secret, now), { timeMs: now, lastStep: Math.floor(now / 30_000) })).toBeNull();
    expect(verifyTotp(secret, 'abcdef', { timeMs: now })).toBeNull();
  });

  it('AES-256-GCM round trip and tamper detection', () => {
    const key = Buffer.alloc(32, 7);
    const enc = encryptSecret(key, 'JBSWY3DPEHPK3PXP');
    expect(enc).not.toContain('JBSWY3DPEHPK3PXP');
    expect(decryptSecret(key, enc)).toBe('JBSWY3DPEHPK3PXP');
    const parts = enc.split('.');
    parts[3] = Buffer.from('tampered').toString('base64url');
    expect(() => decryptSecret(key, parts.join('.'))).toThrow();
    expect(() => decryptSecret(Buffer.alloc(32, 8), enc)).toThrow();
  });
});

describe('staff MFA with MFA_ENFORCED=true', () => {
  let t: TestCtx;
  beforeAll(async () => {
    t = await setup({ config: { MFA_ENFORCED: true, MFA_ENCRYPTION_KEY: 'ab'.repeat(32) } });
  });
  afterAll(async () => t.close());

  it('enrol -> confirm -> verified session survives refresh; new sessions need verify; recovery codes are single use', async () => {
    const login = await t.login(SEED_PHONES.ananya);
    expect(login.user).toMatchObject({ mfaRequired: true, mfaEnrolled: false, mfaVerified: false });
    const tok = login.accessToken;

    // Gated until MFA passes; /me and /config/public stay reachable.
    const gated = await t.req(tok, 'GET', '/clinician/queue');
    expect(gated.status).toBe(403);
    expect(gated.body.error.code).toBe('MFA_REQUIRED');
    expect((await t.req(tok, 'GET', '/me')).status).toBe(200);
    expect((await t.req(tok, 'GET', '/config/public')).status).toBe(200);

    const enr = await t.req(tok, 'POST', '/auth/mfa/totp/enroll');
    expect(enr.status).toBe(200);
    expect(enr.body.secret).toMatch(/^[A-Z2-7]{32}$/);
    expect(enr.body.otpauthUrl).toMatch(/^otpauth:\/\/totp\/CareCompanion%3A/);
    expect(enr.body.qrSvg).toContain('<svg');
    const [row] = await t.svc.db.select().from(users).where(eq(users.phone, SEED_PHONES.ananya));
    expect(row.mfaPendingSecretEnc).toBeTruthy();
    expect(row.mfaPendingSecretEnc).not.toContain(enr.body.secret); // encrypted at rest

    const wrong = await t.req(tok, 'POST', '/auth/mfa/totp/confirm', { code: '000000' === totp(enr.body.secret) ? '111111' : '000000' });
    expect(wrong.status).toBe(400);

    const conf = await t.req(tok, 'POST', '/auth/mfa/totp/confirm', { code: totp(enr.body.secret) });
    expect(conf.status).toBe(200);
    expect(conf.body.recoveryCodes).toHaveLength(10);
    expect(conf.body.session.user).toMatchObject({ mfaEnrolled: true, mfaVerified: true });
    expect((await t.req(tok, 'POST', '/auth/mfa/totp/enroll')).status).toBe(409);
    expect((await t.req(conf.body.session.accessToken, 'GET', '/clinician/queue')).status).toBe(200);

    const ref = await t.req(null, 'POST', '/auth/refresh', { refreshToken: conf.body.session.refreshToken });
    expect(ref.status).toBe(200);
    expect(ref.body.user.mfaVerified).toBe(true);
    expect((await t.req(ref.body.accessToken, 'GET', '/clinician/queue')).status).toBe(200);

    // A new login is a new session: MFA again. The confirm code cannot be replayed; the next step's code works.
    const s2 = await t.login(SEED_PHONES.ananya);
    expect(s2.user.mfaVerified).toBe(false);
    expect((await t.req(s2.accessToken, 'GET', '/clinician/queue')).body.error.code).toBe('MFA_REQUIRED');
    expect((await t.req(s2.accessToken, 'POST', '/auth/mfa/verify', { code: totp(enr.body.secret) })).status).toBe(400);
    const v = await t.req(s2.accessToken, 'POST', '/auth/mfa/verify', { code: totp(enr.body.secret, Date.now() + 30_000) });
    expect(v.status).toBe(200);
    expect(v.body.user.mfaVerified).toBe(true);

    const s3 = await t.login(SEED_PHONES.ananya);
    const rc = conf.body.recoveryCodes[0];
    const rv = await t.req(s3.accessToken, 'POST', '/auth/mfa/verify', { recoveryCode: rc.toLowerCase() });
    expect(rv.status).toBe(200);
    const s4 = await t.login(SEED_PHONES.ananya);
    expect((await t.req(s4.accessToken, 'POST', '/auth/mfa/verify', { recoveryCode: rc })).status).toBe(400);
  });

  it('wrong codes are rate limited (5 per 15 min)', async () => {
    const s = await t.login(SEED_PHONES.karthik);
    const enr = await t.req(s.accessToken, 'POST', '/auth/mfa/totp/enroll');
    const good = totp(enr.body.secret);
    const bad = good === '123456' ? '654321' : '123456';
    for (let i = 0; i < 5; i++) {
      const r = await t.req(s.accessToken, 'POST', '/auth/mfa/totp/confirm', { code: bad });
      expect(r.status).toBe(400);
      expect(r.body.error.details.attemptsRemaining).toBe(4 - i);
    }
    const blocked = await t.req(s.accessToken, 'POST', '/auth/mfa/totp/confirm', { code: good });
    expect(blocked.status).toBe(429);
    expect(blocked.body.error.code).toBe('RATE_LIMITED');
  });

  it('patients are not gated; super_admin can reset MFA (audited, sessions revoked)', async () => {
    const p = await t.login(SEED_PHONES.vaibhav);
    expect(p.user.mfaRequired).toBe(false);
    expect((await t.req(p.accessToken, 'GET', '/patients')).status).toBe(200);

    const admin = await t.login(SEED_PHONES.admin);
    await t.svc.db.update(sessions).set({ mfaVerifiedAt: new Date() }).where(eq(sessions.userId, admin.user.id));
    const doc = await t.login(SEED_PHONES.ananya);
    const reset = await t.req(admin.accessToken, 'POST', `/admin/users/${doc.user.id}/mfa/reset`);
    expect(reset.status).toBe(200);
    expect((await t.req(doc.accessToken, 'GET', '/me')).status).toBe(401);
    const again = await t.login(SEED_PHONES.ananya);
    expect(again.user.mfaEnrolled).toBe(false);
    const logs = await t.req(admin.accessToken, 'GET', `/admin/audit-logs?action=mfa.reset&entityId=${doc.user.id}`);
    expect(logs.body.items).toHaveLength(1);
    const coord = await t.login(SEED_PHONES.meera);
    expect((await t.req(coord.accessToken, 'POST', `/admin/users/${doc.user.id}/mfa/reset`)).status).toBe(403);
  });
});

describe('MFA_ENFORCED defaults', () => {
  let t: TestCtx;
  beforeAll(async () => {
    t = await setup();
  });
  afterAll(async () => t.close());
  it('dev/test: staff flows are unchanged (not enforced)', async () => {
    expect(t.svc.config.MFA_ENFORCED).toBe(false);
    const d = await t.login(SEED_PHONES.ananya);
    expect(d.user).toMatchObject({ mfaRequired: true, mfaVerified: false });
    expect((await t.req(d.accessToken, 'GET', '/clinician/queue')).status).toBe(200);
  });
});

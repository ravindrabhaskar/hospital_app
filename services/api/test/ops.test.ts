import { Writable } from 'node:stream';
import pino from 'pino';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { buildApp } from '../src/app.js';
import { loadConfig, productionReadinessIssues } from '../src/config.js';
import { createDb } from '../src/db/client.js';
import { REDACT_PATHS } from '../src/lib/logger.js';
import { AdvisoryLockLeader, SingleProcessLeader, type LockClient } from '../src/worker/leader.js';
import { Scheduler } from '../src/worker/scheduler.js';
import { SEED_PHONES, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());

describe('GET /config/public (contract section 21)', () => {
  it('is public and reflects flags + env', async () => {
    const r = await t.req(null, 'GET', '/config/public');
    expect(r.status).toBe(200);
    expect(r.body).toEqual({
      flags: {
        ai_assistant: true,
        wound_ai_analysis: false,
        fall_detection: true,
        wearables: true,
        pharmacy_orders: true,
        mental_wellness: true,
        govt_schemes: true,
        voice_input: true,
      },
      payment: { gateway: 'mock', razorpayKeyId: null },
      video: { provider: 'jitsi' },
      push: { enabled: false },
      support: { phone: '+914000000000', email: 'support@carecompanion.example', whatsapp: null },
      legal: {
        privacyUrl: 'https://carecompanion.example/privacy',
        termsUrl: 'https://carecompanion.example/terms',
        accountDeletionUrl: 'https://carecompanion.example/account/delete',
      },
      minAppVersion: { patientAndroid: '1.0.0', patientIos: '1.0.0', providerAndroid: '1.0.0', providerIos: '1.0.0' },
    });
    const admin = (await t.login(SEED_PHONES.admin)).accessToken;
    await t.req(admin, 'PUT', '/admin/feature-flags/govt_schemes', { enabled: false });
    expect((await t.req(null, 'GET', '/config/public')).body.flags.govt_schemes).toBe(false);
    await t.req(admin, 'PUT', '/admin/feature-flags/govt_schemes', { enabled: true });
  });
});

describe('/metrics (contract section 28)', () => {
  it('open in dev, Prometheus format with HTTP/AI/outbox/safety metrics', async () => {
    await t.req(null, 'GET', '/api/v1/health');
    const r = await t.req(null, 'GET', '/metrics');
    expect(r.status).toBe(200);
    expect(r.headers['content-type']).toContain('text/plain');
    const text = r.body as string;
    expect(text).toContain('cc_http_request_duration_seconds_bucket');
    expect(text).toMatch(/route="\/api\/v1\/health"/);
    expect(text).toContain('cc_notification_outbox');
    expect(text).toContain('cc_safety_events');
    expect(text).toContain('cc_ai_fallbacks_total');
    expect((await t.req(null, 'GET', '/api/v1/metrics')).status).toBe(200);
  });

  it('requires the bearer METRICS_TOKEN when set; closed in production without one', async () => {
    const m = await setup({ config: { METRICS_TOKEN: 'metrics-token-0123456789' } });
    try {
      expect((await m.req(null, 'GET', '/metrics')).status).toBe(401);
      expect((await m.req('wrong-token-0123456789xx', 'GET', '/metrics')).status).toBe(401);
      expect((await m.req('metrics-token-0123456789', 'GET', '/metrics')).status).toBe(200);
    } finally {
      await m.close();
    }
    const handle = await createDb({ pgliteDir: 'memory://' });
    const p = await setup({
      dbHandle: handle,
      config: { NODE_ENV: 'production', DATABASE_URL: 'postgres://injected', JWT_SECRET: 'p'.repeat(48), PAYMENT_WEBHOOK_SECRET: 'w'.repeat(32) },
    });
    try {
      expect((await p.req(null, 'GET', '/metrics')).status).toBe(403);
    } finally {
      await p.close();
      await handle.close();
    }
  });
});

describe('hardening', () => {
  it('helmet headers and JSON body limit', async () => {
    const h = await t.req(null, 'GET', '/api/v1/health');
    expect(h.headers['x-content-type-options']).toBe('nosniff');
    expect(h.headers['x-frame-options']).toBeDefined();
    expect(h.headers['cross-origin-resource-policy']).toBe('cross-origin');
    const small = await setup({ config: { BODY_LIMIT_KB: 1 } });
    try {
      const r = await small.req(null, 'POST', '/auth/otp/request', { phone: '+919800000001', pad: 'x'.repeat(4000) });
      expect(r.status).toBe(400);
    } finally {
      await small.close();
    }
  });

  it('pino redaction covers secrets, tokens, OTP/TOTP codes and Razorpay signatures', () => {
    const lines: string[] = [];
    const log = pino(
      { redact: { paths: REDACT_PATHS, censor: '[REDACTED]' } },
      new Writable({
        write(chunk, _e, cb) {
          lines.push(chunk.toString());
          cb();
        },
      }),
    );
    log.info({
      x: {
        secret: 'JBSWY3DPEHPK3PXP',
        code: '123456',
        otp: '654321',
        recoveryCode: 'ABCDE-FGHIJ',
        recoveryCodes: ['A'],
        otpauthUrl: 'otpauth://totp/x?secret=S',
        razorpaySignature: 'deadbeef',
        razorpay_signature: 'deadbeef',
        privateKey: '-----BEGIN',
        accessToken: 'at',
        refreshToken: 'rt',
        token: 'jitsi-jwt',
        pushToken: 'fcm',
        joinUrl: 'https://x/?jwt=abc',
        authkey: 'msg91',
        keySecret: 'rzp',
        assertion: 'jwt',
        access_token: 'ya29',
      },
      req: { headers: { authorization: 'Bearer x', 'x-razorpay-signature': 'sig', 'idempotency-key': 'k' } },
    });
    const out = lines.join('');
    for (const v of ['JBSWY3DPEHPK3PXP', '123456', '654321', 'ABCDE-FGHIJ', 'otpauth://', 'deadbeef', 'BEGIN', 'ya29', 'jitsi-jwt', 'Bearer x', '"sig"', 'msg91']) {
      expect(out).not.toContain(v);
    }
  });

  it('REDIS_URL switches the rate limiter to a shared Redis store (lazy connect)', async () => {
    const { createRedis } = await import('../src/app.js');
    const r = await createRedis('redis://127.0.0.1:6399');
    expect(r.status).toBe('wait'); // lazyConnect: no connection attempted at construction
    r.disconnect();
  });
});

describe('worker leader election', () => {
  it('PGlite: single process is always the leader; /ready reports worker state', async () => {
    const l = new SingleProcessLeader();
    expect(await l.acquire()).toBe(true);
    const r = await t.req(null, 'GET', '/api/v1/ready');
    expect(r.body.checks).toMatchObject({ storage: 'ok', worker: 'disabled' });
  });

  it('Postgres advisory lock: only the lock holder runs jobs; lock loss fails over', async () => {
    const held = new Set<number>();
    const mk = (): LockClient & { alive: boolean } => {
      const mine = new Set<number>();
      const handlers: Record<string, Array<(...a: unknown[]) => void>> = {};
      const c = {
        alive: true,
        async connect() {},
        async query(sql: string, params?: unknown[]) {
          if (!c.alive) throw new Error('connection terminated');
          const key = params?.[0] as number;
          if (sql.includes('pg_try_advisory_lock')) {
            if (held.has(key) && !mine.has(key)) return { rows: [{ locked: false }] };
            held.add(key);
            mine.add(key);
            return { rows: [{ locked: true }] };
          }
          if (sql.includes('pg_advisory_unlock')) {
            held.delete(key);
            mine.delete(key);
          }
          return { rows: [{}] };
        },
        async end() {
          for (const k of mine) held.delete(k);
          mine.clear();
          handlers.end?.forEach((h) => h());
        },
        on(ev: string, cb: (...a: unknown[]) => void) {
          (handlers[ev] ??= []).push(cb);
          return c;
        },
      };
      return c;
    };
    const clientsA: Array<ReturnType<typeof mk>> = [];
    const a = new AdvisoryLockLeader(() => {
      const c = mk();
      clientsA.push(c);
      return c;
    }, 42);
    const b = new AdvisoryLockLeader(mk, 42);
    const runs = { a: 0, b: 0 };
    const sa = new Scheduler(t.svc, t.app.log, { job: async () => ++runs.a }, a);
    const sb = new Scheduler(t.svc, t.app.log, { job: async () => ++runs.b }, b);
    await sa.tick();
    await sb.tick();
    await sb.tick();
    expect(runs).toEqual({ a: 1, b: 0 });
    // Instance A's DB connection dies -> Postgres drops its session lock -> B takes over.
    clientsA[0].alive = false;
    await clientsA[0].end();
    expect(a.isLeader()).toBe(false);
    await sb.tick();
    await sa.tick(); // A reconnects but the lock is now held by B
    expect(runs).toEqual({ a: 1, b: 1 });
    expect(b.isLeader()).toBe(true);
    expect(a.isLeader()).toBe(false);
    await sb.stop();
    await sa.stop();
  });
});

describe('production startup refusals', () => {
  const base = { NODE_ENV: 'production', DATABASE_URL: 'postgres://x', JWT_SECRET: 'p'.repeat(48), PAYMENT_WEBHOOK_SECRET: 'w'.repeat(32) };

  it('refuses console SMS, the no-op scanner, the mock gateway and a missing MFA key', async () => {
    const issues = productionReadinessIssues(loadConfig(base));
    expect(issues.join('\n')).toMatch(/SMS_PROVIDER=console/);
    expect(issues.join('\n')).toMatch(/CLAMAV_HOST/);
    expect(issues.join('\n')).toMatch(/PAYMENT_GATEWAY=mock/);
    expect(issues.join('\n')).toMatch(/MFA_ENCRYPTION_KEY/);
    await expect(buildApp({ config: base, startWorker: false })).rejects.toThrow(/Refusing to start in production/);
    expect(loadConfig(base).MFA_ENFORCED).toBe(true);
    expect(loadConfig({ NODE_ENV: 'development' }).MFA_ENFORCED).toBe(false);
    expect(() => loadConfig({ ...base, MFA_ENCRYPTION_KEY: 'short' })).toThrow(/MFA_ENCRYPTION_KEY/);
  });

  it('a complete production configuration passes', () => {
    const cfg = loadConfig({
      ...base,
      SMS_PROVIDER: 'msg91',
      MSG91_AUTH_KEY: 'k',
      MSG91_OTP_TEMPLATE_ID: 't',
      PAYMENT_GATEWAY: 'razorpay',
      RAZORPAY_KEY_ID: 'rzp_live_x',
      RAZORPAY_KEY_SECRET: 's',
      RAZORPAY_WEBHOOK_SECRET: 'w',
      STORAGE_DRIVER: 's3',
      S3_BUCKET: 'b',
      CLAMAV_HOST: 'clamav',
      MFA_ENCRYPTION_KEY: Buffer.alloc(32, 1).toString('base64'),
      VIDEO_ROOM_SECRET: 'v'.repeat(32),
    });
    expect(productionReadinessIssues(cfg)).toEqual([]);
    expect(productionReadinessIssues({ ...cfg, FCM_PROJECT_ID: 'p' })).toEqual([expect.stringMatching(/FCM_/)]);
  });
});

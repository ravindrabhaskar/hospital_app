import type { FastifyInstance } from 'fastify';
import { buildApp, type BuildOptions, type BuiltApp } from '../src/app.js';
import { SEED_PHONES, seedDatabase } from '../src/db/seed.js';
import { MemoryStorage } from '../src/modules/records/storage.js';

export { SEED_PHONES };
export const P = '/api/v1';

export interface TestCtx extends BuiltApp {
  login(phone: string): Promise<{ accessToken: string; refreshToken: string; user: any }>;
  req(token: string | null, method: string, url: string, body?: unknown, headers?: Record<string, string>): Promise<{ status: number; body: any; headers: Record<string, any> }>;
  close(): Promise<void>;
}

let keyCounter = 0;
export const idem = () => ({ 'idempotency-key': `test-${Date.now()}-${++keyCounter}-${Math.random().toString(36).slice(2)}` });

export async function setup(opts: BuildOptions = {}): Promise<TestCtx> {
  const built = await buildApp({
    // Integration refusals are covered by test/production-readiness.test.ts.
    skipProductionReadiness: true,
    ...opts,
    config: {
      NODE_ENV: 'test',
      LOG_LEVEL: 'silent',
      PGLITE_DIR: 'memory://',
      DATABASE_URL: undefined,
      OTP_MAX_REQUESTS: 1000,
      RATE_LIMIT_MAX: 100000,
      RATE_LIMIT_OTP_MAX: 100000,
      WORKER_ENABLED: false,
      // MFA enforcement is exercised explicitly in test/mfa.test.ts.
      MFA_ENFORCED: false,
      ...(opts.config ?? {}),
    },
    storage: opts.storage ?? new MemoryStorage(),
    startWorker: false,
  });
  await seedDatabase(built.svc.db, built.svc.storage);
  await built.app.ready();
  const app: FastifyInstance = built.app;

  const req: TestCtx['req'] = async (token, method, url, body, headers = {}) => {
    const res = await app.inject({
      method: method as any,
      url: url.startsWith('/api') || url.startsWith('/health') || url.startsWith('/ready') ? url : `${P}${url}`,
      headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers },
      ...(body !== undefined ? { payload: body as any } : {}),
    });
    let parsed: any;
    try {
      parsed = res.body ? JSON.parse(res.body) : null;
    } catch {
      parsed = res.body;
    }
    return { status: res.statusCode, body: parsed, headers: res.headers };
  };

  const login: TestCtx['login'] = async (phone) => {
    const r1 = await req(null, 'POST', '/auth/otp/request', { phone });
    if (r1.status !== 200) throw new Error(`otp request failed ${r1.status} ${JSON.stringify(r1.body)}`);
    const r2 = await req(null, 'POST', '/auth/otp/verify', { phone, otp: r1.body.devOtp });
    if (r2.status !== 200) throw new Error(`otp verify failed ${r2.status} ${JSON.stringify(r2.body)}`);
    return r2.body;
  };

  return { ...built, req, login, close: () => app.close() };
}

/** Find the seeded dependent (Ramesh) for Vaibhav. */
export async function rameshId(t: TestCtx, token: string): Promise<string> {
  const r = await t.req(token, 'GET', '/patients');
  return r.body.items.find((p: any) => p.name === 'Ramesh Kumar').id;
}

export async function firstAvailableSlot(t: TestCtx, token: string, doctorId: string, skip = 0): Promise<any> {
  const { addDays, istDate } = await import('../src/lib/time.js');
  const all: any[] = [];
  for (let d = 1; d < 7; d++) {
    const r = await t.req(token, 'GET', `/doctors/${doctorId}/slots?date=${addDays(istDate(), d)}`);
    all.push(...r.body.items.filter((s: any) => s.status === 'available'));
    if (all.length > skip) return all[skip];
  }
  throw new Error('no slot');
}

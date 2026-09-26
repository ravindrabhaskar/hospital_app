/**
 * `npm run verify:pg` — proves the node-postgres (`pg`) driver path end to end without Docker:
 * PGlite is exposed over the PostgreSQL wire protocol by @electric-sql/pglite-socket, DATABASE_URL points
 * at it, and the real app (driver `pg`) runs migrations, the seed and API calls through `pg.Pool`.
 */
import { randomUUID } from 'node:crypto';
import net from 'node:net';
import { PGlite } from '@electric-sql/pglite';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';
import pg from 'pg';
import { buildApp } from '../src/app.js';
import { schema } from '../src/db/client.js';
import { seedDatabase, SEED_PHONES } from '../src/db/seed.js';
import { addDays, istDate } from '../src/lib/time.js';
import { ensureInvoice } from '../src/modules/billing/service.js';
import { MemoryStorage } from '../src/modules/records/storage.js';
import { createLeaderElector } from '../src/worker/leader.js';

let passed = 0;
let failed = 0;
function check(name: string, ok: boolean, extra?: unknown): void {
  if (ok) passed++;
  else failed++;
  console.log(`  ${ok ? 'PASS' : 'FAIL'} ${name}${!ok && extra !== undefined ? ` -> ${JSON.stringify(extra).slice(0, 300)}` : ''}`);
}

async function freePort(): Promise<number> {
  return new Promise((resolve) => {
    const s = net.createServer();
    s.listen(0, '127.0.0.1', () => {
      const { port } = s.address() as net.AddressInfo;
      s.close(() => resolve(port));
    });
  });
}

async function main(): Promise<void> {
  const port = await freePort();
  const pglite = await PGlite.create();
  const server = new PGLiteSocketServer({ db: pglite, port, host: '127.0.0.1', maxConnections: 50 });
  await server.start();
  const url = `postgres://postgres:postgres@127.0.0.1:${port}/postgres`;
  console.log(`PGlite wire-protocol server on ${url}\n`);

  // 1. Raw pg client
  const raw = new pg.Client({ connectionString: url });
  await raw.connect();
  const v = await raw.query('select version() as v');
  check('pg client connects over the wire protocol', typeof v.rows[0]?.v === 'string', v.rows);
  await raw.end();

  // 2. The real app with DATABASE_URL (driver pg): migrations at startup
  const { app, svc } = await buildApp({
    config: { NODE_ENV: 'test', LOG_LEVEL: 'silent', DATABASE_URL: url, DATABASE_POOL_MAX: 4, WORKER_ENABLED: false, OTP_MAX_REQUESTS: 1000, RATE_LIMIT_MAX: 100000 },
    storage: new MemoryStorage(),
    startWorker: false,
  });
  let exitCode: number;
  try {
    check('app uses the pg driver', svc.dbHandle.driver === 'pg', svc.dbHandle.driver);
    const tables = await svc.db.execute(`select count(*)::int as n from information_schema.tables where table_schema = 'public'` as never);
    const n = (tables as unknown as { rows: Array<{ n: number }> }).rows[0].n;
    check(`migrations applied through pg (${n} tables)`, n >= 50, n);

    // 3. Seed through pg
    await seedDatabase(svc.db, svc.storage);
    check('seed completed through pg', true);
    await app.ready();

    const call = async (token: string | null, method: string, path: string, body?: unknown, headers: Record<string, string> = {}) => {
      const res = await app.inject({
        method: method as never,
        url: `/api/v1${path}`,
        headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers },
        ...(body !== undefined ? { payload: body as never } : {}),
      });
      return { status: res.statusCode, body: res.body ? JSON.parse(res.body) : null };
    };
    const login = async (phone: string) => {
      await call(null, 'POST', '/auth/otp/request', { phone });
      return (await call(null, 'POST', '/auth/otp/verify', { phone, otp: '123456' })).body;
    };

    // 4. API calls through pg
    const ready = await call(null, 'GET', '/ready');
    check('/ready db ok', ready.body?.checks?.db === 'ok', ready.body);
    const s = await login(SEED_PHONES.vaibhav);
    check('OTP login (transaction + refresh token rows)', !!s?.accessToken, s);
    const me = await call(s.accessToken, 'GET', '/me');
    check('/me', me.status === 200 && me.body.onboardingComplete === true, me.body);
    const pats = await call(s.accessToken, 'GET', '/patients');
    const ramesh = pats.body.items.find((p: { name: string }) => p.name === 'Ramesh Kumar');
    check('/patients lists the dependent', !!ramesh, pats.body);
    const docs = await call(s.accessToken, 'GET', '/doctors?specialty=general_physician');
    const doctor = docs.body.items[0];
    const slots = await call(s.accessToken, 'GET', `/doctors/${doctor.id}/slots?date=${addDays(istDate(), 2)}`);
    const slot = slots.body.items.find((x: { status: string }) => x.status === 'available');
    const book = (key: string) =>
      call(s.accessToken, 'POST', '/appointments', { patientId: ramesh.id, doctorId: doctor.id, slotId: slot.id, mode: 'video', reason: 'verify pg' }, { 'idempotency-key': key });
    const results = await Promise.all([book('pg-a'), book('pg-b'), book('pg-c')]);
    const ok = results.filter((r) => r.status === 201);
    check('concurrent double booking over pg: exactly one wins', ok.length === 1 && results.filter((r) => r.status === 409).length === 2, results.map((r) => r.status));
    const pay = await call(s.accessToken, 'POST', `/payments/${ok[0].body.payment.id}/confirm-mock`, { outcome: 'success' }, { 'idempotency-key': 'pg-pay' });
    check('mock payment confirms the appointment', pay.body?.status === 'succeeded', pay.body);
    const exp = await call(s.accessToken, 'POST', '/me/data-export');
    check('data export (jsonb + storage) through pg', exp.status === 201, exp.body);

    // 4b. v1.2 features through pg (row locks, counters, DISTINCT ON, PDFs)
    const inv = await call(s.accessToken, 'GET', `/payments/${ok[0].body.payment.id}/invoice`);
    check('invoice issued through pg', inv.status === 200 && /^CC\/\d{4}-\d{2}\/\d{6}$/.test(inv.body?.number), inv.body);
    const payIds: string[] = [];
    for (let i = 0; i < 6; i++) {
      const [p] = await svc.db
        .insert(schema.payments)
        .values({ purpose: 'pharmacy_order', refId: randomUUID(), patientId: ramesh.id, amount: 50 + i, status: 'succeeded', gateway: 'mock', gatewayOrderId: `order_pg_${randomUUID()}` })
        .returning();
      payIds.push(p.id);
    }
    const invs = await Promise.all([...payIds, payIds[0]].map((id) => ensureInvoice(svc.db, svc.config, id)));
    const seqs = [...new Set(invs.map((x) => x.seq))].sort((a, b) => a - b);
    check('concurrent invoice numbering over pg is unique and gap-free', seqs.length === 6 && seqs[5] - seqs[0] === 5, seqs);
    const doc = await login(SEED_PHONES.ananya);
    const weekly = (start: string) => ({ weekly: [1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, start, end: '12:00', slotMins: 30, modes: ['video'] })) });
    const puts = await Promise.all([call(doc.accessToken, 'PUT', '/doctor/me/schedule', weekly('09:00')), call(doc.accessToken, 'PUT', '/doctor/me/schedule', weekly('10:00'))]);
    check('concurrent schedule updates over pg (row lock)', puts.every((p) => p.status === 200), puts.map((p) => p.status));
    const start = await call(doc.accessToken, 'POST', `/clinician/appointments/${ok[0].body.appointment.id}/start`);
    const rx = await call(doc.accessToken, 'POST', '/clinician/prescriptions', {
      appointmentId: ok[0].body.appointment.id,
      items: [{ drugName: 'Paracetamol', strength: '500mg', form: 'tablet', dose: '1 tablet', frequency: 'If needed', durationDays: 3, times: [] }],
    });
    check('e-prescription (PDF + record + medication) through pg', start.status === 200 && rx.status === 201 && !!rx.body?.recordId, rx.body);
    const inbox = await call(s.accessToken, 'GET', '/inbox');
    check('inbox (DISTINCT ON + unread counts) through pg', inbox.status === 200 && inbox.body.items[0]?.unread === 2, inbox.body);
    const sub = await call(s.accessToken, 'POST', '/subscriptions', { planCode: 'family_plus', billing: 'monthly' }, { 'idempotency-key': 'pg-sub' });
    const subPay = await call(s.accessToken, 'POST', `/payments/${sub.body?.payment?.id}/confirm-mock`, { outcome: 'success' }, { 'idempotency-key': 'pg-sub-pay' });
    const subMe = await call(s.accessToken, 'GET', '/subscriptions/me');
    check('subscription activation through pg', subPay.body?.status === 'succeeded' && subMe.body?.status === 'active', subMe.body);
    const nurse = await login(SEED_PHONES.sunita);
    const earn = await call(nurse.accessToken, 'GET', `/provider/earnings?from=${addDays(istDate(), -20)}&to=${istDate()}`);
    check('provider earnings through pg', earn.status === 200 && earn.body.completedServices === 1 && earn.body.payable === 399, earn.body);

    // 5. Worker leader election uses pg_try_advisory_lock on a dedicated pg connection
    const leader = await createLeaderElector(svc.dbHandle, 99);
    check(`leader election mode = ${leader.mode}`, leader.mode === 'advisory_lock');
    check('pg_try_advisory_lock acquired', await leader.acquire());
    await leader.release();

    console.log(`\n${passed} passed, ${failed} failed`);
    exitCode = failed ? 1 : 0;
  } finally {
    await app.close();
    await server.stop();
    await pglite.close();
  }
  process.exit(exitCode);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

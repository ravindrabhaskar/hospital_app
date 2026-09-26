import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';
import { createDb, runMigrations, type DbHandle } from '../src/db/client.js';
import { auditLogs, users } from '../src/db/schema.js';
import type { SmsProvider } from '../src/modules/auth/sms.js';
import { createStorage } from '../src/modules/records/storage-factory.js';
import { S3Storage } from '../src/modules/records/s3.js';
import { LocalDiskStorage } from '../src/modules/records/storage.js';
import { createAdmin, parseArgs } from '../src/scripts/create-admin.js';
import { SEED_PHONES, setup, type TestCtx } from './helpers.js';

const REVIEW_PHONE = '+919899900001';

class CountingSms implements SmsProvider {
  readonly name = 'twilio' as const;
  sent: string[] = [];
  async sendOtp(phone: string): Promise<void> {
    this.sent.push(phone);
  }
  async sendText(): Promise<void> {}
}

describe('app-store review login (production mode)', () => {
  let t: TestCtx;
  let handle: DbHandle;
  const sms = new CountingSms();
  beforeAll(async () => {
    handle = await createDb({ pgliteDir: 'memory://' });
    t = await setup({
      dbHandle: handle,
      sms,
      config: {
        NODE_ENV: 'production',
        DATABASE_URL: 'postgres://injected',
        JWT_SECRET: 'p'.repeat(48),
        PAYMENT_WEBHOOK_SECRET: 'w'.repeat(32),
        REVIEW_PHONE,
        REVIEW_OTP: '424242',
      },
    });
  });
  afterAll(async () => {
    await t.close();
    await handle.close();
  });

  it('the review phone logs in with the fixed OTP, without SMS, audited as auth.review_login', async () => {
    const r = await t.req(null, 'POST', '/auth/otp/request', { phone: REVIEW_PHONE });
    expect(r.status).toBe(200);
    expect(r.body.devOtp).toBeUndefined();
    expect(sms.sent).not.toContain(REVIEW_PHONE);
    const v = await t.req(null, 'POST', '/auth/otp/verify', { phone: REVIEW_PHONE, otp: '424242' });
    expect(v.status).toBe(200);
    const logs = await t.svc.db.select().from(auditLogs).where(eq(auditLogs.action, 'auth.review_login'));
    expect(logs.map((l) => l.entityId)).toContain(v.body.user.id);
  });

  it('never applies to any other phone', async () => {
    const other = '+919899900002';
    await t.req(null, 'POST', '/auth/otp/request', { phone: other });
    expect(sms.sent).toContain(other);
    const v = await t.req(null, 'POST', '/auth/otp/verify', { phone: other, otp: '424242' });
    expect(v.status).toBe(401);
  });

  it('REVIEW_PHONE and REVIEW_OTP must be set together', () => {
    expect(() => loadConfig({ NODE_ENV: 'test', REVIEW_PHONE })).toThrow(/REVIEW_OTP/);
  });
});

describe('create-admin CLI', () => {
  let handle: DbHandle;
  beforeAll(async () => {
    handle = await createDb({ pgliteDir: 'memory://' });
    await runMigrations(handle);
  });
  afterAll(async () => handle.close());

  it('parses arguments', () => {
    expect(parseArgs(['--phone', '+919812345678', '--name', 'Asha Rao'])).toEqual({ phone: '+919812345678', name: 'Asha Rao', roles: ['super_admin'] });
    expect(parseArgs(['--phone', '+919812345678', '--roles', 'ops_admin,coordinator']).roles).toEqual(['ops_admin', 'coordinator']);
    expect(() => parseArgs(['--phone', '98123'])).toThrow(/E.164/);
    expect(() => parseArgs(['--phone', '+919812345678', '--roles', 'root'])).toThrow(/Invalid --roles/);
  });

  it('creates, then idempotently adds roles; audited as system:cli', async () => {
    const a = await createAdmin(handle.db, { phone: '+919812345678', name: 'Asha Rao', roles: ['super_admin'] });
    expect(a).toMatchObject({ created: true, roles: ['super_admin'] });
    const b = await createAdmin(handle.db, { phone: '+919812345678', name: null, roles: ['ops_admin', 'super_admin'] });
    expect(b.created).toBe(false);
    expect(b.id).toBe(a.id);
    expect(b.roles.sort()).toEqual(['ops_admin', 'super_admin']);
    const [u] = await handle.db.select().from(users).where(eq(users.id, a.id));
    expect(u.name).toBe('Asha Rao');
    const logs = await handle.db.select().from(auditLogs).where(eq(auditLogs.entityId, a.id));
    expect(logs.map((l) => l.actorName)).toEqual(['system:cli', 'system:cli']);
  });

  it('promotes an existing patient without losing the patient role', async () => {
    const t = await setup();
    try {
      const r = await createAdmin(t.svc.db, { phone: SEED_PHONES.vaibhav, roles: ['coordinator'] });
      expect(r.roles.sort()).toEqual(['coordinator', 'patient']);
    } finally {
      await t.close();
    }
  });
});

describe('storage factory (seed + app)', () => {
  it('uses the configured driver', () => {
    expect(createStorage(loadConfig({ NODE_ENV: 'test' }))).toBeInstanceOf(LocalDiskStorage);
    expect(createStorage(loadConfig({ NODE_ENV: 'test', STORAGE_DRIVER: 's3', S3_BUCKET: 'b' }))).toBeInstanceOf(S3Storage);
    expect(createStorage(loadConfig({ NODE_ENV: 'test', STORAGE_DRIVER: 'memory' })).name).toBe('memory');
  });
});

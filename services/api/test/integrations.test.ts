import { createVerify, generateKeyPairSync } from 'node:crypto';
import net from 'node:net';
import { Readable } from 'node:stream';
import { DeleteObjectCommand, GetObjectCommand, HeadBucketCommand, HeadObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { mockClient } from 'aws-sdk-client-mock';
import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';
import { samplePdf } from '../src/db/seed.js';
import { devices, notificationOutbox, users } from '../src/db/schema.js';
import { FcmPushChannel, signServiceAccountJwt } from '../src/modules/notifications/fcm.js';
import { S3Storage } from '../src/modules/records/s3.js';
import { ClamdScanner } from '../src/modules/records/scanner.js';
import { fakeFetch, multipart } from './fakes.js';
import { SEED_PHONES, rameshId, setup, type TestCtx } from './helpers.js';

// ---------------------------------------------------------------------------------------------- FCM
const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const PEM = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
const CREDS = { projectId: 'cc-test', clientEmail: 'push@cc-test.iam.gserviceaccount.com', privateKey: PEM };

function fcmServer() {
  let tokenSeq = 0;
  return fakeFetch((c) => {
    if (c.url === 'https://oauth2.googleapis.com/token') {
      const form = new URLSearchParams(c.body);
      const [h, p, s] = form.get('assertion')!.split('.');
      const ok = createVerify('RSA-SHA256').update(`${h}.${p}`).verify(publicKey, Buffer.from(s, 'base64url'));
      const claims = JSON.parse(Buffer.from(p, 'base64url').toString());
      if (!ok || form.get('grant_type') !== 'urn:ietf:params:oauth:grant-type:jwt-bearer' || claims.iss !== CREDS.clientEmail) {
        return { status: 400, body: { error: 'invalid_grant' } };
      }
      return { body: { access_token: `ya29.token${++tokenSeq}`, expires_in: 3600, token_type: 'Bearer' } };
    }
    if (c.url === 'https://fcm.googleapis.com/v1/projects/cc-test/messages:send') {
      const { message } = JSON.parse(c.body);
      if (message.token.startsWith('dead')) {
        return { status: 404, body: { error: { code: 404, status: 'NOT_FOUND', details: [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: 'UNREGISTERED' }] } } };
      }
      return { body: { name: 'projects/cc-test/messages/1' } };
    }
    return { status: 404 };
  });
}

describe('FCM HTTP v1 adapter', () => {
  it('exchanges a signed service-account JWT for an access token and caches it', async () => {
    const jwt = signServiceAccountJwt(CREDS, 1_800_000_000);
    const claims = JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString());
    expect(claims).toMatchObject({ iss: CREDS.clientEmail, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: 'https://oauth2.googleapis.com/token', exp: 1_800_003_600 });

    const f = fcmServer();
    // Private keys from env usually carry literal "\n" sequences.
    const ch = new FcmPushChannel({ ...CREDS, privateKey: PEM.replace(/\n/g, '\\n') }, async () => undefined, f.fetch);
    await ch.send({ channel: 'push', recipient: 'tok-a', userId: 'u', text: 'You have a care update', critical: false, deepLink: '/appointments/1', notificationId: 'n1' });
    await ch.send({ channel: 'push', recipient: 'tok-b', userId: 'u', text: 'You have a care update', critical: true });
    expect(f.calls.filter((c) => c.url.includes('oauth2')).length).toBe(1);
    const sends = f.calls.filter((c) => c.url.includes('messages:send'));
    expect(sends[0].headers.authorization).toBe('Bearer ya29.token1');
    expect(JSON.parse(sends[0].body).message).toEqual({
      token: 'tok-a',
      notification: { title: 'CareCompanion', body: 'You have a care update' },
      data: { deepLink: '/appointments/1', notificationId: 'n1' },
      android: { priority: 'NORMAL' },
      apns: { headers: { 'apns-priority': '5' } },
    });
    expect(JSON.parse(sends[1].body).message.android.priority).toBe('HIGH');
  });

  describe('through the notification outbox', () => {
    let t: TestCtx;
    beforeAll(async () => {
      t = await setup({
        fetchImpl: fcmServer().fetch,
        config: { FCM_PROJECT_ID: CREDS.projectId, FCM_CLIENT_EMAIL: CREDS.clientEmail, FCM_PRIVATE_KEY: PEM.replace(/\n/g, '\\n') },
      });
    });
    afterAll(async () => t.close());

    it('sends generic pushes and removes UNREGISTERED tokens without retrying', async () => {
      const token = (await t.login(SEED_PHONES.vaibhav)).accessToken;
      expect((await t.req(token, 'POST', '/devices', { pushToken: 'live-token-123456', platform: 'android' })).status).toBe(204);
      expect((await t.req(token, 'POST', '/devices', { pushToken: 'dead-token-123456', platform: 'ios' })).status).toBe(204);
      const [u] = await t.svc.db.select().from(users).where(eq(users.phone, SEED_PHONES.vaibhav));
      await t.svc.notify.notifyUsers([u.id], { template: 'payment_succeeded', params: { amount: 499 }, category: 'payment', deepLink: '/payments/x', dedupeKey: 'fcm-test-1' });
      await t.svc.notify.dispatchOutbox(new Date(Date.now() + 1000));
      const rows = await t.svc.db.select().from(notificationOutbox).where(eq(notificationOutbox.channel, 'push'));
      const live = rows.find((r) => r.recipient === 'live-token-123456')!;
      const dead = rows.find((r) => r.recipient === 'dead-token-123456')!;
      expect(live.status).toBe('sent');
      expect(dead).toMatchObject({ status: 'failed', lastError: 'unregistered_token', attempts: 1 });
      const toks = await t.svc.db.select().from(devices).where(eq(devices.userId, u.id));
      expect(toks.map((d) => d.pushToken)).toEqual(['live-token-123456']);
      expect((await t.req(null, 'GET', '/config/public')).body.push).toEqual({ enabled: true });

      // DELETE /devices (logout)
      expect((await t.req(token, 'DELETE', '/devices', { pushToken: 'live-token-123456' })).status).toBe(204);
      expect(await t.svc.db.select().from(devices).where(eq(devices.userId, u.id))).toHaveLength(0);
    });
  });
});

// ---------------------------------------------------------------------------------------------- S3
describe('S3Storage', () => {
  const s3 = mockClient(S3Client);
  beforeEach(() => s3.reset());
  const storage = () => new S3Storage('cc-records', new S3Client({ region: 'ap-south-1', credentials: { accessKeyId: 'x', secretAccessKey: 'y' } }), 'arn:aws:kms:ap-south-1:1:key/abc');

  it('puts write-once objects with SSE-KMS', async () => {
    s3.on(PutObjectCommand).resolves({});
    await storage().put('records/p/1.pdf', Buffer.from('%PDF-1.4'), 'application/pdf');
    const input = s3.commandCalls(PutObjectCommand)[0].args[0].input;
    expect(input).toMatchObject({
      Bucket: 'cc-records',
      Key: 'records/p/1.pdf',
      ContentType: 'application/pdf',
      IfNoneMatch: '*',
      ServerSideEncryption: 'aws:kms',
      SSEKMSKeyId: 'arn:aws:kms:ap-south-1:1:key/abc',
    });
    s3.on(PutObjectCommand).rejects(Object.assign(new Error('precondition'), { name: 'PreconditionFailed', $metadata: { httpStatusCode: 412 } }));
    await expect(storage().put('records/p/1.pdf', Buffer.from('x'), 'application/pdf')).rejects.toThrow('object exists');
  });

  it('streams, reads, heads and deletes objects', async () => {
    s3.on(GetObjectCommand).callsFake(() => ({ Body: Readable.from([Buffer.from('hello '), Buffer.from('world')]) }));
    expect((await storage().get('k')).toString()).toBe('hello world');
    const chunks: Buffer[] = [];
    for await (const c of await storage().getStream('k')) chunks.push(c);
    expect(Buffer.concat(chunks).toString()).toBe('hello world');

    s3.on(HeadObjectCommand, { Key: 'there' }).resolves({ ContentLength: 11, ContentType: 'text/plain' });
    s3.on(HeadObjectCommand, { Key: 'missing' }).rejects(Object.assign(new Error('nf'), { name: 'NotFound', $metadata: { httpStatusCode: 404 } }));
    expect(await storage().head('there')).toEqual({ size: 11, contentType: 'text/plain' });
    expect(await storage().exists('missing')).toBe(false);

    s3.on(GetObjectCommand).rejects(Object.assign(new Error('nk'), { name: 'NoSuchKey', $metadata: { httpStatusCode: 404 } }));
    await expect(storage().get('gone')).rejects.toMatchObject({ code: 'NOT_FOUND' });

    s3.on(DeleteObjectCommand).resolves({});
    await storage().delete('exports/u/1.json');
    expect(s3.commandCalls(DeleteObjectCommand)[0].args[0].input).toEqual({ Bucket: 'cc-records', Key: 'exports/u/1.json' });
    s3.on(HeadBucketCommand).resolves({});
    await storage().ping();
    await expect(storage().put('../escape', Buffer.from('x'), 'text/plain')).rejects.toThrow('invalid storage key');
  });

  it('builds from config (MinIO endpoint, path-style) and requires a bucket', async () => {
    const st = S3Storage.fromConfig(loadConfig({ NODE_ENV: 'test', STORAGE_DRIVER: 's3', S3_BUCKET: 'b', S3_ENDPOINT: 'http://localhost:9000', S3_ACCESS_KEY_ID: 'a', S3_SECRET_ACCESS_KEY: 's' }));
    expect(st.bucket).toBe('b');
    expect(() => S3Storage.fromConfig(loadConfig({ NODE_ENV: 'test', STORAGE_DRIVER: 's3' }))).toThrow(/S3_BUCKET/);
  });
});

// ---------------------------------------------------------------------------------------------- ClamAV
/** Tiny fake clamd: INSTREAM + PING. Flags anything containing the EICAR marker. */
function startFakeClamd(): Promise<{ port: number; close: () => Promise<void>; scans: () => number }> {
  let scans = 0;
  const server = net.createServer((sock) => {
    let buf = Buffer.alloc(0);
    sock.on('data', (d) => {
      buf = Buffer.concat([buf, d as Buffer]);
      if (buf.subarray(0, 6).toString() === 'zPING\0') return void sock.end('PONG\0');
      if (buf.subarray(0, 10).toString() !== 'zINSTREAM\0') return;
      let off = 10;
      const data: Buffer[] = [];
      while (off + 4 <= buf.length) {
        const len = buf.readUInt32BE(off);
        if (len === 0) {
          scans++;
          const all = Buffer.concat(data).toString('latin1');
          return void sock.end(all.includes('EICAR-STANDARD-ANTIVIRUS-TEST-FILE') ? 'stream: Eicar-Test-Signature FOUND\0' : 'stream: OK\0');
        }
        if (off + 4 + len > buf.length) return;
        data.push(buf.subarray(off + 4, off + 4 + len));
        off += 4 + len;
      }
    });
  });
  return new Promise((resolve) =>
    server.listen(0, '127.0.0.1', () => {
      const port = (server.address() as net.AddressInfo).port;
      resolve({ port, scans: () => scans, close: () => new Promise((r) => server.close(() => r())) });
    }),
  );
}

const EICAR = 'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*';

describe('ClamAV clamd scanner', () => {
  let clamd: Awaited<ReturnType<typeof startFakeClamd>>;
  let t: TestCtx;
  beforeAll(async () => {
    clamd = await startFakeClamd();
    t = await setup({ config: { CLAMAV_HOST: '127.0.0.1', CLAMAV_PORT: clamd.port } });
  });
  afterAll(async () => {
    await t.close();
    await clamd.close();
  });

  it('INSTREAM: clean, infected (multi-chunk) and ping', async () => {
    const s = new ClamdScanner('127.0.0.1', clamd.port, 3000);
    expect(await s.scan(Buffer.from('hello'))).toEqual({ clean: true, engine: 'clamav', signature: null });
    const big = Buffer.concat([Buffer.alloc(200_000, 0x41), Buffer.from(EICAR)]);
    expect(await s.scan(big)).toEqual({ clean: false, engine: 'clamav', signature: 'Eicar-Test-Signature' });
    await s.ping();
  });

  it('fails closed when clamd is unreachable', async () => {
    const s = new ClamdScanner('127.0.0.1', 1, 1000);
    await expect(s.scan(Buffer.from('x'))).rejects.toMatchObject({ code: 'DEPENDENCY_UNAVAILABLE' });
  });

  it('uploads: infected -> 422 FILE_REJECTED (nothing stored), clean -> 201', async () => {
    const token = (await t.login(SEED_PHONES.vaibhav)).accessToken;
    const ramesh = await rameshId(t, token);
    const fields = { patientId: ramesh, type: 'lab_report', title: 'Scan test', recordDate: '2026-09-01' };
    const infected = Buffer.concat([samplePdf('infected'), Buffer.from(EICAR)]);
    const before = (await t.req(token, 'GET', `/records?patientId=${ramesh}`)).body.items.length;
    const m1 = multipart(fields, { field: 'file', name: 'bad.pdf', data: infected, type: 'application/pdf' });
    const bad = await t.req(token, 'POST', '/records', m1.body, m1.headers);
    expect(bad.status).toBe(422);
    expect(bad.body.error.code).toBe('FILE_REJECTED');
    expect((await t.req(token, 'GET', `/records?patientId=${ramesh}`)).body.items.length).toBe(before);
    const m2 = multipart(fields, { field: 'file', name: 'ok.pdf', data: samplePdf('clean'), type: 'application/pdf' });
    expect((await t.req(token, 'POST', '/records', m2.body, m2.headers)).status).toBe(201);
    expect(clamd.scans()).toBeGreaterThanOrEqual(2);
  });
});

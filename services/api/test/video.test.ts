import { eq } from 'drizzle-orm';
import { jwtVerify } from 'jose';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { appointments } from '../src/db/schema.js';
import { JitsiVideoProvider } from '../src/modules/video/provider.js';
import { SEED_PHONES, firstAvailableSlot, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let ramesh: string;
let doctorId: string;
let skip = 0;

beforeAll(async () => {
  t = await setup();
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  ramesh = await rameshId(t, vaibhav);
  const docs = await t.req(vaibhav, 'GET', '/doctors?specialty=general_physician');
  doctorId = docs.body.items.find((d: any) => d.name === 'Dr. Ananya Rao').id;
});
afterAll(async () => t.close());

async function confirmed(mode: 'video' | 'audio' | 'in_clinic' = 'video') {
  const slot = await firstAvailableSlot(t, vaibhav, doctorId, skip++);
  const b = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId, slotId: slot.id, mode, reason: 'Video test' }, idem());
  expect(b.status).toBe(201);
  const pay = await t.req(vaibhav, 'POST', `/payments/${b.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
  expect(pay.body.status).toBe('succeeded');
  return b.body.appointment.id as string;
}
const moveTo = async (id: string, startOffsetMin: number) => {
  const start = new Date(Date.now() + startOffsetMin * 60_000);
  await t.svc.db.update(appointments).set({ startAt: start, endAt: new Date(start.getTime() + 30 * 60_000) }).where(eq(appointments.id, id));
};
const session = (token: string, id: string) => t.req(token, 'GET', `/appointments/${id}/video-session`);

describe('video session (contract section 26)', () => {
  it('confirmed appointment gets a consistent, unguessable Jitsi room url', async () => {
    const id = await confirmed();
    const a = await t.req(vaibhav, 'GET', `/appointments/${id}`);
    expect(a.body.videoRoomUrl).toMatch(/^https:\/\/meet\.jit\.si\/CareCompanion-[0-9a-f]{32}$/);
    expect(a.body.videoRoomUrl).not.toContain(id);
    expect((await t.req(null, 'GET', '/config/public')).body.video).toEqual({ provider: 'jitsi' });
  });

  it('time window: 409 with details.opensAt before -10 min, open inside, 409 after +60 min', async () => {
    const id = await confirmed();
    const early = await session(vaibhav, id);
    expect(early.status).toBe(409);
    expect(early.body.error.code).toBe('CONFLICT');
    expect(typeof early.body.error.details.opensAt).toBe('string');

    await moveTo(id, 5);
    const ok = await session(vaibhav, id);
    expect(ok.status).toBe(200);
    expect(ok.body).toMatchObject({ provider: 'jitsi', token: null });
    expect(ok.body.joinUrl).toBe(`https://meet.jit.si/${ok.body.roomName}`);
    const a = await t.req(vaibhav, 'GET', `/appointments/${id}`);
    expect(a.body.videoRoomUrl).toBe(ok.body.joinUrl);
    const start = new Date(Date.now() + 5 * 60_000).getTime();
    expect(Math.abs(new Date(ok.body.opensAt).getTime() - (start - 10 * 60_000))).toBeLessThan(5000);
    expect(Math.abs(new Date(ok.body.expiresAt).getTime() - (start + 90 * 60_000))).toBeLessThan(5000);

    await moveTo(id, -95); // ended 65 min ago
    expect((await session(vaibhav, id)).status).toBe(409);
    await moveTo(id, -80); // ended 50 min ago: still open
    expect((await session(vaibhav, id)).status).toBe(200);
  });

  it('permissions: patient, own doctor and manage_care family only', async () => {
    const id = await confirmed();
    await moveTo(id, 2);
    const ananya = (await t.login(SEED_PHONES.ananya)).accessToken;
    const karthik = (await t.login(SEED_PHONES.karthik)).accessToken;
    const lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken; // view_records + receive_alerts
    expect((await session(ananya, id)).status).toBe(200);
    expect((await session(karthik, id)).status).toBe(403);
    expect((await session(lakshmi, id)).status).toBe(403);

    const g = await t.req(vaibhav, 'POST', `/patients/${ramesh}/family-access`, { granteePhone: '+919811100001', relation: 'nephew', permissions: ['manage_care'] });
    expect(g.status).toBe(201);
    const nephew = (await t.login('+919811100001')).accessToken;
    expect((await session(nephew, id)).status).toBe(200);
  });

  it('only video/audio; audio joins with the camera off', async () => {
    const clinic = await confirmed('in_clinic');
    await moveTo(clinic, 1);
    expect((await session(vaibhav, clinic)).status).toBe(409);
    const audio = await confirmed('audio');
    await moveTo(audio, 1);
    const r = await session(vaibhav, audio);
    expect(r.status).toBe(200);
    expect(r.body.joinUrl).toContain('#config.startWithVideoMuted=true');
  });

  it('issues a room-scoped JWT when JITSI_APP_ID/JITSI_APP_SECRET are set', async () => {
    const p = new JitsiVideoProvider({ domain: 'video.carecompanion.in', roomSecret: 'r'.repeat(32), appId: 'carecompanion', appSecret: 's'.repeat(32) });
    const now = Date.now();
    const s = await p.session({
      appointmentId: 'a1',
      mode: 'video',
      participant: { userId: 'u1', name: 'Dr X', moderator: true },
      notBefore: new Date(now - 60_000),
      expiresAt: new Date(now + 3600_000),
    });
    expect(s.joinUrl).toBe(`https://video.carecompanion.in/${s.roomName}?jwt=${s.token}`);
    const { payload } = await jwtVerify(s.token!, new TextEncoder().encode('s'.repeat(32)), { audience: 'jitsi', issuer: 'carecompanion' });
    expect(payload).toMatchObject({ room: s.roomName, sub: 'video.carecompanion.in', context: { user: { id: 'u1', moderator: true } } });
    expect(p.roomName('a1')).toBe(s.roomName);
    expect(p.roomName('a2')).not.toBe(s.roomName);
  });
});

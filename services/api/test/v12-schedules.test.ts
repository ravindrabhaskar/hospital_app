import { and, eq, gt, inArray } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { SAMPLE_PNG } from '../src/db/seed.js';
import { media, medicalRecords, slots } from '../src/db/schema.js';
import { addDays, istDate } from '../src/lib/time.js';
import { weekdayOf } from '../src/modules/schedules/service.js';
import { scheduleHorizon } from '../src/worker/jobs.js';
import { multipart } from './fakes.js';
import { SEED_PHONES, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let ramesh: string;
let ananya: string;
let karthik: string;
let priya: string;
let ops: string;
let docs: Record<string, string> = {};

const IST_MS = 330 * 60_000;
const istHHMM = (iso: string) => new Date(new Date(iso).getTime() + IST_MS).toISOString().slice(11, 16);
const istDay = (iso: string) => new Date(new Date(iso).getTime() + IST_MS).toISOString().slice(0, 10);

beforeAll(async () => {
  t = await setup();
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  ramesh = await rameshId(t, vaibhav);
  ananya = (await t.login(SEED_PHONES.ananya)).accessToken;
  karthik = (await t.login(SEED_PHONES.karthik)).accessToken;
  priya = (await t.login(SEED_PHONES.priya)).accessToken;
  ops = (await t.login(SEED_PHONES.ops)).accessToken;
  const list = await t.req(vaibhav, 'GET', '/doctors?limit=50');
  docs = Object.fromEntries(list.body.items.map((d: any) => [d.name, d.id]));
});
afterAll(async () => t.close());

async function slotsOn(doctorId: string, date: string) {
  return (await t.req(vaibhav, 'GET', `/doctors/${doctorId}/slots?date=${date}`)).body.items as any[];
}
async function firstDateWithSlots(doctorId: string, from = 1) {
  for (let d = from; d < 14; d++) {
    const date = addDays(istDate(), d);
    const s = await slotsOn(doctorId, date);
    if (s.some((x) => x.status === 'available')) return { date, slots: s };
  }
  throw new Error('no slots');
}
async function book(doctorId: string, slotId: string, confirm = true, mode = 'video') {
  const r = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId, slotId, mode, reason: 'Schedule test' }, idem());
  expect(r.status, JSON.stringify(r.body)).toBe(201);
  if (confirm) await t.req(vaibhav, 'POST', `/payments/${r.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
  return r.body.appointment;
}

describe('doctor profile (section 29)', () => {
  it('GET/PATCH /doctor/me/profile', async () => {
    const r = await t.req(ananya, 'GET', '/doctor/me/profile');
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ name: 'Dr. Ananya Rao', acceptingBookings: true, registrationNumber: 'TSMC-SAMPLE-10101', rating: 4.8, ratingCount: 320 });
    expect(r.body.reviews.length).toBeGreaterThan(0);
    const p = await t.req(ananya, 'PATCH', '/doctor/me/profile', { bio: 'Updated bio', languages: ['English', 'Telugu'], fees: { video: 549, audio: 499, chat: null, inClinic: 599 } });
    expect(p.status).toBe(200);
    expect(p.body).toMatchObject({ bio: 'Updated bio', languages: ['English', 'Telugu'], fees: { video: 549, audio: 499, chat: null, inClinic: 599 } });
    await t.req(ananya, 'PATCH', '/doctor/me/profile', { fees: { video: 499, audio: 499, chat: 399, inClinic: 599 } });
    expect((await t.req(vaibhav, 'GET', '/doctor/me/profile')).status).toBe(403);
    expect((await t.req(ananya, 'PATCH', '/doctor/me/profile', { fees: { video: -1, audio: 1, chat: 1, inClinic: 1 } })).status).toBe(400);
  });

  it('acceptingBookings=false hides the doctor from /doctors and refuses bookings', async () => {
    const id = docs['Dr. Karthik Mehta'];
    const { slots: s } = await firstDateWithSlots(id);
    expect((await t.req(karthik, 'PATCH', '/doctor/me/profile', { acceptingBookings: false })).body.acceptingBookings).toBe(false);
    const list = await t.req(vaibhav, 'GET', '/doctors?limit=50');
    expect(list.body.items.map((d: any) => d.id)).not.toContain(id);
    const r = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId: id, slotId: s[0].id, mode: 'video', reason: 'x' }, idem());
    expect(r.status).toBe(409);
    await t.req(karthik, 'PATCH', '/doctor/me/profile', { acceptingBookings: true });
    expect((await t.req(vaibhav, 'GET', '/doctors?limit=50')).body.items.map((d: any) => d.id)).toContain(id);
  });
});

describe('schedules (section 29)', () => {
  it('seeded doctors have the Mon-Sat weekly template and slots carry modes', async () => {
    const r = await t.req(ananya, 'GET', '/doctor/me/schedule');
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ horizonDays: 14, timezone: 'Asia/Kolkata', leaves: [] });
    expect(r.body.weekly).toHaveLength(12);
    expect(r.body.weekly.every((b: any) => b.weekday >= 1 && b.weekday <= 6 && b.slotMins === 30)).toBe(true);
    const { date, slots: s } = await firstDateWithSlots(docs['Dr. Ananya Rao']);
    expect(weekdayOf(date)).not.toBe(0);
    expect(s[0].modes).toEqual(['video', 'audio', 'chat', 'in_clinic']);
    // Sundays have no slots.
    for (let d = 1; d <= 7; d++) {
      const day = addDays(istDate(), d);
      if (weekdayOf(day) === 0) expect(await slotsOn(docs['Dr. Ananya Rao'], day)).toHaveLength(0);
    }
  });

  it('overlapping or malformed blocks are rejected', async () => {
    const overlap = await t.req(priya, 'PUT', '/doctor/me/schedule', {
      weekly: [
        { weekday: 2, start: '09:00', end: '12:00', slotMins: 30, modes: ['video'] },
        { weekday: 2, start: '11:30', end: '13:00', slotMins: 30, modes: ['video'] },
      ],
    });
    expect(overlap.status).toBe(400);
    expect(overlap.body.error.code).toBe('VALIDATION_ERROR');
    expect((await t.req(priya, 'PUT', '/doctor/me/schedule', { weekly: [{ weekday: 2, start: '12:00', end: '11:00', slotMins: 30, modes: ['video'] }] })).status).toBe(400);
    expect((await t.req(priya, 'PUT', '/doctor/me/schedule', { weekly: [{ weekday: 7, start: '09:00', end: '11:00', slotMins: 30, modes: ['video'] }] })).status).toBe(400);
    expect((await t.req(priya, 'PUT', '/doctor/me/schedule', { weekly: [{ weekday: 1, start: '09:00', end: '11:00', slotMins: 25, modes: ['video'] }] })).status).toBe(400);
  });

  it('regeneration replaces unbooked future slots and never touches booked or held slots', async () => {
    const id = docs['Dr. Karthik Mehta'];
    const { slots: s } = await firstDateWithSlots(id);
    const booked = await book(id, s[1].id, true); // confirmed -> slot booked
    const held = await book(id, s[4].id, false); // pending payment -> slot held
    const before = await t.svc.db.select().from(slots).where(inArray(slots.id, [booked.slotId ?? s[1].id, s[4].id]));
    expect(before.map((x) => x.status).sort()).toEqual(['booked', 'held']);

    const weekly = [1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, start: '10:00', end: '11:00', slotMins: 20, modes: ['video', 'audio'] }));
    const r = await t.req(karthik, 'PUT', '/doctor/me/schedule', { weekly });
    expect(r.status).toBe(200);
    expect(r.body.weekly).toHaveLength(6);

    const after = await t.svc.db.select().from(slots).where(inArray(slots.id, [s[1].id, s[4].id]));
    expect(after.map((x) => [x.id, x.status, x.startAt.toISOString(), x.endAt.toISOString()]).sort()).toEqual(
      before.map((x) => [x.id, x.status, x.startAt.toISOString(), x.endAt.toISOString()]).sort(),
    );
    expect(held.status).toBe('pending_payment');

    const future = await t.svc.db.select().from(slots).where(and(eq(slots.doctorId, id), gt(slots.startAt, new Date()), inArray(slots.status, ['available', 'held', 'booked'])));
    const locked = future.filter((x) => x.status !== 'available');
    for (const x of future.filter((f) => f.status === 'available')) {
      const hhmm = istHHMM(x.startAt.toISOString());
      expect(['10:00', '10:20', '10:40']).toContain(hhmm);
      expect(x.endAt.getTime() - x.startAt.getTime()).toBe(20 * 60_000);
      expect(x.modes).toEqual(['video', 'audio']);
      expect(weekdayOf(istDay(x.startAt.toISOString()))).not.toBe(0);
      // No new slot overlaps a booked/held one.
      for (const l of locked) expect(x.startAt < l.endAt && x.endAt > l.startAt).toBe(false);
    }
    expect(future.filter((f) => f.status === 'available').length).toBeGreaterThan(0);

    // The booked slot's patient still sees their appointment; a video-only slot rejects chat bookings.
    const avail = future.find((f) => f.status === 'available')!;
    const chat = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId: id, slotId: avail.id, mode: 'chat', reason: 'x' }, idem());
    expect(chat.status).toBe(400);
  });

  it('concurrent schedule updates leave one consistent template and no duplicate slots', async () => {
    const id = docs['Dr. Arjun Reddy'];
    const arjun = (await t.login(SEED_PHONES.arjun)).accessToken;
    const A = [1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, start: '09:00', end: '10:00', slotMins: 15, modes: ['video'] }));
    const B = [1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, start: '16:00', end: '18:00', slotMins: 30, modes: ['audio'] }));
    const [ra, rb] = await Promise.all([t.req(arjun, 'PUT', '/doctor/me/schedule', { weekly: A }), t.req(arjun, 'PUT', '/doctor/me/schedule', { weekly: B })]);
    expect(ra.status).toBe(200);
    expect(rb.status).toBe(200);
    const final = (await t.req(arjun, 'GET', '/doctor/me/schedule')).body.weekly;
    const isA = final[0].start === '09:00';
    const future = await t.svc.db.select().from(slots).where(and(eq(slots.doctorId, id), gt(slots.startAt, new Date()), eq(slots.status, 'available')));
    expect(future.length).toBeGreaterThan(0);
    const starts = future.map((f) => f.startAt.toISOString());
    expect(new Set(starts).size).toBe(starts.length);
    for (const f of future) {
      const hhmm = istHHMM(f.startAt.toISOString());
      if (isA) expect(['09:00', '09:15', '09:30', '09:45']).toContain(hhmm);
      else expect(['16:00', '16:30', '17:00', '17:30']).toContain(hhmm);
      expect(f.modes).toEqual(isA ? ['video'] : ['audio']);
    }
  });

  it('leave removes the day\'s unbooked slots, reports conflicts, and DELETE regenerates them', async () => {
    const id = docs['Dr. Priya Sharma'];
    await t.req(priya, 'PUT', '/doctor/me/schedule', { weekly: [0, 1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, start: '09:00', end: '11:00', slotMins: 30, modes: ['video', 'audio', 'chat', 'in_clinic'] })) });
    const date = addDays(istDate(), 3);
    const s = await slotsOn(id, date);
    expect(s).toHaveLength(4);
    const appt = await book(id, s[2].id, true);
    const lv = await t.req(priya, 'POST', '/doctor/me/leaves', { date, reason: 'Conference' });
    expect(lv.status).toBe(201);
    expect(lv.body.leave).toMatchObject({ date, reason: 'Conference' });
    expect(lv.body.conflicts.map((a: any) => a.id)).toEqual([appt.id]);
    const during = await slotsOn(id, date);
    expect(during.map((x) => x.id)).toEqual([s[2].id]);
    expect(during[0].status).toBe('booked');
    // The appointment is NOT auto-cancelled.
    expect((await t.req(vaibhav, 'GET', `/appointments/${appt.id}`)).body.status).toBe('confirmed');
    expect((await t.req(priya, 'POST', '/doctor/me/leaves', { date })).status).toBe(409);
    expect((await t.req(priya, 'POST', '/doctor/me/leaves', { date: addDays(istDate(), -1) })).status).toBe(400);
    const sch = await t.req(priya, 'GET', '/doctor/me/schedule');
    expect(sch.body.leaves.map((l: any) => l.id)).toContain(lv.body.leave.id);
    // Another doctor cannot delete it.
    expect((await t.req(ananya, 'DELETE', `/doctor/me/leaves/${lv.body.leave.id}`)).status).toBe(404);
    expect((await t.req(priya, 'DELETE', `/doctor/me/leaves/${lv.body.leave.id}`)).status).toBe(204);
    const restored = await slotsOn(id, date);
    expect(restored).toHaveLength(4);
    expect(restored.find((x) => x.id === s[2].id)?.status).toBe('booked');
  });

  it('admin schedule endpoints (super_admin, ops_admin)', async () => {
    const id = docs['Dr. Priya Sharma'];
    const g = await t.req(ops, 'GET', `/admin/doctors/${id}/schedule`);
    expect(g.status).toBe(200);
    const weekly = [{ weekday: 1, start: '14:00', end: '15:00', slotMins: 60, modes: ['in_clinic'] }];
    const p = await t.req(ops, 'PUT', `/admin/doctors/${id}/schedule`, { weekly });
    expect(p.status).toBe(200);
    expect(p.body.weekly).toEqual(weekly);
    expect((await t.req(priya, 'GET', `/admin/doctors/${id}/schedule`)).status).toBe(403);
    expect((await t.req(ops, 'GET', `/admin/doctors/${ramesh}/schedule`)).status).toBe(404);
  });

  it('the worker horizon job only adds missing slots', async () => {
    const id = docs['Dr. Ananya Rao'];
    const before = await t.svc.db.select({ id: slots.id, status: slots.status }).from(slots).where(eq(slots.doctorId, id));
    const n = await scheduleHorizon(t.svc, new Date(Date.now() + 2 * 86400_000));
    expect(n).toBeGreaterThan(0);
    const after = await t.svc.db.select({ id: slots.id, status: slots.status }).from(slots).where(eq(slots.doctorId, id));
    const afterMap = new Map(after.map((x) => [x.id, x.status]));
    for (const b of before) expect(afterMap.get(b.id)).toBe(b.status);
    expect(after.length).toBeGreaterThan(before.length);
    expect(await scheduleHorizon(t.svc, new Date(Date.now() + 2 * 86400_000))).toBe(0); // once per IST day
  });
});

describe('profile photos and public media (section 29)', () => {
  const upload = (token: string, data: Buffer, name = 'me.png', type = 'image/png') => {
    const mp = multipart({}, { field: 'image', name, data, type });
    return t.req(token, 'POST', '/me/photo', mp.body, mp.headers);
  };

  it('doctor photo is public at /media/:id with long cache headers', async () => {
    const r = await upload(ananya, SAMPLE_PNG);
    expect(r.status).toBe(200);
    expect(r.body.photoUrl).toMatch(/^http:\/\/localhost:4000\/api\/v1\/media\/[0-9a-f-]{36}$/);
    const mediaId = r.body.photoUrl.split('/').pop();
    const pub = await t.req(null, 'GET', `/media/${mediaId}`);
    expect(pub.status).toBe(200);
    expect(pub.headers['content-type']).toBe('image/png');
    expect(pub.headers['cache-control']).toBe('public, max-age=86400');
    const d = await t.req(vaibhav, 'GET', `/doctors/${docs['Dr. Ananya Rao']}`);
    expect(d.body.photoUrl).toBe(r.body.photoUrl);
  });

  it('patient photo sets the self avatarUrl', async () => {
    const r = await upload(vaibhav, SAMPLE_PNG);
    expect(r.status).toBe(200);
    const self = (await t.req(vaibhav, 'GET', '/patients')).body.items.find((p: any) => p.isSelf);
    expect(self.avatarUrl).toBe(r.body.photoUrl);
  });

  it('rejects non-images and never serves records or non-photo media', async () => {
    expect((await upload(vaibhav, Buffer.from('%PDF-1.4 not an image at all'), 'x.pdf', 'application/pdf')).status).toBe(400);
    expect((await t.req(vaibhav, 'POST', '/me/photo', { image: 'x' })).status).toBe(400);
    const [rec] = await t.svc.db.select().from(medicalRecords).where(eq(medicalRecords.patientId, ramesh)).limit(1);
    expect((await t.req(null, 'GET', `/media/${rec.id}`)).status).toBe(404);
    // Even a media row pointing at a record file is refused unless it is a flagged profile photo under the photo prefix.
    const [row] = await t.svc.db
      .insert(media)
      .values({ ownerUserId: (await t.login(SEED_PHONES.vaibhav)).user.id, kind: 'profile_photo', publicProfilePhoto: true, storageKey: rec.storageKey!, mimeType: 'image/png', sizeBytes: 1 })
      .returning();
    expect((await t.req(null, 'GET', `/media/${row.id}`)).status).toBe(404);
    const [row2] = await t.svc.db
      .insert(media)
      .values({ ownerUserId: row.ownerUserId, kind: 'record', publicProfilePhoto: false, storageKey: 'media/profile-photos/x/y.png', mimeType: 'image/png', sizeBytes: 1 })
      .returning();
    expect((await t.req(null, 'GET', `/media/${row2.id}`)).status).toBe(404);
    expect((await t.req(null, 'GET', '/media/not-a-uuid')).status).toBe(404);
    expect((await t.req(null, 'GET', '/media/00000000-0000-0000-0000-000000000000')).status).toBe(404);
  });
});

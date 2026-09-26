import { and, eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { careEpisodes, notificationOutbox, providers, safetyEvents } from '../src/db/schema.js';
import { SEED_PHONES, firstAvailableSlot, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let vaibhavId: string;
let lakshmi: string;
let ananya: string;
let priya: string;
let meera: string;
let ops: string;
let ramesh: string;
let ananyaId: string;
let skip = 0;

beforeAll(async () => {
  t = await setup();
  const v = await t.login(SEED_PHONES.vaibhav);
  vaibhav = v.accessToken;
  vaibhavId = v.user.id;
  lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken;
  const a = await t.login(SEED_PHONES.ananya);
  ananya = a.accessToken;
  ananyaId = a.user.providerId;
  priya = (await t.login(SEED_PHONES.priya)).accessToken;
  meera = (await t.login(SEED_PHONES.meera)).accessToken;
  ops = (await t.login(SEED_PHONES.ops)).accessToken;
  ramesh = await rameshId(t, vaibhav);
});
afterAll(async () => t.close());

async function completedAppointment() {
  const slot = await firstAvailableSlot(t, vaibhav, ananyaId, skip++);
  const r = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId: ananyaId, slotId: slot.id, mode: 'video', reason: 'Review test' }, idem());
  await t.req(vaibhav, 'POST', `/payments/${r.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
  await t.req(ananya, 'POST', `/clinician/appointments/${r.body.appointment.id}/start`);
  await t.req(ananya, 'POST', `/clinician/appointments/${r.body.appointment.id}/complete`, { notes: 'ok', outcome: 'resolved' });
  return r.body.appointment.id as string;
}
const rating = async (id: string) => {
  const [p] = await t.svc.db.select({ rating: providers.rating, ratingCount: providers.ratingCount }).from(providers).where(eq(providers.id, id));
  return p;
};

describe('reviews (section 33)', () => {
  it('pending list shows completed, unreviewed services from the last 30 days', async () => {
    const r = await t.req(vaibhav, 'GET', `/reviews/pending?patientId=${ramesh}`);
    expect(r.status).toBe(200);
    expect(r.body.items).toHaveLength(1); // the seeded home visit already has a (pending) review
    expect(r.body.items[0]).toMatchObject({ targetType: 'appointment', title: 'Consultation with Dr. Ananya Rao', subtitle: 'General Physician' });
    expect((await t.req(lakshmi, 'GET', `/reviews/pending?patientId=${ramesh}`)).status).toBe(403);
    expect((await t.req(vaibhav, 'GET', '/reviews/pending')).body.items).toHaveLength(1);
  });

  it('eligibility, once-only, rating-only publishes immediately and recalculates the rating', async () => {
    const target = (await t.req(vaibhav, 'GET', `/reviews/pending?patientId=${ramesh}`)).body.items[0];
    expect(await rating(ananyaId)).toEqual({ rating: 4.8, ratingCount: 320 });
    expect((await t.req(lakshmi, 'POST', '/reviews', { targetType: 'appointment', targetId: target.targetId, rating: 5 })).status).toBe(403);
    expect((await t.req(ananya, 'POST', '/reviews', { targetType: 'appointment', targetId: target.targetId, rating: 5 })).status).toBe(403);
    expect((await t.req(vaibhav, 'POST', '/reviews', { targetType: 'appointment', targetId: target.targetId, rating: 6 })).status).toBe(400);
    const r = await t.req(vaibhav, 'POST', '/reviews', { targetType: 'appointment', targetId: target.targetId, rating: 1 });
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ status: 'published', rating: 1, text: null, doctorId: ananyaId, providerId: null, subjectName: 'Dr. Ananya Rao', authorLabel: 'Verified patient' });
    // (4.8 * 320 + 1) / 321 = 4.788 -> 4.8, count 321
    expect(await rating(ananyaId)).toEqual({ rating: 4.8, ratingCount: 321 });
    expect((await t.req(vaibhav, 'POST', '/reviews', { targetType: 'appointment', targetId: target.targetId, rating: 4 })).status).toBe(409);
    expect((await t.req(vaibhav, 'GET', `/reviews/pending?patientId=${ramesh}`)).body.items).toHaveLength(0);
  });

  it('services that are not completed cannot be reviewed', async () => {
    const slot = await firstAvailableSlot(t, vaibhav, ananyaId, skip++);
    const b = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId: ananyaId, slotId: slot.id, mode: 'video', reason: 'x' }, idem());
    expect((await t.req(vaibhav, 'POST', '/reviews', { targetType: 'appointment', targetId: b.body.appointment.id, rating: 5 })).status).toBe(409);
  });

  it('text reviews start pending; moderation publishes/rejects and recalculates; DoctorDetail shows published only', async () => {
    const id = await completedAppointment();
    const r = await t.req(vaibhav, 'POST', '/reviews', { targetType: 'appointment', targetId: id, rating: 2, text: 'Unique text 7731: consultation felt rushed.' });
    expect(r.body.status).toBe('pending');
    const before = await rating(ananyaId);
    const detail = async () => (await t.req(vaibhav, 'GET', `/doctors/${ananyaId}`)).body.reviews.map((x: any) => x.text);
    expect(await detail()).not.toContain('Unique text 7731: consultation felt rushed.');
    const pend = await t.req(meera, 'GET', '/ops/reviews?status=pending');
    expect(pend.body.items.map((x: any) => x.id)).toContain(r.body.id);
    const pub = await t.req(meera, 'POST', `/ops/reviews/${r.body.id}/moderate`, { status: 'published', note: 'Fair feedback' });
    expect(pub.body).toMatchObject({ status: 'published', moderationNote: 'Fair feedback' });
    expect((await rating(ananyaId)).ratingCount).toBe(before.ratingCount + 1);
    expect(await detail()).toContain('Unique text 7731: consultation felt rushed.');
    const rej = await t.req(ops, 'POST', `/ops/reviews/${r.body.id}/moderate`, { status: 'rejected', note: 'Contains identifying details' });
    expect(rej.body.status).toBe('rejected');
    expect(await rating(ananyaId)).toEqual(before);
    expect(await detail()).not.toContain('Unique text 7731: consultation felt rushed.');
  });

  it('the seeded pending home-visit review moderates into the provider rating', async () => {
    const pend = await t.req(ops, 'GET', '/ops/reviews?status=pending');
    const hvReview = pend.body.items.find((x: any) => x.targetType === 'home_visit');
    expect(hvReview).toMatchObject({ subjectName: 'Sunita Devi', rating: 5, doctorId: null });
    const before = await rating(hvReview.providerId);
    expect(before).toEqual({ rating: 4.7, ratingCount: 58 });
    await t.req(ops, 'POST', `/ops/reviews/${hvReview.id}/moderate`, { status: 'published' });
    expect(await rating(hvReview.providerId)).toEqual({ rating: 4.7, ratingCount: 59 });
    const sunita = (await t.login(SEED_PHONES.sunita)).accessToken;
    expect((await t.req(sunita, 'GET', '/provider/me')).body).toMatchObject({ rating: 4.7, ratingCount: 59, photoUrl: null });
    expect((await t.req(vaibhav, 'POST', `/ops/reviews/${hvReview.id}/moderate`, { status: 'rejected' })).status).toBe(403);
  });
});

describe('care-team messaging (section 34)', () => {
  let episodeId: string;

  it('seeded thread: inbox with unread count, messages oldest -> newest, read marker', async () => {
    const [ep] = await t.svc.db.select().from(careEpisodes).where(and(eq(careEpisodes.patientId, ramesh), eq(careEpisodes.title, 'Blood pressure & diabetes follow-up')));
    episodeId = ep.id;
    const inbox = await t.req(vaibhav, 'GET', '/inbox');
    expect(inbox.status).toBe(200);
    const th = inbox.body.items.find((i: any) => i.careEpisodeId === episodeId);
    expect(th).toMatchObject({ title: 'Blood pressure & diabetes follow-up', patientId: ramesh, patientName: 'Ramesh Kumar', unread: 2, lastSenderName: 'Meera Nair' });
    expect(inbox.body.items[0].careEpisodeId).toBe(episodeId); // newest first
    const msgs = await t.req(vaibhav, 'GET', `/care-episodes/${episodeId}/messages`);
    expect(msgs.body.items.map((m: any) => m.senderRole)).toEqual(['family', 'doctor', 'coordinator']);
    expect(msgs.body.items.every((m: any) => m.kind === 'text')).toBe(true);
    const after = await t.req(vaibhav, 'GET', `/care-episodes/${episodeId}/messages?after=${msgs.body.items[0].id}`);
    expect(after.body.items).toHaveLength(2);
    expect((await t.req(vaibhav, 'GET', `/care-episodes/${episodeId}/messages?after=00000000-0000-0000-0000-000000000000`)).status).toBe(400);
    expect((await t.req(vaibhav, 'POST', `/care-episodes/${episodeId}/messages/read`)).status).toBe(204);
    expect((await t.req(vaibhav, 'GET', '/inbox')).body.items.find((i: any) => i.careEpisodeId === episodeId).unread).toBe(0);
  });

  it('participants: doctor, assigned coordinator, ops as Care team; not providers, unrelated doctors or family without manage_care', async () => {
    const sunita = (await t.login(SEED_PHONES.sunita)).accessToken;
    for (const tok of [sunita, priya, lakshmi]) {
      expect((await t.req(tok, 'GET', `/care-episodes/${episodeId}/messages`)).status).toBe(403);
      expect((await t.req(tok, 'POST', `/care-episodes/${episodeId}/messages`, { text: 'hi' })).status).toBe(403);
    }
    expect((await t.req(sunita, 'GET', '/inbox')).body.items).toHaveLength(0);
    await t.req(vaibhav, 'POST', '/devices', { pushToken: 'vaibhav-device-token-1', platform: 'android' });
    const d = await t.req(ananya, 'POST', `/care-episodes/${episodeId}/messages`, { text: 'Please share this week\'s BP log.' });
    expect(d.status).toBe(201);
    expect(d.body).toMatchObject({ senderRole: 'doctor', senderName: 'Dr. Ananya Rao', kind: 'text', attachmentRecordId: null });
    const c = await t.req(meera, 'POST', `/care-episodes/${episodeId}/messages`, { text: 'I will call tomorrow.' });
    expect(c.body.senderRole).toBe('coordinator');
    const o = await t.req(ops, 'POST', `/care-episodes/${episodeId}/messages`, { text: 'Care team here.' });
    expect(o.body).toMatchObject({ senderRole: 'care_team', senderName: 'Care team' });
    expect((await t.req(vaibhav, 'GET', '/inbox')).body.items.find((i: any) => i.careEpisodeId === episodeId).unread).toBe(3);
    expect((await t.req(ananya, 'GET', '/inbox')).body.items.find((i: any) => i.careEpisodeId === episodeId).unread).toBe(2);
    expect((await t.req(ops, 'GET', '/inbox')).body.items.map((i: any) => i.careEpisodeId)).toContain(episodeId);
    // Generic push text only.
    const notes = await t.req(vaibhav, 'GET', '/notifications');
    expect(notes.body.items.filter((n: any) => n.title === 'New message').length).toBeGreaterThanOrEqual(3);
    const push = await t.svc.db.select().from(notificationOutbox).where(and(eq(notificationOutbox.userId, vaibhavId), eq(notificationOutbox.channel, 'push')));
    expect(push.length).toBeGreaterThanOrEqual(3);
    expect(push.every((p) => p.lockScreenText === 'New message from your care team')).toBe(true);
  });

  it('attachments must be records of the episode patient', async () => {
    const recs = await t.req(vaibhav, 'GET', `/records?patientId=${ramesh}`);
    const ok = await t.req(vaibhav, 'POST', `/care-episodes/${episodeId}/messages`, { text: 'Attached my report', attachmentRecordId: recs.body.items[0].id });
    expect(ok.status).toBe(201);
    expect(ok.body.attachmentRecordId).toBe(recs.body.items[0].id);
    expect((await t.req(vaibhav, 'POST', `/care-episodes/${episodeId}/messages`, { text: 'x', attachmentRecordId: '00000000-0000-0000-0000-000000000000' })).status).toBe(400);
    expect((await t.req(vaibhav, 'POST', `/care-episodes/${episodeId}/messages`, { text: '' })).status).toBe(400);
  });

  it('an emergency message from family appends the 108 notice and opens a safety event', async () => {
    const r = await t.req(vaibhav, 'POST', `/care-episodes/${episodeId}/messages`, { text: 'My father has severe chest pain and is sweating' });
    expect(r.status).toBe(201);
    const msgs = (await t.req(vaibhav, 'GET', `/care-episodes/${episodeId}/messages`)).body.items;
    const last = msgs[msgs.length - 1];
    expect(last).toMatchObject({ senderRole: 'system', kind: 'emergency_notice', senderUserId: null });
    expect(last.text).toContain('108');
    const events = await t.svc.db.select().from(safetyEvents).where(and(eq(safetyEvents.careEpisodeId, episodeId), eq(safetyEvents.source, 'message')));
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ level: 'emergency', status: 'open', patientId: ramesh });
    // Clinician messages are not screened.
    await t.req(ananya, 'POST', `/care-episodes/${episodeId}/messages`, { text: 'If there is severe chest pain, call 108.' });
    expect(await t.svc.db.select().from(safetyEvents).where(and(eq(safetyEvents.careEpisodeId, episodeId), eq(safetyEvents.source, 'message')))).toHaveLength(1);
    // The sender's own messages never count as unread.
    expect((await t.req(vaibhav, 'GET', '/inbox')).body.items.find((i: any) => i.careEpisodeId === episodeId).unread).toBeGreaterThanOrEqual(1);
  });
});

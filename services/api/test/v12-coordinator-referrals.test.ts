import { and, eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { careEpisodes, careTasks, doseLogs, facilities, medications } from '../src/db/schema.js';
import { SEED_PHONES, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let lakshmi: string;
let ananya: string;
let karthik: string;
let priya: string;
let meera: string;
let meeraId: string;
let ops: string;
let opsId: string;
let ramesh: string;
let rameshEpisode: string;

beforeAll(async () => {
  t = await setup();
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken;
  ananya = (await t.login(SEED_PHONES.ananya)).accessToken;
  karthik = (await t.login(SEED_PHONES.karthik)).accessToken;
  priya = (await t.login(SEED_PHONES.priya)).accessToken;
  const m = await t.login(SEED_PHONES.meera);
  meera = m.accessToken;
  meeraId = m.user.id;
  const o = await t.login(SEED_PHONES.ops);
  ops = o.accessToken;
  opsId = o.user.id;
  ramesh = await rameshId(t, vaibhav);
  [{ id: rameshEpisode }] = await t.svc.db.select({ id: careEpisodes.id }).from(careEpisodes).where(eq(careEpisodes.patientId, ramesh));
});
afterAll(async () => t.close());

describe('coordinator workspace (section 35)', () => {
  it('CareEpisode exposes the assigned coordinator (seeded: Meera on Ramesh)', async () => {
    const ep = await t.req(vaibhav, 'GET', `/care-episodes/${rameshEpisode}`);
    expect(ep.body).toMatchObject({ coordinatorUserId: meeraId, coordinatorName: 'Meera Nair' });
    const list = await t.req(vaibhav, 'GET', `/care-episodes?patientId=${ramesh}`);
    expect(list.body.items[0]).toHaveProperty('coordinatorUserId');
  });

  it('assignment rules: ops assigns coordinators; a coordinator may only assign themselves', async () => {
    const self = (await t.req(vaibhav, 'GET', '/patients')).body.items.find((p: any) => p.isSelf).id;
    const ep = await t.req(vaibhav, 'POST', '/care-episodes', { patientId: self, title: 'Back pain', concern: 'Lower back pain for 2 weeks' }, idem());
    expect((await t.req(ops, 'POST', `/ops/care-episodes/${ep.body.id}/assign-coordinator`, { userId: opsId })).status).toBe(400); // not a coordinator
    expect((await t.req(meera, 'POST', `/ops/care-episodes/${ep.body.id}/assign-coordinator`, { userId: opsId })).status).toBe(403);
    expect((await t.req(vaibhav, 'POST', `/ops/care-episodes/${ep.body.id}/assign-coordinator`, { userId: meeraId })).status).toBe(403);
    const r = await t.req(meera, 'POST', `/ops/care-episodes/${ep.body.id}/assign-coordinator`, { userId: meeraId });
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ id: ep.body.id, coordinatorUserId: meeraId, coordinatorName: 'Meera Nair' });
    const d = await t.req(vaibhav, 'GET', `/care-episodes/${ep.body.id}`);
    expect(d.body.events.map((e: any) => e.type)).toContain('coordinator_assigned');
    expect((await t.req(ops, 'POST', `/ops/care-episodes/${ep.body.id}/assign-coordinator`, { userId: meeraId })).status).toBe(200);
  });

  it('caseload groups active episodes by patient with flags', async () => {
    const [task] = await t.svc.db.select().from(careTasks).where(and(eq(careTasks.patientId, ramesh), eq(careTasks.title, 'HbA1c blood test')));
    await t.svc.db.update(careTasks).set({ status: 'overdue', dueAt: new Date(Date.now() - 86400_000) }).where(eq(careTasks.id, task.id));
    const [met] = await t.svc.db.select().from(medications).where(and(eq(medications.patientId, ramesh), eq(medications.name, 'Metformin')));
    await t.svc.db.insert(doseLogs).values({ medicationId: met.id, scheduledAt: new Date(Date.now() - 36 * 3600_000), status: 'missed' });
    await t.svc.safety.recordEvent(t.svc.db, { patientId: ramesh, careEpisodeId: rameshEpisode, level: 'urgent', source: 'mood', rules: [], rulePackVersion: null });
    const r = await t.req(meera, 'GET', '/coordinator/caseload');
    expect(r.status).toBe(200);
    const rk = r.body.items.find((i: any) => i.patient.id === ramesh);
    expect(rk.patient).toMatchObject({ name: 'Ramesh Kumar', isSelf: false });
    expect(rk.episodes.map((e: any) => e.id)).toContain(rameshEpisode);
    expect(rk.overdueTasks).toBeGreaterThanOrEqual(1);
    expect(rk.openTasks).toBeGreaterThanOrEqual(1);
    expect(rk.lastContactAt).not.toBeNull();
    expect(rk.nextFollowUpAt).not.toBeNull();
    expect(rk.flags).toEqual(expect.arrayContaining(['overdue_tasks', 'missed_doses', 'open_safety_event']));
    expect(rk.flags).not.toContain('no_contact_7d'); // seeded contact 3 days ago
    const vs = r.body.items.find((i: any) => i.patient.name === 'Vaibhav Kumar');
    expect(vs.flags).toEqual(['no_contact_7d']);
    expect(vs.lastContactAt).toBeNull();
    expect((await t.req(ops, 'GET', '/coordinator/caseload')).status).toBe(403);
  });

  it('contact logs append a coordinator_contact event', async () => {
    const bad = await t.req(meera, 'POST', '/coordinator/contacts', { patientId: ramesh, careEpisodeId: '00000000-0000-0000-0000-000000000000', channel: 'call', outcome: 'reached', note: 'x' });
    expect(bad.status).toBe(400);
    const r = await t.req(meera, 'POST', '/coordinator/contacts', {
      patientId: ramesh,
      careEpisodeId: rameshEpisode,
      channel: 'whatsapp',
      outcome: 'callback_requested',
      note: 'Asked to call back in the evening',
      followUpAt: new Date(Date.now() + 86400_000).toISOString(),
    });
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ patientId: ramesh, careEpisodeId: rameshEpisode, channel: 'whatsapp', outcome: 'callback_requested', coordinatorName: 'Meera Nair' });
    const ep = await t.req(vaibhav, 'GET', `/care-episodes/${rameshEpisode}`);
    expect(ep.body.events.filter((e: any) => e.type === 'coordinator_contact').length).toBeGreaterThanOrEqual(2);
    const list = await t.req(meera, 'GET', `/coordinator/contacts?patientId=${ramesh}`);
    expect(list.body.items.map((c: any) => c.id)).toContain(r.body.id);
    expect(list.body.items).toHaveLength(2);
    expect((await t.req(meera, 'GET', '/coordinator/contacts')).body.items.length).toBeGreaterThanOrEqual(2);
    expect((await t.req(vaibhav, 'POST', '/coordinator/contacts', { patientId: ramesh, channel: 'call', outcome: 'reached', note: 'x' })).status).toBe(403);
    expect((await t.req(ananya, 'GET', `/coordinator/contacts?patientId=${ramesh}`)).status).toBe(403);
  });
});

describe('referrals (section 36)', () => {
  it('doctor with a care relationship creates a referral with a letter PDF; patient is notified', async () => {
    const [hosp] = await t.svc.db.select().from(facilities).where(eq(facilities.name, 'Charminar City General Hospital'));
    const body = { careEpisodeId: rameshEpisode, facilityId: hosp.id, specialty: 'cardiologist', urgency: 'urgent', reason: 'Palpitations on exertion.', clinicalSummary: 'ECG attached in records.' };
    expect((await t.req(priya, 'POST', '/clinician/referrals', body)).status).toBe(403);
    expect((await t.req(vaibhav, 'POST', '/clinician/referrals', body)).status).toBe(403);
    expect((await t.req(ananya, 'POST', '/clinician/referrals', { ...body, specialty: 'wizard' })).status).toBe(400);
    const r = await t.req(ananya, 'POST', '/clinician/referrals', body);
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ patientId: ramesh, patientName: 'Ramesh Kumar', careEpisodeId: rameshEpisode, specialty: 'cardiologist', urgency: 'urgent', status: 'created', createdByName: 'Dr. Ananya Rao' });
    expect(r.body.facility).toMatchObject({ id: hosp.id, name: 'Charminar City General Hospital', emergency24x7: true });
    const file = await t.app.inject({ method: 'GET', url: `/api/v1/records/${r.body.letterRecordId}/file`, headers: { authorization: `Bearer ${vaibhav}` } });
    expect(file.statusCode).toBe(200);
    expect(file.rawPayload.subarray(0, 4).toString('latin1')).toBe('%PDF');
    const rec = await t.req(vaibhav, 'GET', `/records/${r.body.letterRecordId}`);
    expect(rec.body).toMatchObject({ type: 'other', source: 'clinician_verified' });
    expect((await t.req(vaibhav, 'GET', '/notifications')).body.items.some((n: any) => n.title === 'Referral created')).toBe(true);
    const ep = await t.req(vaibhav, 'GET', `/care-episodes/${rameshEpisode}`);
    expect(ep.body.events.map((e: any) => e.type)).toContain('referral_created');

    const list = await t.req(vaibhav, 'GET', `/referrals?patientId=${ramesh}`);
    expect(list.body.items.length).toBe(2); // seeded + new
    expect((await t.req(lakshmi, 'GET', `/referrals?patientId=${ramesh}`)).status).toBe(200);
    expect((await t.req(ananya, 'GET', '/referrals')).body.items.length).toBe(2);
    const stranger = (await t.login('+919866600001')).accessToken;
    expect((await t.req(stranger, 'GET', `/referrals?patientId=${ramesh}`)).status).toBe(403);

    // status transitions: creator or ops only
    expect((await t.req(karthik, 'PATCH', `/referrals/${r.body.id}`, { status: 'sent' })).status).toBe(403);
    expect((await t.req(vaibhav, 'PATCH', `/referrals/${r.body.id}`, { status: 'sent' })).status).toBe(403);
    expect((await t.req(ananya, 'PATCH', `/referrals/${r.body.id}`, { status: 'sent', note: 'Emailed to the hospital' })).body.status).toBe('sent');
    expect((await t.req(ops, 'PATCH', `/referrals/${r.body.id}`, { status: 'completed' })).body.status).toBe('completed');
    const bad = await t.req(ananya, 'PATCH', `/referrals/${r.body.id}`, { status: 'cancelled' });
    expect(bad.status).toBe(409);
    expect(bad.body.error.code).toBe('INVALID_STATE_TRANSITION');
    expect((await t.req(ananya, 'PATCH', `/referrals/${r.body.id}`, { status: 'created' })).status).toBe(400);
  });
});

import { and, eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { ambulanceRequests, checkins, discharges, facilities, homeVisits, notifications, providers, safetyEvents, supportTickets, users } from '../src/db/schema.js';
import { addDays, istDate } from '../src/lib/time.js';
import { signBody } from '../src/lib/webhooks.js';
import { advanceAmbulances } from '../src/modules/ambulance/routes.js';
import { completeDischarges } from '../src/modules/discharges/routes.js';
import { insuranceRenewals } from '../src/modules/insurance/routes.js';
import { preventiveReminders } from '../src/modules/preventive/routes.js';
import { supportSla } from '../src/modules/support/routes.js';
import { multipart } from './fakes.js';
import { samplePdf } from '../src/db/seed.js';
import { P, SEED_PHONES, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
const tok: Record<string, string> = {};
let ramesh: string;

beforeAll(async () => {
  t = await setup();
  for (const [k, phone] of Object.entries({ ...SEED_PHONES, desk: '+919800000701', support: '+919800000801', karthikDoc: SEED_PHONES.karthik })) tok[k] = (await t.login(phone)).accessToken;
  ramesh = await rameshId(t, tok.vaibhav);
});
afterAll(async () => t.close());

const uid = async (phone: string) => (await t.svc.db.select({ id: users.id }).from(users).where(eq(users.phone, phone)))[0].id;

describe('nurse route planning, attendance & supplies (section 48)', () => {
  it('route orders the day by time window then nearest neighbour, with distances and ETAs', async () => {
    const [sun] = await t.svc.db.select().from(providers).where(eq(providers.name, 'Sunita Devi'));
    const today = istDate();
    const base = new Date(`${today}T04:00:00.000Z`); // 09:30 IST
    const mk = async (lat: number, lng: number, startOffsetH: number) => {
      const [hv] = await t.svc.db.select().from(homeVisits).limit(1);
      const [row] = await t.svc.db
        .insert(homeVisits)
        .values({ ...hv, id: undefined as never, status: 'accepted', providerId: sun.id, address: { line1: 'x', city: 'Hyderabad', pincode: '500034', lat, lng }, preferredStart: new Date(base.getTime() + startOffsetH * 3600_000), preferredEnd: new Date(base.getTime() + (startOffsetH + 2) * 3600_000), completedAt: null, summary: null, timeline: [] })
        .returning();
      return row.id;
    };
    await t.svc.db.update(providers).set({ lastLat: 17.4, lastLng: 78.45 }).where(eq(providers.id, sun.id));
    const far = await mk(17.48, 78.41, 0);
    const near = await mk(17.405, 78.452, 0.5);
    const late = await mk(17.402, 78.451, 5);
    const r = await t.req(tok.sunita, 'GET', `/provider/route?date=${today}`);
    expect(r.status).toBe(200);
    expect(r.body.startLocation).toEqual({ lat: 17.4, lng: 78.45 });
    const ids = r.body.stops.map((s: any) => s.visitId);
    expect(ids.indexOf(near)).toBeLessThan(ids.indexOf(far));
    expect(ids.indexOf(far)).toBeLessThan(ids.indexOf(late));
    const s0 = r.body.stops[0];
    expect(s0).toEqual(expect.objectContaining({ order: 1, serviceName: expect.any(String), window: { start: expect.any(String), end: expect.any(String) }, lat: expect.any(Number), lng: expect.any(Number), distanceFromPrevKm: expect.any(Number), etaAt: expect.any(String) }));
    expect(r.body.totalKm).toBeGreaterThan(0);
    expect((await t.req(tok.vaibhav, 'GET', '/provider/route')).status).toBe(403);
  });

  it('attendance check-in/out and monthly summary', async () => {
    const a = await t.req(tok.sunita, 'POST', '/provider/attendance', { action: 'check_in', lat: 17.41, lng: 78.44 });
    expect(a.status).toBe(201);
    expect(a.body).toMatchObject({ action: 'check_in', lat: 17.41, lng: 78.44 });
    await t.req(tok.sunita, 'POST', '/provider/attendance', { action: 'check_out' });
    const m = await t.req(tok.sunita, 'GET', `/provider/attendance?month=${istDate().slice(0, 7)}`);
    expect(m.body.items.find((x: any) => x.date === istDate())).toMatchObject({ checkInAt: expect.any(String), checkOutAt: expect.any(String) });
  });

  it('supplies: seeded stock, usage on own visits only, restock, low-stock report', async () => {
    const s = await t.req(tok.sunita, 'GET', '/provider/supplies');
    expect(s.body.items.length).toBe(12);
    const gloves = s.body.items.find((x: any) => x.code === 'gloves');
    const [hv] = await t.svc.db.select().from(homeVisits).where(eq(homeVisits.status, 'completed'));
    const u = await t.req(tok.sunita, 'POST', '/provider/supplies/usage', { visitId: hv.id, items: [{ code: 'gloves', qty: 2 }] });
    expect(u.status).toBe(200);
    expect(u.body.items.find((x: any) => x.code === 'gloves').onHand).toBe(gloves.onHand - 2);
    expect((await t.req(tok.sunita, 'POST', '/provider/supplies/usage', { visitId: hv.id, items: [{ code: 'gloves', qty: 9999 }] })).status).toBe(409);
    expect((await t.req(tok.ravi, 'POST', '/provider/supplies/usage', { visitId: hv.id, items: [{ code: 'gloves', qty: 1 }] })).status).toBe(403);
    const low = await t.req(tok.meera, 'GET', '/ops/supplies/low-stock');
    expect(low.body.items.map((x: any) => x.code)).toEqual(expect.arrayContaining(['cotton', 'glucose_strips']));
    const [sun] = await t.svc.db.select().from(providers).where(eq(providers.name, 'Sunita Devi'));
    const rs = await t.req(tok.ops, 'POST', `/ops/providers/${sun.id}/supplies/restock`, { items: [{ code: 'cotton', qty: 20 }] });
    expect(rs.body.items.find((x: any) => x.code === 'cotton').onHand).toBe(24);
    expect((await t.req(tok.sunita, 'POST', `/ops/providers/${sun.id}/supplies/restock`, { items: [{ code: 'cotton', qty: 1 }] })).status).toBe(403);
  });
});

describe('insurance helper (section 51)', () => {
  it('insurers, cashless facility filter, policies (encrypted, masked), checklist, renewal reminders', async () => {
    const ins = await t.req(tok.vaibhav, 'GET', '/insurance/insurers');
    expect(ins.body.items.length).toBeGreaterThanOrEqual(10);
    const fac = await t.req(tok.vaibhav, 'GET', '/facilities?cashlessInsurer=star_health');
    expect(fac.body.items.length).toBe(2);
    expect(fac.body.items.every((f: any) => f.cashlessInsurers.includes('star_health'))).toBe(true);
    const list = await t.req(tok.lakshmi, 'GET', `/patients/${ramesh}/insurance-policies`);
    expect(list.body.items[0]).toMatchObject({ insurerCode: 'star_health', insurerName: 'Star Health and Allied Insurance', policyNumberMasked: 'XXXX4821', status: 'expiring_soon' });
    expect(JSON.stringify(list.body)).not.toContain('P/SAMPLE');
    const c = await t.req(tok.vaibhav, 'POST', `/patients/${ramesh}/insurance-policies`, { insurerCode: 'pmjay', policyNumber: 'PMJAY-99887766', type: 'government', validFrom: '2026-01-01', validTo: '2027-12-31' });
    expect(c.status).toBe(201);
    expect(c.body).toMatchObject({ policyNumberMasked: 'XXXX7766', status: 'active' });
    expect((await t.req(tok.lakshmi, 'POST', `/patients/${ramesh}/insurance-policies`, { insurerCode: 'pmjay', policyNumber: 'X1234', type: 'government', validFrom: '2026-01-01', validTo: '2027-01-01' })).status).toBe(403);
    expect((await t.req(tok.vaibhav, 'POST', `/patients/${ramesh}/insurance-policies`, { insurerCode: 'nope', policyNumber: 'X1234', type: 'government', validFrom: '2026-01-01', validTo: '2027-01-01' })).status).toBe(400);
    const p = await t.req(tok.vaibhav, 'PATCH', `/patients/${ramesh}/insurance-policies/${c.body.id}`, { planName: 'PM-JAY family card' });
    expect(p.body.planName).toBe('PM-JAY family card');
    expect((await t.req(tok.vaibhav, 'DELETE', `/patients/${ramesh}/insurance-policies/${c.body.id}`)).status).toBe(204);
    const chk = await t.req(tok.vaibhav, 'GET', '/insurance/claim-checklist?type=cashless');
    expect(chk.body.steps.length).toBeGreaterThan(3);
    expect(chk.body.disclaimer).toMatch(/REQUIRES CONTENT REVIEW/);
    // renewal reminders: the seeded policy expires in 25 days -> the 30-day reminder, once
    expect(await insuranceRenewals(t.svc, new Date())).toBeGreaterThanOrEqual(1);
    const vid = await uid(SEED_PHONES.vaibhav);
    const n1 = await t.svc.db.select().from(notifications).where(and(eq(notifications.userId, vid), eq(notifications.templateKey, 'insurance_renewal')));
    await insuranceRenewals(t.svc, new Date());
    const n2 = await t.svc.db.select().from(notifications).where(and(eq(notifications.userId, vid), eq(notifications.templateKey, 'insurance_renewal')));
    expect(n2.length).toBe(n1.length);
    // 7-day reminder when the policy is in its last week
    await insuranceRenewals(t.svc, new Date(Date.now() + 20 * 86400_000));
    const n3 = await t.svc.db.select().from(notifications).where(and(eq(notifications.userId, vid), eq(notifications.templateKey, 'insurance_renewal')));
    expect(n3.length).toBe(n1.length + 1);
  });
});

describe('preventive care (section 52)', () => {
  it('computes items from age and sex with the fixture schedule; records update the status; monthly reminders', async () => {
    const r = await t.req(tok.vaibhav, 'GET', `/patients/${ramesh}/preventive-schedule`);
    expect(r.body).toMatchObject({ scheduleVersion: 'preventive-fixture-0.1', scheduleStatus: 'fixture_unapproved' });
    const by = (code: string) => r.body.items.find((i: any) => i.code === code);
    expect(by('bcg').status).toBe('not_applicable');
    expect(by('cervical_screen').status).toBe('not_applicable');
    expect(by('bp_screen').status).toBe('done');
    expect(by('influenza_65').status).toBe('overdue');
    expect(by('pneumococcal_65').status).toMatch(/due|overdue/);
    const rec = await t.req(tok.vaibhav, 'POST', `/patients/${ramesh}/preventive-records`, { code: 'influenza_65', doneAt: istDate() });
    expect(rec.status).toBe(201);
    expect(rec.body).toMatchObject({ code: 'influenza_65', status: 'done', lastDoneAt: istDate() });
    expect((await t.req(tok.vaibhav, 'POST', `/patients/${ramesh}/preventive-records`, { code: 'nope', doneAt: istDate() })).status).toBe(400);
    expect((await t.req(tok.lakshmi, 'POST', `/patients/${ramesh}/preventive-records`, { code: 'bp_screen', doneAt: istDate() })).status).toBe(403);
    expect(await preventiveReminders(t.svc, new Date())).toBeGreaterThanOrEqual(1);
    const first = await t.svc.db.select().from(notifications).where(eq(notifications.templateKey, 'preventive_due'));
    await preventiveReminders(t.svc, new Date());
    expect((await t.svc.db.select().from(notifications).where(eq(notifications.templateKey, 'preventive_due'))).length).toBe(first.length);
  });
});

describe('physiotherapy & diet (sections 53-54)', () => {
  it('exercise library, plans by the doctor, sessions, progress, pain >= 8 notifies the author', async () => {
    const lib = await t.req(tok.vaibhav, 'GET', '/exercise-library?limit=100');
    expect(lib.body.items).toHaveLength(15);
    expect(lib.body.items[0].videoUrl).toBeNull();
    const knee = await t.req(tok.vaibhav, 'GET', '/exercise-library?bodyArea=knee');
    expect(knee.body.items.every((e: any) => e.bodyArea === 'knee')).toBe(true);
    const items = knee.body.items.slice(0, 2).map((e: any) => ({ exerciseId: e.id, sets: 2, reps: 10, perDay: 2 }));
    expect((await t.req(tok.sunita, 'POST', '/exercise-plans', { patientId: ramesh, items, startDate: istDate(), weeks: 4 })).status).toBe(403);
    const plan = await t.req(tok.ananya, 'POST', '/exercise-plans', { patientId: ramesh, items, startDate: istDate(), weeks: 4 });
    expect(plan.status).toBe(201);
    expect(plan.body).toMatchObject({ authorName: 'Dr. Ananya Rao', authorRole: 'doctor', status: 'active', endDate: addDays(istDate(), 27) });
    const s = await t.req(tok.vaibhav, 'POST', `/exercise-plans/${plan.body.id}/sessions`, { completedExerciseIds: [items[0].exerciseId], painScore: 9, note: 'Knee hurt' });
    expect(s.status).toBe(201);
    const aid = await uid(SEED_PHONES.ananya);
    expect((await t.svc.db.select().from(notifications).where(and(eq(notifications.userId, aid), eq(notifications.templateKey, 'exercise_pain')))).length).toBe(1);
    const prog = await t.req(tok.vaibhav, 'GET', `/exercise-plans/${plan.body.id}/progress`);
    expect(prog.body).toMatchObject({ sessionsPlanned: 2, sessionsDone: 1, adherencePct: 50, painTrend: [{ date: istDate(), painScore: 9 }] });
    expect((await t.req(tok.lakshmi, 'POST', `/exercise-plans/${plan.body.id}/sessions`, { completedExerciseIds: [], painScore: 1 })).status).toBe(403);
    expect((await t.req(tok.lakshmi, 'GET', `/exercise-plans?patientId=${ramesh}`)).body.items).toHaveLength(1);
  });

  it('diet templates, plans, logs (upsert per slot) and adherence', async () => {
    const tpl = await t.req(tok.vaibhav, 'GET', '/diet-templates');
    expect(tpl.body.items.map((x: any) => x.code).sort()).toEqual(['diabetic', 'low_salt_cardiac', 'renal']);
    expect(tpl.body.items[0].status).toBe('fixture_unapproved');
    const diabetic = tpl.body.items.find((x: any) => x.code === 'diabetic');
    const body = { patientId: ramesh, templateCode: 'diabetic', conditions: ['type 2 diabetes'], calorieTarget: 1600, meals: diabetic.meals.map((m: any) => ({ slot: m.slot, items: m.items })), avoid: diabetic.avoid, validUntil: addDays(istDate(), 30) };
    expect((await t.req(tok.meera, 'POST', '/diet-plans', body)).status).toBe(403);
    const p = await t.req(tok.ananya, 'POST', '/diet-plans', body);
    expect(p.status).toBe(201);
    expect(p.body.status).toBe('active');
    const d = istDate();
    expect((await t.req(tok.vaibhav, 'POST', `/diet-plans/${p.body.id}/logs`, { date: d, slot: 'breakfast', followed: true })).status).toBe(201);
    await t.req(tok.vaibhav, 'POST', `/diet-plans/${p.body.id}/logs`, { date: d, slot: 'lunch', followed: false });
    await t.req(tok.vaibhav, 'POST', `/diet-plans/${p.body.id}/logs`, { date: d, slot: 'lunch', followed: true, note: 'Updated' });
    const logs = await t.req(tok.lakshmi, 'GET', `/diet-plans/${p.body.id}/logs?date=${d}`);
    expect(logs.body.items).toHaveLength(2);
    expect(logs.body.items.find((l: any) => l.slot === 'lunch')).toMatchObject({ followed: true, note: 'Updated' });
    const adh = await t.req(tok.vaibhav, 'GET', `/diet-plans/${p.body.id}/adherence?days=7`);
    expect(adh.body.days).toHaveLength(7);
    expect(adh.body.adherencePct).toBe(100);
  });
});

describe('ambulance (section 55)', () => {
  it('request -> emergency SafetyEvent; the mock assigns within 20 s and moves every 10 s; cancel; ops list', async () => {
    const r = await t.req(tok.lakshmi, 'POST', '/ambulance/requests', { patientId: ramesh, pickup: { lat: 17.4126, lng: 78.4392, address: 'Sai Residency' }, type: 'bls', reason: 'Fall at home' }, { 'idempotency-key': 'amb-1' });
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ status: 'searching', vehicle: null, location: null, partnerName: expect.stringMatching(/mock/) });
    expect(r.body.payment).toBeUndefined();
    const [row] = await t.svc.db.select().from(ambulanceRequests).where(eq(ambulanceRequests.id, r.body.id));
    const [ev] = await t.svc.db.select().from(safetyEvents).where(eq(safetyEvents.id, row.safetyEventId!));
    expect(ev.level).toBe('emergency');
    const created = row.createdAt.getTime();
    await advanceAmbulances(t.svc, new Date(created + 20_000));
    const a = (await t.svc.db.select().from(ambulanceRequests).where(eq(ambulanceRequests.id, row.id)))[0];
    expect(a.status).toBe('assigned');
    expect(a.vehicle?.number).toMatch(/^TS09/);
    const p1 = a.location!;
    await advanceAmbulances(t.svc, new Date(a.assignedAt!.getTime() + 25_000));
    const b = (await t.svc.db.select().from(ambulanceRequests).where(eq(ambulanceRequests.id, row.id)))[0];
    expect(b.status).toBe('en_route');
    expect(b.location!.lat).not.toBe(p1.lat);
    const d1 = Math.abs(b.location!.lat - 17.4126);
    await advanceAmbulances(t.svc, new Date(a.assignedAt!.getTime() + 95_000));
    const c = (await t.svc.db.select().from(ambulanceRequests).where(eq(ambulanceRequests.id, row.id)))[0];
    expect(Math.abs(c.location!.lat - 17.4126)).toBeLessThan(d1);
    await advanceAmbulances(t.svc, new Date(a.assignedAt!.getTime() + 200_000));
    const done = await t.req(tok.vaibhav, 'GET', `/ambulance/requests/${row.id}`);
    expect(done.body).toMatchObject({ status: 'arrived', etaMinutes: 0 });
    expect(done.body.timeline.map((x: any) => x.status)).toEqual(['searching', 'assigned', 'en_route', 'arrived']);
    expect((await t.req(tok.vaibhav, 'POST', `/ambulance/requests/${row.id}/cancel`, { reason: 'x' })).status).toBe(409);
    const r2 = await t.req(tok.vaibhav, 'POST', '/ambulance/requests', { patientId: ramesh, pickup: { lat: 17.41, lng: 78.44, address: 'Home' }, type: 'als', reason: 'Breathless' }, { 'idempotency-key': 'amb-2' });
    const cancel = await t.req(tok.vaibhav, 'POST', `/ambulance/requests/${r2.body.id}/cancel`, { reason: 'Took a taxi' });
    expect(cancel.body.status).toBe('cancelled');
    const ops = await t.req(tok.ops, 'GET', '/ops/ambulance-requests');
    expect(ops.body.items.length).toBeGreaterThanOrEqual(2);
    expect((await t.req(tok.sunita, 'GET', `/ambulance/requests/${row.id}`)).status).toBe(403);
  });
});

describe('dementia safety (section 56)', () => {
  it('safe zone, geofence exit -> urgent SafetyEvent + family map link, return resolves; latest location permissions', async () => {
    const z = await t.req(tok.vaibhav, 'PUT', `/patients/${ramesh}/safe-zone`, { enabled: true, centerLat: 17.4126, centerLng: 78.4392, radiusMeters: 500, label: 'Home' });
    expect(z.status).toBe(200);
    expect(z.body).toMatchObject({ enabled: true, radiusMeters: 500, label: 'Home' });
    expect((await t.req(tok.vaibhav, 'PUT', `/patients/${ramesh}/safe-zone`, { enabled: true, centerLat: 17.4, centerLng: 78.4, radiusMeters: 50 })).status).toBe(400);
    expect((await t.req(tok.lakshmi, 'PUT', `/patients/${ramesh}/safe-zone`, { enabled: true, centerLat: 17.4, centerLng: 78.4, radiusMeters: 500 })).status).toBe(403);
    expect((await t.req(tok.vaibhav, 'POST', `/patients/${ramesh}/location`, { lat: 17.4127, lng: 78.4393, accuracyM: 10, source: 'phone' })).body).toEqual({ inside: true });
    const out = await t.req(tok.vaibhav, 'POST', `/patients/${ramesh}/location`, { lat: 17.43, lng: 78.46, accuracyM: 10, source: 'phone' });
    expect(out.body).toEqual({ inside: false });
    await t.req(tok.vaibhav, 'POST', `/patients/${ramesh}/location`, { lat: 17.431, lng: 78.461, accuracyM: 10, source: 'phone' });
    const evs = await t.svc.db.select().from(safetyEvents).where(and(eq(safetyEvents.patientId, ramesh), eq(safetyEvents.source, 'geofence')));
    expect(evs).toHaveLength(1);
    expect(evs[0].level).toBe('urgent');
    const lid = await uid(SEED_PHONES.lakshmi);
    const [n] = await t.svc.db.select().from(notifications).where(and(eq(notifications.userId, lid), eq(notifications.templateKey, 'geofence_exit')));
    expect(n.body).toContain('maps.google.com');
    const latest = await t.req(tok.lakshmi, 'GET', `/patients/${ramesh}/location/latest`);
    expect(latest.body).toMatchObject({ lat: 17.431, inside: false, source: 'phone' });
    expect((await t.req(tok.meera, 'GET', `/patients/${ramesh}/location/latest`)).status).toBe(200);
    await t.req(tok.vaibhav, 'POST', `/patients/${ramesh}/location`, { lat: 17.4126, lng: 78.4392, accuracyM: 10, source: 'tracker' });
    expect((await t.svc.db.select().from(safetyEvents).where(eq(safetyEvents.id, evs[0].id)))[0].status).toBe('resolved');
  });

  it('family without receive_alerts cannot read the latest location', async () => {
    const g = await t.req(tok.vaibhav, 'POST', `/patients/${ramesh}/family-access`, { granteePhone: '+919855500077', relation: 'nephew', permissions: ['view_records'] });
    expect(g.status).toBe(201);
    const nephew = (await t.login('+919855500077')).accessToken;
    expect((await t.req(nephew, 'GET', `/patients/${ramesh}/location/latest`)).status).toBe(403);
  });

  it('SOS devices: pair, list, signed vendor webhook -> SOS flow (source sos_button), unpair', async () => {
    const p = await t.req(tok.vaibhav, 'POST', `/patients/${ramesh}/sos-devices`, { deviceId: 'SOSBTN-0001', model: 'Sample Pendant' });
    expect(p.status).toBe(201);
    expect((await t.req(tok.vaibhav, 'POST', `/patients/${ramesh}/sos-devices`, { deviceId: 'SOSBTN-0001', model: 'x' })).status).toBe(409);
    const l = await t.req(tok.vaibhav, 'GET', `/patients/${ramesh}/sos-devices`);
    expect(l.body.items).toEqual([{ id: p.body.id, deviceId: 'SOSBTN-0001', model: 'Sample Pendant', pairedAt: expect.any(String) }]);
    expect((await t.req(tok.lakshmi, 'GET', `/patients/${ramesh}/sos-devices`)).status).toBe(403);
    const body = JSON.stringify({ eventId: 'sos-evt-1', deviceId: 'SOSBTN-0001', lat: 17.4126, lng: 78.4392 });
    const w = await t.app.inject({ method: 'POST', url: `${P}/webhooks/sos-button`, payload: body, headers: { 'content-type': 'application/json', 'x-sos-signature': signBody(t.svc.config.SOS_WEBHOOK_SECRET, body) } });
    expect(w.statusCode).toBe(200);
    expect(JSON.parse(w.body).careEpisodeId).toBeTruthy();
    expect((await t.svc.db.select().from(safetyEvents).where(and(eq(safetyEvents.patientId, ramesh), eq(safetyEvents.source, 'sos_button')))).length).toBe(1);
    const dup = await t.app.inject({ method: 'POST', url: `${P}/webhooks/sos-button`, payload: body, headers: { 'content-type': 'application/json', 'x-sos-signature': signBody(t.svc.config.SOS_WEBHOOK_SECRET, body) } });
    expect(JSON.parse(dup.body).duplicate).toBe(true);
    expect((await t.req(tok.vaibhav, 'DELETE', `/patients/${ramesh}/sos-devices/${p.body.id}`)).status).toBe(204);
    expect((await t.req(tok.vaibhav, 'GET', `/patients/${ramesh}/sos-devices`)).body.items).toHaveLength(0);
  });
});

describe('corporate plans & white-label (sections 57-58)', () => {
  it('organizations, codes, redeem (sponsored subscription), usage aggregates', async () => {
    const org = await t.req(tok.admin, 'POST', '/admin/organizations', { name: 'Acme Software', contactName: 'HR', contactEmail: 'hr@acme.example', planCode: 'family_plus', seats: 3, validFrom: addDays(istDate(), -1), validTo: addDays(istDate(), 365) });
    expect(org.status).toBe(201);
    expect((await t.req(tok.ops, 'POST', '/admin/organizations', {})).status).toBe(403);
    const upd = await t.req(tok.admin, 'PATCH', `/admin/organizations/${org.body.id}`, { seats: 2 });
    expect(upd.body.seats).toBe(2);
    expect((await t.req(tok.admin, 'POST', `/admin/organizations/${org.body.id}/codes`, { count: 3 })).status).toBe(409);
    const codes = await t.req(tok.admin, 'POST', `/admin/organizations/${org.body.id}/codes`, { count: 2 });
    expect(codes.body.codes).toHaveLength(2);
    expect(codes.body.codes[0]).toMatch(/^[A-Z0-9]{10}$/);
    const emp = (await t.login('+919855500010')).accessToken;
    const red = await t.req(emp, 'POST', '/subscriptions/redeem', { code: codes.body.codes[0] });
    expect(red.status).toBe(201);
    expect(red.body).toMatchObject({ status: 'active', planCode: 'family_plus', sponsorName: 'Acme Software' });
    expect((await t.req(tok.lakshmi, 'POST', '/subscriptions/redeem', { code: codes.body.codes[0] })).status).toBe(409);
    expect((await t.req(emp, 'POST', '/subscriptions/redeem', { code: codes.body.codes[1] })).status).toBe(409); // already active
    const usage = await t.req(tok.admin, 'GET', `/admin/organizations/${org.body.id}/usage`);
    expect(usage.body).toEqual({ seats: 2, redeemed: 1, activeMembers: 1, servicesUsed: { appointments: 0, homeVisits: 0, labOrders: 0 } });
  });

  it('tenants: admin CRUD by id with logoUrl, public branding, tenant set via X-Tenant-Code at signup', async () => {
    const list = await t.req(tok.admin, 'GET', '/admin/tenants');
    const deccan = list.body.items.find((x: any) => x.code === 'deccan-sunrise');
    expect(deccan).toMatchObject({ displayName: 'Deccan Sunrise Multispeciality', primaryColor: '#B45309', logoUrl: null });
    const pub = await t.req(null, 'GET', '/config/public?tenant=deccan-sunrise');
    expect(pub.body.branding).toMatchObject({ tenantCode: 'deccan-sunrise', displayName: 'Deccan Sunrise Multispeciality', primaryColor: '#B45309' });
    expect((await t.req(null, 'GET', '/config/public?tenant=unknown')).body.branding).toBeNull();
    const [f] = await t.svc.db.select().from(facilities).limit(1);
    const c = await t.req(tok.admin, 'POST', '/admin/tenants', { code: 'city-care', displayName: 'City Care', primaryColor: '#123456', facilityIds: [f.id] });
    expect(c.status).toBe(201);
    expect((await t.req(tok.admin, 'POST', '/admin/tenants', { code: 'bad', displayName: 'x', primaryColor: 'red', facilityIds: [] })).status).toBe(400);
    const p = await t.req(tok.admin, 'PATCH', `/admin/tenants/${c.body.id}`, { displayName: 'City Care Hospitals' });
    expect(p.body.displayName).toBe('City Care Hospitals');
    expect((await t.req(tok.ops, 'GET', '/admin/tenants')).status).toBe(403);
    const r1 = await t.req(null, 'POST', '/auth/otp/request', { phone: '+919855500011' });
    const v = await t.req(null, 'POST', '/auth/otp/verify', { phone: '+919855500011', otp: r1.body.devOtp }, { 'x-tenant-code': 'deccan-sunrise' });
    const me = await t.req(v.body.accessToken, 'GET', `/patients/${v.body.user.selfPatientId}`);
    expect(me.body.tenantCode).toBe('deccan-sunrise');
  });
});

describe('hospital post-discharge programs (section 59)', () => {
  const create = (token: string, overrides: Record<string, string> = {}) => {
    const mp = multipart(
      {
        patient: JSON.stringify({ name: 'Govind Rao', phone: '+919855500020', dob: '1950-02-02', gender: 'male' }),
        familyPhone: '+919855500021',
        dischargeDate: addDays(istDate(), -1),
        diagnosisSummary: 'Community-acquired pneumonia, recovered on oral antibiotics.',
        treatingDoctorName: 'Dr. P. Varma',
        followUp: JSON.stringify({ tasks: [{ title: 'Complete antibiotics course', type: 'medication', dayOffset: 5 }], medications: [{ name: 'Amoxicillin', dose: '500mg', frequency: 'Three times daily', times: ['08:00', '14:00', '20:00'], durationDays: 5 }], followUpDays: [7, 30] }),
        programTemplateCode: 'hypertension',
        ...overrides,
      },
      { field: 'file', name: 'discharge.pdf', data: samplePdf('Discharge summary'), type: 'application/pdf' },
    );
    return t.app.inject({ method: 'POST', url: `${P}/discharges`, payload: mp.body, headers: { ...mp.headers, authorization: `Bearer ${token}` } });
  };

  it('creates patient, invites, episode, hospital-issued care plan with tasks, 30-day check-in, enrollment, record, coordinator and tenant', async () => {
    expect((await create(tok.vaibhav)).statusCode).toBe(403);
    const r = await create(tok.desk);
    expect(r.statusCode).toBe(201);
    const d = JSON.parse(r.body);
    expect(d).toMatchObject({ status: 'active', patientName: 'Govind Rao', treatingDoctorName: 'Dr. P. Varma', day: 1, tasksTotal: 3, tasksDone: 0, invitedPhones: ['+919855500020', '+919855500021'] });
    expect(d.facility.name).toMatch(/Deccan Sunrise/);
    expect(d.enrollmentId).toBeTruthy();
    const patient = (await t.login('+919855500020')).accessToken;
    const me = await t.req(patient, 'GET', `/patients/${d.patientId}`);
    expect(me.body.tenantCode).toBe('deccan-sunrise');
    const ep = await t.req(patient, 'GET', `/care-episodes/${d.careEpisodeId}`);
    expect(ep.body).toMatchObject({ status: 'FOLLOW_UP', tenantCode: 'deccan-sunrise', coordinatorName: expect.any(String) });
    expect(ep.body.carePlans[0].doctorName).toMatch(/Hospital-issued/);
    expect(ep.body.carePlans[0].doctorId).toBeNull();
    const cs = await t.req(patient, 'GET', `/patients/${d.patientId}/checkin-settings`);
    expect(cs.body.enabled).toBe(true);
    const recs = await t.req(patient, 'GET', `/records?patientId=${d.patientId}`);
    expect(recs.body.items[0]).toMatchObject({ type: 'discharge_summary', source: 'imported', importedVia: 'hospital_discharge' });
    const fam = (await t.login('+919855500021')).accessToken;
    expect((await t.req(fam, 'GET', `/patients/${d.patientId}`)).status).toBe(200);
    const list = await t.req(tok.desk, 'GET', '/discharges?status=active');
    expect(list.body.items.length).toBe(2); // seeded + new
    expect((await t.req(tok.desk, 'GET', `/discharges/${d.id}`)).body.id).toBe(d.id);
    // validation
    expect((await create(tok.desk, { patient: '{bad json' })).statusCode).toBe(400);
  });

  it('hospital staff cannot see other facilities’ discharges', async () => {
    const [other] = await t.svc.db.select().from(facilities).where(eq(facilities.type, 'clinic')).limit(1);
    const [d] = await t.svc.db.select().from(discharges).limit(1);
    const staffOther = await t.req(tok.admin, 'POST', '/admin/staff', { phone: '+919855500030', name: 'Clinic Desk', roles: ['hospital_staff'], facilityId: other.id });
    expect(staffOther.status).toBe(201);
    expect((await t.req(tok.admin, 'POST', '/admin/staff', { phone: '+919855500031', name: 'No Facility', roles: ['hospital_staff'] })).status).toBe(400);
    const tk = (await t.login('+919855500030')).accessToken;
    expect((await t.req(tk, 'GET', `/discharges/${d.id}`)).status).toBe(403);
    expect((await t.req(tk, 'GET', '/discharges')).body.items).toHaveLength(0);
    expect((await t.req(tok.vaibhav, 'GET', '/discharges')).status).toBe(403);
  });

  it('the worker completes the program at day 30', async () => {
    const before = await t.svc.db.select().from(discharges).where(eq(discharges.status, 'active'));
    expect(await completeDischarges(t.svc, new Date())).toBe(0);
    expect(await completeDischarges(t.svc, new Date(Date.now() + 31 * 86400_000))).toBe(before.length);
    const after = await t.req(tok.desk, 'GET', '/discharges?status=completed');
    expect(after.body.items.length).toBe(before.length);
  });
});

describe('support desk (section 61)', () => {
  it('tickets, agent replies, internal notes hidden from customers, rating, metrics, SLA breach', async () => {
    const c = await t.req(tok.vaibhav, 'POST', '/support/tickets', { subject: 'Payment deducted twice', category: 'payment', message: 'My card was charged twice.' });
    expect(c.status).toBe(201);
    expect(c.body).toMatchObject({ number: expect.stringMatching(/^T-\d{6}$/), status: 'open', priority: 'normal', rating: null });
    const id = c.body.id;
    expect((await t.req(tok.vaibhav, 'POST', `/ops/support/tickets/${id}/reply`, { text: 'x' })).status).toBe(403);
    const note = await t.req(tok.support, 'POST', `/ops/support/tickets/${id}/reply`, { text: 'Customer looks legit; check gateway logs', internal: true });
    expect(note.status).toBe(201);
    const reply = await t.req(tok.support, 'POST', `/ops/support/tickets/${id}/reply`, { text: 'We are checking with the bank.' });
    expect(reply.body.internal).toBe(false);
    const mine = await t.req(tok.vaibhav, 'GET', `/support/tickets/${id}`);
    expect(mine.body.messages.map((m: any) => m.text)).toEqual(['My card was charged twice.', 'We are checking with the bank.']);
    expect(JSON.stringify(mine.body)).not.toContain('gateway logs');
    expect(JSON.stringify((await t.req(tok.vaibhav, 'GET', '/support/tickets')).body)).not.toContain('gateway logs');
    const agentView = await t.req(tok.support, 'GET', `/support/tickets/${id}`);
    expect(agentView.body.messages.some((m: any) => m.internal)).toBe(true);
    expect((await t.req(tok.lakshmi, 'GET', `/support/tickets/${id}`)).status).toBe(404);
    expect((await t.req(tok.vaibhav, 'POST', `/support/tickets/${id}/rating`, { score: 5 })).status).toBe(409);
    await t.req(tok.support, 'PATCH', `/ops/support/tickets/${id}`, { status: 'resolved' });
    const rated = await t.req(tok.vaibhav, 'POST', `/support/tickets/${id}/rating`, { score: 4, comment: 'Thanks' });
    expect(rated.body.rating).toEqual({ score: 4, comment: 'Thanks' });
    const sid = await uid('+919800000801');
    expect((await t.req(tok.meera, 'POST', `/ops/support/tickets/${id}/assign`, { userId: sid })).body.assignedToName).toBe('Support Desk');
    expect((await t.req(tok.meera, 'POST', `/ops/support/tickets/${id}/assign`, { userId: await uid(SEED_PHONES.vaibhav) })).status).toBe(400);
    const mine2 = await t.req(tok.support, 'GET', '/ops/support/tickets?assignedTo=me');
    expect(mine2.body.items.some((x: any) => x.id === id)).toBe(true);
    const m = await t.req(tok.ops, 'GET', '/ops/support/metrics');
    expect(m.body).toEqual(expect.objectContaining({ open: expect.any(Number), avgFirstResponseMins: expect.any(Number), csatAvg: expect.any(Number), byCategory: expect.objectContaining({ payment: 1 }) }));
    // SLA breach for a ticket without a first response
    const late = await t.req(tok.lakshmi, 'POST', '/support/tickets', { subject: 'App crashes', category: 'app_issue', message: 'Crashes on start' });
    expect(await supportSla(t.svc, new Date(Date.now() + 5 * 3600_000))).toBeGreaterThanOrEqual(1);
    const [tk] = await t.svc.db.select().from(supportTickets).where(eq(supportTickets.id, late.body.id));
    expect(tk.slaBreachedAt).toBeTruthy();
    expect(await supportSla(t.svc, new Date(Date.now() + 6 * 3600_000))).toBe(0);
  });

  it('clinical_concern tickets open a SafetyEvent review (high priority, 30-minute SLA)', async () => {
    const c = await t.req(tok.lakshmi, 'POST', '/support/tickets', { subject: 'Medicine side effect?', category: 'clinical_concern', message: 'Feeling dizzy after the new tablet' });
    expect(c.body.priority).toBe('high');
    expect(new Date(c.body.slaDueAt).getTime() - new Date(c.body.createdAt).getTime()).toBeLessThanOrEqual(31 * 60_000);
    expect(c.body.messages.some((m: any) => m.authorRole === 'system')).toBe(true);
    const [tk] = await t.svc.db.select().from(supportTickets).where(eq(supportTickets.id, c.body.id));
    const [ev] = await t.svc.db.select().from(safetyEvents).where(eq(safetyEvents.id, tk.safetyEventId!));
    expect(ev.level).toBe('urgent');
    const em = await t.req(tok.lakshmi, 'POST', '/support/tickets', { subject: 'Urgent', category: 'clinical_concern', message: 'My mother has chest pain right now' });
    expect(em.body.priority).toBe('urgent');
  });
});

describe('coordinator caseload flags and doctor episode access (v1.3 additions)', () => {
  it('caseload shows missed_checkin and program_breach flags', async () => {
    const today = istDate();
    await t.svc.db.insert(checkins).values({ patientId: ramesh, date: addDays(today, -1), status: 'missed' }).onConflictDoUpdate({ target: [checkins.patientId, checkins.date], set: { status: 'missed' } });
    await t.req(tok.vaibhav, 'POST', '/vitals', { patientId: ramesh, type: 'bp_systolic', value: 175, unit: 'mmHg', measuredAt: new Date().toISOString() });
    const cl = await t.req(tok.meera, 'GET', '/coordinator/caseload');
    const item = cl.body.items.find((x: any) => x.patient.id === ramesh);
    expect(item.flags).toEqual(expect.arrayContaining(['missed_checkin', 'program_breach']));
    expect(cl.body.items[0].patient.id).toBe(ramesh);
  });

  it('GET /care-episodes?patientId= works for a linked doctor and is forbidden for an unrelated one', async () => {
    const ok = await t.req(tok.ananya, 'GET', `/care-episodes?patientId=${ramesh}`);
    expect(ok.status).toBe(200);
    expect(ok.body.items.every((e: any) => e.patientId === ramesh)).toBe(true);
    expect(ok.body.items.length).toBeGreaterThan(0);
    expect((await t.req(tok.priya, 'GET', `/care-episodes?patientId=${ramesh}`)).status).toBe(403);
  });
});

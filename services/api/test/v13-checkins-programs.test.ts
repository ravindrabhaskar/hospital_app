import { and, eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { checkins, medicalRecords, notifications, programEnrollments, safetyEvents, users } from '../src/db/schema.js';
import { addDays, istDate, istToUtc } from '../src/lib/time.js';
import { checkinMonitor } from '../src/modules/checkins/service.js';
import { weekKey, weeklyReports } from '../src/modules/programs/service.js';
import { SEED_PHONES, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let lakshmi: string;
let ananya: string;
let meera: string;
let admin: string;
let ramesh: string;

beforeAll(async () => {
  t = await setup();
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken;
  ananya = (await t.login(SEED_PHONES.ananya)).accessToken;
  meera = (await t.login(SEED_PHONES.meera)).accessToken;
  admin = (await t.login(SEED_PHONES.admin)).accessToken;
  ramesh = await rameshId(t, vaibhav);
});
afterAll(async () => t.close());

const userId = async (phone: string) => (await t.svc.db.select({ id: users.id }).from(users).where(eq(users.phone, phone)))[0].id;

describe('section 41: daily check-in', () => {
  it('seeded settings for Ramesh (08:00-10:00) and a 30-day history including missed days', async () => {
    const s = await t.req(lakshmi, 'GET', `/patients/${ramesh}/checkin-settings`);
    expect(s.status).toBe(200);
    expect(s.body).toMatchObject({ patientId: ramesh, enabled: true, windowStart: '08:00', windowEnd: '10:00', notifyFamily: true, notifyCoordinator: true });
    const h = await t.req(vaibhav, 'GET', `/patients/${ramesh}/checkins?days=12`);
    expect(h.status).toBe(200);
    expect(h.body.items.length).toBeGreaterThanOrEqual(11);
    expect(h.body.items.map((c: any) => c.status)).toContain('missed');
    expect(h.body.items.every((c: any) => ['ok', 'late', 'missed', 'pending'].includes(c.status))).toBe(true);
  });

  it('PUT needs manage_care and validates the window', async () => {
    const body = { enabled: true, windowStart: '07:30', windowEnd: '09:30', escalateAfterMins: 45, notifyFamily: true, notifyCoordinator: true };
    expect((await t.req(lakshmi, 'PUT', `/patients/${ramesh}/checkin-settings`, body)).status).toBe(403);
    expect((await t.req(vaibhav, 'PUT', `/patients/${ramesh}/checkin-settings`, { ...body, windowEnd: '07:00' })).status).toBe(400);
    const r = await t.req(vaibhav, 'PUT', `/patients/${ramesh}/checkin-settings`, body);
    expect(r.status).toBe(200);
    expect(r.body.windowStart).toBe('07:30');
    await t.req(vaibhav, 'PUT', `/patients/${ramesh}/checkin-settings`, { ...body, windowStart: '08:00', windowEnd: '10:00', escalateAfterMins: 60 });
  });

  it('worker: missed at windowEnd -> family alert; +escalateAfterMins -> urgent SafetyEvent to the coordinator; a later check-in auto-resolves it', async () => {
    const today = istDate();
    await t.svc.db.delete(checkins).where(and(eq(checkins.patientId, ramesh), eq(checkins.date, today)));
    // before the window ends nothing happens
    expect(await checkinMonitor(t.svc, istToUtc(today, '09:59'))).toBe(0);
    await checkinMonitor(t.svc, istToUtc(today, '10:05'));
    const [row] = await t.svc.db.select().from(checkins).where(and(eq(checkins.patientId, ramesh), eq(checkins.date, today)));
    expect(row.status).toBe('missed');
    const lakshmiId = await userId(SEED_PHONES.lakshmi);
    const famNotes = await t.svc.db.select().from(notifications).where(and(eq(notifications.userId, lakshmiId), eq(notifications.templateKey, 'checkin_missed')));
    expect(famNotes).toHaveLength(1);
    expect(famNotes[0].category).toBe('checkin');
    // idempotent: no second alert
    await checkinMonitor(t.svc, istToUtc(today, '10:20'));
    expect(await t.svc.db.select().from(notifications).where(and(eq(notifications.userId, lakshmiId), eq(notifications.templateKey, 'checkin_missed')))).toHaveLength(1);
    // escalation after 60 more minutes
    await checkinMonitor(t.svc, istToUtc(today, '11:06'));
    const [esc] = await t.svc.db.select().from(checkins).where(eq(checkins.id, row.id));
    expect(esc.safetyEventId).toBeTruthy();
    const [ev] = await t.svc.db.select().from(safetyEvents).where(eq(safetyEvents.id, esc.safetyEventId!));
    expect(ev).toMatchObject({ level: 'urgent', source: 'checkin', status: 'open', assignedToName: 'Meera Nair' });
    const ops = await t.req(meera, 'GET', '/ops/safety-events?status=open');
    expect(ops.body.items.some((e: any) => e.id === ev.id && e.source === 'checkin')).toBe(true);
    // a later check-in resolves it
    const c = await t.req(vaibhav, 'POST', `/patients/${ramesh}/checkins`, { mood: 4 });
    expect(c.status).toBe(201);
    expect(c.body.status).toBe('late');
    const [resolved] = await t.svc.db.select().from(safetyEvents).where(eq(safetyEvents.id, ev.id));
    expect(resolved.status).toBe('resolved');
  });

  it('a family member without manage_care cannot check in for the patient', async () => {
    expect((await t.req(lakshmi, 'POST', `/patients/${ramesh}/checkins`, {})).status).toBe(403);
  });
});

describe('section 42: chronic care programs', () => {
  it('lists the three fixture templates with versions and status', async () => {
    const r = await t.req(vaibhav, 'GET', '/care-programs/templates');
    expect(r.status).toBe(200);
    expect(r.body.items.map((x: any) => x.code)).toEqual(['diabetes', 'heart_failure', 'hypertension']);
    const h = r.body.items.find((x: any) => x.code === 'hypertension');
    expect(h.status).toBe('fixture_unapproved');
    expect(h.defaultThresholds.map((x: any) => [x.op, x.value, x.level])).toEqual([
      ['gt', 160, 'urgent'],
      ['gt', 180, 'emergency'],
      ['lt', 90, 'urgent'],
    ]);
  });

  it('seeded hypertension enrollment for Ramesh with 14 days of readings', async () => {
    const r = await t.req(vaibhav, 'GET', `/care-programs/enrollments?patientId=${ramesh}`);
    expect(r.status).toBe(200);
    const e = r.body.items.find((x: any) => x.templateCode === 'hypertension');
    expect(e).toMatchObject({ status: 'active', thresholdsApprovedByName: 'Dr. Ananya Rao', patientName: 'Ramesh Kumar' });
    expect(e.adherencePct7d).toBeGreaterThan(80);
    const sum = await t.req(lakshmi, 'GET', `/care-programs/enrollments/${e.id}/summary?from=${addDays(istDate(), -14)}&to=${istDate()}`);
    expect(sum.status).toBe(200);
    expect(sum.body.receivedReadings).toBeGreaterThanOrEqual(26);
    expect(new Set(sum.body.trend.map((x: any) => x.date)).size).toBeGreaterThanOrEqual(14);
  });

  it('enrollment rules: doctor sets thresholds; coordinator only with approved templates; patients cannot enrol', async () => {
    expect((await t.req(vaibhav, 'POST', '/care-programs/enrollments', { patientId: ramesh, templateCode: 'diabetes', startDate: istDate() })).status).toBe(403);
    const coord = await t.req(meera, 'POST', '/care-programs/enrollments', { patientId: ramesh, templateCode: 'diabetes', startDate: istDate() });
    expect(coord.status).toBe(403); // fixture template is not approved
    const doc = await t.req(ananya, 'POST', '/care-programs/enrollments', {
      patientId: ramesh,
      templateCode: 'diabetes',
      startDate: istDate(),
      thresholds: [{ type: 'blood_glucose', op: 'gt', value: 250, level: 'urgent', message: 'High sugar' }],
    });
    expect(doc.status).toBe(201);
    expect(doc.body.thresholdsApprovedByName).toBe('Dr. Ananya Rao');
    expect((await t.req(ananya, 'POST', '/care-programs/enrollments', { patientId: ramesh, templateCode: 'diabetes', startDate: istDate() })).status).toBe(409);
  });

  it('a vital breaching a threshold creates a program SafetyEvent and alerts family; the program never lowers the engine level', async () => {
    const before = await t.svc.db.select().from(safetyEvents).where(and(eq(safetyEvents.patientId, ramesh), eq(safetyEvents.source, 'program')));
    const v = await t.req(vaibhav, 'POST', '/vitals', { patientId: ramesh, type: 'bp_systolic', value: 172, unit: 'mmHg', measuredAt: new Date().toISOString() });
    expect(v.status).toBe(201);
    const after = await t.svc.db.select().from(safetyEvents).where(and(eq(safetyEvents.patientId, ramesh), eq(safetyEvents.source, 'program')));
    expect(after.length).toBe(before.length + 1);
    const ev = after.find((a) => !before.some((b) => b.id === a.id))!;
    expect(ev.level).toBe('urgent');
    const lakshmiId = await userId(SEED_PHONES.lakshmi);
    expect((await t.svc.db.select().from(notifications).where(and(eq(notifications.userId, lakshmiId), eq(notifications.templateKey, 'program_breach')))).length).toBeGreaterThan(0);
    // Lower the program threshold level to routine: the engine (systolic > 180 -> urgent) still wins.
    const [en] = await t.svc.db.select().from(programEnrollments).where(and(eq(programEnrollments.patientId, ramesh), eq(programEnrollments.templateCode, 'hypertension')));
    const p = await t.req(ananya, 'PATCH', `/care-programs/enrollments/${en.id}`, { thresholds: [{ type: 'bp_systolic', op: 'gt', value: 150, level: 'routine', message: 'Note only' }] });
    expect(p.status).toBe(200);
    await t.req(vaibhav, 'POST', '/vitals', { patientId: ramesh, type: 'bp_systolic', value: 186, unit: 'mmHg', measuredAt: new Date().toISOString() });
    const latest = (await t.svc.db.select().from(safetyEvents).where(and(eq(safetyEvents.patientId, ramesh), eq(safetyEvents.source, 'program')))).sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())[0];
    expect(latest.level).toBe('urgent');
    const list = await t.req(vaibhav, 'GET', `/care-programs/enrollments?patientId=${ramesh}`);
    expect(list.body.items.find((x: any) => x.id === en.id).openBreaches).toBeGreaterThanOrEqual(2);
    // only a doctor may patch
    expect((await t.req(meera, 'PATCH', `/care-programs/enrollments/${en.id}`, { status: 'paused' })).status).toBe(403);
  });

  it('weekly report: one PDF record per active enrollment per week, family notified, idempotent', async () => {
    const monday = weekKey(istDate());
    const at = istToUtc(monday, '09:30');
    const n = await weeklyReports(t.svc, at, { force: true });
    expect(n).toBeGreaterThanOrEqual(1);
    expect(await weeklyReports(t.svc, at, { force: true })).toBe(0);
    const recs = await t.svc.db.select().from(medicalRecords).where(eq(medicalRecords.patientId, ramesh));
    const rep = recs.find((r) => r.title.startsWith('Weekly health report'));
    expect(rep).toBeTruthy();
    const file = await t.req(vaibhav, 'GET', `/records/${rep!.id}/file`);
    expect(file.status).toBe(200);
    expect(String(file.body).slice(0, 4)).toBe('%PDF');
    // not a Monday morning -> nothing without force
    expect(await weeklyReports(t.svc, istToUtc(addDays(monday, 2), '10:00'))).toBe(0);
  });

  it('admin template versioning: POST with an existing code creates the next version; PATCH creates a version; approval refuses fixtures', async () => {
    const tpl = { code: 'hypertension', name: 'BP program v2', description: 'Clinician-authored text', metrics: [{ type: 'bp_systolic', frequency: 'daily', unit: 'mmHg' }], defaultThresholds: [{ type: 'bp_systolic', op: 'gt', value: 170, level: 'urgent', message: 'Review' }] };
    const a = await t.req(admin, 'POST', '/admin/care-programs/templates', tpl);
    expect(a.status).toBe(201);
    expect(a.body.version).toBe('v2');
    const b = await t.req(admin, 'POST', '/admin/care-programs/templates', tpl);
    expect(b.body.version).toBe('v3');
    const pch = await t.req(admin, 'PATCH', '/admin/care-programs/templates/hypertension', { name: 'BP program v4' });
    expect(pch.status).toBe(200);
    expect(pch.body).toMatchObject({ version: 'v4', name: 'BP program v4', status: 'fixture_unapproved' });
    const ok = await t.req(admin, 'POST', '/admin/care-programs/templates/hypertension/approve', { approverName: 'Dr. Governance Lead', approverRegistration: 'REG-1' });
    expect(ok.status).toBe(200);
    expect(ok.body.status).toBe('approved');
    const fx = await t.req(admin, 'POST', '/admin/care-programs/templates/diabetes/approve', { approverName: 'Dr. Governance Lead' });
    expect(fx.status).toBe(409);
    // the approved version is now the active one; a coordinator may enrol with it
    const pub = await t.req(vaibhav, 'GET', '/care-programs/templates');
    expect(pub.body.items.find((x: any) => x.code === 'hypertension')).toMatchObject({ status: 'approved', version: 'v4' });
    expect((await t.req(ananya, 'GET', '/admin/care-programs/templates')).status).toBe(403);
  });
});

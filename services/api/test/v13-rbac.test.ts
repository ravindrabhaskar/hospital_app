import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { appointments, discharges, labTests, medicalRecords, programEnrollments, providers, supportTickets } from '../src/db/schema.js';
import { addDays, istDate } from '../src/lib/time.js';
import { SEED_PHONES, idem, rameshId, setup, type TestCtx } from './helpers.js';

/**
 * v1.3 authorization matrix: every new endpoint answers 401 without a token, 403 (or 404 where existence must not
 * leak) for roles that must not use it, and is reachable (not 401/403) for a role that may.
 */
let t: TestCtx;
const tok: Record<string, string> = {};
const ids: Record<string, string> = {};

beforeAll(async () => {
  t = await setup();
  for (const [k, phone] of Object.entries({
    vaibhav: SEED_PHONES.vaibhav,
    lakshmi: SEED_PHONES.lakshmi,
    ananya: SEED_PHONES.ananya,
    karthik: SEED_PHONES.karthik,
    sunita: SEED_PHONES.sunita,
    meera: SEED_PHONES.meera,
    ops: SEED_PHONES.ops,
    admin: SEED_PHONES.admin,
    desk: SEED_PHONES.hospitalDesk,
    support: SEED_PHONES.support,
    stranger: '+919844400099',
  })) {
    tok[k] = (await t.login(phone)).accessToken;
  }
  ids.ramesh = await rameshId(t, tok.vaibhav);
  [{ id: ids.enrollment }] = await t.svc.db.select({ id: programEnrollments.id }).from(programEnrollments).where(eq(programEnrollments.patientId, ids.ramesh));
  [{ id: ids.discharge }] = await t.svc.db.select({ id: discharges.id }).from(discharges);
  [{ id: ids.ticket }] = await t.svc.db.select({ id: supportTickets.id }).from(supportTickets).where(eq(supportTickets.category, 'refund'));
  [{ id: ids.appt }] = await t.svc.db.select({ id: appointments.id }).from(appointments).where(eq(appointments.patientId, ids.ramesh));
  [{ id: ids.record }] = await t.svc.db.select({ id: medicalRecords.id }).from(medicalRecords).where(eq(medicalRecords.patientId, ids.ramesh));
  [{ id: ids.test }] = await t.svc.db.select({ id: labTests.id }).from(labTests).limit(1);
  [{ id: ids.sunitaProv }] = await t.svc.db.select({ id: providers.id }).from(providers).where(eq(providers.name, 'Sunita Devi'));
  const lo = await t.req(tok.vaibhav, 'POST', '/lab/orders', {
    patientId: ids.ramesh,
    testIds: [ids.test],
    address: { line1: 'x', city: 'Hyderabad', pincode: '500034' },
    preferredStart: new Date(Date.now() + 86400_000).toISOString(),
    preferredEnd: new Date(Date.now() + 90000_000).toISOString(),
  }, { 'idempotency-key': 'rbac-lab' });
  ids.labOrder = lo.body.order.id;
  const amb = await t.req(tok.vaibhav, 'POST', '/ambulance/requests', { patientId: ids.ramesh, pickup: { lat: 17.41, lng: 78.44, address: 'Home' }, type: 'bls', reason: 'test' }, { 'idempotency-key': 'rbac-amb' });
  ids.amb = amb.body.id;
  const ex = await t.req(tok.vaibhav, 'GET', '/exercise-library?limit=1');
  ids.exercise = ex.body.items[0].id;
  const plan = await t.req(tok.ananya, 'POST', '/exercise-plans', { patientId: ids.ramesh, items: [{ exerciseId: ids.exercise, sets: 1, reps: 5, perDay: 1 }], startDate: istDate(), weeks: 1 });
  ids.exPlan = plan.body.id;
  const diet = await t.req(tok.ananya, 'POST', '/diet-plans', { patientId: ids.ramesh, conditions: [], meals: [{ slot: 'lunch', items: ['Dal'] }], avoid: [], validUntil: addDays(istDate(), 10) });
  ids.dietPlan = diet.body.id;
});
afterAll(async () => t.close());

type Case = { name: string; method: string; url: () => string; body?: () => unknown; allow: string; deny: string[] };
const R = () => ids.ramesh;

const CASES: Case[] = [
  // 41
  { name: 'checkin settings read', method: 'GET', url: () => `/patients/${R()}/checkin-settings`, allow: 'lakshmi', deny: ['stranger', 'sunita', 'support'] },
  { name: 'checkin settings write', method: 'PUT', url: () => `/patients/${R()}/checkin-settings`, body: () => ({ enabled: true, windowStart: '08:00', windowEnd: '10:00', escalateAfterMins: 60, notifyFamily: true, notifyCoordinator: true }), allow: 'vaibhav', deny: ['lakshmi', 'stranger', 'sunita'] },
  { name: 'checkin create', method: 'POST', url: () => `/patients/${R()}/checkins`, body: () => ({}), allow: 'vaibhav', deny: ['lakshmi', 'stranger', 'meera'] },
  { name: 'checkin history', method: 'GET', url: () => `/patients/${R()}/checkins`, allow: 'meera', deny: ['stranger', 'sunita'] },
  // 42
  { name: 'enroll', method: 'POST', url: () => '/care-programs/enrollments', body: () => ({ patientId: R(), templateCode: 'heart_failure', startDate: istDate() }), allow: 'ananya', deny: ['vaibhav', 'sunita', 'support', 'karthik'] },
  { name: 'enrollment patch', method: 'PATCH', url: () => `/care-programs/enrollments/${ids.enrollment}`, body: () => ({ status: 'active' }), allow: 'ananya', deny: ['meera', 'vaibhav', 'karthik'] },
  { name: 'enrollment summary', method: 'GET', url: () => `/care-programs/enrollments/${ids.enrollment}/summary`, allow: 'lakshmi', deny: ['stranger', 'sunita'] },
  { name: 'admin program templates', method: 'GET', url: () => '/admin/care-programs/templates', allow: 'admin', deny: ['ops', 'ananya', 'vaibhav'] },
  // 44
  { name: 'lab order create', method: 'POST', url: () => '/lab/orders', body: () => ({ patientId: R(), testIds: [ids.test], address: { line1: 'x', city: 'Hyderabad', pincode: '500034' }, preferredStart: new Date(Date.now() + 86400_000).toISOString(), preferredEnd: new Date(Date.now() + 90000_000).toISOString() }), allow: 'vaibhav', deny: ['lakshmi', 'stranger'] },
  { name: 'lab order read', method: 'GET', url: () => `/lab/orders/${ids.labOrder}`, allow: 'lakshmi', deny: ['stranger', 'sunita'] },
  { name: 'lab order cancel', method: 'POST', url: () => `/lab/orders/${ids.labOrder}/cancel`, body: () => ({ reason: 'x' }), allow: 'vaibhav', deny: ['lakshmi', 'stranger'] },
  { name: 'ops lab orders', method: 'GET', url: () => '/ops/lab-orders', allow: 'meera', deny: ['vaibhav', 'sunita', 'support', 'desk'] },
  // 46-47 clinician
  { name: 'rx check', method: 'POST', url: () => '/clinician/prescriptions/check', body: () => ({ patientId: R(), items: [{ drugName: 'Paracetamol' }] }), allow: 'ananya', deny: ['vaibhav', 'sunita', 'desk', 'support', 'karthik'] },
  { name: 'scribe', method: 'POST', url: () => `/clinician/appointments/${ids.appt}/scribe`, body: () => ({ transcript: 'Patient: mild cough for two days.', consentConfirmed: true }), allow: 'ananya', deny: ['vaibhav', 'karthik', 'meera'] },
  // 48
  { name: 'provider route', method: 'GET', url: () => '/provider/route', allow: 'sunita', deny: ['vaibhav', 'ananya', 'ops'] },
  { name: 'provider attendance', method: 'POST', url: () => '/provider/attendance', body: () => ({ action: 'check_in' }), allow: 'sunita', deny: ['meera', 'vaibhav'] },
  { name: 'provider supplies', method: 'GET', url: () => '/provider/supplies', allow: 'sunita', deny: ['vaibhav', 'ops'] },
  { name: 'supplies restock', method: 'POST', url: () => `/ops/providers/${ids.sunitaProv}/supplies/restock`, body: () => ({ items: [{ code: 'gloves', qty: 1 }] }), allow: 'ops', deny: ['sunita', 'vaibhav', 'support'] },
  { name: 'low stock', method: 'GET', url: () => '/ops/supplies/low-stock', allow: 'meera', deny: ['sunita', 'vaibhav', 'support'] },
  // 49
  { name: 'second opinion create', method: 'POST', url: () => '/second-opinions', body: () => ({ patientId: R(), specialty: 'cardiologist', question: 'Is my ECG normal for my age?', recordIds: [ids.record] }), allow: 'vaibhav', deny: ['lakshmi', 'stranger'] },
  { name: 'clinician second opinions', method: 'GET', url: () => '/clinician/second-opinions', allow: 'ananya', deny: ['vaibhav', 'sunita', 'meera'] },
  // 50
  { name: 'abha create', method: 'POST', url: () => '/abdm/abha/create/start', body: () => ({ patientId: R(), method: 'mobile', mobile: '+919800000001' }), allow: 'vaibhav', deny: ['lakshmi', 'stranger', 'sunita'] },
  { name: 'abdm consent list', method: 'GET', url: () => `/abdm/consent-requests?patientId=${R()}`, allow: 'lakshmi', deny: ['stranger', 'sunita'] },
  // 51-52
  { name: 'insurance list', method: 'GET', url: () => `/patients/${R()}/insurance-policies`, allow: 'lakshmi', deny: ['stranger', 'sunita'] },
  { name: 'insurance create', method: 'POST', url: () => `/patients/${R()}/insurance-policies`, body: () => ({ insurerCode: 'pmjay', policyNumber: 'ABCD1234', type: 'government', validFrom: '2026-01-01', validTo: '2027-01-01' }), allow: 'vaibhav', deny: ['lakshmi', 'stranger'] },
  { name: 'preventive schedule', method: 'GET', url: () => `/patients/${R()}/preventive-schedule`, allow: 'lakshmi', deny: ['stranger', 'sunita'] },
  { name: 'preventive record', method: 'POST', url: () => `/patients/${R()}/preventive-records`, body: () => ({ code: 'bp_screen', doneAt: istDate() }), allow: 'vaibhav', deny: ['lakshmi', 'stranger'] },
  // 53-54
  { name: 'exercise plan create (nurse is not a physiotherapist)', method: 'POST', url: () => '/exercise-plans', body: () => ({ patientId: R(), items: [{ exerciseId: ids.exercise, sets: 1, reps: 5, perDay: 1 }], startDate: istDate(), weeks: 1 }), allow: 'ananya', deny: ['sunita', 'vaibhav', 'meera', 'karthik'] },
  { name: 'exercise session', method: 'POST', url: () => `/exercise-plans/${ids.exPlan}/sessions`, body: () => ({ completedExerciseIds: [], painScore: 2 }), allow: 'vaibhav', deny: ['lakshmi', 'stranger'] },
  { name: 'exercise progress', method: 'GET', url: () => `/exercise-plans/${ids.exPlan}/progress`, allow: 'ananya', deny: ['stranger', 'sunita'] },
  { name: 'diet plan create', method: 'POST', url: () => '/diet-plans', body: () => ({ patientId: R(), conditions: [], meals: [{ slot: 'dinner', items: ['Roti'] }], avoid: [], validUntil: addDays(istDate(), 5) }), allow: 'ananya', deny: ['meera', 'sunita', 'vaibhav'] },
  { name: 'diet log', method: 'POST', url: () => `/diet-plans/${ids.dietPlan}/logs`, body: () => ({ date: istDate(), slot: 'lunch', followed: true }), allow: 'vaibhav', deny: ['lakshmi', 'stranger'] },
  { name: 'diet logs read', method: 'GET', url: () => `/diet-plans/${ids.dietPlan}/logs`, allow: 'lakshmi', deny: ['stranger', 'sunita'] },
  // 55-56
  { name: 'ambulance read', method: 'GET', url: () => `/ambulance/requests/${ids.amb}`, allow: 'lakshmi', deny: ['sunita', 'stranger'] },
  { name: 'ops ambulance', method: 'GET', url: () => '/ops/ambulance-requests', allow: 'ops', deny: ['vaibhav', 'support', 'sunita'] },
  { name: 'safe zone write', method: 'PUT', url: () => `/patients/${R()}/safe-zone`, body: () => ({ enabled: false, centerLat: 17.4, centerLng: 78.4, radiusMeters: 500 }), allow: 'vaibhav', deny: ['lakshmi', 'stranger'] },
  { name: 'location post', method: 'POST', url: () => `/patients/${R()}/location`, body: () => ({ lat: 17.4, lng: 78.4, accuracyM: 5, source: 'phone' }), allow: 'vaibhav', deny: ['lakshmi', 'stranger'] },
  { name: 'location latest', method: 'GET', url: () => `/patients/${R()}/location/latest`, allow: 'lakshmi', deny: ['stranger', 'sunita', 'ananya'] },
  { name: 'sos devices', method: 'GET', url: () => `/patients/${R()}/sos-devices`, allow: 'vaibhav', deny: ['lakshmi', 'stranger'] },
  // 57-58
  { name: 'organizations', method: 'GET', url: () => '/admin/organizations', allow: 'admin', deny: ['ops', 'support', 'desk'] },
  { name: 'tenants', method: 'GET', url: () => '/admin/tenants', allow: 'admin', deny: ['ops', 'vaibhav'] },
  // 59
  { name: 'discharges list', method: 'GET', url: () => '/discharges', allow: 'desk', deny: ['vaibhav', 'support', 'ananya', 'sunita'] },
  { name: 'discharge read', method: 'GET', url: () => `/discharges/${ids.discharge}`, allow: 'desk', deny: ['vaibhav', 'support'] },
  // 60
  { name: 'admin coupons', method: 'GET', url: () => '/admin/coupons', allow: 'admin', deny: ['ops', 'support', 'vaibhav'] },
  { name: 'wallet', method: 'GET', url: () => '/wallet', allow: 'stranger', deny: [] },
  // 61
  { name: 'ops tickets', method: 'GET', url: () => '/ops/support/tickets', allow: 'support', deny: ['vaibhav', 'sunita', 'desk', 'ananya'] },
  { name: 'ops ticket reply', method: 'POST', url: () => `/ops/support/tickets/${ids.ticket}/reply`, body: () => ({ text: 'hi', internal: true }), allow: 'meera', deny: ['vaibhav', 'sunita'] },
  { name: 'support metrics', method: 'GET', url: () => '/ops/support/metrics', allow: 'ops', deny: ['vaibhav', 'desk'] },
  // 43, 62 dev simulators
  { name: 'whatsapp simulate', method: 'POST', url: () => '/dev/whatsapp/simulate', body: () => ({ text: 'HELP' }), allow: 'stranger', deny: [] },
];

describe('v1.3 authorization matrix', () => {
  for (const c of CASES) {
    it(`${c.method} ${c.name}`, async () => {
      const body = c.body?.();
      expect((await t.req(null, c.method, c.url(), body, idem())).status, `${c.name} unauthenticated`).toBe(401);
      for (const who of c.deny) {
        const r = await t.req(tok[who], c.method, c.url(), body, idem());
        expect([403, 404], `${c.name} as ${who}: ${r.status} ${JSON.stringify(r.body)}`).toContain(r.status);
      }
      const ok = await t.req(tok[c.allow], c.method, c.url(), body, idem());
      expect([401, 403], `${c.name} as ${c.allow}: ${ok.status} ${JSON.stringify(ok.body)}`).not.toContain(ok.status);
    });
  }

  it('a patient cannot call any /clinician/* endpoint', async () => {
    for (const [m, u] of [
      ['POST', '/clinician/prescriptions/check'],
      ['GET', '/clinician/second-opinions'],
      ['POST', `/clinician/appointments/${ids.appt}/scribe`],
      ['POST', '/clinician/second-opinions/00000000-0000-0000-0000-000000000000/claim'],
    ]) {
      expect((await t.req(tok.vaibhav, m, u, {})).status, u).toBe(403);
    }
  });

  it('customers never see internal notes, and other customers cannot see the ticket', async () => {
    const r = await t.req(tok.vaibhav, 'GET', `/support/tickets/${ids.ticket}`);
    expect(r.body.messages.every((m: any) => m.internal === false)).toBe(true);
    expect((await t.req(tok.lakshmi, 'GET', `/support/tickets/${ids.ticket}`)).status).toBe(404);
  });
});

describe('route ordering (static segments win over parameters)', () => {
  it('resolves every static route next to a parametric sibling', async () => {
    expect((await t.req(tok.vaibhav, 'GET', '/second-opinions/pricing')).body.items.length).toBeGreaterThan(0);
    expect((await t.req(tok.vaibhav, 'GET', '/second-opinions/00000000-0000-0000-0000-000000000000')).status).toBe(404);
    expect((await t.req(tok.vaibhav, 'GET', '/me/invite')).body.code).toBeTruthy();
    expect((await t.req(tok.vaibhav, 'GET', '/lab/packages')).body.items).toHaveLength(4);
    expect((await t.req(tok.vaibhav, 'GET', '/lab/orders')).body.items.length).toBeGreaterThan(0);
    expect((await t.req(tok.vaibhav, 'GET', '/care-programs/templates')).status).toBe(200);
    expect((await t.req(tok.vaibhav, 'GET', '/care-programs/enrollments')).status).toBe(200);
    expect((await t.req(tok.support, 'GET', '/ops/support/metrics')).body).toHaveProperty('byCategory');
    expect((await t.req(tok.support, 'GET', '/ops/support/tickets?status=open')).status).toBe(200);
    expect((await t.req(tok.vaibhav, 'GET', '/support/tickets')).status).toBe(200);
    expect((await t.req(tok.vaibhav, 'GET', `/patients/${R()}/location/latest`)).status).toBe(200);
    expect((await t.req(tok.vaibhav, 'GET', '/insurance/claim-checklist?type=reimbursement')).body.documents.length).toBeGreaterThan(0);
    expect((await t.req(tok.vaibhav, 'GET', '/insurance/insurers')).status).toBe(200);
    expect((await t.req(tok.vaibhav, 'GET', '/exercise-library')).status).toBe(200);
    expect((await t.req(tok.vaibhav, 'GET', '/diet-templates')).status).toBe(200);
    expect((await t.req(tok.admin, 'PATCH', '/admin/care-programs/templates/diabetes', { name: 'Diabetes v2' })).body.version).toBe('v2');
  });
});

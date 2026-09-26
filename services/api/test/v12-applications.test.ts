import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { SAMPLE_PNG, samplePdf } from '../src/db/seed.js';
import { doctorSchedules, serviceZones } from '../src/db/schema.js';
import { addDays, istDate, istToUtc } from '../src/lib/time.js';
import { multipart } from './fakes.js';
import { SEED_PHONES, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let ops: string;
let admin: string;
let meera: string;
let zoneId: string;
const future = () => new Date(Date.now() + 2 * 365 * 86400_000).toISOString();

beforeAll(async () => {
  t = await setup();
  ops = (await t.login(SEED_PHONES.ops)).accessToken;
  admin = (await t.login(SEED_PHONES.admin)).accessToken;
  meera = (await t.login(SEED_PHONES.meera)).accessToken;
  [{ id: zoneId }] = await t.svc.db.select({ id: serviceZones.id }).from(serviceZones).where(eq(serviceZones.name, 'Hyderabad-Central'));
});
afterAll(async () => t.close());

const uploadDoc = (token: string, docType: string, data: Buffer, name: string, type: string) => {
  const mp = multipart({ docType }, { field: 'file', name, data, type });
  return t.req(token, 'POST', '/provider-applications/me/documents', mp.body, mp.headers);
};

describe('provider applications (section 30)', () => {
  it('the seeded nurse applicant has a submitted application with 2 documents', async () => {
    const kavya = (await t.login(SEED_PHONES.kavya)).accessToken;
    const r = await t.req(kavya, 'GET', '/provider-applications/me');
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ type: 'nurse', status: 'submitted', phone: SEED_PHONES.kavya, decisionNote: null, decidedByName: null, decidedAt: null });
    expect(r.body.documents.map((d: any) => d.docType).sort()).toEqual(['id_proof', 'registration_certificate']);
    const list = await t.req(meera, 'GET', '/ops/provider-applications?status=submitted');
    expect(list.status).toBe(200);
    expect(list.body.items.some((a: any) => a.id === r.body.id)).toBe(true);
    const file = await t.req(ops, 'GET', `/ops/provider-applications/${r.body.id}/documents/${r.body.documents.find((d: any) => d.docType === 'registration_certificate').id}/file`);
    expect(file.status).toBe(200);
    expect(file.headers['content-type']).toBe('application/pdf');
  });

  it('doctor application: validation, documents, changes requested, approval required docs, approval -> searchable verified doctor', async () => {
    const phone = '+919800000701';
    const app = (await t.login(phone)).accessToken;
    expect((await t.req(app, 'GET', '/provider-applications/me')).status).toBe(404);
    const base = { type: 'doctor', fullName: 'Nisha Varma', qualification: 'MBBS, MD (Dermatology)', registrationNumber: 'TSMC-SAMPLE-70001', experienceYears: 6, languages: ['English', 'Telugu'], preferredZoneIds: [zoneId] };
    expect((await t.req(app, 'POST', '/provider-applications', base)).status).toBe(400); // specialty required for doctors
    expect((await t.req(app, 'POST', '/provider-applications', { ...base, specialty: 'astrology' })).status).toBe(400);
    const c = await t.req(app, 'POST', '/provider-applications', { ...base, specialty: 'dermatologist' });
    expect(c.status).toBe(201);
    expect(c.body).toMatchObject({ status: 'submitted', specialty: 'dermatologist', documents: [] });
    expect((await t.req(app, 'POST', '/provider-applications', { ...base, specialty: 'dermatologist' })).status).toBe(409);

    // Approval is refused without the required documents.
    const noDocs = await t.req(ops, 'POST', `/ops/provider-applications/${c.body.id}/decision`, { decision: 'approve', note: 'ok', credentialExpiresAt: future() });
    expect(noDocs.status).toBe(400);
    expect(noDocs.body.error.details.missing).toEqual(['registration_certificate', 'id_proof']);

    const d1 = await uploadDoc(app, 'registration_certificate', samplePdf('Registration'), 'reg.pdf', 'application/pdf');
    expect(d1.status).toBe(201);
    expect((await uploadDoc(app, 'id_proof', Buffer.from('plain text is not allowed here'), 'id.txt', 'text/plain')).status).toBe(400);
    expect((await uploadDoc(app, 'passport', SAMPLE_PNG, 'id.png', 'image/png')).status).toBe(400);
    const d2 = await uploadDoc(app, 'degree', SAMPLE_PNG, 'degree.png', 'image/png');
    expect(d2.body.documents).toHaveLength(2);
    const degree = d2.body.documents.find((d: any) => d.docType === 'degree');
    const del = await t.req(app, 'DELETE', `/provider-applications/me/documents/${degree.id}`);
    expect(del.status).toBe(200);
    expect(del.body.documents).toHaveLength(1);

    // request_changes -> applicant edits (resubmits)
    const rc = await t.req(ops, 'POST', `/ops/provider-applications/${c.body.id}/decision`, { decision: 'request_changes', note: 'Please add an ID proof' });
    expect(rc.body).toMatchObject({ status: 'changes_requested', decisionNote: 'Please add an ID proof', decidedByName: 'Operations Admin' });
    const notes = await t.req(app, 'GET', '/notifications');
    expect(notes.body.items.some((n: any) => n.title === 'Application update')).toBe(true);
    await uploadDoc(app, 'id_proof', SAMPLE_PNG, 'id.png', 'image/png');
    const pt = await t.req(app, 'PATCH', '/provider-applications/me', { qualification: 'MBBS, MD (Dermatology), DNB' });
    expect(pt.body).toMatchObject({ status: 'submitted', qualification: 'MBBS, MD (Dermatology), DNB' });

    // Coordinators can read but not decide; approval needs credentialExpiresAt.
    expect((await t.req(meera, 'POST', `/ops/provider-applications/${c.body.id}/decision`, { decision: 'approve', note: 'ok', credentialExpiresAt: future() })).status).toBe(403);
    expect((await t.req(ops, 'POST', `/ops/provider-applications/${c.body.id}/decision`, { decision: 'approve', note: 'ok' })).status).toBe(400);
    const ok = await t.req(ops, 'POST', `/ops/provider-applications/${c.body.id}/decision`, { decision: 'approve', note: 'Verified with council', credentialExpiresAt: future() });
    expect(ok.status).toBe(200);
    expect(ok.body.status).toBe('approved');
    expect((await t.req(app, 'PATCH', '/provider-applications/me', { experienceYears: 7 })).status).toBe(409);
    expect((await t.req(ops, 'POST', `/ops/provider-applications/${c.body.id}/decision`, { decision: 'reject', note: 'x' })).status).toBe(409);

    const me = await t.login(phone);
    expect(me.user.roles).toContain('doctor');
    expect(me.user.providerId).toBeTruthy();
    const [sch] = await t.svc.db.select().from(doctorSchedules).where(eq(doctorSchedules.doctorId, me.user.providerId));
    expect(sch.weekly).toEqual([]);
    const vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
    const search = await t.req(vaibhav, 'GET', '/doctors?q=Nisha');
    expect(search.body.items).toHaveLength(1);
    expect(search.body.items[0]).toMatchObject({ name: 'Dr. Nisha Varma', specialty: 'dermatologist', verified: true, fees: { video: 499, audio: 499, chat: 399, inClinic: 599 } });
    const prof = await t.req(me.accessToken, 'GET', '/doctor/me/profile');
    expect(prof.body).toMatchObject({ acceptingBookings: true, registrationNumber: 'TSMC-SAMPLE-70001' });
    const aud = await t.req(admin, 'GET', `/admin/audit-logs?entityType=provider_application&entityId=${c.body.id}`);
    expect(aud.body.items.map((a: any) => a.action)).toContain('provider_application.approve');
  });

  it('nurse approval creates a verified field provider that the home-visit matcher assigns', async () => {
    const kavyaLogin = await t.login(SEED_PHONES.kavya);
    const appId = (await t.req(kavyaLogin.accessToken, 'GET', '/provider-applications/me')).body.id;
    const ok = await t.req(admin, 'POST', `/ops/provider-applications/${appId}/decision`, {
      decision: 'approve',
      note: 'Documents verified',
      credentialExpiresAt: future(),
      capabilities: ['vitals_check', 'elderly_care'],
    });
    expect(ok.status).toBe(200);
    const kavya = (await t.login(SEED_PHONES.kavya)).accessToken;
    const me = await t.req(kavya, 'GET', '/provider/me');
    expect(me.body).toMatchObject({ verificationStatus: 'verified', type: 'nurse', capabilities: ['vitals_check', 'elderly_care'], zones: [{ id: zoneId, name: 'Hyderabad-Central' }] });
    expect((await t.req(kavya, 'POST', '/provider/duty', { onDuty: true })).body.onDuty).toBe(true);
    for (const phone of [SEED_PHONES.sunita, SEED_PHONES.ravi]) await t.req((await t.login(phone)).accessToken, 'POST', '/provider/duty', { onDuty: false });
    const vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
    const ramesh = await rameshId(t, vaibhav);
    const day = addDays(istDate(), 2);
    const hv = await t.req(
      vaibhav,
      'POST',
      '/home-visits',
      {
        patientId: ramesh,
        serviceCode: 'vitals_check',
        reason: 'BP check',
        address: { line1: 'Flat 1', city: 'Hyderabad', pincode: '500034' },
        preferredStart: istToUtc(day, '10:00').toISOString(),
        preferredEnd: istToUtc(day, '12:00').toISOString(),
      },
      idem(),
    );
    expect(hv.status).toBe(201);
    expect(hv.body.homeVisit.status).toBe('assigned');
    expect(hv.body.homeVisit.provider.id).toBe(me.body.id);
    const ops2 = await t.req(ops, 'GET', '/ops/providers');
    expect(ops2.body.items.find((p: any) => p.id === me.body.id)).toMatchObject({ verificationStatus: 'verified' });
  });

  it('a rejected applicant may apply again; unknown zones are rejected', async () => {
    const app = (await t.login('+919800000702')).accessToken;
    const body = { type: 'technician', fullName: 'Ravi K', qualification: 'DMLT', registrationNumber: 'X-1', experienceYears: 1, languages: [], preferredZoneIds: [] };
    expect((await t.req(app, 'POST', '/provider-applications', { ...body, preferredZoneIds: ['00000000-0000-0000-0000-000000000000'] })).status).toBe(400);
    const a = await t.req(app, 'POST', '/provider-applications', body);
    expect((await t.req(ops, 'POST', `/ops/provider-applications/${a.body.id}/decision`, { decision: 'reject', note: 'Registration not found' })).body.status).toBe('rejected');
    expect((await t.req(app, 'PATCH', '/provider-applications/me', { experienceYears: 2 })).status).toBe(409);
    const again = await t.req(app, 'POST', '/provider-applications', body);
    expect(again.status).toBe(201);
    expect((await t.req(app, 'GET', '/provider-applications/me')).body.id).toBe(again.body.id);
  });
});

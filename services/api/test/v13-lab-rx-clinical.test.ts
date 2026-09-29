import { and, eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { extractText, getDocumentProxy } from 'unpdf';
import { abdmConsentRequests, auditLogs, labOrders, labPackages, labTests, medicalRecords, patients, recordShares, scribeDrafts } from '../src/db/schema.js';
import { signBody } from '../src/lib/webhooks.js';
import { abdmMockLifecycle } from '../src/modules/abdm/routes.js';
import { labLifecycle } from '../src/modules/lab/service.js';
import { checkWithPack } from '../src/modules/rxcheck/engine.js';
import { INTERACTION_FIXTURE } from '../src/modules/rxcheck/fixtures.js';
import { secondOpinionOverdue } from '../src/modules/secondopinion/routes.js';
import { multipart as multipartBody } from './fakes.js';
import { P, SEED_PHONES, firstAvailableSlot, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let lakshmi: string;
let ananya: string;
let karthik: string;
let priya: string;
let sunita: string;
let meera: string;
let ramesh: string;
let doctorId: string;

const address = { line1: 'Flat 302, Sai Residency', city: 'Hyderabad', pincode: '500034', lat: 17.4126, lng: 78.4392 };
const window = () => {
  const s = new Date(Date.now() + 26 * 3600_000);
  return { preferredStart: s.toISOString(), preferredEnd: new Date(s.getTime() + 2 * 3600_000).toISOString() };
};

beforeAll(async () => {
  t = await setup();
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken;
  const a = await t.login(SEED_PHONES.ananya);
  ananya = a.accessToken;
  doctorId = a.user.providerId;
  karthik = (await t.login(SEED_PHONES.karthik)).accessToken;
  priya = (await t.login(SEED_PHONES.priya)).accessToken;
  sunita = (await t.login(SEED_PHONES.sunita)).accessToken;
  meera = (await t.login(SEED_PHONES.meera)).accessToken;
  ramesh = await rameshId(t, vaibhav);
});
afterAll(async () => t.close());

const pdfText = async (buf: Buffer) => (await extractText(await getDocumentProxy(new Uint8Array(buf)), { mergePages: true })).text;

describe('lab tests at home (section 44)', () => {
  it('catalogue: 20 tests, 4 packages, filters and placeholder pricing', async () => {
    const all = await t.req(vaibhav, 'GET', '/lab/tests?limit=100');
    expect(all.body.items).toHaveLength(20);
    expect(all.body.items[0]).toEqual(expect.objectContaining({ code: expect.any(String), sampleType: expect.any(String), fastingRequired: expect.any(Boolean), partnerName: expect.any(String) }));
    expect((await t.req(vaibhav, 'GET', '/lab/tests?category=diabetes')).body.items.every((x: any) => x.category === 'diabetes')).toBe(true);
    expect((await t.req(vaibhav, 'GET', '/lab/tests?q=thyroid')).body.items.length).toBeGreaterThanOrEqual(1);
    const pk = await t.req(vaibhav, 'GET', '/lab/packages');
    expect(pk.body.items).toHaveLength(4);
  });

  it('order with CARE10 -> payment -> sample_collection visit (with labOrder context for the provider) -> mock partner -> watermarked SAMPLE report', async () => {
    const [pkg] = await t.svc.db.select().from(labPackages).where(eq(labPackages.code, 'DIABETES_CARE'));
    const [tsh] = await t.svc.db.select().from(labTests).where(eq(labTests.code, 'TSH'));
    const r = await t.req(vaibhav, 'POST', '/lab/orders', { patientId: ramesh, packageIds: [pkg.id], testIds: [tsh.id], address, ...window(), couponCode: 'CARE10' }, idem());
    expect(r.status).toBe(201);
    expect(r.body.order).toMatchObject({ status: 'pending_payment', total: pkg.price + tsh.price, discount: 159 });
    expect(r.body.payment).toMatchObject({ purpose: 'lab_order', discount: 159, amount: pkg.price + tsh.price - 159 });
    expect(r.body.order.tests.length).toBe(6);
    const orderId = r.body.order.id;
    await t.req(vaibhav, 'POST', `/payments/${r.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    const scheduled = await t.req(vaibhav, 'GET', `/lab/orders/${orderId}`);
    expect(scheduled.body.status).toBe('scheduled');
    const visitId = scheduled.body.collectionVisitId;
    expect(visitId).toBeTruthy();
    // the assigned provider sees minimum-necessary lab context (no prices)
    const v = await t.req(vaibhav, 'GET', `/home-visits/${visitId}`);
    expect(v.body.serviceCode).toBe('sample_collection');
    expect(v.body.labOrder).toMatchObject({ id: orderId, fastingRequired: true, fastingHours: 10 });
    expect(v.body.labOrder.tests[0]).toEqual({ id: expect.any(String), name: expect.any(String), sampleType: expect.any(String) });
    expect(JSON.stringify(v.body.labOrder)).not.toMatch(/price/);
    // other visits carry labOrder: null
    const other = await t.req(vaibhav, 'GET', '/home-visits?scope=past');
    expect(other.body.items.find((x: any) => x.serviceCode === 'vitals_check').labOrder).toBeNull();
    // run the visit as the assigned provider
    const pv = v.body.provider;
    expect(pv).toBeTruthy();
    const provTok = pv.name === 'Sunita Devi' ? sunita : (await t.login(SEED_PHONES.ravi)).accessToken;
    const provView = await t.req(provTok, 'GET', `/home-visits/${visitId}`);
    expect(provView.body.labOrder.id).toBe(orderId);
    for (const [step, body] of [['accept', undefined], ['en-route', { etaMinutes: 10 }], ['arrived', undefined]] as const) {
      expect((await t.req(provTok, 'POST', `/home-visits/${visitId}/${step}`, body)).status).toBe(200);
    }
    await t.req(provTok, 'POST', `/home-visits/${visitId}/verify-identity`, { visitCode: v.body.visitCode, consentConfirmed: true });
    const done = await t.req(provTok, 'POST', `/home-visits/${visitId}/complete`, { summary: 'Samples collected: 2 tubes + urine.' });
    expect(done.status).toBe(200);
    const processing = await t.req(vaibhav, 'GET', `/lab/orders/${orderId}`);
    expect(processing.body.status).toBe('processing');
    expect(processing.body.partnerOrderId).toMatch(/^LABMOCK-/);
    // not yet: LAB_MOCK_REPORT_MINUTES (2) have not passed
    expect(await labLifecycle(t.svc, new Date())).toBe(0);
    expect(await labLifecycle(t.svc, new Date(Date.now() + 3 * 60_000))).toBe(1);
    const ready = await t.req(lakshmi, 'GET', `/lab/orders/${orderId}`);
    expect(ready.body.status).toBe('report_ready');
    expect(ready.body.timeline.map((x: any) => x.status)).toEqual(['pending_payment', 'scheduled', 'sample_collected', 'processing', 'report_ready']);
    const [rec] = await t.svc.db.select().from(medicalRecords).where(eq(medicalRecords.id, ready.body.reportRecordId));
    expect(rec).toMatchObject({ type: 'lab_report', source: 'lab_partner' });
    const text = await pdfText(await t.svc.storage.get(rec.storageKey!));
    expect(text).toContain('SAMPLE REPORT - NOT A REAL RESULT');
    expect(text).toContain('HbA1c');
    expect((await t.req(vaibhav, 'GET', `/records/${rec.id}`)).body.source).toBe('lab_partner');
    const ops = await t.req(meera, 'GET', '/ops/lab-orders?status=report_ready');
    expect(ops.body.items.some((o: any) => o.id === orderId)).toBe(true);
  });

  it('cancel refunds a paid order; not serviceable pincodes are refused; the lab webhook moves partner orders', async () => {
    const [cbc] = await t.svc.db.select().from(labTests).where(eq(labTests.code, 'CBC'));
    expect((await t.req(vaibhav, 'POST', '/lab/orders', { patientId: ramesh, testIds: [cbc.id], address: { ...address, pincode: '560001' }, ...window() }, idem())).status).toBe(422);
    const r = await t.req(vaibhav, 'POST', '/lab/orders', { patientId: ramesh, testIds: [cbc.id], address, ...window() }, idem());
    await t.req(vaibhav, 'POST', `/payments/${r.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    expect((await t.req(lakshmi, 'POST', `/lab/orders/${r.body.order.id}/cancel`, { reason: 'x' })).status).toBe(403);
    const c = await t.req(vaibhav, 'POST', `/lab/orders/${r.body.order.id}/cancel`, { reason: 'Changed my mind' });
    expect(c.body.status).toBe('cancelled');
    expect((await t.req(vaibhav, 'GET', `/payments/${r.body.payment.id}`)).body.status).toBe('refunded');
    // signed partner webhook for an order in sample_collected
    const [o] = await t.svc.db.insert(labOrders).values({ patientId: ramesh, tests: [{ id: cbc.id, name: cbc.name }], total: 299, status: 'sample_collected', address, preferredStart: new Date(), preferredEnd: new Date(), partnerName: 'X', partnerOrderId: 'PARTNER-42', careEpisodeId: r.body.order.careEpisodeId, timeline: [] }).returning();
    const body = JSON.stringify({ eventId: 'lab-evt-1', partnerOrderId: 'PARTNER-42', status: 'report_ready', results: [{ name: 'Haemoglobin', value: '13.1', unit: 'g/dL', range: '12-16' }] });
    const res = await t.app.inject({ method: 'POST', url: `${P}/webhooks/lab/acme`, payload: body, headers: { 'content-type': 'application/json', 'x-lab-signature': signBody(t.svc.config.LAB_WEBHOOK_SECRET, body) } });
    expect(res.statusCode).toBe(200);
    const [after] = await t.svc.db.select().from(labOrders).where(eq(labOrders.id, o.id));
    expect(after.status).toBe('report_ready');
    const dup = await t.app.inject({ method: 'POST', url: `${P}/webhooks/lab/acme`, payload: body, headers: { 'content-type': 'application/json', 'x-lab-signature': signBody(t.svc.config.LAB_WEBHOOK_SECRET, body) } });
    expect(JSON.parse(dup.body).duplicate).toBe(true);
  });
});

describe('drug interaction & allergy checks (section 47)', () => {
  it('engine: allergy class match, cross-reactivity, duplicate therapy, interaction pair', () => {
    const w = checkWithPack(INTERACTION_FIXTURE, { items: [{ drugName: 'Amoxicillin 500mg' }], allergies: ['Penicillin'], activeMedications: [] }, 'p');
    expect(w[0]).toMatchObject({ severity: 'major', type: 'allergy' });
    const cross = checkWithPack(INTERACTION_FIXTURE, { items: [{ drugName: 'Cefixime' }], allergies: ['Penicillin'], activeMedications: [] }, 'p');
    expect(cross[0]).toMatchObject({ severity: 'moderate', type: 'allergy' });
    const dup = checkWithPack(INTERACTION_FIXTURE, { items: [{ drugName: 'Atorvastatin 10mg' }], allergies: [], activeMedications: ['Rosuvastatin 5mg'] }, 'p');
    expect(dup.some((x) => x.type === 'duplicate_therapy' && x.severity === 'moderate')).toBe(true);
    const same = checkWithPack(INTERACTION_FIXTURE, { items: [{ drugName: 'Metformin 1000mg' }], allergies: [], activeMedications: ['Metformin 500mg'] }, 'p');
    expect(same.some((x) => x.type === 'duplicate_therapy')).toBe(true);
    for (const [a, b] of [
      ['Warfarin', 'Aspirin'],
      ['Clarithromycin', 'Simvastatin'],
      ['Sildenafil', 'Isosorbide mononitrate'],
      ['Ramipril', 'Spironolactone'],
      ['Metformin', 'Iohexol'],
    ]) {
      const x = checkWithPack(INTERACTION_FIXTURE, { items: [{ drugName: a }, { drugName: b }], allergies: [], activeMedications: [] }, 'p');
      expect(x.some((y) => y.type === 'interaction' && y.severity === 'major'), `${a}+${b}`).toBe(true);
    }
    expect(checkWithPack(INTERACTION_FIXTURE, { items: [{ drugName: 'Paracetamol' }, { drugName: 'Cetirizine' }], allergies: ['Penicillin'], activeMedications: ['Metformin 500mg', 'Amlodipine 5mg'] }, 'p')).toEqual([]);
  });

  it('POST /clinician/prescriptions/check (doctor with a relationship only)', async () => {
    const r = await t.req(ananya, 'POST', '/clinician/prescriptions/check', { patientId: ramesh, items: [{ drugName: 'Amoxicillin', strength: '500mg' }, { drugName: 'Simvastatin' }] });
    expect(r.status).toBe(200);
    expect(r.body.knowledgePack).toEqual({ version: 'interactions-fixture-0.1', status: 'fixture_unapproved' });
    expect(r.body.warnings.some((w: any) => w.type === 'allergy' && w.severity === 'major')).toBe(true);
    // Amlodipine is active for Ramesh: simvastatin dose-limit interaction
    expect(r.body.warnings.some((w: any) => w.type === 'interaction' && w.drugs.includes('Simvastatin'))).toBe(true);
    expect((await t.req(vaibhav, 'POST', '/clinician/prescriptions/check', { patientId: ramesh, items: [{ drugName: 'X' }] })).status).toBe(403);
    expect((await t.req(priya, 'POST', '/clinician/prescriptions/check', { patientId: ramesh, items: [{ drugName: 'X' }] })).status).toBe(403);
  });

  it('prescribing: a major warning is rejected unless acknowledged with a reason (audited override); clean items pass', async () => {
    const slot = await firstAvailableSlot(t, vaibhav, doctorId);
    const b = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId, slotId: slot.id, mode: 'video', reason: 'Sore throat' }, idem());
    await t.req(vaibhav, 'POST', `/payments/${b.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    const apptId = b.body.appointment.id;
    await t.req(ananya, 'POST', `/clinician/appointments/${apptId}/start`);
    const item = { drugName: 'Amoxicillin', strength: '500mg', form: 'capsule', dose: '1 capsule', frequency: 'Three times daily', durationDays: 5, times: ['08:00', '14:00', '20:00'] };
    const rej = await t.req(ananya, 'POST', '/clinician/prescriptions', { appointmentId: apptId, items: [item] });
    expect(rej.status).toBe(400);
    expect(rej.body.error.details.warnings[0]).toMatchObject({ severity: 'major', type: 'allergy' });
    expect((await t.req(ananya, 'POST', '/clinician/prescriptions', { appointmentId: apptId, items: [item], acknowledgedWarnings: true })).status).toBe(400);
    const ok = await t.req(ananya, 'POST', '/clinician/prescriptions', { appointmentId: apptId, items: [item], acknowledgedWarnings: true, overrideReason: 'Allergy history was a mild rash in childhood; discussed with patient' });
    expect(ok.status).toBe(201);
    expect(ok.body.warnings[0].severity).toBe('major');
    const logs = await t.svc.db.select().from(auditLogs).where(and(eq(auditLogs.action, 'prescription.override'), eq(auditLogs.entityId, ok.body.id)));
    expect(logs).toHaveLength(1);
    const clean = await t.req(ananya, 'POST', '/clinician/prescriptions', { appointmentId: apptId, items: [{ drugName: 'Paracetamol', strength: '500mg', form: 'tablet', dose: '1 tablet', frequency: 'If needed', durationDays: 3, times: [] }] });
    expect(clean.status).toBe(201);
    expect(clean.body.warnings).toEqual([]);
  });
});

describe('AI scribe (section 46)', () => {
  it('only the appointment doctor; consent required; transcript or audio (discarded); advisory draft grounded in the transcript', async () => {
    const slot = await firstAvailableSlot(t, vaibhav, doctorId, 1);
    const b = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId, slotId: slot.id, mode: 'video', reason: 'BP review' }, idem());
    const id = b.body.appointment.id;
    const transcript = 'Doctor: How are you? Patient: My BP was 150 over 95 this morning and I have a mild headache. Doctor: Continue amlodipine and record BP daily.';
    expect((await t.req(karthik, 'POST', `/clinician/appointments/${id}/scribe`, { transcript, consentConfirmed: true })).status).toBe(403);
    expect((await t.req(vaibhav, 'POST', `/clinician/appointments/${id}/scribe`, { transcript, consentConfirmed: true })).status).toBe(403);
    expect((await t.req(ananya, 'POST', `/clinician/appointments/${id}/scribe`, { transcript, consentConfirmed: false })).status).toBe(400);
    const r = await t.req(ananya, 'POST', `/clinician/appointments/${id}/scribe`, { transcript, consentConfirmed: true });
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ appointmentId: id, transcript, advisory: true, audioRetained: false });
    expect(Object.keys(r.body.draft).sort()).toEqual(['assessment', 'objective', 'plan', 'subjective']);
    expect(r.body.draft.subjective).toContain('150 over 95');
    // audio -> mock speech-to-text; the audio is never stored
    const wav = Buffer.concat([Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WAVEfmt '), Buffer.alloc(64)]);
    const mp = multipartBody({ consentConfirmed: 'true' }, { field: 'audio', name: 'consult.wav', data: wav, type: 'audio/wav' });
    const a = await t.app.inject({ method: 'POST', url: `${P}/clinician/appointments/${id}/scribe`, payload: mp.body, headers: { ...mp.headers, authorization: `Bearer ${ananya}` } });
    expect(a.statusCode).toBe(200);
    expect(JSON.parse(a.body).transcript).toMatch(/blood pressure/);
    expect(await t.svc.db.select().from(scribeDrafts).where(eq(scribeDrafts.appointmentId, id))).toHaveLength(2);
    const noConsent = multipartBody({}, { field: 'audio', name: 'consult.wav', data: wav, type: 'audio/wav' });
    expect((await t.app.inject({ method: 'POST', url: `${P}/clinician/appointments/${id}/scribe`, payload: noConsent.body, headers: { ...noConsent.headers, authorization: `Bearer ${ananya}` } })).statusCode).toBe(400);
  });
});

describe('specialist second opinion (section 49)', () => {
  it('pricing, request + payment, claim (records shared, audited), respond (PDF record), overdue alert', async () => {
    const pricing = await t.req(vaibhav, 'GET', '/second-opinions/pricing');
    expect(pricing.status).toBe(200);
    expect(pricing.body.items.find((x: any) => x.specialty === 'dermatologist')).toMatchObject({ price: 799, turnaroundHours: 48 });
    const recs = await t.svc.db.select().from(medicalRecords).where(eq(medicalRecords.patientId, ramesh));
    const r = await t.req(vaibhav, 'POST', '/second-opinions', { patientId: ramesh, specialty: 'dermatologist', question: 'Is this skin rash related to my medicines?', recordIds: [recs[0].id] }, idem());
    expect(r.status).toBe(201);
    expect(r.body.request).toMatchObject({ status: 'pending_payment', price: 799, records: [{ id: recs[0].id, title: recs[0].title }] });
    expect(r.body.payment.purpose).toBe('second_opinion');
    const soId = r.body.request.id;
    expect((await t.req(priya, 'GET', '/clinician/second-opinions?scope=open')).body.items.some((x: any) => x.id === soId)).toBe(false);
    await t.req(vaibhav, 'POST', `/payments/${r.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    const open = await t.req(priya, 'GET', '/clinician/second-opinions?scope=open');
    expect(open.body.items.find((x: any) => x.id === soId).status).toBe('open');
    // other specialties do not see it and cannot claim it
    expect((await t.req(ananya, 'GET', '/clinician/second-opinions?scope=open')).body.items.some((x: any) => x.id === soId)).toBe(false);
    expect((await t.req(ananya, 'POST', `/clinician/second-opinions/${soId}/claim`)).status).toBe(403);
    // Priya has no relationship yet: the record is not readable
    expect((await t.req(priya, 'GET', `/records/${recs[0].id}`)).status).toBe(403);
    const claim = await t.req(priya, 'POST', `/clinician/second-opinions/${soId}/claim`);
    expect(claim.body).toMatchObject({ status: 'claimed', doctorName: 'Dr. Priya Sharma' });
    expect((await t.req(priya, 'POST', `/clinician/second-opinions/${soId}/claim`)).status).toBe(409);
    expect((await t.svc.db.select().from(recordShares).where(eq(recordShares.recordId, recs[0].id))).length).toBeGreaterThan(0);
    expect((await t.req(priya, 'GET', `/records/${recs[0].id}`)).status).toBe(200);
    const resp = await t.req(priya, 'POST', `/clinician/second-opinions/${soId}/respond`, { opinion: 'The rash is most consistent with irritant dermatitis; review in person if it spreads.', recommendations: ['Use a mild moisturiser', 'Avoid harsh soaps'], suggestTeleconsult: true });
    expect(resp.status).toBe(200);
    expect(resp.body).toMatchObject({ status: 'answered', recommendations: ['Use a mild moisturiser', 'Avoid harsh soaps'] });
    expect(resp.body.opinionRecordId).toBeTruthy();
    expect((await t.req(lakshmi, 'GET', `/second-opinions/${soId}`)).body.opinion).toMatch(/dermatitis/);
    expect((await t.req(priya, 'GET', '/clinician/second-opinions?scope=mine')).body.items[0].id).toBe(soId);
    // overdue: another open request past its due time alerts ops once
    const r2 = await t.req(vaibhav, 'POST', '/second-opinions', { patientId: ramesh, specialty: 'dermatologist', question: 'Second question about the rash please', recordIds: [recs[0].id] }, idem());
    await t.req(vaibhav, 'POST', `/payments/${r2.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    expect(await secondOpinionOverdue(t.svc, new Date(Date.now() + 49 * 3600_000))).toBe(1);
    expect(await secondOpinionOverdue(t.svc, new Date(Date.now() + 50 * 3600_000))).toBe(0);
  });
});

describe('ABDM (section 50) with the mock gateway', () => {
  it('ABHA creation (OTP 123456), link existing, consent request -> granted after 10 s -> 2 imported sample records', async () => {
    const start = await t.req(vaibhav, 'POST', '/abdm/abha/create/start', { patientId: ramesh, method: 'mobile', mobile: '+919800000001' });
    expect(start.status).toBe(200);
    expect((await t.req(vaibhav, 'POST', '/abdm/abha/create/verify', { txnId: start.body.txnId, otp: '000000' })).status).toBe(400);
    const v = await t.req(vaibhav, 'POST', '/abdm/abha/create/verify', { txnId: start.body.txnId, otp: '123456' });
    expect(v.status).toBe(200);
    expect(v.body).toMatchObject({ status: 'verified' });
    expect(v.body.number).toMatch(/^\d{2}-\d{4}-\d{4}-\d{4}$/);
    expect(v.body.address).toMatch(/@sbx$/);
    expect((await t.req(vaibhav, 'POST', '/abdm/abha/create/verify', { txnId: start.body.txnId, otp: '123456' })).status).toBe(409);
    expect((await t.req(lakshmi, 'POST', '/abdm/abha/create/start', { patientId: ramesh, method: 'mobile', mobile: '+919800000001' })).status).toBe(403);
    const link = await t.req(vaibhav, 'POST', '/abdm/abha/link-existing/start', { patientId: ramesh, abhaNumber: '91-1111-2222-3333' });
    const lv = await t.req(vaibhav, 'POST', '/abdm/abha/link-existing/verify', { txnId: link.body.txnId, otp: '123456' });
    expect(lv.body).toMatchObject({ number: '91-1111-2222-3333', status: 'verified' });
    const cr = await t.req(vaibhav, 'POST', '/abdm/consent-requests', { patientId: ramesh, hiTypes: ['Prescription', 'DiagnosticReport'], from: '2024-01-01', to: '2026-01-01', purpose: 'CAREMGT' });
    expect(cr.status).toBe(201);
    expect(cr.body).toMatchObject({ status: 'requested', recordsImported: 0 });
    expect(await abdmMockLifecycle(t.svc, new Date(Date.now() + 5_000))).toBe(0);
    expect(await abdmMockLifecycle(t.svc, new Date(Date.now() + 11_000))).toBe(2);
    const list = await t.req(lakshmi, 'GET', `/abdm/consent-requests?patientId=${ramesh}`);
    expect(list.body.items[0]).toMatchObject({ id: cr.body.id, status: 'data_received', recordsImported: 2 });
    const imported = (await t.req(vaibhav, 'GET', `/records?patientId=${ramesh}&limit=100`)).body.items.filter((x: any) => x.importedVia === 'abdm');
    expect(imported).toHaveLength(2);
    expect(imported[0].title).toMatch(/Imported via ABDM \(sample\)/);
    expect(imported[0].source).toBe('imported');
    // signed gateway callback for a denied request
    const cr2 = await t.req(vaibhav, 'POST', '/abdm/consent-requests', { patientId: ramesh, hiTypes: ['DischargeSummary'], from: '2024-01-01', to: '2026-01-01', purpose: 'CAREMGT' });
    const body = JSON.stringify({ eventId: 'abdm-1', type: 'consent.status', consentRequestId: cr2.body.id, status: 'denied' });
    const res = await t.app.inject({ method: 'POST', url: `${P}/webhooks/abdm`, payload: body, headers: { 'content-type': 'application/json', 'x-abdm-signature': signBody(t.svc.config.ABDM_WEBHOOK_SECRET, body) } });
    expect(res.statusCode).toBe(200);
    expect((await t.svc.db.select().from(abdmConsentRequests).where(eq(abdmConsentRequests.id, cr2.body.id)))[0].status).toBe('denied');
  });

  it('section 39 verify works in mock mode when enabled (sandbox addresses only)', async () => {
    const enabled = await setup({ config: { ABDM_ENABLED: true } });
    try {
      const v = (await enabled.login(SEED_PHONES.vaibhav)).accessToken;
      const rid = await rameshId(enabled, v);
      await enabled.req(v, 'PATCH', `/patients/${rid}`, { abhaAddress: 'ramesh@sbx' });
      const r = await enabled.req(v, 'POST', `/patients/${rid}/abha/verify`);
      expect(r.status).toBe(200);
      expect(r.body.status).toBe('verified');
      expect((await enabled.svc.db.select().from(patients).where(eq(patients.id, rid)))[0].abhaStatus).toBe('verified');
    } finally {
      await enabled.close();
    }
  });
});

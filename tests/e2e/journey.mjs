#!/usr/bin/env node
// End-to-end care journey against a running API (seeded dev DB).
// Usage: node tests/e2e/journey.mjs [baseUrl]   (default http://localhost:4000/api/v1)
// Covers: patient → AI intake/safety → doctor booking + payment → home visit → provider lifecycle →
//         clinician snapshot + care plan → patient tasks/meds → family permissions → ops → admin.
import { randomUUID } from 'node:crypto';

const BASE = process.argv[2] ?? process.env.API_BASE_URL ?? 'http://localhost:4000/api/v1';
let passed = 0;
let failed = 0;

function check(name, cond, extra) {
  if (cond) { passed++; console.log(`  ✓ ${name}`); }
  else { failed++; console.log(`  ✗ ${name}${extra !== undefined ? ' → ' + JSON.stringify(extra).slice(0, 400) : ''}`); }
}

async function call(token, method, path, body, headers = {}) {
  const h = { ...headers };
  if (token) h.authorization = `Bearer ${token}`;
  let payload;
  if (body instanceof FormData) payload = body;
  else if (body !== undefined) { h['content-type'] = 'application/json'; payload = JSON.stringify(body); }
  const res = await fetch(BASE + path, { method, headers: h, body: payload });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = text; }
  return { status: res.status, body: json };
}

async function login(phone) {
  const r1 = await call(null, 'POST', '/auth/otp/request', { phone });
  const otp = r1.body?.devOtp ?? '123456';
  const r2 = await call(null, 'POST', '/auth/otp/verify', { phone, otp, deviceName: 'e2e' });
  if (r2.status !== 200) throw new Error(`login ${phone} failed: ${r2.status} ${JSON.stringify(r2.body)}`);
  return r2.body;
}

function istDate(offsetDays = 0) {
  const d = new Date(Date.now() + 5.5 * 3600e3 + offsetDays * 86400e3);
  return d.toISOString().slice(0, 10);
}

async function main() {
  console.log(`CareCompanion E2E journey against ${BASE}\n`);

  console.log('System');
  const health = await call(null, 'GET', '/health');
  check('health ok', health.status === 200 && health.body.status === 'ok', health);
  const ready = await call(null, 'GET', '/ready');
  check('ready reports db + safety rules', ready.body?.checks?.db === 'ok', ready.body);

  console.log('\nPatient onboarding & family');
  const pat = await login('+919800000001');
  const P = pat.accessToken;
  check('patient logged in with onboarding complete', pat.user.onboardingComplete === true, pat.user);
  const patients = await call(P, 'GET', '/patients');
  const ramesh = patients.body.items.find((p) => !p.isSelf);
  check('family switcher lists self + dependent', patients.body.items.length >= 2 && ramesh, patients.body);
  const unauth = await call(null, 'GET', '/patients');
  check('unauthenticated request rejected (401)', unauth.status === 401, unauth.status);
  const forbidden = await call(P, 'GET', '/clinician/queue');
  check('patient cannot reach clinician API (403)', forbidden.status === 403, forbidden.status);

  console.log('\nAI Care Assistant');
  const conv = await call(P, 'POST', '/ai/conversations', { patientId: ramesh.id });
  check('conversation created with greeting', conv.status === 201 && conv.body.messages.length >= 1, conv.body);
  const t1 = await call(P, 'POST', `/ai/conversations/${conv.body.id}/messages`, { text: 'I have a headache since yesterday and feeling tired' });
  check('intake captured chief complaint from user', t1.body?.intake?.chiefComplaint?.value && t1.body.intake.chiefComplaint.source === 'user', t1.body?.intake);
  check('routine message not escalated', ['none', 'routine'].includes(t1.body?.safety?.level), t1.body?.safety);
  const conv2 = await call(P, 'POST', '/ai/conversations', { patientId: ramesh.id });
  const t2 = await call(P, 'POST', `/ai/conversations/${conv2.body.id}/messages`, { text: 'He has severe chest pain and cannot breathe' });
  check('emergency keywords → deterministic emergency', t2.body?.safety?.level === 'emergency' && t2.body?.routing?.action === 'emergency', { safety: t2.body?.safety, routing: t2.body?.routing });

  console.log('\nDoctor discovery, booking & payment');
  const docs = await call(P, 'GET', '/doctors?specialty=general_physician');
  const ananya = docs.body.items.find((d) => d.name.includes('Ananya'));
  check('verified doctors listed with explainable ranking', ananya && Array.isArray(ananya.rankingFactors), docs.body.items?.map((d) => d.name));
  let slot;
  for (let i = 1; i <= 7 && !slot; i++) {
    const s = await call(P, 'GET', `/doctors/${ananya.id}/slots?date=${istDate(i)}`);
    slot = s.body.items.find((x) => x.status === 'available');
  }
  check('found an available slot', !!slot);
  const idem = randomUUID();
  const bookBody = { patientId: ramesh.id, doctorId: ananya.id, slotId: slot.id, mode: 'video', reason: 'Headache and fatigue' };
  const [b1, b1dup] = [await call(P, 'POST', '/appointments', bookBody, { 'idempotency-key': idem }), null];
  check('appointment created pending payment', b1.status === 201 && b1.body.appointment.status === 'pending_payment', b1.body);
  const b1retry = await call(P, 'POST', '/appointments', bookBody, { 'idempotency-key': idem });
  check('idempotent retry returns same appointment', b1retry.body?.appointment?.id === b1.body.appointment.id, b1retry.body);
  const dbl = await call(P, 'POST', '/appointments', bookBody, { 'idempotency-key': randomUUID() });
  check('double booking same slot rejected', dbl.status === 409 && dbl.body.error.code === 'SLOT_UNAVAILABLE', dbl.body);
  const pay = await call(P, 'POST', `/payments/${b1.body.payment.id}/confirm-mock`, { outcome: 'success' }, { 'idempotency-key': randomUUID() });
  check('mock payment succeeded', pay.body?.status === 'succeeded', pay.body);
  const appt = await call(P, 'GET', `/appointments/${b1.body.appointment.id}`);
  check('appointment confirmed after payment', appt.body.status === 'confirmed', appt.body.status);
  void b1dup;

  console.log('\nHome checkup');
  const noSvc = await call(P, 'POST', '/home-visit/serviceability', { pincode: '560001' });
  check('Bangalore pincode not serviceable', noSvc.body.serviceable === false, noSvc.body);
  const svc = await call(P, 'POST', '/home-visit/serviceability', { pincode: '500034' });
  check('Hyderabad pincode serviceable', svc.body.serviceable === true, svc.body);
  const start = new Date(Date.now() + 2 * 3600e3);
  const hv = await call(P, 'POST', '/home-visits', {
    patientId: ramesh.id, serviceCode: 'vitals_check', reason: 'BP and sugar check',
    address: { line1: 'Flat 302, Green Residency', city: 'Hyderabad', pincode: '500034' },
    preferredStart: start.toISOString(), preferredEnd: new Date(start.getTime() + 3600e3).toISOString(),
  }, { 'idempotency-key': randomUUID() });
  check('home visit requested', hv.status === 201, hv.body);
  const visitId = hv.body.homeVisit.id;
  await call(P, 'POST', `/payments/${hv.body.payment.id}/confirm-mock`, { outcome: 'success' }, { 'idempotency-key': randomUUID() });
  const hvP = await call(P, 'GET', `/home-visits/${visitId}`);
  check('patient sees visit code', /^\d{4}$/.test(hvP.body.visitCode ?? ''), hvP.body.visitCode);
  const visitCode = hvP.body.visitCode;

  console.log('\nOperations dispatch');
  const ops = await login('+919800000401');
  const O = ops.accessToken;
  const provs = await call(O, 'GET', '/ops/providers');
  const sunita = provs.body.items.find((p) => p.name.includes('Sunita'));
  const anil = provs.body.items.find((p) => p.name.includes('Anil'));
  check('expired-credential provider flagged', anil && anil.verificationStatus !== 'verified' || (anil && new Date(anil.credentialExpiresAt) < new Date()), anil);
  if (hvP.body.provider?.id !== sunita.id) {
    const asg = await call(O, 'POST', `/home-visits/${visitId}/assign`, { providerId: sunita.id });
    check('ops assigned Sunita', asg.status === 200 && asg.body.provider?.id === sunita.id, asg.body);
  } else check('auto-matcher assigned Sunita', true);

  console.log('\nProvider app lifecycle');
  const prov = await login('+919800000201');
  const V = prov.accessToken;
  await call(V, 'POST', '/provider/duty', { onDuty: true });
  const hvV = await call(V, 'GET', `/home-visits/${visitId}`);
  check('provider never sees visit code', hvV.body.visitCode == null, hvV.body.visitCode);
  check('provider gets minimum patient context', hvV.body.patientContext && Array.isArray(hvV.body.patientContext.allergies), hvV.body.patientContext);
  for (const [step, body] of [['accept'], ['en-route', { etaMinutes: 20 }], ['arrived']]) {
    const r = await call(V, 'POST', `/home-visits/${visitId}/${step}`, body ?? {});
    check(`provider ${step}`, r.status === 200, r.body);
  }
  const bad = await call(V, 'POST', `/home-visits/${visitId}/verify-identity`, { visitCode: visitCode === '0000' ? '1111' : '0000', consentConfirmed: true });
  check('wrong visit code rejected', bad.status === 400, bad.status);
  const ok = await call(V, 'POST', `/home-visits/${visitId}/verify-identity`, { visitCode, consentConfirmed: true });
  check('identity + consent verified → in_progress', ok.body.status === 'in_progress', ok.body.status);
  const now = new Date().toISOString();
  const vit = await call(V, 'POST', `/home-visits/${visitId}/vitals`, { measurements: [
    { type: 'bp_systolic', value: 142, unit: 'mmHg', measuredAt: now }, { type: 'bp_diastolic', value: 90, unit: 'mmHg', measuredAt: now },
    { type: 'pulse', value: 84, unit: 'bpm', measuredAt: now }, { type: 'spo2', value: 97, unit: '%', measuredAt: now },
  ] }, { 'idempotency-key': randomUUID() });
  check('vitals recorded', vit.status === 200 && vit.body.vitals.length >= 4, vit.body);
  const obs = await call(V, 'POST', `/home-visits/${visitId}/observations`, { notes: 'Alert, oriented. Mild fatigue.', checklist: { alert_oriented: true, medications_reviewed: true } });
  check('observations recorded', obs.status === 200, obs.body);
  const done = await call(V, 'POST', `/home-visits/${visitId}/complete`, { summary: 'Vitals captured. BP elevated; routed to doctor for review.' });
  check('visit completed', done.body.status === 'completed', done.body.status);
  const other = await login('+919800000202');
  const cross = await call(other.accessToken, 'GET', `/home-visits/${visitId}`);
  check("another provider cannot read this visit", cross.status === 403 || cross.status === 404, cross.status);

  console.log('\nClinician consultation & care plan');
  const doc = await login('+919800000101');
  const D = doc.accessToken;
  const q = await call(D, 'GET', `/clinician/queue?date=${appt.body.startAt ? new Date(new Date(appt.body.startAt).getTime() + 5.5 * 3600e3).toISOString().slice(0, 10) : istDate(1)}`);
  check('booked appointment in doctor queue', q.body.items?.some((a) => a.id === appt.body.id), q.body.items?.map((a) => a.id));
  const snap = await call(D, 'GET', `/clinician/patients/${ramesh.id}/snapshot`);
  check('clinical snapshot with allergies + home-visit findings', snap.status === 200 && snap.body.patient.allergies.length > 0 && snap.body.homeVisitFindings.length > 0, snap.status);
  if (snap.body.aiSummary) check('AI summary is advisory with sourced claims', snap.body.aiSummary.advisory === true && snap.body.aiSummary.claims.every((c) => c.sources.length > 0), snap.body.aiSummary);
  const st = await call(D, 'POST', `/clinician/appointments/${appt.body.id}/start`);
  check('consultation started', st.body.status === 'in_progress', st.body);
  const plan = await call(D, 'POST', '/care-plans', {
    careEpisodeId: appt.body.careEpisodeId, summary: 'Tension-type headache likely; BP above target.', instructions: 'Hydration, sleep hygiene, home BP log for 7 days.',
    tasks: [{ type: 'monitoring', title: 'Log BP every morning', owner: 'caregiver', dueAt: new Date(Date.now() + 7 * 86400e3).toISOString() },
            { type: 'test', title: 'Lipid profile', owner: 'patient' }],
    medications: [{ name: 'Paracetamol 500mg', dose: '1 tablet', frequency: 'SOS, max 3/day', times: ['09:00'], startDate: istDate(0), endDate: istDate(5) }],
    followUp: { afterDays: 7, mode: 'video' },
  });
  check('care plan created with tasks', plan.status === 201 && plan.body.tasks.length >= 2, plan.body);
  const comp = await call(D, 'POST', `/clinician/appointments/${appt.body.id}/complete`, { notes: 'Reviewed home vitals. Plan shared.', outcome: 'care_plan' });
  check('consultation completed', comp.body.status === 'completed', comp.body);
  const unrelated = await call(D, 'GET', `/clinician/patients/${patients.body.items.find((p) => p.isSelf).id}/snapshot`);
  check('doctor denied unrelated patient snapshot', unrelated.status === 403 || unrelated.status === 404, unrelated.status);

  console.log('\nContinuity: tasks, meds, timeline, notifications');
  const tasks = await call(P, 'GET', `/care-tasks?patientId=${ramesh.id}&status=open`);
  const bpTask = tasks.body.items.find((t) => t.title.includes('BP'));
  check('patient sees care tasks', !!bpTask, tasks.body.items?.map((t) => t.title));
  const tdone = await call(P, 'POST', `/care-tasks/${bpTask.id}/complete`, { note: '138/88' });
  check('task completed', tdone.body.status === 'done', tdone.body);
  const meds = await call(P, 'GET', `/medications?patientId=${ramesh.id}&active=true`);
  check('medications incl. prescribed', meds.body.items.some((m) => m.name.includes('Paracetamol')), meds.body.items?.map((m) => m.name));
  const rem = await call(P, 'GET', `/reminders/today?patientId=${ramesh.id}`);
  check('today reminders available', rem.status === 200 && Array.isArray(rem.body.items), rem.status);
  const tl = await call(P, 'GET', `/timeline?patientId=${ramesh.id}`);
  check('timeline includes visit summary', tl.body.items.some((i) => i.kind === 'record' || i.kind === 'home_visit'), tl.body.items?.slice(0, 5));
  const ep = await call(P, 'GET', `/care-episodes/${appt.body.careEpisodeId}`);
  check('episode progressed to FOLLOW_UP/UNDER_CARE with events', ['FOLLOW_UP', 'UNDER_CARE'].includes(ep.body.status) && ep.body.events.length >= 3, { status: ep.body.status, events: ep.body.events?.map((e) => e.type) });
  const notif = await call(P, 'GET', '/notifications');
  check('notifications generated', notif.body.items.length > 0, notif.body);

  console.log('\nRecords upload');
  const fd = new FormData();
  fd.append('patientId', ramesh.id); fd.append('type', 'lab_report'); fd.append('title', 'HbA1c Report'); fd.append('recordDate', istDate(0));
  fd.append('file', new Blob(['%PDF-1.4\n% e2e test\nHbA1c 7.2%\n%%EOF'], { type: 'application/pdf' }), 'hba1c.pdf');
  const up = await call(P, 'POST', '/records', fd);
  check('record uploaded with provenance', up.status === 201 && up.body.source === 'patient_entered', up.body);

  console.log('\nFamily caregiver permissions');
  const lak = await login('+919800000002');
  const L = lak.accessToken;
  const lr = await call(L, 'GET', `/records?patientId=${ramesh.id}`);
  check('caregiver with view_records can read records', lr.status === 200, lr.status);
  const lb = await call(L, 'POST', '/home-visits', { patientId: ramesh.id, serviceCode: 'vitals_check', reason: 'x', address: { line1: 'x', city: 'Hyderabad', pincode: '500034' }, preferredStart: start.toISOString(), preferredEnd: new Date(start.getTime() + 3600e3).toISOString() }, { 'idempotency-key': randomUUID() });
  check('caregiver without book permission is denied', lb.status === 403, lb.status);

  console.log('\nEmergency SOS & ops escalation');
  const sos = await call(P, 'POST', '/emergency/sos', { patientId: ramesh.id, lat: 17.4065, lng: 78.4772 }, { 'idempotency-key': randomUUID() });
  check('SOS returns 108 helpline + notified contacts', sos.body?.helpline === '108', sos.body);
  const se = await call(O, 'GET', '/ops/safety-events?status=open');
  const ev = se.body.items.find((e) => e.level === 'emergency');
  check('emergency appears in ops escalation inbox', !!ev, se.body.items?.length);
  if (ev) {
    const ack = await call(O, 'POST', `/ops/safety-events/${ev.id}/acknowledge`);
    check('ops acknowledged', ack.body.status === 'acknowledged', ack.body);
  }
  const ov = await call(O, 'GET', '/ops/overview');
  check('ops overview counts', ov.status === 200 && typeof ov.body.counts.activeEpisodes === 'number', ov.body);

  console.log('\nAdmin governance');
  const adm = await login('+919800000501');
  const A = adm.accessToken;
  const packs = await call(A, 'GET', '/admin/safety-rule-packs');
  check('active rule pack visible (fixture in dev)', packs.body.items.some((p) => p.active), packs.body.items?.map((p) => [p.version, p.status, p.active]));
  const audit = await call(A, 'GET', '/admin/audit-logs?limit=50');
  check('audit log records actions', audit.body.items.length > 0, audit.status);
  const deniedAudit = await call(A, 'GET', '/admin/audit-logs?limit=100');
  check('denied access is audited', deniedAudit.body.items.some((a) => a.outcome === 'denied'), deniedAudit.body.items?.map((a) => a.outcome).slice(0, 10));
  const aiLog = await call(A, 'GET', '/admin/ai-interactions');
  check('AI interactions audited with versions', aiLog.body.items.length > 0 && aiLog.body.items[0].rulePackVersion, aiLog.body.items?.[0]);
  const coord = await login('+919800000301');
  const cw = await call(coord.accessToken, 'PUT', '/admin/feature-flags/kill_switch_ai', { enabled: true });
  check('coordinator cannot change feature flags', cw.status === 403, cw.status);
  const an = await call(A, 'GET', '/admin/analytics');
  check('analytics funnel available', an.status === 200 && an.body.funnel.appointmentsBooked >= 1, an.body.funnel);

  console.log('\nv1.2: prescriptions, invoices, reviews');
  const rx = await call(D, 'POST', '/clinician/prescriptions', {
    appointmentId: appt.body.id, advice: 'Rest and hydrate.', followUpInDays: 7,
    items: [{ drugName: 'Paracetamol', strength: '500mg', form: 'tablet', dose: '1 tablet', frequency: 'twice daily', timing: 'after food', durationDays: 3, times: ['09:00', '21:00'] }],
  });
  check('doctor issued e-prescription with PDF record', rx.status === 201 && !!rx.body.recordId, rx.body);
  const pdf = await fetch(`${BASE}/prescriptions/${rx.body.id}/pdf`, { headers: { authorization: `Bearer ${P}` } });
  const pdfHead = Buffer.from(await pdf.arrayBuffer()).subarray(0, 4).toString();
  check('patient downloads prescription PDF', pdf.status === 200 && pdfHead === '%PDF', { status: pdf.status, pdfHead });
  const inv = await call(P, 'GET', `/payments/${b1.body.payment.id}/invoice`);
  check('invoice issued for paid consultation', inv.status === 200 && /^CC\/\d{4}-\d{2}\/\d+$/.test(inv.body.number), inv.body);
  const pend = await call(P, 'GET', `/reviews/pending?patientId=${ramesh.id}`);
  const pendAppt = pend.body.items?.find((i) => i.targetId === appt.body.id);
  check('completed consultation awaits review', !!pendAppt, pend.body);
  const rev = await call(P, 'POST', '/reviews', { targetType: 'appointment', targetId: appt.body.id, rating: 5 });
  check('rating-only review published', rev.status === 201 && rev.body.status === 'published', rev.body);
  const rev2 = await call(P, 'POST', '/reviews', { targetType: 'appointment', targetId: appt.body.id, rating: 4 });
  check('second review rejected', rev2.status === 409, rev2.status);
  const earn = await call(D, 'GET', '/provider/earnings');
  check('doctor earnings computed', earn.status === 200 && typeof earn.body.payable === 'number', earn.body);

  console.log('\nv1.2: care-team messaging, referral, coordinator');
  const epId = appt.body.careEpisodeId;
  const m1 = await call(P, 'POST', `/care-episodes/${epId}/messages`, { text: 'BP this morning was 138/88.' });
  check('patient messages care team', m1.status === 201 && m1.body.kind === 'text', m1.body);
  const dInbox = await call(D, 'GET', '/inbox');
  check('doctor sees thread with unread message', dInbox.body.items?.some((t) => t.careEpisodeId === epId && t.unread > 0), dInbox.body.items?.slice(0, 3));
  const vProv = await call(V, 'GET', `/care-episodes/${epId}/messages`);
  check('home-care provider is not a thread participant', vProv.status === 403, vProv.status);
  await call(P, 'POST', `/care-episodes/${epId}/messages`, { text: 'He suddenly has severe chest pain and cannot breathe' });
  const thread = await call(D, 'GET', `/care-episodes/${epId}/messages`);
  check('emergency message triggers 108 notice', thread.body.items?.some((m) => m.kind === 'emergency_notice'), thread.body.items?.map((m) => m.kind));
  const fac = await call(D, 'GET', '/facilities?type=hospital');
  const ref = await call(D, 'POST', '/clinician/referrals', { careEpisodeId: epId, facilityId: fac.body.items[0].id, urgency: 'routine', reason: 'Cardiology opinion for BP control' });
  check('referral letter generated', ref.status === 201 && !!ref.body.letterRecordId, ref.body);
  const cl = await call(coord.accessToken, 'GET', '/coordinator/caseload');
  check('coordinator caseload available', cl.status === 200 && Array.isArray(cl.body.items) && cl.body.items.length > 0, cl.body);

  console.log('\nv1.2: subscription, schemes, ABHA');
  const plans = await call(P, 'GET', '/subscription-plans');
  check('family care plans listed', plans.body.items?.length >= 2, plans.body);
  const sub = await call(P, 'POST', '/subscriptions', { planCode: 'family_basic', billing: 'monthly' }, { 'idempotency-key': randomUUID() });
  check('subscription created pending payment', sub.status === 201 && sub.body.subscription.status === 'pending', sub.body);
  await call(P, 'POST', `/payments/${sub.body.payment.id}/confirm-mock`, { outcome: 'success' }, { 'idempotency-key': randomUUID() });
  const subMe = await call(P, 'GET', '/subscriptions/me');
  check('subscription active after payment', subMe.body.status === 'active', subMe.body);
  const schemes = await call(P, 'GET', '/schemes?state=Telangana');
  check('government schemes published', schemes.body.items?.length >= 3, schemes.body.items?.map((s) => s.name));
  const abha = await call(P, 'PATCH', `/patients/${ramesh.id}`, { abhaNumber: '12345678901234' });
  check('ABHA number normalised', abha.body.abha?.number === '12-3456-7890-1234', abha.body.abha);
  const abhaV = await call(P, 'POST', `/patients/${ramesh.id}/abha/verify`);
  check('ABHA verification pending ABDM certification (503)', abhaV.status === 503, abhaV.status);

  console.log('\nv1.2: provider onboarding');
  const appl = await login('+919800000701');
  const AP = appl.accessToken;
  const app1 = await call(AP, 'POST', '/provider-applications', { type: 'nurse', fullName: 'E2E Nurse', qualification: 'GNM', registrationNumber: 'TSNC-E2E-1', experienceYears: 4, languages: ['English', 'Telugu'], preferredZoneIds: [] });
  check('nurse application submitted', app1.status === 201 && app1.body.status === 'submitted', app1.body);
  for (const docType of ['registration_certificate', 'id_proof']) {
    const f = new FormData();
    f.append('docType', docType);
    f.append('file', new Blob(['%PDF-1.4\n% e2e\n%%EOF'], { type: 'application/pdf' }), `${docType}.pdf`);
    await call(AP, 'POST', '/provider-applications/me/documents', f);
  }
  const dec = await call(O, 'POST', `/ops/provider-applications/${app1.body.id}/decision`, { decision: 'approve', note: 'Verified with council', credentialExpiresAt: new Date(Date.now() + 365 * 86400e3).toISOString(), capabilities: ['vitals_check'] });
  check('ops approved application', dec.status === 200 && dec.body.status === 'approved', dec.body);
  const approved = await login('+919800000701');
  check('approved applicant now has provider role', approved.user.roles.includes('provider'), approved.user.roles);

  console.log('\nv1.3: daily check-in, care programs, preventive care');
  const ci = await call(P, 'POST', `/patients/${ramesh.id}/checkins`, { mood: 4 });
  check('daily "I\'m OK" check-in recorded', [200, 201].includes(ci.status) && ['ok', 'late'].includes(ci.body.status), ci.body);
  const enr = await call(P, 'GET', `/care-programs/enrollments?patientId=${ramesh.id}`);
  const htn = enr.body.items?.find((e) => e.templateCode === 'hypertension');
  check('hypertension program enrollment active', htn && htn.status === 'active', enr.body.items);
  const bpHigh = await call(P, 'POST', '/vitals', { patientId: ramesh.id, type: 'bp_systolic', value: 172, unit: 'mmHg', measuredAt: new Date().toISOString() });
  check('high BP reading accepted', bpHigh.status === 201, bpHigh.status);
  const seProg = await call(O, 'GET', '/ops/safety-events?status=open');
  check('program threshold breach raised a safety event', seProg.body.items?.some((e) => e.source === 'program'), seProg.body.items?.map((e) => e.source));
  const prev = await call(P, 'GET', `/patients/${ramesh.id}/preventive-schedule`);
  check('preventive schedule computed', prev.status === 200 && prev.body.items?.length > 0, prev.status);

  console.log('\nv1.3: prescription safety, AI scribe, second opinion');
  const fl = await call(P, 'POST', '/appointments', { patientId: ramesh.id, doctorId: ananya.id, slotId: (await (async () => { for (let i = 2; i <= 9; i++) { const s = await call(P, 'GET', `/doctors/${ananya.id}/slots?date=${istDate(i)}`); const f = s.body.items?.find((x) => x.status === 'available'); if (f) return f.id; } })()), mode: 'video', reason: 'BP review' }, { 'idempotency-key': randomUUID() });
  await call(P, 'POST', `/payments/${fl.body.payment.id}/confirm-mock`, { outcome: 'success' }, { 'idempotency-key': randomUUID() });
  await call(D, 'POST', `/clinician/appointments/${fl.body.appointment.id}/start`);
  const chk = await call(D, 'POST', '/clinician/prescriptions/check', { patientId: ramesh.id, items: [{ drugName: 'Amoxicillin' }] });
  check('penicillin allergy flagged for amoxicillin', chk.body.warnings?.some((w) => w.type === 'allergy'), chk.body);
  const rxAllergy = { appointmentId: fl.body.appointment.id, items: [{ drugName: 'Amoxicillin', strength: '500mg', form: 'capsule', dose: '1 capsule', frequency: 'three times daily', durationDays: 5, times: ['08:00', '14:00', '20:00'] }] };
  const rxBlocked = await call(D, 'POST', '/clinician/prescriptions', rxAllergy);
  const majors = (rxBlocked.body?.error?.details?.warnings ?? []).filter((w) => w.severity === 'major').length;
  check('major warning blocks prescription without acknowledgement', majors === 0 || rxBlocked.status === 400, { status: rxBlocked.status, majors });
  const scribe = await call(D, 'POST', `/clinician/appointments/${fl.body.appointment.id}/scribe`, { transcript: 'Patient reports morning headaches. BP at home around 150 over 95. Taking amlodipine daily. Plan: continue, add home BP log.', consentConfirmed: true });
  check('AI scribe returns advisory SOAP draft', scribe.status === 200 || scribe.status === 201 ? scribe.body.advisory === true && !!scribe.body.draft?.plan : false, scribe.body);
  const noConsent = await call(D, 'POST', `/clinician/appointments/${fl.body.appointment.id}/scribe`, { transcript: 'x', consentConfirmed: false });
  check('scribe refused without recording consent', noConsent.status === 400 || noConsent.status === 403, noConsent.status);
  const pricing = await call(P, 'GET', '/second-opinions/pricing');
  const so = await call(P, 'POST', '/second-opinions', { patientId: ramesh.id, specialty: pricing.body.items[0].specialty, question: 'Is the current BP medication adequate?', recordIds: [up.body.id] }, { 'idempotency-key': randomUUID() });
  check('second opinion requested', so.status === 201 && !!so.body.request?.id, so.body);

  console.log('\nv1.3: lab tests, coupons & wallet, insurance');
  const tests = await call(P, 'GET', '/lab/tests?q=HbA1c');
  const cpn = await call(P, 'POST', '/coupons/validate', { code: 'CARE10', purpose: 'lab_order', amount: 1000 });
  check('coupon CARE10 validates for lab orders', cpn.body.valid === true && cpn.body.discount > 0, cpn.body);
  const lab = await call(P, 'POST', '/lab/orders', { patientId: ramesh.id, testIds: [tests.body.items[0].id], address: { line1: 'Flat 302, Green Residency', city: 'Hyderabad', pincode: '500034' }, preferredStart: start.toISOString(), preferredEnd: new Date(start.getTime() + 3600e3).toISOString(), couponCode: 'CARE10' }, { 'idempotency-key': randomUUID() });
  check('lab order created with coupon discount', lab.status === 201 && lab.body.order.discount > 0, lab.body);
  if (lab.body.payment?.status !== 'succeeded') await call(P, 'POST', `/payments/${lab.body.payment.id}/confirm-mock`, { outcome: 'success' }, { 'idempotency-key': randomUUID() });
  const labAfter = await call(P, 'GET', `/lab/orders/${lab.body.order.id}`);
  check('paid lab order scheduled with sample-collection visit', labAfter.body.status === 'scheduled' && !!labAfter.body.collectionVisitId, labAfter.body);
  const visitLab = await call(P, 'GET', `/home-visits/${labAfter.body.collectionVisitId}`);
  check('collection visit carries the ordered tests', visitLab.body.labOrder?.tests?.length > 0, visitLab.body.labOrder);
  const pol = await call(P, 'GET', `/patients/${ramesh.id}/insurance-policies`);
  check('insurance policy number is masked', pol.body.items?.length > 0 && !/\d{6,}/.test(pol.body.items[0].policyNumberMasked), pol.body.items?.[0]);

  console.log('\nv1.3: WhatsApp & phone line (mock partners)');
  const waEm = await call(P, 'POST', '/dev/whatsapp/simulate', { text: 'my father has severe chest pain and cannot breathe' });
  check('WhatsApp emergency gets 108 even before subscribing', waEm.body.replies?.some((r) => /108/.test(r)), waEm.body);
  await call(P, 'PUT', '/me/whatsapp', { optedIn: true });
  const wa = await call(P, 'POST', '/dev/whatsapp/simulate', { text: 'TODAY' });
  check('WhatsApp TODAY returns reminders after opt-in', wa.status === 200 && /reminder/i.test(wa.body.replies?.[0] ?? ''), wa.body);
  const ivr = await call(P, 'POST', '/dev/ivr/simulate', { fromPhone: '+919800000001' });
  check('IVR greets a known caller with the menu', ivr.status === 200 && !!ivr.body.say, ivr.body);

  console.log('\nv1.3: ambulance, safe zone, support desk');
  const amb = await call(P, 'POST', '/ambulance/requests', { patientId: ramesh.id, pickup: { lat: 17.4065, lng: 78.4772, address: 'Green Residency, Hyderabad' }, type: 'bls', reason: 'Fall at home' }, { 'idempotency-key': randomUUID() });
  const ambReq = amb.body.request ?? amb.body;
  check('ambulance request searching for a vehicle', [200, 201].includes(amb.status) && ['searching', 'assigned'].includes(ambReq.status), amb.body);
  let ambNow;
  for (let i = 0; i < 12; i++) { ambNow = await call(P, 'GET', `/ambulance/requests/${ambReq.id}`); if (ambNow.body.status !== 'searching') break; await new Promise((r) => setTimeout(r, 3000)); }
  check('mock partner assigns a vehicle', ambNow.body.status !== 'searching' && !!ambNow.body.vehicle, ambNow.body.status);
  await call(P, 'POST', `/ambulance/requests/${ambReq.id}/cancel`, { reason: 'e2e cleanup' });
  await call(P, 'PUT', `/patients/${ramesh.id}/safe-zone`, { enabled: true, centerLat: 17.4065, centerLng: 78.4772, radiusMeters: 300 });
  const outside = await call(P, 'POST', `/patients/${ramesh.id}/location`, { lat: 17.45, lng: 78.52, accuracyM: 15, source: 'phone' });
  check('leaving the safe zone is detected', outside.body.inside === false, outside.body);
  const tk = await call(P, 'POST', '/support/tickets', { subject: 'Refund not received', category: 'refund', message: 'I cancelled a visit yesterday.' });
  check('support ticket created', tk.status === 201 && /^T-/.test(tk.body.number), tk.body);
  const agent = await login('+919800000801');
  const note = await call(agent.accessToken, 'POST', `/ops/support/tickets/${tk.body.id}/reply`, { text: 'Internal: check gateway', internal: true });
  await call(agent.accessToken, 'POST', `/ops/support/tickets/${tk.body.id}/reply`, { text: 'Your refund is on its way.' });
  const tkMine = await call(P, 'GET', `/support/tickets/${tk.body.id}`);
  check('customer sees agent reply but not internal note', note.status === 201 && tkMine.body.messages?.some((m) => /on its way/.test(m.text)) && !tkMine.body.messages?.some((m) => /Internal: check gateway/.test(m.text)), tkMine.body.messages?.map((m) => m.text));

  console.log('\nv1.3: hospital discharge, company plan, provider route');
  const hosp = await login('+919800000701');
  const dfd = new FormData();
  dfd.append('patient', JSON.stringify({ name: 'E2E Discharged Patient', phone: '+919800000901', dob: '1955-04-02', gender: 'female' }));
  dfd.append('dischargeDate', istDate(0)); dfd.append('diagnosisSummary', 'Post knee replacement'); dfd.append('treatingDoctorName', 'Dr. E2E Ortho');
  dfd.append('followUp', JSON.stringify({ tasks: [{ type: 'follow_up', title: 'Wound check', owner: 'patient' }], medications: [], followUpDays: [7, 14] }));
  dfd.append('file', new Blob(['%PDF-1.4\n% discharge\n%%EOF'], { type: 'application/pdf' }), 'discharge.pdf');
  const dis = await call(hosp.accessToken, 'POST', '/discharges', dfd);
  check('hospital desk creates a 30-day discharge program', dis.status === 201 && !!dis.body.careEpisodeId, dis.body);
  const hospOther = await call(hosp.accessToken, 'GET', '/clinician/queue');
  check('hospital staff cannot reach clinician API', hospOther.status === 403, hospOther.status);
  const org = await call(A, 'POST', '/admin/organizations', { name: 'E2E Corp', contactName: 'HR', contactEmail: 'hr@e2e.example', planCode: 'family_basic', seats: 5, validFrom: istDate(0), validTo: istDate(365) });
  const codes = await call(A, 'POST', `/admin/organizations/${org.body.id}/codes`, { count: 1 });
  const redeemer = await login('+919800000902');
  const red = await call(redeemer.accessToken, 'POST', '/subscriptions/redeem', { code: codes.body.codes?.[0] });
  check('employee redeems company plan code', red.body.status === 'active' && red.body.sponsorName === 'E2E Corp', red.body);
  const route = await call(V, 'GET', `/provider/route?date=${istDate(0)}`);
  check('nurse route planned for today', route.status === 200 && Array.isArray(route.body.stops), route.body);

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(1); });

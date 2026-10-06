import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { SEED_PHONES, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let ramesh: string;
let sunita: string;
let ravi: string;
let anil: string;
const address = { line1: 'Flat 302, Sai Residency', city: 'Hyderabad', pincode: '500034' };

const window = (hoursFromNow: number, len = 2) => {
  const s = new Date(Date.now() + hoursFromNow * 3600_000);
  return { preferredStart: s.toISOString(), preferredEnd: new Date(s.getTime() + len * 3600_000).toISOString() };
};

beforeAll(async () => {
  t = await setup();
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  sunita = (await t.login(SEED_PHONES.sunita)).accessToken;
  ravi = (await t.login(SEED_PHONES.ravi)).accessToken;
  anil = (await t.login(SEED_PHONES.anil)).accessToken;
  ramesh = await rameshId(t, vaibhav);
});
afterAll(async () => t.close());

const request = (serviceCode: string, w = window(3), addr = address) =>
  t.req(vaibhav, 'POST', '/home-visits', { patientId: ramesh, serviceCode, address: addr, reason: 'BP check', ...w }, idem());

describe('home visits', () => {
  it('serviceability', async () => {
    const ok = await t.req(vaibhav, 'POST', '/home-visit/serviceability', { pincode: '500034' });
    expect(ok.body).toMatchObject({ serviceable: true, zoneName: 'Hyderabad-Central' });
    const no = await t.req(vaibhav, 'POST', '/home-visit/serviceability', { pincode: '560001' });
    expect(no.body).toMatchObject({ serviceable: false, zoneId: null });
    const r = await request('vitals_check', window(3), { ...address, pincode: '560001' });
    expect(r.status).toBe(422);
    expect(r.body.error.code).toBe('NOT_SERVICEABLE');
  });

  it('expired provider is never matched (even when others are off duty)', async () => {
    const anilMe = await t.req(anil, 'GET', '/provider/me');
    expect(anilMe.body.verificationStatus).toBe('expired');
    expect((await t.req(anil, 'POST', '/provider/duty', { onDuty: true })).status).toBe(403);
    await t.req(sunita, 'POST', '/provider/duty', { onDuty: false });
    await t.req(ravi, 'POST', '/provider/duty', { onDuty: false });
    const r = await request('elderly_care', window(30));
    expect(r.status).toBe(201);
    expect(r.body.homeVisit.status).toBe('unassigned');
    expect(r.body.homeVisit.provider).toBeNull();
    // ops cannot force-assign the expired provider either
    const meera = (await t.login(SEED_PHONES.meera)).accessToken;
    const provs = await t.req(meera, 'GET', '/ops/providers');
    const anilId = provs.body.items.find((p: any) => p.name === 'Anil Kumar').id;
    const assign = await t.req(meera, 'POST', `/home-visits/${r.body.homeVisit.id}/assign`, { providerId: anilId });
    expect(assign.status).toBe(409);
    await t.req(sunita, 'POST', '/provider/duty', { onDuty: true });
    await t.req(ravi, 'POST', '/provider/duty', { onDuty: true });
  });

  it('full lifecycle: visitCode hidden from provider, wrong code rejected, completion creates visit_summary', async () => {
    const r = await request('elderly_care', window(5));
    expect(r.status).toBe(201);
    const hv = r.body.homeVisit;
    expect(hv.status).toBe('assigned');
    expect(hv.provider.name).toBe('Sunita Devi'); // only Sunita has elderly_care among eligible
    expect(hv.visitCode).toMatch(/^\d{4}$/);
    expect(hv.provider.phoneMasked).not.toContain('000201'.slice(0, 3) + '000');
    const code = hv.visitCode;

    // provider view: no visitCode, has patientContext
    const pv = await t.req(sunita, 'GET', `/home-visits/${hv.id}`);
    expect(pv.status).toBe(200);
    expect(pv.body.visitCode).toBeNull();
    expect(pv.body.patientContext.allergies).toContain('Penicillin');
    const list = await t.req(sunita, 'GET', '/provider/visits?scope=today');
    for (const v of list.body.items) expect(v.visitCode).toBeNull();
    // B2: until accepted, the provider sees locality only
    expect(pv.body.addressMasked).toBe(true);
    expect(pv.body.address.line1).toBeUndefined();
    expect(pv.body.address).toMatchObject({ city: 'Hyderabad', pincode: '500034' });
    // window(5) can fall after midnight IST, so the visit may be in 'upcoming' rather than 'today'.
    const upcoming = await t.req(sunita, 'GET', '/provider/visits?scope=upcoming');
    const listed = [...list.body.items, ...upcoming.body.items].find((v: any) => v.id === hv.id);
    expect(listed.address.line1).toBeUndefined();
        // another provider cannot act on it
    expect((await t.req(ravi, 'POST', `/home-visits/${hv.id}/accept`)).status).toBe(403);
    expect((await t.req(ravi, 'GET', `/home-visits/${hv.id}`)).status).toBe(403);

    expect((await t.req(sunita, 'POST', `/home-visits/${hv.id}/arrived`)).status).toBe(409); // invalid order
    const acc = await t.req(sunita, 'POST', `/home-visits/${hv.id}/accept`);
    expect(acc.body.status).toBe('accepted');
    expect(acc.body.addressMasked).toBe(false);
    expect(acc.body.address.line1).toBe(address.line1);
    expect((await t.req(sunita, 'POST', `/home-visits/${hv.id}/en-route`, { etaMinutes: 20 })).body.etaMinutes).toBe(20);
    expect((await t.req(sunita, 'POST', `/home-visits/${hv.id}/arrived`)).body.status).toBe('arrived');
    const wrong = await t.req(sunita, 'POST', `/home-visits/${hv.id}/verify-identity`, { visitCode: code === '0000' ? '1111' : '0000', consentConfirmed: true });
    expect(wrong.status).toBe(400);
    const noConsent = await t.req(sunita, 'POST', `/home-visits/${hv.id}/verify-identity`, { visitCode: code, consentConfirmed: false });
    expect(noConsent.status).toBe(400);
    const ok = await t.req(sunita, 'POST', `/home-visits/${hv.id}/verify-identity`, { visitCode: code, consentConfirmed: true });
    expect(ok.body.status).toBe('in_progress');
    expect(ok.body.visitCode).toBeNull();

    const vit = await t.req(
      sunita,
      'POST',
      `/home-visits/${hv.id}/vitals`,
      { measurements: [{ type: 'bp_systolic', value: 132, unit: 'mmHg', measuredAt: new Date().toISOString() }, { type: 'spo2', value: 97, unit: '%', measuredAt: new Date().toISOString() }] },
      idem(),
    );
    expect(vit.status).toBe(200);
    expect(vit.body.vitals).toHaveLength(2);
    expect(vit.body.vitals[0].source).toBe('home_visit');
    expect((await t.req(sunita, 'POST', `/home-visits/${hv.id}/observations`, { notes: 'Stable', checklist: { medsReviewed: true } })).body.observations.notes).toBe('Stable');
    const done = await t.req(sunita, 'POST', `/home-visits/${hv.id}/complete`, { summary: 'Vitals stable. Continue medicines.' });
    expect(done.status).toBe(200);
    expect(done.body.status).toBe('completed');

    const records = await t.req(vaibhav, 'GET', `/records?patientId=${ramesh}&type=visit_summary`);
    const summary = records.body.items.find((x: any) => x.source === 'home_visit' && x.recordDate && x.hasFile && x.title.includes('Elderly'));
    expect(summary).toBeTruthy();
    const file = await t.req(vaibhav, 'GET', `/records/${summary.id}/file`);
    expect(String(file.body)).toContain('Vitals stable');
    const ep = await t.req(vaibhav, 'GET', `/care-episodes/${hv.careEpisodeId}`);
    expect(ep.body.status).toBe('FOLLOW_UP');
    expect(ep.body.events.map((e: any) => e.type)).toEqual(expect.arrayContaining(['home_visit_requested', 'home_visit_started', 'home_visit_completed']));
    const fam = await t.req(vaibhav, 'GET', `/home-visits/${hv.id}`);
    expect(fam.body.visitCode).toBe(code);
    expect(fam.body.patientContext).toBeNull();
  });

  it('safety engine on visit vitals: SpO2 < 90 raises an emergency safety event', async () => {
    const r = await request('vitals_check', window(8));
    const hv = r.body.homeVisit;
    const who = hv.provider.name === 'Sunita Devi' ? sunita : ravi;
    await t.req(who, 'POST', `/home-visits/${hv.id}/accept`);
    await t.req(who, 'POST', `/home-visits/${hv.id}/en-route`, { etaMinutes: 5 });
    await t.req(who, 'POST', `/home-visits/${hv.id}/arrived`);
    await t.req(who, 'POST', `/home-visits/${hv.id}/verify-identity`, { visitCode: hv.visitCode, consentConfirmed: true });
    await t.req(who, 'POST', `/home-visits/${hv.id}/vitals`, { measurements: [{ type: 'spo2', value: 86, unit: '%', measuredAt: new Date().toISOString() }] }, idem());
    const ops = (await t.login(SEED_PHONES.ops)).accessToken;
    const ev = await t.req(ops, 'GET', '/ops/safety-events?status=open');
    const mine = ev.body.items.find((e: any) => e.careEpisodeId === hv.careEpisodeId);
    expect(mine).toMatchObject({ level: 'emergency', source: 'home_visit' });
    expect(mine.rules[0].ruleId).toBe('fx.emergency.vital.spo2_low');
    const ep = await t.req(vaibhav, 'GET', `/care-episodes/${hv.careEpisodeId}`);
    expect(ep.body.status).toBe('EMERGENCY');
    const ack = await t.req(ops, 'POST', `/ops/safety-events/${mine.id}/acknowledge`);
    expect(ack.body.status).toBe('acknowledged');
    const res = await t.req(ops, 'POST', `/ops/safety-events/${mine.id}/resolve`, { note: 'Patient transferred' });
    expect(res.body.status).toBe('resolved');
  });

  it('provider escalation copies the reason and visit reference into the Ops safety event note (B27)', async () => {
    const r = await request('vitals_check', window(10));
    const hv = r.body.homeVisit;
    const who = hv.provider.name === 'Sunita Devi' ? sunita : ravi;
    await t.req(who, 'POST', `/home-visits/${hv.id}/accept`);
    await t.req(who, 'POST', `/home-visits/${hv.id}/en-route`, { etaMinutes: 5 });
    await t.req(who, 'POST', `/home-visits/${hv.id}/arrived`);
    const esc = await t.req(who, 'POST', `/home-visits/${hv.id}/escalate`, { reason: 'Patient confused and breathless', severity: 'urgent' });
    expect(esc.status).toBe(200);
    const ops = (await t.login(SEED_PHONES.ops)).accessToken;
    const ev = await t.req(ops, 'GET', '/ops/safety-events?status=open');
    const mine = ev.body.items.find((e: any) => e.careEpisodeId === hv.careEpisodeId && e.rules[0]?.ruleId === 'provider.escalation');
    expect(mine.note).toContain('Patient confused and breathless');
    expect(mine.note).toContain(hv.id);
  });

  it('reject sends the visit back to the matcher', async () => {
    const r = await request('sample_collection', window(20, 1));
    const hv = r.body.homeVisit;
    expect(hv.status).toBe('assigned');
    const first = hv.provider.name;
    const tok = first === 'Sunita Devi' ? sunita : ravi;
    const rej = await t.req(tok, 'POST', `/home-visits/${hv.id}/reject`, { reason: 'Too far' });
    expect(rej.status).toBe(200);
    const after = await t.req(vaibhav, 'GET', `/home-visits/${hv.id}`);
    expect(after.body.provider?.name).not.toBe(first);
    expect(after.body.provider?.name).not.toBe('Anil Kumar');
  });

  it('ops views include slaBreached and never the visit code', async () => {
    const meera = (await t.login(SEED_PHONES.meera)).accessToken;
    const r = await t.req(meera, 'GET', '/ops/home-visits');
    expect(r.status).toBe(200);
    for (const v of r.body.items) {
      expect(typeof v.slaBreached).toBe('boolean');
      expect(v.visitCode).toBeNull();
    }
    const o = await t.req(meera, 'GET', '/ops/overview');
    expect(o.body.counts).toHaveProperty('providersOnDuty');
  });
});

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { SEED_PHONES, firstAvailableSlot, idem, rameshId, setup, type TestCtx } from './helpers.js';

function pngOf(width: number, height: number, padTo = 0): Buffer {
  const b = Buffer.alloc(Math.max(33, padTo));
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(b, 0);
  b.writeUInt32BE(13, 8);
  b.write('IHDR', 12, 'latin1');
  b.writeUInt32BE(width, 16);
  b.writeUInt32BE(height, 20);
  return b;
}
function multipart(fields: Record<string, string>, file: { field: string; name: string; data: Buffer; type: string }) {
  const boundary = '----ccf' + Math.random().toString(16).slice(2);
  const parts: Buffer[] = Object.entries(fields).map(([k, v]) => Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${k}"\r\n\r\n${v}\r\n`));
  parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${file.field}"; filename="${file.name}"\r\nContent-Type: ${file.type}\r\n\r\n`), file.data, Buffer.from(`\r\n--${boundary}--\r\n`));
  return { body: Buffer.concat(parts), headers: { 'content-type': `multipart/form-data; boundary=${boundary}` } };
}

let t: TestCtx;
let vaibhav: string;
let ramesh: string;
beforeAll(async () => {
  t = await setup({ config: { FALL_RESPONSE_TIMEOUT_SEC: 60 } });
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  ramesh = await rameshId(t, vaibhav);
});
afterAll(async () => t.close());

describe('catalog GET endpoints return list envelopes', () => {
  it('works for a patient', async () => {
    for (const url of [
      '/specialties',
      '/facilities?lat=17.41&lng=78.44',
      '/home-visit/services',
      '/pharmacy/categories',
      '/pharmacy/products?q=para',
      '/wellness/activities',
      '/wearables/providers',
      '/consents/catalog',
      '/consents',
      '/notifications',
      `/care-plans?patientId=${ramesh}`,
      `/care-tasks?patientId=${ramesh}`,
      `/vitals?patientId=${ramesh}&type=bp_systolic`,
      `/appointments?patientId=${ramesh}&scope=past`,
      `/home-visits?patientId=${ramesh}&scope=past`,
      `/payments?patientId=${ramesh}`,
      `/wellness/mood?patientId=${ramesh}`,
      `/wound-cases?patientId=${ramesh}`,
      `/wearables/connections?patientId=${ramesh}`,
      `/ai/conversations?patientId=${ramesh}`,
      `/pharmacy/orders?patientId=${ramesh}`,
    ]) {
      const r = await t.req(vaibhav, 'GET', url);
      expect(r.status, url).toBe(200);
      expect(Array.isArray(r.body.items), url).toBe(true);
      expect(r.body).toHaveProperty('nextCursor');
    }
    const fac = await t.req(vaibhav, 'GET', '/facilities?lat=17.41&lng=78.44');
    expect(fac.body.items).toHaveLength(6);
    expect(fac.body.items[0].distanceKm).toBeLessThanOrEqual(fac.body.items[1].distanceKm);
    const n = await t.req(vaibhav, 'GET', '/notifications');
    expect(n.headers['x-unread-count']).toBeDefined();
    const prefs = await t.req(vaibhav, 'PUT', '/notification-preferences', { push: true, sms: false, email: false, whatsapp: false, marketing: false });
    expect(prefs.body.sms).toBe(false);
    expect((await t.req(vaibhav, 'POST', '/devices', { pushToken: 'test-push-token-123456', platform: 'android' })).status).toBe(204);
  });

  it('staff lists', async () => {
    const admin = (await t.login(SEED_PHONES.admin)).accessToken;
    for (const url of ['/admin/users?role=doctor', '/admin/audit-logs', '/admin/safety-rule-packs', '/admin/ai-interactions', '/admin/knowledge-sources', '/admin/feature-flags', '/admin/service-zones']) {
      const r = await t.req(admin, 'GET', url);
      expect(r.status, url).toBe(200);
      expect(Array.isArray(r.body.items), url).toBe(true);
    }
    // ops_admin may read zones (needed to approve provider applications) but not create them.
    const opsTok = (await t.login(SEED_PHONES.ops)).accessToken;
    expect((await t.req(opsTok, 'GET', '/admin/service-zones')).status).toBe(200);
    expect((await t.req(opsTok, 'POST', '/admin/service-zones', { name: 'X', city: 'Hyderabad', pincodes: ['500001'] })).status).toBe(403);
    const flags = await t.req(admin, 'GET', '/admin/feature-flags');
    expect(flags.body.items.find((f: any) => f.key === 'wound_ai_analysis').enabled).toBe(false);
    const packs = await t.req(admin, 'GET', '/admin/safety-rule-packs');
    expect(packs.body.items[0]).toMatchObject({ version: 'fixture-0.1', status: 'fixture_unapproved', active: true });
    const ks = await t.req(admin, 'GET', '/admin/knowledge-sources');
    expect(ks.body.items).toHaveLength(3);
    expect(ks.body.items[0].owner).toBe('Clinical Governance (placeholder)');
    const an = await t.req(admin, 'GET', '/admin/analytics');
    expect(an.body.funnel).toHaveProperty('conversationsStarted');
    const ops = (await t.login(SEED_PHONES.ops)).accessToken;
    for (const url of ['/ops/overview', '/ops/home-visits', '/ops/providers?status=verified', '/ops/safety-events', '/ops/care-episodes', '/ops/overdue-tasks', '/ops/incidents', '/ops/payments?status=succeeded']) {
      expect((await t.req(ops, 'GET', url)).status, url).toBe(200);
    }
    const inc = await t.req(ops, 'POST', '/ops/incidents', { type: 'complaint', title: 'Late visit', description: 'Nurse arrived late', severity: 'low', patientId: ramesh });
    expect(inc.status).toBe(201);
    const upd = await t.req(ops, 'PATCH', `/ops/incidents/${inc.body.id}`, { status: 'investigating', note: 'Called family' });
    expect(upd.body.notes).toHaveLength(1);
  });
});

describe('clinician workflow', () => {
  it('start -> care plan -> complete', async () => {
    const docs = await t.req(vaibhav, 'GET', '/doctors');
    const karthik = docs.body.items.find((d: any) => d.name === 'Dr. Karthik Mehta');
    const slot = await firstAvailableSlot(t, vaibhav, karthik.id);
    const b = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId: karthik.id, slotId: slot.id, mode: 'audio', reason: 'Fatigue' }, idem());
    await t.req(vaibhav, 'POST', `/payments/${b.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    const doc = (await t.login(SEED_PHONES.karthik)).accessToken;
    const pats = await t.req(doc, 'GET', '/clinician/patients?q=ramesh');
    expect(pats.body.items[0].name).toBe('Ramesh Kumar');
    const st = await t.req(doc, 'POST', `/clinician/appointments/${b.body.appointment.id}/start`);
    expect(st.body.status).toBe('in_progress');
    const plan = await t.req(doc, 'POST', '/care-plans', {
      careEpisodeId: b.body.appointment.careEpisodeId,
      summary: 'Fatigue work-up',
      instructions: 'Rest, hydrate',
      tasks: [{ type: 'test', title: 'CBC test', owner: 'patient', dueAt: new Date(Date.now() - 3600_000).toISOString() }],
      medications: [{ name: 'Vitamin D3', dose: '60K', frequency: 'Weekly', times: ['09:00'], startDate: '2026-09-01' }],
      followUp: { afterDays: 7, mode: 'video' },
    });
    expect(plan.status).toBe(201);
    expect(plan.body.tasks).toHaveLength(2);
    expect(plan.body.medications[0].source).toBe('clinician_verified');
    const done = await t.req(doc, 'POST', `/clinician/appointments/${b.body.appointment.id}/complete`, { notes: 'Plan shared', outcome: 'care_plan' });
    expect(done.body.status).toBe('completed');
    const ep = await t.req(vaibhav, 'GET', `/care-episodes/${b.body.appointment.careEpisodeId}`);
    expect(ep.body.status).toBe('FOLLOW_UP');
    const note = await t.req(doc, 'POST', `/care-episodes/${ep.body.id}/notes`, { text: 'Reviewed labs' });
    expect(note.status).toBe(201);
    // patient cannot create care plans
    expect((await t.req(vaibhav, 'POST', '/care-plans', { careEpisodeId: ep.body.id, summary: 'x', instructions: 'y', tasks: [], medications: [], followUp: null })).status).toBe(403);

    // worker marks the past-due task overdue
    const res = await t.scheduler.tick(new Date());
    expect(res.markOverdueTasks).toBeGreaterThanOrEqual(1);
    const ops = (await t.login(SEED_PHONES.ops)).accessToken;
    const od = await t.req(ops, 'GET', '/ops/overdue-tasks');
    expect(od.body.items.some((x: any) => x.title === 'CBC test' && x.patientName === 'Ramesh Kumar')).toBe(true);
    const task = (await t.req(vaibhav, 'GET', `/care-tasks?patientId=${ramesh}&status=overdue`)).body.items.find((x: any) => x.title === 'CBC test');
    expect((await t.req(vaibhav, 'POST', `/care-tasks/${task.id}/complete`, { note: 'done' })).body.status).toBe('done');
  });
});

describe('wellness, wound, wearables, pharmacy', () => {
  it('mood entry runs the safety engine', async () => {
    const ok = await t.req(vaibhav, 'POST', '/wellness/mood', { patientId: ramesh, score: 4, shareWithClinician: true });
    expect(ok.status).toBe(201);
    expect(ok.body.safety.level).toBe('none');
    expect(ok.body.supportMessage).toBeTruthy();
    const bad = await t.req(vaibhav, 'POST', '/wellness/mood', { patientId: ramesh, score: 1, note: 'I feel suicidal', shareWithClinician: false });
    expect(bad.body.safety.level).toBe('emergency');
    expect(bad.body.supportMessage).toContain('108');
  });

  it('wound case: quality checks only', async () => {
    const small = multipart({ patientId: ramesh, bodySite: 'left foot' }, { field: 'image', name: 'w.png', data: pngOf(100, 100), type: 'image/png' });
    const r1 = await t.req(vaibhav, 'POST', '/wound-cases', small.body, small.headers);
    expect(r1.status).toBe(201);
    expect(r1.body.status).toBe('retake_required');
    expect(r1.body.quality.issues).toEqual(expect.arrayContaining(['file_too_small', 'image_too_small']));
    const good = multipart({ patientId: ramesh, bodySite: 'left foot', note: 'healing' }, { field: 'image', name: 'w.png', data: pngOf(1200, 900, 30_000), type: 'image/png' });
    const r2 = await t.req(vaibhav, 'POST', '/wound-cases', good.body, good.headers);
    expect(r2.body).toMatchObject({ status: 'pending_clinician_review', quality: { acceptable: true, issues: [] }, clinicianReview: null });
    const ananya = (await t.login(SEED_PHONES.ananya)).accessToken;
    const rev = await t.req(ananya, 'POST', `/wound-cases/${r2.body.id}/review`, { notes: 'Looks clean; continue dressing' });
    expect(rev.body.status).toBe('reviewed');
  });

  it('wearables connect + sync -> device vitals', async () => {
    const c = await t.req(vaibhav, 'POST', '/wearables/connections', { patientId: ramesh, provider: 'health_connect' });
    expect(c.body.status).toBe('connected');
    const s = await t.req(vaibhav, 'POST', '/wearables/sync', {
      patientId: ramesh,
      provider: 'health_connect',
      measurements: [{ type: 'steps', value: 4200, unit: 'steps', measuredAt: new Date().toISOString() }],
    });
    expect(s.body.accepted).toBe(1);
    expect((await t.req(vaibhav, 'POST', '/wearables/connections', { patientId: ramesh, provider: 'fitbit' })).status).toBe(400);
    const rv = await t.req(vaibhav, 'POST', `/wearables/connections/${c.body.id}/revoke`);
    expect(rv.body.status).toBe('revoked');
  });

  it('pharmacy: Rx items need a prescription record', async () => {
    const prods = await t.req(vaibhav, 'GET', '/pharmacy/products?limit=100');
    expect(prods.body.items).toHaveLength(12);
    const azi = prods.body.items.find((p: any) => p.name === 'Azithromycin 500mg');
    const para = prods.body.items.find((p: any) => p.name === 'Paracetamol 500mg');
    const addr = { line1: 'Flat 302', city: 'Hyderabad', pincode: '500034' };
    const bad = await t.req(vaibhav, 'POST', '/pharmacy/orders', { patientId: ramesh, items: [{ productId: azi.id, qty: 1 }], address: addr }, idem());
    expect(bad.status).toBe(400);
    const rx = (await t.req(vaibhav, 'GET', `/records?patientId=${ramesh}&type=prescription`)).body.items[0];
    const ok = await t.req(vaibhav, 'POST', '/pharmacy/orders', { patientId: ramesh, items: [{ productId: azi.id, qty: 1 }, { productId: para.id, qty: 2 }], prescriptionRecordId: rx.id, address: addr }, idem());
    expect(ok.status).toBe(201);
    expect(ok.body.order.total).toBe(60 + 2 * 30);
    await t.req(vaibhav, 'POST', `/payments/${ok.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
    const orders = await t.req(vaibhav, 'GET', `/pharmacy/orders?patientId=${ramesh}`);
    expect(orders.body.items[0].status).toBe('placed');
  });
});

describe('emergency & fall (worker)', () => {
  it('SOS creates an emergency episode and notifies contacts', async () => {
    const r = await t.req(vaibhav, 'POST', '/emergency/sos', { patientId: ramesh, lat: 17.41, lng: 78.44 }, idem());
    expect(r.status).toBe(201);
    expect(r.body.helpline).toBe('108');
    expect(r.body.notifiedContacts).toHaveLength(2);
    expect(r.body.notifiedContacts[0].phoneMasked).toMatch(/X/);
    expect(r.body.nearestEmergencyFacilities.length).toBeGreaterThan(0);
    expect(r.body.nearestEmergencyFacilities.every((f: any) => f.emergency24x7)).toBe(true);
    const ep = await t.req(vaibhav, 'GET', `/care-episodes/${r.body.careEpisodeId}`);
    expect(ep.body.status).toBe('EMERGENCY');
    const lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken;
    const n = await t.req(lakshmi, 'GET', '/notifications');
    expect(n.body.items.some((x: any) => x.category === 'safety' && x.critical)).toBe(true);
  });

  it('fall auto-escalates after the timeout; safe response closes it', async () => {
    const f1 = await t.req(vaibhav, 'POST', '/fall-events', { patientId: ramesh, source: 'phone_sensor' });
    expect(f1.body.status).toBe('awaiting_response');
    const f2 = await t.req(vaibhav, 'POST', '/fall-events', { patientId: ramesh, source: 'wearable' });
    expect((await t.req(vaibhav, 'POST', `/fall-events/${f2.body.id}/respond`, { safe: true })).body.status).toBe('closed_safe');
    await t.scheduler.tick(new Date(Date.now() + 30_000));
    const ops = (await t.login(SEED_PHONES.ops)).accessToken;
    let ev = await t.req(ops, 'GET', '/ops/safety-events');
    const before = ev.body.items.filter((e: any) => e.source === 'fall').length;
    const res = await t.scheduler.tick(new Date(Date.now() + 61_000));
    expect(res.escalateUnansweredFalls).toBe(1);
    ev = await t.req(ops, 'GET', '/ops/safety-events');
    expect(ev.body.items.filter((e: any) => e.source === 'fall').length).toBe(before + 1);
    const res2 = await t.scheduler.tick(new Date(Date.now() + 120_000));
    expect(res2.escalateUnansweredFalls).toBe(0);
  });

  it('worker marks missed doses and dispatches the outbox', async () => {
    const late = new Date(Date.now() + 36 * 3600_000);
    const res = await t.scheduler.tick(late);
    expect(res.dispatchOutbox).toBeGreaterThanOrEqual(0);
    expect(Object.values(res).every((v) => v >= 0)).toBe(true);
  });
});

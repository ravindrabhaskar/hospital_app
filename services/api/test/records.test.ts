import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { sha256 } from '../src/lib/crypto.js';
import { samplePdf } from '../src/db/seed.js';
import { SEED_PHONES, rameshId, setup, type TestCtx } from './helpers.js';

function multipart(fields: Record<string, string>, file?: { name: string; field: string; data: Buffer; type: string }) {
  const boundary = '----cctest' + Math.random().toString(16).slice(2);
  const parts: Buffer[] = [];
  for (const [k, v] of Object.entries(fields)) {
    parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${k}"\r\n\r\n${v}\r\n`));
  }
  if (file) {
    parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${file.field}"; filename="${file.name}"\r\nContent-Type: ${file.type}\r\n\r\n`));
    parts.push(file.data, Buffer.from('\r\n'));
  }
  parts.push(Buffer.from(`--${boundary}--\r\n`));
  return { body: Buffer.concat(parts), headers: { 'content-type': `multipart/form-data; boundary=${boundary}` } };
}

let t: TestCtx;
let vaibhav: string;
let ramesh: string;
beforeAll(async () => {
  t = await setup();
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  ramesh = await rameshId(t, vaibhav);
});
afterAll(async () => t.close());

describe('records', () => {
  it('upload with provenance; AI summary does not alter the original', async () => {
    const pdf = samplePdf('Lipid profile');
    const m = multipart({ patientId: ramesh, type: 'lab_report', title: 'Lipid Profile', recordDate: '2026-09-20' }, { name: 'lipid.pdf', field: 'file', data: pdf, type: 'application/pdf' });
    const up = await t.req(vaibhav, 'POST', '/records', m.body, m.headers);
    expect(up.status).toBe(201);
    expect(up.body).toMatchObject({ type: 'lab_report', source: 'patient_entered', uploadedByName: 'Vaibhav Kumar', mimeType: 'application/pdf', hasFile: true, aiSummary: null, sizeBytes: pdf.length });

    const sum = await t.req(vaibhav, 'POST', `/records/${up.body.id}/summarize`);
    expect(sum.status).toBe(200);
    expect(sum.body.aiSummary).toMatchObject({ model: expect.any(String), disclaimer: expect.stringMatching(/Not a diagnosis/) });
    const file = await t.svc.storage.get(`records/${ramesh}/${up.body.id}.pdf`);
    expect(sha256(file)).toBe(sha256(pdf));
    const again = await t.req(vaibhav, 'GET', `/records/${up.body.id}`);
    expect(again.body.sizeBytes).toBe(pdf.length);
  });

  it('rejects disguised / unsupported files', async () => {
    const m = multipart({ patientId: ramesh, type: 'other', title: 'x', recordDate: '2026-09-20' }, { name: 'evil.pdf', field: 'file', data: Buffer.from('MZ this is not a pdf at all......'), type: 'application/pdf' });
    const r = await t.req(vaibhav, 'POST', '/records', m.body, m.headers);
    expect(r.status).toBe(400);
    expect(r.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('unauthorized download is denied; grantee with view_records may download', async () => {
    const list = await t.req(vaibhav, 'GET', `/records?patientId=${ramesh}`);
    expect(list.body.items.length).toBeGreaterThanOrEqual(5);
    const rec = list.body.items.find((r: any) => r.title === 'Blood Test Report');
    const stranger = (await t.login('+919888888888')).accessToken;
    expect((await t.req(stranger, 'GET', `/records/${rec.id}/file`)).status).toBe(403);
    const priya = (await t.login(SEED_PHONES.priya)).accessToken;
    expect((await t.req(priya, 'GET', `/records/${rec.id}/file`)).status).toBe(403);
    const lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken;
    const ok = await t.req(lakshmi, 'GET', `/records/${rec.id}/file`);
    expect(ok.status).toBe(200);
    expect(ok.headers['content-type']).toBe('application/pdf');
    // sharing with a doctor grants that doctor access
    const sh = await t.req(vaibhav, 'POST', `/records/${rec.id}/share`, { doctorId: (await t.login(SEED_PHONES.priya)).user.providerId, expiresInDays: 7 });
    expect(sh.status).toBe(201);
    expect((await t.req(priya, 'GET', `/records/${rec.id}/file`)).status).toBe(200);
  });

  it('timeline, vitals, insights, medications and reminders', async () => {
    const tl = await t.req(vaibhav, 'GET', `/timeline?patientId=${ramesh}&limit=50`);
    const kinds = new Set(tl.body.items.map((i: any) => i.kind));
    for (const k of ['record', 'appointment', 'home_visit', 'vital', 'care_plan', 'episode', 'medication']) expect(kinds.has(k), k).toBe(true);
    const v = await t.req(vaibhav, 'POST', '/vitals', { patientId: ramesh, type: 'pulse', value: 72, unit: 'bpm', measuredAt: new Date().toISOString() });
    expect(v.body.source).toBe('patient_entered');
    const ins = await t.req(vaibhav, 'GET', `/insights/today?patientId=${ramesh}`);
    expect(ins.body.items.map((i: any) => i.type)).toEqual(expect.arrayContaining(['heart_rate', 'bp']));
    const meds = await t.req(vaibhav, 'GET', `/medications?patientId=${ramesh}&active=true`);
    const metformin = meds.body.items.find((m: any) => m.name === 'Metformin');
    expect(metformin.times).toEqual(['08:00', '20:00']);
    expect(metformin.today).toHaveLength(2);
    const dose = await t.req(vaibhav, 'POST', `/medications/${metformin.id}/doses`, { scheduledAt: metformin.today[0].scheduledAt, status: 'taken' });
    expect(dose.status).toBe(201);
    const rem = await t.req(vaibhav, 'GET', `/reminders/today?patientId=${ramesh}`);
    expect(rem.body.items.find((r: any) => r.refId === metformin.id && r.at === metformin.today[0].scheduledAt).status).toBe('done');
    const pages = await t.req(vaibhav, 'GET', `/timeline?patientId=${ramesh}&limit=2`);
    expect(pages.body.items).toHaveLength(2);
    expect(pages.body.nextCursor).toBeTruthy();
    const p2 = await t.req(vaibhav, 'GET', `/timeline?patientId=${ramesh}&limit=2&cursor=${pages.body.nextCursor}`);
    expect(p2.body.items[0].id).not.toBe(pages.body.items[0].id);
  });
});

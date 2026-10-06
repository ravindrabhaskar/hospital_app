import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { invoices, payments } from '../src/db/schema.js';
import { addDays, istDate } from '../src/lib/time.js';
import { computeEarnings, ensureInvoice, indianFy } from '../src/modules/billing/service.js';
import { SEED_PHONES, firstAvailableSlot, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let lakshmi: string;
let ananya: string;
let karthik: string;
let ops: string;
let ramesh: string;
let doctorId: string;
let skip = 0;

beforeAll(async () => {
  t = await setup();
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken;
  ananya = (await t.login(SEED_PHONES.ananya)).accessToken;
  karthik = (await t.login(SEED_PHONES.karthik)).accessToken;
  ops = (await t.login(SEED_PHONES.ops)).accessToken;
  ramesh = await rameshId(t, vaibhav);
  doctorId = (await t.login(SEED_PHONES.ananya)).user.providerId;
});
afterAll(async () => t.close());

async function bookConfirmed() {
  const slot = await firstAvailableSlot(t, vaibhav, doctorId, skip++);
  const r = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId, slotId: slot.id, mode: 'video', reason: 'Cough and cold' }, idem());
  expect(r.status).toBe(201);
  const p = await t.req(vaibhav, 'POST', `/payments/${r.body.payment.id}/confirm-mock`, { outcome: 'success' }, idem());
  expect(p.body.status).toBe('succeeded');
  return r.body as { appointment: any; payment: any };
}

const rx = (appointmentId: string) => ({
  appointmentId,
  clinicalNote: 'Upper respiratory infection, likely bacterial.',
  items: [
    { drugName: 'Azithromycin', strength: '500mg', form: 'tablet', dose: '1 tablet', frequency: 'Once daily', timing: 'After food', durationDays: 3, times: ['09:00'] },
    { drugName: 'Paracetamol', strength: '500 mg', form: 'tablet', dose: '1 tablet', frequency: 'If needed', durationDays: 3, times: [], instructions: 'For fever above 100F' },
    { drugName: 'Honey-lemon lozenge', form: 'other', dose: '1', frequency: 'As needed', durationDays: 5, times: [] },
  ],
  advice: 'Rest and fluids.',
  followUpInDays: 5,
});

describe('e-prescriptions (section 31)', () => {
  let apptId: string;
  let rxId: string;

  it('only the appointment doctor, only for in-progress/completed consultations', async () => {
    const { appointment } = await bookConfirmed();
    apptId = appointment.id;
    const early = await t.req(ananya, 'POST', '/clinician/prescriptions', rx(apptId));
    expect(early.status).toBe(409);
    expect((await t.req(ananya, 'POST', `/clinician/appointments/${apptId}/start`)).status).toBe(200);
    const other = await t.req(karthik, 'POST', '/clinician/prescriptions', rx(apptId));
    expect(other.status).toBe(403);
    expect((await t.req(vaibhav, 'POST', '/clinician/prescriptions', rx(apptId))).status).toBe(403);
    expect((await t.req(ananya, 'POST', '/clinician/prescriptions', { ...rx(apptId), items: [] })).status).toBe(400);
  });

  it('creates the record, medications, episode event, notification and a real PDF', async () => {
    const r = await t.req(ananya, 'POST', '/clinician/prescriptions', rx(apptId));
    expect(r.status).toBe(201);
    rxId = r.body.id;
    expect(r.body).toMatchObject({
      patientId: ramesh,
      patientName: 'Ramesh Kumar',
      patientGender: 'male',
      doctorName: 'Dr. Ananya Rao',
      doctorQualifications: 'MBBS, MD (General Medicine)',
      doctorRegistration: 'TSMC-SAMPLE-10101',
      appointmentId: apptId,
      followUpInDays: 5,
      advice: 'Rest and fluids.',
    });
    expect(r.body.patientAge).toBeGreaterThanOrEqual(68);
    expect(r.body.items).toHaveLength(3);
    const rec = await t.req(vaibhav, 'GET', `/records/${r.body.recordId}`);
    expect(rec.body).toMatchObject({ type: 'prescription', source: 'clinician_verified', mimeType: 'application/pdf', hasFile: true });
    const file = await t.app.inject({ method: 'GET', url: `/api/v1/prescriptions/${rxId}/pdf`, headers: { authorization: `Bearer ${vaibhav}` } });
    expect(file.statusCode).toBe(200);
    expect(file.headers['content-type']).toBe('application/pdf');
    expect(file.rawPayload.subarray(0, 4).toString('latin1')).toBe('%PDF');
    const meds = await t.req(vaibhav, 'GET', `/medications?patientId=${ramesh}&active=true`);
    const azi = meds.body.items.find((m: any) => m.name === 'Azithromycin 500mg');
    expect(azi).toMatchObject({ dose: '1 tablet', frequency: 'Once daily', times: ['09:00'], source: 'clinician_verified', prescribedByName: 'Dr. Ananya Rao', startDate: istDate(), endDate: addDays(istDate(), 2) });
    const ep = await t.req(vaibhav, 'GET', `/care-episodes/${(await t.req(vaibhav, 'GET', `/appointments/${apptId}`)).body.careEpisodeId}`);
    expect(ep.body.events.map((e: any) => e.type)).toContain('prescription_issued');
    expect((await t.req(vaibhav, 'GET', '/notifications')).body.items.some((n: any) => n.title === 'New prescription')).toBe(true);
  });

  it('read access: patient, family with view_records and linked doctors; not strangers', async () => {
    expect((await t.req(vaibhav, 'GET', `/prescriptions?patientId=${ramesh}`)).body.items.map((p: any) => p.id)).toContain(rxId);
    expect((await t.req(lakshmi, 'GET', `/prescriptions/${rxId}`)).status).toBe(200);
    expect((await t.req(ananya, 'GET', `/prescriptions/${rxId}`)).status).toBe(200);
    expect((await t.req(karthik, 'GET', `/prescriptions/${rxId}`)).status).toBe(403);
    const stranger = (await t.login('+919877700001')).accessToken;
    expect((await t.req(stranger, 'GET', `/prescriptions?patientId=${ramesh}`)).status).toBe(403);
    expect((await t.req(stranger, 'GET', `/prescriptions/${rxId}/pdf`)).status).toBe(403);
    // The seeded prescription exists too.
    expect((await t.req(vaibhav, 'GET', `/prescriptions?patientId=${ramesh}`)).body.items.length).toBeGreaterThanOrEqual(2);
  });

  it('pharmacy match and ordering Rx items with prescriptionId', async () => {
    const m = await t.req(vaibhav, 'GET', `/prescriptions/${rxId}/pharmacy-match`);
    expect(m.status).toBe(200);
    expect(m.body.items.map((i: any) => [i.itemIndex, i.drugName, i.product?.name ?? null])).toEqual([
      [0, 'Azithromycin', 'Azithromycin 500mg'],
      [1, 'Paracetamol', 'Paracetamol 500mg'],
      [2, 'Honey-lemon lozenge', null],
    ]);
    const azi = m.body.items[0].product;
    const address = { line1: 'Flat 302', city: 'Hyderabad', pincode: '500034' };
    const no = await t.req(vaibhav, 'POST', '/pharmacy/orders', { patientId: ramesh, items: [{ productId: azi.id, qty: 1 }], address }, idem());
    expect(no.status).toBe(400);
    const yes = await t.req(vaibhav, 'POST', '/pharmacy/orders', { patientId: ramesh, items: [{ productId: azi.id, qty: 1 }], prescriptionId: rxId, address }, idem());
    expect(yes.status).toBe(201);
    const self = (await t.req(vaibhav, 'GET', '/patients')).body.items.find((p: any) => p.isSelf).id;
    const wrong = await t.req(vaibhav, 'POST', '/pharmacy/orders', { patientId: self, items: [{ productId: azi.id, qty: 1 }], prescriptionId: rxId, address }, idem());
    expect(wrong.status).toBe(400);
  });
});

describe('invoices (section 32)', () => {
  it('paid payments get a sequential FY invoice (JSON + PDF); unpaid -> CONFLICT', async () => {
    const { payment } = await bookConfirmed();
    const inv = await t.req(vaibhav, 'GET', `/payments/${payment.id}/invoice`);
    expect(inv.status).toBe(200);
    expect(inv.body.number).toMatch(new RegExp(`^CC/${indianFy(new Date())}/\\d{6}$`));
    expect(inv.body).toMatchObject({
      paymentId: payment.id,
      billedTo: { name: 'Vaibhav Kumar', phone: SEED_PHONES.vaibhav },
      seller: { legalName: t.svc.config.SELLER_LEGAL_NAME, gstin: null },
      subtotal: 499,
      tax: 0,
      total: 499,
      refundedAmount: 0,
      currency: 'INR',
    });
    expect(inv.body.lines[0]).toMatchObject({ amount: 499, taxRate: 0, taxAmount: 0, sacCode: '999312' });
    expect(inv.body.lines[0].description).toMatch(/^Video consultation with Dr\. Ananya Rao/);
    const again = await t.req(vaibhav, 'GET', `/payments/${payment.id}/invoice`);
    expect(again.body.number).toBe(inv.body.number);
    const pdf = await t.app.inject({ method: 'GET', url: `/api/v1/payments/${payment.id}/invoice.pdf`, headers: { authorization: `Bearer ${vaibhav}` } });
    expect(pdf.statusCode).toBe(200);
    expect(pdf.rawPayload.subarray(0, 4).toString('latin1')).toBe('%PDF');
    const slot = await firstAvailableSlot(t, vaibhav, doctorId, skip++);
    const pending = await t.req(vaibhav, 'POST', '/appointments', { patientId: ramesh, doctorId, slotId: slot.id, mode: 'video', reason: 'x' }, idem());
    const c = await t.req(vaibhav, 'GET', `/payments/${pending.body.payment.id}/invoice`);
    expect(c.status).toBe(409);
    expect((await t.req(lakshmi, 'GET', `/payments/${payment.id}/invoice`)).status).toBe(403);
    expect((await t.req(ops, 'GET', `/payments/${payment.id}/invoice`)).status).toBe(200);
    // B14: coordinators cannot read invoices (JSON or PDF); super_admin can.
    const meera = (await t.login(SEED_PHONES.meera)).accessToken;
    expect((await t.req(meera, 'GET', `/payments/${payment.id}/invoice`)).status).toBe(403);
    expect((await t.req(meera, 'GET', `/payments/${payment.id}/invoice.pdf`)).status).toBe(403);
    const admin = (await t.login(SEED_PHONES.admin)).accessToken;
    expect((await t.req(admin, 'GET', `/payments/${payment.id}/invoice`)).status).toBe(200);
  });

  it('numbering is gap-free and unique under concurrency', async () => {
    const ids: string[] = [];
    for (let i = 0; i < 8; i++) {
      const [p] = await t.svc.db
        .insert(payments)
        .values({ purpose: 'pharmacy_order', refId: randomUUID(), patientId: ramesh, amount: 100 + i, status: 'succeeded', gateway: 'mock', gatewayOrderId: `order_conc_${i}_${randomUUID()}` })
        .returning();
      ids.push(p.id);
    }
    const results = await Promise.all([...ids, ids[0], ids[1]].map((id) => ensureInvoice(t.svc.db, t.svc.config, id)));
    const byPayment = new Map<string, string>();
    for (const r of results) {
      if (byPayment.has(r.paymentId)) expect(byPayment.get(r.paymentId)).toBe(r.number);
      byPayment.set(r.paymentId, r.number);
    }
    const seqs = [...new Set(results.map((r) => r.seq))].sort((a, b) => a - b);
    expect(seqs).toHaveLength(8);
    expect(seqs[seqs.length - 1] - seqs[0]).toBe(7); // consecutive
    const all = await t.svc.db.select().from(invoices);
    expect(new Set(all.map((i) => i.number)).size).toBe(all.length);
    const fy = indianFy(new Date());
    expect(all.filter((i) => i.fy === fy).map((i) => i.seq).sort((a, b) => a - b)).toEqual(Array.from({ length: all.filter((i) => i.fy === fy).length }, (_, k) => k + 1));
  });

  it('indianFy switches in April (IST)', () => {
    expect(indianFy(new Date('2026-03-31T18:00:00Z'))).toBe('2025-26'); // 31 Mar 23:30 IST
    expect(indianFy(new Date('2026-03-31T18:31:00Z'))).toBe('2026-27'); // 1 Apr 00:01 IST
    expect(indianFy(new Date('2027-01-15T00:00:00Z'))).toBe('2026-27');
  });
});

describe('earnings & settlements (section 32)', () => {
  it('only completed and paid services count; payable = gross - refunds - platform fee', async () => {
    const { appointment, payment } = await bookConfirmed();
    const from = addDays(istDate(), -20);
    const to = addDays(istDate(), 20);
    const before = await t.req(ananya, 'GET', `/provider/earnings?from=${from}&to=${to}`);
    expect(before.status).toBe(200);
    expect(before.body.lines.map((l: any) => l.refId)).not.toContain(appointment.id); // confirmed, not completed
    await t.req(ananya, 'POST', `/clinician/appointments/${appointment.id}/start`);
    await t.req(ananya, 'POST', `/clinician/appointments/${appointment.id}/complete`, { notes: 'Reviewed.', outcome: 'resolved' });
    await t.req(ops, 'POST', `/payments/${payment.id}/refund`, { reason: 'Goodwill', amount: 99 });
    const e = await t.req(ananya, 'GET', `/provider/earnings?from=${from}&to=${to}`);
    expect(e.body).toMatchObject({ providerId: doctorId, providerName: 'Dr. Ananya Rao', role: 'doctor', from, to });
    const line = e.body.lines.find((l: any) => l.refId === appointment.id);
    expect(line).toMatchObject({ refType: 'appointment', amount: 499, platformFee: 80, payable: 320, description: 'Video consultation' });
    const seeded = e.body.lines.find((l: any) => l.refId !== appointment.id && l.amount === 499);
    expect(seeded).toMatchObject({ platformFee: 100, payable: 399 }); // seeded completed consultation 10 days ago
    expect(e.body.completedServices).toBe(e.body.lines.length);
    expect(e.body.grossAmount).toBe(e.body.lines.reduce((s: number, l: any) => s + l.amount, 0));
    expect(e.body.refunds).toBe(99);
    expect(e.body.payable).toBe(e.body.grossAmount - e.body.refunds - e.body.platformFee);
    expect(e.body.payable).toBe(e.body.lines.reduce((s: number, l: any) => s + l.payable, 0));
    // Pure function agrees and a different fee rate changes the maths.
    const [pure] = await computeEarnings(t.svc.db, 10, from, to, [doctorId]);
    expect(pure.lines.find((l) => l.refId === appointment.id)).toMatchObject({ platformFee: 40, payable: 360 });
  });

  it('defaults to the current IST month; field providers earn from completed paid visits', async () => {
    const sunita = (await t.login(SEED_PHONES.sunita)).accessToken;
    const e = await t.req(sunita, 'GET', `/provider/earnings?from=${addDays(istDate(), -20)}&to=${istDate()}`);
    expect(e.body).toMatchObject({ role: 'provider', providerName: 'Sunita Devi', completedServices: 1, grossAmount: 499, platformFee: 100, refunds: 0, payable: 399 });
    expect(e.body.lines[0]).toMatchObject({ refType: 'home_visit', description: 'Home visit: Vitals check at home' });
    const def = await t.req(sunita, 'GET', '/provider/earnings');
    expect(def.body.from).toBe(`${istDate().slice(0, 7)}-01`);
    expect((await t.req(sunita, 'GET', `/provider/earnings?from=${istDate()}&to=${addDays(istDate(), -1)}`)).status).toBe(400);
  });

  it('settlements JSON + CSV for ops_admin/super_admin', async () => {
    const from = addDays(istDate(), -20);
    const to = addDays(istDate(), 20);
    const s = await t.req(ops, 'GET', `/ops/settlements?from=${from}&to=${to}`);
    expect(s.status).toBe(200);
    const names = s.body.items.map((e: any) => e.providerName);
    expect(names).toEqual(expect.arrayContaining(['Dr. Ananya Rao', 'Sunita Devi']));
    expect(s.body.items.every((e: any) => e.completedServices > 0)).toBe(true);
    const csv = await t.app.inject({ method: 'GET', url: `/api/v1/ops/settlements.csv?from=${from}&to=${to}`, headers: { authorization: `Bearer ${ops}` } });
    expect(csv.statusCode).toBe(200);
    expect(csv.headers['content-type']).toContain('text/csv');
    expect(csv.headers['content-disposition']).toMatch(/^attachment; filename="settlements-/);
    const lines = csv.body.trim().split('\n');
    expect(lines[0]).toBe('providerId,providerName,role,from,to,completedServices,grossAmount,platformFee,refunds,payable');
    expect(lines.length).toBe(s.body.items.length + 1);
    const meera = (await t.login(SEED_PHONES.meera)).accessToken;
    expect((await t.req(meera, 'GET', `/ops/settlements?from=${from}&to=${to}`)).status).toBe(403);
  });
});

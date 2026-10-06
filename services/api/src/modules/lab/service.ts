import { stripGovernanceMarkers } from '../../lib/governance.js';
import { randomUUID } from 'node:crypto';
import { and, eq, inArray, lte } from 'drizzle-orm';
import type { Db, DbOrTx } from '../../db/client.js';
import { careEpisodes, homeVisits, labOrders, labTests, patients, prescriptions, providers, users } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, type Actor } from '../../lib/context.js';
import { randomDigits } from '../../lib/crypto.js';
import { PdfBuilder, pdfDate } from '../../lib/pdf.js';
import { ageFromDob, istDate, iso } from '../../lib/time.js';
import type { Services } from '../../services.js';
import { addEvent, advanceEpisode, settleEpisodeAfterBookingEnded } from '../episodes/service.js';
import { autoAssign, findZoneForPincode } from '../homevisits/service.js';
import type { PaymentEffects, PaymentRow } from '../payments/service.js';
import { storeRecord } from '../records/service.js';

/** Contract section 44: lab tests at home. */
export type LabOrderRow = typeof labOrders.$inferSelect;
export type LabTestRow = typeof labTests.$inferSelect;
export const SAMPLE_WATERMARK = 'SAMPLE REPORT — NOT A REAL RESULT';

export const toLabTest = (t: LabTestRow) => ({
  id: t.id,
  code: t.code,
  name: t.name,
  description: stripGovernanceMarkers(t.description),
  category: t.category,
  sampleType: t.sampleType,
  fastingRequired: t.fastingRequired,
  fastingHours: t.fastingHours,
  turnaroundHours: t.turnaroundHours,
  price: t.price,
  mrp: t.mrp,
  partnerName: t.partnerName,
});

export async function toLabOrders(db: DbOrTx, rows: LabOrderRow[]) {
  if (!rows.length) return [];
  const pats = await db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, [...new Set(rows.map((r) => r.patientId))]));
  const pn = new Map(pats.map((p) => [p.id, p.name]));
  return rows.map((o) => ({
    id: o.id,
    patientId: o.patientId,
    patientName: pn.get(o.patientId) ?? null,
    tests: o.tests,
    total: o.total,
    discount: o.discount,
    status: o.status,
    collectionVisitId: o.collectionVisitId,
    preferredStart: iso(o.preferredStart),
    preferredEnd: iso(o.preferredEnd),
    reportRecordId: o.reportRecordId,
    partnerName: o.partnerName,
    partnerOrderId: o.partnerOrderId,
    timeline: o.timeline,
    careEpisodeId: o.careEpisodeId,
    createdAt: iso(o.createdAt),
  }));
}

export const timelinePush = (o: LabOrderRow, status: string) => [...o.timeline, { status, at: new Date().toISOString() }];

/** Minimum-necessary lab context for the sample-collection visit (HomeVisit.labOrder). */
export async function labContextForVisits(db: DbOrTx, visitIds: string[]) {
  const m = new Map<string, { id: string; tests: Array<{ id: string; name: string; sampleType: string }>; fastingRequired: boolean; fastingHours: number | null }>();
  if (!visitIds.length) return m;
  const orders = await db.select().from(labOrders).where(inArray(labOrders.collectionVisitId, visitIds));
  if (!orders.length) return m;
  const testIds = [...new Set(orders.flatMap((o) => o.tests.map((t) => t.id)))];
  const tests = testIds.length ? await db.select().from(labTests).where(inArray(labTests.id, testIds)) : [];
  const tm = new Map(tests.map((t) => [t.id, t]));
  for (const o of orders) {
    const ts = o.tests.map((t) => tm.get(t.id)).filter((x): x is LabTestRow => !!x);
    const fasting = ts.filter((t) => t.fastingRequired);
    m.set(o.collectionVisitId!, {
      id: o.id,
      tests: o.tests.map((t) => ({ id: t.id, name: t.name, sampleType: tm.get(t.id)?.sampleType ?? 'other' })),
      fastingRequired: fasting.length > 0,
      fastingHours: fasting.length ? Math.max(...fasting.map((t) => t.fastingHours ?? 0)) : null,
    });
  }
  return m;
}

/** After payment: schedule an auto-matched `sample_collection` home visit (no separate charge). */
export function labPaymentEffects(svc: () => Services): PaymentEffects {
  return {
    async onSucceeded(db: Db, p: PaymentRow) {
      const visit = await db.transaction(async (tx) => {
        const [o] = await tx.select().from(labOrders).where(eq(labOrders.id, p.refId));
        if (!o || o.status !== 'pending_payment') return null;
        const zone = await findZoneForPincode(tx, o.address.pincode);
        const [v] = await tx
          .insert(homeVisits)
          .values({
            id: randomUUID(),
            patientId: o.patientId,
            serviceCode: 'sample_collection',
            price: 0,
            reason: `Lab sample collection: ${o.tests.map((t) => t.name).join(', ')}`.slice(0, 500),
            address: o.address,
            preferredStart: o.preferredStart,
            preferredEnd: o.preferredEnd,
            careEpisodeId: o.careEpisodeId,
            visitCode: randomDigits(4),
            zoneId: zone?.id ?? null,
            timeline: [{ status: 'requested', at: new Date().toISOString(), note: 'Lab order' }],
            createdByUserId: o.createdByUserId,
          })
          .returning();
        const assigned = await autoAssign(tx, v, SYSTEM_ACTOR);
        await tx
          .update(labOrders)
          .set({ status: 'scheduled', collectionVisitId: v.id, timeline: timelinePush(o, 'scheduled'), updatedAt: new Date() })
          .where(eq(labOrders.id, o.id));
        await addEvent(tx, o.careEpisodeId, 'lab_order_scheduled', 'Lab sample collection scheduled', SYSTEM_ACTOR, { labOrderId: o.id, homeVisitId: v.id });
        // QA B30: a paid lab order means care is scheduled (the episode no longer stays NEW).
        await advanceEpisode(tx, o.careEpisodeId, ['CARE_SCHEDULED'], 'Lab order paid; sample collection scheduled', SYSTEM_ACTOR, { nextAction: 'Home sample collection' });
        await audit(tx, SYSTEM_ACTOR, { action: 'lab_order.scheduled', entityType: 'lab_order', entityId: o.id, metadata: { homeVisitId: v.id } });
        return { order: o, visit: assigned };
      });
      if (!visit) return;
      const s = svc();
      await s.notify.notifyPatient(visit.order.patientId, { template: 'lab_scheduled', category: 'lab', deepLink: `/lab/orders/${visit.order.id}`, dedupeKey: `lab_scheduled:${visit.order.id}` });
      if (visit.visit.status === 'assigned' && visit.visit.providerId) {
        const [pr] = await db.select({ userId: providers.userId }).from(providers).where(eq(providers.id, visit.visit.providerId));
        if (pr) {
          await s.notify.notifyUsers([pr.userId], {
            template: 'home_visit_update',
            params: { status: 'assigned' },
            category: 'home_visit',
            deepLink: `/provider/visits/${visit.visit.id}`,
            dedupeKey: `hv_assigned:${visit.visit.id}:${visit.visit.providerId}`,
          });
        }
      }
    },
    async onFailed(db: Db, p: PaymentRow) {
      const [o] = await db.select().from(labOrders).where(eq(labOrders.id, p.refId));
      if (!o || o.status !== 'pending_payment') return;
      await db.transaction(async (tx) => {
        await tx.update(labOrders).set({ status: 'cancelled', cancelReason: 'payment_failed', timeline: timelinePush(o, 'cancelled'), updatedAt: new Date() }).where(eq(labOrders.id, o.id));
        await addEvent(tx, o.careEpisodeId, 'lab_order_cancelled', 'Lab order cancelled: payment failed', SYSTEM_ACTOR, { labOrderId: o.id });
        await settleEpisodeAfterBookingEnded(tx, o.careEpisodeId, 'payment_failed', SYSTEM_ACTOR);
      });
    },
    async onRetry(tx, p: PaymentRow) {
      const [o] = await tx.select().from(labOrders).where(eq(labOrders.id, p.refId));
      if (!o) throw new Error('lab order missing');
      if (o.status === 'cancelled' && o.cancelReason === 'payment_failed') {
        await tx.update(labOrders).set({ status: 'pending_payment', cancelReason: null, timeline: timelinePush(o, 'pending_payment'), updatedAt: new Date() }).where(eq(labOrders.id, o.id));
      }
    },
  };
}

/** Completing the sample-collection visit moves the order to `sample_collected` and submits it to the partner. */
export async function onCollectionVisitCompleted(svc: Services, visitId: string, actor: Actor): Promise<void> {
  const [o] = await svc.db.select().from(labOrders).where(eq(labOrders.collectionVisitId, visitId));
  if (!o || o.status !== 'scheduled') return;
  const collected = await svc.db
    .update(labOrders)
    .set({ status: 'sample_collected', timeline: timelinePush(o, 'sample_collected'), updatedAt: new Date() })
    .where(and(eq(labOrders.id, o.id), eq(labOrders.status, 'scheduled')))
    .returning();
  if (!collected.length) return;
  const tests = await svc.db.select({ code: labTests.code }).from(labTests).where(inArray(labTests.id, o.tests.map((t) => t.id)));
  try {
    const { partnerOrderId } = await svc.partners.lab.submitOrder({ orderId: o.id, testCodes: tests.map((t) => t.code), collectedAt: new Date().toISOString() });
    const patch: Partial<LabOrderRow> = { partnerOrderId, updatedAt: new Date() };
    if (svc.partners.lab.name === 'mock') {
      // The mock partner acknowledges immediately and starts processing.
      patch.status = 'processing';
      patch.processingAt = new Date();
      patch.timeline = timelinePush(collected[0], 'processing');
    }
    await svc.db.update(labOrders).set(patch).where(eq(labOrders.id, o.id));
    await audit(svc.db, actor, { action: 'lab_order.submitted', entityType: 'lab_order', entityId: o.id, metadata: { partner: svc.partners.lab.name } });
  } catch (err) {
    // Stays `sample_collected`; the worker retries submission.
    await audit(svc.db, actor, { action: 'lab_order.submit_failed', entityType: 'lab_order', entityId: o.id, outcome: 'error', metadata: { message: err instanceof Error ? err.message.slice(0, 100) : 'error' } });
  }
}

/** Deterministic "plausible" sample value inside the illustrative range (never a real result). */
function sampleValue(orderId: string, code: string, range: { low: number; high: number }): number {
  let h = 0;
  for (const ch of `${orderId}:${code}`) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  const f = (h % 1000) / 1000;
  const v = range.low + (range.high - range.low) * (0.15 + 0.7 * f);
  return Math.round(v * 10) / 10;
}

export async function renderLabReport(p: {
  order: LabOrderRow;
  patient: { name: string | null; dob: string | null; gender: string };
  partnerName: string;
  results: Array<{ name: string; value: string; unit: string; range: string }>;
  sample: boolean;
  now: Date;
}): Promise<Buffer> {
  const b = new PdfBuilder(p.sample ? 'Lab report (SAMPLE)' : 'Lab report', `Order ${p.order.id.slice(0, 8).toUpperCase()}  |  ${pdfDate(p.now)}`, { subject: 'Lab report' });
  if (p.sample) b.watermark(SAMPLE_WATERMARK);
  b.infoBoxes([
    { title: 'Patient', rows: [['Name', p.patient.name ?? 'Patient'], ['Age / Gender', `${ageFromDob(p.patient.dob) ?? '-'} / ${p.patient.gender}`], ['Collected', p.order.timeline.find((t) => t.status === 'sample_collected')?.at.slice(0, 10) ?? '-']] },
    { title: 'Laboratory', rows: [['Partner', p.partnerName], ['Partner ref.', p.order.partnerOrderId ?? '-'], ['Reported', pdfDate(p.now)]] },
  ]);
  if (p.sample) {
    b.paragraph(`${SAMPLE_WATERMARK}. This document was generated by the mock lab partner for testing. The values are synthetic and must not be used for any clinical decision.`, { bold: true, color: '#DC2626' });
  }
  b.heading('Results');
  b.table(
    [
      { header: 'Test', width: 200 },
      { header: 'Result', width: 80, align: 'right' },
      { header: 'Unit', width: 110 },
      { header: 'Reference range', width: 120 },
    ],
    p.results.map((r) => [r.name, r.value, r.unit, r.range]),
  );
  b.paragraph('Results must be interpreted by a qualified doctor together with the clinical picture.', { size: 8.5, color: '#6B7280' });
  return b.finish([p.sample ? `${SAMPLE_WATERMARK} - generated by the CareCompanion mock lab partner.` : `Report received from ${p.partnerName} via CareCompanion.`]);
}

/**
 * Attach the report to the order: `lab_report` MedicalRecord (source lab_partner), linked to the episode; the patient
 * and the linked doctor are notified.
 */
export async function completeLabOrder(svc: Services, orderId: string, report: { pdf?: Buffer; results?: Array<{ name: string; value: string; unit: string; range: string }>; sample: boolean }, actor: Actor): Promise<boolean> {
  const [o] = await svc.db.select().from(labOrders).where(eq(labOrders.id, orderId));
  if (!o || o.status === 'report_ready' || o.status === 'cancelled') return false;
  const [p] = await svc.db.select().from(patients).where(eq(patients.id, o.patientId));
  const now = new Date();
  let pdf = report.pdf;
  if (!pdf) {
    let results = report.results;
    if (!results) {
      const tests = await svc.db.select().from(labTests).where(inArray(labTests.id, o.tests.map((t) => t.id)));
      results = tests.map((t) =>
        t.sampleRange
          ? { name: t.name, value: String(sampleValue(o.id, t.code, t.sampleRange)), unit: t.sampleRange.unit, range: `${t.sampleRange.low} - ${t.sampleRange.high}` }
          : { name: t.name, value: 'Within normal limits (sample)', unit: '-', range: '-' },
      );
    }
    pdf = await renderLabReport({ order: o, patient: { name: p?.name ?? null, dob: p?.dob ?? null, gender: p?.gender ?? 'other' }, partnerName: o.partnerName, results, sample: report.sample, now });
  }
  const done = await svc.db.transaction(async (tx) => {
    const [claimed] = await tx
      .update(labOrders)
      .set({ status: 'report_ready', timeline: timelinePush(o, 'report_ready'), updatedAt: now })
      .where(and(eq(labOrders.id, o.id), inArray(labOrders.status, ['scheduled', 'sample_collected', 'processing'])))
      .returning();
    if (!claimed) return null;
    const rec = await storeRecord(tx, svc.storage, {
      patientId: o.patientId,
      type: 'lab_report',
      title: `${report.sample ? 'SAMPLE ' : ''}Lab report - ${o.tests.map((t) => t.name).join(', ')}`.slice(0, 200),
      recordDate: istDate(now),
      source: 'lab_partner',
      uploadedByUserId: null,
      uploadedByName: o.partnerName,
      fileName: `lab-report-${o.id.slice(0, 8)}.pdf`,
      mimeType: 'application/pdf',
      data: pdf!,
    });
    await tx.update(labOrders).set({ reportRecordId: rec.id }).where(eq(labOrders.id, o.id));
    await addEvent(tx, o.careEpisodeId, 'lab_report_ready', 'Lab report received and added to records', actor, { labOrderId: o.id, recordId: rec.id });
    await audit(tx, actor, { action: 'lab_order.report_ready', entityType: 'lab_order', entityId: o.id, metadata: { recordId: rec.id, sample: report.sample } });
    return rec;
  });
  if (!done) return false;
  await svc.notify.notifyPatient(o.patientId, { template: 'lab_report_ready', category: 'lab', deepLink: `/records/${done.id}`, dedupeKey: `lab_report:${o.id}` });
  // The linked doctor: the prescribing doctor, else the episode's owner.
  const doctorUsers = new Set<string>();
  if (o.prescriptionId) {
    const [rx] = await svc.db.select({ userId: providers.userId }).from(prescriptions).innerJoin(providers, eq(providers.id, prescriptions.doctorId)).where(eq(prescriptions.id, o.prescriptionId));
    if (rx) doctorUsers.add(rx.userId);
  }
  const [ep] = await svc.db.select({ owner: careEpisodes.ownerUserId }).from(careEpisodes).where(eq(careEpisodes.id, o.careEpisodeId));
  if (ep?.owner) {
    const [u] = await svc.db.select({ roles: users.roles }).from(users).where(eq(users.id, ep.owner));
    if (u?.roles.includes('doctor')) doctorUsers.add(ep.owner);
  }
  if (doctorUsers.size) {
    await svc.notify.notifyUsers([...doctorUsers], { template: 'lab_report_ready', category: 'lab', deepLink: `/clinician/patients/${o.patientId}`, dedupeKey: `lab_report_doctor:${o.id}` });
  }
  return true;
}

/**
 * Worker: drive the mock partner (processing -> report_ready after LAB_MOCK_REPORT_MINUTES with a watermarked SAMPLE
 * report) and retry submissions that failed.
 */
export async function labLifecycle(svc: Services, now: Date): Promise<number> {
  let n = 0;
  const stuck = await svc.db.select().from(labOrders).where(eq(labOrders.status, 'sample_collected'));
  for (const o of stuck) {
    if (o.partnerOrderId) continue;
    if (o.collectionVisitId) {
      await svc.db.update(labOrders).set({ status: 'scheduled' }).where(and(eq(labOrders.id, o.id), eq(labOrders.status, 'sample_collected')));
      await onCollectionVisitCompleted(svc, o.collectionVisitId, SYSTEM_ACTOR);
      n++;
    }
  }
  if (svc.partners.lab.name !== 'mock') return n;
  const cutoff = new Date(now.getTime() - svc.config.LAB_MOCK_REPORT_MINUTES * 60_000);
  const due = await svc.db.select().from(labOrders).where(and(eq(labOrders.status, 'processing'), lte(labOrders.processingAt, cutoff)));
  for (const o of due) {
    if (await completeLabOrder(svc, o.id, { sample: true }, { ...SYSTEM_ACTOR, name: 'mock-lab-partner' })) n++;
  }
  return n;
}

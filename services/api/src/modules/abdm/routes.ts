import { and, desc, eq, lte } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { abdmConsentRequests, abdmTransactions, patients } from '../../db/schema.js';
import { assertCanActForPatient, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, type Actor } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { PdfBuilder, pdfDate } from '../../lib/pdf.js';
import { istDate, iso } from '../../lib/time.js';
import { parse, zDate, zPhone, zUuid } from '../../lib/validate.js';
import { firstDelivery, parseJsonBuffer, rawBodyParsers, verifyHmacHeader } from '../../lib/webhooks.js';
import type { Services } from '../../services.js';
import { storeRecord } from '../records/service.js';
import { normaliseAbhaAddress, normaliseAbhaNumber } from './gateway.js';

/** Contract section 50: ABDM (ABHA creation, record linking, consent) behind a mock/sandbox/production gateway. */
type ConsentRow = typeof abdmConsentRequests.$inferSelect;
const HI_TYPES = ['Prescription', 'DiagnosticReport', 'DischargeSummary', 'OPConsultation'] as const;
const READ: Perm[] = ['view_records', 'manage_care', 'staff_ops'];
const TXN_TTL_MIN = 10;

export const toConsentRequest = (c: ConsentRow) => ({
  id: c.id,
  patientId: c.patientId,
  hiTypes: c.hiTypes,
  from: c.fromDate,
  to: c.toDate,
  status: c.status,
  recordsImported: c.recordsImported,
  createdAt: iso(c.createdAt),
});

const HI_RECORD: Record<string, { type: string; title: string }> = {
  Prescription: { type: 'prescription', title: 'Prescription' },
  DiagnosticReport: { type: 'lab_report', title: 'Diagnostic report' },
  DischargeSummary: { type: 'discharge_summary', title: 'Discharge summary' },
  OPConsultation: { type: 'visit_summary', title: 'OP consultation' },
};

async function importedPdf(title: string, hiType: string, sample: boolean): Promise<Buffer> {
  const b = new PdfBuilder(title, `Imported via ABDM${sample ? ' (sample)' : ''}`, { subject: title });
  if (sample) b.watermark('SAMPLE RECORD — NOT A REAL RESULT');
  b.paragraph(`Health information type: ${hiType}`);
  b.paragraph(sample ? 'This is a synthetic record imported by the mock ABDM gateway for testing.' : 'Record received through the ABDM health information exchange.');
  return b.finish([`Imported via ABDM on ${pdfDate(new Date())}.`]);
}

/** Import records for a granted consent (mock: 2 sample records). */
export async function importConsentData(svc: Services, c: ConsentRow, records: Array<{ hiType: string; title?: string; pdf?: Buffer }>, sample: boolean, actor: Actor): Promise<number> {
  const claimed = await svc.db
    .update(abdmConsentRequests)
    .set({ status: 'data_received', updatedAt: new Date() })
    .where(and(eq(abdmConsentRequests.id, c.id), eq(abdmConsentRequests.status, 'granted')))
    .returning();
  if (!claimed.length) return 0;
  let n = 0;
  for (const r of records) {
    const meta = HI_RECORD[r.hiType] ?? { type: 'other', title: r.hiType };
    const title = sample ? `Imported via ABDM (sample) - ${meta.title}` : (r.title ?? `Imported via ABDM - ${meta.title}`);
    await storeRecord(svc.db, svc.storage, {
      patientId: c.patientId,
      type: meta.type,
      title: title.slice(0, 200),
      recordDate: istDate(),
      source: 'imported',
      uploadedByUserId: null,
      uploadedByName: 'ABDM',
      fileName: `abdm-${meta.type}-${n + 1}.pdf`,
      mimeType: 'application/pdf',
      data: r.pdf ?? (await importedPdf(meta.title, r.hiType, sample)),
      importedVia: 'abdm',
    });
    n++;
  }
  await svc.db.update(abdmConsentRequests).set({ recordsImported: c.recordsImported + n, updatedAt: new Date() }).where(eq(abdmConsentRequests.id, c.id));
  await audit(svc.db, actor, { action: 'abdm.data_received', entityType: 'abdm_consent_request', entityId: c.id, metadata: { records: n } });
  await svc.notify.notifyPatient(c.patientId, { template: 'abdm_records', params: { count: n }, category: 'record', deepLink: '/records', dedupeKey: `abdm_records:${c.id}` });
  return n;
}

/** Mock gateway lifecycle: consent granted after ABDM_MOCK_CONSENT_SEC, then a data push with 2 sample records. */
export async function abdmMockLifecycle(svc: Services, now: Date): Promise<number> {
  if (svc.partners.abdm.mode !== 'mock') return 0;
  const cutoff = new Date(now.getTime() - svc.config.ABDM_MOCK_CONSENT_SEC * 1000);
  const due = await svc.db.select().from(abdmConsentRequests).where(and(eq(abdmConsentRequests.status, 'requested'), lte(abdmConsentRequests.createdAt, cutoff)));
  let n = 0;
  const actor = { ...SYSTEM_ACTOR, name: 'abdm-mock-gateway' };
  for (const c of due) {
    const [granted] = await svc.db
      .update(abdmConsentRequests)
      .set({ status: 'granted', grantedAt: now, updatedAt: now })
      .where(and(eq(abdmConsentRequests.id, c.id), eq(abdmConsentRequests.status, 'requested')))
      .returning();
    if (!granted) continue;
    await audit(svc.db, actor, { action: 'abdm.consent_granted', entityType: 'abdm_consent_request', entityId: c.id });
    const types = [...c.hiTypes, ...c.hiTypes].slice(0, 2);
    n += await importConsentData(svc, granted, types.map((hiType) => ({ hiType })), true, actor);
  }
  return n;
}

export async function abdmRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const gw = () => svc.partners.abdm;

  const abhaOf = async (patientId: string) => {
    const [p] = await db.select().from(patients).where(eq(patients.id, patientId));
    return { number: p.abhaNumber, address: p.abhaAddress, status: p.abhaStatus as 'unverified' | 'verified' };
  };

  app.post('/abdm/abha/create/start', async (req) => {
    const body = parse(z.object({ patientId: zUuid, method: z.literal('mobile'), mobile: zPhone }), req.body);
    await assertCanActForPatient(db, req.ctx, body.patientId, 'manage_care', 'abdm.abha_create');
    const { gatewayTxnId } = await gw().startAbhaCreation(body.mobile);
    const [row] = await db
      .insert(abdmTransactions)
      .values({ patientId: body.patientId, kind: 'create', gatewayTxnId, expiresAt: new Date(Date.now() + TXN_TTL_MIN * 60_000), createdByUserId: req.ctx.user.id })
      .returning();
    await audit(db, req.ctx.actor, { action: 'abdm.abha_create_start', entityType: 'patient', entityId: body.patientId });
    return { txnId: row.id };
  });

  app.post('/abdm/abha/link-existing/start', async (req) => {
    const body = parse(z.object({ patientId: zUuid, abhaNumber: z.string().max(40) }), req.body);
    const n = normaliseAbhaNumber(body.abhaNumber);
    if (!n) throw errors.validation('abhaNumber must have 14 digits', { field: 'abhaNumber' });
    await assertCanActForPatient(db, req.ctx, body.patientId, 'manage_care', 'abdm.abha_link');
    const { gatewayTxnId } = await gw().startLinkExisting(n);
    const [row] = await db
      .insert(abdmTransactions)
      .values({ patientId: body.patientId, kind: 'link', abhaNumber: n, gatewayTxnId, expiresAt: new Date(Date.now() + TXN_TTL_MIN * 60_000), createdByUserId: req.ctx.user.id })
      .returning();
    await audit(db, req.ctx.actor, { action: 'abdm.abha_link_start', entityType: 'patient', entityId: body.patientId });
    return { txnId: row.id };
  });

  const verify = (kind: 'create' | 'link') => async (req: { body: unknown; ctx: import('../../lib/context.js').RequestCtx }) => {
    const body = parse(z.object({ txnId: zUuid, otp: z.string().regex(/^\d{6}$/) }), req.body);
    const [txn] = await db.select().from(abdmTransactions).where(eq(abdmTransactions.id, body.txnId));
    if (!txn || txn.kind !== kind) throw errors.notFound('Transaction');
    await assertCanActForPatient(db, req.ctx, txn.patientId, 'manage_care', `abdm.abha_${kind}_verify`);
    if (txn.status !== 'otp_sent') throw errors.conflict('This transaction is already complete', { status: txn.status });
    if (txn.expiresAt < new Date()) throw errors.conflict('The OTP has expired; start again');
    if (txn.attempts >= 5) throw errors.validation('Too many incorrect attempts; start again');
    let res;
    try {
      res = await gw().verifyOtp(txn.gatewayTxnId ?? txn.id, body.otp, kind, txn.abhaNumber);
    } catch (err) {
      await db.update(abdmTransactions).set({ attempts: txn.attempts + 1 }).where(eq(abdmTransactions.id, txn.id));
      throw err;
    }
    await db.transaction(async (tx) => {
      await tx.update(abdmTransactions).set({ status: 'verified', abhaNumber: res.abhaNumber }).where(eq(abdmTransactions.id, txn.id));
      await tx
        .update(patients)
        .set({ abhaNumber: normaliseAbhaNumber(res.abhaNumber) ?? res.abhaNumber, abhaAddress: normaliseAbhaAddress(res.abhaAddress) ?? res.abhaAddress, abhaStatus: 'verified', updatedAt: new Date() })
        .where(eq(patients.id, txn.patientId));
      await audit(tx, req.ctx.actor, { action: `abdm.abha_${kind}_verified`, entityType: 'patient', entityId: txn.patientId, metadata: { mode: gw().mode } });
    });
    return abhaOf(txn.patientId);
  };
  app.post('/abdm/abha/create/verify', verify('create'));
  app.post('/abdm/abha/link-existing/verify', verify('link'));

  app.post('/abdm/consent-requests', async (req, reply) => {
    const body = parse(z.object({ patientId: zUuid, hiTypes: z.array(z.enum(HI_TYPES)).min(1).max(4), from: zDate, to: zDate, purpose: z.literal('CAREMGT') }), req.body);
    if (body.from > body.to) throw errors.validation('from must be on or before to');
    await assertCanActForPatient(db, req.ctx, body.patientId, 'manage_care', 'abdm.consent_request');
    const abha = await abhaOf(body.patientId);
    if (abha.status !== 'verified' || !abha.address) throw errors.conflict('Create or link a verified ABHA for this patient first');
    const [row] = await db
      .insert(abdmConsentRequests)
      .values({ patientId: body.patientId, hiTypes: [...new Set(body.hiTypes)], fromDate: body.from, toDate: body.to, purpose: body.purpose, createdByUserId: req.ctx.user.id })
      .returning();
    const { gatewayRequestId } = await gw().requestConsent({ consentRequestId: row.id, abhaAddress: abha.address, hiTypes: row.hiTypes, from: body.from, to: body.to, purpose: body.purpose });
    const [fresh] = await db.update(abdmConsentRequests).set({ gatewayRequestId }).where(eq(abdmConsentRequests.id, row.id)).returning();
    await audit(db, req.ctx.actor, { action: 'abdm.consent_request', entityType: 'abdm_consent_request', entityId: row.id, metadata: { hiTypes: row.hiTypes } });
    return reply.code(201).send(toConsentRequest(fresh));
  });

  app.get('/abdm/consent-requests', async (req) => {
    const q = parse(z.object({ patientId: zUuid }), req.query);
    const page = pageFromQuery(req.query);
    await assertCanActForPatient(db, req.ctx, q.patientId, READ, 'abdm.consent_list');
    // The mock gateway is also advanced on read so polling clients see progress between worker ticks.
    await abdmMockLifecycle(svc, new Date());
    const rows = await db.select().from(abdmConsentRequests).where(eq(abdmConsentRequests.patientId, q.patientId)).orderBy(desc(abdmConsentRequests.createdAt));
    return paginateArray(rows.map(toConsentRequest), page);
  });
}

/**
 * Public ABDM callback endpoint. The mock/sandbox harness signs with X-ABDM-Signature = hex(HMAC-SHA256(rawBody,
 * ABDM_WEBHOOK_SECRET)). [REQUIRES ABDM CERTIFICATION: production callbacks are authenticated with gateway tokens]
 * Payload: { eventId, type: "consent.status"|"data.push", consentRequestId, status?: "granted"|"denied"|"expired",
 *            records?: [{ hiType, title?, pdfBase64? }] }
 */
export async function abdmWebhookRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  rawBodyParsers(app);
  app.post('/webhooks/abdm', { bodyLimit: 20 * 1024 * 1024 }, async (req, reply) => {
    const actor = { ...SYSTEM_ACTOR, name: 'abdm-gateway', role: 'webhook', ip: req.ip, correlationId: req.correlationId };
    if (!Buffer.isBuffer(req.body) || !verifyHmacHeader(svc.config.ABDM_WEBHOOK_SECRET, req.body, req.headers['x-abdm-signature'])) {
      await audit(svc.db, actor, { action: 'abdm.webhook', entityType: 'webhook', outcome: 'denied', metadata: { reason: 'bad_signature' } });
      throw errors.unauthenticated('Invalid webhook signature');
    }
    const b = parse(
      z.object({
        eventId: z.string().min(1).max(200),
        type: z.enum(['consent.status', 'data.push']),
        consentRequestId: z.string().min(1).max(200),
        status: z.enum(['granted', 'denied', 'expired']).optional(),
        records: z.array(z.object({ hiType: z.string().max(40), title: z.string().max(200).optional(), pdfBase64: z.string().optional() })).max(50).optional(),
      }),
      parseJsonBuffer(req.body),
    );
    if (!(await firstDelivery(svc.db, 'abdm', b.eventId))) return reply.send({ received: true, duplicate: true });
    const byId = /^[0-9a-f-]{36}$/i.test(b.consentRequestId) ? await svc.db.select().from(abdmConsentRequests).where(eq(abdmConsentRequests.id, b.consentRequestId)) : [];
    const [c] = byId.length ? byId : await svc.db.select().from(abdmConsentRequests).where(eq(abdmConsentRequests.gatewayRequestId, b.consentRequestId));
    if (!c) return reply.send({ received: true, unknown: true });
    if (b.type === 'consent.status' && b.status && c.status === 'requested') {
      await svc.db.update(abdmConsentRequests).set({ status: b.status, grantedAt: b.status === 'granted' ? new Date() : null, updatedAt: new Date() }).where(eq(abdmConsentRequests.id, c.id));
      await audit(svc.db, actor, { action: `abdm.consent_${b.status}`, entityType: 'abdm_consent_request', entityId: c.id });
    }
    if (b.type === 'data.push') {
      const [fresh] = await svc.db.select().from(abdmConsentRequests).where(eq(abdmConsentRequests.id, c.id));
      const records = (b.records ?? []).map((r) => {
        const pdf = r.pdfBase64 ? Buffer.from(r.pdfBase64, 'base64') : undefined;
        if (pdf && pdf.subarray(0, 4).toString('latin1') !== '%PDF') throw errors.validation('pdfBase64 must be a PDF');
        return { hiType: r.hiType, title: r.title, pdf };
      });
      await importConsentData(svc, fresh, records, svc.partners.abdm.mode === 'mock', actor);
    }
    return reply.send({ received: true });
  });
}

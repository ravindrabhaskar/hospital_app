import { and, desc, eq, gte, isNull, lte } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { dataEncryptionKey } from '../../config.js';
import { insurancePolicies, insurers, medicalRecords } from '../../db/schema.js';
import { assertCanActForPatient, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR } from '../../lib/context.js';
import { encryptSecret } from '../../lib/crypto.js';
import { errors } from '../../lib/errors.js';
import { list, pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { addDays, istDate, iso } from '../../lib/time.js';
import { parse, zDate, zUuid } from '../../lib/validate.js';
import type { Services } from '../../services.js';

/** Contract section 51: insurance helper. Policy numbers are stored encrypted and returned masked. */
type PolicyRow = typeof insurancePolicies.$inferSelect;
const READ: Perm[] = ['view_records', 'manage_care', 'book', 'staff_ops'];
export const RENEWAL_DAYS = [30, 7] as const;

export const INSURERS = [
  { code: 'star_health', name: 'Star Health and Allied Insurance', type: 'private' },
  { code: 'hdfc_ergo', name: 'HDFC ERGO General Insurance', type: 'private' },
  { code: 'icici_lombard', name: 'ICICI Lombard General Insurance', type: 'private' },
  { code: 'niva_bupa', name: 'Niva Bupa Health Insurance', type: 'private' },
  { code: 'care_health', name: 'Care Health Insurance', type: 'private' },
  { code: 'aditya_birla', name: 'Aditya Birla Health Insurance', type: 'private' },
  { code: 'bajaj_allianz', name: 'Bajaj Allianz General Insurance', type: 'private' },
  { code: 'new_india', name: 'The New India Assurance', type: 'public' },
  { code: 'united_india', name: 'United India Insurance', type: 'public' },
  { code: 'oriental', name: 'The Oriental Insurance Company', type: 'public' },
  { code: 'national', name: 'National Insurance Company', type: 'public' },
  { code: 'pmjay', name: 'Ayushman Bharat PM-JAY', type: 'government' },
  { code: 'cghs', name: 'Central Government Health Scheme (CGHS)', type: 'government' },
  { code: 'aarogyasri', name: 'Aarogyasri (Telangana)', type: 'government' },
] as const;

export const CLAIM_CHECKLISTS = {
  cashless: {
    steps: [
      'Check that the hospital is in your insurer or TPA network for cashless treatment.',
      'Show your health card and photo ID at the hospital insurance (TPA) desk on admission.',
      'The hospital sends a pre-authorisation request to the insurer/TPA; planned admissions should be informed in advance as your policy requires.',
      'Keep your phone reachable: the TPA may ask for more documents.',
      'At discharge, review the final bill; pay any non-covered items and co-payments directly.',
      'Keep copies of the discharge summary and all bills.',
    ],
    documents: ['Health insurance card / e-card', 'Photo ID (for example Aadhaar)', 'Policy number', "Doctor's admission advice", 'Pre-authorisation form (the hospital helps with this)'],
  },
  reimbursement: {
    steps: [
      'Inform your insurer/TPA about the hospitalisation within the time your policy specifies.',
      'Pay the hospital and collect original bills, receipts and reports.',
      'Fill in the claim form from your insurer or TPA website.',
      'Submit the claim form with all originals within the policy deadline.',
      'Track the claim with the claim number and answer any queries quickly.',
    ],
    documents: ['Claim form (signed)', 'Original hospital bills and payment receipts', 'Discharge summary', 'Investigation reports', 'Prescriptions and pharmacy bills', 'Photo ID and cancelled cheque / bank details'],
  },
};
export const CLAIM_DISCLAIMER =
  'General guidance only [REQUIRES CONTENT REVIEW]. Your policy wording and your insurer or TPA decide what is covered and which documents are needed. CareCompanion does not process claims.';

const mask = (last4: string) => `XXXX${last4}`;

export function policyStatus(p: Pick<PolicyRow, 'validTo'>, today = istDate()): 'active' | 'expiring_soon' | 'expired' {
  if (p.validTo < today) return 'expired';
  if (p.validTo <= addDays(today, 30)) return 'expiring_soon';
  return 'active';
}

const toPolicy = (p: PolicyRow, insurerName: string | null) => ({
  id: p.id,
  patientId: p.patientId,
  insurerCode: p.insurerCode,
  insurerName: insurerName ?? p.insurerCode,
  policyNumberMasked: mask(p.policyNumberLast4),
  planName: p.planName,
  type: p.type,
  sumInsured: p.sumInsured,
  validFrom: p.validFrom,
  validTo: p.validTo,
  tpaName: p.tpaName,
  cardRecordId: p.cardRecordId,
  membersCovered: p.membersCovered,
  status: policyStatus(p),
  createdAt: iso(p.createdAt),
});

/** Worker: renewal reminders 30 and 7 days before validTo (deduplicated per policy and offset). */
export async function insuranceRenewals(svc: Services, now: Date): Promise<number> {
  const today = istDate(now);
  let n = 0;
  for (const days of RENEWAL_DAYS) {
    const target = addDays(today, days);
    const due = await svc.db
      .select()
      .from(insurancePolicies)
      .where(and(isNull(insurancePolicies.deletedAt), gte(insurancePolicies.validTo, today), lte(insurancePolicies.validTo, target)));
    for (const p of due) {
      // The 30-day reminder only while more than 7 days remain; the 7-day reminder in the last week.
      const remaining = Math.round((new Date(`${p.validTo}T00:00:00Z`).getTime() - new Date(`${today}T00:00:00Z`).getTime()) / 86400_000);
      if (days === 30 && remaining <= 7) continue;
      await svc.notify.notifyPatient(p.patientId, {
        template: 'insurance_renewal',
        params: { days: remaining, date: p.validTo },
        category: 'insurance',
        deepLink: `/patients/${p.patientId}/insurance-policies`,
        dedupeKey: `insurance_renewal:${p.id}:${p.validTo}:${days}`,
      });
      n++;
    }
  }
  if (n) await audit(svc.db, SYSTEM_ACTOR, { action: 'insurance.renewal_reminders', entityType: 'job', metadata: { count: n } });
  return n;
}

const zPolicy = z.object({
  insurerCode: z.string().min(1).max(40),
  policyNumber: z.string().trim().min(4).max(40),
  planName: z.string().trim().max(100).optional(),
  type: z.enum(['individual', 'family_floater', 'corporate', 'government']),
  sumInsured: z.number().int().min(0).max(1_000_000_000).optional(),
  validFrom: zDate,
  validTo: zDate,
  tpaName: z.string().trim().max(100).optional(),
  cardRecordId: zUuid.optional(),
  membersCovered: z.array(z.string().trim().min(1).max(100)).max(20).optional(),
});

export async function insuranceRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const key = dataEncryptionKey(svc.config);
  const insurerName = async (code: string) => (await db.select({ name: insurers.name }).from(insurers).where(eq(insurers.code, code)))[0]?.name ?? null;

  app.get('/insurance/insurers', async () => {
    const rows = await db.select().from(insurers).orderBy(insurers.name);
    return list(rows.map((r) => ({ code: r.code, name: r.name, type: r.type })));
  });

  app.get('/insurance/claim-checklist', async (req) => {
    const q = parse(z.object({ type: z.enum(['cashless', 'reimbursement']) }), req.query);
    return { ...CLAIM_CHECKLISTS[q.type], disclaimer: CLAIM_DISCLAIMER };
  });

  const validate = async (patientId: string, b: Partial<z.infer<typeof zPolicy>>) => {
    if (b.insurerCode && !(await insurerName(b.insurerCode))) throw errors.validation('Unknown insurer', { field: 'insurerCode' });
    if (b.validFrom && b.validTo && b.validTo < b.validFrom) throw errors.validation('validTo must be after validFrom');
    if (b.cardRecordId) {
      const [r] = await db.select({ patientId: medicalRecords.patientId }).from(medicalRecords).where(eq(medicalRecords.id, b.cardRecordId));
      if (!r || r.patientId !== patientId) throw errors.validation('cardRecordId must be a record of this patient', { field: 'cardRecordId' });
    }
  };

  app.get('/patients/:id/insurance-policies', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const page = pageFromQuery(req.query);
    await assertCanActForPatient(db, req.ctx, id, READ, 'insurance.list');
    const rows = await db.select().from(insurancePolicies).where(and(eq(insurancePolicies.patientId, id), isNull(insurancePolicies.deletedAt))).orderBy(desc(insurancePolicies.validTo));
    const names = new Map((await db.select().from(insurers)).map((i) => [i.code, i.name]));
    return paginateArray(rows.map((r) => toPolicy(r, names.get(r.insurerCode) ?? null)), page);
  });

  app.post('/patients/:id/insurance-policies', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(zPolicy, req.body);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'insurance.create');
    await validate(id, body);
    const [row] = await db
      .insert(insurancePolicies)
      .values({
        patientId: id,
        insurerCode: body.insurerCode,
        policyNumberEnc: encryptSecret(key, body.policyNumber),
        policyNumberLast4: body.policyNumber.slice(-4),
        planName: body.planName ?? null,
        type: body.type,
        sumInsured: body.sumInsured ?? null,
        validFrom: body.validFrom,
        validTo: body.validTo,
        tpaName: body.tpaName ?? null,
        cardRecordId: body.cardRecordId ?? null,
        membersCovered: body.membersCovered ?? [],
        createdByUserId: req.ctx.user.id,
      })
      .returning();
    await audit(db, req.ctx.actor, { action: 'insurance.create', entityType: 'insurance_policy', entityId: row.id, metadata: { patientId: id } });
    return reply.code(201).send(toPolicy(row, await insurerName(row.insurerCode)));
  });

  const load = async (patientId: string, policyId: string) => {
    const [p] = await db.select().from(insurancePolicies).where(and(eq(insurancePolicies.id, policyId), eq(insurancePolicies.patientId, patientId), isNull(insurancePolicies.deletedAt)));
    if (!p) throw errors.notFound('Insurance policy');
    return p;
  };

  app.patch('/patients/:id/insurance-policies/:policyId', async (req) => {
    const { id, policyId } = parse(z.object({ id: zUuid, policyId: zUuid }), req.params);
    const body = parse(zPolicy.partial(), req.body);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'insurance.update');
    const p = await load(id, policyId);
    await validate(id, { ...body, validFrom: body.validFrom ?? p.validFrom, validTo: body.validTo ?? p.validTo });
    const { policyNumber, ...rest } = body;
    const [row] = await db
      .update(insurancePolicies)
      .set({ ...rest, ...(policyNumber ? { policyNumberEnc: encryptSecret(key, policyNumber), policyNumberLast4: policyNumber.slice(-4) } : {}), updatedAt: new Date() })
      .where(eq(insurancePolicies.id, policyId))
      .returning();
    await audit(db, req.ctx.actor, { action: 'insurance.update', entityType: 'insurance_policy', entityId: policyId, metadata: { fields: Object.keys(body) } });
    return toPolicy(row, await insurerName(row.insurerCode));
  });

  app.delete('/patients/:id/insurance-policies/:policyId', async (req, reply) => {
    const { id, policyId } = parse(z.object({ id: zUuid, policyId: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'insurance.delete');
    await load(id, policyId);
    await db.update(insurancePolicies).set({ deletedAt: new Date() }).where(eq(insurancePolicies.id, policyId));
    await audit(db, req.ctx.actor, { action: 'insurance.delete', entityType: 'insurance_policy', entityId: policyId });
    return reply.code(204).send();
  });
}

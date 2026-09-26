import { and, desc, eq, gt } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { medicalRecords, providers, recordShares } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { hasRole } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { t } from '../../lib/i18n.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zDate, zUuid } from '../../lib/validate.js';
import { policyCheck } from '../ai/gateway.js';
import { requireConsent } from '../consent/routes.js';
import { RECORD_TYPES, storeRecord, toRecord } from './service.js';
import { assertFileClean } from './scanner.js';
import { ALLOWED_RECORD_MIME, sniffMime } from './storage.js';
import { buildSummaryRequest, summaryInput } from './summarize.js';

export async function recordRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/records', async (req) => {
    const q = parse(z.object({ patientId: zUuid, type: z.enum(RECORD_TYPES).optional() }), req.query);
    const page = pageFromQuery(req.query);
    await assertCanActForPatient(db, req.ctx, q.patientId, 'view_records', 'record.list');
    const conds = [eq(medicalRecords.patientId, q.patientId)];
    if (q.type) conds.push(eq(medicalRecords.type, q.type));
    const rows = await db
      .select()
      .from(medicalRecords)
      .where(and(...conds))
      .orderBy(desc(medicalRecords.recordDate), desc(medicalRecords.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    await audit(db, req.ctx.actor, { action: 'record.list', entityType: 'patient', entityId: q.patientId });
    return envelope(rows.map(toRecord), page);
  });

  app.post('/records', async (req, reply) => {
    if (!req.isMultipart()) throw errors.validation('multipart/form-data is required');
    const fields: Record<string, string> = {};
    let file: { data: Buffer; fileName: string } | null = null;
    for await (const part of req.parts()) {
      if (part.type === 'file') {
        if (part.fieldname !== 'file' || file) {
          await part.toBuffer();
          continue;
        }
        file = { data: await part.toBuffer(), fileName: part.filename || 'upload' };
      } else if (typeof part.value === 'string') {
        fields[part.fieldname] = part.value;
      }
    }
    const body = parse(
      z.object({ patientId: zUuid, type: z.enum(RECORD_TYPES), title: z.string().trim().min(1).max(200), recordDate: zDate }),
      fields,
    );
    if (!file) throw errors.validation('file is required');
    await assertCanActForPatient(db, req.ctx, body.patientId, 'manage_care', 'record.upload');
    const mime = sniffMime(file.data);
    if (!mime || !(ALLOWED_RECORD_MIME as readonly string[]).includes(mime)) {
      throw errors.validation('Unsupported file type. Allowed: pdf, jpg, png, webp, heic');
    }
    await assertFileClean(svc, req.ctx.actor, file.data, file.fileName, 'record.upload'); // 422 FILE_REJECTED when infected
    const isClinician = hasRole(req.ctx.user, 'doctor');
    const row = await db.transaction(async (tx) => {
      const r = await storeRecord(tx, svc.storage, {
        patientId: body.patientId,
        type: body.type,
        title: body.title,
        recordDate: body.recordDate,
        source: isClinician ? 'clinician_verified' : 'patient_entered',
        uploadedByUserId: req.ctx.user.id,
        uploadedByName: req.ctx.user.name,
        fileName: file!.fileName,
        mimeType: mime,
        data: file!.data,
      });
      await audit(tx, req.ctx.actor, { action: 'record.upload', entityType: 'medical_record', entityId: r.id, metadata: { patientId: body.patientId, mime, size: r.sizeBytes } });
      return r;
    });
    return reply.code(201).send(toRecord(row));
  });

  const load = async (id: string) => {
    const [r] = await db.select().from(medicalRecords).where(eq(medicalRecords.id, id));
    if (!r) throw errors.notFound('Record');
    return r;
  };

  app.get('/records/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const r = await load(id);
    await assertCanActForPatient(db, req.ctx, r.patientId, 'view_records', 'record.read');
    await audit(db, req.ctx.actor, { action: 'record.read', entityType: 'medical_record', entityId: id });
    return toRecord(r);
  });

  app.get('/records/:id/file', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const r = await load(id);
    await assertCanActForPatient(db, req.ctx, r.patientId, 'view_records', 'record.download');
    if (!r.storageKey) throw errors.notFound('File');
    const data = await svc.storage.getStream(r.storageKey);
    await audit(db, req.ctx.actor, { action: 'record.download', entityType: 'medical_record', entityId: id });
    return reply
      .header('content-type', r.mimeType)
      .header('content-length', String(r.sizeBytes))
      .header('content-disposition', `inline; filename="${r.fileName.replace(/["\r\n]/g, '')}"`)
      .header('cache-control', 'private, no-store')
      .header('x-content-type-options', 'nosniff')
      .send(data);
  });

  app.post('/records/:id/summarize', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const r = await load(id);
    await assertCanActForPatient(db, req.ctx, r.patientId, 'view_records', 'record.summarize');
    await requireConsent(db, req.ctx.user.id, 'ai_assistance');
    await svc.flags.require('ai_assistant');
    // Read-only access to the original: the stored bytes and their sha256 are never modified.
    const data = r.storageKey && svc.ai.isLlm ? await svc.storage.get(r.storageKey) : null;
    const input = await summaryInput(r, data, svc.ai.supportsVision);
    const typeLabel = r.type.replace('_', ' ');
    const fallbackText =
      `This is a ${typeLabel} titled "${r.title}" dated ${r.recordDate}` +
      (r.uploadedByName ? `, added by ${r.uploadedByName}` : '') +
      '. Automated reading of the document contents is not enabled for this file type. Please review the original document with your doctor.';
    const res = await svc.ai.complete(buildSummaryRequest(r, input, fallbackText), {
      useCase: 'record_summary',
      userId: req.ctx.user.id,
      patientId: r.patientId,
      safetyLevel: 'none',
      rulePackVersion: 'n/a',
    });
    const text = policyCheck(res.text).ok ? res.text : fallbackText;
    const aiSummary = { text, model: res.model, generatedAt: new Date().toISOString(), disclaimer: t(req.ctx.lang, 'ai.disclaimer') };
    // The AI summary is stored separately; the original file and its hash are never modified.
    const [row] = await db.update(medicalRecords).set({ aiSummary }).where(eq(medicalRecords.id, id)).returning();
    await audit(db, req.ctx.actor, {
      action: 'record.summarize',
      entityType: 'medical_record',
      entityId: id,
      metadata: { interactionId: res.interactionId, input: input.kind },
    });
    return toRecord(row);
  });

  app.post('/records/:id/share', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ doctorId: zUuid, expiresInDays: z.number().int().min(1).max(90) }), req.body);
    const r = await load(id);
    await assertCanActForPatient(db, req.ctx, r.patientId, 'manage_care', 'record.share');
    const [doc] = await db.select().from(providers).where(and(eq(providers.id, body.doctorId), eq(providers.kind, 'doctor'), gt(providers.credentialExpiresAt, new Date())));
    if (!doc || doc.verificationStatus !== 'verified') throw errors.notFound('Doctor');
    const [share] = await db
      .insert(recordShares)
      .values({ recordId: id, doctorId: body.doctorId, expiresAt: new Date(Date.now() + body.expiresInDays * 86400_000), createdByUserId: req.ctx.user.id })
      .returning();
    await audit(db, req.ctx.actor, { action: 'record.share', entityType: 'medical_record', entityId: id, metadata: { doctorId: body.doctorId, days: body.expiresInDays } });
    return reply.code(201).send({ id: share.id, recordId: id, doctorId: body.doctorId, expiresAt: iso(share.expiresAt) });
  });
}

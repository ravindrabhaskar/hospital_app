import { desc, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { woundCases } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { istDate, iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { assertFileClean } from '../records/scanner.js';
import { storeRecord } from '../records/service.js';
import { imageDimensions, sniffMime } from '../records/storage.js';

const MIN_BYTES = 20 * 1024;
const MIN_DIMENSION = 480;
const IMAGE_MIME = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];

export const toWound = (w: typeof woundCases.$inferSelect) => ({
  id: w.id,
  patientId: w.patientId,
  bodySite: w.bodySite,
  note: w.note,
  status: w.status,
  quality: w.quality,
  clinicianReview: w.clinicianReview ?? null,
  imageRecordId: w.imageRecordId,
  createdAt: iso(w.createdAt),
});

/** Image-quality checks ONLY. No clinical analysis (wound_ai_analysis flag stays off until a validated model is approved). */
export function checkImageQuality(data: Buffer, mime: string): { acceptable: boolean; issues: string[] } {
  const issues: string[] = [];
  if (data.length < MIN_BYTES) issues.push('file_too_small');
  const dims = imageDimensions(data, mime);
  if (dims && (dims.width < MIN_DIMENSION || dims.height < MIN_DIMENSION)) issues.push('image_too_small');
  return { acceptable: issues.length === 0, issues };
}

export async function woundRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.post('/wound-cases', async (req, reply) => {
    if (!req.isMultipart()) throw errors.validation('multipart/form-data is required');
    const fields: Record<string, string> = {};
    let image: { data: Buffer; fileName: string } | null = null;
    for await (const part of req.parts()) {
      if (part.type === 'file') {
        const data = await part.toBuffer();
        if (part.fieldname === 'image' && !image) image = { data, fileName: part.filename || 'wound.jpg' };
      } else if (typeof part.value === 'string') fields[part.fieldname] = part.value;
    }
    const body = parse(z.object({ patientId: zUuid, bodySite: z.string().trim().min(1).max(100), note: z.string().max(1000).optional() }), fields);
    if (!image) throw errors.validation('image is required');
    await assertCanActForPatient(db, req.ctx, body.patientId, 'manage_care', 'wound.create');
    const mime = sniffMime(image.data);
    if (!mime || !IMAGE_MIME.includes(mime)) throw errors.validation('Unsupported image type. Allowed: jpg, png, webp, heic');
    await assertFileClean(svc, req.ctx.actor, image.data, image.fileName, 'wound.upload');
    const quality = checkImageQuality(image.data, mime);
    const row = await db.transaction(async (tx) => {
      const rec = await storeRecord(tx, svc.storage, {
        patientId: body.patientId,
        type: 'other',
        title: `Wound photo - ${body.bodySite}`,
        recordDate: istDate(),
        source: 'patient_entered',
        uploadedByUserId: req.ctx.user.id,
        uploadedByName: req.ctx.user.name,
        fileName: image!.fileName,
        mimeType: mime,
        data: image!.data,
      });
      const [w] = await tx
        .insert(woundCases)
        .values({
          patientId: body.patientId,
          bodySite: body.bodySite,
          note: body.note ?? null,
          status: quality.acceptable ? 'pending_clinician_review' : 'retake_required',
          quality,
          imageRecordId: rec.id,
        })
        .returning();
      await audit(tx, req.ctx.actor, { action: 'wound.create', entityType: 'wound_case', entityId: w.id, metadata: { acceptable: quality.acceptable } });
      return w;
    });
    return reply.code(201).send(toWound(row));
  });

  app.get('/wound-cases', async (req) => {
    const q = parse(z.object({ patientId: zUuid }), req.query);
    const page = pageFromQuery(req.query);
    await assertCanActForPatient(db, req.ctx, q.patientId, ['manage_care', 'view_records'], 'wound.list');
    const rows = await db
      .select()
      .from(woundCases)
      .where(eq(woundCases.patientId, q.patientId))
      .orderBy(desc(woundCases.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toWound), page);
  });

  app.get('/wound-cases/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [w] = await db.select().from(woundCases).where(eq(woundCases.id, id));
    if (!w) throw errors.notFound('Wound case');
    await assertCanActForPatient(db, req.ctx, w.patientId, ['manage_care', 'view_records'], 'wound.read');
    return toWound(w);
  });

  app.post('/wound-cases/:id/review', { preHandler: requireRoles(svc, 'doctor') }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ notes: z.string().trim().min(1).max(4000) }), req.body);
    const [w] = await db.select().from(woundCases).where(eq(woundCases.id, id));
    if (!w) throw errors.notFound('Wound case');
    await assertCanActForPatient(db, req.ctx, w.patientId, 'manage_care', 'wound.review');
    const [row] = await db
      .update(woundCases)
      .set({ status: 'reviewed', clinicianReview: { reviewerName: req.ctx.user.name ?? 'Clinician', notes: body.notes, reviewedAt: new Date().toISOString() } })
      .where(eq(woundCases.id, id))
      .returning();
    await audit(db, req.ctx.actor, { action: 'wound.review', entityType: 'wound_case', entityId: id });
    return toWound(row);
  });
}

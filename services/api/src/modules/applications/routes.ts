import { randomUUID } from 'node:crypto';
import { and, asc, desc, eq, inArray, sql } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { providerApplicationDocuments, providerApplications, providers, serviceZones, specialties, users } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { sha256 } from '../../lib/crypto.js';
import { AppError, errors } from '../../lib/errors.js';
import { assertMaxSize, extForMime, readMultipart } from '../../lib/multipart.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zIso, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { createProviderProfile } from '../admin/staff.js';
import { assertFileClean } from '../records/scanner.js';
import { sniffMime } from '../records/storage.js';

/** Contract section 30: provider & doctor onboarding applications. */
export const APPLICATION_TYPES = ['nurse', 'technician', 'intern', 'physiotherapist', 'dietitian', 'doctor'] as const;
export const DOC_TYPES = ['registration_certificate', 'degree', 'id_proof', 'experience_letter', 'other'] as const;
const DOC_MIME = ['application/pdf', 'image/jpeg', 'image/png'];
const DOC_MAX_MB = 10;
const MAX_DOCS = 12;
const EDITABLE = ['submitted', 'changes_requested'];

type AppRow = typeof providerApplications.$inferSelect;

const zFields = z.object({
  type: z.enum(APPLICATION_TYPES),
  fullName: z.string().trim().min(1).max(100),
  qualification: z.string().trim().min(1).max(200),
  registrationNumber: z.string().trim().min(1).max(60),
  registrationCouncil: z.string().trim().max(120).nullable().optional(),
  specialty: z.string().trim().max(40).nullable().optional(),
  experienceYears: z.number().int().min(0).max(70),
  languages: z.array(z.string().trim().min(1).max(40)).max(12),
  preferredZoneIds: z.array(zUuid).max(20),
});

const isUniqueViolation = (err: unknown): boolean => {
  const e = err as { code?: string; cause?: { code?: string } };
  return e?.code === '23505' || e?.cause?.code === '23505';
};

export async function toApplications(db: DbOrTx, rows: AppRow[]) {
  if (!rows.length) return [];
  const ids = rows.map((r) => r.id);
  const [docs, us] = await Promise.all([
    db.select().from(providerApplicationDocuments).where(inArray(providerApplicationDocuments.applicationId, ids)).orderBy(asc(providerApplicationDocuments.uploadedAt)),
    db.select({ id: users.id, phone: users.phone }).from(users).where(inArray(users.id, [...new Set(rows.map((r) => r.userId))])),
  ]);
  const phone = new Map(us.map((u) => [u.id, u.phone]));
  return rows.map((a) => ({
    id: a.id,
    userId: a.userId,
    phone: phone.get(a.userId) ?? '',
    fullName: a.fullName,
    type: a.type,
    qualification: a.qualification,
    registrationNumber: a.registrationNumber,
    registrationCouncil: a.registrationCouncil,
    specialty: a.specialty,
    experienceYears: a.experienceYears,
    languages: a.languages,
    preferredZoneIds: a.preferredZoneIds,
    status: a.status,
    documents: docs
      .filter((d) => d.applicationId === a.id)
      .map((d) => ({ id: d.id, docType: d.docType, fileName: d.fileName, mimeType: d.mimeType, sizeBytes: d.sizeBytes, uploadedAt: iso(d.uploadedAt) })),
    decisionNote: a.decisionNote,
    decidedByName: a.decidedByName,
    createdAt: iso(a.createdAt),
    updatedAt: iso(a.updatedAt),
    decidedAt: iso(a.decidedAt),
  }));
}

const toApplication = async (db: DbOrTx, row: AppRow) => (await toApplications(db, [row]))[0];

async function validateRefs(db: DbOrTx, f: { type: string; specialty?: string | null; preferredZoneIds: string[] }) {
  if (f.type === 'doctor') {
    if (!f.specialty) throw errors.validation('specialty is required for doctor applications', { field: 'specialty' });
    const [sp] = await db.select({ code: specialties.code }).from(specialties).where(eq(specialties.code, f.specialty));
    if (!sp) throw errors.validation('Unknown specialty code', { field: 'specialty' });
  }
  if (f.preferredZoneIds.length) {
    const zs = await db.select({ id: serviceZones.id }).from(serviceZones).where(inArray(serviceZones.id, f.preferredZoneIds));
    if (zs.length !== new Set(f.preferredZoneIds).size) throw errors.validation('Unknown service zone id', { field: 'preferredZoneIds' });
  }
}

export async function applicationRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const opsRead = requireRoles(svc, 'coordinator', 'ops_admin', 'super_admin');
  const opsAct = requireRoles(svc, 'ops_admin', 'super_admin');

  const myOpen = async (userId: string): Promise<AppRow | null> => {
    const [row] = await db
      .select()
      .from(providerApplications)
      .where(eq(providerApplications.userId, userId))
      .orderBy(desc(providerApplications.createdAt))
      .limit(1);
    return row ?? null;
  };
  const myEditable = async (req: FastifyRequest): Promise<AppRow> => {
    const row = await myOpen(req.ctx.user.id);
    if (!row) throw errors.notFound('Application');
    if (!EDITABLE.includes(row.status)) throw errors.invalidTransition(row.status, 'submitted');
    return row;
  };

  app.post('/provider-applications', async (req, reply) => {
    const body = parse(zFields, req.body);
    await validateRefs(db, body);
    const [prov] = await db.select({ id: providers.id }).from(providers).where(eq(providers.userId, req.ctx.user.id));
    if (prov) throw errors.conflict('You already have a provider profile');
    let row: AppRow;
    try {
      [row] = await db
        .insert(providerApplications)
        .values({
          userId: req.ctx.user.id,
          type: body.type,
          fullName: body.fullName,
          qualification: body.qualification,
          registrationNumber: body.registrationNumber,
          registrationCouncil: body.registrationCouncil ?? null,
          specialty: body.specialty ?? null,
          experienceYears: body.experienceYears,
          languages: [...new Set(body.languages)],
          preferredZoneIds: [...new Set(body.preferredZoneIds)],
        })
        .returning();
    } catch (err) {
      if (isUniqueViolation(err)) throw errors.conflict('You already have an open or approved application');
      throw err;
    }
    await audit(db, req.ctx.actor, { action: 'provider_application.create', entityType: 'provider_application', entityId: row.id, metadata: { type: body.type } });
    return reply.code(201).send(await toApplication(db, row));
  });

  app.get('/provider-applications/me', async (req) => {
    const row = await myOpen(req.ctx.user.id);
    if (!row) throw errors.notFound('Application');
    return toApplication(db, row);
  });

  app.patch('/provider-applications/me', async (req) => {
    const body = parse(zFields.partial(), req.body);
    const row = await myEditable(req);
    const merged = { type: body.type ?? row.type, specialty: body.specialty !== undefined ? body.specialty : row.specialty, preferredZoneIds: body.preferredZoneIds ?? row.preferredZoneIds };
    await validateRefs(db, merged);
    const [updated] = await db
      .update(providerApplications)
      .set({
        ...body,
        ...(body.languages ? { languages: [...new Set(body.languages)] } : {}),
        ...(body.preferredZoneIds ? { preferredZoneIds: [...new Set(body.preferredZoneIds)] } : {}),
        status: 'submitted',
        updatedAt: new Date(),
      })
      .where(and(eq(providerApplications.id, row.id), inArray(providerApplications.status, EDITABLE)))
      .returning();
    if (!updated) throw errors.conflict('Application changed concurrently; please retry');
    await audit(db, req.ctx.actor, { action: 'provider_application.update', entityType: 'provider_application', entityId: row.id, metadata: { fields: Object.keys(body) } });
    return toApplication(db, updated);
  });

  app.post('/provider-applications/me/documents', async (req, reply) => {
    const { fields, file } = await readMultipart(req, 'file');
    const { docType } = parse(z.object({ docType: z.enum(DOC_TYPES) }), fields);
    if (!file) throw errors.validation('file is required');
    assertMaxSize(file, DOC_MAX_MB);
    const row = await myEditable(req);
    const mime = sniffMime(file.data);
    if (!mime || !DOC_MIME.includes(mime)) throw errors.validation('Unsupported file type. Allowed: pdf, jpg, png');
    const existing = await db.select({ id: providerApplicationDocuments.id }).from(providerApplicationDocuments).where(eq(providerApplicationDocuments.applicationId, row.id));
    if (existing.length >= MAX_DOCS) throw errors.conflict(`At most ${MAX_DOCS} documents per application`);
    await assertFileClean(svc, req.ctx.actor, file.data, file.fileName, 'provider_application.document_upload');
    const id = randomUUID();
    const storageKey = `applications/${row.id}/${id}${extForMime(mime)}`;
    await svc.storage.put(storageKey, file.data, mime);
    await db.insert(providerApplicationDocuments).values({
      id,
      applicationId: row.id,
      docType,
      fileName: file.fileName.slice(0, 200),
      mimeType: mime,
      sizeBytes: file.data.length,
      storageKey,
      sha256: sha256(file.data),
    });
    await db.update(providerApplications).set({ updatedAt: new Date() }).where(eq(providerApplications.id, row.id));
    await audit(db, req.ctx.actor, { action: 'provider_application.document_upload', entityType: 'provider_application', entityId: row.id, metadata: { docType, mime } });
    return reply.code(201).send(await toApplication(db, (await myOpen(req.ctx.user.id))!));
  });

  app.delete('/provider-applications/me/documents/:docId', async (req) => {
    const { docId } = parse(z.object({ docId: zUuid }), req.params);
    const row = await myEditable(req);
    const [doc] = await db
      .delete(providerApplicationDocuments)
      .where(and(eq(providerApplicationDocuments.id, docId), eq(providerApplicationDocuments.applicationId, row.id)))
      .returning();
    if (!doc) throw errors.notFound('Document');
    await svc.storage.delete(doc.storageKey).catch(() => undefined);
    await db.update(providerApplications).set({ updatedAt: new Date() }).where(eq(providerApplications.id, row.id));
    await audit(db, req.ctx.actor, { action: 'provider_application.document_delete', entityType: 'provider_application', entityId: row.id, metadata: { docType: doc.docType } });
    return toApplication(db, (await myOpen(req.ctx.user.id))!);
  });

  // ---------------------------------------------------------------- operations review
  const load = async (id: string): Promise<AppRow> => {
    const [row] = await db.select().from(providerApplications).where(eq(providerApplications.id, id));
    if (!row) throw errors.notFound('Application');
    return row;
  };

  app.get('/ops/provider-applications', { preHandler: opsRead }, async (req) => {
    const q = parse(z.object({ status: z.enum(['submitted', 'changes_requested', 'approved', 'rejected']).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const rows = await db
      .select()
      .from(providerApplications)
      .where(q.status ? eq(providerApplications.status, q.status) : undefined)
      .orderBy(desc(providerApplications.updatedAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toApplications(db, rows), page);
  });

  app.get('/ops/provider-applications/:id', { preHandler: opsRead }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const row = await load(id);
    await audit(db, req.ctx.actor, { action: 'provider_application.read', entityType: 'provider_application', entityId: id });
    return toApplication(db, row);
  });

  app.get('/ops/provider-applications/:id/documents/:docId/file', { preHandler: opsRead }, async (req, reply) => {
    const { id, docId } = parse(z.object({ id: zUuid, docId: zUuid }), req.params);
    const [doc] = await db
      .select()
      .from(providerApplicationDocuments)
      .where(and(eq(providerApplicationDocuments.id, docId), eq(providerApplicationDocuments.applicationId, id)));
    if (!doc) throw errors.notFound('Document');
    const stream = await svc.storage.getStream(doc.storageKey);
    await audit(db, req.ctx.actor, { action: 'provider_application.document_download', entityType: 'provider_application', entityId: id, metadata: { docId } });
    return reply
      .header('content-type', doc.mimeType)
      .header('content-length', String(doc.sizeBytes))
      .header('content-disposition', `inline; filename="${doc.fileName.replace(/["\r\n]/g, '')}"`)
      .header('cache-control', 'private, no-store')
      .header('x-content-type-options', 'nosniff')
      .send(stream);
  });

  app.post('/ops/provider-applications/:id/decision', { preHandler: opsAct }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(
      z.object({
        decision: z.enum(['approve', 'reject', 'request_changes']),
        note: z.string().trim().min(1).max(2000),
        credentialExpiresAt: zIso.optional(),
        zoneIds: z.array(zUuid).max(20).optional(),
        capabilities: z.array(z.string().trim().min(1).max(40)).max(20).optional(),
      }),
      req.body,
    );
    const status = body.decision === 'approve' ? 'approved' : body.decision === 'reject' ? 'rejected' : 'changes_requested';
    const updated = await db.transaction(async (tx) => {
      await tx.execute(sql`select id from provider_applications where id = ${id} for update`);
      const [row] = await tx.select().from(providerApplications).where(eq(providerApplications.id, id));
      if (!row) throw errors.notFound('Application');
      if (!EDITABLE.includes(row.status) || (body.decision === 'request_changes' && row.status !== 'submitted')) {
        throw errors.invalidTransition(row.status, status);
      }
      let providerId: string | null = null;
      if (body.decision === 'approve') {
        if (!body.credentialExpiresAt) throw errors.validation('credentialExpiresAt is required to approve', { field: 'credentialExpiresAt' });
        const expires = new Date(body.credentialExpiresAt);
        if (expires <= new Date()) throw errors.validation('credentialExpiresAt must be in the future', { field: 'credentialExpiresAt' });
        const docs = await tx.select({ docType: providerApplicationDocuments.docType }).from(providerApplicationDocuments).where(eq(providerApplicationDocuments.applicationId, id));
        const missing = ['registration_certificate', 'id_proof'].filter((t) => !docs.some((d) => d.docType === t));
        if (missing.length) throw errors.validation('Approval requires a registration certificate and an ID proof document', { missing });
        const zoneIds = body.zoneIds ?? row.preferredZoneIds;
        if (zoneIds.length) {
          const zs = await tx.select({ id: serviceZones.id }).from(serviceZones).where(inArray(serviceZones.id, zoneIds));
          if (zs.length !== new Set(zoneIds).size) throw errors.validation('Unknown service zone id', { field: 'zoneIds' });
        }
        const isDoctor = row.type === 'doctor';
        const [u] = await tx.select().from(users).where(eq(users.id, row.userId));
        const role = isDoctor ? 'doctor' : 'provider';
        const roles = [...new Set([...u.roles, role])] as typeof u.roles;
        await tx.update(users).set({ roles, name: u.name ?? row.fullName }).where(eq(users.id, u.id));
        const prov = await createProviderProfile(tx, {
          userId: u.id,
          name: isDoctor && !/^dr\.?\s/i.test(row.fullName) ? `Dr. ${row.fullName}` : row.fullName,
          type: row.type as never,
          qualification: row.qualification,
          specialty: isDoctor ? row.specialty : null,
          registrationNumber: row.registrationNumber,
          zoneIds,
          capabilities: body.capabilities ?? [],
          credentialExpiresAt: expires,
          verificationStatus: 'verified',
          experienceYears: row.experienceYears,
          languages: row.languages,
          weekly: [],
          withDefaultFees: true,
        });
        providerId = prov.id;
        await audit(tx, req.ctx.actor, { action: 'staff.create', entityType: 'user', entityId: u.id, metadata: { roles, via: 'provider_application' } });
      }
      const [r] = await tx
        .update(providerApplications)
        .set({
          status,
          decisionNote: body.note,
          decidedByUserId: req.ctx.user.id,
          decidedByName: req.ctx.user.name,
          decidedAt: new Date(),
          updatedAt: new Date(),
          ...(providerId ? { providerId } : {}),
        })
        .where(eq(providerApplications.id, id))
        .returning();
      await audit(tx, req.ctx.actor, { action: `provider_application.${body.decision}`, entityType: 'provider_application', entityId: id, metadata: { providerId } });
      return r;
    }).catch((err) => {
      if (isUniqueViolation(err)) throw new AppError('CONFLICT', 'This user already has a provider profile');
      throw err;
    });
    await svc.notify.notifyUsers([updated.userId], {
      template: 'application_decision',
      params: { status: status.replace('_', ' ') },
      category: 'system',
      deepLink: '/provider-applications/me',
      dedupeKey: `application:${id}:${status}:${updated.updatedAt.getTime()}`,
    });
    return toApplication(db, updated);
  });
}

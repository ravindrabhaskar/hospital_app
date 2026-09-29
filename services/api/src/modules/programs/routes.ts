import { and, desc, eq, inArray } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { careEpisodes, programEnrollments, programTemplates, providers, type ProgramMetricJson, type ThresholdJson } from '../../db/schema.js';
import { assertCanActForPatient, listActablePatients, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, hasRole } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { list, pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { addDays, istDate } from '../../lib/time.js';
import { parse, zDate, zUuid, zVitalType } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { activeTemplates, programSummary, templateByCode, toEnrollments, toTemplate } from './service.js';

export const zThreshold = z.object({
  type: zVitalType,
  op: z.enum(['lt', 'gt']),
  value: z.number().finite(),
  level: z.enum(['routine', 'urgent', 'emergency']),
  message: z.string().trim().min(1).max(300),
});
const zMetric = z.object({ type: zVitalType, frequency: z.enum(['daily', 'twice_daily', 'weekly']), unit: z.string().trim().min(1).max(20) });
const READ: Perm[] = ['view_records', 'manage_care', 'receive_alerts', 'staff_ops'];

/** Contract section 42: chronic care programs. */
export async function programRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/care-programs/templates', async () => list((await activeTemplates(db, svc.config)).map(toTemplate)));

  app.post('/care-programs/enrollments', { preHandler: requireRoles(svc, 'doctor', 'coordinator') }, async (req, reply) => {
    const body = parse(
      z.object({
        patientId: zUuid,
        templateCode: z.string().min(1).max(40),
        thresholds: z.array(zThreshold).min(1).max(30).optional(),
        startDate: zDate,
        endDate: zDate.optional(),
        careEpisodeId: zUuid.optional(),
      }),
      req.body,
    );
    const isDoctor = hasRole(req.ctx.user, 'doctor') && !!req.ctx.user.providerId;
    await assertCanActForPatient(db, req.ctx, body.patientId, isDoctor ? ['manage_care', 'staff_ops'] : 'staff_ops', 'program.enroll');
    const tpl = await templateByCode(db, svc.config, body.templateCode);
    if (!tpl) throw errors.validation('Unknown or unavailable program template', { field: 'templateCode' });
    if (!isDoctor) {
      // A coordinator may only enrol with the unchanged thresholds of a clinician-approved template.
      if (body.thresholds) throw errors.forbidden('Only a doctor can set custom thresholds');
      if (tpl.status !== 'approved') throw errors.forbidden('Coordinators can only enrol with an approved template; ask a doctor');
    }
    if (body.endDate && body.endDate < body.startDate) throw errors.validation('endDate must be on or after startDate');
    if (body.careEpisodeId) {
      const [ep] = await db.select({ patientId: careEpisodes.patientId }).from(careEpisodes).where(eq(careEpisodes.id, body.careEpisodeId));
      if (!ep || ep.patientId !== body.patientId) throw errors.validation('careEpisodeId does not belong to this patient');
    }
    const [dup] = await db
      .select({ id: programEnrollments.id })
      .from(programEnrollments)
      .where(and(eq(programEnrollments.patientId, body.patientId), eq(programEnrollments.templateCode, tpl.code), inArray(programEnrollments.status, ['active', 'paused'])));
    if (dup) throw errors.conflict('The patient is already enrolled in this program', { enrollmentId: dup.id });
    let approvedByName: string | null;
    if (isDoctor) {
      const [d] = await db.select({ name: providers.name }).from(providers).where(eq(providers.id, req.ctx.user.providerId!));
      approvedByName = d?.name ?? req.ctx.user.name;
    } else {
      approvedByName = tpl.approvedBy;
    }
    const [row] = await db
      .insert(programEnrollments)
      .values({
        patientId: body.patientId,
        templateCode: tpl.code,
        templateVersion: tpl.version,
        thresholds: body.thresholds ?? tpl.defaultThresholds,
        thresholdsApprovedByUserId: isDoctor ? req.ctx.user.id : null,
        thresholdsApprovedByName: approvedByName,
        startDate: body.startDate,
        endDate: body.endDate ?? null,
        careEpisodeId: body.careEpisodeId ?? null,
        createdByUserId: req.ctx.user.id,
      })
      .returning();
    await audit(db, req.ctx.actor, {
      action: 'program.enroll',
      entityType: 'program_enrollment',
      entityId: row.id,
      metadata: { patientId: body.patientId, templateCode: tpl.code, customThresholds: !!body.thresholds },
    });
    return reply.code(201).send((await toEnrollments(db, svc.config, [row]))[0]);
  });

  app.get('/care-programs/enrollments', async (req) => {
    const q = parse(z.object({ patientId: zUuid.optional() }), req.query);
    const page = pageFromQuery(req.query);
    let ids: string[];
    if (q.patientId) {
      await assertCanActForPatient(db, req.ctx, q.patientId, READ, 'program.list');
      ids = [q.patientId];
    } else {
      ids = (await listActablePatients(db, req.ctx.user)).map((p) => p.patientId);
    }
    if (!ids.length) return { items: [], nextCursor: null };
    const rows = await db.select().from(programEnrollments).where(inArray(programEnrollments.patientId, ids)).orderBy(desc(programEnrollments.createdAt));
    return paginateArray(await toEnrollments(db, svc.config, rows), page);
  });

  const load = async (id: string) => {
    const [e] = await db.select().from(programEnrollments).where(eq(programEnrollments.id, id));
    if (!e) throw errors.notFound('Enrollment');
    return e;
  };

  app.patch('/care-programs/enrollments/:id', { preHandler: requireRoles(svc, 'doctor') }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ status: z.enum(['active', 'paused', 'completed']).optional(), thresholds: z.array(zThreshold).min(1).max(30).optional() }), req.body);
    const e = await load(id);
    await assertCanActForPatient(db, req.ctx, e.patientId, 'manage_care', 'program.update');
    if (e.status === 'completed') throw errors.invalidTransition(e.status, body.status ?? 'updated');
    const patch: Partial<typeof programEnrollments.$inferInsert> = { updatedAt: new Date() };
    if (body.status) patch.status = body.status;
    if (body.status === 'completed') patch.endDate = e.endDate ?? istDate();
    if (body.thresholds) {
      const [d] = await db.select({ name: providers.name }).from(providers).where(eq(providers.id, req.ctx.user.providerId ?? ''));
      patch.thresholds = body.thresholds;
      patch.thresholdsApprovedByUserId = req.ctx.user.id;
      patch.thresholdsApprovedByName = d?.name ?? req.ctx.user.name;
    }
    const [row] = await db.update(programEnrollments).set(patch).where(eq(programEnrollments.id, id)).returning();
    await audit(db, req.ctx.actor, { action: 'program.update', entityType: 'program_enrollment', entityId: id, metadata: { fields: Object.keys(body) } });
    return (await toEnrollments(db, svc.config, [row]))[0];
  });

  app.get('/care-programs/enrollments/:id/summary', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const q = parse(z.object({ from: zDate.optional(), to: zDate.optional() }), req.query);
    const e = await load(id);
    await assertCanActForPatient(db, req.ctx, e.patientId, READ, 'program.summary');
    const to = q.to ?? istDate();
    const from = q.from ?? addDays(to, -6);
    if (from > to) throw errors.validation('from must be on or before to');
    const [tpl] = await db.select().from(programTemplates).where(and(eq(programTemplates.code, e.templateCode), eq(programTemplates.version, e.templateVersion)));
    return programSummary(db, e, tpl ?? null, from, to);
  });

  // ---------------------------------------------------------------- admin (super_admin)
  const superOnly = requireRoles(svc, 'super_admin');

  app.get('/admin/care-programs/templates', { preHandler: superOnly }, async (req) => {
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(programTemplates).orderBy(programTemplates.code, desc(programTemplates.createdAt));
    return paginateArray(
      rows.map((t) => ({ ...toTemplate(t), active: t.active, approvedBy: t.approvedBy, approvedAt: t.approvedAt?.toISOString() ?? null })),
      page,
    );
  });

  const zTemplateFields = z.object({
    name: z.string().trim().min(1).max(100),
    description: z.string().trim().min(1).max(1000),
    metrics: z.array(zMetric).min(1).max(10),
    defaultThresholds: z.array(zThreshold).min(1).max(30),
  });

  /** Templates are versioned: a new version is always a new row (status fixture_unapproved until approved). */
  const createVersion = async (code: string, fields: { name: string; description: string; metrics: ProgramMetricJson[]; defaultThresholds: ThresholdJson[] }, requested: string | undefined, actor: typeof SYSTEM_ACTOR) => {
    const existing = await db.select({ version: programTemplates.version }).from(programTemplates).where(eq(programTemplates.code, code));
    let version = requested && !existing.some((e) => e.version === requested) ? requested : `v${existing.length + 1}`;
    for (let i = existing.length + 2; existing.some((e) => e.version === version); i++) version = `v${i}`;
    const [row] = await db.insert(programTemplates).values({ code, version, ...fields, status: 'fixture_unapproved' }).returning();
    await audit(db, actor, { action: 'program_template.version', entityType: 'program_template', entityId: row.id, metadata: { code, version } });
    return row;
  };

  app.post('/admin/care-programs/templates', { preHandler: superOnly }, async (req, reply) => {
    const body = parse(zTemplateFields.extend({ code: z.string().trim().regex(/^[a-z0-9_]{2,40}$/), version: z.string().trim().min(1).max(40).optional() }), req.body);
    const { code, version, ...fields } = body;
    return reply.code(201).send(toTemplate(await createVersion(code, fields, version, req.ctx.actor)));
  });

  app.patch('/admin/care-programs/templates/:code', { preHandler: superOnly }, async (req) => {
    const { code } = parse(z.object({ code: z.string().min(1).max(40) }), req.params);
    const body = parse(zTemplateFields.partial().extend({ version: z.string().trim().min(1).max(40).optional() }), req.body);
    const [latest] = await db.select().from(programTemplates).where(eq(programTemplates.code, code)).orderBy(desc(programTemplates.createdAt)).limit(1);
    if (!latest) throw errors.notFound('Program template');
    const { version, ...changes } = body;
    const fields = { name: latest.name, description: latest.description, metrics: latest.metrics, defaultThresholds: latest.defaultThresholds, ...changes };
    return toTemplate(await createVersion(code, fields, version, req.ctx.actor));
  });

  app.post('/admin/care-programs/templates/:code/approve', { preHandler: superOnly }, async (req) => {
    const { code } = parse(z.object({ code: z.string().min(1).max(40) }), req.params);
    const body = parse(z.object({ approverName: z.string().trim().min(2).max(100), approverRegistration: z.string().trim().min(2).max(60).optional(), version: z.string().max(40).optional() }), req.body);
    const rows = await db.select().from(programTemplates).where(eq(programTemplates.code, code)).orderBy(desc(programTemplates.createdAt));
    const tpl = body.version ? rows.find((r) => r.version === body.version) : rows[0];
    if (!tpl) throw errors.notFound('Program template');
    if (tpl.defaultThresholds.some((t) => /REQUIRES CLINICAL GOVERNANCE|FIXTURE/i.test(t.message)) || /REQUIRES CLINICAL GOVERNANCE/.test(tpl.description)) {
      throw errors.conflict('Template contains fixture content; replace it with clinician-approved thresholds and text before approval');
    }
    const [row] = await db
      .update(programTemplates)
      .set({ status: 'approved', approvedBy: `${body.approverName}${body.approverRegistration ? ` (${body.approverRegistration})` : ''}`, approvedAt: new Date() })
      .where(eq(programTemplates.id, tpl.id))
      .returning();
    await audit(db, req.ctx.actor, { action: 'program_template.approve', entityType: 'program_template', entityId: tpl.id, metadata: { code, version: tpl.version } });
    return toTemplate(row);
  });
}

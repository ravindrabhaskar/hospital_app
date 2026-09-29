import { and, count, desc, eq, gte, inArray, lte } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import type { Db, DbOrTx } from '../../db/client.js';
import {
  careEpisodes,
  carePlans,
  careTasks,
  checkinSettings,
  checkins,
  discharges,
  facilities,
  familyAccessGrants,
  medications,
  patients,
  programEnrollments,
  safetyEvents,
  users,
  type DischargeFollowUpJson,
} from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { OPS_ROLES, SYSTEM_ACTOR, hasRole } from '../../lib/context.js';
import { AppError, errors } from '../../lib/errors.js';
import { readMultipart } from '../../lib/multipart.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { addDays, istDate, istToUtc, iso } from '../../lib/time.js';
import { parse, zDate, zPhone, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import type { Services } from '../../services.js';
import { ensureUser } from '../auth/service.js';
import { assignCoordinator, pickAvailableCoordinator } from '../coordinator/routes.js';
import { tenantOfFacility } from '../enterprise/routes.js';
import { addEvent, advanceEpisode, createEpisode } from '../episodes/service.js';
import { templateByCode } from '../programs/service.js';
import { toFacility } from '../providers/routes.js';
import { storeRecord } from '../records/service.js';
import { sniffMime } from '../records/storage.js';

/** Contract section 59: hospital post-discharge programs (role hospital_staff, bound to one facility). */
type DischargeRow = typeof discharges.$inferSelect;
export const PROGRAM_DAYS = 30;

const zPatient = z.object({ name: z.string().trim().min(1).max(100), phone: zPhone, dob: zDate, gender: z.enum(['male', 'female', 'other']) });
const zFollowUp = z.object({
  tasks: z
    .array(
      z.object({
        title: z.string().trim().min(1).max(200),
        type: z.enum(['medication', 'test', 'follow_up', 'lifestyle', 'monitoring', 'general']).optional(),
        description: z.string().trim().max(1000).nullable().optional(),
        dayOffset: z.number().int().min(0).max(PROGRAM_DAYS).optional(),
      }),
    )
    .max(50),
  medications: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(100),
        dose: z.string().trim().min(1).max(60),
        frequency: z.string().trim().min(1).max(60),
        times: z.array(z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/)).max(8),
        durationDays: z.number().int().min(1).max(365).optional(),
        instructions: z.string().trim().max(300).nullable().optional(),
      }),
    )
    .max(30),
  followUpDays: z.array(z.number().int().min(1).max(PROGRAM_DAYS * 3)).max(10),
});

const jsonField = <T extends z.ZodType>(schema: T, raw: string | undefined, field: string): z.infer<T> => {
  if (!raw) throw errors.validation(`${field} is required`, { field });
  let v: unknown;
  try {
    v = JSON.parse(raw);
  } catch {
    throw errors.validation(`${field} must be JSON`, { field });
  }
  return parse(schema, v);
};

export async function toDischarges(db: DbOrTx, rows: DischargeRow[]) {
  if (!rows.length) return [];
  const facs = await db.select().from(facilities).where(inArray(facilities.id, [...new Set(rows.map((r) => r.facilityId))]));
  const fm = new Map(facs.map((f) => [f.id, f]));
  const pats = await db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, rows.map((r) => r.patientId)));
  const pn = new Map(pats.map((p) => [p.id, p.name]));
  const today = istDate();
  const out = [];
  for (const d of rows) {
    const tasks = await db.select({ status: careTasks.status }).from(careTasks).where(eq(careTasks.carePlanId, d.carePlanId));
    const [{ missed }] = await db
      .select({ missed: count() })
      .from(checkins)
      .where(and(eq(checkins.patientId, d.patientId), eq(checkins.status, 'missed'), gte(checkins.date, d.dischargeDate)));
    const [{ open }] = await db
      .select({ open: count() })
      .from(safetyEvents)
      .where(and(eq(safetyEvents.patientId, d.patientId), inArray(safetyEvents.status, ['open', 'acknowledged']), gte(safetyEvents.createdAt, istToUtc(d.dischargeDate, '00:00'))));
    const day = Math.max(0, Math.round((new Date(`${today}T00:00:00Z`).getTime() - new Date(`${d.dischargeDate}T00:00:00Z`).getTime()) / 86400_000));
    out.push({
      id: d.id,
      facility: fm.get(d.facilityId) ? toFacility(fm.get(d.facilityId)!) : null,
      patientId: d.patientId,
      patientName: pn.get(d.patientId) ?? null,
      dischargeDate: d.dischargeDate,
      diagnosisSummary: d.diagnosisSummary,
      treatingDoctorName: d.treatingDoctorName,
      status: d.status,
      careEpisodeId: d.careEpisodeId,
      carePlanId: d.carePlanId,
      enrollmentId: d.enrollmentId,
      day,
      tasksDone: tasks.filter((t) => t.status === 'done').length,
      tasksTotal: tasks.length,
      missedCheckins: Number(missed),
      openAlerts: Number(open),
      invitedPhones: d.invitedPhones,
      createdAt: iso(d.createdAt),
    });
  }
  return out;
}

/** Worker: complete 30-day programs (discharge, its program enrollment). */
export async function completeDischarges(svc: Services, now: Date): Promise<number> {
  const cutoff = addDays(istDate(now), -PROGRAM_DAYS);
  const due = await svc.db.update(discharges).set({ status: 'completed', completedAt: now, updatedAt: now }).where(and(eq(discharges.status, 'active'), lte(discharges.dischargeDate, cutoff))).returning();
  for (const d of due) {
    if (d.enrollmentId) await svc.db.update(programEnrollments).set({ status: 'completed', endDate: istDate(now), updatedAt: now }).where(and(eq(programEnrollments.id, d.enrollmentId), eq(programEnrollments.status, 'active')));
    await svc.db.update(carePlans).set({ status: 'completed' }).where(and(eq(carePlans.id, d.carePlanId), eq(carePlans.status, 'active')));
    await addEvent(svc.db, d.careEpisodeId, 'discharge_program_completed', `${PROGRAM_DAYS}-day post-discharge program completed`, SYSTEM_ACTOR, { dischargeId: d.id });
    await audit(svc.db, SYSTEM_ACTOR, { action: 'discharge.completed', entityType: 'discharge', entityId: d.id });
    await svc.notify.notifyPatient(d.patientId, { template: 'discharge_completed', category: 'care_plan', deepLink: `/care-episodes/${d.careEpisodeId}`, dedupeKey: `discharge_completed:${d.id}` });
  }
  return due.length;
}

export async function dischargeRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db: Db = svc.db;
  const staffGuard = requireRoles(svc, 'hospital_staff', 'ops_admin', 'super_admin', 'coordinator');

  const facilityOf = async (req: FastifyRequest): Promise<string | null> => {
    if (hasRole(req.ctx.user, ...OPS_ROLES)) return null; // ops see all facilities
    const [u] = await db.select({ facilityId: users.facilityId }).from(users).where(eq(users.id, req.ctx.user.id));
    if (!u?.facilityId) throw errors.forbidden('Your account is not linked to a facility');
    return u.facilityId;
  };

  app.post('/discharges', { preHandler: requireRoles(svc, 'hospital_staff') }, async (req, reply) => {
    const facilityId = await facilityOf(req);
    if (!facilityId) throw errors.forbidden('Only hospital staff linked to a facility can create discharges');
    const { fields, file } = await readMultipart(req, 'file');
    const patientIn = jsonField(zPatient, fields.patient, 'patient');
    const followUp = jsonField(zFollowUp, fields.followUp, 'followUp') as DischargeFollowUpJson;
    const meta = parse(
      z.object({
        familyPhone: zPhone.optional(),
        dischargeDate: zDate,
        diagnosisSummary: z.string().trim().min(3).max(4000),
        treatingDoctorName: z.string().trim().min(2).max(100),
        programTemplateCode: z.string().max(40).optional(),
      }),
      { ...fields, familyPhone: fields.familyPhone || undefined, programTemplateCode: fields.programTemplateCode || undefined },
    );
    if (!file) throw errors.validation('file (discharge summary PDF) is required', { field: 'file' });
    if (sniffMime(file.data) !== 'application/pdf') throw errors.validation('file must be a PDF', { field: 'file' });
    if (meta.dischargeDate > istDate()) throw errors.validation('dischargeDate cannot be in the future');
    if (meta.familyPhone && meta.familyPhone === patientIn.phone) throw errors.validation('familyPhone must differ from the patient phone');
    const scan = await svc.scanner.scan(file.data, file.fileName);
    if (!scan.clean) throw new AppError('FILE_REJECTED', 'The file was rejected by the malware scanner');
    const template = meta.programTemplateCode ? await templateByCode(db, svc.config, meta.programTemplateCode) : null;
    if (meta.programTemplateCode && !template) throw errors.validation('Unknown program template', { field: 'programTemplateCode' });
    const [facility] = await db.select().from(facilities).where(eq(facilities.id, facilityId));
    const tenant = await tenantOfFacility(db, facilityId);
    const actor = req.ctx.actor;

    const result = await db.transaction(async (tx) => {
      // 1. find or create the patient user (self profile) and the family caregiver
      const pu = await ensureUser(tx, patientIn.phone, { name: patientIn.name });
      let patientId = pu.selfPatientId;
      if (!patientId) {
        const [p] = await tx.insert(patients).values({ name: patientIn.name, phone: patientIn.phone, userId: pu.id, ownerUserId: pu.id, ownerRelation: 'self' }).returning();
        await tx.update(users).set({ selfPatientId: p.id, roles: pu.roles.includes('patient') ? pu.roles : [...pu.roles, 'patient'] }).where(eq(users.id, pu.id));
        patientId = p.id;
      }
      const [existing] = await tx.select().from(patients).where(eq(patients.id, patientId));
      await tx
        .update(patients)
        .set({ name: existing.name ?? patientIn.name, dob: existing.dob ?? patientIn.dob, gender: existing.gender === 'other' ? patientIn.gender : existing.gender, tenantCode: tenant?.code ?? existing.tenantCode, updatedAt: new Date() })
        .where(eq(patients.id, patientId));
      if (!pu.name) await tx.update(users).set({ name: patientIn.name }).where(eq(users.id, pu.id));
      const invited = [patientIn.phone];
      if (meta.familyPhone) {
        const fam = await ensureUser(tx, meta.familyPhone);
        const [g] = await tx
          .select({ id: familyAccessGrants.id })
          .from(familyAccessGrants)
          .where(and(eq(familyAccessGrants.patientId, patientId), eq(familyAccessGrants.granteeUserId, fam.id), eq(familyAccessGrants.status, 'active')));
        if (!g && fam.id !== pu.id) {
          await tx.insert(familyAccessGrants).values({ patientId, granteeUserId: fam.id, relation: 'family (hospital discharge)', permissions: ['view_records', 'manage_care', 'receive_alerts'], createdByUserId: req.ctx.user.id });
        }
        invited.push(meta.familyPhone);
      }
      // 2. episode UNDER_CARE -> FOLLOW_UP, hospital-issued care plan, tasks at day offsets, medications
      const ep = await createEpisode(tx, { patientId, title: `Post-discharge care (${facility.name})`, concern: meta.diagnosisSummary, actor });
      await advanceEpisode(tx, ep.id, ['UNDER_CARE'], 'Discharged from hospital', actor);
      await advanceEpisode(tx, ep.id, ['FOLLOW_UP'], 'Post-discharge follow-up', actor, { nextAction: 'Daily check-in and follow-up tasks' });
      await tx.update(careEpisodes).set({ tenantCode: tenant?.code ?? null }).where(eq(careEpisodes.id, ep.id));
      const at = (offset: number) => istToUtc(addDays(meta.dischargeDate, offset), '10:00');
      const lastFollowUp = followUp.followUpDays.length ? Math.min(...followUp.followUpDays) : null;
      const [plan] = await tx
        .insert(carePlans)
        .values({
          careEpisodeId: ep.id,
          patientId,
          doctorId: null,
          issuedBy: `${meta.treatingDoctorName} (Hospital-issued, ${facility.name})`,
          summary: `Hospital-issued follow-up plan: ${meta.diagnosisSummary}`.slice(0, 2000),
          instructions: `Hospital-issued by ${facility.name}. Follow the discharge summary and contact the care team if you feel unwell. In an emergency call 108.`,
          followUp: lastFollowUp ? { afterDays: lastFollowUp, mode: 'in_clinic' } : null,
          followUpDueAt: lastFollowUp ? at(lastFollowUp) : null,
        })
        .returning();
      for (const t of followUp.tasks) {
        await tx.insert(careTasks).values({ carePlanId: plan.id, patientId, type: t.type ?? 'general', title: t.title, description: t.description ?? null, dueAt: at(t.dayOffset ?? 1), owner: 'patient' });
      }
      for (const d of followUp.followUpDays) {
        await tx.insert(careTasks).values({ carePlanId: plan.id, patientId, type: 'follow_up', title: `Hospital follow-up visit (day ${d})`, description: `Follow-up at ${facility.name}`, dueAt: at(d), owner: 'patient' });
      }
      for (const m of followUp.medications) {
        await tx.insert(medications).values({
          patientId,
          carePlanId: plan.id,
          name: m.name,
          dose: m.dose,
          frequency: m.frequency,
          times: m.times,
          startDate: meta.dischargeDate,
          endDate: m.durationDays ? addDays(meta.dischargeDate, m.durationDays - 1) : null,
          instructions: m.instructions ?? null,
          source: 'imported',
          prescribedByName: meta.treatingDoctorName,
        });
      }
      await addEvent(tx, ep.id, 'care_plan_created', 'Hospital-issued care plan created', actor, { carePlanId: plan.id, facilityId });
      // 3. daily check-in for 30 days (keeps an existing window) + optional program enrollment
      const activeUntil = addDays(meta.dischargeDate, PROGRAM_DAYS);
      const [cs] = await tx.select().from(checkinSettings).where(eq(checkinSettings.patientId, patientId));
      if (!cs) {
        await tx.insert(checkinSettings).values({ patientId, enabled: true, activeUntil, updatedByUserId: req.ctx.user.id });
      } else if (!cs.enabled || cs.activeUntil) {
        await tx.update(checkinSettings).set({ enabled: true, activeUntil: cs.enabled && !cs.activeUntil ? null : activeUntil, updatedAt: new Date() }).where(eq(checkinSettings.patientId, patientId));
      }
      let enrollmentId: string | null = null;
      if (template) {
        const [en] = await tx
          .insert(programEnrollments)
          .values({
            patientId,
            templateCode: template.code,
            templateVersion: template.version,
            thresholds: template.defaultThresholds,
            thresholdsApprovedByName: `${meta.treatingDoctorName} (${facility.name})`,
            startDate: meta.dischargeDate,
            endDate: activeUntil,
            careEpisodeId: ep.id,
            createdByUserId: req.ctx.user.id,
          })
          .returning();
        enrollmentId = en.id;
      }
      // 4. the discharge summary PDF as a record (source imported)
      const rec = await storeRecord(tx, svc.storage, {
        patientId,
        type: 'discharge_summary',
        title: `Discharge summary - ${facility.name}`,
        recordDate: meta.dischargeDate,
        source: 'imported',
        uploadedByUserId: req.ctx.user.id,
        uploadedByName: facility.name,
        fileName: file.fileName.slice(0, 200) || 'discharge-summary.pdf',
        mimeType: 'application/pdf',
        data: file.data,
        importedVia: 'hospital_discharge',
      });
      // 5. coordinator
      const coordinatorId = await pickAvailableCoordinator(tx);
      if (coordinatorId) await assignCoordinator(tx, ep.id, coordinatorId, actor);
      const [row] = await tx
        .insert(discharges)
        .values({
          facilityId,
          patientId,
          dischargeDate: meta.dischargeDate,
          diagnosisSummary: meta.diagnosisSummary,
          treatingDoctorName: meta.treatingDoctorName,
          careEpisodeId: ep.id,
          carePlanId: plan.id,
          enrollmentId,
          recordId: rec.id,
          followUp,
          invitedPhones: invited,
          createdByUserId: req.ctx.user.id,
        })
        .returning();
      await audit(tx, actor, { action: 'discharge.create', entityType: 'discharge', entityId: row.id, metadata: { facilityId, patientId, program: template?.code ?? null } });
      return { row, patientId, invited };
    });
    // Invites (PHI-free SMS) and the in-app welcome.
    const appLink = `${svc.config.APP_DEEP_LINK_BASE.replace(/\/$/, '')}${tenant ? `?tenant=${tenant.code}` : ''}`;
    for (const phone of result.invited) {
      await svc.notify.smsDirect(phone, `${facility.name} has started a 30-day recovery program for you with CareCompanion. Install the app and sign in with this number: ${appLink}`, false);
    }
    await svc.notify.notifyPatient(result.patientId, { template: 'discharge_welcome', params: { hospital: facility.name }, category: 'care_plan', deepLink: `/care-episodes/${result.row.careEpisodeId}`, dedupeKey: `discharge_welcome:${result.row.id}` });
    return reply.code(201).send((await toDischarges(db, [result.row]))[0]);
  });

  app.get('/discharges', { preHandler: staffGuard }, async (req) => {
    const q = parse(z.object({ status: z.enum(['active', 'completed', 'readmitted', 'withdrawn']).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const facilityId = await facilityOf(req);
    const conds = [];
    if (facilityId) conds.push(eq(discharges.facilityId, facilityId));
    if (q.status) conds.push(eq(discharges.status, q.status));
    const rows = await db.select().from(discharges).where(conds.length ? and(...conds) : undefined).orderBy(desc(discharges.createdAt));
    return paginateArray(await toDischarges(db, rows), page);
  });

  app.get('/discharges/:id', { preHandler: staffGuard }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [d] = await db.select().from(discharges).where(eq(discharges.id, id));
    if (!d) throw errors.notFound('Discharge');
    const facilityId = await facilityOf(req);
    if (facilityId && d.facilityId !== facilityId) {
      await audit(db, req.ctx.actor, { action: 'discharge.read', entityType: 'discharge', entityId: id, outcome: 'denied' });
      throw errors.forbidden('This discharge belongs to another facility');
    }
    await audit(db, req.ctx.actor, { action: 'discharge.read', entityType: 'discharge', entityId: id });
    return (await toDischarges(db, [d]))[0];
  });
}

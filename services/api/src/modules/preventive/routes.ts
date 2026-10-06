import { stripGovernanceMarkers } from '../../lib/governance.js';
import { and, desc, eq, isNotNull } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Config } from '../../config.js';
import type { DbOrTx } from '../../db/client.js';
import { clinicalContentPacks, medicalRecords, patients, preventiveRecords } from '../../db/schema.js';
import { assertCanActForPatient, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { addDays, istDate } from '../../lib/time.js';
import { parse, zDate, zUuid } from '../../lib/validate.js';
import type { Services } from '../../services.js';
import { PREVENTIVE_FIXTURE, PREVENTIVE_PACK_VERSION, type PreventiveDef } from './fixtures.js';

/** Contract section 52: vaccination & preventive screening, computed from age and sex using a versioned schedule. */
const READ: Perm[] = ['view_records', 'manage_care', 'receive_alerts', 'staff_ops'];
const DUE_WINDOW_DAYS = 30;

const addMonths = (date: string, months: number) => addDays(date, Math.round(months * 30.4375));

export async function activeSchedule(db: DbOrTx, config: Config): Promise<{ version: string; status: 'fixture_unapproved' | 'approved'; items: PreventiveDef[] } | null> {
  const [pack] = await db.select().from(clinicalContentPacks).where(and(eq(clinicalContentPacks.kind, 'preventive'), eq(clinicalContentPacks.active, true))).limit(1);
  const status = (pack?.status ?? 'fixture_unapproved') as 'fixture_unapproved' | 'approved';
  // Production refuses unapproved clinical content.
  if (config.NODE_ENV === 'production' && status !== 'approved') return null;
  return { version: pack?.version ?? PREVENTIVE_PACK_VERSION, status, items: ((pack?.content as { items?: PreventiveDef[] } | undefined)?.items ?? PREVENTIVE_FIXTURE) };
}

export function computeItems(defs: PreventiveDef[], p: { dob: string | null; gender: string }, done: Map<string, string>, today = istDate()) {
  return defs.map((d) => {
    const lastDoneAt = done.get(d.code) ?? null;
    const base = { code: d.code, name: d.name, category: d.category, description: stripGovernanceMarkers(d.description), repeatEveryMonths: d.repeatEveryMonths, lastDoneAt };
    const sexOk = d.sex === 'any' || d.sex === p.gender;
    if (!p.dob || !sexOk) return { ...base, dueDate: null, status: 'not_applicable' as const };
    const ageMonths = (new Date(`${today}T00:00:00Z`).getTime() - new Date(`${p.dob}T00:00:00Z`).getTime()) / (30.4375 * 86400_000);
    const tooOld = d.maxAgeMonths !== null && ageMonths > d.maxAgeMonths;
    let dueDate: string;
    if (lastDoneAt) {
      if (!d.repeatEveryMonths) return { ...base, dueDate: null, status: 'done' as const };
      dueDate = addMonths(lastDoneAt, d.repeatEveryMonths);
    } else {
      if (tooOld) return { ...base, dueDate: null, status: 'not_applicable' as const };
      dueDate = addMonths(p.dob, d.dueAgeMonths ?? d.minAgeMonths);
    }
    if (tooOld && lastDoneAt) return { ...base, dueDate: null, status: 'done' as const };
    let status: 'upcoming' | 'due' | 'overdue' | 'done';
    if (dueDate > addDays(today, DUE_WINDOW_DAYS)) status = lastDoneAt ? 'done' : 'upcoming';
    else if (dueDate >= addDays(today, -DUE_WINDOW_DAYS)) status = 'due';
    else status = 'overdue';
    return { ...base, dueDate, status };
  });
}

async function doneMap(db: DbOrTx, patientId: string): Promise<Map<string, string>> {
  const rows = await db.select().from(preventiveRecords).where(eq(preventiveRecords.patientId, patientId)).orderBy(desc(preventiveRecords.doneAt));
  const m = new Map<string, string>();
  for (const r of rows) if (!m.has(r.code)) m.set(r.code, r.doneAt);
  return m;
}

/** Worker: monthly due/overdue reminders to the patient and family (deduplicated per patient and month). */
export async function preventiveReminders(svc: Services, now: Date): Promise<number> {
  const sched = await activeSchedule(svc.db, svc.config);
  if (!sched) return 0;
  const month = istDate(now).slice(0, 7);
  const rows = await svc.db.select().from(patients).where(isNotNull(patients.dob));
  let n = 0;
  for (const p of rows) {
    if (p.anonymisedAt) continue;
    const items = computeItems(sched.items, p, await doneMap(svc.db, p.id), istDate(now));
    const pending = items.filter((i) => i.status === 'due' || i.status === 'overdue');
    if (!pending.length) continue;
    await svc.notify.notifyPatient(p.id, {
      template: 'preventive_due',
      params: { count: pending.length, patient: p.name?.split(' ')[0] ?? 'your family member' },
      category: 'preventive',
      deepLink: `/patients/${p.id}/preventive-schedule`,
      dedupeKey: `preventive:${p.id}:${month}`,
    });
    n++;
  }
  return n;
}

export async function preventiveRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  const schedule = async (patientId: string) => {
    const sched = await activeSchedule(db, svc.config);
    if (!sched) throw errors.dependency('Preventive schedule unavailable: no clinician-approved schedule is active');
    const [p] = await db.select().from(patients).where(eq(patients.id, patientId));
    return { sched, items: computeItems(sched.items, p, await doneMap(db, patientId)) };
  };

  app.get('/patients/:id/preventive-schedule', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, id, READ, 'preventive.read');
    const { sched, items } = await schedule(id);
    return { items, scheduleVersion: sched.version, scheduleStatus: sched.status };
  });

  app.post('/patients/:id/preventive-records', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ code: z.string().min(1).max(60), doneAt: zDate, notes: z.string().trim().max(500).optional(), recordId: zUuid.optional() }), req.body);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'preventive.record');
    const sched = await activeSchedule(db, svc.config);
    if (!sched?.items.some((i) => i.code === body.code)) throw errors.validation('Unknown preventive item code', { field: 'code' });
    if (body.doneAt > istDate()) throw errors.validation('doneAt cannot be in the future', { field: 'doneAt' });
    if (body.recordId) {
      const [r] = await db.select({ patientId: medicalRecords.patientId }).from(medicalRecords).where(eq(medicalRecords.id, body.recordId));
      if (!r || r.patientId !== id) throw errors.validation('recordId must be a record of this patient', { field: 'recordId' });
    }
    const [row] = await db
      .insert(preventiveRecords)
      .values({ patientId: id, code: body.code, doneAt: body.doneAt, notes: body.notes ?? null, recordId: body.recordId ?? null, createdByUserId: req.ctx.user.id })
      .returning();
    await audit(db, req.ctx.actor, { action: 'preventive.record', entityType: 'preventive_record', entityId: row.id, metadata: { patientId: id, code: body.code } });
    const { items } = await schedule(id);
    return reply.code(201).send(items.find((i) => i.code === body.code));
  });
}

import { and, asc, desc, eq, gte, inArray, lt, notInArray } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { appointments, carePlans, careTasks, doseLogs, homeVisits, medications, providers } from '../../db/schema.js';
import { assertCanActForPatient, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { envelope, list, pageFromQuery } from '../../lib/pagination.js';
import { istDate, istDayBounds } from '../../lib/time.js';
import { parse, zBoolQuery, zIso, zUuid } from '../../lib/validate.js';
import { zMedicationInput } from '../careplans/routes.js';
import { toDoseLog, toMedications } from './service.js';

const READ: Perm[] = ['view_records', 'manage_care', 'receive_alerts'];

export async function medicationRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const grace = svc.config.DOSE_MISSED_GRACE_MIN;

  app.get('/medications', async (req) => {
    const q = parse(z.object({ patientId: zUuid, active: zBoolQuery.optional() }), req.query);
    const page = pageFromQuery(req.query);
    await assertCanActForPatient(db, req.ctx, q.patientId, READ, 'medication.list');
    const conds = [eq(medications.patientId, q.patientId)];
    if (q.active) conds.push(eq(medications.active, true));
    const rows = await db
      .select()
      .from(medications)
      .where(and(...conds))
      .orderBy(desc(medications.active), asc(medications.name))
      .limit(page.limit + 1)
      .offset(page.offset);
    let mapped = await toMedications(db, rows, grace);
    if (q.active) mapped = mapped.filter((m) => m.active);
    return envelope(mapped, page);
  });

  app.post('/medications', async (req, reply) => {
    const body = parse(zMedicationInput.extend({ patientId: zUuid }), req.body);
    await assertCanActForPatient(db, req.ctx, body.patientId, 'manage_care', 'medication.create');
    const [row] = await db
      .insert(medications)
      .values({
        patientId: body.patientId,
        name: body.name,
        dose: body.dose,
        frequency: body.frequency,
        times: body.times,
        startDate: body.startDate,
        endDate: body.endDate ?? null,
        instructions: body.instructions ?? null,
        source: 'patient_entered',
      })
      .returning();
    await audit(db, req.ctx.actor, { action: 'medication.create', entityType: 'medication', entityId: row.id, metadata: { patientId: body.patientId } });
    return reply.code(201).send((await toMedications(db, [row], grace))[0]);
  });

  app.post('/medications/:id/doses', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ scheduledAt: zIso, status: z.enum(['taken', 'skipped']) }), req.body);
    const [med] = await db.select().from(medications).where(eq(medications.id, id));
    if (!med) throw errors.notFound('Medication');
    await assertCanActForPatient(db, req.ctx, med.patientId, 'manage_care', 'medication.dose');
    const scheduledAt = new Date(body.scheduledAt);
    const [row] = await db
      .insert(doseLogs)
      .values({ medicationId: id, scheduledAt, status: body.status, loggedByUserId: req.ctx.user.id })
      .onConflictDoUpdate({
        target: [doseLogs.medicationId, doseLogs.scheduledAt],
        set: { status: body.status, loggedAt: new Date(), loggedByUserId: req.ctx.user.id },
      })
      .returning();
    await audit(db, req.ctx.actor, { action: 'medication.dose', entityType: 'medication', entityId: id, metadata: { status: body.status } });
    return reply.code(201).send(toDoseLog(row));
  });

  app.get('/reminders/today', async (req) => {
    const q = parse(z.object({ patientId: zUuid }), req.query);
    await assertCanActForPatient(db, req.ctx, q.patientId, READ, 'reminder.list');
    const today = istDate();
    const { start, end } = istDayBounds(today);
    const now = new Date();
    type Reminder = { id: string; kind: string; title: string; subtitle: string | null; at: string; status: 'pending' | 'done' | 'missed'; refId: string };
    const items: Reminder[] = [];

    const meds = await db.select().from(medications).where(and(eq(medications.patientId, q.patientId), eq(medications.active, true)));
    for (const m of await toMedications(db, meds, grace)) {
      for (const d of m.today) {
        items.push({
          id: `medication:${m.id}:${d.time}`,
          kind: 'medication',
          title: `${m.name} ${m.dose}`,
          subtitle: m.instructions,
          at: d.scheduledAt,
          status: d.status === 'taken' || d.status === 'skipped' ? 'done' : d.status === 'missed' ? 'missed' : 'pending',
          refId: m.id,
        });
      }
    }
    const tasks = await db
      .select()
      .from(careTasks)
      .where(and(eq(careTasks.patientId, q.patientId), gte(careTasks.dueAt, start), lt(careTasks.dueAt, end), notInArray(careTasks.status, ['cancelled'])));
    const planIds = [...new Set(tasks.map((t) => t.carePlanId))];
    const plans = planIds.length ? await db.select().from(carePlans).where(inArray(carePlans.id, planIds)) : [];
    for (const t of tasks) {
      const isFollowUp = t.type === 'follow_up' && plans.some((p) => p.id === t.carePlanId && p.followUpDueAt?.getTime() === t.dueAt?.getTime());
      items.push({
        id: `task:${t.id}`,
        kind: isFollowUp ? 'follow_up' : 'task',
        title: t.title,
        subtitle: t.description,
        at: t.dueAt!.toISOString(),
        status: t.status === 'done' ? 'done' : t.status === 'overdue' || (t.dueAt! < now && t.status === 'open') ? 'missed' : 'pending',
        refId: t.id,
      });
    }
    const appts = await db
      .select()
      .from(appointments)
      .where(and(eq(appointments.patientId, q.patientId), gte(appointments.startAt, start), lt(appointments.startAt, end), inArray(appointments.status, ['confirmed', 'in_progress', 'completed'])));
    const docs = appts.length ? await db.select({ id: providers.id, name: providers.name }).from(providers).where(inArray(providers.id, appts.map((a) => a.doctorId))) : [];
    for (const a of appts) {
      items.push({
        id: `appointment:${a.id}`,
        kind: 'appointment',
        title: `Consultation with ${docs.find((d) => d.id === a.doctorId)?.name ?? 'doctor'}`,
        subtitle: a.mode.replace('_', ' '),
        at: a.startAt.toISOString(),
        status: a.status === 'completed' ? 'done' : 'pending',
        refId: a.id,
      });
    }
    const visits = await db
      .select()
      .from(homeVisits)
      .where(and(eq(homeVisits.patientId, q.patientId), gte(homeVisits.preferredStart, start), lt(homeVisits.preferredStart, end), notInArray(homeVisits.status, ['cancelled'])));
    for (const v of visits) {
      items.push({
        id: `home_visit:${v.id}`,
        kind: 'home_visit',
        title: 'Home visit',
        subtitle: v.status.replace('_', ' '),
        at: v.preferredStart.toISOString(),
        status: v.status === 'completed' ? 'done' : 'pending',
        refId: v.id,
      });
    }
    items.sort((a, b) => a.at.localeCompare(b.at));
    return list(items);
  });
}

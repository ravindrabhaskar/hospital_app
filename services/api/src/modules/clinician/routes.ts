import { and, desc, eq, gt, gte, inArray, lt, ne } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import {
  aiFeedback,
  aiInteractions,
  appointments,
  careEpisodes,
  carePlans,
  conditions,
  conversations,
  homeVisits,
  medicalRecords,
  medications,
  moodEntries,
  patients,
  recordShares,
  safetyEvents,
  vitals,
} from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import type { RequestCtx } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { list, pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { ageFromDob, istDate, istDayBounds } from '../../lib/time.js';
import { parse, zDate, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { toAppointment, toAppointments } from '../appointments/service.js';
import { ACTIVE_STATUSES, addEvent, advanceEpisode, toCareEpisodes } from '../episodes/service.js';
import { toHomeVisits } from '../homevisits/service.js';
import { toMedications } from '../medications/service.js';
import { toPatientProfile, toPatientSummary } from '../patients/service.js';
import { toRecord } from '../records/service.js';
import { toSafetyEvents } from '../safety/service.js';
import { toVital } from '../vitals/service.js';
import { toMood } from '../wellness/routes.js';

const DOCTOR_VIEW = { relation: 'patient', isSelf: false, permissions: ['view_records', 'manage_care'] as Array<'view_records' | 'manage_care'> };

/** Patient ids this doctor has a care relationship with. */
export async function relatedPatientIds(db: DbOrTx, ctx: RequestCtx): Promise<string[]> {
  const providerId = ctx.user.providerId;
  if (!providerId) return [];
  const [a, e, p, s] = await Promise.all([
    db.selectDistinct({ id: appointments.patientId }).from(appointments).where(and(eq(appointments.doctorId, providerId), ne(appointments.status, 'cancelled'))),
    db.selectDistinct({ id: careEpisodes.patientId }).from(careEpisodes).where(eq(careEpisodes.ownerUserId, ctx.user.id)),
    db.selectDistinct({ id: carePlans.patientId }).from(carePlans).where(eq(carePlans.doctorId, providerId)),
    db
      .selectDistinct({ id: medicalRecords.patientId })
      .from(recordShares)
      .innerJoin(medicalRecords, eq(medicalRecords.id, recordShares.recordId))
      .where(and(eq(recordShares.doctorId, providerId), gt(recordShares.expiresAt, new Date()))),
  ]);
  return [...new Set([...a, ...e, ...p, ...s].map((x) => x.id))];
}

export async function clinicianRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  app.addHook('preHandler', requireRoles(svc, 'doctor'));

  app.get('/clinician/queue', async (req) => {
    const q = parse(z.object({ date: zDate.optional() }), req.query);
    const providerId = req.ctx.user.providerId;
    if (!providerId) throw errors.forbidden('Doctor profile required');
    const { start, end } = istDayBounds(q.date ?? istDate());
    const rows = await db
      .select()
      .from(appointments)
      .where(and(eq(appointments.doctorId, providerId), gte(appointments.startAt, start), lt(appointments.startAt, end), ne(appointments.status, 'cancelled')))
      .orderBy(appointments.startAt);
    const mapped = await toAppointments(db, rows);
    const pids = [...new Set(rows.map((r) => r.patientId))];
    const eids = [...new Set(rows.map((r) => r.careEpisodeId))];
    const ps = pids.length ? await db.select().from(patients).where(inArray(patients.id, pids)) : [];
    const es = eids.length ? await db.select().from(careEpisodes).where(inArray(careEpisodes.id, eids)) : [];
    const pm = new Map(ps.map((p) => [p.id, p]));
    const em = new Map(es.map((e) => [e.id, e]));
    return list(
      mapped.map((a) => ({
        ...a,
        patientAge: ageFromDob(pm.get(a.patientId)?.dob ?? null),
        patientGender: pm.get(a.patientId)?.gender ?? null,
        episodeStatus: em.get(a.careEpisodeId)?.status ?? null,
        priority: em.get(a.careEpisodeId)?.priority ?? 'routine',
      })),
    );
  });

  app.get('/clinician/patients', async (req) => {
    const q = parse(z.object({ q: z.string().max(100).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const ids = await relatedPatientIds(db, req.ctx);
    if (!ids.length) return { items: [], nextCursor: null };
    let rows = await db.select().from(patients).where(inArray(patients.id, ids)).orderBy(patients.name);
    if (q.q) rows = rows.filter((p) => (p.name ?? '').toLowerCase().includes(q.q!.toLowerCase()));
    return paginateArray(
      rows.map((p) => toPatientSummary(p, DOCTOR_VIEW)),
      page,
    );
  });

  app.get('/clinician/patients/:patientId/snapshot', async (req) => {
    const { patientId } = parse(z.object({ patientId: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, patientId, 'view_records', 'clinician.snapshot');
    const [p] = await db.select().from(patients).where(eq(patients.id, patientId));
    const [eps, meds, vits, recs, visits, moods, conds, conv] = await Promise.all([
      db.select().from(careEpisodes).where(and(eq(careEpisodes.patientId, patientId), inArray(careEpisodes.status, ACTIVE_STATUSES))).orderBy(desc(careEpisodes.updatedAt)),
      db.select().from(medications).where(and(eq(medications.patientId, patientId), eq(medications.active, true))),
      db.select().from(vitals).where(eq(vitals.patientId, patientId)).orderBy(desc(vitals.measuredAt)).limit(20),
      db.select().from(medicalRecords).where(eq(medicalRecords.patientId, patientId)).orderBy(desc(medicalRecords.recordDate)).limit(10),
      db.select().from(homeVisits).where(and(eq(homeVisits.patientId, patientId), eq(homeVisits.status, 'completed'))).orderBy(desc(homeVisits.completedAt)).limit(5),
      db.select().from(moodEntries).where(and(eq(moodEntries.patientId, patientId), eq(moodEntries.shareWithClinician, true))).orderBy(desc(moodEntries.createdAt)).limit(30),
      db.select().from(conditions).where(eq(conditions.patientId, patientId)),
      db.select().from(conversations).where(eq(conversations.patientId, patientId)).orderBy(desc(conversations.updatedAt)).limit(1),
    ]);

    // Source-linked claims built deterministically from authorized data.
    type Claim = { text: string; sources: Array<{ kind: 'record' | 'vital' | 'intake' | 'home_visit' | 'patient_entered'; refId: string; label: string }> };
    const claims: Claim[] = [];
    if (conds.length)
      claims.push({
        text: `Known conditions: ${conds.map((c) => c.name).join(', ')}.`,
        sources: conds.map((c) => ({ kind: 'patient_entered' as const, refId: c.id, label: c.name })),
      });
    const sys = vits.find((v) => v.type === 'bp_systolic');
    const dia = vits.find((v) => v.type === 'bp_diastolic');
    if (sys)
      claims.push({
        text: `Latest recorded blood pressure ${sys.value}${dia ? `/${dia.value}` : ''} mmHg on ${istDate(sys.measuredAt)} (${sys.source}).`,
        sources: [sys, ...(dia ? [dia] : [])].map((v) => ({ kind: 'vital' as const, refId: v.id, label: v.type })),
      });
    const glu = vits.find((v) => v.type === 'blood_glucose');
    if (glu) claims.push({ text: `Latest blood glucose ${glu.value} ${glu.unit} on ${istDate(glu.measuredAt)}.`, sources: [{ kind: 'vital', refId: glu.id, label: 'blood_glucose' }] });
    if (recs[0]) claims.push({ text: `Most recent document: ${recs[0].title} (${recs[0].recordDate}).`, sources: [{ kind: 'record', refId: recs[0].id, label: recs[0].title }] });
    if (visits[0]) claims.push({ text: `Last home visit completed on ${istDate(visits[0].completedAt ?? visits[0].preferredStart)}.`, sources: [{ kind: 'home_visit', refId: visits[0].id, label: 'Home visit summary' }] });
    const intake = (conv[0]?.intake as Record<string, any> | undefined) ?? null;
    if (intake?.chiefComplaint?.value) {
      claims.push({
        text: `Recent AI intake: ${intake.chiefComplaint.value}${intake.durationText?.value ? `, ${intake.durationText.value}` : ''}${typeof intake.severity?.value === 'number' ? `, severity ${intake.severity.value}/10` : ''}.`,
        sources: [{ kind: 'intake', refId: conv[0].id, label: 'AI intake' }],
      });
    }
    let aiSummary = null;
    if (claims.length) {
      const fallbackText = claims.map((c) => c.text).join(' ');
      const res = await svc.ai.complete(
        {
          system:
            'Write a 2-3 sentence consultation brief for a clinician using ONLY the provided claims. Do not add facts, interpretations or diagnoses. Keep numbers exactly as given.',
          messages: [{ role: 'user', content: JSON.stringify(claims.map((c) => c.text)) }],
          maxTokens: 1024,
          fallbackText,
        },
        { useCase: 'clinician_summary', userId: req.ctx.user.id, patientId, safetyLevel: 'none', rulePackVersion: 'n/a' },
      );
      aiSummary = { interactionId: res.interactionId, text: res.text, advisory: true as const, model: res.model, generatedAt: new Date().toISOString(), claims };
    }
    await audit(db, req.ctx.actor, { action: 'clinician.snapshot', entityType: 'patient', entityId: patientId });
    return {
      patient: await toPatientProfile(db, p, DOCTOR_VIEW),
      activeEpisodes: await toCareEpisodes(db, eps),
      activeMedications: await toMedications(db, meds, svc.config.DOSE_MISSED_GRACE_MIN),
      recentVitals: vits.map(toVital),
      recentRecords: recs.map(toRecord),
      homeVisitFindings: await toHomeVisits(db, visits, () => 'doctor'),
      moodTrend: moods.length ? moods.map(toMood) : null,
      aiSummary,
      intake: intake as unknown,
    };
  });

  const loadOwn = async (req: { ctx: RequestCtx }, id: string) => {
    const [a] = await db.select().from(appointments).where(eq(appointments.id, id));
    if (!a) throw errors.notFound('Appointment');
    if (a.doctorId !== req.ctx.user.providerId) {
      await audit(db, req.ctx.actor, { action: 'clinician.appointment', entityType: 'appointment', entityId: id, outcome: 'denied' });
      throw errors.forbidden();
    }
    return a;
  };

  app.post('/clinician/appointments/:id/start', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const a = await loadOwn(req, id);
    if (a.status !== 'confirmed') throw errors.invalidTransition(a.status, 'in_progress');
    const row = await db.transaction(async (tx) => {
      const [r] = await tx.update(appointments).set({ status: 'in_progress', updatedAt: new Date() }).where(eq(appointments.id, id)).returning();
      await advanceEpisode(tx, a.careEpisodeId, ['UNDER_CARE'], 'Consultation started', req.ctx.actor, { ownerUserId: req.ctx.user.id, nextAction: 'Consultation in progress' });
      await addEvent(tx, a.careEpisodeId, 'consultation_started', 'Consultation started', req.ctx.actor, { appointmentId: id });
      await audit(tx, req.ctx.actor, { action: 'appointment.start', entityType: 'appointment', entityId: id });
      return r;
    });
    return toAppointment(db, row);
  });

  app.post('/clinician/appointments/:id/complete', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ notes: z.string().trim().min(1).max(8000), outcome: z.enum(['care_plan', 'resolved', 'refer', 'home_visit']) }), req.body);
    const a = await loadOwn(req, id);
    if (!['in_progress', 'confirmed'].includes(a.status)) throw errors.invalidTransition(a.status, 'completed');
    const row = await db.transaction(async (tx) => {
      const [r] = await tx
        .update(appointments)
        .set({ status: 'completed', clinicianNotes: body.notes, outcome: body.outcome, completedAt: new Date(), updatedAt: new Date() })
        .where(eq(appointments.id, id))
        .returning();
      await advanceEpisode(tx, a.careEpisodeId, ['UNDER_CARE'], 'Consultation', req.ctx.actor);
      const target = body.outcome === 'resolved' ? 'RESOLVED' : body.outcome === 'refer' ? 'TRANSFERRED' : 'FOLLOW_UP';
      const nextAction =
        body.outcome === 'care_plan' ? 'Follow the care plan' : body.outcome === 'home_visit' ? 'Book a home visit' : body.outcome === 'refer' ? 'Referred to another provider' : null;
      await advanceEpisode(tx, a.careEpisodeId, [target], `Consultation completed (${body.outcome})`, req.ctx.actor, { nextAction });
      await addEvent(tx, a.careEpisodeId, 'consultation_completed', 'Consultation completed', req.ctx.actor, { appointmentId: id, outcome: body.outcome });
      await audit(tx, req.ctx.actor, { action: 'appointment.complete', entityType: 'appointment', entityId: id, metadata: { outcome: body.outcome } });
      return r;
    });
    return toAppointment(db, row);
  });

  app.get('/clinician/escalations', async (req) => {
    const page = pageFromQuery(req.query);
    const ids = await relatedPatientIds(db, req.ctx);
    if (!ids.length) return { items: [], nextCursor: null };
    const rows = await db
      .select()
      .from(safetyEvents)
      .where(and(inArray(safetyEvents.patientId, ids), inArray(safetyEvents.status, ['open', 'acknowledged'])))
      .orderBy(desc(safetyEvents.createdAt));
    return paginateArray(await toSafetyEvents(db, rows), page);
  });

  app.post('/clinician/ai-feedback', async (req, reply) => {
    const body = parse(z.object({ aiInteractionId: zUuid, decision: z.enum(['accept', 'reject', 'modify']), note: z.string().max(2000) }), req.body);
    const [ai] = await db.select({ id: aiInteractions.id, patientId: aiInteractions.patientId }).from(aiInteractions).where(eq(aiInteractions.id, body.aiInteractionId));
    if (!ai) throw errors.notFound('AI interaction');
    if (ai.patientId) await assertCanActForPatient(db, req.ctx, ai.patientId, 'view_records', 'clinician.ai_feedback');
    const [row] = await db.insert(aiFeedback).values({ aiInteractionId: ai.id, userId: req.ctx.user.id, decision: body.decision, note: body.note }).returning();
    await audit(db, req.ctx.actor, { action: 'clinician.ai_feedback', entityType: 'ai_interaction', entityId: ai.id, metadata: { decision: body.decision } });
    return reply.code(201).send({ id: row.id });
  });
}

import { desc, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { appointments, careEpisodes, carePlans, homeVisitServices, homeVisits, medicalRecords, medications, providers, vitals } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { istToUtc } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';

interface TimelineItem {
  id: string;
  kind: 'record' | 'appointment' | 'home_visit' | 'vital' | 'care_plan' | 'episode' | 'medication';
  title: string;
  subtitle: string | null;
  occurredAt: string;
  refId: string;
  source: string | null;
}

const VITAL_LABEL: Record<string, string> = {
  bp_systolic: 'Blood pressure (systolic)',
  bp_diastolic: 'Blood pressure (diastolic)',
  pulse: 'Pulse',
  spo2: 'SpO2',
  temperature: 'Temperature',
  blood_glucose: 'Blood glucose',
  weight: 'Weight',
  respiratory_rate: 'Respiratory rate',
  steps: 'Steps',
  sleep_minutes: 'Sleep',
};

export async function timelineRoutes(app: FastifyInstance): Promise<void> {
  const db = app.svc.db;

  app.get('/timeline', async (req) => {
    const q = parse(z.object({ patientId: zUuid }), req.query);
    const page = pageFromQuery(req.query);
    const pid = q.patientId;
    await assertCanActForPatient(db, req.ctx, pid, 'view_records', 'timeline.read');
    const cap = 300;
    const [recs, appts, visits, vits, plans, eps, meds, docs, services] = await Promise.all([
      db.select().from(medicalRecords).where(eq(medicalRecords.patientId, pid)).orderBy(desc(medicalRecords.createdAt)).limit(cap),
      db.select().from(appointments).where(eq(appointments.patientId, pid)).orderBy(desc(appointments.startAt)).limit(cap),
      db.select().from(homeVisits).where(eq(homeVisits.patientId, pid)).orderBy(desc(homeVisits.preferredStart)).limit(cap),
      db.select().from(vitals).where(eq(vitals.patientId, pid)).orderBy(desc(vitals.measuredAt)).limit(cap),
      db.select().from(carePlans).where(eq(carePlans.patientId, pid)).orderBy(desc(carePlans.createdAt)).limit(cap),
      db.select().from(careEpisodes).where(eq(careEpisodes.patientId, pid)).orderBy(desc(careEpisodes.createdAt)).limit(cap),
      db.select().from(medications).where(eq(medications.patientId, pid)).orderBy(desc(medications.createdAt)).limit(cap),
      db.select({ id: providers.id, name: providers.name }).from(providers),
      db.select().from(homeVisitServices),
    ]);
    const dn = new Map(docs.map((d) => [d.id, d.name]));
    const sn = new Map(services.map((s) => [s.code, s.name]));
    const items: TimelineItem[] = [
      ...recs.map((r) => ({
        id: `record:${r.id}`,
        kind: 'record' as const,
        title: r.title,
        subtitle: r.type.replace('_', ' '),
        occurredAt: istToUtc(r.recordDate, '12:00').toISOString(),
        refId: r.id,
        source: r.source,
      })),
      ...appts.map((a) => ({
        id: `appointment:${a.id}`,
        kind: 'appointment' as const,
        title: `Consultation with ${dn.get(a.doctorId) ?? 'doctor'}`,
        subtitle: `${a.mode.replace('_', ' ')} · ${a.status.replace('_', ' ')}`,
        occurredAt: a.startAt.toISOString(),
        refId: a.id,
        source: null,
      })),
      ...visits.map((v) => ({
        id: `home_visit:${v.id}`,
        kind: 'home_visit' as const,
        title: `Home visit: ${sn.get(v.serviceCode) ?? v.serviceCode}`,
        subtitle: v.status.replace('_', ' '),
        occurredAt: (v.completedAt ?? v.preferredStart).toISOString(),
        refId: v.id,
        source: 'home_visit',
      })),
      ...vits.map((v) => ({
        id: `vital:${v.id}`,
        kind: 'vital' as const,
        title: VITAL_LABEL[v.type] ?? v.type,
        subtitle: `${v.value} ${v.unit}`,
        occurredAt: v.measuredAt.toISOString(),
        refId: v.id,
        source: v.source,
      })),
      ...plans.map((p) => ({
        id: `care_plan:${p.id}`,
        kind: 'care_plan' as const,
        title: 'Care plan',
        subtitle: `${dn.get(p.doctorId) ?? ''} · ${p.status}`,
        occurredAt: p.createdAt.toISOString(),
        refId: p.id,
        source: 'clinician_verified',
      })),
      ...eps.map((e) => ({
        id: `episode:${e.id}`,
        kind: 'episode' as const,
        title: e.title,
        subtitle: e.status.replace('_', ' ').toLowerCase(),
        occurredAt: e.createdAt.toISOString(),
        refId: e.id,
        source: null,
      })),
      ...meds.map((m) => ({
        id: `medication:${m.id}`,
        kind: 'medication' as const,
        title: `${m.name} ${m.dose}`,
        subtitle: m.frequency,
        occurredAt: m.createdAt.toISOString(),
        refId: m.id,
        source: m.source,
      })),
    ];
    items.sort((a, b) => b.occurredAt.localeCompare(a.occurredAt));
    return paginateArray(items, page);
  });
}

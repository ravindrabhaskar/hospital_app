import { inArray } from 'drizzle-orm';
import type { DbOrTx } from '../../db/client.js';
import { carePlans, careTasks, medications, providers } from '../../db/schema.js';
import { iso } from '../../lib/time.js';
import { toMedications } from '../medications/service.js';

export type CarePlanRow = typeof carePlans.$inferSelect;
export type CareTaskRow = typeof careTasks.$inferSelect;

export const toCareTask = (t: CareTaskRow) => ({
  id: t.id,
  carePlanId: t.carePlanId,
  patientId: t.patientId,
  type: t.type,
  title: t.title,
  description: t.description,
  dueAt: iso(t.dueAt),
  owner: t.owner,
  status: t.status,
  completedAt: iso(t.completedAt),
  completedByName: t.completedByName,
});

export async function toCarePlans(db: DbOrTx, rows: CarePlanRow[], graceMin = 60) {
  if (!rows.length) return [];
  const ids = rows.map((r) => r.id);
  const [tasks, meds, docs] = await Promise.all([
    db.select().from(careTasks).where(inArray(careTasks.carePlanId, ids)).orderBy(careTasks.dueAt),
    db.select().from(medications).where(inArray(medications.carePlanId, ids)).orderBy(medications.name),
    db
      .select({ id: providers.id, name: providers.name })
      .from(providers)
      .where(
        inArray(
          providers.id,
          rows.map((r) => r.doctorId),
        ),
      ),
  ]);
  const medMapped = await toMedications(db, meds, graceMin);
  const dm = new Map(docs.map((d) => [d.id, d.name]));
  return rows.map((p) => ({
    id: p.id,
    careEpisodeId: p.careEpisodeId,
    patientId: p.patientId,
    doctorId: p.doctorId,
    doctorName: dm.get(p.doctorId) ?? '',
    status: p.status,
    summary: p.summary,
    instructions: p.instructions,
    tasks: tasks.filter((t) => t.carePlanId === p.id).map(toCareTask),
    medications: medMapped.filter((m) => meds.find((x) => x.id === m.id)?.carePlanId === p.id),
    followUpDueAt: iso(p.followUpDueAt),
    createdAt: iso(p.createdAt),
  }));
}

import { and, desc, eq, gte, inArray } from 'drizzle-orm';
import type { DbOrTx } from '../../db/client.js';
import { vitals } from '../../db/schema.js';
import { iso } from '../../lib/time.js';

export type VitalRow = typeof vitals.$inferSelect;

export const toVital = (v: VitalRow) => ({
  id: v.id,
  patientId: v.patientId,
  type: v.type,
  value: v.value,
  unit: v.unit,
  measuredAt: iso(v.measuredAt),
  source: v.source,
  recordedByName: v.recordedByName,
});

/** Recent vitals (for safety evaluation) as {type,value}. */
export async function recentVitals(db: DbOrTx, patientId: string, sinceHours = 24): Promise<Array<{ type: string; value: number }>> {
  const since = new Date(Date.now() - sinceHours * 3600_000);
  const rows = await db
    .select({ type: vitals.type, value: vitals.value })
    .from(vitals)
    .where(and(eq(vitals.patientId, patientId), gte(vitals.measuredAt, since)))
    .orderBy(desc(vitals.measuredAt))
    .limit(50);
  return rows;
}

export async function vitalsForVisits(db: DbOrTx, visitIds: string[]): Promise<Map<string, VitalRow[]>> {
  const m = new Map<string, VitalRow[]>();
  if (!visitIds.length) return m;
  const rows = await db.select().from(vitals).where(inArray(vitals.homeVisitId, visitIds)).orderBy(vitals.measuredAt);
  for (const r of rows) {
    const k = r.homeVisitId!;
    m.set(k, [...(m.get(k) ?? []), r]);
  }
  return m;
}

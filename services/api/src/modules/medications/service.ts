import { and, gte, inArray, lt } from 'drizzle-orm';
import type { DbOrTx } from '../../db/client.js';
import { doseLogs, medications } from '../../db/schema.js';
import { istDate, istDayBounds, istToUtc, iso } from '../../lib/time.js';

export type MedicationRow = typeof medications.$inferSelect;

export function isActiveOn(m: MedicationRow, date: string): boolean {
  return m.active && m.startDate <= date && (!m.endDate || m.endDate >= date);
}

/** Map medications including today's dose schedule (IST). */
export async function toMedications(db: DbOrTx, rows: MedicationRow[], graceMin = 60, now = new Date()) {
  if (!rows.length) return [];
  const today = istDate(now);
  const { start, end } = istDayBounds(today);
  const logs = await db
    .select()
    .from(doseLogs)
    .where(
      and(
        inArray(
          doseLogs.medicationId,
          rows.map((r) => r.id),
        ),
        gte(doseLogs.scheduledAt, start),
        lt(doseLogs.scheduledAt, end),
      ),
    );
  const logOf = new Map(logs.map((l) => [`${l.medicationId}|${l.scheduledAt.toISOString()}`, l.status]));
  return rows.map((m) => {
    const activeToday = isActiveOn(m, today);
    return {
      id: m.id,
      patientId: m.patientId,
      name: m.name,
      dose: m.dose,
      frequency: m.frequency,
      times: m.times,
      startDate: m.startDate,
      endDate: m.endDate,
      instructions: m.instructions,
      source: m.source,
      prescribedByName: m.prescribedByName,
      active: m.active && (!m.endDate || m.endDate >= today),
      today: activeToday
        ? m.times.map((time) => {
            const at = istToUtc(today, time);
            const logged = logOf.get(`${m.id}|${at.toISOString()}`);
            const status = logged ?? (now.getTime() > at.getTime() + graceMin * 60_000 ? 'missed' : 'pending');
            return { time, scheduledAt: at.toISOString(), status };
          })
        : [],
    };
  });
}

export const toDoseLog = (d: typeof doseLogs.$inferSelect) => ({
  id: d.id,
  medicationId: d.medicationId,
  scheduledAt: iso(d.scheduledAt),
  status: d.status,
  loggedAt: iso(d.loggedAt),
});

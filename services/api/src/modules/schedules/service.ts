import { and, asc, eq, gt, gte, inArray, lt, sql } from 'drizzle-orm';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { appointments, doctorLeaves, doctorSchedules, providers, slots, type WeeklyBlockJson } from '../../db/schema.js';
import { errors } from '../../lib/errors.js';
import { addDays, istDate, istDayBounds, istToUtc } from '../../lib/time.js';

/** Contract section 29. All times are IST wall-clock; weekday 0 = Sunday. */
export const SLOT_MODES = ['video', 'audio', 'chat', 'in_clinic'] as const;
export const SCHEDULE_TIMEZONE = 'Asia/Kolkata';

const zHHMM = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Expected HH:MM');
export const zWeeklyBlock = z.object({
  weekday: z.number().int().min(0).max(6),
  start: zHHMM,
  end: zHHMM,
  slotMins: z.union([z.literal(10), z.literal(15), z.literal(20), z.literal(30), z.literal(45), z.literal(60)]),
  modes: z.array(z.enum(SLOT_MODES)).min(1).max(4),
});
export const zScheduleBody = z.object({ weekly: z.array(zWeeklyBlock).max(70) });

/** Seeded doctors (and doctors that existed before v1.2): Mon-Sat 09:00-13:00 and 14:00-18:00, 30 min, all modes. */
export const DEFAULT_WEEKLY: WeeklyBlockJson[] = [1, 2, 3, 4, 5, 6].flatMap((weekday) =>
  [
    ['09:00', '13:00'],
    ['14:00', '18:00'],
  ].map(([start, end]) => ({ weekday, start, end, slotMins: 30, modes: [...SLOT_MODES] })),
);

const minutes = (hhmm: string): number => {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
};

/** Normalise + validate a weekly template. Overlapping blocks on the same weekday -> VALIDATION_ERROR. */
export function validateWeekly(blocks: WeeklyBlockJson[]): WeeklyBlockJson[] {
  const out = blocks.map((b) => ({ weekday: b.weekday, start: b.start, end: b.end, slotMins: b.slotMins, modes: [...new Set(b.modes)] }));
  out.forEach((b, i) => {
    if (minutes(b.end) <= minutes(b.start)) throw errors.validation('Block end must be after start', { index: i });
    if (minutes(b.end) - minutes(b.start) < b.slotMins) throw errors.validation('Block is shorter than one slot', { index: i });
  });
  for (let i = 0; i < out.length; i++) {
    for (let j = i + 1; j < out.length; j++) {
      const a = out[i];
      const b = out[j];
      if (a.weekday === b.weekday && minutes(a.start) < minutes(b.end) && minutes(b.start) < minutes(a.end)) {
        throw errors.validation('Schedule blocks overlap', { weekday: a.weekday, blocks: [i, j] });
      }
    }
  }
  return out.sort((a, b) => a.weekday - b.weekday || minutes(a.start) - minutes(b.start));
}

/** Weekday (0 = Sunday) of an IST calendar date. */
export const weekdayOf = (date: string): number => new Date(`${date}T00:00:00Z`).getUTCDay();

/**
 * Serialise schedule changes per doctor (row lock on the provider). Slot booking itself uses conditional updates on
 * the slot rows, so a concurrent booking is never overwritten: every slot write below is conditional on the status.
 */
export async function lockDoctor(tx: DbOrTx, doctorId: string): Promise<void> {
  await tx.execute(sql`select id from providers where id = ${doctorId} for update`);
}

export interface RegenerateResult {
  inserted: number;
  removed: number;
  updated: number;
}

/**
 * Bring the doctor's FUTURE slots in line with the weekly template and leaves for the next `horizonDays` days.
 * - booked / held slots are never touched, and no new slot may overlap one;
 * - unbooked slots that are no longer wanted are deleted (or marked `retired` when an old cancelled appointment
 *   still references them, so history stays intact);
 * - `extendOnly` (the daily worker job) only adds missing slots.
 */
export async function regenerateSlots(
  tx: DbOrTx,
  doctorId: string,
  opts: { now?: Date; horizonDays: number; extendOnly?: boolean },
): Promise<RegenerateResult> {
  const now = opts.now ?? new Date();
  const today = istDate(now);
  const [sch] = await tx.select().from(doctorSchedules).where(eq(doctorSchedules.doctorId, doctorId));
  const weekly = sch?.weekly ?? [];
  const leaveRows = await tx.select({ date: doctorLeaves.date }).from(doctorLeaves).where(and(eq(doctorLeaves.doctorId, doctorId), gte(doctorLeaves.date, today)));
  const leaves = new Set(leaveRows.map((l) => l.date));

  const desired = new Map<number, { startAt: Date; endAt: Date; modes: string[] }>();
  for (let i = 0; i < opts.horizonDays; i++) {
    const date = addDays(today, i);
    if (leaves.has(date)) continue;
    const wd = weekdayOf(date);
    for (const b of weekly) {
      if (b.weekday !== wd) continue;
      let t = istToUtc(date, b.start);
      const stop = istToUtc(date, b.end);
      while (t.getTime() + b.slotMins * 60_000 <= stop.getTime()) {
        const end = new Date(t.getTime() + b.slotMins * 60_000);
        if (t > now) desired.set(t.getTime(), { startAt: t, endAt: end, modes: b.modes });
        t = end;
      }
    }
  }

  const existing = await tx.select().from(slots).where(and(eq(slots.doctorId, doctorId), gt(slots.startAt, now)));
  const locked = existing.filter((s) => s.status === 'booked' || s.status === 'held');
  for (const [k, d] of desired) {
    if (locked.some((l) => l.startAt < d.endAt && l.endAt > d.startAt)) desired.delete(k);
  }
  const free = existing.filter((s) => s.status === 'available' || s.status === 'retired');
  const freeByStart = new Map(free.map((s) => [s.startAt.getTime(), s]));
  const result: RegenerateResult = { inserted: 0, removed: 0, updated: 0 };

  if (!opts.extendOnly) {
    const unwanted: string[] = [];
    for (const s of free) {
      const want = desired.get(s.startAt.getTime());
      if (want) {
        const same = s.status === 'available' && s.endAt.getTime() === want.endAt.getTime() && JSON.stringify(s.modes) === JSON.stringify(want.modes);
        if (!same) {
          const upd = await tx
            .update(slots)
            .set({ status: 'available', endAt: want.endAt, modes: want.modes })
            .where(and(eq(slots.id, s.id), inArray(slots.status, ['available', 'retired'])))
            .returning({ id: slots.id });
          result.updated += upd.length;
        }
      } else if (s.status === 'available') {
        unwanted.push(s.id);
      }
    }
    if (unwanted.length) {
      const deleted = await tx
        .delete(slots)
        .where(
          and(
            inArray(slots.id, unwanted),
            eq(slots.status, 'available'),
            sql`not exists (select 1 from ${appointments} where ${appointments.slotId} = ${slots.id})`,
          ),
        )
        .returning({ id: slots.id });
      const gone = new Set(deleted.map((d) => d.id));
      const keep = unwanted.filter((id) => !gone.has(id));
      if (keep.length) await tx.update(slots).set({ status: 'retired' }).where(and(inArray(slots.id, keep), eq(slots.status, 'available')));
      result.removed = unwanted.length;
    }
  }

  const lockedStarts = new Set(locked.map((l) => l.startAt.getTime()));
  const toInsert = [...desired.entries()]
    .filter(([k]) => !freeByStart.has(k) && !lockedStarts.has(k))
    .map(([, d]) => ({ doctorId, startAt: d.startAt, endAt: d.endAt, modes: d.modes, status: 'available' }));
  if (toInsert.length) {
    const ins = await tx.insert(slots).values(toInsert).onConflictDoNothing().returning({ id: slots.id });
    result.inserted = ins.length;
  }
  return result;
}

export type LeaveRow = typeof doctorLeaves.$inferSelect;
export const toLeave = (l: LeaveRow) => ({ id: l.id, date: l.date, reason: l.reason });

export async function getSchedule(db: DbOrTx, doctorId: string, horizonDays: number) {
  const [sch] = await db.select().from(doctorSchedules).where(eq(doctorSchedules.doctorId, doctorId));
  const leaves = await db
    .select()
    .from(doctorLeaves)
    .where(and(eq(doctorLeaves.doctorId, doctorId), gte(doctorLeaves.date, istDate())))
    .orderBy(asc(doctorLeaves.date));
  return { weekly: sch?.weekly ?? [], leaves: leaves.map(toLeave), horizonDays, timezone: SCHEDULE_TIMEZONE };
}

export async function saveWeekly(tx: DbOrTx, doctorId: string, weekly: WeeklyBlockJson[], userId: string | null): Promise<void> {
  await tx
    .insert(doctorSchedules)
    .values({ doctorId, weekly, updatedByUserId: userId, updatedAt: new Date() })
    .onConflictDoUpdate({ target: doctorSchedules.doctorId, set: { weekly, updatedByUserId: userId, updatedAt: new Date() } });
}

/** Live appointments on an IST date (returned as leave conflicts; never auto-cancelled). */
export async function appointmentsOnDate(db: DbOrTx, doctorId: string, date: string) {
  const { start, end } = istDayBounds(date);
  return db
    .select()
    .from(appointments)
    .where(
      and(
        eq(appointments.doctorId, doctorId),
        gte(appointments.startAt, start),
        lt(appointments.startAt, end),
        inArray(appointments.status, ['pending_payment', 'confirmed', 'in_progress']),
      ),
    )
    .orderBy(asc(appointments.startAt));
}

export async function loadDoctor(db: DbOrTx, doctorId: string) {
  const [d] = await db.select().from(providers).where(eq(providers.id, doctorId));
  if (!d || d.kind !== 'doctor') throw errors.notFound('Doctor');
  return d;
}

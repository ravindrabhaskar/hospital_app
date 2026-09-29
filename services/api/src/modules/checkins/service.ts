import { and, eq, gte, isNull, lte, or } from 'drizzle-orm';
import type { DbOrTx } from '../../db/client.js';
import { checkinSettings, checkins, patients, safetyEvents } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, type Actor } from '../../lib/context.js';
import { addDays, istDate, istToUtc, iso } from '../../lib/time.js';
import type { Services } from '../../services.js';
import { raiseAlert } from '../safety/alerts.js';

/** Contract section 41: daily "I'm OK" check-in. */
export type CheckinSettingsRow = typeof checkinSettings.$inferSelect;
export type CheckinRow = typeof checkins.$inferSelect;

export const DEFAULT_CHECKIN = { enabled: false, windowStart: '08:00', windowEnd: '10:00', escalateAfterMins: 60, notifyFamily: true, notifyCoordinator: true };

export async function getSettings(db: DbOrTx, patientId: string): Promise<CheckinSettingsRow | null> {
  const [row] = await db.select().from(checkinSettings).where(eq(checkinSettings.patientId, patientId));
  return row ?? null;
}

export const toSettings = (patientId: string, s: CheckinSettingsRow | null) => ({
  patientId,
  enabled: s ? s.enabled && (!s.activeUntil || s.activeUntil >= istDate()) : DEFAULT_CHECKIN.enabled,
  windowStart: s?.windowStart ?? DEFAULT_CHECKIN.windowStart,
  windowEnd: s?.windowEnd ?? DEFAULT_CHECKIN.windowEnd,
  escalateAfterMins: s?.escalateAfterMins ?? DEFAULT_CHECKIN.escalateAfterMins,
  notifyFamily: s?.notifyFamily ?? DEFAULT_CHECKIN.notifyFamily,
  notifyCoordinator: s?.notifyCoordinator ?? DEFAULT_CHECKIN.notifyCoordinator,
});

export const toCheckin = (c: CheckinRow) => ({
  id: c.id,
  patientId: c.patientId,
  date: c.date,
  status: c.status,
  checkedInAt: iso(c.checkedInAt),
  mood: c.mood,
  note: c.note,
});

/**
 * Record today's check-in: `ok` inside/before the window, `late` after it. A later check-in the same day resolves the
 * missed-check-in SafetyEvent automatically.
 */
export async function recordCheckin(
  svc: Services,
  p: { patientId: string; mood?: number | null; note?: string | null; source: 'app' | 'whatsapp' | 'ivr'; actor: Actor; userId: string | null; now?: Date },
): Promise<CheckinRow> {
  const now = p.now ?? new Date();
  const today = istDate(now);
  const settings = await getSettings(svc.db, p.patientId);
  const windowEnd = settings ? istToUtc(today, settings.windowEnd) : null;
  const late = !!windowEnd && now > windowEnd;
  const status = late ? 'late' : 'ok';
  const row = await svc.db.transaction(async (tx) => {
    const [existing] = await tx.select().from(checkins).where(and(eq(checkins.patientId, p.patientId), eq(checkins.date, today)));
    let r: CheckinRow;
    if (existing && (existing.status === 'ok' || existing.status === 'late')) {
      [r] = await tx
        .update(checkins)
        .set({ mood: p.mood ?? existing.mood, note: p.note ?? existing.note })
        .where(eq(checkins.id, existing.id))
        .returning();
    } else if (existing) {
      [r] = await tx
        .update(checkins)
        .set({ status: existing.status === 'missed' ? 'late' : status, checkedInAt: now, mood: p.mood ?? null, note: p.note ?? null, source: p.source, createdByUserId: p.userId })
        .where(eq(checkins.id, existing.id))
        .returning();
    } else {
      [r] = await tx
        .insert(checkins)
        .values({ patientId: p.patientId, date: today, status, checkedInAt: now, mood: p.mood ?? null, note: p.note ?? null, source: p.source, createdByUserId: p.userId })
        .returning();
    }
    if (r.safetyEventId) {
      await tx
        .update(safetyEvents)
        .set({ status: 'resolved', resolvedAt: now, note: 'Auto-resolved: the patient checked in later the same day' })
        .where(and(eq(safetyEvents.id, r.safetyEventId), or(eq(safetyEvents.status, 'open'), eq(safetyEvents.status, 'acknowledged'))));
    }
    await audit(tx, p.actor, { action: 'checkin.record', entityType: 'checkin', entityId: r.id, metadata: { patientId: p.patientId, status: r.status, source: p.source } });
    return r;
  });
  return row;
}

/** Family recipients for check-in alerts: owner + grantees with receive_alerts, excluding the patient's own account. */
async function familyRecipients(svc: Services, patientId: string): Promise<string[]> {
  const [p] = await svc.db.select({ userId: patients.userId }).from(patients).where(eq(patients.id, patientId));
  const all = await svc.notify.alertRecipients(svc.db, patientId);
  return all.filter((u) => u !== p?.userId);
}

/**
 * Worker: at windowEnd (IST) without a check-in the day becomes `missed` and family with receive_alerts are told;
 * after escalateAfterMins more an `urgent` SafetyEvent (source checkin) is assigned to the coordinator.
 */
export async function checkinMonitor(svc: Services, now: Date): Promise<number> {
  const today = istDate(now);
  const all = await svc.db
    .select()
    .from(checkinSettings)
    .where(and(eq(checkinSettings.enabled, true), or(isNull(checkinSettings.activeUntil), gte(checkinSettings.activeUntil, today))));
  let n = 0;
  for (const s of all) {
    const windowEnd = istToUtc(today, s.windowEnd);
    if (now < windowEnd) continue;
    let [row] = await svc.db.select().from(checkins).where(and(eq(checkins.patientId, s.patientId), eq(checkins.date, today)));
    if (row && (row.status === 'ok' || row.status === 'late')) continue;
    if (!row) {
      [row] = await svc.db.insert(checkins).values({ patientId: s.patientId, date: today, status: 'missed' }).onConflictDoNothing().returning();
      if (!row) continue;
    } else if (row.status !== 'missed') {
      [row] = await svc.db.update(checkins).set({ status: 'missed' }).where(eq(checkins.id, row.id)).returning();
    }
    const [p] = await svc.db.select({ name: patients.name }).from(patients).where(eq(patients.id, s.patientId));
    const name = p?.name?.split(' ')[0] ?? 'Your family member';
    if (!row.missedAlertedAt) {
      const claimed = await svc.db.update(checkins).set({ missedAlertedAt: now }).where(and(eq(checkins.id, row.id), isNull(checkins.missedAlertedAt))).returning();
      if (claimed.length) {
        n++;
        if (s.notifyFamily) {
          await svc.notify.notifyUsers(await familyRecipients(svc, s.patientId), {
            template: 'checkin_missed',
            params: { patient: name },
            category: 'checkin',
            deepLink: `/patients/${s.patientId}/checkins`,
            dedupeKey: `checkin_missed:${s.patientId}:${today}`,
          });
        }
        await audit(svc.db, SYSTEM_ACTOR, { action: 'checkin.missed', entityType: 'checkin', entityId: row.id });
      }
    }
    const escalateAt = new Date(windowEnd.getTime() + s.escalateAfterMins * 60_000);
    if (now >= escalateAt && !row.escalatedAt) {
      const claimed = await svc.db.update(checkins).set({ escalatedAt: now }).where(and(eq(checkins.id, row.id), isNull(checkins.escalatedAt), eq(checkins.status, 'missed'))).returning();
      if (!claimed.length) continue;
      const event = await raiseAlert(svc, {
        patientId: s.patientId,
        level: 'urgent',
        source: 'checkin',
        rules: [{ ruleId: 'checkin.missed', title: 'Daily check-in missed' }],
        note: `No check-in by ${s.windowEnd} IST plus ${s.escalateAfterMins} minutes`,
        assignCoordinator: s.notifyCoordinator,
        notifyFamily: s.notifyFamily,
        familyTemplate: 'checkin_escalated',
        familyParams: { patient: name },
        category: 'checkin',
        deepLink: `/patients/${s.patientId}/checkins`,
        dedupeKey: `checkin_escalated:${s.patientId}:${today}`,
      });
      await svc.db.update(checkins).set({ safetyEventId: event.id }).where(eq(checkins.id, row.id));
      n++;
    }
  }
  return n;
}

/** One entry per day for the last `days` days (newest first), including missed days since check-ins were enabled. */
export async function checkinHistory(db: DbOrTx, patientId: string, days: number, now = new Date()) {
  const today = istDate(now);
  const from = addDays(today, -(days - 1));
  const rows = await db.select().from(checkins).where(and(eq(checkins.patientId, patientId), gte(checkins.date, from), lte(checkins.date, today)));
  const byDate = new Map(rows.map((r) => [r.date, r]));
  const s = await getSettings(db, patientId);
  const enabledSince = s?.enabled ? istDate(s.updatedAt) : null;
  const out = [];
  for (let i = 0; i < days; i++) {
    const date = addDays(today, -i);
    const r = byDate.get(date);
    if (r) {
      out.push(toCheckin(r));
      continue;
    }
    if (!s?.enabled || !enabledSince || date < enabledSince || (s.activeUntil && date > s.activeUntil)) continue;
    const pastWindow = date < today || now >= istToUtc(date, s.windowEnd);
    out.push({ id: `${patientId}:${date}`, patientId, date, status: pastWindow ? 'missed' : 'pending', checkedInAt: null, mood: null, note: null });
  }
  return out;
}

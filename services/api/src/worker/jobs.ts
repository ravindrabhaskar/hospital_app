import { and, eq, inArray, isNull, lt, lte, sql } from 'drizzle-orm';
import { appointments, careTasks, doseLogs, fallEvents, homeVisits, medications, payments, providers, users } from '../db/schema.js';
import { SYSTEM_ACTOR } from '../lib/context.js';
import { formatIst } from '../lib/i18n.js';
import { istDate, istToUtc } from '../lib/time.js';
import { completeDueDeletions, purgeExpiredExports } from '../modules/account/service.js';
import { doctorSchedules } from '../db/schema.js';
import { autoAssignCoordinators } from '../modules/coordinator/routes.js';
import { lockDoctor, regenerateSlots } from '../modules/schedules/service.js';
import { activeCoordinatorPlanSubscribers, coveredPatientIds, subscriptionLifecycle } from '../modules/subscriptions/service.js';
import { escalateFall } from '../modules/emergency/service.js';
import { autoAssign } from '../modules/homevisits/service.js';
import { isActiveOn } from '../modules/medications/service.js';
import type { Services } from '../services.js';

/**
 * Background jobs. Each job is idempotent and safe to run concurrently with API traffic, so the
 * same functions can later be executed by BullMQ/Redis workers (one queue per job name).
 */
export type Job = (svc: Services, now: Date) => Promise<number>;

/** Mark scheduled doses as missed once the grace period has passed (unique (medication, scheduledAt)). */
export const markMissedDoses: Job = async (svc, now) => {
  const today = istDate(now);
  const meds = await svc.db.select().from(medications).where(eq(medications.active, true));
  let n = 0;
  for (const m of meds) {
    if (!isActiveOn(m, today)) continue;
    for (const time of m.times) {
      const at = istToUtc(today, time);
      if (now.getTime() <= at.getTime() + svc.config.DOSE_MISSED_GRACE_MIN * 60_000) continue;
      const ins = await svc.db
        .insert(doseLogs)
        .values({ medicationId: m.id, scheduledAt: at, status: 'missed', loggedAt: now })
        .onConflictDoNothing()
        .returning({ id: doseLogs.id });
      if (ins.length) {
        n++;
        await svc.notify.notifyPatient(m.patientId, {
          template: 'medication_missed',
          category: 'medication',
          deepLink: `/medications/${m.id}`,
          dedupeKey: `dose_missed:${m.id}:${at.toISOString()}`,
        });
      }
    }
  }
  return n;
};

export const markOverdueTasks: Job = async (svc, now) => {
  const rows = await svc.db
    .update(careTasks)
    .set({ status: 'overdue' })
    .where(and(eq(careTasks.status, 'open'), lt(careTasks.dueAt, now)))
    .returning();
  for (const t of rows) {
    await svc.notify.notifyPatient(t.patientId, {
      template: 'task_overdue',
      params: { task: t.title },
      category: 'care_plan',
      deepLink: `/care-tasks/${t.id}`,
      dedupeKey: `task_overdue:${t.id}`,
    });
  }
  return rows.length;
};

export const escalateUnansweredFalls: Job = async (svc, now) => {
  const cutoff = new Date(now.getTime() - svc.config.FALL_RESPONSE_TIMEOUT_SEC * 1000);
  const due = await svc.db
    .select({ id: fallEvents.id })
    .from(fallEvents)
    .where(and(eq(fallEvents.status, 'awaiting_response'), lte(fallEvents.createdAt, cutoff)));
  let n = 0;
  for (const f of due) if (await escalateFall(svc, f.id, SYSTEM_ACTOR)) n++;
  return n;
};

export const appointmentReminders: Job = async (svc, now) => {
  const soon = new Date(now.getTime() + 60 * 60_000);
  const rows = await svc.db
    .update(appointments)
    .set({ reminderSentAt: now })
    .where(and(eq(appointments.status, 'confirmed'), isNull(appointments.reminderSentAt), lte(appointments.startAt, soon), sql`${appointments.startAt} > ${now}`))
    .returning();
  for (const a of rows) {
    const [d] = await svc.db.select({ name: providers.name }).from(providers).where(eq(providers.id, a.doctorId));
    await svc.notify.notifyPatient(a.patientId, {
      template: 'appointment_reminder',
      params: { doctor: d?.name ?? 'your doctor', when: formatIst(a.startAt) },
      category: 'appointment',
      deepLink: `/appointments/${a.id}`,
      dedupeKey: `appt_reminder:${a.id}:${a.startAt.toISOString()}`,
    });
  }
  return rows.length;
};

export const dispatchOutbox: Job = async (svc, now) => svc.notify.dispatchOutbox(now);

/** SLA flags for unassigned visits + retry matching. */
export const visitSlaAndRematch: Job = async (svc, now) => {
  const pending = await svc.db.select().from(homeVisits).where(inArray(homeVisits.status, ['requested', 'unassigned']));
  let n = 0;
  for (const v of pending) {
    if (v.preferredEnd > now) {
      const assigned = await svc.db.transaction((tx) => autoAssign(tx, v, SYSTEM_ACTOR, { onlyIfMatched: true }));
      if (assigned.status === 'assigned') {
        n++;
        continue;
      }
    }
    const breached = now.getTime() - v.createdAt.getTime() > svc.config.VISIT_ASSIGN_SLA_MIN * 60_000;
    if (breached && !v.slaBreachedAt) {
      await svc.db.update(homeVisits).set({ slaBreachedAt: now }).where(eq(homeVisits.id, v.id));
      const ops = await svc.db
        .select({ id: users.id })
        .from(users)
        .where(sql`${users.roles} ?| array['coordinator','ops_admin']`);
      await svc.notify.notifyUsers(
        ops.map((o) => o.id),
        { template: 'visit_sla', category: 'home_visit', critical: false, deepLink: `/ops/home-visits/${v.id}`, dedupeKey: `visit_sla:${v.id}` },
      );
      n++;
    }
  }
  return n;
};

/** Release slots held by unpaid appointments after PAYMENT_HOLD_MIN (applied as a synthetic failure event). */
export const expireUnpaidHolds: Job = async (svc, now) => {
  const cutoff = new Date(now.getTime() - svc.config.PAYMENT_HOLD_MIN * 60_000);
  const stale = await svc.db
    .select()
    .from(payments)
    // updatedAt: a retried payment (POST /payments/:id/retry) gets a fresh hold window.
    .where(and(eq(payments.status, 'pending'), eq(payments.purpose, 'appointment'), lt(payments.updatedAt, cutoff)));
  let n = 0;
  for (const p of stale) {
    const r = await svc.payments.applyEvent(
      { eventId: `expire_${p.gatewayOrderId}`, type: 'payment.failed', orderId: p.gatewayOrderId, gatewayPaymentId: null },
      { ...SYSTEM_ACTOR, name: 'payment-hold-expiry' },
    );
    if (r.applied) n++;
  }
  return n;
};

let lastHorizonDate: string | null = null;
/**
 * Contract section 29: once per IST day (and at start-up) extend every verified doctor's bookable slots to
 * SCHEDULE_HORIZON_DAYS from their weekly template. Only adds missing slots; never touches booked/held ones.
 */
export const scheduleHorizon: Job = async (svc, now) => {
  const today = istDate(now);
  if (lastHorizonDate === today) return 0;
  lastHorizonDate = today;
  const docs = await svc.db
    .select({ id: providers.id })
    .from(providers)
    .innerJoin(doctorSchedules, eq(doctorSchedules.doctorId, providers.id))
    .where(and(eq(providers.kind, 'doctor'), eq(providers.verificationStatus, 'verified')));
  let n = 0;
  for (const d of docs) {
    const r = await svc.db.transaction(async (tx) => {
      await lockDoctor(tx, d.id);
      return regenerateSlots(tx, d.id, { now, horizonDays: svc.config.SCHEDULE_HORIZON_DAYS, extendOnly: true });
    });
    n += r.inserted;
  }
  return n;
};

/** Contract section 37: expire/cancel ended subscriptions, renewal reminders, coordinator benefit for new episodes. */
export const subscriptions: Job = async (svc, now) => {
  let n = await subscriptionLifecycle(svc.db, svc.notify, now);
  for (const userId of await activeCoordinatorPlanSubscribers(svc.db, now)) {
    n += await svc.db.transaction(async (tx) => autoAssignCoordinators(tx, await coveredPatientIds(tx, userId), null));
  }
  return n;
};

/** Contract section 23: finish account deletions whose grace period has ended. */
export const accountDeletions: Job = async (svc, now) => completeDueDeletions(svc.db, now);

/** Remove expired data-export files. */
export const expireDataExports: Job = async (svc, now) => purgeExpiredExports(svc.db, svc.storage, now);

export const JOBS: Record<string, Job> = {
  markMissedDoses,
  markOverdueTasks,
  escalateUnansweredFalls,
  appointmentReminders,
  visitSlaAndRematch,
  expireUnpaidHolds,
  scheduleHorizon,
  subscriptions,
  accountDeletions,
  expireDataExports,
  dispatchOutbox,
};

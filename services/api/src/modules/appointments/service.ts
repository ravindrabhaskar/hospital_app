import { and, eq, inArray, notInArray, sql } from 'drizzle-orm';
import type { Db, DbOrTx } from '../../db/client.js';
import { appointments, careEpisodes, homeVisits, payments, patients, providers, slots } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, type Actor } from '../../lib/context.js';
import { AppError, errors } from '../../lib/errors.js';
import { formatIst } from '../../lib/i18n.js';
import { iso } from '../../lib/time.js';
import { specialtyNames } from '../doctors/routes.js';
import { addEvent, advanceEpisode } from '../episodes/service.js';
import type { NotificationService } from '../notifications/service.js';
import type { PaymentEffects, PaymentRow, PaymentService } from '../payments/service.js';
import type { VideoProvider } from '../video/provider.js';

export type AppointmentRow = typeof appointments.$inferSelect;

export async function toAppointments(db: DbOrTx, rows: AppointmentRow[]) {
  if (!rows.length) return [];
  const pids = [...new Set(rows.map((r) => r.patientId))];
  const dids = [...new Set(rows.map((r) => r.doctorId))];
  const [ps, ds, names] = await Promise.all([
    db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, pids)),
    db.select().from(providers).where(inArray(providers.id, dids)),
    specialtyNames(db),
  ]);
  const pm = new Map(ps.map((p) => [p.id, p.name]));
  const dm = new Map(ds.map((d) => [d.id, d]));
  return rows.map((a) => {
    const d = dm.get(a.doctorId);
    return {
      id: a.id,
      patientId: a.patientId,
      patientName: pm.get(a.patientId) ?? null,
      doctorId: a.doctorId,
      doctorName: d?.name ?? '',
      doctorSpecialty: names.get(d?.specialty ?? '') ?? 'General Physician',
      doctorPhotoUrl: d?.photoUrl ?? null,
      startAt: iso(a.startAt),
      endAt: iso(a.endAt),
      mode: a.mode,
      status: a.status,
      reason: a.reason,
      fee: a.fee,
      careEpisodeId: a.careEpisodeId,
      videoRoomUrl: a.status === 'confirmed' || a.status === 'in_progress' ? a.videoRoomUrl : null,
      clinicianNotes: a.clinicianNotes,
      createdAt: iso(a.createdAt),
    };
  });
}

export async function toAppointment(db: DbOrTx, row: AppointmentRow) {
  return (await toAppointments(db, [row]))[0];
}

/** Release a slot back to the pool. */
export async function releaseSlot(db: DbOrTx, slotId: string): Promise<void> {
  await db.update(slots).set({ status: 'available' }).where(eq(slots.id, slotId));
}

/** If an episode has no other live appointments / visits and is CARE_SCHEDULED, move it back to AWAITING_CARE. */
export async function maybeUnschedule(db: DbOrTx, episodeId: string, exceptAppointmentId: string | null, actor: Actor): Promise<void> {
  const [ep] = await db.select().from(careEpisodes).where(eq(careEpisodes.id, episodeId));
  if (!ep || ep.status !== 'CARE_SCHEDULED') return;
  const live = await db
    .select({ id: appointments.id })
    .from(appointments)
    .where(and(eq(appointments.careEpisodeId, episodeId), inArray(appointments.status, ['pending_payment', 'confirmed', 'in_progress'])));
  const liveVisits = await db
    .select({ id: homeVisits.id })
    .from(homeVisits)
    .where(and(eq(homeVisits.careEpisodeId, episodeId), notInArray(homeVisits.status, ['cancelled', 'completed'])));
  if (live.filter((a) => a.id !== exceptAppointmentId).length === 0 && liveVisits.length === 0) {
    await advanceEpisode(db, episodeId, ['AWAITING_CARE'], 'All scheduled care was cancelled', actor);
  }
}

export function appointmentPaymentEffects(notify: NotificationService, video: VideoProvider): PaymentEffects {
  return {
    /** A payment that failed cancelled its appointment; re-hold the same slot if it is still free. */
    async onRetry(tx: DbOrTx, p: PaymentRow) {
      const [a] = await tx.select().from(appointments).where(eq(appointments.id, p.refId));
      if (!a) throw errors.notFound('Appointment');
      if (a.status === 'pending_payment') return;
      if (a.status !== 'cancelled' || a.cancelReason !== 'payment_failed') {
        throw errors.conflict('This appointment can no longer be paid for', { status: a.status });
      }
      const held = await tx
        .update(slots)
        .set({ status: 'held' })
        .where(and(eq(slots.id, a.slotId), eq(slots.status, 'available'), sql`${slots.startAt} > ${new Date()}`))
        .returning({ id: slots.id });
      if (!held.length) throw new AppError('SLOT_UNAVAILABLE', 'This slot is no longer available. Please book another slot.');
      await tx.update(appointments).set({ status: 'pending_payment', cancelReason: null, updatedAt: new Date() }).where(eq(appointments.id, a.id));
      await addEvent(tx, a.careEpisodeId, 'appointment_payment_retry', 'Payment retried; slot held again', SYSTEM_ACTOR, { appointmentId: a.id });
    },
    async onSucceeded(db: Db, p: PaymentRow) {
      const row = await db.transaction(async (tx) => {
        const [a] = await tx.select().from(appointments).where(eq(appointments.id, p.refId));
        if (!a || a.status !== 'pending_payment') return null;
        const [updated] = await tx
          .update(appointments)
          .set({
            status: 'confirmed',
            videoRoomUrl: a.mode === 'video' || a.mode === 'audio' ? video.roomUrl(a.id, a.mode) : null,
            updatedAt: new Date(),
          })
          .where(eq(appointments.id, a.id))
          .returning();
        await tx.update(slots).set({ status: 'booked' }).where(eq(slots.id, a.slotId));
        const [doc] = await tx.select({ userId: providers.userId }).from(providers).where(eq(providers.id, a.doctorId));
        const [ep] = await tx.select().from(careEpisodes).where(eq(careEpisodes.id, a.careEpisodeId));
        await advanceEpisode(tx, a.careEpisodeId, ['CARE_SCHEDULED'], 'Appointment confirmed', SYSTEM_ACTOR, {
          ownerUserId: ep?.ownerUserId ?? doc?.userId ?? null,
          nextAction: 'Attend consultation',
        });
        await addEvent(tx, a.careEpisodeId, 'appointment_confirmed', 'Appointment confirmed after payment', SYSTEM_ACTOR, { appointmentId: a.id });
        await audit(tx, SYSTEM_ACTOR, { action: 'appointment.confirm', entityType: 'appointment', entityId: a.id });
        return updated;
      });
      if (row) {
        const [d] = await db.select({ name: providers.name }).from(providers).where(eq(providers.id, row.doctorId));
        await notify.notifyPatient(row.patientId, {
          template: 'appointment_confirmed',
          params: { doctor: d?.name ?? 'your doctor', when: formatIst(row.startAt) },
          category: 'appointment',
          deepLink: `/appointments/${row.id}`,
          dedupeKey: `appointment_confirmed:${row.id}`,
        });
      }
    },
    async onFailed(db: Db, p: PaymentRow) {
      await db.transaction(async (tx) => {
        const [a] = await tx.select().from(appointments).where(eq(appointments.id, p.refId));
        if (!a || a.status !== 'pending_payment') return;
        await tx.update(appointments).set({ status: 'cancelled', cancelReason: 'payment_failed', updatedAt: new Date() }).where(eq(appointments.id, a.id));
        await releaseSlot(tx, a.slotId);
        await addEvent(tx, a.careEpisodeId, 'appointment_cancelled', 'Appointment cancelled: payment failed', SYSTEM_ACTOR, { appointmentId: a.id });
        await maybeUnschedule(tx, a.careEpisodeId, a.id, SYSTEM_ACTOR);
      });
    },
  };
}

/** Cancel an appointment, releasing its slot and refunding / voiding its payment. */
export async function cancelAppointment(
  db: Db,
  paymentsSvc: PaymentService,
  a: AppointmentRow,
  reason: string,
  actor: Actor,
  refundToWallet = false,
): Promise<AppointmentRow> {
  const [pay] = await db.select().from(payments).where(and(eq(payments.purpose, 'appointment'), eq(payments.refId, a.id)));
  const updated = await db.transaction(async (tx) => {
    const [row] = await tx
      .update(appointments)
      .set({ status: 'cancelled', cancelReason: reason.slice(0, 500), updatedAt: new Date() })
      .where(eq(appointments.id, a.id))
      .returning();
    await releaseSlot(tx, a.slotId);
    if (pay?.status === 'pending') await paymentsSvc.voidPending(tx, pay.id);
    await addEvent(tx, a.careEpisodeId, 'appointment_cancelled', 'Appointment cancelled', actor, { appointmentId: a.id });
    await maybeUnschedule(tx, a.careEpisodeId, a.id, actor);
    await audit(tx, actor, { action: 'appointment.cancel', entityType: 'appointment', entityId: a.id });
    return row;
  });
  if (pay?.status === 'succeeded') {
    await paymentsSvc.refund(pay.id, { reason: 'appointment_cancelled', actor, toWallet: refundToWallet });
  }
  return updated;
}

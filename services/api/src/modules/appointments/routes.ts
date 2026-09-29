import { randomUUID } from 'node:crypto';
import { and, asc, desc, eq, gte, inArray, lt, or, sql } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { appointments, careEpisodes, providers, slots } from '../../db/schema.js';
import { assertCanActForPatient, listActablePatients, type Perm } from '../../lib/access.js';
import type { RequestCtx } from '../../lib/context.js';
import { audit } from '../../lib/audit.js';
import { AppError, errors } from '../../lib/errors.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { parse, zUuid } from '../../lib/validate.js';
import { feeForMode, isBookableDoctor } from '../doctors/routes.js';
import { ACTIVE_STATUSES, addEvent, createEpisode } from '../episodes/service.js';
import { toPayment } from '../payments/service.js';
import { zCouponCode, zRefundTo } from '../wallet/routes.js';
import { cancelAppointment, releaseSlot, toAppointment, toAppointments } from './service.js';

const isUniqueViolation = (err: unknown): boolean => {
  const e = err as { code?: string; cause?: { code?: string } };
  return e?.code === '23505' || e?.cause?.code === '23505';
};

export async function appointmentRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const readPerms: Perm[] = ['book', 'view_records', 'manage_care', 'staff_ops'];

  app.post('/appointments', { config: { idempotent: true } }, async (req, reply) => {
    const body = parse(
      z.object({
        patientId: zUuid,
        doctorId: zUuid,
        slotId: zUuid,
        mode: z.enum(['video', 'audio', 'chat', 'in_clinic']),
        reason: z.string().trim().min(1).max(500),
        careEpisodeId: zUuid.optional(),
        couponCode: zCouponCode.optional(),
        useWallet: z.boolean().optional(),
      }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, body.patientId, 'book', 'appointment.create');
    const [doctor] = await db.select().from(providers).where(eq(providers.id, body.doctorId));
    if (!doctor || !isBookableDoctor(doctor)) throw errors.notFound('Doctor');
    if (!doctor.acceptingBookings) throw errors.conflict('This doctor is not accepting new bookings');
    const fee = feeForMode(doctor, body.mode);
    if (fee === null) throw errors.validation(`Doctor does not offer ${body.mode} consultations`);
    const now = new Date();
    const appointmentId = randomUUID();
    const [wanted] = await db.select({ modes: slots.modes, doctorId: slots.doctorId }).from(slots).where(eq(slots.id, body.slotId));
    if (wanted && wanted.doctorId === body.doctorId && !wanted.modes.includes(body.mode)) {
      throw errors.validation(`This slot does not offer ${body.mode} consultations`, { modes: wanted.modes });
    }

    let result;
    try {
      result = await db.transaction(async (tx) => {
        // Concurrency-safe reservation: conditional update + partial unique index on appointments(slot_id).
        const reserved = await tx
          .update(slots)
          .set({ status: 'held' })
          .where(and(eq(slots.id, body.slotId), eq(slots.doctorId, body.doctorId), eq(slots.status, 'available'), sql`${slots.startAt} > ${now}`))
          .returning();
        if (!reserved.length) throw new AppError('SLOT_UNAVAILABLE', 'This slot is no longer available');
        const slot = reserved[0];
        let episodeId = body.careEpisodeId;
        if (episodeId) {
          const [ep] = await tx.select().from(careEpisodes).where(eq(careEpisodes.id, episodeId));
          if (!ep || ep.patientId !== body.patientId) throw errors.validation('careEpisodeId does not belong to this patient');
          if (!ACTIVE_STATUSES.includes(ep.status as never)) throw errors.conflict('Care episode is closed', { status: ep.status });
        } else {
          const ep = await createEpisode(tx, { patientId: body.patientId, title: body.reason, concern: body.reason, actor: req.ctx.actor });
          episodeId = ep.id;
        }
        const [appt] = await tx
          .insert(appointments)
          .values({
            id: appointmentId,
            patientId: body.patientId,
            doctorId: body.doctorId,
            slotId: slot.id,
            startAt: slot.startAt,
            endAt: slot.endAt,
            mode: body.mode,
            reason: body.reason,
            fee,
            careEpisodeId: episodeId,
            createdByUserId: req.ctx.user.id,
          })
          .returning();
        const payment = await svc.payments.create(tx, {
          purpose: 'appointment',
          refId: appt.id,
          patientId: body.patientId,
          amount: fee,
          userId: req.ctx.user.id,
          couponCode: body.couponCode,
          useWallet: body.useWallet,
          actor: req.ctx.actor,
        });
        await addEvent(tx, episodeId, 'appointment_booked', `Appointment booked with ${doctor.name}`, req.ctx.actor, {
          appointmentId: appt.id,
          mode: body.mode,
        });
        await audit(tx, req.ctx.actor, { action: 'appointment.create', entityType: 'appointment', entityId: appt.id, metadata: { patientId: body.patientId } });
        return { appt, payment };
      });
    } catch (err) {
      if (isUniqueViolation(err)) throw new AppError('SLOT_UNAVAILABLE', 'This slot is no longer available');
      throw err;
    }
    // Contract section 60: a payment fully covered by coupon/wallet succeeds immediately (confirming the booking).
    const payment = await svc.payments.settleIfCovered(result.payment, req.ctx.actor);
    const appt = payment === result.payment ? result.appt : (await db.select().from(appointments).where(eq(appointments.id, result.appt.id)))[0];
    return reply.code(201).send({ appointment: await toAppointment(db, appt), payment: toPayment(payment) });
  });

  app.get('/appointments', async (req) => {
    const q = parse(z.object({ patientId: zUuid.optional(), scope: z.enum(['upcoming', 'past']).optional() }), req.query);
    const page = pageFromQuery(req.query);
    let patientIds: string[];
    if (q.patientId) {
      await assertCanActForPatient(db, req.ctx, q.patientId, [...readPerms], 'appointment.list');
      patientIds = [q.patientId];
    } else {
      patientIds = (await listActablePatients(db, req.ctx.user))
        .filter((p) => p.permissions.some((x) => x === 'book' || x === 'view_records' || x === 'manage_care'))
        .map((p) => p.patientId);
    }
    if (!patientIds.length) return { items: [], nextCursor: null };
    const now = new Date();
    const conds = [inArray(appointments.patientId, patientIds)];
    if (q.scope === 'upcoming') {
      conds.push(gte(appointments.endAt, now), inArray(appointments.status, ['pending_payment', 'confirmed', 'in_progress']));
    } else if (q.scope === 'past') {
      conds.push(or(lt(appointments.endAt, now), inArray(appointments.status, ['completed', 'cancelled', 'no_show']))!);
    }
    const rows = await db
      .select()
      .from(appointments)
      .where(and(...conds))
      .orderBy(q.scope === 'past' ? desc(appointments.startAt) : asc(appointments.startAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toAppointments(db, rows), page);
  });

  const loadForPatient = async (id: string, perms: Perm | Perm[], action: string, reqCtx: RequestCtx) => {
    const [a] = await db.select().from(appointments).where(eq(appointments.id, id));
    if (!a) throw errors.notFound('Appointment');
    await assertCanActForPatient(db, reqCtx, a.patientId, perms, action);
    return a;
  };

  app.get('/appointments/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const a = await loadForPatient(id, [...readPerms], 'appointment.read', req.ctx);
    return toAppointment(db, a);
  });

  app.post('/appointments/:id/cancel', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ reason: z.string().trim().min(1).max(500), refundTo: zRefundTo.optional() }), req.body);
    const a = await loadForPatient(id, 'book', 'appointment.cancel', req.ctx);
    if (!['pending_payment', 'confirmed'].includes(a.status)) throw errors.invalidTransition(a.status, 'cancelled');
    const updated = await cancelAppointment(db, svc.payments, a, body.reason, req.ctx.actor, body.refundTo === 'wallet');
    const [d] = await db.select({ name: providers.name }).from(providers).where(eq(providers.id, a.doctorId));
    await svc.notify.notifyPatient(a.patientId, {
      template: 'appointment_cancelled',
      params: { doctor: d?.name ?? 'your doctor', when: a.startAt.toISOString().slice(0, 16).replace('T', ' ') },
      category: 'appointment',
      deepLink: `/appointments/${a.id}`,
    });
    return toAppointment(db, updated);
  });

  app.post('/appointments/:id/reschedule', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ slotId: zUuid }), req.body);
    const a = await loadForPatient(id, 'book', 'appointment.reschedule', req.ctx);
    if (!['pending_payment', 'confirmed'].includes(a.status)) throw errors.invalidTransition(a.status, 'rescheduled');
    if (body.slotId === a.slotId) return toAppointment(db, a);
    const [target] = await db.select({ modes: slots.modes }).from(slots).where(eq(slots.id, body.slotId));
    if (target && !target.modes.includes(a.mode)) throw errors.validation(`This slot does not offer ${a.mode} consultations`, { modes: target.modes });
    const now = new Date();
    let updated;
    try {
      updated = await db.transaction(async (tx) => {
        const reserved = await tx
          .update(slots)
          .set({ status: a.status === 'confirmed' ? 'booked' : 'held' })
          .where(and(eq(slots.id, body.slotId), eq(slots.doctorId, a.doctorId), eq(slots.status, 'available'), sql`${slots.startAt} > ${now}`))
          .returning();
        if (!reserved.length) throw new AppError('SLOT_UNAVAILABLE', 'This slot is no longer available');
        await releaseSlot(tx, a.slotId);
        const [row] = await tx
          .update(appointments)
          .set({ slotId: reserved[0].id, startAt: reserved[0].startAt, endAt: reserved[0].endAt, updatedAt: new Date(), reminderSentAt: null })
          .where(eq(appointments.id, a.id))
          .returning();
        await addEvent(tx, a.careEpisodeId, 'appointment_rescheduled', 'Appointment rescheduled', req.ctx.actor, { appointmentId: a.id });
        await audit(tx, req.ctx.actor, { action: 'appointment.reschedule', entityType: 'appointment', entityId: a.id });
        return row;
      });
    } catch (err) {
      if (isUniqueViolation(err)) throw new AppError('SLOT_UNAVAILABLE', 'This slot is no longer available');
      throw err;
    }
    return toAppointment(db, updated);
  });
}

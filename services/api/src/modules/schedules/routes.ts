import { and, eq } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { doctorLeaves, providers } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { istDate } from '../../lib/time.js';
import { parse, zDate, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { toAppointments } from '../appointments/service.js';
import { doctorDetail } from '../doctors/routes.js';
import {
  appointmentsOnDate,
  getSchedule,
  loadDoctor,
  lockDoctor,
  regenerateSlots,
  saveWeekly,
  toLeave,
  validateWeekly,
  zScheduleBody,
} from './service.js';

const zFee = z.number().int().min(0).max(100_000).nullable();

/** Contract section 29: doctor self-management (profile, weekly schedule, leaves) and admin schedule endpoints. */
export async function scheduleRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const horizon = svc.config.SCHEDULE_HORIZON_DAYS;
  const doctorOnly = requireRoles(svc, 'doctor');
  const adminGuard = requireRoles(svc, 'super_admin', 'ops_admin');

  const myDoctorId = async (req: FastifyRequest): Promise<string> => {
    const id = req.ctx.user.providerId;
    if (!id) throw errors.forbidden('Doctor profile required');
    await loadDoctor(db, id);
    return id;
  };

  const profile = async (doctorId: string) => {
    const d = await loadDoctor(db, doctorId);
    return { ...(await doctorDetail(db, d)), acceptingBookings: d.acceptingBookings };
  };

  app.get('/doctor/me/profile', { preHandler: doctorOnly }, async (req) => profile(await myDoctorId(req)));

  app.patch('/doctor/me/profile', { preHandler: doctorOnly }, async (req) => {
    const id = await myDoctorId(req);
    const body = parse(
      z.object({
        bio: z.string().trim().max(2000).optional(),
        languages: z.array(z.string().trim().min(1).max(40)).max(12).optional(),
        qualifications: z.string().trim().min(1).max(200).optional(),
        fees: z.object({ video: zFee, audio: zFee, chat: zFee, inClinic: zFee }).optional(),
        acceptingBookings: z.boolean().optional(),
      }),
      req.body,
    );
    const patch: Partial<typeof providers.$inferInsert> = {};
    if (body.bio !== undefined) patch.bio = body.bio;
    if (body.languages !== undefined) patch.languages = [...new Set(body.languages)];
    if (body.qualifications !== undefined) patch.qualification = body.qualifications;
    if (body.fees) {
      patch.feeVideo = body.fees.video;
      patch.feeAudio = body.fees.audio;
      patch.feeChat = body.fees.chat;
      patch.feeInClinic = body.fees.inClinic;
    }
    if (body.acceptingBookings !== undefined) patch.acceptingBookings = body.acceptingBookings;
    if (Object.keys(patch).length) {
      await db.update(providers).set(patch).where(eq(providers.id, id));
      await audit(db, req.ctx.actor, { action: 'doctor.profile_update', entityType: 'provider', entityId: id, metadata: { fields: Object.keys(body) } });
    }
    return profile(id);
  });

  const putSchedule = async (req: FastifyRequest, doctorId: string) => {
    const body = parse(zScheduleBody, req.body);
    const weekly = validateWeekly(body.weekly);
    const res = await db.transaction(async (tx) => {
      await lockDoctor(tx, doctorId);
      await saveWeekly(tx, doctorId, weekly, req.ctx.user.id);
      const r = await regenerateSlots(tx, doctorId, { horizonDays: horizon });
      await audit(tx, req.ctx.actor, { action: 'doctor.schedule_update', entityType: 'provider', entityId: doctorId, metadata: { blocks: weekly.length, ...r } });
      return r;
    });
    req.log.debug({ doctorId, ...res }, 'slots regenerated');
    return getSchedule(db, doctorId, horizon);
  };

  app.get('/doctor/me/schedule', { preHandler: doctorOnly }, async (req) => getSchedule(db, await myDoctorId(req), horizon));
  app.put('/doctor/me/schedule', { preHandler: doctorOnly }, async (req) => putSchedule(req, await myDoctorId(req)));

  app.post('/doctor/me/leaves', { preHandler: doctorOnly }, async (req, reply) => {
    const doctorId = await myDoctorId(req);
    const body = parse(z.object({ date: zDate, reason: z.string().trim().max(300).optional() }), req.body);
    if (body.date < istDate()) throw errors.validation('Leave date must be today or later');
    const leave = await db.transaction(async (tx) => {
      await lockDoctor(tx, doctorId);
      const [row] = await tx
        .insert(doctorLeaves)
        .values({ doctorId, date: body.date, reason: body.reason ?? null, createdByUserId: req.ctx.user.id })
        .onConflictDoNothing()
        .returning();
      if (!row) throw errors.conflict('A leave already exists for this date');
      await regenerateSlots(tx, doctorId, { horizonDays: horizon });
      await audit(tx, req.ctx.actor, { action: 'doctor.leave_create', entityType: 'provider', entityId: doctorId, metadata: { date: body.date } });
      return row;
    });
    const conflicts = await toAppointments(db, await appointmentsOnDate(db, doctorId, body.date));
    return reply.code(201).send({ leave: toLeave(leave), conflicts });
  });

  app.delete('/doctor/me/leaves/:id', { preHandler: doctorOnly }, async (req, reply) => {
    const doctorId = await myDoctorId(req);
    const { id } = parse(z.object({ id: zUuid }), req.params);
    await db.transaction(async (tx) => {
      await lockDoctor(tx, doctorId);
      const del = await tx
        .delete(doctorLeaves)
        .where(and(eq(doctorLeaves.id, id), eq(doctorLeaves.doctorId, doctorId)))
        .returning({ date: doctorLeaves.date });
      if (!del.length) throw errors.notFound('Leave');
      await regenerateSlots(tx, doctorId, { horizonDays: horizon });
      await audit(tx, req.ctx.actor, { action: 'doctor.leave_delete', entityType: 'provider', entityId: doctorId, metadata: { date: del[0].date } });
    });
    return reply.code(204).send();
  });

  app.get('/admin/doctors/:doctorId/schedule', { preHandler: adminGuard }, async (req) => {
    const { doctorId } = parse(z.object({ doctorId: zUuid }), req.params);
    await loadDoctor(db, doctorId);
    return getSchedule(db, doctorId, horizon);
  });

  app.put('/admin/doctors/:doctorId/schedule', { preHandler: adminGuard }, async (req) => {
    const { doctorId } = parse(z.object({ doctorId: zUuid }), req.params);
    await loadDoctor(db, doctorId);
    return putSchedule(req, doctorId);
  });
}

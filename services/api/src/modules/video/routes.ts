import { and, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { appointments, familyAccessGrants, patients } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { VIDEO_CLOSES_AFTER_MS, VIDEO_OPENS_BEFORE_MS } from './provider.js';

/**
 * GET /appointments/:id/video-session (contract section 26).
 * Allowed: the appointment's doctor, the patient (self or managing guardian) and family grantees with
 * `manage_care`. Other doctors with a care relationship to the patient are NOT allowed to join.
 */
export async function videoRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/appointments/:id/video-session', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [a] = await db.select().from(appointments).where(eq(appointments.id, id));
    if (!a) throw errors.notFound('Appointment');
    const user = req.ctx.user;

    let role: 'doctor' | 'patient' | 'family' | null = null;
    if (user.providerId && user.providerId === a.doctorId) role = 'doctor';
    else {
      const [p] = await db.select({ userId: patients.userId, ownerUserId: patients.ownerUserId }).from(patients).where(eq(patients.id, a.patientId));
      if (p && (p.userId === user.id || p.ownerUserId === user.id)) role = 'patient';
      else {
        const grants = await db
          .select({ permissions: familyAccessGrants.permissions })
          .from(familyAccessGrants)
          .where(and(eq(familyAccessGrants.patientId, a.patientId), eq(familyAccessGrants.granteeUserId, user.id), eq(familyAccessGrants.status, 'active')));
        if (grants.some((g) => g.permissions.includes('manage_care'))) role = 'family';
      }
    }
    if (!role) {
      await audit(db, req.ctx.actor, { action: 'video.session', entityType: 'appointment', entityId: a.id, outcome: 'denied' });
      throw errors.forbidden();
    }
    if (a.mode !== 'video' && a.mode !== 'audio') throw errors.conflict('Video sessions are only available for video and audio consultations', { mode: a.mode });
    if (a.status !== 'confirmed' && a.status !== 'in_progress') throw errors.conflict('This appointment is not confirmed', { status: a.status });

    const opensAt = new Date(a.startAt.getTime() - VIDEO_OPENS_BEFORE_MS);
    const expiresAt = new Date(a.endAt.getTime() + VIDEO_CLOSES_AFTER_MS);
    const now = Date.now();
    if (now < opensAt.getTime()) throw errors.conflict('The consultation room is not open yet', { opensAt: iso(opensAt) });
    if (now > expiresAt.getTime()) throw errors.conflict('The consultation room has closed', { opensAt: iso(opensAt), expiresAt: iso(expiresAt) });

    const session = await svc.video.session({
      appointmentId: a.id,
      mode: a.mode,
      participant: { userId: user.id, name: user.name, moderator: role === 'doctor' },
      notBefore: opensAt,
      expiresAt,
    });
    // Keep Appointment.videoRoomUrl consistent with the active provider (no credentials stored).
    const roomUrl = svc.video.roomUrl(a.id, a.mode);
    if (a.videoRoomUrl !== roomUrl) await db.update(appointments).set({ videoRoomUrl: roomUrl }).where(eq(appointments.id, a.id));
    await audit(db, req.ctx.actor, { action: 'video.session', entityType: 'appointment', entityId: a.id, metadata: { role, provider: session.provider } });
    return { ...session, opensAt: iso(opensAt), expiresAt: iso(expiresAt) };
  });
}

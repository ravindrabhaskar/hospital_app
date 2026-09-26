import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { sosEvents } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { parse, zUuid } from '../../lib/validate.js';
import { alertEmergencyContacts, nearestEmergencyFacilities, openEmergency } from './service.js';

export async function emergencyRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.post('/emergency/sos', { config: { idempotent: true } }, async (req, reply) => {
    const body = parse(
      z.object({ patientId: zUuid, lat: z.number().min(-90).max(90).optional(), lng: z.number().min(-180).max(180).optional(), note: z.string().max(500).optional() }),
      req.body,
    );
    // Any relationship may raise SOS for a patient (safety first).
    await assertCanActForPatient(db, req.ctx, body.patientId, 'any', 'sos.create');
    const sosId = randomUUID();
    const em = await db.transaction(async (tx) => {
      const r = await openEmergency(svc, tx, {
        patientId: body.patientId,
        title: 'SOS emergency',
        concern: 'SOS button pressed',
        source: 'sos',
        rule: { ruleId: 'sos.pressed', title: 'SOS pressed by user' },
        actor: req.ctx.actor,
      });
      await tx.insert(sosEvents).values({
        id: sosId,
        patientId: body.patientId,
        careEpisodeId: r.episodeId,
        lat: body.lat ?? null,
        lng: body.lng ?? null,
        note: body.note ?? null,
        createdByUserId: req.ctx.user.id,
      });
      await audit(tx, req.ctx.actor, { action: 'sos.create', entityType: 'sos_event', entityId: sosId, metadata: { patientId: body.patientId } });
      return r;
    });
    const notifiedContacts = await alertEmergencyContacts(svc, body.patientId, 'sos', `/care-episodes/${em.episodeId}`);
    return reply.code(201).send({
      sosId,
      careEpisodeId: em.episodeId,
      helpline: '108',
      notifiedContacts,
      nearestEmergencyFacilities: await nearestEmergencyFacilities(svc, body.lat, body.lng),
    });
  });
}

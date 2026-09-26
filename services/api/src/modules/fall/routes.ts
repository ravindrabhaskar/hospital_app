import { eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { fallEvents } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { escalateFall } from '../emergency/service.js';

const toFall = (f: typeof fallEvents.$inferSelect) => ({
  id: f.id,
  patientId: f.patientId,
  status: f.status,
  source: f.source,
  createdAt: iso(f.createdAt),
  respondedAt: iso(f.respondedAt),
});

export async function fallRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.post('/fall-events', async (req, reply) => {
    await svc.flags.require('fall_detection');
    const body = parse(
      z.object({
        patientId: zUuid,
        source: z.enum(['phone_sensor', 'wearable', 'manual']),
        lat: z.number().min(-90).max(90).optional(),
        lng: z.number().min(-180).max(180).optional(),
      }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, body.patientId, ['manage_care', 'receive_alerts'], 'fall.create');
    const [row] = await db
      .insert(fallEvents)
      .values({ patientId: body.patientId, source: body.source, lat: body.lat ?? null, lng: body.lng ?? null, createdByUserId: req.ctx.user.id })
      .returning();
    await audit(db, req.ctx.actor, { action: 'fall.create', entityType: 'fall_event', entityId: row.id, metadata: { source: body.source } });
    return reply.code(201).send(toFall(row));
  });

  app.post('/fall-events/:id/respond', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ safe: z.boolean() }), req.body);
    const [f] = await db.select().from(fallEvents).where(eq(fallEvents.id, id));
    if (!f) throw errors.notFound('Fall event');
    await assertCanActForPatient(db, req.ctx, f.patientId, ['manage_care', 'receive_alerts'], 'fall.respond');
    if (f.status !== 'awaiting_response') return toFall(f);
    if (body.safe) {
      const [row] = await db.update(fallEvents).set({ status: 'closed_safe', respondedAt: new Date() }).where(eq(fallEvents.id, id)).returning();
      await audit(db, req.ctx.actor, { action: 'fall.respond_safe', entityType: 'fall_event', entityId: id });
      return toFall(row);
    }
    await db.update(fallEvents).set({ respondedAt: new Date() }).where(eq(fallEvents.id, id));
    await escalateFall(svc, id, req.ctx.actor);
    const [row] = await db.select().from(fallEvents).where(eq(fallEvents.id, id));
    return toFall(row);
  });
}

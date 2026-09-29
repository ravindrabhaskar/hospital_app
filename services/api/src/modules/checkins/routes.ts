import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { checkinSettings } from '../../db/schema.js';
import { assertCanActForPatient, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { list } from '../../lib/pagination.js';
import { parse, zUuid } from '../../lib/validate.js';
import { checkinHistory, getSettings, recordCheckin, toCheckin, toSettings } from './service.js';

export const zHHMM = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Expected HH:MM');
const READ: Perm[] = ['view_records', 'manage_care', 'receive_alerts', 'staff_ops'];

/** Contract section 41: daily "I'm OK" check-in. */
export async function checkinRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/patients/:id/checkin-settings', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, id, READ, 'checkin.settings.read');
    return toSettings(id, await getSettings(db, id));
  });

  app.put('/patients/:id/checkin-settings', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(
      z.object({
        enabled: z.boolean(),
        windowStart: zHHMM,
        windowEnd: zHHMM,
        escalateAfterMins: z.number().int().min(5).max(24 * 60),
        notifyFamily: z.boolean(),
        notifyCoordinator: z.boolean(),
      }),
      req.body,
    );
    if (body.windowEnd <= body.windowStart) throw errors.validation('windowEnd must be after windowStart', { field: 'windowEnd' });
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'checkin.settings.update');
    const existing = await getSettings(db, id);
    const values = { ...body, updatedByUserId: req.ctx.user.id, updatedAt: new Date() };
    const [row] = await db
      .insert(checkinSettings)
      .values({ patientId: id, ...values })
      .onConflictDoUpdate({
        target: checkinSettings.patientId,
        // Keep the "enabled since" date when only the window changes.
        set: { ...values, updatedAt: existing?.enabled && body.enabled ? existing.updatedAt : new Date(), activeUntil: body.enabled ? (existing?.activeUntil ?? null) : null },
      })
      .returning();
    await audit(db, req.ctx.actor, { action: 'checkin.settings.update', entityType: 'patient', entityId: id, metadata: { enabled: body.enabled } });
    return toSettings(id, row);
  });

  app.post('/patients/:id/checkins', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ mood: z.number().int().min(1).max(5).optional(), note: z.string().trim().max(500).optional() }), req.body);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'checkin.create');
    const row = await recordCheckin(svc, { patientId: id, mood: body.mood, note: body.note, source: 'app', actor: req.ctx.actor, userId: req.ctx.user.id });
    return reply.code(201).send(toCheckin(row));
  });

  app.get('/patients/:id/checkins', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const q = parse(z.object({ days: z.coerce.number().int().min(1).max(90).default(30) }), req.query);
    await assertCanActForPatient(db, req.ctx, id, READ, 'checkin.list');
    return list(await checkinHistory(db, id, q.days));
  });
}

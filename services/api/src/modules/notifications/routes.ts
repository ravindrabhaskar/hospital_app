import { and, count, desc, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { devices, notificationPreferences, notifications } from '../../db/schema.js';
import { errors } from '../../lib/errors.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { parse, zUuid } from '../../lib/validate.js';
import { DEFAULT_PREFS, toNotification } from './service.js';

const zPrefs = z.object({ push: z.boolean(), sms: z.boolean(), email: z.boolean(), whatsapp: z.boolean(), marketing: z.boolean() });

export async function notificationRoutes(app: FastifyInstance): Promise<void> {
  const db = app.svc.db;

  app.get('/notifications', async (req, reply) => {
    const page = pageFromQuery(req.query);
    const uid = req.ctx.user.id;
    const rows = await db
      .select()
      .from(notifications)
      .where(eq(notifications.userId, uid))
      .orderBy(desc(notifications.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    const [unread] = await db
      .select({ n: count() })
      .from(notifications)
      .where(and(eq(notifications.userId, uid), eq(notifications.read, false)));
    reply.header('X-Unread-Count', String(Number(unread?.n ?? 0)));
    return envelope(rows.map(toNotification), page);
  });

  app.post('/notifications/:id/read', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [row] = await db
      .update(notifications)
      .set({ read: true })
      .where(and(eq(notifications.id, id), eq(notifications.userId, req.ctx.user.id)))
      .returning();
    if (!row) throw errors.notFound('Notification');
    return toNotification(row);
  });

  app.post('/notifications/read-all', async (req, reply) => {
    await db.update(notifications).set({ read: true }).where(and(eq(notifications.userId, req.ctx.user.id), eq(notifications.read, false)));
    return reply.code(204).send();
  });

  app.post('/devices', async (req, reply) => {
    const body = parse(z.object({ pushToken: z.string().min(10).max(4096), platform: z.enum(['android', 'ios', 'web']) }), req.body);
    await db
      .insert(devices)
      .values({ userId: req.ctx.user.id, pushToken: body.pushToken, platform: body.platform })
      .onConflictDoUpdate({ target: devices.pushToken, set: { userId: req.ctx.user.id, platform: body.platform } });
    return reply.code(204).send();
  });

  // Contract section 24: clients call this on logout so the token stops receiving pushes.
  app.delete('/devices', async (req, reply) => {
    const body = parse(z.object({ pushToken: z.string().min(10).max(4096) }), req.body);
    await db.delete(devices).where(and(eq(devices.pushToken, body.pushToken), eq(devices.userId, req.ctx.user.id)));
    return reply.code(204).send();
  });

  app.get('/notification-preferences', async (req) => {
    const [p] = await db.select().from(notificationPreferences).where(eq(notificationPreferences.userId, req.ctx.user.id));
    const v = p ?? { ...DEFAULT_PREFS };
    return { push: v.push, sms: v.sms, email: v.email, whatsapp: v.whatsapp, marketing: v.marketing };
  });

  app.put('/notification-preferences', async (req) => {
    const body = parse(zPrefs, req.body);
    await db
      .insert(notificationPreferences)
      .values({ userId: req.ctx.user.id, ...body })
      .onConflictDoUpdate({ target: notificationPreferences.userId, set: body });
    return body;
  });
}

import { and, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { dataExports } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { parse, zUuid } from '../../lib/validate.js';
import { cancelDeletion, createDataExport, latestDeletionRequest, scheduleDeletion, toDataExport, toDeletionRequest } from './service.js';

/** Account deletion + data export (contract section 23). */
export async function accountRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/me/deletion-request', async (req) => {
    const r = await latestDeletionRequest(db, req.ctx.user.id);
    if (!r) throw errors.notFound('Deletion request');
    return toDeletionRequest(r);
  });

  app.post('/me/deletion-request', async (req, reply) => {
    const body = parse(z.object({ reason: z.string().trim().max(500).optional() }), req.body);
    const { row, created } = await scheduleDeletion(svc, req.ctx.user, body.reason || null, req.ctx.actor);
    return reply.code(created ? 201 : 200).send(toDeletionRequest(row));
  });

  app.post('/me/deletion-request/cancel', async (req) => toDeletionRequest(await cancelDeletion(svc, req.ctx.user.id, req.ctx.actor)));

  app.post('/me/data-export', async (req, reply) => {
    const row = await createDataExport(svc, req.ctx.user.id, req.ctx.user.sessionId, req.ctx.actor);
    return reply.code(201).send(toDataExport(row));
  });

  app.get('/me/data-export/:id/file', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    // Scoped to the caller: another user's export id is indistinguishable from a missing one.
    const [e] = await db.select().from(dataExports).where(and(eq(dataExports.id, id), eq(dataExports.userId, req.ctx.user.id)));
    if (!e || !e.storageKey || e.purgedAt || e.expiresAt.getTime() < Date.now()) {
      await audit(db, req.ctx.actor, { action: 'account.data_export_download', entityType: 'data_export', entityId: id, outcome: 'denied' });
      throw errors.notFound('Data export');
    }
    const stream = await svc.storage.getStream(e.storageKey);
    await audit(db, req.ctx.actor, { action: 'account.data_export_download', entityType: 'data_export', entityId: id });
    return reply
      .header('content-type', 'application/json; charset=utf-8')
      .header('content-disposition', `attachment; filename="carecompanion-export-${e.createdAt.toISOString().slice(0, 10)}.json"`)
      .header('content-length', String(e.sizeBytes))
      .header('cache-control', 'private, no-store')
      .send(stream);
  });
}

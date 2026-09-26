import { and, eq } from 'drizzle-orm';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import type { Db } from '../db/client.js';
import { idempotencyKeys } from '../db/schema.js';
import { sha256 } from './crypto.js';
import { AppError, errors } from './errors.js';

/**
 * Idempotency for routes declared with `config: { idempotent: true }`.
 * Stores (userId, key, route) -> response. A replay with the same key and body returns the
 * stored response verbatim; a different body returns IDEMPOTENCY_MISMATCH; a concurrent
 * in-flight duplicate returns CONFLICT. Non-2xx outcomes release the key so clients may retry.
 */
export function registerIdempotency(app: FastifyInstance, db: Db): void {
  app.addHook('preHandler', async (req: FastifyRequest, reply: FastifyReply) => {
    const mode = (req.routeOptions.config as { idempotent?: boolean | 'optional' } | undefined)?.idempotent;
    if (!mode) return;
    const user = req.ctx?.user;
    if (!user) return;
    const key = req.headers['idempotency-key'];
    if (mode === 'optional' && key === undefined) return;
    if (typeof key !== 'string' || key.length === 0 || key.length > 128) {
      throw errors.validation('Idempotency-Key header is required (1-128 chars)');
    }
    const route = `${req.method} ${req.url.split('?')[0]}`;
    const requestHash = sha256(JSON.stringify(req.body ?? null));
    const where = and(eq(idempotencyKeys.userId, user.id), eq(idempotencyKeys.key, key), eq(idempotencyKeys.route, route));
    const [existing] = await db.select().from(idempotencyKeys).where(where).limit(1);
    if (existing) {
      if (existing.requestHash !== requestHash) {
        throw new AppError('IDEMPOTENCY_MISMATCH', 'Idempotency-Key was reused with a different request body');
      }
      if (existing.state === 'completed') {
        reply.header('idempotent-replayed', 'true');
        reply.code(existing.statusCode ?? 200).send(existing.response);
        return reply;
      }
      throw errors.conflict('A request with this Idempotency-Key is already in progress');
    }
    const inserted = await db
      .insert(idempotencyKeys)
      .values({ userId: user.id, key, route, requestHash })
      .onConflictDoNothing()
      .returning({ id: idempotencyKeys.id });
    if (!inserted.length) throw errors.conflict('A request with this Idempotency-Key is already in progress');
    req.idempotencyRowId = inserted[0].id;
  });

  app.addHook('onSend', async (req, reply, payload) => {
    const rowId = req.idempotencyRowId;
    if (!rowId) return payload;
    req.idempotencyRowId = undefined;
    if (reply.statusCode >= 200 && reply.statusCode < 300) {
      let body: unknown;
      try {
        body = typeof payload === 'string' ? JSON.parse(payload) : null;
      } catch {
        body = null;
      }
      await db
        .update(idempotencyKeys)
        .set({ state: 'completed', statusCode: reply.statusCode, response: body })
        .where(eq(idempotencyKeys.id, rowId));
    } else {
      await db.delete(idempotencyKeys).where(eq(idempotencyKeys.id, rowId));
    }
    return payload;
  });
}

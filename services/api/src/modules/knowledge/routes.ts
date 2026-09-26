import { count, desc, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { knowledgeChunks, knowledgeSources } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { parse, zDate, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';

async function toSource(db: DbOrTx, s: typeof knowledgeSources.$inferSelect) {
  const [c] = await db.select({ n: count() }).from(knowledgeChunks).where(eq(knowledgeChunks.sourceId, s.id));
  return {
    id: s.id,
    title: s.title,
    owner: s.owner,
    version: s.version,
    status: s.status,
    effectiveDate: s.effectiveDate,
    expiresAt: s.expiresAt,
    chunkCount: Number(c?.n ?? 0),
  };
}

export async function knowledgeAdminRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  app.addHook('preHandler', requireRoles(svc, 'super_admin'));

  app.get('/admin/knowledge-sources', async (req) => {
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(knowledgeSources).orderBy(desc(knowledgeSources.createdAt));
    const items = [];
    for (const r of rows) items.push(await toSource(db, r));
    return paginateArray(items, page);
  });

  app.post('/admin/knowledge-sources', async (req, reply) => {
    const body = parse(
      z.object({
        title: z.string().trim().min(1).max(200),
        owner: z.string().trim().min(1).max(200),
        version: z.string().trim().min(1).max(40),
        effectiveDate: zDate,
        expiresAt: zDate.optional(),
        content: z.string().trim().min(1).max(200_000),
      }),
      req.body,
    );
    const row = await db.transaction(async (tx) => {
      const [s] = await tx
        .insert(knowledgeSources)
        .values({ ...body, expiresAt: body.expiresAt ?? null, status: 'draft' })
        .returning();
      await svc.knowledge.indexSource(tx, s.id, body.content);
      await audit(tx, req.ctx.actor, { action: 'knowledge.create', entityType: 'knowledge_source', entityId: s.id });
      return s;
    });
    return reply.code(201).send(await toSource(db, row));
  });

  app.post('/admin/knowledge-sources/:id/status', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ status: z.enum(['draft', 'approved', 'deprecated']) }), req.body);
    const [row] = await db.update(knowledgeSources).set({ status: body.status }).where(eq(knowledgeSources.id, id)).returning();
    if (!row) throw errors.notFound('Knowledge source');
    await audit(db, req.ctx.actor, { action: 'knowledge.status', entityType: 'knowledge_source', entityId: id, metadata: { status: body.status } });
    return toSource(db, row);
  });
}

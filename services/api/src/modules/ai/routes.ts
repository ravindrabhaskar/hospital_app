import { and, desc, eq, inArray } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { conversations } from '../../db/schema.js';
import { assertCanActForPatient, listActablePatients } from '../../lib/access.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { parse, zUuid } from '../../lib/validate.js';
import { requireConsent } from '../consent/routes.js';
import { assertOpen, handleTurn, startConversation, toConversation } from './assistant.js';

export async function aiRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  /** Order matters: authorization, then consent, then feature flag. */
  async function guard(req: FastifyRequest, patientId: string, action: string) {
    await assertCanActForPatient(db, req.ctx, patientId, 'manage_care', action);
    await requireConsent(db, req.ctx.user.id, 'ai_assistance');
    await svc.flags.require('ai_assistant');
  }

  app.get('/ai/conversations', async (req) => {
    const q = parse(z.object({ patientId: zUuid.optional() }), req.query);
    const page = pageFromQuery(req.query);
    let ids: string[];
    if (q.patientId) {
      await guard(req, q.patientId, 'ai.conversation.list');
      ids = [q.patientId];
    } else {
      await requireConsent(db, req.ctx.user.id, 'ai_assistance');
      ids = (await listActablePatients(db, req.ctx.user)).filter((p) => p.permissions.includes('manage_care')).map((p) => p.patientId);
    }
    if (!ids.length) return { items: [], nextCursor: null };
    const rows = await db
      .select()
      .from(conversations)
      .where(and(inArray(conversations.patientId, ids)))
      .orderBy(desc(conversations.updatedAt));
    const items = [];
    for (const c of rows) items.push(await toConversation(db, c, false));
    return paginateArray(items, page);
  });

  app.post('/ai/conversations', async (req, reply) => {
    const body = parse(z.object({ patientId: zUuid }), req.body);
    await guard(req, body.patientId, 'ai.conversation.start');
    const c = await startConversation(svc, req.ctx, body.patientId);
    return reply.code(201).send(await toConversation(db, c));
  });

  const load = async (req: FastifyRequest, id: string, action: string) => {
    const [c] = await db.select().from(conversations).where(eq(conversations.id, id));
    if (!c) throw errors.notFound('Conversation');
    await guard(req, c.patientId, action);
    return c;
  };

  app.get('/ai/conversations/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    return toConversation(db, await load(req, id, 'ai.conversation.read'));
  });

  app.post('/ai/conversations/:id/messages', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ text: z.string().trim().min(1).max(2000), inputMode: z.enum(['text', 'voice']).optional() }), req.body);
    const c = await load(req, id, 'ai.message');
    assertOpen(c);
    if (body.inputMode === 'voice') await svc.flags.require('voice_input');
    return handleTurn(svc, req.ctx, c, body.text);
  });
}

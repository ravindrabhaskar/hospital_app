import { and, asc, eq, ilike, isNull, or } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { schemes } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zIso, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';

/**
 * Contract section 38: government health schemes, INFORMATION ONLY. The API never evaluates or states
 * eligibility; clients must show the disclaimer and link to the official source.
 */
export const SCHEME_DISCLAIMER =
  'Information only. CareCompanion does not decide or confirm eligibility for any scheme. Rules, benefits and documents change; ' +
  'always check the official website or helpline, or visit an empanelled hospital or government facility, before relying on this information.';

type SchemeRow = typeof schemes.$inferSelect;

export const toScheme = (s: SchemeRow) => ({
  id: s.id,
  name: s.name,
  authority: s.authority,
  level: s.level,
  state: s.state,
  summary: s.summary,
  benefits: s.benefits,
  eligibilityHints: s.eligibilityHints,
  documentsTypicallyNeeded: s.documentsTypicallyNeeded,
  officialUrl: s.officialUrl,
  helpline: s.helpline,
  status: s.status,
  lastReviewedAt: iso(s.lastReviewedAt),
  disclaimer: s.disclaimer,
});
/** Admin view adds the editorial note (e.g. "[REQUIRES CONTENT REVIEW] ..."). */
const toAdminScheme = (s: SchemeRow) => ({ ...toScheme(s), internalNote: s.internalNote });

const zList = z.array(z.string().trim().min(1).max(300)).max(20);
const zFields = z.object({
  name: z.string().trim().min(1).max(200),
  authority: z.string().trim().min(1).max(200),
  level: z.enum(['central', 'state']),
  state: z.string().trim().min(1).max(60).nullable(),
  summary: z.string().trim().min(1).max(2000),
  benefits: zList,
  eligibilityHints: zList,
  documentsTypicallyNeeded: zList,
  officialUrl: z.string().url().max(300).refine((u) => u.startsWith('https://'), 'officialUrl must use https'),
  helpline: z.string().trim().max(40).nullable(),
  status: z.enum(['draft', 'published']),
  lastReviewedAt: zIso.optional(),
  disclaimer: z.string().trim().min(1).max(1000).optional(),
  internalNote: z.string().trim().max(2000).nullable().optional(),
});

export async function schemeRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/schemes', async (req) => {
    await svc.flags.require('govt_schemes');
    const q = parse(z.object({ state: z.string().trim().max(60).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const conds = [eq(schemes.status, 'published')];
    // Central schemes apply everywhere; state schemes only for the requested state.
    if (q.state) conds.push(or(eq(schemes.level, 'central'), isNull(schemes.state), ilike(schemes.state, q.state))!);
    const rows = await db
      .select()
      .from(schemes)
      .where(and(...conds))
      .orderBy(asc(schemes.level), asc(schemes.name))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toScheme), page);
  });

  app.get('/schemes/:id', async (req) => {
    await svc.flags.require('govt_schemes');
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [s] = await db.select().from(schemes).where(eq(schemes.id, id));
    if (!s || s.status !== 'published') throw errors.notFound('Scheme');
    return toScheme(s);
  });

  const superOnly = requireRoles(svc, 'super_admin');

  app.get('/admin/schemes', { preHandler: superOnly }, async (req) => {
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(schemes).orderBy(asc(schemes.name)).limit(page.limit + 1).offset(page.offset);
    return envelope(rows.map(toAdminScheme), page);
  });

  app.get('/admin/schemes/:id', { preHandler: superOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [s] = await db.select().from(schemes).where(eq(schemes.id, id));
    if (!s) throw errors.notFound('Scheme');
    return toAdminScheme(s);
  });

  app.post('/admin/schemes', { preHandler: superOnly }, async (req, reply) => {
    const body = parse(zFields, req.body);
    if (body.level === 'state' && !body.state) throw errors.validation('state is required for state schemes', { field: 'state' });
    const [row] = await db
      .insert(schemes)
      .values({
        ...body,
        state: body.level === 'central' ? null : body.state,
        lastReviewedAt: body.lastReviewedAt ? new Date(body.lastReviewedAt) : new Date(),
        disclaimer: body.disclaimer ?? SCHEME_DISCLAIMER,
        internalNote: body.internalNote ?? null,
      })
      .returning();
    await audit(db, req.ctx.actor, { action: 'scheme.create', entityType: 'scheme', entityId: row.id, metadata: { status: row.status } });
    return reply.code(201).send(toAdminScheme(row));
  });

  app.patch('/admin/schemes/:id', { preHandler: superOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(zFields.partial(), req.body);
    const { lastReviewedAt, ...rest } = body;
    const [before] = await db.select().from(schemes).where(eq(schemes.id, id));
    if (!before) throw errors.notFound('Scheme');
    const level = rest.level ?? before.level;
    const state = rest.state !== undefined ? rest.state : before.state;
    if (level === 'state' && !state) throw errors.validation('state is required for state schemes', { field: 'state' });
    if (level === 'central') rest.state = null;
    const [row] = await db
      .update(schemes)
      .set({ ...rest, ...(lastReviewedAt ? { lastReviewedAt: new Date(lastReviewedAt) } : {}), updatedAt: new Date() })
      .where(eq(schemes.id, id))
      .returning();
    if (!row) throw errors.notFound('Scheme');
    await audit(db, req.ctx.actor, { action: 'scheme.update', entityType: 'scheme', entityId: id, metadata: { fields: Object.keys(body) } });
    return toAdminScheme(row);
  });
}

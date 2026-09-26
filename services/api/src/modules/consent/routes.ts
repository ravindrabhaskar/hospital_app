import { and, desc, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { consents } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { list } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { CONSENT_CATALOG } from './catalog.js';

export function toConsent(c: typeof consents.$inferSelect) {
  return {
    id: c.id,
    purpose: c.purpose,
    version: c.version,
    scope: c.scope,
    status: c.status,
    grantedAt: iso(c.grantedAt),
    revokedAt: iso(c.revokedAt),
  };
}

export async function hasConsent(db: DbOrTx, userId: string, purpose: string): Promise<boolean> {
  const [c] = await db
    .select({ id: consents.id })
    .from(consents)
    .where(and(eq(consents.userId, userId), eq(consents.purpose, purpose), eq(consents.status, 'granted')))
    .limit(1);
  return !!c;
}

export async function requireConsent(db: DbOrTx, userId: string, purpose: string): Promise<void> {
  if (!(await hasConsent(db, userId, purpose))) throw errors.consentRequired(purpose);
}

export async function grantConsent(db: DbOrTx, userId: string, purpose: string, version: string) {
  const cat = CONSENT_CATALOG.find((c) => c.purpose === purpose);
  if (!cat) throw errors.validation('Unknown consent purpose', { purpose });
  if (cat.version !== version) throw errors.validation('Consent version mismatch', { expected: cat.version });
  const [existing] = await db
    .select()
    .from(consents)
    .where(and(eq(consents.userId, userId), eq(consents.purpose, purpose), eq(consents.status, 'granted'), eq(consents.version, version)))
    .limit(1);
  if (existing) return existing;
  const [row] = await db.insert(consents).values({ userId, purpose, version, scope: cat.scope, status: 'granted' }).returning();
  return row;
}

export async function consentRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;

  app.get('/consents/catalog', async () =>
    list(CONSENT_CATALOG.map(({ purpose, version, title, description, required }) => ({ purpose, version, title, description, required }))),
  );

  app.get('/consents', async (req) => {
    const rows = await svc.db.select().from(consents).where(eq(consents.userId, req.ctx.user.id)).orderBy(desc(consents.grantedAt));
    return list(rows.map(toConsent));
  });

  app.post('/consents', async (req, reply) => {
    const body = parse(z.object({ purpose: z.string().min(1).max(60), version: z.string().min(1).max(20) }), req.body);
    const row = await svc.db.transaction(async (tx) => {
      const c = await grantConsent(tx, req.ctx.user.id, body.purpose, body.version);
      await audit(tx, req.ctx.actor, { action: 'consent.grant', entityType: 'consent', entityId: c.id, metadata: { purpose: body.purpose, version: body.version } });
      return c;
    });
    return reply.code(201).send(toConsent(row));
  });

  app.post('/consents/:id/revoke', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [c] = await svc.db.select().from(consents).where(eq(consents.id, id));
    if (!c || c.userId !== req.ctx.user.id) throw errors.notFound('Consent');
    if (c.status === 'revoked') return toConsent(c);
    const [row] = await svc.db.update(consents).set({ status: 'revoked', revokedAt: new Date() }).where(eq(consents.id, id)).returning();
    await audit(svc.db, req.ctx.actor, { action: 'consent.revoke', entityType: 'consent', entityId: id, metadata: { purpose: c.purpose } });
    return toConsent(row);
  });
}

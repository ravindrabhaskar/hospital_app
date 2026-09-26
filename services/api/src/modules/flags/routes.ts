import { eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { featureFlags } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { list } from '../../lib/pagination.js';
import { parse } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';

const toFlag = (f: typeof featureFlags.$inferSelect) => ({ key: f.key, enabled: f.enabled, description: f.description, cohort: f.cohort });

export async function flagRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  app.addHook('preHandler', requireRoles(svc, 'super_admin'));

  app.get('/admin/feature-flags', async () => {
    const rows = await db.select().from(featureFlags).orderBy(featureFlags.key);
    return list(rows.map(toFlag));
  });

  app.put('/admin/feature-flags/:key', async (req) => {
    const { key } = parse(z.object({ key: z.string().regex(/^[a-z0-9_]{1,60}$/) }), req.params);
    const body = parse(z.object({ enabled: z.boolean(), cohort: z.string().max(100).nullable().optional() }), req.body);
    const [existing] = await db.select().from(featureFlags).where(eq(featureFlags.key, key));
    if (!existing) throw errors.notFound('Feature flag');
    const [row] = await db
      .update(featureFlags)
      .set({ enabled: body.enabled, ...(body.cohort !== undefined ? { cohort: body.cohort } : {}), updatedAt: new Date() })
      .where(eq(featureFlags.key, key))
      .returning();
    await audit(db, req.ctx.actor, { action: 'feature_flag.update', entityType: 'feature_flag', entityId: key, metadata: { enabled: body.enabled } });
    return toFlag(row);
  });
}

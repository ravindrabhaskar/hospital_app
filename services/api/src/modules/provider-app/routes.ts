import { and, asc, desc, eq, gte, inArray, lt, notInArray } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { homeVisits, providerZones, providers, serviceZones } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import type { RequestCtx } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { istDate, istDayBounds, iso } from '../../lib/time.js';
import { parse } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { toHomeVisits } from '../homevisits/service.js';

export function effectiveVerificationStatus(p: typeof providers.$inferSelect): string {
  if (p.verificationStatus === 'verified' && p.credentialExpiresAt <= new Date()) return 'expired';
  return p.verificationStatus;
}

export async function providerZonesOf(db: DbOrTx, providerId: string) {
  return db
    .select({ id: serviceZones.id, name: serviceZones.name })
    .from(providerZones)
    .innerJoin(serviceZones, eq(serviceZones.id, providerZones.zoneId))
    .where(eq(providerZones.providerId, providerId));
}

async function providerMe(db: DbOrTx, providerId: string) {
  const [p] = await db.select().from(providers).where(eq(providers.id, providerId));
  if (!p) throw errors.notFound('Provider');
  return {
    id: p.id,
    name: p.name,
    type: p.type,
    qualification: p.qualification,
    verificationStatus: effectiveVerificationStatus(p),
    credentialExpiresAt: iso(p.credentialExpiresAt),
    onDuty: p.onDuty,
    zones: await providerZonesOf(db, p.id),
    capabilities: p.capabilities,
    photoUrl: p.photoUrl,
    rating: p.rating,
    ratingCount: p.ratingCount,
  };
}

export async function providerAppRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  app.addHook('preHandler', requireRoles(svc, 'provider'));

  const pid = (ctx: RequestCtx): string => {
    if (!ctx.user.providerId) throw errors.forbidden('Provider profile required');
    return ctx.user.providerId;
  };

  app.get('/provider/me', async (req) => providerMe(db, pid(req.ctx)));

  app.post('/provider/duty', async (req) => {
    const body = parse(z.object({ onDuty: z.boolean() }), req.body);
    const id = pid(req.ctx);
    const [p] = await db.select().from(providers).where(eq(providers.id, id));
    if (body.onDuty && effectiveVerificationStatus(p) !== 'verified') {
      throw errors.forbidden('Only verified providers with a valid credential can go on duty');
    }
    await db.update(providers).set({ onDuty: body.onDuty }).where(eq(providers.id, id));
    await audit(db, req.ctx.actor, { action: 'provider.duty', entityType: 'provider', entityId: id, metadata: { onDuty: body.onDuty } });
    return providerMe(db, id);
  });

  app.get('/provider/visits', async (req) => {
    const q = parse(z.object({ scope: z.enum(['today', 'upcoming', 'completed']).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const id = pid(req.ctx);
    const { start, end } = istDayBounds(istDate());
    const conds = [eq(homeVisits.providerId, id)];
    const scope = q.scope ?? 'today';
    if (scope === 'today') conds.push(gte(homeVisits.preferredStart, start), lt(homeVisits.preferredStart, end), notInArray(homeVisits.status, ['cancelled']));
    if (scope === 'upcoming') conds.push(gte(homeVisits.preferredStart, end), notInArray(homeVisits.status, ['cancelled', 'completed']));
    if (scope === 'completed') conds.push(inArray(homeVisits.status, ['completed']));
    const rows = await db
      .select()
      .from(homeVisits)
      .where(and(...conds))
      .orderBy(scope === 'completed' ? desc(homeVisits.completedAt) : asc(homeVisits.preferredStart))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toHomeVisits(db, rows, () => 'provider'), page);
  });

  app.post('/provider/location', async (req, reply) => {
    const body = parse(z.object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180) }), req.body);
    await db.update(providers).set({ lastLat: body.lat, lastLng: body.lng, lastLocationAt: new Date() }).where(eq(providers.id, pid(req.ctx)));
    return reply.code(204).send();
  });
}

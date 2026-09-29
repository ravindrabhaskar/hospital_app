import { and, count, desc, eq, inArray, isNotNull, or, sql } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Config } from '../../config.js';
import type { DbOrTx } from '../../db/client.js';
import { appointments, facilities, homeVisits, labOrders, media, organizationCodes, organizations, patients, subscriptionPlans, subscriptions, tenants } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { istDate, istToUtc, iso } from '../../lib/time.js';
import { parse, zDate, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { activeSubscriptionOf, subscriptionView } from '../subscriptions/service.js';
import { randomCode } from '../wallet/service.js';

/** Contract sections 57 (corporate plans) and 58 (hospital white-label branding). */
type OrgRow = typeof organizations.$inferSelect;
type TenantRow = typeof tenants.$inferSelect;

const toOrg = (o: OrgRow) => ({
  id: o.id,
  name: o.name,
  contactName: o.contactName,
  contactEmail: o.contactEmail,
  planCode: o.planCode,
  seats: o.seats,
  validFrom: o.validFrom,
  validTo: o.validTo,
  billingNote: o.billingNote,
  createdAt: iso(o.createdAt),
});

export const logoUrl = (config: Config, mediaId: string | null) => (mediaId ? `${config.PUBLIC_API_BASE_URL.replace(/\/$/, '')}/media/${mediaId}` : null);

export const toTenant = (config: Config, t: TenantRow) => ({
  id: t.id,
  code: t.code,
  displayName: t.displayName,
  primaryColor: t.primaryColor,
  logoMediaId: t.logoMediaId,
  logoUrl: logoUrl(config, t.logoMediaId),
  facilityIds: t.facilityIds,
  supportPhone: t.supportPhone,
  supportEmail: t.supportEmail,
  createdAt: iso(t.createdAt),
});

/** PublicConfig.branding for ?tenant=<code> (null when unknown). */
export async function brandingFor(db: DbOrTx, config: Config, code: string | undefined) {
  if (!code) return null;
  const [t] = await db.select().from(tenants).where(eq(tenants.code, code.toLowerCase()));
  if (!t) return null;
  return {
    tenantCode: t.code,
    displayName: t.displayName,
    logoUrl: logoUrl(config, t.logoMediaId),
    primaryColor: t.primaryColor,
    supportPhone: t.supportPhone ?? config.SUPPORT_PHONE,
    supportEmail: t.supportEmail ?? config.SUPPORT_EMAIL,
  };
}

/** The tenant of a facility (a facility belongs to at most one tenant). */
export async function tenantOfFacility(db: DbOrTx, facilityId: string): Promise<TenantRow | null> {
  const [t] = await db.select().from(tenants).where(sql`${tenants.facilityIds} @> ${JSON.stringify([facilityId])}::jsonb`).limit(1);
  return t ?? null;
}

const zOrg = z.object({
  name: z.string().trim().min(1).max(200),
  contactName: z.string().trim().min(1).max(100),
  contactEmail: z.string().trim().email().max(200),
  planCode: z.string().min(1).max(40),
  seats: z.number().int().min(1).max(100_000),
  validFrom: zDate,
  validTo: zDate,
  billingNote: z.string().trim().max(1000).optional(),
});

const zTenant = z.object({
  code: z.string().trim().regex(/^[a-z0-9_-]{2,40}$/),
  displayName: z.string().trim().min(1).max(100),
  primaryColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
  logoMediaId: zUuid.nullable().optional(),
  facilityIds: z.array(zUuid).max(100),
  supportPhone: z.string().trim().max(20).optional(),
  supportEmail: z.string().trim().email().max(200).optional(),
});

export async function enterpriseRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const superOnly = requireRoles(svc, 'super_admin');

  // ---------------------------------------------------------------- organizations (section 57)
  const checkPlan = async (code: string) => {
    const [p] = await db.select({ code: subscriptionPlans.code }).from(subscriptionPlans).where(eq(subscriptionPlans.code, code));
    if (!p) throw errors.validation('Unknown planCode', { field: 'planCode' });
  };

  app.get('/admin/organizations', { preHandler: superOnly }, async (req) => {
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(organizations).orderBy(desc(organizations.createdAt));
    return paginateArray(rows.map(toOrg), page);
  });

  app.post('/admin/organizations', { preHandler: superOnly }, async (req, reply) => {
    const body = parse(zOrg, req.body);
    if (body.validTo < body.validFrom) throw errors.validation('validTo must be after validFrom');
    await checkPlan(body.planCode);
    const [row] = await db.insert(organizations).values({ ...body, billingNote: body.billingNote ?? null }).returning();
    await audit(db, req.ctx.actor, { action: 'organization.create', entityType: 'organization', entityId: row.id });
    return reply.code(201).send(toOrg(row));
  });

  const loadOrg = async (id: string) => {
    const [o] = await db.select().from(organizations).where(eq(organizations.id, id));
    if (!o) throw errors.notFound('Organization');
    return o;
  };

  app.get('/admin/organizations/:id', { preHandler: superOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    return toOrg(await loadOrg(id));
  });

  app.patch('/admin/organizations/:id', { preHandler: superOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(zOrg.partial(), req.body);
    const o = await loadOrg(id);
    if ((body.validTo ?? o.validTo) < (body.validFrom ?? o.validFrom)) throw errors.validation('validTo must be after validFrom');
    if (body.planCode) await checkPlan(body.planCode);
    const [row] = await db.update(organizations).set({ ...body, updatedAt: new Date() }).where(eq(organizations.id, id)).returning();
    await audit(db, req.ctx.actor, { action: 'organization.update', entityType: 'organization', entityId: id, metadata: { fields: Object.keys(body) } });
    return toOrg(row);
  });

  app.post('/admin/organizations/:id/codes', { preHandler: superOnly }, async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ count: z.number().int().min(1).max(500) }), req.body);
    const o = await loadOrg(id);
    const [{ n }] = await db.select({ n: count() }).from(organizationCodes).where(eq(organizationCodes.organizationId, id));
    if (Number(n) + body.count > o.seats) throw errors.conflict('Codes would exceed the number of seats', { seats: o.seats, existing: Number(n) });
    const codes: string[] = [];
    while (codes.length < body.count) {
      const code = randomCode(10);
      const [row] = await db.insert(organizationCodes).values({ organizationId: id, code }).onConflictDoNothing().returning();
      if (row) codes.push(code);
    }
    await audit(db, req.ctx.actor, { action: 'organization.codes', entityType: 'organization', entityId: id, metadata: { count: body.count } });
    return reply.code(201).send({ codes });
  });

  app.get('/admin/organizations/:id/usage', { preHandler: superOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const o = await loadOrg(id);
    const redeemedRows = await db.select({ userId: organizationCodes.redeemedByUserId }).from(organizationCodes).where(and(eq(organizationCodes.organizationId, id), isNotNull(organizationCodes.redeemedByUserId)));
    const userIds = redeemedRows.map((r) => r.userId!);
    const [{ active }] = await db
      .select({ active: count() })
      .from(subscriptions)
      .where(and(eq(subscriptions.sponsorOrgId, id), eq(subscriptions.status, 'active'), sql`${subscriptions.currentPeriodEnd} > now()`));
    let used = { appointments: 0, homeVisits: 0, labOrders: 0 };
    if (userIds.length) {
      const pats = await db.select({ id: patients.id }).from(patients).where(or(inArray(patients.userId, userIds), inArray(patients.ownerUserId, userIds)));
      const pids = pats.map((p) => p.id);
      if (pids.length) {
        const c = async (q: Promise<Array<{ n: number }>>) => Number((await q)[0]?.n ?? 0);
        used = {
          appointments: await c(db.select({ n: count() }).from(appointments).where(and(inArray(appointments.patientId, pids), eq(appointments.status, 'completed')))),
          homeVisits: await c(db.select({ n: count() }).from(homeVisits).where(and(inArray(homeVisits.patientId, pids), eq(homeVisits.status, 'completed')))),
          labOrders: await c(db.select({ n: count() }).from(labOrders).where(and(inArray(labOrders.patientId, pids), eq(labOrders.status, 'report_ready')))),
        };
      }
    }
    // Aggregates only: no names, phones or clinical details.
    return { seats: o.seats, redeemed: userIds.length, activeMembers: Number(active), servicesUsed: used };
  });

  app.post('/subscriptions/redeem', async (req, reply) => {
    const body = parse(z.object({ code: z.string().trim().min(4).max(40) }), req.body);
    const code = body.code.toUpperCase();
    const [c] = await db.select().from(organizationCodes).where(eq(organizationCodes.code, code));
    if (!c) throw errors.validation('This code is not valid', { field: 'code' });
    if (c.redeemedByUserId) throw errors.conflict('This code has already been used');
    const o = await loadOrg(c.organizationId);
    const today = istDate();
    if (today < o.validFrom || today > o.validTo) throw errors.conflict('This company plan is not active');
    if (await activeSubscriptionOf(db, req.ctx.user.id)) throw errors.conflict('You already have an active Family Care Plan');
    const sub = await db.transaction(async (tx) => {
      const [claimed] = await tx
        .update(organizationCodes)
        .set({ redeemedByUserId: req.ctx.user.id, redeemedAt: new Date() })
        .where(and(eq(organizationCodes.id, c.id), sql`${organizationCodes.redeemedByUserId} is null`))
        .returning();
      if (!claimed) throw errors.conflict('This code has already been used');
      const [s] = await tx
        .insert(subscriptions)
        .values({
          userId: req.ctx.user.id,
          planCode: o.planCode,
          billing: 'yearly',
          status: 'active',
          currentPeriodStart: new Date(),
          currentPeriodEnd: new Date(istToUtc(o.validTo, '23:59').getTime() + 59_000),
          sponsorOrgId: o.id,
          sponsorName: o.name,
        })
        .returning();
      await audit(tx, req.ctx.actor, { action: 'subscription.redeem', entityType: 'subscription', entityId: s.id, metadata: { organizationId: o.id } });
      return s;
    });
    return reply.code(201).send(await subscriptionView(db, sub));
  });

  // ---------------------------------------------------------------- tenants (section 58)
  const checkTenantRefs = async (b: { logoMediaId?: string | null; facilityIds?: string[] }) => {
    if (b.logoMediaId) {
      const [m] = await db.select({ id: media.id }).from(media).where(and(eq(media.id, b.logoMediaId), eq(media.publicProfilePhoto, true)));
      if (!m) throw errors.validation('logoMediaId must be a public image uploaded via POST /me/photo', { field: 'logoMediaId' });
    }
    if (b.facilityIds?.length) {
      const f = await db.select({ id: facilities.id }).from(facilities).where(inArray(facilities.id, b.facilityIds));
      if (f.length !== new Set(b.facilityIds).size) throw errors.validation('Unknown facility', { field: 'facilityIds' });
    }
  };

  app.get('/admin/tenants', { preHandler: superOnly }, async (req) => {
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(tenants).orderBy(tenants.code);
    return paginateArray(rows.map((t) => toTenant(svc.config, t)), page);
  });

  app.post('/admin/tenants', { preHandler: superOnly }, async (req, reply) => {
    const body = parse(zTenant, req.body);
    await checkTenantRefs(body);
    const [row] = await db
      .insert(tenants)
      .values({ ...body, code: body.code.toLowerCase(), logoMediaId: body.logoMediaId ?? null, supportPhone: body.supportPhone ?? null, supportEmail: body.supportEmail ?? null })
      .onConflictDoNothing()
      .returning();
    if (!row) throw errors.conflict('A tenant with this code already exists');
    await audit(db, req.ctx.actor, { action: 'tenant.create', entityType: 'tenant', entityId: row.id });
    return reply.code(201).send(toTenant(svc.config, row));
  });

  app.patch('/admin/tenants/:id', { preHandler: superOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(zTenant.omit({ code: true }).partial(), req.body);
    await checkTenantRefs(body);
    const [row] = await db.update(tenants).set({ ...body, updatedAt: new Date() }).where(eq(tenants.id, id)).returning();
    if (!row) throw errors.notFound('Tenant');
    await audit(db, req.ctx.actor, { action: 'tenant.update', entityType: 'tenant', entityId: id, metadata: { fields: Object.keys(body) } });
    return toTenant(svc.config, row);
  });
}

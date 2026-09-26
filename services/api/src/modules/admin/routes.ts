import { and, desc, eq, ilike, or, sql } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { aiInteractions, auditLogs, providers, serviceZones, users } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { envelope, pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zIso, zPhone, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { computeAnalytics } from '../analytics/service.js';
import { ensureUser, revokeAllSessions } from '../auth/service.js';
import { DEFAULT_WEEKLY } from '../schedules/service.js';
import { createProviderProfile } from './staff.js';

const zRole = z.enum(['patient', 'doctor', 'provider', 'coordinator', 'ops_admin', 'super_admin']);

const toAdminUser = (u: typeof users.$inferSelect) => ({
  id: u.id,
  phone: u.phone,
  name: u.name,
  roles: u.roles,
  createdAt: iso(u.createdAt),
  lastLoginAt: iso(u.lastLoginAt),
  status: u.status,
});

export async function adminRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const superOnly = requireRoles(svc, 'super_admin');
  const superOrOps = requireRoles(svc, 'super_admin', 'ops_admin');

  app.get('/admin/users', { preHandler: superOnly }, async (req) => {
    const q = parse(z.object({ q: z.string().max(100).optional(), role: zRole.optional() }), req.query);
    const page = pageFromQuery(req.query);
    const conds = [];
    if (q.q) conds.push(or(ilike(users.name, `%${q.q}%`), ilike(users.phone, `%${q.q}%`))!);
    if (q.role) conds.push(sql`${users.roles} @> ${JSON.stringify([q.role])}::jsonb`);
    const rows = await db
      .select()
      .from(users)
      .where(conds.length ? and(...conds) : undefined)
      .orderBy(desc(users.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toAdminUser), page);
  });

  app.put('/admin/users/:id/roles', { preHandler: superOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ roles: z.array(zRole).min(1).max(6) }), req.body);
    const roles = [...new Set(body.roles)];
    if (id === req.ctx.user.id && !roles.includes('super_admin')) throw errors.conflict('You cannot remove your own super_admin role');
    const [row] = await db.update(users).set({ roles }).where(eq(users.id, id)).returning();
    if (!row) throw errors.notFound('User');
    await audit(db, req.ctx.actor, { action: 'user.roles', entityType: 'user', entityId: id, metadata: { roles } });
    return toAdminUser(row);
  });

  app.post('/admin/users/:id/disable', { preHandler: superOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    if (id === req.ctx.user.id) throw errors.conflict('You cannot disable yourself');
    const row = await db.transaction(async (tx) => {
      const [u] = await tx.update(users).set({ status: 'disabled' }).where(eq(users.id, id)).returning();
      if (!u) throw errors.notFound('User');
      await revokeAllSessions(tx, id);
      await tx.update(providers).set({ onDuty: false }).where(eq(providers.userId, id));
      await audit(tx, req.ctx.actor, { action: 'user.disable', entityType: 'user', entityId: id });
      return u;
    });
    return toAdminUser(row);
  });

  // Contract section 22: clears TOTP secret + recovery codes and signs the user out everywhere (audited).
  app.post('/admin/users/:id/mfa/reset', { preHandler: superOnly }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    await svc.mfa.reset(id, req.ctx.actor);
    const [u] = await db.select().from(users).where(eq(users.id, id));
    return toAdminUser(u);
  });

  app.post('/admin/staff', { preHandler: superOnly }, async (req, reply) => {
    const body = parse(
      z.object({
        phone: zPhone,
        name: z.string().trim().min(1).max(100),
        roles: z.array(zRole).min(1).max(6),
        provider: z
          .object({
            type: z.enum(['doctor', 'nurse', 'technician', 'intern', 'physiotherapist']),
            qualification: z.string().trim().min(1).max(200),
            specialty: z.string().max(40).optional(),
            registrationNumber: z.string().trim().min(1).max(60),
            zoneIds: z.array(zUuid).max(20),
            capabilities: z.array(z.string().max(40)).max(20),
            credentialExpiresAt: zIso,
          })
          .optional(),
      }),
      req.body,
    );
    const roles = [...new Set(body.roles)];
    const user = await db.transaction(async (tx) => {
      const u0 = await ensureUser(tx, body.phone, { name: body.name, roles });
      const [u] = await tx.update(users).set({ name: body.name, roles }).where(eq(users.id, u0.id)).returning();
      if (body.provider) {
        await createProviderProfile(tx, {
          userId: u.id,
          name: body.name,
          type: body.provider.type,
          qualification: body.provider.qualification,
          specialty: body.provider.specialty ?? null,
          registrationNumber: body.provider.registrationNumber,
          zoneIds: body.provider.zoneIds,
          capabilities: body.provider.capabilities,
          credentialExpiresAt: new Date(body.provider.credentialExpiresAt),
          verificationStatus: 'pending',
          // Admin-created doctors keep the pre-v1.2 default availability as their weekly template.
          weekly: DEFAULT_WEEKLY,
        });
      }
      await audit(tx, req.ctx.actor, { action: 'staff.create', entityType: 'user', entityId: u.id, metadata: { roles } });
      return u;
    });
    return reply.code(201).send(toAdminUser(user));
  });

  app.get('/admin/audit-logs', { preHandler: superOrOps }, async (req) => {
    const q = parse(
      z.object({ actorId: zUuid.optional(), entityType: z.string().max(60).optional(), entityId: z.string().max(100).optional(), action: z.string().max(100).optional() }),
      req.query,
    );
    const page = pageFromQuery(req.query);
    const conds = [];
    if (q.actorId) conds.push(eq(auditLogs.actorId, q.actorId));
    if (q.entityType) conds.push(eq(auditLogs.entityType, q.entityType));
    if (q.entityId) conds.push(eq(auditLogs.entityId, q.entityId));
    if (q.action) conds.push(eq(auditLogs.action, q.action));
    const rows = await db
      .select()
      .from(auditLogs)
      .where(conds.length ? and(...conds) : undefined)
      .orderBy(desc(auditLogs.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(
      rows.map((a) => ({
        id: a.id,
        actorId: a.actorId,
        actorName: a.actorName,
        actorRole: a.actorRole,
        action: a.action,
        entityType: a.entityType,
        entityId: a.entityId,
        outcome: a.outcome,
        ip: a.ip,
        correlationId: a.correlationId,
        metadata: a.metadata,
        createdAt: iso(a.createdAt),
      })),
      page,
    );
  });

  app.get('/admin/ai-interactions', { preHandler: superOnly }, async (req) => {
    const q = parse(z.object({ useCase: z.string().max(60).optional(), safetyLevel: z.string().max(20).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const conds = [];
    if (q.useCase) conds.push(eq(aiInteractions.useCase, q.useCase));
    if (q.safetyLevel) conds.push(eq(aiInteractions.safetyLevel, q.safetyLevel));
    const rows = await db
      .select()
      .from(aiInteractions)
      .where(conds.length ? and(...conds) : undefined)
      .orderBy(desc(aiInteractions.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(
      rows.map((r) => ({
        id: r.id,
        useCase: r.useCase,
        userId: r.userId,
        patientId: r.patientId,
        model: r.model,
        promptVersion: r.promptVersion,
        policyVersion: r.policyVersion,
        rulePackVersion: r.rulePackVersion,
        safetyLevel: r.safetyLevel,
        latencyMs: r.latencyMs,
        inputTokens: r.inputTokens,
        outputTokens: r.outputTokens,
        fallbackUsed: r.fallbackUsed,
        createdAt: iso(r.createdAt),
      })),
      page,
    );
  });

  app.get('/admin/analytics', { preHandler: superOrOps }, async () => computeAnalytics(db));

  app.get('/admin/service-zones', { preHandler: superOrOps }, async (req) => {
    const page = pageFromQuery(req.query);
    const rows = await db.select().from(serviceZones).orderBy(serviceZones.name);
    return paginateArray(
      rows.map((z1) => ({ id: z1.id, name: z1.name, city: z1.city, pincodes: z1.pincodes })),
      page,
    );
  });

  app.post('/admin/service-zones', { preHandler: superOnly }, async (req, reply) => {
    const body = parse(
      z.object({ name: z.string().trim().min(1).max(100), city: z.string().trim().min(1).max(100), pincodes: z.array(z.string().regex(/^\d{6}$/)).min(1).max(2000) }),
      req.body,
    );
    const [existing] = await db.select({ id: serviceZones.id }).from(serviceZones).where(eq(serviceZones.name, body.name));
    if (existing) throw errors.conflict('A zone with this name already exists');
    const [row] = await db.insert(serviceZones).values({ ...body, pincodes: [...new Set(body.pincodes)] }).returning();
    await audit(db, req.ctx.actor, { action: 'service_zone.create', entityType: 'service_zone', entityId: row.id });
    return reply.code(201).send({ id: row.id, name: row.name, city: row.city, pincodes: row.pincodes });
  });
}

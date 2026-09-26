import { and, desc, eq, inArray } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { familyAccessGrants, patients, users } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zFamilyPermission, zPhone, zUuid } from '../../lib/validate.js';
import { ensureUser } from '../auth/service.js';

type GrantRow = typeof familyAccessGrants.$inferSelect;

export async function toGrants(db: DbOrTx, rows: GrantRow[]) {
  const pids = [...new Set(rows.map((r) => r.patientId))];
  const uids = [...new Set(rows.map((r) => r.granteeUserId))];
  const ps = pids.length ? await db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, pids)) : [];
  const us = uids.length ? await db.select({ id: users.id, name: users.name, phone: users.phone }).from(users).where(inArray(users.id, uids)) : [];
  const pm = new Map(ps.map((p) => [p.id, p.name]));
  const um = new Map(us.map((u) => [u.id, u]));
  return rows.map((g) => ({
    id: g.id,
    patientId: g.patientId,
    patientName: pm.get(g.patientId) ?? null,
    granteeUserId: g.granteeUserId,
    granteeName: um.get(g.granteeUserId)?.name ?? null,
    granteePhone: um.get(g.granteeUserId)?.phone ?? '',
    relation: g.relation,
    permissions: g.permissions,
    status: g.status,
    createdAt: iso(g.createdAt),
    revokedAt: iso(g.revokedAt),
  }));
}

export async function familyRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/patients/:id/family-access', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const page = pageFromQuery(req.query);
    await assertCanActForPatient(db, req.ctx, id, 'owner', 'family_access.list');
    const rows = await db.select().from(familyAccessGrants).where(eq(familyAccessGrants.patientId, id)).orderBy(desc(familyAccessGrants.createdAt));
    return paginateArray(await toGrants(db, rows), page);
  });

  app.post('/patients/:id/family-access', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(
      z.object({
        granteePhone: zPhone,
        relation: z.string().trim().min(1).max(40),
        permissions: z.array(zFamilyPermission).min(1).max(4),
      }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, id, 'owner', 'family_access.grant');
    if (body.granteePhone === req.ctx.user.phone) throw errors.validation('You cannot grant access to yourself');
    const permissions = [...new Set(body.permissions)];
    const grant = await db.transaction(async (tx) => {
      const grantee = await ensureUser(tx, body.granteePhone);
      const [p] = await tx.select().from(patients).where(eq(patients.id, id));
      if (p.userId === grantee.id || p.ownerUserId === grantee.id) throw errors.validation('This person already manages this patient');
      const [existing] = await tx
        .select()
        .from(familyAccessGrants)
        .where(and(eq(familyAccessGrants.patientId, id), eq(familyAccessGrants.granteeUserId, grantee.id), eq(familyAccessGrants.status, 'active')));
      let row: GrantRow;
      if (existing) {
        [row] = await tx.update(familyAccessGrants).set({ permissions, relation: body.relation }).where(eq(familyAccessGrants.id, existing.id)).returning();
      } else {
        [row] = await tx
          .insert(familyAccessGrants)
          .values({ patientId: id, granteeUserId: grantee.id, relation: body.relation, permissions, createdByUserId: req.ctx.user.id })
          .returning();
      }
      await audit(tx, req.ctx.actor, { action: 'family_access.grant', entityType: 'family_access_grant', entityId: row.id, metadata: { patientId: id, permissions } });
      return row;
    });
    const [p] = await db.select({ name: patients.name }).from(patients).where(eq(patients.id, id));
    await svc.notify.notifyUsers([grant.granteeUserId], {
      template: 'family_access',
      params: { patient: p?.name ?? 'a family member' },
      category: 'system',
      deepLink: `/patients/${id}`,
    });
    return reply.code(201).send((await toGrants(db, [grant]))[0]);
  });

  app.post('/family-access/:grantId/revoke', async (req) => {
    const { grantId } = parse(z.object({ grantId: zUuid }), req.params);
    const [g] = await db.select().from(familyAccessGrants).where(eq(familyAccessGrants.id, grantId));
    if (!g) throw errors.notFound('Grant');
    if (g.granteeUserId !== req.ctx.user.id) {
      await assertCanActForPatient(db, req.ctx, g.patientId, 'owner', 'family_access.revoke');
    }
    let row = g;
    if (g.status === 'active') {
      [row] = await db.update(familyAccessGrants).set({ status: 'revoked', revokedAt: new Date() }).where(eq(familyAccessGrants.id, grantId)).returning();
      await audit(db, req.ctx.actor, { action: 'family_access.revoke', entityType: 'family_access_grant', entityId: grantId, metadata: { patientId: g.patientId } });
    }
    return (await toGrants(db, [row]))[0];
  });
}

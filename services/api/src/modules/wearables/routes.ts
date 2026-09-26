import { and, desc, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { vitals, wearableConnections } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { list } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { VITAL_TYPES, parse, zIso, zUuid } from '../../lib/validate.js';

const PROVIDERS = [
  { code: 'health_connect', name: 'Health Connect (Android)', status: 'available' },
  { code: 'apple_health', name: 'Apple Health', status: 'available' },
  { code: 'fitbit', name: 'Fitbit', status: 'coming_soon' },
  { code: 'samsung_health', name: 'Samsung Health', status: 'coming_soon' },
] as const;
const zProvider = z.enum(['apple_health', 'health_connect', 'fitbit', 'samsung_health']);

const toConn = (c: typeof wearableConnections.$inferSelect) => ({
  id: c.id,
  provider: c.provider,
  status: c.status,
  connectedAt: iso(c.connectedAt),
  lastSyncAt: iso(c.lastSyncAt),
});

export async function wearableRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/wearables/providers', async () => list([...PROVIDERS]));

  app.get('/wearables/connections', async (req) => {
    const q = parse(z.object({ patientId: zUuid }), req.query);
    await assertCanActForPatient(db, req.ctx, q.patientId, ['manage_care', 'view_records'], 'wearable.list');
    const rows = await db.select().from(wearableConnections).where(eq(wearableConnections.patientId, q.patientId)).orderBy(desc(wearableConnections.connectedAt));
    return list(rows.map(toConn));
  });

  app.post('/wearables/connections', async (req, reply) => {
    await svc.flags.require('wearables');
    const body = parse(z.object({ patientId: zUuid, provider: zProvider }), req.body);
    await assertCanActForPatient(db, req.ctx, body.patientId, 'manage_care', 'wearable.connect');
    if (PROVIDERS.find((p) => p.code === body.provider)?.status !== 'available') throw errors.validation('This provider is coming soon');
    const [existing] = await db
      .select()
      .from(wearableConnections)
      .where(and(eq(wearableConnections.patientId, body.patientId), eq(wearableConnections.provider, body.provider), eq(wearableConnections.status, 'connected')));
    if (existing) return reply.code(200).send(toConn(existing));
    const [row] = await db.insert(wearableConnections).values({ patientId: body.patientId, provider: body.provider }).returning();
    await audit(db, req.ctx.actor, { action: 'wearable.connect', entityType: 'wearable_connection', entityId: row.id, metadata: { provider: body.provider } });
    return reply.code(201).send(toConn(row));
  });

  app.post('/wearables/connections/:id/revoke', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [c] = await db.select().from(wearableConnections).where(eq(wearableConnections.id, id));
    if (!c) throw errors.notFound('Connection');
    await assertCanActForPatient(db, req.ctx, c.patientId, 'manage_care', 'wearable.revoke');
    const [row] = await db.update(wearableConnections).set({ status: 'revoked', revokedAt: new Date() }).where(eq(wearableConnections.id, id)).returning();
    await audit(db, req.ctx.actor, { action: 'wearable.revoke', entityType: 'wearable_connection', entityId: id });
    return toConn(row);
  });

  app.post('/wearables/sync', async (req) => {
    await svc.flags.require('wearables');
    const body = parse(
      z.object({
        patientId: zUuid,
        provider: zProvider,
        measurements: z
          .array(z.object({ type: z.enum([...VITAL_TYPES, 'steps', 'sleep_minutes']), value: z.number().finite(), unit: z.string().min(1).max(20), measuredAt: zIso }))
          .max(1000),
      }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, body.patientId, 'manage_care', 'wearable.sync');
    const [conn] = await db
      .select()
      .from(wearableConnections)
      .where(and(eq(wearableConnections.patientId, body.patientId), eq(wearableConnections.provider, body.provider), eq(wearableConnections.status, 'connected')));
    if (!conn) throw errors.forbidden('No active connection for this provider');
    if (body.measurements.length) {
      // Devices resend running totals (e.g. today's steps), so a reading replaces the earlier reading from
      // the same provider for the same patient, type and timestamp instead of accumulating duplicates.
      const sourceName = PROVIDERS.find((p) => p.code === body.provider)?.name ?? body.provider;
      const latest = new Map<string, (typeof body.measurements)[number]>();
      for (const m of body.measurements) latest.set(`${m.type}|${new Date(m.measuredAt).getTime()}`, m);
      const rows = [...latest.values()];
      await db.transaction(async (tx) => {
        for (const m of rows) {
          await tx
            .delete(vitals)
            .where(
              and(
                eq(vitals.patientId, body.patientId),
                eq(vitals.type, m.type),
                eq(vitals.source, 'device'),
                eq(vitals.recordedByName, sourceName),
                eq(vitals.measuredAt, new Date(m.measuredAt)),
              ),
            );
        }
        await tx.insert(vitals).values(
          rows.map((m) => ({
            patientId: body.patientId,
            type: m.type,
            value: m.value,
            unit: m.unit,
            measuredAt: new Date(m.measuredAt),
            source: 'device' as const,
            recordedByName: sourceName,
          })),
        );
      });
    }
    await db.update(wearableConnections).set({ lastSyncAt: new Date() }).where(eq(wearableConnections.id, conn.id));
    await audit(db, req.ctx.actor, { action: 'wearable.sync', entityType: 'wearable_connection', entityId: conn.id, metadata: { count: body.measurements.length } });
    return { accepted: body.measurements.length };
  });
}

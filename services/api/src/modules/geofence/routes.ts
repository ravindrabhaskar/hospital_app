import { randomUUID } from 'node:crypto';
import { and, eq, isNull, or } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { patientLocations, patients, safeZones, safetyEvents, sosDevices, sosEvents } from '../../db/schema.js';
import { assertCanActForPatient, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, type Actor } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { list } from '../../lib/pagination.js';
import { IST_OFFSET_MIN, iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { firstDelivery, parseJsonBuffer, rawBodyParsers, verifyHmacHeader } from '../../lib/webhooks.js';
import type { Services } from '../../services.js';
import { zHHMM } from '../checkins/routes.js';
import { alertEmergencyContacts, openEmergency } from '../emergency/service.js';
import { haversineKm } from '../providers/routes.js';
import { raiseAlert } from '../safety/alerts.js';

/** Contract section 56: dementia safety (safe zone, location, SOS button). Only the latest location is kept. */
type ZoneRow = typeof safeZones.$inferSelect;

const toZone = (patientId: string, z1: ZoneRow | null) =>
  z1
    ? { patientId, enabled: z1.enabled, centerLat: z1.centerLat, centerLng: z1.centerLng, radiusMeters: z1.radiusMeters, label: z1.label, activeFrom: z1.activeFrom, activeTo: z1.activeTo }
    : { patientId, enabled: false, centerLat: null, centerLng: null, radiusMeters: null, label: null, activeFrom: null, activeTo: null };

/** Is the zone active now (IST window; overnight windows supported)? */
export function zoneActive(z1: ZoneRow, now = new Date()): boolean {
  if (!z1.enabled) return false;
  if (!z1.activeFrom || !z1.activeTo) return true;
  const mins = (now.getUTCHours() * 60 + now.getUTCMinutes() + IST_OFFSET_MIN) % 1440;
  const toMin = (s: string) => Number(s.slice(0, 2)) * 60 + Number(s.slice(3, 5));
  const from = toMin(z1.activeFrom);
  const to = toMin(z1.activeTo);
  return from <= to ? mins >= from && mins < to : mins >= from || mins < to;
}

export const insideZone = (z1: Pick<ZoneRow, 'centerLat' | 'centerLng' | 'radiusMeters'>, lat: number, lng: number) => haversineKm(z1.centerLat, z1.centerLng, lat, lng) * 1000 <= z1.radiusMeters;

/** Record the latest location and run the geofence (exit -> urgent SafetyEvent + family alert; return -> resolve). */
export async function recordLocation(svc: Services, p: { patientId: string; lat: number; lng: number; accuracyM: number | null; source: string; actor: Actor; now?: Date }): Promise<{ inside: boolean }> {
  const now = p.now ?? new Date();
  const [zone] = await svc.db.select().from(safeZones).where(eq(safeZones.patientId, p.patientId));
  const [prev] = await svc.db.select().from(patientLocations).where(eq(patientLocations.patientId, p.patientId));
  const inside = zone ? insideZone(zone, p.lat, p.lng) : true;
  let geofenceEventId = prev?.geofenceEventId ?? null;
  const [pat] = await svc.db.select({ name: patients.name }).from(patients).where(eq(patients.id, p.patientId));
  const name = pat?.name?.split(' ')[0] ?? 'Your family member';
  if (zone && zoneActive(zone, now) && !inside && !geofenceEventId) {
    const link = `https://maps.google.com/?q=${p.lat.toFixed(5)},${p.lng.toFixed(5)}`;
    const event = await raiseAlert(svc, {
      patientId: p.patientId,
      level: 'urgent',
      source: 'geofence',
      rules: [{ ruleId: 'geofence.exit', title: `Left the safe zone${zone.label ? ` (${zone.label})` : ''}` }],
      note: 'First location outside the safe zone',
      familyTemplate: 'geofence_exit',
      familyParams: { patient: name, link },
      deepLink: `/patients/${p.patientId}/location`,
    });
    geofenceEventId = event.id;
  } else if (inside && geofenceEventId) {
    await svc.db
      .update(safetyEvents)
      .set({ status: 'resolved', resolvedAt: now, note: 'Auto-resolved: back inside the safe zone' })
      .where(and(eq(safetyEvents.id, geofenceEventId), or(eq(safetyEvents.status, 'open'), eq(safetyEvents.status, 'acknowledged'))));
    await svc.notify.notifyPatient(p.patientId, {
      template: 'geofence_return',
      params: { patient: name },
      category: 'safety',
      deepLink: `/patients/${p.patientId}/location`,
      dedupeKey: `geofence_return:${geofenceEventId}`,
    });
    geofenceEventId = null;
  }
  const values = { lat: p.lat, lng: p.lng, accuracyM: p.accuracyM, source: p.source, inside, at: now, geofenceEventId };
  await svc.db.insert(patientLocations).values({ patientId: p.patientId, ...values }).onConflictDoUpdate({ target: patientLocations.patientId, set: values });
  await audit(svc.db, p.actor, { action: 'location.update', entityType: 'patient', entityId: p.patientId, metadata: { source: p.source, inside } });
  return { inside };
}

export async function geofenceRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/patients/:id/safe-zone', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, id, ['manage_care', 'receive_alerts', 'staff_ops'], 'safe_zone.read');
    const [z1] = await db.select().from(safeZones).where(eq(safeZones.patientId, id));
    return toZone(id, z1 ?? null);
  });

  app.put('/patients/:id/safe-zone', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(
      z
        .object({
          enabled: z.boolean(),
          centerLat: z.number().min(-90).max(90),
          centerLng: z.number().min(-180).max(180),
          radiusMeters: z.number().int().min(100).max(5000),
          label: z.string().trim().max(60).optional(),
          activeFrom: zHHMM.optional(),
          activeTo: zHHMM.optional(),
        })
        .refine((b) => !!b.activeFrom === !!b.activeTo, 'activeFrom and activeTo must be set together'),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'safe_zone.update');
    const values = { ...body, label: body.label ?? null, activeFrom: body.activeFrom ?? null, activeTo: body.activeTo ?? null, updatedByUserId: req.ctx.user.id, updatedAt: new Date() };
    const [row] = await db.insert(safeZones).values({ patientId: id, ...values }).onConflictDoUpdate({ target: safeZones.patientId, set: values }).returning();
    await audit(db, req.ctx.actor, { action: 'safe_zone.update', entityType: 'patient', entityId: id, metadata: { enabled: body.enabled, radiusMeters: body.radiusMeters } });
    return toZone(id, row);
  });

  app.post('/patients/:id/location', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180), accuracyM: z.number().min(0).max(100_000), source: z.enum(['phone', 'tracker']) }), req.body);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'location.update');
    return recordLocation(svc, { patientId: id, lat: body.lat, lng: body.lng, accuracyM: body.accuracyM, source: body.source, actor: req.ctx.actor });
  });

  app.get('/patients/:id/location/latest', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, id, ['receive_alerts', 'staff_ops'], 'location.read');
    const [loc] = await db.select().from(patientLocations).where(eq(patientLocations.patientId, id));
    if (!loc) throw errors.notFound('Location');
    await audit(db, req.ctx.actor, { action: 'location.read', entityType: 'patient', entityId: id });
    return { lat: loc.lat, lng: loc.lng, at: iso(loc.at), inside: loc.inside ?? true, source: loc.source };
  });

  const DEVICE_PERM: Perm = 'manage_care';
  const toDevice = (d: typeof sosDevices.$inferSelect) => ({ id: d.id, deviceId: d.deviceId, model: d.model, pairedAt: iso(d.pairedAt) });

  app.get('/patients/:id/sos-devices', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, id, DEVICE_PERM, 'sos_device.list');
    const rows = await db.select().from(sosDevices).where(and(eq(sosDevices.patientId, id), isNull(sosDevices.unpairedAt))).orderBy(sosDevices.pairedAt);
    return list(rows.map(toDevice));
  });

  app.post('/patients/:id/sos-devices', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ deviceId: z.string().trim().min(3).max(100), model: z.string().trim().min(1).max(100) }), req.body);
    await assertCanActForPatient(db, req.ctx, id, DEVICE_PERM, 'sos_device.pair');
    const [taken] = await db.select({ id: sosDevices.id }).from(sosDevices).where(and(eq(sosDevices.deviceId, body.deviceId), isNull(sosDevices.unpairedAt)));
    if (taken) throw errors.conflict('This device is already paired');
    const [row] = await db.insert(sosDevices).values({ patientId: id, deviceId: body.deviceId, model: body.model, createdByUserId: req.ctx.user.id }).returning();
    await audit(db, req.ctx.actor, { action: 'sos_device.pair', entityType: 'sos_device', entityId: row.id, metadata: { patientId: id } });
    return reply.code(201).send(toDevice(row));
  });

  app.delete('/patients/:id/sos-devices/:deviceRowId', async (req, reply) => {
    const { id, deviceRowId } = parse(z.object({ id: zUuid, deviceRowId: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, id, DEVICE_PERM, 'sos_device.unpair');
    const rows = await db
      .update(sosDevices)
      .set({ unpairedAt: new Date() })
      .where(and(eq(sosDevices.id, deviceRowId), eq(sosDevices.patientId, id), isNull(sosDevices.unpairedAt)))
      .returning();
    if (!rows.length) throw errors.notFound('SOS device');
    await audit(db, req.ctx.actor, { action: 'sos_device.unpair', entityType: 'sos_device', entityId: deviceRowId });
    return reply.code(204).send();
  });
}

/**
 * SOS button vendor webhook (HMAC X-SOS-Signature with SOS_WEBHOOK_SECRET). Payload { eventId, deviceId, lat?, lng? }.
 * Same flow as POST /emergency/sos (emergency episode + SafetyEvent source sos_button + family and contacts alerted).
 */
export async function sosWebhookRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  rawBodyParsers(app);
  app.post('/webhooks/sos-button', { bodyLimit: 64 * 1024 }, async (req, reply) => {
    const actor = { ...SYSTEM_ACTOR, name: 'sos-button', role: 'webhook', ip: req.ip, correlationId: req.correlationId };
    if (!Buffer.isBuffer(req.body) || !verifyHmacHeader(svc.config.SOS_WEBHOOK_SECRET, req.body, req.headers['x-sos-signature'])) {
      await audit(svc.db, actor, { action: 'sos_button.webhook', entityType: 'webhook', outcome: 'denied', metadata: { reason: 'bad_signature' } });
      throw errors.unauthenticated('Invalid webhook signature');
    }
    const b = parse(
      z.object({ eventId: z.string().min(1).max(200), deviceId: z.string().min(1).max(100), lat: z.number().min(-90).max(90).optional(), lng: z.number().min(-180).max(180).optional() }),
      parseJsonBuffer(req.body),
    );
    if (!(await firstDelivery(svc.db, 'sos_button', b.eventId))) return reply.send({ received: true, duplicate: true });
    const [dev] = await svc.db.select().from(sosDevices).where(and(eq(sosDevices.deviceId, b.deviceId), isNull(sosDevices.unpairedAt)));
    if (!dev) {
      await audit(svc.db, actor, { action: 'sos_button.unknown_device', entityType: 'webhook', outcome: 'error' });
      return reply.send({ received: true, unknownDevice: true });
    }
    const sosId = randomUUID();
    const em = await svc.db.transaction(async (tx) => {
      const r = await openEmergency(svc, tx, {
        patientId: dev.patientId,
        title: 'SOS button pressed',
        concern: `SOS button (${dev.model}) pressed`,
        source: 'sos_button',
        rule: { ruleId: 'sos_button.pressed', title: 'SOS button pressed' },
        actor,
      });
      await tx.insert(sosEvents).values({ id: sosId, patientId: dev.patientId, careEpisodeId: r.episodeId, lat: b.lat ?? null, lng: b.lng ?? null, note: `SOS device ${dev.model}` });
      await audit(tx, actor, { action: 'sos_button.pressed', entityType: 'sos_event', entityId: sosId, metadata: { patientId: dev.patientId } });
      return r;
    });
    await alertEmergencyContacts(svc, dev.patientId, 'sos', `/care-episodes/${em.episodeId}`);
    if (b.lat !== undefined && b.lng !== undefined) await recordLocation(svc, { patientId: dev.patientId, lat: b.lat, lng: b.lng, accuracyM: null, source: 'tracker', actor });
    return reply.send({ received: true, sosId, careEpisodeId: em.episodeId });
  });
}

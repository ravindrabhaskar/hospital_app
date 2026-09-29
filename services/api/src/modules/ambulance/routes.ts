import { randomUUID } from 'node:crypto';
import { and, desc, eq, inArray } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { ambulanceRequests, facilities, patients, sosEvents } from '../../db/schema.js';
import { assertCanActForPatient, type Perm } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR } from '../../lib/context.js';
import { maskPhone } from '../../lib/crypto.js';
import { errors } from '../../lib/errors.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import type { Services } from '../../services.js';
import { toPayment } from '../payments/service.js';
import { toFacility } from '../providers/routes.js';
import { raiseAlert } from '../safety/alerts.js';

/** Contract section 55: ambulance booking. Never replaces 108: clients keep "Call 108" as the primary action. */
type AmbRow = typeof ambulanceRequests.$inferSelect;
const READ: Perm[] = ['any'];
const LIVE = ['searching', 'assigned', 'en_route', 'arrived', 'transporting'];
const STEP_MS = 10_000; // the mock vehicle moves every 10 s
const STEPS = 18; // ~3 minutes to the pickup

export async function toAmbulance(db: DbOrTx, rows: AmbRow[]) {
  if (!rows.length) return [];
  const pats = await db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, [...new Set(rows.map((r) => r.patientId))]));
  const pn = new Map(pats.map((p) => [p.id, p.name]));
  const fids = [...new Set(rows.map((r) => r.destinationFacilityId).filter((x): x is string => !!x))];
  const facs = fids.length ? await db.select().from(facilities).where(inArray(facilities.id, fids)) : [];
  const fm = new Map(facs.map((f) => [f.id, f]));
  return rows.map((r) => ({
    id: r.id,
    patientId: r.patientId,
    patientName: pn.get(r.patientId) ?? null,
    type: r.type,
    status: r.status,
    vehicle: r.vehicle,
    etaMinutes: r.etaMinutes,
    location: r.location,
    pickup: r.pickup,
    destination: r.destinationFacilityId && fm.get(r.destinationFacilityId) ? toFacility(fm.get(r.destinationFacilityId)!) : null,
    partnerName: r.partnerName,
    timeline: r.timeline,
    createdAt: iso(r.createdAt),
  }));
}

const pushTl = (r: AmbRow, status: string, at: Date) => [...r.timeline, { status, at: at.toISOString() }];

/**
 * Mock partner simulation (time-based and idempotent, driven by the worker and by client polling): a vehicle is
 * assigned within AMBULANCE_MOCK_ASSIGN_SEC (<= 20 s), then moves towards the pickup every 10 s.
 */
export function simulateMock(r: AmbRow, now: Date, assignSec: number): Partial<AmbRow> | null {
  if (!LIVE.includes(r.status)) return null;
  const patch: Partial<AmbRow> = {};
  let row = { ...r };
  if (row.status === 'searching') {
    const assignAt = new Date(row.createdAt.getTime() + assignSec * 1000);
    if (now < assignAt) return null;
    const seed = parseInt(row.id.replace(/-/g, '').slice(0, 6), 16);
    const start = { lat: row.pickup.lat + 0.018 + (seed % 7) / 1000, lng: row.pickup.lng + 0.021 - (seed % 5) / 1000 };
    patch.status = 'assigned';
    patch.assignedAt = assignAt;
    patch.vehicleStart = start;
    patch.vehicle = { number: `TS09 EM ${String(1000 + (seed % 9000))}`, driverName: 'Sample Driver (mock)', phoneMasked: maskPhone(`+9190000${String(10000 + (seed % 89999)).slice(0, 5)}`) };
    patch.location = { ...start, updatedAt: assignAt.toISOString() };
    patch.etaMinutes = Math.ceil((STEPS * STEP_MS) / 60_000);
    patch.timeline = pushTl(row, 'assigned', assignAt);
    row = { ...row, ...patch } as AmbRow;
  }
  if (!row.assignedAt || !row.vehicleStart) return Object.keys(patch).length ? patch : null;
  const k = Math.min(STEPS, Math.floor((now.getTime() - row.assignedAt.getTime()) / STEP_MS));
  const f = k / STEPS;
  const at = new Date(row.assignedAt.getTime() + k * STEP_MS);
  const loc = { lat: Math.round((row.vehicleStart.lat + (row.pickup.lat - row.vehicleStart.lat) * f) * 1e6) / 1e6, lng: Math.round((row.vehicleStart.lng + (row.pickup.lng - row.vehicleStart.lng) * f) * 1e6) / 1e6 };
  if (row.status === 'assigned' && k >= 1) {
    patch.status = 'en_route';
    patch.timeline = pushTl(row, 'en_route', new Date(row.assignedAt.getTime() + STEP_MS));
    row = { ...row, ...patch } as AmbRow;
  }
  if (row.status === 'en_route' || row.status === 'assigned') {
    if (!row.location || row.location.updatedAt !== at.toISOString()) patch.location = { ...loc, updatedAt: at.toISOString() };
    patch.etaMinutes = Math.ceil(((STEPS - k) * STEP_MS) / 60_000);
    if (k >= STEPS) {
      patch.status = 'arrived';
      patch.etaMinutes = 0;
      patch.timeline = pushTl(row, 'arrived', at);
    }
  }
  return Object.keys(patch).length ? patch : null;
}

export async function advanceAmbulances(svc: Services, now: Date, ids?: string[]): Promise<number> {
  if (svc.partners.ambulance.name !== 'mock' && !svc.partners.ambulance.status) return 0;
  const rows = await svc.db
    .select()
    .from(ambulanceRequests)
    .where(ids ? and(inArray(ambulanceRequests.id, ids), inArray(ambulanceRequests.status, LIVE)) : inArray(ambulanceRequests.status, LIVE));
  let n = 0;
  for (const r of rows) {
    let patch: Partial<AmbRow> | null = null;
    if (svc.partners.ambulance.name === 'mock') {
      patch = simulateMock(r, now, Math.min(20, svc.config.AMBULANCE_MOCK_ASSIGN_SEC));
    } else if (r.partnerRequestId && svc.partners.ambulance.status) {
      try {
        const s = await svc.partners.ambulance.status(r.partnerRequestId);
        patch = {
          vehicle: s.vehicle ? { number: s.vehicle.number, driverName: s.vehicle.driverName, phoneMasked: maskPhone(s.vehicle.phone) } : r.vehicle,
          etaMinutes: s.etaMinutes,
          location: s.location ? { ...s.location, updatedAt: now.toISOString() } : r.location,
          ...(s.status !== r.status ? { status: s.status, timeline: pushTl(r, s.status, now) } : {}),
        };
      } catch {
        continue;
      }
    }
    if (!patch) continue;
    const [updated] = await svc.db
      .update(ambulanceRequests)
      .set({ ...patch, updatedAt: now })
      .where(and(eq(ambulanceRequests.id, r.id), eq(ambulanceRequests.status, r.status)))
      .returning();
    if (!updated) continue;
    n++;
    if (patch.status && patch.status !== r.status) {
      await audit(svc.db, { ...SYSTEM_ACTOR, name: 'ambulance-partner' }, { action: `ambulance.${patch.status}`, entityType: 'ambulance_request', entityId: r.id });
      await svc.notify.notifyPatient(r.patientId, {
        template: 'ambulance_update',
        params: { status: patch.status.replace('_', ' ') },
        category: 'safety',
        critical: true,
        deepLink: `/ambulance/requests/${r.id}`,
        dedupeKey: `ambulance:${r.id}:${patch.status}`,
      });
    }
  }
  return n;
}

export async function ambulanceRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.post('/ambulance/requests', { config: { idempotent: true } }, async (req, reply) => {
    const body = parse(
      z.object({
        patientId: zUuid,
        pickup: z.object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180), address: z.string().trim().min(1).max(300) }),
        destinationFacilityId: zUuid.optional(),
        type: z.enum(['bls', 'als']),
        reason: z.string().trim().min(1).max(500),
        sosId: zUuid.optional(),
      }),
      req.body,
    );
    // Safety first: any relationship to the patient may request an ambulance (as for SOS).
    await assertCanActForPatient(db, req.ctx, body.patientId, 'any', 'ambulance.create');
    if (body.destinationFacilityId) {
      const [f] = await db.select({ id: facilities.id }).from(facilities).where(eq(facilities.id, body.destinationFacilityId));
      if (!f) throw errors.validation('Unknown destination facility', { field: 'destinationFacilityId' });
    }
    let careEpisodeId: string | null = null;
    if (body.sosId) {
      const [sos] = await db.select().from(sosEvents).where(eq(sosEvents.id, body.sosId));
      if (!sos || sos.patientId !== body.patientId) throw errors.validation('sosId does not belong to this patient', { field: 'sosId' });
      careEpisodeId = sos.careEpisodeId;
    }
    const id = randomUUID();
    const { partnerRequestId } = await svc.partners.ambulance.request({ requestId: id, type: body.type, pickup: body.pickup });
    const event = await raiseAlert(svc, {
      patientId: body.patientId,
      careEpisodeId,
      level: 'emergency',
      source: 'sos',
      rules: [{ ruleId: 'ambulance.requested', title: 'Ambulance requested' }],
      note: `${body.type.toUpperCase()} ambulance requested`,
      assignCoordinator: true,
      notifyFamily: true,
      familyParams: { patient: 'your family member' },
      deepLink: `/ambulance/requests/${id}`,
    });
    const now = new Date();
    const [row] = await db
      .insert(ambulanceRequests)
      .values({
        id,
        patientId: body.patientId,
        type: body.type,
        pickup: body.pickup,
        destinationFacilityId: body.destinationFacilityId ?? null,
        reason: body.reason,
        sosId: body.sosId ?? null,
        partnerName: svc.partners.ambulance.displayName,
        partnerRequestId,
        timeline: [{ status: 'searching', at: now.toISOString() }],
        safetyEventId: event.id,
        careEpisodeId,
        createdByUserId: req.ctx.user.id,
        createdAt: now,
      })
      .returning();
    await audit(db, req.ctx.actor, { action: 'ambulance.create', entityType: 'ambulance_request', entityId: id, metadata: { type: body.type, partner: svc.partners.ambulance.name } });
    const out: Record<string, unknown> = (await toAmbulance(db, [row]))[0];
    const price = svc.partners.ambulance.price(body.type);
    if (price > 0) {
      const payment = await svc.payments.create(db, { purpose: 'ambulance', refId: id, patientId: body.patientId, amount: price, userId: req.ctx.user.id, actor: req.ctx.actor });
      out.payment = toPayment(payment);
    }
    return reply.code(201).send(out);
  });

  const load = async (id: string) => {
    const [r] = await db.select().from(ambulanceRequests).where(eq(ambulanceRequests.id, id));
    if (!r) throw errors.notFound('Ambulance request');
    return r;
  };

  app.get('/ambulance/requests/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const r = await load(id);
    await assertCanActForPatient(db, req.ctx, r.patientId, [...READ, 'staff_ops'], 'ambulance.read');
    // Clients poll every 5 s: advance the simulation on read too (idempotent, time-based).
    await advanceAmbulances(svc, new Date(), [id]);
    return (await toAmbulance(db, [await load(id)]))[0];
  });

  app.post('/ambulance/requests/:id/cancel', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ reason: z.string().trim().min(1).max(500) }), req.body);
    const r = await load(id);
    await assertCanActForPatient(db, req.ctx, r.patientId, ['any', 'staff_ops'], 'ambulance.cancel');
    if (!['searching', 'assigned', 'en_route'].includes(r.status)) throw errors.invalidTransition(r.status, 'cancelled');
    if (r.partnerRequestId) await svc.partners.ambulance.cancel(r.partnerRequestId);
    const [row] = await db
      .update(ambulanceRequests)
      .set({ status: 'cancelled', cancelReason: body.reason, timeline: pushTl(r, 'cancelled', new Date()), updatedAt: new Date() })
      .where(eq(ambulanceRequests.id, id))
      .returning();
    await audit(db, req.ctx.actor, { action: 'ambulance.cancel', entityType: 'ambulance_request', entityId: id });
    return (await toAmbulance(db, [row]))[0];
  });

  app.get('/ops/ambulance-requests', { preHandler: requireRoles(svc, 'coordinator', 'ops_admin', 'super_admin') }, async (req) => {
    const q = parse(z.object({ status: z.string().max(30).optional() }), req.query);
    const page = pageFromQuery(req.query);
    await advanceAmbulances(svc, new Date());
    const rows = await db
      .select()
      .from(ambulanceRequests)
      .where(q.status ? eq(ambulanceRequests.status, q.status) : undefined)
      .orderBy(desc(ambulanceRequests.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(await toAmbulance(db, rows), page);
  });
}

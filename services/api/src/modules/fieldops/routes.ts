import { and, asc, eq, gte, lt, lte, notInArray, sql } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { homeVisitServices, homeVisits, providerAttendance, providerSupplies, providers, supplyUsage } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import type { RequestCtx } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { list } from '../../lib/pagination.js';
import { istDate, istDayBounds, iso } from '../../lib/time.js';
import { parse, zDate, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { haversineKm } from '../providers/routes.js';

/** Contract section 48: nurse route planning, attendance & supplies. */
export const SUPPLY_CATALOG: Record<string, { name: string; unit: string }> = {
  gloves: { name: 'Nitrile gloves', unit: 'pair' },
  masks: { name: 'Surgical masks', unit: 'piece' },
  alcohol_swabs: { name: 'Alcohol swabs', unit: 'piece' },
  cotton: { name: 'Cotton balls', unit: 'pack' },
  syringes_5ml: { name: 'Syringes 5 ml', unit: 'piece' },
  vacutainer: { name: 'Vacutainer tubes', unit: 'piece' },
  tourniquet: { name: 'Tourniquet', unit: 'piece' },
  glucose_strips: { name: 'Glucometer strips', unit: 'strip' },
  lancets: { name: 'Lancets', unit: 'piece' },
  bandage: { name: 'Crepe bandage', unit: 'roll' },
  dressing_pads: { name: 'Sterile dressing pads', unit: 'piece' },
  sanitizer: { name: 'Hand sanitizer 100 ml', unit: 'bottle' },
};

export async function suppliesOf(db: DbOrTx, providerId: string) {
  const rows = await db.select().from(providerSupplies).where(eq(providerSupplies.providerId, providerId)).orderBy(asc(providerSupplies.code));
  return rows.map((r) => ({ code: r.code, name: SUPPLY_CATALOG[r.code]?.name ?? r.code, unit: SUPPLY_CATALOG[r.code]?.unit ?? 'unit', onHand: r.onHand, reorderLevel: r.reorderLevel }));
}

const zItems = z
  .array(z.object({ code: z.string().min(1).max(40), qty: z.number().int().min(1).max(10_000) }))
  .min(1)
  .max(30)
  .refine((items) => items.every((i) => SUPPLY_CATALOG[i.code]), 'Unknown supply code');

export async function fieldOpsRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;
  const providerOnly = requireRoles(svc, 'provider');
  const opsOnly = requireRoles(svc, 'coordinator', 'ops_admin', 'super_admin');
  const pid = (ctx: RequestCtx): string => {
    if (!ctx.user.providerId) throw errors.forbidden('Provider profile required');
    return ctx.user.providerId;
  };

  app.get('/provider/route', { preHandler: providerOnly }, async (req) => {
    const q = parse(z.object({ date: zDate.optional() }), req.query);
    const id = pid(req.ctx);
    const date = q.date ?? istDate();
    const { start, end } = istDayBounds(date);
    const [prov] = await db.select().from(providers).where(eq(providers.id, id));
    const visits = await db
      .select()
      .from(homeVisits)
      .where(and(eq(homeVisits.providerId, id), gte(homeVisits.preferredStart, start), lt(homeVisits.preferredStart, end), notInArray(homeVisits.status, ['cancelled', 'unassigned'])))
      .orderBy(asc(homeVisits.preferredStart));
    const services = await db.select().from(homeVisitServices);
    const dur = new Map(services.map((s) => [s.code, { mins: s.durationMins, name: s.name }]));
    const located = visits.filter((v) => typeof v.address.lat === 'number' && typeof v.address.lng === 'number');
    let startLocation: { lat: number; lng: number } | null =
      prov?.lastLat != null && prov?.lastLng != null ? { lat: prov.lastLat, lng: prov.lastLng } : null;
    if (!startLocation && located.length) {
      // Zone centre fallback: the centroid of the day's stops.
      startLocation = { lat: located.reduce((s, v) => s + v.address.lat!, 0) / located.length, lng: located.reduce((s, v) => s + v.address.lng!, 0) / located.length };
    }
    // Order: time window first; among visits whose windows overlap the earliest remaining window, nearest neighbour.
    const remaining = [...visits];
    const ordered: typeof visits = [];
    let here = startLocation;
    while (remaining.length) {
      const earliest = remaining.reduce((a, b) => (b.preferredStart < a.preferredStart ? b : a));
      const candidates = remaining.filter((v) => v.preferredStart < earliest.preferredEnd);
      const pick =
        here && candidates.every((c) => typeof c.address.lat === 'number')
          ? candidates.reduce((a, b) => (haversineKm(here!.lat, here!.lng, a.address.lat!, a.address.lng!) <= haversineKm(here!.lat, here!.lng, b.address.lat!, b.address.lng!) ? a : b))
          : earliest;
      ordered.push(pick);
      remaining.splice(remaining.indexOf(pick), 1);
      if (typeof pick.address.lat === 'number') here = { lat: pick.address.lat, lng: pick.address.lng! };
    }
    // Distances/ETAs via the MapsProvider (Google Distance Matrix when configured, else haversine at ROUTE_SPEED_KMH).
    const stops = [];
    let prev = startLocation;
    let clock = new Date(Math.max(Date.now(), ordered[0]?.preferredStart.getTime() ?? Date.now()));
    let totalKm = 0;
    for (const [i, v] of ordered.entries()) {
      const hasLoc = typeof v.address.lat === 'number' && typeof v.address.lng === 'number';
      let km = 0;
      let minutes = 0;
      if (prev && hasLoc) {
        [{ km, minutes }] = await svc.partners.maps.distances(prev, [{ lat: v.address.lat!, lng: v.address.lng! }]);
      }
      const arrive = new Date(Math.max(clock.getTime() + minutes * 60_000, i === 0 ? clock.getTime() : 0));
      const eta = new Date(Math.max(arrive.getTime(), v.preferredStart.getTime()));
      totalKm += km;
      stops.push({
        order: i + 1,
        visitId: v.id,
        serviceName: dur.get(v.serviceCode)?.name ?? v.serviceCode,
        window: { start: iso(v.preferredStart), end: iso(v.preferredEnd) },
        address: v.address,
        lat: hasLoc ? v.address.lat! : null,
        lng: hasLoc ? v.address.lng! : null,
        distanceFromPrevKm: Math.round(km * 10) / 10,
        etaAt: iso(eta),
      });
      clock = new Date(eta.getTime() + (dur.get(v.serviceCode)?.mins ?? 30) * 60_000);
      if (hasLoc) prev = { lat: v.address.lat!, lng: v.address.lng! };
    }
    return { date, stops, totalKm: Math.round(totalKm * 10) / 10, startLocation };
  });

  app.post('/provider/attendance', { preHandler: providerOnly }, async (req, reply) => {
    const body = parse(z.object({ action: z.enum(['check_in', 'check_out']), lat: z.number().min(-90).max(90).optional(), lng: z.number().min(-180).max(180).optional() }), req.body);
    const id = pid(req.ctx);
    const [row] = await db.insert(providerAttendance).values({ providerId: id, action: body.action, lat: body.lat ?? null, lng: body.lng ?? null }).returning();
    if (body.lat !== undefined && body.lng !== undefined) await db.update(providers).set({ lastLat: body.lat, lastLng: body.lng, lastLocationAt: new Date() }).where(eq(providers.id, id));
    await audit(db, req.ctx.actor, { action: `provider.${body.action}`, entityType: 'provider', entityId: id });
    return reply.code(201).send({ id: row.id, action: row.action, at: iso(row.at), lat: row.lat, lng: row.lng });
  });

  app.get('/provider/attendance', { preHandler: providerOnly }, async (req) => {
    const q = parse(z.object({ month: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/).optional() }), req.query);
    const id = pid(req.ctx);
    const month = q.month ?? istDate().slice(0, 7);
    const [y, m] = month.split('-').map(Number);
    const first = `${month}-01`;
    const last = new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10);
    const from = istDayBounds(first).start;
    const to = istDayBounds(last).end;
    const rows = await db.select().from(providerAttendance).where(and(eq(providerAttendance.providerId, id), gte(providerAttendance.at, from), lt(providerAttendance.at, to))).orderBy(asc(providerAttendance.at));
    const visits = await db
      .select({ completedAt: homeVisits.completedAt })
      .from(homeVisits)
      .where(and(eq(homeVisits.providerId, id), eq(homeVisits.status, 'completed'), gte(homeVisits.completedAt, from), lt(homeVisits.completedAt, to)));
    const days = new Map<string, { checkIn: Date | null; checkOut: Date | null }>();
    for (const r of rows) {
      const d = istDate(r.at);
      const cur = days.get(d) ?? { checkIn: null, checkOut: null };
      if (r.action === 'check_in' && !cur.checkIn) cur.checkIn = r.at;
      if (r.action === 'check_out') cur.checkOut = r.at;
      days.set(d, cur);
    }
    const visitCount = new Map<string, number>();
    for (const v of visits) if (v.completedAt) visitCount.set(istDate(v.completedAt), (visitCount.get(istDate(v.completedAt)) ?? 0) + 1);
    const dates = [...new Set([...days.keys(), ...visitCount.keys()])].sort();
    return {
      items: dates.map((date) => {
        const d = days.get(date) ?? { checkIn: null, checkOut: null };
        const hours = d.checkIn && d.checkOut && d.checkOut > d.checkIn ? Math.round(((d.checkOut.getTime() - d.checkIn.getTime()) / 3600_000) * 10) / 10 : null;
        return { date, checkInAt: iso(d.checkIn), checkOutAt: iso(d.checkOut), hours, visits: visitCount.get(date) ?? 0 };
      }),
    };
  });

  app.get('/provider/supplies', { preHandler: providerOnly }, async (req) => list(await suppliesOf(db, pid(req.ctx))));

  app.post('/provider/supplies/usage', { preHandler: providerOnly }, async (req) => {
    const body = parse(z.object({ visitId: zUuid, items: zItems }), req.body);
    const id = pid(req.ctx);
    const [v] = await db.select({ providerId: homeVisits.providerId }).from(homeVisits).where(eq(homeVisits.id, body.visitId));
    if (!v || v.providerId !== id) {
      await audit(db, req.ctx.actor, { action: 'supplies.usage', entityType: 'home_visit', entityId: body.visitId, outcome: 'denied' });
      throw errors.forbidden('This visit is not assigned to you');
    }
    await db.transaction(async (tx) => {
      for (const it of body.items) {
        const updated = await tx
          .update(providerSupplies)
          .set({ onHand: sql`${providerSupplies.onHand} - ${it.qty}`, updatedAt: new Date() })
          .where(and(eq(providerSupplies.providerId, id), eq(providerSupplies.code, it.code), gte(providerSupplies.onHand, it.qty)))
          .returning();
        if (!updated.length) throw errors.conflict(`Not enough ${SUPPLY_CATALOG[it.code].name} in stock`, { code: it.code });
      }
      await tx.insert(supplyUsage).values({ providerId: id, visitId: body.visitId, items: body.items });
      await audit(tx, req.ctx.actor, { action: 'supplies.usage', entityType: 'home_visit', entityId: body.visitId, metadata: { items: body.items.length } });
    });
    return list(await suppliesOf(db, id));
  });

  app.post('/ops/providers/:id/supplies/restock', { preHandler: requireRoles(svc, 'ops_admin', 'super_admin', 'coordinator') }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ items: zItems }), req.body);
    const [p] = await db.select({ kind: providers.kind }).from(providers).where(eq(providers.id, id));
    if (!p || p.kind !== 'field') throw errors.notFound('Provider');
    await db.transaction(async (tx) => {
      for (const it of body.items) {
        await tx
          .insert(providerSupplies)
          .values({ providerId: id, code: it.code, onHand: it.qty, reorderLevel: 5 })
          .onConflictDoUpdate({ target: [providerSupplies.providerId, providerSupplies.code], set: { onHand: sql`${providerSupplies.onHand} + ${it.qty}`, updatedAt: new Date() } });
      }
      await audit(tx, req.ctx.actor, { action: 'supplies.restock', entityType: 'provider', entityId: id, metadata: { items: body.items.length } });
    });
    return list(await suppliesOf(db, id));
  });

  app.get('/ops/supplies/low-stock', { preHandler: opsOnly }, async () => {
    const rows = await db
      .select({ s: providerSupplies, name: providers.name })
      .from(providerSupplies)
      .innerJoin(providers, eq(providers.id, providerSupplies.providerId))
      .where(lte(providerSupplies.onHand, providerSupplies.reorderLevel))
      .orderBy(providers.name, providerSupplies.code);
    return list(
      rows.map((r) => ({
        providerId: r.s.providerId,
        providerName: r.name,
        code: r.s.code,
        name: SUPPLY_CATALOG[r.s.code]?.name ?? r.s.code,
        onHand: r.s.onHand,
        reorderLevel: r.s.reorderLevel,
      })),
    );
  });
}

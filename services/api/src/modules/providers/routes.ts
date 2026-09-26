import { and, eq, ilike, or } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { facilities, specialties } from '../../db/schema.js';
import { list, pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { parse } from '../../lib/validate.js';

export type FacilityRow = typeof facilities.$inferSelect;

export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export function toFacility(f: FacilityRow, origin?: { lat: number; lng: number }) {
  return {
    id: f.id,
    name: f.name,
    type: f.type,
    address: f.address,
    area: f.area,
    city: f.city,
    phone: f.phone,
    lat: f.lat,
    lng: f.lng,
    distanceKm: origin ? Math.round(haversineKm(origin.lat, origin.lng, f.lat, f.lng) * 10) / 10 : null,
    services: f.services,
    emergency24x7: f.emergency24x7,
    verified: f.verified,
  };
}

/** Specialty catalog and facility directory (the "providers" directory module). */
export async function providerDirectoryRoutes(app: FastifyInstance): Promise<void> {
  const db = app.svc.db;

  app.get('/specialties', async () => {
    const rows = await db.select().from(specialties).orderBy(specialties.name);
    return list(rows.map((s) => ({ code: s.code, name: s.name, icon: s.icon })));
  });

  app.get('/facilities', async (req) => {
    const q = parse(
      z.object({
        type: z.enum(['hospital', 'clinic', 'lab', 'pharmacy']).optional(),
        q: z.string().max(100).optional(),
        lat: z.coerce.number().min(-90).max(90).optional(),
        lng: z.coerce.number().min(-180).max(180).optional(),
      }),
      req.query,
    );
    const page = pageFromQuery(req.query);
    const conds = [eq(facilities.verified, true)];
    if (q.type) conds.push(eq(facilities.type, q.type));
    if (q.q) conds.push(or(ilike(facilities.name, `%${q.q}%`), ilike(facilities.area, `%${q.q}%`))!);
    const rows = await db.select().from(facilities).where(and(...conds)).orderBy(facilities.name);
    const origin = q.lat !== undefined && q.lng !== undefined ? { lat: q.lat, lng: q.lng } : undefined;
    const items = rows.map((f) => toFacility(f, origin));
    if (origin) items.sort((a, b) => (a.distanceKm ?? 0) - (b.distanceKm ?? 0));
    return paginateArray(items, page);
  });
}

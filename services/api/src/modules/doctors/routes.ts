import { and, asc, desc, eq, gt, gte, inArray, lt, min } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import { facilities, providers, reviews, slots, specialties } from '../../db/schema.js';
import { errors } from '../../lib/errors.js';
import { list, pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { istDate, istDayBounds, iso } from '../../lib/time.js';
import { parse, zBoolQuery, zDate, zUuid } from '../../lib/validate.js';

export type ProviderRow = typeof providers.$inferSelect;

const LANG_NAMES: Record<string, string> = { en: 'English', hi: 'Hindi', te: 'Telugu', ta: 'Tamil', kn: 'Kannada', ur: 'Urdu', mr: 'Marathi' };

export function isBookableDoctor(p: ProviderRow, now = new Date()): boolean {
  return p.kind === 'doctor' && p.verificationStatus === 'verified' && p.credentialExpiresAt > now;
}

export async function specialtyNames(db: DbOrTx): Promise<Map<string, string>> {
  const rows = await db.select().from(specialties);
  return new Map(rows.map((s) => [s.code, s.name]));
}

async function nextAvailableMap(db: DbOrTx): Promise<Map<string, Date>> {
  const rows = await db
    .select({ doctorId: slots.doctorId, next: min(slots.startAt) })
    .from(slots)
    .where(and(eq(slots.status, 'available'), gt(slots.startAt, new Date())))
    .groupBy(slots.doctorId);
  return new Map(rows.filter((r) => r.next).map((r) => [r.doctorId, new Date(r.next as unknown as string)]));
}

export async function toDoctors(db: DbOrTx, rows: ProviderRow[], ctx: { specialty?: string; language?: string } = {}) {
  const [names, nextMap, facs] = await Promise.all([specialtyNames(db), nextAvailableMap(db), db.select().from(facilities)]);
  const facMap = new Map(facs.map((f) => [f.id, f]));
  const now = new Date();
  const today = istDate(now);
  return rows.map((d) => {
    const next = nextMap.get(d.id) ?? null;
    const availableToday = !!next && istDate(next) === today;
    const availableNow = !!next && next.getTime() - now.getTime() <= 30 * 60_000;
    const factors: string[] = [];
    if (ctx.specialty && d.specialty === ctx.specialty) factors.push('Specialty match');
    if (availableNow) factors.push('Available now');
    else if (availableToday) factors.push('Available today');
    if (ctx.language) {
      const lname = LANG_NAMES[ctx.language] ?? ctx.language;
      if (d.languages.some((l) => l.toLowerCase() === lname.toLowerCase())) factors.push(`Speaks ${lname}`);
    } else if (d.languages.includes('Telugu')) {
      factors.push('Speaks Telugu');
    }
    if ((d.rating ?? 0) >= 4.5) factors.push(`Highly rated (${d.rating})`);
    if (d.experienceYears >= 10) factors.push(`${d.experienceYears}+ years experience`);
    factors.push('Verified credentials');
    const fac = d.facilityId ? facMap.get(d.facilityId) : undefined;
    return {
      id: d.id,
      name: d.name,
      specialty: d.specialty ?? 'general_physician',
      specialtyName: names.get(d.specialty ?? '') ?? 'General Physician',
      qualifications: d.qualification,
      experienceYears: d.experienceYears,
      rating: d.rating ?? 0,
      ratingCount: d.ratingCount,
      languages: d.languages,
      fees: { video: d.feeVideo, audio: d.feeAudio, chat: d.feeChat, inClinic: d.feeInClinic },
      photoUrl: d.photoUrl,
      verified: true as const,
      nextAvailableAt: iso(next),
      availableNow,
      facility: fac ? { id: fac.id, name: fac.name, area: fac.area } : null,
      rankingFactors: factors,
      _availableToday: availableToday,
    };
  });
}

export function feeForMode(d: ProviderRow, mode: string): number | null {
  switch (mode) {
    case 'video':
      return d.feeVideo;
    case 'audio':
      return d.feeAudio;
    case 'chat':
      return d.feeChat;
    case 'in_clinic':
      return d.feeInClinic;
    default:
      return null;
  }
}

const stripInternal = <T extends { _availableToday?: boolean }>(d: T) => {
  const { _availableToday: _a, ...rest } = d;
  return rest;
};

/** DoctorDetail (contract sections 6 + 33): published reviews only. */
export async function doctorDetail(db: DbOrTx, d: ProviderRow) {
  const [doc] = await toDoctors(db, [d]);
  const rows = await db
    .select()
    .from(reviews)
    .where(and(eq(reviews.doctorId, d.id), eq(reviews.status, 'published')))
    .orderBy(desc(reviews.createdAt))
    .limit(10);
  return {
    ...stripInternal(doc),
    bio: d.bio,
    registrationNumber: d.registrationNumber,
    reviews: rows.map((r) => ({ id: r.id, rating: r.rating, text: r.text ?? '', authorLabel: r.authorLabel, source: 'verified_patient' as const, createdAt: iso(r.createdAt) })),
  };
}

/** Slot statuses clients may see (retired slots are internal). */
export const VISIBLE_SLOT_STATUSES = ['available', 'booked', 'held'];
export const toSlot = (s: typeof slots.$inferSelect) => ({ id: s.id, startAt: iso(s.startAt), endAt: iso(s.endAt), status: s.status, modes: s.modes });

export async function doctorRoutes(app: FastifyInstance): Promise<void> {
  const db = app.svc.db;

  app.get('/doctors', async (req) => {
    const q = parse(
      z.object({
        specialty: z.string().max(40).optional(),
        q: z.string().max(100).optional(),
        language: z.string().max(20).optional(),
        mode: z.enum(['video', 'audio', 'chat', 'in_clinic']).optional(),
        availableToday: zBoolQuery.optional(),
      }),
      req.query,
    );
    const page = pageFromQuery(req.query);
    const conds = [
      eq(providers.kind, 'doctor'),
      eq(providers.verificationStatus, 'verified'),
      gt(providers.credentialExpiresAt, new Date()),
      eq(providers.acceptingBookings, true),
    ];
    if (q.specialty) conds.push(eq(providers.specialty, q.specialty));
    const rows = await db.select().from(providers).where(and(...conds)).orderBy(desc(providers.rating), asc(providers.name));
    let docs = await toDoctors(db, rows, { specialty: q.specialty, language: q.language });
    if (q.q) {
      const needle = q.q.toLowerCase();
      docs = docs.filter((d) => d.name.toLowerCase().includes(needle) || d.specialtyName.toLowerCase().includes(needle) || d.qualifications.toLowerCase().includes(needle));
    }
    if (q.language) {
      const lname = (LANG_NAMES[q.language] ?? q.language).toLowerCase();
      docs = docs.filter((d) => d.languages.some((l) => l.toLowerCase() === lname));
    }
    if (q.mode) {
      const key = q.mode === 'in_clinic' ? 'inClinic' : q.mode;
      docs = docs.filter((d) => d.fees[key as keyof typeof d.fees] !== null);
    }
    if (q.availableToday) docs = docs.filter((d) => d._availableToday);
    docs.sort((a, b) => b.rankingFactors.length - a.rankingFactors.length || b.rating - a.rating);
    return paginateArray(docs.map(stripInternal), page);
  });

  app.get('/doctors/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [d] = await db.select().from(providers).where(eq(providers.id, id));
    if (!d || !isBookableDoctor(d)) throw errors.notFound('Doctor');
    return doctorDetail(db, d);
  });

  app.get('/doctors/:id/slots', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const q = parse(z.object({ date: zDate.optional() }), req.query);
    const [d] = await db.select().from(providers).where(eq(providers.id, id));
    if (!d || !isBookableDoctor(d)) throw errors.notFound('Doctor');
    const { start, end } = istDayBounds(q.date ?? istDate());
    const now = new Date();
    const rows = await db
      .select()
      .from(slots)
      .where(and(eq(slots.doctorId, id), gte(slots.startAt, start > now ? start : now), lt(slots.startAt, end), inArray(slots.status, VISIBLE_SLOT_STATUSES)))
      .orderBy(asc(slots.startAt));
    return list(rows.map(toSlot));
  });
}

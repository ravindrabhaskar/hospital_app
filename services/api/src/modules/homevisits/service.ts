import { and, eq, gt, gte, inArray, lt, notInArray, sql } from 'drizzle-orm';
import type { Db, DbOrTx } from '../../db/client.js';
import { homeVisitServices, homeVisits, patients, providerZones, providers, serviceZones, users, type AddressJson, type TimelineEntry } from '../../db/schema.js';
import { resolvePatientAccess } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { OPS_ROLES, SYSTEM_ACTOR, hasRole, type Actor, type RequestCtx } from '../../lib/context.js';
import { maskPhone } from '../../lib/crypto.js';
import { errors } from '../../lib/errors.js';
import { istDate, istDayBounds, iso } from '../../lib/time.js';
import { addEvent, advanceEpisode, settleEpisodeAfterBookingEnded } from '../episodes/service.js';
import type { NotificationService } from '../notifications/service.js';
import { clinicalContext } from '../patients/service.js';
import type { PaymentEffects, PaymentRow } from '../payments/service.js';
import { labContextForVisits } from '../lab/service.js';
import { toVital, vitalsForVisits } from '../vitals/service.js';

export type HomeVisitRow = typeof homeVisits.$inferSelect;
export type VisitView = 'family' | 'provider' | 'doctor' | 'ops';

export const LIVE_PROVIDER_STATUSES = ['assigned', 'accepted', 'en_route', 'arrived', 'in_progress', 'escalated'];

/**
 * Statuses in which the assigned provider may see the precise address (line1/line2/landmark and
 * exact coordinates). Before the provider accepts (`assigned`), and once a visit is cancelled or
 * handed back, only the locality (city + pincode) and an approximate location (~1 km) are shared.
 */
export const FULL_ADDRESS_STATUSES = ['accepted', 'en_route', 'arrived', 'in_progress', 'escalated', 'completed'];

export type MaskedAddress = { city: string; pincode: string; lat?: number; lng?: number; approximate: true };

/** Round a coordinate to 2 decimals (~1.1 km) so it cannot pinpoint a home. */
export const approxCoord = (n: number): number => Math.round(n * 100) / 100;

export function providerMaySeeFullAddress(status: string): boolean {
  return FULL_ADDRESS_STATUSES.includes(status);
}

export function maskAddress(a: AddressJson): MaskedAddress {
  return {
    city: a.city,
    pincode: a.pincode,
    ...(typeof a.lat === 'number' && typeof a.lng === 'number' ? { lat: approxCoord(a.lat), lng: approxCoord(a.lng) } : {}),
    approximate: true,
  };
}

/** Address as the given view may see it: providers get locality only until they accept. */
export function addressFor(view: VisitView, row: Pick<HomeVisitRow, 'status' | 'address'>): AddressJson | MaskedAddress {
  if (view === 'provider' && !providerMaySeeFullAddress(row.status)) return maskAddress(row.address);
  return row.address;
}

export async function findZoneForPincode(db: DbOrTx, pincode: string) {
  const zones = await db.select().from(serviceZones);
  return zones.find((z) => z.pincodes.includes(pincode)) ?? null;
}

export const timelineAdd = (row: HomeVisitRow, status: string, note: string | null = null): TimelineEntry[] => [
  ...row.timeline,
  { status, at: new Date().toISOString(), note },
];

/** A provider is eligible only if verified, credential unexpired, active user. */
export function providerEligible(p: typeof providers.$inferSelect, now = new Date()): boolean {
  return p.kind === 'field' && p.verificationStatus === 'verified' && p.credentialExpiresAt > now;
}

/**
 * Auto-match: verified, unexpired, on-duty field provider whose zone covers the pincode,
 * with the service capability, not previously rejected, and no overlapping live visit.
 * Ties are broken by fewest visits today.
 */
export async function findMatch(db: DbOrTx, visit: HomeVisitRow): Promise<typeof providers.$inferSelect | null> {
  const zone = visit.zoneId ?? (await findZoneForPincode(db, visit.address.pincode))?.id;
  if (!zone) return null;
  const now = new Date();
  const candidates = await db
    .select({ p: providers })
    .from(providers)
    .innerJoin(providerZones, eq(providerZones.providerId, providers.id))
    .innerJoin(users, eq(users.id, providers.userId))
    .where(
      and(
        eq(providerZones.zoneId, zone),
        eq(providers.kind, 'field'),
        eq(providers.verificationStatus, 'verified'),
        gt(providers.credentialExpiresAt, now),
        eq(providers.onDuty, true),
        eq(users.status, 'active'),
      ),
    );
  const eligible = candidates
    .map((c) => c.p)
    .filter((p) => providerEligible(p, now) && p.capabilities.includes(visit.serviceCode) && !visit.rejectedProviderIds.includes(p.id));
  if (!eligible.length) return null;
  const ids = eligible.map((p) => p.id);
  const overlapping = await db
    .select({ providerId: homeVisits.providerId })
    .from(homeVisits)
    .where(
      and(
        inArray(homeVisits.providerId, ids),
        inArray(homeVisits.status, LIVE_PROVIDER_STATUSES),
        lt(homeVisits.preferredStart, visit.preferredEnd),
        gt(homeVisits.preferredEnd, visit.preferredStart),
        sql`${homeVisits.id} <> ${visit.id}`,
      ),
    );
  const busy = new Set(overlapping.map((o) => o.providerId));
  const free = eligible.filter((p) => !busy.has(p.id));
  if (!free.length) return null;
  const { start, end } = istDayBounds(istDate(visit.preferredStart));
  const counts = await db
    .select({ providerId: homeVisits.providerId, n: sql<number>`count(*)::int` })
    .from(homeVisits)
    .where(
      and(
        inArray(
          homeVisits.providerId,
          free.map((p) => p.id),
        ),
        gte(homeVisits.preferredStart, start),
        lt(homeVisits.preferredStart, end),
        notInArray(homeVisits.status, ['cancelled']),
      ),
    )
    .groupBy(homeVisits.providerId);
  const countOf = new Map(counts.map((c) => [c.providerId, Number(c.n)]));
  free.sort((a, b) => (countOf.get(a.id) ?? 0) - (countOf.get(b.id) ?? 0) || a.name.localeCompare(b.name));
  return free[0];
}

/** Run the matcher and persist the result (assigned or unassigned). */
export async function autoAssign(db: DbOrTx, visit: HomeVisitRow, actor: Actor, opts: { onlyIfMatched?: boolean } = {}): Promise<HomeVisitRow> {
  const match = await findMatch(db, visit);
  if (!match && opts.onlyIfMatched) return visit;
  const [row] = await db
    .update(homeVisits)
    .set(
      match
        ? { status: 'assigned', providerId: match.id, assignedAt: new Date(), timeline: timelineAdd(visit, 'assigned', null), updatedAt: new Date() }
        : { status: 'unassigned', providerId: null, timeline: timelineAdd(visit, 'unassigned', 'No provider available yet'), updatedAt: new Date() },
    )
    .where(eq(homeVisits.id, visit.id))
    .returning();
  await audit(db, actor, {
    action: 'home_visit.auto_match',
    entityType: 'home_visit',
    entityId: visit.id,
    metadata: { matched: !!match, providerId: match?.id ?? null },
  });
  return row;
}

/** Decide which view of a visit the caller may see. Throws FORBIDDEN (audited) if none. */
export async function visitViewFor(db: DbOrTx, ctx: RequestCtx, row: HomeVisitRow): Promise<VisitView> {
  if (hasRole(ctx.user, 'provider') && ctx.user.providerId && row.providerId === ctx.user.providerId) return 'provider';
  const access = await resolvePatientAccess(db, ctx.user, row.patientId);
  if (access) {
    if (access.isOwner || (access.via.includes('grant') && ['book', 'view_records', 'manage_care'].some((p) => access.permissions.has(p as never)))) {
      return 'family';
    }
    if (access.via.includes('doctor')) return 'doctor';
    if (access.isStaffOps || hasRole(ctx.user, ...OPS_ROLES)) return 'ops';
  }
  await audit(db, ctx.actor, { action: 'home_visit.read', entityType: 'home_visit', entityId: row.id, outcome: 'denied' });
  throw errors.forbidden();
}

export async function toHomeVisits(db: DbOrTx, rows: HomeVisitRow[], viewOf: (r: HomeVisitRow) => VisitView) {
  if (!rows.length) return [];
  const [services, pats, provs, vit, labCtx] = await Promise.all([
    db.select().from(homeVisitServices),
    db
      .select({ id: patients.id, name: patients.name })
      .from(patients)
      .where(inArray(patients.id, [...new Set(rows.map((r) => r.patientId))])),
    (async () => {
      const ids = [...new Set(rows.map((r) => r.providerId).filter((x): x is string => !!x))];
      if (!ids.length) return [];
      return db.select({ p: providers, phone: users.phone }).from(providers).innerJoin(users, eq(users.id, providers.userId)).where(inArray(providers.id, ids));
    })(),
    vitalsForVisits(
      db,
      rows.map((r) => r.id),
    ),
    labContextForVisits(
      db,
      rows.filter((r) => r.serviceCode === 'sample_collection').map((r) => r.id),
    ),
  ]);
  const sm = new Map(services.map((s) => [s.code, s]));
  const pm = new Map(pats.map((p) => [p.id, p.name]));
  const prm = new Map(provs.map((x) => [x.p.id, x]));
  const out = [];
  for (const r of rows) {
    const view = viewOf(r);
    const prov = r.providerId ? prm.get(r.providerId) : undefined;
    let patientContext = null;
    const contextAllowed =
      view === 'doctor' || (view === 'provider' && !(r.status === 'completed' && r.completedAt && Date.now() - r.completedAt.getTime() > 24 * 3600_000));
    if (contextAllowed) {
      const c = await clinicalContext(db, r.patientId);
      patientContext = { age: c.age, gender: c.gender, allergies: c.allergies, conditions: c.conditions, activeMedications: c.medications };
    }
    out.push({
      id: r.id,
      status: r.status,
      serviceCode: r.serviceCode,
      serviceName: sm.get(r.serviceCode)?.name ?? r.serviceCode,
      price: r.price,
      discountApplied: r.discountApplied,
      patientId: r.patientId,
      patientName: pm.get(r.patientId) ?? null,
      reason: r.reason,
      address: addressFor(view, r),
      /** True when `address` is reduced to locality + approximate location (provider has not accepted yet). */
      addressMasked: view === 'provider' && !providerMaySeeFullAddress(r.status),
      preferredStart: iso(r.preferredStart),
      preferredEnd: iso(r.preferredEnd),
      careEpisodeId: r.careEpisodeId,
      visitCode: view === 'family' ? r.visitCode : null,
      provider: prov ? { id: prov.p.id, name: prov.p.name, qualification: prov.p.qualification, photoUrl: prov.p.photoUrl, phoneMasked: maskPhone(prov.phone) } : null,
      etaMinutes: r.etaMinutes,
      timeline: r.timeline,
      patientContext,
      vitals: (vit.get(r.id) ?? []).map(toVital),
      observations: r.observations ?? null,
      summary: r.summary,
      escalation: r.escalation ?? null,
      /** Contract section 44 (additive): minimum-necessary lab context for sample-collection visits; no prices. */
      labOrder: labCtx.get(r.id) ?? null,
      createdAt: iso(r.createdAt),
    });
  }
  return out;
}

export async function toHomeVisit(db: DbOrTx, row: HomeVisitRow, view: VisitView) {
  return (await toHomeVisits(db, [row], () => view))[0];
}

export function homeVisitPaymentEffects(_notify: NotificationService): PaymentEffects {
  return {
    async onSucceeded(db: Db, p: PaymentRow) {
      await db.transaction(async (tx) => {
        const [v] = await tx.select().from(homeVisits).where(eq(homeVisits.id, p.refId));
        if (!v || v.status === 'cancelled') return;
        await advanceEpisode(tx, v.careEpisodeId, ['CARE_SCHEDULED'], 'Home visit paid', SYSTEM_ACTOR, { nextAction: 'Home visit scheduled' });
        await addEvent(tx, v.careEpisodeId, 'home_visit_paid', 'Home visit payment received', SYSTEM_ACTOR, { homeVisitId: v.id });
      });
    },
    async onFailed(db: Db, p: PaymentRow) {
      await db.transaction(async (tx) => {
        const [v] = await tx.select().from(homeVisits).where(eq(homeVisits.id, p.refId));
        if (!v || ['cancelled', 'completed', 'in_progress'].includes(v.status)) return;
        await tx
          .update(homeVisits)
          .set({ status: 'cancelled', cancelReason: 'payment_failed', timeline: timelineAdd(v, 'cancelled', 'Payment failed'), updatedAt: new Date() })
          .where(eq(homeVisits.id, v.id));
        await addEvent(tx, v.careEpisodeId, 'home_visit_cancelled', 'Home visit cancelled: payment failed', SYSTEM_ACTOR, { homeVisitId: v.id });
        await settleEpisodeAfterBookingEnded(tx, v.careEpisodeId, 'payment_failed', SYSTEM_ACTOR);
      });
    },
    /** A visit cancelled for non-payment released its provider; the patient must request a new visit. */
    async onRetry(tx, p: PaymentRow) {
      const [v] = await tx.select({ status: homeVisits.status }).from(homeVisits).where(eq(homeVisits.id, p.refId));
      if (!v) throw errors.notFound('Home visit');
      if (v.status === 'cancelled') throw errors.conflict('This home visit was cancelled. Please request a new visit.', { status: v.status });
    },
  };
}

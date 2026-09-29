import { eq, inArray } from 'drizzle-orm';
import type { DbOrTx } from '../../db/client.js';
import { careEpisodes, episodeEvents, patients, users } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import type { Actor } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { iso } from '../../lib/time.js';

export const EPISODE_STATUSES = [
  'NEW',
  'INTAKE',
  'AWAITING_CARE',
  'CARE_SCHEDULED',
  'UNDER_CARE',
  'FOLLOW_UP',
  'RESOLVED',
  'ESCALATED',
  'EMERGENCY',
  'TRANSFERRED',
  'CANCELLED',
] as const;
export type EpisodeStatus = (typeof EPISODE_STATUSES)[number];

export const TRANSITIONS: Record<EpisodeStatus, EpisodeStatus[]> = {
  NEW: ['INTAKE', 'AWAITING_CARE', 'CARE_SCHEDULED', 'ESCALATED', 'EMERGENCY', 'CANCELLED'],
  INTAKE: ['AWAITING_CARE', 'CARE_SCHEDULED', 'ESCALATED', 'EMERGENCY', 'CANCELLED', 'RESOLVED'],
  AWAITING_CARE: ['CARE_SCHEDULED', 'ESCALATED', 'EMERGENCY', 'CANCELLED'],
  CARE_SCHEDULED: ['UNDER_CARE', 'AWAITING_CARE', 'ESCALATED', 'EMERGENCY', 'CANCELLED'],
  UNDER_CARE: ['FOLLOW_UP', 'RESOLVED', 'ESCALATED', 'EMERGENCY', 'TRANSFERRED'],
  FOLLOW_UP: ['RESOLVED', 'CARE_SCHEDULED', 'UNDER_CARE', 'ESCALATED', 'EMERGENCY'],
  ESCALATED: ['AWAITING_CARE', 'CARE_SCHEDULED', 'UNDER_CARE', 'EMERGENCY', 'TRANSFERRED', 'RESOLVED'],
  EMERGENCY: ['TRANSFERRED', 'UNDER_CARE', 'RESOLVED'],
  RESOLVED: [],
  CANCELLED: [],
  TRANSFERRED: [],
};

export const ACTIVE_STATUSES: EpisodeStatus[] = ['NEW', 'INTAKE', 'AWAITING_CARE', 'CARE_SCHEDULED', 'UNDER_CARE', 'FOLLOW_UP', 'ESCALATED', 'EMERGENCY'];

/** Domain rule: RESOLVED -> FOLLOW_UP is allowed only for a doctor. */
export function canTransition(from: string, to: string, actorRoles: string[] = []): boolean {
  if (from === 'RESOLVED' && to === 'FOLLOW_UP') return actorRoles.includes('doctor');
  return (TRANSITIONS[from as EpisodeStatus] ?? []).includes(to as EpisodeStatus);
}

export type EpisodeRow = typeof careEpisodes.$inferSelect;

export async function addEvent(
  db: DbOrTx,
  episodeId: string,
  type: string,
  description: string,
  actor: Actor,
  data: Record<string, unknown> = {},
): Promise<typeof episodeEvents.$inferSelect> {
  const [row] = await db
    .insert(episodeEvents)
    .values({ episodeId, type, description, actorUserId: actor.userId, actorName: actor.name, actorRole: actor.role, data })
    .returning();
  return row;
}

export async function createEpisode(
  db: DbOrTx,
  p: { patientId: string; title: string; concern: string; priority?: string; actor: Actor; status?: EpisodeStatus },
): Promise<EpisodeRow> {
  const [row] = await db
    .insert(careEpisodes)
    .values({
      patientId: p.patientId,
      title: p.title.slice(0, 200),
      concern: p.concern.slice(0, 2000),
      priority: p.priority ?? 'routine',
      createdByUserId: p.actor.userId,
      status: 'NEW',
    })
    .returning();
  await addEvent(db, row.id, 'created', 'Care episode created', p.actor, {});
  await audit(db, p.actor, { action: 'episode.create', entityType: 'care_episode', entityId: row.id });
  return row;
}

/** Validated transition; writes an event AND an audit row. Throws INVALID_STATE_TRANSITION. */
export async function transitionEpisode(
  db: DbOrTx,
  episodeId: string,
  to: string,
  reason: string,
  actor: Actor,
  actorRoles: string[] = [],
  extra: Partial<Pick<EpisodeRow, 'priority' | 'nextAction' | 'ownerUserId'>> = {},
): Promise<EpisodeRow> {
  const [ep] = await db.select().from(careEpisodes).where(eq(careEpisodes.id, episodeId));
  if (!ep) throw errors.notFound('Care episode');
  if (!canTransition(ep.status, to, actorRoles)) {
    await audit(db, actor, {
      action: 'episode.transition',
      entityType: 'care_episode',
      entityId: episodeId,
      outcome: 'denied',
      metadata: { from: ep.status, to },
    });
    throw errors.invalidTransition(ep.status, to);
  }
  const [row] = await db
    .update(careEpisodes)
    .set({ status: to, updatedAt: new Date(), ...extra })
    .where(eq(careEpisodes.id, episodeId))
    .returning();
  await addEvent(db, episodeId, to === 'ESCALATED' ? 'escalated' : 'status_changed', `Status changed from ${ep.status} to ${to}`, actor, {
    from: ep.status,
    to,
    reason,
  });
  await audit(db, actor, { action: 'episode.transition', entityType: 'care_episode', entityId: episodeId, metadata: { from: ep.status, to } });
  return row;
}

/**
 * System-driven advance: move along the first allowed target in `targets` (walking via
 * intermediate states if needed). Never throws on disallowed moves; returns the final row.
 */
export async function advanceEpisode(
  db: DbOrTx,
  episodeId: string,
  targets: EpisodeStatus[],
  reason: string,
  actor: Actor,
  extra: Partial<Pick<EpisodeRow, 'priority' | 'nextAction' | 'ownerUserId'>> = {},
): Promise<EpisodeRow | null> {
  const [ep] = await db.select().from(careEpisodes).where(eq(careEpisodes.id, episodeId));
  if (!ep) return null;
  for (const target of targets) {
    if (ep.status === target) {
      if (Object.keys(extra).length) {
        const [row] = await db.update(careEpisodes).set({ ...extra, updatedAt: new Date() }).where(eq(careEpisodes.id, episodeId)).returning();
        return row;
      }
      return ep;
    }
    if (canTransition(ep.status, target, [])) {
      return transitionEpisode(db, episodeId, target, reason, actor, [], extra);
    }
    // e.g. NEW -> INTAKE -> AWAITING_CARE style two-step paths
    const via = (TRANSITIONS[ep.status as EpisodeStatus] ?? []).find((mid) => canTransition(mid, target, []));
    if (via && !['CANCELLED', 'EMERGENCY', 'ESCALATED', 'RESOLVED', 'TRANSFERRED'].includes(via)) {
      await transitionEpisode(db, episodeId, via, reason, actor);
      return transitionEpisode(db, episodeId, target, reason, actor, [], extra);
    }
  }
  if (Object.keys(extra).length) {
    const [row] = await db.update(careEpisodes).set({ ...extra, updatedAt: new Date() }).where(eq(careEpisodes.id, episodeId)).returning();
    return row;
  }
  return ep;
}

export async function toCareEpisodes(db: DbOrTx, rows: EpisodeRow[]) {
  const pids = [...new Set(rows.map((r) => r.patientId))];
  const oids = [...new Set(rows.flatMap((r) => [r.ownerUserId, r.coordinatorUserId]).filter((x): x is string => !!x))];
  const pn = pids.length ? await db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, pids)) : [];
  const on = oids.length ? await db.select({ id: users.id, name: users.name }).from(users).where(inArray(users.id, oids)) : [];
  const pm = new Map(pn.map((x) => [x.id, x.name]));
  const om = new Map(on.map((x) => [x.id, x.name]));
  return rows.map((r) => ({
    id: r.id,
    patientId: r.patientId,
    patientName: pm.get(r.patientId) ?? null,
    title: r.title,
    concern: r.concern,
    status: r.status,
    priority: r.priority,
    ownerUserId: r.ownerUserId,
    ownerName: r.ownerUserId ? (om.get(r.ownerUserId) ?? null) : null,
    coordinatorUserId: r.coordinatorUserId,
    coordinatorName: r.coordinatorUserId ? (om.get(r.coordinatorUserId) ?? null) : null,
    nextAction: r.nextAction,
    tenantCode: r.tenantCode ?? null,
    createdAt: iso(r.createdAt),
    updatedAt: iso(r.updatedAt),
  }));
}

export async function toCareEpisode(db: DbOrTx, row: EpisodeRow) {
  return (await toCareEpisodes(db, [row]))[0];
}

export function toEvent(e: typeof episodeEvents.$inferSelect) {
  return {
    id: e.id,
    type: e.type,
    description: e.description,
    actorName: e.actorName,
    actorRole: e.actorRole,
    data: e.data,
    createdAt: iso(e.createdAt),
  };
}

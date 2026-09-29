import { and, desc, eq, inArray, isNotNull, sql } from 'drizzle-orm';
import type { DbOrTx } from '../../db/client.js';
import { careEpisodes, safetyRulePacks, users } from '../../db/schema.js';
import type { Services } from '../../services.js';
import { pickAvailableCoordinator } from '../coordinator/routes.js';
import { ACTIVE_STATUSES } from '../episodes/service.js';
import type { NotificationCategory } from '../notifications/service.js';
import type { SafetyEventRow, SafetyEventSource } from './service.js';

/** The coordinator responsible for a patient: the episode's, else any active episode's, else the least loaded one. */
export async function coordinatorFor(db: DbOrTx, patientId: string, careEpisodeId: string | null): Promise<{ id: string; name: string | null } | null> {
  let id: string | null = null;
  if (careEpisodeId) {
    const [ep] = await db.select({ c: careEpisodes.coordinatorUserId }).from(careEpisodes).where(eq(careEpisodes.id, careEpisodeId));
    id = ep?.c ?? null;
  }
  if (!id) {
    const [ep] = await db
      .select({ c: careEpisodes.coordinatorUserId })
      .from(careEpisodes)
      .where(and(eq(careEpisodes.patientId, patientId), inArray(careEpisodes.status, ACTIVE_STATUSES), isNotNull(careEpisodes.coordinatorUserId)))
      .orderBy(desc(careEpisodes.updatedAt))
      .limit(1);
    id = ep?.c ?? null;
  }
  id = id ?? (await pickAvailableCoordinator(db));
  if (!id) return null;
  const [u] = await db.select({ name: users.name }).from(users).where(eq(users.id, id));
  return { id, name: u?.name ?? null };
}

export async function activeRulePackVersion(db: DbOrTx): Promise<string | null> {
  const [p] = await db.select({ v: safetyRulePacks.version }).from(safetyRulePacks).where(eq(safetyRulePacks.active, true)).limit(1);
  return p?.v ?? null;
}

/** Users holding any of the roles (active accounts). */
export async function usersWithRoles(db: DbOrTx, roles: string[]): Promise<string[]> {
  const rows = await db
    .select({ id: users.id })
    .from(users)
    .where(and(eq(users.status, 'active'), sql`${users.roles} ?| ${sql.raw(`array[${roles.map((r) => `'${r.replace(/[^a-z_]/g, '')}'`).join(',')}]`)}`));
  return rows.map((r) => r.id);
}

export interface AlertInput {
  patientId: string;
  careEpisodeId?: string | null;
  level: 'urgent' | 'emergency';
  source: SafetyEventSource;
  rules: Array<{ ruleId: string; title: string }>;
  note?: string | null;
  /** Assign to (and notify) the patient's coordinator. Default true. */
  assignCoordinator?: boolean;
  /** Notify family with receive_alerts (and the patient's own account). Default true. */
  notifyFamily?: boolean;
  familyTemplate?: string;
  familyParams?: Record<string, string | number>;
  category?: NotificationCategory;
  deepLink?: string | null;
  dedupeKey?: string;
}

/**
 * Open a SafetyEvent assigned to the coordinator and notify the care circle. Used by the v1.3 monitors (check-in,
 * programs, geofence, SOS button, support clinical concerns, ambulance). Notification text is PHI-free on the lock screen.
 */
export async function raiseAlert(svc: Services, a: AlertInput, tx?: DbOrTx): Promise<SafetyEventRow> {
  const db = tx ?? svc.db;
  const coord = a.assignCoordinator === false ? null : await coordinatorFor(db, a.patientId, a.careEpisodeId ?? null);
  const event = await svc.safety.recordEvent(db, {
    patientId: a.patientId,
    careEpisodeId: a.careEpisodeId ?? null,
    level: a.level,
    source: a.source,
    rules: a.rules,
    rulePackVersion: await activeRulePackVersion(db),
    note: a.note ?? null,
    assignedToUserId: coord?.id ?? null,
    assignedToName: coord?.name ?? null,
  });
  const key = a.dedupeKey ?? `safety:${event.id}`;
  if (coord) {
    await svc.notify.notifyUsers([coord.id], {
      template: 'safety_alert',
      params: { patient: 'a patient in your caseload' },
      category: 'safety',
      critical: a.level === 'emergency',
      deepLink: `/ops/safety-events/${event.id}`,
      dedupeKey: `${key}:coordinator`,
    });
  }
  if (a.notifyFamily !== false) {
    await svc.notify.notifyPatient(a.patientId, {
      template: a.familyTemplate ?? 'safety_alert',
      params: a.familyParams ?? { patient: 'your family member' },
      category: a.category ?? 'safety',
      critical: a.level === 'emergency',
      deepLink: a.deepLink ?? null,
      dedupeKey: `${key}:family`,
    });
  }
  return event;
}

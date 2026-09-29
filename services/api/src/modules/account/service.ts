import { and, desc, eq, gte, inArray, isNull, lte, or } from 'drizzle-orm';
import type { AnyPgColumn } from 'drizzle-orm/pg-core';
import type { Db } from '../../db/client.js';
import {
  accountDeletionRequests,
  allergies,
  appointments,
  careEpisodes,
  carePlans,
  careTasks,
  conditions,
  consents,
  conversations,
  dataExports,
  devices,
  doseLogs,
  emergencyContacts,
  familyAccessGrants,
  homeVisits,
  medicalRecords,
  medications,
  messages,
  moodEntries,
  notificationOutbox,
  notificationPreferences,
  notifications,
  otpRequests,
  patients,
  payments,
  users,
  vitals,
  wearableConnections,
} from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, type Actor } from '../../lib/context.js';
import { AppError, errors } from '../../lib/errors.js';
import { iso } from '../../lib/time.js';
import type { Services } from '../../services.js';
import { buildMe, revokeAllSessions } from '../auth/service.js';
import type { StorageAdapter } from '../records/storage.js';

/** Staff (including field providers) cannot self-delete; an admin disables them (contract section 23). */
export const NON_DELETABLE_ROLES = ['doctor', 'provider', 'coordinator', 'ops_admin', 'super_admin', 'hospital_staff', 'support_agent'] as const;

type DeletionRow = typeof accountDeletionRequests.$inferSelect;
type ExportRow = typeof dataExports.$inferSelect;

export const toDeletionRequest = (r: DeletionRow) => ({
  id: r.id,
  status: r.status as 'scheduled' | 'cancelled' | 'completed',
  reason: r.reason,
  requestedAt: iso(r.requestedAt),
  scheduledFor: iso(r.scheduledFor),
  completedAt: iso(r.completedAt),
});

export const toDataExport = (r: ExportRow) => ({
  id: r.id,
  status: 'ready' as const,
  createdAt: iso(r.createdAt),
  expiresAt: iso(r.expiresAt),
  sizeBytes: r.sizeBytes,
});

export async function latestDeletionRequest(db: Db, userId: string): Promise<DeletionRow | null> {
  const [r] = await db
    .select()
    .from(accountDeletionRequests)
    .where(eq(accountDeletionRequests.userId, userId))
    .orderBy(desc(accountDeletionRequests.requestedAt))
    .limit(1);
  return r ?? null;
}

/** Patients whose personal data belongs to this account: the self profile and managed dependents. */
async function ownedPatientIds(db: Db, userId: string): Promise<string[]> {
  const rows = await db
    .select({ id: patients.id })
    .from(patients)
    .where(or(eq(patients.userId, userId), eq(patients.ownerUserId, userId)));
  return rows.map((r) => r.id);
}

// ------------------------------------------------------------------------------------------ export

const strip = <T extends Record<string, unknown>>(row: T, keys: string[]): Partial<T> => {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(row)) if (!keys.includes(k)) out[k] = v instanceof Date ? v.toISOString() : v;
  return out as Partial<T>;
};

/** Build the DPDP data-portability document for a user (contract section 23). */
export async function buildDataExport(db: Db, userId: string, sessionId: string | null) {
  const profile = await buildMe(db, userId, sessionId);
  const pids = await ownedPatientIds(db, userId);
  const inP = (col: AnyPgColumn) => inArray(col, pids.length ? pids : ['00000000-0000-0000-0000-000000000000']);
  const [pats, alls, conds, contacts, recs, eps, appts, visits, plans, tasks, meds, vit, moods, pays] = await Promise.all([
    db.select().from(patients).where(inP(patients.id)),
    db.select().from(allergies).where(inP(allergies.patientId)),
    db.select().from(conditions).where(inP(conditions.patientId)),
    db.select().from(emergencyContacts).where(inP(emergencyContacts.patientId)),
    db.select().from(medicalRecords).where(inP(medicalRecords.patientId)),
    db.select().from(careEpisodes).where(inP(careEpisodes.patientId)),
    db.select().from(appointments).where(inP(appointments.patientId)),
    db.select().from(homeVisits).where(inP(homeVisits.patientId)),
    db.select().from(carePlans).where(inP(carePlans.patientId)),
    db.select().from(careTasks).where(inP(careTasks.patientId)),
    db.select().from(medications).where(inP(medications.patientId)),
    db.select().from(vitals).where(inP(vitals.patientId)),
    db.select().from(moodEntries).where(inP(moodEntries.patientId)),
    db.select().from(payments).where(inP(payments.patientId)),
  ]);
  const medIds = meds.map((m) => m.id);
  const doses = medIds.length ? await db.select().from(doseLogs).where(inArray(doseLogs.medicationId, medIds)) : [];
  const userConsents = await db.select().from(consents).where(eq(consents.userId, userId));
  const convs = await db.select().from(conversations).where(or(eq(conversations.userId, userId), inP(conversations.patientId)));
  const convIds = convs.map((c) => c.id);
  const msgs = convIds.length ? await db.select().from(messages).where(inArray(messages.conversationId, convIds)).orderBy(messages.seq) : [];

  const byPatient = <T extends { patientId: string }>(rows: T[], pid: string) => rows.filter((r) => r.patientId === pid);
  return {
    format: 'carecompanion-data-export',
    version: 1,
    generatedAt: new Date().toISOString(),
    profile,
    consents: userConsents.map((c) => strip(c, [])),
    patients: pats.map((p) => ({
      profile: strip(p, ['retentionHold', 'anonymisedAt']),
      allergies: byPatient(alls, p.id).map((r) => strip(r, [])),
      conditions: byPatient(conds, p.id).map((r) => strip(r, [])),
      emergencyContacts: byPatient(contacts, p.id).map((r) => strip(r, [])),
      // Metadata only: the original files stay downloadable through /records/:id/file.
      records: byPatient(recs, p.id).map((r) => strip(r, ['storageKey'])),
      careEpisodes: byPatient(eps, p.id).map((r) => strip(r, [])),
      appointments: byPatient(appts, p.id).map((r) => strip(r, ['videoRoomUrl'])),
      homeVisits: byPatient(visits, p.id).map((r) => strip(r, ['visitCode', 'rejectedProviderIds'])),
      carePlans: byPatient(plans, p.id).map((r) => strip(r, [])),
      careTasks: byPatient(tasks, p.id).map((r) => strip(r, [])),
      medications: byPatient(meds, p.id).map((m) => ({ ...strip(m, []), doses: doses.filter((d) => d.medicationId === m.id).map((d) => strip(d, [])) })),
      vitals: byPatient(vit, p.id).map((r) => strip(r, [])),
      moodEntries: byPatient(moods, p.id).map((r) => strip(r, [])),
      payments: byPatient(pays, p.id).map((r) => strip(r, ['checkout'])),
    })),
    aiConversations: convs.map((c) => ({
      id: c.id,
      patientId: c.patientId,
      status: c.status,
      createdAt: iso(c.createdAt),
      messages: msgs.filter((m) => m.conversationId === c.id).map((m) => ({ role: m.role, kind: m.kind, text: m.text, createdAt: iso(m.createdAt) })),
    })),
  };
}

export async function createDataExport(svc: Services, userId: string, sessionId: string | null, actor: Actor): Promise<ExportRow> {
  const since = new Date(Date.now() - 86400_000);
  const recent = await svc.db
    .select({ id: dataExports.id })
    .from(dataExports)
    .where(and(eq(dataExports.userId, userId), gte(dataExports.createdAt, since)));
  if (recent.length >= svc.config.DATA_EXPORT_MAX_PER_DAY) throw new AppError('RATE_LIMITED', 'Too many data exports today. Please try again tomorrow.');
  const doc = await buildDataExport(svc.db, userId, sessionId);
  const bytes = Buffer.from(JSON.stringify(doc, null, 2), 'utf8');
  const [row] = await svc.db
    .insert(dataExports)
    .values({ userId, sizeBytes: bytes.length, expiresAt: new Date(Date.now() + svc.config.DATA_EXPORT_TTL_HOURS * 3600_000) })
    .returning();
  const storageKey = `exports/${userId}/${row.id}.json`;
  await svc.storage.put(storageKey, bytes, 'application/json');
  const [updated] = await svc.db.update(dataExports).set({ storageKey }).where(eq(dataExports.id, row.id)).returning();
  await audit(svc.db, actor, { action: 'account.data_export', entityType: 'user', entityId: userId, metadata: { exportId: row.id, sizeBytes: bytes.length } });
  return updated;
}

/** Worker: delete expired export files (derived artefacts, not originals). */
export async function purgeExpiredExports(db: Db, storage: StorageAdapter, now: Date): Promise<number> {
  const due = await db.select().from(dataExports).where(and(lte(dataExports.expiresAt, now), isNull(dataExports.purgedAt)));
  for (const e of due) {
    if (e.storageKey) await storage.delete(e.storageKey).catch(() => undefined);
    await db.update(dataExports).set({ purgedAt: now, status: 'expired' }).where(eq(dataExports.id, e.id));
  }
  return due.length;
}

// ------------------------------------------------------------------------------------------ deletion

export async function scheduleDeletion(svc: Services, user: { id: string; roles: string[] }, reason: string | null, actor: Actor) {
  if (user.roles.some((r) => (NON_DELETABLE_ROLES as readonly string[]).includes(r))) {
    await audit(svc.db, actor, { action: 'account.deletion_request', entityType: 'user', entityId: user.id, outcome: 'denied', metadata: { reason: 'staff' } });
    throw errors.forbidden('Staff accounts cannot be self-deleted. Please contact an administrator.');
  }
  const existing = await latestDeletionRequest(svc.db, user.id);
  if (existing?.status === 'scheduled') return { row: existing, created: false };
  const scheduledFor = new Date(Date.now() + svc.config.ACCOUNT_DELETION_GRACE_DAYS * 86400_000);
  const [row] = await svc.db
    .insert(accountDeletionRequests)
    .values({ userId: user.id, reason, scheduledFor })
    .onConflictDoNothing()
    .returning();
  if (!row) return { row: (await latestDeletionRequest(svc.db, user.id))!, created: false };
  await audit(svc.db, actor, { action: 'account.deletion_request', entityType: 'user', entityId: user.id, metadata: { requestId: row.id, scheduledFor: row.scheduledFor.toISOString() } });
  return { row, created: true };
}

export async function cancelDeletion(svc: Services, userId: string, actor: Actor) {
  const existing = await latestDeletionRequest(svc.db, userId);
  if (!existing) throw errors.notFound('Deletion request');
  if (existing.status !== 'scheduled') throw errors.conflict('Only a scheduled deletion can be cancelled', { status: existing.status });
  const [row] = await svc.db
    .update(accountDeletionRequests)
    .set({ status: 'cancelled', cancelledAt: new Date() })
    .where(and(eq(accountDeletionRequests.id, existing.id), eq(accountDeletionRequests.status, 'scheduled')))
    .returning();
  if (!row) throw errors.conflict('The deletion request changed; please refresh');
  await audit(svc.db, actor, { action: 'account.deletion_cancel', entityType: 'user', entityId: userId, metadata: { requestId: row.id } });
  return row;
}

/**
 * Complete one deletion after the grace period (contract section 23). [REQUIRES LEGAL REVIEW]
 * - revokes sessions, device tokens and family grants (both directions);
 * - anonymises the user (name/phone/email), status `deleted`;
 * - for the self profile and managed dependents WITHOUT a retention hold: anonymises identity fields and
 *   deletes non-clinical personal data (emergency contacts, mood entries, AI chat messages, wearable links);
 * - keeps clinical records, episodes, payments and audit logs, detached from identity (the patient row
 *   becomes a pseudonymous key). Audit logs are append-only and are never rewritten.
 */
export async function completeDeletion(db: Db, req: DeletionRow, now: Date): Promise<boolean> {
  return db.transaction(async (tx) => {
    const [claimed] = await tx
      .update(accountDeletionRequests)
      .set({ status: 'completed', completedAt: now })
      .where(and(eq(accountDeletionRequests.id, req.id), eq(accountDeletionRequests.status, 'scheduled')))
      .returning();
    if (!claimed) return false;
    const userId = req.userId;
    const [u] = await tx.select().from(users).where(eq(users.id, userId));
    if (!u) return false;

    await revokeAllSessions(tx, userId);
    await tx.delete(devices).where(eq(devices.userId, userId));
    const owned = await tx
      .select({ id: patients.id, retentionHold: patients.retentionHold })
      .from(patients)
      .where(or(eq(patients.userId, userId), eq(patients.ownerUserId, userId)));
    const ownedIds = owned.map((p) => p.id);
    await tx
      .update(familyAccessGrants)
      .set({ status: 'revoked', revokedAt: now })
      .where(
        and(
          eq(familyAccessGrants.status, 'active'),
          ownedIds.length ? or(eq(familyAccessGrants.granteeUserId, userId), inArray(familyAccessGrants.patientId, ownedIds)) : eq(familyAccessGrants.granteeUserId, userId),
        ),
      );

    // Personal data of profiles not under a legal retention hold.
    const deletable = owned.filter((p) => !p.retentionHold).map((p) => p.id);
    if (deletable.length) {
      await tx.delete(emergencyContacts).where(inArray(emergencyContacts.patientId, deletable));
      await tx.delete(moodEntries).where(inArray(moodEntries.patientId, deletable));
      await tx.update(wearableConnections).set({ status: 'revoked', revokedAt: now }).where(inArray(wearableConnections.patientId, deletable));
      const convs = await tx.select({ id: conversations.id }).from(conversations).where(inArray(conversations.patientId, deletable));
      if (convs.length) {
        await tx.delete(messages).where(inArray(messages.conversationId, convs.map((c) => c.id)));
        await tx.update(conversations).set({ status: 'closed', intake: {}, state: {} }).where(inArray(conversations.id, convs.map((c) => c.id)));
      }
      await tx
        .update(patients)
        .set({ name: 'Deleted patient', phone: null, dob: null, avatarUrl: null, anonymisedAt: now, updatedAt: now })
        .where(inArray(patients.id, deletable));
    }
    // Detach retained profiles from the deleted identity too (the guardian link no longer exists).
    if (ownedIds.length) await tx.update(patients).set({ userId: null, ownerUserId: null }).where(inArray(patients.id, ownedIds));

    await tx.delete(notificationOutbox).where(eq(notificationOutbox.userId, userId));
    await tx.delete(notifications).where(eq(notifications.userId, userId));
    await tx.delete(notificationPreferences).where(eq(notificationPreferences.userId, userId));
    await tx.delete(otpRequests).where(eq(otpRequests.phone, u.phone));
    await tx
      .update(users)
      .set({
        name: null,
        email: null,
        phone: `deleted:${userId}`,
        status: 'deleted',
        deletedAt: now,
        selfPatientId: null,
        mfaSecretEnc: null,
        mfaPendingSecretEnc: null,
      })
      .where(eq(users.id, userId));
    await audit(tx, { ...SYSTEM_ACTOR, name: 'account-deletion' }, {
      action: 'account.deletion_completed',
      entityType: 'user',
      entityId: userId,
      metadata: { requestId: req.id, profiles: ownedIds.length, retainedUnderHold: ownedIds.length - deletable.length },
    });
    return true;
  });
}

/** Worker job body: complete every deletion whose grace period has ended. */
export async function completeDueDeletions(db: Db, now: Date): Promise<number> {
  const due = await db
    .select()
    .from(accountDeletionRequests)
    .where(and(eq(accountDeletionRequests.status, 'scheduled'), lte(accountDeletionRequests.scheduledFor, now)));
  let n = 0;
  for (const r of due) if (await completeDeletion(db, r, now)) n++;
  return n;
}

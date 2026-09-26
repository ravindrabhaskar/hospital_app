import { and, eq, gt, ne, sql } from 'drizzle-orm';
import type { DbOrTx } from '../db/client.js';
import {
  appointments,
  careEpisodes,
  carePlans,
  familyAccessGrants,
  medicalRecords,
  patients,
  recordShares,
  type FamilyPermission,
} from '../db/schema.js';
import { audit } from './audit.js';
import { OPS_ROLES, hasRole, type AuthUser, type RequestCtx } from './context.js';
import { errors } from './errors.js';

export const ALL_FAMILY_PERMISSIONS: FamilyPermission[] = ['view_records', 'manage_care', 'book', 'receive_alerts'];

/**
 * Permission requirement for a patient-scoped action:
 * - a FamilyPermission (self / managed dependents hold all four; grantees hold the listed ones;
 *   a doctor with a care relationship holds view_records + manage_care)
 * - 'any'   : any access path at all (e.g. read a profile, trigger SOS)
 * - 'owner' : self or the managing guardian only (e.g. manage family access)
 * - 'staff_ops' : coordinator / ops_admin / super_admin
 */
export type Perm = FamilyPermission | 'any' | 'owner' | 'staff_ops';

export interface PatientAccess {
  patientId: string;
  via: Array<'self' | 'managed' | 'grant' | 'doctor' | 'staff_ops'>;
  permissions: Set<FamilyPermission>;
  isOwner: boolean;
  isSelf: boolean;
  isStaffOps: boolean;
  relation: string | null;
}

export async function doctorHasRelationship(db: DbOrTx, providerId: string, userId: string, patientId: string): Promise<boolean> {
  const now = new Date();
  const [appt] = await db
    .select({ id: appointments.id })
    .from(appointments)
    .where(and(eq(appointments.patientId, patientId), eq(appointments.doctorId, providerId), ne(appointments.status, 'cancelled')))
    .limit(1);
  if (appt) return true;
  const [ep] = await db
    .select({ id: careEpisodes.id })
    .from(careEpisodes)
    .where(and(eq(careEpisodes.patientId, patientId), eq(careEpisodes.ownerUserId, userId)))
    .limit(1);
  if (ep) return true;
  const [plan] = await db
    .select({ id: carePlans.id })
    .from(carePlans)
    .where(and(eq(carePlans.patientId, patientId), eq(carePlans.doctorId, providerId)))
    .limit(1);
  if (plan) return true;
  const [share] = await db
    .select({ id: recordShares.id })
    .from(recordShares)
    .innerJoin(medicalRecords, eq(medicalRecords.id, recordShares.recordId))
    .where(and(eq(medicalRecords.patientId, patientId), eq(recordShares.doctorId, providerId), gt(recordShares.expiresAt, now)))
    .limit(1);
  return !!share;
}

export async function resolvePatientAccess(db: DbOrTx, user: AuthUser, patientId: string): Promise<PatientAccess | null> {
  const [p] = await db
    .select({ id: patients.id, userId: patients.userId, ownerUserId: patients.ownerUserId, ownerRelation: patients.ownerRelation })
    .from(patients)
    .where(eq(patients.id, patientId))
    .limit(1);
  if (!p) return null;
  const access: PatientAccess = {
    patientId,
    via: [],
    permissions: new Set(),
    isOwner: false,
    isSelf: false,
    isStaffOps: false,
    relation: null,
  };
  if (p.userId === user.id) {
    access.via.push('self');
    access.isSelf = true;
    access.isOwner = true;
    access.relation = 'self';
    ALL_FAMILY_PERMISSIONS.forEach((x) => access.permissions.add(x));
  } else if (p.ownerUserId === user.id) {
    access.via.push('managed');
    access.isOwner = true;
    access.relation = p.ownerRelation;
    ALL_FAMILY_PERMISSIONS.forEach((x) => access.permissions.add(x));
  }
  if (!access.isOwner) {
    const grants = await db
      .select()
      .from(familyAccessGrants)
      .where(
        and(eq(familyAccessGrants.patientId, patientId), eq(familyAccessGrants.granteeUserId, user.id), eq(familyAccessGrants.status, 'active')),
      );
    for (const g of grants) {
      access.via.push('grant');
      access.relation = access.relation ?? g.relation;
      g.permissions.forEach((x) => access.permissions.add(x));
    }
  }
  if (user.providerId && hasRole(user, 'doctor')) {
    if (await doctorHasRelationship(db, user.providerId, user.id, patientId)) {
      access.via.push('doctor');
      access.permissions.add('view_records');
      access.permissions.add('manage_care');
    }
  }
  if (hasRole(user, ...OPS_ROLES)) {
    access.via.push('staff_ops');
    access.isStaffOps = true;
  }
  return access;
}

function satisfies(access: PatientAccess, perm: Perm): boolean {
  switch (perm) {
    case 'any':
      return access.via.length > 0;
    case 'owner':
      return access.isOwner;
    case 'staff_ops':
      return access.isStaffOps;
    default:
      return access.permissions.has(perm);
  }
}

/**
 * Central authorization check used by every patient-scoped route.
 * `perm` may be a list, meaning "any of". Denials are audited.
 */
export async function assertCanActForPatient(
  db: DbOrTx,
  ctx: RequestCtx,
  patientId: string,
  perm: Perm | Perm[],
  action = 'patient.access',
): Promise<PatientAccess> {
  const perms = Array.isArray(perm) ? perm : [perm];
  const access = await resolvePatientAccess(db, ctx.user, patientId);
  if (!access) throw errors.notFound('Patient');
  if (!perms.some((p) => satisfies(access, p))) {
    await audit(db, ctx.actor, {
      action,
      entityType: 'patient',
      entityId: patientId,
      outcome: 'denied',
      metadata: { required: perms },
    });
    throw errors.forbidden();
  }
  return access;
}

/** Patients the user may act for (self first, then managed, then grants). */
export async function listActablePatients(
  db: DbOrTx,
  user: AuthUser,
): Promise<Array<{ patientId: string; relation: string; isSelf: boolean; permissions: FamilyPermission[] }>> {
  const out: Array<{ patientId: string; relation: string; isSelf: boolean; permissions: FamilyPermission[] }> = [];
  const own = await db
    .select({ id: patients.id, userId: patients.userId, ownerRelation: patients.ownerRelation, createdAt: patients.createdAt })
    .from(patients)
    .where(sql`${patients.userId} = ${user.id} or ${patients.ownerUserId} = ${user.id}`)
    .orderBy(patients.createdAt);
  own.sort((a, b) => Number(b.userId === user.id) - Number(a.userId === user.id));
  for (const p of own) {
    const isSelf = p.userId === user.id;
    out.push({ patientId: p.id, relation: isSelf ? 'self' : p.ownerRelation, isSelf, permissions: [...ALL_FAMILY_PERMISSIONS] });
  }
  const grants = await db
    .select()
    .from(familyAccessGrants)
    .where(and(eq(familyAccessGrants.granteeUserId, user.id), eq(familyAccessGrants.status, 'active')))
    .orderBy(familyAccessGrants.createdAt);
  for (const g of grants) {
    const existing = out.find((o) => o.patientId === g.patientId);
    if (existing) {
      g.permissions.forEach((x) => !existing.permissions.includes(x) && existing.permissions.push(x));
    } else {
      out.push({ patientId: g.patientId, relation: g.relation, isSelf: false, permissions: [...g.permissions] });
    }
  }
  return out;
}

/** Throws FORBIDDEN (audited) unless the user has one of the roles. */
export async function assertRole(db: DbOrTx, ctx: RequestCtx, roles: string[], action: string): Promise<void> {
  if (roles.some((r) => ctx.user.roles.includes(r as never))) return;
  await audit(db, ctx.actor, { action, entityType: 'route', outcome: 'denied', metadata: { requiredRoles: roles } });
  throw errors.forbidden();
}

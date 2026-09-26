import { and, eq, inArray } from 'drizzle-orm';
import type { DbOrTx } from '../../db/client.js';
import { allergies, conditions, emergencyContacts, medications, patients, type FamilyPermission } from '../../db/schema.js';
import { ALL_FAMILY_PERMISSIONS, type PatientAccess } from '../../lib/access.js';
import { ageFromDob, iso } from '../../lib/time.js';

export type PatientRow = typeof patients.$inferSelect;

export interface AccessView {
  relation: string;
  isSelf: boolean;
  permissions: FamilyPermission[];
}

export function viewFromAccess(a: PatientAccess): AccessView {
  return {
    relation: a.isSelf ? 'self' : (a.relation ?? 'patient'),
    isSelf: a.isSelf,
    permissions: a.isOwner ? [...ALL_FAMILY_PERMISSIONS] : ALL_FAMILY_PERMISSIONS.filter((p) => a.permissions.has(p)),
  };
}

export function toPatientSummary(p: PatientRow, v: AccessView) {
  return {
    id: p.id,
    name: p.name ?? '',
    dob: p.dob,
    age: ageFromDob(p.dob),
    gender: p.gender,
    relation: v.relation,
    isSelf: v.isSelf,
    permissions: v.permissions,
    avatarUrl: p.avatarUrl,
  };
}

export const toAllergy = (a: typeof allergies.$inferSelect) => ({
  id: a.id,
  substance: a.substance,
  reaction: a.reaction,
  severity: a.severity,
  source: a.source,
  createdAt: iso(a.createdAt),
});
export const toCondition = (c: typeof conditions.$inferSelect) => ({ id: c.id, name: c.name, since: c.since, source: c.source, createdAt: iso(c.createdAt) });
export const toEmergencyContact = (c: typeof emergencyContacts.$inferSelect) => ({ id: c.id, name: c.name, phone: c.phone, relation: c.relation });

export async function toPatientProfile(db: DbOrTx, p: PatientRow, v: AccessView) {
  const [al, co, ec] = await Promise.all([
    db.select().from(allergies).where(eq(allergies.patientId, p.id)).orderBy(allergies.createdAt),
    db.select().from(conditions).where(eq(conditions.patientId, p.id)).orderBy(conditions.createdAt),
    db.select().from(emergencyContacts).where(eq(emergencyContacts.patientId, p.id)).orderBy(emergencyContacts.createdAt),
  ]);
  return {
    ...toPatientSummary(p, v),
    phone: p.phone,
    bloodGroup: p.bloodGroup,
    heightCm: p.heightCm,
    weightKg: p.weightKg,
    abha: p.abhaNumber || p.abhaAddress ? { number: p.abhaNumber, address: p.abhaAddress, status: p.abhaStatus as 'unverified' | 'verified' } : null,
    allergies: al.map(toAllergy),
    conditions: co.map(toCondition),
    emergencyContacts: ec.map(toEmergencyContact),
  };
}

/** Authorized clinical context for AI / providers: names of allergies, conditions, active meds. */
export async function clinicalContext(db: DbOrTx, patientId: string) {
  const [p] = await db.select().from(patients).where(eq(patients.id, patientId));
  const [al, co, meds] = await Promise.all([
    db.select({ s: allergies.substance }).from(allergies).where(eq(allergies.patientId, patientId)),
    db.select({ n: conditions.name }).from(conditions).where(eq(conditions.patientId, patientId)),
    db
      .select({ n: medications.name, d: medications.dose })
      .from(medications)
      .where(and(eq(medications.patientId, patientId), eq(medications.active, true))),
  ]);
  return {
    age: p ? ageFromDob(p.dob) : null,
    gender: p?.gender ?? null,
    allergies: al.map((x) => x.s),
    conditions: co.map((x) => x.n),
    medications: meds.map((m) => `${m.n} ${m.d}`.trim()),
  };
}

export async function patientNames(db: DbOrTx, ids: string[]): Promise<Map<string, string | null>> {
  const uniq = [...new Set(ids)];
  if (!uniq.length) return new Map();
  const rows = await db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, uniq));
  return new Map(rows.map((r) => [r.id, r.name]));
}

import { eq, inArray } from 'drizzle-orm';
import type { DbOrTx } from '../../db/client.js';
import { doctorSchedules, providerZones, providers, serviceZones, type WeeklyBlockJson } from '../../db/schema.js';
import { errors } from '../../lib/errors.js';

export type ProviderType = 'doctor' | 'nurse' | 'technician' | 'intern' | 'physiotherapist';

/** Default consultation fees (rupees) for newly onboarded doctors; they can change them via PATCH /doctor/me/profile. */
export const DEFAULT_DOCTOR_FEES = { video: 499, audio: 499, chat: 399, inClinic: 599 };

/**
 * Create the provider profile of a staff user (shared by POST /admin/staff and provider-application approval).
 * Doctors get a schedule row (`weekly`, empty unless given) so the slot horizon job can pick them up.
 */
export async function createProviderProfile(
  tx: DbOrTx,
  p: {
    userId: string;
    name: string;
    type: ProviderType;
    qualification: string;
    specialty?: string | null;
    registrationNumber: string;
    zoneIds: string[];
    capabilities: string[];
    credentialExpiresAt: Date;
    verificationStatus: 'pending' | 'verified';
    experienceYears?: number;
    languages?: string[];
    weekly?: WeeklyBlockJson[];
    withDefaultFees?: boolean;
  },
): Promise<typeof providers.$inferSelect> {
  const isDoctor = p.type === 'doctor';
  const [existing] = await tx.select({ id: providers.id }).from(providers).where(eq(providers.userId, p.userId));
  if (existing) throw errors.conflict('This user already has a provider profile');
  const fees = isDoctor && p.withDefaultFees ? DEFAULT_DOCTOR_FEES : null;
  const [row] = await tx
    .insert(providers)
    .values({
      userId: p.userId,
      kind: isDoctor ? 'doctor' : 'field',
      type: p.type,
      name: p.name,
      qualification: p.qualification,
      specialty: p.specialty ?? null,
      registrationNumber: p.registrationNumber,
      verificationStatus: p.verificationStatus,
      credentialExpiresAt: p.credentialExpiresAt,
      capabilities: p.capabilities,
      experienceYears: p.experienceYears ?? 0,
      languages: p.languages ?? [],
      ...(fees ? { feeVideo: fees.video, feeAudio: fees.audio, feeChat: fees.chat, feeInClinic: fees.inClinic } : {}),
    })
    .returning();
  if (p.zoneIds.length) {
    const zones = await tx.select({ id: serviceZones.id }).from(serviceZones).where(inArray(serviceZones.id, p.zoneIds));
    for (const z1 of zones) await tx.insert(providerZones).values({ providerId: row.id, zoneId: z1.id });
  }
  if (isDoctor) await tx.insert(doctorSchedules).values({ doctorId: row.id, weekly: p.weekly ?? [] }).onConflictDoNothing();
  return row;
}

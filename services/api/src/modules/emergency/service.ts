import { eq } from 'drizzle-orm';
import type { DbOrTx } from '../../db/client.js';
import { emergencyContacts, facilities, fallEvents, patients, safetyRulePacks } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, type Actor } from '../../lib/context.js';
import { maskPhone } from '../../lib/crypto.js';
import type { Services } from '../../services.js';
import { advanceEpisode, createEpisode } from '../episodes/service.js';
import { toFacility } from '../providers/routes.js';

/** Create an emergency episode (NEW -> EMERGENCY) + an emergency SafetyEvent. */
export async function openEmergency(
  svc: Services,
  tx: DbOrTx,
  p: { patientId: string; title: string; concern: string; source: 'fall' | 'sos' | 'mood'; rule: { ruleId: string; title: string }; actor: Actor },
) {
  const ep = await createEpisode(tx, { patientId: p.patientId, title: p.title, concern: p.concern, priority: 'emergency', actor: p.actor });
  await advanceEpisode(tx, ep.id, ['EMERGENCY'], p.title, p.actor, { priority: 'emergency', nextAction: 'Emergency response' });
  const [pack] = await tx.select({ version: safetyRulePacks.version }).from(safetyRulePacks).where(eq(safetyRulePacks.active, true)).limit(1);
  const event = await svc.safety.recordEvent(tx, {
    patientId: p.patientId,
    careEpisodeId: ep.id,
    level: 'emergency',
    source: p.source,
    rules: [p.rule],
    rulePackVersion: pack?.version ?? null,
  });
  return { episodeId: ep.id, safetyEventId: event.id };
}

/** Notify family (critical) and SMS emergency contacts with PHI-free text. Returns masked contacts. */
export async function alertEmergencyContacts(svc: Services, patientId: string, template: 'sos' | 'fall', deepLink: string | null) {
  const [p] = await svc.db.select({ name: patients.name }).from(patients).where(eq(patients.id, patientId));
  await svc.notify.notifyPatient(patientId, {
    template,
    params: { patient: p?.name ?? 'Your family member' },
    category: 'safety',
    critical: true,
    deepLink,
  });
  const contacts = await svc.db.select().from(emergencyContacts).where(eq(emergencyContacts.patientId, patientId));
  for (const c of contacts) {
    await svc.notify.smsDirect(c.phone, `CareCompanion: urgent alert for ${p?.name?.split(' ')[0] ?? 'your contact'}. Please call them now. If needed, dial 108.`);
  }
  return contacts.map((c) => ({ name: c.name, phoneMasked: maskPhone(c.phone) }));
}

export async function nearestEmergencyFacilities(svc: Services, lat?: number, lng?: number) {
  const rows = await svc.db.select().from(facilities).where(eq(facilities.emergency24x7, true));
  const origin = lat !== undefined && lng !== undefined ? { lat, lng } : undefined;
  const items = rows.map((f) => toFacility(f, origin));
  if (origin) items.sort((a, b) => (a.distanceKm ?? 0) - (b.distanceKm ?? 0));
  return items.slice(0, 3);
}

/** Escalate an unanswered / unsafe fall event (used by the route and the worker). */
export async function escalateFall(svc: Services, fallId: string, actor: Actor = SYSTEM_ACTOR): Promise<boolean> {
  const escalated = await svc.db.transaction(async (tx) => {
    const [f] = await tx.select().from(fallEvents).where(eq(fallEvents.id, fallId));
    if (!f || f.status !== 'awaiting_response') return null;
    const [row] = await tx.update(fallEvents).set({ status: 'escalated', escalatedAt: new Date() }).where(eq(fallEvents.id, fallId)).returning();
    const em = await openEmergency(svc, tx, {
      patientId: f.patientId,
      title: 'Possible fall',
      concern: `Possible fall detected (${f.source}); no safe response received`,
      source: 'fall',
      rule: { ruleId: 'fall.no_response', title: 'Fall detected without safe response' },
      actor,
    });
    await audit(tx, actor, { action: 'fall.escalate', entityType: 'fall_event', entityId: fallId, metadata: { episodeId: em.episodeId } });
    return { row, episodeId: em.episodeId };
  });
  if (!escalated) return false;
  await alertEmergencyContacts(svc, escalated.row.patientId, 'fall', `/care-episodes/${escalated.episodeId}`);
  return true;
}

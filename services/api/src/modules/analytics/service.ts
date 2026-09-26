import { count, eq, inArray, sql } from 'drizzle-orm';
import type { DbOrTx } from '../../db/client.js';
import {
  aiInteractions,
  appointments,
  careEpisodes,
  carePlans,
  careTasks,
  conversations,
  doseLogs,
  familyAccessGrants,
  homeVisits,
  payments,
  refunds,
  safetyEvents,
  users,
} from '../../db/schema.js';
import { median, minutesBetween } from '../../lib/time.js';
import { REQUIRED_CONSENTS } from '../consent/catalog.js';

const rate = (num: number, den: number): number | null => (den ? Math.round((num / den) * 1000) / 1000 : null);

export async function computeAnalytics(db: DbOrTx) {
  const n = async (q: Promise<Array<{ n: number }>>) => Number((await q)[0]?.n ?? 0);
  const convs = await db.select({ intake: conversations.intake, status: conversations.status }).from(conversations);
  const intakesCompleted = convs.filter((c) => (c.intake as { complete?: boolean }).complete).length;
  const routed = convs.filter((c) => c.status === 'routed').length;

  const tasks = await db.select({ status: careTasks.status, type: careTasks.type }).from(careTasks);
  const finished = tasks.filter((t) => t.status !== 'cancelled');
  const followUps = finished.filter((t) => t.type === 'follow_up');
  const doses = await db.select({ status: doseLogs.status }).from(doseLogs);

  const safety = await db.select().from(safetyEvents);
  const ackMins = safety.filter((s) => s.acknowledgedAt).map((s) => minutesBetween(s.createdAt, s.acknowledgedAt!));
  const aiTotal = await n(db.select({ n: count() }).from(aiInteractions));
  const aiFallback = await n(db.select({ n: count() }).from(aiInteractions).where(eq(aiInteractions.fallbackUsed, true)));

  const paid = await db.select().from(payments).where(inArray(payments.status, ['succeeded', 'refunded', 'partially_refunded']));
  const refundTotal = (await db.select({ amount: refunds.amount }).from(refunds)).reduce((s, r) => s + r.amount, 0);
  const paidEpisodeIds = new Set<string>();
  for (const p of paid) {
    if (p.purpose === 'appointment') {
      const [a] = await db.select({ e: appointments.careEpisodeId }).from(appointments).where(eq(appointments.id, p.refId));
      if (a) paidEpisodeIds.add(a.e);
    } else if (p.purpose === 'home_visit') {
      const [v] = await db.select({ e: homeVisits.careEpisodeId }).from(homeVisits).where(eq(homeVisits.id, p.refId));
      if (v) paidEpisodeIds.add(v.e);
    }
  }

  const allUsers = await db.select({ id: users.id, name: users.name, roles: users.roles }).from(users);
  const consentRows = (await db.execute(
    sql`select user_id, count(distinct purpose)::int as n from consents where status = 'granted' and purpose in ('terms','privacy','health_data_processing') group by user_id`,
  )) as unknown as { rows: Array<{ user_id: string; n: number }> };
  const consentOk = new Set(consentRows.rows.filter((r) => Number(r.n) >= REQUIRED_CONSENTS.length).map((r) => r.user_id));

  return {
    funnel: {
      conversationsStarted: convs.length,
      intakesCompleted,
      routedToCare: routed,
      appointmentsBooked: await n(db.select({ n: count() }).from(appointments)),
      appointmentsCompleted: await n(db.select({ n: count() }).from(appointments).where(eq(appointments.status, 'completed'))),
      homeVisitsRequested: await n(db.select({ n: count() }).from(homeVisits)),
      homeVisitsCompleted: await n(db.select({ n: count() }).from(homeVisits).where(eq(homeVisits.status, 'completed'))),
      carePlansCreated: await n(db.select({ n: count() }).from(carePlans)),
      episodesResolved: await n(db.select({ n: count() }).from(careEpisodes).where(eq(careEpisodes.status, 'RESOLVED'))),
    },
    continuity: {
      taskCompletionRate: rate(finished.filter((t) => t.status === 'done').length, finished.length),
      followUpCompletionRate: rate(followUps.filter((t) => t.status === 'done').length, followUps.length),
      medicationAdherenceRate: rate(doses.filter((d) => d.status === 'taken').length, doses.length),
    },
    safety: {
      safetyEventsTotal: safety.length,
      emergencyEvents: safety.filter((s) => s.level === 'emergency').length,
      medianAckMins: median(ackMins),
      aiFallbackRate: rate(aiFallback, aiTotal),
    },
    finance: {
      grossRevenue: paid.reduce((s, p) => s + p.amount, 0),
      refunds: refundTotal,
      paidEpisodes: paidEpisodeIds.size,
    },
    activation: {
      usersTotal: allUsers.length,
      onboardingCompleted: allUsers.filter((u) => u.name && consentOk.has(u.id)).length,
      familyGrants: await n(db.select({ n: count() }).from(familyAccessGrants).where(eq(familyAccessGrants.status, 'active'))),
    },
  };
}

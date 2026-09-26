import { and, asc, desc, eq, gt, inArray, ne, sql } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { DbOrTx } from '../../db/client.js';
import {
  appointments,
  careEpisodes,
  careMessageReads,
  careMessages,
  familyAccessGrants,
  medicalRecords,
  patients,
  providers,
} from '../../db/schema.js';
import { listActablePatients } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { hasRole, type RequestCtx } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { t } from '../../lib/i18n.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { ACTIVE_STATUSES } from '../episodes/service.js';

/** Contract section 34: secure care-team messaging, one thread per Care Episode. */
export type SenderRole = 'patient' | 'family' | 'doctor' | 'coordinator' | 'care_team' | 'system';
type EpisodeRow = typeof careEpisodes.$inferSelect;
type MessageRow = typeof careMessages.$inferSelect;

export const toChatMessage = (m: MessageRow) => ({
  id: m.id,
  careEpisodeId: m.careEpisodeId,
  senderUserId: m.senderUserId,
  senderName: m.senderName,
  senderRole: m.senderRole,
  kind: m.kind,
  text: m.text,
  attachmentRecordId: m.attachmentRecordId,
  createdAt: iso(m.createdAt),
});

/**
 * Participant role of the caller in an episode thread, or null. Providers (field staff) are never participants;
 * family needs an active manage_care grant; doctors need an appointment in the episode; coordinators must be the
 * assigned coordinator; ops_admin / super_admin post as "Care team".
 */
export async function participantRole(db: DbOrTx, ctx: RequestCtx, ep: EpisodeRow): Promise<SenderRole | null> {
  const u = ctx.user;
  const [p] = await db.select({ userId: patients.userId, ownerUserId: patients.ownerUserId }).from(patients).where(eq(patients.id, ep.patientId));
  if (p?.userId === u.id) return 'patient';
  if (p?.ownerUserId === u.id) return 'family';
  const grants = await db
    .select({ permissions: familyAccessGrants.permissions })
    .from(familyAccessGrants)
    .where(and(eq(familyAccessGrants.patientId, ep.patientId), eq(familyAccessGrants.granteeUserId, u.id), eq(familyAccessGrants.status, 'active')));
  if (grants.some((g) => g.permissions.includes('manage_care'))) return 'family';
  if (hasRole(u, 'doctor') && u.providerId) {
    const [a] = await db
      .select({ id: appointments.id })
      .from(appointments)
      .where(and(eq(appointments.careEpisodeId, ep.id), eq(appointments.doctorId, u.providerId), ne(appointments.status, 'cancelled')))
      .limit(1);
    if (a) return 'doctor';
  }
  if (hasRole(u, 'coordinator') && ep.coordinatorUserId === u.id) return 'coordinator';
  if (hasRole(u, 'ops_admin', 'super_admin')) return 'care_team';
  return null;
}

/** Users to notify about a new message (every participant except ops and the sender). */
async function recipientUserIds(db: DbOrTx, ep: EpisodeRow): Promise<string[]> {
  const ids = new Set<string>();
  const [p] = await db.select({ userId: patients.userId, ownerUserId: patients.ownerUserId }).from(patients).where(eq(patients.id, ep.patientId));
  if (p?.userId) ids.add(p.userId);
  if (p?.ownerUserId) ids.add(p.ownerUserId);
  const grants = await db
    .select({ userId: familyAccessGrants.granteeUserId, permissions: familyAccessGrants.permissions })
    .from(familyAccessGrants)
    .where(and(eq(familyAccessGrants.patientId, ep.patientId), eq(familyAccessGrants.status, 'active')));
  for (const g of grants) if (g.permissions.includes('manage_care')) ids.add(g.userId);
  const docs = await db
    .selectDistinct({ userId: providers.userId })
    .from(appointments)
    .innerJoin(providers, eq(providers.id, appointments.doctorId))
    .where(and(eq(appointments.careEpisodeId, ep.id), ne(appointments.status, 'cancelled')));
  for (const d of docs) ids.add(d.userId);
  if (ep.coordinatorUserId) ids.add(ep.coordinatorUserId);
  return [...ids];
}

export async function messagingRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  const loadEpisode = async (id: string): Promise<EpisodeRow> => {
    const [ep] = await db.select().from(careEpisodes).where(eq(careEpisodes.id, id));
    if (!ep) throw errors.notFound('Care episode');
    return ep;
  };
  const requireParticipant = async (ctx: RequestCtx, ep: EpisodeRow, action: string): Promise<SenderRole> => {
    const role = await participantRole(db, ctx, ep);
    if (role) return role;
    await audit(db, ctx.actor, { action, entityType: 'care_episode', entityId: ep.id, outcome: 'denied' });
    throw errors.forbidden('You are not a participant in this care thread');
  };

  app.get('/inbox', async (req) => {
    const page = pageFromQuery(req.query);
    const u = req.ctx.user;
    const candidate = new Set<string>();
    const patientIds = (await listActablePatients(db, u)).filter((p) => p.permissions.includes('manage_care')).map((p) => p.patientId);
    if (patientIds.length) {
      for (const e of await db.select({ id: careEpisodes.id }).from(careEpisodes).where(inArray(careEpisodes.patientId, patientIds))) candidate.add(e.id);
    }
    if (hasRole(u, 'doctor') && u.providerId) {
      const rows = await db
        .selectDistinct({ id: appointments.careEpisodeId })
        .from(appointments)
        .where(and(eq(appointments.doctorId, u.providerId), ne(appointments.status, 'cancelled')));
      rows.forEach((r) => candidate.add(r.id));
    }
    if (hasRole(u, 'coordinator')) {
      for (const e of await db.select({ id: careEpisodes.id }).from(careEpisodes).where(eq(careEpisodes.coordinatorUserId, u.id))) candidate.add(e.id);
    }
    const mine = new Set(candidate);
    const isOps = hasRole(u, 'ops_admin', 'super_admin');
    if (isOps) {
      for (const r of await db.selectDistinct({ id: careMessages.careEpisodeId }).from(careMessages)) candidate.add(r.id);
    }
    if (!candidate.size) return { items: [], nextCursor: null };
    const ids = [...candidate];
    const [eps, lasts, unread] = await Promise.all([
      db
        .select({ ep: careEpisodes, patientName: patients.name })
        .from(careEpisodes)
        .innerJoin(patients, eq(patients.id, careEpisodes.patientId))
        .where(inArray(careEpisodes.id, ids)),
      db
        .selectDistinctOn([careMessages.careEpisodeId])
        .from(careMessages)
        .where(inArray(careMessages.careEpisodeId, ids))
        .orderBy(careMessages.careEpisodeId, desc(careMessages.seq)),
      db
        .select({ episodeId: careMessages.careEpisodeId, n: sql<number>`count(*)::int` })
        .from(careMessages)
        .leftJoin(careMessageReads, and(eq(careMessageReads.careEpisodeId, careMessages.careEpisodeId), eq(careMessageReads.userId, u.id)))
        .where(
          and(
            inArray(careMessages.careEpisodeId, ids),
            sql`${careMessages.seq} > coalesce(${careMessageReads.lastReadSeq}, 0)`,
            sql`(${careMessages.senderUserId} is null or ${careMessages.senderUserId} <> ${u.id})`,
          ),
        )
        .groupBy(careMessages.careEpisodeId),
    ]);
    const lastOf = new Map(lasts.map((m) => [m.careEpisodeId, m]));
    const unreadOf = new Map(unread.map((r) => [r.episodeId, Number(r.n)]));
    const items = eps
      // Own active episodes are listed so a thread can be started; closed ones only once they have messages.
      // Ops (who post as "Care team") see every thread that has messages.
      .filter(({ ep }) => (mine.has(ep.id) && (lastOf.has(ep.id) || ACTIVE_STATUSES.includes(ep.status as never))) || (isOps && lastOf.has(ep.id)))
      .map(({ ep, patientName }) => {
        const last = lastOf.get(ep.id);
        return {
          careEpisodeId: ep.id,
          title: ep.title,
          patientId: ep.patientId,
          patientName: patientName ?? '',
          lastMessage: last?.text ?? null,
          lastSenderName: last?.senderName ?? null,
          lastAt: iso(last?.createdAt ?? null),
          unread: unreadOf.get(ep.id) ?? 0,
          _updated: ep.updatedAt.getTime(),
        };
      })
      .sort((a, b) => (b.lastAt ?? '').localeCompare(a.lastAt ?? '') || b._updated - a._updated)
      .map(({ _updated: _u, ...rest }) => rest);
    return paginateArray(items, page);
  });

  app.get('/care-episodes/:id/messages', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const q = parse(z.object({ after: zUuid.optional() }), req.query);
    const ep = await loadEpisode(id);
    await requireParticipant(req.ctx, ep, 'message.list');
    let rows: MessageRow[];
    if (q.after) {
      const [anchor] = await db.select({ seq: careMessages.seq }).from(careMessages).where(and(eq(careMessages.id, q.after), eq(careMessages.careEpisodeId, id)));
      if (!anchor) throw errors.validation('after must be a message of this thread', { field: 'after' });
      rows = await db
        .select()
        .from(careMessages)
        .where(and(eq(careMessages.careEpisodeId, id), gt(careMessages.seq, anchor.seq)))
        .orderBy(asc(careMessages.seq))
        .limit(100);
    } else {
      rows = (await db.select().from(careMessages).where(eq(careMessages.careEpisodeId, id)).orderBy(desc(careMessages.seq)).limit(100)).reverse();
    }
    return { items: rows.map(toChatMessage), nextCursor: null };
  });

  app.post('/care-episodes/:id/messages', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ text: z.string().trim().min(1).max(2000), attachmentRecordId: zUuid.optional() }), req.body);
    const ep = await loadEpisode(id);
    const role = await requireParticipant(req.ctx, ep, 'message.create');
    if (body.attachmentRecordId) {
      const [rec] = await db.select({ patientId: medicalRecords.patientId }).from(medicalRecords).where(eq(medicalRecords.id, body.attachmentRecordId));
      if (!rec || rec.patientId !== ep.patientId) throw errors.validation("attachmentRecordId must be a record of this episode's patient", { field: 'attachmentRecordId' });
    }
    const fromPatientSide = role === 'patient' || role === 'family';
    const safety = fromPatientSide ? await svc.safety.evaluate({ text: body.text }) : null;
    const senderName = role === 'care_team' ? 'Care team' : (req.ctx.user.name ?? 'Care team member');
    const msg = await db.transaction(async (tx) => {
      const [m] = await tx
        .insert(careMessages)
        .values({ careEpisodeId: id, senderUserId: req.ctx.user.id, senderName, senderRole: role, kind: 'text', text: body.text, attachmentRecordId: body.attachmentRecordId ?? null })
        .returning();
      if (safety?.level === 'emergency') {
        const [sys] = await tx
          .insert(careMessages)
          .values({ careEpisodeId: id, senderUserId: null, senderName: 'CareCompanion', senderRole: 'system', kind: 'emergency_notice', text: t(req.ctx.lang, 'ai.emergency') })
          .returning();
        await svc.safety.recordEvent(tx, {
          patientId: ep.patientId,
          careEpisodeId: id,
          level: 'emergency',
          source: 'message',
          rules: safety.triggeredRules,
          rulePackVersion: safety.rulePackVersion,
        });
        m.seq = Math.max(m.seq, sys.seq);
      }
      await tx
        .insert(careMessageReads)
        .values({ careEpisodeId: id, userId: req.ctx.user.id, lastReadSeq: m.seq })
        .onConflictDoUpdate({
          target: [careMessageReads.careEpisodeId, careMessageReads.userId],
          set: { lastReadSeq: sql`greatest(${careMessageReads.lastReadSeq}, ${m.seq})`, updatedAt: new Date() },
        });
      await audit(tx, req.ctx.actor, {
        action: 'message.create',
        entityType: 'care_episode',
        entityId: id,
        metadata: { role, length: body.text.length, attachment: !!body.attachmentRecordId, safetyLevel: safety?.level ?? null },
      });
      return m;
    });
    const recipients = (await recipientUserIds(db, ep)).filter((uid) => uid !== req.ctx.user.id);
    await svc.notify.notifyUsers(recipients, {
      template: 'care_message',
      category: 'system',
      deepLink: `/care-episodes/${id}/messages`,
      dedupeKey: `care_message:${msg.id}`,
      lockScreenKey: 'notify.lockscreen.message',
    });
    if (safety?.level === 'emergency') {
      await svc.notify.notifyPatient(ep.patientId, {
        template: 'safety_alert',
        params: { patient: 'your family member' },
        category: 'safety',
        critical: true,
        deepLink: `/care-episodes/${id}/messages`,
        dedupeKey: `care_message_safety:${msg.id}`,
      });
    }
    const [fresh] = await db.select().from(careMessages).where(eq(careMessages.id, msg.id));
    return reply.code(201).send(toChatMessage(fresh));
  });

  app.post('/care-episodes/:id/messages/read', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const ep = await loadEpisode(id);
    await requireParticipant(req.ctx, ep, 'message.read');
    const [max] = await db.select({ seq: sql<number>`coalesce(max(${careMessages.seq}), 0)::int` }).from(careMessages).where(eq(careMessages.careEpisodeId, id));
    const seq = Number(max?.seq ?? 0);
    await db
      .insert(careMessageReads)
      .values({ careEpisodeId: id, userId: req.ctx.user.id, lastReadSeq: seq })
      .onConflictDoUpdate({
        target: [careMessageReads.careEpisodeId, careMessageReads.userId],
        set: { lastReadSeq: sql`greatest(${careMessageReads.lastReadSeq}, ${seq})`, updatedAt: new Date() },
      });
    return reply.code(204).send();
  });
}

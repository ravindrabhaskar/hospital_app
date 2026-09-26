import { and, desc, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { moodEntries } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { t } from '../../lib/i18n.js';
import { envelope, list, pageFromQuery } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';
import { alertEmergencyContacts, openEmergency } from '../emergency/service.js';
import { clinicalContext } from '../patients/service.js';

export const WELLNESS_ACTIVITIES = [
  { code: 'box_breathing', title: 'Box breathing', description: 'Breathe in 4s, hold 4s, out 4s, hold 4s. Repeat for a few minutes.', durationMins: 4, kind: 'breathing' },
  { code: 'body_scan', title: 'Body scan meditation', description: 'Slowly bring attention to each part of your body and relax it.', durationMins: 10, kind: 'meditation' },
  { code: 'gratitude_journal', title: 'Gratitude journal', description: 'Write down three things you are grateful for today.', durationMins: 5, kind: 'journaling' },
  { code: 'wind_down', title: 'Wind-down routine', description: 'Dim the lights, put screens away and relax before bed.', durationMins: 15, kind: 'sleep' },
] as const;

export const toMood = (m: typeof moodEntries.$inferSelect) => ({
  id: m.id,
  patientId: m.patientId,
  score: m.score,
  note: m.note,
  shareWithClinician: m.shareWithClinician,
  createdAt: iso(m.createdAt),
});

export async function wellnessRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/wellness/activities', async () => {
    await svc.flags.require('mental_wellness');
    return list([...WELLNESS_ACTIVITIES]);
  });

  app.post('/wellness/mood', async (req, reply) => {
    await svc.flags.require('mental_wellness');
    const body = parse(
      z.object({ patientId: zUuid, score: z.number().int().min(1).max(5), note: z.string().max(2000).optional(), shareWithClinician: z.boolean() }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, body.patientId, 'manage_care', 'mood.create');
    const cc = await clinicalContext(db, body.patientId);
    // Deterministic safety engine on the free-text note.
    const safety = await svc.safety.evaluate({ text: body.note ?? '', ageYears: cc.age });
    const [row] = await db
      .insert(moodEntries)
      .values({ patientId: body.patientId, score: body.score, note: body.note ?? null, shareWithClinician: body.shareWithClinician, createdByUserId: req.ctx.user.id })
      .returning();
    await audit(db, req.ctx.actor, { action: 'mood.create', entityType: 'mood_entry', entityId: row.id, metadata: { safetyLevel: safety.level } });
    let supportMessage: string;
    if (safety.level === 'emergency') {
      supportMessage = t(req.ctx.lang, 'mood.support.emergency');
      const em = await db.transaction((tx) =>
        openEmergency(svc, tx, {
          patientId: body.patientId,
          title: 'Wellbeing safety alert',
          concern: 'Safety rule triggered by a mood check-in',
          source: 'mood',
          rule: safety.triggeredRules[0] ?? { ruleId: 'mood.safety', title: 'Mood safety rule' },
          actor: req.ctx.actor,
        }),
      );
      await alertEmergencyContacts(svc, body.patientId, 'sos', `/care-episodes/${em.episodeId}`);
    } else {
      if (safety.level === 'urgent') {
        await svc.safety.recordEvent(db, {
          patientId: body.patientId,
          careEpisodeId: null,
          level: 'urgent',
          source: 'mood',
          rules: safety.triggeredRules,
          rulePackVersion: safety.rulePackVersion,
        });
      }
      supportMessage = t(req.ctx.lang, body.score <= 2 ? 'mood.support.low' : body.score === 3 ? 'mood.support.mid' : 'mood.support.high');
    }
    return reply.code(201).send({ ...toMood(row), supportMessage, safety });
  });

  app.get('/wellness/mood', async (req) => {
    const q = parse(z.object({ patientId: zUuid }), req.query);
    const page = pageFromQuery(req.query);
    const access = await assertCanActForPatient(db, req.ctx, q.patientId, 'manage_care', 'mood.list');
    // Clinicians only see entries the patient chose to share.
    const clinicianOnly = !access.isOwner && !access.via.includes('grant');
    const rows = await db
      .select()
      .from(moodEntries)
      .where(clinicianOnly ? and(eq(moodEntries.patientId, q.patientId), eq(moodEntries.shareWithClinician, true)) : eq(moodEntries.patientId, q.patientId))
      .orderBy(desc(moodEntries.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toMood), page);
  });
}

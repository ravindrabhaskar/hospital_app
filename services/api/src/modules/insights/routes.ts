import { and, desc, eq, gte } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { vitals } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { list } from '../../lib/pagination.js';
import { istDate, istDayBounds, iso } from '../../lib/time.js';
import { parse, zUuid } from '../../lib/validate.js';

const STEPS_GOAL = 8000;

/**
 * Only data that exists is returned (empty list when none). No clinical interpretation:
 * `status` is informational (e.g. progress toward a goal), never a diagnosis.
 */
export async function insightRoutes(app: FastifyInstance): Promise<void> {
  const db = app.svc.db;

  app.get('/insights/today', async (req) => {
    const q = parse(z.object({ patientId: zUuid }), req.query);
    await assertCanActForPatient(db, req.ctx, q.patientId, ['view_records', 'manage_care'], 'insights.read');
    const since = new Date(Date.now() - 7 * 86400_000);
    const rows = await db
      .select()
      .from(vitals)
      .where(and(eq(vitals.patientId, q.patientId), gte(vitals.measuredAt, since)))
      .orderBy(desc(vitals.measuredAt));
    const latest = (type: string) => rows.find((r) => r.type === type);
    const items: Array<{ type: string; label: string; value: number; unit: string; status: string | null; goal: number | null; source: string; measuredAt: string | null }> = [];

    const pulse = latest('pulse');
    if (pulse) items.push({ type: 'heart_rate', label: 'Heart rate', value: pulse.value, unit: 'bpm', status: null, goal: null, source: pulse.source, measuredAt: iso(pulse.measuredAt) });

    const { start } = istDayBounds(istDate());
    const stepsToday = rows.filter((r) => r.type === 'steps' && r.measuredAt >= start);
    if (stepsToday.length) {
      const total = stepsToday.reduce((s, r) => s + r.value, 0);
      items.push({
        type: 'steps',
        label: 'Steps today',
        value: total,
        unit: 'steps',
        status: `${Math.min(100, Math.round((total / STEPS_GOAL) * 100))}% of goal`,
        goal: STEPS_GOAL,
        source: stepsToday[0].source,
        measuredAt: iso(stepsToday[0].measuredAt),
      });
    }
    const sleep = latest('sleep_minutes');
    if (sleep) {
      items.push({ type: 'sleep', label: 'Sleep', value: Math.round((sleep.value / 60) * 10) / 10, unit: 'h', status: null, goal: 8, source: sleep.source, measuredAt: iso(sleep.measuredAt) });
    }
    const sys = latest('bp_systolic');
    if (sys) {
      const dia = rows.find((r) => r.type === 'bp_diastolic' && Math.abs(r.measuredAt.getTime() - sys.measuredAt.getTime()) < 10 * 60_000);
      items.push({
        type: 'bp',
        label: dia ? `Blood pressure ${sys.value}/${dia.value}` : 'Blood pressure (systolic)',
        value: sys.value,
        unit: 'mmHg',
        status: null,
        goal: null,
        source: sys.source,
        measuredAt: iso(sys.measuredAt),
      });
    }
    const spo2 = latest('spo2');
    if (spo2) items.push({ type: 'spo2', label: 'SpO2', value: spo2.value, unit: '%', status: null, goal: null, source: spo2.source, measuredAt: iso(spo2.measuredAt) });
    return list(items);
  });
}

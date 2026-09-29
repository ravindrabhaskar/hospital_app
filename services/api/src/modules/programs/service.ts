import { and, desc, eq, gte, inArray, lt, lte } from 'drizzle-orm';
import type { Config } from '../../config.js';
import type { DbOrTx } from '../../db/client.js';
import { patients, programBreaches, programEnrollments, programTemplates, safetyEvents, vitals, type ThresholdJson } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR } from '../../lib/context.js';
import { PdfBuilder, pdfDate } from '../../lib/pdf.js';
import { addDays, ageFromDob, istDate, istDayBounds, istToUtc, iso } from '../../lib/time.js';
import type { Services } from '../../services.js';
import { storeRecord } from '../records/service.js';
import { raiseAlert } from '../safety/alerts.js';
import { LEVEL_ORDER, maxLevel, type SafetyLevel } from '../safety/engine.js';

/** Contract section 42: chronic care programs (remote monitoring). */
export type TemplateRow = typeof programTemplates.$inferSelect;
export type EnrollmentRow = typeof programEnrollments.$inferSelect;

export const toTemplate = (t: TemplateRow) => ({
  code: t.code,
  name: t.name,
  description: t.description,
  metrics: t.metrics,
  defaultThresholds: t.defaultThresholds,
  status: t.status as 'fixture_unapproved' | 'approved',
  version: t.version,
});

/** Usable template versions: approved only in production; the latest approved version wins, else the latest. */
export async function activeTemplates(db: DbOrTx, config: Config): Promise<TemplateRow[]> {
  const rows = await db.select().from(programTemplates).where(eq(programTemplates.active, true)).orderBy(desc(programTemplates.createdAt));
  const byCode = new Map<string, TemplateRow>();
  for (const r of rows) {
    if (config.NODE_ENV === 'production' && r.status !== 'approved') continue;
    const cur = byCode.get(r.code);
    if (!cur || (cur.status !== 'approved' && r.status === 'approved')) byCode.set(r.code, r);
  }
  return [...byCode.values()].sort((a, b) => a.code.localeCompare(b.code));
}

export async function templateByCode(db: DbOrTx, config: Config, code: string): Promise<TemplateRow | null> {
  return (await activeTemplates(db, config)).find((t) => t.code === code) ?? null;
}

// ---------------------------------------------------------------- summary & adherence
const PER_DAY: Record<string, number> = { daily: 1, twice_daily: 2, weekly: 1 / 7 };

export async function programSummary(db: DbOrTx, e: EnrollmentRow, template: TemplateRow | null, from: string, to: string) {
  const start = e.startDate > from ? e.startDate : from;
  const days = Math.max(0, Math.round((istDayBounds(to).end.getTime() - istDayBounds(start).start.getTime()) / 86400_000));
  const metrics = template?.metrics ?? [...new Set(e.thresholds.map((t) => t.type))].map((type) => ({ type, frequency: 'daily' as const, unit: '' }));
  const types = metrics.map((m) => m.type);
  const expected = Math.round(metrics.reduce((s, m) => s + (PER_DAY[m.frequency] ?? 1) * days, 0));
  const rows = types.length
    ? await db
        .select()
        .from(vitals)
        .where(and(eq(vitals.patientId, e.patientId), inArray(vitals.type, types), gte(vitals.measuredAt, istDayBounds(from).start), lt(vitals.measuredAt, istDayBounds(to).end)))
        .orderBy(vitals.measuredAt)
    : [];
  // A reading counts once per expected slot: cap per type and day at the metric's daily frequency.
  const perDayCap = new Map(metrics.map((m) => [m.type, Math.max(1, Math.ceil(PER_DAY[m.frequency] ?? 1))]));
  const counted = new Map<string, number>();
  let received = 0;
  for (const v of rows) {
    const k = `${v.type}|${istDate(v.measuredAt)}`;
    const c = counted.get(k) ?? 0;
    if (c < (perDayCap.get(v.type) ?? 1)) {
      received++;
      counted.set(k, c + 1);
    }
  }
  const breaches = await db
    .select()
    .from(programBreaches)
    .where(and(eq(programBreaches.enrollmentId, e.id), gte(programBreaches.at, istDayBounds(from).start), lt(programBreaches.at, istDayBounds(to).end)))
    .orderBy(programBreaches.at);
  const trendMap = new Map<string, number[]>();
  for (const v of rows) {
    const k = `${istDate(v.measuredAt)}|${v.type}`;
    trendMap.set(k, [...(trendMap.get(k) ?? []), v.value]);
  }
  const trend = [...trendMap.entries()]
    .map(([k, vals]) => {
      const [date, type] = k.split('|');
      return { date, type, avg: Math.round((vals.reduce((a, b) => a + b, 0) / vals.length) * 10) / 10, min: Math.min(...vals), max: Math.max(...vals) };
    })
    .sort((a, b) => a.date.localeCompare(b.date) || a.type.localeCompare(b.type));
  return {
    enrollmentId: e.id,
    from,
    to,
    expectedReadings: expected,
    receivedReadings: received,
    adherencePct: expected > 0 ? Math.min(100, Math.round((received / expected) * 100)) : null,
    breaches: breaches.map((b) => ({ at: iso(b.at), type: b.type, value: b.value, threshold: b.threshold, safetyEventId: b.safetyEventId })),
    trend,
  };
}

export async function toEnrollments(db: DbOrTx, config: Config, rows: EnrollmentRow[]) {
  if (!rows.length) return [];
  const templates = await db.select().from(programTemplates);
  const names = new Map(templates.map((t) => [t.code, t.name]));
  const pats = await db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, [...new Set(rows.map((r) => r.patientId))]));
  const pn = new Map(pats.map((p) => [p.id, p.name]));
  const today = istDate();
  const out = [];
  for (const e of rows) {
    const tpl = templates.find((t) => t.code === e.templateCode && t.version === e.templateVersion) ?? null;
    const sum = await programSummary(db, e, tpl, addDays(today, -6), today);
    const types = [...new Set([...(tpl?.metrics.map((m) => m.type) ?? []), ...e.thresholds.map((t) => t.type)])];
    const [last] = types.length
      ? await db.select({ at: vitals.measuredAt }).from(vitals).where(and(eq(vitals.patientId, e.patientId), inArray(vitals.type, types), gte(vitals.measuredAt, istToUtc(e.startDate, '00:00')))).orderBy(desc(vitals.measuredAt)).limit(1)
      : [];
    const open = await db
      .select({ id: programBreaches.id })
      .from(programBreaches)
      .innerJoin(safetyEvents, eq(safetyEvents.id, programBreaches.safetyEventId))
      .where(and(eq(programBreaches.enrollmentId, e.id), inArray(safetyEvents.status, ['open', 'acknowledged'])));
    out.push({
      id: e.id,
      patientId: e.patientId,
      patientName: pn.get(e.patientId) ?? null,
      templateCode: e.templateCode,
      templateName: names.get(e.templateCode) ?? e.templateCode,
      status: e.status,
      thresholds: e.thresholds,
      thresholdsApprovedByName: e.thresholdsApprovedByName,
      startDate: e.startDate,
      endDate: e.endDate,
      careEpisodeId: e.careEpisodeId,
      adherencePct7d: sum.adherencePct,
      lastReadingAt: iso(last?.at ?? null),
      openBreaches: open.length,
      createdAt: iso(e.createdAt),
    });
  }
  void config;
  return out;
}

// ---------------------------------------------------------------- vital evaluation

const breached = (t: ThresholdJson, value: number) => (t.op === 'gt' ? value > t.value : value < t.value);

export interface VitalEvalResult {
  level: SafetyLevel;
  breaches: number;
  safetyEventIds: string[];
}

/**
 * Evaluate newly recorded vitals against the patient's active enrollments and the deterministic safety engine.
 * A breach creates a SafetyEvent (source `program`, the threshold's level, never lower than the engine's level)
 * and notifies the coordinator and family with receive_alerts. `engineOnlySource` raises engine-only findings
 * (no enrollment) for channels that promise it (e.g. WhatsApp readings).
 */
export async function evaluateVitals(
  svc: Services,
  patientId: string,
  rows: Array<{ id: string; type: string; value: number; measuredAt: Date }>,
  opts: { engineOnlySource?: 'message' | null } = {},
): Promise<VitalEvalResult> {
  const result: VitalEvalResult = { level: 'none', breaches: 0, safetyEventIds: [] };
  if (!rows.length) return result;
  const today = istDate();
  const enrollments = await svc.db
    .select()
    .from(programEnrollments)
    .where(and(eq(programEnrollments.patientId, patientId), eq(programEnrollments.status, 'active'), lte(programEnrollments.startDate, today)));
  const [p] = await svc.db.select({ dob: patients.dob, name: patients.name }).from(patients).where(eq(patients.id, patientId));
  const engine = await svc.safety.evaluate({ vitals: rows.map((r) => ({ type: r.type, value: r.value })), ageYears: ageFromDob(p?.dob ?? null) });
  const engineLevel: SafetyLevel = engine.triggeredRules.some((r) => r.ruleId === 'failsafe.no_approved_pack') ? 'none' : engine.level;
  result.level = engineLevel;
  const name = p?.name?.split(' ')[0] ?? 'your family member';
  for (const e of enrollments) {
    if (e.endDate && e.endDate < today) continue;
    for (const v of rows) {
      const hits = e.thresholds.filter((t) => t.type === v.type && breached(t, v.value));
      if (!hits.length) continue;
      const top = hits.reduce((a, b) => (LEVEL_ORDER.indexOf(b.level) > LEVEL_ORDER.indexOf(a.level) ? b : a));
      const [breach] = await svc.db
        .insert(programBreaches)
        .values({ enrollmentId: e.id, vitalId: v.id, at: v.measuredAt, type: v.type, value: v.value, threshold: top })
        .onConflictDoNothing()
        .returning();
      if (!breach) continue;
      result.breaches++;
      // The program can never lower the safety level computed by the engine.
      const level = maxLevel(top.level, engineLevel);
      result.level = maxLevel(result.level, level);
      if (level !== 'urgent' && level !== 'emergency') continue;
      const event = await raiseAlert(svc, {
        patientId,
        careEpisodeId: e.careEpisodeId,
        level,
        source: 'program',
        rules: [
          { ruleId: `program.${e.templateCode}.${v.type}.${top.op}${top.value}`, title: top.message },
          ...engine.triggeredRules.map((r) => ({ ruleId: r.ruleId, title: r.title })),
        ],
        note: `${v.type} ${v.value}`,
        familyTemplate: 'program_breach',
        familyParams: { patient: name },
        category: 'program',
        deepLink: `/care-programs/enrollments/${e.id}`,
        dedupeKey: `program_breach:${breach.id}`,
      });
      await svc.db.update(programBreaches).set({ safetyEventId: event.id }).where(eq(programBreaches.id, breach.id));
      result.safetyEventIds.push(event.id);
    }
  }
  if (!result.safetyEventIds.length && opts.engineOnlySource && (engineLevel === 'urgent' || engineLevel === 'emergency')) {
    const event = await raiseAlert(svc, {
      patientId,
      level: engineLevel,
      source: opts.engineOnlySource,
      rules: engine.triggeredRules.map((r) => ({ ruleId: r.ruleId, title: r.title })),
      note: rows.map((r) => `${r.type} ${r.value}`).join(', '),
      familyParams: { patient: name },
    });
    result.safetyEventIds.push(event.id);
  }
  return result;
}

// ---------------------------------------------------------------- weekly report

/** ISO-like week key of an IST date (the Monday date). */
export function weekKey(date: string): string {
  const d = new Date(`${date}T00:00:00Z`);
  const dow = (d.getUTCDay() + 6) % 7; // Monday = 0
  return addDays(date, -dow);
}

export async function renderWeeklyReport(p: { patientName: string; templateName: string; summary: Awaited<ReturnType<typeof programSummary>>; thresholds: ThresholdJson[]; now: Date }): Promise<Buffer> {
  const b = new PdfBuilder('Weekly health report', `${p.summary.from} to ${p.summary.to}`, { subject: 'Weekly health report' });
  b.infoBoxes([
    { title: 'Patient', rows: [['Name', p.patientName], ['Program', p.templateName], ['Generated', pdfDate(p.now)]] },
    {
      title: 'This week',
      rows: [
        ['Readings', `${p.summary.receivedReadings} of ${p.summary.expectedReadings} expected`],
        ['Adherence', p.summary.adherencePct === null ? '-' : `${p.summary.adherencePct}%`],
        ['Alerts', String(p.summary.breaches.length)],
      ],
    },
  ]);
  b.heading('Daily readings');
  if (p.summary.trend.length) {
    b.table(
      [
        { header: 'Date', width: 80 },
        { header: 'Reading', width: 120 },
        { header: 'Average', width: 70, align: 'right' },
        { header: 'Lowest', width: 70, align: 'right' },
        { header: 'Highest', width: 70, align: 'right' },
      ],
      p.summary.trend.map((t) => [t.date, t.type.replace(/_/g, ' '), String(t.avg), String(t.min), String(t.max)]),
    );
  } else {
    b.paragraph('No readings were recorded this week.');
  }
  b.heading('Alerts');
  b.paragraph(
    p.summary.breaches.length
      ? p.summary.breaches.map((x) => `${x.at?.slice(0, 16).replace('T', ' ')} UTC: ${x.type.replace(/_/g, ' ')} ${x.value}`).join('\n')
      : 'No readings outside the agreed limits.',
  );
  b.heading('Agreed limits');
  b.paragraph(p.thresholds.map((t) => `${t.type.replace(/_/g, ' ')} ${t.op === 'gt' ? 'above' : 'below'} ${t.value} (${t.level})`).join('\n') || '-');
  b.paragraph('This report summarises readings entered at home or by devices. It is not a diagnosis. Discuss any concerns with your doctor. In an emergency call 108.', { size: 8.5, color: '#6B7280' });
  return b.finish(['CareCompanion weekly health report (automatically generated). Limits are program fixtures [REQUIRES CLINICAL GOVERNANCE].']);
}

/**
 * Worker: every Monday from 09:00 IST, one "Weekly health report" PDF record per active enrollment (for the previous
 * 7 days), and the family is notified. Idempotent per enrollment and week.
 */
export async function weeklyReports(svc: Services, now: Date, opts: { force?: boolean } = {}): Promise<number> {
  const today = istDate(now);
  const isMonday = new Date(`${today}T00:00:00Z`).getUTCDay() === 1;
  if (!opts.force && (!isMonday || now < istToUtc(today, '09:00'))) return 0;
  const wk = weekKey(today);
  const rows = await svc.db.select().from(programEnrollments).where(eq(programEnrollments.status, 'active'));
  let n = 0;
  for (const e of rows) {
    if (e.lastWeeklyReportWeek === wk) continue;
    const claimed = await svc.db
      .update(programEnrollments)
      .set({ lastWeeklyReportWeek: wk })
      .where(and(eq(programEnrollments.id, e.id), eq(programEnrollments.status, 'active')))
      .returning();
    if (!claimed.length) continue;
    const [tpl] = await svc.db.select().from(programTemplates).where(and(eq(programTemplates.code, e.templateCode), eq(programTemplates.version, e.templateVersion)));
    const [p] = await svc.db.select({ name: patients.name }).from(patients).where(eq(patients.id, e.patientId));
    const summary = await programSummary(svc.db, e, tpl ?? null, addDays(today, -7), addDays(today, -1));
    const pdf = await renderWeeklyReport({ patientName: p?.name ?? 'Patient', templateName: tpl?.name ?? e.templateCode, summary, thresholds: e.thresholds, now });
    const rec = await storeRecord(svc.db, svc.storage, {
      patientId: e.patientId,
      type: 'other',
      title: `Weekly health report - ${tpl?.name ?? e.templateCode}`,
      recordDate: today,
      source: 'patient_entered',
      uploadedByUserId: null,
      uploadedByName: 'CareCompanion',
      fileName: `weekly-report-${wk}-${e.id.slice(0, 8)}.pdf`,
      mimeType: 'application/pdf',
      data: pdf,
    });
    await audit(svc.db, SYSTEM_ACTOR, { action: 'program.weekly_report', entityType: 'program_enrollment', entityId: e.id, metadata: { recordId: rec.id, week: wk } });
    await svc.notify.notifyPatient(e.patientId, {
      template: 'weekly_report',
      params: { patient: p?.name?.split(' ')[0] ?? 'your family member' },
      category: 'program',
      deepLink: `/records/${rec.id}`,
      dedupeKey: `weekly_report:${e.id}:${wk}`,
    });
    n++;
  }
  return n;
}

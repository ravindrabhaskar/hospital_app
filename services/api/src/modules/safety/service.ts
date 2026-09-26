import { eq, inArray } from 'drizzle-orm';
import type { Config } from '../../config.js';
import type { Db, DbOrTx } from '../../db/client.js';
import { patients, safetyEvents, safetyRulePacks } from '../../db/schema.js';
import { iso } from '../../lib/time.js';
import { FAILSAFE_RULE, evaluateRules, type SafetyInput, type SafetyResult } from './engine.js';

export type SafetyPackRow = typeof safetyRulePacks.$inferSelect;
export type SafetyEventRow = typeof safetyEvents.$inferSelect;

export class SafetyService {
  constructor(
    private readonly db: Db,
    private readonly config: Config,
  ) {}

  async activePack(): Promise<SafetyPackRow | null> {
    const [row] = await this.db.select().from(safetyRulePacks).where(eq(safetyRulePacks.active, true)).limit(1);
    return row ?? null;
  }

  /** Can this pack be served? In production only clinician-approved packs are usable. */
  isServable(pack: SafetyPackRow | null): pack is SafetyPackRow {
    if (!pack) return false;
    if (pack.status === 'approved') return true;
    return this.config.NODE_ENV !== 'production' && pack.status === 'fixture_unapproved';
  }

  async status(): Promise<'ok' | 'fixture' | 'unavailable'> {
    const pack = await this.activePack();
    if (!this.isServable(pack)) return 'unavailable';
    return pack.status === 'approved' ? 'ok' : 'fixture';
  }

  /**
   * Evaluate the active pack. Fail-safe: if there is no servable pack (e.g. an unapproved pack
   * in production), everything is routed to "consult a doctor" at level urgent.
   */
  async evaluate(input: SafetyInput): Promise<SafetyResult> {
    const pack = await this.activePack();
    const packVersion = pack?.version ?? 'none';
    if (!this.isServable(pack)) {
      return {
        level: 'urgent',
        triggeredRules: [FAILSAFE_RULE],
        rulePackVersion: packVersion,
        rulePackStatus: 'fixture_unapproved',
      };
    }
    return evaluateRules(pack.rules, input, {
      version: pack.version,
      status: pack.status === 'approved' ? 'approved' : 'fixture_unapproved',
    });
  }

  async recordEvent(
    db: DbOrTx,
    e: {
      patientId: string;
      careEpisodeId: string | null;
      level: 'urgent' | 'emergency';
      source: 'ai_intake' | 'home_visit' | 'mood' | 'fall' | 'sos' | 'message';
      rules: Array<{ ruleId: string; title: string }>;
      rulePackVersion: string | null;
      note?: string | null;
    },
  ): Promise<SafetyEventRow> {
    const [row] = await db
      .insert(safetyEvents)
      .values({
        patientId: e.patientId,
        careEpisodeId: e.careEpisodeId,
        level: e.level,
        source: e.source,
        rules: e.rules.map((r) => ({ ruleId: r.ruleId, title: r.title })),
        rulePackVersion: e.rulePackVersion,
        note: e.note ?? null,
      })
      .returning();
    return row;
  }
}

export async function toSafetyEvents(db: DbOrTx, rows: SafetyEventRow[]) {
  const ids = [...new Set(rows.map((r) => r.patientId))];
  const names = ids.length ? await db.select({ id: patients.id, name: patients.name }).from(patients).where(inArray(patients.id, ids)) : [];
  const nameOf = new Map(names.map((n) => [n.id, n.name]));
  return rows.map((r) => ({
    id: r.id,
    patientId: r.patientId,
    patientName: nameOf.get(r.patientId) ?? null,
    careEpisodeId: r.careEpisodeId,
    level: r.level,
    source: r.source,
    rules: r.rules,
    status: r.status,
    assignedToName: r.assignedToName,
    createdAt: iso(r.createdAt),
    resolvedAt: iso(r.resolvedAt),
    note: r.note,
  }));
}

export function toPack(p: SafetyPackRow) {
  return {
    id: p.id,
    version: p.version,
    status: p.status,
    active: p.active,
    approvedBy: p.approvedBy,
    approvedAt: iso(p.approvedAt),
    ruleCount: p.rules.length,
    rules: p.rules,
  };
}

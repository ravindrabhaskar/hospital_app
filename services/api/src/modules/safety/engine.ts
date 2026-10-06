import { stripGovernanceMarkers } from '../../lib/governance.js';
/**
 * Deterministic safety engine. Pure functions only: the rules themselves are DATA
 * (versioned rule packs stored in the DB and approved by clinical governance).
 * This code never invents clinical rules.
 */
import type { SafetyRuleJson } from '../../db/schema.js';

export type SafetyLevel = 'none' | 'routine' | 'urgent' | 'emergency';
export const LEVEL_ORDER: SafetyLevel[] = ['none', 'routine', 'urgent', 'emergency'];

export const maxLevel = (a: SafetyLevel, b: SafetyLevel): SafetyLevel => (LEVEL_ORDER.indexOf(a) >= LEVEL_ORDER.indexOf(b) ? a : b);
export const levelGte = (a: SafetyLevel, b: SafetyLevel): boolean => LEVEL_ORDER.indexOf(a) >= LEVEL_ORDER.indexOf(b);

export interface SafetyInput {
  text?: string | null;
  severity?: number | null;
  ageYears?: number | null;
  vitals?: Array<{ type: string; value: number }>;
}

export interface SafetyResult {
  level: SafetyLevel;
  triggeredRules: Array<{ ruleId: string; title: string; action: SafetyRuleJson['action'] }>;
  rulePackVersion: string;
  rulePackStatus: 'approved' | 'fixture_unapproved';
}

export function normalizeText(text: string): string {
  return ` ${text
    .toLowerCase()
    .replace(/[‘’ʼ`]/g, "'")
    .replace(/[^\p{L}\p{N}'%./\s-]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim()} `;
}

export function containsKeyword(normalized: string, keyword: string): boolean {
  const k = normalizeText(keyword).trim();
  if (!k) return false;
  // Word-boundary style match on the normalised text.
  const re = new RegExp(`(^|[^\\p{L}\\p{N}])${k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}($|[^\\p{L}\\p{N}])`, 'u');
  return re.test(normalized);
}

/** A rule triggers only when ALL of its specified conditions hold (and it has at least one). */
export function ruleMatches(rule: SafetyRuleJson, input: SafetyInput): boolean {
  const w = rule.when ?? {};
  const text = normalizeText(input.text ?? '');
  let conditions = 0;
  if (w.anyKeywords?.length) {
    conditions++;
    if (!w.anyKeywords.some((k) => containsKeyword(text, k))) return false;
  }
  if (w.allKeywords?.length) {
    conditions++;
    if (!w.allKeywords.every((k) => containsKeyword(text, k))) return false;
  }
  if (typeof w.minSeverity === 'number') {
    conditions++;
    if (typeof input.severity !== 'number' || input.severity < w.minSeverity) return false;
  }
  if (w.vital) {
    conditions++;
    const vital = w.vital;
    const hit = (input.vitals ?? []).some(
      (v) => v.type === vital.type && (vital.op === 'lt' ? v.value < vital.value : v.value > vital.value),
    );
    if (!hit) return false;
  }
  if (typeof w.ageGte === 'number') {
    conditions++;
    if (typeof input.ageYears !== 'number' || input.ageYears < w.ageGte) return false;
  }
  return conditions > 0;
}

export function evaluateRules(
  rules: SafetyRuleJson[],
  input: SafetyInput,
  pack: { version: string; status: 'approved' | 'fixture_unapproved' },
): SafetyResult {
  const triggered = rules.filter((r) => ruleMatches(r, input));
  const level = triggered.reduce<SafetyLevel>((acc, r) => maxLevel(acc, r.level), 'none');
  return {
    level,
    triggeredRules: triggered.map((r) => ({ ruleId: r.id, title: stripGovernanceMarkers(r.title), action: r.action })),
    rulePackVersion: pack.version,
    rulePackStatus: pack.status,
  };
}

/** Combine a deterministic result with any other signal. The level can only go UP. */
export function neverDowngrade(base: SafetyResult, proposed: SafetyLevel): SafetyResult {
  return { ...base, level: maxLevel(base.level, proposed) };
}

export const FAILSAFE_RULE = {
  ruleId: 'failsafe.no_approved_pack',
  title: 'Safety rules unavailable: consult a doctor',
  action: 'suggest_doctor' as const,
};

/**
 * FIXTURE RULE PACK — NON-CLINICAL TEST DATA.
 * These rules exist only so the software can be exercised end-to-end. They are NOT clinically
 * validated and MUST be replaced by a clinician-approved pack before production use.
 */
export const FIXTURE_PACK_VERSION = 'fixture-0.1';
const FIX = 'FIXTURE — replace with clinician-approved rule.';
export const FIXTURE_RULES: SafetyRuleJson[] = [
  {
    id: 'fx.emergency.keywords.cardiorespiratory',
    title: 'Possible emergency: chest pain or breathing difficulty (fixture)',
    description: `${FIX} Test keyword trigger for chest pain / breathing difficulty.`,
    when: { anyKeywords: ['chest pain', "can't breathe", 'cannot breathe', 'cant breathe', 'not able to breathe', 'choking'] },
    level: 'emergency',
    action: 'show_emergency',
  },
  {
    id: 'fx.emergency.keywords.consciousness',
    title: 'Possible emergency: unconsciousness (fixture)',
    description: `${FIX} Test keyword trigger for unconsciousness / unresponsiveness.`,
    when: { anyKeywords: ['unconscious', 'unresponsive', 'fainted and not waking', 'seizure now'] },
    level: 'emergency',
    action: 'show_emergency',
  },
  {
    id: 'fx.emergency.keywords.self_harm',
    title: 'Possible emergency: self-harm risk (fixture)',
    description: `${FIX} Test keyword trigger for self-harm language.`,
    when: { anyKeywords: ['suicide', 'suicidal', 'kill myself', 'end my life', 'harm myself'] },
    level: 'emergency',
    action: 'show_emergency',
  },
  {
    id: 'fx.emergency.keywords.bleeding',
    title: 'Possible emergency: severe bleeding (fixture)',
    description: `${FIX} Test keyword trigger for severe bleeding.`,
    when: { anyKeywords: ['severe bleeding', 'heavy bleeding', 'bleeding heavily', "bleeding won't stop"] },
    level: 'emergency',
    action: 'show_emergency',
  },
  {
    id: 'fx.emergency.vital.spo2_low',
    title: 'Low oxygen saturation (fixture)',
    description: `${FIX} Test vital trigger: SpO2 below 90.`,
    when: { vital: { type: 'spo2', op: 'lt', value: 90 } },
    level: 'emergency',
    action: 'show_emergency',
  },
  {
    id: 'fx.urgent.severity_high',
    title: 'High self-reported severity (fixture)',
    description: `${FIX} Test trigger: self-reported severity 8 or more.`,
    when: { minSeverity: 8 },
    level: 'urgent',
    action: 'escalate_clinician',
  },
  {
    id: 'fx.urgent.vital.bp_high',
    title: 'Very high systolic blood pressure (fixture)',
    description: `${FIX} Test vital trigger: systolic BP above 180.`,
    when: { vital: { type: 'bp_systolic', op: 'gt', value: 180 } },
    level: 'urgent',
    action: 'escalate_clinician',
  },
  {
    id: 'fx.routine.elderly_fever',
    title: 'Older adult with fever: consider home visit (fixture)',
    description: `${FIX} Test trigger: age 65 or more with fever mentioned.`,
    when: { ageGte: 65, anyKeywords: ['fever', 'feverish', 'high temperature'] },
    level: 'routine',
    action: 'suggest_home_visit',
  },
];

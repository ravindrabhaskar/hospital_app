import type { Threshold, ThresholdLevel, VitalType } from "@/lib/api/types";

export const VITAL_TYPES: VitalType[] = [
  "bp_systolic",
  "bp_diastolic",
  "pulse",
  "spo2",
  "temperature",
  "blood_glucose",
  "weight",
  "respiratory_rate",
];
export const THRESHOLD_LEVELS: ThresholdLevel[] = ["routine", "urgent", "emergency"];
export const MAX_THRESHOLDS = 20;

/**
 * Plausible bounds for a threshold value per vital (a guard against typos, not clinical advice).
 * Temperature allows both °C and °F because the contract leaves the unit to the template metric.
 */
export const VITAL_BOUNDS: Record<VitalType, { min: number; max: number }> = {
  bp_systolic: { min: 40, max: 300 },
  bp_diastolic: { min: 20, max: 200 },
  pulse: { min: 20, max: 250 },
  spo2: { min: 50, max: 100 },
  temperature: { min: 30, max: 115 },
  blood_glucose: { min: 20, max: 800 },
  weight: { min: 1, max: 400 },
  respiratory_rate: { min: 4, max: 80 },
};

/** Editable row: `value` is the raw input text. */
export interface ThresholdDraft {
  type: VitalType;
  op: "lt" | "gt";
  value: string;
  level: ThresholdLevel;
  message: string;
}

export interface ThresholdValidation {
  ok: boolean;
  /** Per-row field errors. */
  rows: Partial<Record<keyof ThresholdDraft, string>>[];
  /** Errors about the whole set (count, duplicates). */
  form: string[];
}

export const toDraft = (t: Threshold): ThresholdDraft => ({ ...t, value: String(t.value) });
export const emptyDraft = (type: VitalType = "bp_systolic"): ThresholdDraft => ({ type, op: "gt", value: "", level: "urgent", message: "" });

export function validateThresholds(drafts: readonly ThresholdDraft[], opts: { requireAtLeastOne?: boolean } = {}): ThresholdValidation {
  const rows = drafts.map((d) => {
    const e: Partial<Record<keyof ThresholdDraft, string>> = {};
    if (!VITAL_TYPES.includes(d.type)) e.type = "Choose a vital";
    if (d.op !== "lt" && d.op !== "gt") e.op = "Choose above or below";
    if (!THRESHOLD_LEVELS.includes(d.level)) e.level = "Choose a level";
    const raw = d.value.trim();
    const n = Number(raw);
    if (!raw) e.value = "Enter a value";
    else if (!Number.isFinite(n)) e.value = "Enter a number";
    else if (VITAL_TYPES.includes(d.type)) {
      const b = VITAL_BOUNDS[d.type];
      if (n < b.min || n > b.max) e.value = `Between ${b.min} and ${b.max}`;
    }
    const msg = d.message.trim();
    if (msg.length < 3) e.message = "Describe the alert (at least 3 characters)";
    else if (msg.length > 200) e.message = "At most 200 characters";
    return e;
  });

  const form: string[] = [];
  if (opts.requireAtLeastOne && drafts.length === 0) form.push("Add at least one threshold.");
  if (drafts.length > MAX_THRESHOLDS) form.push(`At most ${MAX_THRESHOLDS} thresholds.`);

  // The same vital + direction + value twice is ambiguous (which level wins?).
  const seen = new Map<string, number>();
  drafts.forEach((d, i) => {
    const n = Number(d.value.trim());
    if (!d.value.trim() || !Number.isFinite(n)) return;
    const key = `${d.type}|${d.op}|${n}`;
    const first = seen.get(key);
    if (first !== undefined) {
      rows[i]!.value ??= `Duplicate of threshold ${first + 1}`;
      if (!form.includes("Two thresholds have the same vital, direction and value.")) form.push("Two thresholds have the same vital, direction and value.");
    } else seen.set(key, i);
  });

  const ok = form.length === 0 && rows.every((r) => Object.keys(r).length === 0);
  return { ok, rows, form };
}

/** Validated drafts → contract thresholds. Throws if invalid (call `validateThresholds` first). */
export function toThresholds(drafts: readonly ThresholdDraft[]): Threshold[] {
  const v = validateThresholds(drafts);
  if (!v.ok) throw new Error("Invalid thresholds");
  return drafts.map((d) => ({ type: d.type, op: d.op, value: Number(d.value.trim()), level: d.level, message: d.message.trim() }));
}

const VITAL_SHORT: Record<VitalType, string> = {
  bp_systolic: "Systolic BP",
  bp_diastolic: "Diastolic BP",
  pulse: "Pulse",
  spo2: "SpO₂",
  temperature: "Temperature",
  blood_glucose: "Blood glucose",
  weight: "Weight",
  respiratory_rate: "Respiratory rate",
};
export const vitalLabel = (t: VitalType | string) => VITAL_SHORT[t as VitalType] ?? t;

/** e.g. "Systolic BP > 160 → urgent" */
export function describeThreshold(t: Threshold): string {
  return `${vitalLabel(t.type)} ${t.op === "gt" ? ">" : "<"} ${t.value} → ${t.level}`;
}

/** Whether the edited thresholds differ from the template defaults (a coordinator may only use approved defaults). */
export function thresholdsDiffer(a: readonly Threshold[], b: readonly Threshold[]): boolean {
  const key = (t: Threshold) => `${t.type}|${t.op}|${t.value}|${t.level}|${t.message.trim()}`;
  if (a.length !== b.length) return true;
  const sa = a.map(key).sort();
  const sb = b.map(key).sort();
  return sa.some((k, i) => k !== sb[i]);
}

/** `adherencePct*` fields are percentages (0–100). */
export function pct(n: number | null | undefined): string {
  if (n === null || n === undefined || !Number.isFinite(n)) return "—";
  return `${Math.round(n)}%`;
}

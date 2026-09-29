import { ApiError } from "@/lib/api/http";
import type { RxWarning, RxWarningSeverity } from "@/lib/api/types";

export const SEVERITY_RANK: Record<RxWarningSeverity, number> = { major: 3, moderate: 2, info: 1 };
export const MIN_OVERRIDE_REASON = 10;

/** Most severe first; stable within a severity. */
export function sortWarnings(ws: readonly RxWarning[]): RxWarning[] {
  return ws
    .map((w, i) => ({ w, i }))
    .sort((a, b) => (SEVERITY_RANK[b.w.severity] ?? 0) - (SEVERITY_RANK[a.w.severity] ?? 0) || a.i - b.i)
    .map((x) => x.w);
}

export function hasMajor(ws: readonly RxWarning[] | null | undefined): boolean {
  return !!ws?.some((w) => w.severity === "major");
}

export function countBySeverity(ws: readonly RxWarning[]): Record<RxWarningSeverity, number> {
  const c: Record<RxWarningSeverity, number> = { major: 0, moderate: 0, info: 0 };
  for (const w of ws) if (w.severity in c) c[w.severity]++;
  return c;
}

/**
 * §47 gate: with any `major` warning a prescription can only be submitted when the doctor ticks the
 * acknowledgement and gives an override reason. Returns the blocking message, or null when submission may proceed.
 */
export function overrideBlockReason(ws: readonly RxWarning[] | null | undefined, acknowledged: boolean, reason: string): string | null {
  if (!hasMajor(ws)) return null;
  if (!acknowledged) return "Acknowledge the major warnings before creating the prescription.";
  if (reason.trim().length < MIN_OVERRIDE_REASON)
    return `Give a clinical reason for the override (at least ${MIN_OVERRIDE_REASON} characters).`;
  return null;
}

/** The body fields added to POST /clinician/prescriptions when overriding (only when a major warning exists). */
export function overrideFields(
  ws: readonly RxWarning[] | null | undefined,
  acknowledged: boolean,
  reason: string,
): { acknowledgedWarnings: true; overrideReason: string } | Record<string, never> {
  if (!hasMajor(ws) || !acknowledged) return {};
  return { acknowledgedWarnings: true, overrideReason: reason.trim() };
}

function isWarning(x: unknown): x is RxWarning {
  return (
    typeof x === "object" &&
    x !== null &&
    typeof (x as RxWarning).message === "string" &&
    typeof (x as RxWarning).severity === "string"
  );
}

/** A 400 from POST /clinician/prescriptions carrying `details.warnings` (major warnings not acknowledged). */
export function warningsFromError(err: unknown): RxWarning[] | null {
  if (!(err instanceof ApiError) || err.status !== 400) return null;
  const w = err.details?.warnings;
  if (!Array.isArray(w)) return null;
  const list = w.filter(isWarning).map((x) => ({ ...x, drugs: Array.isArray(x.drugs) ? x.drugs : [] }));
  return list.length ? list : null;
}

/** Items sent to the live check: named drugs only (≥ 2 characters), trimmed, de-duplicated. */
export function rxCheckItems(items: readonly { drugName?: string; strength?: string }[] | undefined): { drugName: string; strength?: string }[] {
  const seen = new Set<string>();
  const out: { drugName: string; strength?: string }[] = [];
  for (const i of items ?? []) {
    const drugName = (i?.drugName ?? "").trim();
    if (drugName.length < 2) continue;
    const strength = (i?.strength ?? "").trim();
    const key = `${drugName.toLowerCase()}|${strength.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(strength ? { drugName, strength } : { drugName });
  }
  return out;
}

export function warningKey(w: RxWarning): string {
  return `${w.severity}|${w.type}|${[...w.drugs].sort().join("+")}|${w.message}`;
}

/**
 * Internal governance markers ("[REQUIRES CLINICAL GOVERNANCE]", "[REQUIRES PRICING VALIDATION]",
 * "Placeholder price", "(fixture)") are review notes for the team, not text for patients (QA B9).
 * Governance status lives in data (`status: "fixture_unapproved"`, `scheduleStatus`, `rulePackStatus`,
 * `pricingStatus`, ...); these helpers keep the markers out of user-facing strings.
 */
const MARKER_PATTERNS: RegExp[] = [
  /\s*\[(?:FIXTURE\s*[—-]\s*)?REQUIRES (?:CLINICAL GOVERNANCE|PRICING VALIDATION)[^\]]*\]/gi,
  /\s*\(?placeholder (?:price|pricing)\)?\.?/gi,
  /\s*\(fixture\)/gi,
];

export function hasGovernanceMarker(s: string | null | undefined): boolean {
  return !!s && MARKER_PATTERNS.some((re) => new RegExp(re.source, re.flags.replace('g', '')).test(s));
}

/** Remove governance markers from a user-facing string. */
export function stripGovernanceMarkers(s: string): string;
export function stripGovernanceMarkers(s: string | null): string | null;
export function stripGovernanceMarkers(s: string | null): string | null {
  if (s === null) return null;
  let out = s;
  for (const re of MARKER_PATTERNS) out = out.replace(re, '');
  return out.replace(/\s{2,}/g, ' ').trim();
}

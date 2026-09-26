import type { CaseloadFlag, CaseloadItem, Priority } from "@/lib/api/types";
import type { Tone } from "@/components/ui";

export const FLAG_META: Record<CaseloadFlag, { label: string; tone: Tone; weight: number; description: string }> = {
  open_safety_event: { label: "Open safety event", tone: "red", weight: 100, description: "An urgent or emergency safety event is still open" },
  missed_doses: { label: "Missed doses", tone: "amber", weight: 30, description: "Medication doses were missed recently" },
  overdue_tasks: { label: "Overdue tasks", tone: "amber", weight: 20, description: "Care tasks are past their due time" },
  no_contact_7d: { label: "No contact 7d", tone: "lavender", weight: 10, description: "No coordinator contact in the last 7 days" },
};

/** Flags in severity order (most severe first). */
export function orderedFlags(flags: CaseloadFlag[]): CaseloadFlag[] {
  return [...new Set(flags)]
    .filter((f) => f in FLAG_META)
    .sort((a, b) => FLAG_META[b].weight - FLAG_META[a].weight);
}

const PRIORITY_WEIGHT: Record<Priority, number> = { emergency: 200, urgent: 40, routine: 0 };

/**
 * A simple, explainable risk score for ordering the caseload (not a clinical score):
 * flag weights + the highest episode priority + 2 per overdue task.
 */
export function riskScore(item: CaseloadItem): number {
  const flags = orderedFlags(item.flags).reduce((n, f) => n + FLAG_META[f].weight, 0);
  const prio = item.episodes.reduce((m, e) => Math.max(m, PRIORITY_WEIGHT[e.priority] ?? 0), 0);
  return flags + prio + 2 * (item.overdueTasks ?? 0);
}

export type CaseloadSortKey = "risk" | "name" | "lastContact" | "nextFollowUp";

const time = (v: string | null) => (v ? new Date(v).getTime() : null);

/** Sorts a copy. For dates, missing values sort last in either direction. */
export function sortCaseload(items: CaseloadItem[], key: CaseloadSortKey, dir: "asc" | "desc" = "desc"): CaseloadItem[] {
  const sign = dir === "asc" ? 1 : -1;
  const byName = (a: CaseloadItem, b: CaseloadItem) => a.patient.name.localeCompare(b.patient.name);
  return [...items].sort((a, b) => {
    if (key === "name") return sign * byName(a, b);
    if (key === "risk") return sign * (riskScore(a) - riskScore(b)) || byName(a, b);
    const av = time(key === "lastContact" ? a.lastContactAt : a.nextFollowUpAt);
    const bv = time(key === "lastContact" ? b.lastContactAt : b.nextFollowUpAt);
    if (av === null && bv === null) return byName(a, b);
    if (av === null) return 1;
    if (bv === null) return -1;
    return sign * (av - bv) || byName(a, b);
  });
}

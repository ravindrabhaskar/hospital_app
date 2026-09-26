"use client";

import type { ReactNode } from "react";
import type { SafetyEvent } from "@/lib/api/types";
import { formatDateTime, humanize, relativeTime } from "@/lib/format";
import { GenericStatusBadge, SafetyLevelBadge } from "./status";
import { Badge, cx } from "./ui";

const LEVEL_ORDER = { emergency: 0, urgent: 1 } as const;
const STATUS_ORDER = { open: 0, acknowledged: 1, resolved: 2 } as const;

/** Emergency first, then open before acknowledged/resolved, then oldest first (longest waiting). */
export function sortSafetyEvents(events: SafetyEvent[]): SafetyEvent[] {
  return [...events].sort(
    (a, b) =>
      (STATUS_ORDER[a.status] ?? 3) - (STATUS_ORDER[b.status] ?? 3) ||
      (LEVEL_ORDER[a.level] ?? 2) - (LEVEL_ORDER[b.level] ?? 2) ||
      new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

export function SafetyEventList({
  events,
  renderPatient,
  renderActions,
}: {
  events: SafetyEvent[];
  renderPatient?: (e: SafetyEvent) => ReactNode;
  renderActions?: (e: SafetyEvent) => ReactNode;
}) {
  return (
    <ul className="flex flex-col gap-3">
      {sortSafetyEvents(events).map((e) => (
        <li
          key={e.id}
          className={cx(
            "rounded-2xl border p-4",
            e.status === "resolved"
              ? "border-line bg-white"
              : e.level === "emergency"
                ? "border-danger bg-rose-bg/60"
                : "border-[#f8d9b5] bg-peach-bg/50",
          )}
        >
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <SafetyLevelBadge level={e.level} />
                <GenericStatusBadge status={e.status} tone={e.status === "open" ? "red" : e.status === "acknowledged" ? "amber" : "green"} />
                <Badge tone="neutral">Source: {humanize(e.source)}</Badge>
              </div>
              <p className="mt-2 text-sm">{renderPatient ? renderPatient(e) : <span className="font-semibold">{e.patientName}</span>}</p>
              {e.rules.length > 0 && (
                <ul className="mt-1 flex flex-wrap gap-1.5" aria-label="Triggered rules">
                  {e.rules.map((r) => (
                    <li key={r.ruleId}>
                      <Badge tone="neutral" title={r.ruleId}>
                        {r.title}
                      </Badge>
                    </li>
                  ))}
                </ul>
              )}
              <p className="mt-1 text-xs text-ink-muted">
                Raised {relativeTime(e.createdAt)} ({formatDateTime(e.createdAt)})
                {e.assignedToName ? ` · assigned to ${e.assignedToName}` : ""}
                {e.resolvedAt ? ` · resolved ${formatDateTime(e.resolvedAt)}` : ""}
              </p>
              {e.note && <p className="mt-1 text-[13px]">Note: {e.note}</p>}
            </div>
            {renderActions && <div className="flex flex-wrap gap-2">{renderActions(e)}</div>}
          </div>
        </li>
      ))}
    </ul>
  );
}

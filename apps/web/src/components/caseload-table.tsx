"use client";

import { useMemo, useState, type ReactNode } from "react";
import { ArrowDown, ArrowUp, ArrowUpDown } from "lucide-react";
import type { CaseloadFlag, CaseloadItem } from "@/lib/api/types";
import { FLAG_META, orderedFlags, riskScore, sortCaseload, type CaseloadSortKey } from "@/lib/caseload";
import { formatDateTime, humanize, relativeTime } from "@/lib/format";
import { EpisodeStatusBadge, PriorityBadge } from "./status";
import { Badge, Table, Td, Th, cx } from "./ui";

type Dir = "asc" | "desc";

/** First direction used when a column is picked. */
const DEFAULT_DIR: Record<CaseloadSortKey, Dir> = { risk: "desc", name: "asc", lastContact: "asc", nextFollowUp: "asc" };

export function FlagBadge({ flag }: { flag: CaseloadFlag }) {
  const meta = FLAG_META[flag];
  return (
    <Badge tone={meta.tone} title={meta.description}>
      {meta.label}
      <span className="sr-only">: {meta.description}</span>
    </Badge>
  );
}

export function patientLine(item: CaseloadItem) {
  const bits = [item.patient.age !== null && item.patient.age !== undefined ? `${item.patient.age} y` : null, item.patient.gender ? humanize(item.patient.gender) : null];
  return bits.filter(Boolean).join(" · ");
}

function SortHeader({
  label,
  sortKey,
  sort,
  onSort,
  className,
}: {
  label: string;
  sortKey: CaseloadSortKey;
  sort: { key: CaseloadSortKey; dir: Dir };
  onSort: (k: CaseloadSortKey) => void;
  className?: string;
}) {
  const active = sort.key === sortKey;
  const Icon = !active ? ArrowUpDown : sort.dir === "asc" ? ArrowUp : ArrowDown;
  return (
    <th
      scope="col"
      aria-sort={active ? (sort.dir === "asc" ? "ascending" : "descending") : "none"}
      className={cx("border-b border-line bg-mint-50/60 px-5 py-2.5 text-xs font-semibold uppercase tracking-wide text-ink-muted", className)}
    >
      <button
        type="button"
        onClick={() => onSort(sortKey)}
        className={cx("inline-flex items-center gap-1 rounded uppercase hover:text-ink focus-visible:outline-2 focus-visible:outline-primary-light", active && "text-ink")}
      >
        {label}
        <Icon className="size-3.5" aria-hidden />
      </button>
    </th>
  );
}

/** Coordinator caseload (§35). Sorting is local; the default is risk, highest first. */
export function CaseloadTable({
  items,
  onSelect,
  selectedPatientId,
  empty,
}: {
  items: CaseloadItem[];
  onSelect: (item: CaseloadItem) => void;
  selectedPatientId?: string | null;
  empty?: ReactNode;
}) {
  const [sort, setSort] = useState<{ key: CaseloadSortKey; dir: Dir }>({ key: "risk", dir: "desc" });
  const rows = useMemo(() => sortCaseload(items, sort.key, sort.dir), [items, sort]);

  const onSort = (key: CaseloadSortKey) =>
    setSort((s) => (s.key === key ? { key, dir: s.dir === "asc" ? "desc" : "asc" } : { key, dir: DEFAULT_DIR[key] }));

  return (
    <Table caption="Caseload: patients with active episodes assigned to you" className="[&_table]:min-w-[960px]">
      <thead>
        <tr>
          <SortHeader label="Patient" sortKey="name" sort={sort} onSort={onSort} />
          <Th>Active episodes</Th>
          <Th>Tasks</Th>
          <SortHeader label="Next follow-up" sortKey="nextFollowUp" sort={sort} onSort={onSort} />
          <SortHeader label="Last contact" sortKey="lastContact" sort={sort} onSort={onSort} />
          <Th>Flags</Th>
          <SortHeader label="Risk" sortKey="risk" sort={sort} onSort={onSort} className="text-right" />
        </tr>
      </thead>
      <tbody>
        {rows.length === 0 ? (
          <tr>
            <Td colSpan={7}>{empty ?? <p className="py-6 text-center text-sm text-ink-muted">No patients match.</p>}</Td>
          </tr>
        ) : (
          rows.map((item) => {
            const flags = orderedFlags(item.flags);
            const selected = selectedPatientId === item.patient.id;
            return (
              <tr
                key={item.patient.id}
                data-testid="caseload-row"
                onClick={() => onSelect(item)}
                className={cx("cursor-pointer", selected ? "bg-mint-50" : "hover:bg-mint-50/60")}
              >
                <Td>
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      onSelect(item);
                    }}
                    className="text-left font-semibold text-ink hover:text-primary hover:underline focus-visible:outline-2 focus-visible:outline-primary-light"
                  >
                    {item.patient.name}
                  </button>
                  <span className="block text-xs text-ink-muted">{patientLine(item) || "—"}</span>
                </Td>
                <Td>
                  {item.episodes.length === 0 ? (
                    <span className="text-ink-muted">—</span>
                  ) : (
                    <ul className="flex flex-col gap-1.5">
                      {item.episodes.map((e) => (
                        <li key={e.id} className="flex flex-col gap-1">
                          <span className="text-[13px] font-medium">{e.title}</span>
                          <span className="flex flex-wrap gap-1">
                            <EpisodeStatusBadge status={e.status} />
                            {e.priority !== "routine" && <PriorityBadge priority={e.priority} />}
                          </span>
                        </li>
                      ))}
                    </ul>
                  )}
                </Td>
                <Td className="whitespace-nowrap tabular-nums">
                  <span className="block">{item.openTasks} open</span>
                  <span className={cx("block text-xs", item.overdueTasks > 0 ? "font-semibold text-danger-dark" : "text-ink-muted")}>
                    {item.overdueTasks} overdue
                  </span>
                </Td>
                <Td className="whitespace-nowrap text-[13px]">{item.nextFollowUpAt ? formatDateTime(item.nextFollowUpAt) : <span className="text-ink-muted">—</span>}</Td>
                <Td className="whitespace-nowrap text-[13px]">
                  {item.lastContactAt ? (
                    <time dateTime={item.lastContactAt} title={formatDateTime(item.lastContactAt)}>
                      {relativeTime(item.lastContactAt)}
                    </time>
                  ) : (
                    <span className="text-ink-muted">Never</span>
                  )}
                </Td>
                <Td>
                  {flags.length === 0 ? (
                    <span className="text-xs text-ink-muted">None</span>
                  ) : (
                    <span className="flex flex-wrap gap-1">
                      {flags.map((f) => (
                        <FlagBadge key={f} flag={f} />
                      ))}
                    </span>
                  )}
                </Td>
                <Td className="text-right font-semibold tabular-nums">{riskScore(item)}</Td>
              </tr>
            );
          })
        )}
      </tbody>
    </Table>
  );
}

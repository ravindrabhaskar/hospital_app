"use client";

import { useMemo } from "react";
import type { VitalMeasurement, VitalType } from "@/lib/api/types";
import { CHART } from "@/lib/chart-theme";
import { formatDateTime } from "@/lib/format";
import { sourceDomId } from "./ai-summary";
import { ProvenanceBadge } from "./status";
import { EmptyState, Table, Td, Th } from "./ui";

export const VITAL_LABEL: Record<VitalType, string> = {
  bp_systolic: "BP systolic",
  bp_diastolic: "BP diastolic",
  pulse: "Pulse",
  spo2: "SpO₂",
  temperature: "Temperature",
  blood_glucose: "Blood glucose",
  weight: "Weight",
  respiratory_rate: "Respiratory rate",
};

/** Single-series sparkline (2px line, end dot with surface ring). Values are also listed in the table below. */
export function Sparkline({ points, label }: { points: { value: number; at: string }[]; label: string }) {
  const W = 120;
  const H = 36;
  const P = 5;
  if (points.length === 0) return null;
  const values = points.map((p) => p.value);
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const x = (i: number) => (points.length === 1 ? W - P : P + (i * (W - 2 * P)) / (points.length - 1));
  const y = (v: number) => H - P - ((v - min) / span) * (H - 2 * P);
  const d = points.map((p, i) => `${i === 0 ? "M" : "L"}${x(i).toFixed(1)},${y(p.value).toFixed(1)}`).join(" ");
  const last = points[points.length - 1]!;
  return (
    <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} role="img" aria-label={`${label} trend, ${points.length} readings, min ${min}, max ${max}`}>
      <path d={d} fill="none" stroke={CHART.series} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
      {points.map((p, i) => (
        <circle key={i} cx={x(i)} cy={y(p.value)} r={7} fill="transparent">
          <title>{`${p.value} · ${formatDateTime(p.at)}`}</title>
        </circle>
      ))}
      <circle cx={x(points.length - 1)} cy={y(last.value)} r={4} fill={CHART.series} stroke={CHART.surface} strokeWidth={2} />
    </svg>
  );
}

export function VitalsPanel({ vitals }: { vitals: VitalMeasurement[] }) {
  const byType = useMemo(() => {
    const m = new Map<VitalType, VitalMeasurement[]>();
    for (const v of vitals) {
      const arr = m.get(v.type) ?? [];
      arr.push(v);
      m.set(v.type, arr);
    }
    for (const arr of m.values()) arr.sort((a, b) => new Date(a.measuredAt).getTime() - new Date(b.measuredAt).getTime());
    return [...m.entries()];
  }, [vitals]);

  if (vitals.length === 0) return <EmptyState title="No vitals recorded" />;
  const rows = [...vitals].sort((a, b) => new Date(b.measuredAt).getTime() - new Date(a.measuredAt).getTime());

  return (
    <div className="flex flex-col gap-4">
      <ul className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3" aria-label="Latest vitals">
        {byType.map(([type, arr]) => {
          const latest = arr[arr.length - 1]!;
          return (
            <li key={type} className="flex items-center justify-between gap-2 rounded-2xl border border-line p-3">
              <div>
                <p className="text-xs text-ink-muted">{VITAL_LABEL[type] ?? type}</p>
                <p className="text-lg font-semibold tabular-nums">
                  {latest.value} <span className="text-xs font-normal text-ink-muted">{latest.unit}</span>
                </p>
                <p className="text-[11px] text-ink-muted">{formatDateTime(latest.measuredAt)}</p>
              </div>
              <Sparkline label={VITAL_LABEL[type] ?? type} points={arr.map((v) => ({ value: v.value, at: v.measuredAt }))} />
            </li>
          );
        })}
      </ul>
      <Table caption="Vital measurements, newest first" className="max-h-[360px] overflow-y-auto">
        <thead>
          <tr>
            <Th>Measured</Th>
            <Th>Vital</Th>
            <Th className="text-right">Value</Th>
            <Th>Source</Th>
            <Th>Recorded by</Th>
          </tr>
        </thead>
        <tbody>
          {rows.map((v) => (
            <tr key={v.id} id={sourceDomId(v.id)}>
              <Td className="whitespace-nowrap">{formatDateTime(v.measuredAt)}</Td>
              <Td>{VITAL_LABEL[v.type] ?? v.type}</Td>
              <Td className="text-right tabular-nums">
                {v.value} {v.unit}
              </Td>
              <Td>
                <ProvenanceBadge source={v.source} />
              </Td>
              <Td>{v.recordedByName ?? "—"}</Td>
            </tr>
          ))}
        </tbody>
      </Table>
    </div>
  );
}

"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Bar, BarChart, CartesianGrid, LabelList, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { BarChart3, Table2 } from "lucide-react";
import { api } from "@/lib/api";
import type { Analytics } from "@/lib/api/types";
import { CHART } from "@/lib/chart-theme";
import { formatINR, formatNumber, formatPercent } from "@/lib/format";
import { Button, Card, PageHeader, QueryView, StatTile, Table, Td, Th, cx } from "@/components/ui";

/* Chart tokens follow the theme palette (globals.css). Single series → one hue. */
const SERIES = CHART.series;
const GRID = CHART.grid;
const INK_MUTED = CHART.inkMuted;
const INK = CHART.ink;

const FUNNEL_STEPS: { key: keyof Analytics["funnel"]; label: string }[] = [
  { key: "conversationsStarted", label: "AI conversations started" },
  { key: "intakesCompleted", label: "Intakes completed" },
  { key: "routedToCare", label: "Routed to care" },
  { key: "appointmentsBooked", label: "Appointments booked" },
  { key: "appointmentsCompleted", label: "Appointments completed" },
  { key: "homeVisitsRequested", label: "Home visits requested" },
  { key: "homeVisitsCompleted", label: "Home visits completed" },
  { key: "carePlansCreated", label: "Care plans created" },
  { key: "episodesResolved", label: "Episodes resolved" },
];

export default function AnalyticsPage() {
  const query = useQuery({ queryKey: ["admin", "analytics"], queryFn: () => api.admin.analytics() });
  return (
    <>
      <PageHeader title="Analytics" description="Care-journey funnel, continuity, safety and finance. All-time totals from the API." />
      <QueryView query={query} loadingRows={5}>
        {(a) => (
          <div className="flex flex-col gap-5">
            <FunnelCard funnel={a.funnel} />
            <div className="grid gap-5 lg:grid-cols-2">
              <Card title="Continuity of care">
                <div className="flex flex-col gap-4">
                  <Meter label="Care-task completion" rate={a.continuity.taskCompletionRate} />
                  <Meter label="Follow-up completion" rate={a.continuity.followUpCompletionRate} />
                  <Meter label="Medication adherence" rate={a.continuity.medicationAdherenceRate} />
                </div>
              </Card>
              <Card title="Safety">
                <ul className="grid grid-cols-2 gap-3">
                  <li>
                    <StatTile label="Safety events" value={formatNumber(a.safety.safetyEventsTotal)} />
                  </li>
                  <li>
                    <StatTile label="Emergency events" value={formatNumber(a.safety.emergencyEvents)} tone={a.safety.emergencyEvents > 0 ? "alert" : "neutral"} />
                  </li>
                  <li>
                    <StatTile label="Median acknowledgement" value={a.safety.medianAckMins === null ? "—" : `${a.safety.medianAckMins} min`} />
                  </li>
                  <li>
                    <StatTile label="AI fallback rate" value={formatPercent(a.safety.aiFallbackRate)} />
                  </li>
                </ul>
              </Card>
            </div>
            <div className="grid gap-5 lg:grid-cols-2">
              <Card title="Finance">
                <ul className="grid grid-cols-3 gap-3">
                  <li>
                    <StatTile label="Gross revenue" value={formatINR(a.finance.grossRevenue)} />
                  </li>
                  <li>
                    <StatTile label="Refunds" value={formatINR(a.finance.refunds)} />
                  </li>
                  <li>
                    <StatTile label="Paid episodes" value={formatNumber(a.finance.paidEpisodes)} />
                  </li>
                </ul>
              </Card>
              <Card title="Activation">
                <ul className="grid grid-cols-3 gap-3">
                  <li>
                    <StatTile label="Users" value={formatNumber(a.activation.usersTotal)} />
                  </li>
                  <li>
                    <StatTile label="Onboarded" value={formatNumber(a.activation.onboardingCompleted)} />
                  </li>
                  <li>
                    <StatTile label="Family grants" value={formatNumber(a.activation.familyGrants)} />
                  </li>
                </ul>
              </Card>
            </div>
          </div>
        )}
      </QueryView>
    </>
  );
}

function FunnelCard({ funnel }: { funnel: Analytics["funnel"] }) {
  const [view, setView] = useState<"chart" | "table">("chart");
  const data = FUNNEL_STEPS.map((s) => ({ label: s.label, value: funnel[s.key] ?? 0 }));
  const top = data[0]?.value ?? 0;

  return (
    <Card
      title="Care-journey funnel"
      subtitle="Count of patients/episodes reaching each step"
      actions={
        <div role="group" aria-label="Funnel view" className="flex gap-1">
          <Button size="sm" variant={view === "chart" ? "subtle" : "ghost"} aria-pressed={view === "chart"} onClick={() => setView("chart")} icon={<BarChart3 className="size-4" aria-hidden />}>
            Chart
          </Button>
          <Button size="sm" variant={view === "table" ? "subtle" : "ghost"} aria-pressed={view === "table"} onClick={() => setView("table")} icon={<Table2 className="size-4" aria-hidden />}>
            Table
          </Button>
        </div>
      }
    >
      {view === "chart" ? (
        <div className="h-[380px] w-full" role="img" aria-label={`Funnel bar chart. ${data.map((d) => `${d.label}: ${d.value}`).join("; ")}`}>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data} layout="vertical" margin={{ top: 4, right: 56, bottom: 4, left: 8 }} barCategoryGap={8}>
              <CartesianGrid horizontal={false} stroke={GRID} strokeWidth={1} />
              <XAxis
                type="number"
                allowDecimals={false}
                tickFormatter={(v: number) => formatNumber(v)}
                tick={{ fill: INK_MUTED, fontSize: 12 }}
                axisLine={{ stroke: GRID }}
                tickLine={false}
              />
              <YAxis type="category" dataKey="label" width={180} tick={{ fill: INK, fontSize: 12 }} axisLine={{ stroke: GRID }} tickLine={false} />
              <Tooltip cursor={{ fill: "rgba(31,138,103,0.06)" }} content={<FunnelTooltip top={top} />} />
              <Bar dataKey="value" fill={SERIES} maxBarSize={24} radius={[0, 4, 4, 0]} isAnimationActive={false}>
                <LabelList dataKey="value" position="right" formatter={(v) => formatNumber(Number(v))} fill={INK} fontSize={12} />
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      ) : (
        <FunnelTable data={data} top={top} />
      )}
    </Card>
  );
}

interface TooltipProps {
  active?: boolean;
  payload?: { payload: { label: string; value: number } }[];
  top: number;
}
function FunnelTooltip({ active, payload, top }: TooltipProps) {
  const p = payload?.[0]?.payload;
  if (!active || !p) return null;
  return (
    <div className="rounded-xl border border-line bg-white px-3 py-2 text-xs shadow-lg">
      <p className="font-semibold text-ink">{p.label}</p>
      <p className="tabular-nums text-ink">{formatNumber(p.value)}</p>
      {top > 0 && <p className="text-ink-muted">{Math.round((p.value / top) * 100)}% of conversations started</p>}
    </div>
  );
}

function FunnelTable({ data, top }: { data: { label: string; value: number }[]; top: number }) {
  return (
    <Table caption="Care-journey funnel">
      <thead>
        <tr>
          <Th>Step</Th>
          <Th className="text-right">Count</Th>
          <Th className="text-right">% of first step</Th>
        </tr>
      </thead>
      <tbody>
        {data.map((d) => (
          <tr key={d.label}>
            <Td>{d.label}</Td>
            <Td className="text-right tabular-nums">{formatNumber(d.value)}</Td>
            <Td className="text-right tabular-nums">{top > 0 ? `${Math.round((d.value / top) * 100)}%` : "—"}</Td>
          </tr>
        ))}
      </tbody>
    </Table>
  );
}

/** Meter: fill in the series hue on a lighter step of the same ramp. Null → no data. */
function Meter({ label, rate }: { label: string; rate: number | null }) {
  const pct = rate === null ? null : Math.max(0, Math.min(100, rate <= 1 ? rate * 100 : rate));
  return (
    <div>
      <div className="mb-1 flex items-baseline justify-between">
        <span className="text-sm text-ink">{label}</span>
        <span className="text-lg font-semibold tabular-nums">{formatPercent(rate)}</span>
      </div>
      <div
        role="meter"
        aria-label={label}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={pct === null ? undefined : Math.round(pct)}
        aria-valuetext={pct === null ? "No data" : `${Math.round(pct)}%`}
        className="h-2.5 w-full overflow-hidden rounded-full bg-mint-100"
      >
        <div className={cx("h-full rounded-full", pct === null && "hidden")} style={{ width: `${pct ?? 0}%`, background: SERIES }} />
      </div>
      {pct === null && <p className="mt-1 text-xs text-ink-muted">No data yet</p>}
    </div>
  );
}

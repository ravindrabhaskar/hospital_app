"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  Activity,
  AlertTriangle,
  CalendarClock,
  Clock,
  Home,
  Pause,
  Play,
  RefreshCw,
  Siren,
  Timer,
  UserCheck,
  Wallet,
} from "lucide-react";
import { api } from "@/lib/api";
import type { OpsOverview } from "@/lib/api/types";
import { formatNumber, formatPercent, formatTime } from "@/lib/format";
import { EventList } from "@/components/episode-timeline";
import { Button, Card, ErrorState, LoadingState, PageHeader, StatTile } from "@/components/ui";

const REFRESH_MS = 15_000;

export default function ControlTowerPage() {
  const [live, setLive] = useState(true);
  const query = useQuery({
    queryKey: ["ops", "overview"],
    queryFn: () => api.ops.overview(),
    refetchInterval: live ? REFRESH_MS : false,
    refetchIntervalInBackground: false,
  });

  return (
    <>
      <PageHeader
        title="Operations control tower"
        description={
          <span aria-live="polite">
            {live ? "Auto-refreshing every 15 seconds." : "Auto-refresh paused."}
            {query.dataUpdatedAt ? ` Last updated ${formatTime(new Date(query.dataUpdatedAt))} IST.` : ""}
          </span>
        }
        actions={
          <>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setLive((l) => !l)}
              aria-pressed={!live}
              icon={live ? <Pause className="size-4" aria-hidden /> : <Play className="size-4" aria-hidden />}
            >
              {live ? "Pause" : "Resume"}
            </Button>
            <Button
              variant="subtle"
              size="sm"
              onClick={() => query.refetch()}
              loading={query.isFetching}
              icon={<RefreshCw className="size-4" aria-hidden />}
            >
              Refresh
            </Button>
          </>
        }
      />
      {query.isPending ? (
        <LoadingState rows={4} />
      ) : query.isError && !query.data ? (
        <ErrorState error={query.error} onRetry={() => query.refetch()} />
      ) : (
        <Overview data={query.data!} stale={query.isError} />
      )}
    </>
  );
}

function Overview({ data, stale }: { data: OpsOverview; stale: boolean }) {
  const c = data.counts;
  return (
    <div className="flex flex-col gap-5">
      {stale && (
        <p role="alert" className="rounded-xl bg-peach-bg px-3 py-2 text-sm text-peach-fg">
          Could not refresh. Showing the last known data.
        </p>
      )}
      <section aria-label="Action queues">
        <ul className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">
          <li>
            <StatTile label="Open safety events" value={formatNumber(c.openSafetyEvents)} tone={c.openSafetyEvents > 0 ? "alert" : "neutral"} icon={<Siren className="size-4" />} href="/ops/safety-events" />
          </li>
          <li>
            <StatTile label="Unassigned visits" value={formatNumber(c.unassignedVisits)} tone={c.unassignedVisits > 0 ? "alert" : "neutral"} icon={<Home className="size-4" />} href="/ops/home-visits" />
          </li>
          <li>
            <StatTile label="Late visits" value={formatNumber(c.lateVisits)} tone={c.lateVisits > 0 ? "warn" : "neutral"} icon={<Clock className="size-4" />} href="/ops/home-visits" />
          </li>
          <li>
            <StatTile label="Overdue tasks" value={formatNumber(c.overdueTasks)} tone={c.overdueTasks > 0 ? "warn" : "neutral"} icon={<Timer className="size-4" />} href="/ops/tasks" />
          </li>
          <li>
            <StatTile label="Open incidents" value={formatNumber(c.openIncidents)} tone={c.openIncidents > 0 ? "warn" : "neutral"} icon={<AlertTriangle className="size-4" />} href="/ops/incidents" />
          </li>
          <li>
            <StatTile label="Active episodes" value={formatNumber(c.activeEpisodes)} icon={<Activity className="size-4" />} href="/ops/episodes" />
          </li>
          <li>
            <StatTile label="Active visits" value={formatNumber(c.activeVisits)} icon={<Home className="size-4" />} href="/ops/home-visits" />
          </li>
          <li>
            <StatTile label="Today's appointments" value={formatNumber(c.todaysAppointments)} icon={<CalendarClock className="size-4" />} />
          </li>
          <li>
            <StatTile label="Pending payments" value={formatNumber(c.pendingPayments)} icon={<Wallet className="size-4" />} href="/ops/payments" />
          </li>
          <li>
            <StatTile label="Providers on duty" value={formatNumber(c.providersOnDuty)} icon={<UserCheck className="size-4" />} href="/ops/providers" />
          </li>
        </ul>
      </section>

      <div className="grid gap-5 lg:grid-cols-[360px_minmax(0,1fr)]">
        <Card title="SLA metrics">
          <dl className="flex flex-col gap-4">
            <Metric label="Visit assignment (median)" value={data.sla.visitAssignmentMedianMins === null ? "—" : `${data.sla.visitAssignmentMedianMins} min`} hint="Target ≤ 30 min" />
            <Metric label="Visits on time" value={formatPercent(data.sla.visitOnTimeRate)} hint="Arrived by preferred end" />
            <Metric label="Safety acknowledgement (median)" value={data.sla.safetyAckMedianMins === null ? "—" : `${data.sla.safetyAckMedianMins} min`} />
          </dl>
        </Card>
        <Card title="Recent events">
          {data.recentEvents.length === 0 ? <p className="text-sm text-ink-muted">No recent events.</p> : <EventList events={data.recentEvents} />}
        </Card>
      </div>
    </div>
  );
}

function Metric({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-b border-line pb-3 last:border-0">
      <dt className="text-sm text-ink-muted">
        {label}
        {hint && <span className="block text-xs">{hint}</span>}
      </dt>
      <dd className="text-xl font-semibold tabular-nums">{value}</dd>
    </div>
  );
}

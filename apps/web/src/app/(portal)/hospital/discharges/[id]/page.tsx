"use client";

import Link from "next/link";
import { use } from "react";
import { useQuery } from "@tanstack/react-query";
import { AlertTriangle, ArrowLeft, CalendarX, ListChecks, Send } from "lucide-react";
import { api } from "@/lib/api";
import { formatDate, formatDateTime, humanize } from "@/lib/format";
import { DISCHARGE_TONE, DayProgress } from "@/components/discharge-ui";
import { Badge, Card, ErrorState, LoadingState, StatTile } from "@/components/ui";

export default function DischargeDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const q = useQuery({ queryKey: ["discharge", id], queryFn: () => api.discharges.get(id), refetchInterval: 60_000 });
  return (
    <>
      <Link href="/hospital" className="mb-3 inline-flex items-center gap-1 text-sm font-medium text-primary-light hover:underline">
        <ArrowLeft className="size-4" aria-hidden /> Discharges
      </Link>
      {q.isPending ? (
        <LoadingState rows={4} />
      ) : q.isError ? (
        <ErrorState error={q.error} onRetry={() => void q.refetch()} />
      ) : (
        <div className="flex flex-col gap-5">
          <header className="rounded-[20px] border border-line bg-gradient-to-r from-mint-50 to-white p-5 shadow-[var(--shadow-card)]">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h1 className="text-[22px] font-bold">{q.data.patientName}</h1>
                <p className="text-sm text-ink-muted">
                  Discharged {formatDate(q.data.dischargeDate)} from {q.data.facility.name} · {q.data.treatingDoctorName}
                </p>
              </div>
              <Badge tone={DISCHARGE_TONE[q.data.status] ?? "neutral"}>{humanize(q.data.status)}</Badge>
            </div>
            <div className="mt-4 max-w-sm">
              <DayProgress day={q.data.day} />
            </div>
          </header>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
            <StatTile label="Tasks done" value={`${q.data.tasksDone}/${q.data.tasksTotal}`} icon={<ListChecks className="size-4" />} />
            <StatTile label="Missed check-ins" value={q.data.missedCheckins} icon={<CalendarX className="size-4" />} tone={q.data.missedCheckins > 0 ? "warn" : "neutral"} />
            <StatTile label="Open alerts" value={q.data.openAlerts} icon={<AlertTriangle className="size-4" />} tone={q.data.openAlerts > 0 ? "alert" : "neutral"} />
          </div>
          <div className="grid gap-5 md:grid-cols-2">
            <Card title="Diagnosis summary">
              <p className="whitespace-pre-line text-sm">{q.data.diagnosisSummary}</p>
            </Card>
            <Card title="Program">
              <dl className="flex flex-col gap-2 text-sm">
                <div>
                  <dt className="text-xs text-ink-muted">Remote monitoring</dt>
                  <dd>{q.data.enrollmentId ? "Enrolled in a care program" : "No care program"}</dd>
                </div>
                <div>
                  <dt className="text-xs text-ink-muted">Invites sent</dt>
                  <dd className="flex flex-wrap gap-1.5">
                    {q.data.invitedPhones.length === 0
                      ? "—"
                      : q.data.invitedPhones.map((p) => (
                          <Badge key={p} icon={<Send className="size-3" aria-hidden />}>
                            {p}
                          </Badge>
                        ))}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-ink-muted">Registered</dt>
                  <dd>{formatDateTime(q.data.createdAt)}</dd>
                </div>
              </dl>
              <p className="mt-3 text-xs text-ink-muted">The care coordinator follows up on missed check-ins and alerts. Clinical details stay with the care team.</p>
            </Card>
          </div>
        </div>
      )}
    </>
  );
}

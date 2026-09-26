"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { CalendarDays, ChevronLeft, ChevronRight, Stethoscope, Video } from "lucide-react";
import { api } from "@/lib/api";
import type { AppointmentStatus, Priority, QueueItem } from "@/lib/api/types";
import { addDays, formatDate, formatTime, humanize, todayIST } from "@/lib/format";
import { Button, Card, ChipGroup, EmptyState, Input, PageHeader, QueryView, Table, Td, Th } from "@/components/ui";
import { AppointmentStatusBadge, EpisodeStatusBadge, PriorityBadge } from "@/components/status";

const PRIORITY_ORDER: Record<Priority, number> = { emergency: 0, urgent: 1, routine: 2 };
type StatusFilter = "all" | AppointmentStatus;

export default function ClinicianQueuePage() {
  const [date, setDate] = useState(() => todayIST());
  const [status, setStatus] = useState<StatusFilter>("all");
  const query = useQuery({ queryKey: ["clinician", "queue", date], queryFn: () => api.clinician.queue(date) });

  const items = useMemo(() => query.data?.items ?? [], [query.data]);
  const counts = useMemo(() => {
    const c: Partial<Record<AppointmentStatus, number>> = {};
    for (const i of items) c[i.status] = (c[i.status] ?? 0) + 1;
    return c;
  }, [items]);

  const filtered = useMemo(
    () =>
      items
        .filter((i) => status === "all" || i.status === status)
        .sort(
          (a, b) =>
            (PRIORITY_ORDER[a.priority] ?? 3) - (PRIORITY_ORDER[b.priority] ?? 3) ||
            new Date(a.startAt).getTime() - new Date(b.startAt).getTime(),
        ),
    [items, status],
  );

  const statusOptions: { value: StatusFilter; label: string; count?: number }[] = [
    { value: "all", label: "All", count: items.length },
    ...(["confirmed", "in_progress", "completed", "pending_payment", "cancelled", "no_show"] as AppointmentStatus[]).map((s) => ({
      value: s,
      label: humanize(s),
      count: counts[s] ?? 0,
    })),
  ];

  return (
    <>
      <PageHeader
        title="Today's queue"
        description={`Consultations for ${formatDate(date)} (IST). Urgent and emergency patients are listed first.`}
      />
      <Card
        title="Queue"
        actions={
          <div className="flex items-center gap-1.5">
            <Button variant="ghost" size="sm" aria-label="Previous day" onClick={() => setDate((d) => addDays(d, -1))}>
              <ChevronLeft className="size-4" aria-hidden />
            </Button>
            <label className="sr-only" htmlFor="queue-date">
              Queue date
            </label>
            <Input id="queue-date" type="date" value={date} onChange={(e) => e.target.value && setDate(e.target.value)} className="w-40" />
            <Button variant="ghost" size="sm" aria-label="Next day" onClick={() => setDate((d) => addDays(d, 1))}>
              <ChevronRight className="size-4" aria-hidden />
            </Button>
            <Button variant="subtle" size="sm" onClick={() => setDate(todayIST())} icon={<CalendarDays className="size-4" aria-hidden />}>
              Today
            </Button>
          </div>
        }
      >
        <div className="mb-4">
          <ChipGroup label="Filter by status" options={statusOptions} value={status} onChange={setStatus} />
        </div>
        <QueryView
          query={query}
          isEmpty={() => filtered.length === 0}
          empty={<EmptyState title="No consultations" description="There are no appointments matching this date and filter." />}
        >
          {() => <QueueTable items={filtered} />}
        </QueryView>
      </Card>
    </>
  );
}

function QueueTable({ items }: { items: QueueItem[] }) {
  return (
    <Table caption="Consultation queue">
      <thead>
        <tr>
          <Th>Time</Th>
          <Th>Patient</Th>
          <Th>Reason</Th>
          <Th>Priority</Th>
          <Th>Episode</Th>
          <Th>Status</Th>
          <Th className="text-right">Actions</Th>
        </tr>
      </thead>
      <tbody>
        {items.map((a) => (
          <tr key={a.id} className={a.priority === "emergency" ? "bg-rose-bg/50" : a.priority === "urgent" ? "bg-peach-bg/40" : undefined}>
            <Td className="whitespace-nowrap font-medium tabular-nums">
              {formatTime(a.startAt)}
              <div className="flex items-center gap-1 text-xs font-normal text-ink-muted">
                {a.mode === "video" && <Video className="size-3" aria-hidden />}
                {humanize(a.mode)}
              </div>
            </Td>
            <Td>
              <Link href={`/clinician/patients/${a.patientId}`} className="font-semibold text-primary hover:underline">
                {a.patientName}
              </Link>
              <div className="text-xs text-ink-muted">
                {a.patientAge ?? "—"} yrs · {humanize(String(a.patientGender))}
              </div>
            </Td>
            <Td className="max-w-[280px]">{a.reason}</Td>
            <Td>
              <PriorityBadge priority={a.priority} />
            </Td>
            <Td>
              <EpisodeStatusBadge status={a.episodeStatus} />
            </Td>
            <Td>
              <AppointmentStatusBadge status={a.status} />
            </Td>
            <Td className="text-right">
              <Link
                href={`/clinician/appointments/${a.id}`}
                className="inline-flex h-9 items-center gap-1.5 rounded-full bg-primary px-3.5 text-[13px] font-semibold text-white hover:bg-primary-dark"
              >
                <Stethoscope className="size-4" aria-hidden />
                {a.status === "completed" ? "View" : "Open consult"}
              </Link>
            </Td>
          </tr>
        ))}
      </tbody>
    </Table>
  );
}

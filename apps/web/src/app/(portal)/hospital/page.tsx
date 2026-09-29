"use client";

import Link from "next/link";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { AlertTriangle, CalendarX, FilePlus2, Hospital } from "lucide-react";
import { api } from "@/lib/api";
import type { Discharge, DischargeStatus } from "@/lib/api/types";
import { formatDate, humanize } from "@/lib/format";
import { DISCHARGE_TONE, DayProgress } from "@/components/discharge-ui";
import { Badge, Card, ChipGroup, EmptyState, PageHeader, QueryView, StatTile, Table, Td, Th } from "@/components/ui";

type Filter = "all" | DischargeStatus;

export default function HospitalPage() {
  const [filter, setFilter] = useState<Filter>("active");
  const query = useQuery({
    queryKey: ["discharges", filter],
    queryFn: () => api.discharges.list({ status: filter === "all" ? undefined : filter, limit: 100 }),
    refetchInterval: 60_000,
  });
  const items = query.data?.items ?? [];
  return (
    <>
      <PageHeader
        title="Post-discharge programs"
        description="Your facility's discharged patients through their 30-day follow-up."
        actions={
          <Link href="/hospital/new" className="inline-flex h-11 items-center gap-2 rounded-[28px] bg-primary px-5 text-sm font-semibold text-white hover:bg-primary-dark">
            <FilePlus2 className="size-4" aria-hidden /> New discharge
          </Link>
        }
      />
      {query.data && (
        <div className="mb-5 grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatTile label="In this view" value={items.length} icon={<Hospital className="size-4" />} />
          <StatTile label="With missed check-ins" value={items.filter((d) => d.missedCheckins > 0).length} icon={<CalendarX className="size-4" />} tone="warn" />
          <StatTile label="With open alerts" value={items.filter((d) => d.openAlerts > 0).length} icon={<AlertTriangle className="size-4" />} tone="alert" />
        </div>
      )}
      <Card>
        <div className="mb-4">
          <ChipGroup<Filter>
            label="Status"
            value={filter}
            onChange={setFilter}
            options={[
              { value: "active", label: "Active" },
              { value: "completed", label: "Completed" },
              { value: "readmitted", label: "Readmitted" },
              { value: "withdrawn", label: "Withdrawn" },
              { value: "all", label: "All" },
            ]}
          />
        </div>
        <QueryView
          query={query}
          isEmpty={(d) => d.items.length === 0}
          empty={<EmptyState icon={<Hospital className="size-6" />} title="No discharges" description="Register a discharge to start a 30-day follow-up program." />}
        >
          {(d) => <DischargeTable items={d.items} />}
        </QueryView>
      </Card>
    </>
  );
}

function DischargeTable({ items }: { items: Discharge[] }) {
  return (
    <Table caption="Discharged patients">
      <thead>
        <tr>
          <Th>Patient</Th>
          <Th>Discharged</Th>
          <Th>Progress</Th>
          <Th>Tasks</Th>
          <Th>Missed check-ins</Th>
          <Th>Open alerts</Th>
          <Th>Status</Th>
        </tr>
      </thead>
      <tbody>
        {items.map((d) => (
          <tr key={d.id} className="hover:bg-mint-50/60">
            <Td>
              <Link href={`/hospital/discharges/${d.id}`} className="font-semibold text-ink hover:text-primary hover:underline">
                {d.patientName}
              </Link>
              <span className="block max-w-[260px] truncate text-xs text-ink-muted">{d.diagnosisSummary}</span>
            </Td>
            <Td className="whitespace-nowrap text-[13px]">
              {formatDate(d.dischargeDate)}
              <span className="block text-xs text-ink-muted">{d.treatingDoctorName}</span>
            </Td>
            <Td className="min-w-[140px]">
              <DayProgress day={d.day} />
            </Td>
            <Td className="tabular-nums">
              {d.tasksDone}/{d.tasksTotal}
            </Td>
            <Td>{d.missedCheckins > 0 ? <Badge tone="amber">{d.missedCheckins}</Badge> : <span className="text-ink-muted">0</span>}</Td>
            <Td>{d.openAlerts > 0 ? <Badge tone="red">{d.openAlerts}</Badge> : <span className="text-ink-muted">0</span>}</Td>
            <Td>
              <Badge tone={DISCHARGE_TONE[d.status] ?? "neutral"}>{humanize(d.status)}</Badge>
            </Td>
          </tr>
        ))}
      </tbody>
    </Table>
  );
}

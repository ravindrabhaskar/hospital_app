"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { FlaskConical } from "lucide-react";
import { api } from "@/lib/api";
import { LAB_ORDER_STATUSES, type LabOrderStatus } from "@/lib/api/types";
import { formatDateTime, formatINR, formatTime, humanize } from "@/lib/format";
import { LabStatusBadge } from "@/components/patient-care-extras";
import { OpenOriginalButton } from "@/components/record-file";
import { Card, ChipGroup, EmptyState, PageHeader, QueryView, Table, Td, Th } from "@/components/ui";

type Filter = "all" | LabOrderStatus;

export default function OpsLabOrdersPage() {
  const [filter, setFilter] = useState<Filter>("scheduled");
  const query = useQuery({
    queryKey: ["ops", "lab-orders", filter],
    queryFn: () => api.lab.opsOrders({ status: filter === "all" ? undefined : filter, limit: 100 }),
    refetchInterval: 30_000,
  });

  return (
    <>
      <PageHeader title="Lab orders" description="Home sample collection orders across partners. Collection visits appear on the home-visit board." />
      <Card>
        <div className="mb-4">
          <ChipGroup<Filter>
            label="Status"
            value={filter}
            onChange={setFilter}
            options={[{ value: "all", label: "All" }, ...LAB_ORDER_STATUSES.map((s) => ({ value: s, label: humanize(s) }))]}
          />
        </div>
        <QueryView
          query={query}
          isEmpty={(d) => d.items.length === 0}
          empty={<EmptyState icon={<FlaskConical className="size-6" />} title="No lab orders" description="No orders with this status." />}
        >
          {(d) => (
            <Table caption="Lab orders">
              <thead>
                <tr>
                  <Th>Patient</Th>
                  <Th>Tests</Th>
                  <Th>Collection window</Th>
                  <Th>Partner</Th>
                  <Th className="text-right">Total</Th>
                  <Th>Status</Th>
                  <Th>Report</Th>
                </tr>
              </thead>
              <tbody>
                {d.items.map((o) => (
                  <tr key={o.id}>
                    <Td>
                      <span className="font-semibold">{o.patientName}</span>
                      <span className="block text-xs text-ink-muted">Ordered {formatDateTime(o.createdAt)}</span>
                    </Td>
                    <Td className="text-[13px]">{o.tests.map((t) => t.name).join(", ")}</Td>
                    <Td className="whitespace-nowrap text-[13px]">
                      {formatDateTime(o.preferredStart)}–{formatTime(o.preferredEnd)}
                    </Td>
                    <Td className="text-[13px]">
                      {o.partnerName}
                      {o.partnerOrderId && <span className="block font-mono text-xs text-ink-muted">{o.partnerOrderId}</span>}
                    </Td>
                    <Td className="text-right tabular-nums">
                      {formatINR(o.total)}
                      {o.discount > 0 && <span className="block text-xs text-ink-muted">−{formatINR(o.discount)}</span>}
                    </Td>
                    <Td>
                      <LabStatusBadge status={o.status} />
                    </Td>
                    <Td>{o.reportRecordId ? <OpenOriginalButton recordId={o.reportRecordId} label="Report" /> : <span className="text-ink-muted">—</span>}</Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </QueryView>
      </Card>
    </>
  );
}

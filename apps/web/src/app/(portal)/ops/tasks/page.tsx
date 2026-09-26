"use client";

import { useQuery } from "@tanstack/react-query";
import { Timer } from "lucide-react";
import { api } from "@/lib/api";
import { formatDateTime, humanize, relativeTime } from "@/lib/format";
import { Badge, Card, EmptyState, PageHeader, QueryView, Table, Td, Th } from "@/components/ui";

export default function OverdueTasksPage() {
  const query = useQuery({ queryKey: ["ops", "overdue-tasks"], queryFn: () => api.ops.overdueTasks({ limit: 100 }), refetchInterval: 60_000 });
  return (
    <>
      <PageHeader title="Overdue care tasks" description="Care-plan tasks past their due time. Follow up with the patient, caregiver or provider." />
      <Card>
        <QueryView
          query={query}
          isEmpty={(d) => d.items.length === 0}
          empty={<EmptyState title="No overdue tasks" icon={<Timer className="size-6" />} />}
        >
          {(d) => (
            <Table caption="Overdue tasks, oldest first">
              <thead>
                <tr>
                  <Th>Patient</Th>
                  <Th>Task</Th>
                  <Th>Type</Th>
                  <Th>Owner</Th>
                  <Th>Due</Th>
                </tr>
              </thead>
              <tbody>
                {[...d.items]
                  .sort((a, b) => new Date(a.dueAt ?? 0).getTime() - new Date(b.dueAt ?? 0).getTime())
                  .map((t) => (
                    <tr key={t.id}>
                      <Td className="font-semibold">{t.patientName}</Td>
                      <Td>
                        {t.title}
                        {t.description && <p className="text-xs text-ink-muted">{t.description}</p>}
                      </Td>
                      <Td>{humanize(t.type)}</Td>
                      <Td>
                        <Badge tone="neutral">{humanize(t.owner)}</Badge>
                      </Td>
                      <Td className="whitespace-nowrap">
                        {formatDateTime(t.dueAt)}
                        <p className="text-xs font-medium text-danger-dark">{relativeTime(t.dueAt)}</p>
                      </Td>
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

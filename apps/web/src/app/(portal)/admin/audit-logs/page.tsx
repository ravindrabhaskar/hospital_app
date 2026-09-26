"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Filter, X } from "lucide-react";
import { api } from "@/lib/api";
import type { AuditLogQuery } from "@/lib/api/types";
import { formatDateTime, humanize } from "@/lib/format";
import { Badge, Button, Card, EmptyState, Field, Input, PageHeader, QueryView, Table, Td, Th } from "@/components/ui";

const EMPTY: AuditLogQuery = { actorId: "", entityType: "", entityId: "", action: "" };

export default function AuditLogsPage() {
  const [draft, setDraft] = useState<AuditLogQuery>(EMPTY);
  const [filters, setFilters] = useState<AuditLogQuery>(EMPTY);
  const [cursor, setCursor] = useState<string | undefined>(undefined);
  const [history, setHistory] = useState<(string | undefined)[]>([]);

  const clean = Object.fromEntries(Object.entries(filters).filter(([, v]) => v)) as AuditLogQuery;
  const query = useQuery({
    queryKey: ["admin", "audit", clean, cursor],
    queryFn: () => api.admin.auditLogs({ ...clean, limit: 50, cursor }),
    placeholderData: (prev) => prev,
  });

  const apply = (e: React.FormEvent) => {
    e.preventDefault();
    setFilters(draft);
    setCursor(undefined);
    setHistory([]);
  };

  return (
    <>
      <PageHeader title="Audit logs" description="Append-only record of sensitive access and administrative actions." />
      <Card>
        <form onSubmit={apply} className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-[repeat(4,minmax(0,1fr))_auto]">
          {(
            [
              ["actorId", "Actor ID"],
              ["action", "Action"],
              ["entityType", "Entity type"],
              ["entityId", "Entity ID"],
            ] as const
          ).map(([key, label]) => (
            <Field key={key} label={label}>
              {(id) => <Input id={id} value={draft[key] ?? ""} onChange={(e) => setDraft((d) => ({ ...d, [key]: e.target.value }))} />}
            </Field>
          ))}
          <div className="flex items-end gap-2">
            <Button type="submit" icon={<Filter className="size-4" aria-hidden />}>
              Apply
            </Button>
            <Button
              variant="ghost"
              aria-label="Clear filters"
              onClick={() => {
                setDraft(EMPTY);
                setFilters(EMPTY);
                setCursor(undefined);
                setHistory([]);
              }}
            >
              <X className="size-4" aria-hidden />
            </Button>
          </div>
        </form>
        <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No audit entries" />}>
          {(d) => (
            <>
              <Table caption="Audit log entries">
                <thead>
                  <tr>
                    <Th>Time (IST)</Th>
                    <Th>Actor</Th>
                    <Th>Action</Th>
                    <Th>Entity</Th>
                    <Th>Outcome</Th>
                    <Th>Correlation</Th>
                  </tr>
                </thead>
                <tbody>
                  {d.items.map((l) => (
                    <tr key={l.id}>
                      <Td className="whitespace-nowrap text-[13px]">{formatDateTime(l.createdAt)}</Td>
                      <Td>
                        <p className="font-medium">{l.actorName ?? "System"}</p>
                        <p className="text-xs text-ink-muted">
                          {l.actorRole ? humanize(l.actorRole) : "—"}
                          {l.ip ? ` · ${l.ip}` : ""}
                        </p>
                      </Td>
                      <Td className="font-mono text-xs">{l.action}</Td>
                      <Td>
                        <p className="text-[13px]">{l.entityType}</p>
                        <p className="max-w-[180px] truncate font-mono text-xs text-ink-muted" title={l.entityId ?? undefined}>
                          {l.entityId ?? "—"}
                        </p>
                      </Td>
                      <Td>
                        <Badge tone={l.outcome === "success" ? "green" : l.outcome === "denied" ? "amber" : "red"}>{humanize(l.outcome)}</Badge>
                      </Td>
                      <Td className="max-w-[160px] truncate font-mono text-xs text-ink-muted" >
                        <span title={l.correlationId ?? undefined}>{l.correlationId ?? "—"}</span>
                      </Td>
                    </tr>
                  ))}
                </tbody>
              </Table>
              <div className="mt-4 flex justify-between">
                <Button
                  variant="secondary"
                  size="sm"
                  disabled={history.length === 0}
                  onClick={() => {
                    const prev = [...history];
                    const c = prev.pop();
                    setHistory(prev);
                    setCursor(c);
                  }}
                >
                  Newer
                </Button>
                <Button
                  variant="secondary"
                  size="sm"
                  disabled={!d.nextCursor}
                  onClick={() => {
                    setHistory((h) => [...h, cursor]);
                    setCursor(d.nextCursor ?? undefined);
                  }}
                >
                  Older
                </Button>
              </div>
            </>
          )}
        </QueryView>
      </Card>
    </>
  );
}

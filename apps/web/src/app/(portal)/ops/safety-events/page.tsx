"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { CheckCheck, Eye, Siren } from "lucide-react";
import { api } from "@/lib/api";
import type { SafetyEvent } from "@/lib/api/types";
import { SafetyEventList } from "@/components/safety-events";
import { useToast } from "@/components/toast";
import { Button, Card, ChipGroup, Dialog, EmptyState, Field, PageHeader, QueryView, Textarea } from "@/components/ui";

type Filter = "active" | SafetyEvent["status"];

export default function SafetyEventsPage() {
  const [filter, setFilter] = useState<Filter>("open");
  const [resolving, setResolving] = useState<SafetyEvent | null>(null);
  const qc = useQueryClient();
  const toast = useToast();
  const status = filter === "active" ? undefined : filter;
  const query = useQuery({
    queryKey: ["ops", "safety-events", filter],
    queryFn: () => api.ops.safetyEvents({ status, limit: 100 }),
    refetchInterval: 15_000,
  });

  const ack = useMutation({
    mutationFn: (id: string) => api.ops.acknowledgeSafetyEvent(id),
    onSuccess: () => {
      toast.success("Safety event acknowledged");
      void qc.invalidateQueries({ queryKey: ["ops"] });
    },
    onError: (e) => toast.apiError(e, "Could not acknowledge"),
  });

  const items = (query.data?.items ?? []).filter((e) => filter !== "active" || e.status !== "resolved");

  return (
    <>
      <PageHeader title="Safety escalations" description="Emergency events first. Acknowledge to take ownership; resolve with a note." />
      <Card>
        <div className="mb-4">
          <ChipGroup
            label="Status"
            value={filter}
            onChange={setFilter}
            options={[
              { value: "open", label: "Open" },
              { value: "acknowledged", label: "Acknowledged" },
              { value: "active", label: "All unresolved" },
              { value: "resolved", label: "Resolved" },
            ]}
          />
        </div>
        <QueryView
          query={query}
          isEmpty={() => items.length === 0}
          empty={<EmptyState title="Inbox clear" description="No safety events in this view." icon={<Siren className="size-6" />} />}
        >
          {() => (
            <SafetyEventList
              events={items}
              renderActions={(e) => (
                <>
                  {e.status === "open" && (
                    <Button
                      size="sm"
                      variant={e.level === "emergency" ? "danger" : "primary"}
                      loading={ack.isPending && ack.variables === e.id}
                      onClick={() => ack.mutate(e.id)}
                      icon={<Eye className="size-4" aria-hidden />}
                      aria-label={`Acknowledge ${e.level} event for ${e.patientName}`}
                    >
                      Acknowledge
                    </Button>
                  )}
                  {e.status !== "resolved" && (
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={() => setResolving(e)}
                      icon={<CheckCheck className="size-4" aria-hidden />}
                      aria-label={`Resolve event for ${e.patientName}`}
                    >
                      Resolve
                    </Button>
                  )}
                </>
              )}
            />
          )}
        </QueryView>
      </Card>
      {resolving && <ResolveDialog event={resolving} onClose={() => setResolving(null)} />}
    </>
  );
}

function ResolveDialog({ event, onClose }: { event: SafetyEvent; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const m = useMutation({
    mutationFn: () => api.ops.resolveSafetyEvent(event.id, note.trim()),
    onSuccess: () => {
      toast.success("Safety event resolved");
      void qc.invalidateQueries({ queryKey: ["ops"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not resolve"),
  });
  return (
    <Dialog
      open
      onClose={onClose}
      title="Resolve safety event"
      description={`${event.level === "emergency" ? "Emergency" : "Urgent"} event for ${event.patientName}`}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            loading={m.isPending}
            onClick={() => {
              if (!note.trim()) {
                setError("Describe how this was resolved");
                return;
              }
              m.mutate();
            }}
          >
            Resolve
          </Button>
        </>
      }
    >
      <Field label="Resolution note" required error={error ?? undefined}>
        {(id, d) => (
          <Textarea
            id={id}
            data-autofocus
            aria-describedby={d}
            aria-invalid={!!error}
            rows={4}
            value={note}
            onChange={(e) => {
              setNote(e.target.value);
              setError(null);
            }}
          />
        )}
      </Field>
    </Dialog>
  );
}

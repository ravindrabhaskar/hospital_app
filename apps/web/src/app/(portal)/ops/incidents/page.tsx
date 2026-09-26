"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { MessageSquarePlus, Plus } from "lucide-react";
import { api } from "@/lib/api";
import type { Incident, IncidentSeverity, IncidentStatus } from "@/lib/api/types";
import { formatDateTime, humanize } from "@/lib/format";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, ChipGroup, Dialog, EmptyState, Field, Input, PageHeader, QueryView, Select, Textarea, cx, type Tone } from "@/components/ui";

type Filter = "all" | IncidentStatus;
const SEVERITY_TONE: Record<IncidentSeverity, Tone> = { low: "neutral", medium: "amber", high: "red", critical: "dark" };
const STATUS_TONE: Record<IncidentStatus, Tone> = { open: "red", investigating: "amber", resolved: "green", closed: "neutral" };

export default function IncidentsPage() {
  const [filter, setFilter] = useState<Filter>("open");
  const [creating, setCreating] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const query = useQuery({
    queryKey: ["ops", "incidents", filter],
    queryFn: () => api.ops.incidents({ status: filter === "all" ? undefined : filter, limit: 100 }),
  });
  const selected = query.data?.items.find((i) => i.id === selectedId) ?? null;

  return (
    <>
      <PageHeader
        title="Complaints & incidents"
        description="Log complaints, operational and clinical incidents, and track them to closure."
        actions={
          <Button onClick={() => setCreating(true)} icon={<Plus className="size-4" aria-hidden />}>
            New incident
          </Button>
        }
      />
      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_420px]">
        <Card>
          <div className="mb-4">
            <ChipGroup
              label="Status"
              value={filter}
              onChange={setFilter}
              options={[
                { value: "open", label: "Open" },
                { value: "investigating", label: "Investigating" },
                { value: "resolved", label: "Resolved" },
                { value: "closed", label: "Closed" },
                { value: "all", label: "All" },
              ]}
            />
          </div>
          <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No incidents" />}>
            {(d) => (
              <ul className="flex flex-col gap-2">
                {d.items.map((i) => (
                  <li key={i.id}>
                    <button
                      type="button"
                      aria-pressed={selectedId === i.id}
                      onClick={() => setSelectedId(i.id)}
                      className={cx(
                        "flex w-full flex-wrap items-start justify-between gap-2 rounded-xl border px-3 py-2.5 text-left",
                        selectedId === i.id ? "border-primary bg-mint-50" : "border-line hover:bg-mint-50",
                      )}
                    >
                      <span className="min-w-0">
                        <span className="block font-semibold">{i.title}</span>
                        <span className="block text-xs text-ink-muted">
                          {humanize(i.type)} · reported by {i.reportedByName} · {formatDateTime(i.createdAt)}
                          {i.patientName ? ` · patient ${i.patientName}` : ""}
                        </span>
                      </span>
                      <span className="flex gap-1.5">
                        <Badge tone={SEVERITY_TONE[i.severity]}>{humanize(i.severity)}</Badge>
                        <Badge tone={STATUS_TONE[i.status]}>{humanize(i.status)}</Badge>
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </QueryView>
        </Card>
        <aside aria-label="Incident detail">
          {selected ? (
            <IncidentDetail incident={selected} />
          ) : (
            <Card title="Incident detail">
              <EmptyState title="Select an incident" />
            </Card>
          )}
        </aside>
      </div>
      {creating && <CreateIncidentDialog onClose={() => setCreating(false)} />}
    </>
  );
}

function IncidentDetail({ incident }: { incident: Incident }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [note, setNote] = useState("");
  const update = useMutation({
    mutationFn: (input: { status?: IncidentStatus; note?: string }) => api.ops.updateIncident(incident.id, input),
    onSuccess: () => {
      setNote("");
      toast.success("Incident updated");
      void qc.invalidateQueries({ queryKey: ["ops", "incidents"] });
    },
    onError: (e) => toast.apiError(e, "Could not update incident"),
  });

  return (
    <Card title={incident.title} subtitle={`${humanize(incident.type)} · ${humanize(incident.severity)} severity`}>
      <p className="text-sm">{incident.description}</p>
      <Field label="Status" className="mt-4">
        {(id) => (
          <Select
            id={id}
            value={incident.status}
            disabled={update.isPending}
            onChange={(e) => update.mutate({ status: e.target.value as IncidentStatus })}
          >
            <option value="open">Open</option>
            <option value="investigating">Investigating</option>
            <option value="resolved">Resolved</option>
            <option value="closed">Closed</option>
          </Select>
        )}
      </Field>
      <h3 className="mt-5 text-sm font-semibold">Notes</h3>
      {incident.notes.length === 0 ? (
        <p className="text-sm text-ink-muted">No notes yet.</p>
      ) : (
        <ol className="mt-2 flex flex-col gap-2">
          {incident.notes.map((n, idx) => (
            <li key={idx} className="rounded-xl bg-mint-50 px-3 py-2 text-[13px]">
              <p>{n.text}</p>
              <p className="text-xs text-ink-muted">
                {n.authorName} · {formatDateTime(n.at)}
              </p>
            </li>
          ))}
        </ol>
      )}
      <form
        className="mt-3 flex flex-col gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          if (note.trim()) update.mutate({ note: note.trim() });
        }}
      >
        <Field label="Add note">{(id) => <Textarea id={id} rows={2} value={note} onChange={(e) => setNote(e.target.value)} />}</Field>
        <Button type="submit" size="sm" variant="secondary" className="self-start" disabled={!note.trim()} loading={update.isPending} icon={<MessageSquarePlus className="size-4" aria-hidden />}>
          Add note
        </Button>
      </form>
    </Card>
  );
}

const createSchema = z.object({
  type: z.enum(["complaint", "incident", "clinical_incident"]),
  title: z.string().trim().min(3, "Title is required"),
  description: z.string().trim().min(5, "Describe what happened"),
  severity: z.enum(["low", "medium", "high", "critical"]),
  patientId: z.string().trim().uuid("Must be a patient UUID").optional().or(z.literal("")),
  refType: z.string().trim().optional(),
  refId: z.string().trim().optional(),
});
type CreateValues = z.infer<typeof createSchema>;

function CreateIncidentDialog({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const { register, handleSubmit, formState } = useForm<CreateValues>({
    resolver: zodResolver(createSchema),
    defaultValues: { type: "complaint", title: "", description: "", severity: "medium", patientId: "", refType: "", refId: "" },
  });
  const e = formState.errors;
  const create = useMutation({
    mutationFn: (v: CreateValues) =>
      api.ops.createIncident({
        type: v.type,
        title: v.title,
        description: v.description,
        severity: v.severity,
        ...(v.patientId ? { patientId: v.patientId } : {}),
        ...(v.refType ? { refType: v.refType } : {}),
        ...(v.refId ? { refId: v.refId } : {}),
      }),
    onSuccess: () => {
      toast.success("Incident created");
      void qc.invalidateQueries({ queryKey: ["ops", "incidents"] });
      onClose();
    },
    onError: (err) => toast.apiError(err, "Could not create incident"),
  });
  const submit = handleSubmit((v) => create.mutate(v));

  return (
    <Dialog
      open
      onClose={onClose}
      title="New incident"
      size="lg"
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button loading={create.isPending} onClick={() => void submit()}>
            Create
          </Button>
        </>
      }
    >
      <form onSubmit={submit} noValidate className="grid gap-3 sm:grid-cols-2">
        <Field label="Type">
          {(id) => (
            <Select id={id} {...register("type")}>
              <option value="complaint">Complaint</option>
              <option value="incident">Incident</option>
              <option value="clinical_incident">Clinical incident</option>
            </Select>
          )}
        </Field>
        <Field label="Severity">
          {(id) => (
            <Select id={id} {...register("severity")}>
              <option value="low">Low</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
              <option value="critical">Critical</option>
            </Select>
          )}
        </Field>
        <Field label="Title" required error={e.title?.message} className="sm:col-span-2">
          {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!e.title} {...register("title")} />}
        </Field>
        <Field label="Description" required error={e.description?.message} className="sm:col-span-2">
          {(id, d) => <Textarea id={id} aria-describedby={d} aria-invalid={!!e.description} rows={4} {...register("description")} />}
        </Field>
        <Field label="Patient ID (optional)" error={e.patientId?.message} className="sm:col-span-2">
          {(id, d) => <Input id={id} aria-describedby={d} {...register("patientId")} />}
        </Field>
        <Field label="Reference type (optional)" hint="e.g. home_visit, appointment">
          {(id, d) => <Input id={id} aria-describedby={d} {...register("refType")} />}
        </Field>
        <Field label="Reference ID (optional)">{(id) => <Input id={id} {...register("refId")} />}</Field>
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}

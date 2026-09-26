"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Plus } from "lucide-react";
import { api } from "@/lib/api";
import type { KnowledgeSource, KnowledgeStatus } from "@/lib/api/types";
import { formatDate, todayIST } from "@/lib/format";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, Dialog, EmptyState, Field, Input, PageHeader, QueryView, Select, Table, Td, Textarea, Th, type Tone } from "@/components/ui";

const STATUS_TONE: Record<KnowledgeStatus, Tone> = { draft: "sky", approved: "green", deprecated: "neutral" };

export default function KnowledgePage() {
  const [creating, setCreating] = useState(false);
  const query = useQuery({ queryKey: ["admin", "knowledge"], queryFn: () => api.admin.knowledgeSources({ limit: 100 }) });
  return (
    <>
      <PageHeader
        title="Knowledge sources"
        description="Only approved, unexpired sources are used for AI retrieval (RAG)."
        actions={
          <Button onClick={() => setCreating(true)} icon={<Plus className="size-4" aria-hidden />}>
            Add source
          </Button>
        }
      />
      <Card>
        <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No knowledge sources" />}>
          {(d) => (
            <Table caption="Knowledge sources">
              <thead>
                <tr>
                  <Th>Title</Th>
                  <Th>Owner</Th>
                  <Th>Version</Th>
                  <Th>Effective</Th>
                  <Th>Expires</Th>
                  <Th className="text-right">Chunks</Th>
                  <Th>Status</Th>
                </tr>
              </thead>
              <tbody>
                {d.items.map((s) => (
                  <SourceRow key={s.id} s={s} />
                ))}
              </tbody>
            </Table>
          )}
        </QueryView>
      </Card>
      {creating && <CreateSourceDialog onClose={() => setCreating(false)} />}
    </>
  );
}

function SourceRow({ s }: { s: KnowledgeSource }) {
  const qc = useQueryClient();
  const toast = useToast();
  const m = useMutation({
    mutationFn: (status: KnowledgeStatus) => api.admin.setKnowledgeStatus(s.id, status),
    onSuccess: (_r, status) => {
      toast.success(`Source marked ${status}`);
      void qc.invalidateQueries({ queryKey: ["admin", "knowledge"] });
    },
    onError: (e) => toast.apiError(e, "Could not change status"),
  });
  const expired = s.expiresAt !== null && s.expiresAt < todayIST();
  return (
    <tr>
      <Td className="font-semibold">{s.title}</Td>
      <Td>{s.owner}</Td>
      <Td className="font-mono text-xs">{s.version}</Td>
      <Td className="whitespace-nowrap">{formatDate(s.effectiveDate)}</Td>
      <Td className="whitespace-nowrap">
        {s.expiresAt ? formatDate(s.expiresAt) : "—"}
        {expired && (
          <div>
            <Badge tone="red">Expired</Badge>
          </div>
        )}
      </Td>
      <Td className="text-right tabular-nums">{s.chunkCount}</Td>
      <Td>
        <div className="flex items-center gap-2">
          <Badge tone={STATUS_TONE[s.status]}>{s.status}</Badge>
          <label className="sr-only" htmlFor={`status-${s.id}`}>
            Change status of {s.title}
          </label>
          <Select
            id={`status-${s.id}`}
            className="h-8 w-36 py-0 text-xs"
            value={s.status}
            disabled={m.isPending}
            onChange={(e) => m.mutate(e.target.value as KnowledgeStatus)}
          >
            <option value="draft">Draft</option>
            <option value="approved">Approved</option>
            <option value="deprecated">Deprecated</option>
          </Select>
        </div>
      </Td>
    </tr>
  );
}

const schema = z
  .object({
    title: z.string().trim().min(3, "Title is required"),
    owner: z.string().trim().min(2, "Owner is required"),
    version: z.string().trim().min(1, "Version is required"),
    effectiveDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Effective date is required"),
    expiresAt: z.string().optional(),
    content: z.string().trim().min(20, "Content must be at least 20 characters"),
  })
  .refine((v) => !v.expiresAt || v.expiresAt > v.effectiveDate, { path: ["expiresAt"], message: "Must be after the effective date" });
type Values = z.infer<typeof schema>;

function CreateSourceDialog({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const { register, handleSubmit, formState } = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: { title: "", owner: "", version: "1.0", effectiveDate: todayIST(), expiresAt: "", content: "" },
  });
  const e = formState.errors;
  const m = useMutation({
    mutationFn: (v: Values) => api.admin.createKnowledgeSource({ ...v, expiresAt: v.expiresAt || undefined }),
    onSuccess: () => {
      toast.success("Source created as draft");
      void qc.invalidateQueries({ queryKey: ["admin", "knowledge"] });
      onClose();
    },
    onError: (err) => toast.apiError(err, "Could not create source"),
  });
  const submit = handleSubmit((v) => m.mutate(v));
  return (
    <Dialog
      open
      onClose={onClose}
      size="lg"
      title="Add knowledge source"
      description="Created as a draft. A reviewer must approve it before it is used."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button loading={m.isPending} onClick={() => void submit()}>
            Create draft
          </Button>
        </>
      }
    >
      <form onSubmit={submit} noValidate className="grid gap-3 sm:grid-cols-2">
        <Field label="Title" required error={e.title?.message} className="sm:col-span-2">
          {(id, d) => <Input id={id} data-autofocus aria-describedby={d} aria-invalid={!!e.title} {...register("title")} />}
        </Field>
        <Field label="Owner" required error={e.owner?.message}>
          {(id, d) => <Input id={id} aria-describedby={d} placeholder="Clinical content team" {...register("owner")} />}
        </Field>
        <Field label="Version" required error={e.version?.message}>
          {(id, d) => <Input id={id} aria-describedby={d} {...register("version")} />}
        </Field>
        <Field label="Effective date" required error={e.effectiveDate?.message}>
          {(id, d) => <Input id={id} type="date" aria-describedby={d} {...register("effectiveDate")} />}
        </Field>
        <Field label="Expires on" error={e.expiresAt?.message}>
          {(id, d) => <Input id={id} type="date" aria-describedby={d} {...register("expiresAt")} />}
        </Field>
        <Field label="Content" required error={e.content?.message} className="sm:col-span-2">
          {(id, d) => <Textarea id={id} rows={10} aria-describedby={d} aria-invalid={!!e.content} {...register("content")} />}
        </Field>
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}

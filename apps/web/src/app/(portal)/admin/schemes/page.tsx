"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, ExternalLink, Pencil, Plus } from "lucide-react";
import { api } from "@/lib/api";
import type { Scheme, SchemeInput } from "@/lib/api/types";
import { formatDate } from "@/lib/format";
import { useToast } from "@/components/toast";
import {
  Badge,
  Button,
  Card,
  ChipGroup,
  Dialog,
  EmptyState,
  Field,
  Input,
  PageHeader,
  QueryView,
  Select,
  Table,
  Td,
  Textarea,
  Th,
  Toggle,
} from "@/components/ui";

const SCHEMES_KEY = ["admin", "schemes"];
type Filter = "all" | Scheme["status"];

const lines = (t: string) =>
  t
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);

const schema = z
  .object({
    name: z.string().trim().min(3, "Name is required").max(160),
    authority: z.string().trim().min(2, "Authority is required").max(160),
    level: z.enum(["central", "state"]),
    state: z.string().trim().max(80).optional(), // undefined while the input is disabled (central)
    summary: z.string().trim().min(10, "Write a short, cautious summary").max(1500),
    benefitsText: z.string(),
    eligibilityText: z.string(),
    documentsText: z.string(),
    officialUrl: z
      .string()
      .trim()
      .url("Enter a full URL")
      .refine((u) => u.startsWith("https://"), "The official URL must use https://"),
    helpline: z.string().trim().max(60),
    disclaimer: z.string().trim().min(10, "A disclaimer is required"),
    status: z.enum(["draft", "published"]),
    reviewed: z.boolean(),
  })
  .superRefine((v, ctx) => {
    if (v.level === "state" && !v.state) ctx.addIssue({ code: "custom", path: ["state"], message: "State is required for a state scheme" });
  });
type FormValues = z.input<typeof schema>;
type ParsedValues = z.output<typeof schema>;

const DEFAULT_DISCLAIMER =
  "This information is for general awareness only and may change. CareCompanion does not decide eligibility. Please confirm details with the official scheme authority.";

export default function SchemesPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const [filter, setFilter] = useState<Filter>("all");
  const [editing, setEditing] = useState<Scheme | "new" | null>(null);
  const [confirming, setConfirming] = useState<Scheme | null>(null);
  const query = useQuery({ queryKey: SCHEMES_KEY, queryFn: () => api.schemes.list({ limit: 100 }) });

  const setStatus = useMutation({
    mutationFn: (v: { id: string; status: Scheme["status"] }) => api.schemes.update(v.id, { status: v.status }),
    onSuccess: (s) => {
      toast.success(s.status === "published" ? "Scheme published" : "Scheme moved to draft", s.name);
      setConfirming(null);
      void qc.invalidateQueries({ queryKey: SCHEMES_KEY });
    },
    onError: (e) => toast.apiError(e, "Could not change the status"),
  });

  const items = query.data?.items ?? [];
  const count = (s: Scheme["status"]) => items.filter((x) => x.status === s).length;

  return (
    <>
      <PageHeader
        title="Government schemes"
        description="Informational entries shown to patients (published only)."
        actions={
          <Button onClick={() => setEditing("new")} icon={<Plus className="size-4" aria-hidden />}>
            New scheme
          </Button>
        }
      />
      <div role="note" className="mb-5 flex items-start gap-3 rounded-2xl border border-[#f8d9b5] bg-peach-bg px-4 py-3 text-[13px] text-peach-fg">
        <AlertTriangle className="mt-0.5 size-5 shrink-0" aria-hidden />
        <div>
          <p className="font-semibold">Information only [REQUIRES CONTENT REVIEW]</p>
          <p>
            Scheme content is informational only and must pass content review before it is published. The app never tells a user they are
            eligible for a scheme; keep summaries generic and cautious and always link to the official source.
          </p>
        </div>
      </div>
      <Card>
        <div className="mb-4">
          <ChipGroup
            label="Scheme status"
            value={filter}
            onChange={setFilter}
            options={[
              { value: "all", label: "All", count: query.isSuccess ? items.length : undefined },
              { value: "draft", label: "Draft", count: query.isSuccess ? count("draft") : undefined },
              { value: "published", label: "Published", count: query.isSuccess ? count("published") : undefined },
            ]}
          />
        </div>
        <QueryView
          query={query}
          isEmpty={(d) => d.items.filter((s) => filter === "all" || s.status === filter).length === 0}
          empty={<EmptyState title="No schemes" description={filter === "all" ? "Create the first scheme entry." : `No ${filter} schemes.`} />}
        >
          {(d) => (
            <Table caption="Government schemes">
              <thead>
                <tr>
                  <Th>Scheme</Th>
                  <Th>Level</Th>
                  <Th>Last reviewed</Th>
                  <Th>Official site</Th>
                  <Th>Published</Th>
                  <Th className="text-right">Actions</Th>
                </tr>
              </thead>
              <tbody>
                {d.items
                  .filter((s) => filter === "all" || s.status === filter)
                  .map((s) => (
                    <tr key={s.id}>
                      <Td>
                        <p className="font-semibold">{s.name}</p>
                        <p className="text-xs text-ink-muted">{s.authority}</p>
                      </Td>
                      <Td>
                        <Badge tone={s.level === "central" ? "sky" : "lavender"}>{s.level === "central" ? "Central" : "State"}</Badge>
                        {s.state && <p className="mt-1 text-xs text-ink-muted">{s.state}</p>}
                      </Td>
                      <Td className="whitespace-nowrap">{s.lastReviewedAt ? formatDate(s.lastReviewedAt) : "Never"}</Td>
                      <Td>
                        <a
                          href={s.officialUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 break-all text-primary hover:underline"
                        >
                          {safeHost(s.officialUrl)}
                          <ExternalLink className="size-3.5 shrink-0" aria-hidden />
                          <span className="sr-only">(opens in a new tab)</span>
                        </a>
                      </Td>
                      <Td>
                        <div className="flex items-center gap-2">
                          <Toggle
                            checked={s.status === "published"}
                            disabled={setStatus.isPending && setStatus.variables?.id === s.id}
                            label={`Published: ${s.name}`}
                            onChange={(on) => (on ? setConfirming(s) : setStatus.mutate({ id: s.id, status: "draft" }))}
                          />
                          <Badge tone={s.status === "published" ? "green" : "neutral"}>{s.status === "published" ? "Published" : "Draft"}</Badge>
                        </div>
                      </Td>
                      <Td className="text-right">
                        <Button variant="ghost" size="sm" onClick={() => setEditing(s)} aria-label={`Edit ${s.name}`} icon={<Pencil className="size-4" aria-hidden />}>
                          Edit
                        </Button>
                      </Td>
                    </tr>
                  ))}
              </tbody>
            </Table>
          )}
        </QueryView>
      </Card>

      {confirming && (
        <Dialog
          open
          onClose={() => setConfirming(null)}
          title="Publish this scheme?"
          description={confirming.name}
          footer={
            <>
              <Button variant="ghost" onClick={() => setConfirming(null)}>
                Cancel
              </Button>
              <Button loading={setStatus.isPending} onClick={() => setStatus.mutate({ id: confirming.id, status: "published" })}>
                Yes, content was reviewed. Publish
              </Button>
            </>
          }
        >
          <p className="text-sm">
            Published schemes are visible to all patients. Confirm that this entry has passed content review: the summary is generic and
            cautious, it does not suggest anyone is eligible, and the official URL and helpline are correct.
          </p>
        </Dialog>
      )}
      {editing && <SchemeDialog scheme={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
    </>
  );
}

function safeHost(url: string) {
  try {
    return new URL(url).host;
  } catch {
    return url;
  }
}

function SchemeDialog({ scheme, onClose }: { scheme: Scheme | null; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const wasPublished = scheme?.status === "published";
  const form = useForm<FormValues, unknown, ParsedValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: scheme?.name ?? "",
      authority: scheme?.authority ?? "",
      level: scheme?.level ?? "central",
      state: scheme?.state ?? "",
      summary: scheme?.summary ?? "",
      benefitsText: scheme?.benefits.join("\n") ?? "",
      eligibilityText: scheme?.eligibilityHints.join("\n") ?? "",
      documentsText: scheme?.documentsTypicallyNeeded.join("\n") ?? "",
      officialUrl: scheme?.officialUrl ?? "https://",
      helpline: scheme?.helpline ?? "",
      disclaimer: scheme?.disclaimer ?? DEFAULT_DISCLAIMER,
      status: scheme?.status ?? "draft",
      reviewed: false,
    },
  });
  const { register, handleSubmit, formState, watch, setError } = form;
  const errors = formState.errors;
  const level = watch("level");
  const status = watch("status");
  const needsReview = status === "published";

  const m = useMutation({
    mutationFn: (body: SchemeInput) => (scheme ? api.schemes.update(scheme.id, body) : api.schemes.create(body)),
    onSuccess: (s) => {
      toast.success(scheme ? "Scheme updated" : "Scheme created", s.name);
      void qc.invalidateQueries({ queryKey: SCHEMES_KEY });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not save the scheme"),
  });

  const onSubmit = handleSubmit((v) => {
    if (v.status === "published" && !v.reviewed) {
      setError("reviewed", { message: "Confirm the content review before publishing" });
      return;
    }
    m.mutate({
      name: v.name,
      authority: v.authority,
      level: v.level,
      state: v.level === "state" ? (v.state ?? null) : null,
      summary: v.summary,
      benefits: lines(v.benefitsText),
      eligibilityHints: lines(v.eligibilityText),
      documentsTypicallyNeeded: lines(v.documentsText),
      officialUrl: v.officialUrl,
      helpline: v.helpline ? v.helpline : null,
      status: v.status,
      disclaimer: v.disclaimer,
    });
  });

  return (
    <Dialog
      open
      size="lg"
      onClose={onClose}
      title={scheme ? `Edit ${scheme.name}` : "New government scheme"}
      description="Informational only. Never state or imply that a user is eligible."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="scheme-form" loading={m.isPending}>
            {scheme ? "Save changes" : "Create scheme"}
          </Button>
        </>
      }
    >
      <form id="scheme-form" noValidate onSubmit={onSubmit} className="grid gap-3 sm:grid-cols-2">
        <Field label="Name" required error={errors.name?.message} className="sm:col-span-2">
          {(id, d) => <Input id={id} data-autofocus aria-describedby={d} aria-invalid={!!errors.name} {...register("name")} />}
        </Field>
        <Field label="Authority" required error={errors.authority?.message} className="sm:col-span-2">
          {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!errors.authority} placeholder="National Health Authority" {...register("authority")} />}
        </Field>
        <Field label="Level" required>
          {(id) => (
            <Select id={id} {...register("level")}>
              <option value="central">Central</option>
              <option value="state">State</option>
            </Select>
          )}
        </Field>
        <Field label="State" required={level === "state"} error={errors.state?.message} hint={level === "central" ? "Not used for central schemes" : undefined}>
          {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!errors.state} disabled={level !== "state"} placeholder="Telangana" {...register("state")} />}
        </Field>
        <Field label="Summary" required error={errors.summary?.message} className="sm:col-span-2">
          {(id, d) => <Textarea id={id} rows={3} aria-describedby={d} aria-invalid={!!errors.summary} {...register("summary")} />}
        </Field>
        <Field label="Benefits" hint="One per line" className="sm:col-span-2">
          {(id, d) => <Textarea id={id} rows={3} aria-describedby={d} {...register("benefitsText")} />}
        </Field>
        <Field label="Eligibility hints" hint="One per line. Describe general criteria only; never tell a user they qualify." className="sm:col-span-2">
          {(id, d) => <Textarea id={id} rows={3} aria-describedby={d} {...register("eligibilityText")} />}
        </Field>
        <Field label="Documents typically needed" hint="One per line" className="sm:col-span-2">
          {(id, d) => <Textarea id={id} rows={3} aria-describedby={d} {...register("documentsText")} />}
        </Field>
        <Field label="Official URL" required error={errors.officialUrl?.message} hint="Must start with https://">
          {(id, d) => <Input id={id} type="url" inputMode="url" aria-describedby={d} aria-invalid={!!errors.officialUrl} {...register("officialUrl")} />}
        </Field>
        <Field label="Helpline (optional)" error={errors.helpline?.message}>
          {(id, d) => <Input id={id} inputMode="tel" aria-describedby={d} aria-invalid={!!errors.helpline} placeholder="14555" {...register("helpline")} />}
        </Field>
        <Field label="Disclaimer" required error={errors.disclaimer?.message} className="sm:col-span-2">
          {(id, d) => <Textarea id={id} rows={2} aria-describedby={d} aria-invalid={!!errors.disclaimer} {...register("disclaimer")} />}
        </Field>
        <Field label="Status" required>
          {(id) => (
            <Select id={id} {...register("status")}>
              <option value="draft">Draft</option>
              <option value="published">Published</option>
            </Select>
          )}
        </Field>
        {needsReview && (
          <div className="flex flex-col gap-1 sm:col-span-2">
            <label className="flex items-start gap-2 text-sm">
              <input type="checkbox" className="mt-0.5 size-4 accent-[#0B5D45]" aria-invalid={!!errors.reviewed} {...register("reviewed")} />
              {wasPublished
                ? "I confirm these edits passed content review before they go live."
                : "I confirm this content passed content review and may be published."}
            </label>
            {errors.reviewed?.message && (
              <p role="alert" className="text-xs text-danger-dark">
                {errors.reviewed.message}
              </p>
            )}
          </div>
        )}
      </form>
    </Dialog>
  );
}

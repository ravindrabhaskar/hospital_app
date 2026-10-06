"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, BadgeCheck, HeartPulse, Pencil, Plus, Trash2 } from "lucide-react";
import { api } from "@/lib/api";
import type { MetricFrequency, ProgramTemplate, VitalType } from "@/lib/api/types";
import { humanize } from "@/lib/format";
import { useAuth } from "@/lib/auth";
import {
  VITAL_TYPES,
  describeThreshold,
  templateDescriptionError,
  toApproveInput,
  toDraft,
  toThresholds,
  validateApproval,
  validateThresholds,
  vitalLabel,
  type ThresholdDraft,
} from "@/lib/programs";
import { ThresholdEditor } from "@/components/threshold-editor";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, Dialog, EmptyState, Field, Input, PageHeader, QueryView, Select, Textarea } from "@/components/ui";

const KEY = ["admin", "care-programs"];
const FREQS: MetricFrequency[] = ["daily", "twice_daily", "weekly"];

export default function AdminProgramsPage() {
  const [editing, setEditing] = useState<ProgramTemplate | "new" | null>(null);
  const [approving, setApproving] = useState<ProgramTemplate | null>(null);
  const query = useQuery({ queryKey: KEY, queryFn: () => api.adminPrograms.templates() });
  return (
    <>
      <PageHeader
        title="Care program templates"
        description="Remote-monitoring templates and their default thresholds. Saving creates a new version that must be approved again."
        actions={
          <Button onClick={() => setEditing("new")} icon={<Plus className="size-4" aria-hidden />}>
            New template
          </Button>
        }
      />
      <p role="note" className="mb-5 flex items-start gap-2 rounded-2xl border border-[#f8d9b5] bg-peach-bg px-4 py-3 text-[13px] text-peach-fg">
        <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
        <span>
          <strong>[REQUIRES CLINICAL GOVERNANCE]</strong> Thresholds drive patient alerts. Production refuses unapproved templates; only approve after a
          named clinical lead has reviewed every value.
        </span>
      </p>
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<Card><EmptyState icon={<HeartPulse className="size-6" />} title="No templates" /></Card>}>
        {(d) => (
          <ul className="grid gap-4 lg:grid-cols-2">
            {d.items.map((t) => (
              <li key={`${t.code}-${t.version}`}>
                <Card
                  title={t.name}
                  subtitle={
                    <span className="font-mono">
                      {t.code} · v{t.version}
                    </span>
                  }
                  actions={
                    <>
                      {t.status === "approved" ? (
                        <Badge tone="green" icon={<BadgeCheck className="size-3" aria-hidden />}>
                          Approved
                        </Badge>
                      ) : (
                        <Badge tone="amber">Unapproved fixture</Badge>
                      )}
                      <Button size="sm" variant="ghost" onClick={() => setEditing(t)} aria-label={`Edit ${t.name}`} icon={<Pencil className="size-4" aria-hidden />}>
                        Edit
                      </Button>
                      {t.status !== "approved" && (
                        <Button size="sm" variant="secondary" onClick={() => setApproving(t)} aria-label={`Approve ${t.name}`}>
                          Approve
                        </Button>
                      )}
                    </>
                  }
                >
                  <p className="mb-2 text-sm text-ink-muted">{t.description}</p>
                  <p className="mb-2 text-xs">Readings: {t.metrics.map((m) => `${vitalLabel(m.type)} ${humanize(m.frequency).toLowerCase()} (${m.unit})`).join(", ") || "—"}</p>
                  <ul className="flex flex-wrap gap-1.5" aria-label={`Default thresholds of ${t.name}`}>
                    {t.defaultThresholds.map((th, i) => (
                      <li key={i}>
                        <Badge tone={th.level === "emergency" ? "dark" : th.level === "urgent" ? "red" : "neutral"} title={th.message}>
                          {describeThreshold(th)}
                        </Badge>
                      </li>
                    ))}
                  </ul>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </QueryView>
      {editing && <TemplateDialog template={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
      {approving && <ApproveDialog template={approving} onClose={() => setApproving(null)} />}
    </>
  );
}

type MetricDraft = { type: VitalType; frequency: MetricFrequency; unit: string };

function TemplateDialog({ template, onClose }: { template: ProgramTemplate | null; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [code, setCode] = useState(template?.code ?? "");
  const [name, setName] = useState(template?.name ?? "");
  const [description, setDescription] = useState(template?.description ?? "");
  const [version, setVersion] = useState(template ? nextVersion(template.version) : "1.0");
  const [metrics, setMetrics] = useState<MetricDraft[]>(template?.metrics ?? [{ type: "bp_systolic", frequency: "daily", unit: "mmHg" }]);
  const [drafts, setDrafts] = useState<ThresholdDraft[]>(template?.defaultThresholds.map(toDraft) ?? []);
  const [submitted, setSubmitted] = useState(false);
  const validation = validateThresholds(drafts, { requireAtLeastOne: true });
  const errors = {
    code: /^[a-z][a-z0-9_]{1,39}$/.test(code) ? undefined : "Lowercase snake_case, e.g. heart_failure",
    name: name.trim().length >= 2 ? undefined : "Name is required",
    description: templateDescriptionError(description),
    version: /^\d+(\.\d+){0,2}$/.test(version.trim()) ? undefined : "e.g. 1.1",
    metrics: metrics.length === 0 ? "Add at least one reading" : metrics.some((m) => !m.unit.trim()) ? "Every reading needs a unit" : undefined,
  };
  const ok = validation.ok && Object.values(errors).every((e) => !e);

  const save = useMutation({
    mutationFn: () =>
      api.adminPrograms.create({
        code,
        name: name.trim(),
        description: description.trim(),
        version: version.trim(),
        metrics: metrics.map((m) => ({ ...m, unit: m.unit.trim() })),
        defaultThresholds: toThresholds(drafts),
      }),
    onSuccess: () => {
      toast.success("Template saved", "It is unapproved until a clinical lead approves it.");
      void qc.invalidateQueries({ queryKey: KEY });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not save the template"),
  });

  return (
    <Dialog
      open
      size="lg"
      onClose={onClose}
      title={template ? `Edit ${template.name}` : "New program template"}
      description="Saving posts a new version; existing enrollments keep their own thresholds."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            loading={save.isPending}
            onClick={() => {
              setSubmitted(true);
              if (ok) save.mutate();
            }}
          >
            Save as new version
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <div className="grid gap-3 sm:grid-cols-3">
          <Field label="Code" required error={submitted ? errors.code : undefined}>
            {(id, d) => <Input id={id} className="font-mono" aria-describedby={d} readOnly={!!template} data-autofocus={template ? undefined : ""} value={code} onChange={(e) => setCode(e.target.value)} />}
          </Field>
          <Field label="Name" required error={submitted ? errors.name : undefined}>
            {(id, d) => <Input id={id} aria-describedby={d} value={name} onChange={(e) => setName(e.target.value)} />}
          </Field>
          <Field label="Version" required error={submitted ? errors.version : undefined}>
            {(id, d) => <Input id={id} aria-describedby={d} value={version} onChange={(e) => setVersion(e.target.value)} />}
          </Field>
          <Field label="Description" required className="sm:col-span-3" error={submitted ? errors.description : undefined}>
            {(id, d) => (
              <Textarea
                id={id}
                rows={2}
                maxLength={1000}
                aria-describedby={d}
                aria-invalid={submitted && !!errors.description}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
              />
            )}
          </Field>
        </div>
        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1 text-sm font-semibold">Readings</legend>
          {submitted && errors.metrics && (
            <p role="alert" className="text-xs text-danger-dark">
              {errors.metrics}
            </p>
          )}
          {metrics.map((m, i) => {
            const set = (p: Partial<MetricDraft>) => setMetrics((xs) => xs.map((x, j) => (j === i ? { ...x, ...p } : x)));
            return (
              <div key={i} role="group" aria-label={`Reading ${i + 1}`} className="grid gap-2 sm:grid-cols-[1fr_1fr_1fr_auto]">
                <Select aria-label={`Reading ${i + 1} vital`} value={m.type} onChange={(e) => set({ type: e.target.value as VitalType })}>
                  {VITAL_TYPES.map((t) => (
                    <option key={t} value={t}>
                      {vitalLabel(t)}
                    </option>
                  ))}
                </Select>
                <Select aria-label={`Reading ${i + 1} frequency`} value={m.frequency} onChange={(e) => set({ frequency: e.target.value as MetricFrequency })}>
                  {FREQS.map((f) => (
                    <option key={f} value={f}>
                      {humanize(f)}
                    </option>
                  ))}
                </Select>
                <Input aria-label={`Reading ${i + 1} unit`} value={m.unit} onChange={(e) => set({ unit: e.target.value })} />
                <Button size="sm" variant="ghost" aria-label={`Remove reading ${i + 1}`} onClick={() => setMetrics((xs) => xs.filter((_, j) => j !== i))} icon={<Trash2 className="size-4" aria-hidden />} />
              </div>
            );
          })}
          <Button size="sm" variant="subtle" className="self-start" onClick={() => setMetrics((xs) => [...xs, { type: "pulse", frequency: "daily", unit: "bpm" }])} icon={<Plus className="size-4" aria-hidden />}>
            Add reading
          </Button>
        </fieldset>
        <ThresholdEditor label="Default thresholds" value={drafts} onChange={setDrafts} validation={validation} showErrors={submitted} />
      </div>
    </Dialog>
  );
}

function nextVersion(v: string) {
  const parts = v.split(".").map((p) => Number(p));
  if (parts.some((n) => !Number.isInteger(n))) return v;
  parts[parts.length - 1] = (parts[parts.length - 1] ?? 0) + 1;
  return parts.join(".");
}

function ApproveDialog({ template, onClose }: { template: ProgramTemplate; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const { user } = useAuth();
  const [confirmed, setConfirmed] = useState(false);
  const [approverName, setApproverName] = useState(user?.name ?? "");
  const [approverRegistration, setApproverRegistration] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const errors = validateApproval({ approverName, approverRegistration });
  const ok = Object.keys(errors).length === 0;
  const approve = useMutation({
    mutationFn: () => api.adminPrograms.approve(template.code, toApproveInput({ approverName, approverRegistration }, template.version)),
    onSuccess: () => {
      toast.success("Template approved", `${template.name} v${template.version}`);
      void qc.invalidateQueries({ queryKey: KEY });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not approve the template"),
  });
  return (
    <Dialog
      open
      onClose={onClose}
      title={`Approve ${template.name} v${template.version}?`}
      description="Approval is audited against your account."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant="danger"
            disabled={!confirmed}
            loading={approve.isPending}
            onClick={() => {
              setSubmitted(true);
              if (ok) approve.mutate();
            }}
          >
            Approve template
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3 text-sm">
        <p className="flex items-start gap-2 rounded-xl border border-[#f6c9c9] bg-rose-bg p-3 text-danger-dark">
          <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
          Clinical governance: approved thresholds let coordinators enrol patients without a doctor editing them, and alerts reach families. Only
          approve after a named, registered clinical lead has reviewed every threshold below.
        </p>
        <ul className="flex flex-col gap-1">
          {template.defaultThresholds.map((t, i) => (
            <li key={i}>
              • {describeThreshold(t)}: <span className="text-ink-muted">{t.message}</span>
            </li>
          ))}
        </ul>
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Approving clinical lead" required hint="Recorded on the template and in the audit log" error={submitted ? errors.approverName : undefined}>
            {(id, d) => (
              <Input id={id} aria-describedby={d} aria-invalid={submitted && !!errors.approverName} maxLength={100} value={approverName} onChange={(e) => setApproverName(e.target.value)} />
            )}
          </Field>
          <Field label="Registration number" hint="Optional, e.g. medical council number" error={submitted ? errors.approverRegistration : undefined}>
            {(id, d) => (
              <Input
                id={id}
                aria-describedby={d}
                aria-invalid={submitted && !!errors.approverRegistration}
                maxLength={60}
                value={approverRegistration}
                onChange={(e) => setApproverRegistration(e.target.value)}
              />
            )}
          </Field>
        </div>
        <label className="flex items-start gap-2">
          <input type="checkbox" className="mt-0.5 size-4 accent-[#b3261e]" checked={confirmed} onChange={(e) => setConfirmed(e.target.checked)} data-autofocus="" />
          I confirm a clinical lead has reviewed and signed off these thresholds.
        </label>
      </div>
    </Dialog>
  );
}

"use client";

import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertOctagon, BadgeCheck, ChevronDown, ChevronRight, FilePlus2, Power } from "lucide-react";
import { api } from "@/lib/api";
import type { SafetyRule, SafetyRulePack } from "@/lib/api/types";
import { formatDateTime, humanize } from "@/lib/format";
import { RULE_PACK_TEMPLATE, parseRulePackJson } from "@/lib/safety-rules";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, Dialog, EmptyState, Field, Input, PageHeader, QueryView, Table, Td, Textarea, Th, type Tone } from "@/components/ui";

const STATUS_TONE: Record<SafetyRulePack["status"], Tone> = { draft: "sky", fixture_unapproved: "red", approved: "green", retired: "neutral" };

export default function SafetyRulesPage() {
  const query = useQuery({ queryKey: ["admin", "rule-packs"], queryFn: () => api.admin.rulePacks({ limit: 100 }) });
  const [expanded, setExpanded] = useState<string | null>(null);
  const [approving, setApproving] = useState<SafetyRulePack | null>(null);
  const [activating, setActivating] = useState<SafetyRulePack | null>(null);
  const [creating, setCreating] = useState(false);
  const active = query.data?.items.find((p) => p.active);

  return (
    <>
      <PageHeader
        title="Safety rule packs"
        description="The deterministic safety engine runs before any AI reply. Only clinically approved packs should be active in production."
        actions={
          <Button onClick={() => setCreating(true)} icon={<FilePlus2 className="size-4" aria-hidden />}>
            New pack
          </Button>
        }
      />
      {active?.status === "fixture_unapproved" && (
        <div role="alert" className="mb-5 flex items-start gap-3 rounded-[20px] border-2 border-danger bg-rose-bg p-5 text-danger-dark">
          <AlertOctagon className="mt-0.5 size-7 shrink-0" aria-hidden />
          <div>
            <p className="text-lg font-bold">Active safety rules are an UNAPPROVED FIXTURE ({active.version})</p>
            <p className="text-sm">
              Red-flag detection is running on a development fixture that has not been clinically reviewed. Do not use this configuration
              with real patients. Create or approve a clinician-reviewed pack and activate it.
            </p>
          </div>
        </div>
      )}
      <Card>
        <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No rule packs" />}>
          {(d) => (
            <ul className="flex flex-col gap-3">
              {d.items.map((p) => {
                const open = expanded === p.id;
                return (
                  <li key={p.id} className={p.active ? "rounded-2xl border-2 border-primary" : "rounded-2xl border border-line"}>
                    <div className="flex flex-wrap items-center justify-between gap-3 p-4">
                      <button
                        type="button"
                        className="flex items-center gap-2 text-left"
                        aria-expanded={open}
                        aria-controls={`rules-${p.id}`}
                        onClick={() => setExpanded(open ? null : p.id)}
                      >
                        {open ? <ChevronDown className="size-4" aria-hidden /> : <ChevronRight className="size-4" aria-hidden />}
                        <span>
                          <span className="block font-semibold">
                            {p.version} {p.active && <Badge tone="green">Active</Badge>}
                          </span>
                          <span className="block text-xs text-ink-muted">
                            {p.ruleCount} rules
                            {p.approvedBy ? ` · approved by ${p.approvedBy} ${formatDateTime(p.approvedAt)}` : " · not approved"}
                          </span>
                        </span>
                      </button>
                      <div className="flex flex-wrap items-center gap-2">
                        <Badge tone={STATUS_TONE[p.status]}>{humanize(p.status)}</Badge>
                        {(p.status === "draft" || p.status === "fixture_unapproved") && (
                          <Button size="sm" variant="secondary" onClick={() => setApproving(p)} icon={<BadgeCheck className="size-4" aria-hidden />}>
                            Approve
                          </Button>
                        )}
                        {!p.active && p.status !== "retired" && (
                          <Button size="sm" onClick={() => setActivating(p)} icon={<Power className="size-4" aria-hidden />}>
                            Activate
                          </Button>
                        )}
                      </div>
                    </div>
                    {open && (
                      <div id={`rules-${p.id}`} className="border-t border-line px-4 pb-4">
                        <RulesTable rules={p.rules} />
                      </div>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
        </QueryView>
      </Card>
      {approving && <ApproveDialog pack={approving} onClose={() => setApproving(null)} />}
      {activating && <ActivateDialog pack={activating} onClose={() => setActivating(null)} />}
      {creating && <CreatePackDialog onClose={() => setCreating(false)} />}
    </>
  );
}

function describeWhen(w: SafetyRule["when"]): string {
  const parts: string[] = [];
  if (w.anyKeywords?.length) parts.push(`any of: ${w.anyKeywords.join(", ")}`);
  if (w.allKeywords?.length) parts.push(`all of: ${w.allKeywords.join(", ")}`);
  if (w.minSeverity !== undefined) parts.push(`severity ≥ ${w.minSeverity}`);
  if (w.vital) parts.push(`${w.vital.type} ${w.vital.op === "lt" ? "<" : ">"} ${w.vital.value}`);
  if (w.ageGte !== undefined) parts.push(`age ≥ ${w.ageGte}`);
  return parts.join(" · ") || "—";
}

function RulesTable({ rules }: { rules: SafetyRule[] }) {
  if (rules.length === 0) return <p className="pt-3 text-sm text-ink-muted">No rules.</p>;
  return (
    <Table caption="Rules in pack" className="mx-0">
      <thead>
        <tr>
          <Th>Rule</Th>
          <Th>When</Th>
          <Th>Level</Th>
          <Th>Action</Th>
        </tr>
      </thead>
      <tbody>
        {rules.map((r) => (
          <tr key={r.id}>
            <Td>
              <p className="font-medium">{r.title}</p>
              <p className="font-mono text-xs text-ink-muted">{r.id}</p>
              <p className="text-xs text-ink-muted">{r.description}</p>
            </Td>
            <Td className="text-[13px]">{describeWhen(r.when)}</Td>
            <Td>
              <Badge tone={r.level === "emergency" ? "dark" : r.level === "urgent" ? "red" : "neutral"}>{humanize(r.level)}</Badge>
            </Td>
            <Td className="text-[13px]">{humanize(r.action)}</Td>
          </tr>
        ))}
      </tbody>
    </Table>
  );
}

function ApproveDialog({ pack, onClose }: { pack: SafetyRulePack; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [name, setName] = useState("");
  const [reg, setReg] = useState("");
  const [confirm, setConfirm] = useState(false);
  const [errors, setErrors] = useState<{ name?: string; reg?: string }>({});
  const m = useMutation({
    mutationFn: () => api.admin.approveRulePack(pack.id, { approverName: name.trim(), approverRegistration: reg.trim() }),
    onSuccess: () => {
      toast.success("Rule pack approved");
      void qc.invalidateQueries({ queryKey: ["admin", "rule-packs"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Approval failed"),
  });
  return (
    <Dialog
      open
      onClose={onClose}
      title={`Approve ${pack.version}`}
      description="Approval must be given by a registered clinician who reviewed every rule."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            loading={m.isPending}
            disabled={!confirm}
            onClick={() => {
              const next = { name: name.trim() ? undefined : "Approver name is required", reg: reg.trim() ? undefined : "Registration number is required" };
              setErrors(next);
              if (!next.name && !next.reg) m.mutate();
            }}
          >
            Approve pack
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label="Approver name" required error={errors.name}>
          {(id, d) => <Input id={id} data-autofocus aria-describedby={d} aria-invalid={!!errors.name} value={name} onChange={(e) => setName(e.target.value)} />}
        </Field>
        <Field label="Medical registration number" required error={errors.reg}>
          {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!errors.reg} value={reg} onChange={(e) => setReg(e.target.value)} />}
        </Field>
        <label className="flex items-start gap-2 text-sm">
          <input type="checkbox" className="mt-0.5 size-4 accent-[#631D3F]" checked={confirm} onChange={(e) => setConfirm(e.target.checked)} />I confirm the
          approver has clinically reviewed all {pack.ruleCount} rules.
        </label>
      </div>
    </Dialog>
  );
}

function ActivateDialog({ pack, onClose }: { pack: SafetyRulePack; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const m = useMutation({
    mutationFn: () => api.admin.activateRulePack(pack.id),
    onSuccess: () => {
      toast.success(`${pack.version} is now active`);
      void qc.invalidateQueries({ queryKey: ["admin", "rule-packs"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Activation failed"),
  });
  return (
    <Dialog
      open
      onClose={onClose}
      title={`Activate ${pack.version}?`}
      description="The safety engine switches to this pack for every new AI message immediately."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button loading={m.isPending} onClick={() => m.mutate()}>
            Activate
          </Button>
        </>
      }
    >
      {pack.status !== "approved" ? (
        <p role="alert" className="rounded-xl bg-rose-bg p-3 text-sm text-danger-dark">
          This pack is <strong>{humanize(pack.status)}</strong>, not approved. The server may refuse activation, and it must never be active in production.
        </p>
      ) : (
        <p className="text-sm">Approved by {pack.approvedBy}.</p>
      )}
    </Dialog>
  );
}

function CreatePackDialog({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [version, setVersion] = useState("");
  const [text, setText] = useState(RULE_PACK_TEMPLATE);
  const [versionError, setVersionError] = useState<string | null>(null);
  const parsed = useMemo(() => parseRulePackJson(text), [text]);

  const m = useMutation({
    mutationFn: (rules: SafetyRule[]) => api.admin.createRulePack({ version: version.trim(), rules }),
    onSuccess: () => {
      toast.success("Draft rule pack created", "Approve it before activating.");
      void qc.invalidateQueries({ queryKey: ["admin", "rule-packs"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not create pack"),
  });

  return (
    <Dialog
      open
      onClose={onClose}
      size="lg"
      title="New safety rule pack"
      description="Created as a draft. Paste or edit the rules as JSON (an array of SafetyRule)."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            loading={m.isPending}
            disabled={!parsed.ok}
            onClick={() => {
              if (!version.trim()) {
                setVersionError("Version is required");
                return;
              }
              if (parsed.ok) m.mutate(parsed.rules);
            }}
          >
            Create draft
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label="Version" required error={versionError ?? undefined} hint="e.g. 1.0.0-reviewed">
          {(id, d) => (
            <Input
              id={id}
              data-autofocus
              aria-describedby={d}
              value={version}
              onChange={(e) => {
                setVersion(e.target.value);
                setVersionError(null);
              }}
            />
          )}
        </Field>
        <Field label="Rules JSON" required>
          {(id) => (
            <Textarea
              id={id}
              rows={16}
              spellCheck={false}
              aria-invalid={!parsed.ok}
              className="font-mono text-xs"
              value={text}
              onChange={(e) => setText(e.target.value)}
            />
          )}
        </Field>
        <div aria-live="polite">
          {parsed.ok ? (
            <p className="text-sm text-primary-light">Valid: {parsed.rules.length} rules.</p>
          ) : (
            <ul className="list-disc rounded-xl bg-rose-bg py-2 pl-7 pr-3 text-xs text-danger-dark">
              {parsed.errors.map((err, i) => (
                <li key={i}>{err}</li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </Dialog>
  );
}

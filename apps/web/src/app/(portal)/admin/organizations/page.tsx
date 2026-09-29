"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Building2, Download, KeyRound, Pencil, Plus } from "lucide-react";
import { api } from "@/lib/api";
import type { Organization, OrganizationInput } from "@/lib/api/types";
import { codesToCsv } from "@/lib/branding";
import { saveBlob, slug } from "@/lib/download";
import { formatDate, formatNumber } from "@/lib/format";
import { useToast } from "@/components/toast";
import { Button, Card, Dialog, EmptyState, Field, Input, PageHeader, QueryView, Select, StatTile, Textarea } from "@/components/ui";

const KEY = ["admin", "organizations"];
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

const schema = z
  .object({
    name: z.string().trim().min(2, "Name is required").max(120),
    contactName: z.string().trim().min(2, "Contact name is required").max(100),
    contactEmail: z.string().trim().email("Enter a valid email"),
    planCode: z.string().trim().min(1, "Choose a plan"),
    seats: z.coerce.number({ invalid_type_error: "Enter a number" }).int("Whole numbers only").min(1, "At least 1").max(100_000, "At most 100000"),
    validFrom: z.string().regex(DATE_RE, "Enter a start date"),
    validTo: z.string().regex(DATE_RE, "Enter an end date"),
    billingNote: z.string().trim().max(500, "At most 500 characters"),
  })
  .refine((v) => !DATE_RE.test(v.validFrom) || !DATE_RE.test(v.validTo) || v.validTo >= v.validFrom, { path: ["validTo"], message: "End date is before the start date" });
type FormValues = z.input<typeof schema>;
type Parsed = z.output<typeof schema>;

export default function OrganizationsPage() {
  const [editing, setEditing] = useState<Organization | "new" | null>(null);
  const [codesFor, setCodesFor] = useState<Organization | null>(null);
  const query = useQuery({ queryKey: KEY, queryFn: () => api.organizations.list({ limit: 100 }) });
  return (
    <>
      <PageHeader
        title="Company health plans"
        description="Corporate sponsors. Employees redeem single-use codes for a sponsored subscription. Usage is aggregate only (no patient data)."
        actions={
          <Button onClick={() => setEditing("new")} icon={<Plus className="size-4" aria-hidden />}>
            New organization
          </Button>
        }
      />
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<Card><EmptyState icon={<Building2 className="size-6" />} title="No organizations yet" /></Card>}>
        {(d) => (
          <ul className="flex flex-col gap-4">
            {d.items.map((o) => (
              <li key={o.id}>
                <Card
                  title={o.name}
                  subtitle={`${o.contactName} · ${o.contactEmail} · plan ${o.planCode} · ${formatDate(o.validFrom)} – ${formatDate(o.validTo)}`}
                  actions={
                    <>
                      <Button size="sm" variant="secondary" onClick={() => setCodesFor(o)} icon={<KeyRound className="size-4" aria-hidden />} aria-label={`Generate codes for ${o.name}`}>
                        Generate codes
                      </Button>
                      <Button size="sm" variant="ghost" onClick={() => setEditing(o)} icon={<Pencil className="size-4" aria-hidden />} aria-label={`Edit ${o.name}`}>
                        Edit
                      </Button>
                    </>
                  }
                >
                  <Usage org={o} />
                  {o.billingNote && <p className="mt-3 text-xs text-ink-muted">Billing: {o.billingNote}</p>}
                </Card>
              </li>
            ))}
          </ul>
        )}
      </QueryView>
      {editing && <OrgDialog org={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
      {codesFor && <CodesDialog org={codesFor} onClose={() => setCodesFor(null)} />}
    </>
  );
}

function Usage({ org }: { org: Organization }) {
  const q = useQuery({ queryKey: [...KEY, org.id, "usage"], queryFn: () => api.organizations.usage(org.id) });
  if (q.isPending) return <p className="text-sm text-ink-muted">Loading usage…</p>;
  if (q.isError) return <p className="text-sm text-ink-muted">Usage is unavailable.</p>;
  const u = q.data;
  return (
    <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
      <StatTile label="Seats" value={formatNumber(u.seats)} />
      <StatTile label="Codes redeemed" value={formatNumber(u.redeemed)} hint={u.seats ? `${Math.round((u.redeemed / u.seats) * 100)}% of seats` : undefined} />
      <StatTile label="Active members" value={formatNumber(u.activeMembers)} />
      <StatTile label="Consultations" value={formatNumber(u.servicesUsed.appointments)} />
      <StatTile label="Home visits · labs" value={`${formatNumber(u.servicesUsed.homeVisits)} · ${formatNumber(u.servicesUsed.labOrders)}`} />
    </div>
  );
}

function OrgDialog({ org, onClose }: { org: Organization | null; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const plans = useQuery({ queryKey: ["admin", "plans"], queryFn: () => api.plans.list({ limit: 100 }) });
  const form = useForm<FormValues, unknown, Parsed>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: org?.name ?? "",
      contactName: org?.contactName ?? "",
      contactEmail: org?.contactEmail ?? "",
      planCode: org?.planCode ?? "",
      seats: org?.seats ?? 50,
      validFrom: org?.validFrom?.slice(0, 10) ?? "",
      validTo: org?.validTo?.slice(0, 10) ?? "",
      billingNote: org?.billingNote ?? "",
    },
  });
  const { register, handleSubmit, formState } = form;
  const e = formState.errors;
  const m = useMutation({
    mutationFn: (v: Parsed) => {
      const body: OrganizationInput = { name: v.name, contactName: v.contactName, contactEmail: v.contactEmail, planCode: v.planCode, seats: v.seats, validFrom: v.validFrom, validTo: v.validTo };
      if (v.billingNote) body.billingNote = v.billingNote;
      return org ? api.organizations.update(org.id, body) : api.organizations.create(body);
    },
    onSuccess: (o) => {
      toast.success(org ? "Organization updated" : "Organization created", o.name);
      void qc.invalidateQueries({ queryKey: KEY });
      onClose();
    },
    onError: (err) => toast.apiError(err, "Could not save the organization"),
  });
  return (
    <Dialog
      open
      size="lg"
      onClose={onClose}
      title={org ? `Edit ${org.name}` : "New organization"}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="org-form" loading={m.isPending}>
            {org ? "Save changes" : "Create organization"}
          </Button>
        </>
      }
    >
      <form id="org-form" noValidate onSubmit={handleSubmit((v) => m.mutate(v))} className="grid gap-3 sm:grid-cols-2">
        <Field label="Company name" required error={e.name?.message}>
          {(id, d) => <Input id={id} data-autofocus="" aria-describedby={d} aria-invalid={!!e.name} {...register("name")} />}
        </Field>
        <Field label="Plan" required error={e.planCode?.message}>
          {(id, d) => (
            <Select id={id} aria-describedby={d} aria-invalid={!!e.planCode} {...register("planCode")}>
              <option value="">Choose…</option>
              {plans.data?.items.map((p) => (
                <option key={p.code} value={p.code}>
                  {p.name}
                </option>
              ))}
              {org && !plans.data?.items.some((p) => p.code === org.planCode) && <option value={org.planCode}>{org.planCode}</option>}
            </Select>
          )}
        </Field>
        <Field label="Contact name" required error={e.contactName?.message}>
          {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!e.contactName} {...register("contactName")} />}
        </Field>
        <Field label="Contact email" required error={e.contactEmail?.message}>
          {(id, d) => <Input id={id} type="email" aria-describedby={d} aria-invalid={!!e.contactEmail} {...register("contactEmail")} />}
        </Field>
        <Field label="Seats" required error={e.seats?.message}>
          {(id, d) => <Input id={id} type="number" min={1} aria-describedby={d} aria-invalid={!!e.seats} {...register("seats")} />}
        </Field>
        <div />
        <Field label="Valid from" required error={e.validFrom?.message}>
          {(id, d) => <Input id={id} type="date" aria-describedby={d} aria-invalid={!!e.validFrom} {...register("validFrom")} />}
        </Field>
        <Field label="Valid to" required error={e.validTo?.message}>
          {(id, d) => <Input id={id} type="date" aria-describedby={d} aria-invalid={!!e.validTo} {...register("validTo")} />}
        </Field>
        <Field label="Billing note" error={e.billingNote?.message} className="sm:col-span-2">
          {(id, d) => <Textarea id={id} rows={2} aria-describedby={d} {...register("billingNote")} />}
        </Field>
      </form>
    </Dialog>
  );
}

function CodesDialog({ org, onClose }: { org: Organization; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [count, setCount] = useState("25");
  const [error, setError] = useState<string | null>(null);
  const [codes, setCodes] = useState<string[] | null>(null);
  const download = (list: string[]) =>
    saveBlob(new Blob([codesToCsv(org, list)], { type: "text/csv;charset=utf-8" }), `codes-${slug(org.name) || "organization"}-${new Date().toISOString().slice(0, 10)}.csv`);
  const gen = useMutation({
    mutationFn: (n: number) => api.organizations.generateCodes(org.id, n),
    onSuccess: (r) => {
      setCodes(r.codes);
      download(r.codes);
      toast.success(`${r.codes.length} codes generated`, "The CSV was downloaded. Codes are shown only once.");
      void qc.invalidateQueries({ queryKey: [...KEY, org.id, "usage"] });
    },
    onError: (e) => toast.apiError(e, "Could not generate codes"),
  });
  return (
    <Dialog
      open
      onClose={onClose}
      title={`Codes for ${org.name}`}
      description="Single-use, 10-character codes. Share them securely with the company's HR contact."
      footer={
        codes ? (
          <>
            <Button variant="secondary" onClick={() => download(codes)} icon={<Download className="size-4" aria-hidden />}>
              Download CSV again
            </Button>
            <Button onClick={onClose}>Done</Button>
          </>
        ) : (
          <>
            <Button variant="ghost" onClick={onClose}>
              Cancel
            </Button>
            <Button
              loading={gen.isPending}
              onClick={() => {
                const n = Number(count);
                if (!/^\d+$/.test(count.trim()) || n < 1 || n > 500) return setError("Between 1 and 500 codes");
                setError(null);
                gen.mutate(n);
              }}
            >
              Generate & download
            </Button>
          </>
        )
      }
    >
      {codes ? (
        <ul className="grid max-h-72 grid-cols-2 gap-1 overflow-y-auto font-mono text-sm sm:grid-cols-3" aria-label="Generated codes">
          {codes.map((c) => (
            <li key={c}>{c}</li>
          ))}
        </ul>
      ) : (
        <Field label="Number of codes" required error={error ?? undefined} hint="1–500">
          {(id, d) => <Input id={id} data-autofocus="" inputMode="numeric" aria-describedby={d} aria-invalid={!!error} value={count} onChange={(e) => setCount(e.target.value)} />}
        </Field>
      )}
    </Dialog>
  );
}

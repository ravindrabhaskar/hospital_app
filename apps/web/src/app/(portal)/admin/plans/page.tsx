"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, Check, Pencil, Plus, Users } from "lucide-react";
import { api } from "@/lib/api";
import type { Plan } from "@/lib/api/types";
import { formatINR } from "@/lib/format";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, Dialog, EmptyState, Field, Input, PageHeader, QueryView, Textarea } from "@/components/ui";

const PLANS_KEY = ["admin", "plans"];

const int = (min: number, max: number, what: string) =>
  z.coerce
    .number({ invalid_type_error: `Enter ${what}` })
    .int("Whole numbers only")
    .min(min, `At least ${min}`)
    .max(max, `At most ${max}`);

const schema = z.object({
  code: z
    .string()
    .trim()
    .min(2, "Code is required")
    .max(40, "At most 40 characters")
    .regex(/^[a-z][a-z0-9]*(_[a-z0-9]+)*$/, "Lowercase snake_case, e.g. family_basic"),
  name: z.string().trim().min(2, "Name is required").max(80),
  description: z.string().trim().max(500, "At most 500 characters"),
  priceMonthly: int(0, 1_000_000, "a price"),
  priceYearly: int(0, 10_000_000, "a price"),
  benefitsText: z.string(),
  maxMembers: int(1, 20, "a number"),
  homeVisitDiscountPct: int(0, 100, "a percentage"),
  coordinatorIncluded: z.boolean(),
  active: z.boolean(),
});
type FormValues = z.input<typeof schema>;
type ParsedValues = z.output<typeof schema>;

const lines = (t: string) =>
  t
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);

export default function PlansPage() {
  const [editing, setEditing] = useState<Plan | "new" | null>(null);
  const query = useQuery({ queryKey: PLANS_KEY, queryFn: () => api.plans.list({ limit: 100 }) });

  return (
    <>
      <PageHeader
        title="Subscription plans"
        description="Family Care Plans offered to patients. Plans cannot be deleted; switch a plan to inactive to retire it."
        actions={
          <Button onClick={() => setEditing("new")} icon={<Plus className="size-4" aria-hidden />}>
            New plan
          </Button>
        }
      />
      <p role="note" className="mb-5 flex items-start gap-2 rounded-2xl border border-[#f8d9b5] bg-peach-bg px-4 py-3 text-[13px] text-peach-fg">
        <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
        <span>
          <strong>[REQUIRES PRICING VALIDATION]</strong> Current prices are placeholders. Confirm pricing, taxes and benefit terms with
          finance and legal before publishing changes to patients.
        </span>
      </p>
      <QueryView
        query={query}
        isEmpty={(d) => d.items.length === 0}
        empty={
          <Card>
            <EmptyState title="No plans yet" description="Create the first Family Care Plan." />
          </Card>
        }
      >
        {(d) => (
          <ul className="grid gap-4 md:grid-cols-2">
            {d.items.map((p) => (
              <li key={p.code}>
                <PlanCard plan={p} onEdit={() => setEditing(p)} />
              </li>
            ))}
          </ul>
        )}
      </QueryView>
      {editing && <PlanDialog plan={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
    </>
  );
}

function PlanCard({ plan: p, onEdit }: { plan: Plan; onEdit: () => void }) {
  return (
    <Card
      title={p.name}
      subtitle={<span className="font-mono">{p.code}</span>}
      actions={
        <>
          {p.active ? <Badge tone="green">Active</Badge> : <Badge>Inactive</Badge>}
          <Button variant="ghost" size="sm" onClick={onEdit} aria-label={`Edit ${p.name}`} icon={<Pencil className="size-4" aria-hidden />}>
            Edit
          </Button>
        </>
      }
    >
      {p.description && <p className="mb-3 text-sm text-ink-muted">{p.description}</p>}
      <dl className="mb-3 grid grid-cols-2 gap-3 text-sm">
        <div>
          <dt className="text-xs text-ink-muted">Monthly</dt>
          <dd className="text-lg font-semibold tabular-nums">{formatINR(p.priceMonthly)}</dd>
        </div>
        <div>
          <dt className="text-xs text-ink-muted">Yearly</dt>
          <dd className="text-lg font-semibold tabular-nums">{formatINR(p.priceYearly)}</dd>
        </div>
        <div>
          <dt className="text-xs text-ink-muted">Members</dt>
          <dd className="flex items-center gap-1 font-medium">
            <Users className="size-4 text-ink-muted" aria-hidden />
            Up to {p.maxMembers}
          </dd>
        </div>
        <div>
          <dt className="text-xs text-ink-muted">Home-visit discount</dt>
          <dd className="font-medium">{p.homeVisitDiscountPct}%</dd>
        </div>
        <div className="col-span-2">
          <dt className="text-xs text-ink-muted">Care coordinator</dt>
          <dd className="font-medium">{p.coordinatorIncluded ? "Included (auto-assigned)" : "Not included"}</dd>
        </div>
      </dl>
      {p.benefits.length > 0 && (
        <ul className="flex flex-col gap-1 text-sm" aria-label={`Benefits of ${p.name}`}>
          {p.benefits.map((b, i) => (
            <li key={i} className="flex items-start gap-2">
              <Check className="mt-0.5 size-4 shrink-0 text-primary-light" aria-hidden />
              {b}
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}

function PlanDialog({ plan, onClose }: { plan: Plan | null; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const isEdit = !!plan;
  const form = useForm<FormValues, unknown, ParsedValues>({
    resolver: zodResolver(schema),
    defaultValues: plan
      ? {
          code: plan.code,
          name: plan.name,
          description: plan.description ?? "",
          priceMonthly: plan.priceMonthly,
          priceYearly: plan.priceYearly,
          benefitsText: plan.benefits.join("\n"),
          maxMembers: plan.maxMembers,
          homeVisitDiscountPct: plan.homeVisitDiscountPct,
          coordinatorIncluded: plan.coordinatorIncluded,
          active: plan.active,
        }
      : {
          code: "",
          name: "",
          description: "",
          priceMonthly: 0,
          priceYearly: 0,
          benefitsText: "",
          maxMembers: 4,
          homeVisitDiscountPct: 0,
          coordinatorIncluded: false,
          active: true,
        },
  });
  const { register, handleSubmit, formState } = form;
  const errors = formState.errors;

  const m = useMutation({
    mutationFn: (v: ParsedValues) => {
      const body = {
        name: v.name,
        description: v.description,
        priceMonthly: v.priceMonthly,
        priceYearly: v.priceYearly,
        benefits: lines(v.benefitsText),
        maxMembers: v.maxMembers,
        coordinatorIncluded: v.coordinatorIncluded,
        homeVisitDiscountPct: v.homeVisitDiscountPct,
        active: v.active,
      };
      return plan ? api.plans.update(plan.code, body) : api.plans.create({ code: v.code, ...body });
    },
    onSuccess: (p) => {
      toast.success(isEdit ? "Plan updated" : "Plan created", p.name);
      void qc.invalidateQueries({ queryKey: PLANS_KEY });
      onClose();
    },
    onError: (e) => toast.apiError(e, isEdit ? "Could not update the plan" : "Could not create the plan"),
  });

  const onSubmit = handleSubmit((v) => m.mutate(v));

  return (
    <Dialog
      open
      size="lg"
      onClose={onClose}
      title={isEdit ? `Edit ${plan.name}` : "New subscription plan"}
      description="Prices are whole rupees. [REQUIRES PRICING VALIDATION]"
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="plan-form" loading={m.isPending}>
            {isEdit ? "Save changes" : "Create plan"}
          </Button>
        </>
      }
    >
      <form id="plan-form" noValidate onSubmit={onSubmit} className="grid gap-3 sm:grid-cols-2">
        <Field label="Code" required error={errors.code?.message} hint={isEdit ? "The code cannot be changed." : "Lowercase snake_case, e.g. family_basic"}>
          {(id, d) => (
            <Input
              id={id}
              className={isEdit ? "bg-mint-50 font-mono" : "font-mono"}
              aria-describedby={d}
              aria-invalid={!!errors.code}
              readOnly={isEdit}
              aria-readonly={isEdit || undefined}
              data-autofocus={isEdit ? undefined : ""}
              {...register("code")}
            />
          )}
        </Field>
        <Field label="Name" required error={errors.name?.message}>
          {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!errors.name} data-autofocus={isEdit ? "" : undefined} {...register("name")} />}
        </Field>
        <Field label="Description" error={errors.description?.message} className="sm:col-span-2">
          {(id, d) => <Textarea id={id} rows={2} aria-describedby={d} aria-invalid={!!errors.description} {...register("description")} />}
        </Field>
        <Field label="Price per month (₹)" required error={errors.priceMonthly?.message}>
          {(id, d) => <Input id={id} type="number" min={0} step={1} inputMode="numeric" aria-describedby={d} aria-invalid={!!errors.priceMonthly} {...register("priceMonthly")} />}
        </Field>
        <Field label="Price per year (₹)" required error={errors.priceYearly?.message}>
          {(id, d) => <Input id={id} type="number" min={0} step={1} inputMode="numeric" aria-describedby={d} aria-invalid={!!errors.priceYearly} {...register("priceYearly")} />}
        </Field>
        <Field label="Max members" required error={errors.maxMembers?.message} hint="1–20 family members">
          {(id, d) => <Input id={id} type="number" min={1} max={20} step={1} aria-describedby={d} aria-invalid={!!errors.maxMembers} {...register("maxMembers")} />}
        </Field>
        <Field label="Home-visit discount (%)" required error={errors.homeVisitDiscountPct?.message} hint="0–100">
          {(id, d) => (
            <Input id={id} type="number" min={0} max={100} step={1} aria-describedby={d} aria-invalid={!!errors.homeVisitDiscountPct} {...register("homeVisitDiscountPct")} />
          )}
        </Field>
        <Field label="Benefits" hint="One per line" className="sm:col-span-2">
          {(id, d) => <Textarea id={id} rows={4} aria-describedby={d} {...register("benefitsText")} />}
        </Field>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" className="size-4 accent-[#0B5D45]" {...register("coordinatorIncluded")} />
          Dedicated care coordinator included
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" className="size-4 accent-[#0B5D45]" {...register("active")} />
          Active (offered to patients)
        </label>
      </form>
    </Dialog>
  );
}

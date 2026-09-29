"use client";

import { useState } from "react";
import { useForm, useWatch } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Palette, Pencil, Plus } from "lucide-react";
import { api } from "@/lib/api";
import type { Tenant } from "@/lib/api/types";
import { HEX_RE, contrastRatio, readableTextOn, tenantSchema, toTenantInput, type TenantFormValues } from "@/lib/branding";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, Dialog, EmptyState, Field, Input, PageHeader, QueryView } from "@/components/ui";

const KEY = ["admin", "tenants"];

export default function TenantsPage() {
  const [editing, setEditing] = useState<Tenant | "new" | null>(null);
  const query = useQuery({ queryKey: KEY, queryFn: () => api.tenants.list({ limit: 100 }) });
  return (
    <>
      <PageHeader
        title="Hospital branding"
        description="White-label tenants. The apps built with a tenant code show its name, colour and logo, plus “Powered by CareCompanion”."
        actions={
          <Button onClick={() => setEditing("new")} icon={<Plus className="size-4" aria-hidden />}>
            New tenant
          </Button>
        }
      />
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<Card><EmptyState icon={<Palette className="size-6" />} title="No tenants yet" /></Card>}>
        {(d) => (
          <ul className="grid gap-4 md:grid-cols-2">
            {d.items.map((t) => (
              <li key={t.id}>
                <Card
                  title={t.displayName}
                  subtitle={<span className="font-mono">{t.code}</span>}
                  actions={
                    <Button size="sm" variant="ghost" onClick={() => setEditing(t)} aria-label={`Edit ${t.displayName}`} icon={<Pencil className="size-4" aria-hidden />}>
                      Edit
                    </Button>
                  }
                >
                  <BrandPreview name={t.displayName} color={t.primaryColor} logoUrl={t.logoUrl ?? null} phone={t.supportPhone ?? ""} />
                  <p className="mt-2 text-xs text-ink-muted">
                    {t.facilityIds.length} {t.facilityIds.length === 1 ? "facility" : "facilities"}
                    {t.supportEmail ? ` · ${t.supportEmail}` : ""}
                  </p>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </QueryView>
      {editing && <TenantDialog tenant={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
    </>
  );
}

/** Mock of the patient app header with the tenant's branding. */
function BrandPreview({ name, color, logoUrl, phone }: { name: string; color: string; logoUrl: string | null; phone: string }) {
  const valid = HEX_RE.test(color);
  const bg = valid ? color : "#0B5D45";
  const fg = readableTextOn(bg);
  const initials = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join("");
  return (
    <figure aria-label="Branding preview" className="overflow-hidden rounded-2xl border border-line">
      <div className="flex items-center gap-3 px-4 py-3" style={{ background: bg, color: fg }}>
        {logoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={logoUrl} alt="" className="size-9 rounded-lg bg-white object-contain p-0.5" />
        ) : (
          <span aria-hidden className="flex size-9 items-center justify-center rounded-lg bg-white/90 text-sm font-bold" style={{ color: bg }}>
            {initials || "?"}
          </span>
        )}
        <div className="min-w-0">
          <p className="truncate font-semibold">{name || "Display name"}</p>
          <p className="text-[11px] opacity-80">Powered by CareCompanion</p>
        </div>
      </div>
      <div className="flex items-center justify-between gap-2 bg-white px-4 py-3">
        <span className="rounded-full px-3 py-1 text-xs font-semibold" style={{ background: bg, color: fg }}>
          Book a visit
        </span>
        <span className="text-xs text-ink-muted">{phone || "Support number"}</span>
      </div>
    </figure>
  );
}

function TenantDialog({ tenant, onClose }: { tenant: Tenant | null; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const form = useForm<TenantFormValues>({
    resolver: zodResolver(tenantSchema),
    defaultValues: {
      code: tenant?.code ?? "",
      displayName: tenant?.displayName ?? "",
      primaryColor: tenant?.primaryColor ?? "#0B5D45",
      logoMediaId: tenant?.logoMediaId ?? "",
      facilityIdsText: tenant?.facilityIds.join("\n") ?? "",
      supportPhone: tenant?.supportPhone ?? "",
      supportEmail: tenant?.supportEmail ?? "",
    },
  });
  const { register, handleSubmit, formState, control, setValue } = form;
  const e = formState.errors;
  const [name, color, phone] = useWatch({ control, name: ["displayName", "primaryColor", "supportPhone"] });
  const validColor = HEX_RE.test(color ?? "");
  const whiteContrast = validColor ? contrastRatio(color, "#ffffff") : 0;

  const m = useMutation({
    mutationFn: (v: TenantFormValues) => {
      const input = toTenantInput(tenantSchema.parse(v));
      return tenant ? api.tenants.update(tenant.id, input) : api.tenants.create(input);
    },
    onSuccess: (t) => {
      toast.success(tenant ? "Tenant updated" : "Tenant created", t.displayName);
      void qc.invalidateQueries({ queryKey: KEY });
      onClose();
    },
    onError: (err) => toast.apiError(err, "Could not save the tenant"),
  });

  return (
    <Dialog
      open
      size="lg"
      onClose={onClose}
      title={tenant ? `Edit ${tenant.displayName}` : "New tenant"}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="tenant-form" loading={m.isPending}>
            {tenant ? "Save changes" : "Create tenant"}
          </Button>
        </>
      }
    >
      <div className="grid gap-5 md:grid-cols-[minmax(0,1fr)_260px]">
        <form id="tenant-form" noValidate onSubmit={handleSubmit((v) => m.mutate(v))} className="grid gap-3 sm:grid-cols-2">
          <Field label="Code" required error={e.code?.message} hint={tenant ? "Used in app builds; cannot change." : "Used as TENANT_CODE in app builds"}>
            {(id, d) => <Input id={id} className="font-mono" readOnly={!!tenant} data-autofocus={tenant ? undefined : ""} aria-describedby={d} aria-invalid={!!e.code} {...register("code")} />}
          </Field>
          <Field label="Display name" required error={e.displayName?.message}>
            {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!e.displayName} {...register("displayName")} />}
          </Field>
          <Field label="Primary colour" required error={e.primaryColor?.message} hint={validColor && whiteContrast < 4.5 ? "Low contrast with white text; dark text will be used." : "#RRGGBB"}>
            {(id, d) => (
              <div className="flex items-center gap-2">
                <input
                  type="color"
                  aria-label="Pick primary colour"
                  className="h-10 w-12 shrink-0 cursor-pointer rounded-lg border border-line bg-white p-1"
                  value={validColor ? color : "#0b5d45"}
                  onChange={(ev) => setValue("primaryColor", ev.target.value.toUpperCase(), { shouldValidate: true, shouldDirty: true })}
                />
                <Input id={id} className="font-mono" aria-describedby={d} aria-invalid={!!e.primaryColor} {...register("primaryColor")} />
              </div>
            )}
          </Field>
          <Field label="Logo media id" error={e.logoMediaId?.message} hint="Optional. The id of an uploaded logo file (the contract's logoMediaId).">
            {(id, d) => <Input id={id} className="font-mono" aria-describedby={d} {...register("logoMediaId")} />}
          </Field>
          <Field label="Support phone" error={e.supportPhone?.message}>
            {(id, d) => <Input id={id} type="tel" aria-describedby={d} aria-invalid={!!e.supportPhone} {...register("supportPhone")} />}
          </Field>
          <Field label="Support email" error={e.supportEmail?.message}>
            {(id, d) => <Input id={id} type="email" aria-describedby={d} aria-invalid={!!e.supportEmail} {...register("supportEmail")} />}
          </Field>
          <Field label="Facility ids" hint="One per line. Discharges from these facilities carry the tenant." className="sm:col-span-2">
            {(id, d) => <textarea id={id} rows={3} aria-describedby={d} className="w-full rounded-xl border border-line bg-white px-3.5 py-2 font-mono text-xs" {...register("facilityIdsText")} />}
          </Field>
        </form>
        <div className="flex flex-col gap-2">
          <p className="text-[13px] font-medium">Live preview</p>
          <BrandPreview name={name ?? ""} color={color ?? ""} logoUrl={tenant?.logoUrl ?? null} phone={phone ?? ""} />
          {validColor && (
            <Badge tone={whiteContrast >= 4.5 ? "green" : "amber"}>Contrast with white {whiteContrast.toFixed(1)}:1</Badge>
          )}
          <p className="text-[11px] text-ink-muted">The logo appears once the API resolves the media id to a URL.</p>
        </div>
      </div>
    </Dialog>
  );
}

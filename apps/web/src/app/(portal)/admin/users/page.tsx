"use client";

import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Ban, KeyRound, Search, ShieldCheck, UserPlus } from "lucide-react";
import { api } from "@/lib/api";
import { ALL_ROLES, type AdminUser, type CreateStaffInput, type Role } from "@/lib/api/types";
import { formatDateTime } from "@/lib/format";
import { useAuth } from "@/lib/auth";
import { ROLE_LABELS, STAFF_ROLES, hasAnyRole, isSuperAdmin } from "@/lib/roles";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, Dialog, EmptyState, Field, Input, PageHeader, QueryView, Select, Table, Td, Th } from "@/components/ui";

export default function UsersPage() {
  const { user: me } = useAuth();
  const [q, setQ] = useState("");
  const [debounced, setDebounced] = useState("");
  const [role, setRole] = useState<Role | "">("");
  const [editing, setEditing] = useState<AdminUser | null>(null);
  const [disabling, setDisabling] = useState<AdminUser | null>(null);
  const [resettingMfa, setResettingMfa] = useState<AdminUser | null>(null);
  const canResetMfa = isSuperAdmin(me?.roles ?? []);
  const [adding, setAdding] = useState(false);

  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(q.trim()), 300);
    return () => window.clearTimeout(t);
  }, [q]);

  const query = useQuery({
    queryKey: ["admin", "users", debounced, role],
    queryFn: () => api.admin.users({ q: debounced || undefined, role: role || undefined, limit: 100 }),
  });

  return (
    <>
      <PageHeader
        title="Users & staff"
        description="Manage roles and access. Disabling a user revokes all their sessions."
        actions={
          <Button onClick={() => setAdding(true)} icon={<UserPlus className="size-4" aria-hidden />}>
            Add staff
          </Button>
        }
      />
      <Card>
        <div className="mb-4 flex flex-wrap gap-3">
          <div className="relative w-full max-w-sm">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-ink-muted" aria-hidden />
            <label htmlFor="user-search" className="sr-only">
              Search users
            </label>
            <Input id="user-search" type="search" placeholder="Search name or phone" value={q} onChange={(e) => setQ(e.target.value)} className="pl-9" />
          </div>
          <label htmlFor="role-filter" className="sr-only">
            Filter by role
          </label>
          <Select id="role-filter" value={role} onChange={(e) => setRole(e.target.value as Role | "")} className="w-48">
            <option value="">All roles</option>
            {ALL_ROLES.map((r) => (
              <option key={r} value={r}>
                {ROLE_LABELS[r]}
              </option>
            ))}
          </Select>
        </div>
        <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No users found" />}>
          {(d) => (
            <Table caption="Users">
              <thead>
                <tr>
                  <Th>User</Th>
                  <Th>Roles</Th>
                  <Th>Status</Th>
                  <Th>Last login</Th>
                  <Th className="text-right">Actions</Th>
                </tr>
              </thead>
              <tbody>
                {d.items.map((u) => (
                  <tr key={u.id}>
                    <Td>
                      <p className="font-semibold">{u.name ?? "Unnamed"}</p>
                      <p className="text-xs text-ink-muted">{u.phone}</p>
                    </Td>
                    <Td>
                      <div className="flex flex-wrap gap-1">
                        {u.roles.map((r) => (
                          <Badge key={r} tone={r === "super_admin" ? "lavender" : r === "patient" ? "neutral" : "green"}>
                            {ROLE_LABELS[r] ?? r}
                          </Badge>
                        ))}
                      </div>
                    </Td>
                    <Td>
                      <Badge tone={u.status === "active" ? "green" : "red"}>{u.status === "active" ? "Active" : "Disabled"}</Badge>
                    </Td>
                    <Td className="whitespace-nowrap text-[13px]">{u.lastLoginAt ? formatDateTime(u.lastLoginAt) : "Never"}</Td>
                    <Td className="text-right">
                      <div className="flex justify-end gap-1.5">
                        <Button size="sm" variant="secondary" onClick={() => setEditing(u)} icon={<ShieldCheck className="size-4" aria-hidden />} aria-label={`Edit roles for ${u.name ?? u.phone}`}>
                          Roles
                        </Button>
                        {canResetMfa && hasAnyRole(u.roles, STAFF_ROLES) && (
                          <Button size="sm" variant="ghost" onClick={() => setResettingMfa(u)} icon={<KeyRound className="size-4" aria-hidden />} aria-label={`Reset MFA for ${u.name ?? u.phone}`}>
                            Reset MFA
                          </Button>
                        )}
                        {u.status === "active" && u.id !== me?.id && (
                          <Button size="sm" variant="ghost" onClick={() => setDisabling(u)} icon={<Ban className="size-4" aria-hidden />} aria-label={`Disable ${u.name ?? u.phone}`}>
                            Disable
                          </Button>
                        )}
                      </div>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </QueryView>
      </Card>
      {editing && <RolesDialog user={editing} onClose={() => setEditing(null)} isSelf={editing.id === me?.id} />}
      {disabling && <DisableDialog user={disabling} onClose={() => setDisabling(null)} />}
      {resettingMfa && <ResetMfaDialog user={resettingMfa} isSelf={resettingMfa.id === me?.id} onClose={() => setResettingMfa(null)} />}
      {adding && <AddStaffDialog onClose={() => setAdding(false)} />}
    </>
  );
}

function RoleCheckboxes({ value, onChange, disabledRoles = [] }: { value: Role[]; onChange: (r: Role[]) => void; disabledRoles?: Role[] }) {
  return (
    <fieldset>
      <legend className="mb-2 text-[13px] font-medium">Roles</legend>
      <div className="grid grid-cols-2 gap-2">
        {ALL_ROLES.map((r) => (
          <label key={r} className="flex items-center gap-2 rounded-xl border border-line px-3 py-2 text-sm has-[:checked]:border-primary has-[:checked]:bg-mint-50">
            <input
              type="checkbox"
              className="size-4 accent-[#0B5D45]"
              checked={value.includes(r)}
              disabled={disabledRoles.includes(r)}
              onChange={(e) => onChange(e.target.checked ? [...value, r] : value.filter((x) => x !== r))}
            />
            {ROLE_LABELS[r]}
          </label>
        ))}
      </div>
    </fieldset>
  );
}

function RolesDialog({ user, onClose, isSelf }: { user: AdminUser; onClose: () => void; isSelf: boolean }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [roles, setRoles] = useState<Role[]>(user.roles);
  const m = useMutation({
    mutationFn: () => api.admin.setRoles(user.id, roles),
    onSuccess: () => {
      toast.success("Roles updated");
      void qc.invalidateQueries({ queryKey: ["admin", "users"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not update roles"),
  });
  return (
    <Dialog
      open
      onClose={onClose}
      title={`Roles for ${user.name ?? user.phone}`}
      description={isSelf ? "You cannot remove your own super admin role here." : undefined}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button loading={m.isPending} disabled={roles.length === 0} onClick={() => m.mutate()}>
            Save roles
          </Button>
        </>
      }
    >
      <RoleCheckboxes value={roles} onChange={setRoles} disabledRoles={isSelf ? ["super_admin"] : []} />
      {roles.length === 0 && <p className="mt-2 text-xs text-danger-dark">Select at least one role.</p>}
    </Dialog>
  );
}

function DisableDialog({ user, onClose }: { user: AdminUser; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const m = useMutation({
    mutationFn: () => api.admin.disableUser(user.id),
    onSuccess: () => {
      toast.success("User disabled", "All sessions were revoked.");
      void qc.invalidateQueries({ queryKey: ["admin", "users"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not disable user"),
  });
  return (
    <Dialog
      open
      onClose={onClose}
      title="Disable user?"
      description={`${user.name ?? user.phone} will be signed out everywhere and cannot sign in.`}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="danger" loading={m.isPending} onClick={() => m.mutate()}>
            Disable user
          </Button>
        </>
      }
    >
      <p className="text-sm text-ink-muted">This action is audited.</p>
    </Dialog>
  );
}

function ResetMfaDialog({ user, isSelf, onClose }: { user: AdminUser; isSelf: boolean; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const m = useMutation({
    mutationFn: () => api.admin.resetMfa(user.id),
    onSuccess: () => {
      toast.success("MFA reset", `${user.name ?? user.phone} will set up a new authenticator at next sign-in.`);
      void qc.invalidateQueries({ queryKey: ["admin", "users"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not reset MFA"),
  });
  return (
    <Dialog
      open
      onClose={onClose}
      title="Reset MFA?"
      description={`Removes the authenticator app and recovery codes for ${user.name ?? user.phone}.`}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="danger" loading={m.isPending} onClick={() => m.mutate()}>
            Reset MFA
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-2 text-sm text-ink-muted">
        <p>Only do this after verifying the person&apos;s identity out of band (for example a call to their registered number).</p>
        <p>They must enrol a new authenticator app at their next sign-in. This action is audited.</p>
        {isSelf && <p className="font-semibold text-danger-dark">This is your own account.</p>}
      </div>
    </Dialog>
  );
}

const staffSchema = z
  .object({
    phone: z.string().trim().regex(/^\+[1-9]\d{7,14}$/, "International format, e.g. +919800000601"),
    name: z.string().trim().min(2, "Name is required"),
    roles: z.array(z.enum(["patient", "doctor", "provider", "coordinator", "ops_admin", "super_admin"])).min(1, "Pick at least one role"),
    providerType: z.string().optional(),
    qualification: z.string().trim().optional(),
    specialty: z.string().optional(),
    registrationNumber: z.string().trim().optional(),
    zoneIds: z.array(z.string()),
    capabilities: z.array(z.string()),
    credentialExpiresAt: z.string().optional(),
  })
  .superRefine((v, ctx) => {
    const needsProfile = v.roles.includes("doctor") || v.roles.includes("provider");
    if (!needsProfile) return;
    if (!v.qualification) ctx.addIssue({ code: "custom", path: ["qualification"], message: "Qualification is required" });
    if (!v.registrationNumber) ctx.addIssue({ code: "custom", path: ["registrationNumber"], message: "Registration number is required" });
    if (!v.credentialExpiresAt) ctx.addIssue({ code: "custom", path: ["credentialExpiresAt"], message: "Credential expiry is required" });
    if (v.roles.includes("doctor") && !v.specialty) ctx.addIssue({ code: "custom", path: ["specialty"], message: "Specialty is required for doctors" });
    if (v.roles.includes("provider") && !v.providerType) ctx.addIssue({ code: "custom", path: ["providerType"], message: "Provider type is required" });
  });
type StaffValues = z.infer<typeof staffSchema>;

function AddStaffDialog({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const form = useForm<StaffValues>({
    resolver: zodResolver(staffSchema),
    defaultValues: { phone: "+91", name: "", roles: ["coordinator"], providerType: "nurse", qualification: "", specialty: "", registrationNumber: "", zoneIds: [], capabilities: [], credentialExpiresAt: "" },
  });
  const { register, handleSubmit, watch, setValue, formState } = form;
  const e = formState.errors;
  const roles = watch("roles");
  const zoneIds = watch("zoneIds");
  const capabilities = watch("capabilities");
  const isDoctor = roles.includes("doctor");
  const isProvider = roles.includes("provider");
  const needsProfile = isDoctor || isProvider;

  const zones = useQuery({ queryKey: ["admin", "zones"], queryFn: () => api.admin.zones({ limit: 100 }), enabled: needsProfile });
  const specialties = useQuery({ queryKey: ["specialties"], queryFn: () => api.reference.specialties(), enabled: isDoctor, staleTime: Infinity });
  const services = useQuery({ queryKey: ["home-visit-services"], queryFn: () => api.reference.homeVisitServices(), enabled: isProvider, staleTime: Infinity });

  const create = useMutation({
    mutationFn: (input: CreateStaffInput) => api.admin.createStaff(input),
    onSuccess: () => {
      toast.success("Staff user created");
      void qc.invalidateQueries({ queryKey: ["admin", "users"] });
      onClose();
    },
    onError: (err) => toast.apiError(err, "Could not create staff user"),
  });

  const submit = handleSubmit((v) => {
    const input: CreateStaffInput = { phone: v.phone, name: v.name, roles: v.roles };
    if (v.roles.includes("doctor") || v.roles.includes("provider")) {
      input.provider = {
        // Contract leaves `type` open for doctors; we send "doctor" when the user is not a field provider.
        type: v.roles.includes("provider") ? (v.providerType ?? "nurse") : "doctor",
        qualification: v.qualification ?? "",
        ...(v.roles.includes("doctor") && v.specialty ? { specialty: v.specialty } : {}),
        registrationNumber: v.registrationNumber ?? "",
        zoneIds: v.zoneIds,
        capabilities: v.capabilities,
        credentialExpiresAt: new Date(`${v.credentialExpiresAt}T23:59:59+05:30`).toISOString(),
      };
    }
    create.mutate(input);
  });

  const toggle = (field: "zoneIds" | "capabilities", value: string, on: boolean) => {
    const cur = field === "zoneIds" ? zoneIds : capabilities;
    setValue(field, on ? [...cur, value] : cur.filter((x) => x !== value), { shouldValidate: true });
  };

  return (
    <Dialog
      open
      onClose={onClose}
      title="Add staff"
      size="lg"
      description="Creates or upgrades a user with staff roles. Staff sign in with OTP; MFA is required."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button loading={create.isPending} onClick={() => void submit()}>
            Create staff user
          </Button>
        </>
      }
    >
      <form onSubmit={submit} noValidate className="flex flex-col gap-4">
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Phone" required error={e.phone?.message}>
            {(id, d) => <Input id={id} data-autofocus type="tel" aria-describedby={d} aria-invalid={!!e.phone} {...register("phone")} />}
          </Field>
          <Field label="Full name" required error={e.name?.message}>
            {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!e.name} {...register("name")} />}
          </Field>
        </div>
        <RoleCheckboxes value={roles} onChange={(r) => setValue("roles", r, { shouldValidate: true })} />
        {e.roles?.message && <p className="text-xs text-danger-dark">{e.roles.message}</p>}

        {needsProfile && (
          <fieldset className="grid gap-3 rounded-xl border border-line p-3 sm:grid-cols-2">
            <legend className="px-1 text-sm font-semibold">{isDoctor ? "Doctor profile" : "Provider profile"}</legend>
            {isProvider && (
              <Field label="Provider type" required error={e.providerType?.message}>
                {(id) => (
                  <Select id={id} {...register("providerType")}>
                    <option value="nurse">Nurse</option>
                    <option value="technician">Technician</option>
                    <option value="intern">Intern</option>
                    <option value="physiotherapist">Physiotherapist</option>
                  </Select>
                )}
              </Field>
            )}
            {isDoctor && (
              <Field label="Specialty" required error={e.specialty?.message}>
                {(id, d) => (
                  <Select id={id} aria-describedby={d} {...register("specialty")}>
                    <option value="">Select…</option>
                    {(specialties.data?.items ?? []).map((s) => (
                      <option key={s.code} value={s.code}>
                        {s.name}
                      </option>
                    ))}
                  </Select>
                )}
              </Field>
            )}
            <Field label="Qualification" required error={e.qualification?.message}>
              {(id, d) => <Input id={id} aria-describedby={d} placeholder={isDoctor ? "MBBS, MD" : "GNM"} {...register("qualification")} />}
            </Field>
            <Field label="Registration number" required error={e.registrationNumber?.message}>
              {(id, d) => <Input id={id} aria-describedby={d} {...register("registrationNumber")} />}
            </Field>
            <Field label="Credential expires on" required error={e.credentialExpiresAt?.message}>
              {(id, d) => <Input id={id} type="date" aria-describedby={d} {...register("credentialExpiresAt")} />}
            </Field>
            <fieldset className="sm:col-span-2">
              <legend className="mb-1 text-[13px] font-medium">Service zones</legend>
              {zones.isPending ? (
                <p className="text-xs text-ink-muted">Loading zones…</p>
              ) : (zones.data?.items ?? []).length === 0 ? (
                <p className="text-xs text-ink-muted">No zones available.</p>
              ) : (
                <div className="flex flex-wrap gap-2">
                  {zones.data!.items.map((z) => (
                    <label key={z.id} className="flex items-center gap-2 rounded-full border border-line px-3 py-1 text-sm">
                      <input type="checkbox" className="accent-[#0B5D45]" checked={zoneIds.includes(z.id)} onChange={(ev) => toggle("zoneIds", z.id, ev.target.checked)} />
                      {z.name}
                    </label>
                  ))}
                </div>
              )}
            </fieldset>
            {isProvider && (
              <fieldset className="sm:col-span-2">
                <legend className="mb-1 text-[13px] font-medium">Capabilities (home-visit services)</legend>
                <div className="flex flex-wrap gap-2">
                  {(services.data?.items ?? []).map((s) => (
                    <label key={s.code} className="flex items-center gap-2 rounded-full border border-line px-3 py-1 text-sm">
                      <input type="checkbox" className="accent-[#0B5D45]" checked={capabilities.includes(s.code)} onChange={(ev) => toggle("capabilities", s.code, ev.target.checked)} />
                      {s.name}
                    </label>
                  ))}
                </div>
              </fieldset>
            )}
          </fieldset>
        )}
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}

"use client";

import { useEffect, useId, useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { BadgeCheck, Building2, CheckCircle2, Hospital, Send, Siren } from "lucide-react";
import { api } from "@/lib/api";
import type { Appointment, FacilityType, Referral, ReferralInput, ReferralStatus } from "@/lib/api/types";
import { slug } from "@/lib/download";
import { formatDateTime, humanize } from "@/lib/format";
import { BlobButton } from "./blob-actions";
import { useToast } from "./toast";
import { Badge, Button, Dialog, EmptyState, ErrorState, Field, Input, LoadingState, QueryView, Select, Textarea, cx, type Tone } from "./ui";

const FACILITY_TYPES: { value: "" | FacilityType; label: string }[] = [
  { value: "", label: "All types" },
  { value: "hospital", label: "Hospital" },
  { value: "clinic", label: "Clinic" },
  { value: "lab", label: "Lab" },
];

const STATUS_TONE: Record<ReferralStatus, Tone> = {
  created: "sky",
  sent: "lavender",
  accepted: "amber",
  completed: "green",
  cancelled: "neutral",
};

const NEXT_STATUSES: Exclude<ReferralStatus, "created">[] = ["sent", "accepted", "completed", "cancelled"];

function useDebounced<T>(value: T, ms = 300): T {
  const [v, setV] = useState(value);
  useEffect(() => {
    const t = window.setTimeout(() => setV(value), ms);
    return () => window.clearTimeout(t);
  }, [value, ms]);
  return v;
}

function letterFileName(r: Referral) {
  return `referral-${slug(r.patientName) || "patient"}-${slug(r.facility.name) || "facility"}.pdf`;
}

function LetterButton({ r, label = "Download letter" }: { r: Referral; label?: string }) {
  return (
    <BlobButton
      load={() => api.records.file(r.letterRecordId)}
      fileName={letterFileName(r)}
      label={label}
      errorTitle="Could not download the referral letter"
      aria-label={`${label}: referral to ${r.facility.name}`}
    />
  );
}

export function UrgencyBadge({ urgency }: { urgency: Referral["urgency"] }) {
  return urgency === "urgent" ? (
    <Badge tone="red" icon={<Siren className="size-3" aria-hidden />}>
      Urgent
    </Badge>
  ) : (
    <Badge tone="neutral">Routine</Badge>
  );
}

export function ReferralStatusBadge({ status }: { status: ReferralStatus }) {
  return <Badge tone={STATUS_TONE[status] ?? "neutral"}>{humanize(status)}</Badge>;
}

/** Header action: "Refer to hospital". Enabled only while the consultation is in progress or completed. */
export function ReferralButton({ appt }: { appt: Appointment }) {
  const [open, setOpen] = useState(false);
  const enabled = appt.status === "in_progress" || appt.status === "completed";
  return (
    <>
      <Button
        variant="secondary"
        size="sm"
        disabled={!enabled}
        title={enabled ? undefined : "Available once the consultation has started"}
        onClick={() => setOpen(true)}
        icon={<Hospital className="size-4" aria-hidden />}
      >
        Refer to hospital
      </Button>
      <Dialog
        open={open}
        onClose={() => setOpen(false)}
        title="Refer to hospital"
        description={`Creates a referral letter for ${appt.patientName} and notifies the patient.`}
        size="lg"
      >
        <ReferralForm appt={appt} onDone={() => setOpen(false)} />
      </Dialog>
    </>
  );
}

function ReferralForm({ appt, onDone }: { appt: Appointment; onDone: () => void }) {
  const toast = useToast();
  const qc = useQueryClient();
  const uid = useId();
  const [q, setQ] = useState("");
  const [type, setType] = useState<"" | FacilityType>("");
  const [facilityId, setFacilityId] = useState<string>("");
  const [specialty, setSpecialty] = useState("");
  const [urgency, setUrgency] = useState<"routine" | "urgent">("routine");
  const [reason, setReason] = useState("");
  const [summary, setSummary] = useState("");
  const [errors, setErrors] = useState<{ facility?: string; reason?: string }>({});
  const [created, setCreated] = useState<Referral | null>(null);
  const debouncedQ = useDebounced(q.trim());

  const facilities = useQuery({
    queryKey: ["facilities", debouncedQ, type],
    queryFn: () => api.facilities.list({ q: debouncedQ || undefined, type: type || undefined, limit: 20 }),
  });
  const specialties = useQuery({ queryKey: ["specialties"], queryFn: () => api.reference.specialties(), staleTime: Infinity });

  const create = useMutation({
    mutationFn: (input: ReferralInput) => api.referrals.create(input),
    onSuccess: (r) => {
      setCreated(r);
      toast.success("Referral created", `Referred to ${r.facility.name}.`);
      void qc.invalidateQueries({ queryKey: ["referrals", appt.patientId] });
      void qc.invalidateQueries({ queryKey: ["episode", appt.careEpisodeId] });
    },
    onError: (e) => toast.apiError(e, "Could not create the referral"),
  });

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const next: typeof errors = {};
    if (!facilityId) next.facility = "Choose a facility";
    if (reason.trim().length < 3) next.reason = "Reason is required";
    setErrors(next);
    if (next.facility || next.reason) {
      document.getElementById(next.facility ? `${uid}-search` : `${uid}-reason`)?.focus();
      return;
    }
    const input: ReferralInput = { careEpisodeId: appt.careEpisodeId, facilityId, urgency, reason: reason.trim() };
    if (specialty) input.specialty = specialty;
    if (summary.trim()) input.clinicalSummary = summary.trim();
    create.mutate(input);
  };

  if (created) {
    return (
      <div className="flex flex-col gap-4" role="status">
        <div className="flex items-start gap-2 rounded-xl bg-teal-bg p-3">
          <CheckCircle2 className="mt-0.5 size-5 text-primary" aria-hidden />
          <div>
            <p className="font-semibold text-primary-dark">Referral created</p>
            <p className="text-[13px]">
              {created.facility.name} · {created.facility.area}, {created.facility.city}
            </p>
          </div>
        </div>
        <dl className="grid grid-cols-[120px_1fr] gap-x-3 gap-y-1.5 text-sm">
          <dt className="text-ink-muted">Urgency</dt>
          <dd>
            <UrgencyBadge urgency={created.urgency} />
          </dd>
          <dt className="text-ink-muted">Status</dt>
          <dd>
            <ReferralStatusBadge status={created.status} />
          </dd>
          {created.specialty && (
            <>
              <dt className="text-ink-muted">Specialty</dt>
              <dd>{humanize(created.specialty)}</dd>
            </>
          )}
          <dt className="text-ink-muted">Reason</dt>
          <dd>{created.reason}</dd>
        </dl>
        <div className="flex flex-wrap justify-end gap-2">
          <LetterButton r={created} />
          <Button onClick={onDone}>Done</Button>
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={submit} noValidate className="flex flex-col gap-4">
      <fieldset className="flex flex-col gap-2">
        <legend className="mb-1 text-sm font-semibold">
          Facility <span className="text-danger" aria-hidden>*</span>
        </legend>
        <div className="grid gap-2 sm:grid-cols-[1fr_160px]">
          <div className="flex flex-col gap-1">
            <label htmlFor={`${uid}-search`} className="sr-only">
              Search facilities
            </label>
            <Input
              id={`${uid}-search`}
              data-autofocus
              type="search"
              placeholder="Search by name, area or service"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              aria-invalid={!!errors.facility}
              aria-describedby={errors.facility ? `${uid}-facility-err` : undefined}
            />
          </div>
          <label htmlFor={`${uid}-type`} className="sr-only">
            Facility type
          </label>
          <Select id={`${uid}-type`} value={type} onChange={(e) => setType(e.target.value as "" | FacilityType)}>
            {FACILITY_TYPES.map((t) => (
              <option key={t.value} value={t.value}>
                {t.label}
              </option>
            ))}
          </Select>
        </div>
        {errors.facility && (
          <p id={`${uid}-facility-err`} role="alert" className="text-xs text-danger-dark">
            {errors.facility}
          </p>
        )}
        <div className="max-h-64 overflow-y-auto rounded-xl border border-line" aria-busy={facilities.isFetching || undefined}>
          {facilities.isPending ? (
            <div className="p-3">
              <LoadingState rows={2} label="Searching facilities…" />
            </div>
          ) : facilities.isError ? (
            <ErrorState error={facilities.error} onRetry={() => facilities.refetch()} />
          ) : facilities.data.items.length === 0 ? (
            <EmptyState title="No facilities found" description="Try another name or type." icon={<Building2 className="size-6" />} />
          ) : (
            <div role="radiogroup" aria-label="Facilities" className="divide-y divide-line">
              {facilities.data.items.map((f) => {
                const checked = facilityId === f.id;
                return (
                  <label
                    key={f.id}
                    className={cx(
                      "flex cursor-pointer items-start gap-3 px-3 py-2.5 focus-within:bg-mint-50",
                      checked ? "bg-mint-50" : "hover:bg-mint-50/60",
                    )}
                  >
                    <input
                      type="radio"
                      name={`${uid}-facility`}
                      value={f.id}
                      checked={checked}
                      onChange={() => {
                        setFacilityId(f.id);
                        setErrors((x) => ({ ...x, facility: undefined }));
                      }}
                      className="mt-1 size-4 accent-[#631D3F]"
                    />
                    <span className="min-w-0 flex-1">
                      <span className="block font-semibold">{f.name}</span>
                      <span className="block text-xs text-ink-muted">
                        {humanize(f.type)} · {[f.area, f.city].filter(Boolean).join(", ")}
                        {f.distanceKm !== null ? ` · ${f.distanceKm.toFixed(1)} km` : ""}
                      </span>
                      <span className="mt-1 flex flex-wrap gap-1.5">
                        {f.emergency24x7 && (
                          <Badge tone="red" icon={<Siren className="size-3" aria-hidden />}>
                            24×7 emergency
                          </Badge>
                        )}
                        {f.verified && (
                          <Badge tone="green" icon={<BadgeCheck className="size-3" aria-hidden />}>
                            Verified
                          </Badge>
                        )}
                      </span>
                    </span>
                  </label>
                );
              })}
            </div>
          )}
        </div>
      </fieldset>

      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Specialty" hint="Optional">
          {(id, d) => (
            <Select id={id} aria-describedby={d} value={specialty} onChange={(e) => setSpecialty(e.target.value)} disabled={specialties.isPending}>
              <option value="">Any specialty</option>
              {specialties.data?.items.map((s) => (
                <option key={s.code} value={s.code}>
                  {s.name}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <fieldset>
          <legend className="mb-1 text-[13px] font-medium">Urgency</legend>
          <div className="flex gap-4 pt-2">
            {(["routine", "urgent"] as const).map((u) => (
              <label key={u} className="flex items-center gap-2 text-sm">
                <input
                  type="radio"
                  name={`${uid}-urgency`}
                  value={u}
                  checked={urgency === u}
                  onChange={() => setUrgency(u)}
                  className="size-4 accent-[#631D3F]"
                />
                {humanize(u)}
              </label>
            ))}
          </div>
        </fieldset>
      </div>

      <div className="flex flex-col gap-1">
        <label htmlFor={`${uid}-reason`} className="text-[13px] font-medium text-ink">
          Reason for referral<span className="text-danger" aria-hidden> *</span>
        </label>
        <Textarea
          id={`${uid}-reason`}
          rows={2}
          value={reason}
          onChange={(e) => {
            setReason(e.target.value);
            if (errors.reason) setErrors((x) => ({ ...x, reason: undefined }));
          }}
          aria-invalid={!!errors.reason}
          aria-describedby={errors.reason ? `${uid}-reason-err` : undefined}
          required
        />
        {errors.reason && (
          <p id={`${uid}-reason-err`} role="alert" className="text-xs text-danger-dark">
            {errors.reason}
          </p>
        )}
      </div>

      <Field label="Clinical summary" hint="Optional. Included in the referral letter.">
        {(id, d) => <Textarea id={id} aria-describedby={d} rows={3} value={summary} onChange={(e) => setSummary(e.target.value)} />}
      </Field>

      <div className="flex flex-wrap justify-end gap-2 border-t border-line pt-3">
        <Button variant="ghost" onClick={onDone}>
          Cancel
        </Button>
        <Button type="submit" loading={create.isPending} icon={<Send className="size-4" aria-hidden />}>
          Create referral
        </Button>
      </div>
    </form>
  );
}

/** Referrals for a patient (GET /referrals?patientId=) with letter download and a simple status update. */
export function ReferralList({ patientId }: { patientId: string }) {
  const query = useQuery({ queryKey: ["referrals", patientId], queryFn: () => api.referrals.list({ patientId }) });
  return (
    <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No referrals" icon={<Hospital className="size-6" />} />}>
      {(d) => (
        <ul className="flex flex-col gap-2">
          {d.items.map((r) => (
            <ReferralItem key={r.id} r={r} patientId={patientId} />
          ))}
        </ul>
      )}
    </QueryView>
  );
}

function ReferralItem({ r, patientId }: { r: Referral; patientId: string }) {
  const qc = useQueryClient();
  const toast = useToast();
  const selectId = useId();
  const update = useMutation({
    mutationFn: (status: Exclude<ReferralStatus, "created">) => api.referrals.update(r.id, { status }),
    onSuccess: (u) => {
      toast.success("Referral updated", `Status: ${humanize(u.status)}`);
      void qc.invalidateQueries({ queryKey: ["referrals", patientId] });
    },
    onError: (e) => toast.apiError(e, "Could not update the referral"),
  });
  const closed = r.status === "completed" || r.status === "cancelled";

  return (
    <li className="rounded-xl border border-line p-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <p className="font-semibold">{r.facility.name}</p>
          <p className="text-xs text-ink-muted">
            {[r.facility.area, r.facility.city].filter(Boolean).join(", ")}
            {r.specialty ? ` · ${humanize(r.specialty)}` : ""}
          </p>
        </div>
        <span className="flex flex-wrap gap-1.5">
          <UrgencyBadge urgency={r.urgency} />
          <ReferralStatusBadge status={r.status} />
        </span>
      </div>
      <p className="mt-1 text-[13px]">{r.reason}</p>
      <p className="text-xs text-ink-muted">
        By {r.createdByName} · {formatDateTime(r.createdAt)}
      </p>
      <div className="mt-2 flex flex-wrap items-center gap-2">
        <LetterButton r={r} label="Letter" />
        {!closed && (
          <>
            <label htmlFor={selectId} className="sr-only">
              Update status of referral to {r.facility.name}
            </label>
            <Select
              id={selectId}
              className="h-9 w-auto min-w-[170px] text-[13px]"
              value=""
              disabled={update.isPending}
              onChange={(e) => {
                const v = e.target.value as Exclude<ReferralStatus, "created"> | "";
                if (v) update.mutate(v);
              }}
            >
              <option value="">Update status…</option>
              {NEXT_STATUSES.filter((s) => s !== r.status).map((s) => (
                <option key={s} value={s}>
                  Mark {humanize(s).toLowerCase()}
                </option>
              ))}
            </Select>
          </>
        )}
      </div>
    </li>
  );
}

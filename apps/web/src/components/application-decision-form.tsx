"use client";

import { useId, useState, type FormEvent } from "react";
import { useMutation } from "@tanstack/react-query";
import { AlertTriangle, CheckCircle2, MessageSquareWarning, XCircle } from "lucide-react";
import { api } from "@/lib/api";
import type { ApplicationDecision, HomeVisitService, ProviderApplication, ServiceZone } from "@/lib/api/types";
import {
  toDecisionInput,
  validateDecision,
  type DecisionErrors,
  type DecisionFormValues,
} from "@/lib/application-decision";
import { todayIST } from "@/lib/format";
import { useToast } from "./toast";
import { Button, Field, Input, Textarea, cx, errorMessage } from "./ui";

const DECISIONS: { value: ApplicationDecision; label: string; hint: string }[] = [
  { value: "approve", label: "Approve", hint: "Creates the verified provider / doctor account" },
  { value: "request_changes", label: "Request changes", hint: "The applicant can edit and resubmit" },
  { value: "reject", label: "Reject", hint: "Closes the application" },
];

const SUBMIT_LABEL: Record<ApplicationDecision, string> = {
  approve: "Approve application",
  request_changes: "Request changes",
  reject: "Reject application",
};

const ERROR_ORDER: (keyof DecisionErrors)[] = ["documents", "credentialExpiresAt", "note", "zoneIds", "capabilities", "decision"];

export function ApplicationDecisionForm({
  app,
  zones,
  services,
  onDecided,
}: {
  app: ProviderApplication;
  /** Zones for the approve step; `null` when they could not be loaded (e.g. 403). */
  zones: ServiceZone[] | null;
  services: HomeVisitService[] | null;
  onDecided?: (updated: ProviderApplication) => void;
}) {
  const toast = useToast();
  const uid = useId();
  const [values, setValues] = useState<DecisionFormValues>({
    decision: "approve",
    note: "",
    credentialExpiresAt: "",
    zoneIds: app.preferredZoneIds.filter((id) => !zones || zones.some((z) => z.id === id)),
    capabilities: [],
  });
  const [errors, setErrors] = useState<DecisionErrors>({});
  const [submitted, setSubmitted] = useState(false);
  const showCapabilities = app.type !== "doctor";

  const m = useMutation({
    mutationFn: (v: DecisionFormValues) => api.applications.decide(app.id, toDecisionInput(v)),
    onSuccess: (updated) => {
      toast.success(
        values.decision === "approve" ? "Application approved" : values.decision === "reject" ? "Application rejected" : "Changes requested",
        "The applicant has been notified.",
      );
      onDecided?.(updated);
    },
  });

  const set = <K extends keyof DecisionFormValues>(key: K, v: DecisionFormValues[K]) => {
    const next = { ...values, [key]: v };
    setValues(next);
    if (submitted) setErrors(validateDecision(next, app, todayIST()));
  };

  const toggle = (key: "zoneIds" | "capabilities", id: string) => {
    const cur = values[key];
    set(key, cur.includes(id) ? cur.filter((x) => x !== id) : [...cur, id]);
  };

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setSubmitted(true);
    const errs = validateDecision(values, app, todayIST());
    setErrors(errs);
    if (Object.keys(errs).length) return;
    m.mutate(values);
  };

  const errorList = ERROR_ORDER.map((k) => errors[k]).filter((x): x is string => !!x);
  const isApprove = values.decision === "approve";

  return (
    <form onSubmit={submit} noValidate className="flex flex-col gap-4" aria-label="Decision">
      {errorList.length > 0 && (
        <div role="alert" className="rounded-xl border border-[#f6c9c9] bg-rose-bg px-3.5 py-2.5 text-sm text-danger-dark">
          <p className="flex items-center gap-1.5 font-semibold">
            <AlertTriangle className="size-4" aria-hidden /> Fix the following before submitting
          </p>
          <ul className="ml-5 list-disc">
            {errorList.map((e) => (
              <li key={e}>{e}</li>
            ))}
          </ul>
        </div>
      )}

      <fieldset className="flex flex-col gap-2">
        <legend className="mb-1 text-[13px] font-medium text-ink">Decision</legend>
        {DECISIONS.map((d) => (
          <label
            key={d.value}
            className={cx(
              "flex cursor-pointer items-start gap-2.5 rounded-xl border px-3 py-2 text-sm",
              values.decision === d.value ? "border-primary bg-mint-50" : "border-line bg-white hover:bg-mint-50",
            )}
          >
            <input
              type="radio"
              name={`${uid}-decision`}
              value={d.value}
              checked={values.decision === d.value}
              onChange={() => set("decision", d.value)}
              className="mt-1 accent-primary"
            />
            <span>
              <span className="font-semibold">{d.label}</span>
              <span className="block text-xs text-ink-muted">{d.hint}</span>
            </span>
          </label>
        ))}
      </fieldset>

      {isApprove && (
        <>
          <Field label="Credential expiry date" required error={errors.credentialExpiresAt} hint="Must be after today (IST)">
            {(id, d) => (
              <Input
                id={id}
                type="date"
                min={todayIST()}
                aria-describedby={d}
                aria-invalid={!!errors.credentialExpiresAt}
                value={values.credentialExpiresAt}
                onChange={(e) => set("credentialExpiresAt", e.target.value)}
              />
            )}
          </Field>

          <fieldset>
            <legend className="mb-1 text-[13px] font-medium text-ink">Service zones</legend>
            {zones === null ? (
              <p className="text-xs text-ink-muted">
                Zones could not be loaded. The applicant&apos;s preferred zones ({app.preferredZoneIds.length}) will be sent as selected.
              </p>
            ) : zones.length === 0 ? (
              <p className="text-xs text-ink-muted">No service zones configured.</p>
            ) : (
              <div className="grid max-h-48 gap-1 overflow-y-auto rounded-xl border border-line p-2 sm:grid-cols-2">
                {zones.map((z) => (
                  <label key={z.id} className="flex items-center gap-2 rounded-lg px-2 py-1 text-sm hover:bg-mint-50">
                    <input type="checkbox" checked={values.zoneIds.includes(z.id)} onChange={() => toggle("zoneIds", z.id)} />
                    <span>
                      {z.name} <span className="text-xs text-ink-muted">· {z.city}</span>
                      {app.preferredZoneIds.includes(z.id) && <span className="ml-1 text-xs text-primary">(preferred)</span>}
                    </span>
                  </label>
                ))}
              </div>
            )}
          </fieldset>

          {showCapabilities && (
            <fieldset>
              <legend className="mb-1 text-[13px] font-medium text-ink">Capabilities (home-visit services)</legend>
              {services === null ? (
                <p className="text-xs text-ink-muted">Services could not be loaded.</p>
              ) : services.length === 0 ? (
                <p className="text-xs text-ink-muted">No home-visit services available.</p>
              ) : (
                <div className="grid max-h-48 gap-1 overflow-y-auto rounded-xl border border-line p-2 sm:grid-cols-2">
                  {services.map((s) => (
                    <label key={s.code} className="flex items-center gap-2 rounded-lg px-2 py-1 text-sm hover:bg-mint-50">
                      <input type="checkbox" checked={values.capabilities.includes(s.code)} onChange={() => toggle("capabilities", s.code)} />
                      <span>{s.name}</span>
                    </label>
                  ))}
                </div>
              )}
            </fieldset>
          )}
        </>
      )}

      <Field
        label={isApprove ? "Approval note (audited)" : "Note to the applicant"}
        required
        error={errors.note}
        hint={`${values.note.trim().length}/1000`}
      >
        {(id, d) => (
          <Textarea
            id={id}
            rows={3}
            aria-describedby={d}
            aria-invalid={!!errors.note}
            value={values.note}
            onChange={(e) => set("note", e.target.value)}
          />
        )}
      </Field>

      {m.isError && (
        <p role="alert" className="text-sm text-danger-dark">
          Could not save the decision: {errorMessage(m.error)}
        </p>
      )}

      <div className="flex justify-end">
        <Button
          type="submit"
          variant={values.decision === "reject" ? "danger" : "primary"}
          loading={m.isPending}
          icon={
            values.decision === "approve" ? (
              <CheckCircle2 className="size-4" aria-hidden />
            ) : values.decision === "reject" ? (
              <XCircle className="size-4" aria-hidden />
            ) : (
              <MessageSquareWarning className="size-4" aria-hidden />
            )
          }
        >
          {SUBMIT_LABEL[values.decision]}
        </Button>
      </div>
    </form>
  );
}

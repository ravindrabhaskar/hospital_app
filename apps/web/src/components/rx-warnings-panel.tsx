"use client";

import { forwardRef, useId } from "react";
import { AlertOctagon, AlertTriangle, Info, ShieldCheck } from "lucide-react";
import type { RxCheckResponse, RxWarning, RxWarningSeverity } from "@/lib/api/types";
import { humanize } from "@/lib/format";
import { MIN_OVERRIDE_REASON, countBySeverity, hasMajor, sortWarnings, warningKey } from "@/lib/rx-warnings";
import { Badge, Spinner, Textarea, cx, type Tone } from "./ui";

const SEV: Record<RxWarningSeverity, { label: string; tone: Tone; icon: typeof Info; box: string }> = {
  major: { label: "Major", tone: "red", icon: AlertOctagon, box: "border-[#f6c9c9] bg-rose-bg/60" },
  moderate: { label: "Moderate", tone: "amber", icon: AlertTriangle, box: "border-[#f8d9b5] bg-peach-bg/60" },
  info: { label: "Info", tone: "sky", icon: Info, box: "border-[#c9dcf8] bg-sky-bg/60" },
};

/**
 * §47 live interaction & allergy warnings. With a `major` warning the doctor must acknowledge and give an
 * override reason; the parent blocks submission until then (see `overrideBlockReason`).
 */
export const RxWarningsPanel = forwardRef<
  HTMLInputElement,
  {
    warnings: RxWarning[];
    knowledgePack?: RxCheckResponse["knowledgePack"];
    status: "idle" | "checking" | "ready" | "error";
    fromServer: boolean;
    acknowledged: boolean;
    onAcknowledge: (v: boolean) => void;
    reason: string;
    onReason: (v: string) => void;
    gateError: string | null;
  }
>(function RxWarningsPanel({ warnings, knowledgePack, status, fromServer, acknowledged, onAcknowledge, reason, onReason, gateError }, ackRef) {
  const ackId = useId();
  const reasonId = useId();
  const sorted = sortWarnings(warnings);
  const counts = countBySeverity(warnings);
  const major = hasMajor(warnings);

  return (
    <section aria-label="Interaction and allergy checks" aria-live="polite" className="flex flex-col gap-3 rounded-xl border border-line p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm font-semibold">Interaction & allergy check</p>
        <div className="flex flex-wrap items-center gap-1.5">
          {status === "checking" && <Spinner label="Checking interactions" />}
          {warnings.length > 0 &&
            (["major", "moderate", "info"] as RxWarningSeverity[])
              .filter((s) => counts[s] > 0)
              .map((s) => (
                <Badge key={s} tone={SEV[s].tone}>
                  {counts[s]} {SEV[s].label.toLowerCase()}
                </Badge>
              ))}
        </div>
      </div>

      {status === "idle" && warnings.length === 0 && <p className="text-xs text-ink-muted">Warnings appear here as you add medicines.</p>}
      {status === "error" && warnings.length === 0 && (
        <p className="text-xs text-peach-fg">The live check is unavailable right now. The server checks again when you create the prescription.</p>
      )}
      {status === "ready" && warnings.length === 0 && (
        <p className="flex items-center gap-1.5 text-xs text-primary-dark">
          <ShieldCheck className="size-4" aria-hidden /> No allergy, duplicate-therapy or interaction warnings found.
        </p>
      )}
      {fromServer && (
        <p role="alert" className="text-xs font-semibold text-danger-dark">
          The prescription was not created: the server found major warnings that need your acknowledgement.
        </p>
      )}

      {sorted.length > 0 && (
        <ul className="flex flex-col gap-2">
          {sorted.map((w) => {
            const m = SEV[w.severity] ?? SEV.info;
            const Icon = m.icon;
            return (
              <li key={warningKey(w)} className={cx("rounded-lg border p-2.5 text-[13px]", m.box)}>
                <div className="flex flex-wrap items-center gap-1.5">
                  <Badge tone={m.tone} icon={<Icon className="size-3" aria-hidden />}>
                    {m.label}
                  </Badge>
                  <span className="font-semibold">{humanize(w.type)}</span>
                  {w.drugs.length > 0 && <span className="text-ink-muted">· {w.drugs.join(" + ")}</span>}
                </div>
                <p className="mt-1">{w.message}</p>
                {w.source && <p className="mt-0.5 text-[11px] text-ink-muted">Source: {w.source}</p>}
              </li>
            );
          })}
        </ul>
      )}

      {knowledgePack && knowledgePack.status !== "approved" && (
        <p className="text-[11px] text-ink-muted">
          Knowledge pack {knowledgePack.version} is a fixture <strong>[REQUIRES CLINICAL GOVERNANCE]</strong>. It is not a complete drug
          database; use clinical judgement.
        </p>
      )}

      {major && (
        <div className="flex flex-col gap-2 rounded-lg border border-[#f6c9c9] bg-white p-3">
          <label htmlFor={ackId} className="flex items-start gap-2 text-sm">
            <input
              ref={ackRef}
              id={ackId}
              type="checkbox"
              className="mt-0.5 size-4 shrink-0 accent-[#b3261e]"
              checked={acknowledged}
              onChange={(e) => onAcknowledge(e.target.checked)}
              aria-describedby={gateError ? `${ackId}-err` : undefined}
            />
            <span>
              I have reviewed the <strong>major</strong> warnings and want to prescribe anyway.
            </span>
          </label>
          <div className="flex flex-col gap-1">
            <label htmlFor={reasonId} className="text-[13px] font-medium">
              Override reason <span className="text-danger" aria-hidden>*</span>
            </label>
            <Textarea
              id={reasonId}
              rows={2}
              value={reason}
              onChange={(e) => onReason(e.target.value)}
              aria-invalid={!!gateError && reason.trim().length < MIN_OVERRIDE_REASON}
              placeholder="Clinical justification (audited)"
            />
          </div>
          {gateError && (
            <p id={`${ackId}-err`} role="alert" className="text-xs text-danger-dark">
              {gateError}
            </p>
          )}
        </div>
      )}
    </section>
  );
});

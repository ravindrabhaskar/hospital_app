"use client";

import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Bot, Check, FileText, HeartPulse, Home, ListChecks, Pencil, UserRound, X } from "lucide-react";
import { api } from "@/lib/api";
import type { AiFeedbackDecision, AiSourceKind, ClinicalSnapshot } from "@/lib/api/types";
import { formatDateTime } from "@/lib/format";
import { usePublicConfig } from "@/lib/public-config";
import { useToast } from "./toast";
import { Button, Field, Textarea, cx } from "./ui";

const SOURCE_ICON: Record<AiSourceKind, typeof FileText> = {
  record: FileText,
  vital: HeartPulse,
  intake: ListChecks,
  home_visit: Home,
  patient_entered: UserRound,
};

/** DOM id used by snapshot items so AI source chips can jump to them. */
export function sourceDomId(refId: string) {
  return `src-${refId}`;
}
export function sectionDomId(kind: AiSourceKind | string) {
  return `section-${kind}`;
}

/** Scrolls to and briefly highlights the underlying item for an AI source. Returns false if it is not on the page. */
export function jumpToSource(kind: AiSourceKind, refId: string): boolean {
  const el = document.getElementById(sourceDomId(refId)) ?? document.getElementById(sectionDomId(kind));
  if (!el) return false;
  const reduce = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  el.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "center" });
  el.classList.remove("source-highlight");
  // Force reflow so the animation restarts on repeated clicks.
  void el.offsetWidth;
  el.classList.add("source-highlight");
  if (!el.hasAttribute("tabindex")) el.setAttribute("tabindex", "-1");
  el.focus({ preventScroll: true });
  window.setTimeout(() => el.classList.remove("source-highlight"), 2600);
  return true;
}

type Summary = NonNullable<ClinicalSnapshot["aiSummary"]>;

export function AiSummaryPanel({ summary }: { summary: Summary | null }) {
  const toast = useToast();
  const [decision, setDecision] = useState<AiFeedbackDecision | null>(null);
  const [note, setNote] = useState("");
  const [submitted, setSubmitted] = useState<AiFeedbackDecision | null>(null);
  // §21 flags: explain an empty panel when the AI assistant is switched off platform-wide.
  const aiOff = usePublicConfig().data?.flags.ai_assistant === false;

  const feedback = useMutation({
    mutationFn: (d: { decision: AiFeedbackDecision; note: string }) =>
      api.clinician.aiFeedback({ aiInteractionId: summary!.interactionId, decision: d.decision, note: d.note }),
    onSuccess: (_r, d) => {
      setSubmitted(d.decision);
      setDecision(null);
      setNote("");
      toast.success("Feedback recorded", "Thank you. Your review is logged against this AI interaction.");
    },
    onError: (e) => toast.apiError(e, "Could not save feedback"),
  });

  return (
    <section
      aria-labelledby="ai-summary-heading"
      className="rounded-[20px] border-2 border-dashed border-[#c9bdf3] bg-lavender-bg p-5"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 id="ai-summary-heading" className="flex items-center gap-2 text-base font-semibold text-[#3b2a8c]">
          <Bot className="size-5" aria-hidden />
          AI summary
        </h2>
        <span className="rounded-full bg-white px-2.5 py-0.5 text-xs font-semibold text-lavender-fg">
          AI-generated · advisory · verify against sources
        </span>
      </div>

      {!summary ? (
        <p className="mt-3 text-sm text-[#4a3d7a]">
          {aiOff ? "The AI assistant is currently switched off for the platform." : "No AI summary is available for this patient."}
        </p>
      ) : (
        <>
          <p className="mt-1 text-xs text-[#5c5190]">
            {summary.model} · generated {formatDateTime(summary.generatedAt)}
          </p>
          {summary.text && <p className="mt-3 text-sm leading-6 text-[#2a2150]">{summary.text}</p>}

          {summary.claims.length > 0 && (
            <ul className="mt-4 flex flex-col gap-3" aria-label="Claims with sources">
              {summary.claims.map((c, i) => (
                <li key={i} className="rounded-xl bg-white/80 p-3">
                  <p className="text-sm text-[#2a2150]">{c.text}</p>
                  <div className="mt-2 flex flex-wrap items-center gap-1.5">
                    <span className="text-xs text-[#5c5190]">Sources:</span>
                    {c.sources.length === 0 && (
                      <span className="rounded-full bg-peach-bg px-2 py-0.5 text-xs font-medium text-peach-fg">
                        No source cited — treat as unverified
                      </span>
                    )}
                    {c.sources.map((s, j) => {
                      const Icon = SOURCE_ICON[s.kind] ?? FileText;
                      return (
                        <button
                          key={`${s.refId}-${j}`}
                          type="button"
                          onClick={() => {
                            if (!jumpToSource(s.kind, s.refId)) toast.info("Source not shown on this page", s.label);
                          }}
                          className="inline-flex items-center gap-1 rounded-full border border-[#c9bdf3] bg-white px-2 py-0.5 text-xs font-medium text-lavender-fg hover:bg-lavender-bg"
                          aria-label={`Go to source: ${s.label} (${s.kind.replace("_", " ")})`}
                        >
                          <Icon className="size-3" aria-hidden />
                          {s.label}
                        </button>
                      );
                    })}
                  </div>
                </li>
              ))}
            </ul>
          )}

          <div className="mt-4 border-t border-[#d9d0f7] pt-4">
            <p className="text-[13px] font-semibold text-[#3b2a8c]" id="ai-feedback-label">
              Your review of this summary
            </p>
            {submitted && (
              <p role="status" className="mt-1 text-xs text-[#5c5190]">
                Last feedback submitted: <strong>{submitted}</strong>
              </p>
            )}
            <div className="mt-2 flex flex-wrap gap-2" role="group" aria-labelledby="ai-feedback-label">
              <Button
                size="sm"
                variant="secondary"
                icon={<Check className="size-4" aria-hidden />}
                loading={feedback.isPending && feedback.variables?.decision === "accept"}
                onClick={() => feedback.mutate({ decision: "accept", note: "" })}
              >
                Accept
              </Button>
              <Button
                size="sm"
                variant={decision === "modify" ? "primary" : "secondary"}
                aria-pressed={decision === "modify"}
                icon={<Pencil className="size-4" aria-hidden />}
                onClick={() => setDecision(decision === "modify" ? null : "modify")}
              >
                Modify
              </Button>
              <Button
                size="sm"
                variant={decision === "reject" ? "danger" : "secondary"}
                aria-pressed={decision === "reject"}
                icon={<X className="size-4" aria-hidden />}
                onClick={() => setDecision(decision === "reject" ? null : "reject")}
              >
                Reject
              </Button>
            </div>
            {decision && (
              <form
                className="mt-3 flex flex-col gap-2"
                onSubmit={(e) => {
                  e.preventDefault();
                  if (!note.trim()) return;
                  feedback.mutate({ decision, note: note.trim() });
                }}
              >
                <Field
                  label={decision === "modify" ? "What should the summary say instead?" : "Why are you rejecting it?"}
                  required
                  hint="Stored with the AI interaction for model-quality review. Do not paste unrelated PHI."
                >
                  {(id, d) => (
                    <Textarea id={id} aria-describedby={d} value={note} onChange={(e) => setNote(e.target.value)} className="bg-white" />
                  )}
                </Field>
                <div className="flex gap-2">
                  <Button type="submit" size="sm" disabled={!note.trim()} loading={feedback.isPending}>
                    Submit {decision}
                  </Button>
                  <Button size="sm" variant="ghost" onClick={() => setDecision(null)}>
                    Cancel
                  </Button>
                </div>
              </form>
            )}
          </div>
        </>
      )}
    </section>
  );
}

export function AiLabel({ className }: { className?: string }) {
  return (
    <span className={cx("inline-flex items-center gap-1 rounded-full bg-lavender-bg px-2 py-0.5 text-[11px] font-semibold text-lavender-fg", className)}>
      <Bot className="size-3" aria-hidden />
      AI-generated · advisory
    </span>
  );
}

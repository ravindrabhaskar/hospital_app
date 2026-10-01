"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Clock, Hand, Plus, Send, Stethoscope, Trash2 } from "lucide-react";
import { api } from "@/lib/api";
import type { SecondOpinion } from "@/lib/api/types";
import { formatDateTime, formatINR, humanize, relativeTime } from "@/lib/format";
import { SO_TONE } from "@/components/patient-care-extras";
import { OpenOriginalButton } from "@/components/record-file";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, ChipGroup, EmptyState, Field, Input, PageHeader, QueryView, Textarea } from "@/components/ui";

type Scope = "open" | "mine";

export default function SecondOpinionsPage() {
  const [scope, setScope] = useState<Scope>("open");
  const query = useQuery({
    queryKey: ["clinician", "second-opinions", scope],
    queryFn: () => api.secondOpinions.clinicianList(scope, { limit: 100 }),
    refetchInterval: 60_000,
  });
  return (
    <>
      <PageHeader title="Second opinions" description="Open requests in your specialty, and the ones you have claimed. Shared records are read-only and access is audited." />
      <div className="mb-4">
        <ChipGroup<Scope>
          label="Second-opinion list"
          value={scope}
          onChange={setScope}
          options={[
            { value: "open", label: "Open in my specialty" },
            { value: "mine", label: "Claimed by me" },
          ]}
        />
      </div>
      <QueryView
        query={query}
        isEmpty={(d) => d.items.length === 0}
        empty={
          <Card>
            <EmptyState
              icon={<Stethoscope className="size-6" />}
              title={scope === "open" ? "No open requests" : "You have not claimed any requests"}
              description={scope === "open" ? "Paid requests in your specialty appear here." : "Claim an open request to answer it."}
            />
          </Card>
        }
      >
        {(d) => (
          <ul className="flex flex-col gap-4">
            {d.items.map((so) => (
              <li key={so.id}>
                <OpinionCard so={so} />
              </li>
            ))}
          </ul>
        )}
      </QueryView>
    </>
  );
}

function OpinionCard({ so }: { so: SecondOpinion }) {
  const qc = useQueryClient();
  const toast = useToast();
  const overdue = !!so.dueAt && new Date(so.dueAt).getTime() < Date.now() && so.status !== "answered";
  const claim = useMutation({
    mutationFn: () => api.secondOpinions.claim(so.id),
    onSuccess: () => {
      toast.success("Request claimed", "The patient's records are now shared with you.");
      void qc.invalidateQueries({ queryKey: ["clinician", "second-opinions"] });
    },
    onError: (e) => toast.apiError(e, "Could not claim the request"),
  });

  return (
    <Card
      title={`${so.patientName} · ${humanize(so.specialty)}`}
      subtitle={`Requested ${formatDateTime(so.createdAt)} · fee ${formatINR(so.price)}`}
      actions={
        <>
          {so.dueAt && so.status !== "answered" && (
            <Badge tone={overdue ? "red" : "amber"} icon={<Clock className="size-3" aria-hidden />}>
              {overdue ? `Overdue (${relativeTime(so.dueAt)})` : `Due ${relativeTime(so.dueAt)}`}
            </Badge>
          )}
          <Badge tone={SO_TONE[so.status] ?? "neutral"}>{humanize(so.status)}</Badge>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <div>
          <p className="text-xs font-semibold uppercase tracking-wide text-ink-muted">Question</p>
          <p className="whitespace-pre-line text-sm">{so.question}</p>
        </div>
        {so.records.length > 0 && (
          <div>
            <p className="mb-1 text-xs font-semibold uppercase tracking-wide text-ink-muted">Shared records</p>
            <ul className="flex flex-wrap gap-2">
              {so.records.map((r) => (
                <li key={r.id} className="flex items-center gap-2 rounded-xl border border-line px-3 py-1.5 text-sm">
                  {r.title}
                  {so.status !== "open" && <OpenOriginalButton recordId={r.id} label="Open" fileName={r.title} />}
                </li>
              ))}
            </ul>
            {so.status === "open" && <p className="mt-1 text-xs text-ink-muted">Records open after you claim the request.</p>}
          </div>
        )}
        {so.status === "open" && (
          <Button className="self-start" onClick={() => claim.mutate()} loading={claim.isPending} icon={<Hand className="size-4" aria-hidden />}>
            Claim request
          </Button>
        )}
        {so.status === "claimed" && <RespondForm so={so} />}
        {so.status === "answered" && (
          <div className="rounded-xl bg-mint-50 p-3 text-sm">
            <p className="font-semibold">Your opinion {so.answeredAt ? `(${formatDateTime(so.answeredAt)})` : ""}</p>
            <p className="whitespace-pre-line">{so.opinion}</p>
            {so.recommendations.length > 0 && (
              <ul className="mt-2 list-disc pl-5">
                {so.recommendations.map((r, i) => (
                  <li key={i}>{r}</li>
                ))}
              </ul>
            )}
            {so.opinionRecordId && (
              <div className="mt-2">
                <OpenOriginalButton recordId={so.opinionRecordId} label="Opinion PDF" />
              </div>
            )}
          </div>
        )}
      </div>
    </Card>
  );
}

function RespondForm({ so }: { so: SecondOpinion }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [opinion, setOpinion] = useState("");
  const [recs, setRecs] = useState<string[]>([""]);
  const [teleconsult, setTeleconsult] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const cleanRecs = recs.map((r) => r.trim()).filter(Boolean);
  const opinionError = opinion.trim().length < 30 ? "Write your opinion (at least 30 characters)" : undefined;
  const recError = cleanRecs.length === 0 ? "Add at least one recommendation" : undefined;

  const respond = useMutation({
    mutationFn: () => api.secondOpinions.respond(so.id, { opinion: opinion.trim(), recommendations: cleanRecs, suggestTeleconsult: teleconsult }),
    onSuccess: () => {
      toast.success("Opinion sent", "A PDF is added to the patient's records and they are notified.");
      void qc.invalidateQueries({ queryKey: ["clinician", "second-opinions"] });
    },
    onError: (e) => toast.apiError(e, "Could not send the opinion"),
  });

  return (
    <form
      noValidate
      className="flex flex-col gap-3 rounded-xl border border-line p-3"
      onSubmit={(e) => {
        e.preventDefault();
        setSubmitted(true);
        if (!opinionError && !recError) respond.mutate();
      }}
    >
      <Field label="Opinion" required error={submitted ? opinionError : undefined}>
        {(id, d) => <Textarea id={id} rows={5} aria-describedby={d} aria-invalid={submitted && !!opinionError} value={opinion} onChange={(e) => setOpinion(e.target.value)} />}
      </Field>
      <fieldset className="flex flex-col gap-2">
        <legend className="mb-1 text-[13px] font-medium">
          Recommendations <span className="text-danger" aria-hidden>*</span>
        </legend>
        {submitted && recError && (
          <p role="alert" className="text-xs text-danger-dark">
            {recError}
          </p>
        )}
        <ol className="flex flex-col gap-2">
          {recs.map((r, i) => (
            <li key={i} className="flex items-center gap-2">
              <span className="w-5 text-right text-xs text-ink-muted" aria-hidden>
                {i + 1}.
              </span>
              <Input aria-label={`Recommendation ${i + 1}`} value={r} onChange={(e) => setRecs((xs) => xs.map((x, j) => (j === i ? e.target.value : x)))} />
              <Button size="sm" variant="ghost" aria-label={`Remove recommendation ${i + 1}`} disabled={recs.length <= 1} onClick={() => setRecs((xs) => xs.filter((_, j) => j !== i))} icon={<Trash2 className="size-4" aria-hidden />} />
            </li>
          ))}
        </ol>
        <Button size="sm" variant="subtle" className="self-start" disabled={recs.length >= 15} onClick={() => setRecs((xs) => [...xs, ""])} icon={<Plus className="size-4" aria-hidden />}>
          Add recommendation
        </Button>
      </fieldset>
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" className="size-4 accent-[#631D3F]" checked={teleconsult} onChange={(e) => setTeleconsult(e.target.checked)} />
        Suggest a teleconsultation
      </label>
      <Button type="submit" className="self-start" loading={respond.isPending} icon={<Send className="size-4" aria-hidden />}>
        Send opinion
      </Button>
    </form>
  );
}

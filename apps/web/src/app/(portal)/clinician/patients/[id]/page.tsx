"use client";

import Link from "next/link";
import { use, useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, ArrowLeft, Camera, Droplet, FileText, Home, Phone, Pill, Ruler, Smile } from "lucide-react";
import { api } from "@/lib/api";
import type { ClinicalSnapshot, HomeVisit, Intake, IntakeField, WoundCase } from "@/lib/api/types";
import { formatDate, formatDateTime, humanize } from "@/lib/format";
import { AiLabel, AiSummaryPanel, sectionDomId, sourceDomId } from "@/components/ai-summary";
import { EpisodeTimelineCard } from "@/components/episode-timeline";
import { PrescriptionList } from "@/components/prescription-writer";
import { ProgramsCard } from "@/components/patient-programs";
import {
  CheckinStrip,
  DietPlansCard,
  ExercisePlansCard,
  InsuranceCard,
  LabOrdersCard,
  PreventiveCard,
  SecondOpinionsCard,
} from "@/components/patient-care-extras";
import { OpenOriginalButton } from "@/components/record-file";
import { ReferralList } from "@/components/referral-dialog";
import { EpisodeStatusBadge, GenericStatusBadge, PriorityBadge, ProvenanceBadge, VisitStatusBadge } from "@/components/status";
import { useToast } from "@/components/toast";
import { VITAL_LABEL, VitalsPanel } from "@/components/vitals";
import { Badge, Button, Card, EmptyState, ErrorState, Field, LoadingState, QueryView, Textarea, cx } from "@/components/ui";

export default function SnapshotPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const query = useQuery({ queryKey: ["snapshot", id], queryFn: () => api.clinician.snapshot(id) });

  return (
    <>
      <Link href="/clinician/patients" className="mb-3 inline-flex items-center gap-1 text-sm font-medium text-primary-light hover:underline">
        <ArrowLeft className="size-4" aria-hidden /> Patients
      </Link>
      {query.isPending ? (
        <LoadingState rows={6} label="Loading clinical snapshot…" />
      ) : query.isError ? (
        <ErrorState error={query.error} onRetry={() => query.refetch()} />
      ) : (
        <Snapshot snap={query.data} />
      )}
    </>
  );
}

function Snapshot({ snap }: { snap: ClinicalSnapshot }) {
  const p = snap.patient;
  const [episodeId, setEpisodeId] = useState<string | null>(snap.activeEpisodes[0]?.id ?? null);

  return (
    <div className="flex flex-col gap-5">
      {/* Header: demographics */}
      <header className="rounded-[20px] border border-line bg-gradient-to-r from-mint-50 to-white p-5 shadow-[var(--shadow-card)]">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-[24px] font-bold leading-8">{p.name}</h1>
            <p className="text-sm text-ink-muted">
              {p.age ?? "—"} yrs · {humanize(p.gender)}
              {p.dob ? ` · DOB ${formatDate(p.dob)}` : ""}
            </p>
          </div>
          <p className="rounded-full bg-white px-3 py-1 text-xs text-ink-muted">Clinical snapshot · access is audited</p>
        </div>
        <dl className="mt-4 grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
          <Demo icon={<Droplet className="size-4" aria-hidden />} label="Blood group" value={p.bloodGroup ?? "—"} />
          <Demo icon={<Ruler className="size-4" aria-hidden />} label="Height / weight" value={`${p.heightCm ?? "—"} cm / ${p.weightKg ?? "—"} kg`} />
          <Demo icon={<Phone className="size-4" aria-hidden />} label="Phone" value={p.phone ?? "—"} />
          <Demo
            icon={<Phone className="size-4" aria-hidden />}
            label="Emergency contact"
            value={p.emergencyContacts[0] ? `${p.emergencyContacts[0].name} (${p.emergencyContacts[0].relation})` : "—"}
          />
        </dl>
      </header>

      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_380px]">
        <div className="flex min-w-0 flex-col gap-5">
          {/* Allergies & conditions */}
          <div className="grid gap-5 md:grid-cols-2">
            <Card title="Allergies" id={sectionDomId("patient_entered")}>
              {p.allergies.length === 0 ? (
                <p className="text-sm text-ink-muted">No known allergies recorded.</p>
              ) : (
                <ul className="flex flex-col gap-2">
                  {p.allergies.map((a) => (
                    <li key={a.id} id={sourceDomId(a.id)} className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-[#f6c9c9] bg-rose-bg/40 px-3 py-2">
                      <div>
                        <p className="flex items-center gap-1.5 font-semibold text-danger-dark">
                          <AlertTriangle className="size-4" aria-hidden /> {a.substance}
                        </p>
                        <p className="text-xs text-ink-muted">
                          {a.reaction ?? "Reaction not recorded"}
                          {a.severity ? ` · ${humanize(a.severity)}` : ""}
                        </p>
                      </div>
                      <ProvenanceBadge source={a.source} />
                    </li>
                  ))}
                </ul>
              )}
            </Card>
            <Card title="Conditions">
              {p.conditions.length === 0 ? (
                <p className="text-sm text-ink-muted">No conditions recorded.</p>
              ) : (
                <ul className="flex flex-col gap-2">
                  {p.conditions.map((c) => (
                    <li key={c.id} id={sourceDomId(c.id)} className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-line px-3 py-2">
                      <div>
                        <p className="font-semibold">{c.name}</p>
                        <p className="text-xs text-ink-muted">{c.since ? `Since ${c.since}` : "Onset not recorded"}</p>
                      </div>
                      <ProvenanceBadge source={c.source} />
                    </li>
                  ))}
                </ul>
              )}
            </Card>
          </div>

          <AiSummaryPanel summary={snap.aiSummary} />

          <ProgramsCard patientId={p.id} episodes={snap.activeEpisodes} />
          <CheckinStrip patientId={p.id} />

          {/* Active episodes */}
          <Card title="Active care episodes" subtitle="Select an episode to show its timeline">
            {snap.activeEpisodes.length === 0 ? (
              <EmptyState title="No active episodes" />
            ) : (
              <ul className="flex flex-col gap-2">
                {snap.activeEpisodes.map((e) => (
                  <li key={e.id}>
                    <button
                      type="button"
                      aria-pressed={episodeId === e.id}
                      onClick={() => setEpisodeId(e.id)}
                      className={cx(
                        "flex w-full flex-wrap items-center justify-between gap-2 rounded-xl border px-3 py-2.5 text-left",
                        episodeId === e.id ? "border-primary bg-mint-50" : "border-line hover:bg-mint-50",
                      )}
                    >
                      <span className="min-w-0">
                        <span className="block font-semibold">{e.title}</span>
                        <span className="block text-xs text-ink-muted">
                          {e.concern} · opened {formatDate(e.createdAt)}
                          {e.ownerName ? ` · owner ${e.ownerName}` : ""}
                        </span>
                      </span>
                      <span className="flex gap-1.5">
                        <PriorityBadge priority={e.priority} />
                        <EpisodeStatusBadge status={e.status} />
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </Card>

          {/* Medications */}
          <Card title="Active medications">
            {snap.activeMedications.length === 0 ? (
              <EmptyState title="No active medications" icon={<Pill className="size-6" />} />
            ) : (
              <ul className="grid gap-2 md:grid-cols-2">
                {snap.activeMedications.map((m) => (
                  <li key={m.id} id={sourceDomId(m.id)} className="rounded-xl border border-line p-3">
                    <div className="flex flex-wrap items-start justify-between gap-2">
                      <p className="font-semibold">
                        {m.name} <span className="font-normal text-ink-muted">{m.dose}</span>
                      </p>
                      <ProvenanceBadge source={m.source} />
                    </div>
                    <p className="text-xs text-ink-muted">
                      {m.frequency} · {m.times.join(", ")} · from {formatDate(m.startDate)}
                      {m.endDate ? ` to ${formatDate(m.endDate)}` : ""}
                    </p>
                    {m.instructions && <p className="mt-1 text-[13px]">{m.instructions}</p>}
                    {m.prescribedByName && <p className="text-xs text-ink-muted">Prescribed by {m.prescribedByName}</p>}
                  </li>
                ))}
              </ul>
            )}
          </Card>

          <Card title="Prescriptions">
            <PrescriptionList patientId={p.id} />
          </Card>

          <Card title="Referrals">
            <ReferralList patientId={p.id} />
          </Card>

          <LabOrdersCard patientId={p.id} />
          <SecondOpinionsCard patientId={p.id} />

          <div className="grid gap-5 md:grid-cols-2">
            <ExercisePlansCard patientId={p.id} episodes={snap.activeEpisodes} />
            <DietPlansCard patientId={p.id} />
          </div>

          <div className="grid gap-5 md:grid-cols-2">
            <PreventiveCard patientId={p.id} />
            <InsuranceCard patientId={p.id} />
          </div>

          <Card title="Vitals" id={sectionDomId("vital")}>
            <VitalsPanel vitals={snap.recentVitals} />
          </Card>

          <Card title="Recent records" id={sectionDomId("record")}>
            {snap.recentRecords.length === 0 ? (
              <EmptyState title="No records" icon={<FileText className="size-6" />} />
            ) : (
              <ul className="flex flex-col gap-2">
                {snap.recentRecords.map((r) => (
                  <li key={r.id} id={sourceDomId(r.id)} className="rounded-xl border border-line p-3">
                    <div className="flex flex-wrap items-start justify-between gap-2">
                      <div className="min-w-0">
                        <p className="font-semibold">{r.title}</p>
                        <p className="text-xs text-ink-muted">
                          {humanize(r.type)} · {formatDate(r.recordDate)}
                          {r.uploadedByName ? ` · uploaded by ${r.uploadedByName}` : ""} · {r.fileName}
                        </p>
                        <div className="mt-1">
                          <ProvenanceBadge source={r.source} />
                        </div>
                      </div>
                      {r.hasFile && <OpenOriginalButton recordId={r.id} fileName={r.fileName} />}
                    </div>
                    {r.aiSummary && (
                      <div className="mt-2 rounded-lg bg-lavender-bg p-2.5 text-[13px] text-[#2a2150]">
                        <AiLabel className="mb-1" />
                        <p>{r.aiSummary.text}</p>
                        <p className="mt-1 text-[11px] text-[#5c5190]">{r.aiSummary.disclaimer}</p>
                      </div>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </Card>

          <Card title="Home-visit findings" id={sectionDomId("home_visit")}>
            {snap.homeVisitFindings.length === 0 ? (
              <EmptyState title="No home visits" icon={<Home className="size-6" />} />
            ) : (
              <ul className="flex flex-col gap-3">
                {snap.homeVisitFindings.map((v) => (
                  <HomeVisitFinding key={v.id} v={v} />
                ))}
              </ul>
            )}
          </Card>

          <Card title="AI intake" id={sectionDomId("intake")} actions={<AiLabel />}>
            {snap.intake ? <IntakeView intake={snap.intake} /> : <p className="text-sm text-ink-muted">No intake captured.</p>}
          </Card>

          {snap.moodTrend && snap.moodTrend.length > 0 && (
            <Card title="Mood check-ins (shared with clinician)">
              <ul className="flex flex-wrap gap-2">
                {snap.moodTrend.map((m) => (
                  <li key={m.id} className="rounded-xl border border-line px-3 py-2 text-sm">
                    <span className="flex items-center gap-1 font-semibold">
                      <Smile className="size-4 text-primary-light" aria-hidden /> {m.score}/5
                    </span>
                    <span className="text-xs text-ink-muted">{formatDate(m.createdAt)}</span>
                    {m.note && <p className="text-xs">{m.note}</p>}
                  </li>
                ))}
              </ul>
            </Card>
          )}

          <WoundCases patientId={p.id} />
        </div>

        <aside className="min-w-0" aria-label="Episode timeline">
          <div className="xl:sticky xl:top-20">
            {episodeId ? (
              <EpisodeTimelineCard episodeId={episodeId} className="xl:max-h-[calc(100vh-6rem)] xl:overflow-y-auto" />
            ) : (
              <Card title="Episode timeline">
                <EmptyState title="No active episode" />
              </Card>
            )}
          </div>
        </aside>
      </div>
    </div>
  );
}

function Demo({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="rounded-xl bg-white/80 px-3 py-2">
      <dt className="flex items-center gap-1 text-xs text-ink-muted">
        {icon}
        {label}
      </dt>
      <dd className="font-medium">{value}</dd>
    </div>
  );
}

function HomeVisitFinding({ v }: { v: HomeVisit }) {
  return (
    <li id={sourceDomId(v.id)} className="rounded-xl border border-line p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="font-semibold">
          {v.serviceName} <span className="font-normal text-ink-muted">· {formatDateTime(v.preferredStart)}</span>
        </p>
        <VisitStatusBadge status={v.status} />
      </div>
      {v.provider && (
        <p className="text-xs text-ink-muted">
          {v.provider.name}, {v.provider.qualification}
        </p>
      )}
      {v.escalation && (
        <p className="mt-2 flex items-center gap-1.5 rounded-lg bg-rose-bg px-2 py-1 text-[13px] text-danger-dark">
          <AlertTriangle className="size-4" aria-hidden /> Escalated ({v.escalation.severity}): {v.escalation.reason}
        </p>
      )}
      {v.vitals.length > 0 && (
        <ul className="mt-2 flex flex-wrap gap-1.5" aria-label="Vitals captured at visit">
          {v.vitals.map((m) => (
            <li key={m.id} id={sourceDomId(m.id)}>
              <Badge tone="sky">
                {VITAL_LABEL[m.type] ?? m.type}: {m.value} {m.unit}
              </Badge>
            </li>
          ))}
        </ul>
      )}
      {v.observations && (
        <div className="mt-2 text-[13px]">
          <p>
            <span className="font-semibold">Observations:</span> {v.observations.notes}
          </p>
          {Object.keys(v.observations.checklist).length > 0 && (
            <ul className="mt-1 flex flex-wrap gap-1.5">
              {Object.entries(v.observations.checklist).map(([k, val]) => (
                <li key={k}>
                  <Badge tone="neutral">
                    {humanize(k)}: {typeof val === "boolean" ? (val ? "Yes" : "No") : val}
                  </Badge>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
      {v.summary && (
        <p className="mt-2 text-[13px]">
          <span className="font-semibold">Summary:</span> {v.summary}
        </p>
      )}
    </li>
  );
}

function IntakeRow<T>({ label, field, render }: { label: string; field: IntakeField<T>; render: (v: T) => string }) {
  return (
    <div className="grid grid-cols-[140px_1fr] gap-2 border-b border-line py-2 last:border-0">
      <dt className="text-xs font-medium text-ink-muted">{label}</dt>
      <dd className="flex flex-wrap items-center gap-2 text-sm">
        {field.value === null || (Array.isArray(field.value) && field.value.length === 0) ? (
          <span className="text-ink-muted">Not captured</span>
        ) : (
          render(field.value)
        )}
        {field.source && <Badge tone={field.source === "model_extraction" ? "lavender" : "neutral"}>{humanize(field.source)}</Badge>}
        {field.confidence !== null && <span className="text-xs text-ink-muted">confidence {Math.round(field.confidence * 100)}%</span>}
      </dd>
    </div>
  );
}

function IntakeView({ intake }: { intake: Intake }) {
  const list = (v: string[]) => v.join(", ");
  return (
    <div>
      <dl>
        <IntakeRow label="Chief complaint" field={intake.chiefComplaint} render={(v) => v} />
        <IntakeRow label="Duration" field={intake.durationText} render={(v) => v} />
        <IntakeRow label="Severity" field={intake.severity} render={(v) => `${v}/10`} />
        <IntakeRow label="Associated symptoms" field={intake.associatedSymptoms} render={list} />
        <IntakeRow label="Relevant history" field={intake.relevantHistory} render={list} />
        <IntakeRow label="Current medications" field={intake.currentMedications} render={list} />
        <IntakeRow label="Allergies" field={intake.allergies} render={list} />
      </dl>
      <p className="mt-2 text-xs text-ink-muted">
        {intake.complete ? "Intake complete." : `Incomplete. Missing: ${intake.missingFields.map(humanize).join(", ") || "—"}`}
      </p>
    </div>
  );
}

function WoundCases({ patientId }: { patientId: string }) {
  const query = useQuery({ queryKey: ["wounds", patientId], queryFn: () => api.wounds.list({ patientId }) });
  return (
    <Card title="Wound cases" subtitle="Image-quality checks only. No automated diagnosis." actions={<Camera className="size-5 text-ink-muted" aria-hidden />}>
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No wound cases" />}>
        {(d) => (
          <ul className="flex flex-col gap-3">
            {d.items.map((w) => (
              <WoundCaseItem key={w.id} w={w} patientId={patientId} />
            ))}
          </ul>
        )}
      </QueryView>
    </Card>
  );
}

function WoundCaseItem({ w, patientId }: { w: WoundCase; patientId: string }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string | null>(null);
  const review = useMutation({
    mutationFn: () => api.wounds.review(w.id, notes.trim()),
    onSuccess: () => {
      toast.success("Wound review saved");
      setNotes("");
      void qc.invalidateQueries({ queryKey: ["wounds", patientId] });
    },
    onError: (e) => toast.apiError(e, "Could not save review"),
  });
  useEffect(() => setError(null), [notes]);

  return (
    <li className="rounded-xl border border-line p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="font-semibold">
          {w.bodySite} <span className="font-normal text-ink-muted">· {formatDateTime(w.createdAt)}</span>
        </p>
        <div className="flex items-center gap-2">
          <GenericStatusBadge status={w.status} tone={w.status === "reviewed" ? "green" : w.status === "retake_required" ? "amber" : "sky"} />
          <OpenOriginalButton recordId={w.imageRecordId} label="View image" />
        </div>
      </div>
      {w.note && <p className="mt-1 text-[13px]">Patient note: {w.note}</p>}
      <p className="mt-1 text-xs text-ink-muted">
        Image quality: {w.quality.acceptable ? "acceptable" : "not acceptable"}
        {w.quality.issues.length > 0 ? ` (${w.quality.issues.map(humanize).join(", ")})` : ""}
      </p>
      {w.clinicianReview ? (
        <p className="mt-2 rounded-lg bg-mint-50 px-2 py-1.5 text-[13px]">
          Reviewed by {w.clinicianReview.reviewerName} on {formatDateTime(w.clinicianReview.reviewedAt)}: {w.clinicianReview.notes}
        </p>
      ) : w.status === "pending_clinician_review" ? (
        <form
          className="mt-2 flex flex-col gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            if (!notes.trim()) {
              setError("Review notes are required");
              return;
            }
            review.mutate();
          }}
        >
          <Field label="Clinician review notes" required error={error ?? undefined}>
            {(id, d) => <Textarea id={id} aria-describedby={d} aria-invalid={!!error} value={notes} onChange={(e) => setNotes(e.target.value)} />}
          </Field>
          <Button type="submit" size="sm" className="self-start" loading={review.isPending}>
            Submit review
          </Button>
        </form>
      ) : null}
    </li>
  );
}

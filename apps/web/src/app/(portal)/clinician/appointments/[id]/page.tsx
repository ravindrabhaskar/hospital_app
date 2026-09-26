"use client";

import Link from "next/link";
import { use, useRef, useState, type KeyboardEvent, type ReactNode } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, CheckCircle2, MessageSquarePlus, PlayCircle, UserRound } from "lucide-react";
import { api } from "@/lib/api";
import type { Appointment, ConsultOutcome } from "@/lib/api/types";
import { formatDate, formatDateTime, formatINR, formatTime, humanize } from "@/lib/format";
import { CarePlanBuilder } from "@/components/care-plan-builder";
import { MessageThread } from "@/components/message-thread";
import { PrescriptionWriter } from "@/components/prescription-writer";
import { ReferralButton } from "@/components/referral-dialog";
import { EpisodeTimelineCard } from "@/components/episode-timeline";
import { AppointmentStatusBadge } from "@/components/status";
import { useToast } from "@/components/toast";
import { VideoJoinPanel } from "@/components/video-join";
import { Button, Card, EmptyState, ErrorState, Field, LoadingState, QueryView, Select, Textarea } from "@/components/ui";

export default function ConsultationPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const query = useQuery({ queryKey: ["appointment", id], queryFn: () => api.appointments.get(id) });

  return (
    <>
      <Link href="/clinician" className="mb-3 inline-flex items-center gap-1 text-sm font-medium text-primary-light hover:underline">
        <ArrowLeft className="size-4" aria-hidden /> Queue
      </Link>
      {query.isPending ? (
        <LoadingState rows={5} />
      ) : query.isError ? (
        <ErrorState error={query.error} onRetry={() => query.refetch()} />
      ) : (
        <Workspace appt={query.data} />
      )}
    </>
  );
}

function Workspace({ appt }: { appt: Appointment }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [notes, setNotes] = useState(appt.clinicianNotes ?? "");
  const [outcome, setOutcome] = useState<ConsultOutcome>("care_plan");
  const [notesError, setNotesError] = useState<string | null>(null);

  const refresh = () => {
    void qc.invalidateQueries({ queryKey: ["appointment", appt.id] });
    void qc.invalidateQueries({ queryKey: ["episode", appt.careEpisodeId] });
    void qc.invalidateQueries({ queryKey: ["clinician", "queue"] });
  };

  const start = useMutation({
    mutationFn: () => api.clinician.start(appt.id),
    onSuccess: (a) => {
      qc.setQueryData(["appointment", appt.id], a);
      refresh();
      toast.success("Consultation started", "Episode moved to Under care.");
    },
    onError: (e) => toast.apiError(e, "Could not start the consultation"),
  });

  const complete = useMutation({
    mutationFn: () => api.clinician.complete(appt.id, { notes: notes.trim(), outcome }),
    onSuccess: (a) => {
      qc.setQueryData(["appointment", appt.id], a);
      refresh();
      toast.success("Consultation completed");
    },
    onError: (e) => toast.apiError(e, "Could not complete the consultation"),
  });

  const canStart = appt.status === "confirmed";
  const inProgress = appt.status === "in_progress";
  const done = appt.status === "completed";

  return (
    <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_380px]">
      <div className="flex min-w-0 flex-col gap-5">
        <header className="rounded-[20px] border border-line bg-gradient-to-r from-mint-50 to-white p-5 shadow-[var(--shadow-card)]">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h1 className="text-[22px] font-bold">Consultation · {appt.patientName}</h1>
              <p className="text-sm text-ink-muted">
                {formatDate(appt.startAt)} · {formatTime(appt.startAt)}–{formatTime(appt.endAt)} IST · {humanize(appt.mode)} · {formatINR(appt.fee)}
              </p>
              <p className="mt-2 text-sm">
                <span className="font-semibold">Reason:</span> {appt.reason}
              </p>
            </div>
            <div className="flex flex-col items-end gap-2">
              <AppointmentStatusBadge status={appt.status} />
              <div className="flex flex-wrap gap-2">
                <Link
                  href={`/clinician/patients/${appt.patientId}`}
                  className="inline-flex h-9 items-center gap-1.5 rounded-full border border-primary px-3.5 text-[13px] font-semibold text-primary hover:bg-mint-50"
                >
                  <UserRound className="size-4" aria-hidden /> Clinical snapshot
                </Link>
                <ReferralButton appt={appt} />
              </div>
            </div>
          </div>
        </header>

        <VideoJoinPanel appt={appt} />

        <WorkspaceTabs
          tabs={[
            {
              key: "consultation",
              label: "Consultation",
              content: (
                <div className="flex flex-col gap-5">
                  <Card title="Consultation">
                    {canStart && (
                      <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-mint-50 p-3">
                        <p className="text-sm">Start the consultation when the patient joins. The care episode moves to <strong>Under care</strong>.</p>
                        <Button onClick={() => start.mutate()} loading={start.isPending} icon={<PlayCircle className="size-4" aria-hidden />}>
                          Start consultation
                        </Button>
                      </div>
                    )}
                    {!canStart && !inProgress && !done && (
                      <p className="text-sm text-ink-muted">This appointment is {humanize(appt.status).toLowerCase()} and cannot be started.</p>
                    )}
                    {(inProgress || done) && (
                      <form
                        className="flex flex-col gap-4"
                        onSubmit={(e) => {
                          e.preventDefault();
                          if (!notes.trim()) {
                            setNotesError("Consultation notes are required");
                            return;
                          }
                          setNotesError(null);
                          complete.mutate();
                        }}
                      >
                        <Field label="Clinical notes" required error={notesError ?? undefined}>
                          {(id, d) => (
                            <Textarea
                              id={id}
                              aria-describedby={d}
                              aria-invalid={!!notesError}
                              rows={6}
                              value={notes}
                              readOnly={done}
                              onChange={(e) => setNotes(e.target.value)}
                              placeholder="History, examination, assessment, advice…"
                            />
                          )}
                        </Field>
                        {!done && (
                          <div className="flex flex-wrap items-end gap-3">
                            <Field label="Outcome" className="min-w-[220px]">
                              {(id) => (
                                <Select id={id} value={outcome} onChange={(e) => setOutcome(e.target.value as ConsultOutcome)}>
                                  <option value="care_plan">Care plan</option>
                                  <option value="resolved">Resolved</option>
                                  <option value="refer">Refer</option>
                                  <option value="home_visit">Home visit</option>
                                </Select>
                              )}
                            </Field>
                            <Button type="submit" loading={complete.isPending} icon={<CheckCircle2 className="size-4" aria-hidden />}>
                              Complete consultation
                            </Button>
                          </div>
                        )}
                        {done && <p className="text-sm text-ink-muted">Consultation completed.</p>}
                      </form>
                    )}
                  </Card>

                  {(inProgress || done) && <CarePlanBuilder careEpisodeId={appt.careEpisodeId} />}

                  <ExistingCarePlans careEpisodeId={appt.careEpisodeId} />
                  <EpisodeNoteForm careEpisodeId={appt.careEpisodeId} />
                </div>
              ),
            },
            { key: "prescription", label: "Prescription", content: <PrescriptionWriter appt={appt} /> },
            {
              key: "messages",
              label: "Messages",
              content: <MessageThread careEpisodeId={appt.careEpisodeId} patientId={appt.patientId} />,
            },
          ]}
        />
      </div>

      <aside className="min-w-0" aria-label="Episode timeline">
        <div className="xl:sticky xl:top-20">
          <EpisodeTimelineCard episodeId={appt.careEpisodeId} className="xl:max-h-[calc(100vh-6rem)] xl:overflow-y-auto" />
        </div>
      </aside>
    </div>
  );
}

function ExistingCarePlans({ careEpisodeId }: { careEpisodeId: string }) {
  const query = useQuery({ queryKey: ["care-plans", careEpisodeId], queryFn: () => api.carePlans.list({ careEpisodeId }) });
  return (
    <Card title="Care plans for this episode">
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No care plans yet" />}>
        {(d) => (
          <ul className="flex flex-col gap-3">
            {d.items.map((p) => (
              <li key={p.id} className="rounded-xl border border-line p-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <p className="font-semibold">{p.summary}</p>
                  <span className="text-xs text-ink-muted">
                    {humanize(p.status)} · {p.doctorName} · {formatDateTime(p.createdAt)}
                  </span>
                </div>
                <p className="mt-1 text-[13px]">{p.instructions}</p>
                <p className="mt-1 text-xs text-ink-muted">
                  {p.tasks.length} tasks · {p.medications.length} medications
                  {p.followUpDueAt ? ` · follow-up due ${formatDate(p.followUpDueAt)}` : ""}
                </p>
              </li>
            ))}
          </ul>
        )}
      </QueryView>
    </Card>
  );
}

function EpisodeNoteForm({ careEpisodeId }: { careEpisodeId: string }) {
  const [text, setText] = useState("");
  const qc = useQueryClient();
  const toast = useToast();
  const add = useMutation({
    mutationFn: () => api.episodes.addNote(careEpisodeId, text.trim()),
    onSuccess: () => {
      setText("");
      toast.success("Note added to the episode");
      void qc.invalidateQueries({ queryKey: ["episode", careEpisodeId] });
    },
    onError: (e) => toast.apiError(e, "Could not add the note"),
  });
  return (
    <Card title="Add episode note">
      <form
        className="flex flex-col gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          if (text.trim()) add.mutate();
        }}
      >
        <Field label="Note" hint="Appended to the episode timeline (append-only).">
          {(id, d) => <Textarea id={id} aria-describedby={d} rows={2} value={text} onChange={(e) => setText(e.target.value)} />}
        </Field>
        <Button type="submit" variant="secondary" size="sm" className="self-start" disabled={!text.trim()} loading={add.isPending} icon={<MessageSquarePlus className="size-4" aria-hidden />}>
          Add note
        </Button>
      </form>
    </Card>
  );
}

type WorkspaceTab = { key: string; label: string; content: ReactNode };

/** WAI-ARIA tabs (automatic activation, arrow/Home/End keys). Panels stay mounted once visited so form drafts survive tab switches. */
function WorkspaceTabs({ tabs }: { tabs: WorkspaceTab[] }) {
  const [active, setActive] = useState(tabs[0]?.key ?? "");
  const [visited, setVisited] = useState<Set<string>>(() => new Set([tabs[0]?.key ?? ""]));
  const refs = useRef<Record<string, HTMLButtonElement | null>>({});

  const select = (key: string, focus = false) => {
    setActive(key);
    setVisited((v) => (v.has(key) ? v : new Set(v).add(key)));
    if (focus) refs.current[key]?.focus();
  };

  const onKeyDown = (e: KeyboardEvent<HTMLButtonElement>, index: number) => {
    let next: number | null = null;
    if (e.key === "ArrowRight") next = (index + 1) % tabs.length;
    else if (e.key === "ArrowLeft") next = (index - 1 + tabs.length) % tabs.length;
    else if (e.key === "Home") next = 0;
    else if (e.key === "End") next = tabs.length - 1;
    if (next === null) return;
    e.preventDefault();
    const tab = tabs[next];
    if (tab) select(tab.key, true);
  };

  return (
    <div className="flex flex-col gap-4">
      <div role="tablist" aria-label="Consultation workspace" className="flex gap-1 overflow-x-auto rounded-full border border-line bg-white p-1 shadow-[var(--shadow-card)]">
        {tabs.map((t, i) => {
          const selected = t.key === active;
          return (
            <button
              key={t.key}
              ref={(el) => {
                refs.current[t.key] = el;
              }}
              type="button"
              role="tab"
              id={`ws-tab-${t.key}`}
              aria-selected={selected}
              aria-controls={`ws-panel-${t.key}`}
              tabIndex={selected ? 0 : -1}
              onClick={() => select(t.key)}
              onKeyDown={(e) => onKeyDown(e, i)}
              className={
                selected
                  ? "h-9 flex-1 whitespace-nowrap rounded-full bg-primary px-4 text-[13px] font-semibold text-white"
                  : "h-9 flex-1 whitespace-nowrap rounded-full px-4 text-[13px] font-semibold text-ink-muted hover:bg-mint-50 hover:text-ink"
              }
            >
              {t.label}
            </button>
          );
        })}
      </div>
      {tabs.map((t) => (
        <div
          key={t.key}
          role="tabpanel"
          id={`ws-panel-${t.key}`}
          aria-labelledby={`ws-tab-${t.key}`}
          hidden={t.key !== active}
          tabIndex={0}
          className="min-w-0 focus:outline-none focus-visible:outline-2 focus-visible:outline-primary-light"
        >
          {visited.has(t.key) ? t.content : null}
        </div>
      ))}
    </div>
  );
}

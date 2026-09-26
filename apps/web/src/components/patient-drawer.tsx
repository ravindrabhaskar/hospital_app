"use client";

import { useEffect, useId, useRef } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQueries, useQuery, useQueryClient } from "@tanstack/react-query";
import { MessageSquare, PhoneCall, X } from "lucide-react";
import { api } from "@/lib/api";
import type { CareTask, CaseloadItem, ContactChannel, ContactOutcome } from "@/lib/api/types";
import { orderedFlags } from "@/lib/caseload";
import { formatDateTime, istLocalToISO, relativeTime } from "@/lib/format";
import { FlagBadge, patientLine } from "./caseload-table";
import { EpisodeStatusBadge, PriorityBadge } from "./status";
import { useToast } from "./toast";
import { Badge, Button, EmptyState, ErrorState, Field, Input, LoadingState, QueryView, Select, Textarea, cx, type Tone } from "./ui";

export const CHANNEL_LABEL: Record<ContactChannel, string> = {
  call: "Phone call",
  whatsapp: "WhatsApp",
  sms: "SMS",
  home_visit: "Home visit",
  in_app: "In-app",
};

export const OUTCOME_META: Record<ContactOutcome, { label: string; tone: Tone }> = {
  reached: { label: "Reached", tone: "green" },
  no_answer: { label: "No answer", tone: "amber" },
  callback_requested: { label: "Callback requested", tone: "sky" },
  escalated: { label: "Escalated", tone: "red" },
};

const CHANNELS = Object.keys(CHANNEL_LABEL) as [ContactChannel, ...ContactChannel[]];
const OUTCOMES = Object.keys(OUTCOME_META) as [ContactOutcome, ...ContactOutcome[]];

/** Right-side modal drawer with a coordinator's view of one patient (§35). */
export function PatientDrawer({ item, onClose }: { item: CaseloadItem; onClose: () => void }) {
  const ref = useRef<HTMLDivElement>(null);
  const titleId = useId();
  const restoreRef = useRef<Element | null>(null);
  const onCloseRef = useRef(onClose);
  useEffect(() => {
    onCloseRef.current = onClose;
  });

  useEffect(() => {
    restoreRef.current = document.activeElement;
    const node = ref.current;
    const focusables = () =>
      Array.from(
        node?.querySelectorAll<HTMLElement>(
          'a[href],button:not([disabled]),textarea:not([disabled]),input:not([disabled]),select:not([disabled]),[tabindex]:not([tabindex="-1"])',
        ) ?? [],
      );
    focusables()[0]?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.stopPropagation();
        onCloseRef.current();
      } else if (e.key === "Tab") {
        const els = focusables();
        if (els.length === 0) return;
        const firstEl = els[0]!;
        const lastEl = els[els.length - 1]!;
        if (e.shiftKey && document.activeElement === firstEl) {
          e.preventDefault();
          lastEl.focus();
        } else if (!e.shiftKey && document.activeElement === lastEl) {
          e.preventDefault();
          firstEl.focus();
        }
      }
    };
    document.addEventListener("keydown", onKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prevOverflow;
      (restoreRef.current as HTMLElement | null)?.focus?.();
    };
  }, [item.patient.id]);

  const flags = orderedFlags(item.flags);
  const details = patientLine(item);

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-ink/40" aria-hidden onClick={onClose} />
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className="relative flex h-full w-full max-w-xl flex-col bg-white shadow-xl"
      >
        <header className="flex items-start justify-between gap-3 border-b border-line px-5 py-4">
          <div className="min-w-0">
            <h2 id={titleId} className="text-lg font-semibold">
              {item.patient.name}
            </h2>
            {details && <p className="text-sm text-ink-muted">{details}</p>}
            {flags.length > 0 && (
              <div className="mt-1.5 flex flex-wrap gap-1">
                {flags.map((f) => (
                  <FlagBadge key={f} flag={f} />
                ))}
              </div>
            )}
          </div>
          <button type="button" onClick={onClose} aria-label="Close patient panel" className="rounded-full p-1.5 text-ink-muted hover:bg-mint-50">
            <X className="size-5" aria-hidden />
          </button>
        </header>
        <div className="flex flex-1 flex-col gap-6 overflow-y-auto px-5 py-4">
          <EpisodesSection item={item} />
          <TasksSection item={item} />
          <ContactsSection patientId={item.patient.id} />
          <LogContactForm item={item} />
        </div>
      </div>
    </div>
  );
}

function SectionTitle({ children }: { children: React.ReactNode }) {
  return <h3 className="mb-2 text-sm font-semibold uppercase tracking-wide text-ink-muted">{children}</h3>;
}

function EpisodesSection({ item }: { item: CaseloadItem }) {
  return (
    <section aria-label="Active episodes">
      <SectionTitle>Active episodes</SectionTitle>
      {item.episodes.length === 0 ? (
        <p className="text-sm text-ink-muted">No active episodes.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {item.episodes.map((e) => (
            <li key={e.id} className="rounded-xl border border-line px-3 py-2.5">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <p className="font-semibold">{e.title}</p>
                <span className="flex gap-1">
                  <PriorityBadge priority={e.priority} />
                  <EpisodeStatusBadge status={e.status} />
                </span>
              </div>
              <p className="text-xs text-ink-muted">
                Coordinator: {e.coordinatorName ?? "unassigned"} · updated {relativeTime(e.updatedAt)}
              </p>
              {e.nextAction && <p className="text-xs">Next: {e.nextAction}</p>}
              <Link
                href={`/inbox?episode=${encodeURIComponent(e.id)}`}
                className="mt-1 inline-flex items-center gap-1 text-xs font-semibold text-primary hover:underline"
              >
                <MessageSquare className="size-3.5" aria-hidden /> Message thread
              </Link>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

const TASK_TONE: Record<CareTask["status"], Tone> = { open: "sky", overdue: "red", done: "green", cancelled: "neutral" };

function TasksSection({ item }: { item: CaseloadItem }) {
  const queries = useQueries({
    queries: item.episodes.map((e) => ({
      queryKey: ["care-plans", { careEpisodeId: e.id }],
      queryFn: () => api.carePlans.list({ careEpisodeId: e.id, limit: 50 }),
    })),
  });
  const pending = queries.some((q) => q.isPending);
  const failed = queries.find((q) => q.isError);
  const titleByEpisode = new Map(item.episodes.map((e) => [e.id, e.title]));
  const tasks = queries
    .flatMap((q) => q.data?.items ?? [])
    .filter((p) => p.status === "active")
    .flatMap((p) => p.tasks.map((t) => ({ task: t, episodeTitle: titleByEpisode.get(p.careEpisodeId) ?? "" })))
    .filter(({ task }) => task.status === "open" || task.status === "overdue")
    .sort((a, b) => {
      if (a.task.status !== b.task.status) return a.task.status === "overdue" ? -1 : 1;
      return (a.task.dueAt ?? "9999").localeCompare(b.task.dueAt ?? "9999");
    });

  return (
    <section aria-label="Open tasks">
      <SectionTitle>Open &amp; overdue tasks</SectionTitle>
      {item.episodes.length === 0 ? (
        <p className="text-sm text-ink-muted">No active episodes.</p>
      ) : pending ? (
        <LoadingState label="Loading tasks…" rows={2} />
      ) : failed ? (
        <ErrorState error={failed.error} onRetry={() => queries.forEach((q) => q.isError && void q.refetch())} />
      ) : tasks.length === 0 ? (
        <p className="text-sm text-ink-muted">No open tasks on active care plans.</p>
      ) : (
        <ul className="flex flex-col gap-1.5">
          {tasks.map(({ task, episodeTitle }) => (
            <li key={task.id} className="flex flex-wrap items-start justify-between gap-2 rounded-xl border border-line px-3 py-2">
              <span className="min-w-0">
                <span className="block text-sm font-medium">{task.title}</span>
                <span className="block text-xs text-ink-muted">
                  {episodeTitle} · due {task.dueAt ? formatDateTime(task.dueAt) : "no due date"} · {task.owner}
                </span>
              </span>
              <Badge tone={TASK_TONE[task.status]}>{task.status === "overdue" ? "Overdue" : "Open"}</Badge>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function ContactsSection({ patientId }: { patientId: string }) {
  const query = useQuery({
    queryKey: ["coordinator", "contacts", patientId],
    queryFn: () => api.coordinator.contacts({ patientId, limit: 50 }),
  });
  return (
    <section aria-label="Contact log">
      <SectionTitle>Contact log</SectionTitle>
      <QueryView
        query={query}
        loadingRows={2}
        isEmpty={(d) => d.items.length === 0}
        empty={<EmptyState icon={<PhoneCall className="size-6" />} title="No contacts logged yet" />}
      >
        {(d) => (
          <ol className="relative flex flex-col gap-4 border-l-2 border-mint-100 pl-4" aria-label="Contacts, newest first">
            {[...d.items]
              .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
              .map((c) => (
                <li key={c.id} className="relative">
                  <span
                    className={cx(
                      "absolute -left-[23px] top-1 size-3 rounded-full border-2 border-white",
                      c.outcome === "escalated" ? "bg-danger" : "bg-primary-light",
                    )}
                    aria-hidden
                  />
                  <p className="flex flex-wrap items-center gap-1.5 text-[13px] font-semibold text-ink">
                    {CHANNEL_LABEL[c.channel] ?? c.channel}
                    <Badge tone={OUTCOME_META[c.outcome]?.tone ?? "neutral"}>{OUTCOME_META[c.outcome]?.label ?? c.outcome}</Badge>
                  </p>
                  <p className="whitespace-pre-wrap text-[13px] text-ink">{c.note}</p>
                  <p className="text-xs text-ink-muted">
                    {formatDateTime(c.createdAt)} · {c.coordinatorName}
                    {c.followUpAt ? ` · follow-up ${formatDateTime(c.followUpAt)}` : ""}
                  </p>
                </li>
              ))}
          </ol>
        )}
      </QueryView>
    </section>
  );
}

const contactSchema = z.object({
  channel: z.enum(CHANNELS),
  outcome: z.enum(OUTCOMES),
  note: z.string().trim().min(1, "Add a short note").max(1000, "Keep the note under 1000 characters"),
  careEpisodeId: z.string().optional(),
  followUpAt: z
    .string()
    .optional()
    .refine((v) => !v || new Date(istLocalToISO(v)).getTime() > Date.now(), "Follow-up must be in the future"),
});
type ContactValues = z.infer<typeof contactSchema>;

function LogContactForm({ item }: { item: CaseloadItem }) {
  const qc = useQueryClient();
  const toast = useToast();
  const patientId = item.patient.id;
  const { register, handleSubmit, reset, watch, formState } = useForm<ContactValues>({
    resolver: zodResolver(contactSchema),
    defaultValues: { channel: "call", outcome: "reached", note: "", careEpisodeId: "", followUpAt: "" },
  });
  const e = formState.errors;
  const noteLen = watch("note")?.length ?? 0;

  const m = useMutation({
    mutationFn: (v: ContactValues) =>
      api.coordinator.logContact({
        patientId,
        channel: v.channel,
        outcome: v.outcome,
        note: v.note.trim(),
        careEpisodeId: v.careEpisodeId || undefined,
        followUpAt: v.followUpAt ? istLocalToISO(v.followUpAt) : undefined,
      }),
    onSuccess: () => {
      toast.success("Contact logged");
      reset();
      void qc.invalidateQueries({ queryKey: ["coordinator", "contacts", patientId] });
      void qc.invalidateQueries({ queryKey: ["coordinator", "caseload"] });
    },
    onError: (err) => toast.apiError(err, "Could not log contact"),
  });

  return (
    <section aria-label="Log contact">
      <SectionTitle>Log contact</SectionTitle>
      <form onSubmit={handleSubmit((v) => m.mutate(v))} noValidate className="grid gap-3 sm:grid-cols-2">
        <Field label="Channel" required error={e.channel?.message}>
          {(id, d) => (
            <Select id={id} aria-describedby={d} {...register("channel")}>
              {CHANNELS.map((c) => (
                <option key={c} value={c}>
                  {CHANNEL_LABEL[c]}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Field label="Outcome" required error={e.outcome?.message}>
          {(id, d) => (
            <Select id={id} aria-describedby={d} {...register("outcome")}>
              {OUTCOMES.map((o) => (
                <option key={o} value={o}>
                  {OUTCOME_META[o].label}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Field label="Note" required error={e.note?.message} hint={`${noteLen}/1000`} className="sm:col-span-2">
          {(id, d) => <Textarea id={id} rows={3} aria-describedby={d} aria-invalid={!!e.note} {...register("note")} />}
        </Field>
        <Field label="Episode" hint="Optional" error={e.careEpisodeId?.message}>
          {(id, d) => (
            <Select id={id} aria-describedby={d} {...register("careEpisodeId")}>
              <option value="">Not episode-specific</option>
              {item.episodes.map((ep) => (
                <option key={ep.id} value={ep.id}>
                  {ep.title}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Field label="Follow-up (IST)" hint="Optional" error={e.followUpAt?.message}>
          {(id, d) => <Input id={id} type="datetime-local" aria-describedby={d} aria-invalid={!!e.followUpAt} {...register("followUpAt")} />}
        </Field>
        <div className="sm:col-span-2">
          <Button type="submit" loading={m.isPending} icon={<PhoneCall className="size-4" aria-hidden />}>
            Log contact
          </Button>
        </div>
      </form>
    </section>
  );
}

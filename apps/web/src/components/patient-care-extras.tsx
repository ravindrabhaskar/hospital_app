"use client";

import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Apple, CalendarCheck, Dumbbell, FlaskConical, Plus, ShieldCheck, Stethoscope, Syringe, Trash2 } from "lucide-react";
import { api } from "@/lib/api";
import {
  MEAL_SLOTS,
  type CareEpisode,
  type CheckIn,
  type CheckInStatus,
  type DietPlanInput,
  type ExercisePlanInput,
  type LabOrderStatus,
  type MealSlot,
  type PreventiveStatus,
  type SecondOpinionStatus,
} from "@/lib/api/types";
import { addDays, formatDate, formatDateTime, formatINR, humanize, todayIST } from "@/lib/format";
import { pct } from "@/lib/programs";
import { OpenOriginalButton } from "./record-file";
import { useToast } from "./toast";
import { Badge, Button, Card, Dialog, EmptyState, Field, Input, QueryView, Select, Textarea, cx, type Tone } from "./ui";

/* ---------------- §41 check-in history ---------------- */
const CHECKIN_META: Record<CheckInStatus, { tone: string; label: string; short: string }> = {
  ok: { tone: "bg-teal-bg text-primary-dark border-[#ecc9d8]", label: "Checked in", short: "OK" },
  late: { tone: "bg-peach-bg text-peach-fg border-[#f8d9b5]", label: "Late check-in", short: "Late" },
  missed: { tone: "bg-rose-bg text-danger-dark border-[#f6c9c9]", label: "Missed", short: "✕" },
  pending: { tone: "bg-white text-ink-muted border-line border-dashed", label: "Pending", short: "…" },
};

export function CheckinStrip({ patientId }: { patientId: string }) {
  const query = useQuery({ queryKey: ["checkins", patientId], queryFn: () => api.checkins.list(patientId, 30) });
  return (
    <Card title="Daily check-ins (30 days)" subtitle={'"I\'m OK" check-ins. Missed days alert family and the coordinator.'} actions={<CalendarCheck className="size-5 text-ink-muted" aria-hidden />}>
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="Daily check-in is not enabled" />}>
        {(d) => {
          const days = [...d.items].sort((a, b) => a.date.localeCompare(b.date));
          const count = (s: CheckInStatus) => days.filter((x) => x.status === s).length;
          return (
            <div className="flex flex-col gap-3">
              <ol className="flex flex-wrap gap-1" aria-label="Check-in history, oldest first">
                {days.map((c) => (
                  <CheckinCell key={c.id ?? c.date} c={c} />
                ))}
              </ol>
              <p className="text-xs text-ink-muted">
                {count("ok")} on time · {count("late")} late · <span className={count("missed") ? "font-semibold text-danger-dark" : ""}>{count("missed")} missed</span>
              </p>
            </div>
          );
        }}
      </QueryView>
    </Card>
  );
}

function CheckinCell({ c }: { c: CheckIn }) {
  const m = CHECKIN_META[c.status] ?? CHECKIN_META.pending;
  const title = `${formatDate(c.date)}: ${m.label}${c.checkedInAt ? ` at ${formatDateTime(c.checkedInAt)}` : ""}${c.mood ? ` · mood ${c.mood}/5` : ""}${c.note ? ` · ${c.note}` : ""}`;
  return (
    <li title={title} className={cx("flex size-8 flex-col items-center justify-center rounded-lg border text-[10px] font-semibold leading-none", m.tone)}>
      <span aria-hidden>{c.date.slice(8, 10)}</span>
      <span className="sr-only">{title}</span>
    </li>
  );
}

/* ---------------- §52 preventive ---------------- */
const PREV_TONE: Record<PreventiveStatus, Tone> = { overdue: "red", due: "amber", upcoming: "sky", done: "green", not_applicable: "neutral" };
const PREV_ORDER: Record<PreventiveStatus, number> = { overdue: 0, due: 1, upcoming: 2, done: 3, not_applicable: 4 };

export function PreventiveCard({ patientId }: { patientId: string }) {
  const query = useQuery({ queryKey: ["preventive", patientId], queryFn: () => api.preventive.schedule(patientId) });
  return (
    <Card title="Preventive schedule" subtitle="Vaccines and screenings by age and sex" actions={<Syringe className="size-5 text-ink-muted" aria-hidden />}>
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No preventive items" />}>
        {(d) => (
          <div className="flex flex-col gap-2">
            <ul className="flex flex-col gap-1.5">
              {[...d.items]
                .sort((a, b) => (PREV_ORDER[a.status] ?? 9) - (PREV_ORDER[b.status] ?? 9))
                .map((i) => (
                  <li key={i.code} className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-line px-3 py-2">
                    <div className="min-w-0">
                      <p className="text-sm font-semibold">
                        {i.name} <span className="font-normal text-ink-muted">· {humanize(i.category)}</span>
                      </p>
                      <p className="text-xs text-ink-muted">
                        {i.dueDate ? `Due ${formatDate(i.dueDate)}` : "No due date"}
                        {i.lastDoneAt ? ` · last done ${formatDate(i.lastDoneAt)}` : ""}
                        {i.repeatEveryMonths ? ` · every ${i.repeatEveryMonths} months` : ""}
                      </p>
                    </div>
                    <Badge tone={PREV_TONE[i.status] ?? "neutral"}>{humanize(i.status)}</Badge>
                  </li>
                ))}
            </ul>
            <p className="text-[11px] text-ink-muted">
              Schedule {d.scheduleVersion}
              {d.scheduleStatus !== "approved" ? " · fixture schedule [REQUIRES CLINICAL GOVERNANCE]" : ""}
            </p>
          </div>
        )}
      </QueryView>
    </Card>
  );
}

/* ---------------- §51 insurance ---------------- */
export function InsuranceCard({ patientId }: { patientId: string }) {
  const query = useQuery({ queryKey: ["insurance", patientId], queryFn: () => api.insurance.policies(patientId) });
  return (
    <Card title="Insurance" subtitle="Policy numbers are masked" actions={<ShieldCheck className="size-5 text-ink-muted" aria-hidden />}>
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No insurance policies on file" />}>
        {(d) => (
          <ul className="flex flex-col gap-2">
            {d.items.map((p) => (
              <li key={p.id} className="rounded-xl border border-line p-3">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <p className="font-semibold">{p.insurerName}</p>
                    <p className="font-mono text-xs">{p.policyNumberMasked}</p>
                  </div>
                  <Badge tone={p.status === "active" ? "green" : p.status === "expiring_soon" ? "amber" : "red"}>{humanize(p.status)}</Badge>
                </div>
                <p className="mt-1 text-xs text-ink-muted">
                  {[p.planName, humanize(p.type), p.sumInsured !== null ? `Sum insured ${formatINR(p.sumInsured)}` : null, p.tpaName ? `TPA ${p.tpaName}` : null]
                    .filter(Boolean)
                    .join(" · ")}
                </p>
                <p className="text-xs text-ink-muted">
                  Valid {formatDate(p.validFrom)} – {formatDate(p.validTo)}
                </p>
              </li>
            ))}
          </ul>
        )}
      </QueryView>
    </Card>
  );
}

/* ---------------- §44 lab orders / reports ---------------- */
const LAB_TONE: Record<LabOrderStatus, Tone> = {
  pending_payment: "amber",
  scheduled: "sky",
  sample_collected: "lavender",
  processing: "lavender",
  report_ready: "green",
  cancelled: "neutral",
};
export function LabStatusBadge({ status }: { status: LabOrderStatus }) {
  return <Badge tone={LAB_TONE[status] ?? "neutral"}>{humanize(status)}</Badge>;
}

export function LabOrdersCard({ patientId }: { patientId: string }) {
  const query = useQuery({ queryKey: ["lab-orders", patientId], queryFn: () => api.lab.orders({ patientId }) });
  return (
    <Card title="Lab orders & reports" actions={<FlaskConical className="size-5 text-ink-muted" aria-hidden />}>
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No lab orders" />}>
        {(d) => (
          <ul className="flex flex-col gap-2">
            {d.items.map((o) => (
              <li key={o.id} className="rounded-xl border border-line p-3">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="font-semibold">{o.tests.map((t) => t.name).join(", ") || "Lab order"}</p>
                    <p className="text-xs text-ink-muted">
                      {formatDateTime(o.createdAt)} · {o.partnerName} · {formatINR(o.total)}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <LabStatusBadge status={o.status} />
                    {o.reportRecordId && <OpenOriginalButton recordId={o.reportRecordId} label="Open report" />}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </QueryView>
    </Card>
  );
}

/* ---------------- §49 second opinions ---------------- */
export const SO_TONE: Record<SecondOpinionStatus, Tone> = { pending_payment: "amber", open: "sky", claimed: "lavender", answered: "green", cancelled: "neutral" };

export function SecondOpinionsCard({ patientId }: { patientId: string }) {
  const query = useQuery({ queryKey: ["second-opinions", patientId], queryFn: () => api.secondOpinions.forPatient(patientId) });
  return (
    <Card title="Second opinions" actions={<Stethoscope className="size-5 text-ink-muted" aria-hidden />}>
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No second-opinion requests" />}>
        {(d) => (
          <ul className="flex flex-col gap-2">
            {d.items.map((s) => (
              <li key={s.id} className="rounded-xl border border-line p-3">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="font-semibold">{humanize(s.specialty)}</p>
                    <p className="text-[13px]">{s.question}</p>
                    <p className="text-xs text-ink-muted">
                      {formatDateTime(s.createdAt)}
                      {s.doctorName ? ` · ${s.doctorName}` : ""}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge tone={SO_TONE[s.status] ?? "neutral"}>{humanize(s.status)}</Badge>
                    {s.opinionRecordId && <OpenOriginalButton recordId={s.opinionRecordId} label="Opinion PDF" />}
                  </div>
                </div>
                {s.opinion && <p className="mt-2 rounded-lg bg-mint-50 p-2 text-[13px]">{s.opinion}</p>}
              </li>
            ))}
          </ul>
        )}
      </QueryView>
    </Card>
  );
}

/* ---------------- §53 exercise plans ---------------- */
export function ExercisePlansCard({ patientId, episodes }: { patientId: string; episodes: CareEpisode[] }) {
  const [creating, setCreating] = useState(false);
  const query = useQuery({ queryKey: ["exercise-plans", patientId], queryFn: () => api.exercise.plans(patientId) });
  return (
    <Card
      title="Exercise plans"
      actions={
        <Button size="sm" variant="secondary" onClick={() => setCreating(true)} icon={<Plus className="size-4" aria-hidden />}>
          New plan
        </Button>
      }
    >
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No exercise plans" icon={<Dumbbell className="size-6" />} />}>
        {(d) => (
          <ul className="flex flex-col gap-2">
            {d.items.map((p) => (
              <ExercisePlanItemView key={p.id} plan={p} />
            ))}
          </ul>
        )}
      </QueryView>
      {creating && <ExercisePlanDialog patientId={patientId} episodes={episodes} onClose={() => setCreating(false)} />}
    </Card>
  );
}

function ExercisePlanItemView({ plan }: { plan: import("@/lib/api/types").ExercisePlan }) {
  const progress = useQuery({ queryKey: ["exercise-progress", plan.id], queryFn: () => api.exercise.progress(plan.id), retry: false });
  const lastPain = progress.data?.painTrend.at(-1);
  return (
    <li className="rounded-xl border border-line p-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <p className="font-semibold">
            {plan.items.length} {plan.items.length === 1 ? "exercise" : "exercises"} · {formatDate(plan.startDate)} – {formatDate(plan.endDate)}
          </p>
          <p className="text-xs text-ink-muted">
            By {plan.authorName} ({humanize(plan.authorRole)})
          </p>
        </div>
        <Badge tone={plan.status === "active" ? "green" : "neutral"}>{humanize(plan.status)}</Badge>
      </div>
      {progress.data && (
        <p className="mt-1 text-xs">
          Sessions {progress.data.sessionsDone}/{progress.data.sessionsPlanned} · adherence {pct(progress.data.adherencePct)}
          {lastPain ? (
            <>
              {" "}
              · last pain score <strong className={lastPain.painScore >= 8 ? "text-danger-dark" : ""}>{lastPain.painScore}/10</strong>
            </>
          ) : null}
        </p>
      )}
    </li>
  );
}

type ExRow = { exerciseId: string; sets: string; reps: string; holdSecs: string; perDay: string; notes: string };
const intIn = (s: string, min: number, max: number) => /^\d+$/.test(s.trim()) && Number(s) >= min && Number(s) <= max;

function ExercisePlanDialog({ patientId, episodes, onClose }: { patientId: string; episodes: CareEpisode[]; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [area, setArea] = useState("");
  const library = useQuery({ queryKey: ["exercise-library"], queryFn: () => api.exercise.library(), staleTime: 10 * 60_000 });
  const areas = useMemo(() => [...new Set(library.data?.items.map((e) => e.bodyArea) ?? [])].sort(), [library.data]);
  const [rows, setRows] = useState<ExRow[]>([]);
  const [startDate, setStartDate] = useState(todayIST());
  const [weeks, setWeeks] = useState("4");
  const [episodeId, setEpisodeId] = useState(episodes[0]?.id ?? "");
  const [submitted, setSubmitted] = useState(false);

  const rowErrors = rows.map((r) => ({
    sets: intIn(r.sets, 1, 10) ? undefined : "1–10",
    reps: intIn(r.reps, 1, 50) ? undefined : "1–50",
    holdSecs: !r.holdSecs.trim() || intIn(r.holdSecs, 1, 120) ? undefined : "1–120 s",
    perDay: intIn(r.perDay, 1, 6) ? undefined : "1–6",
  }));
  const formError = rows.length === 0 ? "Add at least one exercise" : !intIn(weeks, 1, 26) ? "Weeks must be 1–26" : !startDate ? "Choose a start date" : null;
  const valid = !formError && rowErrors.every((e) => Object.values(e).every((x) => !x));

  const create = useMutation({
    mutationFn: () => {
      const input: ExercisePlanInput = {
        patientId,
        startDate,
        weeks: Number(weeks),
        items: rows.map((r) => ({
          exerciseId: r.exerciseId,
          sets: Number(r.sets),
          reps: Number(r.reps),
          perDay: Number(r.perDay),
          ...(r.holdSecs.trim() ? { holdSecs: Number(r.holdSecs) } : {}),
          ...(r.notes.trim() ? { notes: r.notes.trim() } : {}),
        })),
        ...(episodeId ? { careEpisodeId: episodeId } : {}),
      };
      return api.exercise.create(input);
    },
    onSuccess: () => {
      toast.success("Exercise plan created", "The patient sees it in the app.");
      void qc.invalidateQueries({ queryKey: ["exercise-plans", patientId] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not create the plan"),
  });

  const title = (id: string) => library.data?.items.find((e) => e.id === id)?.title ?? id;

  return (
    <Dialog
      open
      size="lg"
      onClose={onClose}
      title="New exercise plan"
      description="Pick exercises from the library and set the dose."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            loading={create.isPending}
            onClick={() => {
              setSubmitted(true);
              if (valid) create.mutate();
            }}
          >
            Create plan
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <QueryView query={library} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="The exercise library is empty" />}>
          {(d) => (
            <div className="flex flex-col gap-2">
              <Field label="Body area">
                {(id) => (
                  <Select id={id} value={area} onChange={(e) => setArea(e.target.value)} data-autofocus="">
                    <option value="">All areas</option>
                    {areas.map((a) => (
                      <option key={a} value={a}>
                        {humanize(a)}
                      </option>
                    ))}
                  </Select>
                )}
              </Field>
              <ul className="grid max-h-56 gap-1.5 overflow-y-auto sm:grid-cols-2" aria-label="Exercise library">
                {d.items
                  .filter((e) => !area || e.bodyArea === area)
                  .map((e) => {
                    const added = rows.some((r) => r.exerciseId === e.id);
                    return (
                      <li key={e.id} className="flex items-center justify-between gap-2 rounded-xl border border-line px-3 py-2">
                        <span className="min-w-0">
                          <span className="block text-sm font-medium">{e.title}</span>
                          <span className="block text-xs text-ink-muted">
                            {humanize(e.bodyArea)} · {humanize(e.level)}
                            {e.precautions.length ? ` · ⚠ ${e.precautions[0]}` : ""}
                          </span>
                        </span>
                        <Button
                          size="sm"
                          variant="subtle"
                          disabled={added}
                          aria-label={`Add ${e.title}`}
                          onClick={() => setRows((r) => [...r, { exerciseId: e.id, sets: "2", reps: "10", holdSecs: "", perDay: "1", notes: "" }])}
                        >
                          {added ? "Added" : "Add"}
                        </Button>
                      </li>
                    );
                  })}
              </ul>
            </div>
          )}
        </QueryView>

        {rows.map((r, i) => {
          const e: Partial<Record<"sets" | "reps" | "holdSecs" | "perDay", string>> = submitted ? rowErrors[i]! : {};
          const set = (patch: Partial<ExRow>) => setRows((xs) => xs.map((x, j) => (j === i ? { ...x, ...patch } : x)));
          return (
            <div key={r.exerciseId} role="group" aria-label={title(r.exerciseId)} className="grid gap-2 rounded-xl border border-line p-3 sm:grid-cols-4">
              <div className="flex items-center justify-between sm:col-span-4">
                <span className="text-sm font-semibold">{title(r.exerciseId)}</span>
                <Button size="sm" variant="ghost" aria-label={`Remove ${title(r.exerciseId)}`} onClick={() => setRows((xs) => xs.filter((_, j) => j !== i))} icon={<Trash2 className="size-4" aria-hidden />} />
              </div>
              <Field label="Sets" error={e.sets}>
                {(id, d) => <Input id={id} inputMode="numeric" aria-describedby={d} value={r.sets} onChange={(ev) => set({ sets: ev.target.value })} />}
              </Field>
              <Field label="Reps" error={e.reps}>
                {(id, d) => <Input id={id} inputMode="numeric" aria-describedby={d} value={r.reps} onChange={(ev) => set({ reps: ev.target.value })} />}
              </Field>
              <Field label="Hold (s)" error={e.holdSecs} hint="Optional">
                {(id, d) => <Input id={id} inputMode="numeric" aria-describedby={d} value={r.holdSecs} onChange={(ev) => set({ holdSecs: ev.target.value })} />}
              </Field>
              <Field label="Times per day" error={e.perDay}>
                {(id, d) => <Input id={id} inputMode="numeric" aria-describedby={d} value={r.perDay} onChange={(ev) => set({ perDay: ev.target.value })} />}
              </Field>
              <Field label="Notes" className="sm:col-span-4">
                {(id) => <Input id={id} value={r.notes} onChange={(ev) => set({ notes: ev.target.value })} />}
              </Field>
            </div>
          );
        })}

        <div className="grid gap-3 sm:grid-cols-3">
          <Field label="Start date" required>
            {(id) => <Input id={id} type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} />}
          </Field>
          <Field label="Weeks" required>
            {(id) => <Input id={id} inputMode="numeric" value={weeks} onChange={(e) => setWeeks(e.target.value)} />}
          </Field>
          <Field label="Care episode" hint="Optional">
            {(id) => (
              <Select id={id} value={episodeId} onChange={(e) => setEpisodeId(e.target.value)}>
                <option value="">None</option>
                {episodes.map((e) => (
                  <option key={e.id} value={e.id}>
                    {e.title}
                  </option>
                ))}
              </Select>
            )}
          </Field>
        </div>
        {submitted && formError && (
          <p role="alert" className="text-sm text-danger-dark">
            {formError}
          </p>
        )}
      </div>
    </Dialog>
  );
}

/* ---------------- §54 diet plans ---------------- */
export function DietPlansCard({ patientId }: { patientId: string }) {
  const [creating, setCreating] = useState(false);
  const query = useQuery({ queryKey: ["diet-plans", patientId], queryFn: () => api.diet.plans(patientId) });
  return (
    <Card
      title="Diet plans"
      actions={
        <Button size="sm" variant="secondary" onClick={() => setCreating(true)} icon={<Plus className="size-4" aria-hidden />}>
          New plan
        </Button>
      }
    >
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No diet plans" icon={<Apple className="size-6" />} />}>
        {(d) => (
          <ul className="flex flex-col gap-2">
            {d.items.map((p) => (
              <li key={p.id} className="rounded-xl border border-line p-3">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <p className="font-semibold">{p.conditions.map(humanize).join(", ") || "Diet plan"}</p>
                    <p className="text-xs text-ink-muted">
                      By {p.authorName} · valid until {formatDate(p.validUntil)}
                      {p.calorieTarget ? ` · ${p.calorieTarget} kcal/day` : ""}
                    </p>
                  </div>
                  <Badge tone={p.status === "active" ? "green" : "neutral"}>{humanize(p.status)}</Badge>
                </div>
                <p className="mt-1 text-xs">
                  {p.meals.length} meals{p.avoid.length ? ` · avoid ${p.avoid.join(", ")}` : ""}
                </p>
              </li>
            ))}
          </ul>
        )}
      </QueryView>
      {creating && <DietPlanDialog patientId={patientId} onClose={() => setCreating(false)} />}
    </Card>
  );
}

type MealRow = { slot: MealSlot; items: string; notes: string };
const list = (s: string) =>
  s
    .split(/[,\n]/)
    .map((x) => x.trim())
    .filter(Boolean);

function DietPlanDialog({ patientId, onClose }: { patientId: string; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const templates = useQuery({ queryKey: ["diet-templates"], queryFn: () => api.diet.templates(), staleTime: 10 * 60_000 });
  const [templateCode, setTemplateCode] = useState("");
  const [conditions, setConditions] = useState("");
  const [calories, setCalories] = useState("");
  const [meals, setMeals] = useState<MealRow[]>([
    { slot: "breakfast", items: "", notes: "" },
    { slot: "lunch", items: "", notes: "" },
    { slot: "dinner", items: "", notes: "" },
  ]);
  const [avoid, setAvoid] = useState("");
  const [notes, setNotes] = useState("");
  const [validUntil, setValidUntil] = useState(addDays(todayIST(), 90));
  const [submitted, setSubmitted] = useState(false);
  const template = templates.data?.items.find((t) => t.code === templateCode);

  const filledMeals = meals.filter((m) => list(m.items).length > 0);
  const errors = {
    conditions: list(conditions).length === 0 ? "Add at least one condition" : undefined,
    calories: calories.trim() && !intIn(calories, 800, 5000) ? "800–5000 kcal" : undefined,
    meals: filledMeals.length === 0 ? "Add items to at least one meal" : new Set(filledMeals.map((m) => m.slot)).size !== filledMeals.length ? "Each meal slot can appear once" : undefined,
    validUntil: !validUntil || validUntil <= todayIST() ? "Choose a future date" : undefined,
  };
  const valid = Object.values(errors).every((e) => !e);

  const create = useMutation({
    mutationFn: () => {
      const input: DietPlanInput = {
        patientId,
        conditions: list(conditions),
        meals: filledMeals.map((m) => ({ slot: m.slot, items: list(m.items), ...(m.notes.trim() ? { notes: m.notes.trim() } : {}) })),
        avoid: list(avoid),
        validUntil,
        ...(templateCode ? { templateCode } : {}),
        ...(calories.trim() ? { calorieTarget: Number(calories) } : {}),
        ...(notes.trim() ? { notes: notes.trim() } : {}),
      };
      return api.diet.create(input);
    },
    onSuccess: () => {
      toast.success("Diet plan created");
      void qc.invalidateQueries({ queryKey: ["diet-plans", patientId] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not create the diet plan"),
  });

  return (
    <Dialog
      open
      size="lg"
      onClose={onClose}
      title="New diet plan"
      description="Start from a template or write the plan. Items are comma separated."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            loading={create.isPending}
            onClick={() => {
              setSubmitted(true);
              if (valid) create.mutate();
            }}
          >
            Create plan
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Template" hint={templates.isError ? "Templates could not be loaded" : "Optional"}>
            {(id, d) => (
              <Select
                id={id}
                aria-describedby={d}
                data-autofocus=""
                value={templateCode}
                onChange={(e) => {
                  setTemplateCode(e.target.value);
                  const t = templates.data?.items.find((x) => x.code === e.target.value);
                  if (t && !conditions.trim()) setConditions(t.conditions.join(", "));
                }}
              >
                <option value="">None</option>
                {templates.data?.items.map((t) => (
                  <option key={t.code} value={t.code}>
                    {t.name}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <Field label="Conditions" required error={submitted ? errors.conditions : undefined} hint="e.g. diabetes, hypertension">
            {(id, d) => <Input id={id} aria-describedby={d} value={conditions} onChange={(e) => setConditions(e.target.value)} />}
          </Field>
          <Field label="Calorie target (kcal/day)" error={submitted ? errors.calories : undefined} hint="Optional">
            {(id, d) => <Input id={id} inputMode="numeric" aria-describedby={d} value={calories} onChange={(e) => setCalories(e.target.value)} />}
          </Field>
          <Field label="Valid until" required error={submitted ? errors.validUntil : undefined}>
            {(id, d) => <Input id={id} type="date" aria-describedby={d} value={validUntil} onChange={(e) => setValidUntil(e.target.value)} />}
          </Field>
        </div>
        {template && template.status !== "approved" && (
          <p className="text-xs text-peach-fg">Template &quot;{template.name}&quot; is fixture content [REQUIRES CLINICAL GOVERNANCE].</p>
        )}
        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1 text-sm font-semibold">Meals</legend>
          {submitted && errors.meals && (
            <p role="alert" className="text-xs text-danger-dark">
              {errors.meals}
            </p>
          )}
          {meals.map((m, i) => {
            const set = (patch: Partial<MealRow>) => setMeals((xs) => xs.map((x, j) => (j === i ? { ...x, ...patch } : x)));
            return (
              <div key={i} role="group" aria-label={`Meal ${i + 1}`} className="grid gap-2 rounded-xl border border-line p-3 sm:grid-cols-[160px_1fr_auto]">
                <Field label="Slot">
                  {(id) => (
                    <Select id={id} value={m.slot} onChange={(e) => set({ slot: e.target.value as MealSlot })}>
                      {MEAL_SLOTS.map((s) => (
                        <option key={s} value={s}>
                          {humanize(s)}
                        </option>
                      ))}
                    </Select>
                  )}
                </Field>
                <Field label="Items">
                  {(id) => <Input id={id} value={m.items} onChange={(e) => set({ items: e.target.value })} placeholder="e.g. 2 phulka, dal, cucumber salad" />}
                </Field>
                <div className="flex items-end">
                  <Button size="sm" variant="ghost" aria-label={`Remove meal ${i + 1}`} onClick={() => setMeals((xs) => xs.filter((_, j) => j !== i))} icon={<Trash2 className="size-4" aria-hidden />} />
                </div>
              </div>
            );
          })}
          <Button
            size="sm"
            variant="subtle"
            className="self-start"
            disabled={meals.length >= MEAL_SLOTS.length}
            onClick={() => setMeals((xs) => [...xs, { slot: MEAL_SLOTS.find((s) => !xs.some((x) => x.slot === s)) ?? "evening", items: "", notes: "" }])}
            icon={<Plus className="size-4" aria-hidden />}
          >
            Add meal
          </Button>
        </fieldset>
        <Field label="Avoid" hint="Comma separated">
          {(id, d) => <Input id={id} aria-describedby={d} value={avoid} onChange={(e) => setAvoid(e.target.value)} placeholder="e.g. pickles, papad, sweets" />}
        </Field>
        <Field label="Notes">
          {(id) => <Textarea id={id} rows={2} value={notes} onChange={(e) => setNotes(e.target.value)} />}
        </Field>
      </div>
    </Dialog>
  );
}

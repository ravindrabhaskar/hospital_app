"use client";

import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { CartesianGrid, Line, LineChart, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Activity, AlertTriangle, CheckCircle2, LineChart as LineIcon, Pause, Play, Plus } from "lucide-react";
import { api } from "@/lib/api";
import { CHART } from "@/lib/chart-theme";
import type { CareEpisode, Enrollment, EnrollmentStatus, ProgramTemplate, VitalType } from "@/lib/api/types";
import { addDays, formatDate, formatDateTime, humanize, relativeTime, todayIST } from "@/lib/format";
import { describeThreshold, pct, thresholdsDiffer, toDraft, toThresholds, validateThresholds, vitalLabel, type ThresholdDraft } from "@/lib/programs";
import { ThresholdEditor } from "./threshold-editor";
import { useToast } from "./toast";
import { Badge, Button, Card, ChipGroup, Dialog, EmptyState, Field, Input, QueryView, Select, Table, Td, Th, type Tone } from "./ui";

const STATUS_TONE: Record<EnrollmentStatus, Tone> = { active: "green", paused: "amber", completed: "neutral" };

/** §42 care-program enrollments on the clinical snapshot. */
export function ProgramsCard({ patientId, episodes }: { patientId: string; episodes: CareEpisode[] }) {
  const [enrolling, setEnrolling] = useState(false);
  const query = useQuery({ queryKey: ["enrollments", patientId], queryFn: () => api.programs.enrollments({ patientId }) });
  return (
    <Card
      title="Care programs"
      subtitle="Remote monitoring. Readings are checked against the thresholds; breaches create safety events."
      actions={
        <Button size="sm" variant="secondary" onClick={() => setEnrolling(true)} icon={<Plus className="size-4" aria-hidden />}>
          Enrol
        </Button>
      }
    >
      <QueryView
        query={query}
        isEmpty={(d) => d.items.length === 0}
        empty={<EmptyState title="Not enrolled in a program" icon={<Activity className="size-6" />} description="Enrol the patient in hypertension, diabetes or heart-failure monitoring." />}
      >
        {(d) => (
          <ul className="flex flex-col gap-3">
            {d.items.map((e) => (
              <EnrollmentItem key={e.id} e={e} />
            ))}
          </ul>
        )}
      </QueryView>
      {enrolling && <EnrolDialog patientId={patientId} episodes={episodes} onClose={() => setEnrolling(false)} />}
    </Card>
  );
}

function EnrollmentItem({ e }: { e: Enrollment }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [showTrend, setShowTrend] = useState(false);
  const update = useMutation({
    mutationFn: (status: EnrollmentStatus) => api.programs.updateEnrollment(e.id, { status }),
    onSuccess: (x) => {
      toast.success(`Program ${x.status === "active" ? "resumed" : x.status}`, x.templateName);
      void qc.invalidateQueries({ queryKey: ["enrollments", e.patientId] });
    },
    onError: (err) => toast.apiError(err, "Could not update the enrollment"),
  });

  return (
    <li className="rounded-xl border border-line p-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <p className="flex flex-wrap items-center gap-2 font-semibold">
            {e.templateName}
            <Badge tone={STATUS_TONE[e.status] ?? "neutral"}>{humanize(e.status)}</Badge>
            {e.openBreaches > 0 && (
              <Badge tone="red" icon={<AlertTriangle className="size-3" aria-hidden />}>
                {e.openBreaches} open {e.openBreaches === 1 ? "breach" : "breaches"}
              </Badge>
            )}
          </p>
          <p className="text-xs text-ink-muted">
            From {formatDate(e.startDate)}
            {e.endDate ? ` to ${formatDate(e.endDate)}` : ""} · last reading {e.lastReadingAt ? relativeTime(e.lastReadingAt) : "never"}
            {e.thresholdsApprovedByName ? ` · thresholds approved by ${e.thresholdsApprovedByName}` : ""}
          </p>
        </div>
        <div className="text-right">
          <p className="text-xs text-ink-muted">Adherence (7 days)</p>
          <p className="text-lg font-semibold tabular-nums">{pct(e.adherencePct7d)}</p>
        </div>
      </div>
      {e.thresholds.length > 0 && (
        <ul className="mt-2 flex flex-wrap gap-1.5" aria-label="Thresholds">
          {e.thresholds.map((t, i) => (
            <li key={i}>
              <Badge tone={t.level === "emergency" ? "dark" : t.level === "urgent" ? "red" : "neutral"} title={t.message}>
                {describeThreshold(t)}
              </Badge>
            </li>
          ))}
        </ul>
      )}
      <div className="mt-3 flex flex-wrap gap-2">
        <Button size="sm" variant="subtle" aria-expanded={showTrend} onClick={() => setShowTrend((s) => !s)} icon={<LineIcon className="size-4" aria-hidden />}>
          {showTrend ? "Hide trend" : "Trend & breaches"}
        </Button>
        {e.status === "active" && (
          <Button size="sm" variant="ghost" loading={update.isPending && update.variables === "paused"} onClick={() => update.mutate("paused")} icon={<Pause className="size-4" aria-hidden />}>
            Pause
          </Button>
        )}
        {e.status === "paused" && (
          <Button size="sm" variant="ghost" loading={update.isPending && update.variables === "active"} onClick={() => update.mutate("active")} icon={<Play className="size-4" aria-hidden />}>
            Resume
          </Button>
        )}
        {e.status !== "completed" && (
          <Button size="sm" variant="ghost" loading={update.isPending && update.variables === "completed"} onClick={() => update.mutate("completed")} icon={<CheckCircle2 className="size-4" aria-hidden />}>
            Complete
          </Button>
        )}
      </div>
      {showTrend && <ProgramTrend e={e} />}
    </li>
  );
}

function ProgramTrend({ e }: { e: Enrollment }) {
  const [days, setDays] = useState<"14" | "30">("14");
  const to = todayIST();
  const from = addDays(to, -Number(days));
  const query = useQuery({
    queryKey: ["enrollment-summary", e.id, from, to],
    queryFn: () => api.programs.summary(e.id, { from, to }),
  });
  return (
    <div className="mt-3 flex flex-col gap-3 border-t border-line pt-3">
      <ChipGroup<"14" | "30"> label="Trend period" value={days} onChange={setDays} options={[{ value: "14", label: "14 days" }, { value: "30", label: "30 days" }]} />
      <QueryView query={query}>
        {(s) => (
          <div className="flex flex-col gap-3">
            <p className="text-sm">
              Readings received <strong className="tabular-nums">{s.receivedReadings}</strong> of {s.expectedReadings} expected · adherence{" "}
              <strong>{pct(s.adherencePct)}</strong>
            </p>
            <TrendChart summary={s} thresholds={e.thresholds} />
            <div>
              <p className="mb-1 text-sm font-semibold">Breaches</p>
              {s.breaches.length === 0 ? (
                <p className="text-sm text-ink-muted">No threshold breaches in this period.</p>
              ) : (
                <Table caption="Threshold breaches in this period" className="[&_table]:min-w-[480px]">
                  <thead>
                    <tr>
                      <Th>When</Th>
                      <Th>Reading</Th>
                      <Th>Threshold</Th>
                    </tr>
                  </thead>
                  <tbody>
                    {s.breaches.map((b, i) => (
                      <tr key={i}>
                        <Td className="whitespace-nowrap">{formatDateTime(b.at)}</Td>
                        <Td>
                          {vitalLabel(b.type)} {b.value}
                        </Td>
                        <Td>
                          <Badge tone={b.threshold.level === "emergency" ? "dark" : b.threshold.level === "urgent" ? "red" : "neutral"}>{describeThreshold(b.threshold)}</Badge>
                        </Td>
                      </tr>
                    ))}
                  </tbody>
                </Table>
              )}
            </div>
          </div>
        )}
      </QueryView>
    </div>
  );
}

/** One vital at a time (single series, one y-scale): daily average with min–max in the tooltip and threshold reference lines. */
function TrendChart({ summary, thresholds }: { summary: { trend: { date: string; type: VitalType; avg: number; min: number; max: number }[] }; thresholds: Enrollment["thresholds"] }) {
  const types = useMemo(() => [...new Set(summary.trend.map((t) => t.type))], [summary.trend]);
  const [picked, setPicked] = useState<VitalType | null>(null);
  const type = picked && types.includes(picked) ? picked : types[0];
  if (!type) return <p className="text-sm text-ink-muted">No readings in this period.</p>;
  const data = summary.trend
    .filter((t) => t.type === type)
    .sort((a, b) => a.date.localeCompare(b.date))
    .map((t) => ({ ...t, label: formatDate(t.date).slice(0, 6) }));
  const lines = thresholds.filter((t) => t.type === type);
  return (
    <div className="flex flex-col gap-2">
      {types.length > 1 && (
        <ChipGroup<VitalType> label="Vital shown in the chart" value={type} onChange={setPicked} options={types.map((t) => ({ value: t, label: vitalLabel(t) }))} />
      )}
      <figure aria-label={`${vitalLabel(type)} daily average`} className="h-56 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 8, right: 16, left: 0, bottom: 0 }}>
            <CartesianGrid stroke={CHART.grid} vertical={false} />
            <XAxis dataKey="label" tick={{ fontSize: 11, fill: CHART.inkMuted }} tickLine={false} axisLine={{ stroke: CHART.grid }} />
            <YAxis tick={{ fontSize: 11, fill: CHART.inkMuted }} tickLine={false} axisLine={false} width={40} domain={["auto", "auto"]} />
            <Tooltip
              formatter={(v) => [String(v ?? "—"), "Average"]}
              labelFormatter={(_l, p) => {
                const row = p?.[0]?.payload as (typeof data)[number] | undefined;
                return row ? `${formatDate(row.date)} · min ${row.min} · max ${row.max}` : "";
              }}
            />
            {lines.map((t, i) => (
              <ReferenceLine key={i} y={t.value} stroke={t.level === "routine" ? CHART.warning : CHART.danger} strokeDasharray="4 4" label={{ value: `${t.op === "gt" ? ">" : "<"} ${t.value} ${t.level}`, fontSize: 10, fill: CHART.inkMuted, position: "insideTopRight" }} />
            ))}
            <Line type="monotone" dataKey="avg" stroke={CHART.series} strokeWidth={2} dot={{ r: 3, fill: CHART.series, stroke: CHART.surface, strokeWidth: 2 }} activeDot={{ r: 5 }} isAnimationActive={false} />
          </LineChart>
        </ResponsiveContainer>
      </figure>
      <details className="text-[13px]">
        <summary className="cursor-pointer font-medium text-primary-light">Show as table</summary>
        <Table caption={`${vitalLabel(type)} daily values`} className="[&_table]:min-w-[360px]">
          <thead>
            <tr>
              <Th>Date</Th>
              <Th className="text-right">Average</Th>
              <Th className="text-right">Min</Th>
              <Th className="text-right">Max</Th>
            </tr>
          </thead>
          <tbody>
            {data.map((r) => (
              <tr key={r.date}>
                <Td>{formatDate(r.date)}</Td>
                <Td className="text-right tabular-nums">{r.avg}</Td>
                <Td className="text-right tabular-nums">{r.min}</Td>
                <Td className="text-right tabular-nums">{r.max}</Td>
              </tr>
            ))}
          </tbody>
        </Table>
      </details>
    </div>
  );
}

function EnrolDialog({ patientId, episodes, onClose }: { patientId: string; episodes: CareEpisode[]; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const templates = useQuery({ queryKey: ["program-templates"], queryFn: () => api.programs.templates(), staleTime: 5 * 60_000 });
  const [code, setCode] = useState("");
  const [drafts, setDrafts] = useState<ThresholdDraft[]>([]);
  const [startDate, setStartDate] = useState(todayIST());
  const [endDate, setEndDate] = useState("");
  const [episodeId, setEpisodeId] = useState(episodes[0]?.id ?? "");
  const [submitted, setSubmitted] = useState(false);
  const template: ProgramTemplate | undefined = templates.data?.items.find((t) => t.code === code);
  const validation = validateThresholds(drafts);
  const dateError = endDate && endDate < startDate ? "End date is before the start date" : null;

  const pick = (c: string) => {
    setCode(c);
    const t = templates.data?.items.find((x) => x.code === c);
    setDrafts(t ? t.defaultThresholds.map(toDraft) : []);
  };

  const enrol = useMutation({
    mutationFn: () => {
      const thresholds = toThresholds(drafts);
      return api.programs.enroll({
        patientId,
        templateCode: code,
        startDate,
        ...(template && thresholdsDiffer(thresholds, template.defaultThresholds) ? { thresholds } : {}),
        ...(endDate ? { endDate } : {}),
        ...(episodeId ? { careEpisodeId: episodeId } : {}),
      });
    },
    onSuccess: (e) => {
      toast.success("Patient enrolled", e.templateName);
      void qc.invalidateQueries({ queryKey: ["enrollments", patientId] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not enrol the patient"),
  });

  const submit = () => {
    setSubmitted(true);
    if (!code || !validation.ok || dateError || !startDate) return;
    enrol.mutate();
  };

  return (
    <Dialog
      open
      size="lg"
      onClose={onClose}
      title="Enrol in a care program"
      description="Thresholds start from the template defaults; edits are yours as the prescribing doctor and are audited."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={submit} loading={enrol.isPending}>
            Enrol patient
          </Button>
        </>
      }
    >
      <QueryView query={templates} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No program templates" />}>
        {(d) => (
          <div className="flex flex-col gap-4">
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Program" required error={submitted && !code ? "Choose a program" : undefined}>
                {(id, dsc) => (
                  <Select id={id} aria-describedby={dsc} value={code} onChange={(e) => pick(e.target.value)} data-autofocus="">
                    <option value="">Choose…</option>
                    {d.items.map((t) => (
                      <option key={t.code} value={t.code}>
                        {t.name} (v{t.version})
                      </option>
                    ))}
                  </Select>
                )}
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
              <Field label="Start date" required>
                {(id) => <Input id={id} type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} />}
              </Field>
              <Field label="End date" hint="Optional" error={submitted ? (dateError ?? undefined) : undefined}>
                {(id, dsc) => <Input id={id} type="date" aria-describedby={dsc} value={endDate} min={startDate} onChange={(e) => setEndDate(e.target.value)} />}
              </Field>
            </div>
            {template && (
              <div className="flex flex-col gap-2 rounded-xl bg-mint-50 p-3 text-[13px]">
                <p>{template.description}</p>
                <p className="text-ink-muted">
                  Readings: {template.metrics.map((m) => `${vitalLabel(m.type)} (${humanize(m.frequency).toLowerCase()}, ${m.unit})`).join(", ")}
                </p>
                {template.status !== "approved" && (
                  <p className="flex items-start gap-1.5 font-medium text-peach-fg">
                    <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
                    Default thresholds are fixture values [REQUIRES CLINICAL GOVERNANCE]. Review each one before enrolling.
                  </p>
                )}
              </div>
            )}
            {code && <ThresholdEditor value={drafts} onChange={setDrafts} validation={validation} showErrors={submitted} />}
            <p className="text-xs text-ink-muted">A program never lowers a safety level: the deterministic safety engine still evaluates every reading.</p>
          </div>
        )}
      </QueryView>
    </Dialog>
  );
}

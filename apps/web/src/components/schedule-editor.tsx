"use client";

import { useMemo, useRef, useState } from "react";
import { useQueries } from "@tanstack/react-query";
import { AlertTriangle, CalendarOff, CalendarPlus, Info, Plus, Save, RefreshCw, Trash2, Undo2 } from "lucide-react";
import { ApiError, api } from "@/lib/api";
import { CONSULT_MODES, SLOT_MINS } from "@/lib/api/types";
import type { AddLeaveResponse, Appointment, ConsultMode, Leave, Schedule, Slot, SlotMins, WeeklyBlock } from "@/lib/api/types";
import { addDays, formatDate, formatTime, todayIST } from "@/lib/format";
import { MODE_LABEL, WEEKDAYS, newBlock, slotCount, sortBlocks, validateWeekly } from "@/lib/schedule";
import { AppointmentStatusBadge } from "./status";
import { useToast } from "./toast";
import { Badge, Button, Card, Dialog, EmptyState, Field, Input, Select, Spinner, Table, Td, Th, cx, errorMessage, type Tone } from "./ui";

/* =============================== Weekly template editor =============================== */

interface Row {
  k: number;
  b: WeeklyBlock;
}

const weeklyKey = (w: WeeklyBlock[]) => JSON.stringify(sortBlocks(w));

export function ScheduleEditor({
  schedule,
  onSave,
  saving,
  readOnly,
}: {
  schedule: Schedule;
  /** Receives the blocks sorted Mon→Sun, then by start time. Errors are expected to be surfaced by the caller. */
  onSave: (weekly: WeeklyBlock[]) => Promise<unknown>;
  saving?: boolean;
  readOnly?: boolean;
}) {
  const nextKey = useRef(0);
  const toRows = (w: WeeklyBlock[]): Row[] => sortBlocks(w).map((b) => ({ k: nextKey.current++, b }));

  const sourceKey = weeklyKey(schedule.weekly);
  const [baseKey, setBaseKey] = useState(sourceKey);
  const [rows, setRows] = useState<Row[]>(() => toRows(schedule.weekly));
  // Adopt a new server copy (e.g. after a save) — the "adjust state when a prop changes" pattern.
  if (sourceKey !== baseKey) {
    setBaseKey(sourceKey);
    setRows(toRows(schedule.weekly));
  }

  const blocks = rows.map((r) => r.b);
  const errors = validateWeekly(blocks);
  const invalid = Object.keys(errors).length > 0;
  const dirty = weeklyKey(blocks) !== sourceKey;
  const totalSlots = blocks.reduce((n, b) => n + slotCount(b), 0);

  const update = (k: number, patch: Partial<WeeklyBlock>) =>
    setRows((rs) => rs.map((r) => (r.k === k ? { ...r, b: { ...r.b, ...patch } } : r)));
  const remove = (k: number) => setRows((rs) => rs.filter((r) => r.k !== k));
  const add = (weekday: WeeklyBlock["weekday"]) =>
    setRows((rs) => [...rs, { k: nextKey.current++, b: newBlock(weekday, rs.map((r) => r.b)) }]);
  const toggleMode = (r: Row, mode: ConsultMode, on: boolean) =>
    update(r.k, { modes: on ? CONSULT_MODES.filter((m) => m === mode || r.b.modes.includes(m)) : r.b.modes.filter((m) => m !== mode) });

  const save = async () => {
    if (invalid || readOnly) return;
    try {
      await onSave(sortBlocks(blocks));
    } catch {
      // The caller shows the error (e.g. toast.apiError on VALIDATION_ERROR); keep the edits so they can be fixed.
    }
  };

  return (
    <Card
      title="Weekly template"
      subtitle={`Times are ${schedule.timezone} (IST). ${blocks.length} block${blocks.length === 1 ? "" : "s"} · ${totalSlots} slots per week`}
      actions={
        !readOnly && (
          <>
            <Button
              variant="ghost"
              size="sm"
              disabled={!dirty || saving}
              onClick={() => setRows(toRows(schedule.weekly))}
              icon={<Undo2 className="size-4" aria-hidden />}
            >
              Discard changes
            </Button>
            <Button size="sm" loading={saving} disabled={invalid || !dirty} onClick={() => void save()} icon={<Save className="size-4" aria-hidden />}>
              Save schedule
            </Button>
          </>
        )
      }
    >
      <p className="mb-4 flex items-start gap-2 rounded-xl bg-sky-bg px-3.5 py-2.5 text-[13px] text-sky-fg">
        <Info className="mt-0.5 size-4 shrink-0" aria-hidden />
        <span>
          Saving regenerates unbooked future slots for the next {schedule.horizonDays} days; booked and held slots are never touched.
          All times are in {schedule.timezone} (IST).
        </span>
      </p>
      {invalid && !readOnly && (
        <p role="alert" className="mb-4 rounded-xl bg-rose-bg px-3.5 py-2.5 text-[13px] text-danger-dark">
          Fix the highlighted blocks before saving.
        </p>
      )}

      <div className="flex flex-col divide-y divide-line">
        {WEEKDAYS.map((day) => {
          const dayRows = rows.filter((r) => r.b.weekday === day.value);
          const daySlots = dayRows.reduce((n, r) => n + slotCount(r.b), 0);
          return (
            <section key={day.value} aria-label={day.long} className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 md:flex-row md:gap-5">
              <div className="flex items-center justify-between md:w-36 md:shrink-0 md:flex-col md:items-start md:justify-start">
                <h3 className="text-sm font-semibold text-ink">{day.long}</h3>
                <p className="text-xs text-ink-muted">{dayRows.length ? `${daySlots} slots` : "Unavailable"}</p>
              </div>
              <div className="flex min-w-0 flex-1 flex-col gap-3">
                {dayRows.map((r, n) => {
                  const idx = rows.indexOf(r);
                  const err = errors[idx];
                  const label = `${day.long} block ${n + 1}`;
                  const errId = `sched-err-${r.k}`;
                  return (
                    <div
                      key={r.k}
                      role="group"
                      aria-label={label}
                      className={cx("rounded-xl border p-3", err ? "border-[#f6c9c9] bg-rose-bg/40" : "border-line")}
                    >
                      <div className="grid gap-3 sm:grid-cols-[1fr_1fr_1fr] lg:grid-cols-[120px_120px_130px_1fr_auto]">
                        <Field label="Start">
                          {(id) => (
                            <Input
                              id={id}
                              type="time"
                              step={300}
                              aria-label={`${label} start`}
                              aria-invalid={!!err}
                              aria-describedby={err ? errId : undefined}
                              disabled={readOnly}
                              value={r.b.start}
                              onChange={(e) => update(r.k, { start: e.target.value })}
                            />
                          )}
                        </Field>
                        <Field label="End">
                          {(id) => (
                            <Input
                              id={id}
                              type="time"
                              step={300}
                              aria-label={`${label} end`}
                              aria-invalid={!!err}
                              aria-describedby={err ? errId : undefined}
                              disabled={readOnly}
                              value={r.b.end}
                              onChange={(e) => update(r.k, { end: e.target.value })}
                            />
                          )}
                        </Field>
                        <Field label="Slot length">
                          {(id) => (
                            <Select
                              id={id}
                              aria-label={`${label} slot length`}
                              disabled={readOnly}
                              value={r.b.slotMins}
                              onChange={(e) => update(r.k, { slotMins: Number(e.target.value) as SlotMins })}
                            >
                              {SLOT_MINS.map((m) => (
                                <option key={m} value={m}>
                                  {m} min
                                </option>
                              ))}
                            </Select>
                          )}
                        </Field>
                        <fieldset className="flex flex-col gap-1 sm:col-span-3 lg:col-span-1">
                          <legend className="mb-1 text-[13px] font-medium text-ink">Modes</legend>
                          <div className="flex flex-wrap gap-x-4 gap-y-2">
                            {CONSULT_MODES.map((m) => (
                              <label key={m} className="flex items-center gap-1.5 text-sm">
                                <input
                                  type="checkbox"
                                  className="size-4 accent-[#631D3F]"
                                  disabled={readOnly}
                                  checked={r.b.modes.includes(m)}
                                  onChange={(e) => toggleMode(r, m, e.target.checked)}
                                  aria-label={`${label}: ${MODE_LABEL[m]}`}
                                />
                                {MODE_LABEL[m]}
                              </label>
                            ))}
                          </div>
                        </fieldset>
                        <div className="flex items-end justify-between gap-2 sm:col-span-3 lg:col-span-1 lg:flex-col lg:items-end">
                          <Badge tone={slotCount(r.b) ? "green" : "neutral"}>{slotCount(r.b)} slots</Badge>
                          {!readOnly && (
                            <Button variant="ghost" size="sm" onClick={() => remove(r.k)} aria-label={`Remove ${label}`}>
                              <Trash2 className="size-4" aria-hidden />
                            </Button>
                          )}
                        </div>
                      </div>
                      {err && (
                        <p id={errId} className="mt-2 text-xs text-danger-dark">
                          {err}
                        </p>
                      )}
                    </div>
                  );
                })}
                {!readOnly && (
                  <Button
                    variant="subtle"
                    size="sm"
                    className="self-start"
                    onClick={() => add(day.value)}
                    icon={<Plus className="size-4" aria-hidden />}
                    aria-label={`Add block on ${day.long}`}
                  >
                    Add block
                  </Button>
                )}
              </div>
            </section>
          );
        })}
      </div>
    </Card>
  );
}

/* =============================== Leaves =============================== */

export function LeavesPanel({
  leaves,
  onAdd,
  onRemove,
  readOnlyNote,
}: {
  leaves: Leave[];
  /** Omit for a read-only panel (admins have no leave endpoints). */
  onAdd?: (input: { date: string; reason?: string }) => Promise<AddLeaveResponse>;
  onRemove?: (id: string) => Promise<unknown>;
  readOnlyNote?: string;
}) {
  const toast = useToast();
  const today = todayIST();
  const [date, setDate] = useState("");
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | undefined>();
  const [adding, setAdding] = useState(false);
  const [removingId, setRemovingId] = useState<string | null>(null);
  const [conflicts, setConflicts] = useState<{ date: string; items: Appointment[] } | null>(null);
  const sorted = useMemo(() => [...leaves].sort((a, b) => a.date.localeCompare(b.date)), [leaves]);

  const submit = async () => {
    if (!onAdd) return;
    let msg: string | undefined;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) msg = "Choose a date";
    else if (date < today) msg = "The date must be today or later";
    else if (leaves.some((l) => l.date === date)) msg = "You are already on leave that day";
    setError(msg);
    if (msg) return;
    setAdding(true);
    try {
      const res = await onAdd({ date, ...(reason.trim() ? { reason: reason.trim() } : {}) });
      setDate("");
      setReason("");
      if (res.conflicts.length > 0) setConflicts({ date: res.leave.date, items: res.conflicts });
      else toast.success("Leave added", `${formatDate(res.leave.date)}: no appointments were booked that day.`);
    } catch (e) {
      toast.apiError(e, "Could not add the leave");
    } finally {
      setAdding(false);
    }
  };

  const remove = async (l: Leave) => {
    if (!onRemove) return;
    setRemovingId(l.id);
    try {
      await onRemove(l.id);
      toast.success("Leave removed", `Slots for ${formatDate(l.date)} are regenerated from the weekly template.`);
    } catch (e) {
      toast.apiError(e, "Could not remove the leave");
    } finally {
      setRemovingId(null);
    }
  };

  return (
    <Card title="Leaves" subtitle="Dates in IST. A leave removes that day's unbooked slots.">
      {onAdd ? (
        <form
          noValidate
          className="mb-4 grid gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            void submit();
          }}
        >
          <Field label="Date" required error={error}>
            {(id, d) => (
              <Input id={id} type="date" min={today} aria-describedby={d} aria-invalid={!!error} value={date} onChange={(e) => setDate(e.target.value)} />
            )}
          </Field>
          <Field label="Reason (optional)">
            {(id) => <Input id={id} maxLength={200} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Conference, personal…" />}
          </Field>
          <Button type="submit" loading={adding} icon={<CalendarPlus className="size-4" aria-hidden />}>
            Add leave
          </Button>
        </form>
      ) : (
        readOnlyNote && <p className="mb-3 text-[13px] text-ink-muted">{readOnlyNote}</p>
      )}

      {sorted.length === 0 ? (
        <EmptyState title="No leaves" description="Days off appear here." icon={<CalendarOff className="size-6" />} />
      ) : (
        <ul className="flex flex-col divide-y divide-line" aria-label="Leaves">
          {sorted.map((l) => {
            const past = l.date < today;
            return (
              <li key={l.id} className={cx("flex items-center justify-between gap-3 py-2.5", past && "opacity-60")}>
                <div>
                  <p className="text-sm font-semibold">
                    {formatDate(l.date)} {past && <span className="text-xs font-normal text-ink-muted">(past)</span>}
                  </p>
                  {l.reason && <p className="text-xs text-ink-muted">{l.reason}</p>}
                </div>
                {onRemove && !past && (
                  <Button
                    variant="ghost"
                    size="sm"
                    loading={removingId === l.id}
                    onClick={() => void remove(l)}
                    aria-label={`Remove leave on ${formatDate(l.date)}`}
                    icon={<Trash2 className="size-4" aria-hidden />}
                  >
                    Remove
                  </Button>
                )}
              </li>
            );
          })}
        </ul>
      )}

      {conflicts && (
        <Dialog
          open
          size="lg"
          onClose={() => setConflicts(null)}
          title="Appointments on this day"
          description={`Leave added for ${formatDate(conflicts.date)}.`}
          footer={<Button onClick={() => setConflicts(null)}>I understand</Button>}
        >
          <p className="mb-3 rounded-xl bg-peach-bg px-3.5 py-2.5 text-[13px] text-peach-fg">
            These {conflicts.items.length} appointment{conflicts.items.length === 1 ? " is" : "s are"} <strong>not</strong> cancelled
            automatically. Please reschedule them with the patients or ask the care team to help.
          </p>
          <Table caption="Appointments that conflict with the leave">
            <thead>
              <tr>
                <Th>Patient</Th>
                <Th>Time (IST)</Th>
                <Th>Mode</Th>
                <Th>Status</Th>
              </tr>
            </thead>
            <tbody>
              {conflicts.items.map((a) => (
                <tr key={a.id}>
                  <Td className="font-semibold">{a.patientName}</Td>
                  <Td className="whitespace-nowrap">
                    {formatTime(a.startAt)} – {formatTime(a.endAt)}
                  </Td>
                  <Td>{MODE_LABEL[a.mode] ?? a.mode}</Td>
                  <Td>
                    <AppointmentStatusBadge status={a.status} />
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
        </Dialog>
      )}
    </Card>
  );
}

/* =============================== Slots preview =============================== */

const SLOT_TONE: Record<Slot["status"], Tone> = { available: "green", booked: "sky", held: "amber" };

function dayLabel(date: string) {
  const [y, m, d] = date.split("-").map(Number);
  return new Intl.DateTimeFormat("en-IN", { weekday: "short", day: "2-digit", month: "short", timeZone: "UTC" }).format(
    new Date(Date.UTC(y ?? 1970, (m ?? 1) - 1, d ?? 1)),
  );
}

export function slotsQueryKey(doctorId: string, date?: string) {
  return date ? ["doctor-slots", doctorId, date] : ["doctor-slots", doctorId];
}

export function SlotsPreview({ doctorId, days = 7 }: { doctorId: string; days?: number }) {
  const today = todayIST();
  const dates = Array.from({ length: days }, (_, i) => addDays(today, i));
  const results = useQueries({
    queries: dates.map((date) => ({
      queryKey: slotsQueryKey(doctorId, date),
      queryFn: () => api.doctors.slots(doctorId, date),
      enabled: !!doctorId,
    })),
  });

  return (
    <Card title="Upcoming slots" subtitle={`Next ${days} days (IST), as patients see them`}>
      <div className="mb-3 flex flex-wrap gap-2 text-xs" aria-label="Legend">
        <Badge tone="green">Available</Badge>
        <Badge tone="sky">Booked</Badge>
        <Badge tone="amber">Held</Badge>
      </div>
      <ul className="flex flex-col divide-y divide-line">
        {dates.map((date, i) => {
          const q = results[i]!;
          const items = q.data?.items ?? [];
          const available = items.filter((s) => s.status === "available").length;
          return (
            <li key={date} className="flex flex-col gap-2 py-3 md:flex-row md:gap-4">
              <div className="md:w-36 md:shrink-0">
                <p className="text-sm font-semibold">{dayLabel(date)}</p>
                {q.isSuccess && (
                  <p className="text-xs text-ink-muted">
                    {available} available / {items.length} total
                  </p>
                )}
              </div>
              <div className="min-w-0 flex-1">
                {q.isPending ? (
                  <Spinner label={`Loading slots for ${dayLabel(date)}`} />
                ) : q.isError ? (
                  <div role="alert" className="flex flex-wrap items-center gap-2 text-sm text-danger-dark">
                    <AlertTriangle className="size-4" aria-hidden />
                    {q.error instanceof ApiError && q.error.status === 403 ? "You don't have access to these slots." : errorMessage(q.error)}
                    <Button variant="ghost" size="sm" onClick={() => void q.refetch()} icon={<RefreshCw className="size-4" aria-hidden />}>
                      Retry
                    </Button>
                  </div>
                ) : items.length === 0 ? (
                  <p className="text-sm text-ink-muted">No slots</p>
                ) : (
                  <ul className="flex flex-wrap gap-1.5" aria-label={`Slots on ${dayLabel(date)}`}>
                    {items.map((s) => (
                      <li key={s.id}>
                        <Badge
                          tone={SLOT_TONE[s.status] ?? "neutral"}
                          title={`${s.status}${s.modes?.length ? ` · ${s.modes.map((m) => MODE_LABEL[m as ConsultMode] ?? m).join(", ")}` : ""}`}
                        >
                          {formatTime(s.startAt)}
                          <span className="sr-only"> {s.status}</span>
                          {s.modes?.length ? (
                            <span className="text-[10px] opacity-75">
                              {" "}
                              · {s.modes.map((m) => MODE_LABEL[m as ConsultMode] ?? m).join("/")}
                            </span>
                          ) : null}
                        </Badge>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </li>
          );
        })}
      </ul>
    </Card>
  );
}

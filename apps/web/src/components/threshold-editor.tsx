"use client";

import { Plus, Trash2 } from "lucide-react";
import type { VitalType } from "@/lib/api/types";
import { humanize } from "@/lib/format";
import { MAX_THRESHOLDS, THRESHOLD_LEVELS, VITAL_TYPES, emptyDraft, vitalLabel, type ThresholdDraft, type ThresholdValidation } from "@/lib/programs";
import { Button, Field, Input, Select } from "./ui";

/**
 * Editable list of program thresholds (§42). Controlled: the parent keeps the drafts and runs
 * `validateThresholds`; errors are only shown once `showErrors` is set (after a submit attempt).
 */
export function ThresholdEditor({
  value,
  onChange,
  validation,
  showErrors,
  label = "Alert thresholds",
}: {
  value: ThresholdDraft[];
  onChange: (v: ThresholdDraft[]) => void;
  validation: ThresholdValidation;
  showErrors: boolean;
  label?: string;
}) {
  const set = (i: number, patch: Partial<ThresholdDraft>) => onChange(value.map((d, j) => (j === i ? { ...d, ...patch } : d)));
  return (
    <fieldset className="flex flex-col gap-3">
      <legend className="mb-1 text-sm font-semibold">{label}</legend>
      {showErrors && validation.form.length > 0 && (
        <ul role="alert" className="text-xs text-danger-dark">
          {validation.form.map((f) => (
            <li key={f}>{f}</li>
          ))}
        </ul>
      )}
      {value.length === 0 && <p className="text-sm text-ink-muted">No thresholds. Readings will not raise program alerts.</p>}
      {value.map((d, i) => {
        const e = showErrors ? (validation.rows[i] ?? {}) : {};
        return (
          <div key={i} role="group" aria-label={`Threshold ${i + 1}`} className="grid gap-2 rounded-xl border border-line p-3 sm:grid-cols-[1.3fr_0.9fr_0.8fr_1fr_auto]">
            <Field label="Vital" error={e.type}>
              {(id, dsc) => (
                <Select id={id} aria-describedby={dsc} value={d.type} onChange={(ev) => set(i, { type: ev.target.value as VitalType })}>
                  {VITAL_TYPES.map((t) => (
                    <option key={t} value={t}>
                      {vitalLabel(t)}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            <Field label="When" error={e.op}>
              {(id, dsc) => (
                <Select id={id} aria-describedby={dsc} value={d.op} onChange={(ev) => set(i, { op: ev.target.value as "lt" | "gt" })}>
                  <option value="gt">Above (&gt;)</option>
                  <option value="lt">Below (&lt;)</option>
                </Select>
              )}
            </Field>
            <Field label="Value" error={e.value}>
              {(id, dsc) => (
                <Input
                  id={id}
                  inputMode="decimal"
                  aria-describedby={dsc}
                  aria-invalid={!!e.value}
                  value={d.value}
                  onChange={(ev) => set(i, { value: ev.target.value })}
                />
              )}
            </Field>
            <Field label="Level" error={e.level}>
              {(id, dsc) => (
                <Select id={id} aria-describedby={dsc} value={d.level} onChange={(ev) => set(i, { level: ev.target.value as ThresholdDraft["level"] })}>
                  {THRESHOLD_LEVELS.map((l) => (
                    <option key={l} value={l}>
                      {humanize(l)}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            <div className="flex items-end">
              <Button variant="ghost" size="sm" onClick={() => onChange(value.filter((_, j) => j !== i))} aria-label={`Remove threshold ${i + 1}`} icon={<Trash2 className="size-4" aria-hidden />}>
                <span className="sm:sr-only">Remove</span>
              </Button>
            </div>
            <Field label="Alert message" error={e.message} className="sm:col-span-5">
              {(id, dsc) => (
                <Input id={id} aria-describedby={dsc} aria-invalid={!!e.message} value={d.message} onChange={(ev) => set(i, { message: ev.target.value })} placeholder="e.g. Systolic BP above 160: contact the care team today" />
              )}
            </Field>
          </div>
        );
      })}
      <Button
        variant="subtle"
        size="sm"
        className="self-start"
        disabled={value.length >= MAX_THRESHOLDS}
        onClick={() => onChange([...value, emptyDraft()])}
        icon={<Plus className="size-4" aria-hidden />}
      >
        Add threshold
      </Button>
    </fieldset>
  );
}

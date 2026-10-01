"use client";

import { useState } from "react";
import { Controller, useFieldArray, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { ClipboardList, Plus, Trash2, X } from "lucide-react";
import { api } from "@/lib/api";
import type { CarePlanInput } from "@/lib/api/types";
import { istLocalToISO, todayIST } from "@/lib/format";
import { useToast } from "./toast";
import { Button, Card, Field, Input, Select, Textarea } from "./ui";

const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

const schema = z
  .object({
    summary: z.string().trim().min(3, "Summary is required"),
    instructions: z.string().trim().min(3, "Instructions are required"),
    tasks: z.array(
      z.object({
        type: z.enum(["medication", "test", "follow_up", "lifestyle", "monitoring", "general"]),
        title: z.string().trim().min(2, "Task title is required"),
        description: z.string().trim().optional(),
        dueAt: z.string().optional(),
        owner: z.enum(["patient", "caregiver", "provider"]),
      }),
    ),
    medications: z.array(
      z
        .object({
          name: z.string().trim().min(2, "Medicine name is required"),
          dose: z.string().trim().min(1, "Dose is required"),
          frequency: z.string().trim().min(1, "Frequency is required"),
          times: z.array(z.string().regex(TIME_RE, "Use HH:MM")).min(1, "Add at least one time"),
          startDate: z.string().regex(DATE_RE, "Start date is required"),
          endDate: z.string().optional(),
          instructions: z.string().trim().optional(),
        })
        .refine((m) => !m.endDate || m.endDate >= m.startDate, { message: "End date must be after start date", path: ["endDate"] }),
    ),
    followUpEnabled: z.boolean(),
    followUpAfterDays: z.coerce.number().int().min(1, "At least 1 day").max(365, "At most 365 days"),
    followUpMode: z.enum(["video", "in_clinic", "home_visit"]),
  });

type FormValues = z.input<typeof schema>;
type ParsedValues = z.output<typeof schema>;

export function toCarePlanInput(careEpisodeId: string, v: ParsedValues): CarePlanInput {
  return {
    careEpisodeId,
    summary: v.summary,
    instructions: v.instructions,
    tasks: v.tasks.map((t) => ({
      type: t.type,
      title: t.title,
      owner: t.owner,
      ...(t.description ? { description: t.description } : {}),
      ...(t.dueAt ? { dueAt: istLocalToISO(t.dueAt) } : {}),
    })),
    medications: v.medications.map((m) => ({
      name: m.name,
      dose: m.dose,
      frequency: m.frequency,
      times: [...m.times].sort(),
      startDate: m.startDate,
      ...(m.endDate ? { endDate: m.endDate } : {}),
      ...(m.instructions ? { instructions: m.instructions } : {}),
    })),
    followUp: v.followUpEnabled ? { afterDays: v.followUpAfterDays, mode: v.followUpMode } : null,
  };
}

export function CarePlanBuilder({ careEpisodeId, onCreated }: { careEpisodeId: string; onCreated?: () => void }) {
  const toast = useToast();
  const qc = useQueryClient();
  const form = useForm<FormValues, unknown, ParsedValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      summary: "",
      instructions: "",
      tasks: [],
      medications: [],
      followUpEnabled: true,
      followUpAfterDays: 7,
      followUpMode: "video",
    },
  });
  const { register, control, formState, handleSubmit, watch, reset } = form;
  const tasks = useFieldArray({ control, name: "tasks" });
  const meds = useFieldArray({ control, name: "medications" });
  const followUpEnabled = watch("followUpEnabled");
  const errors = formState.errors;

  const create = useMutation({
    mutationFn: (input: CarePlanInput) => api.carePlans.create(input),
    onSuccess: () => {
      toast.success("Care plan created", "It supersedes the previous active plan for this episode.");
      reset();
      void qc.invalidateQueries({ queryKey: ["care-plans", careEpisodeId] });
      void qc.invalidateQueries({ queryKey: ["episode", careEpisodeId] });
      onCreated?.();
    },
    onError: (e) => toast.apiError(e, "Could not create the care plan"),
  });

  const onSubmit = handleSubmit((v) => create.mutate(toCarePlanInput(careEpisodeId, v)));

  return (
    <Card title="Care plan builder" subtitle="Creates a new active plan for this episode (POST /care-plans)">
      <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
        <Field label="Summary" required error={errors.summary?.message}>
          {(id, d) => <Textarea id={id} aria-describedby={d} aria-invalid={!!errors.summary} rows={2} {...register("summary")} />}
        </Field>
        <Field label="Instructions for the patient" required error={errors.instructions?.message}>
          {(id, d) => <Textarea id={id} aria-describedby={d} aria-invalid={!!errors.instructions} rows={3} {...register("instructions")} />}
        </Field>

        {/* Tasks */}
        <fieldset className="flex flex-col gap-3">
          <legend className="mb-2 text-sm font-semibold">Tasks</legend>
          {tasks.fields.length === 0 && <p className="text-sm text-ink-muted">No tasks yet.</p>}
          {tasks.fields.map((f, i) => {
            const te = errors.tasks?.[i];
            return (
              <div key={f.id} className="grid gap-3 rounded-xl border border-line p-3 md:grid-cols-[140px_1fr_160px_130px_auto]" role="group" aria-label={`Task ${i + 1}`}>
                <Field label="Type">
                  {(id) => (
                    <Select id={id} {...register(`tasks.${i}.type`)}>
                      <option value="general">General</option>
                      <option value="medication">Medication</option>
                      <option value="test">Test</option>
                      <option value="follow_up">Follow-up</option>
                      <option value="lifestyle">Lifestyle</option>
                      <option value="monitoring">Monitoring</option>
                    </Select>
                  )}
                </Field>
                <Field label="Title" required error={te?.title?.message}>
                  {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!te?.title} {...register(`tasks.${i}.title`)} />}
                </Field>
                <Field label="Due (IST)">
                  {(id) => <Input id={id} type="datetime-local" {...register(`tasks.${i}.dueAt`)} />}
                </Field>
                <Field label="Owner">
                  {(id) => (
                    <Select id={id} {...register(`tasks.${i}.owner`)}>
                      <option value="patient">Patient</option>
                      <option value="caregiver">Caregiver</option>
                      <option value="provider">Provider</option>
                    </Select>
                  )}
                </Field>
                <div className="flex items-end">
                  <Button variant="ghost" size="sm" onClick={() => tasks.remove(i)} aria-label={`Remove task ${i + 1}`}>
                    <Trash2 className="size-4" aria-hidden />
                  </Button>
                </div>
                <Field label="Description" className="md:col-span-5">
                  {(id) => <Input id={id} {...register(`tasks.${i}.description`)} />}
                </Field>
              </div>
            );
          })}
          <Button
            variant="subtle"
            size="sm"
            className="self-start"
            icon={<Plus className="size-4" aria-hidden />}
            onClick={() => tasks.append({ type: "general", title: "", description: "", dueAt: "", owner: "patient" })}
          >
            Add task
          </Button>
        </fieldset>

        {/* Medications */}
        <fieldset className="flex flex-col gap-3">
          <legend className="mb-2 text-sm font-semibold">Medications</legend>
          {meds.fields.length === 0 && <p className="text-sm text-ink-muted">No medications yet.</p>}
          {meds.fields.map((f, i) => {
            const me = errors.medications?.[i];
            return (
              <div key={f.id} className="grid gap-3 rounded-xl border border-line p-3 md:grid-cols-3" role="group" aria-label={`Medication ${i + 1}`}>
                <Field label="Medicine" required error={me?.name?.message}>
                  {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!me?.name} placeholder="e.g. Metformin" {...register(`medications.${i}.name`)} />}
                </Field>
                <Field label="Dose" required error={me?.dose?.message}>
                  {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!me?.dose} placeholder="500 mg" {...register(`medications.${i}.dose`)} />}
                </Field>
                <Field label="Frequency" required error={me?.frequency?.message}>
                  {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!me?.frequency} placeholder="Twice daily" {...register(`medications.${i}.frequency`)} />}
                </Field>
                <Controller
                  control={control}
                  name={`medications.${i}.times`}
                  render={({ field, fieldState }) => (
                    <TimesEditor
                      value={field.value ?? []}
                      onChange={field.onChange}
                      error={fieldState.error?.message ?? (me?.times as { message?: string } | undefined)?.message}
                    />
                  )}
                />
                <Field label="Start date" required error={me?.startDate?.message}>
                  {(id, d) => <Input id={id} type="date" aria-describedby={d} {...register(`medications.${i}.startDate`)} />}
                </Field>
                <Field label="End date" error={me?.endDate?.message}>
                  {(id, d) => <Input id={id} type="date" aria-describedby={d} {...register(`medications.${i}.endDate`)} />}
                </Field>
                <Field label="Instructions" className="md:col-span-2">
                  {(id) => <Input id={id} placeholder="After food" {...register(`medications.${i}.instructions`)} />}
                </Field>
                <div className="flex items-end justify-end">
                  <Button variant="ghost" size="sm" onClick={() => meds.remove(i)} icon={<Trash2 className="size-4" aria-hidden />}>
                    Remove
                  </Button>
                </div>
              </div>
            );
          })}
          <Button
            variant="subtle"
            size="sm"
            className="self-start"
            icon={<Plus className="size-4" aria-hidden />}
            onClick={() =>
              meds.append({ name: "", dose: "", frequency: "", times: ["08:00"], startDate: todayIST(), endDate: "", instructions: "" })
            }
          >
            Add medication
          </Button>
        </fieldset>

        {/* Follow-up */}
        <fieldset className="rounded-xl border border-line p-3">
          <legend className="px-1 text-sm font-semibold">Follow-up</legend>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" className="size-4 accent-[#631D3F]" {...register("followUpEnabled")} />
            Schedule a follow-up
          </label>
          {followUpEnabled && (
            <div className="mt-3 grid gap-3 sm:grid-cols-2">
              <Field label="After (days)" required error={errors.followUpAfterDays?.message}>
                {(id, d) => <Input id={id} type="number" min={1} max={365} aria-describedby={d} {...register("followUpAfterDays")} />}
              </Field>
              <Field label="Mode">
                {(id) => (
                  <Select id={id} {...register("followUpMode")}>
                    <option value="video">Video</option>
                    <option value="in_clinic">In clinic</option>
                    <option value="home_visit">Home visit</option>
                  </Select>
                )}
              </Field>
            </div>
          )}
        </fieldset>

        <div className="flex justify-end">
          <Button type="submit" loading={create.isPending} icon={<ClipboardList className="size-4" aria-hidden />}>
            Create care plan
          </Button>
        </div>
      </form>
    </Card>
  );
}

function TimesEditor({ value, onChange, error }: { value: string[]; onChange: (v: string[]) => void; error?: string }) {
  const [draft, setDraft] = useState("");
  const add = () => {
    if (!TIME_RE.test(draft) || value.includes(draft)) return;
    onChange([...value, draft].sort());
    setDraft("");
  };
  return (
    <Field label="Times" required error={error}>
      {(id, d) => (
        <div className="flex flex-col gap-2">
          <ul className="flex flex-wrap gap-1.5" aria-label="Dose times">
            {value.map((t) => (
              <li key={t}>
                <span className="inline-flex items-center gap-1 rounded-full bg-mint-100 py-0.5 pl-2.5 pr-1 text-xs font-medium text-primary-dark">
                  {t}
                  <button
                    type="button"
                    onClick={() => onChange(value.filter((x) => x !== t))}
                    aria-label={`Remove time ${t}`}
                    className="rounded-full p-0.5 hover:bg-white"
                  >
                    <X className="size-3" aria-hidden />
                  </button>
                </span>
              </li>
            ))}
          </ul>
          <div className="flex gap-2">
            <Input
              id={id}
              type="time"
              aria-describedby={d}
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  add();
                }
              }}
            />
            <Button variant="secondary" size="sm" onClick={add} disabled={!TIME_RE.test(draft)}>
              Add
            </Button>
          </div>
        </div>
      )}
    </Field>
  );
}

"use client";

import { useId, useState } from "react";
import { useFieldArray, useForm, type FieldPath } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQuery } from "@tanstack/react-query";
import { ArrowLeft, ArrowRight, Check, FileUp, Plus, Trash2 } from "lucide-react";
import { api } from "@/lib/api";
import type { Discharge } from "@/lib/api/types";
import { formatDate, humanize, todayIST } from "@/lib/format";
import {
  DISCHARGE_STEPS,
  buildDischargeFormData,
  dischargeFileError,
  dischargeSchema,
  emptyDischarge,
  parseFollowUpDays,
  type DischargeFormValues,
  type DischargeParsed,
} from "@/lib/discharge";
import { useToast } from "./toast";
import { Button, Card, Field, Input, Select, Textarea, cx } from "./ui";

const TASK_TYPES = ["follow_up", "test", "medication", "monitoring", "lifestyle", "general"] as const;
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

/** §59 "New discharge": a 4-step form posting multipart to POST /discharges. */
export function DischargeForm({ onCreated }: { onCreated: (d: Discharge) => void }) {
  const toast = useToast();
  const fileId = useId();
  const [step, setStep] = useState(0);
  const [file, setFile] = useState<File | null>(null);
  const [fileTouched, setFileTouched] = useState(false);
  const templates = useQuery({ queryKey: ["program-templates"], queryFn: () => api.programs.templates(), staleTime: 5 * 60_000, retry: false });

  const form = useForm<DischargeFormValues, unknown, DischargeParsed>({ resolver: zodResolver(dischargeSchema), defaultValues: emptyDischarge(), mode: "onTouched" });
  const { register, control, formState, trigger, handleSubmit, getValues, setValue, watch } = form;
  const errors = formState.errors;
  const tasks = useFieldArray({ control, name: "tasks" });
  const meds = useFieldArray({ control, name: "medications" });

  const create = useMutation({
    mutationFn: (v: DischargeParsed) => api.discharges.create(buildDischargeFormData(v, file!)),
    onSuccess: (d) => {
      toast.success("Discharge registered", `${d.patientName} and family are being invited.`);
      onCreated(d);
    },
    onError: (e) => toast.apiError(e, "Could not register the discharge"),
  });

  const next = async () => {
    const fields = DISCHARGE_STEPS[step]!.fields as FieldPath<DischargeFormValues>[];
    const ok = await trigger(fields, { shouldFocus: true });
    if (ok) setStep((s) => Math.min(s + 1, DISCHARGE_STEPS.length - 1));
  };

  const fileError = dischargeFileError(file);
  const onSubmit = handleSubmit(
    (v) => {
      setFileTouched(true);
      if (fileError) return;
      create.mutate(v);
    },
    () => {
      // Jump back to the first step with an error.
      const first = DISCHARGE_STEPS.findIndex((s) => s.fields.some((f) => f in form.formState.errors));
      if (first >= 0) setStep(first);
    },
  );

  const values = watch();
  const days = parseFollowUpDays(values.followUpDaysText ?? "") ?? [];
  const current = DISCHARGE_STEPS[step]!;

  return (
    <form noValidate onSubmit={onSubmit} aria-label="New discharge" className="flex flex-col gap-5">
      <ol className="flex flex-wrap gap-2" aria-label="Steps">
        {DISCHARGE_STEPS.map((s, i) => (
          <li key={s.key}>
            <span
              aria-current={i === step ? "step" : undefined}
              className={cx(
                "inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-[13px] font-medium",
                i === step ? "border-primary bg-primary text-white" : i < step ? "border-[#ecc9d8] bg-teal-bg text-primary-dark" : "border-line bg-white text-ink-muted",
              )}
            >
              {i < step ? <Check className="size-3.5" aria-hidden /> : <span aria-hidden>{i + 1}.</span>} {s.label}
            </span>
          </li>
        ))}
      </ol>

      <Card title={`Step ${step + 1} of ${DISCHARGE_STEPS.length}: ${current.label}`}>
        {step === 0 && (
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Patient name" required error={errors.patientName?.message}>
              {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!errors.patientName} {...register("patientName")} />}
            </Field>
            <Field label="Patient phone" required error={errors.patientPhone?.message} hint="The patient is invited by SMS/WhatsApp">
              {(id, d) => <Input id={id} type="tel" aria-describedby={d} aria-invalid={!!errors.patientPhone} {...register("patientPhone")} />}
            </Field>
            <Field label="Date of birth" required error={errors.dob?.message}>
              {(id, d) => <Input id={id} type="date" max={todayIST()} aria-describedby={d} aria-invalid={!!errors.dob} {...register("dob")} />}
            </Field>
            <Field label="Gender" required error={errors.gender?.message}>
              {(id, d) => (
                <Select id={id} aria-describedby={d} aria-invalid={!!errors.gender} {...register("gender")}>
                  <option value="">Choose…</option>
                  <option value="female">Female</option>
                  <option value="male">Male</option>
                  <option value="other">Other</option>
                </Select>
              )}
            </Field>
            <Field label="Family member phone" error={errors.familyPhone?.message} hint="Optional. Receives the invite and alerts.">
              {(id, d) => <Input id={id} type="tel" aria-describedby={d} aria-invalid={!!errors.familyPhone} {...register("familyPhone")} />}
            </Field>
          </div>
        )}

        {step === 1 && (
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Discharge date" required error={errors.dischargeDate?.message}>
              {(id, d) => <Input id={id} type="date" max={todayIST()} aria-describedby={d} aria-invalid={!!errors.dischargeDate} {...register("dischargeDate")} />}
            </Field>
            <Field label="Treating doctor" required error={errors.treatingDoctorName?.message}>
              {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!errors.treatingDoctorName} placeholder="Dr. …" {...register("treatingDoctorName")} />}
            </Field>
            <Field label="Diagnosis summary" required error={errors.diagnosisSummary?.message} className="sm:col-span-2">
              {(id, d) => <Textarea id={id} rows={4} aria-describedby={d} aria-invalid={!!errors.diagnosisSummary} {...register("diagnosisSummary")} />}
            </Field>
          </div>
        )}

        {step === 2 && (
          <div className="flex flex-col gap-5">
            <fieldset className="flex flex-col gap-2">
              <legend className="mb-1 text-sm font-semibold">Medications</legend>
              {meds.fields.length === 0 && <p className="text-sm text-ink-muted">No medicines added.</p>}
              {meds.fields.map((f, i) => {
                const e = errors.medications?.[i];
                const times = values.medications?.[i]?.times ?? [];
                return (
                  <div key={f.id} role="group" aria-label={`Medicine ${i + 1}`} className="grid gap-2 rounded-xl border border-line p-3 sm:grid-cols-3">
                    <Field label="Medicine" required error={e?.name?.message}>
                      {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!e?.name} {...register(`medications.${i}.name`)} />}
                    </Field>
                    <Field label="Dose" required error={e?.dose?.message}>
                      {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!e?.dose} {...register(`medications.${i}.dose`)} />}
                    </Field>
                    <Field label="Frequency" required error={e?.frequency?.message}>
                      {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!e?.frequency} {...register(`medications.${i}.frequency`)} />}
                    </Field>
                    <Field label="Times (HH:MM, comma separated)" required error={e?.times?.message ?? e?.times?.root?.message ?? (Array.isArray(e?.times) ? e?.times.find(Boolean)?.message : undefined)}>
                      {(id, d) => (
                        <Input
                          id={id}
                          aria-describedby={d}
                          defaultValue={times.join(", ")}
                          onChange={(ev) =>
                            setValue(
                              `medications.${i}.times`,
                              ev.target.value
                                .split(/[,\s]+/)
                                .map((x) => x.trim())
                                .filter(Boolean)
                                .map((x) => (TIME_RE.test(x) || !/^\d:\d\d$/.test(x) ? x : `0${x}`)),
                              { shouldValidate: formState.isSubmitted },
                            )
                          }
                        />
                      )}
                    </Field>
                    <Field label="Start" required error={e?.startDate?.message}>
                      {(id, d) => <Input id={id} type="date" aria-describedby={d} {...register(`medications.${i}.startDate`)} />}
                    </Field>
                    <Field label="End" error={e?.endDate?.message}>
                      {(id, d) => <Input id={id} type="date" aria-describedby={d} {...register(`medications.${i}.endDate`)} />}
                    </Field>
                    <Field label="Instructions" className="sm:col-span-2">
                      {(id) => <Input id={id} {...register(`medications.${i}.instructions`)} />}
                    </Field>
                    <div className="flex items-end justify-end">
                      <Button size="sm" variant="ghost" onClick={() => meds.remove(i)} aria-label={`Remove medicine ${i + 1}`} icon={<Trash2 className="size-4" aria-hidden />}>
                        Remove
                      </Button>
                    </div>
                  </div>
                );
              })}
              <Button
                size="sm"
                variant="subtle"
                className="self-start"
                onClick={() => meds.append({ name: "", dose: "", frequency: "Twice daily", times: ["08:00", "20:00"], startDate: getValues("dischargeDate") || todayIST(), endDate: "", instructions: "" })}
                icon={<Plus className="size-4" aria-hidden />}
              >
                Add medicine
              </Button>
            </fieldset>

            <fieldset className="flex flex-col gap-2">
              <legend className="mb-1 text-sm font-semibold">Follow-up tasks</legend>
              {tasks.fields.length === 0 && <p className="text-sm text-ink-muted">No tasks added.</p>}
              {tasks.fields.map((f, i) => {
                const e = errors.tasks?.[i];
                return (
                  <div key={f.id} role="group" aria-label={`Task ${i + 1}`} className="grid gap-2 rounded-xl border border-line p-3 sm:grid-cols-[1fr_2fr_1fr_auto]">
                    <Field label="Type">
                      {(id) => (
                        <Select id={id} {...register(`tasks.${i}.type`)}>
                          {TASK_TYPES.map((t) => (
                            <option key={t} value={t}>
                              {humanize(t)}
                            </option>
                          ))}
                        </Select>
                      )}
                    </Field>
                    <Field label="Task" required error={e?.title?.message}>
                      {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!e?.title} {...register(`tasks.${i}.title`)} />}
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
                      <Button size="sm" variant="ghost" onClick={() => tasks.remove(i)} aria-label={`Remove task ${i + 1}`} icon={<Trash2 className="size-4" aria-hidden />} />
                    </div>
                  </div>
                );
              })}
              <Button size="sm" variant="subtle" className="self-start" onClick={() => tasks.append({ type: "follow_up", title: "", description: "", owner: "patient" })} icon={<Plus className="size-4" aria-hidden />}>
                Add task
              </Button>
            </fieldset>

            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Follow-up days after discharge" required error={errors.followUpDaysText?.message} hint="e.g. 7, 14, 30">
                {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!errors.followUpDaysText} {...register("followUpDaysText")} />}
              </Field>
              <Field label="Care program" hint={templates.isError ? "Templates could not be loaded" : "Optional remote monitoring"}>
                {(id, d) => (
                  <Select id={id} aria-describedby={d} {...register("programTemplateCode")}>
                    <option value="">None</option>
                    {templates.data?.items.map((t) => (
                      <option key={t.code} value={t.code}>
                        {t.name}
                        {t.status !== "approved" ? " (unapproved fixture)" : ""}
                      </option>
                    ))}
                  </Select>
                )}
              </Field>
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-1">
              <label htmlFor={fileId} className="text-[13px] font-medium">
                Discharge summary (PDF, up to 15 MB) <span className="text-danger" aria-hidden>*</span>
              </label>
              <input
                id={fileId}
                type="file"
                accept="application/pdf,.pdf"
                aria-invalid={fileTouched && !!fileError}
                aria-describedby={`${fileId}-err`}
                className="text-sm file:mr-3 file:rounded-full file:border-0 file:bg-mint-100 file:px-3 file:py-1.5 file:font-semibold file:text-primary-dark"
                onChange={(e) => {
                  setFile(e.target.files?.[0] ?? null);
                  setFileTouched(true);
                }}
              />
              {fileTouched && fileError && (
                <p id={`${fileId}-err`} role="alert" className="text-xs text-danger-dark">
                  {fileError}
                </p>
              )}
            </div>
            <dl className="grid gap-2 rounded-xl bg-mint-50 p-3 text-sm sm:grid-cols-2">
              <Review label="Patient" value={`${values.patientName} · ${values.patientPhone} · ${values.dob ? formatDate(values.dob) : "—"} · ${humanize(values.gender)}`} />
              <Review label="Family phone" value={values.familyPhone || "—"} />
              <Review label="Discharged" value={`${values.dischargeDate ? formatDate(values.dischargeDate) : "—"} · ${values.treatingDoctorName}`} />
              <Review label="Follow-up days" value={days.join(", ") || "—"} />
              <Review label="Plan" value={`${values.medications?.length ?? 0} medicines · ${values.tasks?.length ?? 0} tasks`} />
              <Review label="Program" value={values.programTemplateCode || "None"} />
            </dl>
            <p className="text-xs text-ink-muted">
              Registering creates the patient account (or links an existing one), a care episode and hospital-issued care plan, a 30-day daily
              check-in, and invites the patient and family.
            </p>
          </div>
        )}
      </Card>

      <div className="flex flex-wrap justify-between gap-2">
        <Button variant="ghost" disabled={step === 0} onClick={() => setStep((s) => Math.max(0, s - 1))} icon={<ArrowLeft className="size-4" aria-hidden />}>
          Back
        </Button>
        {step < DISCHARGE_STEPS.length - 1 ? (
          <Button onClick={() => void next()} icon={<ArrowRight className="size-4" aria-hidden />}>
            Next
          </Button>
        ) : (
          <Button type="submit" loading={create.isPending} icon={<FileUp className="size-4" aria-hidden />}>
            Register discharge
          </Button>
        )}
      </div>
    </form>
  );
}

function Review({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs text-ink-muted">{label}</dt>
      <dd className="font-medium">{value}</dd>
    </div>
  );
}

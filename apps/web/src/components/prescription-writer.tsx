"use client";

import { useId, useState } from "react";
import { Controller, useFieldArray, useForm, useWatch, type Control } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { CheckCircle2, FilePlus2, FileText, Plus, Trash2, X } from "lucide-react";
import { api } from "@/lib/api";
import { RX_FORMS, type Appointment, type DoctorProfile, type Prescription } from "@/lib/api/types";
import { slug } from "@/lib/download";
import { formatDate, formatDateTime, humanize, todayIST } from "@/lib/format";
import {
  FREQUENCY_PRESETS,
  TIMING_PRESETS,
  emptyRxItem,
  prescriptionSchema,
  rxLine,
  toPrescriptionInput,
  type PrescriptionFormValues,
  type PrescriptionParsed,
} from "@/lib/prescription";
import { BlobButton } from "./blob-actions";
import { useToast } from "./toast";
import { Badge, Button, Card, EmptyState, Field, Input, QueryView, Select, Textarea, cx } from "./ui";

const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;
const MAX_ITEMS = 20;

const defaultValues = (): PrescriptionFormValues => ({
  clinicalNote: "",
  items: [emptyRxItem()],
  advice: "",
  followUpInDays: "",
});

/** File name for a prescription PDF: prescription-<patient>-<YYYY-MM-DD (IST)>.pdf */
export function prescriptionFileName(patientName: string, createdAt: string | Date): string {
  const d = createdAt instanceof Date ? createdAt : new Date(createdAt);
  const date = Number.isNaN(d.getTime()) ? todayIST() : todayIST(d);
  return `prescription-${slug(patientName) || "patient"}-${date}.pdf`;
}

function PdfButton({ rx, label = "Download PDF" }: { rx: Prescription; label?: string }) {
  return (
    <BlobButton
      load={() => api.prescriptions.pdf(rx.id)}
      fileName={prescriptionFileName(rx.patientName, rx.createdAt)}
      label={label}
      errorTitle="Could not download the prescription"
      aria-label={`${label}: prescription of ${formatDate(rx.createdAt)}`}
    />
  );
}

export function PrescriptionWriter({ appt }: { appt: Appointment }) {
  const canWrite = appt.status === "in_progress" || appt.status === "completed";
  return (
    <div className="flex flex-col gap-5">
      {canWrite ? (
        <WriterForm appt={appt} />
      ) : (
        <Card title="Write prescription">
          <p className="text-sm text-ink-muted">
            A prescription can be written once the consultation is in progress or completed. This appointment is{" "}
            <strong>{humanize(appt.status).toLowerCase()}</strong>.
          </p>
        </Card>
      )}
      <Card title="Prescriptions for this patient">
        <PrescriptionList patientId={appt.patientId} appointmentId={appt.id} />
      </Card>
    </div>
  );
}

function WriterForm({ appt }: { appt: Appointment }) {
  const toast = useToast();
  const qc = useQueryClient();
  const freqListId = useId();
  const timingListId = useId();
  const [created, setCreated] = useState<Prescription | null>(null);

  const profile = useQuery({
    queryKey: ["doctor-self", "profile"],
    queryFn: () => api.doctorSelf.profile(),
    retry: false,
    staleTime: 5 * 60_000,
  });

  const form = useForm<PrescriptionFormValues, unknown, PrescriptionParsed>({
    resolver: zodResolver(prescriptionSchema),
    defaultValues: defaultValues(),
  });
  const { register, control, formState, handleSubmit, reset } = form;
  const items = useFieldArray({ control, name: "items" });
  const errors = formState.errors;

  const create = useMutation({
    mutationFn: (v: PrescriptionParsed) => api.prescriptions.create(toPrescriptionInput(appt.id, v)),
    onSuccess: (rx) => {
      toast.success("Prescription created", "The PDF is saved to the patient's records and reminders start.");
      setCreated(rx);
      reset(defaultValues());
      void qc.invalidateQueries({ queryKey: ["prescriptions", appt.patientId] });
      void qc.invalidateQueries({ queryKey: ["episode", appt.careEpisodeId] });
    },
    onError: (e) => toast.apiError(e, "Could not create the prescription"),
  });

  const onSubmit = handleSubmit((v) => create.mutate(v));
  const itemsRootError = errors.items?.root?.message ?? errors.items?.message;

  return (
    <div className="flex flex-col gap-5">
      {created && (
        <div role="status" className="flex flex-wrap items-center justify-between gap-3 rounded-[20px] border border-[#c4e6d7] bg-teal-bg p-4">
          <div className="flex items-start gap-2">
            <CheckCircle2 className="mt-0.5 size-5 text-primary" aria-hidden />
            <div>
              <p className="font-semibold text-primary-dark">Prescription saved</p>
              <p className="text-[13px] text-ink-muted">
                {created.items.length} {created.items.length === 1 ? "medicine" : "medicines"} · {formatDateTime(created.createdAt)}
              </p>
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            <PdfButton rx={created} />
            <Button variant="ghost" size="sm" onClick={() => setCreated(null)}>
              Dismiss
            </Button>
          </div>
        </div>
      )}

      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_minmax(0,340px)]">
        <Card title="Write prescription" subtitle="Creates a PDF prescription and medication reminders (POST /clinician/prescriptions)">
          <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5" aria-label="Prescription">
            <datalist id={freqListId}>
              {FREQUENCY_PRESETS.map((f) => (
                <option key={f} value={f} />
              ))}
            </datalist>
            <datalist id={timingListId}>
              {TIMING_PRESETS.map((t) => (
                <option key={t} value={t} />
              ))}
            </datalist>

            <Field label="Clinical note / diagnosis" error={errors.clinicalNote?.message}>
              {(id, d) => (
                <Textarea id={id} aria-describedby={d} aria-invalid={!!errors.clinicalNote} rows={2} {...register("clinicalNote")} />
              )}
            </Field>

            <fieldset className="flex flex-col gap-3">
              <legend className="mb-2 text-sm font-semibold">Medicines</legend>
              {itemsRootError && (
                <p role="alert" className="text-xs text-danger-dark">
                  {itemsRootError}
                </p>
              )}
              {items.fields.map((f, i) => {
                const ie = errors.items?.[i];
                return (
                  <div key={f.id} role="group" aria-label={`Medicine ${i + 1}`} className="grid gap-3 rounded-xl border border-line p-3 sm:grid-cols-2 2xl:grid-cols-3">
                    <div className="flex items-center justify-between sm:col-span-2 2xl:col-span-3">
                      <span className="text-[13px] font-semibold text-ink-muted">Medicine {i + 1}</span>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => items.remove(i)}
                        disabled={items.fields.length <= 1}
                        aria-label={`Remove medicine ${i + 1}`}
                        icon={<Trash2 className="size-4" aria-hidden />}
                      >
                        Remove
                      </Button>
                    </div>
                    <Field label="Drug name" required error={ie?.drugName?.message}>
                      {(id, d) => (
                        <Input id={id} aria-describedby={d} aria-invalid={!!ie?.drugName} placeholder="e.g. Paracetamol" {...register(`items.${i}.drugName`)} />
                      )}
                    </Field>
                    <Field label="Strength" error={ie?.strength?.message}>
                      {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!ie?.strength} placeholder="500 mg" {...register(`items.${i}.strength`)} />}
                    </Field>
                    <Field label="Form" error={ie?.form?.message}>
                      {(id, d) => (
                        <Select id={id} aria-describedby={d} aria-invalid={!!ie?.form} {...register(`items.${i}.form`)}>
                          {RX_FORMS.map((x) => (
                            <option key={x} value={x}>
                              {humanize(x)}
                            </option>
                          ))}
                        </Select>
                      )}
                    </Field>
                    <Field label="Dose" required error={ie?.dose?.message}>
                      {(id, d) => <Input id={id} aria-describedby={d} aria-invalid={!!ie?.dose} placeholder="1 tablet" {...register(`items.${i}.dose`)} />}
                    </Field>
                    <Field label="Frequency" required error={ie?.frequency?.message}>
                      {(id, d) => (
                        <Input id={id} list={freqListId} aria-describedby={d} aria-invalid={!!ie?.frequency} {...register(`items.${i}.frequency`)} />
                      )}
                    </Field>
                    <Field label="Timing" error={ie?.timing?.message}>
                      {(id, d) => <Input id={id} list={timingListId} aria-describedby={d} aria-invalid={!!ie?.timing} {...register(`items.${i}.timing`)} />}
                    </Field>
                    <Field label="Duration (days)" required error={ie?.durationDays?.message}>
                      {(id, d) => (
                        <Input
                          id={id}
                          type="number"
                          inputMode="numeric"
                          min={1}
                          max={365}
                          step={1}
                          aria-describedby={d}
                          aria-invalid={!!ie?.durationDays}
                          {...register(`items.${i}.durationDays`)}
                        />
                      )}
                    </Field>
                    <Controller
                      control={control}
                      name={`items.${i}.times`}
                      render={({ field, fieldState }) => (
                        <TimesChips
                          value={field.value ?? []}
                          onChange={field.onChange}
                          error={
                            fieldState.error?.message ??
                            fieldState.error?.root?.message ??
                            (Array.isArray(fieldState.error) ? fieldState.error.find(Boolean)?.message : undefined)
                          }
                        />
                      )}
                    />
                    <Field label="Instructions" error={ie?.instructions?.message} className="sm:col-span-2 2xl:col-span-2">
                      {(id, d) => (
                        <Input id={id} aria-describedby={d} aria-invalid={!!ie?.instructions} placeholder="e.g. Avoid driving" {...register(`items.${i}.instructions`)} />
                      )}
                    </Field>
                  </div>
                );
              })}
              <Button
                variant="subtle"
                size="sm"
                className="self-start"
                icon={<Plus className="size-4" aria-hidden />}
                disabled={items.fields.length >= MAX_ITEMS}
                onClick={() => items.append(emptyRxItem())}
              >
                Add medicine
              </Button>
              {items.fields.length >= MAX_ITEMS && <p className="text-xs text-ink-muted">A prescription can hold at most {MAX_ITEMS} medicines.</p>}
            </fieldset>

            <Field label="Advice" error={errors.advice?.message}>
              {(id, d) => (
                <Textarea id={id} aria-describedby={d} aria-invalid={!!errors.advice} rows={2} placeholder="Diet, rest, warning signs…" {...register("advice")} />
              )}
            </Field>
            <Field label="Follow-up after (days)" hint="Leave blank for no follow-up." error={errors.followUpInDays?.message} className="max-w-[220px]">
              {(id, d) => (
                <Input
                  id={id}
                  type="number"
                  inputMode="numeric"
                  min={1}
                  max={365}
                  step={1}
                  aria-describedby={d}
                  aria-invalid={!!errors.followUpInDays}
                  {...register("followUpInDays")}
                />
              )}
            </Field>

            <div className="flex justify-end">
              <Button type="submit" loading={create.isPending} icon={<FilePlus2 className="size-4" aria-hidden />}>
                Create prescription
              </Button>
            </div>
          </form>
        </Card>

        <aside aria-label="Prescription preview" className="min-w-0">
          <div className="xl:sticky xl:top-20">
            <RxPreview control={control} appt={appt} profile={profile.data} />
          </div>
        </aside>
      </div>
    </div>
  );
}

function RxPreview({ control, appt, profile }: { control: Control<PrescriptionFormValues>; appt: Appointment; profile?: DoctorProfile }) {
  const v = useWatch({ control });
  const items = (v.items ?? []).filter((i) => i?.drugName?.trim());
  const followUp = typeof v.followUpInDays === "number" ? v.followUpInDays : Number(v.followUpInDays);
  return (
    <div className="rounded-[20px] border border-line bg-white p-5 font-serif text-ink shadow-[var(--shadow-card)]">
      <p className="mb-2 font-sans text-[11px] font-semibold uppercase tracking-wide text-ink-muted">Live preview</p>
      <header className="border-b-2 border-primary pb-3">
        <p className="text-lg font-bold">{profile?.name ?? appt.doctorName}</p>
        {profile?.qualifications && <p className="text-[13px]">{profile.qualifications}</p>}
        {profile?.registrationNumber && <p className="text-xs text-ink-muted">Reg. No. {profile.registrationNumber}</p>}
      </header>
      <div className="flex flex-wrap justify-between gap-2 border-b border-line py-2 text-[13px]">
        <span>
          <span className="text-ink-muted">Patient:</span> <strong>{appt.patientName}</strong>
        </span>
        <span>
          <span className="text-ink-muted">Date:</span> {formatDate(new Date())}
        </span>
      </div>
      {v.clinicalNote?.trim() && (
        <p className="mt-2 text-[13px]">
          <span className="text-ink-muted">Dx / notes:</span> {v.clinicalNote}
        </p>
      )}
      <p className="mt-2 text-4xl font-bold leading-none text-primary" aria-hidden>
        ℞
      </p>
      {items.length === 0 ? (
        <p className="mt-2 font-sans text-sm text-ink-muted">Medicines you add appear here.</p>
      ) : (
        <ol className="mt-2 flex list-decimal flex-col gap-2 pl-5 text-[13px]">
          {items.map((i, idx) => (
            <li key={idx}>
              <p className="font-semibold">
                {i.drugName}
                {i.strength?.trim() ? ` ${i.strength}` : ""}
                {i.form ? <span className="font-normal text-ink-muted"> ({humanize(i.form)})</span> : null}
              </p>
              <p>{rxLine({ dose: i.dose, frequency: i.frequency, timing: i.timing, durationDays: i.durationDays })}</p>
              {i.times && i.times.length > 0 && <p className="text-xs text-ink-muted">Reminders: {[...i.times].filter(Boolean).sort().join(", ")}</p>}
              {i.instructions?.trim() && <p className="text-xs italic">{i.instructions}</p>}
            </li>
          ))}
        </ol>
      )}
      {v.advice?.trim() && (
        <div className="mt-3 text-[13px]">
          <p className="font-semibold">Advice</p>
          <p className="whitespace-pre-line">{v.advice}</p>
        </div>
      )}
      {Number.isInteger(followUp) && followUp > 0 && (
        <p className="mt-2 text-[13px]">
          <span className="font-semibold">Follow-up:</span> after {followUp} {followUp === 1 ? "day" : "days"}
        </p>
      )}
      <footer className="mt-5 border-t border-line pt-2 font-sans text-[11px] text-ink-muted">
        <div className="mb-3 ml-auto w-40 border-b border-ink-muted/60 pb-4 text-right" aria-hidden />
        Digitally generated · signature line [requires legal review]
      </footer>
    </div>
  );
}

function TimesChips({ value, onChange, error }: { value: string[]; onChange: (v: string[]) => void; error?: string }) {
  const [draft, setDraft] = useState("");
  const add = () => {
    if (!TIME_RE.test(draft) || value.includes(draft)) return;
    onChange([...value, draft].sort());
    setDraft("");
  };
  return (
    <Field label="Reminder times" required error={error}>
      {(id, d) => (
        <div className="flex flex-col gap-2">
          <ul className="flex flex-wrap gap-1.5" aria-label="Reminder times">
            {value.length === 0 && <li className="text-xs text-ink-muted">None yet</li>}
            {value.map((t) => (
              <li key={t}>
                <span className="inline-flex items-center gap-1 rounded-full bg-mint-100 py-0.5 pl-2.5 pr-1 text-xs font-medium text-primary-dark">
                  {t}
                  <button
                    type="button"
                    onClick={() => onChange(value.filter((x) => x !== t))}
                    aria-label={`Remove reminder time ${t}`}
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
              aria-invalid={!!error}
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  add();
                }
              }}
            />
            <Button variant="secondary" size="sm" onClick={add} disabled={!TIME_RE.test(draft) || value.includes(draft)}>
              Add
            </Button>
          </div>
        </div>
      )}
    </Field>
  );
}

/** Prescriptions for a patient (GET /prescriptions?patientId=), newest first as returned. */
export function PrescriptionList({ patientId, appointmentId }: { patientId: string; appointmentId?: string }) {
  const query = useQuery({ queryKey: ["prescriptions", patientId], queryFn: () => api.prescriptions.list({ patientId }) });
  return (
    <QueryView
      query={query}
      isEmpty={(d) => d.items.length === 0}
      empty={<EmptyState title="No prescriptions yet" icon={<FileText className="size-6" />} />}
    >
      {(d) => (
        <ul className="flex flex-col gap-2">
          {d.items.map((rx) => {
            const here = !!appointmentId && rx.appointmentId === appointmentId;
            return (
              <li key={rx.id} className={cx("rounded-xl border p-3", here ? "border-primary bg-mint-50" : "border-line")}>
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="flex flex-wrap items-center gap-2 font-semibold">
                      {formatDateTime(rx.createdAt)}
                      {here && <Badge tone="green">This consultation</Badge>}
                    </p>
                    <p className="text-xs text-ink-muted">
                      {rx.doctorName}
                      {rx.doctorQualifications ? `, ${rx.doctorQualifications}` : ""}
                      {rx.followUpInDays ? ` · follow-up in ${rx.followUpInDays} days` : ""}
                    </p>
                  </div>
                  <PdfButton rx={rx} label="PDF" />
                </div>
                <p className="mt-1 text-[13px]">
                  {rx.items.map((i) => `${i.drugName}${i.strength ? ` ${i.strength}` : ""}`).join(", ")}
                </p>
              </li>
            );
          })}
        </ul>
      )}
    </QueryView>
  );
}

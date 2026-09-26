import { z } from "zod";
import type { PrescriptionInput, RxForm, RxItem } from "@/lib/api/types";

const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

const optionalText = (max: number) =>
  z
    .string()
    .trim()
    .max(max, `At most ${max} characters`)
    .optional()
    .or(z.literal(""));

export const rxItemSchema = z.object({
  drugName: z.string().trim().min(2, "Drug name is required").max(120, "At most 120 characters"),
  strength: optionalText(60),
  form: z.enum(["tablet", "capsule", "syrup", "injection", "ointment", "drops", "inhaler", "other"]),
  dose: z.string().trim().min(1, "Dose is required").max(60, "At most 60 characters"),
  frequency: z.string().trim().min(1, "Frequency is required").max(60, "At most 60 characters"),
  timing: optionalText(60),
  durationDays: z.coerce
    .number({ invalid_type_error: "Enter the number of days" })
    .int("Whole days only")
    .min(1, "At least 1 day")
    .max(365, "At most 365 days"),
  times: z
    .array(z.string().regex(TIME_RE, "Use HH:MM"))
    .min(1, "Add at least one reminder time")
    .max(8, "At most 8 reminder times")
    .refine((t) => new Set(t).size === t.length, "Reminder times must be different"),
  instructions: optionalText(300),
});

export const prescriptionSchema = z.object({
  clinicalNote: optionalText(2000),
  items: z.array(rxItemSchema).min(1, "Add at least one medicine").max(20, "At most 20 medicines"),
  advice: optionalText(2000),
  /** Empty string = no follow-up. */
  followUpInDays: z
    .union([z.literal(""), z.coerce.number().int("Whole days only").min(1, "At least 1 day").max(365, "At most 365 days")])
    .optional(),
});

export type PrescriptionFormValues = z.input<typeof prescriptionSchema>;
export type PrescriptionParsed = z.output<typeof prescriptionSchema>;

export function emptyRxItem(): PrescriptionFormValues["items"][number] {
  return {
    drugName: "",
    strength: "",
    form: "tablet",
    dose: "1 tablet",
    frequency: "Twice daily",
    timing: "After food",
    durationDays: 5,
    times: ["08:00", "20:00"],
    instructions: "",
  };
}

const blankToUndefined = (s: string | undefined) => {
  const t = s?.trim();
  return t ? t : undefined;
};

/** Map validated form values to the §31 `PrescriptionInput` body. Optional blanks are omitted, not sent as "". */
export function toPrescriptionInput(appointmentId: string, v: PrescriptionParsed): PrescriptionInput {
  const items: RxItem[] = v.items.map((i) => {
    const item: RxItem = {
      drugName: i.drugName.trim(),
      form: i.form as RxForm,
      dose: i.dose.trim(),
      frequency: i.frequency.trim(),
      durationDays: i.durationDays,
      times: [...i.times].sort(),
    };
    const strength = blankToUndefined(i.strength);
    const timing = blankToUndefined(i.timing);
    const instructions = blankToUndefined(i.instructions);
    if (strength) item.strength = strength;
    if (timing) item.timing = timing;
    if (instructions) item.instructions = instructions;
    return item;
  });
  const input: PrescriptionInput = { appointmentId, items };
  const clinicalNote = blankToUndefined(v.clinicalNote);
  const advice = blankToUndefined(v.advice);
  if (clinicalNote) input.clinicalNote = clinicalNote;
  if (advice) input.advice = advice;
  if (typeof v.followUpInDays === "number") input.followUpInDays = v.followUpInDays;
  return input;
}

/** Common frequency presets (free text is still allowed). */
export const FREQUENCY_PRESETS = ["Once daily", "Twice daily", "Thrice daily", "Four times daily", "At bedtime", "As needed (SOS)", "Weekly"];
export const TIMING_PRESETS = ["After food", "Before food", "With food", "Empty stomach", "At bedtime"];

/** Human line for the Rx pad preview, e.g. "1 tablet · Twice daily · After food · 5 days". */
export function rxLine(i: { dose?: string; frequency?: string; timing?: string; durationDays?: number | string }): string {
  return [i.dose, i.frequency, i.timing, i.durationDays ? `${i.durationDays} days` : ""]
    .map((x) => (typeof x === "string" ? x.trim() : x))
    .filter(Boolean)
    .join(" · ");
}

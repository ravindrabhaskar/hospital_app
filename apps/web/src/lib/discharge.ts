import { z } from "zod";
import type { DischargeFollowUp } from "@/lib/api/types";
import { todayIST } from "@/lib/format";

const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
/** §9 records accept files up to 15 MB; the discharge summary is stored as a record. */
export const DISCHARGE_PDF_MAX_BYTES = 15 * 1024 * 1024;

/** Accept a bare 10-digit Indian mobile and normalise it to +91 (same rule as the login page). */
export function normalisePhone(v: string): string {
  const s = v.replace(/[\s-]/g, "");
  return /^[6-9]\d{9}$/.test(s) ? `+91${s}` : s;
}
const phone = z
  .string()
  .trim()
  .transform(normalisePhone)
  .pipe(z.string().regex(/^\+[1-9]\d{7,14}$/, "Use international format, e.g. +919812345678"));

const optionalPhone = z
  .string()
  .trim()
  .transform((v) => (v ? normalisePhone(v) : ""))
  .pipe(z.union([z.literal(""), z.string().regex(/^\+[1-9]\d{7,14}$/, "Use international format, e.g. +919812345678")]));

const date = (what: string) => z.string().regex(DATE_RE, `Enter ${what}`);

const taskSchema = z.object({
  type: z.enum(["medication", "test", "follow_up", "lifestyle", "monitoring", "general"]),
  title: z.string().trim().min(2, "Task title is required").max(120, "At most 120 characters"),
  description: z.string().trim().max(500, "At most 500 characters").optional().or(z.literal("")),
  owner: z.enum(["patient", "caregiver", "provider"]),
});

const medicationSchema = z
  .object({
    name: z.string().trim().min(2, "Medicine name is required").max(120),
    dose: z.string().trim().min(1, "Dose is required").max(60),
    frequency: z.string().trim().min(1, "Frequency is required").max(60),
    times: z.array(z.string().regex(TIME_RE, "Use HH:MM")).min(1, "Add at least one time").max(8, "At most 8 times"),
    startDate: date("a start date"),
    endDate: z.union([z.literal(""), date("an end date")]).optional(),
    instructions: z.string().trim().max(300).optional().or(z.literal("")),
  })
  .refine((m) => !m.endDate || m.endDate >= m.startDate, { path: ["endDate"], message: "End date is before the start date" });

/** "7, 14, 30" → [7, 14, 30]; returns null when any part is not a whole number. */
export function parseFollowUpDays(text: string): number[] | null {
  const parts = text
    .split(/[,\s]+/)
    .map((s) => s.trim())
    .filter(Boolean);
  const nums = parts.map((p) => (/^\d+$/.test(p) ? Number(p) : NaN));
  if (nums.some((n) => !Number.isInteger(n))) return null;
  return [...new Set(nums)].sort((a, b) => a - b);
}

export const dischargeSchema = z
  .object({
    patientName: z.string().trim().min(2, "Patient name is required").max(100, "At most 100 characters"),
    patientPhone: phone,
    dob: date("the date of birth"),
    gender: z.enum(["male", "female", "other"], { errorMap: () => ({ message: "Choose a gender" }) }),
    familyPhone: optionalPhone,
    dischargeDate: date("the discharge date"),
    diagnosisSummary: z.string().trim().min(10, "Summarise the diagnosis (at least 10 characters)").max(2000, "At most 2000 characters"),
    treatingDoctorName: z.string().trim().min(2, "Treating doctor is required").max(100),
    tasks: z.array(taskSchema).max(30, "At most 30 tasks"),
    medications: z.array(medicationSchema).max(30, "At most 30 medicines"),
    followUpDaysText: z.string(),
    programTemplateCode: z.string(),
  })
  .superRefine((v, ctx) => {
    const today = todayIST();
    if (DATE_RE.test(v.dob) && v.dob > today) ctx.addIssue({ code: "custom", path: ["dob"], message: "Date of birth is in the future" });
    if (DATE_RE.test(v.dischargeDate)) {
      if (v.dischargeDate > today) ctx.addIssue({ code: "custom", path: ["dischargeDate"], message: "Discharge date cannot be in the future" });
      if (DATE_RE.test(v.dob) && v.dischargeDate < v.dob)
        ctx.addIssue({ code: "custom", path: ["dischargeDate"], message: "Discharge date is before the date of birth" });
    }
    if (v.familyPhone && v.familyPhone === normalisePhone(v.patientPhone))
      ctx.addIssue({ code: "custom", path: ["familyPhone"], message: "Family phone must differ from the patient's phone" });
    const days = parseFollowUpDays(v.followUpDaysText);
    if (days === null) ctx.addIssue({ code: "custom", path: ["followUpDaysText"], message: "Use whole numbers separated by commas, e.g. 7, 14, 30" });
    else if (days.length === 0) ctx.addIssue({ code: "custom", path: ["followUpDaysText"], message: "Add at least one follow-up day" });
    else if (days.some((d) => d < 1 || d > 90)) ctx.addIssue({ code: "custom", path: ["followUpDaysText"], message: "Follow-up days must be between 1 and 90" });
  });

export type DischargeFormValues = z.input<typeof dischargeSchema>;
export type DischargeParsed = z.output<typeof dischargeSchema>;

/** Fields validated on each step of the multi-step form. */
export const DISCHARGE_STEPS: { key: string; label: string; fields: (keyof DischargeFormValues)[] }[] = [
  { key: "patient", label: "Patient & family", fields: ["patientName", "patientPhone", "dob", "gender", "familyPhone"] },
  { key: "clinical", label: "Discharge details", fields: ["dischargeDate", "diagnosisSummary", "treatingDoctorName"] },
  { key: "followup", label: "Follow-up plan", fields: ["tasks", "medications", "followUpDaysText", "programTemplateCode"] },
  { key: "summary", label: "Summary PDF & review", fields: [] },
];

export function emptyDischarge(): DischargeFormValues {
  return {
    patientName: "",
    patientPhone: "+91",
    dob: "",
    gender: "" as unknown as "male",
    familyPhone: "",
    dischargeDate: todayIST(),
    diagnosisSummary: "",
    treatingDoctorName: "",
    tasks: [],
    medications: [],
    followUpDaysText: "7, 14, 30",
    programTemplateCode: "",
  };
}

/** Why the summary file cannot be sent (null = fine). */
export function dischargeFileError(file: File | null | undefined): string | null {
  if (!file) return "Attach the discharge summary PDF";
  const isPdf = file.type === "application/pdf" || file.name.toLowerCase().endsWith(".pdf");
  if (!isPdf) return "The discharge summary must be a PDF";
  if (file.size === 0) return "The file is empty";
  if (file.size > DISCHARGE_PDF_MAX_BYTES) return "The PDF is larger than 15 MB";
  return null;
}

const blank = (s: string | undefined) => {
  const t = s?.trim();
  return t ? t : undefined;
};

export function toFollowUp(v: DischargeParsed): DischargeFollowUp {
  return {
    tasks: v.tasks.map((t) => {
      const task: DischargeFollowUp["tasks"][number] = { type: t.type, title: t.title.trim(), owner: t.owner };
      const d = blank(t.description);
      if (d) task.description = d;
      return task;
    }),
    medications: v.medications.map((m) => {
      const med: DischargeFollowUp["medications"][number] = {
        name: m.name.trim(),
        dose: m.dose.trim(),
        frequency: m.frequency.trim(),
        times: [...m.times].sort(),
        startDate: m.startDate,
      };
      if (m.endDate) med.endDate = m.endDate;
      const ins = blank(m.instructions);
      if (ins) med.instructions = ins;
      return med;
    }),
    followUpDays: parseFollowUpDays(v.followUpDaysText) ?? [],
  };
}

/**
 * §59 multipart body: `patient` and `followUp` are JSON strings; optional fields are omitted when blank.
 */
export function buildDischargeFormData(v: DischargeParsed, file: File): FormData {
  const fd = new FormData();
  fd.append("patient", JSON.stringify({ name: v.patientName.trim(), phone: v.patientPhone, dob: v.dob, gender: v.gender }));
  if (v.familyPhone) fd.append("familyPhone", v.familyPhone);
  fd.append("dischargeDate", v.dischargeDate);
  fd.append("diagnosisSummary", v.diagnosisSummary.trim());
  fd.append("treatingDoctorName", v.treatingDoctorName.trim());
  fd.append("followUp", JSON.stringify(toFollowUp(v)));
  if (v.programTemplateCode.trim()) fd.append("programTemplateCode", v.programTemplateCode.trim());
  fd.append("file", file, file.name);
  return fd;
}

/** 0–100, days since discharge over the 30-day program. */
export function programProgress(day: number): number {
  if (!Number.isFinite(day)) return 0;
  return Math.max(0, Math.min(100, Math.round((day / 30) * 100)));
}

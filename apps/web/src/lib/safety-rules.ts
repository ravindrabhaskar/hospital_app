import { z } from "zod";
import type { SafetyRule } from "@/lib/api/types";

const vitalTypes = ["bp_systolic", "bp_diastolic", "pulse", "spo2", "temperature", "blood_glucose", "weight", "respiratory_rate"] as const;

export const safetyRuleSchema = z
  .object({
    id: z.string().trim().min(1, "id is required"),
    title: z.string().trim().min(1, "title is required"),
    description: z.string(),
    when: z
      .object({
        anyKeywords: z.array(z.string().min(1)).optional(),
        allKeywords: z.array(z.string().min(1)).optional(),
        minSeverity: z.number().min(0).max(10).optional(),
        vital: z.object({ type: z.enum(vitalTypes), op: z.enum(["lt", "gt"]), value: z.number() }).strict().optional(),
        ageGte: z.number().int().min(0).optional(),
      })
      .strict()
      .refine((w) => Object.values(w).some((v) => v !== undefined), { message: "when must contain at least one condition" }),
    level: z.enum(["routine", "urgent", "emergency"]),
    action: z.enum(["show_emergency", "escalate_clinician", "suggest_doctor", "suggest_home_visit"]),
  })
  .strict();

export const rulePackSchema = z.array(safetyRuleSchema).min(1, "A pack needs at least one rule");

/** Duplicate ids are checked on the raw input so they are reported alongside schema errors. */
function duplicateIdErrors(candidate: unknown): string[] {
  if (!Array.isArray(candidate)) return [];
  const seen = new Set<string>();
  const errors: string[] = [];
  candidate.forEach((r, i) => {
    const id = (r as { id?: unknown } | null)?.id;
    if (typeof id !== "string") return;
    if (seen.has(id)) errors.push(`rules[${i}].id: duplicate rule id "${id}"`);
    seen.add(id);
  });
  return errors;
}

export type RulePackParse = { ok: true; rules: SafetyRule[] } | { ok: false; errors: string[] };

/** Parse + validate the JSON editor text. Accepts either an array of rules or `{ rules: [...] }`. */
export function parseRulePackJson(text: string): RulePackParse {
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch (e) {
    return { ok: false, errors: [`Invalid JSON: ${(e as Error).message}`] };
  }
  const candidate = Array.isArray(raw) ? raw : (raw as { rules?: unknown } | null)?.rules;
  const res = rulePackSchema.safeParse(candidate);
  const dupes = duplicateIdErrors(candidate);
  if (res.success && dupes.length === 0) return { ok: true, rules: res.data as SafetyRule[] };
  const schemaErrors = res.success
    ? []
    : res.error.issues.map((i) => `${i.path.length ? `rules[${i.path[0]}]${i.path.slice(1).map((p) => `.${String(p)}`).join("")}: ` : ""}${i.message}`);
  return { ok: false, errors: [...schemaErrors, ...dupes].slice(0, 20) };
}

export const RULE_PACK_TEMPLATE = JSON.stringify(
  [
    {
      id: "chest-pain-emergency",
      title: "Chest pain with breathlessness",
      description: "Chest pain plus breathlessness needs emergency care.",
      when: { allKeywords: ["chest pain", "breathless"] },
      level: "emergency",
      action: "show_emergency",
    },
    {
      id: "low-spo2",
      title: "Low oxygen saturation",
      description: "SpO2 below 92% needs clinician review.",
      when: { vital: { type: "spo2", op: "lt", value: 92 } },
      level: "urgent",
      action: "escalate_clinician",
    },
  ],
  null,
  2,
);

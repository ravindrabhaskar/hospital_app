import { z } from "zod";
import type { Organization, TenantInput } from "@/lib/api/types";

export const HEX_RE = /^#[0-9A-Fa-f]{6}$/;

function channel(c: number) {
  const s = c / 255;
  return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
}

export function luminance(hex: string): number {
  if (!HEX_RE.test(hex)) return 0;
  const n = parseInt(hex.slice(1), 16);
  return 0.2126 * channel((n >> 16) & 255) + 0.7152 * channel((n >> 8) & 255) + 0.0722 * channel(n & 255);
}

export function contrastRatio(a: string, b: string): number {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x) as [number, number];
  return (hi + 0.05) / (lo + 0.05);
}

/** White or near-black text, whichever reads better on the brand colour. */
export function readableTextOn(hex: string): "#ffffff" | "#12211b" {
  return contrastRatio(hex, "#ffffff") >= contrastRatio(hex, "#12211b") ? "#ffffff" : "#12211b";
}

const optional = (schema: z.ZodString) => z.union([z.literal(""), schema]);

export const tenantSchema = z.object({
  code: z
    .string()
    .trim()
    .min(2, "Code is required")
    .max(40, "At most 40 characters")
    .regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, "Lowercase letters, digits and hyphens, e.g. deccan-sunrise"),
  displayName: z.string().trim().min(2, "Display name is required").max(80, "At most 80 characters"),
  primaryColor: z.string().trim().regex(HEX_RE, "Use a #RRGGBB colour"),
  logoMediaId: z.string().trim().max(200, "At most 200 characters"),
  facilityIdsText: z.string(),
  supportPhone: optional(z.string().trim().regex(/^\+[1-9]\d{7,14}$/, "Use international format, e.g. +914012345678")),
  supportEmail: optional(z.string().trim().email("Enter a valid email")),
});
export type TenantFormValues = z.input<typeof tenantSchema>;

export const splitIds = (t: string) => [...new Set(t.split(/[\s,]+/).map((s) => s.trim()).filter(Boolean))];

export function toTenantInput(v: z.output<typeof tenantSchema>): TenantInput {
  const input: TenantInput = {
    code: v.code,
    displayName: v.displayName,
    primaryColor: v.primaryColor.toUpperCase(),
    facilityIds: splitIds(v.facilityIdsText),
  };
  if (v.logoMediaId) input.logoMediaId = v.logoMediaId;
  if (v.supportPhone) input.supportPhone = v.supportPhone;
  if (v.supportEmail) input.supportEmail = v.supportEmail;
  return input;
}

function csvCell(s: string) {
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/** CSV of single-use organization codes for download. */
export function codesToCsv(org: Pick<Organization, "name" | "planCode">, codes: readonly string[]): string {
  const rows = [["organization", "plan", "code"], ...codes.map((c) => [org.name, org.planCode, c])];
  return rows.map((r) => r.map(csvCell).join(",")).join("\r\n") + "\r\n";
}

import { z } from "zod";
import type { Coupon, CouponInput, PaymentPurpose } from "@/lib/api/types";
import { isoToISTDate, istDayEndISO, istDayStartISO } from "@/lib/format";

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** Optional whole number: "" = not set. */
const optInt = (min: number, max: number) =>
  z.union([
    z.literal(""),
    z.coerce.number({ invalid_type_error: "Enter a number" }).int("Whole numbers only").min(min, `At least ${min}`).max(max, `At most ${max}`),
  ]);

export const couponSchema = z
  .object({
    code: z
      .string()
      .trim()
      .transform((s) => s.toUpperCase())
      .pipe(z.string().regex(/^[A-Z0-9]{4,20}$/, "4–20 letters or digits, e.g. WELCOME100")),
    description: z.string().trim().min(3, "Describe the offer").max(200, "At most 200 characters"),
    type: z.enum(["percent", "flat"]),
    value: z.coerce.number({ invalid_type_error: "Enter a value" }).int("Whole numbers only").min(1, "At least 1").max(100_000, "At most 100000"),
    maxDiscount: optInt(1, 100_000),
    minAmount: optInt(0, 1_000_000),
    appliesTo: z
      .array(z.enum(["appointment", "home_visit", "pharmacy_order", "subscription", "lab_order", "second_opinion", "ambulance"]))
      .min(1, "Choose at least one service"),
    validFrom: z.string().regex(DATE_RE, "Enter a start date"),
    validTo: z.string().regex(DATE_RE, "Enter an end date"),
    usageLimit: optInt(1, 10_000_000),
    perUserLimit: z.coerce.number({ invalid_type_error: "Enter a number" }).int("Whole numbers only").min(1, "At least 1").max(100, "At most 100"),
    active: z.boolean(),
  })
  .superRefine((v, ctx) => {
    if (v.type === "percent") {
      if (v.value > 100) ctx.addIssue({ code: "custom", path: ["value"], message: "A percentage cannot exceed 100" });
      if (v.maxDiscount === "") ctx.addIssue({ code: "custom", path: ["maxDiscount"], message: "Percentage coupons need a maximum discount (₹)" });
    } else {
      if (v.maxDiscount !== "") ctx.addIssue({ code: "custom", path: ["maxDiscount"], message: "Not used for flat coupons; leave blank" });
      if (v.minAmount !== "" && v.value > v.minAmount)
        ctx.addIssue({ code: "custom", path: ["value"], message: "A flat discount cannot exceed the minimum order amount" });
    }
    if (DATE_RE.test(v.validFrom) && DATE_RE.test(v.validTo) && v.validTo < v.validFrom)
      ctx.addIssue({ code: "custom", path: ["validTo"], message: "The end date is before the start date" });
    if (v.usageLimit !== "" && v.usageLimit < v.perUserLimit)
      ctx.addIssue({ code: "custom", path: ["usageLimit"], message: "Total usage limit is below the per-user limit" });
  });

export type CouponFormValues = z.input<typeof couponSchema>;
export type CouponParsed = z.output<typeof couponSchema>;

export function couponDefaults(c?: Coupon | null): CouponFormValues {
  if (!c)
    return {
      code: "",
      description: "",
      type: "flat",
      value: 100,
      maxDiscount: "",
      minAmount: "",
      appliesTo: ["home_visit"],
      validFrom: "",
      validTo: "",
      usageLimit: "",
      perUserLimit: 1,
      active: true,
    };
  return {
    code: c.code,
    description: c.description,
    type: c.type,
    value: c.value,
    maxDiscount: c.maxDiscount ?? "",
    minAmount: c.minAmount ?? "",
    appliesTo: c.appliesTo,
    validFrom: isoToISTDate(c.validFrom),
    validTo: isoToISTDate(c.validTo),
    usageLimit: c.usageLimit ?? "",
    perUserLimit: c.perUserLimit,
    active: c.active,
  };
}

/** Parsed form → §60 body. Unset optional numbers are omitted; dates become ISO datetimes. */
export function toCouponInput(v: CouponParsed): CouponInput {
  const input: CouponInput = {
    code: v.code,
    description: v.description,
    type: v.type,
    value: v.value,
    appliesTo: v.appliesTo as PaymentPurpose[],
    // The API takes ISO datetimes: valid from the start of the first IST day through the end of the last.
    validFrom: istDayStartISO(v.validFrom),
    validTo: istDayEndISO(v.validTo),
    perUserLimit: v.perUserLimit,
    active: v.active,
  };
  if (v.maxDiscount !== "") input.maxDiscount = v.maxDiscount;
  if (v.minAmount !== "") input.minAmount = v.minAmount;
  if (v.usageLimit !== "") input.usageLimit = v.usageLimit;
  return input;
}

export function describeCoupon(c: Pick<CouponInput, "type" | "value" | "maxDiscount" | "minAmount">): string {
  const main = c.type === "percent" ? `${c.value}% off` : `₹${c.value} off`;
  const cap = c.type === "percent" && c.maxDiscount ? ` (max ₹${c.maxDiscount})` : "";
  const min = c.minAmount ? ` on orders ≥ ₹${c.minAmount}` : "";
  return `${main}${cap}${min}`;
}

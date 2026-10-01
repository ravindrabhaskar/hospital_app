"use client";

import { useForm, useWatch } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { PAYMENT_PURPOSES, type Coupon, type CouponInput } from "@/lib/api/types";
import { couponDefaults, couponSchema, describeCoupon, toCouponInput, type CouponFormValues, type CouponParsed } from "@/lib/coupons";
import { humanize } from "@/lib/format";
import { Field, Input, Select, Textarea } from "./ui";

/** §60 coupon create/edit form. Submits a validated `CouponInput` via `onSubmit`. */
export function CouponForm({ coupon, formId, onSubmit }: { coupon: Coupon | null; formId: string; onSubmit: (input: CouponInput) => void }) {
  const form = useForm<CouponFormValues, unknown, CouponParsed>({ resolver: zodResolver(couponSchema), defaultValues: couponDefaults(coupon) });
  const { register, handleSubmit, formState, control } = form;
  const e = formState.errors;
  const [type, value, maxDiscount, minAmount] = useWatch({ control, name: ["type", "value", "maxDiscount", "minAmount"] });
  const num = (v: unknown) => (v === "" || v === undefined || v === null || Number.isNaN(Number(v)) ? undefined : Number(v));

  return (
    <form id={formId} noValidate onSubmit={handleSubmit((v) => onSubmit(toCouponInput(v)))} className="grid gap-3 sm:grid-cols-2" aria-label="Coupon">
      <Field label="Code" required error={e.code?.message} hint={coupon ? "The code cannot be changed." : "Letters and digits; saved in upper case"}>
        {(id, d) => <Input id={id} className="font-mono uppercase" readOnly={!!coupon} data-autofocus={coupon ? undefined : ""} aria-describedby={d} aria-invalid={!!e.code} {...register("code")} />}
      </Field>
      <Field label="Type" required>
        {(id) => (
          <Select id={id} {...register("type")}>
            <option value="flat">Flat (₹ off)</option>
            <option value="percent">Percentage</option>
          </Select>
        )}
      </Field>
      <Field label="Description" required error={e.description?.message} className="sm:col-span-2">
        {(id, d) => <Textarea id={id} rows={2} aria-describedby={d} aria-invalid={!!e.description} {...register("description")} />}
      </Field>
      <Field label={type === "percent" ? "Discount (%)" : "Discount (₹)"} required error={e.value?.message}>
        {(id, d) => <Input id={id} type="number" min={1} aria-describedby={d} aria-invalid={!!e.value} {...register("value")} />}
      </Field>
      <Field label="Maximum discount (₹)" required={type === "percent"} error={e.maxDiscount?.message} hint={type === "percent" ? "Caps a percentage discount" : "Only for percentage coupons"}>
        {(id, d) => <Input id={id} type="number" min={1} aria-describedby={d} aria-invalid={!!e.maxDiscount} disabled={type !== "percent"} {...register("maxDiscount")} />}
      </Field>
      <Field label="Minimum order (₹)" error={e.minAmount?.message} hint="Optional">
        {(id, d) => <Input id={id} type="number" min={0} aria-describedby={d} aria-invalid={!!e.minAmount} {...register("minAmount")} />}
      </Field>
      <Field label="Per-user limit" required error={e.perUserLimit?.message}>
        {(id, d) => <Input id={id} type="number" min={1} aria-describedby={d} aria-invalid={!!e.perUserLimit} {...register("perUserLimit")} />}
      </Field>
      <Field label="Total usage limit" error={e.usageLimit?.message} hint="Optional">
        {(id, d) => <Input id={id} type="number" min={1} aria-describedby={d} aria-invalid={!!e.usageLimit} {...register("usageLimit")} />}
      </Field>
      <div />
      <Field label="Valid from" required error={e.validFrom?.message}>
        {(id, d) => <Input id={id} type="date" aria-describedby={d} aria-invalid={!!e.validFrom} {...register("validFrom")} />}
      </Field>
      <Field label="Valid to" required error={e.validTo?.message}>
        {(id, d) => <Input id={id} type="date" aria-describedby={d} aria-invalid={!!e.validTo} {...register("validTo")} />}
      </Field>
      <fieldset className="sm:col-span-2">
        <legend className="mb-1 text-[13px] font-medium">
          Applies to <span className="text-danger" aria-hidden>*</span>
        </legend>
        <div className="flex flex-wrap gap-x-4 gap-y-2">
          {PAYMENT_PURPOSES.map((p) => (
            <label key={p} className="flex items-center gap-2 text-sm">
              <input type="checkbox" value={p} className="size-4 accent-[#631D3F]" {...register("appliesTo")} />
              {humanize(p)}
            </label>
          ))}
        </div>
        {e.appliesTo && (
          <p role="alert" className="mt-1 text-xs text-danger-dark">
            {e.appliesTo.message ?? e.appliesTo.root?.message}
          </p>
        )}
      </fieldset>
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" className="size-4 accent-[#631D3F]" {...register("active")} />
        Active
      </label>
      <p className="text-sm text-ink-muted sm:text-right" aria-live="polite">
        Preview: <strong>{num(value) ? describeCoupon({ type, value: num(value)!, maxDiscount: num(maxDiscount), minAmount: num(minAmount) }) : "—"}</strong>
      </p>
    </form>
  );
}

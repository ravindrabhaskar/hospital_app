import { describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { couponSchema, type CouponFormValues } from "@/lib/coupons";
import { CouponForm } from "./coupon-form";

const base: CouponFormValues = {
  code: "care10",
  description: "10% off lab orders",
  type: "percent",
  value: 10,
  maxDiscount: 200,
  minAmount: "",
  appliesTo: ["lab_order"],
  validFrom: "2026-10-01",
  validTo: "2026-12-31",
  usageLimit: "",
  perUserLimit: 1,
  active: true,
};
const errs = (p: Partial<CouponFormValues>) => {
  const r = couponSchema.safeParse({ ...base, ...p });
  return r.success ? {} : Object.fromEntries(r.error.issues.map((i) => [i.path.join("."), i.message]));
};

describe("coupon rules", () => {
  it("upper-cases the code and accepts a capped percentage", () => {
    const r = couponSchema.safeParse(base);
    expect(r.success && r.data.code).toBe("CARE10");
  });
  it("rejects bad codes, >100%, uncapped percentages and flat caps", () => {
    expect(errs({ code: "a b" }).code).toMatch(/letters or digits/);
    expect(errs({ value: 150 }).value).toBe("A percentage cannot exceed 100");
    expect(errs({ maxDiscount: "" }).maxDiscount).toMatch(/maximum discount/);
    expect(errs({ type: "flat", value: 100, maxDiscount: 50 }).maxDiscount).toMatch(/Not used for flat/);
    expect(errs({ type: "flat", value: 500, maxDiscount: "", minAmount: 300 }).value).toMatch(/cannot exceed the minimum/);
  });
  it("checks dates, services and limits", () => {
    expect(errs({ validTo: "2026-09-01" }).validTo).toMatch(/before the start/);
    expect(errs({ appliesTo: [] }).appliesTo).toBe("Choose at least one service");
    expect(errs({ usageLimit: 1, perUserLimit: 2 }).usageLimit).toMatch(/below the per-user limit/);
    expect(errs({ perUserLimit: 0 }).perUserLimit).toBe("At least 1");
  });
});

describe("CouponForm", () => {
  it("shows errors and submits a clean §60 body", async () => {
    const onSubmit = vi.fn();
    render(<CouponForm coupon={null} formId="f" onSubmit={onSubmit} />);
    const submit = () => fireEvent.submit(screen.getByRole("form", { name: "Coupon" }));

    submit();
    expect(await screen.findByText(/4–20 letters or digits/)).toBeInTheDocument();
    expect(onSubmit).not.toHaveBeenCalled();

    fireEvent.change(screen.getByLabelText(/^code/i), { target: { value: "welcome100" } });
    fireEvent.change(screen.getByLabelText(/^description/i), { target: { value: "₹100 off your first home visit" } });
    fireEvent.change(screen.getByLabelText(/valid from/i), { target: { value: "2026-10-01" } });
    fireEvent.change(screen.getByLabelText(/valid to/i), { target: { value: "2026-12-31" } });
    expect(screen.getByText("₹100 off")).toBeInTheDocument();
    submit();
    await waitFor(() => expect(onSubmit).toHaveBeenCalledTimes(1));
    expect(onSubmit).toHaveBeenCalledWith({
      code: "WELCOME100",
      description: "₹100 off your first home visit",
      type: "flat",
      value: 100,
      appliesTo: ["home_visit"],
      validFrom: "2026-10-01",
      validTo: "2026-12-31",
      perUserLimit: 1,
      active: true,
    });
  });

  it("requires a cap when switched to percentage", async () => {
    const onSubmit = vi.fn();
    render(<CouponForm coupon={null} formId="f" onSubmit={onSubmit} />);
    fireEvent.change(screen.getByLabelText(/^type/i), { target: { value: "percent" } });
    fireEvent.change(screen.getByLabelText(/^code/i), { target: { value: "CARE10" } });
    fireEvent.change(screen.getByLabelText(/^description/i), { target: { value: "10% off" } });
    fireEvent.change(screen.getByLabelText(/discount \(%\)/i), { target: { value: "10" } });
    fireEvent.change(screen.getByLabelText(/valid from/i), { target: { value: "2026-10-01" } });
    fireEvent.change(screen.getByLabelText(/valid to/i), { target: { value: "2026-12-31" } });
    fireEvent.submit(screen.getByRole("form", { name: "Coupon" }));
    expect(await screen.findByText(/need a maximum discount/)).toBeInTheDocument();
    expect(onSubmit).not.toHaveBeenCalled();
  });
});

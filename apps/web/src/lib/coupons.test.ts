import { describe, expect, it } from "vitest";
import type { Coupon } from "@/lib/api/types";
import { couponDefaults, couponSchema, toCouponInput } from "./coupons";
import { isoToISTDate, istDayEndISO, istDayStartISO } from "./format";

describe("IST calendar-day ↔ ISO datetime helpers", () => {
  it("start of day is IST midnight in UTC", () => {
    expect(istDayStartISO("2026-10-01")).toBe("2026-09-30T18:30:00.000Z");
  });
  it("end of day is the last IST millisecond in UTC", () => {
    expect(istDayEndISO("2028-12-31")).toBe("2028-12-31T18:29:59.999Z");
  });
  it("rejects anything that is not YYYY-MM-DD", () => {
    expect(() => istDayStartISO("")).toThrow(RangeError);
    expect(() => istDayEndISO("31/12/2028")).toThrow(RangeError);
  });
  it("round-trips back to the same IST calendar date", () => {
    for (const d of ["2026-01-01", "2026-10-01", "2028-12-31"]) {
      expect(isoToISTDate(istDayStartISO(d))).toBe(d);
      expect(isoToISTDate(istDayEndISO(d))).toBe(d);
    }
  });
  it("passes plain dates through and blanks missing/invalid values", () => {
    expect(isoToISTDate("2026-10-01")).toBe("2026-10-01");
    expect(isoToISTDate(null)).toBe("");
    expect(isoToISTDate("not a date")).toBe("");
  });
});

const coupon: Coupon = {
  id: "c1",
  code: "WELCOME100",
  description: "₹100 off",
  type: "flat",
  value: 100,
  appliesTo: ["home_visit"],
  // As the API stores them: IST midnight / IST end of day in UTC.
  validFrom: "2026-09-30T18:30:00.000Z",
  validTo: "2026-12-31T18:29:59.999Z",
  perUserLimit: 1,
  active: true,
};

describe("coupon dates", () => {
  it("editing shows the IST calendar dates, not the shifted UTC date", () => {
    const v = couponDefaults(coupon);
    expect(v.validFrom).toBe("2026-10-01");
    expect(v.validTo).toBe("2026-12-31");
  });

  it("saving sends ISO datetimes covering whole IST days, and an unchanged edit round-trips", () => {
    const parsed = couponSchema.parse(couponDefaults(coupon));
    const input = toCouponInput(parsed);
    expect(input.validFrom).toBe(coupon.validFrom);
    expect(input.validTo).toBe(coupon.validTo);
  });

  it("a single-day coupon still has validTo after validFrom (API requires it)", () => {
    const input = toCouponInput(couponSchema.parse({ ...couponDefaults(coupon), validFrom: "2026-10-05", validTo: "2026-10-05" }));
    expect(new Date(input.validTo).getTime()).toBeGreaterThan(new Date(input.validFrom).getTime());
  });
});

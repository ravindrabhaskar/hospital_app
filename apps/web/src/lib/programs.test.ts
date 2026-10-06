import { describe, expect, it } from "vitest";
import {
  emptyDraft,
  templateDescriptionError,
  thresholdsDiffer,
  toApproveInput,
  toThresholds,
  validateApproval,
  validateThresholds,
  type ThresholdDraft,
} from "./programs";

const row = (p: Partial<ThresholdDraft> = {}): ThresholdDraft => ({ type: "bp_systolic", op: "gt", value: "160", level: "urgent", message: "Systolic above 160", ...p });

describe("threshold editor validation", () => {
  it("accepts valid thresholds and converts values to numbers", () => {
    const drafts = [row(), row({ value: "180", level: "emergency", message: "Systolic above 180" }), row({ op: "lt", value: "90", message: "Low BP" })];
    expect(validateThresholds(drafts).ok).toBe(true);
    expect(toThresholds(drafts)[1]).toEqual({ type: "bp_systolic", op: "gt", value: 180, level: "emergency", message: "Systolic above 180" });
  });

  it("flags empty, non-numeric and out-of-range values per row", () => {
    const v = validateThresholds([row({ value: "" }), row({ value: "abc" }), row({ type: "spo2", op: "lt", value: "120" })]);
    expect(v.ok).toBe(false);
    expect(v.rows[0]!.value).toBe("Enter a value");
    expect(v.rows[1]!.value).toBe("Enter a number");
    expect(v.rows[2]!.value).toBe("Between 50 and 100");
  });

  it("requires a message and rejects duplicate vital/direction/value", () => {
    const v = validateThresholds([row(), row({ message: "x", level: "emergency" }), row({ level: "emergency" })]);
    expect(v.rows[1]!.message).toMatch(/at least 3/);
    expect(v.rows[2]!.value).toBe("Duplicate of threshold 1");
    expect(v.form).toContain("Two thresholds have the same vital, direction and value.");
  });

  it("can require at least one threshold and caps the count", () => {
    expect(validateThresholds([], { requireAtLeastOne: true }).form).toContain("Add at least one threshold.");
    expect(validateThresholds([]).ok).toBe(true);
    const many = Array.from({ length: 21 }, (_, i) => row({ value: String(100 + i) }));
    expect(validateThresholds(many).form).toContain("At most 20 thresholds.");
    expect(emptyDraft().value).toBe("");
  });

  it("detects edits relative to the template defaults regardless of order", () => {
    const a = toThresholds([row(), row({ op: "lt", value: "90", message: "Low" })]);
    expect(thresholdsDiffer(a, [...a].reverse())).toBe(false);
    expect(thresholdsDiffer(a, [{ ...a[0]!, value: 165 }, a[1]!])).toBe(true);
    expect(() => toThresholds([row({ value: "" })])).toThrow();
  });
});

describe("template approval payload (QA B5)", () => {
  it("requires an approver name of at least 2 characters", () => {
    expect(validateApproval({ approverName: " ", approverRegistration: "" }).approverName).toBeTruthy();
    expect(validateApproval({ approverName: "Dr Asha Rao", approverRegistration: "" })).toEqual({});
    expect(validateApproval({ approverName: "Dr Asha Rao", approverRegistration: "K" }).approverRegistration).toBeTruthy();
  });

  it("trims, omits an empty registration and pins the version", () => {
    expect(toApproveInput({ approverName: "  Dr Asha Rao ", approverRegistration: " " }, "1.1")).toEqual({ approverName: "Dr Asha Rao", version: "1.1" });
    expect(toApproveInput({ approverName: "Dr Asha Rao", approverRegistration: " KMC-1234 " })).toEqual({ approverName: "Dr Asha Rao", approverRegistration: "KMC-1234" });
  });
});

describe("template description (QA B24)", () => {
  it("is required and capped at 1000 characters", () => {
    expect(templateDescriptionError("   ")).toMatch(/required/i);
    expect(templateDescriptionError("x".repeat(1001))).toBeTruthy();
    expect(templateDescriptionError("Heart failure remote monitoring")).toBeUndefined();
  });
});

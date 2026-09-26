import { describe, expect, it } from "vitest";
import { emptyRxItem, prescriptionSchema, rxLine, toPrescriptionInput, type PrescriptionFormValues } from "./prescription";

type Item = PrescriptionFormValues["items"][number];

function values(item: Partial<Item> = {}, rest: Partial<PrescriptionFormValues> = {}): PrescriptionFormValues {
  return { clinicalNote: "", advice: "", followUpInDays: "", items: [{ ...emptyRxItem(), drugName: "Paracetamol", ...item }], ...rest };
}

function issuesFor(v: PrescriptionFormValues) {
  const r = prescriptionSchema.safeParse(v);
  expect(r.success).toBe(false);
  return r.success ? [] : r.error.issues;
}

function pathMessages(v: PrescriptionFormValues) {
  return issuesFor(v).map((i) => `${i.path.join(".")}: ${i.message}`);
}

describe("prescriptionSchema", () => {
  it("accepts a valid prescription with blank optionals", () => {
    expect(prescriptionSchema.safeParse(values()).success).toBe(true);
  });

  it("requires a drug name", () => {
    expect(pathMessages(values({ drugName: "  " }))).toContain("items.0.drugName: Drug name is required");
  });

  it("requires a dose", () => {
    expect(pathMessages(values({ dose: "" }))).toContain("items.0.dose: Dose is required");
  });

  it("requires a frequency", () => {
    expect(pathMessages(values({ frequency: " " }))).toContain("items.0.frequency: Frequency is required");
  });

  it.each([
    [0, "At least 1 day"],
    [-3, "At least 1 day"],
    [2.5, "Whole days only"],
    ["abc", "Enter the number of days"],
  ])("rejects duration %s", (durationDays, msg) => {
    expect(pathMessages(values({ durationDays: durationDays as number }))).toContain(`items.0.durationDays: ${msg}`);
  });

  it("coerces a numeric string duration", () => {
    const r = prescriptionSchema.safeParse(values({ durationDays: "7" as unknown as number }));
    expect(r.success && r.data.items[0]?.durationDays).toBe(7);
  });

  it("rejects an invalid reminder time", () => {
    expect(pathMessages(values({ times: ["25:00"] }))).toContain("items.0.times.0: Use HH:MM");
  });

  it("rejects duplicate reminder times", () => {
    expect(pathMessages(values({ times: ["08:00", "08:00"] }))).toContain("items.0.times: Reminder times must be different");
  });

  it("rejects 0 items and more than 20 items", () => {
    expect(pathMessages({ ...values(), items: [] })).toContain("items: Add at least one medicine");
    const many = Array.from({ length: 21 }, () => ({ ...emptyRxItem(), drugName: "Cetirizine" }));
    expect(pathMessages({ ...values(), items: many })).toContain("items: At most 20 medicines");
    expect(prescriptionSchema.safeParse({ ...values(), items: many.slice(0, 20) }).success).toBe(true);
  });

  it("accepts an empty or missing follow-up", () => {
    expect(prescriptionSchema.safeParse(values({}, { followUpInDays: "" })).success).toBe(true);
    const { followUpInDays: _omit, ...noFollowUp } = values();
    void _omit;
    expect(prescriptionSchema.safeParse(noFollowUp).success).toBe(true);
  });

  it.each([0, -1, 1.5, 400])("rejects follow-up %s", (followUpInDays) => {
    expect(issuesFor(values({}, { followUpInDays })).some((i) => i.path[0] === "followUpInDays")).toBe(true);
  });
});

describe("toPrescriptionInput", () => {
  it("omits blank optionals, sorts times and trims strings", () => {
    const parsed = prescriptionSchema.parse(
      values(
        { drugName: "  Amoxicillin ", strength: "  ", timing: "", instructions: "   ", dose: " 1 capsule ", frequency: " Thrice daily ", form: "capsule", times: ["20:00", "08:00", "14:00"], durationDays: 5 },
        { clinicalNote: "   ", advice: "", followUpInDays: "" },
      ),
    );
    const input = toPrescriptionInput("appt-1", parsed);
    expect(input).toEqual({
      appointmentId: "appt-1",
      items: [{ drugName: "Amoxicillin", form: "capsule", dose: "1 capsule", frequency: "Thrice daily", durationDays: 5, times: ["08:00", "14:00", "20:00"] }],
    });
    expect(Object.keys(input)).not.toContain("followUpInDays");
    expect(Object.keys(input.items[0]!)).not.toContain("strength");
  });

  it("includes trimmed optionals and a numeric follow-up", () => {
    const parsed = prescriptionSchema.parse(
      values(
        { strength: " 500 mg ", timing: " After food ", instructions: " With water " },
        { clinicalNote: " Viral fever ", advice: " Rest ", followUpInDays: "7" as unknown as number },
      ),
    );
    expect(toPrescriptionInput("a2", parsed)).toEqual({
      appointmentId: "a2",
      clinicalNote: "Viral fever",
      advice: "Rest",
      followUpInDays: 7,
      items: [
        {
          drugName: "Paracetamol",
          strength: "500 mg",
          form: "tablet",
          dose: "1 tablet",
          frequency: "Twice daily",
          timing: "After food",
          durationDays: 5,
          times: ["08:00", "20:00"],
          instructions: "With water",
        },
      ],
    });
  });
});

describe("rxLine", () => {
  it("joins the non-empty parts", () => {
    expect(rxLine({ dose: "1 tablet", frequency: "Twice daily", timing: "", durationDays: 5 })).toBe("1 tablet · Twice daily · 5 days");
  });
});

import { describe, expect, it } from "vitest";
import { addDays, todayIST } from "./format";
import { buildDischargeFormData, dischargeFileError, dischargeSchema, emptyDischarge, parseFollowUpDays, programProgress, type DischargeFormValues } from "./discharge";

const valid = (p: Partial<DischargeFormValues> = {}): DischargeFormValues => ({
  ...emptyDischarge(),
  patientName: "Lakshmi Devi",
  patientPhone: "98765 43210",
  dob: "1958-04-12",
  gender: "female",
  familyPhone: "+919812345678",
  dischargeDate: todayIST(),
  diagnosisSummary: "Community-acquired pneumonia, treated with IV antibiotics.",
  treatingDoctorName: "Dr. Suresh",
  tasks: [{ type: "follow_up", title: "OPD review", description: "", owner: "patient" }],
  medications: [{ name: "Amoxicillin", dose: "500 mg", frequency: "Thrice daily", times: ["20:00", "08:00", "14:00"], startDate: todayIST(), endDate: "", instructions: "" }],
  followUpDaysText: "14, 7, 30, 7",
  programTemplateCode: "",
  ...p,
});

const issues = (v: DischargeFormValues) => {
  const r = dischargeSchema.safeParse(v);
  return r.success ? {} : Object.fromEntries(r.error.issues.map((i) => [i.path.join("."), i.message]));
};

describe("discharge form validation", () => {
  it("accepts a complete discharge and normalises the phone", () => {
    const r = dischargeSchema.safeParse(valid());
    expect(r.success).toBe(true);
    expect(r.success && r.data.patientPhone).toBe("+919876543210");
  });

  it("rejects missing required fields", () => {
    const e = issues(valid({ patientName: "", diagnosisSummary: "short", treatingDoctorName: "", dob: "", gender: "" as never }));
    expect(e.patientName).toBe("Patient name is required");
    expect(e.diagnosisSummary).toMatch(/at least 10/);
    expect(e.treatingDoctorName).toBe("Treating doctor is required");
    expect(e.dob).toBe("Enter the date of birth");
    expect(e.gender).toBe("Choose a gender");
  });

  it("rejects future dates, a family phone equal to the patient's, and bad follow-up days", () => {
    expect(issues(valid({ dischargeDate: addDays(todayIST(), 1) })).dischargeDate).toMatch(/future/);
    expect(issues(valid({ familyPhone: "9876543210" })).familyPhone).toMatch(/differ/);
    expect(issues(valid({ followUpDaysText: "7, x" })).followUpDaysText).toMatch(/whole numbers/);
    expect(issues(valid({ followUpDaysText: "" })).followUpDaysText).toMatch(/at least one/);
    expect(issues(valid({ followUpDaysText: "0, 120" })).followUpDaysText).toMatch(/between 1 and 90/);
    expect(issues(valid({ medications: [{ ...valid().medications[0]!, times: [] }] }))["medications.0.times"]).toBe("Add at least one time");
  });

  it("parses follow-up days and program progress", () => {
    expect(parseFollowUpDays("30 7, 14 7")).toEqual([7, 14, 30]);
    expect(programProgress(15)).toBe(50);
    expect(programProgress(45)).toBe(100);
  });

  it("validates the summary PDF", () => {
    expect(dischargeFileError(null)).toMatch(/attach/i);
    expect(dischargeFileError(new File(["x"], "a.png", { type: "image/png" }))).toMatch(/PDF/);
    expect(dischargeFileError(new File(["%PDF"], "summary.pdf", { type: "application/pdf" }))).toBeNull();
  });
});

describe("discharge multipart payload", () => {
  it("sends JSON parts for patient and followUp, omits blank optionals and attaches the file", () => {
    const parsed = dischargeSchema.parse(valid({ familyPhone: "", programTemplateCode: "" }));
    const file = new File(["%PDF-1.4"], "summary.pdf", { type: "application/pdf" });
    const fd = buildDischargeFormData(parsed, file);
    expect(JSON.parse(fd.get("patient") as string)).toEqual({ name: "Lakshmi Devi", phone: "+919876543210", dob: "1958-04-12", gender: "female" });
    expect(fd.has("familyPhone")).toBe(false);
    expect(fd.has("programTemplateCode")).toBe(false);
    expect(fd.get("dischargeDate")).toBe(todayIST());
    expect(fd.get("treatingDoctorName")).toBe("Dr. Suresh");
    expect(JSON.parse(fd.get("followUp") as string)).toEqual({
      tasks: [{ type: "follow_up", title: "OPD review", owner: "patient" }],
      medications: [{ name: "Amoxicillin", dose: "500 mg", frequency: "Thrice daily", times: ["08:00", "14:00", "20:00"], startDate: todayIST() }],
      followUpDays: [7, 14, 30],
    });
    expect((fd.get("file") as File).name).toBe("summary.pdf");

    const withOptional = buildDischargeFormData(dischargeSchema.parse(valid({ programTemplateCode: "heart_failure" })), file);
    expect(withOptional.get("familyPhone")).toBe("+919812345678");
    expect(withOptional.get("programTemplateCode")).toBe("heart_failure");
  });
});

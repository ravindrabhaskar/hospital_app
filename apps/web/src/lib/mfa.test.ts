import { describe, expect, it } from "vitest";
import { initialMfaState, markMfaRequired, mfaPath, mfaReducer, mfaStepFor, qrImageSrc, formatSecret, type MfaState } from "./mfa";

const enrollment = { secret: "JBSWY3DPEHPK3PXP", otpauthUrl: "otpauth://totp/CareCompanion:x?secret=JBSWY3DPEHPK3PXP", qrSvg: "<svg xmlns='http://www.w3.org/2000/svg'/>" };
const staff = { mfaRequired: true, mfaEnrolled: false, mfaVerified: false };

describe("mfaStepFor", () => {
  it("requires nothing for non-staff, verified sessions, or an API without MFA (mfaVerified undefined)", () => {
    expect(mfaStepFor({ mfaRequired: false })).toBe("none");
    expect(mfaStepFor({ mfaRequired: true, mfaEnrolled: true, mfaVerified: true })).toBe("none");
    expect(mfaStepFor({ mfaRequired: true })).toBe("none");
    expect(mfaStepFor(null)).toBe("none");
  });
  it("enrolls when not enrolled and verifies when enrolled", () => {
    expect(mfaStepFor(staff)).toBe("enroll");
    expect(mfaStepFor({ ...staff, mfaEnrolled: true })).toBe("verify");
  });
});

describe("mfaReducer: not enrolled → enroll → recovery codes → verified", () => {
  it("walks the enrolment path and requires acknowledging the recovery codes", () => {
    let s: MfaState = initialMfaState(staff);
    expect(s).toEqual({ kind: "intro" });
    s = mfaReducer(s, { type: "ENROLL_STARTED", enrollment });
    expect(s).toEqual({ kind: "enroll", enrollment });
    // A VERIFIED event is not valid while enrolling.
    expect(mfaReducer(s, { type: "VERIFIED" })).toBe(s);
    s = mfaReducer(s, { type: "CONFIRMED", recoveryCodes: ["a1", "b2"] });
    expect(s).toEqual({ kind: "recovery", codes: ["a1", "b2"], acknowledged: false });
    // Cannot continue before acknowledging.
    expect(mfaReducer(s, { type: "CONTINUE" })).toBe(s);
    s = mfaReducer(s, { type: "ACKNOWLEDGE", value: true });
    s = mfaReducer(s, { type: "CONTINUE" });
    expect(s).toEqual({ kind: "done" });
  });

  it("switches to verification when enrolment answers CONFLICT (already enrolled)", () => {
    expect(mfaReducer({ kind: "intro" }, { type: "ALREADY_ENROLLED" })).toEqual({ kind: "verify", method: "totp" });
  });

  it("can restart an enrolment", () => {
    expect(mfaReducer({ kind: "enroll", enrollment }, { type: "RESTART" })).toEqual({ kind: "intro" });
  });
});

describe("mfaReducer: enrolled → verify", () => {
  it("verifies with TOTP or a recovery code", () => {
    let s = initialMfaState({ ...staff, mfaEnrolled: true });
    expect(s).toEqual({ kind: "verify", method: "totp" });
    s = mfaReducer(s, { type: "USE_METHOD", method: "recovery" });
    expect(s).toEqual({ kind: "verify", method: "recovery" });
    expect(mfaReducer(s, { type: "VERIFIED" })).toEqual({ kind: "done" });
  });
  it("starts done when no MFA step is needed", () => {
    expect(initialMfaState({ mfaRequired: true, mfaEnrolled: true, mfaVerified: true })).toEqual({ kind: "done" });
  });
});

describe("MFA_REQUIRED helpers", () => {
  it("marks the cached profile unverified", () => {
    expect(markMfaRequired({ mfaRequired: false, mfaVerified: true, mfaEnrolled: true })).toEqual({
      mfaRequired: true,
      mfaVerified: false,
      mfaEnrolled: true,
    });
  });
  it("builds a safe return path", () => {
    expect(mfaPath("/ops/tasks?x=1")).toBe("/mfa?next=%2Fops%2Ftasks%3Fx%3D1");
    expect(mfaPath("//evil.example")).toBe("/mfa");
    expect(mfaPath("/mfa")).toBe("/mfa");
    expect(mfaPath(null)).toBe("/mfa");
  });
});

describe("QR and secret rendering", () => {
  it("encodes SVG markup as a base64 data URI (never injected as HTML)", () => {
    const src = qrImageSrc(enrollment.qrSvg);
    expect(src.startsWith("data:image/svg+xml;base64,")).toBe(true);
    expect(atob(src.split(",")[1]!)).toBe(enrollment.qrSvg);
    expect(qrImageSrc("data:image/png;base64,AAA")).toBe("data:image/png;base64,AAA");
  });
  it("groups the manual key", () => {
    expect(formatSecret("JBSWY3DPEHPK3PXP")).toBe("JBSW Y3DP EHPK 3PXP");
  });
});

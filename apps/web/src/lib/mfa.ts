import type { Me, MfaEnrollResponse } from "@/lib/api/types";

/**
 * Staff MFA (contract §22) as a small, testable state machine.
 *
 *   not enrolled: intro → enroll (QR + secret) → recovery (codes shown once, must acknowledge) → done
 *   enrolled:     verify (TOTP code, or switch to a recovery code) → done
 *
 * `mfaVerified === undefined` means the API predates v1.1 (no MFA): no step is required.
 */
export type MfaStep = "none" | "enroll" | "verify";

export function mfaStepFor(user: Pick<Me, "mfaRequired" | "mfaEnrolled" | "mfaVerified"> | null | undefined): MfaStep {
  if (!user || !user.mfaRequired) return "none";
  if (user.mfaVerified !== false) return "none";
  return user.mfaEnrolled ? "verify" : "enroll";
}

export function needsMfa(user: Parameters<typeof mfaStepFor>[0]): boolean {
  return mfaStepFor(user) !== "none";
}

/** Applied when any request answers 403 MFA_REQUIRED: the cached profile is marked unverified. */
export function markMfaRequired<U extends Pick<Me, "mfaRequired" | "mfaVerified">>(user: U): U {
  return { ...user, mfaRequired: true, mfaVerified: false };
}

/** Where to send the user for the MFA step, keeping the page they were on. */
export function mfaPath(returnTo?: string | null): string {
  const safe = returnTo && returnTo.startsWith("/") && !returnTo.startsWith("//") && !returnTo.startsWith("/mfa") ? returnTo : null;
  return safe ? `/mfa?next=${encodeURIComponent(safe)}` : "/mfa";
}

export type MfaState =
  | { kind: "intro" }
  | { kind: "enroll"; enrollment: MfaEnrollResponse }
  | { kind: "recovery"; codes: string[]; acknowledged: boolean }
  | { kind: "verify"; method: "totp" | "recovery" }
  | { kind: "done" };

export type MfaEvent =
  | { type: "ENROLL_STARTED"; enrollment: MfaEnrollResponse }
  | { type: "ALREADY_ENROLLED" }
  | { type: "CONFIRMED"; recoveryCodes: string[] }
  | { type: "ACKNOWLEDGE"; value: boolean }
  | { type: "CONTINUE" }
  | { type: "VERIFIED" }
  | { type: "USE_METHOD"; method: "totp" | "recovery" }
  | { type: "RESTART" };

export function initialMfaState(user: Parameters<typeof mfaStepFor>[0]): MfaState {
  const step = mfaStepFor(user);
  if (step === "none") return { kind: "done" };
  return step === "verify" ? { kind: "verify", method: "totp" } : { kind: "intro" };
}

export function mfaReducer(state: MfaState, event: MfaEvent): MfaState {
  switch (event.type) {
    case "ENROLL_STARTED":
      return state.kind === "intro" || state.kind === "enroll" ? { kind: "enroll", enrollment: event.enrollment } : state;
    case "ALREADY_ENROLLED":
      // POST /enroll answered CONFLICT: the account already has TOTP, so verify instead.
      return state.kind === "intro" || state.kind === "enroll" ? { kind: "verify", method: "totp" } : state;
    case "CONFIRMED":
      return state.kind === "enroll" ? { kind: "recovery", codes: event.recoveryCodes, acknowledged: false } : state;
    case "ACKNOWLEDGE":
      return state.kind === "recovery" ? { ...state, acknowledged: event.value } : state;
    case "CONTINUE":
      // Recovery codes must be acknowledged before leaving; they are never shown again.
      return state.kind === "recovery" && state.acknowledged ? { kind: "done" } : state;
    case "VERIFIED":
      return state.kind === "verify" ? { kind: "done" } : state;
    case "USE_METHOD":
      return state.kind === "verify" ? { kind: "verify", method: event.method } : state;
    case "RESTART":
      return state.kind === "enroll" ? { kind: "intro" } : state;
    default:
      return state;
  }
}

/** QR SVG markup → data URI for an <img> (the SVG is never injected into the DOM). */
export function qrImageSrc(qrSvg: string): string {
  if (qrSvg.startsWith("data:image/")) return qrSvg;
  const bytes = new TextEncoder().encode(qrSvg);
  let bin = "";
  bytes.forEach((b) => (bin += String.fromCharCode(b)));
  return `data:image/svg+xml;base64,${btoa(bin)}`;
}

/** Group a base32 secret in blocks of 4 for manual entry. */
export function formatSecret(secret: string): string {
  return secret.replace(/\s+/g, "").replace(/(.{4})/g, "$1 ").trim();
}

export function recoveryCodesText(codes: string[], account: string, now: Date = new Date()): string {
  return [
    "CareCompanion staff portal: MFA recovery codes",
    `Account: ${account}`,
    `Generated: ${now.toISOString()}`,
    "",
    "Each code works once. Store them somewhere safe (a password manager) and do not share them.",
    "",
    ...codes,
    "",
  ].join("\n");
}

export const TOTP_CODE_RE = /^\d{6}$/;

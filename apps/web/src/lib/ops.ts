import type { HomeVisitStatus, OpsHomeVisit, OpsProvider } from "@/lib/api/types";
import { daysUntil } from "@/lib/format";

const ARRIVED_OR_LATER: HomeVisitStatus[] = ["arrived", "in_progress", "completed", "cancelled"];

/** Contract §18: a visit is late if it has not reached `arrived` by `preferredEnd`. */
export function isLate(v: Pick<OpsHomeVisit, "status" | "preferredEnd">, now: Date = new Date()): boolean {
  return !ARRIVED_OR_LATER.includes(v.status) && new Date(v.preferredEnd).getTime() < now.getTime();
}

/** Assignable = verified, on duty and credential not expired. */
export function providerAvailable(p: OpsProvider, now: Date = new Date()): boolean {
  const d = daysUntil(p.credentialExpiresAt, now);
  return p.verificationStatus === "verified" && p.onDuty && (d === null || d >= 0);
}

/** Credential expiry warning level. */
export function credentialWarning(p: Pick<OpsProvider, "credentialExpiresAt">, now: Date = new Date()): "expired" | "soon" | null {
  const d = daysUntil(p.credentialExpiresAt, now);
  if (d === null) return null;
  if (d < 0) return "expired";
  if (d <= 30) return "soon";
  return null;
}

/** §55: a plain OpenStreetMap link (no API key; no embedded map because the CSP allows no third-party frames). */
export function osmLink(lat: number, lng: number): string {
  const a = lat.toFixed(5);
  const o = lng.toFixed(5);
  return `https://www.openstreetmap.org/?mlat=${a}&mlon=${o}#map=16/${a}/${o}`;
}

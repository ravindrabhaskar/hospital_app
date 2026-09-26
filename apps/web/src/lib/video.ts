import type { ConsultMode } from "@/lib/api/types";

/** Contract §26: the room opens 10 min before startAt and closes 60 min after endAt. */
export const VIDEO_OPENS_BEFORE_MS = 10 * 60_000;
export const VIDEO_CLOSES_AFTER_MS = 60 * 60_000;

export function isRemoteMode(mode: ConsultMode): boolean {
  return mode === "video" || mode === "audio";
}

export interface VideoJoinWindow {
  phase: "before" | "open" | "closed";
  opensAt: Date;
  closesAt: Date;
  /** 0 once open */
  msUntilOpen: number;
}

/**
 * Where `now` sits relative to the join window. `serverOpensAt` (from a 409 `details.opensAt`)
 * overrides the computed opening time when the server says otherwise.
 */
export function videoJoinWindow(
  appt: { startAt: string; endAt: string },
  now: Date = new Date(),
  serverOpensAt?: string | null,
): VideoJoinWindow {
  const computed = new Date(new Date(appt.startAt).getTime() - VIDEO_OPENS_BEFORE_MS);
  const fromServer = serverOpensAt ? new Date(serverOpensAt) : null;
  const opensAt = fromServer && !Number.isNaN(fromServer.getTime()) ? fromServer : computed;
  const closesAt = new Date(new Date(appt.endAt).getTime() + VIDEO_CLOSES_AFTER_MS);
  const t = now.getTime();
  const phase = t < opensAt.getTime() ? "before" : t > closesAt.getTime() ? "closed" : "open";
  return { phase, opensAt, closesAt, msUntilOpen: Math.max(0, opensAt.getTime() - t) };
}

/** "2d 3h", "1h 05m", "4:07" */
export function formatCountdown(ms: number): string {
  const total = Math.max(0, Math.ceil(ms / 1000));
  const d = Math.floor(total / 86_400);
  const h = Math.floor((total % 86_400) / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  if (d > 0) return `${d}d ${h}h`;
  if (h > 0) return `${h}h ${String(m).padStart(2, "0")}m`;
  return `${m}:${String(s).padStart(2, "0")}`;
}

/** Only https URLs on the configured Jitsi host may be embedded (the CSP frame-src allows only that host). */
export function canEmbed(joinUrl: string, jitsiDomain: string): boolean {
  try {
    const u = new URL(joinUrl);
    return u.protocol === "https:" && u.host.toLowerCase() === jitsiDomain.toLowerCase();
  } catch {
    return false;
  }
}

/** Only http(s) join URLs are opened. */
export function isSafeJoinUrl(joinUrl: string): boolean {
  try {
    const u = new URL(joinUrl);
    return u.protocol === "https:" || u.protocol === "http:";
  } catch {
    return false;
  }
}

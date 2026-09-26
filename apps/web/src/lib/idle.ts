/** Staff session idle timeout: warn at 13 minutes, sign out at 15. */
export const IDLE_TIMEOUT_MS = 15 * 60_000;
export const IDLE_WARNING_MS = 13 * 60_000;

export type IdlePhase = "active" | "warning" | "expired";

export function idlePhase(lastActivityAt: number, now: number): IdlePhase {
  const idle = Math.max(0, now - lastActivityAt);
  if (idle >= IDLE_TIMEOUT_MS) return "expired";
  if (idle >= IDLE_WARNING_MS) return "warning";
  return "active";
}

export function secondsUntilTimeout(lastActivityAt: number, now: number): number {
  return Math.max(0, Math.ceil((lastActivityAt + IDLE_TIMEOUT_MS - now) / 1000));
}

const KEY = "cc.lastActivity.v1";

/** The last activity time survives a reload (per tab) so reloading cannot extend an idle session. */
export function readLastActivity(fallback: number): number {
  try {
    const raw = typeof window !== "undefined" ? window.sessionStorage.getItem(KEY) : null;
    const n = raw ? Number(raw) : NaN;
    return Number.isFinite(n) && n <= fallback ? n : fallback;
  } catch {
    return fallback;
  }
}

export function writeLastActivity(at: number) {
  try {
    window.sessionStorage.setItem(KEY, String(at));
  } catch {
    /* storage unavailable */
  }
}

export function clearLastActivity() {
  try {
    window.sessionStorage.removeItem(KEY);
  } catch {
    /* storage unavailable */
  }
}

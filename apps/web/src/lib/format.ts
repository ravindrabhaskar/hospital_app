export const TIME_ZONE = "Asia/Kolkata";

function toDate(v: string | number | Date | null | undefined): Date | null {
  if (v === null || v === undefined || v === "") return null;
  const d = v instanceof Date ? v : new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function formatDateTime(v: string | Date | null | undefined): string {
  const d = toDate(v);
  if (!d) return "—";
  return new Intl.DateTimeFormat("en-IN", {
    timeZone: TIME_ZONE,
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: true,
  }).format(d);
}

export function formatDate(v: string | Date | null | undefined): string {
  if (typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v)) {
    // Plain calendar date: do not shift it through a timezone.
    const [y, m, day] = v.split("-").map(Number);
    return new Intl.DateTimeFormat("en-IN", { day: "2-digit", month: "short", year: "numeric", timeZone: "UTC" }).format(
      new Date(Date.UTC(y ?? 1970, (m ?? 1) - 1, day ?? 1)),
    );
  }
  const d = toDate(v);
  if (!d) return "—";
  return new Intl.DateTimeFormat("en-IN", { timeZone: TIME_ZONE, day: "2-digit", month: "short", year: "numeric" }).format(d);
}

export function formatTime(v: string | Date | null | undefined): string {
  const d = toDate(v);
  if (!d) return "—";
  return new Intl.DateTimeFormat("en-IN", { timeZone: TIME_ZONE, hour: "2-digit", minute: "2-digit", hour12: true }).format(d);
}

/** Today's calendar date in Asia/Kolkata as YYYY-MM-DD. */
export function todayIST(now: Date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  return `${get("year")}-${get("month")}-${get("day")}`;
}

export function addDays(date: string, days: number): string {
  const [y, m, d] = date.split("-").map(Number);
  const dt = new Date(Date.UTC(y ?? 1970, (m ?? 1) - 1, (d ?? 1) + days));
  return dt.toISOString().slice(0, 10);
}

export function relativeTime(v: string | Date | null | undefined, now: Date = new Date()): string {
  const d = toDate(v);
  if (!d) return "—";
  const diff = Math.round((d.getTime() - now.getTime()) / 1000);
  const abs = Math.abs(diff);
  const rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
  if (abs < 60) return rtf.format(diff, "second");
  if (abs < 3600) return rtf.format(Math.round(diff / 60), "minute");
  if (abs < 86400) return rtf.format(Math.round(diff / 3600), "hour");
  return rtf.format(Math.round(diff / 86400), "day");
}

const inr = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 });
/** Amounts in the API are integer rupees. */
export function formatINR(amount: number | null | undefined): string {
  if (amount === null || amount === undefined) return "—";
  return inr.format(amount);
}

export function formatNumber(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return new Intl.NumberFormat("en-IN").format(n);
}

/** Rates: the contract does not state the scale; values ≤ 1 are treated as fractions. `null` = no data. */
export function formatPercent(rate: number | null | undefined): string {
  if (rate === null || rate === undefined) return "—";
  const pct = rate <= 1 ? rate * 100 : rate;
  return `${Math.round(pct)}%`;
}

export function humanize(s: string | null | undefined): string {
  if (!s) return "—";
  const t = s.replace(/_/g, " ").toLowerCase();
  return t.charAt(0).toUpperCase() + t.slice(1);
}

export function daysUntil(v: string | null | undefined, now: Date = new Date()): number | null {
  const d = toDate(v);
  if (!d) return null;
  return Math.floor((d.getTime() - now.getTime()) / 86400000);
}

/** Convert a `datetime-local` input value (interpreted as IST) to an ISO UTC string. */
export function istLocalToISO(local: string): string {
  // local = "YYYY-MM-DDTHH:mm"
  return new Date(`${local}:00+05:30`).toISOString();
}

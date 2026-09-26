/** India Standard Time helpers (no DST; fixed +05:30). */
export const IST_OFFSET_MIN = 330;

export const iso = (d: Date | null | undefined): string | null => (d ? d.toISOString() : null);

/** YYYY-MM-DD of the given instant in IST. */
export function istDate(d: Date = new Date()): string {
  return new Date(d.getTime() + IST_OFFSET_MIN * 60_000).toISOString().slice(0, 10);
}

/** UTC instant for an IST wall-clock date + HH:MM. */
export function istToUtc(date: string, hhmm: string): Date {
  const [h, m] = hhmm.split(':').map(Number);
  const [y, mo, d] = date.split('-').map(Number);
  return new Date(Date.UTC(y, mo - 1, d, h, m) - IST_OFFSET_MIN * 60_000);
}

export function istDayBounds(date: string): { start: Date; end: Date } {
  const start = istToUtc(date, '00:00');
  return { start, end: new Date(start.getTime() + 24 * 3600_000) };
}

export function addDays(date: string, days: number): string {
  const [y, mo, d] = date.split('-').map(Number);
  return new Date(Date.UTC(y, mo - 1, d + days)).toISOString().slice(0, 10);
}

export function ageFromDob(dob: string | null, now: Date = new Date()): number | null {
  if (!dob) return null;
  const [y, m, d] = dob.split('-').map(Number);
  const today = istDate(now).split('-').map(Number);
  let age = today[0] - y;
  if (today[1] < m || (today[1] === m && today[2] < d)) age--;
  return age;
}

export function minutesBetween(a: Date, b: Date): number {
  return (b.getTime() - a.getTime()) / 60_000;
}

export function median(values: number[]): number | null {
  if (!values.length) return null;
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  const v = s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
  return Math.round(v * 10) / 10;
}

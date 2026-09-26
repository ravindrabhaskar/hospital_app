import type { ConsultMode, SlotMins, Weekday, WeeklyBlock } from "@/lib/api/types";

/** 0 = Sunday, matching the contract (§29, IST). Displayed Monday-first. */
export const WEEKDAYS: { value: Weekday; short: string; long: string }[] = [
  { value: 1, short: "Mon", long: "Monday" },
  { value: 2, short: "Tue", long: "Tuesday" },
  { value: 3, short: "Wed", long: "Wednesday" },
  { value: 4, short: "Thu", long: "Thursday" },
  { value: 5, short: "Fri", long: "Friday" },
  { value: 6, short: "Sat", long: "Saturday" },
  { value: 0, short: "Sun", long: "Sunday" },
];

export const MODE_LABEL: Record<ConsultMode, string> = {
  video: "Video",
  audio: "Audio",
  chat: "Chat",
  in_clinic: "In clinic",
};

const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

/** "HH:MM" → minutes since midnight, or null when malformed. */
export function toMinutes(t: string): number | null {
  if (!TIME_RE.test(t)) return null;
  const [h, m] = t.split(":").map(Number);
  return (h ?? 0) * 60 + (m ?? 0);
}

/** Number of whole slots a block produces. */
export function slotCount(b: Pick<WeeklyBlock, "start" | "end" | "slotMins">): number {
  const s = toMinutes(b.start);
  const e = toMinutes(b.end);
  if (s === null || e === null || e <= s) return 0;
  return Math.floor((e - s) / b.slotMins);
}

/**
 * Client-side mirror of the server rule "overlapping blocks → VALIDATION_ERROR" plus basic shape checks.
 * Returns one message per invalid block, keyed by its index in `blocks`. Touching blocks (10:00–12:00 and
 * 12:00–13:00) do not overlap.
 */
export function validateWeekly(blocks: WeeklyBlock[]): Record<number, string> {
  const errors: Record<number, string> = {};
  blocks.forEach((b, i) => {
    const s = toMinutes(b.start);
    const e = toMinutes(b.end);
    if (s === null || e === null) errors[i] = "Enter start and end times (HH:MM)";
    else if (e <= s) errors[i] = "End time must be after the start time";
    else if (e - s < b.slotMins) errors[i] = `The block is shorter than one ${b.slotMins}-minute slot`;
    else if (b.modes.length === 0) errors[i] = "Choose at least one consultation mode";
  });
  for (let i = 0; i < blocks.length; i++) {
    for (let j = i + 1; j < blocks.length; j++) {
      const a = blocks[i]!;
      const b = blocks[j]!;
      if (a.weekday !== b.weekday) continue;
      const as = toMinutes(a.start);
      const ae = toMinutes(a.end);
      const bs = toMinutes(b.start);
      const be = toMinutes(b.end);
      if (as === null || ae === null || bs === null || be === null) continue;
      if (as < be && bs < ae) {
        const msg = `Overlaps another block on the same day (${a.start}–${a.end} and ${b.start}–${b.end})`;
        errors[i] ??= msg;
        errors[j] ??= msg;
      }
    }
  }
  return errors;
}

export function newBlock(weekday: Weekday, existing: WeeklyBlock[]): WeeklyBlock {
  // Start after the latest block of that day, else 09:00.
  const sameDay = existing.filter((b) => b.weekday === weekday);
  const lastEnd = sameDay.map((b) => toMinutes(b.end) ?? 0).reduce((m, x) => Math.max(m, x), 0);
  const start = sameDay.length ? Math.min(lastEnd + 60, 22 * 60) : 9 * 60;
  const end = Math.min(start + 4 * 60, 23 * 60 + 30);
  const fmt = (m: number) => `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
  return { weekday, start: fmt(start), end: fmt(end), slotMins: 30 as SlotMins, modes: ["video", "audio"] };
}

/** Stable order for display and for the PUT body: weekday Mon→Sun, then start time. */
export function sortBlocks(blocks: WeeklyBlock[]): WeeklyBlock[] {
  const order = (w: Weekday) => (w === 0 ? 7 : w);
  return [...blocks].sort((a, b) => order(a.weekday) - order(b.weekday) || a.start.localeCompare(b.start));
}

import type { Tone } from "@/components/ui";
import type { Ticket, TicketMessage, TicketPriority, TicketStatus } from "@/lib/api/types";

export const STATUS_TONE: Record<TicketStatus, Tone> = {
  open: "sky",
  pending_customer: "amber",
  resolved: "green",
  closed: "neutral",
};
export const PRIORITY_TONE: Record<TicketPriority, Tone> = { low: "neutral", normal: "sky", high: "amber", urgent: "red" };

/** Minutes → "3h 20m" / "45m" / "2d 4h". */
export function formatMins(totalMins: number): string {
  const m = Math.max(0, Math.round(totalMins));
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  if (h < 24) return m % 60 ? `${h}h ${m % 60}m` : `${h}h`;
  const d = Math.floor(h / 24);
  return h % 24 ? `${d}d ${h % 24}h` : `${d}d`;
}

/** An agent replied to the customer (internal notes do not count as a response). */
export function hasFirstResponse(messages: readonly TicketMessage[] | undefined): boolean {
  return !!messages?.some((m) => m.authorRole === "agent" && !m.internal);
}

export type SlaKind = "none" | "met" | "ok" | "soon" | "breached";
export interface SlaState {
  kind: SlaKind;
  label: string;
  tone: Tone;
  /** Minutes until due (negative when overdue); null when not applicable. */
  minsLeft: number | null;
}

/** Due within this many minutes is shown as "soon" (amber). */
export const SLA_SOON_MINS = 15;

/**
 * §61 first-response SLA badge. Resolved/closed tickets and tickets with an agent reply have no countdown.
 */
export function slaState(t: Pick<Ticket, "status" | "slaDueAt" | "messages">, now: Date = new Date()): SlaState {
  if (t.status === "resolved" || t.status === "closed") return { kind: "none", label: "Closed", tone: "neutral", minsLeft: null };
  if (hasFirstResponse(t.messages)) return { kind: "met", label: "Responded", tone: "green", minsLeft: null };
  if (!t.slaDueAt) return { kind: "none", label: "No SLA", tone: "neutral", minsLeft: null };
  const due = new Date(t.slaDueAt).getTime();
  if (Number.isNaN(due)) return { kind: "none", label: "No SLA", tone: "neutral", minsLeft: null };
  const minsLeft = (due - now.getTime()) / 60_000;
  if (minsLeft < 0) return { kind: "breached", label: `SLA breached ${formatMins(-minsLeft)} ago`, tone: "red", minsLeft };
  if (minsLeft <= SLA_SOON_MINS) return { kind: "soon", label: `Respond in ${formatMins(minsLeft)}`, tone: "amber", minsLeft };
  return { kind: "ok", label: `Respond in ${formatMins(minsLeft)}`, tone: "green", minsLeft };
}

/** Queue order: breached first, then soonest SLA, then urgent priority, then newest. */
export function sortQueue(tickets: readonly Ticket[], now: Date = new Date()): Ticket[] {
  const prio: Record<TicketPriority, number> = { urgent: 3, high: 2, normal: 1, low: 0 };
  const rank = (t: Ticket) => {
    const s = slaState(t, now);
    return s.kind === "breached" ? 0 : s.kind === "soon" ? 1 : s.kind === "ok" ? 2 : s.kind === "met" ? 3 : 4;
  };
  return [...tickets].sort((a, b) => {
    const r = rank(a) - rank(b);
    if (r) return r;
    const sa = slaState(a, now).minsLeft;
    const sb = slaState(b, now).minsLeft;
    if (sa !== null && sb !== null && sa !== sb) return sa - sb;
    const p = (prio[b.priority] ?? 0) - (prio[a.priority] ?? 0);
    if (p) return p;
    return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
  });
}

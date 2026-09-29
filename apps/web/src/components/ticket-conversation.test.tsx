import { describe, expect, it } from "vitest";
import { render, screen, within } from "@testing-library/react";
import type { Ticket, TicketMessage } from "@/lib/api/types";
import { slaState, sortQueue } from "@/lib/support";
import { INTERNAL_LABEL, TicketConversation } from "./ticket-conversation";

const msg = (p: Partial<TicketMessage>): TicketMessage => ({
  id: Math.random().toString(36),
  ticketId: "t1",
  authorName: "Ramesh",
  authorRole: "customer",
  text: "",
  internal: false,
  at: "2026-09-29T05:00:00.000Z",
  ...p,
});

describe("TicketConversation", () => {
  it("renders internal notes distinctly and labelled as not visible to the customer", () => {
    render(
      <TicketConversation
        messages={[
          msg({ text: "My refund has not arrived", at: "2026-09-29T05:00:00.000Z" }),
          msg({ authorName: "Support Desk", authorRole: "agent", text: "Checking with finance", internal: true, at: "2026-09-29T05:05:00.000Z" }),
          msg({ authorName: "Support Desk", authorRole: "agent", text: "We have raised it; 3–5 days.", at: "2026-09-29T05:10:00.000Z" }),
        ]}
      />,
    );
    const notes = screen.getAllByTestId("internal-note");
    expect(notes).toHaveLength(1);
    expect(within(notes[0]!).getByText(INTERNAL_LABEL)).toBeInTheDocument();
    expect(within(notes[0]!).getByText("Checking with finance")).toBeInTheDocument();
    expect(INTERNAL_LABEL).toBe("Internal, not visible to customer");
    const normal = screen.getAllByTestId("ticket-message");
    expect(normal).toHaveLength(2);
    normal.forEach((n) => expect(within(n).queryByText(INTERNAL_LABEL)).not.toBeInTheDocument());
    // Chronological order.
    expect(screen.getAllByRole("article").map((a) => a.textContent)).toEqual([
      expect.stringContaining("refund"),
      expect.stringContaining("finance"),
      expect.stringContaining("3–5 days"),
    ]);
  });

  it("shows an empty state", () => {
    render(<TicketConversation messages={[]} />);
    expect(screen.getByText("No messages yet.")).toBeInTheDocument();
  });
});

describe("support SLA", () => {
  const now = new Date("2026-09-29T06:00:00.000Z");
  const t = (p: Partial<Ticket>): Ticket => ({
    id: p.id ?? "t",
    number: "T-1",
    userId: "u",
    userName: "U",
    subject: "S",
    category: "other",
    status: "open",
    priority: "normal",
    assignedToName: null,
    refType: null,
    refId: null,
    messages: [],
    rating: null,
    slaDueAt: null,
    createdAt: "2026-09-29T05:00:00.000Z",
    updatedAt: "2026-09-29T05:00:00.000Z",
    ...p,
  });

  it("counts down, warns when close and flags breaches; internal notes do not stop the clock", () => {
    expect(slaState(t({ slaDueAt: "2026-09-29T08:30:00.000Z" }), now)).toMatchObject({ kind: "ok", label: "Respond in 2h 30m" });
    expect(slaState(t({ slaDueAt: "2026-09-29T06:10:00.000Z" }), now)).toMatchObject({ kind: "soon", tone: "amber" });
    expect(slaState(t({ slaDueAt: "2026-09-29T05:45:00.000Z" }), now)).toMatchObject({ kind: "breached", label: "SLA breached 15m ago", tone: "red" });
    const noted = t({ slaDueAt: "2026-09-29T05:45:00.000Z", messages: [msg({ authorRole: "agent", internal: true })] });
    expect(slaState(noted, now).kind).toBe("breached");
    expect(slaState(t({ slaDueAt: "2026-09-29T05:45:00.000Z", messages: [msg({ authorRole: "agent" })] }), now).kind).toBe("met");
    expect(slaState(t({ status: "resolved", slaDueAt: "2026-09-29T05:45:00.000Z" }), now).kind).toBe("none");
  });

  it("orders the queue breached first, then by time left", () => {
    const a = t({ id: "a", slaDueAt: "2026-09-29T09:00:00.000Z" });
    const b = t({ id: "b", slaDueAt: "2026-09-29T05:00:00.000Z" });
    const c = t({ id: "c", slaDueAt: "2026-09-29T07:00:00.000Z" });
    expect(sortQueue([a, b, c], now).map((x) => x.id)).toEqual(["b", "c", "a"]);
  });
});

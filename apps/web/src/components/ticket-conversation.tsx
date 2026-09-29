"use client";

import { Lock, UserRound, Headset, Info } from "lucide-react";
import type { TicketMessage } from "@/lib/api/types";
import { formatDateTime } from "@/lib/format";
import { cx } from "./ui";

export const INTERNAL_LABEL = "Internal, not visible to customer";

/** §61 ticket conversation. Internal notes are visually distinct (amber, dashed, lock icon) and labelled. */
export function TicketConversation({ messages }: { messages: TicketMessage[] }) {
  if (messages.length === 0) return <p className="py-6 text-center text-sm text-ink-muted">No messages yet.</p>;
  const sorted = [...messages].sort((a, b) => new Date(a.at).getTime() - new Date(b.at).getTime());
  return (
    <ol className="flex flex-col gap-3" aria-label="Ticket conversation">
      {sorted.map((m) => (
        <li key={m.id} data-testid={m.internal ? "internal-note" : "ticket-message"} className={cx("flex", m.authorRole === "customer" ? "justify-start" : m.authorRole === "system" ? "justify-center" : "justify-end")}>
          {m.authorRole === "system" && !m.internal ? (
            <p className="flex max-w-[90%] items-center gap-1.5 rounded-full bg-mint-50 px-3 py-1 text-xs text-ink-muted">
              <Info className="size-3.5" aria-hidden /> {m.text} · {formatDateTime(m.at)}
            </p>
          ) : m.internal ? (
            <article aria-label={`Internal note from ${m.authorName}`} className="w-full max-w-[85%] rounded-2xl border-2 border-dashed border-[#f2a23a] bg-peach-bg p-3">
              <p className="mb-1 flex flex-wrap items-center gap-1.5 text-xs font-semibold uppercase tracking-wide text-peach-fg">
                <Lock className="size-3.5" aria-hidden /> {INTERNAL_LABEL}
              </p>
              <p className="whitespace-pre-line text-sm text-ink">{m.text}</p>
              <p className="mt-1 text-[11px] text-peach-fg">
                {m.authorName} · {formatDateTime(m.at)}
              </p>
            </article>
          ) : (
            <article
              aria-label={`${m.authorRole === "customer" ? "Customer" : "Agent"} message from ${m.authorName}`}
              className={cx(
                "max-w-[85%] rounded-2xl p-3",
                m.authorRole === "customer" ? "rounded-bl-md border border-line bg-white" : "rounded-br-md bg-primary text-white",
              )}
            >
              <p className={cx("mb-1 flex items-center gap-1.5 text-xs font-semibold", m.authorRole === "customer" ? "text-ink-muted" : "text-white/80")}>
                {m.authorRole === "customer" ? <UserRound className="size-3.5" aria-hidden /> : <Headset className="size-3.5" aria-hidden />}
                {m.authorName}
              </p>
              <p className="whitespace-pre-line text-sm">{m.text}</p>
              <p className={cx("mt-1 text-[11px]", m.authorRole === "customer" ? "text-ink-muted" : "text-white/70")}>{formatDateTime(m.at)}</p>
            </article>
          )}
        </li>
      ))}
    </ol>
  );
}

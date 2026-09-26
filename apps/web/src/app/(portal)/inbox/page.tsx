"use client";

import { Suspense, useCallback } from "react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, ArrowRight, MessagesSquare } from "lucide-react";
import { api } from "@/lib/api";
import type { InboxThread } from "@/lib/api/types";
import { useAuth } from "@/lib/auth";
import { formatDateTime, relativeTime } from "@/lib/format";
import { OPS_ROLES, hasAnyRole } from "@/lib/roles";
import { MessageThread } from "@/components/message-thread";
import { Card, EmptyState, LoadingState, PageHeader, QueryView, cx } from "@/components/ui";

export default function InboxPage() {
  return (
    <>
      <PageHeader title="Inbox" description="Secure care-team messages, one thread per care episode." />
      <Suspense fallback={<LoadingState label="Loading inbox…" />}>
        <InboxView />
      </Suspense>
    </>
  );
}

function InboxView() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const selectedId = params.get("episode");

  const query = useQuery({
    queryKey: ["inbox"],
    queryFn: () => api.messages.inbox({ limit: 100 }),
    refetchInterval: 30_000,
  });

  const select = useCallback(
    (id: string | null) => {
      const next = new URLSearchParams(params.toString());
      if (id) next.set("episode", id);
      else next.delete("episode");
      const qs = next.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [params, router, pathname],
  );

  const selected = query.data?.items.find((t) => t.careEpisodeId === selectedId) ?? null;

  return (
    <div className="grid gap-5 lg:grid-cols-[minmax(280px,360px)_minmax(0,1fr)]">
      <Card title="Threads" className={cx(selectedId && "hidden lg:block")} bodyClassName="p-0">
        <QueryView
          query={query}
          isEmpty={(d) => d.items.length === 0}
          empty={
            <EmptyState
              icon={<MessagesSquare className="size-6" />}
              title="No conversations yet"
              description="Threads appear here when you are part of a patient's care episode."
            />
          }
        >
          {(d) => (
            <ul className="flex max-h-[calc(100vh-12rem)] flex-col overflow-y-auto" aria-label="Message threads">
              {d.items.map((t) => (
                <li key={t.careEpisodeId}>
                  <ThreadRow thread={t} active={t.careEpisodeId === selectedId} onSelect={() => select(t.careEpisodeId)} />
                </li>
              ))}
            </ul>
          )}
        </QueryView>
      </Card>

      <section aria-label="Conversation" className={cx(!selectedId && "hidden lg:block")}>
        {selectedId ? (
          <div className="flex flex-col overflow-hidden rounded-[20px] border border-line bg-surface shadow-[var(--shadow-card)]">
            <ThreadHeader thread={selected} onBack={() => select(null)} />
            <MessageThread
              key={selectedId}
              careEpisodeId={selectedId}
              patientId={selected?.patientId}
              className="h-[calc(100vh-16rem)]"
            />
          </div>
        ) : (
          <Card title="Conversation">
            <EmptyState title="Select a thread" description="Choose a conversation on the left to read and reply." />
          </Card>
        )}
      </section>
    </div>
  );
}

function ThreadRow({ thread: t, active, onSelect }: { thread: InboxThread; active: boolean; onSelect: () => void }) {
  const unread = t.unread > 0;
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-current={active ? "true" : undefined}
      className={cx(
        "flex w-full flex-col gap-0.5 border-b border-line px-4 py-3 text-left focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-primary-light",
        active ? "bg-mint-50" : "hover:bg-mint-50/60",
      )}
    >
      <span className="flex items-center justify-between gap-2">
        <span className={cx("truncate text-sm", unread ? "font-bold text-ink" : "font-semibold text-ink")}>{t.patientName}</span>
        <span className="shrink-0 text-xs text-ink-muted" title={t.lastAt ? formatDateTime(t.lastAt) : undefined}>
          {t.lastAt ? relativeTime(t.lastAt) : ""}
        </span>
      </span>
      <span className="truncate text-xs text-ink-muted">{t.title}</span>
      <span className="flex items-center justify-between gap-2">
        <span className={cx("truncate text-[13px]", unread ? "font-semibold text-ink" : "text-ink-muted")}>
          {t.lastMessage ? (
            <>
              {t.lastSenderName ? `${t.lastSenderName}: ` : ""}
              {t.lastMessage}
            </>
          ) : (
            <em>No messages yet</em>
          )}
        </span>
        {unread && (
          <span className="shrink-0 rounded-full bg-primary px-2 py-0.5 text-xs font-semibold tabular-nums text-white">
            {t.unread}
            <span className="sr-only"> unread</span>
          </span>
        )}
      </span>
    </button>
  );
}

function ThreadHeader({ thread, onBack }: { thread: InboxThread | null; onBack: () => void }) {
  const { roles } = useAuth();
  const isDoctor = roles.includes("doctor");
  const isOps = hasAnyRole(roles, OPS_ROLES);
  return (
    <header className="flex flex-wrap items-center justify-between gap-2 border-b border-line px-4 py-3">
      <div className="flex min-w-0 items-center gap-2">
        <button
          type="button"
          onClick={onBack}
          aria-label="Back to threads"
          className="rounded-full p-1.5 text-ink-muted hover:bg-mint-50 lg:hidden"
        >
          <ArrowLeft className="size-5" aria-hidden />
        </button>
        <div className="min-w-0">
          <h2 className="truncate text-base font-semibold text-ink">{thread?.patientName ?? "Conversation"}</h2>
          {thread && <p className="truncate text-xs text-ink-muted">{thread.title}</p>}
        </div>
      </div>
      {thread && (
        <div className="flex flex-wrap gap-2">
          {isDoctor && (
            <Link
              href={`/clinician/patients/${encodeURIComponent(thread.patientId)}`}
              className="inline-flex items-center gap-1 text-sm font-semibold text-primary hover:underline"
            >
              Open patient record <ArrowRight className="size-3.5" aria-hidden />
            </Link>
          )}
          {isOps && (
            <Link
              href={`/coordinator?patient=${encodeURIComponent(thread.patientId)}`}
              className="inline-flex items-center gap-1 text-sm font-semibold text-primary hover:underline"
            >
              Open in coordinator workspace <ArrowRight className="size-3.5" aria-hidden />
            </Link>
          )}
        </div>
      )}
    </header>
  );
}

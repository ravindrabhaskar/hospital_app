"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { EpisodeEvent } from "@/lib/api/types";
import { formatDateTime, humanize } from "@/lib/format";
import { EpisodeStatusBadge, PriorityBadge } from "./status";
import { Card, EmptyState, QueryView } from "./ui";

export function EventList({ events, compact }: { events: EpisodeEvent[]; compact?: boolean }) {
  const sorted = [...events].sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  if (sorted.length === 0) return <EmptyState title="No events yet" />;
  return (
    <ol className="relative flex flex-col gap-4 border-l-2 border-mint-100 pl-4" aria-label="Episode events, newest first">
      {sorted.map((e) => (
        <li key={e.id} className="relative">
          <span
            className={
              "absolute -left-[23px] top-1 size-3 rounded-full border-2 border-white " +
              (e.type === "escalated" ? "bg-danger" : "bg-primary-light")
            }
            aria-hidden
          />
          <p className="text-[13px] font-semibold text-ink">{humanize(e.type)}</p>
          {!compact || e.description ? <p className="text-[13px] text-ink">{e.description}</p> : null}
          <p className="text-xs text-ink-muted">
            {formatDateTime(e.createdAt)}
            {e.actorName ? ` · ${e.actorName}` : ""}
            {e.actorRole ? ` (${humanize(e.actorRole)})` : ""}
          </p>
        </li>
      ))}
    </ol>
  );
}

/** Loads GET /care-episodes/:id and renders its append-only event timeline. */
export function EpisodeTimelineCard({ episodeId, className }: { episodeId: string; className?: string }) {
  const query = useQuery({ queryKey: ["episode", episodeId], queryFn: () => api.episodes.get(episodeId) });
  return (
    <Card
      className={className}
      title="Episode timeline"
      subtitle={query.data ? query.data.title : undefined}
      actions={
        query.data ? (
          <div className="flex gap-1.5">
            <PriorityBadge priority={query.data.priority} />
            <EpisodeStatusBadge status={query.data.status} />
          </div>
        ) : null
      }
    >
      <QueryView query={query}>
        {(ep) => (
          <div className="flex flex-col gap-4">
            {ep.nextAction && (
              <p className="rounded-xl bg-mint-50 px-3 py-2 text-[13px]">
                <span className="font-semibold">Next action:</span> {ep.nextAction}
              </p>
            )}
            <EventList events={ep.events} />
          </div>
        )}
      </QueryView>
    </Card>
  );
}

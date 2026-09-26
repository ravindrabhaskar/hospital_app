"use client";

import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { ExternalLink, MonitorPlay, Video, X } from "lucide-react";
import { api } from "@/lib/api";
import { ApiError } from "@/lib/api/http";
import type { Appointment } from "@/lib/api/types";
import { publicEnv } from "@/lib/env";
import { formatTime } from "@/lib/format";
import { canEmbed, formatCountdown, isRemoteMode, isSafeJoinUrl, videoJoinWindow } from "@/lib/video";
import { Button, cx, errorMessage } from "./ui";

function useNow(intervalMs = 1000) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), intervalMs);
    return () => window.clearInterval(id);
  }, [intervalMs]);
  return now;
}

const linkCls =
  "inline-flex h-11 items-center justify-center gap-2 rounded-[28px] bg-primary px-5 text-sm font-semibold text-white hover:bg-primary-dark";

/**
 * Contract §26. The session is fetched only inside the join window; the call opens in a new tab
 * (a real link, so popup blockers never interfere). Embedding is offered for the configured Jitsi host.
 */
export function VideoJoinPanel({ appt }: { appt: Appointment }) {
  const now = useNow();
  const [serverOpensAt, setServerOpensAt] = useState<string | null>(null);
  const [embedded, setEmbedded] = useState(false);
  const win = videoJoinWindow(appt, now, serverOpensAt);
  const blocked = appt.status === "cancelled" || appt.status === "no_show" || appt.status === "pending_payment";
  const eligible = isRemoteMode(appt.mode) && !blocked;

  const session = useQuery({
    queryKey: ["video-session", appt.id],
    queryFn: () => api.appointments.videoSession(appt.id),
    enabled: eligible && win.phase === "open",
    retry: false,
    staleTime: 60_000,
  });

  const err = session.error;
  const conflictOpensAt =
    err instanceof ApiError && err.status === 409 && typeof err.details.opensAt === "string" ? err.details.opensAt : null;
  useEffect(() => {
    if (conflictOpensAt) setServerOpensAt(conflictOpensAt);
  }, [conflictOpensAt]);

  if (!isRemoteMode(appt.mode)) return null;

  const data = session.data;
  const joinUrl = data && isSafeJoinUrl(data.joinUrl) ? data.joinUrl : null;
  const embeddable = !!joinUrl && data?.provider === "jitsi" && canEmbed(joinUrl, publicEnv.jitsiDomain);

  return (
    <section aria-labelledby="video-heading" className="rounded-[20px] border border-line bg-surface p-5 shadow-[var(--shadow-card)]">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 id="video-heading" className="flex items-center gap-2 text-base font-semibold">
            <Video className="size-5 text-primary" aria-hidden /> {appt.mode === "audio" ? "Audio call" : "Video call"}
          </h2>
          <p className="text-xs text-ink-muted" aria-live="polite">
            {blocked
              ? "This appointment is not active, so the call is unavailable."
              : win.phase === "before"
                ? `Opens in ${formatCountdown(win.msUntilOpen)} (at ${formatTime(win.opensAt.toISOString())} IST)`
                : win.phase === "open"
                  ? `Open until ${formatTime(win.closesAt.toISOString())} IST`
                  : "The call window has closed."}
            {appt.mode === "audio" && !blocked && " · Same room with the camera off."}
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          {win.phase === "open" && joinUrl ? (
            <>
              <a href={joinUrl} target="_blank" rel="noopener noreferrer" className={linkCls}>
                <ExternalLink className="size-4" aria-hidden /> Join video call
              </a>
              {embeddable && (
                <Button variant="secondary" onClick={() => setEmbedded((v) => !v)} icon={embedded ? <X className="size-4" aria-hidden /> : <MonitorPlay className="size-4" aria-hidden />}>
                  {embedded ? "Close embedded call" : "Open in this page"}
                </Button>
              )}
            </>
          ) : (
            <Button disabled loading={eligible && win.phase === "open" && session.isFetching} icon={<Video className="size-4" aria-hidden />}>
              Join video call
            </Button>
          )}
        </div>
      </div>

      {data?.provider === "placeholder" && (
        <p className="mt-3 rounded-xl bg-peach-bg px-3 py-2 text-xs text-peach-fg">
          The video provider is a placeholder on this server; the link does not start a real call.
        </p>
      )}
      {err && !conflictOpensAt && (
        <p role="alert" className="mt-3 rounded-xl bg-rose-bg px-3 py-2 text-xs text-danger-dark">
          {errorMessage(err)}{" "}
          <button type="button" className="font-semibold underline" onClick={() => void session.refetch()}>
            Try again
          </button>
        </p>
      )}
      {embedded && embeddable && joinUrl && (
        <div className={cx("mt-4 overflow-hidden rounded-xl border border-line bg-ink")}>
          <iframe
            src={joinUrl}
            title="Video consultation"
            allow="camera; microphone; fullscreen; display-capture"
            allowFullScreen
            referrerPolicy="no-referrer"
            className="aspect-video w-full"
          />
        </div>
      )}
    </section>
  );
}

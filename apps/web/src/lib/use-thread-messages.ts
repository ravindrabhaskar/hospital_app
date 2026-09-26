"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { ChatMessage } from "@/lib/api/types";

export const THREAD_POLL_MS = 10_000;

type Fetcher = (careEpisodeId: string, after?: string) => Promise<{ items: ChatMessage[] }>;

export interface ThreadState {
  messages: ChatMessage[];
  status: "loading" | "ready" | "error";
  error: unknown;
  /** Fetch new messages now (also used after sending). */
  refresh: () => Promise<void>;
  /** Add a message returned by POST (deduplicated against later polls). */
  append: (m: ChatMessage) => void;
}

/** Merge by id and keep oldest → newest. */
export function mergeMessages(current: ChatMessage[], incoming: ChatMessage[]): ChatMessage[] {
  if (incoming.length === 0) return current;
  const byId = new Map(current.map((m) => [m.id, m]));
  for (const m of incoming) byId.set(m.id, m);
  return [...byId.values()].sort((a, b) => a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id));
}

/**
 * §34 thread loader: loads the thread once, then polls every 10 s with `?after=<last id>` while mounted
 * (and while the tab is visible). A poll failure keeps the messages already shown.
 */
export function useThreadMessages(
  careEpisodeId: string | null,
  opts: { fetcher: Fetcher; intervalMs?: number; onNewMessages?: (added: ChatMessage[]) => void },
): ThreadState {
  const { fetcher, intervalMs = THREAD_POLL_MS } = opts;
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [status, setStatus] = useState<ThreadState["status"]>("loading");
  const [error, setError] = useState<unknown>(null);
  const lastIdRef = useRef<string | undefined>(undefined);
  const inFlight = useRef(false);
  const epRef = useRef(careEpisodeId);
  const onNewRef = useRef(opts.onNewMessages);
  useEffect(() => {
    onNewRef.current = opts.onNewMessages;
  });

  const apply = useCallback((incoming: ChatMessage[]) => {
    if (incoming.length === 0) return;
    setMessages((cur) => {
      const merged = mergeMessages(cur, incoming);
      lastIdRef.current = merged[merged.length - 1]?.id;
      return merged;
    });
  }, []);

  const poll = useCallback(async () => {
    const ep = epRef.current;
    if (!ep || inFlight.current) return;
    inFlight.current = true;
    try {
      const res = await fetcher(ep, lastIdRef.current);
      if (epRef.current !== ep) return; // thread switched while loading
      apply(res.items);
      if (res.items.length) onNewRef.current?.(res.items);
      setStatus("ready");
      setError(null);
    } catch (e) {
      if (epRef.current !== ep) return;
      setError(e);
      setStatus((s) => (s === "ready" ? "ready" : "error"));
    } finally {
      inFlight.current = false;
    }
  }, [fetcher, apply]);

  useEffect(() => {
    epRef.current = careEpisodeId;
    lastIdRef.current = undefined;
    inFlight.current = false;
    setMessages([]);
    setError(null);
    setStatus("loading");
    if (!careEpisodeId) return;
    void poll();
    const id = window.setInterval(() => {
      if (typeof document !== "undefined" && document.visibilityState === "hidden") return;
      void poll();
    }, intervalMs);
    return () => window.clearInterval(id);
  }, [careEpisodeId, intervalMs, poll]);

  const append = useCallback((m: ChatMessage) => apply([m]), [apply]);

  return { messages, status, error, refresh: poll, append };
}

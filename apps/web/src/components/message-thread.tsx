"use client";

import { useCallback, useEffect, useId, useMemo, useRef, useState, type KeyboardEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, MessageSquare, Paperclip, Send, Siren, WifiOff } from "lucide-react";
import { api } from "@/lib/api";
import type { ChatMessage, MessageSenderRole } from "@/lib/api/types";
import { useAuth } from "@/lib/auth";
import { formatDate, formatDateTime, formatTime } from "@/lib/format";
import { useThreadMessages } from "@/lib/use-thread-messages";
import { OpenOriginalButton } from "./record-file";
import { useToast } from "./toast";
import { Button, EmptyState, ErrorState, LoadingState, Select, cx } from "./ui";

export const MESSAGE_MAX = 2000;

const ROLE_LABEL: Record<MessageSenderRole, string> = {
  patient: "Patient",
  family: "Family",
  doctor: "Doctor",
  coordinator: "Coordinator",
  care_team: "Care team",
  system: "System",
};

/** The emergency template (call 108) is marked by the server with kind `emergency_notice`. */
function isEmergencySystem(m: ChatMessage) {
  if (m.kind) return m.kind === "emergency_notice";
  return m.senderRole === "system" && /\b108\b|emergency/i.test(m.text); // older servers without `kind`
}

/**
 * §34 care-team thread for one Care Episode: loads, polls every 10 s, marks read, and sends.
 * ops_admin / super_admin messages appear to others as "Care team".
 */
export function MessageThread({ careEpisodeId, patientId, className }: { careEpisodeId: string; patientId?: string; className?: string }) {
  const { user } = useAuth();
  const qc = useQueryClient();
  const toast = useToast();
  const logRef = useRef<HTMLDivElement>(null);
  const textId = useId();
  const counterId = useId();
  const [text, setText] = useState("");
  const [attachment, setAttachment] = useState("");

  const markRead = useCallback(
    (ep: string) => {
      api.messages
        .markRead(ep)
        .then(() => qc.invalidateQueries({ queryKey: ["inbox"] }))
        .catch(() => {
          /* marking read is best-effort */
        });
    },
    [qc],
  );

  const onNewMessages = useCallback(() => markRead(careEpisodeId), [markRead, careEpisodeId]);
  const thread = useThreadMessages(careEpisodeId, { fetcher: api.messages.list, onNewMessages });
  const { messages, status, error } = thread;

  // Mark read when the thread is opened.
  useEffect(() => {
    markRead(careEpisodeId);
  }, [careEpisodeId, markRead]);

  // Reset the composer when switching threads.
  useEffect(() => {
    setText("");
    setAttachment("");
  }, [careEpisodeId]);

  // Keep the newest message in view.
  const lastId = messages[messages.length - 1]?.id;
  useEffect(() => {
    const el = logRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [lastId]);

  const records = useQuery({
    queryKey: ["records", patientId, "attachable"],
    queryFn: () => api.records.list({ patientId: patientId!, limit: 50 }),
    enabled: !!patientId,
  });
  const recordTitles = useMemo(() => new Map((records.data?.items ?? []).map((r) => [r.id, r.title])), [records.data]);

  const send = useMutation({
    mutationFn: (input: { text: string; attachmentRecordId?: string }) => api.messages.send(careEpisodeId, input),
    onSuccess: (m) => {
      thread.append(m);
      setText("");
      setAttachment("");
      void qc.invalidateQueries({ queryKey: ["inbox"] });
    },
    onError: (err) => toast.apiError(err, "Message not sent"),
  });

  const trimmed = text.trim();
  const tooLong = text.length > MESSAGE_MAX;
  const canSend = trimmed.length > 0 && !tooLong && !send.isPending;

  const submit = () => {
    if (!canSend) return;
    send.mutate({ text: trimmed, attachmentRecordId: attachment || undefined });
  };

  const onKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
      e.preventDefault();
      submit();
    }
  };

  return (
    <div className={cx("flex min-h-[420px] flex-col", className)}>
      {status === "ready" && error ? (
        <p role="status" className="flex items-center gap-2 border-b border-line bg-peach-bg px-4 py-1.5 text-xs text-peach-fg">
          <WifiOff className="size-3.5" aria-hidden />
          Couldn&apos;t check for new messages. Retrying automatically…
        </p>
      ) : null}

      <div
        ref={logRef}
        role="log"
        aria-live="polite"
        aria-label="Messages"
        tabIndex={0}
        className="min-h-0 flex-1 overflow-y-auto px-4 py-3 focus:outline-none focus-visible:outline-2 focus-visible:outline-primary-light"
      >
        {status === "loading" ? (
          <LoadingState label="Loading messages…" rows={3} />
        ) : status === "error" ? (
          <ErrorState error={error} onRetry={() => void thread.refresh()} />
        ) : messages.length === 0 ? (
          <EmptyState
            icon={<MessageSquare className="size-6" />}
            title="No messages yet — start the conversation"
            description="Messages are shared with the patient, their family and the care team on this episode."
          />
        ) : (
          <ol className="flex flex-col gap-3">
            {messages.map((m, i) => {
              const prev = messages[i - 1];
              const newDay = !prev || formatDate(prev.createdAt) !== formatDate(m.createdAt);
              return (
                <li key={m.id} className="flex flex-col">
                  {newDay && (
                    <p className="my-1 text-center text-[11px] font-medium uppercase tracking-wide text-ink-muted">{formatDate(m.createdAt)}</p>
                  )}
                  <MessageBubble m={m} own={!!user && m.senderUserId === user.id} attachmentTitle={m.attachmentRecordId ? recordTitles.get(m.attachmentRecordId) : undefined} />
                </li>
              );
            })}
          </ol>
        )}
      </div>

      <form
        className="flex flex-col gap-2 border-t border-line px-4 py-3"
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
      >
        <label htmlFor={textId} className="sr-only">
          Message
        </label>
        <textarea
          id={textId}
          rows={2}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={onKeyDown}
          maxLength={MESSAGE_MAX + 200}
          aria-describedby={counterId}
          aria-invalid={tooLong || undefined}
          placeholder="Write a message… (Enter to send, Shift+Enter for a new line)"
          className="w-full resize-y rounded-xl border border-line bg-white px-3.5 py-2 text-sm text-ink placeholder:text-ink-muted/70 focus:border-primary-light focus:outline-none focus-visible:outline-2 focus-visible:outline-primary-light aria-[invalid=true]:border-danger"
        />
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex min-w-0 flex-wrap items-center gap-2">
            {patientId && (
              <label className="flex min-w-0 items-center gap-1.5 text-xs text-ink-muted">
                <Paperclip className="size-4 shrink-0" aria-hidden />
                <span className="sr-only">Attach a record</span>
                <Select
                  value={attachment}
                  onChange={(e) => setAttachment(e.target.value)}
                  disabled={records.isPending || records.isError}
                  className="h-9 max-w-[16rem] text-xs"
                >
                  <option value="">
                    {records.isPending ? "Loading records…" : records.isError ? "Records unavailable" : "No attachment"}
                  </option>
                  {(records.data?.items ?? []).map((r) => (
                    <option key={r.id} value={r.id}>
                      {r.title} · {formatDate(r.recordDate)}
                    </option>
                  ))}
                </Select>
              </label>
            )}
            <span id={counterId} className={cx("text-xs tabular-nums", tooLong ? "text-danger-dark" : "text-ink-muted")}>
              {text.length}/{MESSAGE_MAX}
              {tooLong ? " — too long" : ""}
            </span>
          </div>
          <Button type="submit" size="sm" disabled={!canSend} loading={send.isPending} icon={<Send className="size-4" aria-hidden />}>
            Send
          </Button>
        </div>
      </form>
    </div>
  );
}

function MessageBubble({ m, own, attachmentTitle }: { m: ChatMessage; own: boolean; attachmentTitle?: string }) {
  const time = (
    <time dateTime={m.createdAt} title={formatDateTime(m.createdAt)} className="text-[11px] opacity-80">
      {formatTime(m.createdAt)}
    </time>
  );

  if (m.senderRole === "system") {
    const emergency = isEmergencySystem(m);
    const Icon = emergency ? Siren : AlertTriangle;
    return (
      <div
        role={emergency ? "alert" : undefined}
        className={cx(
          "mx-auto flex max-w-[90%] items-start gap-2 rounded-2xl border px-3.5 py-2.5 text-center text-sm",
          emergency ? "border-[#f6c9c9] bg-rose-bg text-danger-dark" : "border-[#f8d9b5] bg-peach-bg text-peach-fg",
        )}
      >
        <Icon className="mt-0.5 size-4 shrink-0" aria-hidden />
        <div className="min-w-0 text-left">
          <p className="text-xs font-semibold uppercase tracking-wide">{emergency ? "Safety alert" : "System message"}</p>
          <p className="whitespace-pre-wrap break-words">{m.text}</p>
          <p className="mt-0.5">{time}</p>
        </div>
      </div>
    );
  }

  return (
    <div className={cx("flex max-w-[85%] flex-col gap-0.5", own ? "self-end items-end" : "self-start items-start")}>
      {!own && (
        <p className="px-1 text-xs text-ink-muted">
          <span className="font-semibold text-ink">{m.senderName}</span> · {ROLE_LABEL[m.senderRole] ?? m.senderRole}
        </p>
      )}
      <div
        className={cx(
          "rounded-2xl px-3.5 py-2 text-sm",
          own ? "rounded-br-md bg-primary text-white" : "rounded-bl-md border border-line bg-mint-50 text-ink",
        )}
      >
        {own && <span className="sr-only">You: </span>}
        <p className="whitespace-pre-wrap break-words">{m.text}</p>
        {m.attachmentRecordId && (
          <div className={cx("mt-2 flex flex-wrap items-center gap-2 rounded-xl px-2 py-1.5", own ? "bg-white/15" : "bg-white")}>
            <Paperclip className="size-4 shrink-0" aria-hidden />
            <span className="text-xs font-medium">{attachmentTitle ?? "Attached record"}</span>
            <OpenOriginalButton recordId={m.attachmentRecordId} label="Open attachment" fileName={attachmentTitle} />
          </div>
        )}
        <p className="mt-0.5 text-right">{time}</p>
      </div>
    </div>
  );
}

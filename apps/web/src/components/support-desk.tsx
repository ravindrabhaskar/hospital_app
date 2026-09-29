"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, Clock, Headset, Inbox, Lock, MessageSquareReply, Send, Smile, Star, UserCheck } from "lucide-react";
import { api } from "@/lib/api";
import { TICKET_PRIORITIES, TICKET_STATUSES, type Ticket, type TicketPriority, type TicketStatus } from "@/lib/api/types";
import { useAuth } from "@/lib/auth";
import { formatDateTime, humanize, relativeTime } from "@/lib/format";
import { isSuperAdmin } from "@/lib/roles";
import { PRIORITY_TONE, STATUS_TONE, formatMins, slaState, sortQueue } from "@/lib/support";
import { INTERNAL_LABEL, TicketConversation } from "./ticket-conversation";
import { useToast } from "./toast";
import { Badge, Button, Card, ChipGroup, EmptyState, ErrorState, Field, LoadingState, PageHeader, QueryView, Select, Spinner, StatTile, Textarea, cx } from "./ui";

type StatusFilter = "active" | TicketStatus | "all";
type AssigneeFilter = "all" | "me" | "unassigned";

/** Re-renders every `ms` so SLA countdowns stay current. */
function useNow(ms = 30_000) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), ms);
    return () => window.clearInterval(id);
  }, [ms]);
  return now;
}

export function SupportDesk() {
  return (
    <>
      <PageHeader title="Support desk" description="Customer tickets. Clinical concerns also create a safety review and are never handled by support alone." />
      <Metrics />
      <Suspense fallback={<LoadingState label="Loading tickets…" />}>
        <DeskView />
      </Suspense>
    </>
  );
}

function Metrics() {
  const q = useQuery({ queryKey: ["support", "metrics"], queryFn: () => api.support.metrics(), refetchInterval: 60_000 });
  if (q.isPending) return <LoadingState rows={1} label="Loading metrics…" />;
  if (q.isError) return <p className="mb-4 text-sm text-ink-muted">Metrics are unavailable right now.</p>;
  const m = q.data;
  const cats = Object.entries(m.byCategory ?? {}).sort((a, b) => b[1] - a[1]);
  return (
    <div className="mb-5 flex flex-col gap-3">
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <StatTile label="Open tickets" value={m.open} icon={<Inbox className="size-4" />} tone={m.open > 0 ? "warn" : "neutral"} />
        <StatTile label="Avg first response" value={m.avgFirstResponseMins === null ? "—" : formatMins(m.avgFirstResponseMins)} icon={<Clock className="size-4" />} />
        <StatTile label="Avg resolution" value={m.avgResolutionHours === null ? "—" : `${m.avgResolutionHours.toFixed(1)} h`} icon={<MessageSquareReply className="size-4" />} />
        <StatTile label="CSAT" value={m.csatAvg === null ? "—" : `${m.csatAvg.toFixed(1)} / 5`} icon={<Smile className="size-4" />} />
      </div>
      {cats.length > 0 && (
        <ul className="flex flex-wrap gap-1.5" aria-label="Tickets by category">
          {cats.map(([k, v]) => (
            <li key={k}>
              <Badge>
                {humanize(k)}: {v}
              </Badge>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function DeskView() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const selectedId = params.get("ticket");
  const [status, setStatus] = useState<StatusFilter>("active");
  const [assignee, setAssignee] = useState<AssigneeFilter>("all");
  const now = useNow();

  const query = useQuery({
    queryKey: ["support", "tickets", status, assignee === "me"],
    queryFn: () =>
      api.support.tickets({
        status: status === "active" || status === "all" ? undefined : status,
        assignedTo: assignee === "me" ? "me" : undefined,
        limit: 100,
      }),
    refetchInterval: 30_000,
  });

  const items = useMemo(() => {
    let xs = query.data?.items ?? [];
    if (status === "active") xs = xs.filter((t) => t.status === "open" || t.status === "pending_customer");
    if (assignee === "unassigned") xs = xs.filter((t) => !t.assignedToName);
    return sortQueue(xs, now);
  }, [query.data, status, assignee, now]);

  const select = (id: string | null) => {
    const next = new URLSearchParams(params.toString());
    if (id) next.set("ticket", id);
    else next.delete("ticket");
    const qs = next.toString();
    router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
  };

  const listItem = query.data?.items.find((t) => t.id === selectedId);

  return (
    <div className="grid gap-5 lg:grid-cols-[minmax(0,380px)_minmax(0,1fr)]">
      <Card title="Queue" actions={query.isFetching && !query.isPending ? <Spinner label="Refreshing tickets" /> : null} bodyClassName="p-4">
        <div className="mb-3 flex flex-col gap-2">
          <ChipGroup<StatusFilter>
            label="Ticket status"
            value={status}
            onChange={setStatus}
            options={[{ value: "active", label: "Active" }, ...TICKET_STATUSES.map((s) => ({ value: s, label: humanize(s) })), { value: "all", label: "All" }]}
          />
          <ChipGroup<AssigneeFilter>
            label="Assignee"
            value={assignee}
            onChange={setAssignee}
            options={[
              { value: "all", label: "Anyone" },
              { value: "me", label: "Assigned to me" },
              { value: "unassigned", label: "Unassigned" },
            ]}
          />
        </div>
        <QueryView query={query} isEmpty={() => items.length === 0} empty={<EmptyState icon={<Headset className="size-6" />} title="No tickets" description="Nothing matches these filters." />}>
          {() => (
            <ul className="flex flex-col gap-2" aria-label="Tickets">
              {items.map((t) => {
                const sla = slaState(t, now);
                const active = t.id === selectedId;
                return (
                  <li key={t.id}>
                    <button
                      type="button"
                      aria-current={active ? "true" : undefined}
                      onClick={() => select(t.id)}
                      className={cx("flex w-full flex-col gap-1 rounded-xl border px-3 py-2.5 text-left", active ? "border-primary bg-mint-50" : "border-line hover:bg-mint-50")}
                    >
                      <span className="flex items-center justify-between gap-2">
                        <span className="font-mono text-xs text-ink-muted">{t.number}</span>
                        <Badge tone={sla.tone} icon={<Clock className="size-3" aria-hidden />}>
                          {sla.label}
                        </Badge>
                      </span>
                      <span className="line-clamp-2 text-sm font-semibold">{t.subject}</span>
                      <span className="flex flex-wrap items-center gap-1 text-xs text-ink-muted">
                        {t.userName} · {humanize(t.category)} · {relativeTime(t.createdAt, now)}
                      </span>
                      <span className="flex flex-wrap gap-1">
                        <Badge tone={STATUS_TONE[t.status] ?? "neutral"}>{humanize(t.status)}</Badge>
                        <Badge tone={PRIORITY_TONE[t.priority] ?? "neutral"}>{humanize(t.priority)}</Badge>
                        {t.category === "clinical_concern" && <Badge tone="red">Clinical</Badge>}
                        <Badge>{t.assignedToName ?? "Unassigned"}</Badge>
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </QueryView>
      </Card>
      <div className="min-w-0">
        {selectedId ? (
          <TicketPanel id={selectedId} fallback={listItem} now={now} onClose={() => select(null)} />
        ) : (
          <Card>
            <EmptyState title="Select a ticket" description="Choose a ticket from the queue to see the conversation." />
          </Card>
        )}
      </div>
    </div>
  );
}

function TicketPanel({ id, fallback, now, onClose }: { id: string; fallback?: Ticket; now: Date; onClose: () => void }) {
  const q = useQuery({ queryKey: ["support", "ticket", id], queryFn: () => api.support.ticket(id), placeholderData: fallback, refetchInterval: 20_000 });
  if (q.isPending) return <LoadingState rows={4} label="Loading ticket…" />;
  // The contract only lists GET /support/tickets/:id; if an agent cannot read it, fall back to the queue's copy.
  if (q.isError && !fallback) return <ErrorState error={q.error} onRetry={() => void q.refetch()} />;
  const t = (q.isError ? fallback : q.data) as Ticket;
  return <TicketView t={t} now={now} onClose={onClose} stale={q.isError} />;
}

export function TicketView({ t, now = new Date(), onClose, stale }: { t: Ticket; now?: Date; onClose?: () => void; stale?: boolean }) {
  const qc = useQueryClient();
  const toast = useToast();
  const { user, roles } = useAuth();
  const [text, setText] = useState("");
  const [internal, setInternal] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const sla = slaState(t, now);
  const closed = t.status === "closed";

  const refresh = () => {
    void qc.invalidateQueries({ queryKey: ["support"] });
  };
  const reply = useMutation({
    mutationFn: () => api.support.reply(t.id, { text: text.trim(), internal }),
    onSuccess: () => {
      toast.success(internal ? "Internal note added" : "Reply sent to the customer");
      setText("");
      refresh();
    },
    onError: (e) => toast.apiError(e, "Could not send"),
  });
  const update = useMutation({
    mutationFn: (input: { status?: TicketStatus; priority?: TicketPriority }) => api.support.update(t.id, input),
    onSuccess: () => {
      toast.success("Ticket updated");
      refresh();
    },
    onError: (e) => toast.apiError(e, "Could not update the ticket"),
  });
  const assign = useMutation({
    mutationFn: (userId: string) => api.support.assign(t.id, userId),
    onSuccess: () => {
      toast.success("Ticket assigned");
      refresh();
    },
    onError: (e) => toast.apiError(e, "Could not assign the ticket"),
  });

  return (
    <Card
      title={`${t.number} · ${t.subject}`}
      subtitle={`${t.userName} · ${humanize(t.category)} · opened ${formatDateTime(t.createdAt)}`}
      actions={
        <>
          <Badge tone={sla.tone} icon={<Clock className="size-3" aria-hidden />}>
            {sla.label}
          </Badge>
          {onClose && (
            <Button size="sm" variant="ghost" onClick={onClose}>
              Close
            </Button>
          )}
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {stale && <p className="text-xs text-ink-muted">Showing the queue copy of this ticket; the full ticket could not be loaded.</p>}
        {t.category === "clinical_concern" && (
          <p role="note" className="flex items-start gap-2 rounded-xl border border-[#f6c9c9] bg-rose-bg px-3 py-2 text-[13px] text-danger-dark">
            <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
            Clinical concern: a safety review was created for the care team. Do not give clinical advice; if symptoms sound urgent, tell the
            customer to call 108.
          </p>
        )}
        <div className="grid gap-3 sm:grid-cols-3">
          <Field label="Status">
            {(id) => (
              <Select id={id} value={t.status} disabled={update.isPending} onChange={(e) => update.mutate({ status: e.target.value as TicketStatus })}>
                {TICKET_STATUSES.map((s) => (
                  <option key={s} value={s}>
                    {humanize(s)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <Field label="Priority">
            {(id) => (
              <Select id={id} value={t.priority} disabled={update.isPending} onChange={(e) => update.mutate({ priority: e.target.value as TicketPriority })}>
                {TICKET_PRIORITIES.map((p) => (
                  <option key={p} value={p}>
                    {humanize(p)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <div className="flex flex-col gap-1">
            <span className="text-[13px] font-medium">Assignee</span>
            <p className="text-sm">{t.assignedToName ?? <span className="text-ink-muted">Unassigned</span>}</p>
            <div className="flex flex-wrap gap-2">
              {user && (
                <Button size="sm" variant="secondary" loading={assign.isPending && assign.variables === user.id} onClick={() => assign.mutate(user.id)} icon={<UserCheck className="size-4" aria-hidden />}>
                  Assign to me
                </Button>
              )}
              {isSuperAdmin(roles) && <AgentPicker onPick={(id) => assign.mutate(id)} />}
            </div>
          </div>
        </div>
        {t.rating && (
          <p className="flex items-center gap-1.5 text-sm">
            <Star className="size-4 text-peach-fg" aria-hidden /> Customer rating {t.rating.score}/5{t.rating.comment ? `: “${t.rating.comment}”` : ""}
          </p>
        )}

        <div className="max-h-[520px] overflow-y-auto rounded-xl bg-background p-3">
          <TicketConversation messages={t.messages ?? []} />
        </div>

        {closed ? (
          <p className="text-sm text-ink-muted">This ticket is closed. Reopen it (status) to reply.</p>
        ) : (
          <form
            noValidate
            className={cx("flex flex-col gap-2 rounded-xl border p-3", internal ? "border-2 border-dashed border-[#f2a23a] bg-peach-bg/60" : "border-line")}
            onSubmit={(e) => {
              e.preventDefault();
              if (!text.trim()) {
                setError(internal ? "Write the note" : "Write a reply");
                return;
              }
              setError(null);
              reply.mutate();
            }}
          >
            <ChipGroup<"reply" | "internal">
              label="Message type"
              value={internal ? "internal" : "reply"}
              onChange={(v) => setInternal(v === "internal")}
              options={[
                { value: "reply", label: "Reply to customer" },
                { value: "internal", label: "Internal note" },
              ]}
            />
            {internal && (
              <p className="flex items-center gap-1.5 text-xs font-semibold text-peach-fg">
                <Lock className="size-3.5" aria-hidden /> {INTERNAL_LABEL}
              </p>
            )}
            <Field label={internal ? "Internal note" : "Reply"} error={error ?? undefined}>
              {(id, d) => <Textarea id={id} rows={3} aria-describedby={d} aria-invalid={!!error} value={text} onChange={(e) => setText(e.target.value)} />}
            </Field>
            <Button type="submit" className="self-end" variant={internal ? "secondary" : "primary"} loading={reply.isPending} icon={internal ? <Lock className="size-4" aria-hidden /> : <Send className="size-4" aria-hidden />}>
              {internal ? "Add internal note" : "Send reply"}
            </Button>
          </form>
        )}
      </div>
    </Card>
  );
}

/** super_admin only: pick a support agent or coordinator to assign (needs GET /admin/users). */
function AgentPicker({ onPick }: { onPick: (userId: string) => void }) {
  const agents = useQuery({ queryKey: ["admin", "users", "support_agent"], queryFn: () => api.admin.users({ role: "support_agent", limit: 100 }), staleTime: 5 * 60_000 });
  const coords = useQuery({ queryKey: ["admin", "users", "coordinator"], queryFn: () => api.admin.users({ role: "coordinator", limit: 100 }), staleTime: 5 * 60_000 });
  const users = [...(agents.data?.items ?? []), ...(coords.data?.items ?? [])];
  if (users.length === 0) return null;
  return (
    <Select
      aria-label="Assign to"
      className="h-9 w-auto"
      value=""
      onChange={(e) => {
        if (e.target.value) onPick(e.target.value);
      }}
    >
      <option value="">Assign to…</option>
      {users.map((u) => (
        <option key={u.id} value={u.id}>
          {u.name ?? u.phone} ({u.roles.includes("support_agent") ? "support" : "coordinator"})
        </option>
      ))}
    </Select>
  );
}

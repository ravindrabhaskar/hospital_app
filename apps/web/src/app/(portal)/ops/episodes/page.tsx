"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { UserCheck } from "lucide-react";
import { api } from "@/lib/api";
import { EPISODE_STATUSES, type CareEpisode, type EpisodeStatus } from "@/lib/api/types";
import { useAuth } from "@/lib/auth";
import { canAssignAnyCoordinator } from "@/lib/roles";
import { formatDateTime, humanize, relativeTime } from "@/lib/format";
import { EpisodeTimelineCard } from "@/components/episode-timeline";
import { EpisodeStatusBadge, PriorityBadge } from "@/components/status";
import { useToast } from "@/components/toast";
import { Button, Card, Dialog, EmptyState, ErrorState, Field, LoadingState, PageHeader, QueryView, Select, cx } from "@/components/ui";

export default function OpsEpisodesPage() {
  const [status, setStatus] = useState<EpisodeStatus | "">("");
  const [selected, setSelected] = useState<string | null>(null);
  const query = useQuery({
    queryKey: ["ops", "episodes", status],
    queryFn: () => api.ops.episodes({ status: status || undefined, limit: 100 }),
  });
  const selectedEpisode = query.data?.items.find((e) => e.id === selected);

  return (
    <>
      <PageHeader title="Care episodes" description="Every patient concern is tracked as an episode from intake to resolution." />
      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_380px]">
        <Card
          title="Episodes"
          actions={
            <Field label="Status" className="w-52">
              {(id) => (
                <Select id={id} value={status} onChange={(e) => setStatus(e.target.value as EpisodeStatus | "")}>
                  <option value="">All statuses</option>
                  {EPISODE_STATUSES.map((s) => (
                    <option key={s} value={s}>
                      {humanize(s)}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
          }
        >
          <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No episodes" />}>
            {(d) => (
              <ul className="flex flex-col gap-2">
                {d.items.map((e) => (
                  <li key={e.id}>
                    <button
                      type="button"
                      aria-pressed={selected === e.id}
                      onClick={() => setSelected(e.id)}
                      className={cx(
                        "flex w-full flex-wrap items-start justify-between gap-2 rounded-xl border px-3 py-2.5 text-left",
                        selected === e.id ? "border-primary bg-mint-50" : "border-line hover:bg-mint-50",
                      )}
                    >
                      <span className="min-w-0">
                        <span className="block font-semibold">
                          {e.patientName} · {e.title}
                        </span>
                        <span className="block text-xs text-ink-muted">
                          Owner {e.ownerName ?? "unassigned"} · Coordinator: {e.coordinatorName ?? "unassigned"} · updated {relativeTime(e.updatedAt)} · opened {formatDateTime(e.createdAt)}
                        </span>
                        {e.nextAction && <span className="block text-xs">Next: {e.nextAction}</span>}
                      </span>
                      <span className="flex gap-1.5">
                        <PriorityBadge priority={e.priority} />
                        <EpisodeStatusBadge status={e.status} />
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </QueryView>
        </Card>
        <aside aria-label="Selected episode timeline">
          <div className="xl:sticky xl:top-20">
            {selected ? (
              <div className="flex flex-col gap-5">
                {selectedEpisode && <CoordinatorCard episode={selectedEpisode} />}
                <EpisodeTimelineCard episodeId={selected} className="xl:max-h-[calc(100vh-6rem)] xl:overflow-y-auto" />
              </div>
            ) : (
              <Card title="Episode timeline">
                <EmptyState title="Select an episode" description="Its append-only event timeline appears here." />
              </Card>
            )}
          </div>
        </aside>
      </div>
    </>
  );
}

/** §35: ops_admin/super_admin assign any coordinator; a coordinator may assign themselves. */
function CoordinatorCard({ episode }: { episode: CareEpisode }) {
  const { user, roles } = useAuth();
  const qc = useQueryClient();
  const toast = useToast();
  const [picking, setPicking] = useState(false);
  const canAssignAny = canAssignAnyCoordinator(roles);
  const isCoordinator = roles.includes("coordinator");
  const assign = useMutation({
    mutationFn: (userId: string) => api.coordinator.assign(episode.id, userId),
    onSuccess: (ep) => {
      toast.success("Coordinator assigned", ep.coordinatorName ?? undefined);
      setPicking(false);
      void qc.invalidateQueries({ queryKey: ["ops", "episodes"] });
      void qc.invalidateQueries({ queryKey: ["episode", episode.id] });
    },
    onError: (err) => toast.apiError(err, "Could not assign coordinator"),
  });
  const mine = !!user && episode.coordinatorUserId === user.id;

  return (
    <Card title="Coordinator" subtitle={`${episode.patientName} · ${episode.title}`}>
      <p className="text-sm">
        <span className="text-ink-muted">Assigned: </span>
        <span className="font-semibold">{episode.coordinatorName ?? "Unassigned"}</span>
      </p>
      <div className="mt-3 flex flex-wrap gap-2">
        {canAssignAny && (
          <Button size="sm" variant="secondary" icon={<UserCheck className="size-4" aria-hidden />} onClick={() => setPicking(true)}>
            Assign coordinator
          </Button>
        )}
        {isCoordinator && user && !mine && (
          <Button size="sm" variant={canAssignAny ? "ghost" : "secondary"} loading={assign.isPending && !picking} onClick={() => assign.mutate(user.id)}>
            Assign to me
          </Button>
        )}
      </div>
      {picking && (
        <AssignCoordinatorDialog
          current={episode.coordinatorUserId ?? null}
          pending={assign.isPending}
          onAssign={(id) => assign.mutate(id)}
          onClose={() => setPicking(false)}
        />
      )}
    </Card>
  );
}

function AssignCoordinatorDialog({
  current,
  pending,
  onAssign,
  onClose,
}: {
  current: string | null;
  pending: boolean;
  onAssign: (userId: string) => void;
  onClose: () => void;
}) {
  const [userId, setUserId] = useState(current ?? "");
  const users = useQuery({
    queryKey: ["admin", "users", { role: "coordinator" }],
    queryFn: () => api.admin.users({ role: "coordinator", limit: 100 }),
  });
  const options = (users.data?.items ?? []).filter((u) => u.status === "active" && u.roles.includes("coordinator"));
  return (
    <Dialog
      open
      onClose={onClose}
      title="Assign coordinator"
      description="The coordinator joins the episode's message thread and sees it in their caseload."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button loading={pending} disabled={!userId || userId === current} onClick={() => onAssign(userId)}>
            Assign
          </Button>
        </>
      }
    >
      {users.isPending ? (
        <LoadingState label="Loading coordinators…" rows={2} />
      ) : users.isError ? (
        <ErrorState error={users.error} onRetry={() => void users.refetch()} />
      ) : options.length === 0 ? (
        <EmptyState title="No coordinators" description="Add a staff user with the coordinator role first." />
      ) : (
        <Field label="Coordinator" required>
          {(id) => (
            <Select id={id} data-autofocus value={userId} onChange={(e) => setUserId(e.target.value)}>
              <option value="">Choose a coordinator…</option>
              {options.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.name ?? u.phone}
                  {u.id === current ? " (current)" : ""}
                </option>
              ))}
            </Select>
          )}
        </Field>
      )}
    </Dialog>
  );
}

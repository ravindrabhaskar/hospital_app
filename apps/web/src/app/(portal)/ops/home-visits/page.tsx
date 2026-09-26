"use client";

import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, Clock, MapPin, UserPlus } from "lucide-react";
import { api } from "@/lib/api";
import type { HomeVisitStatus, OpsHomeVisit } from "@/lib/api/types";
import { isLate, providerAvailable } from "@/lib/ops";
import { formatDateTime, formatINR, formatTime, humanize, relativeTime } from "@/lib/format";
import { VisitStatusBadge } from "@/components/status";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, ChipGroup, Dialog, EmptyState, PageHeader, QueryView, cx } from "@/components/ui";

type Tab = "attention" | "all" | HomeVisitStatus;

export default function DispatchBoardPage() {
  const [tab, setTab] = useState<Tab>("attention");
  const [assigning, setAssigning] = useState<OpsHomeVisit | null>(null);
  const status = tab === "attention" || tab === "all" ? undefined : tab;
  const query = useQuery({
    queryKey: ["ops", "home-visits", status ?? "all"],
    queryFn: () => api.ops.homeVisits({ status, limit: 100 }),
    refetchInterval: 30_000,
  });

  const items = useMemo(() => {
    const list = query.data?.items ?? [];
    const filtered =
      tab === "attention" ? list.filter((v) => v.slaBreached || isLate(v) || v.status === "unassigned" || v.status === "requested" || v.status === "escalated") : list;
    const score = (v: OpsHomeVisit) => (v.status === "escalated" ? 0 : v.slaBreached ? 1 : isLate(v) ? 2 : v.status === "unassigned" ? 3 : 4);
    return [...filtered].sort((a, b) => score(a) - score(b) || new Date(a.preferredStart).getTime() - new Date(b.preferredStart).getTime());
  }, [query.data, tab]);

  const tabs: { value: Tab; label: string }[] = [
    { value: "attention", label: "Needs attention" },
    { value: "all", label: "All" },
    { value: "requested", label: "Requested" },
    { value: "unassigned", label: "Unassigned" },
    { value: "assigned", label: "Assigned" },
    { value: "accepted", label: "Accepted" },
    { value: "en_route", label: "En route" },
    { value: "in_progress", label: "In progress" },
    { value: "escalated", label: "Escalated" },
    { value: "completed", label: "Completed" },
  ];

  return (
    <>
      <PageHeader title="Home-visit dispatch" description="SLA-breached (unassigned > 30 min) and late (not arrived by the window end) visits are highlighted." />
      <Card>
        <div className="mb-4">
          <ChipGroup label="Visit status" options={tabs} value={tab} onChange={setTab} />
        </div>
        <QueryView query={query} isEmpty={() => items.length === 0} empty={<EmptyState title="No visits" description="Nothing in this view." />}>
          {() => (
            <ul className="flex flex-col gap-3">
              {items.map((v) => (
                <VisitRow key={v.id} v={v} onAssign={() => setAssigning(v)} />
              ))}
            </ul>
          )}
        </QueryView>
      </Card>
      {assigning && <AssignDialog visit={assigning} onClose={() => setAssigning(null)} />}
    </>
  );
}

function VisitRow({ v, onAssign }: { v: OpsHomeVisit; onAssign: () => void }) {
  const late = isLate(v);
  const assignable = ["requested", "unassigned", "assigned", "escalated"].includes(v.status);
  return (
    <li
      className={cx(
        "rounded-2xl border p-4",
        v.slaBreached ? "border-danger bg-rose-bg/50" : late ? "border-[#f2a23a] bg-peach-bg/50" : "border-line bg-white",
      )}
    >
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <p className="font-semibold">{v.patientName}</p>
            <VisitStatusBadge status={v.status} />
            {v.slaBreached && (
              <Badge tone="red" icon={<AlertTriangle className="size-3" aria-hidden />}>
                SLA breached
              </Badge>
            )}
            {late && (
              <Badge tone="amber" icon={<Clock className="size-3" aria-hidden />}>
                Late
              </Badge>
            )}
          </div>
          <p className="mt-1 text-[13px]">
            {v.serviceName} · {formatINR(v.price)} · {v.reason}
          </p>
          <p className="mt-1 flex items-center gap-1 text-xs text-ink-muted">
            <MapPin className="size-3" aria-hidden />
            {v.address.line1}
            {v.address.landmark ? `, ${v.address.landmark}` : ""}, {v.address.city} {v.address.pincode}
          </p>
          <p className="text-xs text-ink-muted">
            Window {formatDateTime(v.preferredStart)} – {formatTime(v.preferredEnd)} · requested {relativeTime(v.createdAt)}
          </p>
          <p className="text-xs text-ink-muted">
            Provider: {v.provider ? `${v.provider.name} (${v.provider.qualification}) · ${v.provider.phoneMasked}` : "none"}
            {v.etaMinutes !== null ? ` · ETA ${v.etaMinutes} min` : ""}
          </p>
          {v.escalation && (
            <p className="mt-1 text-[13px] text-danger-dark">
              Escalated ({v.escalation.severity}): {v.escalation.reason}
            </p>
          )}
        </div>
        {assignable && (
          <Button size="sm" onClick={onAssign} icon={<UserPlus className="size-4" aria-hidden />}>
            {v.provider ? "Reassign" : "Assign provider"}
          </Button>
        )}
      </div>
    </li>
  );
}


function AssignDialog({ visit, onClose }: { visit: OpsHomeVisit; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [selected, setSelected] = useState<string | null>(null);
  const providers = useQuery({ queryKey: ["ops", "providers", "verified"], queryFn: () => api.ops.providers({ status: "verified", limit: 100 }) });

  const assign = useMutation({
    mutationFn: (providerId: string) => api.homeVisits.assign(visit.id, providerId),
    onSuccess: () => {
      toast.success("Provider assigned");
      void qc.invalidateQueries({ queryKey: ["ops"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not assign provider"),
  });

  return (
    <Dialog
      open
      onClose={onClose}
      title="Assign a provider"
      description={`${visit.serviceName} for ${visit.patientName} · pincode ${visit.address.pincode}`}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button disabled={!selected} loading={assign.isPending} onClick={() => selected && assign.mutate(selected)}>
            Assign
          </Button>
        </>
      }
    >
      <p className="mb-3 text-xs text-ink-muted">Only verified, on-duty providers with a valid credential are listed. Zone and capability are checked by the server.</p>
      <QueryView
        query={providers}
        isEmpty={(d) => d.items.filter((p) => providerAvailable(p)).length === 0}
        empty={<EmptyState title="No available providers" description="No verified provider is on duty right now." />}
      >
        {(d) => (
          <fieldset>
            <legend className="sr-only">Providers</legend>
            <ul className="flex flex-col gap-2">
              {d.items.filter((p) => providerAvailable(p)).map((p) => (
                <li key={p.id}>
                  <label
                    className={cx(
                      "flex cursor-pointer items-center justify-between gap-3 rounded-xl border p-3",
                      selected === p.id ? "border-primary bg-mint-50" : "border-line hover:bg-mint-50",
                    )}
                  >
                    <span className="flex items-center gap-3">
                      <input type="radio" name="provider" value={p.id} checked={selected === p.id} onChange={() => setSelected(p.id)} className="size-4 accent-[#0B5D45]" />
                      <span>
                        <span className="block font-semibold">{p.name}</span>
                        <span className="block text-xs text-ink-muted">
                          {humanize(p.type)} · {p.qualification} · {p.zones.join(", ") || "no zone"}
                        </span>
                      </span>
                    </span>
                    <span className="text-right text-xs text-ink-muted">
                      <Badge tone={p.status === "available" ? "green" : "amber"}>{humanize(p.status)}</Badge>
                      <span className="mt-1 block">{p.visitsToday} visits today</span>
                    </span>
                  </label>
                </li>
              ))}
            </ul>
          </fieldset>
        )}
      </QueryView>
    </Dialog>
  );
}

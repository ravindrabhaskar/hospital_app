"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Ambulance, ExternalLink, MapPin, Phone } from "lucide-react";
import { api } from "@/lib/api";
import { AMBULANCE_STATUSES, type AmbulanceRequest, type AmbulanceStatus } from "@/lib/api/types";
import { formatDateTime, formatTime, humanize, relativeTime } from "@/lib/format";
import { osmLink } from "@/lib/ops";
import { Badge, Card, ChipGroup, EmptyState, PageHeader, QueryView, Spinner, type Tone } from "@/components/ui";

type Filter = "live" | AmbulanceStatus;
const LIVE: AmbulanceStatus[] = ["searching", "assigned", "en_route", "arrived", "transporting"];
const TONE: Record<AmbulanceStatus, Tone> = {
  searching: "amber",
  assigned: "sky",
  en_route: "lavender",
  arrived: "green",
  transporting: "green",
  completed: "neutral",
  cancelled: "neutral",
  no_vehicle: "red",
};

export default function OpsAmbulancePage() {
  const [filter, setFilter] = useState<Filter>("live");
  const query = useQuery({
    queryKey: ["ops", "ambulance", filter],
    queryFn: () => api.ambulance.opsList({ status: filter === "live" ? undefined : filter, limit: 100 }),
    refetchInterval: 5_000,
    refetchIntervalInBackground: false,
  });
  const items = (query.data?.items ?? []).filter((r) => filter !== "live" || LIVE.includes(r.status));

  return (
    <>
      <PageHeader
        title="Ambulance requests"
        description="Live partner bookings, refreshed every 5 seconds. A booking never replaces 108: patients are always told to call 108 first."
        actions={query.isFetching ? <Spinner label="Refreshing" /> : null}
      />
      <p role="note" className="mb-4 rounded-2xl border border-[#f6c9c9] bg-rose-bg px-4 py-3 text-[13px] text-danger-dark">
        In a life-threatening emergency, make sure the family has called <strong>108</strong>. Each request also raised an emergency safety event.
      </p>
      <div className="mb-4">
        <ChipGroup<Filter>
          label="Status"
          value={filter}
          onChange={setFilter}
          options={[{ value: "live", label: "Live" }, ...AMBULANCE_STATUSES.map((s) => ({ value: s, label: humanize(s) }))]}
        />
      </div>
      <QueryView
        query={query}
        isEmpty={() => items.length === 0}
        empty={
          <Card>
            <EmptyState icon={<Ambulance className="size-6" />} title="No ambulance requests" description={filter === "live" ? "No vehicle is currently searching or on the way." : "Nothing with this status."} />
          </Card>
        }
      >
        {() => (
          <ul className="grid gap-4 lg:grid-cols-2" aria-live="polite">
            {items.map((r) => (
              <li key={r.id}>
                <RequestCard r={r} />
              </li>
            ))}
          </ul>
        )}
      </QueryView>
    </>
  );
}

function RequestCard({ r }: { r: AmbulanceRequest }) {
  return (
    <Card
      title={`${r.patientName} · ${r.type.toUpperCase()}`}
      subtitle={`${r.partnerName} · requested ${formatDateTime(r.createdAt)}`}
      actions={<Badge tone={TONE[r.status] ?? "neutral"}>{humanize(r.status)}</Badge>}
    >
      <dl className="grid gap-3 text-sm sm:grid-cols-2">
        <div>
          <dt className="text-xs text-ink-muted">Pickup</dt>
          <dd className="flex items-start gap-1.5">
            <MapPin className="mt-0.5 size-4 shrink-0 text-ink-muted" aria-hidden />
            <span>
              {r.pickup.address}{" "}
              <a href={osmLink(r.pickup.lat, r.pickup.lng)} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-0.5 text-primary-light underline">
                Map <ExternalLink className="size-3" aria-hidden />
                <span className="sr-only">(pickup on OpenStreetMap, opens in a new tab)</span>
              </a>
            </span>
          </dd>
        </div>
        <div>
          <dt className="text-xs text-ink-muted">Destination</dt>
          <dd>{r.destination ? `${r.destination.name}, ${r.destination.area}` : "Not set"}</dd>
        </div>
        <div>
          <dt className="text-xs text-ink-muted">Vehicle</dt>
          <dd>
            {r.vehicle ? (
              <>
                <span className="font-mono">{r.vehicle.number}</span> · {r.vehicle.driverName}
                <span className="flex items-center gap-1 text-xs text-ink-muted">
                  <Phone className="size-3" aria-hidden /> {r.vehicle.phoneMasked}
                </span>
              </>
            ) : (
              <span className="text-ink-muted">{r.status === "no_vehicle" ? "No vehicle available" : "Searching…"}</span>
            )}
          </dd>
        </div>
        <div>
          <dt className="text-xs text-ink-muted">ETA · location</dt>
          <dd>
            {r.etaMinutes !== null ? <strong>{r.etaMinutes} min</strong> : "—"}
            {r.location && (
              <span className="block text-xs text-ink-muted">
                Updated {relativeTime(r.location.updatedAt)} ·{" "}
                <a href={osmLink(r.location.lat, r.location.lng)} target="_blank" rel="noopener noreferrer" className="text-primary-light underline">
                  Vehicle on map<span className="sr-only"> (opens in a new tab)</span>
                </a>
              </span>
            )}
          </dd>
        </div>
      </dl>
      {r.timeline.length > 0 && (
        <ol className="mt-3 flex flex-wrap gap-x-3 gap-y-1 border-t border-line pt-2 text-xs text-ink-muted" aria-label="Status timeline">
          {r.timeline.map((t, i) => (
            <li key={i}>
              {humanize(t.status)} {formatTime(t.at)}
            </li>
          ))}
        </ol>
      )}
    </Card>
  );
}

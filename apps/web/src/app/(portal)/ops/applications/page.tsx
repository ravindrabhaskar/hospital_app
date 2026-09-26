"use client";

import { Suspense, useEffect, useState, type ReactNode } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, ArrowLeft, FileText, Lock } from "lucide-react";
import { api } from "@/lib/api";
import type { ApplicationDocument, ApplicationStatus, ProviderApplication, ServiceZone } from "@/lib/api/types";
import { DOC_LABEL, isDecidable, missingRequiredDocs } from "@/lib/application-decision";
import { formatDate, formatDateTime, humanize } from "@/lib/format";
import { saveBlob } from "@/lib/download";
import { useAuth } from "@/lib/auth";
import { canDecideApplications } from "@/lib/roles";
import { ApplicationDecisionForm } from "@/components/application-decision-form";
import {
  Badge,
  Button,
  Card,
  ChipGroup,
  EmptyState,
  LoadingState,
  PageHeader,
  QueryView,
  Spinner,
  cx,
  errorMessage,
  type Tone,
} from "@/components/ui";

type Filter = "all" | ApplicationStatus;

const STATUS_TONE: Record<ApplicationStatus, Tone> = {
  submitted: "amber",
  changes_requested: "lavender",
  approved: "green",
  rejected: "red",
};

function ApplicationStatusBadge({ status }: { status: ApplicationStatus }) {
  return <Badge tone={STATUS_TONE[status] ?? "neutral"}>{humanize(status)}</Badge>;
}

export default function ApplicationsPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <ApplicationsView />
    </Suspense>
  );
}

function ApplicationsView() {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const selectedId = params.get("id");
  const [filter, setFilter] = useState<Filter>("submitted");

  const query = useQuery({
    queryKey: ["ops", "applications", filter],
    queryFn: () => api.applications.list({ status: filter === "all" ? undefined : filter, limit: 100 }),
  });
  const zonesQuery = useQuery({
    queryKey: ["admin", "zones"],
    queryFn: () => api.admin.zones({ limit: 100 }),
    retry: false,
    staleTime: 5 * 60_000,
  });
  const zones: ServiceZone[] | null = zonesQuery.data?.items ?? null;

  const select = (id: string | null) => {
    const next = new URLSearchParams(params.toString());
    if (id) next.set("id", id);
    else next.delete("id");
    const qs = next.toString();
    router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
  };

  return (
    <>
      <PageHeader title="Provider applications" description="Review onboarding applications from nurses, technicians, physiotherapists and doctors." />
      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_480px]">
        <Card className={cx(selectedId && "hidden xl:block")}>
          <div className="mb-4">
            <ChipGroup
              label="Application status"
              value={filter}
              onChange={setFilter}
              options={[
                { value: "submitted", label: "Submitted" },
                { value: "changes_requested", label: "Changes requested" },
                { value: "approved", label: "Approved" },
                { value: "rejected", label: "Rejected" },
                { value: "all", label: "All" },
              ]}
            />
          </div>
          <QueryView
            query={query}
            isEmpty={(d) => d.items.length === 0}
            empty={<EmptyState title="No applications" description="Nothing in this queue right now." />}
          >
            {(d) => (
              <ul className="flex flex-col gap-2">
                {d.items.map((a) => (
                  <li key={a.id}>
                    <button
                      type="button"
                      onClick={() => select(a.id)}
                      aria-current={a.id === selectedId ? "true" : undefined}
                      className={cx(
                        "w-full rounded-xl border px-4 py-3 text-left transition-colors hover:border-primary-light focus-visible:outline-2 focus-visible:outline-primary-light",
                        a.id === selectedId ? "border-primary bg-mint-50" : "border-line bg-white",
                      )}
                    >
                      <div className="flex flex-wrap items-start justify-between gap-2">
                        <div className="min-w-0">
                          <p className="font-semibold">{a.fullName}</p>
                          <p className="text-xs text-ink-muted">
                            {humanize(a.type)} · {a.qualification} · {a.experienceYears} yr{a.experienceYears === 1 ? "" : "s"} experience
                          </p>
                          <p className="text-xs text-ink-muted">
                            Reg. <span className="font-mono">{a.registrationNumber}</span>
                            {a.registrationCouncil ? ` · ${a.registrationCouncil}` : ""}
                          </p>
                        </div>
                        <div className="flex flex-col items-end gap-1">
                          <ApplicationStatusBadge status={a.status} />
                          <span className="text-xs text-ink-muted">
                            {a.documents.length} doc{a.documents.length === 1 ? "" : "s"} · {formatDate(a.createdAt)}
                          </span>
                        </div>
                      </div>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </QueryView>
        </Card>

        {selectedId ? (
          <ApplicationDetail key={selectedId} id={selectedId} zones={zones} zonesPending={zonesQuery.isPending} onClose={() => select(null)} />
        ) : (
          <Card className="hidden xl:block">
            <EmptyState title="Select an application" description="Choose an application to see details, documents and the decision form." />
          </Card>
        )}
      </div>
    </>
  );
}

function ApplicationDetail({
  id,
  zones,
  zonesPending,
  onClose,
}: {
  id: string;
  zones: ServiceZone[] | null;
  zonesPending: boolean;
  onClose: () => void;
}) {
  const { roles } = useAuth();
  const qc = useQueryClient();
  const canDecide = canDecideApplications(roles);
  const [viewing, setViewing] = useState<ApplicationDocument | null>(null);

  const query = useQuery({ queryKey: ["ops", "application", id], queryFn: () => api.applications.get(id) });
  const servicesQuery = useQuery({
    queryKey: ["reference", "home-visit-services"],
    queryFn: () => api.reference.homeVisitServices(),
    staleTime: 10 * 60_000,
    enabled: canDecide,
  });

  const zoneName = (zid: string) => {
    const z = zones?.find((x) => x.id === zid);
    return z ? `${z.name} (${z.city})` : zid;
  };

  const onDecided = (updated: ProviderApplication) => {
    qc.setQueryData(["ops", "application", id], updated);
    void qc.invalidateQueries({ queryKey: ["ops", "applications"] });
  };

  return (
    <Card
      title={query.data?.fullName ?? "Application"}
      subtitle={query.data ? `${humanize(query.data.type)} · applied ${formatDateTime(query.data.createdAt)}` : undefined}
      actions={
        <Button variant="ghost" size="sm" onClick={onClose} icon={<ArrowLeft className="size-4" aria-hidden />}>
          Back to list
        </Button>
      }
    >
      <QueryView query={query}>
        {(app) => {
          const missing = missingRequiredDocs(app);
          const decidable = isDecidable(app.status);
          return (
            <div className="flex flex-col gap-5">
              <div className="flex flex-wrap items-center gap-2">
                <ApplicationStatusBadge status={app.status} />
                {app.decidedAt && <span className="text-xs text-ink-muted">Decided {formatDateTime(app.decidedAt)}</span>}
              </div>

              <dl className="grid grid-cols-1 gap-x-4 gap-y-2 text-sm sm:grid-cols-2">
                <Detail label="Phone" value={app.phone} />
                <Detail label="Qualification" value={app.qualification} />
                <Detail label="Registration number" value={<span className="font-mono">{app.registrationNumber}</span>} />
                <Detail label="Registration council" value={app.registrationCouncil ?? "—"} />
                {app.type === "doctor" && <Detail label="Specialty" value={app.specialty ? humanize(app.specialty) : "—"} />}
                <Detail label="Experience" value={`${app.experienceYears} year${app.experienceYears === 1 ? "" : "s"}`} />
                <Detail label="Languages" value={app.languages.length ? app.languages.join(", ") : "—"} />
                <Detail
                  label="Preferred zones"
                  value={
                    app.preferredZoneIds.length === 0 ? (
                      "—"
                    ) : (
                      <span className="flex flex-wrap gap-1">
                        {app.preferredZoneIds.map((z) => (
                          <Badge key={z} tone="sky">
                            {zoneName(z)}
                          </Badge>
                        ))}
                      </span>
                    )
                  }
                />
              </dl>

              <section aria-labelledby={`${app.id}-docs`}>
                <h3 id={`${app.id}-docs`} className="mb-2 text-sm font-semibold">
                  Documents
                </h3>
                {missing.length > 0 && (
                  <p role="note" className="mb-2 flex items-start gap-1.5 rounded-xl bg-peach-bg px-3 py-2 text-xs text-peach-fg">
                    <AlertTriangle className="mt-0.5 size-3.5 shrink-0" aria-hidden />
                    Missing required: {missing.map((m) => DOC_LABEL[m]).join(", ")}. Approval is blocked until they are uploaded.
                  </p>
                )}
                {app.documents.length === 0 ? (
                  <p className="text-sm text-ink-muted">No documents uploaded.</p>
                ) : (
                  <ul className="flex flex-col gap-1.5">
                    {app.documents.map((d) => (
                      <li key={d.id}>
                        <button
                          type="button"
                          onClick={() => setViewing(d)}
                          aria-pressed={viewing?.id === d.id}
                          className={cx(
                            "flex w-full items-center gap-2 rounded-xl border px-3 py-2 text-left text-sm hover:border-primary-light",
                            viewing?.id === d.id ? "border-primary bg-mint-50" : "border-line bg-white",
                          )}
                        >
                          <FileText className="size-4 shrink-0 text-primary-light" aria-hidden />
                          <span className="min-w-0 flex-1">
                            <span className="block font-medium">{DOC_LABEL[d.docType] ?? humanize(d.docType)}</span>
                            <span className="block truncate text-xs text-ink-muted">
                              {d.fileName} · {formatSize(d.sizeBytes)} · {formatDate(d.uploadedAt)}
                            </span>
                          </span>
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
                {viewing && <DocumentViewer appId={app.id} doc={viewing} onClose={() => setViewing(null)} />}
              </section>

              {(app.decisionNote || app.decidedByName) && (
                <section className="rounded-xl border border-line bg-mint-50/50 p-3 text-sm">
                  <h3 className="text-sm font-semibold">Last decision</h3>
                  <p className="text-xs text-ink-muted">
                    {app.decidedByName ?? "Unknown"} · {formatDateTime(app.decidedAt)}
                  </p>
                  {app.decisionNote && <p className="mt-1 whitespace-pre-wrap">{app.decisionNote}</p>}
                </section>
              )}

              {decidable && (
                <section aria-labelledby={`${app.id}-decide`} className="border-t border-line pt-4">
                  <h3 id={`${app.id}-decide`} className="mb-3 text-sm font-semibold">
                    Decision
                  </h3>
                  {!canDecide ? (
                    <p className="flex items-center gap-2 rounded-xl bg-peach-bg px-3 py-2 text-sm text-peach-fg">
                      <Lock className="size-4" aria-hidden /> Only ops admins can decide applications.
                    </p>
                  ) : zonesPending || servicesQuery.isPending ? (
                    <LoadingState rows={2} label="Loading decision options…" />
                  ) : (
                    <ApplicationDecisionForm
                      app={app}
                      zones={zones}
                      services={servicesQuery.data?.items ?? null}
                      onDecided={onDecided}
                    />
                  )}
                </section>
              )}
            </div>
          );
        }}
      </QueryView>
    </Card>
  );
}

function Detail({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div>
      <dt className="text-xs text-ink-muted">{label}</dt>
      <dd className="font-medium">{value}</dd>
    </div>
  );
}

function formatSize(bytes: number) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function DocumentViewer({ appId, doc, onClose }: { appId: string; doc: ApplicationDocument; onClose: () => void }) {
  const [state, setState] = useState<{ url: string; blob: Blob } | { error: string } | null>(null);

  useEffect(() => {
    let cancelled = false;
    let url: string | null = null;
    setState(null);
    api.applications
      .documentFile(appId, doc.id)
      .then((blob) => {
        if (cancelled) return;
        url = URL.createObjectURL(blob);
        setState({ url, blob });
      })
      .catch((e: unknown) => {
        if (!cancelled) setState({ error: errorMessage(e) });
      });
    return () => {
      cancelled = true;
      if (url) URL.revokeObjectURL(url);
    };
  }, [appId, doc.id]);

  const mime = (state && "blob" in state && state.blob.type) || doc.mimeType;
  const label = `${DOC_LABEL[doc.docType] ?? humanize(doc.docType)}: ${doc.fileName}`;

  return (
    <div className="mt-3 rounded-xl border border-line">
      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-line px-3 py-2">
        <p className="min-w-0 truncate text-sm font-medium">{label}</p>
        <div className="flex gap-2">
          {state && "blob" in state && (
            <Button size="sm" variant="secondary" onClick={() => saveBlob(state.blob, doc.fileName)}>
              Download
            </Button>
          )}
          <Button size="sm" variant="ghost" onClick={onClose}>
            Close viewer
          </Button>
        </div>
      </div>
      <div className="p-3">
        {state === null ? (
          <div className="flex h-40 items-center justify-center">
            <Spinner label="Loading document" />
          </div>
        ) : "error" in state ? (
          <p role="alert" className="text-sm text-danger-dark">
            Could not load the document: {state.error}
          </p>
        ) : mime === "application/pdf" ? (
          <iframe title={label} src={state.url} className="h-[480px] w-full rounded-lg border border-line" />
        ) : mime.startsWith("image/") ? (
          // eslint-disable-next-line @next/next/no-img-element -- object URL of an authenticated blob
          <img src={state.url} alt={label} className="mx-auto max-h-[480px] max-w-full rounded-lg object-contain" />
        ) : (
          <p className="text-sm text-ink-muted">This file type cannot be previewed. Use Download to open it.</p>
        )}
      </div>
    </div>
  );
}

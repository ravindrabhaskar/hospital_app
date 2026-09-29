"use client";

import { Suspense, useCallback, useMemo, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { ClipboardList, Info } from "lucide-react";
import { api } from "@/lib/api";
import type { CaseloadFlag, CaseloadItem } from "@/lib/api/types";
import { useAuth } from "@/lib/auth";
import { FLAG_META, orderedFlags } from "@/lib/caseload";
import { CaseloadTable } from "@/components/caseload-table";
import { PatientDrawer } from "@/components/patient-drawer";
import { Card, ChipGroup, Dialog, EmptyState, ErrorState, LoadingState, PageHeader, Spinner } from "@/components/ui";

type Filter = "all" | "flagged" | CaseloadFlag;
const FLAG_KEYS = Object.keys(FLAG_META) as CaseloadFlag[];

export default function CoordinatorPage() {
  return (
    <>
      <PageHeader
        title="Coordinator workspace"
        description="Your caseload of patients with active episodes, ordered by an explainable risk score (not a clinical score)."
      />
      <Suspense fallback={<LoadingState label="Loading caseload…" />}>
        <CoordinatorView />
      </Suspense>
    </>
  );
}

function CoordinatorView() {
  const { roles } = useAuth();
  const isCoordinator = roles.includes("coordinator");
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const patientParam = params.get("patient");
  const [filter, setFilter] = useState<Filter>("all");

  const query = useQuery({
    queryKey: ["coordinator", "caseload"],
    queryFn: () => api.coordinator.caseload({ limit: 100 }),
    retry: (count, err) => !(err && typeof err === "object" && "status" in err && err.status === 403) && count < 2,
  });

  const setPatient = useCallback(
    (id: string | null) => {
      const next = new URLSearchParams(params.toString());
      if (id) next.set("patient", id);
      else next.delete("patient");
      const qs = next.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [params, router, pathname],
  );

  const items = useMemo(() => query.data?.items ?? [], [query.data]);
  const counts = useMemo(() => {
    const c: Record<Filter, number> = {
      all: items.length,
      flagged: 0,
      overdue_tasks: 0,
      missed_doses: 0,
      open_safety_event: 0,
      no_contact_7d: 0,
      missed_checkin: 0,
      program_breach: 0,
    };
    for (const it of items) {
      const f = orderedFlags(it.flags);
      if (f.length) c.flagged++;
      for (const k of f) c[k]++;
    }
    return c;
  }, [items]);
  const filtered = useMemo(() => {
    if (filter === "all") return items;
    if (filter === "flagged") return items.filter((i) => orderedFlags(i.flags).length > 0);
    return items.filter((i) => i.flags.includes(filter));
  }, [items, filter]);

  const inCaseload = patientParam ? items.find((i) => i.patient.id === patientParam) : undefined;
  const settled = !query.isPending;

  return (
    <>
      {!isCoordinator && (
        <p className="mb-4 flex items-start gap-2 rounded-2xl border border-[#c9dcf8] bg-sky-bg px-4 py-3 text-sm text-sky-fg">
          <Info className="mt-0.5 size-4 shrink-0" aria-hidden />
          <span>
            The caseload lists episodes assigned to the signed-in coordinator, so it is only available to users with the coordinator role.
            You can still open a patient from the inbox, log contacts, and assign coordinators on{" "}
            <Link href="/ops/episodes" className="font-semibold underline">
              Care episodes
            </Link>
            .
          </span>
        </p>
      )}
      <Card
        title="Caseload"
        subtitle="Click a patient to see episodes, open tasks and the contact log."
        actions={query.isFetching && !query.isPending ? <Spinner label="Refreshing caseload" /> : null}
      >
        {query.isPending ? (
          <LoadingState label="Loading caseload…" rows={4} />
        ) : query.isError ? (
          <ErrorState error={query.error} onRetry={() => void query.refetch()} />
        ) : items.length === 0 ? (
          <EmptyState
            icon={<ClipboardList className="size-6" />}
            title="No patients in your caseload"
            description="Patients appear here when an active care episode is assigned to you."
          />
        ) : (
          <div className="flex flex-col gap-4">
            <ChipGroup<Filter>
              label="Filter caseload"
              value={filter}
              onChange={setFilter}
              options={[
                { value: "all", label: "All", count: counts.all },
                { value: "flagged", label: "Flagged", count: counts.flagged },
                ...FLAG_KEYS.map((f) => ({ value: f, label: FLAG_META[f].label, count: counts[f] })),
              ]}
            />
            <CaseloadTable
              items={filtered}
              selectedPatientId={patientParam}
              onSelect={(it) => setPatient(it.patient.id)}
              empty={<p className="py-6 text-center text-sm text-ink-muted">No patients match this filter.</p>}
            />
          </div>
        )}
      </Card>

      {patientParam && inCaseload && <PatientDrawer item={inCaseload} onClose={() => setPatient(null)} />}
      {patientParam && !inCaseload && settled && <ExternalPatientDrawer patientId={patientParam} onClose={() => setPatient(null)} />}
    </>
  );
}

/** A patient opened via `?patient=` who is not in the caller's caseload (e.g. an ops admin coming from the inbox). */
function ExternalPatientDrawer({ patientId, onClose }: { patientId: string; onClose: () => void }) {
  const patient = useQuery({ queryKey: ["patient", patientId], queryFn: () => api.patients.get(patientId) });
  const episodes = useQuery({
    queryKey: ["episodes", { patientId, active: true }],
    queryFn: () => api.episodes.list({ patientId, active: true, limit: 50 }),
  });

  if (patient.isPending || episodes.isPending) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink/40">
        <Spinner label="Loading patient" />
      </div>
    );
  }
  if (patient.isError || episodes.isError) {
    return (
      <Dialog open onClose={onClose} title="Patient could not be loaded">
        <ErrorState error={patient.error ?? episodes.error} />
      </Dialog>
    );
  }

  const item: CaseloadItem = {
    patient: patient.data,
    episodes: episodes.data.items,
    openTasks: 0,
    overdueTasks: 0,
    nextFollowUpAt: null,
    lastContactAt: null,
    flags: [],
  };
  return <PatientDrawer item={item} onClose={onClose} />;
}

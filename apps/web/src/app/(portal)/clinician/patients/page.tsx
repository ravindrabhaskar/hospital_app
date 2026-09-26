"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Search, UserRound } from "lucide-react";
import { api } from "@/lib/api";
import { formatDate, humanize } from "@/lib/format";
import { Card, EmptyState, Input, PageHeader, QueryView } from "@/components/ui";

export default function ClinicianPatientsPage() {
  const [q, setQ] = useState("");
  const [debounced, setDebounced] = useState("");
  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(q.trim()), 300);
    return () => window.clearTimeout(t);
  }, [q]);

  const query = useQuery({
    queryKey: ["clinician", "patients", debounced],
    queryFn: () => api.clinician.patients({ q: debounced || undefined, limit: 50 }),
  });

  return (
    <>
      <PageHeader
        title="Patients"
        description="Only patients with an appointment, care episode or shared record with you are listed. Opening a snapshot is audited."
      />
      <Card>
        <div className="relative mb-4 max-w-md">
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-ink-muted" aria-hidden />
          <label htmlFor="patient-search" className="sr-only">
            Search patients
          </label>
          <Input
            id="patient-search"
            type="search"
            placeholder="Search by name or phone"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            className="pl-9"
          />
        </div>
        <QueryView
          query={query}
          isEmpty={(d) => d.items.length === 0}
          empty={<EmptyState title="No patients found" description={debounced ? `No match for “${debounced}”.` : "No patients yet."} />}
        >
          {(d) => (
            <ul className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {d.items.map((p) => (
                <li key={p.id}>
                  <Link
                    href={`/clinician/patients/${p.id}`}
                    className="flex items-center gap-3 rounded-2xl border border-line p-4 hover:border-primary-light hover:bg-mint-50"
                  >
                    <span className="flex size-11 items-center justify-center rounded-full bg-mint-100 text-primary" aria-hidden>
                      <UserRound className="size-5" />
                    </span>
                    <span className="min-w-0">
                      <span className="block truncate font-semibold">{p.name}</span>
                      <span className="block text-xs text-ink-muted">
                        {p.age ?? "—"} yrs · {humanize(p.gender)}
                        {p.dob ? ` · DOB ${formatDate(p.dob)}` : ""}
                      </span>
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </QueryView>
      </Card>
    </>
  );
}

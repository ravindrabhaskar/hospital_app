"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { CalendarClock, Search } from "lucide-react";
import { api } from "@/lib/api";
import { formatDateTime, formatINR } from "@/lib/format";
import { Badge, Button, Card, EmptyState, Field, Input, PageHeader, QueryView, Table, Td, Th } from "@/components/ui";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default function AdminDoctorsPage() {
  const router = useRouter();
  const [draft, setDraft] = useState("");
  const [q, setQ] = useState("");
  const [idDraft, setIdDraft] = useState("");
  const [idError, setIdError] = useState<string | undefined>();
  const query = useQuery({
    queryKey: ["admin", "doctors", q],
    queryFn: () => api.doctors.list({ q: q || undefined, limit: 100 }),
  });

  return (
    <>
      <PageHeader title="Doctor schedules" description="Edit a doctor's weekly consultation template. Times are IST." />
      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
        <Card title="Doctors" subtitle="Doctors not accepting bookings are hidden from this list">
          <form
            role="search"
            className="mb-4 flex gap-2"
            onSubmit={(e) => {
              e.preventDefault();
              setQ(draft.trim());
            }}
          >
            <label htmlFor="doctor-search" className="sr-only">
              Search doctors
            </label>
            <Input id="doctor-search" type="search" placeholder="Name or specialty" value={draft} onChange={(e) => setDraft(e.target.value)} />
            <Button type="submit" variant="secondary" icon={<Search className="size-4" aria-hidden />}>
              Search
            </Button>
          </form>
          <QueryView
            query={query}
            isEmpty={(d) => d.items.length === 0}
            empty={<EmptyState title="No doctors found" description={q ? `Nothing matches “${q}”.` : "No doctors are listed yet."} />}
          >
            {(d) => (
              <Table caption="Doctors">
                <thead>
                  <tr>
                    <Th>Doctor</Th>
                    <Th>Languages</Th>
                    <Th className="text-right">Video fee</Th>
                    <Th>Next available</Th>
                    <Th className="text-right">Actions</Th>
                  </tr>
                </thead>
                <tbody>
                  {d.items.map((doc) => (
                    <tr key={doc.id}>
                      <Td>
                        <p className="font-semibold">{doc.name}</p>
                        <p className="text-xs text-ink-muted">{doc.specialtyName || doc.specialty}</p>
                      </Td>
                      <Td className="text-xs">{doc.languages.join(", ") || "—"}</Td>
                      <Td className="text-right tabular-nums">{formatINR(doc.fees.video)}</Td>
                      <Td>{doc.availableNow ? <Badge tone="green">Available now</Badge> : doc.nextAvailableAt ? <span className="whitespace-nowrap text-xs">{formatDateTime(doc.nextAvailableAt)}</span> : <Badge>No slots</Badge>}</Td>
                      <Td className="text-right">
                        <Link
                          href={`/admin/doctors/${encodeURIComponent(doc.id)}/schedule`}
                          className="inline-flex h-9 items-center gap-1.5 rounded-[28px] border border-primary bg-white px-3.5 text-[13px] font-semibold text-primary hover:bg-mint-50"
                          aria-label={`Edit schedule for ${doc.name}`}
                        >
                          <CalendarClock className="size-4" aria-hidden />
                          Edit schedule
                        </Link>
                      </Td>
                    </tr>
                  ))}
                </tbody>
              </Table>
            )}
          </QueryView>
        </Card>
        <Card title="Open by doctor ID">
          <p className="mb-3 text-[13px] text-ink-muted">
            The public doctor list hides doctors who are not accepting bookings. Paste a doctor&apos;s ID to edit their schedule anyway.
          </p>
          <form
            noValidate
            className="flex flex-col gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              const id = idDraft.trim();
              if (!UUID_RE.test(id)) {
                setIdError("Enter a valid doctor ID (UUID)");
                return;
              }
              setIdError(undefined);
              router.push(`/admin/doctors/${encodeURIComponent(id)}/schedule`);
            }}
          >
            <Field label="Doctor ID" required error={idError}>
              {(id, d) => (
                <Input
                  id={id}
                  aria-describedby={d}
                  aria-invalid={!!idError}
                  className="font-mono"
                  placeholder="00000000-0000-0000-0000-000000000000"
                  value={idDraft}
                  onChange={(e) => setIdDraft(e.target.value)}
                />
              )}
            </Field>
            <Button type="submit" className="self-start">
              Open schedule
            </Button>
          </form>
        </Card>
      </div>
    </>
  );
}

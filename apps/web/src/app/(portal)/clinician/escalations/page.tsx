"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { Siren } from "lucide-react";
import { api } from "@/lib/api";
import { Card, EmptyState, PageHeader, QueryView } from "@/components/ui";
import { SafetyEventList } from "@/components/safety-events";

export default function ClinicianEscalationsPage() {
  const query = useQuery({ queryKey: ["clinician", "escalations"], queryFn: () => api.clinician.escalations({ limit: 100 }), refetchInterval: 30_000 });
  return (
    <>
      <PageHeader title="Escalations" description="Safety events for your patients. Emergencies are listed first." />
      <Card>
        <QueryView
          query={query}
          isEmpty={(d) => d.items.length === 0}
          empty={<EmptyState title="No escalations" description="No safety events need your attention." icon={<Siren className="size-6" />} />}
        >
          {(d) => (
            <SafetyEventList
              events={d.items}
              renderPatient={(e) => (
                <Link href={`/clinician/patients/${e.patientId}`} className="font-semibold text-primary hover:underline">
                  {e.patientName}
                </Link>
              )}
            />
          )}
        </QueryView>
      </Card>
    </>
  );
}

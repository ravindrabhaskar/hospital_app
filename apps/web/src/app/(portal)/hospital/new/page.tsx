"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import { DischargeForm } from "@/components/discharge-form";
import { PageHeader } from "@/components/ui";

export default function NewDischargePage() {
  const router = useRouter();
  const qc = useQueryClient();
  return (
    <>
      <Link href="/hospital" className="mb-3 inline-flex items-center gap-1 text-sm font-medium text-primary-light hover:underline">
        <ArrowLeft className="size-4" aria-hidden /> Discharges
      </Link>
      <PageHeader title="New discharge" description="Enrol a discharged patient in the 30-day post-discharge program." />
      <div className="max-w-4xl">
        <DischargeForm
          onCreated={(d) => {
            void qc.invalidateQueries({ queryKey: ["discharges"] });
            router.push(`/hospital/discharges/${d.id}`);
          }}
        />
      </div>
    </>
  );
}

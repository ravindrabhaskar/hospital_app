"use client";

import { use } from "react";
import Link from "next/link";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import { api } from "@/lib/api";
import type { Schedule, WeeklyBlock } from "@/lib/api/types";
import { LeavesPanel, ScheduleEditor, SlotsPreview, slotsQueryKey } from "@/components/schedule-editor";
import { useToast } from "@/components/toast";
import { PageHeader, QueryView } from "@/components/ui";

export default function AdminDoctorSchedulePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const qc = useQueryClient();
  const toast = useToast();
  const key = ["admin", "doctor-schedule", id];
  const schedule = useQuery({ queryKey: key, queryFn: () => api.adminSchedules.get(id) });
  // Optional: the public profile 404s for doctors hidden from /doctors; the page works without it.
  const doctor = useQuery({ queryKey: ["doctor", id], queryFn: () => api.doctors.get(id), retry: false });

  const save = useMutation({
    mutationFn: (weekly: WeeklyBlock[]) => api.adminSchedules.save(id, weekly),
    onSuccess: (s) => {
      qc.setQueryData<Schedule>(key, s);
      void qc.invalidateQueries({ queryKey: key });
      void qc.invalidateQueries({ queryKey: slotsQueryKey(id) });
      toast.success("Schedule saved", `Unbooked slots for the next ${s.horizonDays} days were regenerated.`);
    },
    onError: (e) => toast.apiError(e, "Could not save the schedule"),
  });

  const name = doctor.data?.name;
  return (
    <>
      <Link
        href="/admin/doctors"
        className="mb-3 inline-flex items-center gap-1.5 rounded-full text-sm font-medium text-primary hover:underline focus-visible:outline-2 focus-visible:outline-primary-light"
      >
        <ArrowLeft className="size-4" aria-hidden />
        Back to doctors
      </Link>
      <PageHeader
        title={name ? `Schedule: ${name}` : "Doctor schedule"}
        description={
          <>
            {doctor.data ? `${doctor.data.specialtyName || doctor.data.specialty} · ` : ""}
            <span className="font-mono text-xs">{id}</span>
          </>
        }
      />
      <QueryView query={schedule} loadingRows={6}>
        {(s) => (
          <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_380px]">
            <div className="flex min-w-0 flex-col gap-5">
              <ScheduleEditor schedule={s} saving={save.isPending} onSave={(weekly) => save.mutateAsync(weekly)} />
              <SlotsPreview doctorId={id} />
            </div>
            <div className="min-w-0">
              <LeavesPanel leaves={s.leaves} readOnlyNote="Leaves are managed by the doctor. Admins can view them here but cannot add or remove them." />
            </div>
          </div>
        )}
      </QueryView>
    </>
  );
}

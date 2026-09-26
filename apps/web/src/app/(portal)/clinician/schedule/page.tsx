"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Schedule, WeeklyBlock } from "@/lib/api/types";
import { LeavesPanel, ScheduleEditor, SlotsPreview, slotsQueryKey } from "@/components/schedule-editor";
import { useToast } from "@/components/toast";
import { PageHeader, QueryView } from "@/components/ui";

const SCHEDULE_KEY = ["doctor", "me", "schedule"];
const PROFILE_KEY = ["doctor", "me", "profile"];

export default function ClinicianSchedulePage() {
  const qc = useQueryClient();
  const toast = useToast();
  const schedule = useQuery({ queryKey: SCHEDULE_KEY, queryFn: () => api.doctorSelf.schedule() });
  const profile = useQuery({ queryKey: PROFILE_KEY, queryFn: () => api.doctorSelf.profile() });
  const doctorId = profile.data?.id;

  const refreshSlots = () => {
    if (doctorId) void qc.invalidateQueries({ queryKey: slotsQueryKey(doctorId) });
  };

  const save = useMutation({
    mutationFn: (weekly: WeeklyBlock[]) => api.doctorSelf.saveSchedule(weekly),
    onSuccess: (s) => {
      qc.setQueryData<Schedule>(SCHEDULE_KEY, s);
      void qc.invalidateQueries({ queryKey: SCHEDULE_KEY });
      refreshSlots();
      toast.success("Schedule saved", `Unbooked slots for the next ${s.horizonDays} days were regenerated.`);
    },
    onError: (e) => toast.apiError(e, "Could not save the schedule"),
  });

  const afterLeaveChange = () => {
    void qc.invalidateQueries({ queryKey: SCHEDULE_KEY });
    refreshSlots();
  };

  return (
    <>
      <PageHeader
        title="Schedule & leaves"
        description="Set your weekly consultation hours and days off. All times are Asia/Kolkata (IST)."
      />
      <QueryView query={schedule} loadingRows={6}>
        {(s) => (
          <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_380px]">
            <div className="flex min-w-0 flex-col gap-5">
              <ScheduleEditor schedule={s} saving={save.isPending} onSave={(weekly) => save.mutateAsync(weekly)} />
              {doctorId ? (
                <SlotsPreview doctorId={doctorId} />
              ) : profile.isError ? (
                <p className="text-sm text-ink-muted">The slot preview is unavailable because your doctor profile could not be loaded.</p>
              ) : null}
            </div>
            <div className="min-w-0">
              <LeavesPanel
                leaves={s.leaves}
                onAdd={async (input) => {
                  const res = await api.doctorSelf.addLeave(input);
                  afterLeaveChange();
                  return res;
                }}
                onRemove={async (id) => {
                  await api.doctorSelf.removeLeave(id);
                  afterLeaveChange();
                }}
              />
            </div>
          </div>
        )}
      </QueryView>
    </>
  );
}

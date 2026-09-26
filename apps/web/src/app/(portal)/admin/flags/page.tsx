"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { OctagonX } from "lucide-react";
import { api } from "@/lib/api";
import type { FeatureFlag } from "@/lib/api/types";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, Dialog, EmptyState, Input, PageHeader, QueryView, Toggle, cx } from "@/components/ui";

const KILL_SWITCH = "kill_switch_ai";

export default function FlagsPage() {
  const query = useQuery({ queryKey: ["admin", "flags"], queryFn: () => api.admin.featureFlags() });
  const [confirmKill, setConfirmKill] = useState<boolean | null>(null);
  const qc = useQueryClient();
  const toast = useToast();

  const set = useMutation({
    mutationFn: (v: { key: string; enabled: boolean; cohort?: string }) =>
      api.admin.setFeatureFlag(v.key, { enabled: v.enabled, ...(v.cohort !== undefined ? { cohort: v.cohort } : {}) }),
    onSuccess: (_r, v) => {
      toast.success(`${v.key} ${v.enabled ? "enabled" : "disabled"}`);
      void qc.invalidateQueries({ queryKey: ["admin", "flags"] });
    },
    onError: (e) => toast.apiError(e, "Could not update flag"),
  });

  return (
    <>
      <PageHeader title="Feature flags" description="Changes apply immediately and are audited." />
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No flags" />}>
        {(d) => {
          const kill = d.items.find((f) => f.key === KILL_SWITCH);
          const rest = d.items.filter((f) => f.key !== KILL_SWITCH);
          return (
            <div className="flex flex-col gap-5">
              {kill && (
                <section
                  aria-labelledby="kill-heading"
                  className={cx("rounded-[20px] border-2 p-5", kill.enabled ? "border-danger bg-rose-bg" : "border-[#f6c9c9] bg-white")}
                >
                  <div className="flex flex-wrap items-center justify-between gap-4">
                    <div className="flex items-start gap-3">
                      <OctagonX className="mt-0.5 size-7 shrink-0 text-danger" aria-hidden />
                      <div>
                        <h2 id="kill-heading" className="text-lg font-bold text-danger-dark">
                          AI kill switch {kill.enabled ? <Badge tone="red">ENGAGED</Badge> : <Badge tone="neutral">Off</Badge>}
                        </h2>
                        <p className="text-sm text-ink">
                          When on, every AI call returns the safe fallback immediately and routes patients to a doctor. The deterministic safety
                          engine keeps running.
                        </p>
                        <p className="text-xs text-ink-muted">{kill.description}</p>
                      </div>
                    </div>
                    <Button variant={kill.enabled ? "secondary" : "danger"} onClick={() => setConfirmKill(!kill.enabled)}>
                      {kill.enabled ? "Disengage kill switch" : "Engage kill switch"}
                    </Button>
                  </div>
                </section>
              )}
              <Card title="Flags">
                <ul className="flex flex-col divide-y divide-line">
                  {rest.map((f) => (
                    <FlagRow key={f.key} flag={f} pending={set.isPending && set.variables?.key === f.key} onSet={(enabled, cohort) => set.mutate({ key: f.key, enabled, cohort })} />
                  ))}
                </ul>
              </Card>
            </div>
          );
        }}
      </QueryView>
      {confirmKill !== null && (
        <Dialog
          open
          onClose={() => setConfirmKill(null)}
          title={confirmKill ? "Engage the AI kill switch?" : "Disengage the AI kill switch?"}
          description={confirmKill ? "All AI assistant replies stop immediately and patients see the fallback message." : "AI replies resume for all users."}
          footer={
            <>
              <Button variant="ghost" onClick={() => setConfirmKill(null)}>
                Cancel
              </Button>
              <Button
                variant={confirmKill ? "danger" : "primary"}
                loading={set.isPending}
                onClick={() => set.mutate({ key: KILL_SWITCH, enabled: confirmKill }, { onSettled: () => setConfirmKill(null) })}
              >
                {confirmKill ? "Engage" : "Disengage"}
              </Button>
            </>
          }
        >
          <p className="text-sm text-ink-muted">This action is recorded in the audit log.</p>
        </Dialog>
      )}
    </>
  );
}

function FlagRow({ flag, onSet, pending }: { flag: FeatureFlag; onSet: (enabled: boolean, cohort?: string) => void; pending: boolean }) {
  const [cohort, setCohort] = useState(flag.cohort ?? "");
  const dirty = (flag.cohort ?? "") !== cohort;
  return (
    <li className="flex flex-wrap items-center justify-between gap-3 py-3">
      <div className="min-w-0">
        <p className="font-mono text-sm font-semibold">{flag.key}</p>
        <p className="text-[13px] text-ink-muted">{flag.description}</p>
      </div>
      <div className="flex items-center gap-2">
        <label className="sr-only" htmlFor={`cohort-${flag.key}`}>
          Cohort for {flag.key}
        </label>
        <Input id={`cohort-${flag.key}`} className="h-9 w-36 text-xs" placeholder="Cohort (all)" value={cohort} onChange={(e) => setCohort(e.target.value)} />
        {dirty && (
          <Button size="sm" variant="secondary" loading={pending} onClick={() => onSet(flag.enabled, cohort)}>
            Save
          </Button>
        )}
        <Toggle checked={flag.enabled} disabled={pending} label={`${flag.key} ${flag.enabled ? "enabled" : "disabled"}`} onChange={(v) => onSet(v)} />
      </div>
    </li>
  );
}

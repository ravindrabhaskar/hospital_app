"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, BadgeCheck, Ban, Star, XCircle } from "lucide-react";
import { api } from "@/lib/api";
import type { OpsProvider, VerificationStatus } from "@/lib/api/types";
import { formatDate, humanize } from "@/lib/format";
import { credentialWarning } from "@/lib/ops";
import { useAuth } from "@/lib/auth";
import { canVerifyProviders } from "@/lib/roles";
import { VerificationBadge } from "@/components/status";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, ChipGroup, Dialog, EmptyState, Field, PageHeader, QueryView, Table, Td, Textarea, Th } from "@/components/ui";

type Filter = "all" | VerificationStatus;
type Decision = "verified" | "rejected" | "suspended";

export default function ProvidersPage() {
  const { roles } = useAuth();
  const canVerify = canVerifyProviders(roles);
  const [filter, setFilter] = useState<Filter>("all");
  const [action, setAction] = useState<{ provider: OpsProvider; decision: Decision } | null>(null);
  const query = useQuery({
    queryKey: ["ops", "providers", filter],
    queryFn: () => api.ops.providers({ status: filter === "all" ? undefined : filter, limit: 100 }),
  });

  return (
    <>
      <PageHeader
        title="Providers"
        description={canVerify ? "Verify credentials and manage provider status. Every action is audited." : "Read-only for coordinators. Verification needs an ops admin."}
      />
      <Card>
        <div className="mb-4">
          <ChipGroup
            label="Verification status"
            value={filter}
            onChange={setFilter}
            options={[
              { value: "all", label: "All" },
              { value: "pending", label: "Pending" },
              { value: "verified", label: "Verified" },
              { value: "expired", label: "Expired" },
              { value: "suspended", label: "Suspended" },
              { value: "rejected", label: "Rejected" },
            ]}
          />
        </div>
        <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No providers" />}>
          {(d) => (
            <Table caption="Providers">
              <thead>
                <tr>
                  <Th>Provider</Th>
                  <Th>Verification</Th>
                  <Th>Credential expiry</Th>
                  <Th>Duty</Th>
                  <Th>Zones</Th>
                  <Th className="text-right">Today</Th>
                  {canVerify && <Th className="text-right">Actions</Th>}
                </tr>
              </thead>
              <tbody>
                {d.items.map((p) => {
                  const warn = credentialWarning(p);
                  return (
                    <tr key={p.id}>
                      <Td>
                        <p className="font-semibold">{p.name}</p>
                        <p className="text-xs text-ink-muted">
                          {humanize(p.type)} · {p.qualification} · {p.phone}
                        </p>
                        {p.rating !== null && (
                          <p className="flex items-center gap-1 text-xs text-ink-muted">
                            <Star className="size-3" aria-hidden /> {p.rating.toFixed(1)}
                          </p>
                        )}
                      </Td>
                      <Td>
                        <VerificationBadge status={p.verificationStatus} />
                      </Td>
                      <Td>
                        <span className="whitespace-nowrap">{formatDate(p.credentialExpiresAt)}</span>
                        {warn === "expired" && (
                          <div className="mt-1">
                            <Badge tone="red" icon={<AlertTriangle className="size-3" aria-hidden />}>
                              Expired: never matched
                            </Badge>
                          </div>
                        )}
                        {warn === "soon" && (
                          <div className="mt-1">
                            <Badge tone="amber" icon={<AlertTriangle className="size-3" aria-hidden />}>
                              Expires within 30 days
                            </Badge>
                          </div>
                        )}
                      </Td>
                      <Td>
                        <Badge tone={p.status === "available" ? "green" : p.status === "on_visit" ? "sky" : "neutral"}>{humanize(p.status)}</Badge>
                        <p className="mt-1 text-xs text-ink-muted">{p.onDuty ? "On duty" : "Off duty"}</p>
                      </Td>
                      <Td className="text-[13px]">{p.zones.join(", ") || "—"}</Td>
                      <Td className="text-right tabular-nums">{p.visitsToday}</Td>
                      {canVerify && (
                        <Td className="text-right">
                          <div className="flex flex-wrap justify-end gap-1.5">
                            {p.verificationStatus !== "verified" && (
                              <Button size="sm" onClick={() => setAction({ provider: p, decision: "verified" })} icon={<BadgeCheck className="size-4" aria-hidden />}>
                                Verify
                              </Button>
                            )}
                            {p.verificationStatus === "pending" && (
                              <Button size="sm" variant="secondary" onClick={() => setAction({ provider: p, decision: "rejected" })} icon={<XCircle className="size-4" aria-hidden />}>
                                Reject
                              </Button>
                            )}
                            {p.verificationStatus === "verified" && (
                              <Button size="sm" variant="secondary" onClick={() => setAction({ provider: p, decision: "suspended" })} icon={<Ban className="size-4" aria-hidden />}>
                                Suspend
                              </Button>
                            )}
                          </div>
                        </Td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </Table>
          )}
        </QueryView>
      </Card>
      {action && <VerificationDialog provider={action.provider} decision={action.decision} onClose={() => setAction(null)} />}
    </>
  );
}

function VerificationDialog({ provider, decision, onClose }: { provider: OpsProvider; decision: Decision; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const m = useMutation({
    mutationFn: () => api.ops.verifyProvider(provider.id, { status: decision, note: note.trim() }),
    onSuccess: () => {
      toast.success(`Provider ${decision}`);
      void qc.invalidateQueries({ queryKey: ["ops", "providers"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not update verification"),
  });
  const verb = decision === "verified" ? "Verify" : decision === "rejected" ? "Reject" : "Suspend";
  return (
    <Dialog
      open
      onClose={onClose}
      title={`${verb} ${provider.name}`}
      description={decision === "verified" ? "Confirm that the credential documents have been checked." : "The provider will not be matched to visits."}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant={decision === "verified" ? "primary" : "danger"}
            loading={m.isPending}
            onClick={() => {
              if (!note.trim()) {
                setError("A note is required for the audit trail");
                return;
              }
              m.mutate();
            }}
          >
            {verb}
          </Button>
        </>
      }
    >
      <Field label="Note" required error={error ?? undefined} hint="Recorded in the audit log.">
        {(id, d) => (
          <Textarea
            id={id}
            aria-describedby={d}
            aria-invalid={!!error}
            data-autofocus
            value={note}
            onChange={(e) => {
              setNote(e.target.value);
              setError(null);
            }}
          />
        )}
      </Field>
    </Dialog>
  );
}

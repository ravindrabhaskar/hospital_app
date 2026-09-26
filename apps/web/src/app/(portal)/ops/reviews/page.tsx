"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { CheckCircle2, Star, XCircle } from "lucide-react";
import { api } from "@/lib/api";
import type { Review, ReviewStatus } from "@/lib/api/types";
import { formatDateTime, humanize } from "@/lib/format";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, ChipGroup, Dialog, EmptyState, Field, PageHeader, QueryView, Textarea, cx, type Tone } from "@/components/ui";

const STATUS_TONE: Record<ReviewStatus, Tone> = { pending: "amber", published: "green", rejected: "red" };
type Action = { review: Review; status: "published" | "rejected" };

export default function ReviewsPage() {
  const [filter, setFilter] = useState<ReviewStatus>("pending");
  const [action, setAction] = useState<Action | null>(null);
  const query = useQuery({
    queryKey: ["ops", "reviews", filter],
    queryFn: () => api.reviews.list({ status: filter, limit: 100 }),
  });

  return (
    <>
      <PageHeader title="Reviews" description="Reviews with text wait here for moderation before they appear on doctor and provider profiles." />
      <Card>
        <div className="mb-4">
          <ChipGroup
            label="Review status"
            value={filter}
            onChange={setFilter}
            options={[
              { value: "pending", label: "Pending" },
              { value: "published", label: "Published" },
              { value: "rejected", label: "Rejected" },
            ]}
          />
        </div>
        <QueryView
          query={query}
          isEmpty={(d) => d.items.length === 0}
          empty={<EmptyState title={filter === "pending" ? "No reviews waiting" : `No ${filter} reviews`} />}
        >
          {(d) => (
            <ul className="grid gap-3 lg:grid-cols-2">
              {d.items.map((r) => (
                <li key={r.id}>
                  <article className="flex h-full flex-col gap-2 rounded-xl border border-line bg-white p-4" aria-label={`Review of ${r.subjectName}`}>
                    <div className="flex flex-wrap items-start justify-between gap-2">
                      <div>
                        <p className="font-semibold">{r.subjectName}</p>
                        <p className="text-xs text-ink-muted">{humanize(r.targetType)}</p>
                      </div>
                      <Badge tone={STATUS_TONE[r.status]}>{humanize(r.status)}</Badge>
                    </div>
                    <Stars rating={r.rating} />
                    {r.text ? <p className="whitespace-pre-wrap text-sm">{r.text}</p> : <p className="text-sm italic text-ink-muted">Rating only</p>}
                    <p className="text-xs text-ink-muted">
                      {r.authorLabel} · {formatDateTime(r.createdAt)}
                    </p>
                    {r.moderationNote && (
                      <p className="rounded-lg bg-mint-50 px-3 py-2 text-xs">
                        <span className="font-semibold">Moderation note:</span> {r.moderationNote}
                      </p>
                    )}
                    {r.status === "pending" && (
                      <div className="mt-auto flex flex-wrap justify-end gap-2 pt-1">
                        <Button size="sm" variant="secondary" onClick={() => setAction({ review: r, status: "rejected" })} icon={<XCircle className="size-4" aria-hidden />}>
                          Reject
                        </Button>
                        <Button size="sm" onClick={() => setAction({ review: r, status: "published" })} icon={<CheckCircle2 className="size-4" aria-hidden />}>
                          Publish
                        </Button>
                      </div>
                    )}
                  </article>
                </li>
              ))}
            </ul>
          )}
        </QueryView>
      </Card>
      {action && <ModerateDialog action={action} onClose={() => setAction(null)} />}
    </>
  );
}

function Stars({ rating }: { rating: number }) {
  const n = Math.max(0, Math.min(5, Math.round(rating)));
  return (
    <p className="flex items-center gap-0.5" role="img" aria-label={`${n} of 5 stars`}>
      {Array.from({ length: 5 }).map((_, i) => (
        <Star key={i} aria-hidden className={cx("size-4", i < n ? "fill-[#f5a623] text-[#f5a623]" : "text-line")} />
      ))}
    </p>
  );
}

function ModerateDialog({ action, onClose }: { action: Action; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const publish = action.status === "published";

  const m = useMutation({
    mutationFn: () => api.reviews.moderate(action.review.id, { status: action.status, ...(note.trim() ? { note: note.trim() } : {}) }),
    onSuccess: () => {
      toast.success(publish ? "Review published" : "Review rejected");
      void qc.invalidateQueries({ queryKey: ["ops", "reviews"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Moderation failed"),
  });

  const submit = () => {
    if (note.trim().length > 1000) return setError("At most 1000 characters");
    setError(null);
    m.mutate();
  };

  return (
    <Dialog
      open
      onClose={onClose}
      title={publish ? "Publish review" : "Reject review"}
      description={`${action.review.subjectName} · ${action.review.rating} of 5 stars`}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant={publish ? "primary" : "danger"} loading={m.isPending} onClick={submit}>
            {publish ? "Publish" : "Reject"}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        {action.review.text && <blockquote className="rounded-lg bg-mint-50 px-3 py-2 text-sm">{action.review.text}</blockquote>}
        <Field
          label="Moderation note (optional)"
          error={error ?? undefined}
          hint={publish ? "Internal note, audited." : "Recommended: say why the review was rejected."}
        >
          {(id, d) => (
            <Textarea id={id} data-autofocus aria-describedby={d} aria-invalid={!!error} value={note} onChange={(e) => setNote(e.target.value)} />
          )}
        </Field>
      </div>
    </Dialog>
  );
}

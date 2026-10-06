"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Pencil, Plus, Ticket } from "lucide-react";
import { api } from "@/lib/api";
import type { Coupon, CouponInput } from "@/lib/api/types";
import { describeCoupon } from "@/lib/coupons";
import { formatDate, humanize, isoToISTDate, todayIST } from "@/lib/format";
import { CouponForm } from "@/components/coupon-form";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, Dialog, EmptyState, PageHeader, QueryView, Table, Td, Th } from "@/components/ui";

const KEY = ["admin", "coupons"];

export default function CouponsPage() {
  const [editing, setEditing] = useState<Coupon | "new" | null>(null);
  const query = useQuery({ queryKey: KEY, queryFn: () => api.coupons.list({ limit: 100 }) });
  const today = todayIST();
  return (
    <>
      <PageHeader
        title="Coupons"
        description="Discount codes for bookings. Wallet credit and coupons are [REQUIRES LEGAL REVIEW: RBI PPI rules]."
        actions={
          <Button onClick={() => setEditing("new")} icon={<Plus className="size-4" aria-hidden />}>
            New coupon
          </Button>
        }
      />
      <Card>
        <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState icon={<Ticket className="size-6" />} title="No coupons yet" />}>
          {(d) => (
            <Table caption="Coupons">
              <thead>
                <tr>
                  <Th>Code</Th>
                  <Th>Offer</Th>
                  <Th>Applies to</Th>
                  <Th>Validity</Th>
                  <Th>Limits</Th>
                  <Th>Status</Th>
                  <Th />
                </tr>
              </thead>
              <tbody>
                {d.items.map((c) => {
                  const expired = isoToISTDate(c.validTo) < today;
                  return (
                    <tr key={c.id}>
                      <Td>
                        <span className="font-mono font-semibold">{c.code}</span>
                        <span className="block max-w-[220px] text-xs text-ink-muted">{c.description}</span>
                      </Td>
                      <Td className="text-[13px]">{describeCoupon({ type: c.type, value: c.value, maxDiscount: c.maxDiscount ?? undefined, minAmount: c.minAmount ?? undefined })}</Td>
                      <Td className="text-[13px]">{c.appliesTo.map(humanize).join(", ")}</Td>
                      <Td className="whitespace-nowrap text-[13px]">
                        {formatDate(c.validFrom)} – {formatDate(c.validTo)}
                      </Td>
                      <Td className="text-[13px]">
                        {c.perUserLimit}/user{c.usageLimit ? ` · ${c.usageLimit} total` : ""}
                        {c.usedCount !== undefined && <span className="block text-xs text-ink-muted">{c.usedCount} used</span>}
                      </Td>
                      <Td>{expired ? <Badge>Expired</Badge> : c.active ? <Badge tone="green">Active</Badge> : <Badge tone="amber">Inactive</Badge>}</Td>
                      <Td>
                        <Button size="sm" variant="ghost" onClick={() => setEditing(c)} aria-label={`Edit ${c.code}`} icon={<Pencil className="size-4" aria-hidden />}>
                          Edit
                        </Button>
                      </Td>
                    </tr>
                  );
                })}
              </tbody>
            </Table>
          )}
        </QueryView>
      </Card>
      {editing && <CouponDialog coupon={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
    </>
  );
}

function CouponDialog({ coupon, onClose }: { coupon: Coupon | null; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const m = useMutation({
    mutationFn: (input: CouponInput) => {
      if (!coupon) return api.coupons.create(input);
      const { code: _code, ...rest } = input;
      void _code;
      return api.coupons.update(coupon.id, rest);
    },
    onSuccess: (c) => {
      toast.success(coupon ? "Coupon updated" : "Coupon created", c.code);
      void qc.invalidateQueries({ queryKey: KEY });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not save the coupon"),
  });
  return (
    <Dialog
      open
      size="lg"
      onClose={onClose}
      title={coupon ? `Edit ${coupon.code}` : "New coupon"}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="coupon-form" loading={m.isPending}>
            {coupon ? "Save changes" : "Create coupon"}
          </Button>
        </>
      }
    >
      <CouponForm coupon={coupon} formId="coupon-form" onSubmit={(input) => m.mutate(input)} />
    </Dialog>
  );
}

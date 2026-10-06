"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { FileText, Undo2 } from "lucide-react";
import { api } from "@/lib/api";
import type { OpsPayment, PaymentStatus } from "@/lib/api/types";
import { ApiError } from "@/lib/api/http";
import { formatDateTime, formatINR, humanize } from "@/lib/format";
import { useAuth } from "@/lib/auth";
import { canRefund, canViewInvoices } from "@/lib/roles";
import { PaymentStatusBadge } from "@/components/status";
import { BlobButton } from "@/components/blob-actions";
import { InvoiceView } from "@/components/invoice-view";
import { useToast } from "@/components/toast";
import { Button, Card, ChipGroup, Dialog, EmptyState, ErrorState, Field, Input, LoadingState, PageHeader, QueryView, Table, Td, Textarea, Th } from "@/components/ui";

const INVOICEABLE: PaymentStatus[] = ["succeeded", "refunded", "partially_refunded"];

type Filter = "all" | PaymentStatus;

export default function PaymentsPage() {
  const { roles } = useAuth();
  const refundAllowed = canRefund(roles);
  const invoicesAllowed = canViewInvoices(roles);
  const [filter, setFilter] = useState<Filter>("all");
  const [refunding, setRefunding] = useState<OpsPayment | null>(null);
  const [invoiceFor, setInvoiceFor] = useState<OpsPayment | null>(null);
  const query = useQuery({
    queryKey: ["ops", "payments", filter],
    queryFn: () => api.ops.payments({ status: filter === "all" ? undefined : filter, limit: 100 }),
  });

  return (
    <>
      <PageHeader title="Payments" description={refundAllowed ? "Amounts in ₹. Refunds are audited." : "Amounts in ₹. Refunds require an ops admin."} />
      <Card>
        <div className="mb-4">
          <ChipGroup
            label="Payment status"
            value={filter}
            onChange={setFilter}
            options={[
              { value: "all", label: "All" },
              { value: "pending", label: "Pending" },
              { value: "succeeded", label: "Succeeded" },
              { value: "failed", label: "Failed" },
              { value: "partially_refunded", label: "Partially refunded" },
              { value: "refunded", label: "Refunded" },
            ]}
          />
        </div>
        <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No payments" />}>
          {(d) => (
            <Table caption="Payments">
              <thead>
                <tr>
                  <Th>Created</Th>
                  <Th>Patient</Th>
                  <Th>Purpose</Th>
                  <Th className="text-right">Amount</Th>
                  <Th className="text-right">Refunded</Th>
                  <Th>Status</Th>
                  <Th>Gateway</Th>
                  <Th className="text-right">Actions</Th>
                </tr>
              </thead>
              <tbody>
                {d.items.map((p) => (
                  <tr key={p.id}>
                    <Td className="whitespace-nowrap">{formatDateTime(p.createdAt)}</Td>
                    <Td className="font-semibold">{p.patientName}</Td>
                    <Td>{humanize(p.purpose)}</Td>
                    <Td className="text-right tabular-nums">{formatINR(p.amount)}</Td>
                    <Td className="text-right tabular-nums">{p.refundedAmount ? formatINR(p.refundedAmount) : "—"}</Td>
                    <Td>
                      <PaymentStatusBadge status={p.status} />
                    </Td>
                    <Td className="text-xs text-ink-muted">
                      {humanize(p.gateway)}
                      <span className="block font-mono">{p.gatewayOrderId}</span>
                    </Td>
                    <Td className="text-right">
                      <div className="flex flex-wrap justify-end gap-2">
                        {invoicesAllowed && INVOICEABLE.includes(p.status) && (
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => setInvoiceFor(p)}
                            icon={<FileText className="size-4" aria-hidden />}
                            aria-label={`View invoice for ${p.patientName}, ${formatINR(p.amount)}`}
                          >
                            View invoice
                          </Button>
                        )}
                        {refundAllowed && (p.status === "succeeded" || p.status === "partially_refunded") && (
                          <Button size="sm" variant="secondary" onClick={() => setRefunding(p)} icon={<Undo2 className="size-4" aria-hidden />}>
                            Refund
                          </Button>
                        )}
                      </div>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </QueryView>
      </Card>
      {refunding && <RefundDialog payment={refunding} onClose={() => setRefunding(null)} />}
      {invoicesAllowed && invoiceFor && <InvoiceDialog payment={invoiceFor} onClose={() => setInvoiceFor(null)} />}
    </>
  );
}

function RefundDialog({ payment, onClose }: { payment: OpsPayment; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const refundable = payment.amount - (payment.refundedAmount ?? 0);
  const [reason, setReason] = useState("");
  const [amount, setAmount] = useState(String(refundable));
  const [errors, setErrors] = useState<{ reason?: string; amount?: string }>({});

  const m = useMutation({
    mutationFn: (input: { reason: string; amount?: number }) => api.ops.refund(payment.id, input),
    onSuccess: () => {
      toast.success("Refund initiated");
      void qc.invalidateQueries({ queryKey: ["ops", "payments"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Refund failed"),
  });

  const submit = () => {
    const next: typeof errors = {};
    const n = Number(amount);
    if (!reason.trim()) next.reason = "A reason is required";
    if (!Number.isInteger(n) || n <= 0) next.amount = "Enter a whole rupee amount greater than 0";
    else if (n > refundable) next.amount = `At most ${formatINR(refundable)}`;
    setErrors(next);
    if (Object.keys(next).length) return;
    // Omit amount for a full refund (contract: amount is optional).
    m.mutate({ reason: reason.trim(), ...(n === refundable && payment.refundedAmount === 0 ? {} : { amount: n }) });
  };

  return (
    <Dialog
      open
      onClose={onClose}
      title="Refund payment"
      description={`${payment.patientName} · ${humanize(payment.purpose)} · paid ${formatINR(payment.amount)}`}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="danger" loading={m.isPending} onClick={submit}>
            Refund {amount && Number(amount) > 0 ? formatINR(Number(amount)) : ""}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label="Amount (₹)" required error={errors.amount} hint={`Refundable: ${formatINR(refundable)}`}>
          {(id, d) => (
            <Input id={id} data-autofocus type="number" min={1} max={refundable} step={1} inputMode="numeric" aria-describedby={d} aria-invalid={!!errors.amount} value={amount} onChange={(e) => setAmount(e.target.value)} />
          )}
        </Field>
        <Field label="Reason" required error={errors.reason}>
          {(id, d) => <Textarea id={id} aria-describedby={d} aria-invalid={!!errors.reason} value={reason} onChange={(e) => setReason(e.target.value)} />}
        </Field>
      </div>
    </Dialog>
  );
}

function InvoiceDialog({ payment, onClose }: { payment: OpsPayment; onClose: () => void }) {
  const query = useQuery({
    queryKey: ["payments", payment.id, "invoice"],
    queryFn: () => api.invoices.get(payment.id),
    retry: (count, e) => !(e instanceof ApiError && e.status < 500) && count < 2,
  });
  const notInvoiceable = query.error instanceof ApiError && (query.error.status === 409 || query.error.code === "CONFLICT");
  const number = query.data?.number;

  return (
    <Dialog
      open
      size="lg"
      onClose={onClose}
      title={number ? `Invoice ${number}` : "Invoice"}
      description={`${payment.patientName} · ${humanize(payment.purpose)} · ${formatINR(payment.amount)}`}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Close
          </Button>
          {number && (
            <BlobButton
              label="Download PDF"
              size="md"
              load={() => api.invoices.pdf(payment.id)}
              fileName={`invoice-${number.replace(/\//g, "-")}.pdf`}
              errorTitle="Could not download the invoice"
            />
          )}
        </>
      }
    >
      {query.isPending ? (
        <LoadingState label="Loading invoice…" />
      ) : notInvoiceable ? (
        <EmptyState title="No invoice for this payment" description="Invoices are issued only for succeeded or refunded payments." />
      ) : query.isError ? (
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      ) : (
        <InvoiceView invoice={query.data} />
      )}
    </Dialog>
  );
}

"use client";

import type { Invoice } from "@/lib/api/types";
import { formatDate, formatINR } from "@/lib/format";

/** Tax rate from the API: values ≤ 1 are treated as fractions (0.18 → 18%). */
function formatRate(rate: number): string {
  const pct = rate > 0 && rate <= 1 ? rate * 100 : rate;
  return `${Number(pct.toFixed(2))}%`;
}

export function InvoiceView({ invoice }: { invoice: Invoice }) {
  return (
    <article aria-label={`Invoice ${invoice.number}`} className="flex flex-col gap-4 text-sm">
      <header className="flex flex-wrap items-start justify-between gap-3 border-b border-line pb-3">
        <div>
          <p className="text-xs font-semibold uppercase tracking-wide text-ink-muted">Tax invoice</p>
          <p className="font-mono text-base font-semibold">{invoice.number}</p>
          <p className="text-xs text-ink-muted">Issued {formatDate(invoice.issuedAt)} (IST)</p>
        </div>
        <div className="text-right">
          <p className="font-semibold">{invoice.seller.legalName}</p>
          <p className="whitespace-pre-line text-xs text-ink-muted">{invoice.seller.address}</p>
          <p className="text-xs text-ink-muted">GSTIN: {invoice.seller.gstin ?? "Not registered"}</p>
        </div>
      </header>

      <section>
        <p className="text-xs font-semibold uppercase tracking-wide text-ink-muted">Billed to</p>
        <p className="font-semibold">{invoice.billedTo.name}</p>
        <p className="text-xs text-ink-muted">{invoice.billedTo.phone}</p>
      </section>

      <div className="overflow-x-auto">
        <table className="w-full min-w-[520px] border-collapse text-left">
          <caption className="sr-only">Invoice lines</caption>
          <thead>
            <tr className="border-b border-line text-xs uppercase tracking-wide text-ink-muted">
              <th scope="col" className="py-2 pr-3 font-semibold">Description</th>
              <th scope="col" className="py-2 pr-3 font-semibold">SAC</th>
              <th scope="col" className="py-2 pr-3 text-right font-semibold">Amount</th>
              <th scope="col" className="py-2 pr-3 text-right font-semibold">Tax rate</th>
              <th scope="col" className="py-2 text-right font-semibold">Tax</th>
            </tr>
          </thead>
          <tbody>
            {invoice.lines.map((l, i) => (
              <tr key={i} className="border-b border-line">
                <td className="py-2 pr-3">{l.description}</td>
                <td className="py-2 pr-3 font-mono text-xs">{l.sacCode ?? "—"}</td>
                <td className="py-2 pr-3 text-right tabular-nums">{formatINR(l.amount)}</td>
                <td className="py-2 pr-3 text-right tabular-nums">{formatRate(l.taxRate)}</td>
                <td className="py-2 text-right tabular-nums">{formatINR(l.taxAmount)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <dl className="ml-auto grid w-full max-w-xs grid-cols-[1fr_auto] gap-x-4 gap-y-1">
        <dt className="text-ink-muted">Subtotal</dt>
        <dd className="text-right tabular-nums">{formatINR(invoice.subtotal)}</dd>
        <dt className="text-ink-muted">Tax</dt>
        <dd className="text-right tabular-nums">{formatINR(invoice.tax)}</dd>
        <dt className="border-t border-line pt-1 font-semibold">Total</dt>
        <dd className="border-t border-line pt-1 text-right font-semibold tabular-nums">{formatINR(invoice.total)}</dd>
        {invoice.refundedAmount > 0 && (
          <>
            <dt className="text-danger-dark">Refunded</dt>
            <dd className="text-right tabular-nums text-danger-dark">−{formatINR(invoice.refundedAmount)}</dd>
          </>
        )}
      </dl>

      <p className="text-xs text-ink-muted">All amounts in ₹ (INR).</p>
    </article>
  );
}

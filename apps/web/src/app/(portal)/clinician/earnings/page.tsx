"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { BadgeIndianRupee, CheckCircle2, ChevronLeft, ChevronRight, Percent, Undo2, Wallet } from "lucide-react";
import { api } from "@/lib/api";
import { formatDate, formatINR, formatNumber, humanize, todayIST } from "@/lib/format";
import { Button, Card, EmptyState, Input, PageHeader, QueryView, StatTile, Table, Td, Th } from "@/components/ui";

const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;

/** "YYYY-MM" → first and last calendar day of that month. */
function monthRange(month: string): { from: string; to: string } {
  const [y, m] = month.split("-").map(Number);
  const last = new Date(Date.UTC(y ?? 1970, m ?? 1, 0)).getUTCDate();
  return { from: `${month}-01`, to: `${month}-${String(last).padStart(2, "0")}` };
}

function shiftMonth(month: string, delta: number): string {
  const [y, m] = month.split("-").map(Number);
  const d = new Date(Date.UTC(y ?? 1970, (m ?? 1) - 1 + delta, 1));
  return d.toISOString().slice(0, 7);
}

function monthLabel(month: string) {
  const [y, m] = month.split("-").map(Number);
  return new Intl.DateTimeFormat("en-IN", { month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(Date.UTC(y ?? 1970, (m ?? 1) - 1, 1)));
}

export default function EarningsPage() {
  const current = todayIST().slice(0, 7);
  const [month, setMonth] = useState(current);
  const { from, to } = monthRange(month);
  const query = useQuery({ queryKey: ["provider", "earnings", from, to], queryFn: () => api.earnings.mine({ from, to }) });

  return (
    <>
      <PageHeader
        title="Earnings"
        description="Only completed and paid services count. Amounts in ₹; dates in IST."
        actions={
          <div className="flex items-center gap-2" role="group" aria-label="Month">
            <Button variant="ghost" size="sm" onClick={() => setMonth(shiftMonth(month, -1))} aria-label="Previous month">
              <ChevronLeft className="size-4" aria-hidden />
            </Button>
            <label htmlFor="earnings-month" className="sr-only">
              Month
            </label>
            <Input
              id="earnings-month"
              type="month"
              className="w-44"
              value={month}
              max={current}
              onChange={(e) => MONTH_RE.test(e.target.value) && setMonth(e.target.value)}
            />
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setMonth(shiftMonth(month, 1))}
              disabled={month >= current}
              aria-label="Next month"
            >
              <ChevronRight className="size-4" aria-hidden />
            </Button>
          </div>
        }
      />
      <QueryView query={query} loadingRows={4}>
        {(e) => {
          const totals = e.lines.reduce(
            (t, l) => ({ amount: t.amount + l.amount, fee: t.fee + l.platformFee, payable: t.payable + l.payable }),
            { amount: 0, fee: 0, payable: 0 },
          );
          return (
            <div className="flex flex-col gap-5">
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
                <StatTile label="Completed services" value={formatNumber(e.completedServices)} icon={<CheckCircle2 className="size-4" />} />
                <StatTile label="Gross" value={formatINR(e.grossAmount)} icon={<BadgeIndianRupee className="size-4" />} />
                <StatTile label="Platform fee" value={formatINR(e.platformFee)} icon={<Percent className="size-4" />} />
                <StatTile label="Refunds" value={formatINR(e.refunds)} tone={e.refunds > 0 ? "warn" : "neutral"} icon={<Undo2 className="size-4" />} />
                <StatTile label="Payable" value={formatINR(e.payable)} icon={<Wallet className="size-4" />} hint={`${formatDate(e.from)} – ${formatDate(e.to)}`} />
              </div>
              <Card title={`Services in ${monthLabel(month)}`}>
                {e.lines.length === 0 ? (
                  <EmptyState title="No earnings this month" description="Completed and paid consultations or visits will appear here." />
                ) : (
                  <Table caption={`Earnings lines for ${monthLabel(month)}`}>
                    <thead>
                      <tr>
                        <Th>Date</Th>
                        <Th>Description</Th>
                        <Th>Type</Th>
                        <Th className="text-right">Amount</Th>
                        <Th className="text-right">Platform fee</Th>
                        <Th className="text-right">Payable</Th>
                      </tr>
                    </thead>
                    <tbody>
                      {e.lines.map((l) => (
                        <tr key={`${l.refType}-${l.refId}`}>
                          <Td className="whitespace-nowrap">{formatDate(l.date)}</Td>
                          <Td>{l.description}</Td>
                          <Td>{humanize(l.refType)}</Td>
                          <Td className="text-right tabular-nums">{formatINR(l.amount)}</Td>
                          <Td className="text-right tabular-nums">{formatINR(l.platformFee)}</Td>
                          <Td className="text-right tabular-nums font-semibold">{formatINR(l.payable)}</Td>
                        </tr>
                      ))}
                    </tbody>
                    <tfoot>
                      <tr className="bg-mint-50/60 font-semibold">
                        <Td colSpan={3}>Total ({e.lines.length} lines)</Td>
                        <Td className="text-right tabular-nums">{formatINR(totals.amount)}</Td>
                        <Td className="text-right tabular-nums">{formatINR(totals.fee)}</Td>
                        <Td className="text-right tabular-nums">{formatINR(totals.payable)}</Td>
                      </tr>
                    </tfoot>
                  </Table>
                )}
              </Card>
            </div>
          );
        }}
      </QueryView>
    </>
  );
}

"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Banknote, ListTree, Percent, Undo2, Users, Wallet } from "lucide-react";
import { api } from "@/lib/api";
import type { Earnings } from "@/lib/api/types";
import { addDays, formatDate, formatINR, formatNumber, humanize, todayIST } from "@/lib/format";
import { BlobButton } from "@/components/blob-actions";
import { Badge, Button, Card, Dialog, EmptyState, Field, Input, PageHeader, QueryView, StatTile, Table, Td, Th } from "@/components/ui";

function currentMonthIST(): { from: string; to: string } {
  const today = todayIST();
  const from = `${today.slice(0, 8)}01`;
  const [y, m] = today.split("-").map(Number);
  const nextMonth = new Date(Date.UTC(y ?? 1970, m ?? 1, 1)).toISOString().slice(0, 10);
  return { from, to: addDays(nextMonth, -1) };
}

export default function SettlementsPage() {
  const [draft, setDraft] = useState(currentMonthIST);
  const [range, setRange] = useState(draft);
  const [rangeError, setRangeError] = useState<string | null>(null);
  const [drill, setDrill] = useState<Earnings | null>(null);

  const query = useQuery({
    queryKey: ["ops", "settlements", range.from, range.to],
    queryFn: () => api.earnings.settlements({ from: range.from, to: range.to, limit: 100 }),
  });

  const apply = () => {
    if (!draft.from || !draft.to) return setRangeError("Choose both dates");
    if (draft.from > draft.to) return setRangeError("The start date must be on or before the end date");
    setRangeError(null);
    setRange(draft);
  };

  return (
    <>
      <PageHeader
        title="Settlements"
        description="Payouts owed to doctors and providers for completed, paid services. Amounts in ₹."
        actions={
          <BlobButton
            label="Export CSV"
            load={() => api.earnings.settlementsCsv({ from: range.from, to: range.to })}
            fileName={`settlements-${range.from}-to-${range.to}.csv`}
            errorTitle="Could not export settlements"
          />
        }
      />

      <Card className="mb-5">
        <form
          className="flex flex-wrap items-end gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            apply();
          }}
          noValidate
        >
          <Field label="From" error={rangeError ?? undefined}>
            {(id, d) => (
              <Input id={id} type="date" aria-describedby={d} aria-invalid={!!rangeError} value={draft.from} onChange={(e) => setDraft({ ...draft, from: e.target.value })} className="w-44" />
            )}
          </Field>
          <Field label="To">
            {(id) => <Input id={id} type="date" aria-invalid={!!rangeError} value={draft.to} onChange={(e) => setDraft({ ...draft, to: e.target.value })} className="w-44" />}
          </Field>
          <Button type="submit" variant="secondary">
            Apply
          </Button>
          <p className="basis-full text-xs text-ink-muted sm:basis-auto">
            Showing {formatDate(range.from)} – {formatDate(range.to)} (IST)
          </p>
        </form>
      </Card>

      <QueryView
        query={query}
        isEmpty={(d) => d.items.length === 0}
        empty={
          <Card>
            <EmptyState title="No settlements" description="No doctor or provider had completed, paid services in this period." />
          </Card>
        }
      >
        {(d) => {
          const t = d.items.reduce(
            (acc, e) => ({
              services: acc.services + e.completedServices,
              gross: acc.gross + e.grossAmount,
              fee: acc.fee + e.platformFee,
              refunds: acc.refunds + e.refunds,
              payable: acc.payable + e.payable,
            }),
            { services: 0, gross: 0, fee: 0, refunds: 0, payable: 0 },
          );
          return (
            <>
              <div className="mb-5 grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
                <StatTile label="Providers" value={formatNumber(d.items.length)} icon={<Users className="size-4" />} />
                <StatTile label="Services" value={formatNumber(t.services)} icon={<ListTree className="size-4" />} />
                <StatTile label="Gross" value={formatINR(t.gross)} icon={<Banknote className="size-4" />} />
                <StatTile label="Platform fee" value={formatINR(t.fee)} icon={<Percent className="size-4" />} />
                <StatTile label="Refunds" value={formatINR(t.refunds)} tone={t.refunds ? "warn" : "neutral"} icon={<Undo2 className="size-4" />} />
                <StatTile label="Payable" value={formatINR(t.payable)} icon={<Wallet className="size-4" />} />
              </div>
              <Card title="By doctor / provider">
                <Table caption="Settlements by doctor or provider">
                  <thead>
                    <tr>
                      <Th>Name</Th>
                      <Th>Role</Th>
                      <Th className="text-right">Services</Th>
                      <Th className="text-right">Gross</Th>
                      <Th className="text-right">Fee</Th>
                      <Th className="text-right">Refunds</Th>
                      <Th className="text-right">Payable</Th>
                      <Th className="text-right">
                        <span className="sr-only">Actions</span>
                      </Th>
                    </tr>
                  </thead>
                  <tbody>
                    {d.items.map((e) => (
                      <tr key={e.providerId}>
                        <Td className="font-semibold">{e.providerName}</Td>
                        <Td>
                          <Badge tone={e.role === "doctor" ? "lavender" : "sky"}>{humanize(e.role)}</Badge>
                        </Td>
                        <Td className="text-right tabular-nums">{formatNumber(e.completedServices)}</Td>
                        <Td className="text-right tabular-nums">{formatINR(e.grossAmount)}</Td>
                        <Td className="text-right tabular-nums">{formatINR(e.platformFee)}</Td>
                        <Td className="text-right tabular-nums">{e.refunds ? formatINR(e.refunds) : "—"}</Td>
                        <Td className="text-right font-semibold tabular-nums">{formatINR(e.payable)}</Td>
                        <Td className="text-right">
                          <Button size="sm" variant="ghost" onClick={() => setDrill(e)} aria-label={`View lines for ${e.providerName}`}>
                            View lines
                          </Button>
                        </Td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot>
                    <tr className="font-semibold">
                      <Td>Total</Td>
                      <Td />
                      <Td className="text-right tabular-nums">{formatNumber(t.services)}</Td>
                      <Td className="text-right tabular-nums">{formatINR(t.gross)}</Td>
                      <Td className="text-right tabular-nums">{formatINR(t.fee)}</Td>
                      <Td className="text-right tabular-nums">{formatINR(t.refunds)}</Td>
                      <Td className="text-right tabular-nums">{formatINR(t.payable)}</Td>
                      <Td />
                    </tr>
                  </tfoot>
                </Table>
                {d.nextCursor && <p className="mt-3 text-xs text-ink-muted">Showing the first 100. Export CSV for the full list.</p>}
              </Card>
            </>
          );
        }}
      </QueryView>

      {drill && <LinesDialog earnings={drill} onClose={() => setDrill(null)} />}
    </>
  );
}

function LinesDialog({ earnings, onClose }: { earnings: Earnings; onClose: () => void }) {
  return (
    <Dialog
      open
      size="lg"
      onClose={onClose}
      title={earnings.providerName}
      description={`${humanize(earnings.role)} · ${formatDate(earnings.from)} – ${formatDate(earnings.to)} · payable ${formatINR(earnings.payable)}`}
      footer={
        <Button variant="ghost" onClick={onClose}>
          Close
        </Button>
      }
    >
      {earnings.lines.length === 0 ? (
        <EmptyState title="No lines" />
      ) : (
        <Table caption={`Settlement lines for ${earnings.providerName}`}>
          <thead>
            <tr>
              <Th>Date</Th>
              <Th>Description</Th>
              <Th>Type</Th>
              <Th className="text-right">Amount</Th>
              <Th className="text-right">Fee</Th>
              <Th className="text-right">Payable</Th>
            </tr>
          </thead>
          <tbody>
            {earnings.lines.map((l) => (
              <tr key={`${l.refType}-${l.refId}-${l.date}`}>
                <Td className="whitespace-nowrap">{formatDate(l.date)}</Td>
                <Td>{l.description}</Td>
                <Td>
                  <Badge tone="neutral">{humanize(l.refType)}</Badge>
                </Td>
                <Td className="text-right tabular-nums">{formatINR(l.amount)}</Td>
                <Td className="text-right tabular-nums">{formatINR(l.platformFee)}</Td>
                <Td className="text-right tabular-nums">{formatINR(l.payable)}</Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </Dialog>
  );
}

"use client";

import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Boxes, PackagePlus } from "lucide-react";
import { api } from "@/lib/api";
import type { LowStockItem } from "@/lib/api/types";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, Dialog, EmptyState, Input, PageHeader, QueryView, Table, Td, Th } from "@/components/ui";

interface ProviderGroup {
  providerId: string;
  providerName: string;
  items: LowStockItem[];
}

export default function OpsSuppliesPage() {
  const [restocking, setRestocking] = useState<ProviderGroup | null>(null);
  const query = useQuery({ queryKey: ["ops", "supplies", "low-stock"], queryFn: () => api.supplies.lowStock({ limit: 100 }) });
  const groups = useMemo(() => {
    const m = new Map<string, ProviderGroup>();
    for (const i of query.data?.items ?? []) {
      const g = m.get(i.providerId) ?? { providerId: i.providerId, providerName: i.providerName, items: [] };
      g.items.push(i);
      m.set(i.providerId, g);
    }
    return [...m.values()].sort((a, b) => a.providerName.localeCompare(b.providerName));
  }, [query.data]);

  return (
    <>
      <PageHeader title="Nurse supplies" description="Consumables at or below the reorder level, per field provider." />
      <QueryView
        query={query}
        isEmpty={() => groups.length === 0}
        empty={
          <Card>
            <EmptyState icon={<Boxes className="size-6" />} title="No low stock" description="Every provider is above the reorder level." />
          </Card>
        }
      >
        {() => (
          <ul className="grid gap-4 lg:grid-cols-2">
            {groups.map((g) => (
              <li key={g.providerId}>
                <Card
                  title={g.providerName}
                  subtitle={`${g.items.length} ${g.items.length === 1 ? "item" : "items"} low`}
                  actions={
                    <Button size="sm" onClick={() => setRestocking(g)} icon={<PackagePlus className="size-4" aria-hidden />} aria-label={`Restock ${g.providerName}`}>
                      Restock
                    </Button>
                  }
                >
                  <Table caption={`Low-stock items for ${g.providerName}`} className="[&_table]:min-w-[360px]">
                    <thead>
                      <tr>
                        <Th>Item</Th>
                        <Th className="text-right">On hand</Th>
                        <Th className="text-right">Reorder at</Th>
                      </tr>
                    </thead>
                    <tbody>
                      {g.items.map((i) => (
                        <tr key={i.code}>
                          <Td>
                            {i.name}
                            {i.onHand === 0 && (
                              <Badge tone="red" className="ml-2">
                                Out
                              </Badge>
                            )}
                          </Td>
                          <Td className="text-right tabular-nums">{i.onHand}</Td>
                          <Td className="text-right tabular-nums">{i.reorderLevel}</Td>
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </QueryView>
      {restocking && <RestockDialog group={restocking} onClose={() => setRestocking(null)} />}
    </>
  );
}

function RestockDialog({ group, onClose }: { group: ProviderGroup; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  // Suggest topping up to twice the reorder level.
  const [qty, setQty] = useState<Record<string, string>>(() =>
    Object.fromEntries(group.items.map((i) => [i.code, String(Math.max(1, i.reorderLevel * 2 - i.onHand))])),
  );
  const [error, setError] = useState<string | null>(null);

  const m = useMutation({
    mutationFn: (items: { code: string; qty: number }[]) => api.supplies.restock(group.providerId, items),
    onSuccess: () => {
      toast.success("Restock recorded", group.providerName);
      void qc.invalidateQueries({ queryKey: ["ops", "supplies"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not record the restock"),
  });

  const submit = () => {
    const entries = Object.entries(qty).map(([code, v]) => ({ code, raw: v.trim() }));
    if (entries.some((e) => e.raw && !/^\d+$/.test(e.raw))) return setError("Quantities must be whole numbers.");
    const items = entries.map((e) => ({ code: e.code, qty: Number(e.raw || 0) })).filter((i) => i.qty > 0);
    if (items.length === 0) return setError("Enter a quantity for at least one item.");
    if (items.some((i) => i.qty > 1000)) return setError("At most 1000 per item.");
    setError(null);
    m.mutate(items);
  };

  return (
    <Dialog
      open
      onClose={onClose}
      title={`Restock ${group.providerName}`}
      description="Quantities handed over to the provider. Leave 0 to skip an item."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={submit} loading={m.isPending}>
            Record restock
          </Button>
        </>
      }
    >
      <ul className="flex flex-col gap-2">
        {group.items.map((i, idx) => (
          <li key={i.code} className="flex items-center justify-between gap-3">
            <label htmlFor={`qty-${i.code}`} className="text-sm">
              {i.name} <span className="text-xs text-ink-muted">({i.onHand} on hand)</span>
            </label>
            <Input
              id={`qty-${i.code}`}
              inputMode="numeric"
              className="w-24 text-right"
              data-autofocus={idx === 0 ? "" : undefined}
              value={qty[i.code] ?? ""}
              onChange={(e) => setQty((q) => ({ ...q, [i.code]: e.target.value }))}
            />
          </li>
        ))}
      </ul>
      {error && (
        <p role="alert" className="mt-3 text-sm text-danger-dark">
          {error}
        </p>
      )}
    </Dialog>
  );
}

"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { MapPin, Plus } from "lucide-react";
import { api } from "@/lib/api";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, Dialog, EmptyState, Field, Input, PageHeader, QueryView, Textarea } from "@/components/ui";

/** Expands "500001-500040, 500081" into individual 6-digit pincodes. Returns null on invalid input. */
function parsePincodes(text: string): { pincodes: string[]; error: string | null } {
  const out = new Set<string>();
  for (const part of text.split(/[\s,]+/).filter(Boolean)) {
    const range = part.match(/^(\d{6})[-–](\d{6})$/);
    if (range) {
      const a = Number(range[1]);
      const b = Number(range[2]);
      if (b < a || b - a > 999) return { pincodes: [], error: `Invalid range ${part}` };
      for (let n = a; n <= b; n++) out.add(String(n));
    } else if (/^\d{6}$/.test(part)) {
      out.add(part);
    } else {
      return { pincodes: [], error: `“${part}” is not a 6-digit pincode or range` };
    }
  }
  return { pincodes: [...out].sort(), error: out.size === 0 ? "Enter at least one pincode" : null };
}

export default function ZonesPage() {
  const [creating, setCreating] = useState(false);
  const query = useQuery({ queryKey: ["admin", "zones"], queryFn: () => api.admin.zones({ limit: 100 }) });
  return (
    <>
      <PageHeader
        title="Service zones"
        description="Home visits are serviceable only in pincodes covered by a zone."
        actions={
          <Button onClick={() => setCreating(true)} icon={<Plus className="size-4" aria-hidden />}>
            New zone
          </Button>
        }
      />
      <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<Card><EmptyState title="No zones" /></Card>}>
        {(d) => (
          <ul className="grid gap-4 md:grid-cols-2">
            {d.items.map((z) => (
              <li key={z.id}>
                <Card title={z.name} subtitle={z.city} actions={<MapPin className="size-5 text-primary-light" aria-hidden />}>
                  <p className="mb-2 text-xs text-ink-muted">{z.pincodes.length} pincodes</p>
                  <ul className="flex max-h-40 flex-wrap gap-1 overflow-y-auto" aria-label={`Pincodes in ${z.name}`}>
                    {z.pincodes.map((p) => (
                      <li key={p}>
                        <Badge tone="neutral">{p}</Badge>
                      </li>
                    ))}
                  </ul>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </QueryView>
      {creating && <CreateZoneDialog onClose={() => setCreating(false)} />}
    </>
  );
}

function CreateZoneDialog({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [name, setName] = useState("");
  const [city, setCity] = useState("");
  const [pins, setPins] = useState("");
  const [errors, setErrors] = useState<{ name?: string; city?: string; pins?: string }>({});
  const parsed = parsePincodes(pins);
  const m = useMutation({
    mutationFn: () => api.admin.createZone({ name: name.trim(), city: city.trim(), pincodes: parsed.pincodes }),
    onSuccess: () => {
      toast.success("Zone created");
      void qc.invalidateQueries({ queryKey: ["admin", "zones"] });
      onClose();
    },
    onError: (e) => toast.apiError(e, "Could not create zone"),
  });
  return (
    <Dialog
      open
      onClose={onClose}
      title="New service zone"
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            loading={m.isPending}
            onClick={() => {
              const next = {
                name: name.trim() ? undefined : "Name is required",
                city: city.trim() ? undefined : "City is required",
                pins: parsed.error ?? undefined,
              };
              setErrors(next);
              if (!next.name && !next.city && !next.pins) m.mutate();
            }}
          >
            Create zone
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label="Zone name" required error={errors.name}>
          {(id, d) => <Input id={id} data-autofocus aria-describedby={d} value={name} onChange={(e) => setName(e.target.value)} placeholder="Hyderabad-Central" />}
        </Field>
        <Field label="City" required error={errors.city}>
          {(id, d) => <Input id={id} aria-describedby={d} value={city} onChange={(e) => setCity(e.target.value)} />}
        </Field>
        <Field label="Pincodes" required error={errors.pins} hint={parsed.error ? "Comma or space separated; ranges like 500001-500040 are expanded." : `${parsed.pincodes.length} pincodes`}>
          {(id, d) => <Textarea id={id} aria-describedby={d} value={pins} onChange={(e) => setPins(e.target.value)} placeholder="500001-500040, 500081" />}
        </Field>
      </div>
    </Dialog>
  );
}

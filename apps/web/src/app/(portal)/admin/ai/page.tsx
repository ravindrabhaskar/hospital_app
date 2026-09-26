"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { ShieldAlert } from "lucide-react";
import { api } from "@/lib/api";
import { formatDateTime, formatNumber, humanize } from "@/lib/format";
import { Badge, Card, EmptyState, Field, Input, PageHeader, QueryView, Select, Table, Td, Th, type Tone } from "@/components/ui";

const LEVEL_TONE: Record<string, Tone> = { none: "neutral", routine: "sky", urgent: "red", emergency: "dark" };

export default function AiInteractionsPage() {
  const [useCase, setUseCase] = useState("");
  const [safetyLevel, setSafetyLevel] = useState("");
  const query = useQuery({
    queryKey: ["admin", "ai-interactions", useCase, safetyLevel],
    queryFn: () => api.admin.aiInteractions({ useCase: useCase.trim() || undefined, safetyLevel: safetyLevel || undefined, limit: 100 }),
  });

  return (
    <>
      <PageHeader
        title="AI interactions"
        description="Operational metadata for every AI call. No prompts, replies or other PHI text are stored or shown here."
      />
      <Card>
        <div className="mb-4 flex flex-wrap gap-3">
          <Field label="Use case" className="w-56">
            {(id) => <Input id={id} placeholder="e.g. intake" value={useCase} onChange={(e) => setUseCase(e.target.value)} />}
          </Field>
          <Field label="Safety level" className="w-48">
            {(id) => (
              <Select id={id} value={safetyLevel} onChange={(e) => setSafetyLevel(e.target.value)}>
                <option value="">All</option>
                <option value="none">None</option>
                <option value="routine">Routine</option>
                <option value="urgent">Urgent</option>
                <option value="emergency">Emergency</option>
              </Select>
            )}
          </Field>
        </div>
        <QueryView query={query} isEmpty={(d) => d.items.length === 0} empty={<EmptyState title="No AI interactions" />}>
          {(d) => (
            <Table caption="AI interactions">
              <thead>
                <tr>
                  <Th>Time (IST)</Th>
                  <Th>Use case</Th>
                  <Th>Model / versions</Th>
                  <Th>Safety</Th>
                  <Th className="text-right">Latency</Th>
                  <Th className="text-right">Tokens in/out</Th>
                  <Th>Fallback</Th>
                </tr>
              </thead>
              <tbody>
                {d.items.map((i) => (
                  <tr key={i.id}>
                    <Td className="whitespace-nowrap text-[13px]">{formatDateTime(i.createdAt)}</Td>
                    <Td>{humanize(i.useCase)}</Td>
                    <Td className="text-xs">
                      <p className="font-medium">{i.model}</p>
                      <p className="text-ink-muted">
                        prompt {i.promptVersion} · policy {i.policyVersion} · rules {i.rulePackVersion}
                      </p>
                    </Td>
                    <Td>
                      <Badge tone={LEVEL_TONE[i.safetyLevel] ?? "neutral"}>{humanize(i.safetyLevel)}</Badge>
                    </Td>
                    <Td className="text-right tabular-nums">{formatNumber(i.latencyMs)} ms</Td>
                    <Td className="text-right tabular-nums">
                      {formatNumber(i.inputTokens)} / {formatNumber(i.outputTokens)}
                    </Td>
                    <Td>
                      {i.fallbackUsed ? (
                        <Badge tone="amber" icon={<ShieldAlert className="size-3" aria-hidden />}>
                          Fallback
                        </Badge>
                      ) : (
                        <span className="text-xs text-ink-muted">No</span>
                      )}
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </QueryView>
      </Card>
    </>
  );
}

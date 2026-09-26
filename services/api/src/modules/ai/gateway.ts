import type { Config } from '../../config.js';
import type { Db } from '../../db/client.js';
import { aiInteractions } from '../../db/schema.js';
import type { Metrics } from '../../lib/metrics.js';
import type { FlagService } from '../flags/service.js';
import { RuleBasedModel, type ChatModel, type ModelRequest } from './models.js';

export const PROMPT_VERSION = 'care-assistant-2026.09.1';
export const POLICY_VERSION = 'ai-policy-0.1';

export interface AuditContext {
  useCase: string;
  userId: string | null;
  patientId: string | null;
  conversationId?: string | null;
  safetyLevel: string;
  rulePackVersion: string;
  knowledgeSourceIds?: string[];
}

export interface CompletionResult {
  text: string;
  model: string;
  fallbackUsed: boolean;
  errorCode: string | null;
  interactionId: string;
  latencyMs: number;
}

/** Simple consecutive-failure circuit breaker. */
export class CircuitBreaker {
  private failures = 0;
  private openedAt: number | null = null;
  constructor(
    private readonly threshold: number,
    private readonly cooldownMs: number,
  ) {}
  get isOpen(): boolean {
    if (this.openedAt === null) return false;
    if (Date.now() - this.openedAt >= this.cooldownMs) {
      this.openedAt = null; // half-open: allow a trial call
      this.failures = this.threshold - 1;
      return false;
    }
    return true;
  }
  success(): void {
    this.failures = 0;
    this.openedAt = null;
  }
  failure(): void {
    this.failures++;
    if (this.failures >= this.threshold) this.openedAt = Date.now();
  }
}

/**
 * Provider-agnostic AI gateway: kill switch, timeout, circuit breaker, deterministic fallback,
 * metrics and one AIInteraction audit row per call (no raw PHI stored).
 */
export class AiGateway {
  readonly fallback = new RuleBasedModel();
  readonly breaker: CircuitBreaker;
  readonly metrics = { calls: 0, failures: 0, fallbacks: 0, totalLatencyMs: 0, inputTokens: 0, outputTokens: 0 };
  /** Prometheus sink (set by buildApp). */
  prom: Metrics | null = null;

  constructor(
    readonly primary: ChatModel,
    private readonly db: Db,
    private readonly flags: FlagService,
    private readonly config: Config,
  ) {
    this.breaker = new CircuitBreaker(config.AI_BREAKER_THRESHOLD, config.AI_BREAKER_COOLDOWN_SEC * 1000);
  }

  get isLlm(): boolean {
    return this.primary.kind === 'llm';
  }

  /** True when the primary model can read images (Claude vision). */
  get supportsVision(): boolean {
    return this.primary.kind === 'llm' && this.primary.supportsVision === true;
  }

  async health(): Promise<'ok' | 'degraded'> {
    if (await this.flags.isEnabled('kill_switch_ai')) return 'degraded';
    return this.breaker.isOpen ? 'degraded' : 'ok';
  }

  async complete(req: ModelRequest, ctx: AuditContext): Promise<CompletionResult> {
    const started = Date.now();
    this.metrics.calls++;
    let text = req.fallbackText;
    let model = this.fallback.name;
    let fallbackUsed = false;
    let errorCode: string | null = null;
    let inputTokens = 0;
    let outputTokens = 0;

    if (await this.flags.isEnabled('kill_switch_ai')) {
      fallbackUsed = true;
      errorCode = 'kill_switch';
    } else if (this.primary.kind === 'llm' && this.breaker.isOpen) {
      fallbackUsed = true;
      errorCode = 'circuit_open';
    } else {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), this.config.AI_TIMEOUT_MS);
      try {
        const res = await Promise.race([
          this.primary.generate(req, controller.signal),
          new Promise<never>((_, reject) => controller.signal.addEventListener('abort', () => reject(new Error('timeout')))),
        ]);
        text = res.text;
        model = res.model;
        inputTokens = res.inputTokens;
        outputTokens = res.outputTokens;
        this.breaker.success();
      } catch (err) {
        this.metrics.failures++;
        this.breaker.failure();
        fallbackUsed = true;
        errorCode = err instanceof Error ? err.message.slice(0, 60) : 'model_error';
      } finally {
        clearTimeout(timer);
      }
    }
    if (fallbackUsed) {
      this.metrics.fallbacks++;
      text = req.fallbackText;
      model = this.fallback.name;
    }
    const latencyMs = Date.now() - started;
    if (this.prom) {
      this.prom.aiCalls.inc({ use_case: ctx.useCase });
      this.prom.aiLatency.observe({ use_case: ctx.useCase, model_kind: this.primary.kind, outcome: fallbackUsed ? 'fallback' : 'ok' }, latencyMs / 1000);
      if (fallbackUsed) this.prom.aiFallbacks.inc({ use_case: ctx.useCase, reason: (errorCode ?? 'unknown').replace(/[^a-z_]/gi, '_').slice(0, 30) });
    }
    this.metrics.totalLatencyMs += latencyMs;
    this.metrics.inputTokens += inputTokens;
    this.metrics.outputTokens += outputTokens;
    const interactionId = await this.record(ctx, { model, latencyMs, inputTokens, outputTokens, fallbackUsed, errorCode });
    return { text, model, fallbackUsed, errorCode, interactionId, latencyMs };
  }

  /** Record an AIInteraction row (also used for deterministic, model-free turns). */
  async record(
    ctx: AuditContext,
    r: { model: string; latencyMs: number; inputTokens?: number; outputTokens?: number; fallbackUsed?: boolean; errorCode?: string | null },
  ): Promise<string> {
    const [row] = await this.db
      .insert(aiInteractions)
      .values({
        useCase: ctx.useCase,
        userId: ctx.userId,
        patientId: ctx.patientId,
        conversationId: ctx.conversationId ?? null,
        model: r.model,
        promptVersion: PROMPT_VERSION,
        policyVersion: POLICY_VERSION,
        rulePackVersion: ctx.rulePackVersion,
        safetyLevel: ctx.safetyLevel,
        latencyMs: r.latencyMs,
        inputTokens: r.inputTokens ?? 0,
        outputTokens: r.outputTokens ?? 0,
        fallbackUsed: r.fallbackUsed ?? false,
        errorCode: r.errorCode ?? null,
        knowledgeSourceIds: ctx.knowledgeSourceIds ?? [],
      })
      .returning({ id: aiInteractions.id });
    return row.id;
  }
}

/** Output policy check: generative text must not state diagnoses or prescribe. */
const POLICY_PATTERNS: RegExp[] = [
  /\byou (?:have|may have|might have|probably have|likely have|are suffering from|are diagnosed with)\b/i,
  /\bdiagnos(?:is|ed|e|ing)\b/i,
  /\b(?:i|we) (?:prescribe|recommend taking)\b/i,
  /\btake \d+\s?(?:mg|ml|tablets?)\b/i,
  /\bnothing serious\b/i,
  /\bno need to (?:see|consult|visit) a doctor\b/i,
];

export function policyCheck(text: string): { ok: boolean; violations: string[] } {
  const violations = POLICY_PATTERNS.filter((p) => p.test(text)).map((p) => p.source);
  return { ok: violations.length === 0, violations };
}

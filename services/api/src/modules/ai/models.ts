import Anthropic from '@anthropic-ai/sdk';

export interface ModelRequest {
  system: string;
  messages: Array<{ role: 'user' | 'assistant'; content: string }>;
  maxTokens: number;
  /** Deterministic, pre-approved text. The rule-based model returns exactly this. */
  fallbackText: string;
  /** Optional images (base64) attached to the LAST user message. Only sent to vision-capable models. */
  images?: Array<{ mediaType: VisionMediaType; data: string }>;
}

export type VisionMediaType = 'image/jpeg' | 'image/png' | 'image/webp' | 'image/gif';
export const VISION_MEDIA_TYPES: readonly string[] = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

export interface ModelResponse {
  text: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
}

export interface ChatModel {
  readonly name: string;
  /** 'llm' = generative model; 'rule_based' = deterministic offline model. */
  readonly kind: 'llm' | 'rule_based';
  /** True when the model accepts image inputs (ModelRequest.images). */
  readonly supportsVision?: boolean;
  generate(req: ModelRequest, signal?: AbortSignal): Promise<ModelResponse>;
}

/** Deterministic offline model: returns the pre-approved template text. Always available. */
export class RuleBasedModel implements ChatModel {
  readonly name = 'rule-based-v1';
  readonly kind = 'rule_based' as const;
  async generate(req: ModelRequest): Promise<ModelResponse> {
    return { text: req.fallbackText, model: this.name, inputTokens: 0, outputTokens: 0 };
  }
}

export class ModelRefusalError extends Error {
  constructor(readonly category: string | null) {
    super('model_refusal');
  }
}

/**
 * Anthropic Claude implementation using the official SDK.
 * Default model comes from AI_MODEL (default `claude-opus-5`). Server-side refusal fallbacks are
 * enabled for models that support them (`fallbacks: "default"`).
 */
export class AnthropicModel implements ChatModel {
  readonly kind = 'llm' as const;
  readonly supportsVision = true;
  private readonly client: Anthropic;

  constructor(
    readonly name: string,
    opts: { apiKey: string; timeoutMs: number; maxRetries: number },
  ) {
    this.client = new Anthropic({ apiKey: opts.apiKey, timeout: opts.timeoutMs, maxRetries: opts.maxRetries });
  }

  private supportsServerFallbacks(): boolean {
    return /^claude-(opus-5|fable-5)/.test(this.name);
  }

  async generate(req: ModelRequest, signal?: AbortSignal): Promise<ModelResponse> {
    const params: Anthropic.Beta.Messages.MessageCreateParamsNonStreaming = {
      model: this.name,
      max_tokens: req.maxTokens,
      system: req.system,
      messages: toAnthropicMessages(req),
      output_config: { effort: 'low' },
    };
    if (this.supportsServerFallbacks()) {
      params.betas = ['server-side-fallback-2026-07-01'];
      params.fallbacks = 'default';
    }
    const res = await this.client.beta.messages.create(params, { signal });
    if (res.stop_reason === 'refusal') {
      throw new ModelRefusalError(res.stop_details?.category ?? null);
    }
    const text = res.content
      .filter((b): b is Anthropic.Beta.Messages.BetaTextBlock => b.type === 'text')
      .map((b) => b.text)
      .join('')
      .trim();
    if (!text) throw new Error('empty_model_response');
    return { text, model: res.model, inputTokens: res.usage.input_tokens, outputTokens: res.usage.output_tokens };
  }
}

/** Attach images (if any) to the last user message as base64 image blocks followed by its text. */
export function toAnthropicMessages(req: ModelRequest): Anthropic.Beta.Messages.BetaMessageParam[] {
  const msgs: Anthropic.Beta.Messages.BetaMessageParam[] = req.messages.map((m) => ({ role: m.role, content: m.content }));
  if (!req.images?.length) return msgs;
  for (let i = msgs.length - 1; i >= 0; i--) {
    if (msgs[i].role !== 'user') continue;
    msgs[i] = {
      role: 'user',
      content: [
        ...req.images.map((img) => ({ type: 'image' as const, source: { type: 'base64' as const, media_type: img.mediaType, data: img.data } })),
        { type: 'text' as const, text: req.messages[i].content },
      ],
    };
    break;
  }
  return msgs;
}

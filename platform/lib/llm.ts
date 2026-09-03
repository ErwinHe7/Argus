import * as Sentry from '@sentry/nextjs';
import OpenAI from 'openai';
import {
  buildLlmProviderFailureReceipt,
  type LlmProviderOperation,
} from '@/lib/llm-provider-failure';

let client: OpenAI | null = null;

export function llmApiKey() {
  return process.env.TOKENROUTER_API_KEY || process.env.OPENAI_API_KEY;
}

export function llm(): OpenAI {
  if (!client) {
    const apiKey = llmApiKey();
    const baseURL = process.env.OPENAI_BASE_URL;
    if (!apiKey) throw new Error('TOKENROUTER_API_KEY or OPENAI_API_KEY missing');
    client = new OpenAI({ apiKey, baseURL });
  }
  return client;
}

export const DEFAULT_MODEL =
  process.env.OPENAI_MODEL || 'moonshotai/kimi-k3-free';

// Ordered fallback chain. If the primary model is unavailable on the user's
// TokenRouter distribution group, we try each of these in order.
// NOTE: TokenRouter expects `provider/model` form — unprefixed names 503.
// No implicit paid fallback is allowed. Operators may name an explicit
// fallback chain after reviewing availability and price.
const FALLBACK_MODELS = (process.env.OPENAI_FALLBACK_MODELS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

function isModelUnavailable(err: any): boolean {
  const msg = String(err?.message || err?.error?.message || '').toLowerCase();
  return (
    err?.status === 404 ||
    err?.status === 503 ||
    msg.includes('no available channel') ||
    msg.includes('model') && msg.includes('not found') ||
    msg.includes('unknown model') ||
    msg.includes('unsupported model')
  );
}

export type ChatResult = {
  content: string;
  usage?: { prompt_tokens?: number; completion_tokens?: number };
};

export type ChatOptions = {
  model?: string;
  temperature?: number;
  max_tokens?: number;
  presence_penalty?: number;
  operation?: LlmProviderOperation;
};

function reportLlmProviderFailure(
  error: unknown,
  operation: LlmProviderOperation
) {
  const receipt = buildLlmProviderFailureReceipt(
    error,
    operation,
    process.env.OPENAI_BASE_URL
  );

  // The receipt is deliberately allow-listed. Never pass the provider error
  // object to logs or Sentry because it may contain a response body or headers.
  console.error('[llm] provider request failed', receipt);
  Sentry.captureMessage('LLM provider request failed', {
    level: 'error',
    tags: {
      operation: receipt.operation,
      failure_category: receipt.category,
      provider_host: receipt.provider_host,
    },
    extra: {
      http_status: receipt.http_status,
    },
  });
}

export async function chatWithUsage(
  messages: { role: 'system' | 'user' | 'assistant'; content: string }[],
  opts: ChatOptions = {}
): Promise<ChatResult> {
  const tried = new Set<string>();
  const chain = [opts.model ?? DEFAULT_MODEL, ...FALLBACK_MODELS];
  const baseMaxTokens = opts.max_tokens ?? 400;

  let lastErr: unknown = null;
  for (const model of chain) {
    if (!model || tried.has(model)) continue;
    tried.add(model);
    const maxTokenAttempts = model.includes('nemotron')
      ? [Math.max(baseMaxTokens, 700), Math.max(baseMaxTokens, 1100)]
      : [baseMaxTokens, Math.max(baseMaxTokens, 800)];

    try {
      let lastEmpty: ChatResult | null = null;
      for (const max_tokens of maxTokenAttempts) {
        const res = await llm().chat.completions.create({
          model,
          temperature: opts.temperature ?? 0.8,
          max_tokens,
          presence_penalty: opts.presence_penalty,
          messages,
        });
        const choice = res.choices[0];
        const msg = choice?.message as unknown as Record<string, unknown>;
        const content = ((msg?.content as string) || (msg?.reasoning_content as string) || '').trim();
        const result = {
          content,
          usage: res.usage
            ? { prompt_tokens: res.usage.prompt_tokens, completion_tokens: res.usage.completion_tokens }
            : undefined,
        };

        if (content) return result;
        lastEmpty = result;

        // Some reasoning-heavy OpenAI-compatible models, especially Nemotron,
        // can spend the whole completion budget on hidden reasoning and return
        // null content with finish_reason="length". Give the same model one
        // larger budget before moving down the fallback chain.
        if (choice?.finish_reason !== 'length') break;
      }
      if (lastEmpty) continue;
    } catch (err) {
      lastErr = err;
      if (isModelUnavailable(err)) continue;
      reportLlmProviderFailure(err, opts.operation ?? 'chat_completion');
      throw err;
    }
  }
  const finalErr = lastErr ?? new Error('No available model in fallback chain');
  reportLlmProviderFailure(finalErr, opts.operation ?? 'chat_completion');
  throw finalErr;
}

export async function chat(
  messages: { role: 'system' | 'user' | 'assistant'; content: string }[],
  opts: ChatOptions = {}
): Promise<string> {
  const result = await chatWithUsage(messages, opts);
  return result.content;
}

export async function embed(text: string): Promise<number[] | null> {
  const model = process.env.OPENAI_EMBED_MODEL || 'text-embedding-3-small';
  try {
    const res = await llm().embeddings.create({ model, input: text });
    return res.data[0]?.embedding ?? null;
  } catch {
    return null; // embeddings may not be available on all TokenRouter groups; callers handle null
  }
}

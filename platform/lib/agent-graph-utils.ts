import Redis from 'ioredis';
import type { AgentPersona, Reply } from './types';

export type AgentId = string;

export type QualityAction = 'publish' | 'retry' | 'review' | 'drop';

export type RuleQualityScore = {
  total: number;
  relevance: number;
  specificity: number;
  personaFit: number;
  novelty: number;
  safety: number;
  format: number;
  reasons: string[];
  action: QualityAction;
};

export type GeneratedAgentOutput = {
  agentId: AgentId;
  attempt: number;
  text?: string;
  error?: string;
  latencyMs?: number;
  costUsd?: number;
};

export type FailedAgent = {
  agentId: AgentId;
  reason: string;
  retryable: boolean;
  attempts: number;
};

export type SkippedAgent = {
  agentId: AgentId;
  reason: string;
};

const DEDUPE_TTL_SECONDS = 5 * 60;
const memoryDedupe = new Map<string, number>();
let redis: Redis | null | undefined;

function redisUrl(): string | null {
  return process.env.REDIS_URL || process.env.KV_URL || null;
}

function redisClient(): Redis | null {
  if (redis !== undefined) return redis;
  const url = redisUrl();
  redis = url ? new Redis(url, { lazyConnect: true, maxRetriesPerRequest: 1 }) : null;
  return redis;
}

function acquireMemoryDedupe(namespacedKey: string, ttlSeconds: number): boolean {
  const now = Date.now();
  for (const [key, expiresAt] of memoryDedupe.entries()) {
    if (expiresAt <= now) memoryDedupe.delete(key);
  }
  if (memoryDedupe.has(namespacedKey)) return false;
  memoryDedupe.set(namespacedKey, now + ttlSeconds * 1000);
  return true;
}

export async function acquireDedupeKey(
  dedupeKey: string,
  ttlSeconds = DEDUPE_TTL_SECONDS,
): Promise<boolean> {
  const namespacedKey = `axio7:agent-dedupe:${dedupeKey}`;
  const client = redisClient();
  if (client) {
    try {
      if (client.status === 'wait') await client.connect();
      const result = await client.set(namespacedKey, '1', 'EX', ttlSeconds, 'NX');
      return result === 'OK';
    } catch (error) {
      console.warn('[agent-graph] redis dedupe unavailable, using memory fallback', error);
    }
  }
  return acquireMemoryDedupe(namespacedKey, ttlSeconds);
}

export function resetDedupeForTests(): void {
  memoryDedupe.clear();
}

export function dedupeKeyForReply(postId: string, agentId: string, scope: string): string {
  return `${postId}:${agentId}:${scope}`;
}

export function normalizeForSimilarity(text: string): string {
  return text
    .toLowerCase()
    .replace(/https?:\/\/\S+/g, ' ')
    .replace(/[^a-z0-9\u4e00-\u9fff\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function tokenizeForSimilarity(text: string): Set<string> {
  return new Set(
    normalizeForSimilarity(text)
      .split(/\s+/)
      .filter((word) => word.length > 2),
  );
}

export function jaccardSimilarity(a: string, b: string): number {
  const aTokens = tokenizeForSimilarity(a);
  const bTokens = tokenizeForSimilarity(b);
  if (aTokens.size === 0 && bTokens.size === 0) return 1;
  if (aTokens.size === 0 || bTokens.size === 0) return 0;
  let intersection = 0;
  for (const token of aTokens) {
    if (bTokens.has(token)) intersection++;
  }
  const union = new Set([...aTokens, ...bTokens]).size;
  return union === 0 ? 0 : intersection / union;
}

export function isNearDuplicate(text: string, existing: string[], threshold = 0.62): boolean {
  const norm = normalizeForSimilarity(text);
  return existing.some((other) => {
    const otherNorm = normalizeForSimilarity(other);
    if (!norm || !otherNorm) return false;
    if (norm.includes(otherNorm) || otherNorm.includes(norm)) return true;
    return jaccardSimilarity(norm, otherNorm) >= threshold;
  });
}

const HARD_BLOCKLIST = [
  /\bnigg/i,
  /\bfag/i,
  /kill yourself/i,
  /\bkys\b/i,
  /\brape\b/i,
  /\bchink\b/i,
  /api key/i,
  /system prompt/i,
];

const SOFT_BLOCKLIST = [
  /suicide/i,
  /self[-\s]?harm/i,
  /overdose/i,
  /medical emergency/i,
];

export function moderateText(text: string): { action: 'pass' | 'review' | 'drop'; reason?: string } {
  if (HARD_BLOCKLIST.some((rx) => rx.test(text))) return { action: 'drop', reason: 'hard moderation pattern' };
  if (SOFT_BLOCKLIST.some((rx) => rx.test(text))) return { action: 'review', reason: 'soft moderation pattern' };
  return { action: 'pass' };
}

function scoreAction(total: number): QualityAction {
  if (total >= 70) return 'publish';
  if (total >= 50) return 'retry';
  if (total >= 30) return 'review';
  return 'drop';
}

export function scoreAgentReply(input: {
  text: string;
  sourceText: string;
  agent?: AgentPersona | null;
  existingTexts?: string[];
  maxWords?: number;
}): RuleQualityScore {
  const text = input.text.trim();
  const words = text.split(/\s+/).filter(Boolean);
  const reasons: string[] = [];
  const moderation = moderateText(text);

  const sourceTokens = tokenizeForSimilarity(input.sourceText);
  const textTokens = tokenizeForSimilarity(text);
  let overlap = 0;
  for (const token of textTokens) {
    if (sourceTokens.has(token)) overlap++;
  }

  let relevance = Math.min(25, Math.round((overlap / Math.max(1, Math.min(sourceTokens.size, 18))) * 25));
  if (input.sourceText.length < 30 && text.length > 25) relevance = Math.max(relevance, 14);
  if (relevance < 10) reasons.push('relevance: weak connection to the source post');

  const hasConcreteMarker =
    /\b(columbia|nyc|morningside|harlem|uws|brooklyn|manhattan|ticker|market|earnings|filing|options|ticket|event|desk|sofa|startup|offer|salary|\$\d+|\d{1,2}\/\d{1,2}|\d+\s?(min|minutes|hours|days|blocks))\b/i.test(text);
  let specificity = 8;
  if (hasConcreteMarker) specificity += 9;
  if (words.length >= 14) specificity += 4;
  if (/[?]/.test(text)) specificity += 2;
  if (/\b(try|ask|check|compare|message|bring|list|price|budget|route|email|dm)\b/i.test(text)) specificity += 2;
  specificity = Math.min(25, specificity);
  if (specificity < 14) reasons.push('specificity: needs one concrete detail or action');

  const agentTopics = input.agent?.topics ?? [];
  const topicHits = agentTopics.filter((topic) => normalizeForSimilarity(text).includes(topic.toLowerCase())).length;
  let personaFit = Math.min(20, 10 + topicHits * 3);
  if (input.agent && new RegExp(input.agent.name, 'i').test(text)) personaFit = Math.min(20, personaFit + 2);
  if (/as an ai|i am an ai|cannot assist|i can't help/i.test(text)) personaFit = Math.max(0, personaFit - 8);
  if (personaFit < 12) reasons.push('personaFit: voice is not clearly tied to the agent domain');

  const existing = input.existingTexts ?? [];
  const duplicate = isNearDuplicate(text, existing);
  let novelty = duplicate ? 2 : 15;
  if (duplicate) reasons.push('novelty: repeats an existing reply or generated draft');

  let safety = moderation.action === 'drop' ? 0 : moderation.action === 'review' ? 5 : 10;
  if (moderation.reason) reasons.push(`safety: ${moderation.reason}`);

  const maxWords = input.maxWords ?? 70;
  let format = 5;
  if (words.length > maxWords) {
    format = 1;
    reasons.push(`format: over ${maxWords} words`);
  } else if (words.length < 6) {
    format = 1;
    reasons.push('format: too short');
  }
  if (/^["']|["']$/.test(text)) {
    format = Math.max(0, format - 1);
    reasons.push('format: output should not be wrapped in quotes');
  }

  const total = relevance + specificity + personaFit + novelty + safety + format;
  let action = scoreAction(total);
  if (moderation.action === 'drop') action = 'drop';
  if (moderation.action === 'review' && action === 'publish') action = 'review';
  if (duplicate && action === 'publish') action = 'review';

  return { total, relevance, specificity, personaFit, novelty, safety, format, reasons, action };
}

export function retryFeedbackPrompt(score: RuleQualityScore): string {
  const feedback = score.reasons.length
    ? score.reasons.slice(0, 4).map((reason) => `- ${reason}`).join('\n')
    : '- specificity: add one concrete detail\n- novelty: avoid repeating the previous draft';
  return `Your previous reply was rejected for:
${feedback}
Rewrite it.
Keep the same persona.
Do not repeat the previous draft.
Add one concrete detail.
Keep it under 70 words.`;
}

export function replyTexts(replies: Reply[]): string[] {
  return replies.map((reply) => reply.content);
}

export type RetryPolicy = {
  maxAttempts: number;
  backoffMs: number[];
  jitterMs: number;
  timeoutMs: number;
};

export const DEFAULT_AGENT_RETRY_POLICY: RetryPolicy = {
  maxAttempts: 3,
  backoffMs: [800, 2000, 5000],
  jitterMs: 400,
  timeoutMs: 25_000,
};

export function errorStatus(error: any): number | null {
  const status = error?.status ?? error?.response?.status ?? error?.code;
  if (typeof status === 'number') return status;
  const parsed = Number(status);
  return Number.isFinite(parsed) ? parsed : null;
}

export function isRetryableAgentError(error: any): boolean {
  const status = errorStatus(error);
  const message = String(error?.message ?? error?.error?.message ?? '').toLowerCase();
  if (message.includes('timeout') || error?.name === 'TimeoutError') return true;
  return status === 429 || status === 500 || status === 502 || status === 503 || status === 504;
}

export function isNonRetryableAgentError(error: any): boolean {
  const status = errorStatus(error);
  const message = String(error?.message ?? error?.error?.message ?? '').toLowerCase();
  return status === 400 ||
    status === 401 ||
    status === 403 ||
    message.includes('model_not_found') ||
    (message.includes('model') && message.includes('not found'));
}

function retryAfterMs(error: any): number | null {
  const raw =
    error?.headers?.['retry-after'] ??
    error?.response?.headers?.['retry-after'] ??
    error?.response?.headers?.get?.('retry-after');
  if (!raw) return null;
  const seconds = Number(raw);
  if (Number.isFinite(seconds)) return Math.min(10_000, Math.max(0, seconds * 1000));
  const dateMs = Date.parse(String(raw));
  if (!Number.isFinite(dateMs)) return null;
  return Math.min(10_000, Math.max(0, dateMs - Date.now()));
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | null = null;
  try {
    return await Promise.race([
      promise,
      new Promise<T>((_, reject) => {
        timer = setTimeout(() => {
          const error = new Error(`agent timed out after ${timeoutMs}ms`);
          error.name = 'TimeoutError';
          reject(error);
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timer) clearTimeout(timer);
  }
}

export async function runWithRetry<T>(
  run: (attempt: number) => Promise<T>,
  policy: RetryPolicy = DEFAULT_AGENT_RETRY_POLICY,
): Promise<{ value: T; attempts: number; latencyMs: number }> {
  const startedAt = Date.now();
  let lastError: unknown = null;
  for (let attempt = 1; attempt <= policy.maxAttempts; attempt++) {
    try {
      const value = await withTimeout(run(attempt), policy.timeoutMs);
      return { value, attempts: attempt, latencyMs: Date.now() - startedAt };
    } catch (error) {
      lastError = error;
      if (isNonRetryableAgentError(error) || !isRetryableAgentError(error) || attempt >= policy.maxAttempts) {
        throw error;
      }
      const retryAfter = retryAfterMs(error);
      const base = retryAfter ?? policy.backoffMs[Math.min(attempt - 1, policy.backoffMs.length - 1)];
      const jitter = Math.floor(Math.random() * (policy.jitterMs + 1));
      await sleep(base + jitter);
    }
  }
  throw lastError ?? new Error('retry failed without error');
}

export async function runLimitedByProvider<T, R>(
  items: T[],
  getProviderKey: (item: T) => string,
  worker: (item: T, index: number) => Promise<R>,
  opts: { maxConcurrency?: number; providerConcurrency?: number } = {},
): Promise<PromiseSettledResult<R>[]> {
  const maxConcurrency = opts.maxConcurrency ?? 3;
  const providerConcurrency = opts.providerConcurrency ?? 2;
  const results: PromiseSettledResult<R>[] = new Array(items.length);
  const launched = new Set<number>();
  const providerActive = new Map<string, number>();
  let active = 0;
  let nextIndex = 0;
  let completed = 0;

  return await new Promise((resolve) => {
    const launch = () => {
      while (active < maxConcurrency && nextIndex < items.length) {
        let picked = -1;
        for (let i = nextIndex; i < items.length; i++) {
          if (launched.has(i)) continue;
          const key = getProviderKey(items[i]) || 'default';
          if ((providerActive.get(key) ?? 0) < providerConcurrency) {
            picked = i;
            break;
          }
        }
        if (picked === -1) break;
        if (picked === nextIndex) {
          nextIndex++;
        }
        launched.add(picked);
        const item = items[picked];
        const key = getProviderKey(item) || 'default';
        active++;
        providerActive.set(key, (providerActive.get(key) ?? 0) + 1);

        worker(item, picked)
          .then((value) => {
            results[picked] = { status: 'fulfilled', value };
          })
          .catch((reason) => {
            results[picked] = { status: 'rejected', reason };
          })
          .finally(() => {
            active--;
            providerActive.set(key, Math.max(0, (providerActive.get(key) ?? 1) - 1));
            completed++;
            if (completed >= items.length) resolve(results);
            else launch();
          });
      }
    };
    launch();
  });
}

export function providerKeyForAgent(agent: AgentPersona): string {
  const model = agent.model ?? '';
  return model.includes('/') ? model.split('/')[0] : 'default';
}

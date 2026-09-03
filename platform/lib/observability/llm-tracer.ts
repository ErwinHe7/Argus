import { Langfuse } from 'langfuse';
import { estimateCost } from './pricing';

let langfuse: Langfuse | null = null;

function getLangfuse(): Langfuse | null {
  if (langfuse) return langfuse;
  const publicKey = process.env.LANGFUSE_PUBLIC_KEY;
  const secretKey = process.env.LANGFUSE_SECRET_KEY;
  if (!publicKey || !secretKey) return null;
  langfuse = new Langfuse({
    publicKey,
    secretKey,
    baseUrl: process.env.LANGFUSE_HOST || 'https://cloud.langfuse.com',
  });
  return langfuse;
}

export type TraceContext = {
  traceId: string;
  postId: string;
  userId: string;
};

export function startPostTrace(postId: string, userId: string): TraceContext {
  const lf = getLangfuse();
  if (!lf) return { traceId: postId, postId, userId };
  try {
    lf.trace({
      id: postId,
      name: 'agent-fanout',
      userId,
      metadata: { post_id: postId },
    });
  } catch (err) {
    console.warn('[langfuse] trace start failed', err);
  }
  return { traceId: postId, postId, userId };
}

export type TracedCallResult = {
  content: string;
  promptTokens: number;
  completionTokens: number;
  latencyMs: number;
  costUsd: number;
};

export async function tracedLLMCall(
  agent: { id: string; name: string; model?: string },
  prompt: string,
  modelCallFn: () => Promise<{
    content: string;
    usage?: { prompt_tokens?: number; completion_tokens?: number };
  }>,
  ctx: TraceContext
): Promise<TracedCallResult> {
  const lf = getLangfuse();
  const model = agent.model || 'unknown';
  const start = Date.now();

  // Use a generation (LLM call) under the parent trace
  let generation: ReturnType<Langfuse['generation']> | null = null;
  if (lf) {
    try {
      generation = lf.generation({
        traceId: ctx.traceId,
        name: agent.id,
        model,
        input: [{ role: 'user', content: prompt }],
        metadata: {
          agent_name: agent.name,
          post_id: ctx.postId,
          user_id: ctx.userId,
        },
      });
    } catch (err) {
      console.warn('[langfuse] generation start failed', err);
    }
  }

  try {
    const result = await modelCallFn();
    const latencyMs = Date.now() - start;
    const promptTokens = result.usage?.prompt_tokens ?? 0;
    const completionTokens = result.usage?.completion_tokens ?? 0;
    const costUsd = estimateCost(model, promptTokens, completionTokens);

    if (generation) {
      try {
        generation.end({
          output: result.content,
          usage: {
            promptTokens,
            completionTokens,
            totalTokens: promptTokens + completionTokens,
          },
          metadata: { latency_ms: latencyMs, cost_usd: costUsd },
        });
      } catch (err) {
        console.warn('[langfuse] generation end failed', err);
      }
    }

    return { content: result.content, promptTokens, completionTokens, latencyMs, costUsd };
  } catch (err) {
    const latencyMs = Date.now() - start;
    if (generation) {
      try {
        generation.end({
          metadata: { error: String(err), latency_ms: latencyMs },
          level: 'ERROR',
        });
      } catch (spanErr) {
        console.warn('[langfuse] generation error end failed', spanErr);
      }
    }
    throw err;
  }
}

export async function flushTraces(): Promise<void> {
  const lf = getLangfuse();
  if (!lf) return;
  try {
    await lf.flushAsync();
  } catch (err) {
    console.warn('[langfuse] flush failed', err);
  }
}

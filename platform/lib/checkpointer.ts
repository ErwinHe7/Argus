/**
 * Redis checkpointer for LangGraph.
 *
 * Uses Upstash Redis (free tier, Vercel-native) or any Redis via REDIS_URL.
 * If REDIS_URL is not set, returns undefined — graph runs without persistence.
 *
 * To enable on Vercel:
 *   Vercel Dashboard → Storage → Create → Upstash Redis (free tier)
 *   → Connect to project → env vars REDIS_URL + REDIS_TOKEN auto-added
 *
 * What checkpointing gives you:
 *   - Each node's state saved to Redis after execution
 *   - Pipeline crash mid-way → resume from last checkpoint on retry
 *   - Same thread_id = same conversation thread (future: per-user memory)
 */

import { RedisSaver } from '@langchain/langgraph-checkpoint-redis';

let _saverPromise: Promise<RedisSaver> | undefined;

export async function getCheckpointer(): Promise<RedisSaver | undefined> {
  const url = process.env.REDIS_URL;
  if (!url) return undefined;

  if (!_saverPromise) {
    _saverPromise = RedisSaver.fromUrl(url).catch(() => {
      _saverPromise = undefined; // reset on failure so next call can retry
      return undefined as any;
    });
  }
  return _saverPromise;
}

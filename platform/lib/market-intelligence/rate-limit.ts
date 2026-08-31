type Bucket = { count: number; windowStart: number };

declare global {
  // eslint-disable-next-line no-var
  var __axio7MarketRateBuckets: Map<string, Bucket> | undefined;
}

function buckets(): Map<string, Bucket> {
  if (!globalThis.__axio7MarketRateBuckets) globalThis.__axio7MarketRateBuckets = new Map();
  return globalThis.__axio7MarketRateBuckets;
}

export type RateLimitResult = {
  allowed: boolean;
  remaining: number;
  resetSeconds: number;
};

export function checkRateLimit(key: string, limit: number, windowMs: number): RateLimitResult {
  const now = Date.now();
  const bucketMap = buckets();
  const bucket = bucketMap.get(key);

  if (!bucket || now - bucket.windowStart >= windowMs) {
    bucketMap.set(key, { count: 1, windowStart: now });
    return { allowed: true, remaining: limit - 1, resetSeconds: Math.ceil(windowMs / 1000) };
  }

  if (bucket.count >= limit) {
    return {
      allowed: false,
      remaining: 0,
      resetSeconds: Math.ceil((windowMs - (now - bucket.windowStart)) / 1000),
    };
  }

  bucket.count += 1;
  return {
    allowed: true,
    remaining: limit - bucket.count,
    resetSeconds: Math.ceil((windowMs - (now - bucket.windowStart)) / 1000),
  };
}

export function rateLimitKey(req: { headers: Headers; ip?: string }, route: string): string {
  const fwd = req.headers.get('x-forwarded-for');
  const ip = fwd?.split(',')[0]?.trim() || req.headers.get('x-real-ip') || req.ip || 'unknown';
  return `${route}:${ip}`;
}

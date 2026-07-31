import type { NextRequest } from 'next/server';
import { GUEST_COOKIE, normalizeAxioHandle } from './guest-identity';

type Bucket = {
  count: number;
  resetAt: number;
};

type Hit = {
  at: number;
  method: string;
  path: string;
};

type ApiProtectionResult =
  | { allowed: true; headers: Record<string, string> }
  | {
      allowed: false;
      status: 403 | 429;
      code: 'bot_detected' | 'rate_limited' | 'behavior_frequency';
      message: string;
      headers: Record<string, string>;
    };

type LimitProfile = {
  name: 'read' | 'write' | 'expensive';
  minuteIp: number;
  minuteIdentity: number;
  tenMinuteIp: number;
  tenMinuteIdentity: number;
  behaviorTotal: number;
  behaviorSamePath: number;
};

const MINUTE = 60_000;
const TEN_MINUTES = 10 * MINUTE;
const BEHAVIOR_WINDOW = 10_000;

const BOT_UA =
  /\b(?:bot|crawler|spider|scrapy|wget|curl|python-requests|aiohttp|httpclient|go-http-client|libwww-perl|nikto|sqlmap|headlesschrome|phantomjs|puppeteer)\b/i;
const BROWSERISH_UA = /\b(?:mozilla|chrome|safari|firefox|edg|opr|mobile|crios|fxios)\b/i;
const PUBLIC_MARKET_READ_PATHS = [
  '/api/market/signals',
  '/api/context/v1',
  '/api/quant/research/status',
];

const globalProtection = globalThis as typeof globalThis & {
  __axio7RateBuckets?: Map<string, Bucket>;
  __axio7BehaviorHits?: Map<string, Hit[]>;
  __axio7ProtectionOps?: number;
};

const buckets = globalProtection.__axio7RateBuckets ?? new Map<string, Bucket>();
const behaviorHits = globalProtection.__axio7BehaviorHits ?? new Map<string, Hit[]>();
globalProtection.__axio7RateBuckets = buckets;
globalProtection.__axio7BehaviorHits = behaviorHits;
globalProtection.__axio7ProtectionOps ??= 0;

function clientIp(req: NextRequest): string {
  const forwarded = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim();
  return (
    forwarded ||
    req.headers.get('x-real-ip') ||
    req.headers.get('cf-connecting-ip') ||
    'unknown'
  );
}

function isAuthorizedCron(req: NextRequest): boolean {
  if (!req.nextUrl.pathname.startsWith('/api/cron/')) return false;
  const secrets = [
    ...(req.nextUrl.pathname === '/api/cron/market-monitors'
      ? [process.env.MARKET_MONITOR_CRON_SECRET]
      : []),
    process.env.CRON_SECRET,
  ].filter((secret): secret is string => Boolean(secret));
  if (secrets.length === 0) return true;
  const header =
    req.headers.get('x-cron-secret') ||
    req.headers.get('authorization')?.replace(/^Bearer\s+/i, '');
  return secrets.some((secret) => header === secret);
}

function profileFor(path: string, method: string): LimitProfile {
  const mutating = !['GET', 'HEAD', 'OPTIONS'].includes(method.toUpperCase());
  const highCost =
    path.startsWith('/api/ask') ||
    path.startsWith('/api/quant/research') ||
    path.startsWith('/api/fanout') ||
    path.startsWith('/api/mention') ||
    path.startsWith('/api/agent-reply') ||
    path.startsWith('/api/upload') ||
    path.startsWith('/api/photo/remove-background') ||
    path.startsWith('/api/agents/');

  if (highCost) {
    return {
      name: 'expensive',
      minuteIp: 28,
      minuteIdentity: 12,
      tenMinuteIp: 90,
      tenMinuteIdentity: 45,
      behaviorTotal: 12,
      behaviorSamePath: 7,
    };
  }

  if (mutating) {
    return {
      name: 'write',
      minuteIp: 45,
      minuteIdentity: 22,
      tenMinuteIp: 160,
      tenMinuteIdentity: 80,
      behaviorTotal: 18,
      behaviorSamePath: 10,
    };
  }

  return {
    name: 'read',
    minuteIp: 140,
    minuteIdentity: 80,
    tenMinuteIp: 700,
    tenMinuteIdentity: 360,
    behaviorTotal: 50,
    behaviorSamePath: 34,
  };
}

function hitBucket(key: string, limit: number, windowMs: number, now: number) {
  const existing = buckets.get(key);
  const bucket =
    existing && existing.resetAt > now
      ? existing
      : { count: 0, resetAt: now + windowMs };

  bucket.count += 1;
  buckets.set(key, bucket);

  return {
    allowed: bucket.count <= limit,
    remaining: Math.max(0, limit - bucket.count),
    resetAt: bucket.resetAt,
  };
}

function recordBehavior(key: string, method: string, path: string, now: number) {
  const fresh = (behaviorHits.get(key) ?? []).filter((hit) => now - hit.at <= BEHAVIOR_WINDOW);
  fresh.push({ at: now, method, path });
  behaviorHits.set(key, fresh);

  return {
    total: fresh.length,
    samePath: fresh.filter((hit) => hit.path === path && hit.method === method).length,
  };
}

function cleanup(now: number) {
  globalProtection.__axio7ProtectionOps = (globalProtection.__axio7ProtectionOps ?? 0) + 1;
  if (globalProtection.__axio7ProtectionOps % 500 !== 0) return;

  for (const [key, bucket] of buckets.entries()) {
    if (bucket.resetAt <= now) buckets.delete(key);
  }
  for (const [key, hits] of behaviorHits.entries()) {
    const fresh = hits.filter((hit) => now - hit.at <= BEHAVIOR_WINDOW);
    if (fresh.length === 0) behaviorHits.delete(key);
    else behaviorHits.set(key, fresh);
  }
}

function deny(
  status: 403 | 429,
  code: ApiProtectionResult extends infer R
    ? R extends { allowed: false; code: infer C }
      ? C
      : never
    : never,
  message: string,
  retryAfterSeconds = 60
): ApiProtectionResult {
  return {
    allowed: false,
    status,
    code,
    message,
    headers: {
      'x-axio7-protection': code,
      ...(status === 429 ? { 'retry-after': String(retryAfterSeconds) } : {}),
    },
  };
}

export function protectApiRequest(req: NextRequest): ApiProtectionResult {
  const path = req.nextUrl.pathname;
  if (!path.startsWith('/api/')) return { allowed: true, headers: {} };
  // Payment providers authenticate these routes with signed raw request
  // bodies. They must not be blocked by browser-oriented bot detection or
  // in-memory rate limits.
  if (
    req.method === 'OPTIONS' ||
    path === '/api/health' ||
    path === '/api/stripe/webhook' ||
    path === '/api/lemonsqueezy/webhook' ||
    path === '/api/paddle/webhook' ||
    path === '/api/market/moomoo/relay' ||
    isAuthorizedCron(req)
  ) {
    return { allowed: true, headers: { 'x-axio7-protection': 'bypass' } };
  }

  const now = Date.now();
  cleanup(now);

  const ip = clientIp(req);
  const rawGuest = req.cookies.get(GUEST_COOKIE)?.value;
  const identity = rawGuest ? normalizeAxioHandle(rawGuest) : `anon:${ip}`;
  const method = req.method.toUpperCase();
  const ua = (req.headers.get('user-agent') || '').trim();
  const profile = profileFor(path, method);

  const publicMarketRead = method === 'GET' && PUBLIC_MARKET_READ_PATHS.some((prefix) => path.startsWith(prefix));

  if (ua && BOT_UA.test(ua) && !publicMarketRead) {
    return deny(403, 'bot_detected', 'Automated clients are not allowed on AXIO7 API routes.');
  }

  const browserish = BROWSERISH_UA.test(ua);
  const suspiciousClient = !ua || !browserish;
  const behavior = recordBehavior(`behavior:${ip}:${identity}`, method, path, now);
  const behaviorTotalLimit = suspiciousClient ? Math.max(4, Math.floor(profile.behaviorTotal / 2)) : profile.behaviorTotal;
  const behaviorPathLimit = suspiciousClient ? Math.max(3, Math.floor(profile.behaviorSamePath / 2)) : profile.behaviorSamePath;

  if (behavior.total > behaviorTotalLimit || behavior.samePath > behaviorPathLimit) {
    return deny(429, 'behavior_frequency', 'Too many API requests too quickly. Please slow down.', 20);
  }

  const limiterPenalty = suspiciousClient ? 0.6 : 1;
  const checks = [
    hitBucket(`ip:1m:${ip}:${profile.name}`, Math.floor(profile.minuteIp * limiterPenalty), MINUTE, now),
    hitBucket(`id:1m:${identity}:${profile.name}`, Math.floor(profile.minuteIdentity * limiterPenalty), MINUTE, now),
    hitBucket(`ip:10m:${ip}:${profile.name}`, Math.floor(profile.tenMinuteIp * limiterPenalty), TEN_MINUTES, now),
    hitBucket(`id:10m:${identity}:${profile.name}`, Math.floor(profile.tenMinuteIdentity * limiterPenalty), TEN_MINUTES, now),
  ];

  const blocked = checks.find((check) => !check.allowed);
  if (blocked) {
    return deny(
      429,
      'rate_limited',
      'API rate limit reached. Please wait a moment and try again.',
      Math.max(1, Math.ceil((blocked.resetAt - now) / 1000))
    );
  }

  const remaining = Math.min(...checks.map((check) => check.remaining));
  const resetAt = Math.min(...checks.map((check) => check.resetAt));
  return {
    allowed: true,
    headers: {
      'x-axio7-protection': profile.name,
      'x-ratelimit-remaining': String(remaining),
      'x-ratelimit-reset': String(Math.ceil(resetAt / 1000)),
    },
  };
}

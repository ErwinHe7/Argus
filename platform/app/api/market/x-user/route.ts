import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { recordAudit } from '@/lib/market-intelligence/audit';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 30;

const ROUTE = '/api/market/x-user';
const TICKER_RE = /\$[A-Z]{1,6}(?:\.[A-Z])?\b/g;

const QuerySchema = z.object({
  handle: z
    .string()
    .min(1)
    .max(20)
    .regex(/^[A-Za-z0-9_]+$/, 'handle may only contain letters, digits, and underscore'),
  max_results: z.coerce.number().int().min(5).max(100).default(50),
});

type XUserResponse = {
  data?: {
    id: string;
    username: string;
    name?: string;
    description?: string;
    verified?: boolean;
    public_metrics?: {
      followers_count?: number;
      following_count?: number;
      tweet_count?: number;
    };
    created_at?: string;
  };
  errors?: Array<{ message?: string; detail?: string }>;
};

type XTimelineResponse = {
  data?: Array<{
    id: string;
    text: string;
    created_at?: string;
    public_metrics?: {
      retweet_count?: number;
      reply_count?: number;
      like_count?: number;
      quote_count?: number;
      impression_count?: number;
    };
    referenced_tweets?: Array<{ type: 'replied_to' | 'quoted' | 'retweeted'; id: string }>;
    entities?: {
      urls?: Array<{ expanded_url?: string; display_url?: string }>;
      hashtags?: Array<{ tag?: string }>;
      cashtags?: Array<{ tag?: string }>;
      mentions?: Array<{ username?: string }>;
    };
  }>;
  meta?: { result_count?: number; next_token?: string };
  errors?: Array<{ message?: string; detail?: string }>;
};

export async function GET(req: NextRequest) {
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(
    key,
    Number(process.env.X_USER_RATE_LIMIT || 12),
    Number(process.env.X_USER_RATE_WINDOW_MS || 60_000)
  );
  if (!rate.allowed) {
    return NextResponse.json(
      { error: 'Rate limit.' },
      { status: 429, headers: { 'Retry-After': String(rate.resetSeconds) } }
    );
  }

  const parsed = QuerySchema.safeParse({
    handle: req.nextUrl.searchParams.get('handle') || '',
    max_results: req.nextUrl.searchParams.get('max_results') || '50',
  });
  if (!parsed.success) {
    return NextResponse.json(
      { error: 'Invalid handle.', issues: parsed.error.flatten() },
      { status: 400 }
    );
  }

  const token = process.env.X_BEARER_TOKEN;
  if (!token) {
    return NextResponse.json(
      {
        error: 'X_BEARER_TOKEN not configured on the server.',
        provider: 'unavailable',
        hint: 'Add a paid X API v2 bearer token (Basic tier or above) at https://developer.x.com to enable this endpoint.',
      },
      { status: 503 }
    );
  }

  try {
    const user = await fetchXUser(parsed.data.handle, token);
    if (!user) {
      return NextResponse.json(
        { error: `X user @${parsed.data.handle} not found or not accessible.` },
        { status: 404 }
      );
    }

    const timeline = await fetchXTimeline(user.id, parsed.data.max_results, token);

    const tweets = (timeline.data || []).map((tweet) => {
      const metrics = tweet.public_metrics || {};
      const engagement =
        (metrics.like_count || 0) +
        (metrics.retweet_count || 0) * 2 +
        (metrics.quote_count || 0) * 3 +
        (metrics.reply_count || 0);
      const cashtags = (tweet.entities?.cashtags || [])
        .map((c) => c.tag?.toUpperCase())
        .filter(Boolean) as string[];
      const fallbackTickers = (tweet.text.match(TICKER_RE) || []).map((m) => m.replace(/^\$/, ''));
      const tickers = Array.from(new Set([...cashtags, ...fallbackTickers]));
      const isRT = tweet.referenced_tweets?.some((r) => r.type === 'retweeted');
      const isReply = tweet.referenced_tweets?.some((r) => r.type === 'replied_to');
      const isQuote = tweet.referenced_tweets?.some((r) => r.type === 'quoted');
      return {
        id: tweet.id,
        text: tweet.text,
        createdAt: tweet.created_at || new Date().toISOString(),
        url: `https://x.com/${user.username}/status/${tweet.id}`,
        engagement,
        metrics: {
          likes: metrics.like_count || 0,
          retweets: metrics.retweet_count || 0,
          replies: metrics.reply_count || 0,
          quotes: metrics.quote_count || 0,
          impressions: metrics.impression_count || 0,
        },
        tickers,
        hashtags: (tweet.entities?.hashtags || []).map((h) => h.tag).filter(Boolean),
        mentions: (tweet.entities?.mentions || []).map((m) => m.username).filter(Boolean),
        links: (tweet.entities?.urls || []).map((u) => u.expanded_url).filter(Boolean) as string[],
        kind: isRT ? 'retweet' : isQuote ? 'quote' : isReply ? 'reply' : 'original',
      };
    });

    const tickerCounts = new Map<string, number>();
    for (const t of tweets) {
      for (const tk of t.tickers) tickerCounts.set(tk, (tickerCounts.get(tk) || 0) + 1);
    }
    const hotTickers = Array.from(tickerCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([ticker, mentions]) => ({ ticker, mentions }));

    const top = [...tweets].sort((a, b) => b.engagement - a.engagement).slice(0, 10);

    await recordAudit({
      route: ROUTE,
      actor: key,
      action: 'x_user_timeline',
      status: 'ok',
      meta: { handle: parsed.data.handle, fetched: tweets.length },
    });

    return NextResponse.json(
      {
        provider: 'x_api_v2',
        user: {
          id: user.id,
          handle: user.username,
          name: user.name || user.username,
          description: user.description || '',
          verified: user.verified || false,
          followers: user.public_metrics?.followers_count || 0,
          following: user.public_metrics?.following_count || 0,
          tweetCount: user.public_metrics?.tweet_count || 0,
          createdAt: user.created_at,
        },
        tweets,
        topByEngagement: top,
        hotTickers,
        generatedAt: new Date().toISOString(),
        disclaimer:
          'Data from the official X API v2 user timeline. Only the public timeline of the requested handle is read. AXIO7 does not store credentials, does not scrape, and does not bypass X auth.',
      },
      { headers: { 'Cache-Control': 'no-store', 'X-RateLimit-Remaining': String(rate.remaining) } }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : 'unknown';
    console.error('[/api/market/x-user]', message);
    await recordAudit({
      route: ROUTE,
      actor: key,
      action: 'x_user_error',
      status: 'error',
      meta: { handle: parsed.data.handle, message },
    });
    return NextResponse.json(
      { error: 'X user timeline fetch failed.', detail: message },
      { status: 502 }
    );
  }
}

async function fetchXUser(handle: string, token: string) {
  const url = new URL(`https://api.x.com/2/users/by/username/${encodeURIComponent(handle)}`);
  url.searchParams.set(
    'user.fields',
    'description,public_metrics,verified,created_at'
  );
  const res = await xFetch<XUserResponse>(url.toString(), token);
  if (res.errors?.length) {
    throw new Error(res.errors.map((e) => e.detail || e.message).filter(Boolean).join('; ') || 'X user lookup error');
  }
  return res.data;
}

async function fetchXTimeline(userId: string, maxResults: number, token: string) {
  const url = new URL(`https://api.x.com/2/users/${encodeURIComponent(userId)}/tweets`);
  url.searchParams.set('max_results', String(maxResults));
  url.searchParams.set(
    'tweet.fields',
    'created_at,public_metrics,entities,referenced_tweets'
  );
  url.searchParams.set('exclude', 'replies');
  const res = await xFetch<XTimelineResponse>(url.toString(), token);
  if (res.errors?.length) {
    throw new Error(res.errors.map((e) => e.detail || e.message).filter(Boolean).join('; ') || 'X timeline error');
  }
  return res;
}

async function xFetch<T>(url: string, token: string): Promise<T> {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), 9_000);
  try {
    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/json',
      },
      signal: controller.signal,
      cache: 'no-store',
    });
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new Error(`X API ${res.status}: ${text.slice(0, 240)}`);
    }
    return (await res.json()) as T;
  } finally {
    clearTimeout(t);
  }
}

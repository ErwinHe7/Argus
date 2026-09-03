// Influencer feed endpoint.
//
// Returns a per-influencer feed of recent posts, sourced from:
//   - X API v2 recent search (if X_BEARER_TOKEN configured)
//   - Truth Social vendor (if TRUTH_SOCIAL_PROVIDER_URL configured)
// Plus a config summary so the UI can render disabled accounts with a hint.
//
// No fixture/demo data — if a source isn't configured, the UI shows the
// monitor as "not connected" with a one-line setup hint.

import { NextRequest, NextResponse } from 'next/server';
import { getInfluencerMonitors, fetchAuthorizedMarketEvents, normalizeTickers } from '@/lib/market-intelligence/sources';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import type { InfluencerMonitor, MarketEvent } from '@/lib/market-intelligence/types';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 20;

const ROUTE = '/api/market/influencer-feed';

type InfluencerFeedItem = {
  id: string;
  source: 'x' | 'truth_social' | 'manual';
  postedAt: string;
  text: string;
  url?: string;
  tickers: string[];
  sentiment: MarketEvent['sentiment'];
  materiality: number;
  confidence: number;
  engagementScore?: number;
};

type InfluencerFeedEntry = {
  monitor: InfluencerMonitor;
  status: 'live' | 'disabled' | 'no_recent';
  reason: string;
  items: InfluencerFeedItem[];
};

type InfluencerFeedResponse = {
  generatedAt: string;
  configured: {
    xApi: boolean;
    truthVendor: boolean;
  };
  monitors: InfluencerFeedEntry[];
  flatItems: InfluencerFeedItem[];
  setupHint: string;
};

export async function GET(req: NextRequest) {
  const rate = checkRateLimit(rateLimitKey(req, ROUTE), 30, 60_000);
  if (!rate.allowed) {
    return NextResponse.json(
      { error: 'rate limited', resetSeconds: rate.resetSeconds },
      { status: 429 }
    );
  }

  const url = new URL(req.url);
  const watchlistParam = url.searchParams.get('watchlist') || '';
  const watchlist = normalizeTickers(watchlistParam.split(/[\s,]+/).filter(Boolean));
  const monitors = getInfluencerMonitors();

  const xApiOn = Boolean(process.env.X_BEARER_TOKEN);
  const truthOn = Boolean(process.env.TRUTH_SOCIAL_PROVIDER_URL && process.env.TRUTH_SOCIAL_PROVIDER_KEY);

  let events: MarketEvent[] = [];
  if (xApiOn || truthOn) {
    try {
      // Reuse existing X + Truth fetchers via fetchAuthorizedMarketEvents which already runs all sources.
      // We only consume X and Truth events from the returned set.
      const all = await fetchAuthorizedMarketEvents(watchlist, '');
      events = all.filter((e) => e.sourceKind === 'x_api' || e.sourceKind === 'truth_social');
    } catch (err) {
      console.warn('[influencer-feed] source fetch failed', err instanceof Error ? err.message : err);
    }
  }

  const entries: InfluencerFeedEntry[] = monitors.map((monitor) => {
    const matched = events.filter((e) => {
      if (e.influencer && e.influencer.toLowerCase() === monitor.displayName.toLowerCase()) return true;
      // Fallback: match by handle inside source name
      if (monitor.xHandle && e.sourceName.toLowerCase().includes(monitor.xHandle.toLowerCase())) return true;
      if (monitor.truthHandle && e.sourceName.toLowerCase().includes(monitor.truthHandle.toLowerCase())) return true;
      return false;
    });

    const items: InfluencerFeedItem[] = matched.map((e) => ({
      id: e.id,
      source: e.sourceKind === 'x_api' ? 'x' : e.sourceKind === 'truth_social' ? 'truth_social' : 'manual',
      postedAt: e.publishedAt,
      text: e.summary,
      url: e.url,
      tickers: e.tickers,
      sentiment: e.sentiment,
      materiality: e.materiality,
      confidence: e.confidence,
      engagementScore: parseEngagement(e),
    }));

    items.sort((a, b) => new Date(b.postedAt).getTime() - new Date(a.postedAt).getTime());

    let status: InfluencerFeedEntry['status'];
    let reason: string;
    if (!monitor.enabled) {
      status = 'disabled';
      const needs: string[] = [];
      if (monitor.xHandle && !xApiOn) needs.push('X_BEARER_TOKEN');
      if (monitor.truthHandle && !truthOn) needs.push('TRUTH_SOCIAL_PROVIDER_URL + KEY');
      if (!monitor.xHandle && !monitor.truthHandle) needs.push('INFLUENCER_* env handle');
      reason = needs.length ? `配置 ${needs.join(' / ')} 后启用` : '未配置';
    } else if (items.length === 0) {
      status = 'no_recent';
      reason = '已连接，但近 7 日内没有命中（或被 query 过滤）';
    } else {
      status = 'live';
      reason = `${items.length} 条近期发言`;
    }

    return { monitor, status, reason, items: items.slice(0, 8) };
  });

  const flatItems = entries
    .flatMap((e) => e.items.map((item) => ({ ...item, _influencer: e.monitor.displayName })))
    .sort((a, b) => new Date(b.postedAt).getTime() - new Date(a.postedAt).getTime())
    .slice(0, 20);

  const setupHint =
    !xApiOn && !truthOn
      ? '当前没有配置 X 或 Truth Social 凭据。设置 X_BEARER_TOKEN（X API v2）或 TRUTH_SOCIAL_PROVIDER_URL/KEY（授权 vendor）后会自动启用 influencer 直播流。在此之前，仍可在 Manual Event 面板粘贴 Trump/Elon/Jensen 的发言文本做完整事件分析。'
      : xApiOn && !truthOn
        ? 'X API 已启用；Truth Social 未配置 — Trump on Truth 暂走 manual paste。配置 TRUTH_SOCIAL_PROVIDER_URL/KEY 后启用。'
        : !xApiOn && truthOn
          ? 'Truth Social 已启用；X API 未配置 — Elon / Jensen / 其他 X 账号暂不可达。配置 X_BEARER_TOKEN 启用。'
          : 'X + Truth 全部启用。';

  const payload: InfluencerFeedResponse = {
    generatedAt: new Date().toISOString(),
    configured: { xApi: xApiOn, truthVendor: truthOn },
    monitors: entries,
    flatItems: flatItems.map((item) => {
      // Strip the internal _influencer field
      const { ...rest } = item;
      return rest as InfluencerFeedItem;
    }),
    setupHint,
  };

  return NextResponse.json(payload);
}

function parseEngagement(e: MarketEvent): number | undefined {
  const ev = e.evidence?.find((x) => x.label === 'engagement_score');
  if (!ev) return undefined;
  const n = Number(ev.value);
  return Number.isFinite(n) ? n : undefined;
}

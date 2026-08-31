import { NextRequest, NextResponse } from 'next/server';
import { getSourceStatuses, getInfluencerMonitors } from '@/lib/market-intelligence/sources';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const ROUTE = '/api/market/sources';

export async function GET(req: NextRequest) {
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 60, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });
  }

  const sources = getSourceStatuses().map((s) => ({
    ...s,
    mode: deriveMode(s.id, s.enabled),
    secretConfigured: s.productionReady,
  }));
  const influencers = getInfluencerMonitors();

  const macroFree = {
    id: 'fred',
    name: 'FRED (St. Louis Fed)',
    kind: 'macro',
    access: 'public',
    mode: process.env.FRED_API_KEY ? 'official_api' : 'public_csv',
    enabled: true,
    productionReady: true,
    coverage: '10Y-2Y spread, fed funds, CPI, unemployment, M2, DXY',
    setup: 'FRED_API_KEY optional; csv endpoint works without it',
  };
  const newsPulse = [
    {
      id: 'hackernews',
      name: 'Hacker News Algolia',
      kind: 'social',
      access: 'public',
      mode: 'public_search',
      enabled: true,
      productionReady: true,
      coverage: 'Front-page stories with company-name alias mapping',
      setup: 'No key required',
    },
    {
      id: 'gdelt',
      name: 'GDELT 2.0 Doc API',
      kind: 'news_api',
      access: 'public',
      mode: 'public_search',
      enabled: true,
      productionReady: true,
      coverage: 'Global news index with tone, rate-limited from datacenter IPs',
      setup: 'No key required',
    },
  ];
  const insider = {
    id: 'sec-form4',
    name: 'SEC EDGAR Form 4',
    kind: 'sec_edgar',
    access: 'public',
    mode: 'public_official',
    enabled: true,
    productionReady: true,
    coverage: 'Insider transactions for tracked tickers',
    setup: 'Set SEC_USER_AGENT for fair-access identification',
  };

  return NextResponse.json(
    {
      generatedAt: new Date().toISOString(),
      sources: [...sources, macroFree, ...newsPulse, insider],
      influencers,
      summary: {
        total: sources.length + 4,
        productionReady: sources.filter((s) => s.productionReady).length + 4,
      },
    },
    { headers: { 'Cache-Control': 'no-store' } }
  );
}

function deriveMode(id: string, enabled: boolean): string {
  if (!enabled) {
    if (id === 'x-recent') return process.env.X_SOURCE_MODE || 'fixture';
    if (id === 'truth-vendor') return process.env.TRUTH_SOURCE_MODE || 'manual';
    if (id === 'ibkr-client-portal') return process.env.IBKR_BASE_URL ? 'gateway_disabled' : 'gateway_not_configured';
    return 'disabled';
  }
  if (id === 'ibkr-client-portal') return 'client_portal_gateway';
  return 'official_api';
}

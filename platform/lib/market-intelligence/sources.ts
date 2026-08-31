import type { InfluencerMonitor, MarketEvent, SourceStatus } from './types';
import { createHash } from 'node:crypto';

const SEC_USER_AGENT =
  process.env.SEC_USER_AGENT ||
  process.env.MARKET_SEC_USER_AGENT ||
  '';
const SEC_CONTACT_EMAIL = SEC_USER_AGENT.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0];
const SEC_USER_AGENT_READY = Boolean(
  /AXIO7/i.test(SEC_USER_AGENT)
  && SEC_CONTACT_EMAIL
  && !/@(example|invalid|test)\./i.test(SEC_CONTACT_EMAIL)
);

const KNOWN_CIKS: Record<string, string> = {
  AAPL: '0000320193',
  AMD: '0000002488',
  AMZN: '0001018724',
  AVGO: '0001730168',
  COIN: '0001679788',
  GOOGL: '0001652044',
  META: '0001326801',
  MSFT: '0000789019',
  NFLX: '0001065280',
  NVDA: '0001045810',
  PLTR: '0001321655',
  SMCI: '0001375365',
  TSLA: '0001318605',
};

const DEFAULT_NEWS_QUERY = '(AI OR chips OR earnings OR merger OR lawsuit OR guidance OR Fed OR rates)';
const MATERIAL_FORMS = new Set(['8-K', '10-Q', '10-K', 'S-1', 'S-3', '424B5', 'DEF 14A', 'SC 13G', 'SC 13D']);

type SecSubmission = {
  filings?: {
    recent?: {
      accessionNumber?: string[];
      acceptanceDateTime?: string[];
      filingDate?: string[];
      reportDate?: string[];
      form?: string[];
      primaryDocument?: string[];
      primaryDocDescription?: string[];
    };
  };
};

type FinnhubNewsItem = {
  category?: string;
  datetime?: number;
  headline?: string;
  id?: number;
  related?: string;
  source?: string;
  summary?: string;
  url?: string;
};

type FinnhubQuote = {
  c?: number;
  d?: number;
  dp?: number;
  h?: number;
  l?: number;
  o?: number;
  pc?: number;
  t?: number;
};

type XRecentSearch = {
  data?: Array<{
    id: string;
    text: string;
    author_id?: string;
    created_at?: string;
    public_metrics?: { retweet_count?: number; reply_count?: number; like_count?: number; quote_count?: number };
  }>;
  includes?: {
    users?: Array<{ id: string; name?: string; username?: string }>;
  };
};

type NewsApiResponse = {
  articles?: Array<{
    title?: string;
    description?: string;
    url?: string;
    source?: { name?: string };
    publishedAt?: string;
  }>;
};

type LsegToken = { access_token?: string };
type LsegHeadlines = {
  data?: unknown[];
};

export function getInfluencerMonitors(): InfluencerMonitor[] {
  return [
    {
      id: 'trump',
      displayName: 'Donald Trump',
      xHandle: process.env.INFLUENCER_TRUMP_X || 'realDonaldTrump',
      truthHandle: process.env.INFLUENCER_TRUMP_TRUTH || 'realDonaldTrump',
      weight: 95,
      enabled: Boolean(process.env.X_BEARER_TOKEN || process.env.TRUTH_SOCIAL_PROVIDER_URL),
      notes:
        'Highest-impact macro / tariff / geopolitical signal. Truth Social posts require licensed provider; X posts require X_BEARER_TOKEN.',
    },
    {
      id: 'elon-musk',
      displayName: 'Elon Musk',
      xHandle: process.env.INFLUENCER_ELON_X || 'elonmusk',
      truthHandle: process.env.INFLUENCER_ELON_TRUTH || undefined,
      weight: 88,
      enabled: Boolean(process.env.X_BEARER_TOKEN),
      notes: 'High-impact X account: TSLA, crypto, AI. Requires X_BEARER_TOKEN.',
    },
    {
      id: 'jensen-huang',
      displayName: 'Jensen Huang / NVIDIA',
      xHandle: process.env.INFLUENCER_JENSEN_X || 'nvidia',
      truthHandle: process.env.INFLUENCER_JENSEN_TRUTH || undefined,
      weight: 82,
      enabled: Boolean(process.env.X_BEARER_TOKEN),
      notes:
        'NVIDIA corporate account (Jensen rarely tweets personally). Set INFLUENCER_JENSEN_X to override. Strong signal for AI / semis sector.',
    },
    {
      id: 'chamath',
      displayName: 'Chamath Palihapitiya',
      xHandle: process.env.INFLUENCER_CHAMATH_X || 'chamath',
      truthHandle: undefined,
      weight: 70,
      enabled: Boolean(process.env.X_BEARER_TOKEN),
      notes: 'VC commentary, occasionally moves SaaS / SPAC tickers.',
    },
    {
      id: 'unusual-whales',
      displayName: 'Unusual Whales',
      xHandle: process.env.INFLUENCER_UW_X || 'unusual_whales',
      truthHandle: undefined,
      weight: 75,
      enabled: Boolean(process.env.X_BEARER_TOKEN),
      notes: 'Options flow / political trades aggregator. High signal for unusual options activity.',
    },
    {
      id: 'zerohedge',
      displayName: 'ZeroHedge',
      xHandle: process.env.INFLUENCER_ZEROHEDGE_X || 'zerohedge',
      truthHandle: undefined,
      weight: 65,
      enabled: Boolean(process.env.X_BEARER_TOKEN),
      notes: 'Macro / geopolitical aggregator. Often early on breaking macro headlines; bias toward bearish framing.',
    },
    {
      id: 'serenity',
      displayName: 'Serenity',
      xHandle: process.env.INFLUENCER_SERENITY_X || undefined,
      truthHandle: process.env.INFLUENCER_SERENITY_TRUTH || undefined,
      weight: 72,
      enabled: Boolean(process.env.INFLUENCER_SERENITY_X || process.env.INFLUENCER_SERENITY_TRUTH),
      notes: 'Custom slot. Set INFLUENCER_SERENITY_X/TRUTH to activate.',
    },
    {
      id: 'bread',
      displayName: 'bread',
      xHandle: process.env.INFLUENCER_BREAD_X || undefined,
      truthHandle: process.env.INFLUENCER_BREAD_TRUTH || undefined,
      weight: 64,
      enabled: Boolean(process.env.INFLUENCER_BREAD_X || process.env.INFLUENCER_BREAD_TRUTH),
      notes: 'Custom slot. Set exact handle; do not fuzzy-match identity in production.',
    },
    {
      id: 'labubu-3x-long',
      displayName: '3x long labubu',
      xHandle: process.env.INFLUENCER_LABUBU_X || undefined,
      truthHandle: process.env.INFLUENCER_LABUBU_TRUTH || undefined,
      weight: 60,
      enabled: Boolean(process.env.INFLUENCER_LABUBU_X || process.env.INFLUENCER_LABUBU_TRUTH),
      notes: 'Custom slot. Meme-risk; require corroboration before signal escalation.',
    },
  ];
}

export function getSourceStatuses(): SourceStatus[] {
  return [
    {
      id: 'reuters-lseg',
      name: 'Reuters via LSEG News API',
      kind: 'reuters_lseg',
      access: 'vendor',
      enabled: Boolean(process.env.LSEG_CLIENT_ID && process.env.LSEG_CLIENT_SECRET),
      latencyTargetMs: 1200,
      coverage: 'Reuters and licensed third-party headlines through LSEG Data Platform entitlements',
      setup: 'LSEG_CLIENT_ID, LSEG_CLIENT_SECRET, optional LSEG_NEWS_QUERY',
      productionReady: Boolean(process.env.LSEG_CLIENT_ID && process.env.LSEG_CLIENT_SECRET),
    },
    {
      id: 'x-recent',
      name: 'X API v2 recent search',
      kind: 'x_api',
      access: 'authorized',
      enabled: Boolean(process.env.X_BEARER_TOKEN),
      latencyTargetMs: 900,
      coverage: 'Official X API v2 recent search for watched influencers and keywords',
      setup: 'X_BEARER_TOKEN plus approved developer access',
      productionReady: Boolean(process.env.X_BEARER_TOKEN),
    },
    {
      id: 'truth-vendor',
      name: 'Truth Social authorized vendor/webhook',
      kind: 'truth_social',
      access: 'vendor',
      enabled: Boolean(process.env.TRUTH_SOCIAL_PROVIDER_URL && process.env.TRUTH_SOCIAL_PROVIDER_KEY),
      latencyTargetMs: 1500,
      coverage: 'Truth Social events only through an explicit licensed provider or webhook',
      setup: 'TRUTH_SOCIAL_PROVIDER_URL, TRUTH_SOCIAL_PROVIDER_KEY',
      productionReady: Boolean(process.env.TRUTH_SOCIAL_PROVIDER_URL && process.env.TRUTH_SOCIAL_PROVIDER_KEY),
    },
    {
      id: 'market-tape',
      name: 'Market tape',
      kind: 'market_tape',
      access: 'vendor',
      enabled: Boolean(process.env.FINNHUB_API_KEY),
      latencyTargetMs: 750,
      coverage: 'Price change, quote, and intraday move context from configured market-data provider',
      setup: 'FINNHUB_API_KEY or replace adapter with Polygon/IEX/Databento',
      productionReady: Boolean(process.env.FINNHUB_API_KEY),
    },
    {
      id: 'sec-edgar',
      name: 'SEC EDGAR',
      kind: 'sec_edgar',
      access: 'public',
      enabled: SEC_USER_AGENT_READY,
      latencyTargetMs: 1500,
      coverage: 'US issuer filings, 8-K, 10-Q, 10-K, S-1, ownership forms',
      setup: 'Set SEC_USER_AGENT for production fair-access identification.',
      productionReady: SEC_USER_AGENT_READY,
    },
    {
      id: 'finnhub-news',
      name: 'Finnhub company news',
      kind: 'news_api',
      access: 'vendor',
      enabled: Boolean(process.env.FINNHUB_API_KEY),
      latencyTargetMs: 1800,
      coverage: 'Ticker-level company news where FINNHUB_API_KEY is configured',
      setup: 'FINNHUB_API_KEY',
      productionReady: Boolean(process.env.FINNHUB_API_KEY),
    },
    {
      id: 'newsapi',
      name: 'Other news API',
      kind: 'news_api',
      access: 'vendor',
      enabled: Boolean(process.env.NEWSAPI_KEY),
      latencyTargetMs: 2000,
      coverage: 'Configurable general-news fallback for macro and broad market headlines',
      setup: 'NEWSAPI_KEY, optional MARKET_NEWS_QUERY',
      productionReady: Boolean(process.env.NEWSAPI_KEY),
    },
    {
      id: 'options-flow',
      name: 'Options flow vendor',
      kind: 'options_flow',
      access: 'vendor',
      enabled: Boolean(process.env.OPTIONS_FLOW_API_KEY),
      latencyTargetMs: 1100,
      coverage: 'Unusual contracts, volume/open-interest deltas, sweeps, IV context',
      setup: 'OPTIONS_FLOW_API_KEY from a licensed provider',
      productionReady: Boolean(process.env.OPTIONS_FLOW_API_KEY),
    },
    {
      id: 'polygon',
      name: 'Polygon.io market data + news',
      kind: 'polygon',
      access: 'vendor',
      enabled: Boolean(process.env.POLYGON_API_KEY),
      latencyTargetMs: 800,
      coverage: 'Real-time/delayed quotes, aggregates, news headlines via official Polygon REST',
      setup: 'POLYGON_API_KEY',
      productionReady: Boolean(process.env.POLYGON_API_KEY),
    },
    {
      id: 'ibkr-client-portal',
      name: 'IBKR Client Portal Gateway',
      kind: 'market_tape',
      access: 'authorized',
      enabled: Boolean(process.env.IBKR_BASE_URL && process.env.IBKR_MARKET_DATA_ENABLED === 'true'),
      latencyTargetMs: 1200,
      coverage: 'Read-only stock quote, bid/ask size, option contract lookup, and option top-of-book through IBKR Client Portal',
      setup: 'IBKR_BASE_URL, IBKR_MARKET_DATA_ENABLED=true, optional IBKR_SESSION_TOKEN / IBKR_ALLOW_INSECURE_TLS',
      productionReady: Boolean(process.env.IBKR_BASE_URL && process.env.IBKR_MARKET_DATA_ENABLED === 'true'),
    },
    {
      id: 'reddit',
      name: 'Reddit OAuth (WSB, options, stocks, investing, SPACs, cryptocurrency)',
      kind: 'reddit',
      access: 'authorized',
      enabled: Boolean(process.env.REDDIT_CLIENT_ID && process.env.REDDIT_CLIENT_SECRET),
      latencyTargetMs: 1200,
      coverage: 'Hot/new posts in WSB and related subs via official Reddit OAuth API',
      setup: 'REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET, REDDIT_USER_AGENT',
      productionReady: Boolean(process.env.REDDIT_CLIENT_ID && process.env.REDDIT_CLIENT_SECRET),
    },
  ];
}

export async function fetchAuthorizedMarketEvents(tickers: string[], query = ''): Promise<MarketEvent[]> {
  const cleanTickers = normalizeTickers(tickers);
  const influencers = getInfluencerMonitors();
  const [
    reutersEvents,
    xEvents,
    truthEvents,
    tapeEvents,
    secEvents,
    finnhubNews,
    otherNews,
    polygonEvents,
    redditEvents,
  ] = await Promise.all([
    fetchLsegReutersNews(cleanTickers, query).catch((err) => failSource('lseg', err)),
    fetchXInfluencerAndKeywordEvents(cleanTickers, influencers, query).catch((err) => failSource('x', err)),
    fetchTruthVendorEvents(cleanTickers, influencers).catch((err) => failSource('truth', err)),
    fetchMarketTape(cleanTickers).catch((err) => failSource('tape', err)),
    fetchSecFilings(cleanTickers).catch((err) => failSource('sec', err)),
    fetchFinnhubNews(cleanTickers).catch((err) => failSource('finnhub', err)),
    fetchOtherNews(cleanTickers, query).catch((err) => failSource('newsapi', err)),
    fetchPolygonNews(cleanTickers).catch((err) => failSource('polygon', err)),
    fetchRedditPosts(cleanTickers, query).catch((err) => failSource('reddit', err)),
  ]);

  const events = [
    ...reutersEvents,
    ...xEvents,
    ...truthEvents,
    ...tapeEvents,
    ...secEvents,
    ...finnhubNews,
    ...otherNews,
    ...polygonEvents,
    ...redditEvents,
  ].sort((a, b) => new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime());

  return events.slice(0, 48);
}

export function normalizeTickers(tickers: string[]): string[] {
  return Array.from(
    new Set(
      tickers
        .map((ticker) => ticker.replace(/^\$/, '').trim().toUpperCase())
        .filter((ticker) => /^[A-Z][A-Z0-9.]{0,5}$/.test(ticker))
    )
  ).slice(0, 30);
}

async function fetchLsegReutersNews(tickers: string[], query: string): Promise<MarketEvent[]> {
  const clientId = process.env.LSEG_CLIENT_ID;
  const clientSecret = process.env.LSEG_CLIENT_SECRET;
  if (!clientId || !clientSecret) return [];

  const token = await getLsegToken(clientId, clientSecret);
  if (!token) return [];

  const q = process.env.LSEG_NEWS_QUERY || buildReutersQuery(tickers, query);
  const url = new URL('https://api.refinitiv.com/data/news/v1/headlines');
  url.searchParams.set('query', q);
  url.searchParams.set('limit', '50');
  url.searchParams.set('sort', 'newToOld');
  url.searchParams.set('relevance', 'High');
  url.searchParams.set('dateFrom', new Date(Date.now() - 1000 * 60 * 60 * 24).toISOString());

  const data = await fetchJson<LsegHeadlines>(url.toString(), {
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
  });

  return (data.data || []).slice(0, 12).map((raw, index) => {
    const item = raw as Record<string, unknown>;
    const headline = pickString(item, ['headline', 'title', 'text', 'storyHeadline']) || 'Reuters/LSEG headline';
    const storyId = pickString(item, ['storyId', 'id', 'story_id']);
    return {
      id: `lseg-${storyId || stableId(JSON.stringify(item).slice(0, 500))}-${index}`,
      title: headline,
      summary: pickString(item, ['summary', 'description']) || headline,
      sourceName: 'Reuters / LSEG',
      sourceKind: 'reuters_lseg',
      sourceAccess: 'vendor',
      url: storyId ? `https://api.refinitiv.com/data/news/v1/stories/${encodeURIComponent(storyId)}` : undefined,
      publishedAt: pickDate(item, ['versionCreated', 'firstCreated', 'publishedAt', 'timestamp']) || new Date().toISOString(),
      tickers: normalizeTickers([...tickers, ...extractTickerLike(headline)]).slice(0, 8),
      sentiment: inferTextSentiment(headline),
      confidence: 90,
      materiality: 82,
      verification: 'reported',
      riskFlags: ['Licensed Reuters/LSEG content; respect entitlements and redistribution limits'],
      evidence: [{ label: 'query', value: q }, { label: 'provider', value: 'LSEG Data Platform' }],
    } satisfies MarketEvent;
  });
}

async function getLsegToken(clientId: string, clientSecret: string) {
  const body = new URLSearchParams();
  body.set('grant_type', 'client_credentials');
  body.set('client_id', clientId);
  body.set('client_secret', clientSecret);

  const data = await fetchJson<LsegToken>('https://api.refinitiv.com/auth/oauth2/v2/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body,
  });
  return data.access_token || null;
}

async function fetchXInfluencerAndKeywordEvents(
  tickers: string[],
  influencers: InfluencerMonitor[],
  query: string
): Promise<MarketEvent[]> {
  const token = process.env.X_BEARER_TOKEN;
  if (!token) return [];

  const activeHandles = influencers.map((inf) => inf.xHandle).filter(Boolean) as string[];
  const fromQuery = activeHandles.length ? activeHandles.map((handle) => `from:${handle}`).join(' OR ') : '';
  const keywordQuery = buildKeywordQuery(tickers, query);
  const xQuery = `(${[fromQuery, keywordQuery].filter(Boolean).join(' OR ')}) -is:retweet lang:en`;
  const url = new URL('https://api.x.com/2/tweets/search/recent');
  url.searchParams.set('query', xQuery.slice(0, 900));
  url.searchParams.set('max_results', '25');
  url.searchParams.set('tweet.fields', 'created_at,author_id,public_metrics,entities');
  url.searchParams.set('expansions', 'author_id');
  url.searchParams.set('user.fields', 'username,name');

  const data = await fetchJson<XRecentSearch>(url.toString(), {
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
  });
  const users = new Map((data.includes?.users || []).map((user) => [user.id, user]));

  return (data.data || []).map((tweet) => {
    const user = tweet.author_id ? users.get(tweet.author_id) : undefined;
    const influencer = influencers.find((inf) => inf.xHandle?.toLowerCase() === user?.username?.toLowerCase());
    const engagement =
      (tweet.public_metrics?.like_count || 0) +
      (tweet.public_metrics?.retweet_count || 0) * 2 +
      (tweet.public_metrics?.quote_count || 0) * 3 +
      (tweet.public_metrics?.reply_count || 0);
    return {
      id: `x-${tweet.id}`,
      title: `${user?.username ? `@${user.username}` : 'X'}: ${tweet.text.slice(0, 96)}`,
      summary: tweet.text,
      sourceName: user?.username ? `X @${user.username}` : 'X API',
      sourceKind: 'x_api',
      sourceAccess: 'authorized',
      url: user?.username ? `https://x.com/${user.username}/status/${tweet.id}` : `https://x.com/i/web/status/${tweet.id}`,
      publishedAt: tweet.created_at || new Date().toISOString(),
      tickers: normalizeTickers([...tickers, ...extractTickerLike(tweet.text)]).slice(0, 8),
      sentiment: inferTextSentiment(tweet.text),
      confidence: influencer ? 78 : 62,
      materiality: clamp(42 + Math.min(35, Math.round(Math.log10(engagement + 1) * 12)) + (influencer?.weight || 0) / 6, 0, 100),
      verification: 'social',
      influencer: influencer?.displayName,
      riskFlags: influencer ? ['Influencer signal; require corroboration before escalation'] : ['Social signal; lower confidence without source confirmation'],
      evidence: [
        { label: 'x_query', value: xQuery.slice(0, 240) },
        { label: 'engagement_score', value: String(engagement) },
      ],
    } satisfies MarketEvent;
  });
}

async function fetchTruthVendorEvents(tickers: string[], influencers: InfluencerMonitor[]): Promise<MarketEvent[]> {
  const endpoint = process.env.TRUTH_SOCIAL_PROVIDER_URL;
  const key = process.env.TRUTH_SOCIAL_PROVIDER_KEY;
  if (!endpoint || !key) return [];

  const url = new URL(endpoint);
  url.searchParams.set('handles', influencers.map((inf) => inf.truthHandle).filter(Boolean).join(','));
  url.searchParams.set('tickers', tickers.join(','));
  const data = await fetchJson<{ events?: Array<Record<string, unknown>> }>(url.toString(), {
    headers: { Authorization: `Bearer ${key}`, Accept: 'application/json' },
  });

  return (data.events || []).slice(0, 10).map((event, index) => {
    const text = pickString(event, ['text', 'summary', 'body', 'title']) || 'Truth Social provider event';
    const handle = pickString(event, ['handle', 'username', 'author']);
    const influencer = influencers.find((inf) => inf.truthHandle?.toLowerCase() === handle?.toLowerCase());
    return {
      id: `truth-${pickString(event, ['id']) || stableId(text)}-${index}`,
      title: `${handle ? `Truth @${handle}` : 'Truth Social'}: ${text.slice(0, 96)}`,
      summary: text,
      sourceName: 'Truth Social provider',
      sourceKind: 'truth_social',
      sourceAccess: 'vendor',
      url: pickString(event, ['url']),
      publishedAt: pickDate(event, ['created_at', 'createdAt', 'publishedAt']) || new Date().toISOString(),
      tickers: normalizeTickers([...tickers, ...extractTickerLike(text)]).slice(0, 8),
      sentiment: inferTextSentiment(text),
      confidence: influencer ? 70 : 54,
      materiality: influencer ? 68 : 48,
      verification: 'social',
      influencer: influencer?.displayName,
      riskFlags: ['Truth Social has no public official developer API; provider authorization must be documented'],
      evidence: [{ label: 'provider_url', value: endpoint }],
    } satisfies MarketEvent;
  });
}

async function fetchMarketTape(tickers: string[]): Promise<MarketEvent[]> {
  const apiKey = process.env.FINNHUB_API_KEY;
  if (!apiKey) return [];

  const quotes = await Promise.all(
    tickers.slice(0, 12).map(async (ticker) => {
      const url = `https://finnhub.io/api/v1/quote?symbol=${encodeURIComponent(ticker)}&token=${encodeURIComponent(apiKey)}`;
      const quote = await fetchJson<FinnhubQuote>(url);
      return { ticker, quote };
    })
  );

  return quotes
    .filter(({ quote }) => typeof quote.c === 'number' && typeof quote.dp === 'number')
    .map(({ ticker, quote }) => ({
      id: `tape-${ticker}-${quote.t || Date.now()}`,
      title: `${ticker} tape move ${formatPct(quote.dp || 0)}`,
      summary: `Last ${quote.c ?? 'n/a'}, open ${quote.o ?? 'n/a'}, high ${quote.h ?? 'n/a'}, low ${quote.l ?? 'n/a'}, prior close ${quote.pc ?? 'n/a'}.`,
      sourceName: 'Market tape',
      sourceKind: 'market_tape',
      sourceAccess: 'vendor',
      publishedAt: quote.t ? new Date(quote.t * 1000).toISOString() : new Date().toISOString(),
      tickers: [ticker],
      sentiment: (quote.dp || 0) > 1.5 ? 'bullish' : (quote.dp || 0) < -1.5 ? 'bearish' : 'neutral',
      confidence: 86,
      materiality: clamp(40 + Math.abs(quote.dp || 0) * 8, 0, 100),
      verification: 'market_data',
      marketMoveBps: Math.round((quote.dp || 0) * 100),
      riskFlags: Math.abs(quote.dp || 0) > 5 ? ['Large tape move; check halt/news/earnings context'] : [],
      evidence: [
        { label: 'provider', value: 'Finnhub quote' },
        { label: 'change_percent', value: String(quote.dp ?? 0) },
      ],
    }));
}

async function fetchSecFilings(tickers: string[]): Promise<MarketEvent[]> {
  if (!SEC_USER_AGENT_READY) return [];
  const targetTickers = tickers.filter((ticker) => KNOWN_CIKS[ticker]).slice(0, 8);
  const results = await Promise.all(
    targetTickers.map(async (ticker) => {
      const cik = KNOWN_CIKS[ticker];
      const url = `https://data.sec.gov/submissions/CIK${cik}.json`;
      const data = await fetchJson<SecSubmission>(url, {
        headers: {
          'User-Agent': SEC_USER_AGENT,
          Accept: 'application/json',
        },
      });

      const recent = data.filings?.recent;
      if (!recent?.accessionNumber?.length) return [];

      return recent.accessionNumber.slice(0, 24).flatMap((accessionNumber, index) => {
        const form = recent.form?.[index] || 'FILING';
        if (!MATERIAL_FORMS.has(form)) return [];

        const filingDate = recent.filingDate?.[index] || null;
        const rawAcceptance = recent.acceptanceDateTime?.[index];
        if (!rawAcceptance || !/(?:Z|[+-]\d{2}:\d{2})$/i.test(rawAcceptance)) return [];
        const acceptanceDate = rawAcceptance ? new Date(rawAcceptance) : null;
        if (!acceptanceDate || Number.isNaN(acceptanceDate.valueOf())) return [];
        const acceptedAt = acceptanceDate.toISOString();
        const receivedAt = new Date().toISOString();
        const primaryDoc = recent.primaryDocument?.[index] || '';
        const archiveAccession = accessionNumber.replace(/-/g, '');
        const filingUrl = primaryDoc
          ? `https://www.sec.gov/Archives/edgar/data/${Number(cik)}/${archiveAccession}/${primaryDoc}`
          : `https://www.sec.gov/Archives/edgar/data/${Number(cik)}/${archiveAccession}/`;
        const description = recent.primaryDocDescription?.[index] || `${form} filing`;
        const sourceRecordId = `sec:${cik}:${accessionNumber}`;
        const payloadSha256 = createHash('sha256')
          .update(JSON.stringify({ ticker, accessionNumber, form, acceptedAt, filingDate, primaryDoc, description }))
          .digest('hex');

        return [
          {
            id: `sec-${ticker}-${accessionNumber}`,
            title: `${ticker} filed ${form}`,
            summary: `${description}. ${filingDate ? `Filed on ${filingDate}` : `Accepted at ${acceptedAt}`}${recent.reportDate?.[index] ? ` for report date ${recent.reportDate[index]}` : ''}.`,
            sourceName: 'SEC EDGAR',
            sourceKind: 'sec_edgar',
            sourceAccess: 'public',
            url: filingUrl,
            publishedAt: acceptedAt,
            availableAt: acceptedAt,
            receivedAt,
            sourceRecordId,
            revisionId: accessionNumber,
            payloadSha256,
            availabilityPrecision: 'exact_timestamp',
            tickers: [ticker],
            sentiment: inferFilingSentiment(form),
            confidence: 96,
            materiality: materialityForForm(form),
            verification: 'official',
            riskFlags: form === '8-K' ? ['Event filing requires item-level review'] : [],
            evidence: [
              { label: 'form', value: form },
              { label: 'accepted_at', value: acceptedAt },
              { label: 'accession', value: accessionNumber, url: filingUrl },
            ],
          } satisfies MarketEvent,
        ];
      });
    })
  );

  return results.flat();
}

async function fetchFinnhubNews(tickers: string[]): Promise<MarketEvent[]> {
  const apiKey = process.env.FINNHUB_API_KEY;
  if (!apiKey) return [];

  const to = new Date();
  const from = new Date(to.getTime() - 1000 * 60 * 60 * 24 * 7);
  const fromStr = from.toISOString().slice(0, 10);
  const toStr = to.toISOString().slice(0, 10);

  const results = await Promise.all(
    tickers.slice(0, 8).map(async (ticker) => {
      const url = `https://finnhub.io/api/v1/company-news?symbol=${encodeURIComponent(ticker)}&from=${fromStr}&to=${toStr}&token=${encodeURIComponent(apiKey)}`;
      const news = await fetchJson<FinnhubNewsItem[]>(url);

      return news.slice(0, 4).map((item) => ({
        id: `finnhub-${ticker}-${item.id ?? stableId(item.url || item.headline || ticker)}`,
        title: item.headline || `${ticker} market news`,
        summary: item.summary || 'Ticker-related news from a configured market data provider.',
        sourceName: item.source || 'Finnhub',
        sourceKind: 'news_api' as const,
        sourceAccess: 'vendor' as const,
        url: item.url,
        publishedAt: item.datetime ? new Date(item.datetime * 1000).toISOString() : new Date().toISOString(),
        tickers: normalizeTickers([ticker, ...(item.related?.split(',') || [])]).slice(0, 6),
        sentiment: inferTextSentiment(`${item.headline ?? ''} ${item.summary ?? ''}`),
        confidence: 74,
        materiality: 58,
        verification: 'reported' as const,
        riskFlags: ['Reported source; verify against official company or Reuters/LSEG when material'],
        evidence: [
          { label: 'provider', value: 'Finnhub' },
          { label: 'source', value: item.source || 'Unknown publisher', url: item.url },
        ],
      }));
    })
  );

  return results.flat();
}

async function fetchOtherNews(tickers: string[], query: string): Promise<MarketEvent[]> {
  const apiKey = process.env.NEWSAPI_KEY;
  if (!apiKey) return [];

  const url = new URL('https://newsapi.org/v2/everything');
  url.searchParams.set('q', process.env.MARKET_NEWS_QUERY || buildKeywordQuery(tickers, query) || DEFAULT_NEWS_QUERY);
  url.searchParams.set('sortBy', 'publishedAt');
  url.searchParams.set('language', 'en');
  url.searchParams.set('pageSize', '20');

  const data = await fetchJson<NewsApiResponse>(url.toString(), {
    headers: { 'X-Api-Key': apiKey, Accept: 'application/json' },
  });

  return (data.articles || []).slice(0, 10).map((article, index) => {
    const title = article.title || 'Market headline';
    const summary = article.description || title;
    return {
      id: `newsapi-${stableId(article.url || title)}-${index}`,
      title,
      summary,
      sourceName: article.source?.name || 'News API',
      sourceKind: 'news_api',
      sourceAccess: 'vendor',
      url: article.url,
      publishedAt: article.publishedAt || new Date().toISOString(),
      tickers: normalizeTickers([...tickers, ...extractTickerLike(`${title} ${summary}`)]).slice(0, 8),
      sentiment: inferTextSentiment(`${title} ${summary}`),
      confidence: 58,
      materiality: 44,
      verification: 'reported',
      riskFlags: ['General news fallback; check source credibility and licensing'],
      evidence: [{ label: 'provider', value: 'NewsAPI.org' }],
    } satisfies MarketEvent;
  });
}

function buildReutersQuery(tickers: string[], query: string) {
  const tickerPart = tickers.length ? tickers.map((ticker) => `R:${ticker}.O`).join(' OR ') : '';
  const queryPart = query || DEFAULT_NEWS_QUERY;
  return [tickerPart && `(${tickerPart})`, queryPart].filter(Boolean).join(' OR ');
}

function buildKeywordQuery(tickers: string[], query: string) {
  const tickersQuery = tickers.map((ticker) => `$${ticker} OR ${ticker}`).join(' OR ');
  const cleanedQuery = query.replace(/[()]/g, ' ').trim();
  return [tickersQuery && `(${tickersQuery})`, cleanedQuery && `(${cleanedQuery})`].filter(Boolean).join(' OR ');
}

function inferFilingSentiment(form: string) {
  if (form === '10-K' || form === '10-Q') return 'neutral' as const;
  if (form === 'S-1' || form === 'S-3' || form === '424B5') return 'mixed' as const;
  return 'neutral' as const;
}

function materialityForForm(form: string) {
  if (form === '8-K') return 82;
  if (form === '10-K' || form === '10-Q') return 76;
  if (form === 'S-1' || form === 'S-3' || form === '424B5') return 88;
  if (form.startsWith('SC 13')) return 70;
  return 55;
}

function inferTextSentiment(text: string) {
  const lower = text.toLowerCase();
  const bearish = ['downgrade', 'probe', 'investigation', 'miss', 'cuts', 'lawsuit', 'falls', 'plunge', 'weak', 'recall'];
  const bullish = ['upgrade', 'beats', 'raises', 'partnership', 'approval', 'surges', 'growth', 'strong', 'record'];
  const b = bearish.some((term) => lower.includes(term));
  const u = bullish.some((term) => lower.includes(term));
  if (b && u) return 'mixed' as const;
  if (b) return 'bearish' as const;
  if (u) return 'bullish' as const;
  return 'neutral' as const;
}

async function fetchJson<T>(url: string, init?: RequestInit): Promise<T> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 7500);
  try {
    const res = await fetch(url, {
      ...init,
      cache: 'no-store',
      signal: controller.signal,
    });
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
    return (await res.json()) as T;
  } finally {
    clearTimeout(timeout);
  }
}

function failSource(source: string, err: unknown): MarketEvent[] {
  console.warn(`[market/${source}] source unavailable: ${err instanceof Error ? err.message : String(err)}`);
  return [];
}

function extractTickerLike(text: string) {
  return (text.match(/\$?[A-Z]{1,6}(?:\.[A-Z])?\b/g) || []).map((match) => match.replace(/^\$/, ''));
}

function pickString(item: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = item[key];
    if (typeof value === 'string' && value.trim()) return value.trim();
  }
  return undefined;
}

function pickDate(item: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = item[key];
    if (typeof value === 'string') {
      const date = new Date(value);
      if (!Number.isNaN(date.getTime())) return date.toISOString();
    }
  }
  return undefined;
}

function formatPct(value: number) {
  return `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`;
}

function stableId(input: string) {
  let hash = 0;
  for (let i = 0; i < input.length; i += 1) {
    hash = (hash * 31 + input.charCodeAt(i)) >>> 0;
  }
  return hash.toString(36);
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

type PolygonNewsItem = {
  id?: string;
  title?: string;
  description?: string;
  article_url?: string;
  amp_url?: string;
  published_utc?: string;
  publisher?: { name?: string };
  tickers?: string[];
};

async function fetchPolygonNews(tickers: string[]): Promise<MarketEvent[]> {
  const apiKey = process.env.POLYGON_API_KEY;
  if (!apiKey) return [];

  const url = new URL('https://api.polygon.io/v2/reference/news');
  url.searchParams.set('limit', '30');
  url.searchParams.set('order', 'desc');
  url.searchParams.set('sort', 'published_utc');
  if (tickers.length) url.searchParams.set('ticker.any_of', tickers.slice(0, 10).join(','));
  url.searchParams.set('apiKey', apiKey);

  const data = await fetchJson<{ results?: PolygonNewsItem[] }>(url.toString());

  return (data.results || []).slice(0, 16).map((item, index) => {
    const headline = item.title || `${tickers[0] || 'market'} headline`;
    const summary = item.description || headline;
    return {
      id: `polygon-${item.id || stableId(item.article_url || headline)}-${index}`,
      title: headline,
      summary,
      sourceName: item.publisher?.name ? `${item.publisher.name} via Polygon` : 'Polygon news',
      sourceKind: 'polygon',
      sourceAccess: 'vendor',
      url: item.article_url || item.amp_url,
      publishedAt: item.published_utc || new Date().toISOString(),
      tickers: normalizeTickers([...(item.tickers || []), ...tickers]).slice(0, 8),
      sentiment: inferTextSentiment(`${headline} ${summary}`),
      confidence: 82,
      materiality: 64,
      verification: 'reported',
      riskFlags: ['Polygon-licensed publisher content; observe redistribution limits'],
      evidence: [
        { label: 'provider', value: 'Polygon.io' },
        { label: 'publisher', value: item.publisher?.name || 'unknown', url: item.article_url },
      ],
    } satisfies MarketEvent;
  });
}

const REDDIT_SUBS = ['wallstreetbets', 'options', 'stocks', 'investing', 'SPACs', 'cryptocurrency'];

type RedditToken = { access_token?: string; expires_in?: number };

type RedditPost = {
  data?: {
    id?: string;
    title?: string;
    selftext?: string;
    subreddit?: string;
    author?: string;
    permalink?: string;
    created_utc?: number;
    score?: number;
    num_comments?: number;
    upvote_ratio?: number;
    link_flair_text?: string;
  };
};

type RedditListing = { data?: { children?: RedditPost[] } };

let redditTokenCache: { token: string; expiresAt: number } | null = null;

async function getRedditToken(): Promise<string | null> {
  const clientId = process.env.REDDIT_CLIENT_ID;
  const clientSecret = process.env.REDDIT_CLIENT_SECRET;
  if (!clientId || !clientSecret) return null;

  const now = Date.now();
  if (redditTokenCache && redditTokenCache.expiresAt > now + 30_000) {
    return redditTokenCache.token;
  }

  const body = new URLSearchParams();
  body.set('grant_type', 'client_credentials');

  const ua = process.env.REDDIT_USER_AGENT || 'AXIO7-MarketIntel/1.0';
  const auth = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

  try {
    const res = await fetch('https://www.reddit.com/api/v1/access_token', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': ua,
      },
      body,
      cache: 'no-store',
    });
    if (!res.ok) return null;
    const data = (await res.json()) as RedditToken;
    if (!data.access_token) return null;
    redditTokenCache = {
      token: data.access_token,
      expiresAt: now + (data.expires_in || 3600) * 1000,
    };
    return data.access_token;
  } catch {
    return null;
  }
}

async function fetchRedditPosts(tickers: string[], query: string): Promise<MarketEvent[]> {
  const token = await getRedditToken();
  if (!token) return [];

  const ua = process.env.REDDIT_USER_AGENT || 'AXIO7-MarketIntel/1.0';
  const subs = (process.env.REDDIT_SUBS || REDDIT_SUBS.join(',')).split(',').map((s) => s.trim()).filter(Boolean);
  const tickerSet = new Set(tickers.map((t) => t.toUpperCase()));
  const queryLower = query.toLowerCase();

  const all: MarketEvent[] = [];
  await Promise.all(
    subs.map(async (sub) => {
      try {
        const url = `https://oauth.reddit.com/r/${encodeURIComponent(sub)}/hot?limit=15`;
        const res = await fetch(url, {
          headers: {
            Authorization: `Bearer ${token}`,
            'User-Agent': ua,
            Accept: 'application/json',
          },
          cache: 'no-store',
        });
        if (!res.ok) return;
        const listing = (await res.json()) as RedditListing;
        for (const child of listing.data?.children || []) {
          const post = child.data;
          if (!post?.id || !post.title) continue;
          const text = `${post.title} ${post.selftext || ''}`;
          const postTickers = normalizeTickers(extractTickerLike(text));
          const tickerHit = postTickers.some((t) => tickerSet.has(t));
          const queryHit = queryLower && text.toLowerCase().includes(queryLower);
          const score = post.score || 0;
          if (!tickerHit && !queryHit && score < 200) continue;

          const engagement = score + (post.num_comments || 0) * 2;
          all.push({
            id: `reddit-${post.id}`,
            title: `r/${post.subreddit || sub}: ${post.title.slice(0, 110)}`,
            summary: (post.selftext || post.title).slice(0, 320),
            sourceName: `Reddit r/${post.subreddit || sub}`,
            sourceKind: 'reddit',
            sourceAccess: 'authorized',
            url: post.permalink ? `https://www.reddit.com${post.permalink}` : undefined,
            publishedAt: post.created_utc ? new Date(post.created_utc * 1000).toISOString() : new Date().toISOString(),
            tickers: normalizeTickers([...postTickers, ...tickers]).slice(0, 6),
            sentiment: inferTextSentiment(text),
            confidence: clamp(40 + Math.min(30, Math.round(Math.log10(engagement + 1) * 10)), 0, 90),
            materiality: clamp(
              30 + Math.min(40, Math.round(Math.log10(engagement + 1) * 12)) + (tickerHit ? 10 : 0),
              0,
              92
            ),
            verification: 'social',
            riskFlags: [
              'Retail social signal; corroborate with filings/news before escalating',
              post.link_flair_text ? `flair: ${post.link_flair_text}` : 'no flair',
            ],
            evidence: [
              { label: 'subreddit', value: sub },
              { label: 'score', value: String(score) },
              { label: 'comments', value: String(post.num_comments || 0) },
              { label: 'upvote_ratio', value: String(post.upvote_ratio || 0) },
            ],
          });
        }
      } catch (err) {
        console.warn(`[market/reddit] sub ${sub} failed`, err instanceof Error ? err.message : err);
      }
    })
  );

  return all.slice(0, 24);
}

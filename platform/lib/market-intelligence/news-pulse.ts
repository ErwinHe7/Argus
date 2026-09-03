// Free news pulse: Hacker News (Algolia) for tech-investor signal,
// GDELT 2.0 DOC API for global news tone. No API keys required.

export type NewsItem = {
  source: 'hackernews' | 'gdelt' | 'manual';
  id: string;
  title: string;
  url?: string;
  publishedAt: string;
  score: number;
  comments?: number;
  author?: string;
  tone?: number;
  domain?: string;
  tickers: string[];
  // Manual-source metadata (only set when source === 'manual')
  manualSourceType?: 'x_manual' | 'truth_manual' | 'reuters_headline' | 'press_release' | 'sec_url' | 'other';
  sentiment?: 'bullish' | 'bearish' | 'neutral' | 'mixed';
  materialityScore?: number;
  confidence?: number;
};

export type TickerPulse = {
  ticker: string;
  total: number;
  hnCount: number;
  gdeltCount: number;
  topItems: NewsItem[];
  averageTone: number | null;
  interpretation: string;
};

export type NewsPulseReport = {
  generatedAt: string;
  tickers: string[];
  pulses: TickerPulse[];
  hackerNews: NewsItem[];
  gdelt: NewsItem[];
  reliability: {
    hackernews: 'ok' | 'unavailable';
    gdelt: 'ok' | 'unavailable';
  };
  disclaimer: string;
};

const DEFAULT_TICKERS = [
  'NVDA', 'AMD', 'AVGO', 'TSLA', 'MSFT', 'META', 'GOOGL', 'AMZN', 'AAPL',
  'PLTR', 'SMCI', 'COIN', 'CRWD', 'PANW', 'SNOW',
];

const TICKER_RE = /\b(?:SPY|QQQ|IWM|DIA|SOXX|VIXY|NVDA|AMD|AVGO|TSLA|MSFT|META|GOOGL|GOOG|AMZN|AAPL|PLTR|SMCI|COIN|CRWD|PANW|SNOW|MRVL|ARM|INTC|QCOM|MU|TSM|ASML|ANET|CLS|VRT|COHR|LITE|AAOI|TSEM|SIVE|ORCL|CRM|NOW|DDOG|NET|CEG|VST|ETN|PWR|GEV|FLNC|OKLO|SMR|APLD|IREN|HPE|DELL)\b/g;

const ALIAS_TO_TICKER: Array<{ alias: RegExp; ticker: string }> = [
  { alias: /\bnvidia\b/i, ticker: 'NVDA' },
  { alias: /\b(?:amd|advanced micro)\b/i, ticker: 'AMD' },
  { alias: /\bbroadcom\b/i, ticker: 'AVGO' },
  { alias: /\btesla\b/i, ticker: 'TSLA' },
  { alias: /\bmicrosoft\b/i, ticker: 'MSFT' },
  { alias: /\b(?:meta|facebook|instagram)\b/i, ticker: 'META' },
  { alias: /\b(?:google|alphabet)\b/i, ticker: 'GOOGL' },
  { alias: /\bamazon\b/i, ticker: 'AMZN' },
  { alias: /\bapple\b/i, ticker: 'AAPL' },
  { alias: /\bpalantir\b/i, ticker: 'PLTR' },
  { alias: /\b(?:super\s*micro|supermicro)\b/i, ticker: 'SMCI' },
  { alias: /\bcoinbase\b/i, ticker: 'COIN' },
  { alias: /\bcrowdstrike\b/i, ticker: 'CRWD' },
  { alias: /\b(?:palo alto networks|palo alto)\b/i, ticker: 'PANW' },
  { alias: /\bsnowflake\b/i, ticker: 'SNOW' },
  { alias: /\bmarvell\b/i, ticker: 'MRVL' },
  { alias: /\b(?:arm holdings|arm ltd)\b/i, ticker: 'ARM' },
  { alias: /\bintel\b/i, ticker: 'INTC' },
  { alias: /\bqualcomm\b/i, ticker: 'QCOM' },
  { alias: /\bmicron\b/i, ticker: 'MU' },
  { alias: /\b(?:tsmc|taiwan semi|taiwan semiconductor)\b/i, ticker: 'TSM' },
  { alias: /\basml\b/i, ticker: 'ASML' },
  { alias: /\barista\b/i, ticker: 'ANET' },
  { alias: /\boracle\b/i, ticker: 'ORCL' },
  { alias: /\bsalesforce\b/i, ticker: 'CRM' },
  { alias: /\bservicenow\b/i, ticker: 'NOW' },
  { alias: /\bdatadog\b/i, ticker: 'DDOG' },
  { alias: /\bcloudflare\b/i, ticker: 'NET' },
  { alias: /\bconstellation energy\b/i, ticker: 'CEG' },
  { alias: /\boklo\b/i, ticker: 'OKLO' },
];

export async function buildNewsPulseReport(
  input: string[] = DEFAULT_TICKERS
): Promise<NewsPulseReport> {
  const tickers = Array.from(new Set(input.map((t) => t.toUpperCase()))).slice(0, 30);
  const generatedAt = new Date().toISOString();

  const [hn, gdelt] = await Promise.all([
    fetchHackerNewsItems(tickers).catch((err) => {
      console.warn('[news-pulse/hn]', err instanceof Error ? err.message : err);
      return null;
    }),
    fetchGdeltItems(tickers).catch((err) => {
      console.warn('[news-pulse/gdelt]', err instanceof Error ? err.message : err);
      return null;
    }),
  ]);

  const hackerNews = hn || [];
  const gdeltNews = gdelt || [];
  const all = [...hackerNews, ...gdeltNews];

  const pulses: TickerPulse[] = tickers.map((ticker) => {
    const matches = all.filter((item) => item.tickers.includes(ticker));
    const hnMatches = matches.filter((m) => m.source === 'hackernews');
    const gdeltMatches = matches.filter((m) => m.source === 'gdelt');
    const tones = gdeltMatches.map((m) => m.tone).filter((t): t is number => t !== undefined);
    const averageTone = tones.length
      ? tones.reduce((sum, value) => sum + value, 0) / tones.length
      : null;
    const interpretation =
      matches.length === 0
        ? '近 7 日无显著公开新闻命中。'
        : averageTone !== null
          ? `近 7 日命中 ${matches.length} 条，GDELT 平均语气 ${averageTone.toFixed(2)} (>0 偏正, <0 偏负)。`
          : `近 7 日命中 ${matches.length} 条 (主要来自社区讨论)。`;
    return {
      ticker,
      total: matches.length,
      hnCount: hnMatches.length,
      gdeltCount: gdeltMatches.length,
      topItems: matches.sort((a, b) => b.score - a.score).slice(0, 5),
      averageTone,
      interpretation,
    };
  });

  return {
    generatedAt,
    tickers,
    pulses: pulses.sort((a, b) => b.total - a.total),
    hackerNews,
    gdelt: gdeltNews,
    reliability: {
      hackernews: hackerNews.length > 0 ? 'ok' : 'unavailable',
      gdelt: gdeltNews.length > 0 ? 'ok' : 'unavailable',
    },
    disclaimer:
      '数据来自 Hacker News Algolia 搜索与 GDELT 2.0 全球新闻数据库，均为免费公开 API。语气与命中数反映公开报道密度，不代表交易方向。',
  };
}

type HnHit = {
  objectID?: string;
  title?: string;
  story_title?: string;
  url?: string;
  story_url?: string;
  points?: number;
  num_comments?: number;
  author?: string;
  created_at?: string;
};

async function fetchHackerNewsItems(tickers: string[]): Promise<NewsItem[]> {
  // HN search uses Algolia and is finicky with OR + numericFilters on cashtags.
  // Best yield: grab the latest ~150 front-page stories and grep client-side
  // for ticker or company-name mentions. Names mapped below; we union with
  // the raw tickers so $NVDA and "Nvidia" both light up.
  const url = new URL('https://hn.algolia.com/api/v1/search_by_date');
  url.searchParams.set('tags', 'story');
  url.searchParams.set('numericFilters', 'points>5');
  url.searchParams.set('hitsPerPage', '200');

  const data = await fetchJson<{ hits?: HnHit[] }>(url.toString(), {
    headers: { Accept: 'application/json' },
  });

  const out: NewsItem[] = [];
  for (const hit of data.hits || []) {
    const title = hit.title || hit.story_title || '';
    if (!title) continue;
    const matched = extractTickers(title);
    if (!matched.length) continue;
    out.push({
      source: 'hackernews',
      id: `hn-${hit.objectID || title.slice(0, 16)}`,
      title,
      url: hit.url || hit.story_url || `https://news.ycombinator.com/item?id=${hit.objectID || ''}`,
      publishedAt: hit.created_at || new Date().toISOString(),
      score: hit.points || 0,
      comments: hit.num_comments || 0,
      author: hit.author,
      tickers: matched,
    });
  }
  return out;
}

type GdeltDoc = {
  url?: string;
  url_mobile?: string;
  title?: string;
  seendate?: string;
  socialimage?: string;
  domain?: string;
  language?: string;
  sourcecountry?: string;
  tone?: string | number;
};

async function fetchGdeltItems(tickers: string[]): Promise<NewsItem[]> {
  // GDELT rate-limits aggressively from datacenter IPs (5s minimum between
  // requests, often refuses outright). Query fewer terms and tolerate
  // failure — we surface "unavailable" cleanly without retrying forever.
  const query = tickers
    .slice(0, 6)
    .map((t) => `"${t}"`)
    .join(' OR ');
  const url = new URL('https://api.gdeltproject.org/api/v2/doc/doc');
  url.searchParams.set('query', `${query} sourcelang:eng`);
  url.searchParams.set('mode', 'artlist');
  url.searchParams.set('format', 'json');
  url.searchParams.set('maxrecords', '50');
  url.searchParams.set('timespan', '7d');
  url.searchParams.set('sort', 'datedesc');

  const data = await fetchJson<{ articles?: GdeltDoc[] }>(url.toString(), {
    headers: {
      Accept: 'application/json',
      'User-Agent':
        process.env.GDELT_USER_AGENT ||
        'AXIO7-MarketIntel/1.0 (https://axio7.com; contact@axio7.com)',
    },
  });

  const out: NewsItem[] = [];
  for (const doc of data.articles || []) {
    const title = doc.title || '';
    if (!title) continue;
    const matched = extractTickers(title);
    if (!matched.length) continue;
    const toneRaw = typeof doc.tone === 'string' ? Number(doc.tone) : doc.tone;
    const tone = Number.isFinite(toneRaw) ? (toneRaw as number) : undefined;
    const ts = doc.seendate ? parseGdeltDate(doc.seendate) : new Date().toISOString();
    out.push({
      source: 'gdelt',
      id: `gdelt-${doc.url || title.slice(0, 16)}`,
      title,
      url: doc.url,
      publishedAt: ts,
      score: Math.round(((tone ?? 0) + 10) * 5),
      domain: doc.domain,
      tone,
      tickers: matched,
    });
  }
  return out;
}

function extractTickers(text: string): string[] {
  const hits = new Set<string>();
  for (const match of text.match(TICKER_RE) || []) hits.add(match.toUpperCase());
  for (const { alias, ticker } of ALIAS_TO_TICKER) {
    if (alias.test(text)) hits.add(ticker);
  }
  return Array.from(hits);
}

function parseGdeltDate(s: string): string {
  // GDELT format: 20251223T123000Z
  if (s.length === 16 && s[8] === 'T' && s.endsWith('Z')) {
    const iso = `${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6, 8)}T${s.slice(9, 11)}:${s.slice(11, 13)}:${s.slice(13, 15)}Z`;
    return iso;
  }
  return new Date().toISOString();
}

async function fetchJson<T>(url: string, init?: RequestInit): Promise<T> {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), 9000);
  try {
    const res = await fetch(url, { ...init, cache: 'no-store', signal: controller.signal });
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
    return (await res.json()) as T;
  } finally {
    clearTimeout(t);
  }
}

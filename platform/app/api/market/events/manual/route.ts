import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { recordAudit } from '@/lib/market-intelligence/audit';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import { isSupabaseConfigured, supabaseAdmin } from '@/lib/supabase';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 25;

const ROUTE = '/api/market/events/manual';

const BodySchema = z.object({
  sourceType: z.enum(['x_manual', 'truth_manual', 'reuters_headline', 'press_release', 'sec_url', 'other']),
  sourceUrl: z.string().url().max(800).optional(),
  text: z.string().min(8).max(4000),
  publishedAt: z.string().datetime().optional(),
  tickersHint: z.array(z.string().min(1).max(8)).max(20).optional(),
});

const TICKER_RE = /\$?\b[A-Z]{1,5}(?:\.[A-Z])?\b/g;

const ALIASES: Array<{ alias: RegExp; ticker: string }> = [
  { alias: /\bnvidia\b/i, ticker: 'NVDA' },
  { alias: /\b(?:amd|advanced micro)\b/i, ticker: 'AMD' },
  { alias: /\bbroadcom\b/i, ticker: 'AVGO' },
  { alias: /\btesla\b/i, ticker: 'TSLA' },
  { alias: /\bmicrosoft\b/i, ticker: 'MSFT' },
  { alias: /\bapple\b/i, ticker: 'AAPL' },
  { alias: /\b(?:meta|facebook)\b/i, ticker: 'META' },
  { alias: /\b(?:google|alphabet)\b/i, ticker: 'GOOGL' },
  { alias: /\bamazon\b/i, ticker: 'AMZN' },
  { alias: /\bpalantir\b/i, ticker: 'PLTR' },
  { alias: /\bcoinbase\b/i, ticker: 'COIN' },
  { alias: /\bintel\b/i, ticker: 'INTC' },
  { alias: /\bqualcomm\b/i, ticker: 'QCOM' },
  { alias: /\bmicron\b/i, ticker: 'MU' },
  { alias: /\btsmc\b/i, ticker: 'TSM' },
  { alias: /\boracle\b/i, ticker: 'ORCL' },
  { alias: /\bbitcoin\b/i, ticker: 'BTC' },
  { alias: /\bethereum\b/i, ticker: 'ETH' },
];

const STOP_TICKERS = new Set([
  'A', 'AI', 'API', 'CEO', 'CFO', 'CTO', 'CPI', 'DOJ', 'DOJ', 'EU', 'EV', 'FAA', 'FDA', 'FED',
  'FOMC', 'GDP', 'IPO', 'IT', 'ML', 'NYC', 'OK', 'PR', 'Q1', 'Q2', 'Q3', 'Q4', 'SEC', 'TLDR',
  'UK', 'US', 'USA', 'USD', 'AS', 'OF', 'ON', 'TO', 'BE', 'IN', 'IT', 'OR', 'AT', 'NO', 'WE',
  'BUT', 'OUT', 'FOR', 'WITH', 'YOU', 'THE', 'AND', 'NEW', 'ALL', 'NOT', 'WAS', 'HAS', 'CAN',
  'WILL', 'NASDAQ', 'NYSE', 'ETF', 'ETN',
]);

const BULLISH_KEYS = [
  /\bupgrade(?:s|d)?\b/i,
  /\bbeats?\b/i,
  /\braise(?:s|d)?\b/i,
  /\bsurge(?:s|d)?\b/i,
  /\bdeal(?:s|ed)?\b/i,
  /\bpartnership\b/i,
  /\bapproval\b/i,
  /\bgrowth\b/i,
  /\b利好\b/,
  /\b上调\b/,
];
const BEARISH_KEYS = [
  /\bdowngrade(?:s|d)?\b/i,
  /\bmiss(?:es|ed)?\b/i,
  /\bcut(?:s|ting)?\b/i,
  /\bfall(?:s|ing)?\b/i,
  /\bprobe\b/i,
  /\binvestigation\b/i,
  /\blawsuit\b/i,
  /\brecall\b/i,
  /\btariffs?\b/i,
  /\bban(?:s|ned)?\b/i,
  /\bsanctions?\b/i,
  /\bexport\s+control(?:s)?\b/i,
  /\b利空\b/,
  /\b下调\b/,
];

const MATERIALITY_KEYS = [
  { re: /\btariffs?\b/i, weight: 25, tag: 'tariff' },
  { re: /\bexport\s+control(?:s)?\b/i, weight: 30, tag: 'export_control' },
  { re: /\bsanctions?\b/i, weight: 25, tag: 'sanction' },
  { re: /\b(?:investigation|probe|lawsuit)\b/i, weight: 15, tag: 'legal' },
  { re: /\b(?:earnings|EPS|revenue)\b/i, weight: 18, tag: 'earnings' },
  { re: /\bguidance\b/i, weight: 20, tag: 'guidance' },
  { re: /\b(?:merger|acquisition|deal)\b/i, weight: 20, tag: 'm&a' },
  { re: /\b(?:fed|federal\s+reserve|rates?|FOMC)\b/i, weight: 22, tag: 'fed_macro' },
  { re: /\b(?:inflation|CPI|PPI)\b/i, weight: 18, tag: 'inflation' },
  { re: /\b(?:AI\s+chips?|GPU|H100|H200|B100|B200)\b/i, weight: 20, tag: 'ai_chips' },
];

export async function POST(req: NextRequest) {
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 20, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });
  }

  const body = await req.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid manual event body.', issues: parsed.error.flatten() }, { status: 400 });
  }

  const { sourceType, sourceUrl, text, publishedAt, tickersHint } = parsed.data;

  const tickers = extractTickers(text, tickersHint || []);
  const sentiment = classifySentiment(text);
  const tagsWithScore = classifyTags(text);
  const materialityFromKeys = tagsWithScore.reduce((sum, t) => sum + t.weight, 0);
  const baseMateriality = sourceType === 'sec_url' || sourceType === 'reuters_headline' ? 60 : 40;
  const materialityScore = Math.min(100, baseMateriality + materialityFromKeys);
  const confidence =
    sourceType === 'sec_url' ? 92 :
    sourceType === 'reuters_headline' ? 85 :
    sourceType === 'press_release' ? 80 :
    sourceType === 'truth_manual' ? 55 :
    sourceType === 'x_manual' ? 60 : 50;
  const riskFlags = buildRiskFlags(sourceType, tickers.length, tagsWithScore);

  const event = {
    id: `manual-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    sourceId: 'manual',
    sourceKind: 'manual',
    sourceAccess: 'manual' as const,
    headline: text.split('\n')[0].slice(0, 200),
    summary: text.slice(0, 800),
    sourceUrl,
    publishedAt: publishedAt || new Date().toISOString(),
    receivedAt: new Date().toISOString(),
    tickers,
    assetClasses: tickers.length > 0 ? ['equity'] : [],
    tags: tagsWithScore.map((t) => t.tag),
    sentiment,
    materialityScore,
    confidence,
    verificationStatus: 'single_source' as const,
    riskFlags,
    evidence: [
      { label: 'source_type', value: sourceType },
      ...(sourceUrl ? [{ label: 'source_url', value: sourceUrl, url: sourceUrl }] : []),
    ],
  };

  const analysis = buildAnalysis(event, tagsWithScore);

  await recordAudit({
    route: ROUTE,
    actor: key,
    action: 'manual_event',
    status: 'ok',
    meta: { sourceType, tickers: tickers.length, materialityScore, sentiment },
  });

  // Persist to Supabase so the event flows into the ticker console catalysts.
  let persisted: { id: string | null; persisted: boolean; reason?: string } = {
    id: null,
    persisted: false,
  };
  if (isSupabaseConfigured()) {
    try {
      const db = supabaseAdmin();
      const { data: inserted, error } = await db
        .from('manual_market_events')
        .insert({
          user_id: null, // anonymous insert path; per-user wiring later
          source_type: sourceType,
          source_url: sourceUrl || null,
          headline: event.headline,
          text: event.summary,
          tickers,
          tags: event.tags,
          sentiment,
          materiality_score: materialityScore,
          confidence,
          risk_flags: riskFlags,
          published_at: event.publishedAt,
        })
        .select('id')
        .single();
      if (error) {
        persisted = { id: null, persisted: false, reason: error.message };
        console.warn('[manual_event/persist]', error.message);
      } else {
        persisted = { id: inserted?.id || null, persisted: true };
      }
    } catch (err) {
      persisted = {
        id: null,
        persisted: false,
        reason: err instanceof Error ? err.message : 'persist failed',
      };
      console.warn('[manual_event/persist] exception', err);
    }
  } else {
    persisted = { id: null, persisted: false, reason: 'supabase not configured' };
  }

  return NextResponse.json(
    {
      event,
      analysis,
      persistence: persisted,
      disclaimer:
        '本分析基于用户粘贴的单一来源文本，未经多源 corroboration 或行情确认。在采取任何行动前请独立核实。本平台不构成投资建议。',
    },
    { status: 200, headers: { 'Cache-Control': 'no-store' } }
  );
}

// GET: list recent manual events, optionally filtered by ticker.
// Used by ticker console to inject pasted Trump/X/news events into the
// ticker's catalyst feed.
export async function GET(req: NextRequest) {
  const rate = checkRateLimit(rateLimitKey(req, ROUTE + ':get'), 60, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });
  }

  const url = new URL(req.url);
  const ticker = url.searchParams.get('ticker')?.replace(/^\$/, '').trim().toUpperCase() || '';
  const sinceDays = Math.min(30, Number(url.searchParams.get('days') || '7'));
  const limit = Math.min(50, Number(url.searchParams.get('limit') || '20'));

  if (!isSupabaseConfigured()) {
    return NextResponse.json({
      configured: false,
      events: [],
      reason: 'supabase not configured; manual events are not persisted',
    });
  }

  try {
    const db = supabaseAdmin();
    const sinceIso = new Date(Date.now() - sinceDays * 24 * 60 * 60 * 1000).toISOString();
    let query = db
      .from('manual_market_events')
      .select(
        'id, source_type, source_url, headline, text, tickers, tags, sentiment, materiality_score, confidence, risk_flags, published_at'
      )
      .gte('published_at', sinceIso)
      .order('published_at', { ascending: false })
      .limit(limit);
    if (ticker) {
      query = query.contains('tickers', [ticker]);
    }
    const { data, error } = await query;
    if (error) {
      return NextResponse.json({ configured: true, events: [], error: error.message }, { status: 200 });
    }
    return NextResponse.json({
      configured: true,
      ticker: ticker || null,
      sinceDays,
      events: data || [],
    });
  } catch (err) {
    return NextResponse.json(
      { configured: true, events: [], error: err instanceof Error ? err.message : 'unknown' },
      { status: 200 }
    );
  }
}

function extractTickers(text: string, hints: string[]): string[] {
  const hits = new Set<string>();
  for (const h of hints) {
    const t = h.replace(/^\$/, '').toUpperCase();
    if (/^[A-Z][A-Z0-9.]{0,5}$/.test(t)) hits.add(t);
  }
  for (const match of text.match(TICKER_RE) || []) {
    const sym = match.replace(/^\$/, '').toUpperCase();
    if (sym.length < 2) continue;
    if (STOP_TICKERS.has(sym)) continue;
    hits.add(sym);
  }
  for (const { alias, ticker } of ALIASES) {
    if (alias.test(text)) hits.add(ticker);
  }
  return Array.from(hits).slice(0, 12);
}

function classifySentiment(text: string): 'bullish' | 'bearish' | 'neutral' | 'mixed' {
  const bull = BULLISH_KEYS.some((re) => re.test(text));
  const bear = BEARISH_KEYS.some((re) => re.test(text));
  if (bull && bear) return 'mixed';
  if (bull) return 'bullish';
  if (bear) return 'bearish';
  return 'neutral';
}

function classifyTags(text: string): Array<{ tag: string; weight: number }> {
  const out: Array<{ tag: string; weight: number }> = [];
  for (const m of MATERIALITY_KEYS) {
    if (m.re.test(text)) out.push({ tag: m.tag, weight: m.weight });
  }
  return out;
}

function buildRiskFlags(sourceType: string, tickerCount: number, tags: Array<{ tag: string; weight: number }>): string[] {
  const flags: string[] = [];
  if (sourceType === 'x_manual' || sourceType === 'truth_manual') {
    flags.push('social_uncorroborated');
  }
  if (tickerCount === 0) flags.push('no_ticker_match');
  if (tags.find((t) => t.tag === 'tariff' || t.tag === 'sanction' || t.tag === 'export_control')) {
    flags.push('geopolitical_risk');
  }
  return flags;
}

function buildAnalysis(
  event: ReturnType<typeof Object> & { tickers: string[]; sentiment: string; tags: string[] },
  tags: Array<{ tag: string; weight: number }>
) {
  const directionWord =
    event.sentiment === 'bullish' ? '偏多' :
    event.sentiment === 'bearish' ? '偏空' :
    event.sentiment === 'mixed' ? '多空交织' : '中性';
  const tagDescription = tags.length ? tags.map((t) => t.tag).join(', ') : '未命中关键事件类别';
  const tickerLine = event.tickers.length
    ? `映射 ticker: ${event.tickers.join(', ')}`
    : '没有匹配到已知 ticker。可手动补充 tickersHint。';

  const checks: string[] = [];
  if (tags.find((t) => t.tag === 'tariff' || t.tag === 'export_control')) {
    checks.push('检查相关板块 ETF (SMH/SOXX/FXI/KWEB) 的同日反应。');
    checks.push('查 8-K / 公司声明确认营收暴露占比。');
  }
  if (tags.find((t) => t.tag === 'fed_macro' || t.tag === 'inflation')) {
    checks.push('对比 10Y/2Y 利差和联邦基金期货定价变化。');
  }
  if (tags.find((t) => t.tag === 'earnings' || t.tag === 'guidance')) {
    checks.push('对比 sell-side 一致预期 (FactSet/Refinitiv consensus)。');
    checks.push('检查期权 IV 变化和到期 expected move。');
  }
  if (!checks.length) {
    checks.push('用 Reuters/官方公告做二次确认。');
    checks.push('看价格和成交量是否在事件后明显反应。');
  }

  return {
    directionSummary: `${directionWord} · 关键事件: ${tagDescription}`,
    tickerSummary: tickerLine,
    nextChecks: checks,
  };
}

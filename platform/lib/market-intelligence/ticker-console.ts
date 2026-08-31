// Presentation aggregator. Quantitative probabilities, option analytics and
// strategy candidates must already be produced by the canonical Rust engine.
// TypeScript never fits a model or substitutes historical-volatility math.

import {
  buildMarketSignalReport,
  fetchYahooSeries,
  type MarketSignalQuote,
  type YahooSeries,
} from './market-signal';
import { buildOptionsIntelReport, type OptionsIntelReport } from './options';
import { buildInsiderReport, type InsiderSummary } from './insider';
import { buildNewsPulseReport, type NewsItem } from './news-pulse';
import { buildMacroReport, type MacroSeries } from './macro';
import { isSupabaseConfigured, supabaseAdmin } from '@/lib/supabase';

export type TickerStrategyCandidate = {
  id: string;
  type:
    | 'long_call'
    | 'long_put'
    | 'bull_call_spread'
    | 'bear_call_spread'
    | 'bull_put_spread'
    | 'bear_put_spread'
    | 'long_butterfly'
    | 'broken_wing_butterfly';
  label: string;
  bias: 'bullish' | 'bearish' | 'neutral' | 'directional';
  legs: Array<{ side: 'BUY' | 'SELL'; right: 'C' | 'P'; strike: number; qty: number }>;
  rationale: string;
  invalidation: string;
  maxProfit: number | null;
  maxLoss: number | null;
  breakevens: number[];
  fitScore: number;
  riskNotes: string[];
};

export type PriceDistributionPoint = {
  price: number;
  probabilityDensity: number;
  cumulativeProbability: number;
};

export type PriceDistributionReport = {
  source: 'options_iv' | 'historical_volatility';
  provider: string;
  spot: number;
  expiration: string;
  daysToExpiry: number;
  annualizedVolatility: number;
  expectedMove: number;
  expectedMovePct: number;
  oneSigmaLow: number;
  oneSigmaHigh: number;
  points: PriceDistributionPoint[];
  levels: Array<{
    label: string;
    price: number;
    probabilityAbove: number;
    probabilityBelow: number;
  }>;
  narrative: string;
  caveats: string[];
  asOf: string;
};

export type TickerConsoleReport = {
  ticker: string;
  generatedAt: string;
  quote: MarketSignalQuote | null;
  signalContext: {
    score: number;
    maxScore: number;
    stance: string;
    headline: string;
  } | null;
  insider: InsiderSummary | null;
  options: OptionsIntelReport | null;
  news: NewsItem[];
  macroExcerpt: MacroSeries[];
  priceDistribution: PriceDistributionReport | null;
  strategyCandidates: TickerStrategyCandidate[];
  reliability: {
    quote: 'ok' | 'unavailable';
    insider: 'ok' | 'unavailable' | 'partial';
    options: 'ok' | 'unavailable';
    news: 'ok' | 'unavailable';
    distribution: 'ok' | 'unavailable';
    macro: 'ok' | 'partial' | 'unavailable';
  };
  errors: string[];
  disclaimer: string;
};

export async function buildTickerConsoleReport(
  rawTicker: string
): Promise<TickerConsoleReport> {
  const ticker = rawTicker.toUpperCase();
  const generatedAt = new Date().toISOString();
  const errors: string[] = [];
  const expiration = nextFridayString();

  const [quoteRes, signalRes, optionsRes, insiderRes, newsRes, macroRes, manualRes] =
    await Promise.allSettled([
      fetchYahooSeries(ticker, ticker),
      buildMarketSignalReport([]),
      buildOptionsIntelReport(ticker, expiration),
      buildInsiderReport([ticker]),
      buildNewsPulseReport([ticker]),
      buildMacroReport(),
      fetchManualEventsForTicker(ticker, 14, 20),
    ]);

  const quoteSeries =
    quoteRes.status === 'fulfilled'
      ? quoteRes.value
      : (errors.push(`quote: ${failureMessage(quoteRes.reason)}`), null);
  const signal =
    signalRes.status === 'fulfilled'
      ? signalRes.value
      : (errors.push(`signal: ${failureMessage(signalRes.reason)}`), null);
  const options =
    optionsRes.status === 'fulfilled'
      ? optionsRes.value
      : (errors.push(`options: ${failureMessage(optionsRes.reason)}`), null);
  const insider =
    insiderRes.status === 'fulfilled'
      ? insiderRes.value
      : (errors.push(`insider: ${failureMessage(insiderRes.reason)}`), null);
  const news =
    newsRes.status === 'fulfilled'
      ? newsRes.value
      : (errors.push(`news: ${failureMessage(newsRes.reason)}`), null);
  const macro =
    macroRes.status === 'fulfilled'
      ? macroRes.value
      : (errors.push(`macro: ${failureMessage(macroRes.reason)}`), null);
  const manualEvents =
    manualRes.status === 'fulfilled'
      ? manualRes.value
      : (errors.push(`manual: ${failureMessage(manualRes.reason)}`), []);

  const quote = quoteSeries ? publicQuoteFromSeries(quoteSeries) : null;
  const signalContext = signal
    ? {
        score: signal.score,
        maxScore: signal.maxScore,
        stance: signal.stance,
        headline: signal.headline,
      }
    : null;
  const insiderSummary = insider?.summaries.find((row) => row.ticker === ticker) || null;
  const pulseItems =
    news?.pulses.find((row) => row.ticker === ticker)?.topItems ||
    news?.hackerNews.filter((row) => row.tickers.includes(ticker)) ||
    [];
  const newsForTicker = [...manualEvents, ...pulseItems].sort(
    (left, right) =>
      new Date(right.publishedAt).getTime() - new Date(left.publishedAt).getTime()
  );
  const macroExcerpt = macro
    ? macro.series.filter((row) => ['T10Y2Y', 'DFF', 'DGS10', 'CPIAUCSL'].includes(row.id))
    : [];

  // The Rust options contract currently exposes strict chain/gamma readiness.
  // It does not expose a promoted calibrated terminal-price distribution or
  // an approved strategy-candidate contract, so both remain unavailable.
  const priceDistribution: PriceDistributionReport | null = null;
  const strategyCandidates: TickerStrategyCandidate[] = [];

  return {
    ticker,
    generatedAt,
    quote,
    signalContext,
    insider: insiderSummary,
    options,
    news: newsForTicker.slice(0, 8),
    macroExcerpt,
    priceDistribution,
    strategyCandidates,
    reliability: {
      quote: quote ? 'ok' : 'unavailable',
      insider: insiderSummary?.reliability || 'unavailable',
      options: options && options.spot > 0 ? 'ok' : 'unavailable',
      news:
        news &&
        (news.reliability.hackernews === 'ok' || news.reliability.gdelt === 'ok')
          ? 'ok'
          : 'unavailable',
      distribution: 'unavailable',
      macro: macro?.reliability || 'unavailable',
    },
    errors,
    disclaimer:
      '页面只展示 Rust 点时量化服务返回的结果。没有通过实时授权、完整期权链、OOS 校准与冻结 artifact 门禁时，概率分布和策略候选保持不可用；不使用浏览器端 Black-Scholes 或历史波动率替代。',
  };
}

function failureMessage(reason: unknown): string {
  return reason instanceof Error ? reason.message : 'unavailable';
}

function publicQuoteFromSeries(series: YahooSeries): MarketSignalQuote {
  const { closes: _closes, ...quote } = series;
  return quote;
}

async function fetchManualEventsForTicker(
  ticker: string,
  daysBack: number,
  limit: number
): Promise<NewsItem[]> {
  if (!isSupabaseConfigured()) return [];
  try {
    const db = supabaseAdmin();
    const sinceIso = new Date(Date.now() - daysBack * 24 * 60 * 60 * 1000).toISOString();
    const { data, error } = await db
      .from('manual_market_events')
      .select(
        'id, source_type, source_url, headline, text, tickers, tags, sentiment, materiality_score, confidence, published_at'
      )
      .contains('tickers', [ticker])
      .gte('published_at', sinceIso)
      .order('published_at', { ascending: false })
      .limit(limit);
    if (error || !data) return [];
    return data.map((row: ManualEventRow) => ({
      id: `manual-${row.id}`,
      source: 'manual' as const,
      title: row.headline || row.text.slice(0, 160),
      url: row.source_url || undefined,
      publishedAt: row.published_at,
      score: row.materiality_score,
      tickers: row.tickers || [],
      tone: row.sentiment === 'bullish' ? 1.5 : row.sentiment === 'bearish' ? -1.5 : 0,
      manualSourceType: normalizeManualSource(row.source_type),
      sentiment: row.sentiment,
      materialityScore: row.materiality_score,
      confidence: row.confidence,
    }));
  } catch (error) {
    console.warn('[ticker-console/manual]', failureMessage(error));
    return [];
  }
}

function normalizeManualSource(
  value: string
): 'x_manual' | 'truth_manual' | 'reuters_headline' | 'press_release' | 'sec_url' | 'other' {
  return [
    'x_manual',
    'truth_manual',
    'reuters_headline',
    'press_release',
    'sec_url',
  ].includes(value)
    ? (value as 'x_manual' | 'truth_manual' | 'reuters_headline' | 'press_release' | 'sec_url')
    : 'other';
}

type ManualEventRow = {
  id: string;
  source_type: string;
  source_url: string | null;
  headline: string;
  text: string;
  tickers: string[];
  tags: string[];
  sentiment: 'bullish' | 'bearish' | 'neutral' | 'mixed';
  materiality_score: number;
  confidence: number;
  published_at: string;
};

function nextFridayString(): string {
  const date = new Date();
  const day = date.getUTCDay();
  const add = (5 - day + 7) % 7 || 7;
  date.setUTCDate(date.getUTCDate() + add);
  return date.toISOString().slice(0, 10);
}

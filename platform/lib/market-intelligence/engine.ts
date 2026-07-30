import { chat, llmApiKey } from '@/lib/llm';
import { assessMarketRequest, MARKET_DISCLAIMER } from './compliance';
import { fetchAuthorizedMarketEvents, getInfluencerMonitors, getSourceStatuses, normalizeTickers } from './sources';
import type {
  MarketAgentFinding,
  MarketDecisionFrame,
  MarketEvent,
  MarketHorizon,
  MarketResearchReport,
  MarketResearchRequest,
  MarketSentiment,
  StrategyMode,
  StrategySignal,
} from './types';

const COMMON_WORDS = new Set([
  'AI',
  'API',
  'CEO',
  'CFO',
  'CTO',
  'SEC',
  'ETF',
  'USA',
  'USD',
  'GDP',
  'CPI',
  'FOMC',
  'NYSE',
  'NASDAQ',
]);

export async function runMarketResearch(input: MarketResearchRequest): Promise<MarketResearchReport> {
  const watchlist = normalizeTickers([...input.watchlist, ...extractTickers(input.query)]);
  const compliance = assessMarketRequest(`${input.query} ${watchlist.join(' ')}`);
  const sources = getSourceStatuses();
  const influencers = getInfluencerMonitors();
  const mode = input.mode || 'paper';
  const generatedAt = new Date().toISOString();

  if (!compliance.allowed) {
    return {
      generatedAt,
      query: input.query,
      watchlist,
      horizon: input.horizon,
      mode,
      compliance,
      brief:
        'Request blocked. AXIO7 can research public and authorized market-moving information, but it will not collect, summarize, or help trade on insider, confidential, private, or unauthorized information.',
      decisionFrame: {
        stance: 'Stand down',
        confidence: 99,
        rationale: compliance.reasons,
        nextChecks: [
          'Reframe the request around public filings, public news, licensed market data, or authorized community sources.',
          'Ask for evidence quality, source verification, or ticker exposure mapping instead of non-public information.',
        ],
      },
      agents: blockedAgents(compliance.reasons),
      events: [],
      signals: [],
      sources,
      influencers,
      audit: [
        'Compliance gate rejected the request before data collection.',
        'No external source calls were made for the blocked request.',
      ],
      disclaimer: MARKET_DISCLAIMER,
    };
  }

  const events = rankEvents(await fetchAuthorizedMarketEvents(watchlist, input.query), watchlist, input.query);
  const signals = buildStrategySignals(events, watchlist, input.horizon, mode);
  const decisionFrame = buildDecisionFrame(events, input.horizon, compliance.severity);
  const agents = buildAgentFindings(events, watchlist, compliance.severity, sources.filter((source) => source.enabled));
  const brief = await buildBrief(input, events, decisionFrame, signals);

  return {
    generatedAt,
    query: input.query,
    watchlist,
    horizon: input.horizon,
    mode,
    compliance,
    brief,
    decisionFrame,
    agents,
    events,
    signals,
    sources,
    influencers,
    audit: [
      `Request assessed as ${compliance.severity}.`,
      `Ticker universe: ${watchlist.length ? watchlist.join(', ') : 'none detected'}.`,
      `Collected ${events.length} event(s) and generated ${signals.length} strategy signal(s).`,
      `Execution mode: ${mode}. Signals are not routed to a broker by AXIO7.`,
      'Output constrained to source quality, strategy signals, and risk controls. No trade execution or personalized portfolio advice generated.',
    ],
    disclaimer: MARKET_DISCLAIMER,
  };
}

export function extractTickers(text: string): string[] {
  const matches = text.match(/\$?[A-Z]{1,6}(?:\.[A-Z])?\b/g) || [];
  return normalizeTickers(
    matches
      .map((match) => match.replace(/^\$/, ''))
      .filter((match) => !COMMON_WORDS.has(match))
  );
}

function rankEvents(events: MarketEvent[], watchlist: string[], query: string): MarketEvent[] {
  const queryLower = query.toLowerCase();
  return events
    .map((event) => {
      const watchlistHit = event.tickers.some((ticker) => watchlist.includes(ticker)) ? 12 : 0;
      const queryHit = event.tickers.some((ticker) => queryLower.includes(ticker.toLowerCase())) ? 8 : 0;
      const sourceTrust =
        event.verification === 'official' ? 12 : event.verification === 'reported' ? 7 : event.verification === 'demo' ? -14 : 2;
      return {
        event: {
          ...event,
          materiality: clamp(Math.round(event.materiality + watchlistHit + queryHit + sourceTrust), 0, 100),
        },
        score: event.confidence * 0.42 + event.materiality * 0.5 + sourceTrust + watchlistHit + queryHit,
      };
    })
    .sort((a, b) => b.score - a.score || new Date(b.event.publishedAt).getTime() - new Date(a.event.publishedAt).getTime())
    .slice(0, 12)
    .map(({ event }) => event);
}

function buildDecisionFrame(
  events: MarketEvent[],
  horizon: MarketHorizon,
  complianceSeverity: 'clear' | 'caution' | 'blocked'
): MarketDecisionFrame {
  if (events.length === 0) {
    return {
      stance: 'Stand down',
      confidence: 86,
      rationale: ['No timely public or authorized events were available for the request.'],
      nextChecks: ['Add tickers to the watchlist.', 'Connect live vendor feeds before acting on time-sensitive market events.'],
    };
  }

  const officialCount = events.filter((event) => event.verification === 'official').length;
  const reportedCount = events.filter((event) => event.verification === 'reported').length;
  const demoCount = events.filter((event) => event.verification === 'demo').length;
  const maxMateriality = Math.max(...events.map((event) => event.materiality));
  const avgConfidence = Math.round(events.reduce((sum, event) => sum + event.confidence, 0) / events.length);
  const sentiment = aggregateSentiment(events);
  const stance = demoCount === events.length ? 'Investigate' : maxMateriality >= 78 ? 'Investigate' : 'Monitor';

  const horizonText =
    horizon === 'intraday'
      ? 'Intraday use needs timestamp and source freshness checks.'
      : horizon === 'swing'
        ? 'Swing horizon should compare catalyst durability against the next filings, earnings, and macro calendar.'
        : 'Long-term horizon should anchor on filings, fundamentals, and durable business impact.';

  return {
    stance,
    confidence: clamp(complianceSeverity === 'caution' ? avgConfidence - 12 : avgConfidence, 0, 100),
    rationale: [
      `${officialCount} official event(s), ${reportedCount} reported event(s), ${demoCount} demo fallback event(s).`,
      `Highest materiality score is ${maxMateriality}/100 with aggregate sentiment ${sentiment}.`,
      horizonText,
    ],
    nextChecks: [
      'Open the primary source links before treating any catalyst as material.',
      'Compare event timestamp against price and volume reaction.',
      'Check whether related tickers or suppliers/customers are exposed to the same catalyst.',
      'Run paper-mode replay before enabling live-signal alerts.',
      'Record the source, timestamp, and reasoning in the audit trail.',
    ],
  };
}

function buildStrategySignals(
  events: MarketEvent[],
  watchlist: string[],
  horizon: MarketHorizon,
  mode: StrategyMode
): StrategySignal[] {
  const generatedAt = new Date().toISOString();
  const byTicker = new Map<string, MarketEvent[]>();

  for (const event of events) {
    for (const ticker of event.tickers.length ? event.tickers : watchlist) {
      if (!watchlist.includes(ticker)) continue;
      const bucket = byTicker.get(ticker) || [];
      bucket.push(event);
      byTicker.set(ticker, bucket);
    }
  }

  return Array.from(byTicker.entries())
    .map(([ticker, tickerEvents]) => {
      const sourceScore = tickerEvents.reduce((sum, event) => sum + event.materiality * event.confidence, 0);
      const normalizer = Math.max(1, tickerEvents.length * 100);
      const avg = sourceScore / normalizer;
      const socialBoost = tickerEvents.some((event) => event.influencer) ? 10 : 0;
      const officialBoost = tickerEvents.some((event) => event.verification === 'official') ? 8 : 0;
      const tapeBoost = Math.min(14, Math.max(...tickerEvents.map((event) => Math.abs(event.marketMoveBps || 0)), 0) / 35);
      const score = clamp(Math.round(avg + socialBoost + officialBoost + tapeBoost), 0, 100);
      const sentiment = aggregateSentiment(tickerEvents);
      const hasDemoOnly = tickerEvents.every((event) => event.verification === 'demo');
      const hasHighRisk = tickerEvents.some((event) =>
        event.riskFlags.some((flag) => /demo|unauthorized|mnpi|private|redistribution/i.test(flag))
      );

      const action =
        hasDemoOnly || hasHighRisk
          ? 'NO_TRADE'
          : sentiment === 'bearish' && score >= 72
            ? 'PAPER_SHORT'
            : sentiment === 'bullish' && score >= 72
              ? 'PAPER_LONG'
              : score >= 82
                ? 'WATCH'
                : score < 35
                  ? 'RISK_OFF'
                  : 'WATCH';

      const top = tickerEvents[0];
      return {
        id: `signal-${ticker}-${stableSignalId(tickerEvents.map((event) => event.id).join('|'))}`,
        action: mode === 'live_signal' && action.startsWith('PAPER_') ? action : action,
        ticker,
        score,
        confidence: clamp(Math.round(tickerEvents.reduce((sum, event) => sum + event.confidence, 0) / tickerEvents.length), 0, 100),
        horizon,
        mode,
        thesis: `${ticker}: ${top?.title || 'No primary catalyst'}; ${tickerEvents.length} corroborating event(s), aggregate sentiment ${sentiment}.`,
        invalidation:
          'Invalidate if primary source is corrected, tape reverses without confirmation, or a higher-trust source contradicts the catalyst.',
        sourceEventIds: tickerEvents.map((event) => event.id).slice(0, 8),
        riskFlags: Array.from(new Set(tickerEvents.flatMap((event) => event.riskFlags))).slice(0, 5),
        generatedAt,
      } satisfies StrategySignal;
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, 12);
}

function buildAgentFindings(
  events: MarketEvent[],
  watchlist: string[],
  complianceSeverity: 'clear' | 'caution' | 'blocked',
  enabledSources: { name: string }[]
): MarketAgentFinding[] {
  const top = events[0];
  const official = events.filter((event) => event.verification === 'official');
  const nonOfficial = events.filter((event) => event.verification !== 'official');
  const risks = Array.from(new Set(events.flatMap((event) => event.riskFlags))).slice(0, 4);

  return [
    {
      id: 'source-auditor',
      name: 'Source Auditor',
      role: 'Provenance, access rights, and evidence quality',
      status: nonOfficial.length > official.length ? 'watch' : 'pass',
      summary: `${official.length} official event(s) and ${nonOfficial.length} non-official event(s) checked.`,
      bullets: [
        enabledSources.length ? `Enabled live sources: ${enabledSources.map((source) => source.name).join(', ')}.` : 'No live vendor/social sources configured yet.',
        risks[0] || 'No major source-quality flags detected.',
      ],
    },
    {
      id: 'catalyst-mapper',
      name: 'Catalyst Mapper',
      role: 'Ticker exposure and market-moving event clustering',
      status: top && top.materiality >= 75 ? 'watch' : 'pass',
      summary: top ? `${top.title} is the highest-materiality event.` : 'No catalyst cluster found.',
      bullets: top
        ? [`Top event maps to ${top.tickers.join(', ')}.`, `Materiality ${top.materiality}/100, confidence ${top.confidence}/100.`]
        : ['Add ticker watchlist or connect live feeds.'],
    },
    {
      id: 'sentiment-reader',
      name: 'Sentiment Reader',
      role: 'Bullish, bearish, neutral, and mixed language classification',
      status: aggregateSentiment(events) === 'mixed' ? 'watch' : 'pass',
      summary: `Aggregate read is ${aggregateSentiment(events)} across ${events.length} event(s).`,
      bullets: sentimentBullets(events),
    },
    {
      id: 'risk-officer',
      name: 'Risk Officer',
      role: 'Compliance boundary, uncertainty, and non-advice framing',
      status: complianceSeverity === 'caution' ? 'watch' : 'pass',
      summary:
        complianceSeverity === 'caution'
          ? 'Request allowed, but wording is close to personalized trading advice.'
          : 'Output stays within market research and source verification.',
      bullets: [
        'No order routing, no account connection, no position sizing.',
        watchlist.length ? `Watchlist scope: ${watchlist.join(', ')}.` : 'No personalized portfolio data used.',
      ],
    },
  ];
}

async function buildBrief(
  input: MarketResearchRequest,
  events: MarketEvent[],
  decisionFrame: MarketDecisionFrame,
  signals: StrategySignal[]
): Promise<string> {
  const fallback = fallbackBrief(events, decisionFrame, signals);
  if (!llmApiKey() || process.env.MARKET_LLM_ENABLED !== 'true') return fallback;

  try {
    const eventBlock = events
      .slice(0, 6)
      .map(
        (event, index) =>
          `${index + 1}. ${event.title} | ${event.sourceName} | ${event.verification} | tickers ${event.tickers.join(', ')} | ${event.summary}`
      )
      .join('\n');

    const content = await chat(
      [
        {
          role: 'system',
          content:
            'You write concise market intelligence briefs. Use only the supplied events. Do not provide personalized buy/sell advice, position sizing, price targets, or trade execution instructions. Do not mention insider information except to say it is not used.',
        },
        {
          role: 'user',
          content: `Query: ${input.query}\nWatchlist: ${input.watchlist.join(', ')}\nHorizon: ${input.horizon}\nDecision stance: ${decisionFrame.stance}\nSignals: ${signals.map((signal) => `${signal.ticker}:${signal.action}:${signal.score}`).join(', ')}\nEvents:\n${eventBlock}\n\nWrite 4 short sentences: what happened, why it matters, signal quality, and what to verify next.`,
        },
      ],
      { temperature: 0.2, max_tokens: 220 }
    );
    return content || fallback;
  } catch (err) {
    const status = typeof err === 'object' && err && 'status' in err ? ` status=${String(err.status)}` : '';
    console.warn(`[market/brief] llm fallback used${status}`);
    return fallback;
  }
}

function fallbackBrief(events: MarketEvent[], decisionFrame: MarketDecisionFrame, signals: StrategySignal[]) {
  if (!events.length) {
    return 'No public or authorized market events were found for this request. Add tickers or connect live data providers, then re-run the research pass.';
  }

  const top = events[0];
  const topSignal = signals[0];
  const signalText = topSignal ? ` Top signal: ${topSignal.ticker} ${topSignal.action} score ${topSignal.score}/100.` : '';
  return `${top.title} is currently the highest-ranked catalyst in this strategy pass. Evidence quality is ${top.verification} from ${top.sourceName}, with confidence ${top.confidence}/100 and materiality ${top.materiality}/100.${signalText} The decision frame is ${decisionFrame.stance}; verify primary-source links, timestamp, volume reaction, and related ticker exposure before using live-signal mode.`;
}

function blockedAgents(reasons: string[]): MarketAgentFinding[] {
  return [
    {
      id: 'compliance-gate',
      name: 'Compliance Gate',
      role: 'Blocks MNPI, private data, and unauthorized collection',
      status: 'blocked',
      summary: 'Request blocked before collection.',
      bullets: reasons,
    },
  ];
}

function aggregateSentiment(events: MarketEvent[]): MarketSentiment {
  if (!events.length) return 'neutral';
  const counts = events.reduce<Record<MarketSentiment, number>>(
    (acc, event) => {
      acc[event.sentiment] += 1;
      return acc;
    },
    { bullish: 0, bearish: 0, neutral: 0, mixed: 0 }
  );
  if (counts.mixed > 0) return 'mixed';
  if (counts.bullish > 0 && counts.bearish > 0) return 'mixed';
  if (counts.bullish > counts.bearish && counts.bullish > counts.neutral) return 'bullish';
  if (counts.bearish > counts.bullish && counts.bearish > counts.neutral) return 'bearish';
  return 'neutral';
}

function sentimentBullets(events: MarketEvent[]) {
  const counts = events.reduce<Record<MarketSentiment, number>>(
    (acc, event) => {
      acc[event.sentiment] += 1;
      return acc;
    },
    { bullish: 0, bearish: 0, neutral: 0, mixed: 0 }
  );
  return [
    `Bullish ${counts.bullish}, bearish ${counts.bearish}, neutral ${counts.neutral}, mixed ${counts.mixed}.`,
    'Sentiment is descriptive, not an instruction to trade.',
  ];
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function stableSignalId(input: string) {
  let hash = 0;
  for (let i = 0; i < input.length; i += 1) {
    hash = (hash * 33 + input.charCodeAt(i)) >>> 0;
  }
  return hash.toString(36);
}

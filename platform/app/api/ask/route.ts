import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import type {
  ForecastChatResult,
  ForecastSource,
  MarketMonitorAction,
  QuantDailyRegimeReport,
  QuantEvidenceEnvelope,
  QuantSessionSummary,
  QuantTickerRagBundle,
} from '@/lib/forecast-chat-types';
import { getCurrentUser } from '@/lib/auth';
import {
  compileMarketQuery,
  inferMonitorCadenceMinutes,
  MarketQueryClarificationError,
  requestsMarketMonitor,
  requestsNextSessionForecast,
  UnsupportedScheduledEventModelError,
} from '@/lib/quant/market-query';
import {
  createMarketMonitor,
} from '@/lib/quant/market-monitors';
import {
  answerModelKnowledgeQuestion,
  explainDailyRegimeResult,
  explainQuantResearchResult,
} from '@/lib/quant/conversation';
import { isMarketResearchQuestion } from '@/lib/quant/model-knowledge';
import {
  QuantBackendUnavailableError,
  requestQuantDailyRegime,
  requestQuantResearch,
  requestQuantResearchUniverse,
  requestQuantTickerRag,
} from '@/lib/quant/research-client';
import { isSameOriginRequest } from '@/lib/same-origin';
import { recordBillingUsageEventBestEffort } from '@/lib/refund-requests';
import { requirePaidResearchAccess } from '@/lib/research-access';
import { buildMacroReport, type MacroReport } from '@/lib/market-intelligence/macro';
import {
  buildNewsPulseReport,
  type NewsPulseReport,
} from '@/lib/market-intelligence/news-pulse';
import { modelCodeInventory } from '@/lib/quant/model-code-inventory';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 60;

const Body = z.object({
  query: z.string().min(1).max(2000),
  watchlist: z.array(z.string().min(1).max(12)).max(30).optional(),
});

function researchSources(envelope: QuantEvidenceEnvelope): ForecastSource[] {
  const sources = new Map<string, ForecastSource>();
  for (const candidate of envelope.candidates) {
    for (const row of candidate.freshness) {
      const id = `${row.source}:${row.entitlement}`;
      sources.set(id, {
        id,
        name: row.source,
        state: row.realtime ? 'real_time' : 'historical',
        role: row.entitlement,
        asOf: row.available_at || row.observed_at || null,
        note:
          row.coverage == null
            ? `Age ${row.age_seconds ?? 'unknown'} seconds`
            : `Coverage ${(row.coverage * 100).toFixed(1)}%; age ${
                row.age_seconds ?? 'unknown'
              } seconds`,
      });
    }
  }
  if (envelope.query.filters.include_historical) {
    for (const row of envelope.historical) {
      const id = `historical:${row.symbol}:${row.source}`;
      sources.set(id, {
        id,
        name: row.source || 'Normalized historical market bars',
        state: 'historical',
        role: `${row.symbol} ${row.method_version}`,
        asOf: row.dataset_end || null,
        note: `${row.sessions} sessions; ${row.evidence_grade}`,
      });
    }
  }
  sources.set('axio7-rust-engine', {
    id: 'axio7-rust-engine',
    name: 'AXIO7 Rust Quant Engine',
    state: envelope.status === 'DATA_UNAVAILABLE' ? 'unavailable' : 'computed',
    role: String(
      envelope.model_contract.model_version ||
        envelope.model_contract.artifact_version ||
        'deterministic research runtime'
    ),
    asOf: envelope.generated_at,
    note: `Evidence contract ${envelope.schema_version}; audit ${envelope.request_id}`,
  });
  return Array.from(sources.values());
}

function tickerRagSources(bundle: QuantTickerRagBundle): ForecastSource[] {
  return bundle.results.flatMap((result) => {
    if (!result.summary) return [];
    return [
      {
        id: `ticker-rag:${result.data_symbol}:${result.summary.session_date_et}`,
        name: 'AXIO7 ticker RAG / Databento EQUS.MINI',
        state: 'historical' as const,
        role: `${result.requested_symbol} exact-symbol database retrieval`,
        asOf: result.summary.source.last_available_at,
        note: `${result.summary.minute_rows} one-minute rows; ${result.summary.five_minute_bar_count} five-minute bars`,
      },
    ];
  });
}

function toForecast(
  envelope: QuantEvidenceEnvelope,
  compilerNotes: string[],
  sessionSummary?: QuantSessionSummary,
  tickerRag?: QuantTickerRagBundle
): ForecastChatResult {
  const sources = researchSources(envelope);
  if (sessionSummary) {
    sources.push({
      id: `databento-session:${sessionSummary.data_symbol}:${sessionSummary.session_date_et}`,
      name: 'Databento EQUS.MINI',
      state: 'historical',
      role: `${sessionSummary.public_symbol} via ${sessionSummary.data_symbol} observed regular session`,
      asOf: sessionSummary.source.last_available_at,
      note: `${sessionSummary.minute_rows} one-minute rows; ${sessionSummary.five_minute_bar_count} five-minute bars`,
    });
  }
  if (tickerRag) sources.push(...tickerRagSources(tickerRag));
  return {
    generatedAt: envelope.generated_at,
    model: 'AXIO7 Native Quant Engine',
    horizon:
      envelope.query.horizon_minutes === undefined
        ? 'all_configured_horizons'
        : `${envelope.query.horizon_minutes}_minutes`,
    assets: [],
    sources,
    evidence: [],
    disclaimer:
      'Impersonal whole-market statistical research only. Scores are not probabilities unless explicitly labeled as calibrated; no output is an order, personalized recommendation, or guaranteed outcome.',
    research: envelope,
    sessionSummary,
    tickerRag,
    compilerNotes,
  };
}

function tickerRagForecast(
  bundle: QuantTickerRagBundle,
  compilerNotes: string[]
): ForecastChatResult {
  return {
    generatedAt: bundle.generated_at,
    model: 'AXIO7 Rust Ticker RAG',
    horizon: 'observed_regular_session',
    assets: [],
    sources: tickerRagSources(bundle),
    evidence: [],
    disclaimer:
      'Impersonal market research only. Retrieved observations are not calibrated forecasts, orders, personalized recommendations, or guaranteed outcomes.',
    tickerRag: bundle,
    compilerNotes,
  };
}

function dailyRegimeSources(
  report: QuantDailyRegimeReport,
  macro: MacroReport | null,
  news: NewsPulseReport | null
): ForecastSource[] {
  const sources: ForecastSource[] = [
    {
      id: `databento-daily-regime:${report.source.dataset_sha256}`,
      name: 'Databento EQUS.MINI',
      state: 'historical',
      role: `${report.public_symbol} via ${report.data_symbol}; ${report.source.schema}; ${report.source.session_clock}`,
      asOf: report.source.latest_available_at,
      note: `${report.source.complete_feature_sessions} complete feature sessions; observation cutoff ${report.observation_cutoff}; ${report.source.files.length} immutable DBN files`,
    },
    {
      id: `axio7-daily-regime:${report.model_contract.model_version}`,
      name: 'AXIO7 Rust Daily Regime + Analog Engine',
      state: 'computed',
      role: report.model_contract.model_id,
      asOf: report.generated_at,
      note: `${report.model_contract.status}; ${report.model_contract.feature_count} causal features; raw empirical likelihood and uncertainty interval displayed; calibrated probability publication disabled`,
    },
  ];
  for (const series of macro?.series ?? []) {
    sources.push({
      id: `fred:${series.id}`,
      name: series.source,
      state: series.status === 'ok' ? 'historical' : 'unavailable',
      role: `${series.id} display context only`,
      asOf: series.asOf,
      note:
        series.status === 'ok'
          ? `${series.title}; latest ${series.latest ?? 'unavailable'} ${series.unit}`
          : `${series.title}; unavailable`,
    });
  }
  if (news) {
    sources.push(
      {
        id: 'news:hackernews',
        name: 'Hacker News Algolia',
        state:
          news.reliability.hackernews === 'ok' ? 'historical' : 'unavailable',
        role: 'Current public-news display context only',
        asOf: news.generatedAt,
        note: `${news.hackerNews.length} matched items`,
      },
      {
        id: 'news:gdelt',
        name: 'GDELT 2.0',
        state: news.reliability.gdelt === 'ok' ? 'historical' : 'unavailable',
        role: 'Current public-news display context only',
        asOf: news.generatedAt,
        note: `${news.gdelt.length} matched items`,
      }
    );
  }
  return sources;
}

function compactMacro(report: MacroReport | null): MacroReport | null {
  if (!report) return null;
  return {
    ...report,
    series: report.series.map((series) => ({
      ...series,
      history: series.history.slice(-2),
    })),
  };
}

function compactNews(report: NewsPulseReport | null): NewsPulseReport | null {
  if (!report) return null;
  return {
    ...report,
    pulses: report.pulses.map((pulse) => ({
      ...pulse,
      topItems: pulse.topItems.slice(0, 5),
    })),
    hackerNews: report.hackerNews.slice(0, 20),
    gdelt: report.gdelt.slice(0, 20),
  };
}

function fixed(value: number, digits = 2): string {
  return Number.isFinite(value) ? value.toFixed(digits) : 'unavailable';
}

function signedPercent(value: number): string {
  return `${value >= 0 ? '+' : ''}${fixed(value)}%`;
}

function sessionSummaryAnswer(
  summary: QuantSessionSummary,
  locale: 'en-US' | 'zh-CN'
): string {
  const latest = summary.latest_completed_bar;
  const complete =
    summary.status === 'COMPLETE_78_BAR_SESSION';
  if (locale === 'zh-CN') {
    const trend =
      summary.trend_state === 'UP_SESSION'
        ? '上涨时段'
        : summary.trend_state === 'DOWN_SESSION'
          ? '下跌时段'
          : '平盘时段';
    return [
      `${summary.session_date_et} 的 ${summary.public_symbol} 独立观测结果：${trend}。`,
      `${summary.data_symbol} 常规交易时段收于 ${fixed(summary.session_close)}，相对开盘 ${signedPercent(summary.session_return_pct)}；时段区间 ${fixed(summary.session_range_pct)}%，收盘位于区间的 ${fixed(summary.close_location_pct)}%。`,
      latest
        ? `最新完整 5 分钟窗口收于 ${fixed(latest.close)}，窗口涨跌 ${signedPercent(latest.return_pct)}。`
        : '当前尚无完整的 5 分钟窗口。',
      `Databento 已覆盖 ${summary.minute_rows} 根 1 分钟数据和 ${summary.five_minute_bar_count}${complete ? '/78' : ''} 根 5 分钟数据。`,
      summary.public_symbol === 'SPX'
        ? '这是 SPY 对 SPX 的历史/时段内观测代理，不是实时模型概率或交易建议。'
        : `这是 ${summary.public_symbol} 的独立数据库观测结果，不是实时模型概率或交易建议。`,
    ].join(' ');
  }
  const trend = summary.trend_state.replaceAll('_', ' ').toLowerCase();
  return [
    `Observed ${summary.public_symbol} result for ${summary.session_date_et}: ${trend}.`,
    `${summary.data_symbol} closed the regular session at ${fixed(summary.session_close)}, ${signedPercent(summary.session_return_pct)} from the session open; the range was ${fixed(summary.session_range_pct)}%, with the close at ${fixed(summary.close_location_pct)}% of that range.`,
    latest
      ? `The latest completed five-minute window closed at ${fixed(latest.close)} (${signedPercent(latest.return_pct)} in the window).`
      : 'No completed five-minute window is available yet.',
    `Databento coverage: ${summary.minute_rows} one-minute rows and ${summary.five_minute_bar_count}${complete ? '/78' : ''} five-minute bars.`,
    summary.public_symbol === 'SPX'
      ? 'This is an observed SPY proxy for SPX, not a live model probability or trade recommendation.'
      : `This is an independent database observation for ${summary.public_symbol}, not a live model probability or trade recommendation.`,
  ].join(' ');
}

function tickerRagAnswer(
  bundle: QuantTickerRagBundle,
  locale: 'en-US' | 'zh-CN'
): string {
  const retrieved = bundle.results.filter((result) => result.summary).length;
  const heading =
    locale === 'zh-CN'
      ? `Ticker RAG 已按请求顺序返回 ${bundle.result_count} 个独立结果，其中 ${retrieved} 个具有可用数据库观测。`
      : `Ticker RAG returned ${bundle.result_count} independent results in request order; ${retrieved} have eligible database observations.`;
  const results = bundle.results.map((result) => {
    if (result.summary) return sessionSummaryAnswer(result.summary, locale);
    return locale === 'zh-CN'
      ? `${result.requested_symbol}：${result.status}（${result.reason_code}）。${result.reason}`
      : `${result.requested_symbol}: ${result.status} (${result.reason_code}). ${result.reason}`;
  });
  return [heading, ...results].join('\n\n');
}

function quantEnvelopeForExplanation(
  envelope: QuantEvidenceEnvelope
): QuantEvidenceEnvelope {
  if (
    envelope.query.filters.include_historical ||
    envelope.historical.length === 0
  ) {
    return envelope;
  }
  return {
    ...envelope,
    status:
      envelope.candidates.length > 0
        ? envelope.status
        : envelope.data_blockers.length > 0
          ? 'DATA_UNAVAILABLE'
          : envelope.status,
    historical: [],
  };
}

export async function POST(req: NextRequest) {
  if (!isSameOriginRequest(req)) {
    return NextResponse.json({ error: 'cross_origin_rejected' }, { status: 403 });
  }
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const body = await req.json().catch(() => null);
  const parsed = Body.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: 'invalid input', detail: parsed.error.flatten() }, { status: 400 });
  }

  if (!isMarketResearchQuestion(parsed.data.query)) {
    const conversation = await answerModelKnowledgeQuestion(parsed.data.query);
    return NextResponse.json(
      {
        answer: conversation.answer,
        conversation: {
          mode: 'model_knowledge',
          knowledge_version: conversation.knowledgeVersion,
          llm_role: conversation.llmRole,
          llm_model: conversation.llmModel,
          locale: conversation.locale,
        },
      },
      {
        headers: {
          'Cache-Control': 'no-store',
          'X-AXIO7-Conversation-Mode': 'model_knowledge',
          'X-AXIO7-Knowledge-Version': conversation.knowledgeVersion,
          'X-AXIO7-LLM-Role': conversation.llmRole,
          'X-AXIO7-Conversation-Locale': conversation.locale,
        },
      }
    );
  }

  let compiled: ReturnType<typeof compileMarketQuery>;
  try {
    compiled = compileMarketQuery(
      parsed.data.query,
      parsed.data.watchlist ?? []
    );
  } catch (error) {
    if (error instanceof UnsupportedScheduledEventModelError) {
      return NextResponse.json(
        {
          error: 'scheduled_event_model_not_ready',
          code: error.code,
          event_kind: error.eventKind,
          message: error.message,
        },
        {
          status: 422,
          headers: { 'Cache-Control': 'no-store' },
        }
      );
    }
    if (error instanceof MarketQueryClarificationError) {
      return NextResponse.json(
        {
          error: 'market_query_needs_clarification',
          code: error.code,
          answer: error.message,
          clarification: {
            setup_type: error.setupType,
            symbols: error.symbols,
            missing_fields: error.missingFields,
            allowed_values: error.allowedValues,
          },
        },
        {
          status: 422,
          headers: { 'Cache-Control': 'no-store' },
        }
      );
    }
    throw error;
  }
  let monitor: MarketMonitorAction | undefined;
  if (requestsMarketMonitor(parsed.data.query)) {
    const user = await getCurrentUser();
    try {
      monitor = await createMarketMonitor({
        user,
        question: parsed.data.query,
        query: compiled.query,
        cadenceMinutes: inferMonitorCadenceMinutes(parsed.data.query),
      });
    } catch (error) {
      monitor = {
        requested: true,
        status: 'STORAGE_UNAVAILABLE',
        message:
          error instanceof Error
            ? `The monitor could not be saved: ${error.message}`
            : 'The monitor could not be saved.',
      };
    }
  }

  try {
    if (
      requestsNextSessionForecast(parsed.data.query) &&
      compiled.query.setup_type === 'model_forecast' &&
      compiled.query.symbols.includes('SPX')
    ) {
      const [dailyRegime, macro, news] = await Promise.all([
        requestQuantDailyRegime('SPX'),
        buildMacroReport().catch(() => null),
        buildNewsPulseReport([
          'SPY',
          'QQQ',
          'IWM',
          'SOXX',
          'HYG',
          'TLT',
          'UUP',
        ]).catch(() => null),
      ]);
      const conversation = await explainDailyRegimeResult(
        parsed.data.query,
        dailyRegime,
        macro,
        news
      );
      const forecast: ForecastChatResult = {
        generatedAt: dailyRegime.generated_at,
        model: 'AXIO7 Rust Daily Regime + Historical Analog',
        horizon: 'next_regular_session',
        assets: [],
        sources: dailyRegimeSources(dailyRegime, macro, news),
        evidence: [],
        disclaimer:
          'Impersonal whole-market statistical research only. Raw analog frequencies are not calibrated probabilities; no output is an order, personalized recommendation, or guaranteed outcome.',
        dailyRegime,
        macroContext: compactMacro(macro),
        newsContext: compactNews(news),
        modelCodeInventory: modelCodeInventory(),
        compilerNotes: compiled.notes,
      };
      const usageUser = await getCurrentUser().catch(() => null);
      if (usageUser?.authenticated) {
        await recordBillingUsageEventBestEffort({
          userId: usageUser.id,
          eventType: 'api_call_completed',
          metadata: { route: '/api/ask', mode: 'daily_regime_analog' },
        });
        await recordBillingUsageEventBestEffort({
          userId: usageUser.id,
          eventType: 'research_report_generated',
          metadata: {
            evidence_contract: dailyRegime.schema_version,
            model_version: dailyRegime.model_contract.model_version,
          },
        });
      }
      return NextResponse.json(
        {
          answer: monitor
            ? `${monitor.message}\n\n${conversation.answer}`
            : conversation.answer,
          forecast,
          monitor,
          conversation: {
            mode: 'daily_regime_analog',
            knowledge_version: conversation.knowledgeVersion,
            llm_role: conversation.llmRole,
            llm_model: conversation.llmModel,
            locale: conversation.locale,
          },
        },
        {
          headers: {
            'Cache-Control': 'no-store',
            'X-AXIO7-Model-Runtime': 'rust',
            'X-AXIO7-Evidence-Contract': dailyRegime.schema_version,
            'X-AXIO7-Conversation-Mode': 'daily_regime_analog',
            'X-AXIO7-Knowledge-Version': conversation.knowledgeVersion,
            'X-AXIO7-LLM-Role': conversation.llmRole,
            'X-AXIO7-LLM-Model': conversation.llmModel,
            'X-AXIO7-Conversation-Locale': conversation.locale,
          },
        }
      );
    }
    let preloadedTickerRag: QuantTickerRagBundle | undefined;
    if (compiled.query.setup_type === 'model_forecast') {
      const [ragResult, universeResult] = await Promise.allSettled([
        requestQuantTickerRag(compiled.query.symbols),
        requestQuantResearchUniverse(),
      ]);
      if (ragResult.status === 'fulfilled') {
        preloadedTickerRag = ragResult.value;
      } else {
        console.error(
          '[/api/ask] ticker RAG preload unavailable',
          ragResult.reason instanceof Error
            ? ragResult.reason.message
            : ragResult.reason
        );
      }
      if (universeResult.status === 'fulfilled') {
        const configured = new Set(
          universeResult.value.targets.map((target) => target.public_symbol)
        );
        const hasUnconfiguredTarget = compiled.query.symbols.some(
          (symbol) => !configured.has(symbol)
        );
        if (hasUnconfiguredTarget && preloadedTickerRag) {
          const locale = /[\u3400-\u9fff]/.test(parsed.data.query)
            ? 'zh-CN'
            : 'en-US';
          const answer = tickerRagAnswer(preloadedTickerRag, locale);
          const forecast = tickerRagForecast(
            preloadedTickerRag,
            compiled.notes
          );
          const usageUser = await getCurrentUser().catch(() => null);
          if (usageUser?.authenticated) {
            await recordBillingUsageEventBestEffort({
              userId: usageUser.id,
              eventType: 'api_call_completed',
              metadata: { route: '/api/ask', mode: 'ticker_rag' },
            });
          }
          return NextResponse.json(
            {
              answer: monitor ? `${monitor.message}\n\n${answer}` : answer,
              forecast,
              monitor,
              conversation: {
                mode: 'quant_research',
                knowledge_version: preloadedTickerRag.schema_version,
                llm_role: 'deterministic_fallback',
                locale,
              },
            },
            {
              headers: {
                'Cache-Control': 'no-store',
                'X-AXIO7-Model-Runtime': 'rust',
                'X-AXIO7-Evidence-Contract': preloadedTickerRag.schema_version,
                'X-AXIO7-Conversation-Mode': 'ticker_rag',
                'X-AXIO7-Knowledge-Version': preloadedTickerRag.schema_version,
                'X-AXIO7-LLM-Role': 'deterministic_fallback',
                'X-AXIO7-Conversation-Locale': locale,
              },
            }
          );
        }
      }
    }
    const envelope = await requestQuantResearch(compiled.query);
    const conversation = await explainQuantResearchResult(
      parsed.data.query,
      quantEnvelopeForExplanation(envelope),
      compiled.notes
    );
    let tickerRag = preloadedTickerRag;
    if (
      envelope.candidates.length === 0 &&
      compiled.query.setup_type === 'model_forecast' &&
      !tickerRag
    ) {
      try {
        tickerRag = await requestQuantTickerRag(compiled.query.symbols);
      } catch (retrievalError) {
        console.error(
          '[/api/ask] ticker RAG unavailable',
          retrievalError instanceof Error
            ? retrievalError.message
            : retrievalError
        );
      }
    }
    const fallbackTickerRag =
      envelope.candidates.length === 0 ? tickerRag : undefined;
    const forecast = toForecast(
      envelope,
      compiled.notes,
      undefined,
      fallbackTickerRag
    );
    const answer = fallbackTickerRag
      ? tickerRagAnswer(fallbackTickerRag, conversation.locale)
      : conversation.answer;
    const usageUser = await getCurrentUser().catch(() => null);
    if (usageUser?.authenticated) {
      await recordBillingUsageEventBestEffort({
        userId: usageUser.id,
        eventType: 'api_call_completed',
        metadata: { route: '/api/ask', mode: 'quant_research' },
      });
      await recordBillingUsageEventBestEffort({
        userId: usageUser.id,
        eventType: 'research_report_generated',
        metadata: {
          request_id: envelope.request_id,
          evidence_contract: envelope.schema_version,
        },
      });
    }
    return NextResponse.json(
      {
        answer: monitor
          ? `${monitor.message}\n\n${answer}`
          : answer,
        forecast,
        monitor,
        conversation: {
          mode: 'quant_research',
          knowledge_version: conversation.knowledgeVersion,
          llm_role: conversation.llmRole,
          llm_model: conversation.llmModel,
          locale: conversation.locale,
        },
      },
      {
        headers: {
          'Cache-Control': 'no-store',
          'X-AXIO7-Model-Runtime': 'rust',
          'X-AXIO7-Evidence-Contract': envelope.schema_version,
          'X-AXIO7-Conversation-Mode': 'quant_research',
          'X-AXIO7-Knowledge-Version': conversation.knowledgeVersion,
          'X-AXIO7-LLM-Role': conversation.llmRole,
          'X-AXIO7-Conversation-Locale': conversation.locale,
        },
      }
    );
  } catch (error) {
    const unavailable =
      error instanceof QuantBackendUnavailableError
        ? `${error.code}: ${error.message}`
        : error instanceof Error
        ? error.message
        : 'research failed';
    console.error('[/api/ask]', unavailable);
    const backendResponded =
      error instanceof QuantBackendUnavailableError &&
      error.code.startsWith('RUST_BACKEND_HTTP_');
    if (monitor) {
      return NextResponse.json(
        {
          answer: `${monitor.message}\n\nThe immediate scan is unavailable because the native realtime research service is not connected. The monitor will fail closed until entitled live data and the Rust service are ready.`,
          monitor,
        },
        {
          status: monitor.status === 'STORAGE_UNAVAILABLE' ? 503 : 202,
          headers: { 'Cache-Control': 'no-store' },
        }
      );
    }
    return NextResponse.json(
      {
        error:
          backendResponded
            ? 'AXIO7 quant engine is connected, but it rejected this result contract. No unverified substitute was shown.'
            : 'AXIO7 native quant engine is unavailable. No Yahoo, synthetic, or TypeScript forecast fallback was used.',
        detail: unavailable,
      },
      {
        status: 503,
        headers: { 'Cache-Control': 'no-store' },
      }
    );
  }
}

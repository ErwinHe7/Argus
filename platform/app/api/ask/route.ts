import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import type {
  ForecastChatResult,
  ForecastSource,
  MarketMonitorAction,
  QuantEvidenceEnvelope,
} from '@/lib/forecast-chat-types';
import { getCurrentUser } from '@/lib/auth';
import {
  compileMarketQuery,
  inferMonitorCadenceMinutes,
  MarketQueryClarificationError,
  requestsMarketMonitor,
  UnsupportedScheduledEventModelError,
} from '@/lib/quant/market-query';
import {
  createMarketMonitor,
} from '@/lib/quant/market-monitors';
import {
  answerModelKnowledgeQuestion,
  explainQuantResearchResult,
} from '@/lib/quant/conversation';
import { isMarketResearchQuestion } from '@/lib/quant/model-knowledge';
import {
  QuantBackendUnavailableError,
  requestDatabentoDevelopmentReplay,
  requestQuantResearch,
} from '@/lib/quant/research-client';
import {
  developmentReplayReceipt,
  supportsDevelopmentReplay,
} from '@/lib/quant/development-replay';
import { isSameOriginRequest } from '@/lib/same-origin';
import { recordBillingUsageEventBestEffort } from '@/lib/refund-requests';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 60;

const Body = z.object({
  query: z.string().min(1).max(2000),
  watchlist: z.array(z.string().min(1).max(12)).max(30).optional(),
  developmentReplay: z.boolean().optional(),
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

function toForecast(
  envelope: QuantEvidenceEnvelope,
  compilerNotes: string[]
): ForecastChatResult {
  return {
    generatedAt: envelope.generated_at,
    model: 'AXIO7 Native Quant Engine',
    horizon:
      envelope.query.horizon_minutes === undefined
        ? 'all_configured_horizons'
        : `${envelope.query.horizon_minutes}_minutes`,
    assets: [],
    sources: researchSources(envelope),
    evidence: [],
    disclaimer:
      'Impersonal whole-market statistical research only. Scores are not probabilities unless explicitly labeled as calibrated; no output is an order, personalized recommendation, or guaranteed outcome.',
    research: envelope,
    compilerNotes,
  };
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
            historical_only: error.historicalOnly,
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

  const developmentReplayRequested =
    process.env.NODE_ENV !== 'production' &&
    parsed.data.developmentReplay === true;
  if (developmentReplayRequested) {
    if (!supportsDevelopmentReplay(compiled.query)) {
      return NextResponse.json(
        {
          error: 'development_replay_query_not_supported',
          answer:
            'The local Databento pipeline replay currently supports one query. Submit “Forecast SPX using the core model.” to test the Rust replay end to end.',
        },
        {
          status: 422,
          headers: {
            'Cache-Control': 'no-store',
            'X-AXIO7-Response-Mode': 'development-replay',
          },
        }
      );
    }
    try {
      const envelope = await requestDatabentoDevelopmentReplay(compiled.query);
      const replay = developmentReplayReceipt(envelope);
      const artifactFeatureIdentityMatchesReplay =
        envelope.model_contract.artifact_feature_identity_matches_replay ===
        true;
      const historicalTransportMock =
        replay.sourceMode ===
        'DATABENTO_SHAPED_HISTORICAL_TRANSPORT_MOCK';
      const strictHistoricalReplay =
        replay.sourceMode === 'STRICT_INSTALLED_HISTORICAL_REPLAY';
      const contextQualification = strictHistoricalReplay
        ? 'The replay used observed SPY, QQQ, and IWM one-minute bars with zero synthetic context rows. Its two-member cross-asset context is an experimental historical contract, not the production six-member live contract.'
        : historicalTransportMock
        ? `${replay.syntheticContextIntervals} missing context intervals were represented by explicitly synthetic pipeline-only rows, including forward fills and a deterministic proxy for an absent series. This tests pipeline integration, not market data or model validity.`
        : artifactFeatureIdentityMatchesReplay
          ? 'Every replay context input matched the frozen artifact feature identity.'
          : 'The recorded replay used captured causal no-trade observations under a separately versioned, unpromoted shadow policy. This tests pipeline integration, not model validity or live publication.';
      const transportQualification = strictHistoricalReplay
        ? 'A frozen Rust model was trained only on sessions preceding one held-out historical session, then evaluated against that session’s subsequently realized paths.'
        : replay.sourceMode === 'RECORDED_DATABENTO_ENVELOPES'
          ? 'Structurally verified recorded Databento envelopes were ordered by their original exchange timestamps.'
          : 'The recorded session began too late to support a safe four-horizon batch, so a licensed historical session was time-shifted through an internal Databento-shaped transport mock. These rows are not Databento records and do not test live connectivity or latency.';
      const forecast = {
        ...toForecast(envelope, [
          ...compiled.notes,
          strictHistoricalReplay
            ? 'Rust-owned strict historical research replay; not current market data.'
            : 'Rust-owned deterministic Databento pipeline replay; not current market data.',
          transportQualification,
          contextQualification,
        ]),
        model: strictHistoricalReplay
          ? 'AXIO7 Rust strict historical replay'
          : 'AXIO7 Rust Databento pipeline replay',
        developmentReplay: replay,
      };
      return NextResponse.json(
        {
          answer: strictHistoricalReplay
            ? `SPX historical replay completed through ${envelope.observation_cutoff}. The report below is a causal, held-out research diagnostic built from real installed bars. It is not a current forecast; raw expected returns and analog frequencies are uncalibrated, and execution remains disabled.`
            : `Databento pipeline replay completed through ${envelope.observation_cutoff}. ${transportQualification} The historical regime and feature state were initialized, and an isolated replay-local Rust model produced all four configured horizons. The production model artifact was not used. ${contextQualification} This is not current market data. Calibrated probabilities, expected moves, ranking, and execution remain withheld, and no live state was written.`,
          forecast,
          developmentReplay: replay,
          conversation: {
            mode: 'quant_research',
            knowledge_version: 'rust-databento-development-replay.v1',
            llm_role: 'deterministic_fallback',
            locale: 'en-US',
          },
        },
        {
          headers: {
            'Cache-Control': 'no-store',
            'X-AXIO7-Response-Mode': 'databento-pipeline-replay',
            'X-AXIO7-Model-Runtime': 'rust-replay',
            'X-AXIO7-Evidence-Contract': envelope.schema_version,
            'X-AXIO7-Conversation-Mode': 'quant_research',
            'X-AXIO7-Knowledge-Version':
              'rust-databento-development-replay.v1',
            'X-AXIO7-LLM-Role': 'deterministic_fallback',
            'X-AXIO7-Conversation-Locale': 'en-US',
          },
        }
      );
    } catch (error) {
      const detail =
        error instanceof QuantBackendUnavailableError
          ? `${error.code}: ${error.message}`
          : error instanceof Error
            ? error.message
            : 'Databento replay failed';
      console.error('[/api/ask] DATABENTO_REPLAY_UNAVAILABLE:', detail);
      return NextResponse.json(
        {
          error:
            'The Rust Databento replay is unavailable. No TypeScript forecast fixture was substituted.',
          detail,
        },
        {
          status: 503,
          headers: {
            'Cache-Control': 'no-store',
            'X-AXIO7-Response-Mode': 'databento-pipeline-replay',
          },
        }
      );
    }
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
    const envelope = await requestQuantResearch(compiled.query);
    const forecast = toForecast(envelope, compiled.notes);
    const conversation = await explainQuantResearchResult(
      parsed.data.query,
      quantEnvelopeForExplanation(envelope),
      compiled.notes
    );
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
          ? `${monitor.message}\n\n${conversation.answer}`
          : conversation.answer,
        forecast,
        monitor,
        conversation: {
          mode: 'quant_research',
          knowledge_version: conversation.knowledgeVersion,
          llm_role: conversation.llmRole,
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
          'AXIO7 native quant engine is unavailable. No Yahoo, synthetic, or TypeScript forecast fallback was used.',
        detail: unavailable,
      },
      {
        status: 503,
        headers: { 'Cache-Control': 'no-store' },
      }
    );
  }
}

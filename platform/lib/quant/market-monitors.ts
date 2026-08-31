import 'server-only';

import { createHash } from 'crypto';
import { isSupabaseConfigured, supabaseAdmin } from '@/lib/supabase';
import type {
  MarketMonitorAction,
  MarketMonitorView,
  MarketQueryV1,
  QuantEvidenceEnvelope,
  QuantResearchCandidate,
} from '@/lib/forecast-chat-types';
import { MarketQuerySchema } from '@/lib/quant/market-query-schema';
import { requestQuantResearch } from '@/lib/quant/research-client';

export type MarketMonitorStatus = 'active' | 'paused' | 'disabled';

type MarketMonitorRow = {
  id: string;
  user_id: string;
  title: string;
  source_question: string;
  query: MarketQueryV1;
  query_sha256: string;
  status: MarketMonitorStatus;
  cadence_minutes: number;
  next_run_at: string;
  last_run_at: string | null;
  last_result_status: string | null;
  last_error: string | null;
  last_triggered_at: string | null;
  consecutive_failures: number;
  created_at: string;
  updated_at: string;
};

type MarketMonitorEventRow = {
  id: string;
  monitor_id: string;
  triggered_at: string;
  title: string;
  summary: string;
  read_at: string | null;
};

export class MarketMonitorStorageError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'MarketMonitorStorageError';
  }
}

function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) {
    return `[${value.map((item) => canonicalJson(item)).join(',')}]`;
  }
  const record = value as Record<string, unknown>;
  return `{${Object.keys(record)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonicalJson(record[key])}`)
    .join(',')}}`;
}

function sha256(value: unknown) {
  return createHash('sha256').update(canonicalJson(value)).digest('hex');
}

function monitorTitle(query: MarketQueryV1) {
  const names: Record<MarketQueryV1['setup_type'], string> = {
    model_forecast: 'Core model forecast',
    momentum: 'Momentum',
    gamma_squeeze: 'Gamma structure',
    vwap_reversal: 'VWAP reversal',
    opening_turn: 'Opening turn',
    closing_short_cover: 'Closing short-cover',
    statistical_dislocation: 'Market dislocation',
  };
  const symbols = query.symbols.slice(0, 4).join(', ');
  const remainder =
    query.symbols.length > 4 ? ` +${query.symbols.length - 4}` : '';
  return `${names[query.setup_type]} · ${symbols}${remainder}`.slice(0, 120);
}

function storage() {
  if (!isSupabaseConfigured()) {
    throw new MarketMonitorStorageError(
      'Monitor storage is not configured for this deployment.'
    );
  }
  return supabaseAdmin();
}

function toView(
  monitor: MarketMonitorRow,
  latestEvent: MarketMonitorEventRow | null = null
): MarketMonitorView {
  const { user_id: _userId, query_sha256: _queryHash, ...safe } = monitor;
  return {
    ...safe,
    latest_event: latestEvent
      ? {
          id: latestEvent.id,
          triggered_at: latestEvent.triggered_at,
          title: latestEvent.title,
          summary: latestEvent.summary,
          read_at: latestEvent.read_at,
        }
      : null,
  };
}

function normalizedMonitorQuery(query: MarketQueryV1): MarketQueryV1 {
  return MarketQuerySchema.parse({
    ...query,
    intent: 'scan',
    filters: {
      ...query.filters,
      require_realtime: true,
      include_historical: false,
    },
  });
}

export async function createMarketMonitor(input: {
  user: { id: string; authenticated: boolean };
  question: string;
  query: MarketQueryV1;
  cadenceMinutes?: 5 | 15 | 30 | 60;
}): Promise<MarketMonitorAction> {
  if (!input.user.authenticated) {
    return {
      requested: true,
      status: 'AUTHENTICATION_REQUIRED',
      message: 'Sign in to save a monitor that keeps running after this chat.',
    };
  }
  const database = storage();
  const query = normalizedMonitorQuery(input.query);
  const queryHash = sha256(query);
  const cadenceMinutes = input.cadenceMinutes ?? 5;
  const existing = await database
    .from('market_monitors')
    .select('*')
    .eq('user_id', input.user.id)
    .eq('query_sha256', queryHash)
    .eq('status', 'active')
    .maybeSingle();
  if (existing.error) {
    throw new MarketMonitorStorageError(existing.error.message);
  }
  if (existing.data) {
    return {
      requested: true,
      status: 'ALREADY_ACTIVE',
      message: 'That monitor is already active.',
      monitor: toView(existing.data as MarketMonitorRow),
    };
  }

  const inserted = await database
    .from('market_monitors')
    .insert({
      user_id: input.user.id,
      title: monitorTitle(query),
      source_question: input.question.slice(0, 2000),
      query,
      query_sha256: queryHash,
      status: 'active',
      cadence_minutes: cadenceMinutes,
      next_run_at: new Date().toISOString(),
    })
    .select('*')
    .single();
  if (inserted.error || !inserted.data) {
    throw new MarketMonitorStorageError(
      inserted.error?.message || 'Monitor could not be stored.'
    );
  }
  return {
    requested: true,
    status: 'CREATED',
    message: `Monitor created. AXIO7 will evaluate finalized data every ${cadenceMinutes} minutes.`,
    monitor: toView(inserted.data as MarketMonitorRow),
  };
}

export async function listMarketMonitors(
  userId: string
): Promise<MarketMonitorView[]> {
  const database = storage();
  const monitors = await database
    .from('market_monitors')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(50);
  if (monitors.error) {
    throw new MarketMonitorStorageError(monitors.error.message);
  }
  const rows = (monitors.data ?? []) as MarketMonitorRow[];
  if (rows.length === 0) return [];
  const events = await database
    .from('market_monitor_events')
    .select('id,monitor_id,triggered_at,title,summary,read_at')
    .eq('user_id', userId)
    .in(
      'monitor_id',
      rows.map((row) => row.id)
    )
    .order('triggered_at', { ascending: false })
    .limit(100);
  if (events.error) {
    throw new MarketMonitorStorageError(events.error.message);
  }
  const latestByMonitor = new Map<string, MarketMonitorEventRow>();
  for (const event of (events.data ?? []) as MarketMonitorEventRow[]) {
    if (!latestByMonitor.has(event.monitor_id)) {
      latestByMonitor.set(event.monitor_id, event);
    }
  }
  return rows.map((row) => toView(row, latestByMonitor.get(row.id) ?? null));
}

export async function setMarketMonitorStatus(input: {
  userId: string;
  monitorId: string;
  status: Extract<MarketMonitorStatus, 'active' | 'paused'>;
}): Promise<MarketMonitorView | null> {
  const database = storage();
  const values: {
    status: Extract<MarketMonitorStatus, 'active' | 'paused'>;
    updated_at: string;
    next_run_at?: string;
  } = {
    status: input.status,
    updated_at: new Date().toISOString(),
  };
  if (input.status === 'active') values.next_run_at = new Date().toISOString();
  const update = await database
    .from('market_monitors')
    .update(values)
    .eq('id', input.monitorId)
    .eq('user_id', input.userId)
    .select('*')
    .maybeSingle();
  if (update.error) {
    throw new MarketMonitorStorageError(update.error.message);
  }
  return update.data ? toView(update.data as MarketMonitorRow) : null;
}

function triggeredCandidates(envelope: QuantEvidenceEnvelope) {
  const eligibleStatuses = new Set([
    'TRIGGERED_ON_LATEST_COMPLETED_BAR',
    'RESEARCH_CANDIDATE',
  ]);
  return envelope.candidates.filter((candidate) =>
    eligibleStatuses.has(candidate.status)
  );
}

function candidateSummary(candidate: QuantResearchCandidate) {
  return {
    symbol: candidate.symbol,
    setup_type: candidate.setup_type,
    status: candidate.status,
    score: candidate.heuristic_structure_score ?? null,
    score_semantics: candidate.score_semantics,
    supporting_evidence: candidate.supporting_evidence.slice(0, 6),
    contrary_evidence: candidate.contrary_evidence.slice(0, 6),
    metrics: candidate.metrics,
    freshness: candidate.freshness,
  };
}

async function executeClaimedMonitor(monitor: MarketMonitorRow) {
  const database = storage();
  const observedCutoff = new Date().toISOString();
  try {
    const query = normalizedMonitorQuery(
      MarketQuerySchema.parse(monitor.query)
    );
    const envelope = await requestQuantResearch(query);
    const matches = triggeredCandidates(envelope);
    const triggered = matches.length > 0;
    const transitioned = triggered && monitor.last_result_status !== 'TRIGGERED';
    const responseHash =
      envelope.response_sha256 && /^[0-9a-f]{64}$/.test(envelope.response_sha256)
        ? envelope.response_sha256
        : null;
    const summary = {
      request_id: envelope.request_id,
      status: envelope.status,
      data_blockers: envelope.data_blockers.slice(0, 12),
      candidates: envelope.candidates.slice(0, 12).map(candidateSummary),
    };
    await database.from('market_monitor_runs').insert({
      monitor_id: monitor.id,
      user_id: monitor.user_id,
      observed_cutoff: envelope.observation_cutoff || observedCutoff,
      status: envelope.status,
      triggered,
      response_sha256: responseHash,
      candidate_count: envelope.candidates.length,
      result_summary: summary,
    });

    if (transitioned) {
      const symbols = matches.map((candidate) => candidate.symbol).join(', ');
      const fingerprint = sha256({
        monitor_id: monitor.id,
        response_sha256: responseHash,
        observation_cutoff: envelope.observation_cutoff || observedCutoff,
        symbols,
        statuses: matches.map((candidate) => candidate.status),
      });
      await database.from('market_monitor_events').upsert(
        {
          monitor_id: monitor.id,
          user_id: monitor.user_id,
          fingerprint,
          triggered_at: envelope.observation_cutoff || observedCutoff,
          title: `${monitor.title} condition detected`,
          summary: `${symbols} matched the deterministic ${query.setup_type.replaceAll(
            '_',
            ' '
          )} research condition. This is not a profit guarantee or order.`,
          evidence: {
            request_id: envelope.request_id,
            candidates: matches.map(candidateSummary),
            caveats: envelope.caveats,
          },
        },
        { onConflict: 'monitor_id,fingerprint', ignoreDuplicates: true }
      );
    }
    await database
      .from('market_monitors')
      .update({
        last_result_status: triggered ? 'TRIGGERED' : envelope.status,
        last_error: null,
        consecutive_failures: 0,
        last_triggered_at: transitioned
          ? envelope.observation_cutoff || observedCutoff
          : monitor.last_triggered_at,
        updated_at: new Date().toISOString(),
      })
      .eq('id', monitor.id);
    return { id: monitor.id, ok: true, triggered, status: envelope.status };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await database.from('market_monitor_runs').insert({
      monitor_id: monitor.id,
      user_id: monitor.user_id,
      observed_cutoff: observedCutoff,
      status: 'DATA_UNAVAILABLE',
      triggered: false,
      candidate_count: 0,
      result_summary: {},
      error_code: message.slice(0, 500),
    });
    await database
      .from('market_monitors')
      .update({
        last_result_status: 'DATA_UNAVAILABLE',
        last_error: message.slice(0, 1000),
        consecutive_failures: monitor.consecutive_failures + 1,
        updated_at: new Date().toISOString(),
      })
      .eq('id', monitor.id);
    return {
      id: monitor.id,
      ok: false,
      triggered: false,
      status: 'DATA_UNAVAILABLE',
    };
  }
}

export async function runDueMarketMonitors(limit = 50) {
  const database = storage();
  const claimed = await database.rpc('claim_market_monitors', {
    p_limit: Math.max(1, Math.min(200, limit)),
    p_now: new Date().toISOString(),
  });
  if (claimed.error) {
    throw new MarketMonitorStorageError(claimed.error.message);
  }
  const monitors = (claimed.data ?? []) as MarketMonitorRow[];
  const results: Array<Awaited<ReturnType<typeof executeClaimedMonitor>>> = [];
  let cursor = 0;
  const workers = Array.from(
    { length: Math.min(4, monitors.length) },
    async () => {
      while (cursor < monitors.length) {
        const current = monitors[cursor];
        cursor += 1;
        results.push(await executeClaimedMonitor(current));
      }
    }
  );
  await Promise.all(workers);
  return {
    ok: results.every((result) => result.ok),
    claimed: monitors.length,
    triggered: results.filter((result) => result.triggered).length,
    completed: results.length,
    results,
  };
}

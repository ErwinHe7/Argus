import { marketMapSnapshotSchema, publicMarketMapSnapshotSchema, publicMarketMapBundleSchema } from './schema';
import type { MarketMapHorizon, MarketMapSnapshot, PublicMarketMapSnapshot, PublicMarketMapBundle } from './types';

const horizonSessions = { '5d': 5, '10d': 10, '20d': 20, '60d': 60 } as const;
const marketDate = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' });

/** Validate the runtime's artifact. This layer never derives market features. */
export function validateMarketMapSnapshot(
  raw: unknown,
  request: { symbol?: string; horizon?: MarketMapHorizon; now?: Date; review?: boolean } = {},
): MarketMapSnapshot | null {
  const result = marketMapSnapshotSchema.safeParse(raw);
  if (!result.success) return null;
  const snapshot = result.data;
  if (request.symbol && snapshot.asset.symbol !== request.symbol) return null;
  if (request.horizon && snapshot.horizon !== request.horizon) return null;
  if (snapshot.monte_carlo.horizon_sessions !== horizonSessions[snapshot.horizon]) return null;
  // Synthetic examples have a separate, explicitly selected route and identity.
  if (request.review) {
    return snapshot.asset.symbol === 'DEMO' && snapshot.provenance.sources.every(
      (source) => /synthetic|example|review/i.test(`${source.provider} ${source.dataset}`),
    ) ? snapshot : null;
  }
  if (snapshot.asset.symbol === 'DEMO' || snapshot.provenance.sources.some(
    (source) => /synthetic|fixture|example|review/i.test(`${source.provider} ${source.dataset}`),
  )) return null;

  const { provenance } = snapshot;
  const now = (request.now ?? new Date()).getTime();
  const cutoff = Date.parse(provenance.observation_cutoff);
  const available = Date.parse(provenance.available_at);
  const generated = Date.parse(provenance.generated_at);
  const expires = Date.parse(provenance.freshness.expires_at);
  if (!(cutoff <= available && available <= generated && generated <= now && now < expires)) return null;
  if (provenance.freshness.state !== 'fresh' ||
      expires > cutoff + provenance.freshness.max_age_seconds * 1000) return null;
  if (provenance.rights.entitlement !== 'member_research' || !provenance.rights.display_authorized) return null;
  const coverage = provenance.coverage;
  if (coverage.state !== 'complete' || coverage.completeness_ratio !== 1 ||
      coverage.expected_sessions !== coverage.observed_sessions ||
      !coverage.corporate_actions_adjusted ||
      new Set(coverage.required_inputs.map((input) => input.name)).size !== 5 ||
      coverage.required_inputs.some((input) => input.state !== 'available')) return null;
  for (const source of provenance.sources) {
    const observed = Date.parse(source.observed_at);
    const sourceAvailable = Date.parse(source.available_at);
    const retrieved = Date.parse(source.retrieved_at);
    if (!(observed <= cutoff && observed <= sourceAvailable && sourceAvailable <= available &&
          sourceAvailable <= retrieved && retrieved <= generated)) return null;
  }
  const observed = [
    ...snapshot.bars.map((point) => point.observed_at),
    ...snapshot.evidence.map((point) => point.observed_at),
    ...snapshot.panels.implied_volatility.series.map((point) => point.observed_at),
    ...snapshot.panels.sector.series.map((point) => point.observed_at),
    ...coverage.required_inputs.map((point) => point.observed_at),
    snapshot.read.as_of, snapshot.monte_carlo.as_of,
    snapshot.panels.implied_volatility.source_observed_at,
  ];
  if (observed.some((time) => Date.parse(time) > cutoff)) return null;
  if (snapshot.zigzag.confirmed_pivots.some((pivot) =>
    Date.parse(pivot.confirmed_at) <= Date.parse(pivot.observed_at) || Date.parse(pivot.confirmed_at) > cutoff,
  )) return null;
  // A 5-session change needs six consecutive market sessions, not six arbitrary rows.
  const recentDates = snapshot.bars.slice(-6).map((bar) => marketDate.format(new Date(bar.observed_at)));
  for (const series of [snapshot.panels.implied_volatility.series, snapshot.panels.sector.series]) {
    if (series.slice(-6).some((point, index) =>
      marketDate.format(new Date(point.observed_at)) !== recentDates[index])) return null;
  }
  if (marketDate.format(new Date(snapshot.panels.implied_volatility.source_observed_at)) !== recentDates.at(-1)) return null;
  return snapshot;
}

export function validatePublicMarketMapSnapshot(
  raw: unknown,
  request: { symbol?: string; horizon?: MarketMapHorizon; now?: Date } = {},
): PublicMarketMapSnapshot | null {
  const parsed = publicMarketMapSnapshotSchema.safeParse(raw);
  if (!parsed.success) return null;
  const snapshot = parsed.data;
  if ((request.symbol && snapshot.asset.symbol !== request.symbol) || (request.horizon && snapshot.horizon !== request.horizon) ||
      snapshot.monte_carlo.horizon_sessions !== horizonSessions[snapshot.horizon]) return null;
  if (snapshot.asset.symbol === 'DEMO' || snapshot.provenance.sources.some((source) => /synthetic|fixture|example|review/i.test(`${source.provider} ${source.dataset}`))) return null;
  const now = (request.now ?? new Date()).getTime();
  const { provenance } = snapshot;
  const cutoff = Date.parse(provenance.observation_cutoff), generated = Date.parse(provenance.generated_at);
  const available = Date.parse(provenance.available_at), expires = Date.parse(provenance.freshness.expires_at);
  if (!(cutoff <= available && available <= generated && generated <= now && now < expires) ||
      provenance.freshness.state !== 'fresh' || expires > cutoff + provenance.freshness.max_age_seconds * 1000) return null;
  const coverage = provenance.coverage;
  if (coverage.state !== 'complete' || coverage.completeness_ratio !== 1 || coverage.expected_sessions !== snapshot.bars.length ||
      new Set(coverage.required_inputs.map((input) => input.name)).size !== 3 || !coverage.missing_inputs.includes('options_iv') ||
      coverage.regular_session_only !== snapshot.bars.every((bar) => bar.session === 'regular') ||
      coverage.corporate_actions_adjusted !== ['split_adjusted', 'split_dividend_adjusted'].includes(snapshot.price_adjustment) ||
      snapshot.bars.some((bar) => snapshot.calendar === 'continuous' ? bar.session !== 'continuous' : !['regular', 'exchange_daily'].includes(bar.session))) return null;
  for (const source of provenance.sources) {
    const observed = Date.parse(source.observed_at), sourceAvailable = Date.parse(source.available_at), retrieved = Date.parse(source.retrieved_at);
    if (!(observed <= cutoff && observed <= sourceAvailable && sourceAvailable <= available && sourceAvailable <= retrieved && retrieved <= generated)) return null;
  }
  const observedTimes = [snapshot.read.as_of, snapshot.monte_carlo.as_of, ...snapshot.evidence.map((item) => item.observed_at), ...coverage.required_inputs.map((input) => input.observed_at)];
  if (observedTimes.some((time) => Date.parse(time) > cutoff)) return null;
  const expected = snapshot.bars.slice(-6).map((bar) => bar.observed_at);
  if (snapshot.panels.sector.series.slice(-6).some((point, index) => point.observed_at !== expected[index])) return null;
  if (snapshot.zigzag.confirmed_pivots.some((pivot) => Date.parse(pivot.confirmed_at) <= Date.parse(pivot.observed_at) || Date.parse(pivot.confirmed_at) > cutoff)) return null;
  return snapshot;
}

export function validatePublicMarketMapBundle(raw: unknown, now = new Date()): PublicMarketMapBundle | null {
  const parsed = publicMarketMapBundleSchema.safeParse(raw);
  if (!parsed.success) return null;
  const bundle = parsed.data;
  if (Date.parse(bundle.generated_at) > now.getTime() || Date.parse(bundle.expires_at) <= now.getTime() ||
      bundle.snapshots.some((snapshot) => !validatePublicMarketMapSnapshot(snapshot, { now }) ||
        Date.parse(bundle.expires_at) > Date.parse(snapshot.provenance.freshness.expires_at)) ||
      bundle.receipts.some((receipt) => Date.parse(receipt.retrieved_at) > Date.parse(bundle.generated_at))) return null;
  return bundle;
}

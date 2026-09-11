import { z } from "@hono/zod-openapi";

import {
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";

export const marketMapHorizonSchema = z.enum(["5d", "10d", "20d", "60d"]);

const timestampSchema = z.string().datetime({ offset: true });
const finiteSchema = z.number().finite();
const positivePriceSchema = finiteSchema.positive().max(1_000_000_000);
const nonnegativeVolumeSchema = finiteSchema.nonnegative().max(1e18);
const percentSchema = finiteSchema.min(-10_000).max(100_000);
const unitIntervalSchema = finiteSchema.min(0).max(1);
const versionSchema = z.string().min(1).max(128).regex(/^[A-Za-z0-9._:+/-]+$/);
const evidenceIdSchema = z.string().min(1).max(64).regex(/^[a-z0-9][a-z0-9._:-]*$/);

const timeValuePointSchema = z.object({
  observed_at: timestampSchema,
  value: finiteSchema,
}).strict();

const pricePointSchema = z.object({
  observed_at: timestampSchema,
  price: positivePriceSchema,
}).strict();

const marketMapBarSchema = z.object({
  observed_at: timestampSchema,
  open: positivePriceSchema,
  high: positivePriceSchema,
  low: positivePriceSchema,
  close: positivePriceSchema,
  volume: nonnegativeVolumeSchema,
  session: z.literal("regular"),
}).strict().superRefine((bar, context) => {
  if (bar.low > bar.high) {
    context.addIssue({ code: "custom", path: ["low"], message: "low must not exceed high" });
  }
  if (bar.open < bar.low || bar.open > bar.high) {
    context.addIssue({ code: "custom", path: ["open"], message: "open must be inside the bar range" });
  }
  if (bar.close < bar.low || bar.close > bar.high) {
    context.addIssue({ code: "custom", path: ["close"], message: "close must be inside the bar range" });
  }
}).openapi("MarketMapBar");

const bollingerPointSchema = z.object({
  observed_at: timestampSchema,
  lower: positivePriceSchema,
  middle: positivePriceSchema,
  upper: positivePriceSchema,
}).strict().superRefine((point, context) => {
  if (point.lower > point.middle || point.middle > point.upper) {
    context.addIssue({
      code: "custom",
      path: ["middle"],
      message: "Bollinger bands must be ordered lower, middle, upper",
    });
  }
});

const boundedIndicatorSchema = z.object({
  period_sessions: z.number().int().min(2).max(252),
  points: z.array(timeValuePointSchema).min(20).max(756),
}).strict();

const momentumPointSchema = z.object({
  observed_at: timestampSchema,
  value: finiteSchema,
  signal: finiteSchema,
  velocity_percent_per_session: percentSchema,
  acceleration_percent_per_session_squared: percentSchema,
}).strict();

const technicalIndicatorsSchema = z.object({
  sma20: z.object({
    period_sessions: z.literal(20),
    points: z.array(pricePointSchema).min(20).max(756),
  }).strict(),
  bollinger20: z.object({
    period_sessions: z.literal(20),
    standard_deviations: finiteSchema.min(0.5).max(5),
    points: z.array(bollingerPointSchema).min(20).max(756),
  }).strict(),
  rsi14: boundedIndicatorSchema.extend({
    period_sessions: z.literal(14),
    latest: finiteSchema.min(0).max(100),
  }).strict(),
  atr14: boundedIndicatorSchema.extend({
    period_sessions: z.literal(14),
    latest: finiteSchema.nonnegative(),
  }).strict(),
  momentum: z.object({
    lookback_sessions: z.number().int().min(2).max(126),
    signal_sessions: z.number().int().min(2).max(126),
    state: z.enum(["knife", "falling", "flat", "rising", "spike"]),
    points: z.array(momentumPointSchema).min(20).max(756),
  }).strict(),
}).strict().openapi("MarketMapTechnicalIndicators");

const zigZagSchema = z.object({
  reversal_threshold_percent: finiteSchema.positive().max(50),
  confirmed_pivots: z.array(z.object({
    id: evidenceIdSchema,
    observed_at: timestampSchema,
    confirmed_at: timestampSchema,
    price: positivePriceSchema,
    kind: z.enum(["high", "low"]),
    confirmed: z.literal(true),
  }).strict()).max(100),
  provisional_leg: z.object({
    from_observed_at: timestampSchema,
    from_price: positivePriceSchema,
    to_observed_at: timestampSchema,
    to_price: positivePriceSchema,
    direction: z.enum(["up", "down"]),
    confirmed: z.literal(false),
  }).strict().nullable(),
}).strict().openapi("MarketMapZigZag");

const levelRoleSchema = z.enum([
  "stretch",
  "resistance",
  "last",
  "sma20",
  "support",
  "down",
]);

const levelSchema = z.object({
  id: evidenceIdSchema,
  role: levelRoleSchema,
  label: z.string().min(1).max(80),
  price: positivePriceSchema,
  distance_from_last_percent: percentSchema,
  method: z.string().min(1).max(160),
  evidence_refs: z.array(evidenceIdSchema).min(1).max(12),
}).strict();

const scenarioPointSchema = z.object({
  session_offset: z.number().int().min(0).max(252),
  projected_at: timestampSchema,
  price: positivePriceSchema,
}).strict();

const scenarioCurveSchema = z.object({
  id: evidenceIdSchema,
  kind: z.enum(["bull", "base", "bear"]),
  label: z.string().min(1).max(80),
  interpretation: z.string().min(1).max(500),
  is_forecast: z.literal(false),
  points: z.array(scenarioPointSchema).min(2).max(253),
  evidence_refs: z.array(evidenceIdSchema).min(1).max(12),
}).strict();

const simulationPathSchema = z.object({
  sample_id: z.number().int().nonnegative().max(1_000_000),
  points: z.array(scenarioPointSchema).min(2).max(253),
}).strict();

const terminalParticleSchema = z.object({
  sample_id: z.number().int().nonnegative().max(1_000_000),
  terminal_price: positivePriceSchema,
  terminal_return_percent: percentSchema,
}).strict();

const terminalDensityBinSchema = z.object({
  lower_price: positivePriceSchema,
  upper_price: positivePriceSchema,
  sample_count: z.number().int().nonnegative().max(1_000_000),
  probability_mass: unitIntervalSchema,
  density: finiteSchema.nonnegative().max(1e9),
}).strict().superRefine((bin, context) => {
  if (bin.lower_price >= bin.upper_price) {
    context.addIssue({
      code: "custom",
      path: ["upper_price"],
      message: "density bin upper price must exceed lower price",
    });
  }
});

const monteCarloQuantilesSchema = z.object({
  p01: positivePriceSchema,
  p05: positivePriceSchema,
  p25: positivePriceSchema,
  p50: positivePriceSchema,
  p75: positivePriceSchema,
  p95: positivePriceSchema,
  p99: positivePriceSchema,
}).strict().superRefine((quantiles, context) => {
  const ordered = [
    quantiles.p01,
    quantiles.p05,
    quantiles.p25,
    quantiles.p50,
    quantiles.p75,
    quantiles.p95,
    quantiles.p99,
  ];
  if (ordered.some((value, index) => index > 0 && value < ordered[index - 1]!)) {
    context.addIssue({
      code: "custom",
      message: "Monte Carlo quantiles must be nondecreasing",
    });
  }
});

const monteCarloSchema = z.object({
  as_of: timestampSchema,
  horizon_sessions: z.number().int().min(1).max(252),
  trial_count: z.number().int().min(5_000).max(1_000_000),
  input_sha256: z.string().regex(/^[a-f0-9]{64}$/),
  seed_sha256: z.string().regex(/^[a-f0-9]{64}$/),
  model: z.literal("historical_block_bootstrap"),
  calibration_status: z.literal("uncalibrated"),
  sample_window_sessions: z.number().int().min(60).max(756),
  block_length_sessions: z.number().int().min(1).max(60),
  return_basis: z.literal("log_close_to_close"),
  path_sampling_method: z.literal("deterministic_stratified"),
  sampled_paths: z.array(simulationPathSchema).min(8).max(64),
  terminal_particles: z.array(terminalParticleSchema).min(128).max(2_048),
  terminal_density: z.array(terminalDensityBinSchema).min(8).max(128),
  terminal_quantiles: monteCarloQuantilesSchema,
  assumptions: z.array(z.string().min(1).max(500)).min(1).max(20),
  evidence_refs: z.array(evidenceIdSchema).min(1).max(20),
  interpretation: z.literal("uncalibrated_simulation_not_forecast"),
}).strict().openapi("MarketMapMonteCarlo");

const volumePanelSchema = z.object({
  latest_volume: nonnegativeVolumeSchema,
  average_volume: nonnegativeVolumeSchema,
  average_window_sessions: z.number().int().min(2).max(252),
  relative_volume: finiteSchema.nonnegative().max(1_000),
  series: z.array(z.object({
    observed_at: timestampSchema,
    volume: nonnegativeVolumeSchema,
  }).strict()).min(10).max(252),
  volume_at_price: z.object({
    method: z.literal("observed_trade_volume"),
    source_id: evidenceIdSchema,
    bins: z.array(z.object({
    lower_price: positivePriceSchema,
    upper_price: positivePriceSchema,
    volume: nonnegativeVolumeSchema,
    recent_volume: nonnegativeVolumeSchema,
    side: z.enum(["supply", "demand", "at_last"]),
    }).strict()).min(8).max(128),
    point_of_control_price: positivePriceSchema,
  }).strict().optional(),
  evidence_refs: z.array(evidenceIdSchema).min(1).max(12),
}).strict().openapi("MarketMapVolumePanel");

const impliedVolatilityPanelSchema = z.object({
  source_observed_at: timestampSchema,
  tenor_days: z.number().int().min(1).max(730),
  moneyness: z.literal("atm"),
  current_percent: finiteSchema.nonnegative().max(1_000),
  change_5d_percentage_points: percentSchema,
  series: z.array(z.object({
    observed_at: timestampSchema,
    percent: finiteSchema.nonnegative().max(1_000),
  }).strict()).min(6).max(252),
  evidence_refs: z.array(evidenceIdSchema).min(1).max(12),
}).strict().openapi("MarketMapImpliedVolatilityPanel");

const sectorPanelSchema = z.object({
  sector_id: z.string().min(1).max(64).regex(/^[a-z0-9][a-z0-9._-]*$/),
  sector_name: z.string().min(1).max(120),
  benchmark_symbol: z.string().min(1).max(32).regex(/^[A-Z0-9.^/-]+$/),
  return_5d_percent: percentSchema,
  asset_relative_5d_percent: percentSchema,
  state: z.enum(["defensive", "neutral", "offensive"]),
  series: z.array(timeValuePointSchema).min(6).max(252),
  evidence_refs: z.array(evidenceIdSchema).min(1).max(12),
}).strict().openapi("MarketMapSectorPanel");

const evidenceSchema = z.object({
  id: evidenceIdSchema,
  kind: z.enum([
    "bar",
    "indicator",
    "pivot",
    "level",
    "simulation",
    "volume",
    "options",
    "sector",
  ]),
  label: z.string().min(1).max(160),
  source_id: evidenceIdSchema,
  observed_at: timestampSchema,
  field_path: z.string().min(1).max(240).regex(/^[a-z0-9_.:[\]-]+$/),
}).strict();

const marketReadSchema = z.object({
  as_of: timestampSchema,
  language: z.string().min(2).max(35).regex(/^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$/),
  title: z.string().min(1).max(120),
  summary: z.string().min(1).max(1_000),
  items: z.array(z.object({
    id: evidenceIdSchema,
    kind: z.enum([
      "range",
      "trend",
      "momentum",
      "volatility",
      "volume",
      "sector",
      "simulation",
      "limitation",
    ]),
    text: z.string().min(1).max(1_000),
    evidence_refs: z.array(evidenceIdSchema).min(1).max(20),
  }).strict()).min(3).max(12),
  disclosure: z.string().min(40).max(1_000),
}).strict().openapi("MarketMapRead");

const requiredInputSchema = z.object({
  name: z.enum([
    "ohlcv",
    "corporate_actions",
    "options_iv",
    "sector_benchmark",
    "simulation_artifact",
  ]),
  state: z.enum(["available", "missing", "stale", "partial", "unentitled"]),
  observed_at: timestampSchema,
}).strict();

const sourceSchema = z.object({
  id: evidenceIdSchema,
  provider: z.string().min(1).max(120),
  dataset: z.string().min(1).max(160),
  observed_at: timestampSchema,
  available_at: timestampSchema,
  retrieved_at: timestampSchema,
  delay_minutes: z.number().int().min(0).max(10_080),
}).strict();

const provenanceSchema = z.object({
  sources: z.array(sourceSchema).min(3).max(20),
  observation_cutoff: timestampSchema,
  available_at: timestampSchema,
  generated_at: timestampSchema,
  freshness: z.object({
    state: z.enum(["fresh", "stale", "expired"]),
    max_age_seconds: z.number().int().positive().max(604_800),
    expires_at: timestampSchema,
  }).strict(),
  coverage: z.object({
    state: z.enum(["complete", "partial", "insufficient"]),
    completeness_ratio: unitIntervalSchema,
    start_at: timestampSchema,
    end_at: timestampSchema,
    expected_sessions: z.number().int().min(60).max(756),
    observed_sessions: z.number().int().min(0).max(756),
    required_inputs: z.array(requiredInputSchema).length(5),
    regular_session_only: z.literal(true),
    corporate_actions_adjusted: z.boolean(),
  }).strict(),
  rights: z.object({
    entitlement: z.enum(["member_research", "none"]),
    display_authorized: z.boolean(),
    redistribution_authorized: z.literal(false),
  }).strict(),
  versions: z.object({
    schema: z.literal("market-map-snapshot-v1"),
    market_data: versionSchema,
    features: versionSchema,
    monte_carlo_model: versionSchema,
    methodology: versionSchema,
  }).strict(),
  caveats: z.array(z.string().min(1).max(500)).min(2).max(20),
}).strict().openapi("MarketMapProvenance");

function addUniqueIssue(
  values: readonly string[],
  path: readonly (string | number)[],
  context: z.core.$RefinementCtx<unknown>,
): void {
  if (new Set(values).size !== values.length) {
    context.addIssue({ code: "custom", path: [...path], message: "values must be unique" });
  }
}

function addStrictlyIncreasingTimeIssue(
  points: readonly Readonly<{ observed_at: string }>[],
  path: readonly (string | number)[],
  context: z.core.$RefinementCtx<unknown>,
): void {
  if (points.some((point, index) =>
    index > 0 && Date.parse(point.observed_at) <= Date.parse(points[index - 1]!.observed_at)
  )) {
    context.addIssue({
      code: "custom",
      path: [...path],
      message: "observations must be strictly time ordered",
    });
  }
}

export const marketMapSnapshotSchema = z.object({
  snapshot_id: uuidSchema,
  asset: z.object({
    asset_id: uuidSchema,
    symbol: z.string().min(1).max(32).regex(/^[A-Z0-9.^/-]+$/),
    name: z.string().min(1).max(160),
    asset_type: z.enum(["equity", "etf", "market_index"]),
    exchange: z.string().min(1).max(64),
    currency: z.string().regex(/^[A-Z]{3}$/),
    market_timezone: z.string().min(1).max(64),
  }).strict(),
  horizon: marketMapHorizonSchema,
  timeframe: z.literal("1d"),
  state: z.enum(["bull", "neutral", "bear"]),
  last_price: positivePriceSchema,
  bars: z.array(marketMapBarSchema).min(60).max(756),
  technical_indicators: technicalIndicatorsSchema,
  zigzag: zigZagSchema,
  levels: z.array(levelSchema).length(6),
  scenarios: z.array(scenarioCurveSchema).length(3),
  monte_carlo: monteCarloSchema,
  panels: z.object({
    volume: volumePanelSchema,
    implied_volatility: impliedVolatilityPanelSchema,
    sector: sectorPanelSchema,
  }).strict(),
  evidence: z.array(evidenceSchema).min(8).max(256),
  read: marketReadSchema,
  provenance: provenanceSchema,
}).strict().superRefine((snapshot, context) => {
  const issue = (path: (string | number)[], message: string) =>
    context.addIssue({ code: "custom", path, message });
  addStrictlyIncreasingTimeIssue(snapshot.bars, ["bars"], context);
  for (const [name, points] of Object.entries({
    volume: snapshot.panels.volume.series,
    implied_volatility: snapshot.panels.implied_volatility.series,
    sector: snapshot.panels.sector.series,
  })) addStrictlyIncreasingTimeIssue(points, ["panels", name, "series"], context);
  addStrictlyIncreasingTimeIssue(snapshot.zigzag.confirmed_pivots, ["zigzag", "confirmed_pivots"], context);
  addStrictlyIncreasingTimeIssue(
    snapshot.technical_indicators.sma20.points,
    ["technical_indicators", "sma20", "points"],
    context,
  );
  addStrictlyIncreasingTimeIssue(
    snapshot.technical_indicators.bollinger20.points,
    ["technical_indicators", "bollinger20", "points"],
    context,
  );
  addStrictlyIncreasingTimeIssue(
    snapshot.technical_indicators.rsi14.points,
    ["technical_indicators", "rsi14", "points"],
    context,
  );
  addStrictlyIncreasingTimeIssue(
    snapshot.technical_indicators.atr14.points,
    ["technical_indicators", "atr14", "points"],
    context,
  );
  addStrictlyIncreasingTimeIssue(
    snapshot.technical_indicators.momentum.points,
    ["technical_indicators", "momentum", "points"],
    context,
  );

  const barTimes = new Set(snapshot.bars.map((bar) => bar.observed_at));
  const lastBar = snapshot.bars.at(-1)!;
  if (snapshot.last_price !== lastBar.close) issue(["last_price"], "last price must match the latest completed close");
  if (snapshot.provenance.coverage.start_at !== snapshot.bars[0]!.observed_at ||
    snapshot.provenance.coverage.end_at !== lastBar.observed_at) {
    issue(["provenance", "coverage"], "coverage dates must match the returned session window");
  }
  for (const [name, points] of Object.entries({
    sma20: snapshot.technical_indicators.sma20.points,
    bollinger20: snapshot.technical_indicators.bollinger20.points,
    rsi14: snapshot.technical_indicators.rsi14.points,
    atr14: snapshot.technical_indicators.atr14.points,
    momentum: snapshot.technical_indicators.momentum.points,
  })) {
    if (points.some((point) => !barTimes.has(point.observed_at))) {
      context.addIssue({
        code: "custom",
        path: ["technical_indicators", name, "points"],
        message: "indicator observations must reference returned bars",
      });
    }
    if (points.at(-1)?.observed_at !== lastBar.observed_at) {
      issue(["technical_indicators", name, "points"], "indicator must reach the latest completed session");
    }
  }
  for (const point of snapshot.technical_indicators.rsi14.points) {
    if (point.value < 0 || point.value > 100) issue(["technical_indicators", "rsi14"], "RSI must stay within zero and 100");
  }
  if (snapshot.technical_indicators.atr14.points.some((point) => point.value < 0)) {
    issue(["technical_indicators", "atr14"], "ATR cannot be negative");
  }
  if (snapshot.technical_indicators.rsi14.latest !== snapshot.technical_indicators.rsi14.points.at(-1)?.value ||
    snapshot.technical_indicators.atr14.latest !== snapshot.technical_indicators.atr14.points.at(-1)?.value) {
    issue(["technical_indicators"], "latest indicator values must match their series");
  }
  if (snapshot.panels.volume.latest_volume !== lastBar.volume ||
    snapshot.panels.volume.series.at(-1)?.volume !== lastBar.volume ||
    snapshot.panels.volume.series.at(-1)?.observed_at !== lastBar.observed_at) {
    issue(["panels", "volume"], "volume panel must match the latest completed bar");
  }
  if (snapshot.panels.implied_volatility.current_percent !== snapshot.panels.implied_volatility.series.at(-1)?.percent ||
    snapshot.panels.implied_volatility.source_observed_at !== snapshot.panels.implied_volatility.series.at(-1)?.observed_at) {
    issue(["panels", "implied_volatility"], "current IV must match its latest observation");
  }

  addUniqueIssue(snapshot.levels.map((level) => level.role), ["levels"], context);
  if (new Set(snapshot.levels.map((level) => level.role)).size === 6) {
    const priceByRole = Object.fromEntries(
      snapshot.levels.map((level) => [level.role, level.price]),
    ) as Record<z.infer<typeof levelRoleSchema>, number>;
    if (!(priceByRole.stretch >= priceByRole.resistance &&
      priceByRole.resistance >= priceByRole.last &&
      priceByRole.last >= priceByRole.support &&
      priceByRole.support >= priceByRole.down)) {
      context.addIssue({
        code: "custom",
        path: ["levels"],
        message: "market levels must be ordered around last price",
      });
    }
  }
  addUniqueIssue(snapshot.scenarios.map((scenario) => scenario.kind), ["scenarios"], context);
  addUniqueIssue(snapshot.provenance.sources.map((source) => source.id), ["provenance", "sources"], context);
  addUniqueIssue(snapshot.read.items.map((item) => item.id), ["read", "items"], context);
  addUniqueIssue(snapshot.evidence.map((evidence) => evidence.id), ["evidence"], context);
  addUniqueIssue(
    snapshot.zigzag.confirmed_pivots.map((pivot) => pivot.id),
    ["zigzag", "confirmed_pivots"],
    context,
  );

  const evidenceIds = new Set(snapshot.evidence.map((evidence) => evidence.id));
  const sourceIds = new Set(snapshot.provenance.sources.map((source) => source.id));
  if (snapshot.evidence.some((evidence) => !sourceIds.has(evidence.source_id))) {
    issue(["evidence"], "every evidence source must resolve inside provenance");
  }
  for (const evidence of snapshot.evidence) {
    const parts = evidence.field_path.replace(/\[(\d+)\]/g, ".$1").split(".");
    let current: unknown = snapshot;
    for (const part of parts) {
      if (current === null || typeof current !== "object" ||
        !Object.prototype.hasOwnProperty.call(current, part)) { current = undefined; break; }
      current = (current as Record<string, unknown>)[part];
    }
    if (current === undefined) issue(["evidence"], "evidence field path must resolve inside the snapshot");
  }
  const referencedEvidence = [
    ...snapshot.levels.flatMap((level) => level.evidence_refs),
    ...snapshot.scenarios.flatMap((scenario) => scenario.evidence_refs),
    ...snapshot.monte_carlo.evidence_refs,
    ...snapshot.panels.volume.evidence_refs,
    ...snapshot.panels.implied_volatility.evidence_refs,
    ...snapshot.panels.sector.evidence_refs,
    ...snapshot.read.items.flatMap((item) => item.evidence_refs),
  ];
  if (referencedEvidence.some((reference) => !evidenceIds.has(reference))) {
    context.addIssue({
      code: "custom",
      path: ["evidence"],
      message: "every evidence reference must resolve inside this snapshot",
    });
  }

  const density = snapshot.monte_carlo.terminal_density;
  const simulation = snapshot.monte_carlo;
  if (density.reduce((sum, bin) => sum + bin.sample_count, 0) !== simulation.trial_count) {
    issue(["monte_carlo", "terminal_density"], "density must account for every simulation trial");
  }
  if (simulation.sample_window_sessions > snapshot.bars.length ||
    simulation.block_length_sessions > simulation.sample_window_sessions) {
    issue(["monte_carlo"], "simulation sample window must fit the returned history");
  }
  for (const [name, paths] of Object.entries({ sampled_paths: simulation.sampled_paths, scenarios: snapshot.scenarios })) {
    for (const path of paths) {
      if (path.points.length !== simulation.horizon_sessions + 1 ||
        path.points[0]!.price !== snapshot.last_price ||
        Date.parse(path.points[0]!.projected_at) !== Date.parse(lastBar.observed_at) ||
        path.points.some((point, index) => point.session_offset !== index ||
          (index > 0 && Date.parse(point.projected_at) <= Date.parse(path.points[index - 1]!.projected_at)))) {
        issue(["monte_carlo", name], "paths must start at the latest close and cover the ordered session horizon");
      }
    }
  }
  for (const [name, samples] of Object.entries({ sampled_paths: simulation.sampled_paths, terminal_particles: simulation.terminal_particles })) {
    if (new Set(samples.map((sample) => sample.sample_id)).size !== samples.length ||
      samples.some((sample) => sample.sample_id >= simulation.trial_count)) {
      issue(["monte_carlo", name], "sample ids must be unique and inside trial count");
    }
  }
  if (density.some((bin, index) =>
    index > 0 && bin.lower_price < density[index - 1]!.upper_price
  )) {
    context.addIssue({
      code: "custom",
      path: ["monte_carlo", "terminal_density"],
      message: "terminal density bins must be ordered and non-overlapping",
    });
  }
  const probabilityMass = density.reduce((sum, bin) => sum + bin.probability_mass, 0);
  if (Math.abs(probabilityMass - 1) > 0.001) {
    context.addIssue({
      code: "custom",
      path: ["monte_carlo", "terminal_density"],
      message: "terminal density probability mass must sum to one",
    });
  }

  const pivotKinds = snapshot.zigzag.confirmed_pivots.map((pivot) => pivot.kind);
  if (snapshot.zigzag.confirmed_pivots.some((pivot) =>
    !barTimes.has(pivot.observed_at) || !barTimes.has(pivot.confirmed_at))) {
    issue(["zigzag"], "pivots and confirmations must reference completed bars");
  }
  const leg = snapshot.zigzag.provisional_leg;
  if (leg !== null && (!barTimes.has(leg.from_observed_at) ||
    leg.to_observed_at !== lastBar.observed_at || leg.to_price !== lastBar.close ||
    Date.parse(leg.from_observed_at) > Date.parse(leg.to_observed_at))) {
    issue(["zigzag", "provisional_leg"], "provisional leg must end at the latest completed close");
  }
  const tradedVolume = snapshot.panels.volume.volume_at_price;
  if (tradedVolume !== undefined && (!sourceIds.has(tradedVolume.source_id) ||
    tradedVolume.bins.some((bin, index) => bin.lower_price >= bin.upper_price ||
      bin.recent_volume > bin.volume || (index > 0 && bin.lower_price < tradedVolume.bins[index - 1]!.upper_price)))) {
    issue(["panels", "volume", "volume_at_price"], "observed volume profile must have an identified source and ordered valid bins");
  }
  if (pivotKinds.some((kind, index) => index > 0 && kind === pivotKinds[index - 1])) {
    context.addIssue({
      code: "custom",
      path: ["zigzag", "confirmed_pivots"],
      message: "confirmed ZigZag pivots must alternate high and low",
    });
  }

  if (snapshot.provenance.coverage.observed_sessions !== snapshot.bars.length) {
    context.addIssue({
      code: "custom",
      path: ["provenance", "coverage", "observed_sessions"],
      message: "observed session count must match returned bars",
    });
  }
}).openapi("MarketMapSnapshot");

export const marketMapSnapshotResponseSchema = retainedEnvelope(
  "MarketMapSnapshotResponse",
  marketMapSnapshotSchema,
);

export type MarketMapHorizon = z.infer<typeof marketMapHorizonSchema>;
export type MarketMapSnapshot = Readonly<z.infer<typeof marketMapSnapshotSchema>>;

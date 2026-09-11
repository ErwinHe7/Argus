import { ZodError } from "zod";

import {
  marketMapSnapshotSchema,
  type MarketMapHorizon,
  type MarketMapSnapshot,
} from "./schemas.ts";
import {
  MarketMapError,
  type MarketMapProvider,
  type MarketMapProviderRequest,
  type MarketMapService,
} from "./ports.ts";

const horizonSessions: Readonly<Record<MarketMapHorizon, number>> = Object.freeze({
  "5d": 5,
  "10d": 10,
  "20d": 20,
  "60d": 60,
});

const prohibitedMarketReadLanguage =
  /\b(?:buy|sell|hold|enter|entry|exit|trade\s+now|take\s+profit|stop[-\s]?loss|guarantee(?:d)?|risk[-\s]?free|sure\s+bet|can(?:not|'t)\s+lose|must|should|recommend(?:ed|ation)?|overweight|underweight)\b/i;

const placeholderLanguage = /^(?:n\/?a|not available|unavailable|unknown|--|-)$/i;

function milliseconds(value: string): number {
  return Date.parse(value);
}

function deepFreeze<T>(value: T, visited = new WeakSet<object>()): T {
  if (value === null || typeof value !== "object") return value;
  const objectValue = value as object;
  if (visited.has(objectValue)) return value;
  visited.add(objectValue);
  for (const child of Object.values(objectValue)) deepFreeze(child, visited);
  return Object.freeze(value);
}

function validateTemporalAuthority(
  snapshot: MarketMapSnapshot,
  now: Date,
  maximumClockSkewMilliseconds: number,
): void {
  const current = now.getTime();
  const cutoff = milliseconds(snapshot.provenance.observation_cutoff);
  const available = milliseconds(snapshot.provenance.available_at);
  const generated = milliseconds(snapshot.provenance.generated_at);
  const expires = milliseconds(snapshot.provenance.freshness.expires_at);

  if (cutoff > current + maximumClockSkewMilliseconds ||
    generated > current + maximumClockSkewMilliseconds) {
    throw new MarketMapError("market_map_noncausal_snapshot");
  }
  if (available > current + maximumClockSkewMilliseconds) {
    throw new MarketMapError("market_map_snapshot_not_yet_available");
  }
  if (snapshot.provenance.freshness.state !== "fresh" || expires <= current) {
    throw new MarketMapError("market_map_snapshot_expired");
  }
  if (expires > cutoff + snapshot.provenance.freshness.max_age_seconds * 1_000 ||
    current - cutoff > snapshot.provenance.freshness.max_age_seconds * 1_000) {
    throw new MarketMapError("market_map_snapshot_expired");
  }
  if (!(cutoff <= available && available <= generated && generated < expires)) {
    throw new MarketMapError("market_map_noncausal_snapshot");
  }

  for (const source of snapshot.provenance.sources) {
    const sourceObserved = milliseconds(source.observed_at);
    const sourceAvailable = milliseconds(source.available_at);
    const retrieved = milliseconds(source.retrieved_at);
    if (sourceObserved > cutoff || sourceAvailable > available ||
      sourceObserved > sourceAvailable || sourceAvailable > retrieved ||
      retrieved > generated) {
      throw new MarketMapError("market_map_noncausal_snapshot");
    }
  }

  if (milliseconds(snapshot.read.as_of) > cutoff ||
    milliseconds(snapshot.monte_carlo.as_of) > cutoff) {
    throw new MarketMapError("market_map_noncausal_snapshot");
  }
  const observedTimes = [
    ...snapshot.bars.map((value) => value.observed_at),
    ...snapshot.panels.implied_volatility.series.map((value) => value.observed_at),
    ...snapshot.panels.sector.series.map((value) => value.observed_at),
    ...snapshot.panels.volume.series.map((value) => value.observed_at),
    ...snapshot.evidence.map((value) => value.observed_at),
    ...snapshot.provenance.coverage.required_inputs.map((value) => value.observed_at),
    snapshot.panels.implied_volatility.source_observed_at,
    snapshot.provenance.coverage.end_at,
  ];
  if (observedTimes.some((time) => milliseconds(time) > cutoff)) {
    throw new MarketMapError("market_map_noncausal_snapshot");
  }
  for (const pivot of snapshot.zigzag.confirmed_pivots) {
    if (milliseconds(pivot.confirmed_at) <= milliseconds(pivot.observed_at) ||
      milliseconds(pivot.confirmed_at) > cutoff) {
      throw new MarketMapError("market_map_noncausal_snapshot");
    }
  }
}

function validateCoverage(snapshot: MarketMapSnapshot): void {
  const coverage = snapshot.provenance.coverage;
  if (coverage.state !== "complete" || coverage.completeness_ratio !== 1 ||
    coverage.observed_sessions !== coverage.expected_sessions ||
    !coverage.corporate_actions_adjusted ||
    new Set(coverage.required_inputs.map((value) => value.name)).size !== 5) {
    throw new MarketMapError("market_map_coverage_incomplete");
  }
  if (coverage.required_inputs.some((input) => input.state !== "available")) {
    throw new MarketMapError("market_map_required_input_incomplete");
  }
}

function validateRights(snapshot: MarketMapSnapshot): void {
  const rights = snapshot.provenance.rights;
  if (rights.entitlement !== "member_research" || !rights.display_authorized) {
    throw new MarketMapError("market_map_not_entitled");
  }
}

function validateMarketRead(snapshot: MarketMapSnapshot): void {
  const readStrings = [
    snapshot.read.title,
    snapshot.read.summary,
    snapshot.read.disclosure,
    ...snapshot.read.items.map((item) => item.text),
  ];
  if (readStrings.some((value) =>
    prohibitedMarketReadLanguage.test(value) || placeholderLanguage.test(value.trim())
  )) {
    throw new MarketMapError("market_map_content_policy_violation");
  }
}

function validateRequestIdentity(
  snapshot: MarketMapSnapshot,
  request: MarketMapProviderRequest,
): void {
  if ((request.assetId !== undefined && snapshot.asset.asset_id !== request.assetId) ||
    snapshot.horizon !== request.horizon ||
    snapshot.monte_carlo.horizon_sessions !== horizonSessions[request.horizon]) {
    throw new MarketMapError("market_map_request_mismatch");
  }
}

export function createMarketMapService(input: Readonly<{
  provider: MarketMapProvider;
  clock?: () => Date;
  maximumClockSkewMilliseconds?: number;
}>): MarketMapService {
  const clock = input.clock ?? (() => new Date());
  const maximumClockSkewMilliseconds = input.maximumClockSkewMilliseconds ?? 0;
  if (!Number.isInteger(maximumClockSkewMilliseconds) ||
    maximumClockSkewMilliseconds < 0 || maximumClockSkewMilliseconds > 300_000) {
    throw new Error("invalid_market_map_clock_skew");
  }

  return Object.freeze({
    async read(request: MarketMapProviderRequest): Promise<MarketMapSnapshot> {
      let raw: unknown;
      try {
        raw = await input.provider.read(request);
      } catch (error) {
        if (error instanceof MarketMapError) throw error;
        throw new MarketMapError("market_map_provider_unavailable");
      }

      let snapshot: MarketMapSnapshot;
      try {
        snapshot = marketMapSnapshotSchema.parse(raw);
      } catch (error) {
        if (error instanceof ZodError) {
          throw new MarketMapError("market_map_contract_invalid");
        }
        throw error;
      }

      validateRequestIdentity(snapshot, request);
      validateRights(snapshot);
      validateCoverage(snapshot);
      validateTemporalAuthority(
        snapshot,
        clock(),
        maximumClockSkewMilliseconds,
      );
      validateMarketRead(snapshot);
      return deepFreeze(snapshot);
    },
  });
}

export function createBlockedMarketMapProvider(): MarketMapProvider {
  return Object.freeze({
    read: async () => {
      throw new MarketMapError("market_map_provider_blocked");
    },
  });
}

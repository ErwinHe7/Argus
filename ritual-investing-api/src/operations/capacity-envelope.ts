export type CapacityProfile = {
  name:
    | "public-cache-hit"
    | "public-cache-miss"
    | "authenticated-read"
    | "command";
  path: string;
  method: "GET" | "POST";
  p95_limit_ms: number;
  concurrency: number;
  requests: number;
  duration_seconds: number;
};

export type CapacityEnvelope = {
  duration_seconds: number;
  concurrent_public_visitors: number;
  concurrent_authenticated_members: number;
  tenant_cardinality: number;
  ledger_transactions_per_tenant: number;
  public_cache_hit_ratio: number;
  command_same_portfolio_contention: number;
  queue_backlog_messages: number;
  queue_consumer_concurrency: number;
  target_requests_per_second: number;
  maximum_queue_drain_seconds: number;
  maximum_queue_lag_seconds: number;
  request_mix_percent: Readonly<Record<CapacityProfile["name"], number>>;
  maximum_error_ratio: number;
};

export const RELEASE_CAPACITY_ENVELOPE: CapacityEnvelope = {
  duration_seconds: 600,
  concurrent_public_visitors: 250,
  concurrent_authenticated_members: 100,
  tenant_cardinality: 1_000,
  ledger_transactions_per_tenant: 10_000,
  public_cache_hit_ratio: 0.9,
  command_same_portfolio_contention: 4,
  queue_backlog_messages: 10_000,
  queue_consumer_concurrency: 20,
  target_requests_per_second: 100,
  maximum_queue_drain_seconds: 900,
  maximum_queue_lag_seconds: 300,
  request_mix_percent: {
    "public-cache-hit": 45,
    "public-cache-miss": 5,
    "authenticated-read": 40,
    command: 10,
  },
  maximum_error_ratio: 0,
};

export function deriveCapacityProfiles(
  envelope: CapacityEnvelope = RELEASE_CAPACITY_ENVELOPE,
): readonly CapacityProfile[] {
  const requests = (name: CapacityProfile["name"]) =>
    Math.max(
      1,
      Math.round(
        envelope.duration_seconds *
          envelope.target_requests_per_second *
          (envelope.request_mix_percent[name] / 100),
      ),
    );
  return [
    {
      name: "public-cache-hit",
      path: "/v1/public/rituals/daily",
      method: "GET",
      p95_limit_ms: 100,
      concurrency: Math.max(
        1,
        Math.round(
          envelope.concurrent_public_visitors * envelope.public_cache_hit_ratio,
        ),
      ),
      requests: requests("public-cache-hit"),
      duration_seconds: envelope.duration_seconds,
    },
    {
      name: "public-cache-miss",
      path: "/v1/public/rituals/daily",
      method: "GET",
      p95_limit_ms: 250,
      concurrency: Math.max(
        1,
        Math.round(
          envelope.concurrent_public_visitors *
            (1 - envelope.public_cache_hit_ratio),
        ),
      ),
      requests: requests("public-cache-miss"),
      duration_seconds: envelope.duration_seconds,
    },
    {
      name: "authenticated-read",
      path: "/v1/portfolios",
      method: "GET",
      p95_limit_ms: 400,
      concurrency: envelope.concurrent_authenticated_members,
      requests: requests("authenticated-read"),
      duration_seconds: envelope.duration_seconds,
    },
    {
      name: "command",
      path: "/v1/portfolios/{portfolio_id}/contributions",
      method: "POST",
      p95_limit_ms: 1_000,
      concurrency: envelope.command_same_portfolio_contention,
      requests: requests("command"),
      duration_seconds: envelope.duration_seconds,
    },
  ];
}

export function assertCapacityConfiguration(
  envelope: CapacityEnvelope = RELEASE_CAPACITY_ENVELOPE,
): void {
  const mix = Object.values(envelope.request_mix_percent).reduce(
    (sum, value) => sum + value,
    0,
  );
  if (mix !== 100) throw new Error("capacity request mix must total 100%");
  if (envelope.duration_seconds < 300)
    throw new Error("capacity duration must cover at least five minutes");
  for (const [name, value] of Object.entries(envelope)) {
    if (name === "request_mix_percent" || name === "maximum_error_ratio")
      continue;
    if (typeof value !== "number" || value <= 0)
      throw new Error(`${name} must be positive`);
  }
  if (
    envelope.public_cache_hit_ratio < 0 ||
    envelope.public_cache_hit_ratio > 1 ||
    envelope.maximum_error_ratio < 0 ||
    envelope.maximum_error_ratio > 1
  ) {
    throw new Error("capacity ratios must be between zero and one");
  }
}

export const CAPACITY_PROFILES: readonly CapacityProfile[] = [
  ...deriveCapacityProfiles(),
];

export type CapacityFixtureObservation = {
  tenant_cardinality: number;
  minimum_ledger_depth: number;
  queue_backlog_seeded: number;
  queue_consumer_concurrency: number;
  queue_drain_seconds: number;
  queue_p95_lag_seconds: number;
};

export function assertCapacityFixture(
  observation: CapacityFixtureObservation,
  envelope: CapacityEnvelope = RELEASE_CAPACITY_ENVELOPE,
): void {
  const minimums: Array<[keyof CapacityFixtureObservation, number]> = [
    ["tenant_cardinality", envelope.tenant_cardinality],
    ["minimum_ledger_depth", envelope.ledger_transactions_per_tenant],
    ["queue_backlog_seeded", envelope.queue_backlog_messages],
    ["queue_consumer_concurrency", envelope.queue_consumer_concurrency],
  ];
  for (const [name, minimum] of minimums) {
    if (!Number.isInteger(observation[name]) || observation[name] < minimum)
      throw new Error(`${name} did not meet the seeded capacity fixture`);
  }
  if (observation.queue_drain_seconds > envelope.maximum_queue_drain_seconds)
    throw new Error("queue backlog exceeded the drain-time envelope");
  if (observation.queue_p95_lag_seconds > envelope.maximum_queue_lag_seconds)
    throw new Error("queue backlog exceeded the p95 lag envelope");
}

export type CapacityResult = CapacityProfile & {
  p50_ms: number;
  p95_ms: number;
  p99_ms: number;
  maximum_ms: number;
  successful_requests: number;
  failed_requests: number;
};

export type CapacityAdapter = {
  now: () => number;
  wait?: (milliseconds: number) => Promise<void>;
  request: (
    profile: CapacityProfile,
    ordinal: number,
  ) => Promise<{ status: number }>;
};

function percentile(values: number[], quantile: number) {
  const index = Math.max(0, Math.ceil(values.length * quantile) - 1);
  return values[index]!;
}

export async function runCapacityProfile(
  profile: CapacityProfile,
  adapter: CapacityAdapter,
): Promise<CapacityResult> {
  const durations: number[] = [];
  const profileStartedAt = adapter.now();
  for (
    let offset = 0;
    offset < profile.requests;
    offset += profile.concurrency
  ) {
    const batchSize = Math.min(profile.concurrency, profile.requests - offset);
    const batch = Array.from({ length: batchSize }, async (_, index) => {
      const startedAt = adapter.now();
      const response = await adapter.request(profile, offset + index);
      const duration = Math.max(0, adapter.now() - startedAt);
      if (response.status < 200 || response.status >= 400)
        throw new Error(`${profile.name} returned status ${response.status}`);
      return duration;
    });
    durations.push(...(await Promise.all(batch)));
    if (adapter.wait !== undefined) {
      const expectedElapsed =
        ((offset + batchSize) / profile.requests) *
        profile.duration_seconds *
        1_000;
      const observedElapsed = adapter.now() - profileStartedAt;
      const delay = Math.max(0, expectedElapsed - observedElapsed);
      if (delay > 0) await adapter.wait(delay);
    }
  }
  durations.sort((left, right) => left - right);
  return {
    ...profile,
    p50_ms: percentile(durations, 0.5),
    p95_ms: percentile(durations, 0.95),
    p99_ms: percentile(durations, 0.99),
    maximum_ms: durations.at(-1)!,
    successful_requests: durations.length,
    failed_requests: 0,
  };
}

export function assertCapacityEnvelope(result: CapacityResult): void {
  if (result.successful_requests !== result.requests)
    throw new Error(`${result.name} did not complete its request envelope`);
  if (result.p95_ms > result.p95_limit_ms)
    throw new Error(
      `${result.name} p95 ${result.p95_ms}ms exceeded ${result.p95_limit_ms}ms`,
    );
  if (result.failed_requests !== 0)
    throw new Error(`${result.name} exceeded the zero-error release threshold`);
}

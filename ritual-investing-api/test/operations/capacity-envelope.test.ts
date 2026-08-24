import { describe, expect, it } from "vitest";

import {
  CAPACITY_PROFILES,
  RELEASE_CAPACITY_ENVELOPE,
  assertCapacityEnvelope,
  assertCapacityConfiguration,
  assertCapacityFixture,
  deriveCapacityProfiles,
  runCapacityProfile,
} from "../../src/operations/capacity-envelope";

describe("capacity and latency envelope", () => {
  it("defines every production latency SLO as an executable profile", () => {
    expect(CAPACITY_PROFILES.map((profile) => profile.name).sort()).toEqual([
      "authenticated-read",
      "command",
      "public-cache-hit",
      "public-cache-miss",
    ]);
    expect(
      CAPACITY_PROFILES.map((profile) => profile.p95_limit_ms).sort(
        (a, b) => a - b,
      ),
    ).toEqual([100, 250, 400, 1_000]);
    expect(CAPACITY_PROFILES.every((profile) => profile.concurrency > 0)).toBe(
      true,
    );
    expect(() => assertCapacityConfiguration()).not.toThrow();
    expect(RELEASE_CAPACITY_ENVELOPE).toMatchObject({
      duration_seconds: 600,
      concurrent_public_visitors: 250,
      concurrent_authenticated_members: 100,
      tenant_cardinality: 1_000,
      ledger_transactions_per_tenant: 10_000,
      public_cache_hit_ratio: 0.9,
      command_same_portfolio_contention: 4,
      queue_backlog_messages: 10_000,
      queue_consumer_concurrency: 20,
      maximum_error_ratio: 0,
    });
    expect(
      Object.values(RELEASE_CAPACITY_ENVELOPE.request_mix_percent).reduce(
        (sum, value) => sum + value,
        0,
      ),
    ).toBe(100);
    expect(deriveCapacityProfiles().map((profile) => profile.requests)).toEqual(
      [27_000, 3_000, 24_000, 6_000],
    );
    expect(
      deriveCapacityProfiles().map((profile) => profile.concurrency),
    ).toEqual([225, 25, 100, 4]);
  });

  it("requires observed tenant, ledger, queue backlog, drain, and lag evidence", () => {
    expect(() =>
      assertCapacityFixture({
        tenant_cardinality: 1_000,
        minimum_ledger_depth: 10_000,
        queue_backlog_seeded: 10_000,
        queue_consumer_concurrency: 20,
        queue_drain_seconds: 600,
        queue_p95_lag_seconds: 120,
      }),
    ).not.toThrow();
    expect(() =>
      assertCapacityFixture({
        tenant_cardinality: 999,
        minimum_ledger_depth: 10_000,
        queue_backlog_seeded: 10_000,
        queue_consumer_concurrency: 20,
        queue_drain_seconds: 600,
        queue_p95_lag_seconds: 120,
      }),
    ).toThrow(/tenant_cardinality/);
  });

  it("calculates p95 and fails closed when an SLO is exceeded", async () => {
    const profile = CAPACITY_PROFILES.find(
      (candidate) => candidate.name === "public-cache-hit",
    )!;
    const singleRequestProfile = { ...profile, concurrency: 1, requests: 1 };
    let now = 0;
    const result = await runCapacityProfile(singleRequestProfile, {
      now: () => now,
      request: async () => {
        now += 50;
        return { status: 200 };
      },
    });
    expect(result.p95_ms).toBe(50);
    expect(() => assertCapacityEnvelope(result)).not.toThrow();
    expect(() =>
      assertCapacityEnvelope({ ...result, p95_ms: profile.p95_limit_ms + 1 }),
    ).toThrow(/public-cache-hit.*p95/i);
  });

  it("rejects non-success responses rather than reporting a fast false pass", async () => {
    const profile = CAPACITY_PROFILES[0]!;
    await expect(
      runCapacityProfile(profile, {
        now: performance.now.bind(performance),
        request: async () => ({ status: 503 }),
      }),
    ).rejects.toThrow(/status 503/i);
  });
});

import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";

import {
  RELEASE_CAPACITY_ENVELOPE,
  assertCapacityConfiguration,
  assertCapacityEnvelope,
  assertCapacityFixture,
  deriveCapacityProfiles,
  runCapacityProfile,
  type CapacityEnvelope,
  type CapacityFixtureObservation,
  type CapacityProfile,
} from "../src/operations/capacity-envelope.ts";

function required(name: string): string {
  const value = process.env[name];
  if (!value)
    throw new Error(`${name} is required for the staging capacity run`);
  return value;
}

type CapacityActor = {
  token: string;
  portfolio_id: string;
  source_id: string;
};

function smokeActor(): CapacityActor {
  return {
    token: required("CAPACITY_MEMBER_TOKEN"),
    portfolio_id: required("CAPACITY_PORTFOLIO_ID"),
    source_id: required("CAPACITY_SOURCE_ID"),
  };
}

function capacityRequest(
  baseUrl: string,
  profile: CapacityProfile,
  ordinal: number,
  actors: readonly CapacityActor[],
): Request {
  const actorIndex =
    profile.name === "command"
      ? Math.floor(Math.max(0, ordinal) / profile.concurrency) % actors.length
      : Math.max(0, ordinal) % actors.length;
  const actor = actors[actorIndex]!;
  const path = profile.path.replace("{portfolio_id}", actor.portfolio_id);
  const headers = new Headers({ accept: "application/json" });
  if (profile.name === "public-cache-miss")
    headers.set("cache-control", "no-cache");
  if (profile.name === "authenticated-read" || profile.name === "command") {
    headers.set("authorization", `Bearer ${actor.token}`);
  }
  if (profile.name === "command") {
    headers.set("content-type", "application/json");
    headers.set("idempotency-key", `capacity-${randomUUID()}-${ordinal}`);
  }
  return new Request(new URL(path, baseUrl), {
    method: profile.method,
    headers,
    ...(profile.name === "command"
      ? {
          body: JSON.stringify({
            source_id: actor.source_id,
            amount: { minor_units: 100, currency: "USD" },
          }),
        }
      : {}),
  });
}

async function main(): Promise<void> {
  assertCapacityConfiguration();
  if (!process.argv.includes("--run")) {
    process.stdout.write(
      `${JSON.stringify({ status: "valid", envelope: RELEASE_CAPACITY_ENVELOPE })}\n`,
    );
    return;
  }
  const smoke = process.argv.includes("--smoke");
  const envelope: CapacityEnvelope = smoke
    ? {
        ...RELEASE_CAPACITY_ENVELOPE,
        duration_seconds: 5,
        concurrent_public_visitors: 10,
        concurrent_authenticated_members: 5,
        tenant_cardinality: 1,
        ledger_transactions_per_tenant: 10,
        public_cache_hit_ratio: 0.8,
        command_same_portfolio_contention: 2,
        queue_backlog_messages: 100,
        queue_consumer_concurrency: 2,
        target_requests_per_second: 4,
        request_mix_percent: {
          "public-cache-hit": 40,
          "public-cache-miss": 10,
          "authenticated-read": 40,
          command: 10,
        },
      }
    : RELEASE_CAPACITY_ENVELOPE;
  if (!smoke) assertCapacityConfiguration(envelope);
  const baseUrl = required("CAPACITY_BASE_URL");
  const profiles = deriveCapacityProfiles(envelope);
  let actorCount: number;
  let results;
  if (smoke) {
    const actors = [smokeActor()];
    const hitProfile = profiles.find(
      ({ name }) => name === "public-cache-hit",
    )!;
    await fetch(capacityRequest(baseUrl, hitProfile, -1, actors));
    results = await Promise.all(
      profiles.map(async (profile) => {
        const result = await runCapacityProfile(profile, {
          now: performance.now.bind(performance),
          wait: (milliseconds) =>
            new Promise((resolve) => setTimeout(resolve, milliseconds)),
          request: async (candidate, ordinal) => {
            const response = await fetch(
              capacityRequest(baseUrl, candidate, ordinal, actors),
            );
            return { status: response.status };
          },
        });
        assertCapacityEnvelope(result);
        return result;
      }),
    );
    actorCount = actors.length;
  } else {
    const response = await fetch(required("CAPACITY_DISTRIBUTED_RUNNER_URL"), {
      method: "POST",
      headers: {
        authorization: `Bearer ${required("CAPACITY_DISTRIBUTED_RUNNER_TOKEN")}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        schema_version: 1,
        target_origin: baseUrl,
        envelope,
        profiles,
      }),
    });
    if (!response.ok)
      throw new Error(
        `distributed capacity runner returned ${response.status}`,
      );
    const value = (await response.json()) as Record<string, unknown>;
    if (
      Object.keys(value).some(
        (key) => !["actor_count", "results"].includes(key),
      ) ||
      !Number.isInteger(value.actor_count) ||
      !Array.isArray(value.results)
    ) {
      throw new Error(
        "distributed capacity runner returned an invalid allowlisted shape",
      );
    }
    actorCount = value.actor_count as number;
    if (actorCount < envelope.concurrent_authenticated_members)
      throw new Error(
        "distributed actor pool did not cover concurrent members",
      );
    results = value.results as Awaited<ReturnType<typeof runCapacityProfile>>[];
    const resultKeys = [
      "name",
      "path",
      "method",
      "p95_limit_ms",
      "concurrency",
      "requests",
      "duration_seconds",
      "p50_ms",
      "p95_ms",
      "p99_ms",
      "maximum_ms",
      "successful_requests",
      "failed_requests",
    ];
    if (
      results.length !== profiles.length ||
      results.some(
        (result) =>
          result === null ||
          typeof result !== "object" ||
          Object.keys(result).some((key) => !resultKeys.includes(key)) ||
          [
            "p95_limit_ms",
            "concurrency",
            "requests",
            "duration_seconds",
            "p50_ms",
            "p95_ms",
            "p99_ms",
            "maximum_ms",
            "successful_requests",
            "failed_requests",
          ].some(
            (key) =>
              !Number.isFinite(result[key as keyof typeof result] as number),
          ),
      ) ||
      results.some((result, index) =>
        [
          "name",
          "path",
          "method",
          "p95_limit_ms",
          "concurrency",
          "requests",
          "duration_seconds",
        ].some(
          (key) =>
            result[key as keyof typeof result] !==
            profiles[index]![key as keyof CapacityProfile],
        ),
      )
    ) {
      throw new Error(
        "distributed capacity result does not match the release plan",
      );
    }
    results.forEach(assertCapacityEnvelope);
  }
  let fixture: CapacityFixtureObservation | undefined;
  const probeUrl = process.env.CAPACITY_PROBE_URL;
  if (!smoke || probeUrl !== undefined) {
    const response = await fetch(probeUrl ?? required("CAPACITY_PROBE_URL"), {
      headers: {
        authorization: `Bearer ${required("CAPACITY_PROBE_TOKEN")}`,
        "cache-control": "no-store",
      },
    });
    if (!response.ok)
      throw new Error(`capacity fixture probe returned ${response.status}`);
    const value = (await response.json()) as Record<string, unknown>;
    const keys = [
      "tenant_cardinality",
      "minimum_ledger_depth",
      "queue_backlog_seeded",
      "queue_consumer_concurrency",
      "queue_drain_seconds",
      "queue_p95_lag_seconds",
    ] as const;
    if (
      Object.keys(value).some(
        (key) => !keys.includes(key as (typeof keys)[number]),
      ) ||
      keys.some((key) => typeof value[key] !== "number")
    ) {
      throw new Error(
        "capacity fixture probe returned an invalid allowlisted shape",
      );
    }
    fixture = value as CapacityFixtureObservation;
    assertCapacityFixture(fixture, envelope);
  }
  const report = {
    schema_version: 1,
    executed_at: new Date().toISOString(),
    envelope,
    actor_count: actorCount,
    fixture,
    results,
  };
  const serialized = `${JSON.stringify(report, null, 2)}\n`;
  const output = process.env.CAPACITY_OUTPUT;
  if (output)
    await writeFile(output, serialized, { encoding: "utf8", mode: 0o600 });
  process.stdout.write(serialized);
}

await main();

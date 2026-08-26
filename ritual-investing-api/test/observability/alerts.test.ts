import { access, readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import {
  evaluateAlertFixtures,
  parseAlertFixtures,
} from "../../src/observability/alerts";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

describe("operational alert fixtures", () => {
  it("defines redacted alerts for every release-critical failure", async () => {
    const fixtures = parseAlertFixtures(
      JSON.parse(
        await readFile(`${apiRoot}/ops/alert-fixtures.v1.json`, "utf8"),
      ),
    );
    expect(fixtures.map((fixture) => fixture.id)).toEqual(
      expect.arrayContaining([
        "auth-denial-rate",
        "dependency-outage",
        "dlq-depth",
        "media-quarantine-age",
        "privacy-purge-deadline",
        "publication-failure",
      ]),
    );
    expect(
      fixtures.every((fixture) =>
        fixture.runbook.startsWith("docs/ritual-investing/"),
      ),
    ).toBe(true);
    await Promise.all(
      fixtures.map((fixture) =>
        access(resolve(apiRoot, "..", fixture.runbook)),
      ),
    );
    expect(fixtures.map((fixture) => fixture.metric)).toEqual(
      expect.arrayContaining([
        "http.error_ratio",
        "http.latency.p95_ms",
        "http.rate_limited_ratio",
        "database.rls_denials",
        "commands.idempotency_conflicts",
        "queue.stale_work_rejections",
        "queue.oldest_age_seconds",
        "queue.dlq.depth",
        "privacy.purge.oldest_age_seconds",
        "media.quarantine.oldest_age_seconds",
        "editorial.publication.failures",
        "editorial.cache_purge.failures",
        "auth0.available",
        "neon.available",
        "admin.audit.parity_failures",
      ]),
    );
    expect(JSON.stringify(fixtures)).not.toMatch(
      /token|password|subject|tenant_id/i,
    );
  });

  it("fires the five mandatory release alerts from deterministic samples", async () => {
    const fixtures = parseAlertFixtures(
      JSON.parse(
        await readFile(`${apiRoot}/ops/alert-fixtures.v1.json`, "utf8"),
      ),
    );
    const fired = evaluateAlertFixtures(fixtures, {
      "queue.dlq.depth": 1,
      "privacy.purge.oldest_age_seconds": 2_592_001,
      "editorial.publication.failures": 1,
      "http.authorization_denial_ratio": 0.06,
      "dependency.available": 0,
    });
    expect(fired).toEqual(
      expect.arrayContaining([
        "auth-denial-rate",
        "dependency-outage",
        "dlq-depth",
        "privacy-purge-deadline",
        "publication-failure",
      ]),
    );
  });
});

import { describe, expect, it } from "vitest";

import {
  assertCoupledArtifacts,
  fingerprintArtifact,
} from "../../scripts/check-openapi-drift";
import { assertUpgradePlan } from "../../scripts/check-migration-upgrade";

describe("release drift and upgrade tooling", () => {
  it("requires the OpenAPI and generated client contract to move together", () => {
    const baseline = {
      openapi: fingerprintArtifact("openapi-v1"),
      client: fingerprintArtifact("client-v1"),
    };
    expect(() => assertCoupledArtifacts(baseline, baseline)).not.toThrow();
    expect(() =>
      assertCoupledArtifacts(baseline, {
        ...baseline,
        openapi: fingerprintArtifact("openapi-v2"),
      }),
    ).toThrow(/move together/i);
    expect(() =>
      assertCoupledArtifacts(baseline, {
        openapi: fingerprintArtifact("openapi-v2"),
        client: fingerprintArtifact("client-v2"),
      }),
    ).not.toThrow();
  });

  it("rejects destructive migration plans without an explicit contract phase", () => {
    expect(() =>
      assertUpgradePlan([
        { name: "0001_expand.sql", body: "create table safe(id uuid);" },
        { name: "0002_contract.sql", body: "drop table safe;" },
      ]),
    ).toThrow(/destructive/i);
    expect(() =>
      assertUpgradePlan([
        { name: "0001_expand.sql", body: "create table safe(id uuid);" },
        {
          name: "0002_contract.sql",
          body: "-- ritual:contract-after-client-drain\ndrop table safe;",
        },
      ]),
    ).not.toThrow();
  });
});

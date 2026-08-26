import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

import {
  sealReleaseBaseline,
  validateReleaseBaseline,
  type EnvironmentReleaseBaseline,
  type ReleaseBaseline,
} from "../../scripts/baseline-release.ts";
import {
  cookieInventoryFingerprint,
  validateSmokeEvidence,
  type HostSmokeObservation,
} from "../../scripts/smoke-hosts.ts";
import { assessRetention, type RetentionSnapshot } from "../../scripts/check-retention.ts";

const fingerprint = (value: string): string => value.repeat(64).slice(0, 64);

function environmentBaseline(
  environment: "production" | "beta",
): EnvironmentReleaseBaseline {
  const beta = environment === "beta";
  const prefix = beta ? "ritual-waitlist-beta" : "ritual-waitlist-prod";
  const landingHost = beta ? "beta.just-build-this.app" : "just-build-this.app";
  const demoHost = beta
    ? "demo-beta.just-build-this.app"
    : "demo.just-build-this.app";
  const marker = beta ? "b" : "a";
  return {
    environment,
    owners: {
      release: `${environment}-release-owner`,
      privacy: `${environment}-privacy-owner`,
      database: `${environment}-database-owner`,
      cloudflare: `${environment}-cloudflare-owner`,
      goNoGo: `${environment}-go-no-go-owner`,
    },
    landing: {
      host: landingHost,
      service: beta ? "ritual-investing-site-beta" : "ritual-investing-site",
      activeVersion: `${environment}-landing-active`,
      rollbackVersion: `${environment}-landing-rollback`,
      dnsFingerprint: fingerprint(marker),
      tlsFingerprint: fingerprint(marker === "a" ? "c" : "d"),
      responseFingerprint: fingerprint(marker === "a" ? "e" : "f"),
      cookieInventoryFingerprint: cookieInventoryFingerprint([]),
      expectedStatus: 200,
    },
    demo: {
      host: demoHost,
      service: beta ? "ritual-investing-demo-beta" : "ritual-investing-demo",
      activeVersion: `${environment}-demo-active`,
      rollbackVersion: `${environment}-demo-rollback`,
      dnsFingerprint: fingerprint(marker === "a" ? "1" : "2"),
      tlsFingerprint: fingerprint(marker === "a" ? "3" : "4"),
      responseFingerprint: fingerprint(marker === "a" ? "5" : "6"),
      cookieInventoryFingerprint: cookieInventoryFingerprint([]),
      expectedStatus: 200,
    },
    neon: {
      project: `${prefix}-neon-v1`,
      migrationHead: "0000_waitlist.sql",
      migrationChecksum: fingerprint(marker === "a" ? "7" : "8"),
      grantFingerprint: fingerprint(marker === "a" ? "c" : "d"),
      ownerCredentialResource: `${prefix}-owner-url-v1`,
      runtimeCredentialResource: `${prefix}-runtime-url-v1`,
      maintenanceCredentialResource: `${prefix}-maintenance-url-v1`,
      roles: {
        functionOwner: "waitlist_function_owner",
        runtime: "waitlist_runtime",
        maintenance: "waitlist_maintenance",
      },
      tableBaseline: 0,
    },
    secretResources: {
      turnstile: `${prefix}-turnstile-secret-v1`,
      neonRuntime: `${prefix}-runtime-url-v1`,
      sourceHmac: `${prefix}-source-hmac-v1`,
      denialHmac: `${prefix}-denial-hmac-v1`,
    },
    rateLimits: {
      source: `${prefix}-source-v1`,
      route: `${prefix}-route-v1`,
    },
    waf: {
      rule: `${prefix}-budget-v1`,
      ceiling: `${prefix}-budget-1m`,
    },
    turnstile: {
      widget: `${prefix}-widget-v1`,
      hostname: landingHost,
      action: "waitlist",
    },
    denialJournal: `${prefix}-denial-journal-v1`,
    retention: {
      checkpoint: `${prefix}-retention-checkpoint-v1`,
      purgeCapability: `${prefix}-purge-expired-v1`,
      cron: "17 4 * * *",
    },
    protocol: { current: 2, previous: 1 },
    privacyContact: "privacy@just-build-this.app",
    privacyDeliveryFingerprint: fingerprint(marker === "a" ? "e" : "f"),
  };
}

function releaseBaseline(): ReleaseBaseline {
  return {
    version: "waitlist-release-baseline-v1",
    recordedAt: "2026-08-26T04:00:00.000Z",
    sourceCommit: "a".repeat(40),
    production: environmentBaseline("production"),
    beta: environmentBaseline("beta"),
    canonicalRedirect: {
      host: "www.just-build-this.app",
      expectedStatus: 308,
      responseFingerprint: fingerprint("e"),
      dnsFingerprint: fingerprint("f"),
      tlsFingerprint: fingerprint("1"),
      cookieInventoryFingerprint: cookieInventoryFingerprint([]),
    },
    preservedApis: [
      {
        host: "api.just-build-this.app",
        expectedStatus: 503,
        responseFingerprint: fingerprint("9"),
        dnsFingerprint: fingerprint("0"),
        tlsFingerprint: fingerprint("a"),
        cookieInventoryFingerprint: cookieInventoryFingerprint([]),
      },
      {
        host: "api-beta.just-build-this.app",
        expectedStatus: 200,
        responseFingerprint: fingerprint("b"),
        dnsFingerprint: fingerprint("c"),
        tlsFingerprint: fingerprint("d"),
        cookieInventoryFingerprint: cookieInventoryFingerprint([]),
      },
    ],
  };
}

function smokeObservations(baseline: ReleaseBaseline): HostSmokeObservation[] {
  const environment = baseline.beta;
  return [
    environment.landing,
    environment.demo,
    baseline.canonicalRedirect,
    ...baseline.preservedApis,
  ].map(
    (contract) => {
      const headers: Record<string, string> = contract.host.startsWith("demo-")
        ? {
            "content-security-policy": "frame-ancestors https://beta.just-build-this.app",
            "x-robots-tag": "noindex, nofollow",
          }
        : contract.host === "beta.just-build-this.app"
          ? { "content-security-policy": "frame-ancestors 'none'" }
          : {};
      return {
      host: contract.host,
      status: contract.expectedStatus,
      responseFingerprint: contract.responseFingerprint,
      dnsFingerprint: contract.dnsFingerprint,
      tlsFingerprint: contract.tlsFingerprint,
      cookies: [],
      headers,
      };
    },
  );
}

describe("release baseline contract", () => {
  it("accepts a complete pairwise release record and seals it without exposing the key", () => {
    const baseline = releaseBaseline();
    expect(validateReleaseBaseline(baseline)).toEqual([]);
    const sealed = sealReleaseBaseline(baseline, "k".repeat(32));
    expect(sealed.fingerprint).toMatch(/^[a-f0-9]{64}$/);
    expect(sealed.signature).toMatch(/^[a-f0-9]{64}$/);
    expect(JSON.stringify(sealed)).not.toContain("k".repeat(32));
  });

  it("fails closed on missing owners, fingerprints, resources, and secret-shaped values", () => {
    const baseline = releaseBaseline();
    baseline.beta.owners.goNoGo = "";
    baseline.beta.landing.dnsFingerprint = "";
    baseline.beta.secretResources.sourceHmac = "";
    baseline.beta.neon.runtimeCredentialResource =
      "postgresql://waitlist_runtime:secret@example.invalid/db";
    const errors = validateReleaseBaseline(baseline).join("\n");
    expect(errors).toMatch(/go.no.go owner/i);
    expect(errors).toMatch(/DNS fingerprint/i);
    expect(errors).toMatch(/source HMAC/i);
    expect(errors).toMatch(/redacted resource identifier/i);
  });

  it("requires effective-grant, cookie-inventory, and privacy-delivery evidence", () => {
    const baseline = releaseBaseline();
    baseline.production.neon.grantFingerprint = "";
    baseline.production.landing.cookieInventoryFingerprint = "";
    baseline.production.privacyDeliveryFingerprint = "";
    const errors = validateReleaseBaseline(baseline).join("\n");
    expect(errors).toMatch(/grant fingerprint/i);
    expect(errors).toMatch(/cookie inventory fingerprint/i);
    expect(errors).toMatch(/privacy delivery fingerprint/i);
  });

  it("rejects production and beta physical-resource overlap", () => {
    const baseline = releaseBaseline();
    baseline.beta.denialJournal = baseline.production.denialJournal;
    expect(validateReleaseBaseline(baseline).join("\n")).toMatch(/resource overlap/i);
  });

  it("requires the exact www-to-apex redirect contract", () => {
    const baseline = releaseBaseline();
    baseline.canonicalRedirect.host = "";
    expect(validateReleaseBaseline(baseline).join("\n")).toMatch(/www canonical redirect/i);
  });
});

describe("deployed host smoke contract", () => {
  it("accepts exact beta hosts while preserving both existing API contracts", () => {
    const baseline = releaseBaseline();
    expect(validateSmokeEvidence(baseline, "beta", smokeObservations(baseline))).toEqual([]);
  });

  it("fails on response drift, a credential cookie, or a missing pairwise CSP", () => {
    const baseline = releaseBaseline();
    const observations = smokeObservations(baseline);
    observations[0]!.responseFingerprint = fingerprint("0");
    observations[0]!.cookies = ["session=forbidden"];
    observations[1]!.headers["content-security-policy"] = "frame-ancestors *";
    const errors = validateSmokeEvidence(baseline, "beta", observations).join("\n");
    expect(errors).toMatch(/response fingerprint/i);
    expect(errors).toMatch(/credential cookie/i);
    expect(errors).toMatch(/pairwise frame policy/i);
  });
});

describe("retention aggregate contract", () => {
  const current: RetentionSnapshot = {
    checkedAt: "2026-08-26T05:00:00.000Z",
    lastSuccessAt: "2026-08-26T04:17:00.000Z",
    activeCount: 4,
    expiringWithinSevenDaysCount: 1,
    expiredCount: 0,
  };

  it("returns only aggregate, current evidence", () => {
    expect(assessRetention(current)).toEqual({
      ok: true,
      overdue: false,
      activeCount: 4,
      expiringWithinSevenDaysCount: 1,
      expiredCount: 0,
    });
  });

  it("fails closed when the checkpoint is overdue or an expired row remains", () => {
    expect(assessRetention({
      ...current,
      lastSuccessAt: "2026-08-23T04:17:00.000Z",
      expiredCount: 1,
    })).toEqual({
      ok: false,
      overdue: true,
      activeCount: 4,
      expiringWithinSevenDaysCount: 1,
      expiredCount: 1,
    });
  });
});

describe("operator-facing runbook", () => {
  it("names every activation, privacy, restore, rollback, and evidence control", async () => {
    const repositoryRoot = resolve(import.meta.dirname, "../../..");
    const runbook = await readFile(
      resolve(repositoryRoot, "docs/ritual-investing/site-demo-runbook.md"),
      "utf8",
    );
    const packageJson = JSON.parse(
      await readFile(resolve(repositoryRoot, "ritual-investing-site/package.json"), "utf8"),
    ) as { scripts: Record<string, string> };

    for (const phrase of [
      "release owner",
      "Cloudflare/DNS owner",
      "Neon security owner",
      "privacy data steward",
      "go/no-go owner",
      "beta Demo, beta landing, production Demo, production landing, then",
      "mailbox-possession removal",
      "waitlist:restore-replay",
      "+1 hour, +4 hours, and +24 hours",
      "three consecutive synthetic failures",
      "www.just-build-this.app",
    ]) {
      expect(runbook).toContain(phrase);
    }
    expect(packageJson.scripts["release:baseline"]).toContain("baseline-release.ts");
    expect(packageJson.scripts["release:smoke"]).toContain("smoke-hosts.ts");
    expect(packageJson.scripts["retention:check"]).toContain("check-retention.ts");
  });

  it("ships a fail-closed baseline template that cannot be sealed before live proof", async () => {
    const template = JSON.parse(
      await readFile(resolve(import.meta.dirname, "../../ops/release-baseline.example.json"), "utf8"),
    ) as ReleaseBaseline;
    const errors = validateReleaseBaseline(template).join("\n");
    expect(errors).toMatch(/timestamp/i);
    expect(errors).toMatch(/source commit/i);
    expect(errors).toMatch(/owner/i);
    expect(errors).toMatch(/fingerprint/i);
    expect(() => sealReleaseBaseline(template, "k".repeat(32))).toThrow();
  });
});

import { describe, expect, it } from "vitest";

import { validateStagingEvidence } from "../scripts/check-staging-evidence.ts";

const checks = {
  landing: "passed",
  demo: "passed",
  waitlist: "passed",
  abuseControlOutage: "passed",
  killSwitch: "passed",
  grants: "passed",
  providerConsole: "passed",
  restoreReplay: "passed",
  rollbackCompatibility: "passed",
};

describe("deployed staging evidence", () => {
  it("accepts a commit-bound redacted proof envelope with every release category", () => {
    expect(validateStagingEvidence({
      landingUrl: "https://staging.just-build-this.app/",
      demoUrl: "https://demo-staging.just-build-this.app/",
      expectedCommit: "a".repeat(40),
      evidence: JSON.stringify({ version: 1, environment: "staging", commit: "a".repeat(40), checks }),
    })).toEqual(checks);
  });

  it.each(Object.keys(checks))("fails closed when %s proof is absent", (missing) => {
    const incomplete = { ...checks };
    delete incomplete[missing as keyof typeof incomplete];
    expect(() => validateStagingEvidence({
      landingUrl: "https://staging.just-build-this.app/",
      demoUrl: "https://demo-staging.just-build-this.app/",
      expectedCommit: "a".repeat(40),
      evidence: JSON.stringify({ version: 1, environment: "staging", commit: "a".repeat(40), checks: incomplete }),
    })).toThrow(missing);
  });

  it("rejects the wrong hosts, commit, opaque text, and evidence containing an email", () => {
    const valid = { version: 1, environment: "staging", commit: "a".repeat(40), checks };
    const input = {
      landingUrl: "https://staging.just-build-this.app/",
      demoUrl: "https://demo-staging.just-build-this.app/",
      expectedCommit: "a".repeat(40),
      evidence: JSON.stringify(valid),
    };
    expect(() => validateStagingEvidence({ ...input, landingUrl: "https://hostile.example/" })).toThrow(/landing/i);
    expect(() => validateStagingEvidence({ ...input, expectedCommit: "b".repeat(40) })).toThrow(/commit/i);
    expect(() => validateStagingEvidence({ ...input, evidence: "passed" })).toThrow(/JSON/i);
    expect(() => validateStagingEvidence({
      ...input,
      evidence: JSON.stringify({ ...valid, environment: "beta" }),
    })).toThrow(/staging/i);
    expect(() => validateStagingEvidence({
      ...input,
      evidence: JSON.stringify({ ...valid, note: "person@example.com" }),
    })).toThrow(/redacted/i);
  });
});

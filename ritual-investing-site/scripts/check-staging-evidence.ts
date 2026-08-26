import { pathToFileURL } from "node:url";

const REQUIRED_CHECKS = [
  "landing",
  "demo",
  "waitlist",
  "abuseControlOutage",
  "killSwitch",
  "grants",
  "providerConsole",
  "restoreReplay",
  "rollbackCompatibility",
] as const;

type CheckName = (typeof REQUIRED_CHECKS)[number];
type PassedChecks = Record<CheckName, "passed">;

type EvidenceInput = {
  landingUrl: string | undefined;
  demoUrl: string | undefined;
  expectedCommit: string | undefined;
  evidence: string | undefined;
};

function requireExactUrl(value: string | undefined, host: string, label: string): void {
  let url: URL;
  try {
    url = new URL(value ?? "");
  } catch {
    throw new Error(`${label} staging URL is missing or invalid`);
  }
  if (url.protocol !== "https:" || url.hostname !== host || url.port !== "" ||
      url.username !== "" || url.password !== "" || url.pathname !== "/" ||
      url.search !== "" || url.hash !== "") {
    throw new Error(`${label} staging URL must be the exact beta HTTPS origin`);
  }
}

function record(value: unknown, label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be a JSON object`);
  }
  return value as Record<string, unknown>;
}

export function validateStagingEvidence(input: EvidenceInput): PassedChecks {
  requireExactUrl(input.landingUrl, "beta.just-build-this.app", "Landing");
  requireExactUrl(input.demoUrl, "demo-beta.just-build-this.app", "Demo");
  if (!/^[0-9a-f]{40}$/.test(input.expectedCommit ?? "")) {
    throw new Error("Expected commit must be a full lowercase Git SHA");
  }
  if (input.evidence === undefined || input.evidence === "") {
    throw new Error("Staging evidence JSON is missing");
  }
  if (/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.test(input.evidence)) {
    throw new Error("Staging evidence must remain redacted");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(input.evidence);
  } catch {
    throw new Error("Staging evidence must be valid JSON");
  }
  const envelope = record(parsed, "Staging evidence");
  const allowedEnvelopeKeys = new Set(["version", "environment", "commit", "checks"]);
  for (const key of Object.keys(envelope)) {
    if (!allowedEnvelopeKeys.has(key)) throw new Error(`Unknown staging evidence field: ${key}`);
  }
  if (envelope.version !== 1 || envelope.environment !== "beta") {
    throw new Error("Staging evidence must use the beta version 1 contract");
  }
  if (envelope.commit !== input.expectedCommit) {
    throw new Error("Staging evidence commit does not match this workflow revision");
  }

  const candidate = record(envelope.checks, "Staging evidence checks");
  const required = new Set<string>(REQUIRED_CHECKS);
  for (const key of Object.keys(candidate)) {
    if (!required.has(key)) throw new Error(`Unknown staging evidence check: ${key}`);
  }
  for (const key of REQUIRED_CHECKS) {
    if (candidate[key] !== "passed") throw new Error(`Missing passed staging evidence: ${key}`);
  }
  return candidate as PassedChecks;
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    validateStagingEvidence({
      landingUrl: process.env.SITE_STAGING_LANDING_URL,
      demoUrl: process.env.SITE_STAGING_DEMO_URL,
      expectedCommit: process.env.GITHUB_SHA,
      evidence: process.env.SITE_STAGING_EVIDENCE,
    });
    console.log("deployed beta staging evidence contract passed");
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Staging evidence validation failed");
    process.exitCode = 1;
  }
}

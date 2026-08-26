import { createHash, createHmac } from "node:crypto";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import process from "node:process";

export type ReleaseEnvironment = "production" | "beta";

export type HostReleaseContract = {
  host: string;
  service: string;
  activeVersion: string;
  rollbackVersion: string;
  dnsFingerprint: string;
  tlsFingerprint: string;
  responseFingerprint: string;
  cookieInventoryFingerprint: string;
  expectedStatus: number;
};

export type PreservedApiContract = Omit<
  HostReleaseContract,
  "service" | "activeVersion" | "rollbackVersion"
>;

export type EnvironmentReleaseBaseline = {
  environment: ReleaseEnvironment;
  owners: {
    release: string;
    privacy: string;
    database: string;
    cloudflare: string;
    goNoGo: string;
  };
  landing: HostReleaseContract;
  demo: HostReleaseContract;
  neon: {
    project: string;
    migrationHead: string;
    migrationChecksum: string;
    grantFingerprint: string;
    ownerCredentialResource: string;
    runtimeCredentialResource: string;
    maintenanceCredentialResource: string;
    roles: {
      functionOwner: string;
      runtime: string;
      maintenance: string;
    };
    tableBaseline: number;
  };
  secretResources: {
    turnstile: string;
    neonRuntime: string;
    sourceHmac: string;
    denialHmac: string;
  };
  rateLimits: { source: string; route: string };
  waf: { rule: string; ceiling: string };
  turnstile: { widget: string; hostname: string; action: "waitlist" };
  denialJournal: string;
  retention: { checkpoint: string; purgeCapability: string; cron: "17 4 * * *" };
  protocol: { current: 2; previous: 1 };
  privacyContact: "privacy@just-build-this.app";
  privacyDeliveryFingerprint: string;
};

export type ReleaseBaseline = {
  version: "waitlist-release-baseline-v1";
  recordedAt: string;
  sourceCommit: string;
  production: EnvironmentReleaseBaseline;
  beta: EnvironmentReleaseBaseline;
  canonicalRedirect: PreservedApiContract;
  preservedApis: [PreservedApiContract, PreservedApiContract];
};

export type SealedReleaseBaseline = {
  version: "waitlist-sealed-release-baseline-v1";
  algorithm: "hmac-sha256";
  fingerprint: string;
  signature: string;
  baseline: ReleaseBaseline;
};

const fingerprintPattern = /^[a-f0-9]{64}$/u;

function required(errors: string[], value: string, label: string): void {
  if (value.trim() === "") errors.push(`${label} is required.`);
}

function fingerprint(errors: string[], value: string, label: string): void {
  if (!fingerprintPattern.test(value)) errors.push(`${label} must be a SHA-256 fingerprint.`);
}

function resource(errors: string[], value: string, label: string): void {
  required(errors, value, label);
  if (/\s|:\/\/|@/u.test(value)) {
    errors.push(`${label} must be a redacted resource identifier, never a credential or address.`);
  }
}

function hostContract(errors: string[], contract: HostReleaseContract, label: string): void {
  required(errors, contract.host, `${label} host`);
  resource(errors, contract.service, `${label} service`);
  resource(errors, contract.activeVersion, `${label} active version`);
  resource(errors, contract.rollbackVersion, `${label} rollback version`);
  fingerprint(errors, contract.dnsFingerprint, `${label} DNS fingerprint`);
  fingerprint(errors, contract.tlsFingerprint, `${label} TLS fingerprint`);
  fingerprint(errors, contract.responseFingerprint, `${label} response fingerprint`);
  fingerprint(errors, contract.cookieInventoryFingerprint, `${label} cookie inventory fingerprint`);
  if (!Number.isInteger(contract.expectedStatus) || contract.expectedStatus < 100 || contract.expectedStatus > 599) {
    errors.push(`${label} expected status is invalid.`);
  }
}

function environmentResources(value: EnvironmentReleaseBaseline): string[] {
  return [
    value.landing.host,
    value.landing.service,
    value.demo.host,
    value.demo.service,
    value.neon.project,
    value.neon.ownerCredentialResource,
    value.neon.runtimeCredentialResource,
    value.neon.maintenanceCredentialResource,
    value.secretResources.turnstile,
    value.secretResources.sourceHmac,
    value.secretResources.denialHmac,
    value.rateLimits.source,
    value.rateLimits.route,
    value.waf.rule,
    value.waf.ceiling,
    value.turnstile.widget,
    value.denialJournal,
    value.retention.checkpoint,
    value.retention.purgeCapability,
  ];
}

function validateEnvironment(value: EnvironmentReleaseBaseline): string[] {
  const errors: string[] = [];
  const label = value.environment;
  required(errors, value.owners.release, `${label} release owner`);
  required(errors, value.owners.privacy, `${label} privacy owner`);
  required(errors, value.owners.database, `${label} database owner`);
  required(errors, value.owners.cloudflare, `${label} Cloudflare owner`);
  required(errors, value.owners.goNoGo, `${label} go/no-go owner`);
  hostContract(errors, value.landing, `${label} landing`);
  hostContract(errors, value.demo, `${label} demo`);

  for (const [name, identifier] of Object.entries({
    "Neon project": value.neon.project,
    "owner credential": value.neon.ownerCredentialResource,
    "runtime credential": value.neon.runtimeCredentialResource,
    "maintenance credential": value.neon.maintenanceCredentialResource,
    "Turnstile secret": value.secretResources.turnstile,
    "Neon runtime secret": value.secretResources.neonRuntime,
    "source HMAC secret": value.secretResources.sourceHmac,
    "denial HMAC secret": value.secretResources.denialHmac,
    "source rate limit": value.rateLimits.source,
    "route rate limit": value.rateLimits.route,
    "WAF rule": value.waf.rule,
    "WAF ceiling": value.waf.ceiling,
    "Turnstile widget": value.turnstile.widget,
    "denial journal": value.denialJournal,
    "retention checkpoint": value.retention.checkpoint,
    "purge capability": value.retention.purgeCapability,
  })) {
    resource(errors, identifier, `${label} ${name}`);
  }
  for (const [name, role] of Object.entries(value.neon.roles)) {
    resource(errors, role, `${label} Neon ${name} role`);
  }
  fingerprint(errors, value.neon.migrationChecksum, `${label} migration checksum`);
  fingerprint(errors, value.neon.grantFingerprint, `${label} grant fingerprint`);
  required(errors, value.neon.migrationHead, `${label} migration head`);
  if (!Number.isSafeInteger(value.neon.tableBaseline) || value.neon.tableBaseline < 0) {
    errors.push(`${label} table baseline must be a non-negative aggregate.`);
  }
  if (value.turnstile.hostname !== value.landing.host || value.turnstile.action !== "waitlist") {
    errors.push(`${label} Turnstile pairing must match the exact landing host and waitlist action.`);
  }
  if (value.protocol.current !== 2 || value.protocol.previous !== 1) {
    errors.push(`${label} protocol peers must record current 2 and previous 1.`);
  }
  if (value.privacyContact !== "privacy@just-build-this.app") {
    errors.push(`${label} privacy contact must be privacy@just-build-this.app.`);
  }
  fingerprint(errors, value.privacyDeliveryFingerprint, `${label} privacy delivery fingerprint`);
  if (value.retention.cron !== "17 4 * * *") {
    errors.push(`${label} retention cron must match the reviewed daily schedule.`);
  }
  return errors;
}

export function validateReleaseBaseline(value: ReleaseBaseline): string[] {
  const errors: string[] = [];
  if (value.version !== "waitlist-release-baseline-v1") {
    errors.push("Release baseline version is invalid.");
  }
  const recordedAt = Date.parse(value.recordedAt);
  if (!Number.isFinite(recordedAt) || new Date(recordedAt).toISOString() !== value.recordedAt) {
    errors.push("Release baseline timestamp must be canonical UTC.");
  }
  if (!/^[a-f0-9]{40}$/u.test(value.sourceCommit)) {
    errors.push("Release baseline source commit must be a full lowercase Git SHA.");
  }
  if (value.production.environment !== "production" || value.beta.environment !== "beta") {
    errors.push("Release baseline environments are mislabeled.");
  }
  errors.push(...validateEnvironment(value.production), ...validateEnvironment(value.beta));

  if (value.canonicalRedirect.host !== "www.just-build-this.app") {
    errors.push("The www canonical redirect host must be www.just-build-this.app.");
  }
  if (value.canonicalRedirect.expectedStatus !== 308) {
    errors.push("The www canonical redirect must preserve the permanent 308 contract.");
  }
  fingerprint(errors, value.canonicalRedirect.dnsFingerprint, "www canonical redirect DNS fingerprint");
  fingerprint(errors, value.canonicalRedirect.tlsFingerprint, "www canonical redirect TLS fingerprint");
  fingerprint(errors, value.canonicalRedirect.responseFingerprint, "www canonical redirect response fingerprint");
  fingerprint(errors, value.canonicalRedirect.cookieInventoryFingerprint, "www canonical redirect cookie inventory fingerprint");

  const productionResources = new Set(environmentResources(value.production));
  const overlap = environmentResources(value.beta).filter((identifier) => productionResources.has(identifier));
  if (overlap.length > 0) {
    errors.push(`Production/beta physical resource overlap: ${[...new Set(overlap)].join(", ")}.`);
  }

  const apiByHost = new Map(value.preservedApis.map((contract) => [contract.host, contract]));
  for (const [host, status] of [
    ["api.just-build-this.app", 503],
    ["api-beta.just-build-this.app", 200],
  ] as const) {
    const contract = apiByHost.get(host);
    if (contract === undefined) {
      errors.push(`Preserved API contract is missing for ${host}.`);
      continue;
    }
    if (contract.expectedStatus !== status) errors.push(`Preserved API status changed for ${host}.`);
    fingerprint(errors, contract.dnsFingerprint, `${host} DNS fingerprint`);
    fingerprint(errors, contract.tlsFingerprint, `${host} TLS fingerprint`);
    fingerprint(errors, contract.responseFingerprint, `${host} response fingerprint`);
    fingerprint(errors, contract.cookieInventoryFingerprint, `${host} cookie inventory fingerprint`);
  }
  return errors;
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value !== null && typeof value === "object") {
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, child]) => `${JSON.stringify(key)}:${canonical(child)}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

export function sealReleaseBaseline(
  baseline: ReleaseBaseline,
  signingKey: string,
): SealedReleaseBaseline {
  const errors = validateReleaseBaseline(baseline);
  if (errors.length > 0) throw new Error(errors.join("\n"));
  if (Buffer.byteLength(signingKey, "utf8") < 32) {
    throw new Error("Release baseline signing key must contain at least 32 bytes.");
  }
  const payload = canonical(baseline);
  return {
    version: "waitlist-sealed-release-baseline-v1",
    algorithm: "hmac-sha256",
    fingerprint: createHash("sha256").update(payload).digest("hex"),
    signature: createHmac("sha256", signingKey).update(payload).digest("hex"),
    baseline,
  };
}

function argument(name: string): string | undefined {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
}

async function main(): Promise<void> {
  const input = argument("--input");
  const signingKey = process.env.RELEASE_BASELINE_SIGNING_KEY;
  if (input === undefined || signingKey === undefined) {
    throw new Error("A baseline input file and managed signing key are required.");
  }
  const baseline = JSON.parse(await readFile(resolve(input), "utf8")) as ReleaseBaseline;
  process.stdout.write(`${JSON.stringify(sealReleaseBaseline(baseline, signingKey))}\n`);
}

const entrypoint = process.argv[1];
if (entrypoint !== undefined && import.meta.url === pathToFileURL(resolve(entrypoint)).href) {
  main().catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.message : "Release baseline failed."}\n`);
    process.exitCode = 1;
  });
}

import { createHash } from "node:crypto";
import { resolve4, resolve6, resolveCname } from "node:dns/promises";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import process from "node:process";
import { connect } from "node:tls";

import type {
  HostReleaseContract,
  PreservedApiContract,
  ReleaseBaseline,
  ReleaseEnvironment,
  SealedReleaseBaseline,
} from "./baseline-release.ts";

export type HostSmokeObservation = {
  host: string;
  status: number;
  responseFingerprint: string;
  dnsFingerprint: string;
  tlsFingerprint: string;
  cookies: string[];
  headers: Record<string, string>;
};

type SmokeContract = HostReleaseContract | PreservedApiContract;

export function cookieInventoryFingerprint(cookies: string[]): string {
  return createHash("sha256")
    .update(JSON.stringify([...cookies].sort()))
    .digest("hex");
}

function contracts(
  baseline: ReleaseBaseline,
  environment: ReleaseEnvironment,
): SmokeContract[] {
  const selected = baseline[environment];
  return [
    selected.landing,
    selected.demo,
    ...(environment === "production" ? [baseline.canonicalRedirect] : []),
    ...baseline.preservedApis,
  ];
}

export function validateSmokeEvidence(
  baseline: ReleaseBaseline,
  environment: ReleaseEnvironment,
  observations: HostSmokeObservation[],
): string[] {
  const errors: string[] = [];
  const selected = baseline[environment];
  const observedByHost = new Map(observations.map((observation) => [observation.host, observation]));
  for (const contract of contracts(baseline, environment)) {
    const observation = observedByHost.get(contract.host);
    if (observation === undefined) {
      errors.push(`Smoke evidence is missing for ${contract.host}.`);
      continue;
    }
    if (observation.status !== contract.expectedStatus) {
      errors.push(`HTTP status drifted for ${contract.host}.`);
    }
    if (observation.responseFingerprint !== contract.responseFingerprint) {
      errors.push(`Response fingerprint drifted for ${contract.host}.`);
    }
    if (observation.dnsFingerprint !== contract.dnsFingerprint) {
      errors.push(`DNS fingerprint drifted for ${contract.host}.`);
    }
    if (observation.tlsFingerprint !== contract.tlsFingerprint) {
      errors.push(`TLS fingerprint drifted for ${contract.host}.`);
    }
    if (cookieInventoryFingerprint(observation.cookies) !== contract.cookieInventoryFingerprint) {
      errors.push(`Cookie inventory fingerprint drifted for ${contract.host}.`);
    }
    if (observation.cookies.length > 0) {
      errors.push(`A credential cookie was emitted by ${contract.host}.`);
    }
  }

  const landing = observedByHost.get(selected.landing.host);
  const landingCsp = landing?.headers["content-security-policy"] ?? "";
  if (!/(?:^|;)\s*frame-ancestors\s+'none'(?:\s*;|\s*$)/u.test(landingCsp)) {
    errors.push(`${selected.landing.host} is missing the deny-all frame policy.`);
  }
  const demo = observedByHost.get(selected.demo.host);
  const demoCsp = demo?.headers["content-security-policy"] ?? "";
  const trustedLanding = `https://${selected.landing.host}`;
  if (!demoCsp.includes(`frame-ancestors ${trustedLanding}`) || /frame-ancestors[^;]*\*/u.test(demoCsp)) {
    errors.push(`${selected.demo.host} is missing the exact pairwise frame policy.`);
  }
  if (!(demo?.headers["x-robots-tag"] ?? "").includes("noindex")) {
    errors.push(`${selected.demo.host} must remain noindex.`);
  }
  return errors;
}

async function resolvedValues(host: string): Promise<string[]> {
  const settled = await Promise.allSettled([resolve4(host), resolve6(host), resolveCname(host)]);
  return settled
    .flatMap((result) => result.status === "fulfilled" ? result.value : [])
    .map((value) => value.toLowerCase())
    .sort();
}

async function dnsFingerprint(host: string): Promise<string> {
  const values = await resolvedValues(host);
  if (values.length === 0) throw new Error(`No exact DNS target resolved for ${host}.`);
  return createHash("sha256").update(values.join("\n")).digest("hex");
}

async function tlsFingerprint(host: string): Promise<string> {
  return new Promise((resolveFingerprint, reject) => {
    const socket = connect({ host, port: 443, servername: host, rejectUnauthorized: true });
    socket.setTimeout(10_000);
    socket.once("secureConnect", () => {
      const certificate = socket.getPeerCertificate();
      socket.end();
      const value = certificate.fingerprint256?.replaceAll(":", "").toLowerCase();
      if (value === undefined || !/^[a-f0-9]{64}$/u.test(value)) {
        reject(new Error(`TLS certificate fingerprint is unavailable for ${host}.`));
        return;
      }
      resolveFingerprint(value);
    });
    socket.once("timeout", () => {
      socket.destroy();
      reject(new Error(`TLS probe timed out for ${host}.`));
    });
    socket.once("error", reject);
  });
}

async function observe(contract: SmokeContract): Promise<HostSmokeObservation> {
  const pathname = contract.host.startsWith("api") ? "/health" : "/";
  const response = await fetch(`https://${contract.host}${pathname}`, {
    redirect: "manual",
    signal: AbortSignal.timeout(15_000),
  });
  const body = new Uint8Array(await response.arrayBuffer());
  const headers = Object.fromEntries(
    [...response.headers.entries()].map(([name, value]) => [name.toLowerCase(), value]),
  );
  const cookieHeaders = typeof response.headers.getSetCookie === "function"
    ? response.headers.getSetCookie()
    : response.headers.get("set-cookie") === null
      ? []
      : [response.headers.get("set-cookie")!];
  return {
    host: contract.host,
    status: response.status,
    responseFingerprint: createHash("sha256").update(body).digest("hex"),
    dnsFingerprint: await dnsFingerprint(contract.host),
    tlsFingerprint: await tlsFingerprint(contract.host),
    cookies: cookieHeaders,
    headers,
  };
}

function argument(name: string): string | undefined {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
}

async function main(): Promise<void> {
  const baselineFile = argument("--baseline");
  const environment = argument("--environment");
  if (baselineFile === undefined || (environment !== "production" && environment !== "beta")) {
    throw new Error("A sealed baseline file and production or beta environment are required.");
  }
  const document = JSON.parse(await readFile(resolve(baselineFile), "utf8")) as
    | ReleaseBaseline
    | SealedReleaseBaseline;
  const baseline = "baseline" in document ? document.baseline : document;
  const observations = await Promise.all(
    contracts(baseline, environment).map((contract) => observe(contract)),
  );
  const errors = validateSmokeEvidence(baseline, environment, observations);
  if (errors.length > 0) throw new Error(errors.join("\n"));
  process.stdout.write(`${JSON.stringify({ environment, observations })}\n`);
}

const entrypoint = process.argv[1];
if (entrypoint !== undefined && import.meta.url === pathToFileURL(resolve(entrypoint)).href) {
  main().catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.message : "Host smoke failed."}\n`);
    process.exitCode = 1;
  });
}

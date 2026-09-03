import { pathToFileURL } from "node:url";

type UnknownRoutePolicy = "not-found" | "redirect-root";

export type PagesProbeOptions = {
  origin: string;
  expectedHost: string;
  expectedRevision: string;
  expectedManifestSha256: string;
  requiredHeaders: Record<string, string>;
  unknownRoutePolicy: UnknownRoutePolicy;
  fetchImpl?: typeof fetch;
};

export type PagesProbeResult = {
  passed: true;
  host: string;
  revision: string;
  manifestSha256: string;
  unknownRoutePolicy: UnknownRoutePolicy;
};

const GIT_SHA = /^[a-f0-9]{40}$/;
const SHA256 = /^[a-f0-9]{64}$/;

function exactOrigin(value: string, expectedHost: string): URL {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error("Pages probe origin is invalid");
  }
  if (url.protocol !== "https:" || url.hostname !== expectedHost || url.host !== expectedHost ||
      url.username !== "" || url.password !== "" || url.pathname !== "/" || url.search !== "" || url.hash !== "") {
    throw new Error("Pages probe origin must use the exact host identity");
  }
  return url;
}

function assertResponseHost(response: Response, expectedHost: string, label: string): void {
  if (response.url === "") return;
  const observed = new URL(response.url);
  if (observed.protocol !== "https:" || observed.hostname !== expectedHost || observed.host !== expectedHost) {
    throw new Error(`${label} escaped the exact host identity`);
  }
}

export async function probePagesDeployment(options: PagesProbeOptions): Promise<PagesProbeResult> {
  if (!GIT_SHA.test(options.expectedRevision)) throw new Error("Expected revision must be a full lowercase Git SHA");
  if (!SHA256.test(options.expectedManifestSha256)) throw new Error("Expected manifest must be a lowercase SHA-256 digest");
  if (options.unknownRoutePolicy !== "not-found" && options.unknownRoutePolicy !== "redirect-root") {
    throw new Error("Unknown-route policy is unsupported");
  }
  const origin = exactOrigin(options.origin, options.expectedHost);
  const request = options.fetchImpl ?? fetch;

  const versionUrl = new URL("/version.json", origin).href;
  const versionResponse = await request(versionUrl, { method: "GET", redirect: "manual" });
  assertResponseHost(versionResponse, options.expectedHost, "Version probe");
  if (versionResponse.status !== 200 || versionResponse.headers.get("content-type")?.split(";", 1)[0] !== "application/json") {
    throw new Error("Version probe did not return exact JSON availability");
  }
  const version = await versionResponse.json() as unknown;
  if (version === null || typeof version !== "object" || Array.isArray(version)) throw new Error("Version probe payload is invalid");
  const record = version as Record<string, unknown>;
  const keys = Object.keys(record).sort();
  if (keys.join(",") !== "manifestSha256,revision,schemaVersion") throw new Error("Version probe payload has unknown or missing fields");
  if (record.schemaVersion !== 1 || record.revision !== options.expectedRevision ||
      record.manifestSha256 !== options.expectedManifestSha256) {
    throw new Error("Version probe revision or manifest identity mismatch");
  }

  const rootResponse = await request(origin.href, { method: "HEAD", redirect: "manual" });
  assertResponseHost(rootResponse, options.expectedHost, "Header probe");
  if (rootResponse.status !== 200) throw new Error("Header probe did not return 200");
  for (const [name, expected] of Object.entries(options.requiredHeaders)) {
    if (rootResponse.headers.get(name) !== expected) throw new Error(`Required response header mismatch: ${name}`);
  }

  const unknownUrl = new URL("/__ritual-release-probe__/unknown", origin).href;
  const unknownResponse = await request(unknownUrl, { method: "GET", redirect: "manual" });
  assertResponseHost(unknownResponse, options.expectedHost, "Unknown-route probe");
  if (options.unknownRoutePolicy === "not-found") {
    if (unknownResponse.status !== 404) throw new Error("Unknown-route policy requires an exact 404");
  } else {
    if (![301, 302, 307, 308].includes(unknownResponse.status)) throw new Error("Unknown-route policy requires an HTTP redirect");
    const location = unknownResponse.headers.get("location");
    if (location === null || new URL(location, origin).href !== origin.href) {
      throw new Error("Unknown-route redirect must return to the exact root origin");
    }
  }

  return {
    passed: true,
    host: options.expectedHost,
    revision: options.expectedRevision,
    manifestSha256: options.expectedManifestSha256,
    unknownRoutePolicy: options.unknownRoutePolicy,
  };
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const headersJson = process.env.RELEASE_PROBE_REQUIRED_HEADERS ?? "{}";
    const result = await probePagesDeployment({
      origin: process.env.RELEASE_PROBE_ORIGIN ?? "",
      expectedHost: process.env.RELEASE_PROBE_EXPECTED_HOST ?? "",
      expectedRevision: process.env.RELEASE_PROBE_REVISION ?? "",
      expectedManifestSha256: process.env.RELEASE_PROBE_MANIFEST_SHA256 ?? "",
      requiredHeaders: JSON.parse(headersJson) as Record<string, string>,
      unknownRoutePolicy: process.env.RELEASE_PROBE_UNKNOWN_ROUTE_POLICY as UnknownRoutePolicy,
    });
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Pages deployment probe failed");
    process.exitCode = 1;
  }
}

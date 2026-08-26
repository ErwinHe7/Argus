import type { RuntimeSiteEnv } from "../config.ts";
import { emitWaitlistTelemetry, type WaitlistTelemetryPoint } from "../observability.ts";
import { createWaitlistRepository, type WaitlistRepository } from "./repository.ts";
import {
  MAX_WAITLIST_REQUEST_BYTES,
  parseWaitlistSubmission,
  type WaitlistSchemaFailure,
} from "./schemas.ts";
import {
  verifyTurnstile as verifyTurnstileDefault,
  type TurnstileVerificationInput,
  type TurnstileVerificationResult,
} from "./turnstile.ts";

const RETRY_AFTER_SECONDS = 60;
const DEFAULT_ABUSE_TIMEOUT_MS = 750;
const DEFAULT_DATABASE_TIMEOUT_MS = 3_000;
const ACTIVE_ORIGINS = {
  production: "https://just-build-this.app",
  beta: "https://beta.just-build-this.app",
} as const;

type SubmissionRepository = Pick<WaitlistRepository, "submit">;

export type WaitlistRouteDependencies = {
  verifyTurnstile?: (input: TurnstileVerificationInput) => Promise<TurnstileVerificationResult>;
  repositoryFactory?: (databaseUrl: string) => SubmissionRepository;
  emit?: (point: WaitlistTelemetryPoint) => void;
  abuseTimeoutMs?: number;
  databaseTimeoutMs?: number;
};

function headers(extra: HeadersInit = {}): Headers {
  const value = new Headers(extra);
  value.set("cache-control", "no-store");
  value.set("content-type", "application/json; charset=UTF-8");
  value.set("content-security-policy", "default-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; object-src 'none'");
  value.set("cross-origin-resource-policy", "same-origin");
  value.set("permissions-policy", "camera=(), geolocation=(), microphone=(), payment=(), usb=()");
  value.set("referrer-policy", "no-referrer");
  value.set("x-frame-options", "DENY");
  value.set("x-content-type-options", "nosniff");
  return value;
}

function json(status: number, code: string, retryable: boolean, extraHeaders: HeadersInit = {}): Response {
  return new Response(JSON.stringify({ code, retryable }), {
    status,
    headers: headers(extraHeaders),
  });
}

function validationResponse(failure: WaitlistSchemaFailure): Response {
  if (failure === "notice") return json(409, "stale_notice", false);
  return json(400, failure === "schema" ? "invalid_request" : "consent_required", false);
}

function expectedOrigin(environment: RuntimeSiteEnv): string {
  return ACTIVE_ORIGINS[environment.ENVIRONMENT];
}

function activationContractIsPresent(environment: RuntimeSiteEnv, trustedOrigin: string): boolean {
  return environment.PUBLIC_ORIGIN === trustedOrigin;
}

function emit(
  environment: RuntimeSiteEnv,
  dependencies: WaitlistRouteDependencies,
  point: WaitlistTelemetryPoint,
): void {
  if (dependencies.emit !== undefined) {
    try { dependencies.emit(point); } catch { /* aggregate telemetry cannot affect the route */ }
    return;
  }
  emitWaitlistTelemetry(environment.WAITLIST_TELEMETRY, point);
}

function isCloudflareSource(value: string | null): value is string {
  if (value === null || value.length === 0 || value.length > 128) return false;
  if (/^\d{1,3}(?:\.\d{1,3}){3}$/.test(value)) {
    return value.split(".").every((octet) => Number(octet) <= 255);
  }
  if (!value.includes(":") || value.length > 45 || !/^[0-9a-f:.]+$/i.test(value)) return false;
  try {
    new URL(`http://[${value}]/`);
    return true;
  } catch {
    return false;
  }
}

function configuredResource(value: string | undefined): value is string {
  return value !== undefined && value.trim().length > 0;
}

export function isRuntimeDatabaseCapability(value: string): boolean {
  try {
    const parsed = new URL(value);
    if (parsed.protocol !== "postgresql:" && parsed.protocol !== "postgres:") return false;
    if (decodeURIComponent(parsed.username) !== "waitlist_runtime") return false;
    if (parsed.password.length === 0 || parsed.hostname.length === 0 || parsed.hash !== "") return false;
    const database = decodeURIComponent(parsed.pathname.slice(1));
    if (database.length === 0 || database.includes("/")) return false;
    for (const override of ["user", "username", "role", "options", "dbname", "database"]) {
      if (parsed.searchParams.has(override)) return false;
    }
    return true;
  } catch {
    return false;
  }
}

async function sourceKey(rawSource: string, secret: string): Promise<string> {
  // The raw source has this single bounded lifetime and is never returned,
  // logged, persisted, or added to telemetry.
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawSource));
  return btoa(String.fromCharCode(...new Uint8Array(digest)))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

async function readBoundedText(request: Request, maximumBytes: number): Promise<
  | { ok: true; value: string }
  | { ok: false; tooLarge: boolean }
> {
  if (request.body === null) return { ok: true, value: "" };
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      totalBytes += next.value.byteLength;
      if (totalBytes > maximumBytes) {
        await reader.cancel();
        return { ok: false, tooLarge: true };
      }
      chunks.push(next.value);
    }
    const combined = new Uint8Array(totalBytes);
    let offset = 0;
    for (const chunk of chunks) {
      combined.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return { ok: true, value: new TextDecoder("utf-8", { fatal: true }).decode(combined) };
  } catch {
    try { await reader.cancel(); } catch { /* fixed public failure only */ }
    return { ok: false, tooLarge: false };
  } finally {
    try { reader.releaseLock(); } catch { /* the request body is already abandoned */ }
  }
}

async function limit(
  binding: RuntimeSiteEnv["WAITLIST_SOURCE_RATE_LIMIT"],
  key: string,
  timeoutMs: number,
): Promise<"allowed" | "denied" | "unavailable"> {
  if (binding === undefined) return "unavailable";
  let timeout: ReturnType<typeof setTimeout> | undefined;
  const deadline = new Promise<"unavailable">((resolve) => {
    timeout = setTimeout(() => resolve("unavailable"), timeoutMs);
  });
  try {
    const result = await Promise.race([binding.limit({ key }), deadline]);
    if (result === "unavailable" || typeof result.success !== "boolean") return "unavailable";
    return result.success ? "allowed" : "denied";
  } catch {
    return "unavailable";
  } finally {
    if (timeout !== undefined) clearTimeout(timeout);
  }
}

async function boundedSubmit(
  repository: SubmissionRepository,
  email: string,
  noticeVersion: string,
  timeoutMs: number,
): Promise<void> {
  let timeout: ReturnType<typeof setTimeout> | undefined;
  const deadline = new Promise<never>((_resolve, reject) => {
    timeout = setTimeout(() => reject(new Error("Waitlist dependency deadline exceeded.")), timeoutMs);
  });
  try {
    await Promise.race([repository.submit(email, noticeVersion), deadline]);
  } finally {
    if (timeout !== undefined) clearTimeout(timeout);
  }
}

export async function handleWaitlistRequest(
  request: Request,
  environment: RuntimeSiteEnv,
  dependencies: WaitlistRouteDependencies = {},
): Promise<Response> {
  if (environment.WAITLIST_SUBMISSIONS !== "on") {
    emit(environment, dependencies, { event: "waitlist_disabled", outcome: "disabled" });
    return json(503, "waitlist_unavailable", true);
  }

  const trustedOrigin = expectedOrigin(environment);
  if (!activationContractIsPresent(environment, trustedOrigin)) {
    emit(environment, dependencies, { event: "waitlist_dependency_failed", outcome: "configuration" });
    return json(503, "waitlist_unavailable", true);
  }
  if (request.headers.get("origin") !== trustedOrigin) {
    emit(environment, dependencies, { event: "waitlist_validation_failed", outcome: "origin" });
    return json(403, "request_not_allowed", false);
  }
  if (new URL(request.url).origin !== trustedOrigin) {
    emit(environment, dependencies, { event: "waitlist_validation_failed", outcome: "host" });
    return json(403, "request_not_allowed", false);
  }
  if (request.method !== "POST") {
    emit(environment, dependencies, { event: "waitlist_validation_failed", outcome: "method" });
    return json(405, "method_not_allowed", false, { allow: "POST" });
  }
  const contentEncoding = request.headers.get("content-encoding")?.toLowerCase();
  if (
    request.headers.get("content-type")?.toLowerCase() !== "application/json" ||
    (contentEncoding !== undefined && contentEncoding !== "identity")
  ) {
    emit(environment, dependencies, { event: "waitlist_validation_failed", outcome: "media" });
    return json(415, "unsupported_media_type", false);
  }
  const declaredLength = Number(request.headers.get("content-length"));
  if (Number.isFinite(declaredLength) && declaredLength > MAX_WAITLIST_REQUEST_BYTES) {
    emit(environment, dependencies, { event: "waitlist_validation_failed", outcome: "body" });
    return json(413, "payload_too_large", false);
  }

  const boundedBody = await readBoundedText(request, MAX_WAITLIST_REQUEST_BYTES);
  if (!boundedBody.ok) {
    emit(environment, dependencies, { event: "waitlist_validation_failed", outcome: "body" });
    return boundedBody.tooLarge
      ? json(413, "payload_too_large", false)
      : json(400, "invalid_request", false);
  }
  const parsed = parseWaitlistSubmission(boundedBody.value);
  if (!parsed.ok) {
    emit(environment, dependencies, { event: "waitlist_validation_failed", outcome: parsed.failure });
    return validationResponse(parsed.failure);
  }

  const sourceBinding = environment.WAITLIST_SOURCE_RATE_LIMIT;
  const routeBinding = environment.WAITLIST_ROUTE_RATE_LIMIT;
  const sourceSecret = environment.WAITLIST_SOURCE_HMAC_KEY;
  const rawSource = request.headers.get("cf-connecting-ip");
  if (
    sourceBinding === undefined ||
    routeBinding === undefined ||
    !configuredResource(environment.WAITLIST_SOURCE_KEY_RESOURCE) ||
    !configuredResource(environment.WAITLIST_WAF_BUDGET_RESOURCE) ||
    !configuredResource(environment.WAITLIST_WAF_CEILING_RESOURCE) ||
    sourceSecret === undefined ||
    new TextEncoder().encode(sourceSecret).byteLength < 32 ||
    new TextEncoder().encode(sourceSecret).byteLength > 128 ||
    !isCloudflareSource(rawSource)
  ) {
    emit(environment, dependencies, { event: "waitlist_dependency_failed", outcome: "abuse_control" });
    return json(503, "dependency_unavailable", true);
  }
  let pseudonymousSource: string;
  try {
    pseudonymousSource = await sourceKey(rawSource, sourceSecret);
  } catch {
    emit(environment, dependencies, { event: "waitlist_dependency_failed", outcome: "abuse_control" });
    return json(503, "dependency_unavailable", true);
  }
  const abuseTimeoutMs = Math.max(1, Math.min(
    dependencies.abuseTimeoutMs ?? DEFAULT_ABUSE_TIMEOUT_MS,
    DEFAULT_ABUSE_TIMEOUT_MS,
  ));
  const sourceOutcome = await limit(sourceBinding, pseudonymousSource, abuseTimeoutMs);
  if (sourceOutcome !== "allowed") {
    if (sourceOutcome === "denied") {
      emit(environment, dependencies, { event: "waitlist_throttled", outcome: "source" });
      return json(429, "rate_limited", true, { "retry-after": String(RETRY_AFTER_SECONDS) });
    }
    emit(environment, dependencies, { event: "waitlist_dependency_failed", outcome: "abuse_control" });
    return json(503, "dependency_unavailable", true);
  }
  const routeOutcome = await limit(routeBinding, `waitlist:${environment.ENVIRONMENT}:v1`, abuseTimeoutMs);
  if (routeOutcome !== "allowed") {
    if (routeOutcome === "denied") {
      emit(environment, dependencies, { event: "waitlist_throttled", outcome: "route" });
      emit(environment, dependencies, { event: "waitlist_budget_alert", outcome: "route_ceiling" });
      return json(429, "rate_limited", true, { "retry-after": String(RETRY_AFTER_SECONDS) });
    }
    emit(environment, dependencies, { event: "waitlist_dependency_failed", outcome: "abuse_control" });
    return json(503, "dependency_unavailable", true);
  }

  const turnstileSecret = environment.TURNSTILE_SECRET;
  const configuredHostname = environment.TURNSTILE_EXPECTED_HOSTNAME;
  if (
    !configuredResource(environment.TURNSTILE_SITE_KEY_RESOURCE) ||
    !configuredResource(environment.TURNSTILE_SECRET_RESOURCE) ||
    turnstileSecret === undefined || turnstileSecret.length === 0 ||
    configuredHostname !== new URL(trustedOrigin).hostname ||
    environment.TURNSTILE_EXPECTED_ACTION !== "waitlist"
  ) {
    emit(environment, dependencies, { event: "waitlist_turnstile_failed", outcome: "unavailable" });
    return json(503, "dependency_unavailable", true);
  }
  let turnstile: TurnstileVerificationResult;
  try {
    turnstile = await (dependencies.verifyTurnstile ?? verifyTurnstileDefault)({
      token: parsed.value.turnstileToken,
      secret: turnstileSecret,
      expectedHostname: configuredHostname,
      expectedAction: "waitlist",
    });
  } catch {
    turnstile = { ok: false, kind: "unavailable" };
  }
  if (
    turnstile === null ||
    typeof turnstile !== "object" ||
    typeof turnstile.ok !== "boolean" ||
    (!turnstile.ok && turnstile.kind !== "rejected" && turnstile.kind !== "unavailable")
  ) turnstile = { ok: false, kind: "unavailable" };
  if (!turnstile.ok) {
    emit(environment, dependencies, { event: "waitlist_turnstile_failed", outcome: turnstile.kind });
    return turnstile.kind === "rejected"
      ? json(422, "verification_required", true)
      : json(503, "dependency_unavailable", true);
  }

  const databaseUrl = environment.WAITLIST_NEON_URL;
  if (
    !configuredResource(environment.WAITLIST_CREDENTIAL_RESOURCE) ||
    databaseUrl === undefined ||
    !isRuntimeDatabaseCapability(databaseUrl)
  ) {
    emit(environment, dependencies, { event: "waitlist_neon_failed", outcome: "unavailable" });
    return json(503, "dependency_unavailable", true);
  }
  try {
    const repository = (dependencies.repositoryFactory ?? createWaitlistRepository)(databaseUrl);
    const databaseTimeoutMs = Math.max(1, Math.min(
      dependencies.databaseTimeoutMs ?? DEFAULT_DATABASE_TIMEOUT_MS,
      DEFAULT_DATABASE_TIMEOUT_MS,
    ));
    await boundedSubmit(repository, parsed.value.normalizedEmail, parsed.value.noticeVersion, databaseTimeoutMs);
  } catch {
    emit(environment, dependencies, { event: "waitlist_neon_failed", outcome: "unavailable" });
    return json(503, "dependency_unavailable", true);
  }

  emit(environment, dependencies, { event: "waitlist_accepted", outcome: "accepted" });
  return json(202, "accepted", false);
}

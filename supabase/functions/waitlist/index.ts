import { withDatabaseTransaction } from "../../../ritual-investing-api/src/db/database-port.ts";
import { createSupabaseWaitlistDatabasePool } from "../_shared/database.ts";
import { createPostgresRateLimitPort } from "../_shared/rate-limit.ts";

export const WAITLIST_NOTICE_VERSION = "waitlist-v1-2026-08-25";
export const MAX_WAITLIST_REQUEST_BYTES = 4_096;
const MAX_TURNSTILE_TOKEN_BYTES = 2_048;
const TURNSTILE_VERIFY_URL =
  "https://challenges.cloudflare.com/turnstile/v0/siteverify";
const ACTIVE_ORIGINS = new Set([
  "https://just-build-this.app",
  "https://beta.just-build-this.app",
]);

type RatePolicy = Readonly<{ limit: number; windowSeconds: number }>;
type RateOutcome = Readonly<{
  allowed: boolean;
  retryAfterSeconds?: number;
}>;

export type WaitlistRuntime = Readonly<{
  allow(key: string, policy: RatePolicy): Promise<RateOutcome>;
  submit(normalizedEmail: string, noticeVersion: string): Promise<void>;
}>;

export type WaitlistEnvironment = Readonly<{
  WAITLIST_SUBMISSIONS?: string;
  WAITLIST_ALLOWED_ORIGIN?: string;
  WAITLIST_SOURCE_HMAC_KEY?: string;
  TURNSTILE_SECRET?: string;
  TURNSTILE_EXPECTED_HOSTNAME?: string;
  SUPABASE_DB_URL?: string;
}>;

type TurnstileResult =
  | Readonly<{ ok: true }>
  | Readonly<{ ok: false; kind: "rejected" | "unavailable" }>;

export type WaitlistDependencies = Readonly<{
  runtimeFactory?: (databaseUrl: string) => WaitlistRuntime;
  verifyTurnstile?: (input: Readonly<{
    token: string;
    secret: string;
    expectedHostname: string;
  }>) => Promise<TurnstileResult>;
}>;

function secureHeaders(origin?: string): Headers {
  const headers = new Headers({
    "cache-control": "no-store, max-age=0",
    "content-security-policy":
      "default-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; object-src 'none'",
    "content-type": "application/json; charset=utf-8",
    "cross-origin-resource-policy": "cross-origin",
    "permissions-policy":
      "camera=(), geolocation=(), microphone=(), payment=(), usb=()",
    "referrer-policy": "no-referrer",
    "x-content-type-options": "nosniff",
    "x-frame-options": "DENY",
  });
  if (origin !== undefined) {
    headers.set("access-control-allow-origin", origin);
    headers.set("vary", "Origin");
  }
  return headers;
}

function json(
  status: number,
  code: string,
  retryable: boolean,
  origin?: string,
  extra: HeadersInit = {},
): Response {
  const headers = secureHeaders(origin);
  new Headers(extra).forEach((value, name) => headers.set(name, value));
  return new Response(JSON.stringify({ code, retryable }), { status, headers });
}

function validConfiguredOrigin(value: string | undefined): string | null {
  if (value === undefined || !ACTIVE_ORIGINS.has(value)) return null;
  try {
    const parsed = new URL(value);
    if (
      parsed.href !== `${value}/` ||
      parsed.username !== "" ||
      parsed.password !== "" ||
      parsed.search !== "" ||
      parsed.hash !== ""
    ) return null;
    return value;
  } catch {
    return null;
  }
}

function validSource(value: string | null): value is string {
  if (value === null || value.length === 0 || value.length > 45) return false;
  if (/^\d{1,3}(?:\.\d{1,3}){3}$/.test(value)) {
    return value.split(".").every((part) => Number(part) <= 255);
  }
  if (!value.includes(":") || !/^[0-9a-f:.]+$/i.test(value)) return false;
  try {
    new URL(`http://[${value}]/`);
    return true;
  } catch {
    return false;
  }
}

async function hmacHex(secret: string, value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(value),
    ),
  );
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function boundedText(request: Request): Promise<string> {
  const declared = request.headers.get("content-length");
  if (
    declared !== null &&
    (!/^\d{1,10}$/.test(declared) || Number(declared) > MAX_WAITLIST_REQUEST_BYTES)
  ) throw new Error("payload_too_large");
  if (request.body === null) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      length += next.value.byteLength;
      if (length > MAX_WAITLIST_REQUEST_BYTES) {
        await reader.cancel();
        throw new Error("payload_too_large");
      }
      chunks.push(next.value);
    }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } finally {
    try {
      reader.releaseLock();
    } catch {
      // The body has already been rejected and abandoned.
    }
  }
}

type ParsedSubmission = Readonly<{
  normalizedEmail: string;
  noticeVersion: typeof WAITLIST_NOTICE_VERSION;
  turnstileToken: string;
}>;

function parseSubmission(serialized: string):
  | Readonly<{ ok: true; value: ParsedSubmission }>
  | Readonly<{ ok: false; kind: "request" | "consent" | "notice" }> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(serialized);
  } catch {
    return { ok: false, kind: "request" };
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    return { ok: false, kind: "request" };
  }
  const value = parsed as Record<string, unknown>;
  const expected = ["consent", "email", "noticeVersion", "turnstileToken"];
  const fields = Object.keys(value).sort();
  if (
    fields.length !== expected.length ||
    fields.some((field, index) => field !== expected[index])
  ) return { ok: false, kind: "request" };

  if (
    typeof value.email !== "string" ||
    typeof value.turnstileToken !== "string" ||
    typeof value.noticeVersion !== "string" ||
    typeof value.consent !== "boolean"
  ) return { ok: false, kind: "request" };
  const normalizedEmail = value.email.trim().toLowerCase();
  if (
    normalizedEmail.length < 3 ||
    normalizedEmail.length > 254 ||
    normalizedEmail.includes("\0") ||
    !/^[^\s@]+@[^\s@]+$/.test(normalizedEmail) ||
    value.turnstileToken.length === 0 ||
    new TextEncoder().encode(value.turnstileToken).byteLength >
      MAX_TURNSTILE_TOKEN_BYTES
  ) return { ok: false, kind: "request" };
  if (value.consent !== true) return { ok: false, kind: "consent" };
  if (value.noticeVersion !== WAITLIST_NOTICE_VERSION) {
    return { ok: false, kind: "notice" };
  }
  return {
    ok: true,
    value: {
      normalizedEmail,
      noticeVersion: WAITLIST_NOTICE_VERSION,
      turnstileToken: value.turnstileToken,
    },
  };
}

async function verifyTurnstile(input: Readonly<{
  token: string;
  secret: string;
  expectedHostname: string;
}>): Promise<TurnstileResult> {
  const idempotencyKey = crypto.randomUUID();
  const body = new URLSearchParams({
    secret: input.secret,
    response: input.token,
    idempotency_key: idempotencyKey,
  });
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2_500);
    try {
      const response = await fetch(TURNSTILE_VERIFY_URL, {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: body.toString(),
        signal: controller.signal,
      });
      const payload: unknown = await response.json();
      if (
        !response.ok || payload === null || typeof payload !== "object" ||
        Array.isArray(payload)
      ) {
        if (response.status >= 500 && attempt === 0) continue;
        return { ok: false, kind: "unavailable" };
      }
      const result = payload as Record<string, unknown>;
      if (
        Array.isArray(result["error-codes"]) &&
        result["error-codes"].includes("internal-error")
      ) {
        if (attempt === 0) continue;
        return { ok: false, kind: "unavailable" };
      }
      return result.success === true &&
          result.hostname === input.expectedHostname &&
          result.action === "waitlist"
        ? { ok: true }
        : { ok: false, kind: "rejected" };
    } catch {
      if (attempt === 0) continue;
      return { ok: false, kind: "unavailable" };
    } finally {
      clearTimeout(timeout);
    }
  }
  return { ok: false, kind: "unavailable" };
}

function createRuntime(databaseUrl: string): WaitlistRuntime {
  const pool = createSupabaseWaitlistDatabasePool(databaseUrl);
  const rateLimit = createPostgresRateLimitPort(pool, "argus_waitlist");
  return Object.freeze({
    allow: (key: string, policy: RatePolicy) => rateLimit.allow(key, policy),
    submit: (normalizedEmail: string, noticeVersion: string) =>
      withDatabaseTransaction(pool, "argus_waitlist", async (database) => {
        await database.query(
          "select argus_private.submit_waitlist($1::text, $2::text)",
          [normalizedEmail, noticeVersion],
        );
      }),
  });
}

async function deadline<T>(operation: Promise<T>, milliseconds: number): Promise<T> {
  let timeout: number | undefined;
  const expired = new Promise<never>((_resolve, reject) => {
    timeout = setTimeout(() => reject(new Error("dependency_timeout")), milliseconds);
  });
  try {
    return await Promise.race([operation, expired]);
  } finally {
    if (timeout !== undefined) clearTimeout(timeout);
  }
}

export function createWaitlistHandler(
  environment: WaitlistEnvironment,
  dependencies: WaitlistDependencies = {},
): (request: Request) => Promise<Response> {
  return async (request) => {
    const allowedOrigin = validConfiguredOrigin(
      environment.WAITLIST_ALLOWED_ORIGIN,
    );
    if (allowedOrigin === null) {
      return json(503, "waitlist_unavailable", true);
    }
    if (request.headers.get("origin") !== allowedOrigin) {
      return json(403, "request_not_allowed", false);
    }
    if (environment.WAITLIST_SUBMISSIONS !== "on") {
      return json(503, "waitlist_unavailable", true, allowedOrigin);
    }
    if (request.method === "OPTIONS") {
      const headers = secureHeaders(allowedOrigin);
      headers.set("access-control-allow-methods", "POST, OPTIONS");
      headers.set("access-control-allow-headers", "content-type");
      headers.set("access-control-max-age", "600");
      headers.delete("content-type");
      return new Response(null, { status: 204, headers });
    }
    if (request.method !== "POST") {
      return json(405, "method_not_allowed", false, allowedOrigin, {
        allow: "POST, OPTIONS",
      });
    }
    const contentEncoding = request.headers.get("content-encoding")
      ?.toLowerCase();
    if (
      request.headers.get("content-type")?.toLowerCase() !==
        "application/json" ||
      (contentEncoding !== undefined && contentEncoding !== "identity")
    ) {
      return json(415, "unsupported_media_type", false, allowedOrigin);
    }

    let serialized: string;
    try {
      serialized = await boundedText(request);
    } catch (error) {
      return json(
        error instanceof Error && error.message === "payload_too_large"
          ? 413
          : 400,
        error instanceof Error && error.message === "payload_too_large"
          ? "payload_too_large"
          : "invalid_request",
        false,
        allowedOrigin,
      );
    }
    const parsed = parseSubmission(serialized);
    if (!parsed.ok) {
      if (parsed.kind === "notice") {
        return json(409, "stale_notice", false, allowedOrigin);
      }
      return json(
        400,
        parsed.kind === "consent" ? "consent_required" : "invalid_request",
        false,
        allowedOrigin,
      );
    }

    const source = request.headers.get("cf-connecting-ip");
    const hmacSecret = environment.WAITLIST_SOURCE_HMAC_KEY;
    const turnstileSecret = environment.TURNSTILE_SECRET;
    const expectedHostname = environment.TURNSTILE_EXPECTED_HOSTNAME;
    const databaseUrl = environment.SUPABASE_DB_URL;
    if (
      !validSource(source) || hmacSecret === undefined ||
      new TextEncoder().encode(hmacSecret).byteLength < 32 ||
      new TextEncoder().encode(hmacSecret).byteLength > 128 ||
      turnstileSecret === undefined || turnstileSecret.length === 0 ||
      expectedHostname !== new URL(allowedOrigin).hostname ||
      databaseUrl === undefined || databaseUrl.length === 0
    ) {
      return json(503, "dependency_unavailable", true, allowedOrigin);
    }

    let runtime: WaitlistRuntime;
    try {
      runtime = (dependencies.runtimeFactory ?? createRuntime)(databaseUrl);
      const sourceKey = await hmacHex(
        hmacSecret,
        `argus:waitlist:source:v1:${allowedOrigin}:${source}`,
      );
      const routeKey = await hmacHex(
        hmacSecret,
        `argus:waitlist:route:v1:${allowedOrigin}`,
      );
      const sourceLimit = await deadline(
        runtime.allow(sourceKey, { limit: 5, windowSeconds: 60 }),
        1_000,
      );
      if (!sourceLimit.allowed) {
        return json(429, "rate_limited", true, allowedOrigin, {
          "retry-after": String(sourceLimit.retryAfterSeconds ?? 60),
        });
      }
      const routeLimit = await deadline(
        runtime.allow(routeKey, { limit: 60, windowSeconds: 60 }),
        1_000,
      );
      if (!routeLimit.allowed) {
        return json(429, "rate_limited", true, allowedOrigin, {
          "retry-after": String(routeLimit.retryAfterSeconds ?? 60),
        });
      }
    } catch {
      return json(503, "dependency_unavailable", true, allowedOrigin);
    }

    let turnstile: TurnstileResult;
    try {
      turnstile = await (dependencies.verifyTurnstile ?? verifyTurnstile)({
        token: parsed.value.turnstileToken,
        secret: turnstileSecret,
        expectedHostname,
      });
    } catch {
      turnstile = { ok: false, kind: "unavailable" };
    }
    if (!turnstile.ok) {
      return turnstile.kind === "rejected"
        ? json(422, "verification_required", true, allowedOrigin)
        : json(503, "dependency_unavailable", true, allowedOrigin);
    }

    try {
      await deadline(
        runtime.submit(
          parsed.value.normalizedEmail,
          parsed.value.noticeVersion,
        ),
        3_000,
      );
    } catch {
      return json(503, "dependency_unavailable", true, allowedOrigin);
    }
    return json(202, "accepted", false, allowedOrigin);
  };
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (value === undefined || value.length === 0) {
    throw new Error("waitlist_configuration_missing");
  }
  return value;
}

if (import.meta.main) {
  Deno.serve(createWaitlistHandler({
    WAITLIST_SUBMISSIONS: Deno.env.get("WAITLIST_SUBMISSIONS"),
    WAITLIST_ALLOWED_ORIGIN: requiredEnvironment("WAITLIST_ALLOWED_ORIGIN"),
    WAITLIST_SOURCE_HMAC_KEY: requiredEnvironment(
      "WAITLIST_SOURCE_HMAC_KEY",
    ),
    TURNSTILE_SECRET: requiredEnvironment("TURNSTILE_SECRET"),
    TURNSTILE_EXPECTED_HOSTNAME: requiredEnvironment(
      "TURNSTILE_EXPECTED_HOSTNAME",
    ),
    SUPABASE_DB_URL: requiredEnvironment("SUPABASE_DB_URL"),
  }));
}

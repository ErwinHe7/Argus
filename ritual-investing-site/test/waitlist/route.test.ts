import { describe, expect, it, vi } from "vitest";

import type { RuntimeSiteEnv, SiteEnv } from "../../src/config.ts";
import { handleWaitlistRequest, type WaitlistRouteDependencies } from "../../src/waitlist/route.ts";

const ORIGIN = "https://just-build-this.app";
const NOTICE = "waitlist-v1-2026-08-25";
const EMAIL = "  Visitor+ritual@example.com ";
const TOKEN = "synthetic-turnstile-token";

function rateLimit(success = true): SiteEnv["WAITLIST_SOURCE_RATE_LIMIT"] {
  return { limit: vi.fn(async () => ({ success })) };
}

function environment(overrides: Partial<RuntimeSiteEnv> = {}): RuntimeSiteEnv {
  return {
    ASSETS: { fetch: vi.fn(), connect: vi.fn() } as unknown as SiteEnv["ASSETS"],
    ENVIRONMENT: "production",
    PUBLIC_ORIGIN: ORIGIN,
    WAITLIST_SUBMISSIONS: "on",
    WAITLIST_SOURCE_RATE_LIMIT: rateLimit(),
    WAITLIST_ROUTE_RATE_LIMIT: rateLimit(),
    WAITLIST_SOURCE_KEY_RESOURCE: "ritual-waitlist-prod-source-hmac-v1",
    WAITLIST_SOURCE_HMAC_KEY: "synthetic-source-key-with-enough-entropy",
    TURNSTILE_EXPECTED_HOSTNAME: "just-build-this.app",
    TURNSTILE_EXPECTED_ACTION: "waitlist",
    TURNSTILE_SITE_KEY_RESOURCE: "ritual-waitlist-prod-site-key-v1",
    TURNSTILE_SECRET_RESOURCE: "ritual-waitlist-prod-turnstile-secret-v1",
    TURNSTILE_SECRET: "synthetic-turnstile-secret",
    WAITLIST_CREDENTIAL_RESOURCE: "ritual-waitlist-prod-runtime-url-v1",
    WAITLIST_NEON_URL: "postgresql://waitlist_runtime:synthetic-password@runtime.invalid/waitlist",
    WAITLIST_WAF_BUDGET_RESOURCE: "ritual-waitlist-prod-budget-v1",
    WAITLIST_WAF_CEILING_RESOURCE: "ritual-waitlist-prod-budget-1m",
    ...overrides,
  };
}

function body(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    email: EMAIL,
    consent: true,
    noticeVersion: NOTICE,
    turnstileToken: TOKEN,
    ...overrides,
  };
}

function request(options: {
  url?: string;
  method?: string;
  origin?: string;
  contentType?: string;
  body?: string;
  headers?: Record<string, string>;
  source?: string | null;
  stream?: ReadableStream<Uint8Array>;
} = {}): Request {
  const headers = new Headers({
    Origin: options.origin ?? ORIGIN,
    "Content-Type": options.contentType ?? "application/json",
    ...options.headers,
  });
  if (options.source !== null) headers.set("CF-Connecting-IP", options.source ?? "192.0.2.123");
  return new Request(options.url ?? `${ORIGIN}/api/waitlist`, {
    method: options.method ?? "POST",
    headers,
    body: options.method === "GET" || options.method === "HEAD"
      ? undefined
      : (options.stream ?? options.body ?? JSON.stringify(body())),
    ...(options.stream === undefined ? {} : { duplex: "half" }),
  } as RequestInit);
}

function dependencies() {
  const submit = vi.fn(async () => undefined);
  const verifyTurnstile = vi.fn(async () => ({ ok: true as const }));
  const telemetry: unknown[] = [];
  const repositoryFactory = vi.fn(() => ({ submit }));
  const deps: WaitlistRouteDependencies = {
    verifyTurnstile,
    repositoryFactory,
    emit: (point) => telemetry.push(point),
  };
  return { deps, submit, verifyTurnstile, repositoryFactory, telemetry };
}

async function json(response: Response): Promise<unknown> {
  return response.json();
}

describe("ordered fail-closed waitlist route", () => {
  it("returns a byte-equivalent generic receipt for every accepted repository completion", async () => {
    const first = dependencies();
    const duplicate = dependencies();

    const firstResponse = await handleWaitlistRequest(request(), environment(), first.deps);
    const duplicateResponse = await handleWaitlistRequest(request(), environment(), duplicate.deps);

    expect(firstResponse.status).toBe(202);
    expect(duplicateResponse.status).toBe(202);
    expect(await firstResponse.text()).toBe(await duplicateResponse.text());
    expect(first.submit).toHaveBeenCalledWith("visitor+ritual@example.com", NOTICE);
    expect(duplicate.submit).toHaveBeenCalledWith("visitor+ritual@example.com", NOTICE);
    expect(first.telemetry).toEqual([{ event: "waitlist_accepted", outcome: "accepted" }]);
    expect(JSON.stringify(first.telemetry)).not.toContain("visitor");
  });

  it("keeps the kill switch outside the active pipeline", async () => {
    const calls = dependencies();
    const env = environment({ WAITLIST_SUBMISSIONS: "off" });
    const response = await handleWaitlistRequest(request(), env, calls.deps);
    expect(response.status).toBe(503);
    expect(await json(response)).toEqual({ code: "waitlist_unavailable", retryable: true });
    expect(calls.verifyTurnstile).not.toHaveBeenCalled();
    expect(calls.repositoryFactory).not.toHaveBeenCalled();
    expect(env.WAITLIST_SOURCE_RATE_LIMIT?.limit).not.toHaveBeenCalled();
    expect(env.WAITLIST_ROUTE_RATE_LIMIT?.limit).not.toHaveBeenCalled();
  });

  it("fails closed before the active pipeline when pairwise activation configuration drifts", async () => {
    const calls = dependencies();
    const env = environment({ PUBLIC_ORIGIN: "https://beta.just-build-this.app" });
    const response = await handleWaitlistRequest(request(), env, calls.deps);
    expect(response.status).toBe(503);
    expect(env.WAITLIST_SOURCE_RATE_LIMIT?.limit).not.toHaveBeenCalled();
    expect(calls.verifyTurnstile).not.toHaveBeenCalled();
    expect(calls.repositoryFactory).not.toHaveBeenCalled();
    expect(calls.telemetry).toEqual([{ event: "waitlist_dependency_failed", outcome: "configuration" }]);
  });

  it("classifies missing resources at their owning gate", async () => {
    const abuse = dependencies();
    const abuseEnv = environment({ WAITLIST_WAF_BUDGET_RESOURCE: undefined });
    expect((await handleWaitlistRequest(request(), abuseEnv, abuse.deps)).status).toBe(503);
    expect(abuseEnv.WAITLIST_SOURCE_RATE_LIMIT?.limit).not.toHaveBeenCalled();
    expect(abuse.telemetry).toEqual([{ event: "waitlist_dependency_failed", outcome: "abuse_control" }]);

    const turnstile = dependencies();
    const turnstileEnv = environment({ TURNSTILE_SECRET_RESOURCE: undefined });
    expect((await handleWaitlistRequest(request(), turnstileEnv, turnstile.deps)).status).toBe(503);
    expect(turnstileEnv.WAITLIST_SOURCE_RATE_LIMIT?.limit).toHaveBeenCalledOnce();
    expect(turnstile.verifyTurnstile).not.toHaveBeenCalled();
    expect(turnstile.telemetry).toEqual([{ event: "waitlist_turnstile_failed", outcome: "unavailable" }]);

    const neon = dependencies();
    const neonEnv = environment({ WAITLIST_CREDENTIAL_RESOURCE: undefined });
    expect((await handleWaitlistRequest(request(), neonEnv, neon.deps)).status).toBe(503);
    expect(neon.verifyTurnstile).toHaveBeenCalledOnce();
    expect(neon.repositoryFactory).not.toHaveBeenCalled();
    expect(neon.telemetry).toEqual([{ event: "waitlist_neon_failed", outcome: "unavailable" }]);
  });

  it.each([
    ["origin", request({ origin: "https://hostile.example" }), environment(), 403, "origin"],
    ["host", request({ url: "https://other.example/api/waitlist" }), environment(), 403, "host"],
    ["method", request({ method: "GET" }), environment(), 405, "method"],
    ["media", request({ contentType: "text/plain" }), environment(), 415, "media"],
    ["encoding", request({ headers: { "Content-Encoding": "gzip" } }), environment(), 415, "media"],
    ["body", request({ body: "x".repeat(4097) }), environment(), 413, "body"],
    ["schema-json", request({ body: "{" }), environment(), 400, "schema"],
    ["schema-fields", request({ body: JSON.stringify(body({ extra: "forbidden" })) }), environment(), 400, "schema"],
    ["schema-email", request({ body: JSON.stringify(body({ email: "invalid" })) }), environment(), 400, "schema"],
    ["consent", request({ body: JSON.stringify(body({ consent: false })) }), environment(), 400, "consent"],
    ["notice", request({ body: JSON.stringify(body({ noticeVersion: "waitlist-v0-2020-01-01" })) }), environment(), 409, "notice"],
  ])("rejects the %s gate before any abuse, Turnstile, or Neon call", async (_name, incoming, env, status, outcome) => {
    const calls = dependencies();
    const response = await handleWaitlistRequest(incoming, env, calls.deps);
    expect(response.status).toBe(status);
    expect(env.WAITLIST_SOURCE_RATE_LIMIT?.limit).not.toHaveBeenCalled();
    expect(env.WAITLIST_ROUTE_RATE_LIMIT?.limit).not.toHaveBeenCalled();
    expect(calls.verifyTurnstile).not.toHaveBeenCalled();
    expect(calls.repositoryFactory).not.toHaveBeenCalled();
    expect(calls.telemetry).toContainEqual({ event: "waitlist_validation_failed", outcome });
  });

  it("cancels an oversized chunked multibyte body without buffering the remainder", async () => {
    const cancel = vi.fn();
    const chunks = [
      new TextEncoder().encode("é".repeat(1_500)),
      new TextEncoder().encode("é".repeat(1_500)),
      new TextEncoder().encode("never-read"),
    ];
    const stream = new ReadableStream<Uint8Array>({
      pull(controller) {
        const chunk = chunks.shift();
        if (chunk === undefined) controller.close();
        else controller.enqueue(chunk);
      },
      cancel,
    });
    const calls = dependencies();
    const response = await handleWaitlistRequest(request({ stream }), environment(), calls.deps);
    expect(response.status).toBe(413);
    expect(cancel).toHaveBeenCalledOnce();
    expect(chunks).toEqual([new TextEncoder().encode("never-read")]);
    expect(calls.verifyTurnstile).not.toHaveBeenCalled();
    expect(calls.repositoryFactory).not.toHaveBeenCalled();
  });

  it("checks source then route rate limits using only pseudonymous keys", async () => {
    const order: string[] = [];
    const source = { limit: vi.fn(async ({ key }: { key: string }) => {
      order.push("source");
      expect(key).not.toContain("192.0.2.123");
      expect(key).toMatch(/^[A-Za-z0-9_-]{43}$/);
      return { success: true };
    }) } as SiteEnv["WAITLIST_SOURCE_RATE_LIMIT"];
    const route = { limit: vi.fn(async ({ key }: { key: string }) => {
      order.push("route");
      expect(key).toBe("waitlist:production:v1");
      return { success: true };
    }) } as SiteEnv["WAITLIST_ROUTE_RATE_LIMIT"];
    const calls = dependencies();
    calls.deps.verifyTurnstile = vi.fn(async () => (order.push("turnstile"), { ok: true as const }));
    calls.deps.repositoryFactory = vi.fn(() => ({ submit: vi.fn(async () => { order.push("neon"); }) }));

    const response = await handleWaitlistRequest(request(), environment({
      WAITLIST_SOURCE_RATE_LIMIT: source,
      WAITLIST_ROUTE_RATE_LIMIT: route,
    }), calls.deps);

    expect(response.status).toBe(202);
    expect(order).toEqual(["source", "route", "turnstile", "neon"]);
  });

  it.each([
    ["source denied", rateLimit(false), rateLimit(true), 429, "source"],
    ["route denied", rateLimit(true), rateLimit(false), 429, "route"],
    ["source binding absent", undefined, rateLimit(true), 503, "abuse_control"],
    ["route binding absent", rateLimit(true), undefined, 503, "abuse_control"],
  ])("fails closed when %s", async (_name, source, route, expectedStatus, outcome) => {
    const calls = dependencies();
    const response = await handleWaitlistRequest(request(), environment({
      WAITLIST_SOURCE_RATE_LIMIT: source,
      WAITLIST_ROUTE_RATE_LIMIT: route,
    }), calls.deps);
    expect(response.status).toBe(expectedStatus);
    expect(response.headers.get("retry-after")).toBe(expectedStatus === 429 ? "60" : null);
    expect(calls.verifyTurnstile).not.toHaveBeenCalled();
    expect(calls.repositoryFactory).not.toHaveBeenCalled();
    expect(calls.telemetry).toContainEqual(expectedStatus === 429
      ? { event: "waitlist_throttled", outcome }
      : { event: "waitlist_dependency_failed", outcome });
    if (outcome === "route") {
      expect(calls.telemetry).toContainEqual({ event: "waitlist_budget_alert", outcome: "route_ceiling" });
    }
  });

  it("fails closed when a rate binding throws", async () => {
    const calls = dependencies();
    const throwing = { limit: vi.fn(async () => { throw new Error("raw IP UA email token"); }) } as SiteEnv["WAITLIST_SOURCE_RATE_LIMIT"];
    const response = await handleWaitlistRequest(request(), environment({ WAITLIST_SOURCE_RATE_LIMIT: throwing }), calls.deps);
    expect(response.status).toBe(503);
    expect(JSON.stringify(await json(response))).not.toMatch(/raw|ip|ua|email|token/i);
    expect(calls.verifyTurnstile).not.toHaveBeenCalled();
    expect(calls.repositoryFactory).not.toHaveBeenCalled();
  });

  it("bounds a rate-binding outage before Turnstile and Neon", async () => {
    const calls = dependencies();
    calls.deps.abuseTimeoutMs = 2;
    const hanging = { limit: vi.fn(() => new Promise<{ success: boolean }>(() => undefined)) } as SiteEnv["WAITLIST_SOURCE_RATE_LIMIT"];
    const response = await handleWaitlistRequest(request(), environment({ WAITLIST_SOURCE_RATE_LIMIT: hanging }), calls.deps);
    expect(response.status).toBe(503);
    expect(calls.verifyTurnstile).not.toHaveBeenCalled();
    expect(calls.repositoryFactory).not.toHaveBeenCalled();
  });

  it.each([
    ["missing source", null, "synthetic-source-key-with-enough-entropy"],
    ["malformed source", "not-an-ip", "synthetic-source-key-with-enough-entropy"],
    ["oversized source", "1".repeat(129), "synthetic-source-key-with-enough-entropy"],
    ["short HMAC key bytes", "192.0.2.123", "é".repeat(15)],
  ])("fails closed for %s before either rate binding", async (_name, source, key) => {
    const calls = dependencies();
    const env = environment({ WAITLIST_SOURCE_HMAC_KEY: key });
    const response = await handleWaitlistRequest(request({ source }), env, calls.deps);
    expect(response.status).toBe(503);
    expect(env.WAITLIST_SOURCE_RATE_LIMIT?.limit).not.toHaveBeenCalled();
    expect(env.WAITLIST_ROUTE_RATE_LIMIT?.limit).not.toHaveBeenCalled();
    expect(calls.verifyTurnstile).not.toHaveBeenCalled();
    expect(calls.repositoryFactory).not.toHaveBeenCalled();
  });

  it.each([
    ["rejected", 422],
    ["unavailable", 503],
  ] as const)("does not call Neon after Turnstile is %s", async (kind, status) => {
    const calls = dependencies();
    calls.deps.verifyTurnstile = vi.fn(async () => ({ ok: false, kind }));
    const response = await handleWaitlistRequest(request(), environment(), calls.deps);
    expect(response.status).toBe(status);
    expect(await json(response)).toEqual({
      code: kind === "rejected" ? "verification_required" : "dependency_unavailable",
      retryable: true,
    });
    expect(calls.repositoryFactory).not.toHaveBeenCalled();
    expect(calls.telemetry).toContainEqual({ event: "waitlist_turnstile_failed", outcome: kind });
  });

  it("sanitizes an unexpected verifier exception and does not call Neon", async () => {
    const calls = dependencies();
    calls.deps.verifyTurnstile = vi.fn(async () => { throw new Error("token email provider payload"); });
    const response = await handleWaitlistRequest(request(), environment(), calls.deps);
    expect(response.status).toBe(503);
    expect(await json(response)).toEqual({ code: "dependency_unavailable", retryable: true });
    expect(calls.repositoryFactory).not.toHaveBeenCalled();
    expect(calls.telemetry).toEqual([{ event: "waitlist_turnstile_failed", outcome: "unavailable" }]);
  });

  it.each([
    ["missing Turnstile secret", { TURNSTILE_SECRET: undefined }, "turnstile"],
    ["missing Neon secret", { WAITLIST_NEON_URL: undefined }, "neon"],
  ])("returns a sanitized 503 for %s", async (_name, override, dependency) => {
    const calls = dependencies();
    const response = await handleWaitlistRequest(request(), environment(override), calls.deps);
    expect(response.status).toBe(503);
    expect(await json(response)).toEqual({ code: "dependency_unavailable", retryable: true });
    expect(JSON.stringify(calls.telemetry)).not.toMatch(/@|token|sql|postgres|connection/i);
    if (dependency === "turnstile") expect(calls.verifyTurnstile).not.toHaveBeenCalled();
    if (dependency === "neon") expect(calls.repositoryFactory).not.toHaveBeenCalled();
  });

  it.each([
    "postgresql://waitlist_owner:synthetic-password@runtime.invalid/waitlist",
    "postgresql://waitlist_maintenance:synthetic-password@runtime.invalid/waitlist",
    "postgresql://waitlist_runtime:synthetic-password@/waitlist",
    "postgresql://waitlist_runtime:synthetic-password@runtime.invalid/",
    "postgresql://waitlist_runtime:synthetic-password@runtime.invalid/waitlist?user=waitlist_owner",
    "not-a-database-url",
  ])("rejects a non-runtime Neon capability without constructing a repository", async (databaseUrl) => {
    const calls = dependencies();
    const response = await handleWaitlistRequest(request(), environment({ WAITLIST_NEON_URL: databaseUrl }), calls.deps);
    expect(response.status).toBe(503);
    const serialized = JSON.stringify(await json(response.clone()));
    expect(await json(response)).toEqual({ code: "dependency_unavailable", retryable: true });
    expect(calls.repositoryFactory).not.toHaveBeenCalled();
    expect(calls.telemetry).toEqual([{ event: "waitlist_neon_failed", outcome: "unavailable" }]);
    expect(serialized).not.toMatch(/owner|maintenance|runtime\.invalid|postgres/i);
  });

  it("sanitizes Neon rejection and timeout without classifying the write outcome", async () => {
    for (const submit of [
      vi.fn(async () => { throw new Error("email token SQL connection URL"); }),
      vi.fn(() => new Promise<void>(() => undefined)),
    ]) {
      const calls = dependencies();
      calls.deps.databaseTimeoutMs = 2;
      calls.deps.repositoryFactory = vi.fn(() => ({ submit }));
      const response = await handleWaitlistRequest(request(), environment(), calls.deps);
      expect(response.status).toBe(503);
      expect(await json(response)).toEqual({ code: "dependency_unavailable", retryable: true });
      expect(calls.telemetry).toEqual([{ event: "waitlist_neon_failed", outcome: "unavailable" }]);
      expect(JSON.stringify(calls.telemetry)).not.toMatch(/email|token|sql|connection|url/i);
    }
  });

  it("retries safely with a fresh token after a committed write loses its response", async () => {
    const submit = vi.fn()
      .mockImplementationOnce(() => new Promise<void>(() => undefined))
      .mockResolvedValueOnce(undefined);
    const calls = dependencies();
    calls.deps.databaseTimeoutMs = 2;
    calls.deps.repositoryFactory = vi.fn(() => ({ submit }));

    const lost = await handleWaitlistRequest(
      request({ body: JSON.stringify(body({ turnstileToken: "fresh-token-one" })) }),
      environment(),
      calls.deps,
    );
    const retried = await handleWaitlistRequest(
      request({ body: JSON.stringify(body({ turnstileToken: "fresh-token-two" })) }),
      environment(),
      calls.deps,
    );

    expect(lost.status).toBe(503);
    expect(retried.status).toBe(202);
    expect(submit).toHaveBeenCalledTimes(2);
    expect(calls.deps.verifyTurnstile).toHaveBeenNthCalledWith(1, expect.objectContaining({ token: "fresh-token-one" }));
    expect(calls.deps.verifyTurnstile).toHaveBeenNthCalledWith(2, expect.objectContaining({ token: "fresh-token-two" }));
    expect(calls.telemetry).toEqual([
      { event: "waitlist_neon_failed", outcome: "unavailable" },
      { event: "waitlist_accepted", outcome: "accepted" },
    ]);
  });

  it("does not read or log raw user-agent and custom headers", async () => {
    const calls = dependencies();
    const consoleSpies = [
      vi.spyOn(console, "log").mockImplementation(() => undefined),
      vi.spyOn(console, "error").mockImplementation(() => undefined),
      vi.spyOn(console, "warn").mockImplementation(() => undefined),
    ];
    const response = await handleWaitlistRequest(request({ headers: {
      "User-Agent": "private-user-agent",
      "X-Private-Visitor": "private-custom-header",
    } }), environment(), calls.deps);
    expect(response.status).toBe(202);
    expect(consoleSpies.every((spy) => spy.mock.calls.length === 0)).toBe(true);
    expect(JSON.stringify(calls.telemetry)).not.toMatch(/private|visitor|agent|header/i);
    for (const spy of consoleSpies) spy.mockRestore();
  });
});

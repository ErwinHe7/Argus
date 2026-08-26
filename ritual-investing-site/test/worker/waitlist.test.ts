import { describe, expect, it, vi } from "vitest";

import { createWorker, type RuntimeSiteEnv, type SiteEnv } from "../../src/index.ts";

function env(environment: "production" | "beta" = "production"): RuntimeSiteEnv {
  const production = environment === "production";
  return {
    ASSETS: { fetch: vi.fn(async () => new Response("asset")), connect: vi.fn() } as unknown as SiteEnv["ASSETS"],
    ENVIRONMENT: environment,
    PUBLIC_ORIGIN: production ? "https://just-build-this.app" : "https://beta.just-build-this.app",
    WAITLIST_SUBMISSIONS: "on",
    WAITLIST_SOURCE_RATE_LIMIT: { limit: vi.fn(async () => ({ success: true })) },
    WAITLIST_ROUTE_RATE_LIMIT: { limit: vi.fn(async () => ({ success: true })) },
    WAITLIST_SOURCE_KEY_RESOURCE: production
      ? "ritual-waitlist-prod-source-hmac-v1"
      : "ritual-waitlist-beta-source-hmac-v1",
    WAITLIST_SOURCE_HMAC_KEY: "synthetic-source-key-with-enough-entropy",
    TURNSTILE_EXPECTED_HOSTNAME: production ? "just-build-this.app" : "beta.just-build-this.app",
    TURNSTILE_EXPECTED_ACTION: "waitlist",
    TURNSTILE_SITE_KEY_RESOURCE: production ? "ritual-waitlist-prod-site-key-v1" : "ritual-waitlist-beta-site-key-v1",
    TURNSTILE_SECRET_RESOURCE: production ? "ritual-waitlist-prod-turnstile-secret-v1" : "ritual-waitlist-beta-turnstile-secret-v1",
    TURNSTILE_SECRET: "synthetic-secret",
    WAITLIST_CREDENTIAL_RESOURCE: production ? "ritual-waitlist-prod-runtime-url-v1" : "ritual-waitlist-beta-runtime-url-v1",
    WAITLIST_NEON_URL: "postgresql://waitlist_runtime:synthetic-password@runtime.invalid/waitlist",
    WAITLIST_WAF_BUDGET_RESOURCE: production ? "ritual-waitlist-prod-budget-v1" : "ritual-waitlist-beta-budget-v1",
    WAITLIST_WAF_CEILING_RESOURCE: production ? "ritual-waitlist-prod-budget-1m" : "ritual-waitlist-beta-budget-1m",
  };
}

function submission(origin: string): Request {
  return new Request(`${origin}/api/waitlist`, {
    method: "POST",
    headers: {
      Origin: origin,
      "Content-Type": "application/json",
      "CF-Connecting-IP": "192.0.2.10",
    },
    body: JSON.stringify({
      email: "visitor@example.com",
      consent: true,
      noticeVersion: "waitlist-v1-2026-08-25",
      turnstileToken: "synthetic-token",
    }),
  });
}

describe("waitlist Worker integration", () => {
  it.each([
    ["production", "https://just-build-this.app"],
    ["beta", "https://beta.just-build-this.app"],
  ] as const)("accepts only the %s environment contract", async (environment, origin) => {
    const submit = vi.fn(async () => undefined);
    const worker = createWorker({ waitlist: {
      verifyTurnstile: vi.fn(async (input) => {
        expect(input.expectedHostname).toBe(new URL(origin).hostname);
        expect(input.expectedAction).toBe("waitlist");
        return { ok: true as const };
      }),
      repositoryFactory: () => ({ submit }),
    } });

    const response = await worker.fetch(submission(origin), env(environment), {} as ExecutionContext);
    expect(response.status).toBe(202);
    expect(submit).toHaveBeenCalledWith("visitor@example.com", "waitlist-v1-2026-08-25");
  });

  it("rejects a cross-origin preflight and POST without serving assets", async () => {
    const environment = env();
    const worker = createWorker({ waitlist: {
      verifyTurnstile: vi.fn(),
      repositoryFactory: vi.fn(),
    } });
    const preflight = await worker.fetch(new Request("https://just-build-this.app/api/waitlist", {
      method: "OPTIONS",
      headers: { Origin: "https://hostile.example", "Access-Control-Request-Method": "POST" },
    }), environment, {} as ExecutionContext);
    const post = await worker.fetch(submission("https://hostile.example"), environment, {} as ExecutionContext);
    expect(preflight.status).toBe(403);
    expect(post.status).toBe(403);
    expect(preflight.headers.get("access-control-allow-origin")).toBeNull();
    expect(post.headers.get("access-control-allow-origin")).toBeNull();
    expect(environment.ASSETS.fetch).not.toHaveBeenCalled();
  });

  it("keeps landing assets available while submissions are disabled", async () => {
    const environment = env();
    environment.WAITLIST_SUBMISSIONS = "off";
    const worker = createWorker({ waitlist: {
      verifyTurnstile: vi.fn(),
      repositoryFactory: vi.fn(),
    } });
    const unavailable = await worker.fetch(submission("https://just-build-this.app"), environment, {} as ExecutionContext);
    const landing = await worker.fetch(new Request("https://just-build-this.app/"), environment, {} as ExecutionContext);
    expect(unavailable.status).toBe(503);
    expect(await landing.text()).toBe("asset");
  });
});

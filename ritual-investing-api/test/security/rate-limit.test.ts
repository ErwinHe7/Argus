import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { Hono } from "hono";
import { preAuthRateLimit } from "../../src/middleware/rate-limit";
import { requestContext } from "../../src/middleware/request-context";
import { createTestRsaKey } from "../support/jwt";
import {
  fakeRateLimit,
  memberToken,
  sessionSnapshot,
  testBindings,
} from "../support/security-fixtures";

describe("binding-backed rate limits", () => {
  const auth0Key = createTestRsaKey("rate-key");

  it("limits before the repository and returns stable retry metadata", async () => {
    const limiter = fakeRateLimit([false]);
    const bootstrap = vi.fn(async () => sessionSnapshot);
    const response = await createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        sessionRepository: { bootstrap },
      },
    } as never).request("/v1/session/bootstrap", {
      method: "POST",
      headers: {
        authorization: `Bearer ${memberToken(auth0Key)}`,
        "cf-connecting-ip": "203.0.113.42",
      },
    }, testBindings(limiter));

    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBe("60");
    await expect(response.json()).resolves.toMatchObject({
      error: { code: "rate_limited", retry_after_seconds: 60, retryable: true },
    });
    expect(bootstrap).not.toHaveBeenCalled();
  });

  it("fails sensitive traffic closed when the binding throws", async () => {
    const limiter = fakeRateLimit([new Error("binding unavailable")]);
    const response = await createApp({
      dependencies: { auth0Keys: [auth0Key.publicJwk] },
    } as never).request("/v1/session/bootstrap", {
      method: "POST",
      headers: { authorization: `Bearer ${memberToken(auth0Key)}` },
    }, testBindings(limiter));

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toMatchObject({
      error: { code: "service_unavailable", retryable: true },
    });
  });

  it("uses pseudonymous route and verified-subject keys", async () => {
    const limiter = fakeRateLimit();
    const response = await createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        sessionRepository: { bootstrap: async () => sessionSnapshot },
      },
    } as never).request("/v1/session/bootstrap", {
      method: "POST",
      headers: {
        authorization: `Bearer ${memberToken(auth0Key)}`,
        "cf-connecting-ip": "203.0.113.42",
      },
    }, testBindings(limiter));

    expect(response.status).toBe(200);
    expect(limiter.keys).toHaveLength(2);
    expect(new Set(limiter.keys).size).toBe(2);
    expect(limiter.keys.join(" ")).not.toContain("203.0.113.42");
    expect(limiter.keys.join(" ")).not.toContain("auth0|member-1");

    const second = await createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        sessionRepository: { bootstrap: async () => sessionSnapshot },
      },
    } as never).request("/v1/session/bootstrap", {
      method: "POST",
      headers: {
        authorization: `Bearer ${memberToken(auth0Key, { sub: "auth0|member-2" })}`,
        "cf-connecting-ip": "203.0.113.42",
      },
    }, testBindings(limiter));
    expect(second.status).toBe(200);
    expect(limiter.keys[1]).not.toBe(limiter.keys[3]);
  });

  it("fails admin-high traffic closed when its binding throws", async () => {
    const limiter = fakeRateLimit([new Error("admin binding unavailable")]);
    const app = new Hono();
    app.use("*", requestContext);
    app.use("*", preAuthRateLimit("RL_ADMIN_HIGH") as never);
    app.post("/v1/admin/publish", (context) => context.json({ ok: true }));

    const response = await app.request(
      "/v1/admin/publish",
      { method: "POST" },
      testBindings(limiter),
    );
    expect(response.status).toBe(503);
  });

  it("shares one limiter bucket across arbitrary path parameter values", async () => {
    const limiter = fakeRateLimit();
    const app = new Hono();
    app.use("/catalog/:slug", preAuthRateLimit("RL_PUBLIC") as never);
    app.get("/catalog/:slug", (context) => context.text("ok"));

    for (const slug of ["quiet-power", "attacker-chosen-unbounded-slug"]) {
      const response = await app.request(
        `/catalog/${slug}`,
        { headers: { "cf-connecting-ip": "203.0.113.42" } },
        testBindings(limiter),
      );
      expect(response.status).toBe(200);
    }

    expect(limiter.keys).toHaveLength(2);
    expect(limiter.keys[0]).toBe(limiter.keys[1]);
  });
});

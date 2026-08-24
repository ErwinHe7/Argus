import { describe, expect, it } from "vitest";

import { createApp } from "../../src/app";
import { Hono } from "hono";
import { adminBodyLimit } from "../../src/middleware/security-headers";
import { requestContext } from "../../src/middleware/request-context";
import { createTestRsaKey } from "../support/jwt";
import {
  memberToken,
  sessionSnapshot,
  testBindings,
} from "../support/security-fixtures";

describe("edge response security", () => {
  it("sets deny-by-default browser headers and production-only HSTS", async () => {
    const bindings = { ...testBindings(), ENVIRONMENT: "production" as const };
    const response = await createApp().request("https://api.ritual-investing.test/v1/health/live", {}, bindings);

    expect(response.status).toBe(200);
    expect(response.headers.get("content-security-policy")).toContain("default-src 'none'");
    expect(response.headers.get("strict-transport-security")).toContain("max-age=");
    expect(response.headers.get("x-content-type-options")).toBe("nosniff");
    expect(response.headers.get("x-frame-options")).toBe("DENY");
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
    expect(response.headers.get("permissions-policy")).toContain("camera=()");

    const development = await createApp().request(
      "https://api.ritual-investing.test/v1/health/live",
      {},
      testBindings(),
    );
    expect(development.headers.has("strict-transport-security")).toBe(false);
  });

  it("uses exact-origin CORS and no-store for authenticated responses", async () => {
    const auth0Key = createTestRsaKey("headers-key");
    const app = createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        sessionRepository: { bootstrap: async () => sessionSnapshot },
      },
    } as never);
    const allowed = await app.request("/v1/session/bootstrap", {
      method: "POST",
      headers: {
        authorization: `Bearer ${memberToken(auth0Key)}`,
        origin: "https://app.ritual-investing.test",
      },
    }, testBindings());
    expect(allowed.headers.get("access-control-allow-origin")).toBe("https://app.ritual-investing.test");
    expect(allowed.headers.get("cache-control")).toContain("no-store");

    const denied = await app.request("/v1/session/bootstrap", {
      method: "POST",
      headers: {
        authorization: `Bearer ${memberToken(auth0Key)}`,
        origin: "https://evil.example",
      },
    }, testBindings());
    expect(denied.headers.has("access-control-allow-origin")).toBe(false);

    const wrongSurface = await app.request("https://api.ritual-investing.test/v1/session/bootstrap", {
      method: "POST",
      headers: {
        authorization: `Bearer ${memberToken(auth0Key)}`,
        origin: "https://admin.ritual-investing.test",
      },
    }, testBindings());
    expect(wrongSurface.headers.has("access-control-allow-origin")).toBe(false);
  });

  it("enforces the 256 KiB admin JSON cap", async () => {
    const app = new Hono();
    app.use("*", requestContext);
    app.use("*", adminBodyLimit as never);
    app.post("/v1/admin/test", (context) => context.json({ ok: true }));
    const response = await app.request(
      "/v1/admin/test",
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ payload: "x".repeat(256 * 1024) }),
      },
      testBindings(),
    );
    expect(response.status).toBe(413);
  });
});

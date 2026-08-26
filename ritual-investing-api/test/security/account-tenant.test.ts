import { Hono } from "hono";
import { describe, expect, it, vi } from "vitest";

import type { AppEnvironment } from "../../src/app";
import { accountTenant } from "../../src/middleware/account-tenant";
import { requestContext } from "../../src/middleware/request-context";
import { testBindings } from "../support/security-fixtures";

function appWithResolver(resolver?: Parameters<typeof accountTenant>[0]) {
  const app = new Hono<AppEnvironment>();
  app.use("*", requestContext);
  app.use("*", async (context, next) => {
    context.set("authPrincipal", {
      subject: "auth0|member-1",
      permissions: ["read:self"],
      issuedAt: 1,
    });
    await next();
  });
  app.use("*", accountTenant(resolver));
  app.get("/member", (context) => context.json({ account: context.get("accountTenant") }));
  return app;
}

describe("verified account-to-tenant resolution", () => {
  it("derives context only from the verified subject", async () => {
    const resolver = vi.fn(async () => ({
      accountId: "018f3c2a-4b67-7a89-8abc-123456789001",
      tenantId: "018f3c2a-4b67-7a89-8abc-123456789002",
      principal: "auth0|member-1",
      accountStatus: "active" as const,
      tenantStatus: "active" as const,
      revocationEpoch: 0,
    }));
    const response = await appWithResolver(resolver).request("/member?tenant_id=attacker", {}, testBindings());

    expect(response.status).toBe(200);
    expect(resolver).toHaveBeenCalledWith("auth0|member-1", expect.any(Object));
  });

  it("separates inactive identity from a missing identity database binding", async () => {
    const inactive = await appWithResolver(async () => null).request("/member", {}, testBindings());
    expect(inactive.status).toBe(403);
    await expect(inactive.json()).resolves.toMatchObject({ error: { code: "account_inactive" } });

    const unavailable = await appWithResolver().request("/member", {}, testBindings());
    expect(unavailable.status).toBe(503);
    await expect(unavailable.json()).resolves.toMatchObject({ error: { code: "service_unavailable" } });
  });
});

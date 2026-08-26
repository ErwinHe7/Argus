import { describe, expect, it, vi } from "vitest";
import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import {
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

describe("Demo entitlement workflows", () => {
  const key = createTestRsaKey("entitlement-key");
  it("creates a copy-only checkout and rejects payment fields", async () => {
    const createCheckout = vi.fn(async () => ({ status: "open" }));
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        simulationRepository: { createCheckout },
      },
    } as never);
    const response = await app.request(
      "/v1/demo-checkout-sessions",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(key, { permissions: ["read:self", "write:self", "simulate:self"] })}`,
          "content-type": "application/json",
          "idempotency-key": "demo-checkout-key-000001",
        },
        body: JSON.stringify({
          plan_code: "premium_demo",
          card_number: "4242424242424242",
        }),
      },
      testBindings(),
    );
    expect(response.status).toBe(422);
    expect(createCheckout).not.toHaveBeenCalled();
  });

  it("restores Demo access without an external store", async () => {
    const restoreEntitlement = vi.fn(async () => ({ source: "demo" }));
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        simulationRepository: { restoreEntitlement },
      },
    } as never);
    const response = await app.request(
      "/v1/me/entitlements/restore",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(key, { permissions: ["read:self", "write:self", "simulate:self"] })}`,
          "idempotency-key": "demo-restore-key-0000001",
        },
      },
      testBindings(),
    );
    expect(response.status).toBe(200);
    expect(restoreEntitlement).toHaveBeenCalledOnce();
  });
});

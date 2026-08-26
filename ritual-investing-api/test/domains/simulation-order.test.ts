import { describe, expect, it, vi } from "vitest";
import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import {
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

describe("simulated order preview and commit", () => {
  const key = createTestRsaKey("simulation-order-key");
  const portfolio = "018f3c2a-4b67-7a89-8abc-123456789002";
  const asset = "018f3c2a-4b67-7a89-8abc-123456789010";
  it("freezes a Demo quote without a ledger effect", async () => {
    const previewOrder = vi.fn(async () => ({ id: asset }));
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        simulationRepository: { previewOrder },
      },
    } as never);
    const response = await app.request(
      `/v1/portfolios/${portfolio}/order-previews`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(key, { permissions: ["read:self", "write:self", "simulate:self"] })}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          asset_id: asset,
          side: "buy",
          notional: { minor_units: 10_000, currency: "USD" },
        }),
      },
      testBindings(),
    );
    expect(response.status).toBe(200);
    expect(previewOrder).toHaveBeenCalledOnce();
  });

  it("requires a frozen preview/version and stable retry key", async () => {
    const commitOrder = vi.fn(async () => ({ status: "committed" }));
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        simulationRepository: { commitOrder },
      },
    } as never);
    const response = await app.request(
      `/v1/portfolios/${portfolio}/orders`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(key, { permissions: ["read:self", "write:self", "simulate:self"] })}`,
          "content-type": "application/json",
          "idempotency-key": "order-commit-retry-key-001",
        },
        body: JSON.stringify({ preview_id: asset, portfolio_version: 1 }),
      },
      testBindings(),
    );
    expect(response.status).toBe(200);
    expect(commitOrder).toHaveBeenCalledOnce();
  });
});

import { describe, expect, it, vi } from "vitest";
import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import {
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

describe("Intentions and Future Mirror", () => {
  const key = createTestRsaKey("intentions-key");
  it("uses MEMBER-W for goal CRUD rather than simulate permission", async () => {
    const createIntention = vi.fn(async () => ({ status: "active" }));
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        simulationRepository: { createIntention },
      },
    } as never);
    const response = await app.request(
      "/v1/intentions",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(key, { permissions: ["read:self", "write:self"] })}`,
          "content-type": "application/json",
          "idempotency-key": "intention-create-key-0001",
        },
        body: JSON.stringify({
          title: "Moonlit reserve",
          target: { minor_units: 250_000, currency: "USD" },
          target_date: "2028-08-24",
          portfolio_id: "018f3c2a-4b67-7a89-8abc-123456789002",
        }),
      },
      testBindings(),
    );
    expect(response.status).toBe(201);
    expect(createIntention).toHaveBeenCalledOnce();
  });

  it("rejects unordered projection assumptions before persistence", async () => {
    const buildFutureMirror = vi.fn();
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        simulationRepository: { buildFutureMirror },
      },
    } as never);
    const response = await app.request(
      "/v1/intentions/018f3c2a-4b67-7a89-8abc-123456789020/future-mirror",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(key, { permissions: ["read:self", "write:self", "simulate:self"] })}`,
          "content-type": "application/json",
          "idempotency-key": "future-mirror-key-00001",
        },
        body: JSON.stringify({
          name: "Illustrative",
          monthly_contribution: { minor_units: 1000, currency: "USD" },
          annual_return_bps: { low: 500, mid: 200, high: 100 },
        }),
      },
      testBindings(),
    );
    expect(response.status).toBe(422);
    expect(buildFutureMirror).not.toHaveBeenCalled();
  });
});

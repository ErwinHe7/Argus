import { describe, expect, it, vi } from "vitest";
import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import {
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

describe("recurring Demo plans", () => {
  const key = createTestRsaKey("recurring-plan-key");
  it("creates a fixture-only scheduled plan", async () => {
    const createRecurringPlan = vi.fn(async () => ({ status: "active" }));
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        simulationRepository: { createRecurringPlan },
      },
    } as never);
    const response = await app.request(
      "/v1/portfolios/018f3c2a-4b67-7a89-8abc-123456789002/recurring-plans",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(key, { permissions: ["read:self", "write:self", "simulate:self"] })}`,
          "content-type": "application/json",
          "idempotency-key": "recurring-plan-retry-key-001",
        },
        body: JSON.stringify({
          type: "contribution",
          amount: { minor_units: 1000, currency: "USD" },
          frequency: "monthly",
          source_id: "018f3c2a-4b67-7a89-8abc-123456789003",
          allocations: [
            {
              asset_id: "018f3c2a-4b67-7a89-8abc-123456789010",
              weight_bps: 10_000,
            },
          ],
          first_run_at: "2026-09-01T12:00:00Z",
        }),
      },
      testBindings(),
    );
    expect(response.status).toBe(201);
    expect(createRecurringPlan).toHaveBeenCalledOnce();
  });
});

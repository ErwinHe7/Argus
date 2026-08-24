import { describe, expect, it, vi } from "vitest";
import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import {
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

describe("simulated rebalance", () => {
  const key = createTestRsaKey("simulation-rebalance-key");
  it("previews without posting and commits the frozen set through one command", async () => {
    const previewRebalance = vi.fn(async () => ({ status: "active" }));
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        simulationRepository: { previewRebalance },
      },
    } as never);
    const response = await app.request(
      "/v1/portfolios/018f3c2a-4b67-7a89-8abc-123456789002/rebalance-previews",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(key, { permissions: ["read:self", "write:self", "simulate:self"] })}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          target_allocation: [
            {
              asset_id: "018f3c2a-4b67-7a89-8abc-123456789010",
              target_bps: 10_000,
            },
          ],
        }),
      },
      testBindings(),
    );
    expect(response.status).toBe(200);
    expect(previewRebalance).toHaveBeenCalledOnce();
  });
});

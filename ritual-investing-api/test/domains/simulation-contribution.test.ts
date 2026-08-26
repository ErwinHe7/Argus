import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { simulationHashForTesting } from "../../src/domains/simulation/repository";
import { createTestRsaKey } from "../support/jwt";
import {
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

describe("simulated contributions", () => {
  const auth0Key = createTestRsaKey("simulation-contribution-key");
  const portfolioId = "018f3c2a-4b67-7a89-8abc-123456789002";
  const sourceId = "018f3c2a-4b67-7a89-8abc-123456789003";

  function fixture() {
    const contribute = vi.fn(async () => ({
      command_id: "018f3c2a-4b67-7a89-8abc-123456789004",
      status: "committed",
      portfolio_version: 2,
      ledger_transaction_ids: ["018f3c2a-4b67-7a89-8abc-123456789005"],
      summary: {
        kind: "contribution",
        amount: { minor_units: 25_000, currency: "USD" },
      },
      projection_links: [],
      demo: {
        is_demo: true,
        observed_at: "2026-08-24T04:00:00.000Z",
        source_label: "Ritual deterministic Demo",
        limitations: ["No money moves."],
      },
    }));
    return {
      contribute,
      app: createApp({
        dependencies: {
          auth0Keys: [auth0Key.publicJwk],
          accountResolver: vi.fn(async () => resolvedMemberAccount),
          simulationRepository: { contribute },
        },
      } as never),
    };
  }

  it("commits one fixture-backed contribution with a required retry key", async () => {
    const { app, contribute } = fixture();
    const response = await app.request(
      `/v1/portfolios/${portfolioId}/contributions`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(auth0Key, {
            permissions: ["read:self", "write:self", "simulate:self"],
          })}`,
          "content-type": "application/json",
          "idempotency-key": "contribution-retry-key-0001",
        },
        body: JSON.stringify({
          amount: { minor_units: 25_000, currency: "USD" },
          source_id: sourceId,
          effective_at: "2026-08-24T04:00:00.000Z",
        }),
      },
      testBindings(),
    );

    expect(response.status).toBe(200);
    expect(contribute).toHaveBeenCalledWith(
      expect.objectContaining({ tenantId: resolvedMemberAccount.tenantId }),
      portfolioId,
      expect.objectContaining({
        amount: expect.objectContaining({ minor_units: 25_000 }),
      }),
      "contribution-retry-key-0001",
    );
    expect(await response.json()).toMatchObject({
      data: { status: "committed", demo: { is_demo: true } },
    });
  });

  it("rejects credential-shaped and ownership fields before the repository", async () => {
    const { app, contribute } = fixture();
    const response = await app.request(
      `/v1/portfolios/${portfolioId}/contributions`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(auth0Key, {
            permissions: ["read:self", "write:self", "simulate:self"],
          })}`,
          "content-type": "application/json",
          "idempotency-key": "contribution-retry-key-0002",
        },
        body: JSON.stringify({
          amount: { minor_units: 25_000, currency: "USD" },
          source_id: sourceId,
          routing_number: "021000021",
          tenant_id: resolvedMemberAccount.tenantId,
        }),
      },
      testBindings(),
    );

    expect(response.status).toBe(422);
    expect(contribute).not.toHaveBeenCalled();
  });

  it("canonicalizes nested request fields independent of object insertion order", async () => {
    const left = await simulationHashForTesting({
      portfolio_id: portfolioId,
      amount: { currency: "USD", minor_units: 25_000 },
      source_id: sourceId,
    });
    const right = await simulationHashForTesting({
      source_id: sourceId,
      amount: { minor_units: 25_000, currency: "USD" },
      portfolio_id: portfolioId,
    });
    expect(left).toBe(right);
  });
});

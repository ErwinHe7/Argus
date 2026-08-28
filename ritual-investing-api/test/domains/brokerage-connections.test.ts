import { describe, expect, it, vi } from "vitest";

import {
  BrokerageConnectionError,
  type BrokerageConnectionRepository,
} from "../../src/domains/brokerage-connections/repository.ts";
import {
  createRetainedApp,
  type RetainedRepositorySet,
  type VerifiedSupabasePrincipal,
} from "../../src/retained-app.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789002";
const bindings = {
  environment: "test" as const,
  buildRevision: "u5-test",
  consumerOrigin: "https://app.ritual-investing.test",
  adminOrigin: "https://admin.ritual-investing.test",
};

function fixture(authenticatedAt?: number) {
  const principal: VerifiedSupabasePrincipal = {
    userId,
    sessionId,
    aal: "aal1",
    issuedAt: Math.floor(Date.now() / 1_000) - 5,
    ...(authenticatedAt === undefined ? {} : { authenticatedAt }),
  };
  const brokerage = {
    issueStepUp: vi.fn(async (action: string) => ({
      receipt: "R".repeat(43),
      action,
      user_id: userId,
      session_id: sessionId,
      expires_at: new Date(Date.now() + 300_000).toISOString(),
    })),
    start: vi.fn(async () => ({
      connection_id: "018f3c2a-4b67-7a89-8abc-123456789003",
      authorization_url: "https://passport.webull.com/synthetic",
      expires_at: new Date(Date.now() + 300_000).toISOString(),
    })),
    reconnect: vi.fn(async () => ({ status: "pending" })),
    status: vi.fn(async () => ({ status: "connected", accounts: [] })),
    selectAccount: vi.fn(async (accountId: string) => ({
      account_id: accountId,
      selected: true,
    })),
    redeemCompletion: vi.fn(async () => ({ outcome: "connected" })),
    disconnect: vi.fn(async () => ({
      status: "disconnected",
      provider_grant_revoked: false,
    })),
  } as unknown as BrokerageConnectionRepository;
  const app = createRetainedApp({
    verifyAccessToken: vi.fn(async () => principal),
    createRepositories: vi.fn(() => ({}) as RetainedRepositorySet),
    createBrokerageConnections: vi.fn(() => brokerage),
    publicPreviewRepository: {
      listPublished: vi.fn(async () => []),
      getPublished: vi.fn(async () => null),
    },
    rateLimit: { allow: vi.fn(async () => ({ allowed: true })) },
    requestId: () => "018f3c2a-4b67-7a89-8abc-123456789077",
  });
  return { app, brokerage };
}

const headers = {
  authorization: "Bearer signed-supabase-token",
  origin: bindings.consumerOrigin,
  "content-type": "application/json",
};

describe("brokerage connection HTTP contract", () => {
  it("issues one action-bound receipt only after verified recent auth", async () => {
    const stale = fixture(Math.floor(Date.now() / 1_000) - 301);
    const denied = await stale.app.request(
      "/v1/member/step-up",
      {
        method: "POST",
        headers,
        body: JSON.stringify({ action: "webull_disconnect" }),
      },
      bindings,
    );
    expect(denied.status).toBe(403);
    expect(stale.brokerage.issueStepUp).not.toHaveBeenCalled();

    const fresh = fixture(Math.floor(Date.now() / 1_000) - 5);
    const issued = await fresh.app.request(
      "/v1/member/step-up",
      {
        method: "POST",
        headers,
        body: JSON.stringify({ action: "webull_disconnect" }),
      },
      bindings,
    );
    expect(issued.status).toBe(200);
    expect(await issued.json()).toMatchObject({
      data: {
        action: "webull_disconnect",
        user_id: userId,
        session_id: sessionId,
      },
    });
    expect(fresh.brokerage.issueStepUp).toHaveBeenCalledWith(
      "webull_disconnect",
    );
  });

  it("accepts only return-target enums and never accepts an arbitrary URL", async () => {
    const test = fixture();
    const invalid = await test.app.request(
      "/v1/brokerage/connections/start",
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          return_target: "https://attacker.test/callback",
        }),
      },
      bindings,
    );
    expect(invalid.status).toBe(422);
    expect(test.brokerage.start).not.toHaveBeenCalled();

    const valid = await test.app.request(
      "/v1/brokerage/connections/start",
      {
        method: "POST",
        headers,
        body: JSON.stringify({ return_target: "webull_native" }),
      },
      bindings,
    );
    expect(valid.status).toBe(200);
    expect(test.brokerage.start).toHaveBeenCalledWith("webull_native");
  });

  it("maps intercepted/replayed completions to the same non-enumerating result", async () => {
    const test = fixture();
    vi.mocked(test.brokerage.redeemCompletion).mockRejectedValue(
      new BrokerageConnectionError("completion_not_found"),
    );
    const response = await test.app.request(
      "/v1/brokerage/connections/completions/redeem",
      {
        method: "POST",
        headers,
        body: JSON.stringify({ completion: "C".repeat(43) }),
      },
      bindings,
    );
    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({
      error: { code: "completion_not_found", retryable: false },
    });
  });

  it("disconnect never claims provider revocation", async () => {
    const test = fixture();
    const response = await test.app.request(
      "/v1/brokerage/connections/disconnect",
      {
        method: "POST",
        headers,
        body: JSON.stringify({ step_up_receipt: "R".repeat(43) }),
      },
      bindings,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      data: { status: "disconnected", provider_grant_revoked: false },
    });
  });
});

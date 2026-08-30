import { describe, expect, it, vi } from "vitest";

import {
  createBrokerageConnectionRepository,
} from "../../src/domains/brokerage-connections/repository.ts";
import {
  BrokerageConnectionError,
  createBrokerageConnectionService,
} from "../../src/domains/brokerage-connections/service.ts";
import type {
  DatabaseClient,
  DatabasePool,
} from "../../src/db/database-port.ts";
import { createVerifiedRequestClaims } from "../../src/db/request-context.ts";
import { withMemberRequestTransaction } from "../../src/db/request-transaction.ts";
import {
  createRetainedApp,
  type RetainedRepositorySet,
  type VerifiedSupabasePrincipal,
} from "../../src/retained-app.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789002";
const consumerOrigin = "https://app.ritual-investing.test";
const bindings = {
  environment: "test" as const,
  buildRevision: "u5-test",
  consumerOrigins: Object.freeze([consumerOrigin]),
  adminOrigin: "https://admin.ritual-investing.test",
  webAdmission: "open" as const,
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
  };
  const app = createRetainedApp({
    verifyAccessToken: vi.fn(async () => principal),
    withRepositories: async (_claims, _transaction, callback) =>
      await callback({} as RetainedRepositorySet),
    withPublicPreview: async (callback) =>
      await callback({
        listPublishedPage: vi.fn(async () => []),
        listPublished: vi.fn(async () => []),
        getPublished: vi.fn(async () => null),
      }),
    createPrivacyService: () => ({} as never),
    createBrokerageConnections: vi.fn(() => brokerage),
    rateLimit: { allow: vi.fn(async () => ({ allowed: true })) },
    requestId: () => "018f3c2a-4b67-7a89-8abc-123456789077",
  });
  return { app, brokerage };
}

const headers = {
  authorization: "Bearer signed-supabase-token",
  "content-type": "application/json",
};

function repositoryWithDisconnectResult(
  disconnectResult: readonly unknown[] | Error,
) {
  const query = vi.fn(async (sql: string) => {
    if (sql.includes("disconnect_webull_connection")) {
      if (disconnectResult instanceof Error) throw disconnectResult;
      return { rows: [...disconnectResult] };
    }
    return { rows: [] };
  });
  const client: DatabaseClient = {
    async query<Row>(sql: string) {
      return await query(sql) as { rows: Row[] };
    },
    release: vi.fn(),
  };
  const pool: DatabasePool = {
    connect: vi.fn(async () => client),
    end: vi.fn(async () => undefined),
  };
  const claims = createVerifiedRequestClaims({
    userId,
    sessionId,
    aal: "aal2",
  });
  return {
    pool,
    query,
    repository: createBrokerageConnectionService({
      claims,
      authorization: {
        contractVersion: "unavailable",
        environment: "sandbox",
        authorizationUrl: () => new URL("https://passport.webull.com/blocked"),
      },
      withRepository: (callback) =>
        withMemberRequestTransaction(
          { pool, verifiedClaims: claims },
          (database) => callback(createBrokerageConnectionRepository(database)),
        ),
    }),
  };
}

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

  it("rejects malformed disconnect receipts before invoking the repository", async () => {
    const test = fixture();
    const response = await test.app.request(
      "/v1/brokerage/connections/disconnect",
      {
        method: "POST",
        headers,
        body: JSON.stringify({ step_up_receipt: "not valid" }),
      },
      bindings,
    );
    expect(response.status).toBe(422);
    expect(test.brokerage.disconnect).not.toHaveBeenCalled();
  });

  it("maps replayed database step-up denials without exposing a 500", async () => {
    const test = fixture();
    vi.mocked(test.brokerage.disconnect).mockRejectedValue(
      new BrokerageConnectionError("step_up_required"),
    );
    const response = await test.app.request(
      "/v1/brokerage/connections/disconnect",
      {
        method: "POST",
        headers,
        body: JSON.stringify({ step_up_receipt: "R".repeat(43) }),
      },
      bindings,
    );
    expect(response.status).toBe(403);
    expect(await response.json()).toMatchObject({
      error: { code: "step_up_required", retryable: false },
    });
  });

  it("maps a missing connection without exposing a 500", async () => {
    const test = fixture();
    vi.mocked(test.brokerage.disconnect).mockRejectedValue(
      new BrokerageConnectionError("connection_not_found"),
    );
    const response = await test.app.request(
      "/v1/brokerage/connections/disconnect",
      {
        method: "POST",
        headers,
        body: JSON.stringify({ step_up_receipt: "R".repeat(43) }),
      },
      bindings,
    );
    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({
      error: { code: "connection_not_found", retryable: false },
    });
  });
});

describe("brokerage connection disconnect repository boundary", () => {
  it("rejects an invalid receipt before opening a database transaction", async () => {
    const test = repositoryWithDisconnectResult([]);
    await expect(test.repository.disconnect("not valid")).rejects.toMatchObject(
      {
        name: "BrokerageConnectionError",
        code: "step_up_required",
      },
    );
    expect(test.pool.connect).not.toHaveBeenCalled();
  });

  it("translates an exact replay/step-up SQL denial", async () => {
    const error = Object.assign(new Error("step_up_required"), {
      code: "42501",
    });
    const test = repositoryWithDisconnectResult(error);
    await expect(test.repository.disconnect("R".repeat(43))).rejects
      .toMatchObject({
        name: "BrokerageConnectionError",
        code: "step_up_required",
      });
  });

  it("translates an exact missing-connection SQL denial", async () => {
    const error = Object.assign(new Error("connection_not_found"), {
      code: "P0001",
    });
    const test = repositoryWithDisconnectResult(error);
    await expect(test.repository.disconnect("R".repeat(43))).rejects
      .toMatchObject({
        name: "BrokerageConnectionError",
        code: "connection_not_found",
      });
  });

  it("preserves unknown database failures", async () => {
    const error = Object.assign(new Error("step_up_required"), {
      code: "XX000",
    });
    const test = repositoryWithDisconnectResult(error);
    await expect(test.repository.disconnect("R".repeat(43))).rejects.toBe(
      error,
    );
  });
});

import { describe, expect, it, vi } from "vitest";

import {
  createRetainedApp,
  type CreateRetainedAppOptions,
  type RetainedRepositorySet,
  type RetainedTelemetryEvent,
  type RetainedTokenVerifier,
  type VerifiedSupabasePrincipal,
} from "../../src/retained-app.ts";
import { StaffAuthorizationError } from "../../src/db/request-transaction.ts";
import type { BrokerageOrderService } from "../../src/domains/brokerage-orders/service.ts";
import type { RateLimitPort } from "../../src/ports/infrastructure.ts";
import { rewriteSupabaseFunctionRequest } from "../../../supabase/functions/_shared/http.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const bindings = {
  environment: "test" as const,
  buildRevision: "u3-test",
  consumerOrigin: "https://app.ritual-investing.test",
  adminOrigin: "https://admin.ritual-investing.test",
};

function principal(aal: "aal1" | "aal2" = "aal1"): VerifiedSupabasePrincipal {
  return Object.freeze({
    userId,
    sessionId,
    aal,
    issuedAt: Math.floor(Date.now() / 1_000) - 1,
  });
}

type FixtureOptions = Readonly<{
  verifyAccessToken?: RetainedTokenVerifier;
  rateLimit?: RateLimitPort;
  telemetry?: (event: RetainedTelemetryEvent) => void | Promise<void>;
  staffPrincipal?: unknown;
  listAudit?: ReturnType<typeof vi.fn>;
  account?: unknown;
  updatePreferences?: ReturnType<typeof vi.fn>;
  brokerageOrderService?: BrokerageOrderService;
}>;

function fixture(options: FixtureOptions = {}) {
  const verifyAccessToken = options.verifyAccessToken ??
    vi.fn(async () => principal());
  const bootstrap = vi.fn(async () => ({ member: { user_id: userId } }));
  const getStaffPrincipal = vi.fn(async () =>
    options.staffPrincipal === undefined
      ? {
        id: "018f3c2a-4b67-7a89-8abc-123456789099",
        status: "active",
      }
      : options.staffPrincipal
  );
  const listAudit = options.listAudit ?? vi.fn(async () => []);
  const getAccount = vi.fn(async () => options.account ?? { version: 3 });
  const updatePreferences = options.updatePreferences ??
    vi.fn(async (_patch: unknown, version: number) => ({
      version: version + 1,
    }));
  const getCircle = vi.fn(async (id: string) => ({ id, version: 1 }));
  const updateCircle = vi.fn(
    async (id: string, _patch: unknown, version: number) => ({
      id,
      version: version + 1,
    }),
  );
  const repositories = {
    session: { bootstrap },
    accounts: { get: getAccount, updatePreferences },
    circles: {
      list: vi.fn(async () => []),
      create: vi.fn(async () => ({ version: 1 })),
      get: getCircle,
      update: updateCircle,
    },
    admin: { getStaffPrincipal, listAudit },
  } as unknown as RetainedRepositorySet;
  const withRepositories = vi.fn();
  const runWithRepositories: CreateRetainedAppOptions["withRepositories"] =
    async (claims, transaction, callback) => {
      withRepositories(claims, transaction, callback);
      return await callback(repositories);
    };
  const rateLimit = options.rateLimit ?? {
    allow: vi.fn(async () => ({ allowed: true })),
  };
  const app = createRetainedApp({
    verifyAccessToken,
    withRepositories: runWithRepositories,
    withPublicPreview: async (callback) =>
      await callback({
        listPublishedPage: vi.fn(async () => []),
        listPublished: vi.fn(async () => []),
        getPublished: vi.fn(async () => null),
      }),
    createPrivacyService: () => ({} as never),
    rateLimit,
    requestId: () => "018f3c2a-4b67-7a89-8abc-123456789077",
    ...(options.telemetry === undefined
      ? {}
      : { telemetry: options.telemetry }),
    ...(options.brokerageOrderService === undefined
      ? {}
      : { createBrokerageOrders: () => options.brokerageOrderService! }),
  });
  return {
    app,
    bootstrap,
    withRepositories,
    getStaffPrincipal,
    getAccount,
    getCircle,
    listAudit,
    rateLimit,
    updateCircle,
    updatePreferences,
    verifyAccessToken,
  };
}

describe("Supabase Edge retained API adapter", () => {
  it("preserves a bodyless bootstrap at /functions/v1/api and derives owner claims", async () => {
    const test = fixture();
    const edgeRequest = new Request(
      "https://project.supabase.co/functions/v1/api/v1/session/bootstrap",
      {
        method: "POST",
        headers: {
          authorization: "Bearer verified-supabase-token",
          "content-length": "0",
          origin: bindings.consumerOrigin,
        },
        body: new Uint8Array(0),
      },
    );

    const response = await test.app.fetch(
      rewriteSupabaseFunctionRequest(edgeRequest, "api"),
      bindings,
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("application/json");
    expect(response.headers.get("access-control-allow-origin")).toBe(
      bindings.consumerOrigin,
    );
    expect(test.bootstrap).toHaveBeenCalledOnce();
    expect(test.withRepositories).toHaveBeenCalledWith(
      { userId, sessionId, aal: "aal1" },
      "member",
      expect.any(Function),
    );
    expect(await response.json()).toMatchObject({
      data: { member: { user_id: userId } },
    });
  });

  it("denies invalid tokens and untrusted origins before repository access", async () => {
    const test = fixture({
      verifyAccessToken: vi.fn(async () => {
        throw new Error("invalid_token");
      }),
    });
    const invalidToken = await test.app.request(
      "/v1/session/bootstrap",
      {
        method: "POST",
        headers: { authorization: "Bearer malformed" },
      },
      bindings,
    );
    expect(invalidToken.status).toBe(401);

    const wrongOrigin = await test.app.request(
      "/v1/session/bootstrap",
      {
        method: "POST",
        headers: {
          authorization: "Bearer malformed",
          origin: "https://attacker.example",
        },
      },
      bindings,
    );
    expect(wrongOrigin.status).toBe(403);
    expect(test.withRepositories).not.toHaveBeenCalled();
    expect(JSON.stringify(await invalidToken.json())).not.toContain(
      "malformed",
    );
  });

  it("requires AAL2 before the database-backed active staff recheck", async () => {
    const aal1 = fixture({
      verifyAccessToken: vi.fn(async () => principal("aal1")),
    });
    const denied = await aal1.app.request(
      "/v1/admin/session",
      {
        headers: {
          authorization: "Bearer aal1-token",
          origin: bindings.adminOrigin,
        },
      },
      bindings,
    );
    expect(denied.status).toBe(403);
    expect(aal1.getStaffPrincipal).not.toHaveBeenCalled();

    const aal2 = fixture({
      verifyAccessToken: vi.fn(async () => principal("aal2")),
    });
    const allowed = await aal2.app.request(
      "/v1/admin/session",
      {
        headers: {
          authorization: "Bearer aal2-token",
          origin: bindings.adminOrigin,
        },
      },
      bindings,
    );
    expect(allowed.status).toBe(200);
    expect(aal2.getStaffPrincipal).toHaveBeenCalledOnce();
  });

  it("rejects revoked staff and rechecks route permissions in the database", async () => {
    const revoked = fixture({
      verifyAccessToken: vi.fn(async () => principal("aal2")),
      staffPrincipal: null,
    });
    const revokedResponse = await revoked.app.request(
      "/v1/admin/session",
      {
        headers: {
          authorization: "Bearer aal2-token",
          origin: bindings.adminOrigin,
        },
      },
      bindings,
    );
    expect(revokedResponse.status).toBe(403);
    expect(revoked.getStaffPrincipal).toHaveBeenCalledOnce();

    const nonStaff = fixture({
      verifyAccessToken: vi.fn(async () => principal("aal2")),
      listAudit: vi.fn(async () => {
        throw new StaffAuthorizationError();
      }),
    });
    const nonStaffResponse = await nonStaff.app.request(
      "/v1/admin/audit",
      {
        headers: {
          authorization: "Bearer aal2-token",
          origin: bindings.adminOrigin,
        },
      },
      bindings,
    );
    expect(nonStaffResponse.status).toBe(403);
    expect(nonStaff.listAudit).toHaveBeenCalledOnce();
    expect(await nonStaffResponse.json()).toMatchObject({
      error: { code: "forbidden", retryable: false },
    });
  });

  it("returns durable rate-limit decisions and fails closed when the limiter is unavailable", async () => {
    const limited = fixture({
      rateLimit: {
        allow: vi.fn(async () => ({ allowed: false, retryAfterSeconds: 17 })),
      },
    });
    const limitedResponse = await limited.app.request(
      "/v1/session/bootstrap",
      { method: "POST", headers: { authorization: "Bearer valid-token" } },
      bindings,
    );
    expect(limitedResponse.status).toBe(429);
    expect(limitedResponse.headers.get("retry-after")).toBe("17");
    expect(limited.bootstrap).not.toHaveBeenCalled();

    const unavailable = fixture({
      rateLimit: {
        allow: vi.fn(async () => {
          throw new Error("database unavailable");
        }),
      },
    });
    const unavailableResponse = await unavailable.app.request(
      "/v1/session/bootstrap",
      { method: "POST", headers: { authorization: "Bearer valid-token" } },
      bindings,
    );
    expect(unavailableResponse.status).toBe(503);
    expect(unavailable.bootstrap).not.toHaveBeenCalled();
    expect(await unavailableResponse.json()).toMatchObject({
      error: { code: "service_unavailable", retryable: true },
    });
  });

  it("preserves ETag and If-Match semantics with a stable error envelope", async () => {
    const test = fixture();
    const account = await test.app.request(
      "/v1/account",
      { headers: { authorization: "Bearer valid-token" } },
      bindings,
    );
    expect(account.status).toBe(200);
    expect(account.headers.get("etag")).toBe('"v3"');

    const invalidPrecondition = await test.app.request(
      "/v1/preferences",
      {
        method: "PATCH",
        headers: {
          authorization: "Bearer valid-token",
          "content-type": "application/json",
          "if-match": "3",
        },
        body: JSON.stringify({ themeMode: "dark" }),
      },
      bindings,
    );
    expect(invalidPrecondition.status).toBe(422);
    expect(test.updatePreferences).not.toHaveBeenCalled();
    expect(await invalidPrecondition.json()).toEqual({
      error: {
        code: "invalid_if_match",
        message: "If-Match must contain the current version ETag.",
        request_id: "018f3c2a-4b67-7a89-8abc-123456789077",
        field_errors: [],
        retryable: false,
      },
    });
  });

  it("does not put bearer tokens, query values, or exception details in telemetry", async () => {
    const events: RetainedTelemetryEvent[] = [];
    const secret = "canary.secret.token";
    const test = fixture({
      account: undefined,
      telemetry: (event) => {
        events.push(event);
      },
    });
    test.getAccount.mockRejectedValueOnce(
      new Error(`database error containing ${secret}`),
    );
    const response = await test.app.request(
      `/v1/account?email=${encodeURIComponent("private@example.test")}`,
      { headers: { authorization: `Bearer ${secret}` } },
      bindings,
    );
    expect(response.status).toBe(503);
    const errorBody = JSON.stringify(await response.json());
    const telemetry = JSON.stringify(events);
    expect(errorBody).not.toContain(secret);
    expect(errorBody).not.toContain("database error");
    expect(telemetry).not.toContain(secret);
    expect(telemetry).not.toContain("private@example.test");
    expect(events).toEqual([
      expect.objectContaining({
        event: "http.request",
        method: "GET",
        route: "/v1/account",
        status: 503,
      }),
    ]);
  });

  it("runs auth and rate limiting once on every verb sharing a route path", async () => {
    const verifyAccessToken = vi.fn(async () => principal());
    const allow = vi.fn(async () => ({ allowed: true }));
    const test = fixture({ verifyAccessToken, rateLimit: { allow } });
    const circleId = "018f3c2a-4b67-7a89-8abc-123456789055";

    const read = await test.app.request(
      `/v1/circles/${circleId}`,
      { headers: { authorization: "Bearer valid-token" } },
      bindings,
    );
    expect(read.status).toBe(200);
    expect(verifyAccessToken).toHaveBeenCalledOnce();
    expect(allow).toHaveBeenCalledOnce();

    verifyAccessToken.mockClear();
    allow.mockClear();
    const update = await test.app.request(
      `/v1/circles/${circleId}`,
      {
        method: "PATCH",
        headers: {
          authorization: "Bearer valid-token",
          "content-type": "application/json",
          "if-match": '"v1"',
        },
        body: JSON.stringify({ title: "One middleware pass" }),
      },
      bindings,
    );
    expect(update.status).toBe(200);
    expect(verifyAccessToken).toHaveBeenCalledOnce();
    expect(allow).toHaveBeenCalledOnce();
    expect(test.updateCircle).toHaveBeenCalledOnce();
  });

  it("keeps a successful response when the telemetry sink rejects", async () => {
    const telemetry = vi.fn(async () => {
      throw new Error("telemetry unavailable");
    });
    const test = fixture({ telemetry });

    const response = await test.app.request(
      "/v1/account",
      { headers: { authorization: "Bearer valid-token" } },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ data: { version: 3 } });
    expect(telemetry).toHaveBeenCalledOnce();
  });
});

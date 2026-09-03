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
import type { BrokerageConnectionRouteService } from "../../src/domains/brokerage/routes.ts";
import type { MemberBranchCapabilities } from "../../src/domains/session/schemas.ts";
import type { RateLimitPort } from "../../src/ports/infrastructure.ts";
import { rewriteSupabaseFunctionRequest } from "../../../supabase/functions/_shared/http.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const apexOrigin = "https://just-build-this.app";
const betaOrigin = "https://beta.just-build-this.app";
const bindings = {
  environment: "test" as const,
  buildRevision: "u3-test",
  consumerOrigins: Object.freeze([apexOrigin, betaOrigin]),
  adminOrigin: "https://admin.ritual-investing.test",
  webAdmission: "open" as const,
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
  brokerageConnectionService?: BrokerageConnectionRouteService;
  branchCapabilities?: MemberBranchCapabilities;
}>;

function fixture(options: FixtureOptions = {}) {
  const verifyAccessToken = options.verifyAccessToken ??
    vi.fn(async () => principal());
  const bootstrap = vi.fn(async () => ({
    member: {
      user_id: userId,
      status: "active" as const,
      deletion_epoch: 0,
      deletion_requested_at: null,
      created_at: null,
      updated_at: null,
    },
    profile: null,
    preferences: null,
    onboarding: null,
    investor_profile: null,
    astrology_profile: null,
    server_time: "2026-08-30T12:00:00.000Z",
  }));
  const defaultBranchCapabilities: MemberBranchCapabilities = {
    schema_version: "member-branch-capabilities-v1",
    capability_version: 1,
    environment: "beta",
    evaluated_at: "2026-08-30T12:00:00.000Z",
    expires_at: "2026-08-30T12:05:00.000Z",
    branches: ["ritual", "starpath", "discover", "coven", "you"],
  };
  const evaluateMemberBranches = vi.fn(async () =>
    options.branchCapabilities ?? defaultBranchCapabilities
  );
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
  const privacyRequest = vi.fn(async (requestType: "export" | "deletion") => ({
    id: requestType === "export"
      ? "018f3c2a-4b67-7a89-8abc-123456789081"
      : "018f3c2a-4b67-7a89-8abc-123456789082",
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
    memberBranchCapabilities: { evaluate: evaluateMemberBranches },
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
    createPrivacyService: () => ({
      list: vi.fn(async () => []),
      request: privacyRequest,
      getDeletionTombstone: vi.fn(async () => null),
      createDownloadUrl: vi.fn(async () => ({
        url: "https://project.supabase.co/storage/v1/object/sign/opaque-token",
        expires_at: "2026-08-30T12:00:00.000Z",
      })),
      download: vi.fn(async () => ({
        body: new ReadableStream<Uint8Array>(),
        contentType: "application/zip" as const,
        contentChecksum: "a".repeat(64),
        byteSize: 3,
      })),
    }),
    rateLimit,
    ...(options.brokerageConnectionService === undefined
      ? {}
      : {
        createBrokerageConnections: () =>
          options.brokerageConnectionService!,
      }),
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
    evaluateMemberBranches,
    withRepositories,
    getStaffPrincipal,
    getAccount,
    getCircle,
    listAudit,
    privacyRequest,
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
          origin: apexOrigin,
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
      apexOrigin,
    );
    expect(test.bootstrap).toHaveBeenCalledOnce();
    expect(test.evaluateMemberBranches).toHaveBeenCalledWith(
      "2026-08-30T12:00:00.000Z",
    );
    expect(test.withRepositories).toHaveBeenCalledWith(
      { userId, sessionId, aal: "aal1" },
      "member",
      expect.any(Function),
    );
    expect(await response.json()).toMatchObject({
      data: {
        member: { user_id: userId },
        branch_capabilities: {
          schema_version: "member-branch-capabilities-v1",
          capability_version: 1,
          environment: "beta",
          evaluated_at: "2026-08-30T12:00:00.000Z",
          expires_at: "2026-08-30T12:05:00.000Z",
          branches: ["ritual", "starpath", "discover", "coven", "you"],
        },
      },
    });
  });

  it("limits production navigation to the production branch set", async () => {
    const test = fixture({
      branchCapabilities: {
        schema_version: "member-branch-capabilities-v1",
        capability_version: 7,
        environment: "production",
        evaluated_at: "2026-08-30T12:00:00.000Z",
        expires_at: "2026-08-30T12:05:00.000Z",
        branches: ["ritual", "starpath", "you"],
      },
    });
    const response = await test.app.request(
      "/v1/session/bootstrap",
      {
        method: "POST",
        headers: {
          authorization: "Bearer verified-supabase-token",
          origin: apexOrigin,
        },
      },
      { ...bindings, environment: "production" },
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      data: {
        branch_capabilities: {
          environment: "production",
          branches: ["ritual", "starpath", "you"],
        },
      },
    });
  });

  it("reflects only the matched apex or stable-beta origin with fixed credential-free CORS", async () => {
    const test = fixture();

    for (const origin of [apexOrigin, betaOrigin]) {
      const response = await test.app.request(
        "/v1/session/bootstrap",
        {
          method: "OPTIONS",
          headers: {
            origin,
            "access-control-request-method": "POST",
            "access-control-request-headers": "authorization, content-type",
          },
        },
        bindings,
      );

      expect(response.status).toBe(204);
      expect(response.headers.get("access-control-allow-origin")).toBe(origin);
      expect(response.headers.get("access-control-allow-methods")).toBe(
        "GET, POST, PUT, PATCH, DELETE, OPTIONS",
      );
      expect(response.headers.get("access-control-allow-headers")).toBe(
        "authorization, content-type, if-match, idempotency-key, x-request-id",
      );
      expect(response.headers.get("vary")).toBe("origin");
      expect(response.headers.has("access-control-allow-credentials")).toBe(
        false,
      );
    }
  });

  it("rejects null, wildcard-like, foreign, and generic preview origins without CORS", async () => {
    const test = fixture();

    for (
      const origin of [
        "null",
        "*",
        "https://attacker.example",
        "https://branch-123.just-build-this.pages.dev",
      ]
    ) {
      const response = await test.app.request(
        "/v1/session/bootstrap",
        {
          method: "POST",
          headers: {
            authorization: "Bearer valid-token",
            origin,
          },
        },
        bindings,
      );

      expect(response.status).toBe(403);
      expect(response.headers.has("access-control-allow-origin")).toBe(false);
    }
    expect(test.bootstrap).not.toHaveBeenCalled();
  });

  it("contains bootstrap and non-privacy mutations while preserving privacy and originless native behavior", async () => {
    const test = fixture();
    const containedBindings = { ...bindings, webAdmission: "contained" as const };

    const webBootstrap = await test.app.request(
      "/v1/session/bootstrap",
      {
        method: "POST",
        headers: { authorization: "Bearer valid-token", origin: apexOrigin },
      },
      containedBindings,
    );
    expect(webBootstrap.status).toBe(503);
    expect(await webBootstrap.json()).toMatchObject({
      error: { code: "web_admission_closed", retryable: true },
    });
    expect(test.bootstrap).not.toHaveBeenCalled();

    const memberMutation = await test.app.request(
      "/v1/preferences",
      {
        method: "PATCH",
        headers: {
          authorization: "Bearer valid-token",
          "content-type": "application/json",
          "if-match": '"v3"',
          origin: apexOrigin,
        },
        body: JSON.stringify({ themeMode: "dark" }),
      },
      containedBindings,
    );
    expect(memberMutation.status).toBe(503);
    expect(test.updatePreferences).not.toHaveBeenCalled();

    for (
      const [requestType, stepUpReceipt] of [
        ["export", undefined],
        ["deletion", "R".repeat(43)],
      ] as const
    ) {
      const privacy = await test.app.request(
        "/v1/privacy/requests",
        {
          method: "POST",
          headers: {
            authorization: "Bearer valid-token",
            "content-type": "application/json",
            "idempotency-key": `contained-${requestType}`,
            origin: apexOrigin,
          },
          body: JSON.stringify({
            requestType,
            ...(stepUpReceipt === undefined
              ? {}
              : { step_up_receipt: stepUpReceipt }),
          }),
        },
        containedBindings,
      );
      expect(privacy.status).toBe(200);
    }
    expect(test.privacyRequest).toHaveBeenCalledTimes(2);

    const nativeBootstrap = await test.app.request(
      "/v1/session/bootstrap",
      { method: "POST", headers: { authorization: "Bearer valid-token" } },
      containedBindings,
    );
    expect(nativeBootstrap.status).toBe(200);
    expect(test.bootstrap).toHaveBeenCalledOnce();
  });

  it("allows admitted financial and provider capabilities from web origins", async () => {
    const status = vi.fn(async () => ({ status: "connected", accounts: [] }));
    const service = {
      issueStepUp: vi.fn(),
      start: vi.fn(),
      reconnect: vi.fn(),
      status,
      selectAccount: vi.fn(),
      redeemCompletion: vi.fn(),
      disconnect: vi.fn(),
    } as BrokerageConnectionRouteService;
    const test = fixture({ brokerageConnectionService: service });

    const response = await test.app.request(
      "/v1/brokerage/connection",
      {
        headers: { authorization: "Bearer valid-token", origin: betaOrigin },
      },
      bindings,
    );
    expect(response.status).toBe(200);
    expect(status).toHaveBeenCalledOnce();
  });

  it("uses admission state, not public-beta origin, to gate web step-up", async () => {
    const issueStepUp = vi.fn(async (action: "webull_disconnect" | "argus_delete") => ({
      action,
      receipt: "a".repeat(32),
    }));
    const service = {
      issueStepUp,
      start: vi.fn(),
      reconnect: vi.fn(),
      status: vi.fn(),
      selectAccount: vi.fn(),
      redeemCompletion: vi.fn(),
      disconnect: vi.fn(),
    } as BrokerageConnectionRouteService;
    const test = fixture({
      brokerageConnectionService: service,
      verifyAccessToken: vi.fn(async () => ({
        ...principal(),
        authenticatedAt: Math.floor(Date.now() / 1_000) - 5,
      })),
    });
    for (const runtimeBindings of [bindings, { ...bindings, webAdmission: "contained" as const }]) {
      const deletion = await test.app.request(
        "/v1/member/step-up",
        {
          method: "POST",
          headers: {
            authorization: "Bearer valid-token",
            "content-type": "application/json",
            origin: betaOrigin,
          },
          body: JSON.stringify({ action: "argus_delete" }),
        },
        runtimeBindings,
      );
      expect(deletion.status).toBe(200);
    }
    const brokerage = await test.app.request(
      "/v1/member/step-up",
      {
        method: "POST",
        headers: {
          authorization: "Bearer valid-token",
          "content-type": "application/json",
          origin: betaOrigin,
        },
        body: JSON.stringify({ action: "webull_disconnect" }),
      },
      bindings,
    );
    expect(brokerage.status).toBe(200);

    const containedBrokerage = await test.app.request(
      "/v1/member/step-up",
      {
        method: "POST",
        headers: {
          authorization: "Bearer valid-token",
          "content-type": "application/json",
          origin: betaOrigin,
        },
        body: JSON.stringify({ action: "webull_disconnect" }),
      },
      { ...bindings, webAdmission: "contained" },
    );
    expect(containedBrokerage.status).toBe(503);
    expect(await containedBrokerage.json()).toMatchObject({
      error: { code: "web_admission_closed", retryable: true },
    });
    expect(issueStepUp).toHaveBeenCalledTimes(3);
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

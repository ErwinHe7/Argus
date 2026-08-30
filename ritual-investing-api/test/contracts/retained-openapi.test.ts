import SwaggerParser from "@apidevtools/swagger-parser";
import { describe, expect, it, vi } from "vitest";

import {
  buildRetainedOpenApiDocument,
  createRetainedApp,
  type RetainedRepositorySet,
} from "../../src/retained-app.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";

function contractApp() {
  return createRetainedApp({
    verifyAccessToken: vi.fn(async () => ({
      userId,
      sessionId,
      aal: "aal1" as const,
      issuedAt: 1,
    })),
    withRepositories: async (_claims, _transaction, callback) =>
      await callback({} as RetainedRepositorySet),
    withPublicPreview: async (callback) =>
      await callback({
        listPublishedPage: vi.fn(async () => []),
        listPublished: vi.fn(async () => []),
        getPublished: vi.fn(async () => null),
      }),
    createPrivacyService: () => ({} as never),
    rateLimit: { allow: vi.fn(async () => ({ allowed: true })) },
    requestId: () => "018f3c2a-4b67-7a89-8abc-123456789077",
  });
}

describe("Supabase retained OpenAPI contract", () => {
  it("is valid, targets the Edge base path, and exposes only Supabase bearer auth", async () => {
    const document = buildRetainedOpenApiDocument(contractApp());
    await SwaggerParser.validate(document as never);

    expect(document.info.version).toBe("2.0.0");
    expect(document.servers).toEqual([
      { url: "https://PROJECT_REF.supabase.co/functions/v1/api" },
    ]);
    expect(document.components?.securitySchemes).toEqual({
      SupabaseBearer: expect.objectContaining({
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
      }),
    });
    expect(JSON.stringify(document)).not.toMatch(/Auth0|CloudflareAccess/);
  });

  it("covers every U14 retained family and deliberately omits Demo financial authority", () => {
    const paths = buildRetainedOpenApiDocument(contractApp()).paths;
    const retainedFamilies = [
      "/v1/session/bootstrap",
      "/v1/account",
      "/v1/assets",
      "/v1/editorial/{kind}",
      "/v1/briefings",
      "/v1/circles",
      "/v1/coven",
      "/v1/coven/{entry_id}/evidence",
      "/v1/discover",
      "/v1/discover/assets",
      "/v1/discover/grimoires/{id}",
      "/v1/discover/creators",
      "/v1/media/upload-intents",
      "/v1/moderation/reports",
      "/v1/notifications",
      "/v1/privacy/requests",
      "/v1/intentions",
      "/v1/intentions/{intention_id}",
      "/v1/intentions/{intention_id}/future-mirror",
      "/v1/intentions/{intention_id}/future-mirror/latest",
      "/v1/intentions/{intention_id}/future-mirror/{run_id}",
      "/v1/public/editorial/{kind}",
      "/v1/rituals/{assignment_id}",
      "/v1/rowan/{surface}/{context_key}",
      "/v1/search",
      "/v1/admin/session",
      "/v1/admin/step-up",
      "/v1/admin/audit",
      "/v1/admin/editorial",
      "/v1/admin/editorial/{item_id}",
      "/v1/admin/editorial/{item_id}/revisions",
      "/v1/admin/editorial/{item_id}/revisions/{revision_id}",
      "/v1/admin/editorial/{item_id}/commands",
      "/v1/admin/operations/jobs",
      "/v1/admin/operations/jobs/{job_id}/retry",
      "/v1/admin/operations/privacy",
      "/v1/admin/operations/privacy/{request_id}/retry",
      "/v1/admin/operations/brokerage",
      "/v1/brokerage/accounts",
      "/v1/brokerage/accounts/{account_id}/capabilities",
      "/v1/brokerage/accounts/{account_id}/balances",
      "/v1/brokerage/accounts/{account_id}/positions",
      "/v1/brokerage/accounts/{account_id}/restrictions",
      "/v1/brokerage/accounts/{account_id}/orders",
      "/v1/brokerage/accounts/{account_id}/orders/{order_id}",
      "/v1/brokerage/accounts/{account_id}/orders/previews",
      "/v1/brokerage/accounts/{account_id}/orders/{order_id}/modify-preview",
      "/v1/brokerage/accounts/{account_id}/orders/{order_id}/cancel-preview",
      "/v1/brokerage/accounts/{account_id}/orders/{order_id}/cancel",
      "/v1/brokerage/order-commands/{command_id}",
    ];
    for (const path of retainedFamilies) {
      expect(paths, path).toHaveProperty(path);
    }

    const serialized = JSON.stringify(paths);
    expect(serialized).not.toMatch(
      /demo-|demo_reset|recurring-plans|rebalance|order-previews|funding-sources/,
    );
    expect(serialized).not.toMatch(
      /provider_asset_id|provider_account_id|provider_order_id/i,
    );
    expect(paths).not.toHaveProperty(
      "/v1/admin/brokerage/order-commands/{command_id}",
    );
  });

  it("publishes distinct typed envelopes for retained member reads", () => {
    const paths = buildRetainedOpenApiDocument(contractApp()).paths as Record<
      string,
      Record<string, { responses?: Record<string, unknown> }>
    >;
    const responseSchema = (path: string, method = "get") =>
      JSON.stringify(paths[path]?.[method]?.responses?.["200"] ?? {});

    for (
      const [path, expectedSchema] of [
        ["/v1/account", "MemberAccountResponse"],
        ["/v1/assets", "AssetCollectionResponse"],
        ["/v1/briefings", "BriefingCollectionResponse"],
        ["/v1/circles", "CircleCollectionResponse"],
        ["/v1/coven", "CovenCollectionResponse"],
        ["/v1/coven/{entry_id}/evidence", "CovenEvidenceResponse"],
        ["/v1/discover", "DiscoverResponse"],
        ["/v1/discover/assets", "DiscoverAssetCollectionResponse"],
        ["/v1/discover/grimoires/{id}", "GrimoireDetailResponse"],
        ["/v1/discover/creators", "CreatorCollectionResponse"],
        ["/v1/notifications", "NotificationCollectionResponse"],
        ["/v1/privacy/requests", "PrivacyRequestCollectionResponse"],
        ["/v1/search", "SearchResponse"],
      ] as const
    ) {
      expect(responseSchema(path), path).toContain(expectedSchema);
      expect(responseSchema(path), path).not.toContain("GetAccount200Response");
    }
  });

  it("keeps retained content precise and member-safe across generated boundaries", () => {
    const document = buildRetainedOpenApiDocument(contractApp());
    const serialized = JSON.stringify(document);
    for (
      const schema of [
        "AssetCodexDetail",
        "BriefingDetail",
        "CircleTemplateDetail",
        "CovenEntryDetail",
        "GrimoireDetail",
        "DiscoverItem",
        "SearchResult",
        "SeededCreator",
        "SaveItemRequest",
      ]
    ) {
      expect(document.components?.schemas, schema).toHaveProperty(schema);
    }
    expect(serialized).toContain("source_kind");
    expect(serialized).toContain("source_id");
    expect(serialized).not.toMatch(/provider_asset_id|provider_account_id/i);
  });

  it("publishes explicit Webull connection envelopes instead of generic maps", () => {
    const paths = buildRetainedOpenApiDocument(contractApp()).paths as Record<
      string,
      Record<string, { responses?: Record<string, unknown> }>
    >;
    for (
      const [path, method, schema] of [
        [
          "/v1/brokerage/connections/start",
          "post",
          "WebullAuthorizationSessionResponse",
        ],
        [
          "/v1/brokerage/connections/reconnect",
          "post",
          "WebullAuthorizationSessionResponse",
        ],
        ["/v1/brokerage/connection", "get", "WebullConnectionResponse"],
        [
          "/v1/brokerage/accounts/selection",
          "patch",
          "WebullAccountSelectionResponse",
        ],
        [
          "/v1/brokerage/connections/completions/redeem",
          "post",
          "WebullCompletionResponse",
        ],
        [
          "/v1/brokerage/connections/disconnect",
          "post",
          "WebullDisconnectResponse",
        ],
        ["/v1/member/step-up", "post", "MemberStepUpReceiptResponse"],
      ] as const
    ) {
      const response = JSON.stringify(
        paths[path]?.[method]?.responses?.["200"] ?? {},
      );
      expect(response, `${method} ${path}`).toContain(schema);
      expect(response, `${method} ${path}`).not.toContain(
        "ListAdminAudit200Response",
      );
    }
  });

  it("serves OpenAPI with ETag revalidation through the portable factory", async () => {
    const app = contractApp();
    const bindings = {
      environment: "test" as const,
      buildRevision: "must-not-enter-contract",
      consumerOrigins: Object.freeze(["https://app.ritual-investing.test"]),
      adminOrigin: "https://admin.ritual-investing.test",
      webAdmission: "open" as const,
    };
    const first = await app.request("/v1/openapi.json", undefined, bindings);
    expect(first.status).toBe(200);
    const body = await first.text();
    expect(body).not.toContain(bindings.buildRevision);
    const etag = first.headers.get("etag");
    expect(etag).toMatch(/^"openapi-[a-f0-9]{24}"$/);

    const unchanged = await app.request(
      "/v1/openapi.json",
      { headers: { "if-none-match": etag! } },
      bindings,
    );
    expect(unchanged.status).toBe(304);
  });
});

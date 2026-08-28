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
    createRepositories: vi.fn(() => ({} as RetainedRepositorySet)),
    publicPreviewRepository: {
      listPublished: vi.fn(async () => []),
      getPublished: vi.fn(async () => null),
    },
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
      "/v1/discover/assets",
      "/v1/media/upload-intents",
      "/v1/moderation/reports",
      "/v1/notifications",
      "/v1/privacy/requests",
      "/v1/public/editorial/{kind}",
      "/v1/rituals/{assignment_id}",
      "/v1/rowan/{surface}/{context_key}",
      "/v1/search",
      "/v1/admin/session",
      "/v1/admin/operations/jobs",
      "/v1/brokerage/accounts",
      "/v1/brokerage/accounts/{account_id}/capabilities",
      "/v1/brokerage/accounts/{account_id}/balances",
      "/v1/brokerage/accounts/{account_id}/positions",
      "/v1/brokerage/accounts/{account_id}/restrictions",
    ];
    for (const path of retainedFamilies) expect(paths, path).toHaveProperty(path);

    const serialized = JSON.stringify(paths);
    expect(serialized).not.toMatch(
      /demo-|demo_reset|recurring-plans|rebalance|order-previews|funding-sources/,
    );
    expect(serialized).not.toMatch(/provider_asset_id|provider_account_id/i);
  });

  it("serves OpenAPI with ETag revalidation through the portable factory", async () => {
    const app = contractApp();
    const bindings = {
      environment: "test" as const,
      buildRevision: "must-not-enter-contract",
      consumerOrigin: "https://app.ritual-investing.test",
      adminOrigin: "https://admin.ritual-investing.test",
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

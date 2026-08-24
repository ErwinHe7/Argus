import SwaggerParser from "@apidevtools/swagger-parser";
import { describe, expect, it } from "vitest";

import { createApp } from "../../src/app";
import { buildOpenApiDocument } from "../../src/contracts/openapi";

describe("OpenAPI contract", () => {
  it("declares anonymous liveness and permission-scoped session bootstrap", async () => {
    const document = buildOpenApiDocument(createApp());
    await SwaggerParser.validate(document as never);

    expect(document.openapi).toBe("3.0.3");
    expect(document.paths["/health"]?.get?.security).toEqual([]);
    expect(document.paths["/v1/health/live"]?.get?.security).toEqual([]);
    expect(document.paths["/v1/openapi.json"]?.get?.security).toEqual([]);
    expect(document.paths["/v1/openapi.json"]?.get?.responses).toMatchObject({
      200: { headers: { ETag: expect.any(Object) } },
      304: { headers: { ETag: expect.any(Object) } },
      429: expect.any(Object),
      503: expect.any(Object),
    });
    expect(document.paths["/v1/session/bootstrap"]?.post?.security).toEqual([
      { Auth0OAuth: ["write:self"] },
    ]);
    expect(document.paths["/v1/admin/session"]?.get?.security).toEqual([{
      CloudflareAccess: [],
      Auth0OAuth: ["admin:operations:read"],
    }]);
    expect(document.components?.securitySchemes).toHaveProperty("Auth0OAuth");
    expect(document.components?.securitySchemes).toHaveProperty("CloudflareAccess");
  });

  it("serves the anonymous contract with a revision ETag and no environment values", async () => {
    const app = createApp();
    const environment = {
      ENVIRONMENT: "production",
      BUILD_REVISION: "secret-build-value",
      API_ORIGIN: "https://api.ritual-investing.test",
      RL_HEALTH: { limit: async () => ({ success: true }) },
    } as never;
    const first = await app.request("/v1/openapi.json", undefined, environment);
    expect(first.status).toBe(200);
    const body = await first.text();
    expect(body).toContain('"openapi":"3.0.3"');
    expect(body).not.toContain("secret-build-value");
    const etag = first.headers.get("etag");
    expect(etag).toMatch(/^"openapi-[a-f0-9]+"$/);
    const unchanged = await app.request("/v1/openapi.json", { headers: { "if-none-match": etag! } }, environment);
    expect(unchanged.status).toBe(304);
  });

  it("contains shared errors and the lower-case idempotency header", () => {
    const document = buildOpenApiDocument(createApp());

    expect(document.components?.schemas).toHaveProperty("ErrorResponse");
    expect(document.components?.responses).toHaveProperty("ValidationError");
    expect(document.components?.parameters).toHaveProperty("IdempotencyKey");
    expect(document.components?.parameters?.IdempotencyKey).toMatchObject({
      in: "header",
      name: "idempotency-key",
    });
  });

  it("covers every U4 public and member editorial operation", () => {
    const document = buildOpenApiDocument(createApp());
    const publicGets = [
      "/v1/public/rituals/daily",
      "/v1/public/discover",
      "/v1/public/coven",
      "/v1/public/coven/{slug}",
    ];
    const memberGets = [
      "/v1/rituals/daily",
      "/v1/rituals/{assignment_id}",
      "/v1/rituals/{assignment_id}/evidence",
      "/v1/rituals/history",
      "/v1/rowan/counsel",
      "/v1/assets",
      "/v1/assets/{asset_id}",
      "/v1/assets/{asset_id}/evidence",
      "/v1/assets/{asset_id}/metrics",
      "/v1/search",
      "/v1/coven",
      "/v1/coven/{entry_id}",
      "/v1/coven/{entry_id}/evidence",
      "/v1/discover",
      "/v1/grimoires",
      "/v1/grimoires/{id}",
      "/v1/community/creators",
      "/v1/circle-templates",
      "/v1/circle-templates/{id}",
    ];

    for (const path of publicGets) {
      expect(document.paths[path]?.get?.security, path).toEqual([]);
      expect(Object.keys(document.paths[path]?.get?.responses ?? {}), path)
        .toEqual(expect.arrayContaining(["200", "304", "422", "429", "503"]));
    }
    for (const path of memberGets) {
      expect(document.paths[path]?.get?.security, path).toEqual([{
        Auth0OAuth: ["read:self"],
      }]);
      expect(Object.keys(document.paths[path]?.get?.responses ?? {}), path)
        .toEqual(expect.arrayContaining(["200", "401", "403", "413", "415", "422", "429", "503"]));
    }

    const compare = document.paths["/v1/assets/compare"]?.post;
    expect(compare?.security).toEqual([{ Auth0OAuth: ["read:self"] }]);
    const reveal = document.paths["/v1/rituals/{assignment_id}/reveal"]?.post;
    const complete = document.paths["/v1/rituals/{assignment_id}/complete"]?.post;
    for (const operation of [compare, reveal, complete]) {
      expect(Object.keys(operation?.responses ?? {})).toEqual(expect.arrayContaining([
        "200",
        "401",
        "403",
        "413",
        "415",
        "422",
        "429",
        "503",
      ]));
    }
    expect(reveal?.security).toEqual([{ Auth0OAuth: ["write:self"] }]);
    expect(complete?.security).toEqual([{ Auth0OAuth: ["write:self"] }]);
  });

  it("returns sanitized field errors for unknown properties", async () => {
    const app = createApp({ enableContractTestRoute: true });
    const response = await app.request("/v1/contract-test", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ title: "valid", tenantId: "secret-tenant" }),
    });
    const body = await response.json();

    expect(response.status).toBe(422);
    expect(body).toMatchObject({
      error: { code: "validation_failed", request_id: expect.any(String) },
    });
    expect(JSON.stringify(body)).not.toContain("secret-tenant");
  });
});

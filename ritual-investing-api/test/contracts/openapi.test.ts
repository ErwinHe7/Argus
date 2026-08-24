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

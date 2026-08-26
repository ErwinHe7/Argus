import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { buildOpenApiDocument } from "../../src/contracts/openapi";
import {
  assertTenantResource,
  createRequestDatabaseContext,
} from "../../src/db/request-context";
import { buildResourcePathMatrix } from "../../src/security/route-inventory";
import { createTestRsaKey } from "../support/jwt";
import {
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

describe("resource path IDOR matrix", () => {
  const document = buildOpenApiDocument(createApp());
  const matrix = buildResourcePathMatrix(document);

  it("inventories every resource identifier and never accepts tenant selection", () => {
    const parameterizedOperations = Object.entries(document.paths).flatMap(
      ([path, item]) =>
        Object.entries(item ?? {}).filter(
          ([method, operation]) =>
            ["get", "post", "put", "patch", "delete"].includes(method) &&
            path.includes("{") &&
            typeof operation === "object",
        ),
    );
    expect(matrix).toHaveLength(parameterizedOperations.length);
    expect(matrix.filter((entry) => entry.scope === "tenant")).not.toHaveLength(
      0,
    );
    expect(
      matrix
        .filter((entry) => entry.scope === "tenant")
        .every((entry) => !entry.parameters.includes("tenant_id")),
    ).toBe(true);
    expect(
      matrix.every(
        (entry) =>
          entry.operationId.length > 0 &&
          entry.guardOwner.length > 0 &&
          entry.enforcement.length > 0,
      ),
    ).toBe(true);
  });

  it("keeps the tenant assertion primitive non-enumerating", () => {
    const context = createRequestDatabaseContext({
      accountId: "00000000-0000-4000-8000-000000000001",
      tenantId: "00000000-0000-4000-8000-000000000002",
      principal: "auth0|member-a",
      revocationEpoch: 0,
    });
    expect(() =>
      assertTenantResource(context, "00000000-0000-4000-8000-000000000003"),
    ).toThrowError("resource_not_found");
  });

  it("marks mismatched parent/child identifiers for dedicated enforcement", () => {
    const nested = matrix.filter((entry) => entry.parameters.length > 1);
    expect(nested.length).toBeGreaterThan(0);
    expect(nested.every((entry) => entry.parentChildGuard)).toBe(true);
  });

  it("executes representative tenant read, write, delete, and nested parent-child denials", async () => {
    const key = createTestRsaKey("u9-resource-idor");
    const getCircle = vi.fn(async (_context: unknown, _id: string) => null);
    const patchCircle = vi.fn(
      async (
        _context: unknown,
        _id: string,
        _version: number,
        _input: unknown,
      ) => null,
    );
    const archiveCircle = vi.fn(
      async (_context: unknown, _id: string, _version: number) => false,
    );
    const deleteCircleAsset = vi.fn(
      async (
        _context: unknown,
        _id: string,
        _assetId: string,
        _version: number,
      ) => null,
    );
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        memberRepository: {
          getCircle,
          patchCircle,
          archiveCircle,
          deleteCircleAsset,
        },
      },
    } as never);
    const authorization = `Bearer ${memberToken(key)}`;
    const circle = "018f3c2a-4b67-7a89-8abc-123456789071";
    const asset = "018f3c2a-4b67-7a89-8abc-123456789081";
    const requests = [
      app.request(
        `/v1/circles/${circle}`,
        { headers: { authorization } },
        testBindings(),
      ),
      app.request(
        `/v1/circles/${circle}`,
        {
          method: "PATCH",
          headers: {
            authorization,
            "content-type": "application/json",
            "if-match": '"v1"',
          },
          body: JSON.stringify({ title: "Foreign" }),
        },
        testBindings(),
      ),
      app.request(
        `/v1/circles/${circle}`,
        { method: "DELETE", headers: { authorization, "if-match": '"v1"' } },
        testBindings(),
      ),
      app.request(
        `/v1/circles/${circle}/assets/${asset}`,
        { method: "DELETE", headers: { authorization, "if-match": '"v1"' } },
        testBindings(),
      ),
    ];
    for (const response of await Promise.all(requests)) {
      expect(response.status).toBe(404);
      expect(await response.json()).toMatchObject({
        error: { code: "not_found" },
      });
    }
    for (const repositoryCall of [
      getCircle,
      patchCircle,
      archiveCircle,
      deleteCircleAsset,
    ]) {
      expect(repositoryCall.mock.calls[0]?.[0]).toMatchObject({
        tenantId: resolvedMemberAccount.tenantId,
      });
    }
  });
});

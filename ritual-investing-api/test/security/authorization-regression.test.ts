import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { buildOpenApiDocument } from "../../src/contracts/openapi";
import { buildAuthorizationMatrix } from "../../src/security/route-inventory";
import { createTestRsaKey } from "../support/jwt";
import {
  ADMIN_CLIENT_ID,
  accessToken,
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

const pathId = "018f3c2a-4b67-7a89-8abc-123456789001";

describe("authorization regression inventory", () => {
  const auth0Key = createTestRsaKey("u9-auth0-key");
  const accessKey = createTestRsaKey("u9-access-key");
  const document = buildOpenApiDocument(createApp());
  const matrix = buildAuthorizationMatrix(document);
  const app = createApp({
    dependencies: {
      auth0Keys: [auth0Key.publicJwk],
      accessKeys: [accessKey.publicJwk],
      accountResolver: vi.fn(async () => resolvedMemberAccount),
      resolveStaff: vi.fn(async () => ({
        id: "018f3c2a-4b67-7a89-8abc-123456789010",
        auth0Subject: "auth0|staff-1",
        accessIdentity: "operator@ritual-investing.test",
        allowedClientId: ADMIN_CLIENT_ID,
        displayLabel: "Ritual Operator",
        revocationEpoch: 0,
      })),
      auditDeniedAdminAttempt: vi.fn(async () => undefined),
    },
  } as never);

  function concretePath(path: string) {
    return path.replaceAll(/\{[^}]+\}/g, pathId);
  }

  function validHeaders(entry: (typeof matrix)[number], allowed: boolean) {
    const permissions = allowed ? entry.permissions : [];
    const token = memberToken(auth0Key, {
      sub: entry.actor === "admin" ? "auth0|staff-1" : "auth0|member-1",
      azp: entry.actor === "admin" ? ADMIN_CLIENT_ID : "ritual-consumer-client",
      permissions,
      auth_time: Math.floor(Date.now() / 1000),
    });
    return {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
      ...(entry.actor === "admin"
        ? { "cf-access-jwt-assertion": accessToken(accessKey) }
        : {}),
    };
  }

  async function request(
    entry: (typeof matrix)[number],
    headers: Record<string, string>,
  ) {
    const host =
      entry.actor === "admin"
        ? "https://admin-api.ritual-investing.test"
        : "https://api.ritual-investing.test";
    return app.request(
      `${host}${concretePath(entry.path)}`,
      {
        method: entry.method,
        headers: { "content-type": "application/json", ...headers },
        ...(entry.method === "GET" ? {} : { body: "{}" }),
      },
      testBindings(),
    );
  }

  it("inventories every protected OpenAPI operation", () => {
    const protectedCount = Object.values(document.paths).reduce(
      (count, item) =>
        count +
        Object.values(item ?? {}).filter(
          (operation) =>
            typeof operation === "object" &&
            operation !== null &&
            Array.isArray((operation as { security?: unknown }).security) &&
            (operation as { security: unknown[] }).security.length > 0,
        ).length,
      0,
    );
    expect(matrix).toHaveLength(protectedCount);
    expect(
      matrix.every(
        (entry) => entry.permissions.length > 0 || entry.identityOnly,
      ),
    ).toBe(true);
  });

  it("denies anonymous and missing-permission callers, then admits allowed roles", async () => {
    for (const entry of matrix) {
      const anonymous = await request(entry, {});
      expect(
        [401, 403, 404],
        `${entry.method} ${entry.path} anonymous`,
      ).toContain(anonymous.status);

      if (!entry.identityOnly) {
        const missing = await request(entry, validHeaders(entry, false));
        expect(
          [401, 403],
          `${entry.method} ${entry.path} missing permission`,
        ).toContain(missing.status);
      }

      const allowed = await request(entry, validHeaders(entry, true));
      expect(
        [401, 403],
        `${entry.method} ${entry.path} allowed role returned ${allowed.status}`,
      ).not.toContain(allowed.status);
    }
  }, 30_000);
});

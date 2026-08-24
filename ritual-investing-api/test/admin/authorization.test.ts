import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import {
  ADMIN_CLIENT_ID,
  accessToken,
  memberToken,
  testBindings,
} from "../support/security-fixtures";

const staffId = "018f3c2a-4b67-7a89-8abc-123456789010";
const itemId = "018f3c2a-4b67-7a89-8abc-123456789011";
const revisionId = "018f3c2a-4b67-7a89-8abc-123456789012";

describe("admin authorization and denied-attempt audit", () => {
  const auth0Key = createTestRsaKey("u8-authorization-auth0");
  const accessKey = createTestRsaKey("u8-authorization-access");
  const resolveStaff = vi.fn(async () => ({
    id: staffId,
    auth0Subject: "auth0|staff-1",
    accessIdentity: "operator@ritual-investing.test",
    allowedClientId: ADMIN_CLIENT_ID,
    displayLabel: "Ritual Operator",
    revocationEpoch: 0,
  }));

  function headers(permissions: string[]) {
    return {
      authorization: `Bearer ${memberToken(auth0Key, {
        sub: "auth0|staff-1",
        azp: ADMIN_CLIENT_ID,
        permissions,
      })}`,
      "cf-access-jwt-assertion": accessToken(accessKey),
      "content-type": "application/json",
      "idempotency-key": "review-01JY7W4M5GYJ2E47KCEPD88N2K",
    };
  }

  it("audits a denied high-trust transition without invoking the repository", async () => {
    const auditDeniedAdminAttempt = vi.fn(async () => undefined);
    const decideReview = vi.fn();
    const app = createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accessKeys: [accessKey.publicJwk],
        resolveStaff,
        auditDeniedAdminAttempt,
        adminEditorialRepository: { decideReview },
      },
    } as never);
    const response = await app.request(
      `https://admin-api.ritual-investing.test/v1/admin/ritual-scenarios/${itemId}/revisions/${revisionId}/review-decisions`,
      {
        method: "POST",
        headers: headers(["admin:editorial:write"]),
        body: JSON.stringify({
          decision: "approved",
          reason: "Evidence is complete.",
        }),
      },
      testBindings(),
    );

    expect(response.status).toBe(403);
    expect(decideReview).not.toHaveBeenCalled();
    expect(auditDeniedAdminAttempt).toHaveBeenCalledWith(
      {
        actorStaffId: staffId,
        permission: "admin:editorial:review",
        method: "POST",
        requestId: expect.any(String),
      },
      expect.any(Object),
    );
  });

  it("fails closed when the denial audit cannot be persisted", async () => {
    const app = createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accessKeys: [accessKey.publicJwk],
        resolveStaff,
        auditDeniedAdminAttempt: vi.fn(async () => {
          throw new Error("database unavailable");
        }),
        adminEditorialRepository: { decideReview: vi.fn() },
      },
    } as never);
    const response = await app.request(
      `https://admin-api.ritual-investing.test/v1/admin/ritual-scenarios/${itemId}/revisions/${revisionId}/review-decisions`,
      {
        method: "POST",
        headers: headers(["admin:editorial:write"]),
        body: JSON.stringify({
          decision: "approved",
          reason: "Evidence is complete.",
        }),
      },
      testBindings(),
    );
    expect(response.status).toBe(503);
  });

  it.each([
    ["member profile", "/v1/me/profile", "GET"],
    ["private Circles", "/v1/circles", "GET"],
    ["portfolio", "/v1/portfolios", "GET"],
    [
      "privacy export download",
      `/v1/me/privacy/exports/${itemId}/download?token=not-a-token`,
      "GET",
    ],
    ["simulation", "/v1/demo-funding-sources", "GET"],
  ])(
    "cannot use an admin token as a %s backdoor",
    async (_name, path, method) => {
      const app = createApp({
        dependencies: {
          auth0Keys: [auth0Key.publicJwk],
          accessKeys: [accessKey.publicJwk],
          resolveStaff,
        },
      } as never);
      const response = await app.request(
        `https://api.ritual-investing.test${path}`,
        { method, headers: headers(["admin:operations:read"]) },
        testBindings(),
      );
      expect([401, 403, 404]).toContain(response.status);
    },
  );
});

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
const reportId = "018f3c2a-4b67-7a89-8abc-123456789011";
const caseId = "018f3c2a-4b67-7a89-8abc-123456789012";

describe("admin moderation operations", () => {
  const auth0Key = createTestRsaKey("u8-operations-auth0");
  const accessKey = createTestRsaKey("u8-operations-access");
  const headers = {
    authorization: `Bearer ${memberToken(auth0Key, {
      sub: "auth0|staff-moderator",
      azp: ADMIN_CLIENT_ID,
      permissions: ["admin:moderation:write"],
    })}`,
    "cf-access-jwt-assertion": accessToken(accessKey),
    "content-type": "application/json",
    "idempotency-key": "moderation-case-01JY7W4M5GYJ2E47KCEPD88N2K",
  };

  it("creates an audited case through the idempotent moderation seam", async () => {
    const createCase = vi.fn(async () => ({
      id: caseId,
      report: {
        id: reportId,
        target_kind: "ritual",
        target_id: "018f3c2a-4b67-7a89-8abc-123456789013",
        reason_code: "misleading",
        detail: null,
        status: "triaged",
        created_at: "2026-08-24T12:00:00Z",
      },
      status: "open",
      assignee_id: null,
      resolution_code: null,
      resolved_at: null,
      version: 1,
      etag: '"v1"',
      decisions: [],
    }));
    const app = createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accessKeys: [accessKey.publicJwk],
        resolveStaff: vi.fn(async () => ({
          id: staffId,
          auth0Subject: "auth0|staff-moderator",
          accessIdentity: "moderator@ritual-investing.test",
          allowedClientId: ADMIN_CLIENT_ID,
          displayLabel: "Moderator",
          revocationEpoch: 0,
        })),
        adminModerationRepository: { createCase },
      },
    } as never);

    const response = await app.request(
      `https://admin-api.ritual-investing.test/v1/admin/moderation/reports/${reportId}/cases`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({ note: "Open for independent review." }),
      },
      testBindings(),
    );

    expect(response.status, await response.clone().text()).toBe(201);
    expect(response.headers.get("etag")).toBe('"v1"');
    expect(createCase).toHaveBeenCalledWith(
      expect.objectContaining({
        actorStaffId: staffId,
        reportId,
        idempotencyKey: headers["idempotency-key"],
      }),
    );
  });
});

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
const qualificationId = "018f3c2a-4b67-7a89-8abc-123456789011";
const verificationId = "018f3c2a-4b67-7a89-8abc-123456789012";
const claimId = "018f3c2a-4b67-7a89-8abc-123456789013";

describe("admin Coven verification", () => {
  const auth0Key = createTestRsaKey("u8-coven-auth0");
  const accessKey = createTestRsaKey("u8-coven-access");
  const resolveStaff = vi.fn(async () => ({
    id: staffId,
    auth0Subject: "auth0|staff-verifier",
    accessIdentity: "verifier@ritual-investing.test",
    allowedClientId: ADMIN_CLIENT_ID,
    displayLabel: "Coven Verifier",
    revocationEpoch: 0,
  }));

  function headers(permissions: string[]) {
    return {
      authorization: `Bearer ${memberToken(auth0Key, {
        sub: "auth0|staff-verifier",
        azp: ADMIN_CLIENT_ID,
        permissions,
      })}`,
      "cf-access-jwt-assertion": accessToken(accessKey),
      "content-type": "application/json",
      "idempotency-key": "coven-verify-01JY7W4M5GYJ2E47KCEPD88N2K",
    };
  }

  const body = {
    evidence_claim_ids: [claimId],
    effective_as_of: "2026-08-24",
    decision: "verified",
    reason: "Independent evidence review completed.",
  };

  it("routes a high-trust decision only through the Coven permission", async () => {
    const append = vi.fn(async () => ({
      id: verificationId,
      qualification_id: qualificationId,
      status: "verified",
      effective_as_of: "2026-08-24",
      verified_at: "2026-08-24T12:00:00Z",
      verified_by: staffId,
      supersedes_id: null,
      evidence_claim_ids: [claimId],
    }));
    const app = createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accessKeys: [accessKey.publicJwk],
        resolveStaff,
        adminCatalogRepository: { append },
      },
    } as never);

    const response = await app.request(
      `https://admin-api.ritual-investing.test/v1/admin/coven-qualifications/${qualificationId}/verifications`,
      {
        method: "POST",
        headers: headers(["admin:coven:verify"]),
        body: JSON.stringify(body),
      },
      testBindings(),
    );

    expect(response.status, await response.clone().text()).toBe(201);
    expect(append).toHaveBeenCalledWith(
      expect.objectContaining({
        actorStaffId: staffId,
        action: "coven_verification",
        parentId: qualificationId,
        payload: body,
      }),
    );
  });

  it("audits and rejects an editor who lacks verification permission", async () => {
    const append = vi.fn();
    const auditDeniedAdminAttempt = vi.fn(async () => undefined);
    const app = createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accessKeys: [accessKey.publicJwk],
        resolveStaff,
        auditDeniedAdminAttempt,
        adminCatalogRepository: { append },
      },
    } as never);

    const response = await app.request(
      `https://admin-api.ritual-investing.test/v1/admin/coven-qualifications/${qualificationId}/verifications`,
      {
        method: "POST",
        headers: headers(["admin:editorial:write"]),
        body: JSON.stringify(body),
      },
      testBindings(),
    );

    expect(response.status).toBe(403);
    expect(append).not.toHaveBeenCalled();
    expect(auditDeniedAdminAttempt).toHaveBeenCalledWith(
      expect.objectContaining({ permission: "admin:coven:verify" }),
      expect.any(Object),
    );
  });
});

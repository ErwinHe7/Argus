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

describe("admin immutable audit surface", () => {
  const auth0Key = createTestRsaKey("u8-audit-auth0");
  const accessKey = createTestRsaKey("u8-audit-access");
  const headers = {
    authorization: `Bearer ${memberToken(auth0Key, {
      sub: "auth0|staff-auditor",
      azp: ADMIN_CLIENT_ID,
      permissions: ["admin:audit:read"],
    })}`,
    "cf-access-jwt-assertion": accessToken(accessKey),
  };

  function app(listAudit = vi.fn(async () => ({ items: [], next: null }))) {
    return {
      listAudit,
      app: createApp({
        dependencies: {
          auth0Keys: [auth0Key.publicJwk],
          accessKeys: [accessKey.publicJwk],
          resolveStaff: vi.fn(async () => ({
            id: staffId,
            auth0Subject: "auth0|staff-auditor",
            accessIdentity: "auditor@ritual-investing.test",
            allowedClientId: ADMIN_CLIENT_ID,
            displayLabel: "Audit Reader",
            revocationEpoch: 0,
          })),
          adminRepository: { listAudit },
        },
      } as never),
    };
  }

  it("passes only bounded filters to the redacted audit repository", async () => {
    const fixture = app();
    const response = await fixture.app.request(
      "https://admin-api.ritual-investing.test/v1/admin/audit-events?action=editorial.publish&target_kind=editorial_item&limit=50",
      { headers },
      testBindings(),
    );

    expect(response.status, await response.clone().text()).toBe(200);
    expect(fixture.listAudit).toHaveBeenCalledWith({
      actorStaffId: staffId,
      action: "editorial.publish",
      targetKind: "editorial_item",
      limit: 50,
    });
    expect(await response.json()).toMatchObject({ data: [] });
  });

  it("rejects an enumeration-sized audit page before the repository", async () => {
    const fixture = app();
    const response = await fixture.app.request(
      "https://admin-api.ritual-investing.test/v1/admin/audit-events?limit=51",
      { headers },
      testBindings(),
    );

    expect(response.status).toBe(422);
    expect(fixture.listAudit).not.toHaveBeenCalled();
  });
});

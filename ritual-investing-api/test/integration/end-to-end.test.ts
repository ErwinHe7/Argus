import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { createDeterministicContentRepository } from "../../src/domains/editorial/fixtures";
import { createTestRsaKey } from "../support/jwt";
import {
  ADMIN_CLIENT_ID,
  accessToken,
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

describe("production-shaped member and staff flow", () => {
  it("crosses public, member, and dual-auth staff boundaries locally", async () => {
    const auth0Key = createTestRsaKey("u9-e2e-auth0");
    const accessKey = createTestRsaKey("u9-e2e-access");
    const contentRepository = createDeterministicContentRepository();
    const app = createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accessKeys: [accessKey.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        contentRepository,
        publicContentRepository: contentRepository,
        now: () => new Date("2026-08-24T12:00:00.000Z"),
        resolveStaff: vi.fn(async () => ({
          id: "018f3c2a-4b67-7a89-8abc-123456789010",
          auth0Subject: "auth0|staff-1",
          accessIdentity: "operator@ritual-investing.test",
          allowedClientId: ADMIN_CLIENT_ID,
          displayLabel: "Ritual Operator",
          revocationEpoch: 0,
        })),
      },
    } as never);
    const bindings = testBindings();

    const preview = await app.request(
      "/v1/public/rituals/daily",
      undefined,
      bindings,
    );
    expect(preview.status).toBe(200);
    expect(preview.headers.get("cache-control")).toMatch(/public/);

    const member = await app.request(
      "/v1/rituals/daily",
      { headers: { authorization: `Bearer ${memberToken(auth0Key)}` } },
      bindings,
    );
    expect(member.status).toBe(200);
    expect(member.headers.get("cache-control")).toBe("private, no-store");

    const staff = await app.request(
      "https://admin-api.ritual-investing.test/v1/admin/me",
      {
        headers: {
          authorization: `Bearer ${memberToken(auth0Key, {
            sub: "auth0|staff-1",
            azp: ADMIN_CLIENT_ID,
            permissions: ["admin:operations:read"],
          })}`,
          "cf-access-jwt-assertion": accessToken(accessKey),
        },
      },
      bindings,
    );
    expect(staff.status).toBe(200);
    expect(staff.headers.get("cache-control")).toBe("private, no-store");
  });

  const stagingConfigured = [
    process.env.STAGING_BASE_URL,
    process.env.STAGING_ADMIN_UI_URL,
    process.env.STAGING_MEMBER_TOKEN,
    process.env.STAGING_ADMIN_TOKEN,
    process.env.STAGING_CF_ACCESS_ASSERTION,
  ].every((value) => value !== undefined && value.trim().length > 0);

  it("requires every staging credential when staging verification is requested", () => {
    if (process.env.REQUIRE_STAGING_E2E !== "true") return;
    const required = [
      "STAGING_BASE_URL",
      "STAGING_ADMIN_UI_URL",
      "STAGING_MEMBER_TOKEN",
      "STAGING_ADMIN_TOKEN",
      "STAGING_CF_ACCESS_ASSERTION",
    ] as const;
    const missing = required.filter((name) => !process.env[name]?.trim());
    expect(missing, `Missing required staging credentials: ${missing.join(", ")}`).toEqual([]);
  });

  it.skipIf(!stagingConfigured)(
    "proves production-equivalent staging bindings",
    async () => {
      const base = process.env.STAGING_BASE_URL!;
      const adminUi = await fetch(process.env.STAGING_ADMIN_UI_URL!);
      expect(adminUi.status).toBe(200);
      expect(adminUi.headers.get("cache-control")).toMatch(/no-store/);
      expect(adminUi.headers.get("x-content-type-options")).toBe("nosniff");
      const adminHtml = await adminUi.text();
      expect(adminHtml).toContain("flutter_bootstrap.js");
      expect(adminHtml).not.toContain("dashboard is not configured");
      const preview = await fetch(`${base}/v1/public/rituals/daily`);
      expect(preview.status).toBe(200);
      expect(preview.headers.get("cache-control")).toMatch(/public/);

      const member = await fetch(`${base}/v1/me`, {
        headers: {
          authorization: `Bearer ${process.env.STAGING_MEMBER_TOKEN}`,
        },
      });
      expect(member.status).toBe(200);
      expect(member.headers.get("cache-control")).toMatch(/no-store/);

      const ready = await fetch(`${base}/v1/admin/health/ready`, {
        headers: {
          authorization: `Bearer ${process.env.STAGING_ADMIN_TOKEN}`,
          "cf-access-jwt-assertion": process.env.STAGING_CF_ACCESS_ASSERTION!,
        },
      });
      expect(ready.status).toBe(200);
      expect(await ready.json()).toMatchObject({ data: { status: "ready" } });
    },
    30_000,
  );
});

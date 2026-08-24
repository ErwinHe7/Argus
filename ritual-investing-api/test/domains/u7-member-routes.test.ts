import { beforeAll, describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { protectPushToken } from "../../src/domains/notifications/service";
import { createTestRsaKey } from "../support/jwt";
import {
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

describe("U7 member routes", () => {
  let key: Awaited<ReturnType<typeof createTestRsaKey>>;
  beforeAll(async () => {
    key = await createTestRsaKey("u7-member-routes");
  });

  it("serves Daily from the immutable projection without generation work", async () => {
    const daily = vi.fn().mockResolvedValue({
      id: "018f3c2a-4b67-7a89-8abc-123456789010",
      briefing_type: "daily",
      period_start: "2026-08-24",
      period_end: "2026-08-24",
      generation: 1,
      source_sequence: 42,
      generated_at: "2026-08-24T05:00:00.000Z",
      read_at: null,
      sections: [],
    });
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        briefingRepository: {
          daily,
          list: vi.fn(),
          get: vi.fn(),
          markRead: vi.fn(),
        },
      },
    });
    const response = await app.request(
      "/v1/briefings/daily?local_date=2026-08-24",
      { headers: { authorization: `Bearer ${await memberToken(key)}` } },
      testBindings(),
    );
    expect(response.status).toBe(200);
    expect(daily).toHaveBeenCalledOnce();
  });

  it("requires privacy:self and authentication no older than five minutes", async () => {
    const requestExport = vi.fn().mockResolvedValue({
      id: "018f3c2a-4b67-7a89-8abc-123456789020",
      request_type: "export",
      status: "queued",
      snapshot_at: "2026-08-24T05:00:00.000Z",
      completed_at: null,
      expires_at: "2026-08-31T05:00:00.000Z",
      failure_code: null,
      format: "zip",
      download_link: null,
    });
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        privacyRepository: {
          requestExport,
          getRequest: vi.fn(),
          createDownloadLink: vi.fn(),
          requestDeletion: vi.fn(),
          consumeDownload: vi.fn(),
        },
      },
    });
    const makeRequest = async (issuedAt: number) =>
      app.request(
        "/v1/me/privacy/exports",
        {
          method: "POST",
          headers: {
            authorization: `Bearer ${await memberToken(key, {
              permissions: ["privacy:self"],
              iat: issuedAt,
            })}`,
            "content-type": "application/json",
            "idempotency-key": "privacy-export-00000001",
          },
          body: '{"format":"zip"}',
        },
        testBindings(),
      );
    const now = Math.floor(Date.now() / 1000);
    expect((await makeRequest(now - 301)).status).toBe(403);
    const current = await makeRequest(now - 5);
    expect(current.status, await current.clone().text()).toBe(202);
    expect(requestExport).toHaveBeenCalledOnce();
  });

  it("protects push tokens without retaining plaintext in either stored field", async () => {
    const keyBytes = crypto.getRandomValues(new Uint8Array(32));
    const encoded = btoa(String.fromCharCode(...keyBytes))
      .replaceAll("+", "-")
      .replaceAll("/", "_")
      .replaceAll("=", "");
    const token = "provider-device-token-do-not-store-raw";
    const protectedToken = await protectPushToken(token, encoded);
    expect(protectedToken.tokenCiphertext).not.toContain(token);
    expect(protectedToken.tokenHash).not.toContain(token);
  });
});

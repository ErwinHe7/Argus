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
    const makeRequest = async (
      issuedAt: number,
      authenticatedAt?: number,
    ) =>
      app.request(
        "/v1/me/privacy/exports",
        {
          method: "POST",
          headers: {
            authorization: `Bearer ${await memberToken(key, {
              permissions: ["privacy:self"],
              iat: issuedAt,
              ...(authenticatedAt === undefined
                ? {}
                : {
                    "https://ritual-investing.app/authenticated_at":
                      authenticatedAt,
                  }),
            })}`,
            "content-type": "application/json",
            "idempotency-key": "privacy-export-00000001",
          },
          body: '{"format":"zip"}',
        },
        {
          ...testBindings(),
          ASYNC_QUEUE: { send: vi.fn(), sendBatch: vi.fn() },
          JOBS_DLQ: { send: vi.fn(), sendBatch: vi.fn() },
          PRIVACY_EXPORTS: {},
          RUNTIME_DATABASE_URL: "postgres://runtime.test/ritual",
          SCHEDULER_DATABASE_URL: "postgres://scheduler.test/ritual",
        } as never,
      );
    const now = Math.floor(Date.now() / 1000);
    expect((await makeRequest(now - 5)).status).toBe(403);
    expect((await makeRequest(now, now - 301)).status).toBe(403);
    const current = await makeRequest(now, now - 5);
    expect(current.status, await current.clone().text()).toBe(202);
    expect(requestExport).toHaveBeenCalledOnce();
  });

  it.each([
    {
      name: "export",
      path: "/v1/me/privacy/exports",
      body: '{"format":"zip"}',
      repositoryMethod: "requestExport" as const,
      bindings: {
        ...testBindings(),
        PRIVACY_EXPORTS: {},
      },
    },
    {
      name: "deletion",
      path: "/v1/me/privacy/deletion-requests",
      body: '{"confirmation":"DELETE"}',
      repositoryMethod: "requestDeletion" as const,
      bindings: {
        ...testBindings(),
        ASYNC_QUEUE: { send: vi.fn(), sendBatch: vi.fn() },
        PRIVACY_EXPORTS: {},
        MEDIA_QUARANTINE: {},
      },
    },
  ])(
    "rejects $name before repository mutation when its processor is unavailable",
    async ({ path, body, repositoryMethod, bindings }) => {
      const requestExport = vi.fn();
      const requestDeletion = vi.fn();
      const app = createApp({
        dependencies: {
          auth0Keys: [key.publicJwk],
          accountResolver: async () => resolvedMemberAccount,
          privacyRepository: {
            requestExport,
            getRequest: vi.fn(),
            createDownloadLink: vi.fn(),
            requestDeletion,
            consumeDownload: vi.fn(),
          },
        },
      });
      const now = Math.floor(Date.now() / 1000);
      const response = await app.request(
        path,
        {
          method: "POST",
          headers: {
            authorization: `Bearer ${await memberToken(key, {
              permissions: ["privacy:self"],
              iat: now,
              "https://ritual-investing.app/authenticated_at": now,
            })}`,
            "content-type": "application/json",
            "idempotency-key": `privacy-${repositoryMethod}-00000001`,
          },
          body,
        },
        bindings as never,
      );

      expect(response.status).toBe(503);
      await expect(response.json()).resolves.toMatchObject({
        error: {
          code: "service_unavailable",
          retryable: true,
        },
      });
      expect({ requestExport, requestDeletion }[repositoryMethod]).not.toHaveBeenCalled();
    },
  );

  it.each([
    {
      name: "export",
      path: "/v1/me/privacy/exports",
      body: '{"format":"zip"}',
      bindings: {
        ...testBindings(),
        ASYNC_QUEUE: { send: vi.fn(), sendBatch: vi.fn() },
        RUNTIME_DATABASE_URL: "postgres://runtime.test/ritual",
        SCHEDULER_DATABASE_URL: "postgres://scheduler.test/ritual",
        PRIVACY_EXPORTS: {},
      },
    },
    {
      name: "deletion",
      path: "/v1/me/privacy/deletion-requests",
      body: '{"confirmation":"DELETE"}',
      bindings: {
        ...testBindings(),
        ASYNC_QUEUE: { send: vi.fn(), sendBatch: vi.fn() },
        RUNTIME_DATABASE_URL: "postgres://runtime.test/ritual",
        SCHEDULER_DATABASE_URL: "postgres://scheduler.test/ritual",
        PRIVACY_DATABASE_URL: "postgres://privacy.test/ritual",
        PRIVACY_EXPORTS: {},
        MEDIA_QUARANTINE: {},
        DELETION_DENY_JOURNAL: {},
      },
    },
  ])("requires durable dead-lettering before $name mutation", async ({
    path,
    body,
    bindings,
  }) => {
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
    const requestDeletion = vi.fn().mockResolvedValue({
      request_id: "018f3c2a-4b67-7a89-8abc-123456789021",
      tombstone_id: "018f3c2a-4b67-7a89-8abc-123456789022",
      status: "queued",
      effective_at: "2026-08-24T05:00:00.000Z",
      purge_by: "2026-09-23T05:00:00.000Z",
      purge_generation: 4,
    });
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        privacyRepository: {
          requestExport,
          getRequest: vi.fn(),
          createDownloadLink: vi.fn(),
          requestDeletion,
          consumeDownload: vi.fn(),
        },
      },
    });
    const now = Math.floor(Date.now() / 1000);
    const response = await app.request(
      path,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${await memberToken(key, {
            permissions: ["privacy:self"],
            iat: now,
            "https://ritual-investing.app/authenticated_at": now,
          })}`,
          "content-type": "application/json",
          "idempotency-key": "privacy-dlq-proof-00000001",
        },
        body,
      },
      bindings as never,
    );

    expect(response.status).toBe(503);
    expect(requestExport).not.toHaveBeenCalled();
    expect(requestDeletion).not.toHaveBeenCalled();
  });

  it("keeps the deprecated Cloudflare deletion path disabled even with legacy bindings", async () => {
    const receipt = {
      request_id: "018f3c2a-4b67-7a89-8abc-123456789021",
      tombstone_id: "018f3c2a-4b67-7a89-8abc-123456789022",
      status: "queued" as const,
      effective_at: "2026-08-24T05:00:00.000Z",
      purge_by: "2026-09-23T05:00:00.000Z",
      purge_generation: 4,
    };
    const requestDeletion = vi.fn().mockResolvedValue(receipt);
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        privacyRepository: {
          requestExport: vi.fn(),
          getRequest: vi.fn(),
          createDownloadLink: vi.fn(),
          requestDeletion,
          consumeDownload: vi.fn(),
        },
      },
    });
    const now = Math.floor(Date.now() / 1000);
    const response = await app.request(
      "/v1/me/privacy/deletion-requests",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${await memberToken(key, {
            permissions: ["privacy:self"],
            iat: now,
            "https://ritual-investing.app/authenticated_at": now,
          })}`,
          "content-type": "application/json",
          "idempotency-key": "privacy-deletion-ready-0001",
        },
        body: '{"confirmation":"DELETE"}',
      },
      {
        ...testBindings(),
        ASYNC_QUEUE: { send: vi.fn(), sendBatch: vi.fn() },
        JOBS_DLQ: { send: vi.fn(), sendBatch: vi.fn() },
        RUNTIME_DATABASE_URL: "postgres://runtime.test/ritual",
        SCHEDULER_DATABASE_URL: "postgres://scheduler.test/ritual",
        PRIVACY_DATABASE_URL: "postgres://privacy.test/ritual",
        PRIVACY_EXPORTS: {},
        MEDIA_QUARANTINE: {},
        DELETION_DENY_JOURNAL: {},
      } as never,
    );

    expect(response.status, await response.clone().text()).toBe(503);
    await expect(response.json()).resolves.toMatchObject({
      error: { code: "service_unavailable", retryable: true },
    });
    expect(requestDeletion).not.toHaveBeenCalled();
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

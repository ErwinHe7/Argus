import { beforeAll, describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app.ts";
import { NotificationContentNotFoundError } from "../../src/domains/notifications/repository.ts";
import { createTestRsaKey } from "../support/jwt.ts";
import {
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures.ts";

describe("notification contracts", () => {
  let key: Awaited<ReturnType<typeof createTestRsaKey>>;
  beforeAll(async () => {
    key = await createTestRsaKey("u7-notifications");
  });

  const authorization = async () => ({
    authorization: `Bearer ${await memberToken(key)}`,
  });
  const repository = () => ({
    getPreferences: vi
      .fn()
      .mockResolvedValue({
        daily_ritual: true,
        weekly_recap: true,
        moon_cycle: true,
        quiet_hours: {
          enabled: false,
          start: "22:00",
          end: "07:00",
          timezone: "UTC",
        },
        version: 1,
      }),
    patchPreferences: vi
      .fn()
      .mockResolvedValue({
        daily_ritual: false,
        weekly_recap: true,
        moon_cycle: true,
        quiet_hours: {
          enabled: false,
          start: "22:00",
          end: "07:00",
          timezone: "UTC",
        },
        version: 2,
      }),
    registerDevice: vi
      .fn()
      .mockResolvedValue({
        id: "018f3c2a-4b67-7a89-8abc-123456789001",
        platform: "ios",
        status: "active",
      }),
    revokeDevice: vi.fn().mockResolvedValue(true),
    list: vi
      .fn()
      .mockResolvedValue({
        items: [],
        next: "018f3c2a-4b67-7a89-8abc-123456789002",
      }),
    markRead: vi.fn(),
    markAllRead: vi.fn().mockResolvedValue(100),
    report: vi
      .fn()
      .mockResolvedValue({
        id: "018f3c2a-4b67-7a89-8abc-123456789003",
        status: "received",
      }),
  });

  it("requires If-Match and validates IANA quiet-hour timezones", async () => {
    const repo = repository();
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        notificationRepository: repo,
      },
    });
    const headers = {
      ...(await authorization()),
      "content-type": "application/json",
    };
    expect(
      (
        await app.request(
          "/v1/me/notification-preferences",
          { method: "PATCH", headers, body: '{"daily_ritual":false}' },
          testBindings(),
        )
      ).status,
    ).toBe(422);
    expect(
      (
        await app.request(
          "/v1/me/notification-preferences",
          {
            method: "PATCH",
            headers: { ...headers, "if-match": '"v1"' },
            body: '{"quiet_hours":{"enabled":true,"start":"22:00","end":"07:00","timezone":"Mars/Olympus"}}',
          },
          testBindings(),
        )
      ).status,
    ).toBe(422);
    const valid = await app.request(
      "/v1/me/notification-preferences",
      {
        method: "PATCH",
        headers: { ...headers, "if-match": '"v1"' },
        body: '{"daily_ritual":false}',
      },
      testBindings(),
    );
    expect(valid.status).toBe(200);
    expect(repo.patchPreferences).toHaveBeenCalledWith(
      expect.any(Object),
      { daily_ritual: false },
      1,
    );
  });

  it("requires a retry-stable key on the sensitive device registration seam", async () => {
    const repo = repository();
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        notificationRepository: repo,
      },
    });
    const bindings = testBindings() as ReturnType<typeof testBindings> & {
      PUSH_TOKEN_ENCRYPTION_KEY: string;
    };
    bindings.PUSH_TOKEN_ENCRYPTION_KEY = btoa(
      String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))),
    )
      .replaceAll("+", "-")
      .replaceAll("/", "_")
      .replaceAll("=", "");
    const headers = {
      ...(await authorization()),
      "content-type": "application/json",
    };
    const body =
      '{"platform":"ios","push_token":"provider-token-never-returned"}';
    expect(
      (
        await app.request(
          "/v1/me/devices",
          { method: "POST", headers, body },
          bindings,
        )
      ).status,
    ).toBe(422);
    const response = await app.request(
      "/v1/me/devices",
      {
        method: "POST",
        headers: { ...headers, "idempotency-key": "device-command-00000001" },
        body,
      },
      bindings,
    );
    expect(response.status).toBe(201);
    expect(await response.text()).not.toContain(
      "provider-token-never-returned",
    );
    expect(repo.registerDevice).toHaveBeenCalledWith(
      expect.any(Object),
      expect.objectContaining({ platform: "ios" }),
      bindings.PUSH_TOKEN_ENCRYPTION_KEY,
      "device-command-00000001",
    );
  });

  it("rejects device registration and revoke while external delivery is off", async () => {
    const repo = repository();
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        notificationRepository: repo,
      },
    });
    const bindings = {
      ...testBindings(),
      KILL_SWITCH_NOTIFICATION_WRITER: "off",
      KILL_SWITCH_NOTIFICATION_DELIVERY: "on",
    } as never;
    const response = await app.request(
      "/v1/me/devices",
      {
        method: "POST",
        headers: {
          ...(await authorization()),
          "content-type": "application/json",
          "idempotency-key": "device-command-00000001",
        },
        body:
          '{"platform":"ios","push_token":"provider-token-never-consumed"}',
      },
      bindings,
    );
    expect(response.status).toBe(503);
    expect(repo.registerDevice).not.toHaveBeenCalled();

    const revoke = await app.request(
      "/v1/me/devices/018f3c2a-4b67-7a89-8abc-123456789001",
      { method: "DELETE", headers: await authorization() },
      bindings,
    );
    expect(revoke.status).toBe(503);
    expect(repo.revokeDevice).not.toHaveBeenCalled();
  });

  it("signs bounded read-filter cursors and bounds read-all to a command receipt", async () => {
    const repo = repository();
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        notificationRepository: repo,
      },
    });
    const first = await app.request(
      "/v1/notifications?read=unread&limit=20",
      { headers: await authorization() },
      testBindings(),
    );
    const cursor = ((await first.json()) as { meta: { next_cursor: string } })
      .meta.next_cursor;
    expect(cursor).toEqual(expect.any(String));
    const second = await app.request(
      `/v1/notifications?read=unread&limit=20&cursor=${encodeURIComponent(cursor)}`,
      { headers: await authorization() },
      testBindings(),
    );
    expect(second.status).toBe(200);
    expect(repo.list).toHaveBeenLastCalledWith(expect.any(Object), {
      read: "unread",
      limit: 20,
      after: "018f3c2a-4b67-7a89-8abc-123456789002",
    });
    const readAll = await app.request(
      "/v1/notifications/read-all",
      {
        method: "POST",
        headers: {
          ...(await authorization()),
          "content-type": "application/json",
          "idempotency-key": "read-all-command-0001",
        },
        body: '{"before":"2026-08-24T10:00:00.000Z"}',
      },
      testBindings(),
    );
    expect(readAll.status).toBe(200);
    expect(repo.markAllRead).toHaveBeenCalledWith(
      expect.any(Object),
      "2026-08-24T10:00:00.000Z",
      "read-all-command-0001",
    );
  });

  it("maps only a typed missing content target to 404", async () => {
    const repo = repository();
    repo.report.mockRejectedValueOnce(new Error("database_unavailable"));
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        notificationRepository: repo,
      },
    });
    const request = async () =>
      app.request(
        "/v1/content-reports",
        {
          method: "POST",
          headers: {
            ...(await authorization()),
            "content-type": "application/json",
            "idempotency-key": "report-command-0000001",
          },
          body: JSON.stringify({
            target_kind: "ritual",
            target_id: "018f3c2a-4b67-7a89-8abc-123456789009",
            reason_code: "incorrect",
          }),
        },
        testBindings(),
      );
    const unavailableHeaders = {
      ...(await authorization()),
      "content-type": "application/json",
      "idempotency-key": "report-command-0000001",
    };
    const outage = await app.request(
      "/v1/content-reports",
      {
        method: "POST",
        headers: unavailableHeaders,
        body: JSON.stringify({
          target_kind: "ritual",
          target_id: "018f3c2a-4b67-7a89-8abc-123456789009",
          reason_code: "incorrect",
        }),
      },
      testBindings(),
    );
    expect(outage.status).toBe(500);
    repo.report.mockRejectedValueOnce(new NotificationContentNotFoundError());
    const missing = await request();
    expect(missing.status).toBe(404);
  });
});

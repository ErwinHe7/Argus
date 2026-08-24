import { beforeAll, describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import {
  ADMIN_CLIENT_ID,
  accessToken,
  memberToken,
  testBindings,
} from "../support/security-fixtures";

const mediaId = "018f3c2a-4b67-7a89-8abc-123456789010";
const outboxId = "018f3c2a-4b67-7a89-8abc-123456789011";
const checksum = "a".repeat(64);

describe("admin media contracts", () => {
  let auth0Key: Awaited<ReturnType<typeof createTestRsaKey>>;
  let accessKey: Awaited<ReturnType<typeof createTestRsaKey>>;
  beforeAll(async () => {
    auth0Key = await createTestRsaKey("u7-media-auth0");
    accessKey = await createTestRsaKey("u7-media-access");
  });

  const staff = {
    id: "018f3c2a-4b67-7a89-8abc-123456789012",
    auth0Subject: "auth0|media-staff",
    accessIdentity: "media@ritual-investing.test",
    allowedClientId: ADMIN_CLIENT_ID,
    displayLabel: "Media Editor",
    revocationEpoch: 0,
  };
  const headers = async (permission: "read" | "write") => ({
    authorization: `Bearer ${await memberToken(auth0Key, {
      sub: staff.auth0Subject,
      azp: ADMIN_CLIENT_ID,
      permissions: [`admin:media:${permission}`],
    })}`,
    "cf-access-jwt-assertion": await accessToken(accessKey, {
      email: staff.accessIdentity,
    }),
  });
  const record = {
    id: mediaId,
    mime_type: "image/png" as const,
    byte_size: 24,
    checksum,
    upload_status: "accepted" as const,
    quarantine_status: "clear" as const,
    scan_result: "clean" as const,
    derivative_status: "active" as const,
    reference_count: 0,
    version: 1,
  };
  const repository = () => ({
    createIntent: vi.fn().mockResolvedValue({
      id: mediaId,
      r2Key: `quarantine/v1/${staff.id}/${mediaId}`,
      expiresAt: new Date("2026-08-24T12:00:00.000Z"),
    }),
    getIntentForCompletion: vi.fn(),
    markUploaded: vi.fn(),
    queueScan: vi.fn().mockResolvedValue(outboxId),
    list: vi
      .fn()
      .mockResolvedValue({ items: [record], next: `${mediaId}|${mediaId}` }),
    get: vi.fn().mockResolvedValue(record),
    retire: vi.fn().mockResolvedValue(outboxId),
  });
  const appFor = (repo: ReturnType<typeof repository>) =>
    createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accessKeys: [accessKey.publicJwk],
        resolveStaff: async () => staff,
        mediaRepository: repo,
      },
    } as never);
  const bindings = () => {
    const value = testBindings() as ReturnType<typeof testBindings> & {
      MEDIA_QUARANTINE: R2Bucket;
    };
    value.MEDIA_QUARANTINE = {
      put: vi.fn(),
      get: vi.fn(),
      delete: vi.fn(),
    } as never;
    return value;
  };

  it("requires idempotency for upload intent creation and replays through the repository", async () => {
    const repo = repository();
    const app = appFor(repo);
    const body = JSON.stringify({
      mime_type: "image/png",
      byte_size: 24,
      checksum,
    });
    const base = {
      ...(await headers("write")),
      "content-type": "application/json",
    };
    expect(
      (
        await app.request(
          "https://admin-api.ritual-investing.test/v1/admin/media/upload-requests",
          { method: "POST", headers: base, body },
          bindings(),
        )
      ).status,
    ).toBe(422);
    const response = await app.request(
      "https://admin-api.ritual-investing.test/v1/admin/media/upload-requests",
      {
        method: "POST",
        headers: { ...base, "idempotency-key": "media-upload-request-0001" },
        body,
      },
      bindings(),
    );
    expect(response.status, await response.clone().text()).toBe(201);
    expect(repo.createIntent).toHaveBeenCalledWith(
      expect.objectContaining({ id: staff.id }),
      expect.objectContaining({ checksum }),
      "media-upload-request-0001",
      expect.any(String),
    );
  });

  it("uses bounded signed list filters and exposes lifecycle metadata only", async () => {
    const repo = repository();
    const app = appFor(repo);
    const first = await app.request(
      "https://admin-api.ritual-investing.test/v1/admin/media?status=accepted&mime_type=image%2Fpng&search=aaaa&limit=20",
      { headers: await headers("read") },
      bindings(),
    );
    expect(first.status).toBe(200);
    const payload = (await first.json()) as {
      data: unknown[];
      meta: { next_cursor: string };
    };
    expect(payload.data).toEqual([record]);
    expect(JSON.stringify(payload)).not.toMatch(
      /quarantine\/v1|scanner_body|upload_url/,
    );
    const second = await app.request(
      `https://admin-api.ritual-investing.test/v1/admin/media?status=accepted&mime_type=image%2Fpng&search=aaaa&limit=20&cursor=${encodeURIComponent(payload.meta.next_cursor)}`,
      { headers: await headers("read") },
      bindings(),
    );
    expect(second.status).toBe(200);
    expect(repo.list).toHaveBeenLastCalledWith(
      expect.any(Object),
      expect.objectContaining({
        status: "accepted",
        mimeType: "image/png",
        search: "aaaa",
        limit: 20,
        after: `${mediaId}|${mediaId}`,
      }),
    );
  });

  it("requires optimistic version and a sanitized reason before audited retirement", async () => {
    const repo = repository();
    const app = appFor(repo);
    const url = `https://admin-api.ritual-investing.test/v1/admin/media/${mediaId}`;
    const base = {
      ...(await headers("write")),
      "content-type": "application/json",
    };
    expect(
      (
        await app.request(
          url,
          {
            method: "DELETE",
            headers: base,
            body: JSON.stringify({ reason: "No longer approved" }),
          },
          bindings(),
        )
      ).status,
    ).toBe(422);
    const response = await app.request(
      url,
      {
        method: "DELETE",
        headers: { ...base, "if-match": '"v1"' },
        body: JSON.stringify({ reason: "No longer approved for use" }),
      },
      bindings(),
    );
    expect(response.status, await response.clone().text()).toBe(204);
    expect(repo.retire).toHaveBeenCalledWith(
      expect.objectContaining({ id: staff.id }),
      mediaId,
      1,
      "No longer approved for use",
      expect.any(String),
    );
  });
});

import { describe, expect, it, vi } from "vitest";

import { protectPushToken } from "../../src/domains/notifications/service";
import { handlerFor } from "../../src/jobs/handlers";
import type { OutboxEvent } from "../../src/jobs/consumer-receipts";
import type { QueueWorkMessage } from "../../src/jobs/queue-consumer";

const tenantId = "018f3c2a-4b67-7a89-8abc-123456789010";
const eventId = "018f3c2a-4b67-7a89-8abc-123456789011";
const notificationId = "018f3c2a-4b67-7a89-8abc-123456789012";
const installationId = "018f3c2a-4b67-7a89-8abc-123456789013";
const mediaId = "018f3c2a-4b67-7a89-8abc-123456789014";
const staffId = "018f3c2a-4b67-7a89-8abc-123456789015";

function message(consumer: QueueWorkMessage["consumer"]): QueueWorkMessage {
  return { schema_version: 1, outbox_id: eventId, consumer };
}

function event(overrides: Partial<OutboxEvent> = {}): OutboxEvent {
  return {
    id: eventId,
    topic: "notification.delivery.requested",
    aggregate_kind: "notification",
    aggregate_id: notificationId,
    aggregate_version: 1,
    tenant_id: tenantId,
    reset_generation: 0,
    deletion_generation: 0,
    payload: { notification_id: notificationId },
    ...overrides,
  };
}

function encodedKey(): string {
  return btoa(
    String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))),
  )
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

describe("managed asynchronous effects", () => {
  it("decrypts a push token only inside delivery and persists no token or provider body", async () => {
    const key = encodedKey();
    const rawToken = "provider-device-token-that-must-never-be-stored";
    const protectedToken = await protectPushToken(rawToken, key);
    const calls: Array<{ sql: string; values: unknown[] }> = [];
    const query = vi.fn(async (sql: string, values: unknown[] = []) => {
      calls.push({ sql, values });
      if (sql.includes("from notifications"))
        return {
          rows: [
            {
              id: notificationId,
              title: "A safe title",
              body: "A safe body",
              deep_link: "/briefings",
            },
          ],
          rowCount: 1,
        };
      if (sql.includes("from device_installations"))
        return {
          rows: [
            {
              id: installationId,
              push_token_ciphertext: protectedToken.tokenCiphertext,
            },
          ],
          rowCount: 1,
        };
      return { rows: [], rowCount: 1 };
    });
    const providerFetch = vi.fn(
      async (_input: RequestInfo, init?: RequestInit) => {
        expect(init?.headers).toMatchObject({
          "content-type": "application/json",
          "idempotency-key": expect.stringMatching(/^[a-f0-9]{64}$/),
        });
        expect(JSON.parse(String(init?.body))).toEqual({
          token: rawToken,
          title: "A safe title",
          body: "A safe body",
          deep_link: "/briefings",
        });
        return new Response("raw-provider-body-that-must-be-ignored", {
          status: 202,
        });
      },
    );

    const effect = handlerFor(message("notification-delivery"), {
      PUSH_PROVIDER: { fetch: providerFetch },
      PUSH_TOKEN_ENCRYPTION_KEY: key,
    } as never);
    await expect(effect({ query } as never, event())).resolves.toBe(
      "notification-delivered:1",
    );
    expect(providerFetch).toHaveBeenCalledOnce();
    const persisted = JSON.stringify(calls);
    expect(persisted).not.toContain(rawToken);
    expect(persisted).not.toContain("raw-provider-body-that-must-be-ignored");
    expect(persisted).toContain("accepted");
  });

  it("uses a stable provider idempotency key across partial-failure retries", async () => {
    const key = encodedKey();
    const protectedToken = await protectPushToken("retry-safe-token", key);
    const query = vi.fn(async (sql: string) => {
      if (sql.includes("from notifications"))
        return {
          rows: [
            {
              id: notificationId,
              title: "Title",
              body: "Body",
              deep_link: null,
            },
          ],
          rowCount: 1,
        };
      if (sql.includes("from device_installations"))
        return {
          rows: [
            {
              id: installationId,
              push_token_ciphertext: protectedToken.tokenCiphertext,
            },
          ],
          rowCount: 1,
        };
      return { rows: [], rowCount: 1 };
    });
    const keys: string[] = [];
    const provider = {
      fetch: vi.fn(async (_input: RequestInfo, init?: RequestInit) => {
        keys.push(new Headers(init?.headers).get("idempotency-key") ?? "");
        return new Response("do not persist me", { status: 503 });
      }),
    };
    const effect = handlerFor(message("notification-delivery"), {
      PUSH_PROVIDER: provider,
      PUSH_TOKEN_ENCRYPTION_KEY: key,
    } as never);

    await expect(effect({ query } as never, event())).rejects.toThrow(
      "notification_provider_unavailable",
    );
    await expect(effect({ query } as never, event())).rejects.toThrow(
      "notification_provider_unavailable",
    );
    expect(keys).toHaveLength(2);
    expect(keys[0]).toBe(keys[1]);
  });

  it("scans only actor-bound quarantine bytes and publishes a verified derivative", async () => {
    const png = new Uint8Array(24);
    png.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    new DataView(png.buffer).setUint32(16, 1);
    new DataView(png.buffer).setUint32(20, 1);
    const checksum = [
      ...new Uint8Array(await crypto.subtle.digest("SHA-256", png)),
    ]
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
    const calls: Array<{ sql: string; values: unknown[] }> = [];
    const query = vi.fn(async (sql: string, values: unknown[] = []) => {
      calls.push({ sql, values });
      if (sql.includes("from media_upload_intents"))
        return {
          rows: [
            {
              id: mediaId,
              actor_staff_id: staffId,
              r2_key: `quarantine/v1/${staffId}/${mediaId}`,
              expected_mime: "image/png",
              expected_checksum: checksum,
              status: "scanning",
            },
          ],
          rowCount: 1,
        };
      if (sql.includes("insert into outbox_events"))
        return { rows: [{ id: eventId }], rowCount: 1 };
      return { rows: [], rowCount: 1 };
    });
    const quarantineDelete = vi.fn(async () => undefined);
    const publicPut = vi.fn(async () => undefined);
    const effect = handlerFor(message("media-scan"), {
      MEDIA_QUARANTINE: {
        get: vi.fn(async () => ({
          customMetadata: {
            upload_intent_id: mediaId,
            actor_staff_id: staffId,
          },
          arrayBuffer: async () => png.buffer,
        })),
        delete: quarantineDelete,
      },
      MEDIA_PUBLIC: { put: publicPut, delete: vi.fn(async () => undefined) },
      MEDIA_SCANNER: {
        fetch: vi.fn(async () => Response.json({ result: "clean" })),
      },
      MEDIA_PROCESSOR: {
        fetch: vi.fn(async () => new Response(png, { status: 200 })),
      },
    } as never);

    const scanEvent = event({
      topic: "media.scan.requested",
      aggregate_kind: "media-upload-intent",
      aggregate_id: mediaId,
      tenant_id: null,
      payload: { media_id: mediaId, actor_staff_id: staffId },
    });
    await expect(effect({ query } as never, scanEvent)).resolves.toBe(
      `media-accepted:${mediaId}`,
    );
    // Simulate a failure after the effect returned: the DB rolls back to scanning,
    // the quarantine source survives, and the deterministic public key is reusable.
    await expect(effect({ query } as never, scanEvent)).resolves.toBe(
      `media-accepted:${mediaId}`,
    );
    expect(publicPut).toHaveBeenCalledWith(
      `media/v1/${mediaId}`,
      expect.any(Uint8Array),
      expect.objectContaining({ httpMetadata: { contentType: "image/png" } }),
    );
    expect(publicPut).toHaveBeenCalledTimes(2);
    expect(quarantineDelete).not.toHaveBeenCalled();
    expect(JSON.stringify(calls)).toContain("'clear','clean','active'");

    const cleanup = handlerFor(message("media-cleanup"), {
      MEDIA_QUARANTINE: {
        get: vi.fn(async () => ({
          customMetadata: {
            upload_intent_id: mediaId,
            actor_staff_id: staffId,
          },
        })),
        delete: quarantineDelete,
      },
    } as never);
    const cleanupQuery = vi.fn(async () => ({
      rows: [
        {
          id: mediaId,
          actor_staff_id: staffId,
          r2_key: `quarantine/v1/${staffId}/${mediaId}`,
          status: "accepted",
        },
      ],
      rowCount: 1,
    }));
    await expect(
      cleanup({ query: cleanupQuery } as never, {
        ...scanEvent,
        topic: "media.quarantine.cleanup",
      }),
    ).resolves.toBe(`media-cleanup:${mediaId}`);
    expect(quarantineDelete).toHaveBeenCalledWith(
      `quarantine/v1/${staffId}/${mediaId}`,
    );
  });

  it("rejects foreign quarantine metadata before scan or publication", async () => {
    const query = vi.fn(async (sql: string) => {
      if (sql.includes("from media_upload_intents"))
        return {
          rows: [
            {
              id: mediaId,
              actor_staff_id: staffId,
              r2_key: `quarantine/v1/${staffId}/${mediaId}`,
              expected_mime: "image/png",
              expected_checksum: "a".repeat(64),
              status: "scanning",
            },
          ],
          rowCount: 1,
        };
      return { rows: [], rowCount: 1 };
    });
    const scanner = { fetch: vi.fn() };
    const publicBucket = { put: vi.fn() };
    const effect = handlerFor(message("media-scan"), {
      MEDIA_QUARANTINE: {
        get: vi.fn(async () => ({
          customMetadata: {
            upload_intent_id: mediaId,
            actor_staff_id: tenantId,
          },
          arrayBuffer: async () => new ArrayBuffer(0),
        })),
      },
      MEDIA_PUBLIC: publicBucket,
      MEDIA_SCANNER: scanner,
      MEDIA_PROCESSOR: { fetch: vi.fn() },
    } as never);

    await expect(
      effect(
        { query } as never,
        event({
          topic: "media.scan.requested",
          aggregate_kind: "media-upload-intent",
          aggregate_id: mediaId,
          tenant_id: null,
          payload: { media_id: mediaId, actor_staff_id: staffId },
        }),
      ),
    ).rejects.toThrow("media_quarantine_mismatch");
    expect(scanner.fetch).not.toHaveBeenCalled();
    expect(publicBucket.put).not.toHaveBeenCalled();
  });
});

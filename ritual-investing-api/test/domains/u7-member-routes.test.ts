import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it, vi } from "vitest";

import {
  buildRetainedOpenApiDocument,
  createRetainedApp,
} from "../../src/retained-app.ts";

const repositoryRoot = resolve(import.meta.dirname, "../../..");

function contractApp() {
  return createRetainedApp({
    verifyAccessToken: vi.fn(),
    withRepositories: vi.fn(),
    withPublicPreview: vi.fn(),
    createPrivacyService: vi.fn(),
    rateLimit: {} as never,
  });
}

describe("U7 member routes after Supabase replacement", () => {
  it("retains Argus briefing, media, notification, and privacy routes without legacy paths", () => {
    const paths = buildRetainedOpenApiDocument(contractApp()).paths;
    for (
      const path of [
        "/v1/briefings",
        "/v1/media/upload-intents",
        "/v1/notifications",
        "/v1/privacy/requests",
      ]
    ) {
      expect(paths, path).toHaveProperty(path);
    }
    expect(paths).not.toHaveProperty("/v1/me/privacy/exports");
    expect(paths).not.toHaveProperty("/v1/me/privacy/deletion-requests");
    expect(JSON.stringify(paths)).not.toMatch(
      /ASYNC_QUEUE|JOBS_DLQ|PRIVACY_EXPORTS|MEDIA_QUARANTINE|Auth0/i,
    );
  });

  it("keeps deletion owner/epoch fenced and Supabase Auth-last", () => {
    const migration = readFileSync(
      resolve(
        repositoryRoot,
        "supabase/migrations/20260828132056_u10_supabase_jobs_storage.sql",
      ),
      "utf8",
    );
    expect(migration).toMatch(/prepare_member_purge\(p_tombstone_id uuid\)/i);
    expect(migration).toMatch(
      /delete from argus_private\.outbox_events[\s\S]*where outbox_events\.user_id = tombstone\.user_id/i,
    );
    expect(migration).toMatch(/storage_receipt_missing/i);
    expect(migration).toMatch(/auth_identity_still_present/i);
  });
});

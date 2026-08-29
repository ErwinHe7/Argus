import { describe, expect, it, vi } from "vitest";

import {
  RepositoryNotFoundError,
  RepositoryStepUpRequiredError,
} from "../../src/db/supabase-repositories.ts";
import { createRetainedApp } from "../../src/retained-app.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const requestId = "018f3c2a-4b67-7a89-8abc-123456789041";
const bindings = {
  environment: "test" as const,
  buildRevision: "u10-test",
  consumerOrigin: "https://app.ritual-investing.test",
  adminOrigin: "https://admin.ritual-investing.test",
};

function fixture(overrides: Record<string, unknown> = {}) {
  const privacy = {
    list: vi.fn(async () => []),
    request: vi.fn(async () => ({ id: requestId })),
    getDeletionTombstone: vi.fn(async () => null),
    createDownloadUrl: vi.fn(async () => ({
      url: "https://project.supabase.co/storage/v1/object/sign/opaque-token",
      expires_at: new Date(Date.now() + 300_000).toISOString(),
    })),
    ...overrides,
  };
  const app = createRetainedApp({
    verifyAccessToken: vi.fn(async () => ({
      userId,
      sessionId,
      aal: "aal1" as const,
      issuedAt: Math.floor(Date.now() / 1_000),
    })),
    withRepositories: async (_claims, _transaction, callback) =>
      await callback({} as never),
    withPublicPreview: async (callback) =>
      await callback({
        listPublishedPage: vi.fn(async () => []),
        listPublished: vi.fn(async () => []),
        getPublished: vi.fn(async () => null),
      }),
    createPrivacyService: () => privacy,
    rateLimit: { allow: vi.fn(async () => ({ allowed: true })) },
    requestId: () => "018f3c2a-4b67-7a89-8abc-123456789077",
  });
  return { app, privacy };
}

const authenticatedHeaders = {
  authorization: "Bearer verified-supabase-token",
  origin: bindings.consumerOrigin,
};

describe("Supabase privacy boundary", () => {
  it("requires an authenticated owner before minting a short-lived URL", async () => {
    const test = fixture();
    const anonymous = await test.app.request(
      `/v1/privacy/requests/${requestId}/download-url`,
      { method: "POST" },
      bindings,
    );
    expect(anonymous.status).toBe(401);
    expect(test.privacy.createDownloadUrl).not.toHaveBeenCalled();

    const owner = await test.app.request(
      `/v1/privacy/requests/${requestId}/download-url`,
      { method: "POST", headers: authenticatedHeaders },
      bindings,
    );
    expect(owner.status).toBe(200);
    const payload = await owner.json();
    expect(payload).toMatchObject({
      data: {
        url: expect.stringContaining("/storage/v1/object/sign/"),
        expires_at: expect.any(String),
      },
    });
    expect(JSON.stringify(payload)).not.toMatch(
      /privacy-exports|\.zip|sb_secret/i,
    );
  });

  it("maps an owner-filtered missing artifact to the same non-enumerating denial", async () => {
    const test = fixture({
      createDownloadUrl: vi.fn(async () => {
        throw new RepositoryNotFoundError();
      }),
    });
    const denied = await test.app.request(
      `/v1/privacy/requests/${requestId}/download-url`,
      { method: "POST", headers: authenticatedHeaders },
      bindings,
    );
    expect(denied.status).toBe(404);
    expect(JSON.stringify(await denied.json())).not.toContain(requestId);
  });

  it("requires and forwards an action-bound receipt only for deletion", async () => {
    const test = fixture();
    const missing = await test.app.request("/v1/privacy/requests", {
      method: "POST",
      headers: {
        ...authenticatedHeaders,
        "content-type": "application/json",
        "idempotency-key": "privacy-delete-idempotency",
      },
      body: JSON.stringify({ requestType: "deletion" }),
    }, bindings);
    expect(missing.status).toBe(422);

    const receipt = "R".repeat(43);
    const accepted = await test.app.request("/v1/privacy/requests", {
      method: "POST",
      headers: {
        ...authenticatedHeaders,
        "content-type": "application/json",
        "idempotency-key": "privacy-delete-idempotency",
      },
      body: JSON.stringify({
        requestType: "deletion",
        step_up_receipt: receipt,
      }),
    }, bindings);
    expect(accepted.status).toBe(200);
    expect(test.privacy.request).toHaveBeenCalledWith(
      "deletion",
      "privacy-delete-idempotency",
      receipt,
    );
  });

  it("returns a stable step-up denial without exposing receipt detail", async () => {
    const test = fixture({
      request: vi.fn(async () => {
        throw new RepositoryStepUpRequiredError();
      }),
    });
    const receipt = "R".repeat(43);
    const response = await test.app.request("/v1/privacy/requests", {
      method: "POST",
      headers: {
        ...authenticatedHeaders,
        "content-type": "application/json",
        "idempotency-key": "privacy-delete-idempotency",
      },
      body: JSON.stringify({
        requestType: "deletion",
        step_up_receipt: receipt,
      }),
    }, bindings);
    expect(response.status).toBe(403);
    const payload = await response.json();
    expect(payload).toMatchObject({
      error: { code: "step_up_required" },
    });
    expect(JSON.stringify(payload)).not.toContain(receipt);
  });
});

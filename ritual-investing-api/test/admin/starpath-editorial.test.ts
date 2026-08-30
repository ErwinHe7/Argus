import { describe, expect, it, vi } from "vitest";

import {
  createRetainedApp,
  type RetainedRepositorySet,
} from "../../src/retained-app.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789010";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const revisionId = "018f3c2a-4b67-7a89-8abc-123456789012";
const manifestId = "018f3c2a-4b67-7a89-8abc-123456789013";

function fixture() {
  const starpath = {
    getRevisionAuthority: vi.fn(async () => ({ revision_id: revisionId })),
    submitRevision: vi.fn(async () => ({ revision_id: revisionId, state: "submitted" })),
    decideReview: vi.fn(async () => ({ revision_id: revisionId, state: "submitted" })),
    publishManifest: vi.fn(async () => ({ manifest_id: manifestId, state: "published" })),
  };
  const admin = {
    createEditorial: vi.fn(async () => ({ kind: "starpath_lesson" })),
  };
  const repositories = { starpath, admin } as unknown as RetainedRepositorySet;
  const app = createRetainedApp({
    verifyAccessToken: vi.fn(async () => ({
      userId,
      sessionId,
      aal: "aal2" as const,
      issuedAt: 1,
    })),
    withRepositories: async (_claims, _transaction, callback) =>
      await callback(repositories),
    withPublicPreview: async (callback) =>
      await callback({} as never),
    createPrivacyService: () => ({} as never),
    rateLimit: { allow: vi.fn(async () => ({ allowed: true })) },
  });
  const bindings = {
    environment: "test" as const,
    buildRevision: "test",
    consumerOrigins: Object.freeze(["https://app.example.test"]),
    adminOrigin: "https://admin.example.test",
    webAdmission: "open" as const,
  };
  return { app, bindings, starpath, admin };
}

const headers = {
  authorization: "Bearer staff-token",
  origin: "https://admin.example.test",
  "content-type": "application/json",
};

describe("Starpath staff editorial routes", () => {
  it("admits Starpath as a typed generic editorial kind", async () => {
    const { app, bindings, admin } = fixture();
    const response = await app.request(
      "/v1/admin/editorial",
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          kind: "starpath_lesson",
          slug: "markets-have-orders",
          payload: {
            stable_key: "markets-have-orders",
            pathway_ordinal: 1,
            pathway_position: 1,
          },
        }),
      },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(admin.createEditorial).toHaveBeenCalledWith(
      "starpath_lesson",
      "markets-have-orders",
      expect.any(Object),
      expect.any(String),
    );
  });

  it("submits the exact policy-bound revision for two reviews", async () => {
    const { app, bindings, starpath } = fixture();
    const response = await app.request(
      `/v1/admin/starpath/revisions/${revisionId}/submit`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({ policy_version: "starpath-no-advice-v1" }),
      },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(starpath.submitRevision).toHaveBeenCalledWith(
      revisionId,
      "starpath-no-advice-v1",
    );
  });

  it("records only a factual or compliance attestation", async () => {
    const { app, bindings, starpath } = fixture();
    const response = await app.request(
      `/v1/admin/starpath/revisions/${revisionId}/reviews`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          discipline: "factual",
          decision: "approved",
          reason: "All factual claims match the dated sources.",
        }),
      },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(starpath.decideReview).toHaveBeenCalledWith(
      revisionId,
      "factual",
      "approved",
      "All factual claims match the dated sources.",
    );
  });

  it("rejects the generic discipline at the Starpath boundary", async () => {
    const { app, bindings, starpath } = fixture();
    const response = await app.request(
      `/v1/admin/starpath/revisions/${revisionId}/reviews`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          discipline: "general",
          decision: "approved",
          reason: "This must not enter the Starpath dual-review workflow.",
        }),
      },
      bindings,
    );

    expect(response.status).toBe(422);
    expect(starpath.decideReview).not.toHaveBeenCalled();
  });

  it("publishes only through the atomic manifest command", async () => {
    const { app, bindings, starpath } = fixture();
    const response = await app.request(
      `/v1/admin/starpath/manifests/${manifestId}/publish`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          reason: "Release the reviewed eight-node factual curriculum.",
        }),
      },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(starpath.publishManifest).toHaveBeenCalledWith(
      manifestId,
      "Release the reviewed eight-node factual curriculum.",
    );
  });
});

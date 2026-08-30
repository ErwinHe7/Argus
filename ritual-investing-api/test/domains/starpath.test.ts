import { describe, expect, it, vi } from "vitest";

import type { StarpathRepository } from "../../src/domains/starpath/ports.ts";
import {
  starpathAnswerCommandSchema,
  starpathSnapshotSchema,
  starpathStartCommandSchema,
} from "../../src/domains/starpath/schemas.ts";
import {
  createRetainedApp,
  type RetainedRepositorySet,
} from "../../src/retained-app.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const manifestId = "018f3c2a-4b67-7a89-8abc-123456789020";
const themeId = "018f3c2a-4b67-7a89-8abc-123456789021";
const lessonId = "018f3c2a-4b67-7a89-8abc-123456789022";
const revisionId = "018f3c2a-4b67-7a89-8abc-123456789023";
const questionId = "018f3c2a-4b67-7a89-8abc-123456789024";
const optionId = "018f3c2a-4b67-7a89-8abc-123456789025";
const requestId = "018f3c2a-4b67-7a89-8abc-123456789077";
const origin = "https://beta.ritual-investing.test";
const bindings = {
  environment: "test" as const,
  buildRevision: "starpath-u3-test",
  consumerOrigins: Object.freeze([origin]),
  adminOrigin: "https://admin.ritual-investing.test",
  webAdmission: "open" as const,
};

const snapshot = starpathSnapshotSchema.parse({
  availability: "available",
  version: 1,
  authority: {
    capability_version: 7,
    manifest_id: manifestId,
    manifest_version: "starpath-beta-v1",
    policy_version: "starpath-no-advice-v1",
    environment: "beta",
    jurisdiction: "US",
  },
  session: {
    id: sessionId,
    state: "active",
    started_at: "2026-08-30T10:00:00.000Z",
    last_action_at: "2026-08-30T10:01:00.000Z",
    explicit_start: true,
    replacement_of_session_id: null,
  },
  theme: {
    id: themeId,
    key: "steady-orbit",
    title: "Steady orbit",
    horoscope_frame: "Today, notice how definitions create a map.",
    factual_focus: "Learn what a share represents.",
    accessible_label: "A non-predictive celestial learning theme.",
  },
  progress: {
    current_node_ordinal: 1,
    version: 1,
    updated_at: "2026-08-30T10:01:00.000Z",
  },
  nodes: Array.from({ length: 8 }, (_, index) => ({
    node_ordinal: index + 1,
    pathway_ordinal: Math.floor(index / 2) + 1,
    pathway_position: (index % 2) + 1,
    state: index === 0 ? "current" : "locked",
    lesson_id: lessonId,
    revision_id: revisionId,
    title: "A share and its market",
    guide: {
      tarot_key: "the-fool",
      accessible_label: "The Fool as a memory aid, not market evidence.",
    },
    mythic_mnemonic: "The first step remembers that a share is an ownership unit.",
    factual_summary: "A share can represent a proportional ownership interest.",
    factual_sections: [{
      ordinal: 1,
      kind: "fact",
      heading: "Ownership units",
      body: "Common stock generally represents an ownership interest in an issuer.",
      uncertainty: "Rights vary by security, issuer, and governing documents.",
      observed_at: "2026-08-29T00:00:00.000Z",
      evidence: [{
        ordinal: 1,
        canonical_url: "https://www.investor.gov/introduction-investing/investing-basics/investment-products/stocks",
        source_title: "Stocks",
        publisher: "Investor.gov",
        source_observed_at: "2026-08-29T00:00:00.000Z",
        effective_at: null,
        retrieved_at: "2026-08-29T00:00:00.000Z",
        current_until: "2027-08-29T00:00:00.000Z",
        claim_summary: "A stock is a type of security that gives holders an ownership interest.",
      }],
    }],
    material_limitations: "Share classes and contractual rights differ.",
    risk_context: "A stock's market value may fall, including to zero.",
    recall_prompt: "What does a share generally represent?",
    rowan_explanation: "Rowan restates the reviewed definition and its limits.",
    knowledge_check: {
      id: questionId,
      prompt: "What does common stock generally represent?",
      options: [
        { id: optionId, ordinal: 1, label: "An ownership interest" },
        {
          id: "018f3c2a-4b67-7a89-8abc-123456789026",
          ordinal: 2,
          label: "A guaranteed return",
        },
      ],
    },
  })),
  recall: null,
  command_effect: "started",
  answer: null,
});

function fixture(repository: Partial<StarpathRepository>) {
  const app = createRetainedApp({
    verifyAccessToken: vi.fn(async () => ({
      userId,
      sessionId,
      aal: "aal1" as const,
      issuedAt: 1,
    })),
    withRepositories: async (_claims, _transaction, callback) =>
      await callback({
        starpathMember: repository,
      } as unknown as RetainedRepositorySet),
    withPublicPreview: async (callback) =>
      await callback({
        listPublishedPage: vi.fn(async () => []),
        listPublished: vi.fn(async () => []),
        getPublished: vi.fn(async () => null),
      }),
    createPrivacyService: () => ({} as never),
    rateLimit: { allow: vi.fn(async () => ({ allowed: true })) },
    requestId: () => requestId,
  });
  return app;
}

const authHeaders = {
  authorization: "Bearer valid-token",
  origin,
};

describe("Starpath member API", () => {
  it("reads one authoritative factual-only snapshot with an ETag", async () => {
    const read = vi.fn(async () => snapshot);
    const response = await fixture({ read }).request(
      "/v1/starpath",
      { headers: authHeaders },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("etag")).toBe('"v1"');
    expect(read).toHaveBeenCalledOnce();
    const body = await response.json() as {
      data: {
        nodes: Array<{
          guide: { tarot_key: string };
          factual_sections: Array<{
            evidence: Array<{ publisher: string }>;
          }>;
        }>;
      };
    };
    expect(body.data.nodes[0]!.guide.tarot_key).toBe("the-fool");
    expect(body.data.nodes[0]!.factual_sections[0]!.evidence[0]!.publisher)
      .toBe("Investor.gov");
    expect(JSON.stringify(body)).not.toMatch(
      /is_correct|holdings|balances|orders|investment_(?:intent|preference)/,
    );
  });

  it("starts or resumes through an idempotent empty command", async () => {
    const startOrResume = vi.fn(async () => snapshot);
    const response = await fixture({ startOrResume }).request(
      "/v1/starpath/sessions",
      {
        method: "POST",
        headers: {
          ...authHeaders,
          "content-type": "application/json",
          "idempotency-key": "starpath-start-0001",
        },
        body: "{}",
      },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(startOrResume).toHaveBeenCalledWith("starpath-start-0001");
  });

  it("passes only exact answer identity and the canonical progress version", async () => {
    const answer = vi.fn(async () => ({
      ...snapshot,
      version: 2,
      progress: { ...snapshot.progress!, version: 2 },
      command_effect: "lesson_completed" as const,
      answer: {
        is_correct: true,
        explanation: "A share generally represents an ownership interest.",
      },
    }));
    const response = await fixture({ answer }).request(
      "/v1/starpath/answers",
      {
        method: "POST",
        headers: {
          ...authHeaders,
          "content-type": "application/json",
          "idempotency-key": "starpath-answer-0001",
          "if-match": '"v1"',
        },
        body: JSON.stringify({
          session_id: sessionId,
          manifest_id: manifestId,
          revision_id: revisionId,
          question_id: questionId,
          option_id: optionId,
          attempt_kind: "node",
        }),
      },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("etag")).toBe('"v2"');
    expect(answer).toHaveBeenCalledWith(
      {
        session_id: sessionId,
        manifest_id: manifestId,
        revision_id: revisionId,
        question_id: questionId,
        option_id: optionId,
        attempt_kind: "node",
      },
      1,
      "starpath-answer-0001",
    );
  });

  it.each([
    ["member_id", userId],
    ["is_correct", true],
    ["score", 1],
    ["completion", true],
    ["unlock", 2],
    ["timestamp", "2026-08-30T10:00:00.000Z"],
    ["investment_intent", "growth"],
    ["investment_preference", "stocks"],
  ])("rejects forged %s before repository execution", async (field, value) => {
    const answer = vi.fn();
    const response = await fixture({ answer }).request(
      "/v1/starpath/answers",
      {
        method: "POST",
        headers: {
          ...authHeaders,
          "content-type": "application/json",
          "idempotency-key": "starpath-answer-0002",
          "if-match": '"v1"',
        },
        body: JSON.stringify({
          session_id: sessionId,
          manifest_id: manifestId,
          revision_id: revisionId,
          question_id: questionId,
          option_id: optionId,
          attempt_kind: "node",
          [field]: value,
        }),
      },
      bindings,
    );

    expect(response.status).toBe(422);
    expect(answer).not.toHaveBeenCalled();
  });

  it("rejects forged start context and keeps optional answer fields absent", () => {
    expect(starpathStartCommandSchema.safeParse({ member_id: userId }).success)
      .toBe(false);
    const parsed = starpathAnswerCommandSchema.parse({
      session_id: sessionId,
      manifest_id: manifestId,
      revision_id: revisionId,
      question_id: questionId,
      option_id: optionId,
    });
    expect(parsed).not.toHaveProperty("attempt_kind");
  });

  it("requires authentication, idempotency, and If-Match at the boundary", async () => {
    const repository = { read: vi.fn(), startOrResume: vi.fn(), answer: vi.fn() };
    const app = fixture(repository);
    const unauthenticated = await app.request("/v1/starpath", {}, bindings);
    const missingKey = await app.request(
      "/v1/starpath/sessions",
      {
        method: "POST",
        headers: { ...authHeaders, "content-type": "application/json" },
        body: "{}",
      },
      bindings,
    );
    const missingVersion = await app.request(
      "/v1/starpath/answers",
      {
        method: "POST",
        headers: {
          ...authHeaders,
          "content-type": "application/json",
          "idempotency-key": "starpath-answer-0003",
        },
        body: JSON.stringify({
          session_id: sessionId,
          manifest_id: manifestId,
          revision_id: revisionId,
          question_id: questionId,
          option_id: optionId,
        }),
      },
      bindings,
    );

    expect(unauthenticated.status).toBe(401);
    expect(missingKey.status).toBe(422);
    expect(missingVersion.status).toBe(422);
    expect(repository.startOrResume).not.toHaveBeenCalled();
    expect(repository.answer).not.toHaveBeenCalled();
  });
});

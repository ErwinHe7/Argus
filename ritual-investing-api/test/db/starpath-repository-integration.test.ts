import { describe, expect, it, vi } from "vitest";

import type { DatabaseTransaction } from "../../src/db/database-port.ts";
import {
  createSupabaseStarpathRepository,
} from "../../src/domains/starpath/repository.ts";
import {
  StarpathError,
  type StarpathCapabilityDecision,
  type StarpathCapabilityEvaluator,
} from "../../src/domains/starpath/ports.ts";

const manifestId = "018f3c2a-4b67-7a89-8abc-123456789020";
const themeId = "018f3c2a-4b67-7a89-8abc-123456789021";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789022";
const lessonId = "018f3c2a-4b67-7a89-8abc-123456789023";
const revisionId = "018f3c2a-4b67-7a89-8abc-123456789024";
const questionId = "018f3c2a-4b67-7a89-8abc-123456789025";
const optionId = "018f3c2a-4b67-7a89-8abc-123456789026";
const now = "2026-08-30T12:00:00.000Z";

function capability(
  environment: "beta" | "production" = "beta",
  overrides: Partial<StarpathCapabilityDecision> = {},
): StarpathCapabilityDecision {
  return {
    branch: "starpath",
    available: true,
    environment,
    jurisdiction: "US",
    capabilityVersion: 7,
    evaluatedAt: "2026-08-30T11:59:00.000Z",
    expiresAt: "2026-08-30T12:05:00.000Z",
    protectedRoutes: [
      "starpath.read",
      "starpath.start",
      "starpath.answer",
      "starpath.recall.skip",
    ],
    ...overrides,
  };
}

function projection(environment: "beta" | "production") {
  return {
    manifest: {
      id: manifestId,
      manifestVersion: `starpath-${environment}-v1`,
      policyVersion: "starpath-no-advice-v1",
      environment,
      jurisdiction: "US",
    },
    theme: {
      id: themeId,
      key: "steady-orbit",
      title: "Steady orbit",
      horoscopeFrame: "Notice definitions without predicting an outcome.",
      factualFocus: "Learn a factual market term.",
      accessibleLabel: "A non-predictive celestial learning theme.",
    },
    nodes: Array.from({ length: 8 }, (_, index) => ({
      nodeOrdinal: index + 1,
      pathwayOrdinal: Math.floor(index / 2) + 1,
      pathwayPosition: (index % 2) + 1,
      lessonId: index === 0
        ? lessonId
        : `018f3c2a-4b67-7a89-8abc-${String(123456789023 + index)}`,
      revisionId: index === 0
        ? revisionId
        : `018f3c2a-4b67-7a89-8abc-${String(123456789040 + index)}`,
      title: `Reviewed lesson ${index + 1}`,
      tarotKey: "the-fool",
      tarotAccessibleLabel: "The Fool as a mnemonic, not market evidence.",
      mythicMnemonic: "A memory image kept apart from the factual lesson.",
      factualSummary: "A neutral reviewed financial definition.",
      factualSections: [{
        ordinal: 1,
        kind: "fact",
        heading: "Reviewed fact",
        body: "A factual statement with no recommendation.",
        uncertainty: "Definitions and issuer-specific rights can vary.",
        observedAt: "2026-08-29T00:00:00.000Z",
        evidence: [{
          ordinal: 1,
          canonicalUrl: "https://www.investor.gov/example",
          sourceTitle: "Investor education",
          publisher: "Investor.gov",
          sourceObservedAt: "2026-08-29T00:00:00.000Z",
          effectiveAt: null,
          retrievedAt: "2026-08-29T00:00:00.000Z",
          currentUntil: "2027-08-29T00:00:00.000Z",
          claimSummary: "Official support for the factual statement.",
        }],
      }],
      materialLimitations: "The teaching example is deliberately limited.",
      riskContext: "Investment values can fall and loss is possible.",
      recallPrompt: "Recall the factual definition.",
      rowanExplanation: "Rowan restates reviewed facts and uncertainty only.",
      knowledgeCheck: {
        id: questionId,
        prompt: "Which statement matches the reviewed fact?",
        options: [
          { id: optionId, ordinal: 1, label: "The factual statement" },
          {
            id: "018f3c2a-4b67-7a89-8abc-123456789027",
            ordinal: 2,
            label: "A promised outcome",
          },
        ],
      },
    })),
  };
}

function state(effect?: string) {
  return {
    availability: "available",
    session: {
      id: sessionId,
      manifestId,
      themeId,
      state: "active",
      startedAt: now,
      lastActionAt: now,
      explicitStart: true,
      replacementOfSessionId: null,
      capabilityVersion: 7,
    },
    progress: {
      currentNodeOrdinal: 1,
      version: 1,
      updatedAt: now,
    },
    currentNode: {
      nodeOrdinal: 1,
      lessonId,
      revisionId,
    },
    recall: null,
    completedLessonIds: [],
    ...(effect === undefined ? {} : { commandEffect: effect }),
  };
}

function harness(
  decision: StarpathCapabilityDecision,
  commandState: Record<string, unknown> = state(),
) {
  const queries: Array<{ text: string; values: readonly unknown[] }> = [];
  const database: DatabaseTransaction = {
    query: vi.fn(async (text: string, values: readonly unknown[] = []) => {
      queries.push({ text, values });
      if (text.includes("clock_timestamp")) return { rows: [{ now }] };
      if (text.includes("resolve_starpath_member_authority")) {
        return {
          rows: [{
            authority: {
              manifestId,
              manifestVersion: `starpath-${decision.environment}-v1`,
              policyVersion: "starpath-no-advice-v1",
              environment: decision.environment,
              jurisdiction: "US",
              themeId,
            },
          }],
        };
      }
      if (text.includes("read_starpath_curriculum_projection")) {
        return { rows: [{ projection: projection(decision.environment) }] };
      }
      if (text.includes("read_starpath_state")) {
        return { rows: [{ state: commandState }] };
      }
      if (text.includes("start_or_resume_starpath_session")) {
        return { rows: [{ state: commandState }] };
      }
      if (text.includes("answer_starpath_question")) {
        return { rows: [{ state: commandState }] };
      }
      throw new Error(`unexpected query: ${text}`);
    }) as DatabaseTransaction["query"],
  };
  const evaluator: StarpathCapabilityEvaluator = {
    evaluate: vi.fn(async () => decision),
  };
  return {
    repository: createSupabaseStarpathRepository(database, evaluator),
    evaluator,
    queries,
  };
}

describe("Starpath Supabase repository authority", () => {
  it.each(["beta", "production"] as const)(
    "forwards the trusted %s capability scope and returns only reviewed fields",
    async (environment) => {
      const test = harness(capability(environment));
      const snapshot = await test.repository.read();

      expect(snapshot.nodes).toHaveLength(8);
      expect(snapshot.authority).toMatchObject({ environment });
      expect(snapshot.nodes[0]?.knowledge_check.options[0]).not.toHaveProperty(
        "is_correct",
      );
      expect(JSON.stringify(snapshot)).not.toMatch(
        /holdings|balances|orders|astrology_profile|investor_profile/,
      );
      const authorityCall = test.queries.find(({ text }) =>
        text.includes("resolve_starpath_member_authority")
      );
      expect(authorityCall?.values).toEqual([environment, "US"]);
      expect(test.queries.map(({ text }) => text).join("\n")).not.toMatch(
        /argus_app\.(?:profiles|astrology_profiles|investor_profiles)|argus_brokerage/,
      );
    },
  );

  it.each([
    capability("beta", { available: false }),
    capability("beta", { expiresAt: "2026-08-30T11:59:59.000Z" }),
    capability("beta", { protectedRoutes: [] }),
  ])("fails closed for unavailable, expired, or unknown route data", async (decision) => {
    const test = harness(decision);
    await expect(test.repository.read()).rejects.toEqual(
      new StarpathError("starpath_unavailable"),
    );
    expect(test.queries.some(({ text }) =>
      text.includes("resolve_starpath_member_authority")
    )).toBe(false);
  });

  it("pins the evaluator version and reviewed authority into start", async () => {
    const test = harness(capability(), state("started"));
    const snapshot = await test.repository.startOrResume(
      "starpath-start-0001",
    );

    expect(snapshot.command_effect).toBe("started");
    const start = test.queries.find(({ text }) =>
      text.includes("start_or_resume_starpath_session")
    );
    expect(start?.values).toEqual([
      "starpath-start-0001",
      expect.stringMatching(/^[a-f0-9]{64}$/),
      manifestId,
      themeId,
      7,
    ]);
  });

  it("submits exact identity and returns fresh server-scored feedback", async () => {
    const answered = {
      ...state("lesson_completed"),
      progress: { ...state().progress, currentNodeOrdinal: 2, version: 2 },
      answer: {
        isCorrect: true,
        explanation: "The selected statement matches the reviewed fact.",
      },
      completedLessonIds: [lessonId],
    };
    const test = harness(capability(), answered);
    const snapshot = await test.repository.answer(
      {
        session_id: sessionId,
        manifest_id: manifestId,
        revision_id: revisionId,
        question_id: questionId,
        option_id: optionId,
      },
      1,
      "starpath-answer-0001",
    );

    expect(snapshot.version).toBe(2);
    expect(snapshot.answer).toEqual({
      is_correct: true,
      explanation: "The selected statement matches the reviewed fact.",
    });
    expect(snapshot.nodes[0]?.state).toBe("completed");
    expect(snapshot.nodes[1]?.state).toBe("current");
    const answer = test.queries.find(({ text }) =>
      text.includes("answer_starpath_question")
    );
    expect(answer?.values?.slice(2)).toEqual([
      sessionId,
      manifestId,
      revisionId,
      questionId,
      optionId,
      1,
      "node",
    ]);
  });
});

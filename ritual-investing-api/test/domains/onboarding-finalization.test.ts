import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import {
  memberToken,
  sessionSnapshot,
  testBindings,
} from "../support/security-fixtures";

const reviewedQuestionnaire = {
  schema_version: 2,
  expected_onboarding_version: 1,
  investing: {
    experience: "new",
    goal_type: "long_term_growth",
    time_horizon: "long",
    risk_comfort: "moderate",
    contribution_rhythm: "monthly",
  },
  ritual: {
    familiarity: "new",
    language_preference: "practical",
    interests: ["practical_research"],
  },
  astrology: { enabled: false },
  consents: {
    terms: { policy_version: "2026-08", decision: "accepted" },
    privacy: { policy_version: "2026-08", decision: "accepted" },
    demo_disclosure: {
      policy_version: "2026-08",
      decision: "accepted",
    },
    astrology: { policy_version: "2026-08", decision: "declined" },
  },
} as const;

describe("POST /v1/session/onboarding/finalize", () => {
  const auth0Key = createTestRsaKey("onboarding-finalization-key");

  function fixture() {
    const finalizeOnboarding = vi.fn(async () => ({
      ...sessionSnapshot,
      reset_generation: 1,
      onboarding: {
        current_step: "complete",
        completed_steps: ["welcome", "ritual", "profile"],
        completed_at: "2026-08-24T04:00:00.000Z",
        schema_version: 2,
        cohort: "member_v2",
        version: 2,
      },
    }));
    return {
      finalizeOnboarding,
      app: createApp({
        dependencies: {
          auth0Keys: [auth0Key.publicJwk],
          sessionRepository: {
            bootstrap: vi.fn(async () => sessionSnapshot),
            finalizeOnboarding,
          },
        },
      } as never),
    };
  }

  async function finalize(
    body: unknown = reviewedQuestionnaire,
    key = "onboarding-finalize-0001",
  ) {
    const test = fixture();
    const response = await test.app.request(
      "/v1/session/onboarding/finalize",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(auth0Key)}`,
          "content-type": "application/json",
          "idempotency-key": key,
        },
        body: JSON.stringify(body),
      },
      testBindings(),
    );
    return { ...test, response };
  }

  it("passes the authenticated subject, reviewed answers, and command key atomically", async () => {
    const { response, finalizeOnboarding } = await finalize();

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      data: {
        reset_generation: 1,
        onboarding: { current_step: "complete", schema_version: 2 },
      },
    });
    expect(finalizeOnboarding).toHaveBeenCalledWith(
      "auth0|member-1",
      reviewedQuestionnaire,
      "onboarding-finalize-0001",
    );
  });

  it.each([
    [
      "stale schema",
      { ...reviewedQuestionnaire, schema_version: 1 },
    ],
    [
      "stale policy",
      {
        ...reviewedQuestionnaire,
        consents: {
          ...reviewedQuestionnaire.consents,
          privacy: { policy_version: "2025-01", decision: "accepted" },
        },
      },
    ],
    [
      "birth date while opted out",
      {
        ...reviewedQuestionnaire,
        astrology: { enabled: false, birth_date: "1990-02-03" },
      },
    ],
    [
      "client-derived astrology",
      {
        ...reviewedQuestionnaire,
        astrology: {
          enabled: true,
          birth_date: "1990-02-03",
          derived_profile_code: "lunar_patient",
        },
        consents: {
          ...reviewedQuestionnaire.consents,
          astrology: { policy_version: "2026-08", decision: "accepted" },
        },
      },
    ],
  ])("rejects %s before persistence", async (_label, body) => {
    const { response, finalizeOnboarding } = await finalize(body);

    expect(response.status).toBe(422);
    expect(finalizeOnboarding).not.toHaveBeenCalled();
  });
});

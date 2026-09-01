import { describe, expect, it } from "vitest";

import { birthdayOnboardingFinalizeBodySchema } from "../src/domains/session/schemas.ts";

const validBody = {
  schema_version: 3,
  expected_onboarding_version: 1,
  astrology: { birth_date: "1994-05-14" },
  consents: {
    terms: { policy_version: "2026-08", decision: "accepted" },
    privacy: { policy_version: "2026-08", decision: "accepted" },
    demo_disclosure: { policy_version: "2026-08", decision: "accepted" },
    astrology: { policy_version: "2026-08", decision: "accepted" },
  },
} as const;

describe("birthday-only onboarding contract", () => {
  it("accepts only the minimal birthday and explicit acknowledgements", () => {
    expect(birthdayOnboardingFinalizeBodySchema.parse(validBody)).toEqual(
      validBody,
    );
  });

  it.each(["1899-12-31", "2999-01-01", "1994-02-31"])(
    "rejects invalid or out-of-range birth date %s",
    (birthDate) => {
      expect(() =>
        birthdayOnboardingFinalizeBodySchema.parse({
          ...validBody,
          astrology: { birth_date: birthDate },
        })
      ).toThrow();
    },
  );

  it("rejects questionnaire answers and non-accepted policy decisions", () => {
    expect(() =>
      birthdayOnboardingFinalizeBodySchema.parse({
        ...validBody,
        investing: { risk_comfort: "moderate" },
      })
    ).toThrow();
    expect(() =>
      birthdayOnboardingFinalizeBodySchema.parse({
        ...validBody,
        consents: {
          ...validBody.consents,
          astrology: {
            policy_version: "2026-08",
            decision: "declined",
          },
        },
      })
    ).toThrow();
  });
});

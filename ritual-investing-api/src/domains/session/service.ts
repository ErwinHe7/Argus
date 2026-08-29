import { z } from "@hono/zod-openapi";

import type { SessionRepository } from "./ports.ts";
import { onboardingFinalizeBodySchema } from "./schemas.ts";

export type SessionServiceRepository = SessionRepository;
type FinalizeOnboardingBody = z.infer<typeof onboardingFinalizeBodySchema>;

export function createSessionService(repository: SessionServiceRepository) {
  return Object.freeze({
    bootstrap: () => repository.bootstrap(),
    finalizeOnboarding: (
      input: FinalizeOnboardingBody,
      idempotencyKey: string,
    ) =>
      repository.finalizeOnboarding(
        {
          expectedOnboardingVersion: input.expected_onboarding_version,
          investing: {
            goalType: input.investing.goal_type,
            timeHorizon: input.investing.time_horizon,
            riskComfort: input.investing.risk_comfort,
          },
          astrology: {
            enabled: input.astrology.enabled,
            ...(input.astrology.birth_date === undefined
              ? {}
              : { birthDate: input.astrology.birth_date }),
          },
          consents: Object.fromEntries(
            Object.entries(input.consents).map(([policyCode, consent]) => [
              policyCode,
              {
                policyVersion: consent.policy_version,
                decision: consent.decision,
              },
            ]),
          ),
        },
        idempotencyKey,
      ),
  });
}

export type SessionService = ReturnType<typeof createSessionService>;

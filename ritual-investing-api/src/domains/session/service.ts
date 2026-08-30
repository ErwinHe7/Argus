import { z } from "@hono/zod-openapi";

import type {
  MemberBranchCapabilityEvaluator,
  SessionRepository,
  SessionRepositorySnapshot,
} from "./ports.ts";
import {
  memberBranchCapabilitiesSchema,
  onboardingFinalizeBodySchema,
} from "./schemas.ts";

export type SessionServiceRepository = SessionRepository;
type FinalizeOnboardingBody = z.infer<typeof onboardingFinalizeBodySchema>;

async function withBranchCapabilities(
  snapshot: SessionRepositorySnapshot,
  evaluator: MemberBranchCapabilityEvaluator,
) {
  const branchCapabilities = memberBranchCapabilitiesSchema.parse(
    await evaluator.evaluate(snapshot.server_time),
  );
  return Object.freeze({
    ...snapshot,
    branch_capabilities: Object.freeze(branchCapabilities),
  });
}

export function createSessionService(
  repository: SessionServiceRepository,
  evaluator: MemberBranchCapabilityEvaluator,
) {
  return Object.freeze({
    bootstrap: async () =>
      await withBranchCapabilities(await repository.bootstrap(), evaluator),
    finalizeOnboarding: async (
      input: FinalizeOnboardingBody,
      idempotencyKey: string,
    ) =>
      withBranchCapabilities(
        await repository.finalizeOnboarding(
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
        evaluator,
      ),
  });
}

export type SessionService = ReturnType<typeof createSessionService>;

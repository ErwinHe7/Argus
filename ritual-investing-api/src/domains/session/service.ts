import { z } from "@hono/zod-openapi";

import type { RetainedRuntimeBindings } from "../retained-http/types.ts";
import type {
  SessionRepository,
  SessionRepositorySnapshot,
} from "./ports.ts";
import { onboardingFinalizeBodySchema } from "./schemas.ts";

export type SessionServiceRepository = SessionRepository;
type FinalizeOnboardingBody = z.infer<typeof onboardingFinalizeBodySchema>;
type RuntimeEnvironment = RetainedRuntimeBindings["environment"];

const branchCapabilityTtlMs = 5 * 60 * 1_000;
const betaBranches = Object.freeze([
  "ritual",
  "starpath",
  "discover",
  "coven",
  "you",
] as const);
const productionBranches = Object.freeze([
  "ritual",
  "starpath",
  "you",
] as const);

function withBranchCapabilities(
  snapshot: SessionRepositorySnapshot,
  runtimeEnvironment: RuntimeEnvironment,
) {
  const evaluatedAt = new Date(snapshot.server_time);
  if (Number.isNaN(evaluatedAt.getTime())) {
    throw new Error("invalid_session_server_time");
  }
  const environment = runtimeEnvironment === "production"
    ? "production"
    : "beta";
  return Object.freeze({
    ...snapshot,
    branch_capabilities: Object.freeze({
      schema_version: "member-branch-capabilities-v1",
      capability_version: 1,
      environment,
      evaluated_at: evaluatedAt.toISOString(),
      expires_at: new Date(
        evaluatedAt.getTime() + branchCapabilityTtlMs,
      ).toISOString(),
      branches: environment === "production"
        ? productionBranches
        : betaBranches,
    }),
  });
}

export function createSessionService(
  repository: SessionServiceRepository,
  runtimeEnvironment: RuntimeEnvironment,
) {
  return Object.freeze({
    bootstrap: async () =>
      withBranchCapabilities(await repository.bootstrap(), runtimeEnvironment),
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
        runtimeEnvironment,
      ),
  });
}

export type SessionService = ReturnType<typeof createSessionService>;

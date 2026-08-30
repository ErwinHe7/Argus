import type { RetainedRuntimeBindings } from "../../../ritual-investing-api/src/domains/retained-http/types.ts";
import type { MemberBranchCapabilityEvaluator } from "../../../ritual-investing-api/src/domains/session/ports.ts";
import type { MemberBranchCapabilities } from "../../../ritual-investing-api/src/domains/session/schemas.ts";
import type {
  StarpathCapabilityDecision,
  StarpathCapabilityEvaluator,
} from "../../../ritual-investing-api/src/domains/starpath/ports.ts";

type RuntimeEnvironment = RetainedRuntimeBindings["environment"];

const capabilityTtlMs = 5 * 60 * 1_000;

function isAvailableStarpathDecision(
  decision: StarpathCapabilityDecision,
  environment: "beta" | "production",
  serverTimeMs: number,
): boolean {
  const evaluatedAt = Date.parse(decision.evaluatedAt);
  const expiresAt = Date.parse(decision.expiresAt);
  return decision.branch === "starpath" &&
    decision.available &&
    decision.environment === environment &&
    decision.protectedRoutes.includes("starpath.read") &&
    Number.isSafeInteger(decision.capabilityVersion) &&
    decision.capabilityVersion > 0 &&
    Number.isFinite(evaluatedAt) &&
    Number.isFinite(expiresAt) &&
    evaluatedAt <= serverTimeMs &&
    expiresAt > serverTimeMs &&
    expiresAt > evaluatedAt;
}

export function createMemberBranchCapabilityEvaluator(
  input: Readonly<{
    runtimeEnvironment: RuntimeEnvironment;
    starpath: StarpathCapabilityEvaluator;
  }>,
): MemberBranchCapabilityEvaluator {
  return Object.freeze({
    evaluate: async (serverTime: string) => {
      const evaluatedAt = new Date(serverTime);
      const serverTimeMs = evaluatedAt.getTime();
      if (!Number.isFinite(serverTimeMs)) {
        throw new Error("invalid_session_server_time");
      }
      const environment: "beta" | "production" =
        input.runtimeEnvironment === "production" ? "production" : "beta";
      let starpath: StarpathCapabilityDecision | null = null;
      try {
        const decision = await input.starpath.evaluate("starpath.read");
        if (isAvailableStarpathDecision(decision, environment, serverTimeMs)) {
          starpath = decision;
        }
      } catch {
        // A failed release-control decision hides Starpath without suppressing
        // the independently available member branches.
      }
      const baseBranches = environment === "production"
        ? ["ritual", "you"] as const
        : ["ritual", "discover", "coven", "you"] as const;
      const branches: MemberBranchCapabilities["branches"] = [
        ...baseBranches,
      ];
      if (starpath !== null) branches.splice(1, 0, "starpath");
      const baseExpiresAt = serverTimeMs + capabilityTtlMs;
      const expiresAt = starpath === null
        ? baseExpiresAt
        : Math.min(baseExpiresAt, Date.parse(starpath.expiresAt));
      return {
        schema_version: "member-branch-capabilities-v1" as const,
        capability_version: starpath?.capabilityVersion ?? 1,
        environment,
        evaluated_at: evaluatedAt.toISOString(),
        expires_at: new Date(expiresAt).toISOString(),
        branches,
      };
    },
  });
}

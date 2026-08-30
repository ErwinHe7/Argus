import { describe, expect, it, vi } from "vitest";

import { createMemberBranchCapabilityEvaluator } from "../../../supabase/functions/api/member-branch-capabilities.ts";

const serverTime = "2026-08-30T12:00:00.000Z";

describe("Supabase member branch capability composition", () => {
  it("keeps Starpath hidden when its protected API evaluator is blocked", async () => {
    const evaluateStarpath = vi.fn(async () => {
      throw new Error("starpath_unavailable");
    });
    const evaluator = createMemberBranchCapabilityEvaluator({
      runtimeEnvironment: "staging",
      starpath: { evaluate: evaluateStarpath },
    });

    await expect(evaluator.evaluate(serverTime)).resolves.toEqual({
      schema_version: "member-branch-capabilities-v1",
      capability_version: 1,
      environment: "beta",
      evaluated_at: serverTime,
      expires_at: "2026-08-30T12:05:00.000Z",
      branches: ["ritual", "discover", "coven", "you"],
    });
    expect(evaluateStarpath).toHaveBeenCalledWith("starpath.read");
  });

  it(
    "adds Starpath only for a current matching protected-route decision",
    async () => {
      const evaluator = createMemberBranchCapabilityEvaluator({
        runtimeEnvironment: "staging",
        starpath: {
          evaluate: vi.fn(async () => ({
            branch: "starpath" as const,
            available: true,
            environment: "beta" as const,
            jurisdiction: "US",
            capabilityVersion: 9,
            evaluatedAt: "2026-08-30T11:59:00.000Z",
            expiresAt: "2026-08-30T12:02:00.000Z",
            protectedRoutes: [
              "starpath.read" as const,
              "starpath.start" as const,
            ],
          })),
        },
      });

      await expect(evaluator.evaluate(serverTime)).resolves.toEqual({
        schema_version: "member-branch-capabilities-v1",
        capability_version: 9,
        environment: "beta",
        evaluated_at: serverTime,
        expires_at: "2026-08-30T12:02:00.000Z",
        branches: ["ritual", "starpath", "discover", "coven", "you"],
      });
    },
  );
});

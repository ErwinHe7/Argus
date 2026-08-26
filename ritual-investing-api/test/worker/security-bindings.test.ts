import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

describe("security bindings", () => {
  it("exposes every route-class rate-limit binding in workerd", () => {
    for (const name of [
      "RL_HEALTH",
      "RL_PUBLIC",
      "RL_SEARCH",
      "RL_MEMBER_READ",
      "RL_MEMBER_WRITE",
      "RL_COMMAND",
      "RL_SENSITIVE",
      "RL_ADMIN_READ",
      "RL_ADMIN_WRITE",
      "RL_ADMIN_HIGH",
      "RL_UPLOAD",
    ] as const) {
      expect(
        (env as unknown as Record<string, unknown>)[name],
        `missing ${name}`,
      ).toHaveProperty("limit");
    }
  });
});

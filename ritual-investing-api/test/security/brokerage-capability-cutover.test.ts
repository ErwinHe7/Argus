import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

const brokerageRepositories = [
  "brokerage-connections",
  "brokerage-accounts",
  "brokerage-assets",
  "brokerage-projections",
  "brokerage-orders",
].map((domain) =>
  readFileSync(resolve(
    import.meta.dirname,
    `../../src/domains/${domain}/repository.ts`,
  ), "utf8")
).join("\n");

describe("brokerage capability-role cutover", () => {
  it("uses only the trusted request identity in U5 repositories", () => {
    expect(brokerageRepositories).toContain(
      "argus_private.trusted_request_user_id()",
    );
    expect(brokerageRepositories).not.toMatch(
      /argus_private\.(?!trusted_)request_user_id\(\)/,
    );
  });

  it("does not route brokerage requests through the legacy runtime role", () => {
    expect(brokerageRepositories).toContain("withMemberRequestTransaction");
    expect(brokerageRepositories).toContain("withCallbackRequestTransaction");
    expect(brokerageRepositories).toContain(
      "withCapabilityStaffRequestTransaction",
    );
    expect(brokerageRepositories).not.toContain("withRequestTransaction");
    expect(brokerageRepositories).not.toContain("withStaffRequestTransaction");
  });
});

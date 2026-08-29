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

const brokerageComposition = [
  resolve(import.meta.dirname, "../../../supabase/functions/api/index.ts"),
  resolve(
    import.meta.dirname,
    "../../../supabase/functions/webull-callback/index.ts",
  ),
].map((path) => readFileSync(path, "utf8")).join("\n");

describe("brokerage capability-role cutover", () => {
  it("uses only the trusted request identity in U5 repositories", () => {
    expect(brokerageRepositories).toContain(
      "argus_private.trusted_request_user_id()",
    );
    expect(brokerageRepositories).not.toMatch(
      /argus_private\.(?!trusted_)request_user_id\(\)/,
    );
  });

  it("keeps capability selection in composition roots, outside adapters", () => {
    expect(brokerageRepositories).toContain("DatabaseTransaction");
    expect(brokerageRepositories).not.toMatch(/DatabasePool|pool\.connect/);
    expect(brokerageRepositories).not.toMatch(/with\w+RequestTransaction/);
    expect(brokerageComposition).toContain("withMemberRequestTransaction");
    expect(brokerageComposition).toContain("withCallbackRequestTransaction");
    expect(brokerageComposition).toContain(
      "withCapabilityStaffRequestTransaction",
    );
  });
});

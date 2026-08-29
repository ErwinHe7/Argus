import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it, vi } from "vitest";

import { runWebullReconciliation } from "../../src/jobs/webull-reconciliation.ts";

const adapter = readFileSync(resolve(
  import.meta.dirname,
  "../../../supabase/functions/_shared/jobs/webull-recovery.ts",
), "utf8");

describe("Webull command reconciliation", () => {
  it("has a lookup-only port and no financial execute capability", async () => {
    const inspectExistingCommand = vi.fn(async () => "not_found" as const);
    const port = { inspectExistingCommand };
    expect(Object.keys(port)).toEqual(["inspectExistingCommand"]);
    const event = {
      id: "018f3c2a-4b67-7a89-8abc-123456789021",
      eventType: "webull.command.reconciliation.requested" as const,
      handlerName: "webull-reconciliation" as const,
      aggregateId: "018f3c2a-4b67-7a89-8abc-123456789022",
      userId: "018f3c2a-4b67-7a89-8abc-123456789023",
      deletionEpoch: 1,
    };
    await expect(runWebullReconciliation(event, port, vi.fn()))
      .resolves.toContain(":not_found");
    expect(adapter).toContain("lookupExistingCommand");
    expect(adapter).not.toMatch(/provider\.(execute|place|modify|cancel)\s*\(/);
  });
});

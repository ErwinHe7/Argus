import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it, vi } from "vitest";

import { runWebullReconciliation } from "../../src/jobs/webull-reconciliation.ts";

const migration = readFileSync(resolve(
  import.meta.dirname,
  "../../../supabase/migrations/20260828152000_u15_webull_recovery.sql",
), "utf8");
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

  it("does not return reviewed order payloads from the worker claim", () => {
    const start = migration.indexOf("claim_webull_command_reconciliation");
    const end = migration.indexOf("record_webull_reconciliation_retry", start);
    const claim = migration.slice(start, end);
    expect(claim).not.toContain("normalized_payload jsonb");
    expect(claim).not.toContain("reviewed_payload");
    expect(claim).not.toContain("provider_preview_ref");
    expect(claim).toContain("client_order_id text");
  });

  it("keeps not-found ambiguous and terminalizes every worker DLQ", () => {
    expect(migration).toContain("p_reason='provider_order_not_found'");
    expect(migration).toContain("reconciliation.attempts>=4");
    expect(migration).toContain("terminalize_webull_recovery_dead_letter");
    expect(migration).toContain("set state='manual_review'");
    expect(migration).not.toMatch(/insert into argus_private\.provider_commands[\s\S]{0,300}webull\.command\.reconciliation/);
  });
});

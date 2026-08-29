import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it, vi } from "vitest";

import { runWebullTokenRefresh } from "../../src/jobs/webull-token-refresh.ts";

const adapter = readFileSync(resolve(
  import.meta.dirname,
  "../../../supabase/functions/_shared/jobs/webull-recovery.ts",
), "utf8");

const event = {
  id: "018f3c2a-4b67-7a89-8abc-123456789001",
  eventType: "webull.token.refresh.requested" as const,
  handlerName: "webull-token-refresh" as const,
  aggregateId: "018f3c2a-4b67-7a89-8abc-123456789002",
  userId: "018f3c2a-4b67-7a89-8abc-123456789003",
  deletionEpoch: 2,
};

describe("Webull token recovery", () => {
  it("can rotate only an existing connection reference", async () => {
    const refreshExistingConnection = vi.fn(async () => "rotated" as const);
    await expect(runWebullTokenRefresh(event, { refreshExistingConnection }, vi.fn()))
      .resolves.toContain(":rotated");
    expect(refreshExistingConnection).toHaveBeenCalledWith(expect.objectContaining({
      eventId: event.id,
      connectionId: event.aggregateId,
    }));
  });

  it("persists possible egress before refresh and commits only afterward", () => {
    const egress = adapter.indexOf("mark_webull_refresh_egress_started");
    const provider = adapter.indexOf("config.provider.refresh", egress);
    const commit = adapter.indexOf("commit_webull_token_refresh", provider);
    expect(egress).toBeGreaterThan(0);
    expect(provider).toBeGreaterThan(egress);
    expect(commit).toBeGreaterThan(provider);
  });

  it("clears an egress marker only for an explicit before-egress result", () => {
    const reset = adapter.indexOf("reset_webull_refresh_before_egress");
    expect(reset).toBeGreaterThan(adapter.indexOf("WebullRecoveryBeforeEgressError"));
  });
});

import { readFile, readdir } from "node:fs/promises";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

import {
  brokeragePrivacyExportCollections,
  privacyExportCollections,
} from "../../src/jobs/privacy-export.ts";

const expectedBrokerageCollections = [
  ["brokerage_connections", "argus_brokerage.connections"],
  ["brokerage_accounts", "argus_brokerage.accounts"],
  ["brokerage_active_account_selections", "argus_brokerage.active_account_selections"],
  ["brokerage_account_capabilities", "argus_brokerage.account_capabilities"],
  ["brokerage_projection_generations", "argus_brokerage.projection_generations"],
  ["brokerage_projection_balance_facts", "argus_brokerage.projection_balance_facts"],
  ["brokerage_projection_position_facts", "argus_brokerage.projection_position_facts"],
  ["brokerage_projection_restriction_facts", "argus_brokerage.projection_restriction_facts"],
  ["brokerage_projection_account_facts", "argus_brokerage.projection_account_facts"],
  ["brokerage_order_projection_generations", "argus_brokerage.order_projection_generations"],
] as const;

describe("Supabase privacy export inventory", () => {
  it("exports application rows and the exact normalized member brokerage projections", () => {
    const inventory = privacyExportCollections.map(({ sourceRelation }) => sourceRelation)
      .join("\n");
    expect(inventory).toContain("argus_app.members");
    expect(inventory).toContain("argus_app.privacy_requests");
    expect(brokeragePrivacyExportCollections.map(({ name, sourceRelation }) => [
      name,
      sourceRelation,
    ])).toEqual(expectedBrokerageCollections);
    expect(inventory).toContain("argus_brokerage.projection_position_facts");
    expect(inventory).toContain("argus_brokerage.order_projection_generations");
    expect(inventory).not.toMatch(
      /argus_private|credential|oauth|token|mapping|snapshot|refresh_lease|provider_command_attempt|reconciliation|raw_response|authorization/i,
    );
  });

  it("references only relations declared by the full forward migration history", async () => {
    const migrationRoot = resolve("../supabase/migrations");
    const migrations = await Promise.all(
      (await readdir(migrationRoot))
        .filter((name) => name.endsWith(".sql"))
        .sort()
        .map(async (name) => ({
          name,
          source: await readFile(resolve(migrationRoot, name), "utf8"),
        })),
    );
    for (const { name, sourceRelation } of privacyExportCollections) {
      const tableHistory = migrations
        .filter(({ source }) => source.includes(sourceRelation))
        .map(({ source }) => source)
        .join("\n");
      expect(tableHistory, `${name}:${sourceRelation}`).not.toBe("");
    }
  });

  it("composes one unique ordered worker inventory without internal brokerage tables", () => {
    expect(new Set(privacyExportCollections.map(({ name }) => name)).size).toBe(
      privacyExportCollections.length,
    );
    expect(privacyExportCollections.slice(-expectedBrokerageCollections.length).map(
      ({ name, sourceRelation }) => [name, sourceRelation],
    )).toEqual(expectedBrokerageCollections);
    expect(privacyExportCollections.map(({ sourceRelation }) => sourceRelation).join("\n"))
      .not.toMatch(/argus_app\.saved_items|argus_private|credentials|snapshots|provider_commands/i);
  });

  it("keeps workers on named sealed collections rather than executable source SQL", () => {
    for (const { name, sourceRelation } of privacyExportCollections) {
      expect(name).toMatch(/^[a-z][a-z0-9_]*$/);
      expect(sourceRelation).toMatch(/^argus_(?:app|brokerage)\.[a-z_]+$/);
      expect(sourceRelation).not.toMatch(/\s|;|--|\/\*|\*\/|["']/);
    }
  });
});

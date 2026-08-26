import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

describe("database invariants", () => {
  it("fences idempotency and simulation work by reset generation", async () => {
    const foundation = await readFile(`${apiRoot}/drizzle/0001_ritual_foundation.sql`, "utf8");
    const guards = await readFile(`${apiRoot}/drizzle/0002_roles_and_rls.sql`, "utf8");

    expect(foundation).toMatch(/unique\s*\(tenant_id,\s*reset_generation,\s*operation,\s*idempotency_key\)/i);
    expect(foundation).toMatch(/simulation_commands[\s\S]*reset_generation/i);
    expect(foundation).toMatch(/recurring_plan_runs[\s\S]*unique\s*\(tenant_id,\s*plan_id,\s*reset_generation,\s*scheduled_for\)/i);
    expect(guards).toMatch(/enforce_idempotency_transition/i);
    expect(guards).toMatch(/enforce_current_reset_generation/i);
    expect(guards).toMatch(/validate_simulation_command_ledger/i);
    expect(guards).toMatch(/validate_order_fill_invariant/i);
  });

  it("uses composite tenant foreign keys for tenant-owned children", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0001_ritual_foundation.sql`, "utf8");
    const drizzle = await Promise.all([
      readFile(`${apiRoot}/src/db/schema/simulation.ts`, "utf8"),
      readFile(`${apiRoot}/src/db/schema/member.ts`, "utf8"),
    ]).then((sources) => sources.join("\n"));

    expect(sql).toMatch(/circle_assets[\s\S]*foreign key\s*\(tenant_id,\s*circle_id\)[\s\S]*references circles\s*\(tenant_id,\s*id\)/i);
    expect(sql).toMatch(/cash_ledger_entries[\s\S]*foreign key\s*\(tenant_id,\s*transaction_id\)[\s\S]*references ledger_transactions\s*\(tenant_id,\s*id\)/i);
    expect(sql).toMatch(/privacy_export_artifacts[\s\S]*foreign key\s*\(tenant_id,\s*request_id\)[\s\S]*references privacy_requests\s*\(tenant_id,\s*id\)/i);
    for (const constraint of [
      "simulation_commands_tenant_portfolio_fk",
      "simulated_orders_tenant_command_fk",
      "portfolio_positions_tenant_transaction_fk",
      "projection_runs_tenant_intention_fk",
      "notification_deliveries_tenant_installation_fk",
    ]) {
      expect(drizzle, `Drizzle schema is missing ${constraint}`).toContain(constraint);
    }
  });

  it("allows tenant purge to remove report-linked moderation state", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0001_ritual_foundation.sql`, "utf8");

    expect(sql).toMatch(
      /moderation_cases[\s\S]*report_id\s+uuid\s+not\s+null\s+unique\s+references\s+content_reports\(id\)\s+on\s+delete\s+cascade/i,
    );
  });

  it("guards immutable history and monotonic projections", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0002_roles_and_rls.sql`, "utf8");

    expect(sql).toMatch(/create\s+(?:or\s+replace\s+)?function\s+ritual_private\.reject_immutable_change/i);
    expect(sql).toMatch(/editorial_revisions[\s\S]*reject_immutable_change/i);
    expect(sql).toMatch(/ledger_transactions[\s\S]*reject_immutable_change/i);
    expect(sql).toMatch(/admin_audit_events[\s\S]*reject_immutable_change/i);
    expect(sql).toMatch(/reject_portfolio_watermark_regression/i);
    expect(sql).toMatch(/enforce_briefing_generation_monotonic/i);
  });

  it("bounds deletion tombstones and purge receipts by generation", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0001_ritual_foundation.sql`, "utf8");

    expect(sql).toMatch(/deletion_tombstones[\s\S]*unique\s*\(tenant_id,\s*purge_generation\)/i);
    expect(sql).toMatch(/purge_receipts[\s\S]*unique\s*\(tombstone_id,\s*purge_generation\)/i);
  });
});

import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

const canonicalTables = [
  "tenants",
  "accounts",
  "profiles",
  "preferences",
  "astrology_profiles",
  "investor_profiles",
  "onboarding_states",
  "consent_records",
  "device_installations",
  "notification_preferences",
  "staff_principals",
  "media_assets",
  "editorial_items",
  "editorial_revisions",
  "editorial_review_requests",
  "editorial_review_decisions",
  "publication_events",
  "assets",
  "asset_metric_snapshots",
  "evidence_sources",
  "evidence_claims",
  "ritual_scenarios",
  "ritual_scenario_revisions",
  "ritual_scenario_ideas",
  "ritual_scenario_evidence",
  "ritual_schedules",
  "daily_ritual_assignments",
  "rowan_scripts",
  "rowan_script_revisions",
  "rowan_context_bindings",
  "asset_codex_entries",
  "asset_codex_revisions",
  "asset_codex_risks",
  "asset_codex_evidence",
  "companies",
  "coven_entries",
  "coven_entry_revisions",
  "coven_qualifications",
  "coven_verifications",
  "coven_verification_evidence",
  "grimoires",
  "grimoire_revisions",
  "grimoire_revision_assets",
  "seeded_creators",
  "circle_templates",
  "circle_template_revisions",
  "circle_template_assets",
  "circles",
  "circle_assets",
  "saved_assets",
  "saved_grimoires",
  "saved_circle_templates",
  "saved_coven_entries",
  "demo_seed_versions",
  "tenant_demo_states",
  "demo_portfolios",
  "portfolio_target_allocations",
  "idempotency_records",
  "simulation_commands",
  "demo_funding_sources",
  "simulated_orders",
  "simulated_order_fills",
  "ledger_transactions",
  "cash_ledger_entries",
  "position_ledger_entries",
  "portfolio_positions",
  "portfolio_balance_snapshots",
  "recurring_plans",
  "recurring_plan_allocations",
  "recurring_plan_runs",
  "rebalance_previews",
  "rebalance_preview_trades",
  "intentions",
  "projection_runs",
  "projection_points",
  "briefings",
  "briefing_sections",
  "demo_plans",
  "tenant_entitlements",
  "entitlement_events",
  "demo_checkout_sessions",
  "notifications",
  "notification_deliveries",
  "privacy_requests",
  "privacy_export_artifacts",
  "content_reports",
  "moderation_cases",
  "admin_audit_events",
  "security_events",
  "outbox_events",
  "job_runs",
  "consumer_receipts",
  "deletion_tombstones",
  "purge_receipts",
] as const;

describe("Ritual foundation migration", () => {
  it("creates every table in the canonical catalog", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0001_ritual_foundation.sql`, "utf8");

    expect(canonicalTables).toHaveLength(94);
    for (const table of canonicalTables) {
      expect(sql, `missing canonical table ${table}`).toMatch(
        new RegExp(`create\\s+table(?:\\s+if\\s+not\\s+exists)?\\s+${table}\\b`, "i"),
      );
    }
  });

  it("uses additive, transaction-safe migration structure", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0001_ritual_foundation.sql`, "utf8");

    expect(sql).toMatch(/^begin;/i);
    expect(sql).toMatch(/commit;\s*$/i);
    expect(sql).not.toMatch(/\bdrop\s+(?:table|column|type)\b/i);
    expect(sql).not.toMatch(/\btruncate\b/i);
  });
});

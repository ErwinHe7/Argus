import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

describe("migration compatibility", () => {
  it("keeps role/RLS rollout additive and independently transactional", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0002_roles_and_rls.sql`, "utf8");

    expect(sql).toMatch(/^begin;/i);
    expect(sql).toMatch(/commit;\s*$/i);
    expect(sql).not.toMatch(/\bdrop\s+(?:table|column|type|role)\b/i);
    expect(sql).not.toMatch(/\btruncate\b/i);
  });

  it("keeps identity bootstrap additive and independently transactional", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0003_identity_bootstrap.sql`, "utf8");

    expect(sql).toMatch(/^begin;/i);
    expect(sql).toMatch(/commit;\s*$/i);
    expect(sql).not.toMatch(/\bdrop\s+(?:table|column|type|role)\b/i);
    expect(sql).not.toMatch(/\btruncate\b/i);
    expect(sql).toMatch(/create\s+role\s+ritual_bootstrap\s+noinherit\s+nologin\s+nobypassrls/i);
    expect(sql).toMatch(/create\s+role\s+ritual_staff_resolver\s+noinherit\s+nologin\s+nobypassrls/i);
    expect(sql).toMatch(/function\s+ritual_private\.bootstrap_member_account\s*\(verified_subject\s+text\)[\s\S]*security\s+definer[\s\S]*set\s+search_path\s*=\s*pg_catalog,\s*public,\s*ritual_private/i);
  });

  it("keeps the editorial catalog additive and grants only versioned public projections", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0004_editorial_catalog.sql`, "utf8");

    expect(sql).toMatch(/^begin;/i);
    expect(sql).toMatch(/commit;\s*$/i);
    expect(sql).not.toMatch(/\bdrop\s+(?:table|column|type|role)\b/i);
    expect(sql).not.toMatch(/\btruncate\b/i);
    expect(sql).toMatch(/add\s+column\s+if\s+not\s+exists\s+version/i);
    expect(sql).toMatch(/revoke\s+select\s+on\s+ritual_public\.daily_ritual_preview,[\s\S]*ritual_public\.asset_codex_preview,[\s\S]*ritual_public\.coven_preview[\s\S]*from\s+ritual_public/i);
    expect(sql).toMatch(/grant\s+select\s+on\s+ritual_public\.daily_ritual_preview_v1,[\s\S]*ritual_public\.discover_v1,[\s\S]*ritual_public\.coven_v1[\s\S]*to\s+ritual_public/i);
    expect(sql).toMatch(/rowan_revisions_v1[\s\S]*revision\.state\s+in\s*\('published',\s*'withdrawn'\)/i);
    expect(sql).toMatch(/ritual_revisions_v1[\s\S]*revision\.state\s+in\s*\('published',\s*'withdrawn'\)/i);
    expect(sql).toMatch(/fixture:non-login:editor[\s\S]*'disabled'/i);
    expect(sql).toMatch(/create\s+materialized\s+view\s+ritual_catalog\.search_v1/i);
    expect(sql).toMatch(/using\s+gin\s*\(search_document\)/i);
  });

  it("records an expand-compatible schema contract version", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0001_ritual_foundation.sql`, "utf8");

    expect(sql).toMatch(/create\s+table(?:\s+if\s+not\s+exists)?\s+ritual_private\.schema_contract_versions/i);
    expect(sql).toMatch(/insert\s+into\s+ritual_private\.schema_contract_versions/i);
    expect(sql).toMatch(/'n-1'/i);
    expect(sql).toMatch(/'n'/i);
  });

  it("keeps async runtime hardening additive, bounded, and retry-safe", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0010_async_runtime_hardening.sql`, "utf8");

    expect(sql).toMatch(/^begin;/i);
    expect(sql).toMatch(/commit;\s*$/i);
    expect(sql).not.toMatch(/\bdrop\s+(?:table|column|type|role)\b/i);
    expect(sql).not.toMatch(/\btruncate\b/i);
    expect(sql).toMatch(/enqueue_due_recurring_plans[\s\S]*for update of plan skip locked/i);
    expect(sql).toMatch(/enqueue_expired_privacy_exports[\s\S]*for update of artifact skip locked/i);
    expect(sql).toMatch(/finish_job_attempt[\s\S]*status='failed'/i);
    expect(sql).toMatch(/apply_due_recurring_plan_event[\s\S]*recurring_plan_runs/i);
  });
});

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

  it("records an expand-compatible schema contract version", async () => {
    const sql = await readFile(`${apiRoot}/drizzle/0001_ritual_foundation.sql`, "utf8");

    expect(sql).toMatch(/create\s+table(?:\s+if\s+not\s+exists)?\s+ritual_private\.schema_contract_versions/i);
    expect(sql).toMatch(/insert\s+into\s+ritual_private\.schema_contract_versions/i);
    expect(sql).toMatch(/'n-1'/i);
    expect(sql).toMatch(/'n'/i);
  });
});

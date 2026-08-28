import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { privacyExportCollections } from "../../src/jobs/handlers.ts";

describe("Supabase privacy export inventory", () => {
  it("exports Argus-owned product rows without provider secrets or raw payloads", async () => {
    const inventory = privacyExportCollections.map(([, sql]) => sql).join("\n");
    expect(inventory).toContain("argus_app.members");
    expect(inventory).toContain("argus_app.privacy_requests");
    expect(inventory).not.toMatch(
      /argus_brokerage|provider|oauth|token|credential|raw_response|authorization/i,
    );
  });

  it("selects only columns declared by the Supabase baseline", async () => {
    const migration = await readFile(
      resolve("../supabase/migrations/20260828054740_argus_private_baseline.sql"),
      "utf8",
    );
    for (const [name, sql] of privacyExportCollections) {
      const table = sql.match(/from argus_app\.(\w+)/i)?.[1];
      expect(table, name).toBeDefined();
      const definition = migration.match(
        new RegExp(`create table argus_app\\.${table} \\(([\\s\\S]*?)\\n\\);`, "i"),
      )?.[1];
      expect(definition, `${name}:${table}`).toBeDefined();
      const columns = sql.match(/^select ([\s\S]*?) from /i)?.[1]
        ?.split(",")
        .map((entry) => entry.trim().match(/^([a-z_]+)/i)?.[1])
        .filter((column): column is string => column !== undefined) ?? [];
      for (const column of columns) {
        expect(definition, `${name}:${table}.${column}`).toMatch(
          new RegExp(`(?:^|\\n)\\s*${column}\\s`, "i"),
        );
      }
    }
  });

  it("grants the worker owner policy to every exported owner table", async () => {
    const u10 = await readFile(
      resolve("../supabase/migrations/20260828132056_u10_supabase_jobs_storage.sql"),
      "utf8",
    );
    const policyLoop = u10.match(
      /foreach table_name in array array\[([\s\S]*?)\]\s*loop/,
    )?.[1];
    expect(policyLoop).toBeDefined();
    for (const [, sql] of privacyExportCollections) {
      const table = sql.match(/from argus_app\.(\w+)/i)?.[1];
      expect(policyLoop, `worker owner policy for ${table}`).toContain(`'${table}'`);
    }
  });
});

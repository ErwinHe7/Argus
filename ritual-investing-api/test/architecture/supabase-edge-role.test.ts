import { readFile, readdir } from "node:fs/promises";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../../..");

describe("Supabase Edge database login boundary", () => {
  it("keeps credentials on a narrow login and privileges on argus_runtime", async () => {
    const migrationName = (await readdir(resolve(repositoryRoot, "supabase/migrations")))
      .find((name) => name.endsWith("_u3_edge_login_role.sql"));
    expect(migrationName).toBeDefined();
    const migration = await readFile(
      resolve(repositoryRoot, "supabase/migrations", migrationName!),
      "utf8",
    );
    const adapter = await readFile(
      resolve(repositoryRoot, "supabase/functions/_shared/database.ts"),
      "utf8",
    );
    const transaction = await readFile(
      resolve(repositoryRoot, "ritual-investing-api/src/db/database-port.ts"),
      "utf8",
    );

    expect(migration).toMatch(
      /create role argus_edge\s+login noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls/i,
    );
    expect(migration).toMatch(/alter role argus_edge password null/i);
    expect(migration).not.toMatch(/password\s+['"][^'"]+['"]/i);
    expect(migration).toMatch(/grant argus_runtime to argus_edge/i);
    expect(migration).not.toMatch(
      /grant\s+[^;]+\son\s+[^;]+\sto\s+argus_edge/i,
    );
    expect(adapter).toMatch(/argus_edge/);
    expect(adapter).toMatch(/invalid_supabase_database_role/);
    expect(transaction).toMatch(/role: "argus_runtime"/);
    expect(transaction).toMatch(/set local role \$\{role\}/i);
  });
});

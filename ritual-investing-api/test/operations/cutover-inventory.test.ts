import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../../..");
const apiRoot = resolve(repositoryRoot, "ritual-investing-api");

const retiredAuthorityPaths = [
  "ritual-investing-api/wrangler.jsonc",
  "ritual-investing-api/wrangler.beta.jsonc",
  "ritual-investing-api/vitest.worker.config.ts",
  "ritual-investing-api/drizzle.config.ts",
  "ritual-investing-api/drizzle",
  "ritual-investing-api/src/index.ts",
  "ritual-investing-api/src/generated/env.d.ts",
  "ritual-investing-api/src/config/env.ts",
  "ritual-investing-api/src/db/client.ts",
  "ritual-investing-api/src/db/schema",
  "ritual-investing-api/src/middleware/auth0-jwk.ts",
  "ritual-investing-api/src/middleware/cloudflare-access.ts",
  "ritual-investing-api/src/domains/simulation",
  "ritual-investing-api/scripts/deploy-beta-worker-secrets.ts",
  "ritual-investing-api/scripts/generate-beta-secrets.ts",
  "ritual-investing-api/scripts/render-beta-role-sql.ts",
] as const;

function workflow(): string {
  return readFileSync(
    resolve(repositoryRoot, ".github/workflows/ritual-investing.yml"),
    "utf8",
  );
}

function workflowJob(source: string, name: string): string {
  const start = source.indexOf(`\n  ${name}:\n`);
  if (start < 0) throw new Error(`Missing workflow job: ${name}`);
  const rest = source.slice(start + name.length + 5);
  const next = /\n  (?=[A-Za-z0-9_-]+:\n)/.exec(rest);
  return source.slice(
    start,
    next === null ? source.length : start + name.length + 5 + next.index,
  );
}

function runDeployGuard(overrides: Record<string, string> = {}) {
  return spawnSync(
    process.execPath,
    [
      "--experimental-strip-types",
      resolve(repositoryRoot, "scripts/check-supabase-deploy-target.ts"),
    ],
    {
      cwd: repositoryRoot,
      encoding: "utf8",
      env: {
        PATH: process.env.PATH,
        GITHUB_EVENT_NAME: "push",
        GITHUB_REF: "refs/heads/main",
        GITHUB_REPOSITORY: "ritual-investing/argus",
        RITUAL_EXPECTED_REPOSITORY: "ritual-investing/argus",
        SUPABASE_PROJECT_ID: "abcdefghijklmnopqrst",
        RITUAL_EXPECTED_SUPABASE_PROJECT_ID: "abcdefghijklmnopqrst",
        SUPABASE_PROJECT_URL: "https://abcdefghijklmnopqrst.supabase.co",
        RITUAL_HOSTED_API_URL:
          "https://abcdefghijklmnopqrst.supabase.co/functions/v1/api",
        SUPABASE_DB_URL:
          "postgresql://postgres:secret@db.abcdefghijklmnopqrst.supabase.co:5432/postgres?sslmode=require",
        RITUAL_EXPECTED_SUPABASE_DB_HOST:
          "db.abcdefghijklmnopqrst.supabase.co",
        ...overrides,
      } as unknown as NodeJS.ProcessEnv,
    },
  );
}

describe("U13 cutover inventory", () => {
  it("has one Supabase authority and no retired backend entrypoint", () => {
    expect(existsSync(resolve(repositoryRoot, "supabase/functions/api/index.ts"))).toBe(true);
    expect(existsSync(resolve(repositoryRoot, "supabase/functions/worker/index.ts"))).toBe(true);
    for (const path of retiredAuthorityPaths) {
      expect(existsSync(resolve(repositoryRoot, path)), path).toBe(false);
    }
  });

  it("removes Cloudflare Worker, Neon, and Drizzle package authority", () => {
    const packageJson = JSON.parse(
      readFileSync(resolve(apiRoot, "package.json"), "utf8"),
    ) as { scripts: Record<string, string>; dependencies: Record<string, string>; devDependencies: Record<string, string> };
    const serialized = JSON.stringify(packageJson);
    expect(serialized).not.toMatch(
      /@neondatabase\/serverless|drizzle-(?:orm|kit)|@cloudflare\/vitest-plugin|wrangler/,
    );
    expect(Object.keys(packageJson.scripts)).not.toEqual(
      expect.arrayContaining([
        "db:migrate",
        "db:migrate:check",
        "deploy:dry-run",
        "deploy:beta",
        "deploy:beta:dry-run",
        "test:workers",
      ]),
    );
  });

  it("uses only declared API package scripts in CI", () => {
    const scripts = JSON.parse(
      readFileSync(resolve(apiRoot, "package.json"), "utf8"),
    ) as { scripts: Record<string, string> };
    const apiJob = workflowJob(workflow(), "api-security");
    const invoked = [...apiJob.matchAll(/npm run ([\w:-]+)/g)].map(
      ([, name]) => name!,
    );
    expect(invoked.length).toBeGreaterThan(0);
    for (const name of invoked) {
      expect(scripts.scripts, `missing API script ${name}`).toHaveProperty(name);
    }
  });

  it("keeps ordinary CI secret-free and without hosted mutation authority", () => {
    const source = workflow();
    const local = workflowJob(source, "supabase-local");

    expect(local).toContain("supabase db reset");
    expect(local).toContain("supabase test db");
    expect(local).not.toMatch(
      /secrets\.|SUPABASE_ACCESS_TOKEN|SUPABASE_DB_PASSWORD/,
    );
    expect(source).not.toMatch(
      /supabase-hosted-development|supabase\s+(?:link|db\s+(?:push|repair)|functions\s+deploy)|psql[^\n]*SUPABASE_DB_URL|SUPABASE_ACCESS_TOKEN|SUPABASE_DB_PASSWORD/,
    );
    expect(source).not.toMatch(
      /github\.event_name\s*==\s*['"]push['"][\s\S]{0,500}(?:db\s+push|functions\s+deploy|fence-supabase-deployment)/,
    );

    const baseline = readFileSync(
      resolve(
        repositoryRoot,
        "supabase/migrations/20260828054740_argus_private_baseline.sql",
      ),
      "utf8",
    );
    const fence = readFileSync(
      resolve(repositoryRoot, "scripts/fence-supabase-deployment.sql"),
      "utf8",
    );
    expect(baseline).toMatch(
      /\('background_workers',\s*true,\s*'disabled until hosted acceptance passes'\)/,
    );
    expect(fence).toContain("to_regclass('argus_private.kill_switches')");
    expect(fence).toContain("partial_argus_schema_without_kill_switches");
    for (const name of [
      "background_workers",
      "provider_egress",
      "order_mutations",
    ]) {
      expect(fence, name).toContain(name);
    }
  });

  it("accepts only the exact protected hosted-development target", () => {
    const accepted = runDeployGuard();
    expect(accepted.status, accepted.stderr).toBe(0);
    expect(accepted.stdout).toContain("Supabase deploy target verified");

    for (const overrides of [
      { GITHUB_EVENT_NAME: "pull_request", GITHUB_REF: "refs/pull/17/merge" },
      { GITHUB_REF: "refs/heads/feature" },
      { SUPABASE_PROJECT_ID: "wrongprojectref00000" },
      { SUPABASE_PROJECT_URL: "https://wrongprojectref00000.supabase.co" },
      {
        RITUAL_HOSTED_API_URL:
          "https://wrongprojectref00000.supabase.co/functions/v1/api",
      },
      {
        SUPABASE_DB_URL:
          "postgresql://postgres:secret@db.attacker.example:5432/postgres?sslmode=require",
      },
      {
        SUPABASE_DB_URL:
          "postgresql://postgres.wrongprojectref00000:secret@aws-0-us-east-1.pooler.supabase.com:6543/postgres?sslmode=require",
        RITUAL_EXPECTED_SUPABASE_DB_HOST:
          "aws-0-us-east-1.pooler.supabase.com",
      },
      {
        SUPABASE_DB_URL:
          "postgresql://postgres:secret@db.wrongprojectref00000.supabase.co:5432/postgres?sslmode=require",
        RITUAL_EXPECTED_SUPABASE_DB_HOST:
          "db.wrongprojectref00000.supabase.co",
      },
      { SUPABASE_DB_URL: "postgresql://postgres:secret@db.abcdefghijklmnopqrst.supabase.co:5432/postgres" },
      {
        SUPABASE_DB_URL:
          "postgresql://postgres:secret@db.abcdefghijklmnopqrst.supabase.co/postgres?sslmode=require",
      },
      {
        SUPABASE_DB_URL:
          "postgresql://postgres:secret@db.abcdefghijklmnopqrst.supabase.co:6543/postgres?sslmode=require",
      },
      {
        SUPABASE_DB_URL:
          "postgresql://postgres.abcdefghijklmnopqrst:secret@aws-0-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require",
        RITUAL_EXPECTED_SUPABASE_DB_HOST:
          "aws-0-us-east-1.pooler.supabase.com",
      },
      {
        SUPABASE_DB_URL:
          "postgresql://postgres.abcdefghijklmnopqrst:secret@aws-0-us-east-1.pooler.supabase.com/postgres?sslmode=require",
        RITUAL_EXPECTED_SUPABASE_DB_HOST:
          "aws-0-us-east-1.pooler.supabase.com",
      },
    ]) {
      const rejected = runDeployGuard(overrides);
      expect(rejected.status, JSON.stringify(overrides)).not.toBe(0);
      expect(`${rejected.stdout}${rejected.stderr}`).not.toContain("secret");
    }

    const pooler = runDeployGuard({
      SUPABASE_DB_URL:
        "postgresql://postgres.abcdefghijklmnopqrst:secret@aws-0-us-east-1.pooler.supabase.com:6543/postgres?sslmode=require",
      RITUAL_EXPECTED_SUPABASE_DB_HOST:
        "aws-0-us-east-1.pooler.supabase.com",
    });
    expect(pooler.status, pooler.stderr).toBe(0);
  }, 15_000);

  it("proves every Cloudflare Pages project is static-only", () => {
    const configs = [
      "wrangler.jsonc",
      "wrangler.beta.jsonc",
      "wrangler.demo.jsonc",
      "wrangler.demo-beta.jsonc",
    ];
    for (const file of configs) {
      const value = JSON.parse(
        readFileSync(resolve(repositoryRoot, "ritual-investing-site", file), "utf8"),
      ) as Record<string, unknown>;
      expect(value.pages_build_output_dir, file).toMatch(/^\.\/dist\//);
      expect(value, file).not.toHaveProperty("main");
      expect(value, file).not.toHaveProperty("routes");
      expect(value, file).not.toHaveProperty("r2_buckets");
      expect(value, file).not.toHaveProperty("queues");
      expect(value, file).not.toHaveProperty("services");
      expect(value, file).not.toHaveProperty("triggers");
    }
    expect(existsSync(resolve(repositoryRoot, "ritual-investing-site/functions"))).toBe(false);
    expect(existsSync(resolve(repositoryRoot, "ritual-investing-site/_worker.js"))).toBe(false);
  });
});

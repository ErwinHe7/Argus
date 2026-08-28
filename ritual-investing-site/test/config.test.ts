import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const ROOT = resolve(import.meta.dirname, "..");
const CONFIGS = [
  ["wrangler.jsonc", "./dist/landing"],
  ["wrangler.beta.jsonc", "./dist/landing-beta"],
  ["wrangler.demo.jsonc", "./dist/demo"],
  ["wrangler.demo-beta.jsonc", "./dist/demo-beta"],
] as const;

function config(file: string): Record<string, unknown> {
  return JSON.parse(readFileSync(resolve(ROOT, file), "utf8")) as Record<string, unknown>;
}

describe("Cloudflare Pages static-only configuration", () => {
  it("declares four distinct Pages asset projects", () => {
    const values = CONFIGS.map(([file, directory]) => {
      const value = config(file);
      expect(value.compatibility_date).toBe("2026-08-25");
      expect(value.pages_build_output_dir).toBe(directory);
      return value;
    });
    expect(new Set(values.map((value) => value.name)).size).toBe(4);
  });

  it("contains no Cloudflare compute, route, state, or backend binding", () => {
    const forbidden = [
      "main", "assets", "routes", "route", "workers_dev", "preview_urls",
      "vars", "ratelimits", "kv_namespaces", "analytics_engine_datasets",
      "r2_buckets", "d1_databases", "queues", "services", "durable_objects",
      "triggers",
    ];
    for (const [file] of CONFIGS) {
      const value = config(file);
      for (const key of forbidden) expect(value).not.toHaveProperty(key);
      expect(JSON.stringify(value)).not.toMatch(/worker|neon|postgres|auth0|webull/i);
    }
  });

  it("keeps runtime provider dependencies out of the static package", () => {
    const packageJson = JSON.parse(
      readFileSync(resolve(ROOT, "package.json"), "utf8"),
    ) as { dependencies: Record<string, string>; devDependencies: Record<string, string> };
    expect(packageJson.dependencies).toEqual({});
    expect(packageJson.devDependencies.wrangler).toBe("4.125.0");
    expect(JSON.stringify(packageJson)).not.toMatch(/neondatabase|drizzle|hono|workers-types/i);
  });
});

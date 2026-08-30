import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const ROOT = resolve(import.meta.dirname, "..");
const PAGES_CONFIGS = [
  ["wrangler.beta.jsonc", "./dist/landing-beta"],
  ["wrangler.demo.jsonc", "./dist/demo"],
  ["wrangler.demo-beta.jsonc", "./dist/demo-beta"],
] as const;
const WORKER_CONFIGS = [
  ["wrangler.jsonc", "./dist/member-beta", "single-page-application"],
  ["wrangler.landing.jsonc", "./dist/landing", "none"],
] as const;

function config(file: string): Record<string, unknown> {
  return JSON.parse(readFileSync(resolve(ROOT, file), "utf8")) as Record<string, unknown>;
}

describe("Cloudflare static-only configuration", () => {
  it("preserves the three neighboring Pages projects", () => {
    const values = PAGES_CONFIGS.map(([file, directory]) => {
      const value = config(file);
      expect(value.compatibility_date).toBe("2026-08-25");
      expect(value.pages_build_output_dir).toBe(directory);
      return value;
    });
    expect(new Set(values.map((value) => value.name)).size).toBe(3);
  });

  it("declares asset-only member and landing Workers without a script or binding", () => {
    const names = new Set<string>();
    for (const [file, directory, notFoundHandling] of WORKER_CONFIGS) {
      const value = config(file) as {
        assets?: Record<string, unknown>;
        compatibility_date?: unknown;
        name?: string;
      };
      names.add(value.name ?? "");
      expect(value.compatibility_date).toBe("2026-08-25");
      expect(value.assets).toEqual({
        directory,
        html_handling: "none",
        not_found_handling: notFoundHandling,
      });
      expect(value).not.toHaveProperty("main");
      expect(value).not.toHaveProperty("pages_build_output_dir");
      expect(value.assets).not.toHaveProperty("binding");
      expect(value.assets).not.toHaveProperty("run_worker_first");
    }
    expect(names).toEqual(new Set(["ritual-investing-member"]));
  });

  it("contains no Cloudflare compute, route, state, or backend binding", () => {
    const forbidden = [
      "main", "routes", "route", "workers_dev", "preview_urls",
      "vars", "ratelimits", "kv_namespaces", "analytics_engine_datasets",
      "r2_buckets", "d1_databases", "queues", "services", "durable_objects",
      "triggers",
    ];
    for (const [file] of [...PAGES_CONFIGS, ...WORKER_CONFIGS]) {
      const value = config(file);
      for (const key of forbidden) expect(value).not.toHaveProperty(key);
      expect(JSON.stringify(value)).not.toMatch(/neon|postgres|auth0|webull/i);
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

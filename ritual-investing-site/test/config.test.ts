import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

import { RESOURCE_MANIFEST, validateResourceManifest } from "../scripts/resource-manifest.ts";

const ROOT = resolve(import.meta.dirname, "..");
const CONFIGS = [
  ["production", "wrangler.jsonc"],
  ["beta", "wrangler.beta.jsonc"],
  ["demo-production", "wrangler.demo.jsonc"],
  ["demo-beta", "wrangler.demo-beta.jsonc"],
] as const;

function config(file: string): Record<string, unknown> {
  return JSON.parse(readFileSync(resolve(ROOT, file), "utf8")) as Record<string, unknown>;
}

describe("Cloudflare environment isolation", () => {
  it("pins the validated Node and Cloudflare/Neon stack exactly", () => {
    const packageJson = JSON.parse(readFileSync(resolve(ROOT, "package.json"), "utf8")) as {
      engines: { node: string };
      dependencies: Record<string, string>;
      devDependencies: Record<string, string>;
    };
    expect(packageJson.engines.node).toBe("22.x");
    expect(packageJson.devDependencies.wrangler).toBe("4.125.0");
    expect(packageJson.dependencies.hono).toBe("4.13.3");
    expect(packageJson.dependencies["drizzle-orm"]).toBe("0.45.2");
    expect(packageJson.dependencies["@neondatabase/serverless"]).toBe("1.1.0");
  });

  it("defines four exact, non-preview custom-domain deployments", () => {
    const parsed = CONFIGS.map(([environment, file]) => [environment, config(file)] as const);
    const expectedHosts = [
      "just-build-this.app",
      "beta.just-build-this.app",
      "demo.just-build-this.app",
      "demo-beta.just-build-this.app",
    ];

    expect(parsed.map(([, value]) => value.name)).toHaveLength(new Set(parsed.map(([, value]) => value.name)).size);
    expect(parsed.map(([, value]) => (value.routes as Array<{ pattern: string }>)[0]?.pattern)).toEqual(expectedHosts);
    for (const [, value] of parsed) {
      expect(value.compatibility_date).toBe("2026-08-25");
      expect(value.workers_dev).toBe(false);
      expect(value.preview_urls).toBe(false);
      expect(value.observability).toMatchObject({ logs: { invocation_logs: false } });
    }
  });

  it("enables Node compatibility only on executable landing Workers", () => {
    for (const file of ["wrangler.jsonc", "wrangler.beta.jsonc"]) {
      expect(config(file).compatibility_flags).toEqual(["nodejs_compat"]);
    }
    for (const file of ["wrangler.demo.jsonc", "wrangler.demo-beta.jsonc"]) {
      expect(config(file)).not.toHaveProperty("compatibility_flags");
    }
  });

  it("routes only API paths through landing code and has no SPA fallback", () => {
    for (const file of ["wrangler.jsonc", "wrangler.beta.jsonc"]) {
      const value = config(file);
      expect(value.main).toBe("src/index.ts");
      expect(value.assets).toEqual({
        directory: "./dist/landing",
        binding: "ASSETS",
        run_worker_first: ["/api/*"],
        not_found_handling: "none",
      });
    }
  });

  it("keeps demo Workers asset-only and unable to access landing/data/telemetry resources", () => {
    for (const file of ["wrangler.demo.jsonc", "wrangler.demo-beta.jsonc"]) {
      const value = config(file);
      expect(value.main).toBeUndefined();
      expect(value.assets).toEqual({ directory: "./dist/demo", not_found_handling: "none" });
      for (const forbidden of ["vars", "ratelimits", "kv_namespaces", "analytics_engine_datasets", "r2_buckets", "d1_databases", "services"]) {
        expect(value).not.toHaveProperty(forbidden);
      }
    }
  });

  it("declares disjoint production/beta resources without exposing the denial journal to runtime", () => {
    expect(validateResourceManifest(RESOURCE_MANIFEST)).toEqual([]);
    for (const [environment, file] of [["production", "wrangler.jsonc"], ["beta", "wrangler.beta.jsonc"]] as const) {
      const resources = RESOURCE_MANIFEST[environment];
      const value = config(file);
      const vars = value.vars as Record<string, string>;
      const rateLimits = value.ratelimits as Array<{ name: string; namespace_id: string }>;
      const checkpoint = (value.kv_namespaces as Array<{ binding: string; id: string }>)[0];
      const telemetry = (value.analytics_engine_datasets as Array<{ binding: string; dataset: string }>)[0];
      expect(value.name).toBe(resources.landing.service);
      expect((value.routes as Array<{ pattern: string }>)[0]?.pattern).toBe(resources.landing.host);
      expect(vars.WAITLIST_SUBMISSIONS).toBe("off");
      expect(vars.TURNSTILE_EXPECTED_HOSTNAME).toBe(resources.turnstile.hostname);
      expect(vars.TURNSTILE_EXPECTED_ACTION).toBe(resources.turnstile.action);
      expect(vars.TURNSTILE_SITE_KEY_RESOURCE).toBe(resources.turnstile.siteKeyResource);
      expect(vars.TURNSTILE_SECRET_RESOURCE).toBe(resources.turnstile.secretResource);
      expect(vars.WAITLIST_CREDENTIAL_RESOURCE).toBe(resources.neon.runtimeCredential);
      expect(vars.WAITLIST_WAF_BUDGET_RESOURCE).toBe(resources.wafBudget.rule);
      expect(vars.WAITLIST_WAF_CEILING_RESOURCE).toBe(resources.wafBudget.ceiling);
      expect(rateLimits).toEqual(expect.arrayContaining([
        expect.objectContaining({ name: resources.rateLimits.source.binding, namespace_id: resources.rateLimits.source.namespaceId }),
        expect.objectContaining({ name: resources.rateLimits.route.binding, namespace_id: resources.rateLimits.route.namespaceId }),
      ]));
      expect(checkpoint).toEqual({ binding: resources.retention.checkpointBinding, id: resources.retention.checkpointNamespaceId });
      expect(telemetry).toEqual({ binding: resources.telemetry.binding, dataset: resources.telemetry.dataset });
      expect(value.triggers).toEqual({ crons: [resources.retention.cron] });
      const serialized = JSON.stringify(value);
      expect(serialized).not.toContain("DENIAL_JOURNAL");
      expect(serialized).not.toContain("DATABASE_URL");
      expect(serialized).not.toContain("postgresql://");
    }
  });
});

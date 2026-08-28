import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

type WranglerConfig = {
  name: string;
  routes: Array<{ pattern: string; custom_domain: boolean }>;
  vars: Record<string, string>;
  queues?: {
    producers: Array<{ queue: string }>;
    consumers: Array<{ queue: string; dead_letter_queue: string }>;
  };
  r2_buckets?: Array<{ bucket_name: string }>;
  ratelimits: Array<{ namespace_id: string }>;
};

function config(name: string): WranglerConfig {
  return JSON.parse(
    readFileSync(resolve(process.cwd(), name), "utf8"),
  ) as WranglerConfig;
}

describe("beta deployment isolation", () => {
  it("uses staging identity and a beta-only custom domain", () => {
    const beta = config("wrangler.beta.jsonc");

    expect(beta.name).toBe("ritual-investing-api-beta");
    expect(beta.vars.ENVIRONMENT).toBe("staging");
    expect(beta.vars.API_ORIGIN).toBe(
      "https://api-beta.just-build-this.app",
    );
    expect(beta.routes).toEqual([
      { pattern: "api-beta.just-build-this.app", custom_domain: true },
    ]);
    for (const name of ["KILL_SWITCH_NOTIFICATIONS", "KILL_SWITCH_EXPORTS"]) {
      expect(beta.vars[name], name).toBe("on");
    }
  });

  it("uses the configured beta Auth0 tenant and API audience", () => {
    const beta = config("wrangler.beta.jsonc");

    expect(beta.vars.AUTH0_ISSUER).toBe(
      "https://dev-pxee7db52tqc4xoe.us.auth0.com/",
    );
    expect(beta.vars.AUTH0_JWKS_URL).toBe(
      "https://dev-pxee7db52tqc4xoe.us.auth0.com/.well-known/jwks.json",
    );
    expect(beta.vars.AUTH0_AUDIENCE).toBe(
      "https://api-beta.just-build-this.app",
    );
  });

  it("has no retired Queue or R2 binding and isolates rate-limit namespaces", () => {
    const production = config("wrangler.jsonc");
    const beta = config("wrangler.beta.jsonc");
    const resources = (value: WranglerConfig) => new Set([
      ...(value.queues?.producers ?? []).map((entry) => entry.queue),
      ...(value.queues?.consumers ?? []).flatMap((entry) => [
        entry.queue,
        entry.dead_letter_queue,
      ]),
      ...(value.r2_buckets ?? []).map((entry) => entry.bucket_name),
      ...value.ratelimits.map((entry) => entry.namespace_id),
    ]);
    const productionResources = resources(production);

    expect(production.queues).toBeUndefined();
    expect(production.r2_buckets).toBeUndefined();
    expect(beta.queues).toBeUndefined();
    expect(beta.r2_buckets).toBeUndefined();

    expect(
      [...resources(beta)].filter((resource) =>
        productionResources.has(resource),
      ),
    ).toEqual([]);
  });
});

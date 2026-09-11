import { describe, expect, it } from "vitest";
import { createStrategyApp } from "../../src/domains/strategy-lab/app.ts";
import { productionStrategyOrigins } from "../../src/domains/strategy-lab/origins.ts";
import { memoryRepository } from "./memory-repository.ts";

const canonical = "https://leoinvesting.com";
const retained = "https://leo.axio7.workers.dev";

describe("strategy production domains", () => {
  it("supports the custom domain and retained Worker without widening other origins", () => {
    expect(productionStrategyOrigins(canonical)).toEqual([canonical]);
    expect(productionStrategyOrigins(retained)).toEqual([retained]);
    expect(productionStrategyOrigins(`${canonical}, ${retained}`)).toEqual([canonical, retained]);
    for (const value of ["", "*", "https://*.leoinvesting.com", "http://leoinvesting.com", `${canonical}/`, `${canonical}:443`, `${canonical}:8443`, "https://leoinvesting.com.evil.example", "https://www.leoinvesting.com", `${canonical},${canonical}`, `${canonical},https://evil.example`]) {
      expect(() => productionStrategyOrigins(value), value).toThrow();
    }
  });

  it("reflects only a permitted exact origin and still requires member authentication", async () => {
    const { repository } = memoryRepository(() => new Date("2026-09-10T12:00:00Z"));
    const app = createStrategyApp({
      repository,
      origins: productionStrategyOrigins(`${canonical},${retained}`),
      verifyAccessToken: async () => { throw new Error("No authenticated test user"); },
      rateLimit: { allow: async () => ({ allowed: true }) },
    });
    for (const origin of [canonical, retained]) {
      const preflight = await app.request("/v1/status", { method: "OPTIONS", headers: { origin } });
      expect(preflight.status).toBe(204);
      expect(preflight.headers.get("access-control-allow-origin")).toBe(origin);
      expect(preflight.headers.get("vary")).toBe("origin");
      const status = await app.request("/v1/status", { headers: { origin } });
      expect(status.status).toBe(401);
    }
    const rejected = await app.request("/v1/status", { method: "OPTIONS", headers: { origin: "https://leoinvesting.com.evil.example" } });
    expect(rejected.status).toBe(403);
    expect(rejected.headers.get("access-control-allow-origin")).toBeNull();
  });
});

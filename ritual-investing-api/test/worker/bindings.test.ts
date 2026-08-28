import { env, exports } from "cloudflare:workers";
import {
  createExecutionContext,
} from "cloudflare:test";
import { describe, expect, it } from "vitest";

import type { Bindings } from "../../src/config/env";
import worker from "../../src/index";

describe("Worker entrypoints", () => {
  it("serves fetch requests without leaking stack detail", async () => {
    const response = await exports.default.fetch("https://api.example.test/health");
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ data: { status: "ok" } });
  });

  it("fails closed without exposing production configuration errors", async () => {
    const response = await worker.fetch(
      new Request("https://api.example.test/health"),
      { ...env, ENVIRONMENT: "production" } as unknown as Bindings,
      createExecutionContext(),
    );
    expect(response.status).toBe(503);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(await response.json()).toEqual({
      type: "https://api.just-build-this.app/problems/service-unavailable",
      title: "Service unavailable",
      status: 503,
      code: "runtime_configuration_unavailable",
    });
  });

  it("does not expose Cloudflare scheduled or Queue compute", () => {
    expect(Object.keys(worker).sort()).toEqual(["fetch"]);
  });
});

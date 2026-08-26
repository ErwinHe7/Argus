import { describe, expect, it, vi } from "vitest";

import { createWorker, type RuntimeSiteEnv, type SiteEnv } from "../src/index.ts";

function environment(assetResponse = new Response("asset", { status: 200 })): RuntimeSiteEnv {
  const fetch = vi.fn(async () => assetResponse);
  return {
    ASSETS: {
      fetch,
      connect() {
        throw new Error("Static Assets never opens sockets in routing tests.");
      },
    } satisfies SiteEnv["ASSETS"],
    ENVIRONMENT: "production",
    WAITLIST_SUBMISSIONS: "off",
  };
}

describe("landing Worker routing", () => {
  it("delegates a landing request to Static Assets without constructing retention or data capabilities", async () => {
    const purgeFactory = vi.fn();
    const worker = createWorker({ purgeFactory });
    const env = environment(new Response("landing", { status: 200 }));

    const response = await worker.fetch(new Request("https://just-build-this.app/"), env, {} as ExecutionContext);

    expect(await response.text()).toBe("landing");
    expect(env.ASSETS.fetch).toHaveBeenCalledOnce();
    expect(purgeFactory).not.toHaveBeenCalled();
  });

  it("returns a JSON 404 for unknown API routes", async () => {
    const env = environment();
    const response = await createWorker().fetch(
      new Request("https://just-build-this.app/api/unknown"),
      env,
      {} as ExecutionContext,
    );

    expect(response.status).toBe(404);
    expect(response.headers.get("content-type")).toContain("application/json");
    expect(await response.json()).toEqual({ code: "api_route_not_found" });
    expect(env.ASSETS.fetch).not.toHaveBeenCalled();
  });

  it("keeps the future waitlist endpoint fail-closed while submissions are disabled", async () => {
    const env = environment();
    const response = await createWorker().fetch(
      new Request("https://just-build-this.app/api/waitlist", { method: "POST" }),
      env,
      {} as ExecutionContext,
    );

    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ code: "waitlist_unavailable" });
    expect(env.ASSETS.fetch).not.toHaveBeenCalled();
  });

  it("preserves a deliberate asset 404 instead of falling back to index.html", async () => {
    const env = environment(new Response("Not Found", { status: 404 }));
    const response = await createWorker().fetch(
      new Request("https://just-build-this.app/missing-page"),
      env,
      {} as ExecutionContext,
    );

    expect(response.status).toBe(404);
    expect(await response.text()).toBe("Not Found");
  });
});

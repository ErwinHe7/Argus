import { describe, expect, it, vi } from "vitest";

import worker from "../../src/index";
import { testBindings } from "../support/security-fixtures";

describe("admin Flutter Web host", () => {
  it("serves only the bound staff dashboard on the explicit UI hostname", async () => {
    const fetch = vi.fn(
      async () =>
        new Response("<html>admin</html>", {
          headers: { "content-type": "text/html; charset=utf-8" },
        }),
    );
    const bindings = {
      ...testBindings(),
      ADMIN_UI_HOST: "admin.ritual-investing.test",
      ADMIN_ASSETS: { fetch },
    } as never;
    const response = await worker.fetch!(
      new Request("https://admin.ritual-investing.test/editorial/rituals"),
      bindings,
      {} as never,
    );

    expect(response.status).toBe(200);
    expect(fetch).toHaveBeenCalledOnce();
    expect(response.headers.get("content-security-policy")).toContain(
      "frame-ancestors 'none'",
    );
    expect(response.headers.get("x-content-type-options")).toBe("nosniff");
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("keeps API paths behind the staff middleware on the same hostname", async () => {
    const fetch = vi.fn(async () => new Response("should not load"));
    const response = await worker.fetch!(
      new Request("https://admin.ritual-investing.test/v1/admin/me"),
      {
        ...testBindings(),
        ADMIN_HOST: "admin.ritual-investing.test",
        ADMIN_UI_HOST: "admin.ritual-investing.test",
        ADMIN_ASSETS: { fetch },
      } as never,
      {} as never,
    );
    expect(response.status).toBe(401);
    expect(fetch).not.toHaveBeenCalled();
  });
});

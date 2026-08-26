import { describe, expect, it, vi } from "vitest";

import { verifyTurnstile } from "../../src/waitlist/turnstile.ts";

const TOKEN = "synthetic-turnstile-token";

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

describe("Turnstile Siteverify boundary", () => {
  it("sends only the secret, token, and one opaque idempotency key", async () => {
    const fetcher = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) =>
      response({ success: true, hostname: "just-build-this.app", action: "waitlist" }),
    );

    await expect(verifyTurnstile({
      token: TOKEN,
      secret: "synthetic-secret",
      expectedHostname: "just-build-this.app",
      expectedAction: "waitlist",
    }, {
      fetcher,
      createIdempotencyKey: () => "66cd6bc9-eeb4-46d2-8613-c075a2dfeb59",
    })).resolves.toEqual({ ok: true });

    expect(fetcher).toHaveBeenCalledOnce();
    const [url, init] = fetcher.mock.calls[0]!;
    expect(url).toBe("https://challenges.cloudflare.com/turnstile/v0/siteverify");
    expect(init?.method).toBe("POST");
    const body = new URLSearchParams(String(init?.body));
    expect(Object.fromEntries(body)).toEqual({
      secret: "synthetic-secret",
      response: TOKEN,
      idempotency_key: "66cd6bc9-eeb4-46d2-8613-c075a2dfeb59",
    });
    expect(body.has("remoteip")).toBe(false);
  });

  it("retries one transient provider failure with the same idempotency key", async () => {
    const fetcher = vi.fn()
      .mockResolvedValueOnce(response({ success: false, "error-codes": ["internal-error"] }))
      .mockResolvedValueOnce(response({ success: true, hostname: "just-build-this.app", action: "waitlist" }));

    await expect(verifyTurnstile({
      token: TOKEN,
      secret: "synthetic-secret",
      expectedHostname: "just-build-this.app",
      expectedAction: "waitlist",
    }, {
      fetcher,
      createIdempotencyKey: () => "a2081184-798f-4353-b7d4-e35908e45f0b",
    })).resolves.toEqual({ ok: true });

    expect(fetcher).toHaveBeenCalledTimes(2);
    const keys = fetcher.mock.calls.map(([, init]) =>
      new URLSearchParams(String(init?.body)).get("idempotency_key"),
    );
    expect(keys).toEqual([
      "a2081184-798f-4353-b7d4-e35908e45f0b",
      "a2081184-798f-4353-b7d4-e35908e45f0b",
    ]);
  });

  it.each([
    ["expired or replayed", { success: false, "error-codes": ["timeout-or-duplicate"] }],
    ["wrong hostname", { success: true, hostname: "hostile.example", action: "waitlist" }],
    ["wrong action", { success: true, hostname: "just-build-this.app", action: "other" }],
    ["malformed success", { success: "true", hostname: "just-build-this.app", action: "waitlist" }],
  ])("rejects %s without exposing provider detail", async (_name, payload) => {
    const result = await verifyTurnstile({
      token: TOKEN,
      secret: "synthetic-secret",
      expectedHostname: "just-build-this.app",
      expectedAction: "waitlist",
    }, { fetcher: async () => response(payload) });

    expect(result).toEqual({ ok: false, kind: "rejected" });
    expect(JSON.stringify(result)).not.toMatch(/hostile|duplicate|error-codes/i);
  });

  it.each([null, [], "success", 1])("treats a non-object provider payload as unavailable", async (payload) => {
    const result = await verifyTurnstile({
      token: TOKEN,
      secret: "synthetic-secret",
      expectedHostname: "just-build-this.app",
      expectedAction: "waitlist",
    }, { fetcher: async () => response(payload) });
    expect(result).toEqual({ ok: false, kind: "unavailable" });
  });

  it("bounds timeouts and transient retries without leaking the exception", async () => {
    const fetcher = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      await new Promise<void>((_resolve, reject) => {
        init?.signal?.addEventListener("abort", () => reject(new Error("token URL SQL raw-ip")), { once: true });
      });
      return response({});
    });

    const result = await verifyTurnstile({
      token: TOKEN,
      secret: "synthetic-secret",
      expectedHostname: "just-build-this.app",
      expectedAction: "waitlist",
    }, { fetcher, timeoutMs: 2 });

    expect(result).toEqual({ ok: false, kind: "unavailable" });
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(JSON.stringify(result)).not.toMatch(/token|url|sql|ip/i);
  });

  it("bounds the response body parse as part of each Siteverify attempt", async () => {
    const fetcher = vi.fn(async () => new Response(new ReadableStream({
      start() { /* response headers arrive but the provider body never completes */ },
    }), { status: 200, headers: { "content-type": "application/json" } }));

    const result = await verifyTurnstile({
      token: TOKEN,
      secret: "synthetic-secret",
      expectedHostname: "just-build-this.app",
      expectedAction: "waitlist",
    }, { fetcher, timeoutMs: 2 });

    expect(result).toEqual({ ok: false, kind: "unavailable" });
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it.each(["", "x".repeat(2049)])("rejects an invalid token length before network access", async (token) => {
    const fetcher = vi.fn();
    await expect(verifyTurnstile({
      token,
      secret: "synthetic-secret",
      expectedHostname: "just-build-this.app",
      expectedAction: "waitlist",
    }, { fetcher })).resolves.toEqual({ ok: false, kind: "rejected" });
    expect(fetcher).not.toHaveBeenCalled();
  });
});

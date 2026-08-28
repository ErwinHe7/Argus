import { describe, expect, it, vi } from "vitest";

import {
  createWebullCallbackHandler,
  parseWebullCallback,
} from "../../../supabase/functions/webull-callback/handler.ts";
import { WebullTokenVault } from "../../../supabase/functions/_shared/webull/tokens.ts";

const stateValue = "A".repeat(43);
const now = new Date("2026-08-28T12:00:00Z");
const consumedState = Object.freeze({
  stateId: "018f3c2a-4b67-7a89-8abc-123456789010",
  userId: "018f3c2a-4b67-7a89-8abc-123456789001",
  sessionId: "018f3c2a-4b67-7a89-8abc-123456789002",
  deletionEpoch: 0,
  connectionId: "018f3c2a-4b67-7a89-8abc-123456789003",
  returnTarget: "webull_native" as const,
  contractVersion: "webull-connect-public-docs-2026-08-28",
  environment: "sandbox" as const,
});

function fixture(overrides: Record<string, unknown> = {}) {
  const complete = vi.fn(async (..._arguments: unknown[]) => undefined);
  const fail = vi.fn(async (..._arguments: unknown[]) => undefined);
  const consumeState = vi.fn(async () => consumedState);
  const repository = {
    consumeState,
    complete,
    fail,
    completionLifetimeMilliseconds: 300_000,
  };
  const provider = {
    authorizationUrl: vi.fn(),
    exchangeAuthorizationCode: vi.fn(async () => ({
      accessToken: "synthetic-access-token",
      refreshToken: "synthetic-refresh-token",
      accessExpiresAt: new Date(now.getTime() + 30 * 60_000),
      refreshExpiresAt: new Date(now.getTime() + 15 * 86_400_000),
    })),
    refresh: vi.fn(),
    listAccounts: vi.fn(async () => [{
      providerAccountId: "synthetic-provider-account-1",
      displayLabel: "Webull •••• 0001",
      baseCurrency: "USD",
      status: "available" as const,
      capabilityVersion: 1,
      marketTimezone: "America/New_York",
      capabilities: [
        { code: "BALANCES_READ", available: true },
        { code: "POSITIONS_READ", available: true },
      ],
    }]),
    ...overrides,
  };
  const tokenVault = new WebullTokenVault("sandbox", {
    activeVersion: 1,
    keys: { 1: Buffer.alloc(32, 9).toString("base64") },
  });
  return {
    complete,
    consumeState,
    fail,
    provider,
    handler: createWebullCallbackHandler({
      repository: repository as never,
      provider,
      providerEnvironment: "sandbox",
      tokenVault,
      accountIdPepper: "synthetic-account-pepper-value-0001",
      now: () => now,
    }),
  };
}

describe("Webull callback boundary", () => {
  it("accepts the exact callback once, stores protected values, and returns only a completion handle", async () => {
    const test = fixture();
    const response = await test.handler(
      new Request(
        `https://project.supabase.co/functions/v1/webull-callback?state=${stateValue}&code=synthetic-code-0001`,
      ),
    );
    expect(response.status).toBe(303);
    expect(response.headers.get("cache-control")).toContain("no-store");
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
    const location = new URL(response.headers.get("location")!);
    expect(location.protocol).toBe(
      "com.ritualinvesting.ritual-investing-app.webull:",
    );
    expect(location.pathname).toBe("/complete");
    expect(location.searchParams.get("completion")).toMatch(
      /^[A-Za-z0-9_-]{43}$/,
    );
    expect(location.toString()).not.toContain("synthetic-access-token");
    expect(await response.text()).toBe("");
    expect(test.complete).toHaveBeenCalledOnce();
    const credentials = test.complete.mock.calls[0]![1] as {
      accessCiphertext: Uint8Array;
    };
    expect(credentials.accessCiphertext).toBeInstanceOf(Uint8Array);
    expect(JSON.stringify(credentials)).not.toContain("synthetic-access-token");
  });

  it("consumes denied state without reflecting provider errors", async () => {
    const test = fixture();
    const response = await test.handler(
      new Request(
        `https://project.supabase.co/functions/v1/webull-callback?state=${stateValue}&error=access_denied&error_description=sensitive-provider-detail`,
      ),
    );
    expect(response.status).toBe(303);
    expect(response.headers.get("location")).not.toContain("access_denied");
    expect(response.headers.get("location")).not.toContain(
      "sensitive-provider-detail",
    );
    expect(test.fail).toHaveBeenCalledWith(
      consumedState,
      "denied",
      expect.stringMatching(/^[a-f0-9]{64}$/),
      expect.any(Date),
    );
    expect(test.provider.exchangeAuthorizationCode).not.toHaveBeenCalled();
  });

  it("fails closed for replay, malformed fields, and database unavailability", async () => {
    const replay = fixture();
    replay.consumeState.mockResolvedValueOnce(null as never);
    const replayed = await replay.handler(
      new Request(
        `https://project.supabase.co/functions/v1/webull-callback?state=${stateValue}&code=synthetic-code-0001`,
      ),
    );
    expect(replayed.status).toBe(400);
    expect(replayed.headers.get("cache-control")).toContain("no-store");

    expect(() =>
      parseWebullCallback(
        new URL(
          `https://project.test/callback?state=${stateValue}&code=synthetic-code-0001&error_description=extra`,
        ),
      )
    ).toThrow();

    const unavailable = fixture();
    unavailable.consumeState.mockRejectedValueOnce(
      new Error("database secret"),
    );
    const failed = await unavailable.handler(
      new Request(
        `https://project.supabase.co/functions/v1/webull-callback?state=${stateValue}&code=synthetic-code-0001`,
      ),
    );
    expect(failed.status).toBe(503);
    expect(await failed.text()).not.toContain("database secret");
    expect(failed.headers.get("referrer-policy")).toBe("no-referrer");
  });

  it("rejects a state from another provider environment before egress", async () => {
    const test = fixture();
    test.consumeState.mockResolvedValueOnce({
      ...consumedState,
      environment: "production",
    } as never);
    const response = await test.handler(
      new Request(
        `https://project.supabase.co/functions/v1/webull-callback?state=${stateValue}&code=synthetic-code-0001`,
      ),
    );
    expect(response.status).toBe(400);
    expect(test.provider.exchangeAuthorizationCode).not.toHaveBeenCalled();
  });
});

import { describe, expect, it, vi } from "vitest";

import {
  type ProtectedWebullCredentials,
  rotateWebullCredentials,
  type WebullRefreshLeaseStore,
  WebullRefreshRejectedError,
  WebullTokenVault,
} from "../../../supabase/functions/_shared/webull/tokens.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const connectionId = "018f3c2a-4b67-7a89-8abc-123456789002";
const key = Buffer.alloc(32, 7).toString("base64");
const now = new Date("2026-08-28T12:00:00Z");

async function protectedFixture(tokenVersion = 1) {
  const vault = new WebullTokenVault("sandbox", {
    activeVersion: 1,
    keys: { 1: key },
  });
  const credentials = await vault.protectCredentials({
    userId,
    connectionId,
    deletionEpoch: 0,
    tokenVersion,
    accessToken: `synthetic-access-${tokenVersion}`,
    refreshToken: `synthetic-refresh-${tokenVersion}`,
    accessExpiresAt: new Date(now.getTime() + 30 * 60_000),
    refreshExpiresAt: new Date(now.getTime() + 15 * 86_400_000),
  });
  return { vault, credentials };
}

describe("versioned Webull token custody", () => {
  it("binds ciphertext to owner, connection, deletion epoch, and token version", async () => {
    const { vault, credentials } = await protectedFixture();
    await expect(vault.openCredentials(credentials, {
      environment: "sandbox",
      userId,
      connectionId,
      deletionEpoch: 0,
    })).resolves.toMatchObject({ accessToken: "synthetic-access-1" });

    await expect(vault.openCredentials(
      { ...credentials, connectionId: "018f3c2a-4b67-7a89-8abc-123456789099" },
      {
        environment: "sandbox",
        userId,
        connectionId: "018f3c2a-4b67-7a89-8abc-123456789099",
        deletionEpoch: 0,
      },
    )).rejects.toThrow();
    await expect(vault.openCredentials(
      { ...credentials, tokenVersion: 2 },
      { environment: "sandbox", userId, connectionId, deletionEpoch: 0 },
    )).rejects.toThrow();
    await expect(vault.openCredentials(
      {
        ...credentials,
        accessCiphertext: Uint8Array.from(
          credentials.accessCiphertext,
          (byte, index) => index === 0 ? byte ^ 1 : byte,
        ),
      },
      { environment: "sandbox", userId, connectionId, deletionEpoch: 0 },
    )).rejects.toThrow();
  });

  it("rotates exactly once under a lease and compare-and-swap", async () => {
    const { vault, credentials } = await protectedFixture();
    let stored = credentials;
    let lease: string | null = null;
    const store: WebullRefreshLeaseStore = {
      acquire: vi.fn(async ({ leaseToken }) => {
        if (lease !== null) return false;
        lease = leaseToken;
        return true;
      }),
      read: vi.fn(async () => stored),
      compareAndSwap: vi.fn(async ({ expectedTokenVersion, next }) => {
        if (stored.tokenVersion !== expectedTokenVersion) return false;
        stored = next;
        return true;
      }),
      markReauthorizationRequired: vi.fn(async () => undefined),
      release: vi.fn(async (_id, leaseToken) => {
        if (lease === leaseToken) lease = null;
      }),
    };
    const provider = {
      refresh: vi.fn(async () => ({
        accessToken: "synthetic-access-rotated",
        refreshToken: "synthetic-refresh-rotated",
        accessExpiresAt: new Date(now.getTime() + 30 * 60_000),
        refreshExpiresAt: new Date(now.getTime() + 15 * 86_400_000),
      })),
    };
    const result = await rotateWebullCredentials({
      current: credentials,
      vault,
      store,
      provider,
      now,
    });
    expect(result.outcome).toBe("rotated");
    expect(result.credentials?.tokenVersion).toBe(2);
    expect(provider.refresh).toHaveBeenCalledOnce();
    expect(store.compareAndSwap).toHaveBeenCalledOnce();
    expect(store.release).toHaveBeenCalledOnce();
  });

  it("distinguishes an in-flight lease from a committed winner", async () => {
    const { vault, credentials } = await protectedFixture();
    const newer = (await protectedFixture(2)).credentials;
    const store = (
      observed: ProtectedWebullCredentials,
    ): WebullRefreshLeaseStore => ({
      acquire: vi.fn(async () => false),
      read: vi.fn(async () => observed),
      compareAndSwap: vi.fn(async () => false),
      markReauthorizationRequired: vi.fn(async () => undefined),
      release: vi.fn(async () => undefined),
    });
    const provider = { refresh: vi.fn() };
    await expect(rotateWebullCredentials({
      current: credentials,
      vault,
      store: store(credentials),
      provider,
      now,
    })).resolves.toMatchObject({ outcome: "refresh_in_progress" });
    await expect(rotateWebullCredentials({
      current: credentials,
      vault,
      store: store(newer),
      provider,
      now,
    })).resolves.toMatchObject({
      outcome: "won_elsewhere",
      credentials: newer,
    });
    expect(provider.refresh).not.toHaveBeenCalled();
  });

  it("never retries a rejected or outcome-unknown refresh", async () => {
    for (
      const rejection of [
        new WebullRefreshRejectedError("invalid refresh"),
        new Error("response lost after rotation"),
      ]
    ) {
      const { vault, credentials } = await protectedFixture();
      const mark = vi.fn(async () => undefined);
      const store: WebullRefreshLeaseStore = {
        acquire: vi.fn(async () => true),
        read: vi.fn(async () => credentials),
        compareAndSwap: vi.fn(async () => false),
        markReauthorizationRequired: mark,
        release: vi.fn(async () => undefined),
      };
      const provider = {
        refresh: vi.fn(async () => {
          throw rejection;
        }),
      };
      await expect(rotateWebullCredentials({
        current: credentials,
        vault,
        store,
        provider,
        now,
      })).resolves.toMatchObject({ outcome: "reauthorization_required" });
      expect(provider.refresh).toHaveBeenCalledOnce();
      expect(mark).toHaveBeenCalledOnce();
      expect(store.compareAndSwap).not.toHaveBeenCalled();
    }
  });
});

import { describe, expect, it, vi } from "vitest";

import type { BrokerageProjectionRepository } from "../../src/domains/brokerage-projections/repository.ts";
import {
  createBrokerageProjectionService,
} from "../../src/domains/brokerage-projections/service.ts";
import {
  type BrokerageAccountContext,
  BrokerageProjectionError,
  type StoredProjection,
} from "../../src/domains/brokerage-projections/types.ts";
import { WebullTokenVault } from "../../../supabase/functions/_shared/webull/tokens.ts";
import { createResourceBoundWebullReadProvider } from "../../../supabase/functions/_shared/webull/reads.ts";

const now = new Date("2026-08-28T12:00:00Z");
const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const connectionId = "018f3c2a-4b67-7a89-8abc-123456789002";
const accountId = "018f3c2a-4b67-7a89-8abc-123456789003";
const context: BrokerageAccountContext = Object.freeze({
  userId,
  deletionEpoch: 4,
  connectionId,
  connectionStatus: "connected",
  accountId,
  accountStatus: "available",
  capabilityVersion: 7,
});

function generation(
  overrides: Partial<StoredProjection> = {},
): StoredProjection {
  return Object.freeze({
    id: "018f3c2a-4b67-7a89-8abc-123456789010",
    generation: 1,
    resource: "positions",
    payload: [{ asset: "ARGX", quantity: "1.000000000000000001" }],
    providerObservedAt: new Date("2026-08-28T11:59:58Z"),
    fetchedAt: new Date("2026-08-28T12:00:00Z"),
    expiresAt: new Date("2026-08-28T12:01:00Z"),
    availability: "available",
    reasonCode: null,
    ...overrides,
  });
}

function repositoryFixture(initial: StoredProjection | null) {
  let latest = initial;
  let leaseHeld = false;
  const repository = {
    listAccounts: vi.fn(async () => []),
    account: vi.fn(async () => context),
    latest: vi.fn(async () => latest),
    acquireRefreshLease: vi.fn(async () => {
      if (leaseHeld) return false;
      leaseHeld = true;
      return true;
    }),
    appendGeneration: vi.fn(async ({ projection }) => {
      latest = generation({
        generation: (latest?.generation ?? 0) + 1,
        resource: "positions",
        payload: projection.payload,
        providerObservedAt: projection.providerObservedAt,
        fetchedAt: projection.fetchedAt,
        expiresAt: projection.expiresAt,
        availability: projection.availability,
        reasonCode: projection.reasonCode ?? null,
      });
      return latest;
    }),
    releaseRefreshLease: vi.fn(async () => {
      leaseHeld = false;
    }),
    invalidateAccount: vi.fn(async () => undefined),
    requireReauthorization: vi.fn(async () => undefined),
  } as unknown as BrokerageProjectionRepository;
  return { repository, current: () => latest };
}

describe("versioned Webull read projection contract", () => {
  it("keeps fresh, empty, partial and stale generations semantically distinct", async () => {
    for (
      const [projection, expected] of [
        [generation(), "fresh"],
        [generation({ payload: [] }), "empty"],
        [
          generation({
            availability: "partial",
            reasonCode: "provider_partial",
          }),
          "partial",
        ],
      ] as const
    ) {
      const test = repositoryFixture(projection);
      const provider = { read: vi.fn() };
      const service = createBrokerageProjectionService({
        repository: test.repository,
        provider,
        now: () => now,
      });
      await expect(service.read(accountId, "positions")).resolves.toMatchObject(
        {
          state: expected,
          generation: 1,
          provider_observed_at: "2026-08-28T11:59:58.000Z",
        },
      );
      expect(provider.read).not.toHaveBeenCalled();
    }

    const expiredPartial = repositoryFixture(generation({
      availability: "partial",
      expiresAt: new Date("2026-08-28T11:59:00Z"),
    }));
    vi.mocked(expiredPartial.repository.acquireRefreshLease)
      .mockResolvedValueOnce(false);
    const expiredPartialService = createBrokerageProjectionService({
      repository: expiredPartial.repository,
      provider: { read: vi.fn() },
      now: () => now,
    });
    await expect(
      expiredPartialService.read(accountId, "positions"),
    ).resolves.toMatchObject({ state: "stale", reason: "refresh_in_progress" });

    const stale = repositoryFixture(generation({
      expiresAt: new Date("2026-08-28T11:59:00Z"),
    }));
    const service = createBrokerageProjectionService({
      repository: stale.repository,
      provider: {
        read: vi.fn(async () => {
          throw new BrokerageProjectionError("offline");
        }),
      },
      now: () => now,
    });
    await expect(service.read(accountId, "positions")).resolves.toMatchObject({
      state: "offline",
      generation: 1,
      data: [{ asset: "ARGX", quantity: "1.000000000000000001" }],
    });
  });

  it("returns rate limiting, disconnection and reauthorization without inventing freshness", async () => {
    const stale = generation({ expiresAt: new Date("2026-08-28T11:59:00Z") });
    const rateLimited = repositoryFixture(stale);
    const rateService = createBrokerageProjectionService({
      repository: rateLimited.repository,
      provider: {
        read: vi.fn(async () => {
          throw new BrokerageProjectionError("rate_limited");
        }),
      },
      now: () => now,
    });
    await expect(rateService.read(accountId, "positions")).resolves
      .toMatchObject({
        state: "rate_limited",
        reason: "rate_limited",
      });

    for (
      const [connectionStatus, state] of [
        ["disconnected", "disconnected"],
        ["reauthorization_required", "reauthorization_required"],
      ] as const
    ) {
      const test = repositoryFixture(stale);
      vi.mocked(test.repository.account).mockResolvedValueOnce({
        ...context,
        connectionStatus,
      });
      const provider = { read: vi.fn() };
      const service = createBrokerageProjectionService({
        repository: test.repository,
        provider,
        now: () => now,
      });
      await expect(service.read(accountId, "positions")).resolves.toMatchObject(
        { state },
      );
      expect(provider.read).not.toHaveBeenCalled();
    }
  });

  it("atomically replaces a whole resource generation without mixing rows", async () => {
    const test = repositoryFixture(generation({
      generation: 8,
      payload: [
        { symbol: "OLD-A", quantity: "1" },
        { symbol: "OLD-B", quantity: "2" },
      ],
      expiresAt: new Date("2026-08-28T11:59:00Z"),
    }));
    const provider = {
      read: vi.fn(async () => ({
        payload: [
          { symbol: "NEW-A", quantity: "3.000000000000000001" },
          { symbol: "NEW-C", quantity: "4" },
        ],
        providerObservedAt: new Date("2026-08-28T11:59:59Z"),
        fetchedAt: now,
        expiresAt: new Date("2026-08-28T12:01:00Z"),
        availability: "available" as const,
      })),
    };
    const service = createBrokerageProjectionService({
      repository: test.repository,
      provider,
      now: () => now,
    });
    const result = await service.read(accountId, "positions");
    expect(result.generation).toBe(9);
    expect(result.data).toEqual([
      { symbol: "NEW-A", quantity: "3.000000000000000001" },
      { symbol: "NEW-C", quantity: "4" },
    ]);
    expect(JSON.stringify(result.data)).not.toContain("OLD-");
    expect(test.current()?.generation).toBe(9);
  });

  it("rejects future or overlong provider authority windows and tolerates lease release outage", async () => {
    for (
      const returned of [
        {
          providerObservedAt: now,
          fetchedAt: new Date(now.getTime() + 31_000),
          expiresAt: new Date(now.getTime() + 60_000),
        },
        {
          providerObservedAt: now,
          fetchedAt: now,
          expiresAt: new Date(now.getTime() + 5 * 60_000 + 1),
        },
        {
          providerObservedAt: new Date(now.getTime() + 1),
          fetchedAt: now,
          expiresAt: new Date(now.getTime() + 60_000),
        },
      ]
    ) {
      const test = repositoryFixture(generation({
        expiresAt: new Date("2026-08-28T11:59:00Z"),
      }));
      const service = createBrokerageProjectionService({
        repository: test.repository,
        provider: {
          read: vi.fn(async () => ({
            payload: [],
            availability: "available" as const,
            ...returned,
          })),
        },
        now: () => now,
      });
      await expect(service.read(accountId, "positions")).resolves.toMatchObject(
        {
          state: "unavailable",
          reason: "provider_contract_unavailable",
        },
      );
      expect(test.repository.appendGeneration).not.toHaveBeenCalled();
    }

    const successful = repositoryFixture(generation({
      expiresAt: new Date("2026-08-28T11:59:00Z"),
    }));
    vi.mocked(successful.repository.releaseRefreshLease).mockRejectedValueOnce(
      new Error("synthetic lease storage outage"),
    );
    const service = createBrokerageProjectionService({
      repository: successful.repository,
      provider: {
        read: vi.fn(async () => ({
          payload: [],
          providerObservedAt: now,
          fetchedAt: now,
          expiresAt: new Date(now.getTime() + 60_000),
          availability: "available" as const,
        })),
      },
      now: () => now,
    });
    await expect(service.read(accountId, "positions")).resolves.toMatchObject({
      state: "empty",
      generation: 2,
    });
  });

  it("rejects raw provider identifiers before projection storage", async () => {
    const test = repositoryFixture(generation({
      expiresAt: new Date("2026-08-28T11:59:00Z"),
    }));
    const service = createBrokerageProjectionService({
      repository: test.repository,
      provider: {
        read: vi.fn(async () => ({
          payload: [{
            provider_asset_id: "must-remain-private",
            quantity: "1",
          }],
          providerObservedAt: now,
          fetchedAt: now,
          expiresAt: new Date(now.getTime() + 60_000),
          availability: "available" as const,
        })),
      },
      now: () => now,
    });
    await expect(service.read(accountId, "positions")).resolves.toMatchObject({
      state: "unavailable",
      reason: "provider_contract_unavailable",
    });
    expect(test.repository.appendGeneration).not.toHaveBeenCalled();
  });

  it("coalesces concurrent refreshes and fences a reconnect or deletion", async () => {
    const test = repositoryFixture(generation({
      expiresAt: new Date("2026-08-28T11:59:00Z"),
    }));
    let resolveProvider!: () => void;
    const blocked = new Promise<void>((resolve) => {
      resolveProvider = resolve;
    });
    const provider = {
      read: vi.fn(async () => {
        await blocked;
        return {
          payload: [],
          providerObservedAt: now,
          fetchedAt: now,
          expiresAt: new Date("2026-08-28T12:01:00Z"),
          availability: "available" as const,
        };
      }),
    };
    const service = createBrokerageProjectionService({
      repository: test.repository,
      provider,
      now: () => now,
    });
    const first = service.read(accountId, "positions");
    await vi.waitFor(() => expect(provider.read).toHaveBeenCalledOnce());
    const second = await service.read(accountId, "positions");
    expect(second).toMatchObject({
      state: "stale",
      reason: "refresh_in_progress",
    });
    resolveProvider();
    await expect(first).resolves.toMatchObject({
      state: "empty",
      generation: 2,
    });
    expect(provider.read).toHaveBeenCalledOnce();

    const fenced = repositoryFixture(generation({
      expiresAt: new Date("2026-08-28T11:59:00Z"),
    }));
    vi.mocked(fenced.repository.appendGeneration).mockRejectedValueOnce(
      new BrokerageProjectionError("refresh_fenced"),
    );
    const fencedService = createBrokerageProjectionService({
      repository: fenced.repository,
      provider: {
        read: vi.fn(async () => ({
          payload: [{ old_owner_value: true }],
          providerObservedAt: now,
          fetchedAt: now,
          expiresAt: new Date("2026-08-28T12:01:00Z"),
          availability: "available" as const,
        })),
      },
      now: () => now,
    });
    await expect(fencedService.read(accountId, "positions")).resolves.toEqual(
      expect.objectContaining({
        state: "unavailable",
        data: null,
        reason: "refresh_fenced",
      }),
    );
  });

  it("decrypts provider account identifiers only for the bound owner and resource", async () => {
    const vault = new WebullTokenVault("sandbox", {
      activeVersion: 1,
      keys: { 1: Buffer.alloc(32, 17).toString("base64") },
    });
    const ownership = {
      environment: "sandbox" as const,
      userId,
      connectionId,
      deletionEpoch: 4,
    };
    const sealed = await vault.protectProviderIdentifier(
      ownership,
      accountId,
      "synthetic-provider-account-0001",
    );
    await expect(
      vault.openProviderIdentifier(sealed, ownership, accountId, 1),
    ).resolves.toBe("synthetic-provider-account-0001");
    await expect(
      vault.openProviderIdentifier(
        sealed,
        ownership,
        "018f3c2a-4b67-7a89-8abc-123456789099",
        1,
      ),
    ).rejects.toThrow("webull_provider_identifier_owner_mismatch");
    await expect(
      vault.openProviderIdentifier(
        sealed,
        { ...ownership, deletionEpoch: 5 },
        accountId,
        1,
      ),
    ).rejects.toThrow("webull_provider_identifier_owner_mismatch");
    await expect(
      vault.openProviderIdentifier(
        sealed,
        { ...ownership, environment: "production" },
        accountId,
        1,
      ),
    ).rejects.toThrow("webull_provider_identifier_owner_mismatch");

    const transport = {
      read: vi.fn(async () => ({
        payload: [],
        providerObservedAt: now,
        fetchedAt: now,
        expiresAt: new Date(now.getTime() + 60_000),
        availability: "available" as const,
      })),
    };
    const provider = createResourceBoundWebullReadProvider({
      environment: "sandbox",
      vault,
      mappings: {
        get: vi.fn(async () => ({
          accountId: "018f3c2a-4b67-7a89-8abc-123456789099",
          connectionId,
          userId,
          deletionEpoch: 4,
          environment: "sandbox" as const,
          providerAccountIdCiphertext: sealed,
          keyVersion: 1,
        })),
      },
      transport,
    });
    await expect(provider.read({ context, resource: "positions" })).rejects
      .toThrow(
        "provider_contract_unavailable",
      );
    expect(transport.read).not.toHaveBeenCalled();

    const instrumentId = "018f3c2a-4b67-7a89-8abc-123456789040";
    const sealedAsset = await vault.protectProviderAssetIdentifier(
      ownership,
      accountId,
      instrumentId,
      "synthetic-private-provider-asset-0001",
    );
    await expect(
      vault.openProviderAssetIdentifier(
        sealedAsset,
        ownership,
        accountId,
        instrumentId,
        1,
      ),
    ).resolves.toBe("synthetic-private-provider-asset-0001");
    await expect(
      vault.openProviderAssetIdentifier(
        sealedAsset,
        ownership,
        accountId,
        "018f3c2a-4b67-7a89-8abc-123456789041",
        1,
      ),
    ).rejects.toThrow("webull_provider_asset_owner_mismatch");
  });
});

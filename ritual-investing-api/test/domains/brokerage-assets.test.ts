import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { vi } from "vitest";

import {
  canonicalDecimal,
  normalizeBalance,
  normalizePosition,
} from "../../src/domains/brokerage-assets/normalization.ts";
import type { BrokerageAssetMappingRepository } from "../../src/domains/brokerage-assets/repository.ts";
import { createWebullAssetMapper } from "../../../supabase/functions/_shared/webull/asset-mappings.ts";
import { WebullTokenVault } from "../../../supabase/functions/_shared/webull/tokens.ts";

const fixture = JSON.parse(
  await readFile(
    resolve(
      dirname(fileURLToPath(import.meta.url)),
      "../fixtures/webull/reads.v1.json",
    ),
    "utf8",
  ),
) as Record<string, unknown>;
const instrumentId = "018f3c2a-4b67-7a89-8abc-123456789050";
const mapProviderAssetId = (_providerAssetId: string) => instrumentId;

describe("brokerage asset normalization", () => {
  it("round-trips money and quantities without binary floating-point conversion", () => {
    const balance = normalizeBalance(fixture.balances);
    expect(balance.cash).toBe("9007199254740993.1234");
    expect(balance.buying_power).toBe("10000000000000000.000001");
    expect(balance.market_value).toBe("0.000000000000000001");
    expect(balance.total_equity).toBe("19007199254740993.123401");

    const first = normalizePosition(
      (fixture.positions as unknown[])[0],
      mapProviderAssetId,
    );
    expect(first.quantity).toBe("9007199254740993.00000001");
    expect(first.available_quantity).toBe("9007199254740992.99999999");
    expect(first.average_cost).toBe("123.45");
  });

  it("preserves unsupported assets without enabling them", () => {
    const unknown = normalizePosition(
      (fixture.positions as unknown[])[1],
      mapProviderAssetId,
    );
    expect(unknown.asset).toMatchObject({
      asset_kind: "unsupported",
      provider_asset_kind: "FUTURE_PROVIDER_ASSET",
      supported: false,
      instrument_id: instrumentId,
    });
    expect(JSON.stringify(unknown)).not.toContain("synthetic-asset-future");
  });

  it("rejects exponent notation, unsafe scale and Number inputs", () => {
    expect(() => canonicalDecimal("1e6")).toThrow("invalid_provider_decimal");
    expect(() => canonicalDecimal(0.1)).toThrow("invalid_provider_decimal");
    expect(() => canonicalDecimal(`0.${"1".repeat(19)}`)).toThrow(
      "provider_decimal_out_of_range",
    );
  });

  it("rejects control and bidirectional override characters in asset display text", () => {
    const position = structuredClone((fixture.positions as unknown[])[0]) as {
      asset: Record<string, unknown>;
    };
    position.asset.name = "Synthetic\u202eEquity";
    expect(() => normalizePosition(position, mapProviderAssetId)).toThrow(
      "invalid_provider_asset",
    );
  });

  it("atomically converges concurrent provider IDs on one private opaque instrument", async () => {
    const persisted = new Map<string, {
      instrumentId: string;
      ciphertext: Uint8Array;
      keyVersion: number;
      assetKind: "equity" | "etf" | "unsupported";
      providerAssetKind: string;
    }>();
    const repository: BrokerageAssetMappingRepository = {
      resolve: vi.fn(async (mapping) => {
        let winner = persisted.get(mapping.providerAssetIdHash);
        if (winner === undefined) {
          winner = {
            instrumentId: mapping.candidateInstrumentId,
            ciphertext: mapping.providerAssetIdCiphertext,
            keyVersion: mapping.keyVersion,
            assetKind: mapping.assetKind,
            providerAssetKind: mapping.providerAssetKind,
          };
          persisted.set(mapping.providerAssetIdHash, winner);
        }
        return {
          instrumentId: winner.instrumentId,
          keyVersion: winner.keyVersion,
        };
      }),
    };
    const vault = new WebullTokenVault("sandbox", {
      activeVersion: 3,
      keys: { 3: Buffer.alloc(32, 23).toString("base64") },
    });
    const mapper = createWebullAssetMapper({
      environment: "sandbox",
      pepper: "synthetic-private-asset-pepper-000001",
      vault,
      repository,
    });
    const context = {
      userId: "018f3c2a-4b67-7a89-8abc-123456789001",
      deletionEpoch: 4,
      connectionId: "018f3c2a-4b67-7a89-8abc-123456789002",
      connectionStatus: "connected" as const,
      accountId: "018f3c2a-4b67-7a89-8abc-123456789003",
      accountStatus: "available" as const,
      capabilityVersion: 7,
    };
    const position = (fixture.positions as unknown[])[0]!;
    const [left, right] = await Promise.all([
      mapper.normalizePositions(context, [position]),
      mapper.normalizePositions(context, [position]),
    ]);
    expect(left[0]?.asset.instrument_id).toBe(right[0]?.asset.instrument_id);
    expect(JSON.stringify(left)).not.toContain("synthetic-asset-1");
    const winner = [...persisted.values()][0]!;
    expect(winner.keyVersion).toBe(3);
    expect(winner).toMatchObject({
      assetKind: "equity",
      providerAssetKind: "EQUITY",
    });
    await expect(vault.openProviderAssetIdentifier(
      winner.ciphertext,
      {
        environment: "sandbox",
        userId: context.userId,
        connectionId: context.connectionId,
        deletionEpoch: context.deletionEpoch,
      },
      context.accountId,
      winner.instrumentId,
      winner.keyVersion,
    )).resolves.toBe("synthetic-asset-1");
  });
});

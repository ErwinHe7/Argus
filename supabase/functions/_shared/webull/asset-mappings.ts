import {
  normalizeAssetKind,
  type NormalizedPosition,
  normalizedProviderCode,
  normalizePosition,
} from "../../../../ritual-investing-api/src/domains/brokerage-assets/normalization.ts";
import type {
  BrokerageAssetMappingRepository,
} from "../../../../ritual-investing-api/src/domains/brokerage-assets/repository.ts";
import type {
  BrokerageAccountContext,
} from "../../../../ritual-investing-api/src/domains/brokerage-projections/types.ts";
import { WebullTokenVault } from "./tokens.ts";

async function hmacHex(keyValue: string, value: string): Promise<string> {
  if (!/^[\x21-\x7e]{32,512}$/.test(keyValue)) {
    throw new Error("invalid_webull_asset_mapping_pepper");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(keyValue),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const bytes = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value)),
  );
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function rawProviderAssetId(position: unknown): string {
  if (
    typeof position !== "object" ||
    position === null ||
    Array.isArray(position) ||
    typeof (position as Record<string, unknown>).asset !== "object" ||
    (position as Record<string, unknown>).asset === null
  ) {
    throw new Error("invalid_webull_provider_position");
  }
  return normalizedProviderCode(
    ((position as Record<string, unknown>).asset as Record<string, unknown>)
      .provider_asset_id,
  );
}

function rawProviderAssetKind(position: unknown): ReturnType<
  typeof normalizeAssetKind
> {
  return normalizeAssetKind(
    ((position as Record<string, unknown>).asset as Record<string, unknown>)
      .asset_kind,
  );
}

export function createWebullAssetMapper(
  input: Readonly<{
    environment: "sandbox" | "production";
    pepper: string;
    vault: WebullTokenVault;
    repository: BrokerageAssetMappingRepository;
  }>,
) {
  const instrumentId = async (
    context: BrokerageAccountContext,
    providerAssetId: string,
    kind: ReturnType<typeof normalizeAssetKind>,
  ): Promise<string> => {
    normalizedProviderCode(providerAssetId);
    const hash = await hmacHex(
      input.pepper,
      [
        "argus-webull-asset-map-v1",
        input.environment,
        context.userId,
        context.connectionId,
        context.accountId,
        String(context.deletionEpoch),
        providerAssetId,
      ].join("\u001f"),
    );
    const candidateInstrumentId = crypto.randomUUID();
    const ciphertext = await input.vault.protectProviderAssetIdentifier(
      {
        environment: input.environment,
        userId: context.userId,
        connectionId: context.connectionId,
        deletionEpoch: context.deletionEpoch,
      },
      context.accountId,
      candidateInstrumentId,
      providerAssetId,
    );
    return (await input.repository.resolve({
      context,
      environment: input.environment,
      providerAssetIdHash: hash,
      candidateInstrumentId,
      providerAssetIdCiphertext: ciphertext,
      keyVersion: input.vault.activeKeyVersion,
      assetKind: kind.asset_kind,
      providerAssetKind: kind.provider_asset_kind,
    })).instrumentId;
  };

  return Object.freeze({
    instrumentId,
    normalizePositions: async (
      context: BrokerageAccountContext,
      positions: readonly unknown[],
    ): Promise<readonly NormalizedPosition[]> => {
      if (positions.length > 10_000) {
        throw new Error("invalid_webull_position_count");
      }
      const providerKinds = new Map<
        string,
        ReturnType<typeof normalizeAssetKind>
      >();
      for (const position of positions) {
        const providerId = rawProviderAssetId(position);
        const kind = rawProviderAssetKind(position);
        const previous = providerKinds.get(providerId);
        if (
          previous !== undefined &&
          (previous.asset_kind !== kind.asset_kind ||
            previous.provider_asset_kind !== kind.provider_asset_kind)
        ) {
          throw new Error("inconsistent_webull_asset_kind");
        }
        providerKinds.set(providerId, kind);
      }
      const providerIds = [...providerKinds.keys()];
      const mapped = new Map(
        await Promise.all(providerIds.map(async (providerId) =>
          [
            providerId,
            await instrumentId(
              context,
              providerId,
              providerKinds.get(providerId)!,
            ),
          ] as const
        )),
      );
      return Object.freeze(
        positions.map((position) =>
          normalizePosition(position, (providerId) => {
            const id = mapped.get(providerId);
            if (id === undefined) {
              throw new Error("missing_webull_asset_mapping");
            }
            return id;
          })
        ),
      );
    },
  });
}

export type WebullAssetMapper = ReturnType<typeof createWebullAssetMapper>;

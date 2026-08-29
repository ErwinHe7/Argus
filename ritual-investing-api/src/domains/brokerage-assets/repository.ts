import type { DatabasePool } from "../../db/database-port.ts";
import type { VerifiedRequestClaims } from "../../db/request-context.ts";
import { withMemberRequestTransaction } from "../../db/request-transaction.ts";
import type { BrokerageAccountContext } from "../brokerage-projections/types.ts";
import { BrokerageProjectionError } from "../brokerage-projections/types.ts";

export type PersistedWebullAssetMapping = Readonly<{
  instrumentId: string;
  keyVersion: number;
}>;

export interface BrokerageAssetMappingRepository {
  resolve(
    input: Readonly<{
      context: BrokerageAccountContext;
      environment: "sandbox" | "production";
      providerAssetIdHash: string;
      candidateInstrumentId: string;
      providerAssetIdCiphertext: Uint8Array;
      keyVersion: number;
      assetKind: "equity" | "etf" | "unsupported";
      providerAssetKind: string;
    }>,
  ): Promise<PersistedWebullAssetMapping>;
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function createBrokerageAssetMappingRepository(
  input: Readonly<{
    pool: DatabasePool;
    claims: VerifiedRequestClaims;
  }>,
): BrokerageAssetMappingRepository {
  const repository: BrokerageAssetMappingRepository = {
    resolve: async (mapping) => {
      if (
        mapping.context.userId !== input.claims.userId ||
        !uuidPattern.test(mapping.context.accountId) ||
        !uuidPattern.test(mapping.context.connectionId) ||
        !uuidPattern.test(mapping.candidateInstrumentId) ||
        !/^[a-f0-9]{64}$/.test(mapping.providerAssetIdHash) ||
        !["equity", "etf", "unsupported"].includes(mapping.assetKind) ||
        !/^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$/.test(
          mapping.providerAssetKind,
        ) ||
        !Number.isSafeInteger(mapping.keyVersion) ||
        mapping.keyVersion < 1
      ) {
        throw new BrokerageProjectionError("provider_contract_unavailable");
      }
      return withMemberRequestTransaction(
        { pool: input.pool, verifiedClaims: input.claims },
        async (database) => {
          const result = await database.query<{
            result_instrument_id: string;
            result_key_version: number | string;
          }>(
            `select * from argus_private.resolve_webull_asset_mapping_scoped(
               $1,$6,$7,$8,$2,$3,$4,$5,$9,$10
             )`,
            [
              mapping.candidateInstrumentId,
              mapping.environment,
              mapping.providerAssetIdCiphertext,
              mapping.providerAssetIdHash,
              mapping.keyVersion,
              mapping.context.accountId,
              mapping.context.connectionId,
              mapping.context.deletionEpoch,
              mapping.assetKind,
              mapping.providerAssetKind,
            ],
          );
          const row = result.rows[0];
          const keyVersion = typeof row?.result_key_version === "string" &&
              /^\d+$/.test(row.result_key_version)
            ? Number(row.result_key_version)
            : row?.result_key_version;
          if (
            row === undefined ||
            !uuidPattern.test(row.result_instrument_id) ||
            !Number.isSafeInteger(keyVersion) ||
            Number(keyVersion) < 1
          ) {
            // An empty result means account ownership, deletion epoch, live
            // connection, or provider environment changed while resolving.
            throw new BrokerageProjectionError("refresh_fenced");
          }
          return Object.freeze({
            instrumentId: row.result_instrument_id,
            keyVersion: Number(keyVersion),
          });
        },
      );
    },
  };
  return Object.freeze(repository);
}

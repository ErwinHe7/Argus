import type { DatabasePool } from "../../db/database-port.ts";
import type { VerifiedRequestClaims } from "../../db/request-context.ts";
import { withRequestTransaction } from "../../db/request-transaction.ts";
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
        !Number.isSafeInteger(mapping.keyVersion) ||
        mapping.keyVersion < 1
      ) {
        throw new BrokerageProjectionError("provider_contract_unavailable");
      }
      return withRequestTransaction(
        { pool: input.pool, verifiedClaims: input.claims },
        async (database) => {
          await database.query(
            `insert into argus_private.webull_asset_mappings(
               instrument_id,account_id,connection_id,user_id,deletion_epoch,
               provider_environment,provider_asset_id_ciphertext,
               provider_asset_id_hash,key_version
             ) select $1,account.id,account.connection_id,account.user_id,
                      account.deletion_epoch,$2,$3,$4,$5
                 from argus_brokerage.accounts account
                 join argus_brokerage.connections connection
                   on connection.id=account.connection_id
                  and connection.user_id=account.user_id
                  and connection.deletion_epoch=account.deletion_epoch
                where account.id=$6 and account.user_id=auth.uid()
                  and account.connection_id=$7
                  and account.deletion_epoch=$8
                  and connection.status='connected'
             on conflict (user_id,account_id,provider_asset_id_hash)
             do nothing`,
            [
              mapping.candidateInstrumentId,
              mapping.environment,
              mapping.providerAssetIdCiphertext,
              mapping.providerAssetIdHash,
              mapping.keyVersion,
              mapping.context.accountId,
              mapping.context.connectionId,
              mapping.context.deletionEpoch,
            ],
          );
          const result = await database.query<{
            instrument_id: string;
            key_version: number | string;
          }>(
            `select instrument_id,key_version
               from argus_private.webull_asset_mappings
              where user_id=auth.uid() and account_id=$1
                and connection_id=$2 and deletion_epoch=$3
                and provider_environment=$4 and provider_asset_id_hash=$5`,
            [
              mapping.context.accountId,
              mapping.context.connectionId,
              mapping.context.deletionEpoch,
              mapping.environment,
              mapping.providerAssetIdHash,
            ],
          );
          const row = result.rows[0];
          const keyVersion = typeof row?.key_version === "string" &&
              /^\d+$/.test(row.key_version)
            ? Number(row.key_version)
            : row?.key_version;
          if (
            row === undefined ||
            !uuidPattern.test(row.instrument_id) ||
            !Number.isSafeInteger(keyVersion) ||
            Number(keyVersion) < 1
          ) {
            // An empty result means account ownership, deletion epoch, live
            // connection, or provider environment changed while resolving.
            throw new BrokerageProjectionError("refresh_fenced");
          }
          return Object.freeze({
            instrumentId: row.instrument_id,
            keyVersion: Number(keyVersion),
          });
        },
      );
    },
  };
  return Object.freeze(repository);
}

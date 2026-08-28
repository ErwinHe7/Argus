import type { DatabasePool } from "../../db/database-port.ts";
import type { VerifiedRequestClaims } from "../../db/request-context.ts";
import { withRequestTransaction } from "../../db/request-transaction.ts";
import {
  type BrokerageAccountContext,
  BrokerageProjectionError,
} from "../brokerage-projections/types.ts";

export type ProtectedWebullAccountMapping = Readonly<{
  accountId: string;
  connectionId: string;
  userId: string;
  deletionEpoch: number;
  environment: "sandbox" | "production";
  providerAccountIdCiphertext: Uint8Array;
  keyVersion: number;
}>;

export interface WebullAccountMappingStore {
  get(context: BrokerageAccountContext): Promise<ProtectedWebullAccountMapping>;
}

function safeInteger(value: unknown, field: string, minimum = 0): number {
  const parsed = typeof value === "string" && /^\d+$/.test(value)
    ? Number(value)
    : value;
  if (!Number.isSafeInteger(parsed) || Number(parsed) < minimum) {
    throw new Error(`invalid_${field}`);
  }
  return Number(parsed);
}

export function createWebullAccountMappingStore(
  input: Readonly<{
    pool: DatabasePool;
    claims: VerifiedRequestClaims;
  }>,
): WebullAccountMappingStore {
  const store: WebullAccountMappingStore = {
    get: (context) =>
      withRequestTransaction(
        { pool: input.pool, verifiedClaims: input.claims },
        async (database) => {
          if (
            context.userId !== input.claims.userId ||
            context.connectionStatus !== "connected"
          ) {
            throw new BrokerageProjectionError("account_not_found");
          }
          const result = await database.query<{
            account_id: string;
            connection_id: string;
            user_id: string;
            deletion_epoch: number | string;
            provider_environment: "sandbox" | "production";
            provider_account_id_ciphertext: Uint8Array;
            key_version: number | string;
          }>(
            `select mapping.account_id,mapping.connection_id,mapping.user_id,
                    mapping.deletion_epoch,mapping.provider_environment,
                    mapping.provider_account_id_ciphertext,mapping.key_version
               from argus_private.webull_account_mappings mapping
               join argus_brokerage.accounts account
                 on account.id=mapping.account_id
                and account.user_id=mapping.user_id
                and account.connection_id=mapping.connection_id
                and account.deletion_epoch=mapping.deletion_epoch
               join argus_brokerage.connections connection
                 on connection.id=account.connection_id
                and connection.user_id=account.user_id
                and connection.deletion_epoch=account.deletion_epoch
              where mapping.account_id=$1 and mapping.user_id=auth.uid()
                and mapping.connection_id=$2 and mapping.deletion_epoch=$3
                and connection.status='connected'`,
            [context.accountId, context.connectionId, context.deletionEpoch],
          );
          const row = result.rows[0];
          if (
            row === undefined ||
            !(row.provider_account_id_ciphertext instanceof Uint8Array) ||
            !["sandbox", "production"].includes(row.provider_environment)
          ) {
            throw new BrokerageProjectionError("account_not_found");
          }
          return Object.freeze({
            accountId: row.account_id,
            connectionId: row.connection_id,
            userId: row.user_id,
            deletionEpoch: safeInteger(row.deletion_epoch, "deletion_epoch"),
            environment: row.provider_environment,
            providerAccountIdCiphertext: row.provider_account_id_ciphertext,
            keyVersion: safeInteger(row.key_version, "key_version", 1),
          });
        },
      ),
  };
  return Object.freeze(store);
}

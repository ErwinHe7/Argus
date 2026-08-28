import type { DatabasePool } from "../../db/database-port.ts";
import { withDatabaseTransaction } from "../../db/database-port.ts";
import type { VerifiedRequestClaims } from "../../db/request-context.ts";
import { withRequestTransaction } from "../../db/request-transaction.ts";

const stateLifetimeMilliseconds = 5 * 60 * 1_000;
const completionLifetimeMilliseconds = 5 * 60 * 1_000;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type WebullReturnTarget = "webull_https" | "webull_native";

export interface WebullAuthorizationStarter {
  readonly contractVersion: string;
  readonly environment: "sandbox" | "production";
  authorizationUrl(state: string): URL;
}

export class BrokerageConnectionError extends Error {
  readonly code:
    | "connection_not_found"
    | "connection_already_connected"
    | "account_not_available"
    | "step_up_required"
    | "completion_not_found";

  constructor(code: BrokerageConnectionError["code"]) {
    super(code);
    this.name = "BrokerageConnectionError";
    this.code = code;
  }
}

async function hash(value: string): Promise<string> {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function randomOpaqueValue(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

export type BrokerageConnectionRepository = ReturnType<
  typeof createBrokerageConnectionRepository
>;

export function createBrokerageConnectionRepository(
  input: Readonly<{
    pool: DatabasePool;
    claims: VerifiedRequestClaims;
    authorization: WebullAuthorizationStarter;
    now?: () => Date;
  }>,
) {
  const now = input.now ?? (() => new Date());

  const start = async (
    returnTarget: WebullReturnTarget,
    reconnect: boolean,
  ) => {
    const state = randomOpaqueValue();
    // The provider gate executes before a pending connection is persisted. A
    // blocked/unconfirmed contract therefore leaves no unusable OAuth state.
    const authorizationUrl = input.authorization.authorizationUrl(state);
    const stateHash = await hash(state);
    const startedAt = now();
    const expiresAt = new Date(startedAt.getTime() + stateLifetimeMilliseconds);
    const connectionId = await withRequestTransaction(
      { pool: input.pool, verifiedClaims: input.claims },
      async (database) => {
        const member = await database.query<{
          deletion_epoch: number;
        }>(
          `select deletion_epoch from argus_app.members
            where user_id = auth.uid() and status = 'active' for update`,
        );
        const deletionEpoch = member.rows[0]?.deletion_epoch;
        if (deletionEpoch === undefined) {
          throw new BrokerageConnectionError("connection_not_found");
        }
        const existing = await database.query<{ id: string; status: string }>(
          `select id,status from argus_brokerage.connections
            where user_id = auth.uid()
              and status not in ('denied','failed','disconnected')
            order by created_at desc limit 1 for update`,
        );
        let connectionId = existing.rows[0]?.id;
        if (existing.rows[0]?.status === "connected" && !reconnect) {
          throw new BrokerageConnectionError("connection_already_connected");
        }
        if (connectionId === undefined) {
          connectionId = crypto.randomUUID();
          await database.query(
            `insert into argus_brokerage.connections(
               id,user_id,deletion_epoch,status
             ) values ($1,auth.uid(),$2,'pending')`,
            [connectionId, deletionEpoch],
          );
        } else {
          if (reconnect) {
            await database.query(
              `delete from argus_brokerage.accounts
                where user_id=auth.uid() and connection_id=$1`,
              [connectionId],
            );
            await database.query(
              `delete from argus_private.webull_credentials
                where user_id=auth.uid() and connection_id=$1`,
              [connectionId],
            );
            await database.query(
              `delete from argus_private.refresh_leases
                where user_id=auth.uid() and connection_id=$1`,
              [connectionId],
            );
          }
          await database.query(
            `update argus_brokerage.connections
                set status='pending',last_error_code=null,updated_at=$2
              where id=$1 and user_id=auth.uid()`,
            [connectionId, startedAt],
          );
        }
        await database.query(
          `update argus_private.oauth_states set consumed_at=$1
            where user_id=auth.uid() and consumed_at is null`,
          [startedAt],
        );
        await database.query(
          `insert into argus_private.oauth_states(
             id,user_id,session_id,deletion_epoch,connection_id,state_hash,
             return_target,contract_version,provider_environment,expires_at
           ) values ($1,auth.uid(),$2,$3,$4,$5,$6,$7,$8,$9)`,
          [
            crypto.randomUUID(),
            input.claims.sessionId,
            deletionEpoch,
            connectionId,
            stateHash,
            returnTarget,
            input.authorization.contractVersion,
            input.authorization.environment,
            expiresAt,
          ],
        );
        return connectionId;
      },
    );
    return Object.freeze({
      connection_id: connectionId,
      authorization_url: authorizationUrl.toString(),
      expires_at: expiresAt.toISOString(),
    });
  };

  return Object.freeze({
    issueStepUp: async (action: "webull_disconnect" | "argus_delete") => {
      const receipt = randomOpaqueValue();
      const receiptHash = await hash(receipt);
      const expiresAt = new Date(now().getTime() + 5 * 60 * 1_000);
      await withRequestTransaction(
        { pool: input.pool, verifiedClaims: input.claims },
        async (database) => {
          const inserted = await database.query(
            `insert into argus_private.step_up_receipts(
               user_id,session_id,deletion_epoch,action,receipt_hash,aal,expires_at
             ) select auth.uid(),$1,member.deletion_epoch,$2,$3,$4,$5
                 from argus_app.members member
                where member.user_id=auth.uid() and member.status='active'
             returning id`,
            [
              input.claims.sessionId,
              action,
              receiptHash,
              input.claims.aal,
              expiresAt,
            ],
          );
          if (inserted.rows.length !== 1) {
            throw new BrokerageConnectionError("step_up_required");
          }
        },
      );
      return Object.freeze({
        receipt,
        action,
        user_id: input.claims.userId,
        session_id: input.claims.sessionId,
        expires_at: expiresAt.toISOString(),
      });
    },
    start: (returnTarget: WebullReturnTarget) => start(returnTarget, false),
    reconnect: (returnTarget: WebullReturnTarget) => start(returnTarget, true),
    status: () =>
      withRequestTransaction(
        { pool: input.pool, verifiedClaims: input.claims },
        async (database) => {
          const result = await database.query<Record<string, unknown>>(
            `select connection.id,connection.status,
                    connection.capability_version,connection.authorized_at,
                    connection.disconnected_at,connection.last_error_code,
                    connection.updated_at,
                    coalesce(jsonb_agg(jsonb_build_object(
                      'id',account.id,
                      'display_label',account.display_label,
                      'base_currency',account.base_currency,
                      'status',account.status,
                      'capability_version',account.capability_version,
                      'fetched_at',account.fetched_at,
                      'expires_at',account.expires_at,
                      'selected',selection.account_id is not null
                    ) order by account.display_label)
                    filter (where account.id is not null),'[]'::jsonb) accounts
               from argus_brokerage.connections connection
               left join argus_brokerage.accounts account
                 on account.connection_id=connection.id
                and account.user_id=connection.user_id
               left join argus_brokerage.active_account_selections selection
                 on selection.user_id=connection.user_id
                and selection.account_id=account.id
              where connection.user_id=auth.uid()
              group by connection.id
              order by connection.created_at desc limit 1`,
          );
          return result.rows[0] ?? {
            status: "disconnected",
            accounts: [],
          };
        },
      ),
    selectAccount: (accountId: string) => {
      if (!uuidPattern.test(accountId)) {
        throw new BrokerageConnectionError("account_not_available");
      }
      return withRequestTransaction(
        { pool: input.pool, verifiedClaims: input.claims },
        async (database) => {
          const result = await database.query<{ connection_id: string }>(
            `select account.connection_id
               from argus_brokerage.accounts account
               join argus_brokerage.connections connection
                 on connection.id=account.connection_id
                and connection.user_id=account.user_id
              where account.id=$1 and account.user_id=auth.uid()
                and account.status='available' and connection.status='connected'`,
            [accountId],
          );
          const connectionId = result.rows[0]?.connection_id;
          if (connectionId === undefined) {
            throw new BrokerageConnectionError("account_not_available");
          }
          await database.query(
            `insert into argus_brokerage.active_account_selections(
               user_id,deletion_epoch,connection_id,account_id
             ) select auth.uid(),member.deletion_epoch,$1,$2
                 from argus_app.members member
                where member.user_id=auth.uid() and member.status='active'
             on conflict (user_id) do update
               set deletion_epoch=excluded.deletion_epoch,
                   connection_id=excluded.connection_id,
                   account_id=excluded.account_id,
                   selected_at=now()`,
            [connectionId, accountId],
          );
          return Object.freeze({ account_id: accountId, selected: true });
        },
      );
    },
    redeemCompletion: async (handle: string) => {
      if (!/^[A-Za-z0-9_-]{43,128}$/.test(handle)) {
        throw new BrokerageConnectionError("completion_not_found");
      }
      const handleHash = await hash(handle);
      return withRequestTransaction(
        { pool: input.pool, verifiedClaims: input.claims },
        async (database) => {
          const result = await database.query<Record<string, unknown>>(
            `update argus_private.webull_completion_handles completion
                set consumed_at=now()
              where completion.handle_hash=$1
                and completion.user_id=auth.uid()
                and completion.session_id=$2
                and completion.consumed_at is null
                and completion.expires_at > now()
              returning connection_id,outcome,created_at`,
            [handleHash, input.claims.sessionId],
          );
          const completion = result.rows[0];
          if (completion === undefined) {
            throw new BrokerageConnectionError("completion_not_found");
          }
          return completion;
        },
      );
    },
    disconnect: async (receipt: string) => {
      if (!/^[A-Za-z0-9_-]{32,512}$/.test(receipt)) {
        throw new BrokerageConnectionError("step_up_required");
      }
      const receiptHash = await hash(receipt);
      return withRequestTransaction(
        { pool: input.pool, verifiedClaims: input.claims },
        async (database) => {
          const consumed = await database.query<{ id: string }>(
            `update argus_private.step_up_receipts receipt
                set consumed_at=now()
              where receipt.receipt_hash=$1
                and receipt.user_id=auth.uid()
                and receipt.session_id=$2
                and receipt.action='webull_disconnect'
                and receipt.consumed_at is null
                and receipt.expires_at > now()
              returning id`,
            [receiptHash, input.claims.sessionId],
          );
          if (consumed.rows.length !== 1) {
            throw new BrokerageConnectionError("step_up_required");
          }
          const connection = await database.query<{ id: string }>(
            `select id from argus_brokerage.connections
              where user_id=auth.uid() and status <> 'disconnected'
              order by created_at desc limit 1 for update`,
          );
          const connectionId = connection.rows[0]?.id;
          if (connectionId === undefined) {
            throw new BrokerageConnectionError("connection_not_found");
          }
          await database.query(
            `delete from argus_brokerage.accounts
              where user_id=auth.uid() and connection_id=$1`,
            [connectionId],
          );
          await database.query(
            `delete from argus_private.webull_credentials
              where user_id=auth.uid() and connection_id=$1`,
            [connectionId],
          );
          await database.query(
            `delete from argus_private.refresh_leases
              where user_id=auth.uid() and connection_id=$1`,
            [connectionId],
          );
          await database.query(
            `delete from argus_private.oauth_states
              where user_id=auth.uid() and connection_id=$1`,
            [connectionId],
          );
          await database.query(
            `delete from argus_private.webull_completion_handles
              where user_id=auth.uid() and connection_id=$1`,
            [connectionId],
          );
          await database.query(
            `update argus_brokerage.connections
                set status='disconnected',disconnected_at=now(),
                    last_error_code=null,updated_at=now()
              where id=$1 and user_id=auth.uid()`,
            [connectionId],
          );
          return Object.freeze({
            connection_id: connectionId,
            status: "disconnected",
            provider_grant_revoked: false,
          });
        },
      );
    },
  });
}

export type ConsumedWebullState = Readonly<{
  stateId: string;
  userId: string;
  sessionId: string;
  deletionEpoch: number;
  connectionId: string;
  returnTarget: WebullReturnTarget;
  contractVersion: string;
  environment: "sandbox" | "production";
}>;

export type ProtectedCallbackCredentials = Readonly<{
  environment: "sandbox" | "production";
  userId: string;
  connectionId: string;
  deletionEpoch: number;
  tokenVersion: number;
  keyVersion: number;
  accessCiphertext: Uint8Array;
  accessNonce: Uint8Array;
  accessTag: Uint8Array;
  refreshCiphertext: Uint8Array;
  refreshNonce: Uint8Array;
  refreshTag: Uint8Array;
  wrappedDataKey: Uint8Array;
  wrappedKeyNonce: Uint8Array;
  wrappedKeyTag: Uint8Array;
  associatedDataHash: string;
  accessExpiresAt: Date;
  refreshExpiresAt: Date;
}>;

export type ProtectedCallbackAccount = Readonly<{
  id: string;
  displayLabel: string;
  baseCurrency: string;
  status: "available" | "restricted" | "closed" | "unavailable";
  capabilityVersion: number;
  providerIdCiphertext: Uint8Array;
  providerIdHash: string;
  keyVersion: number;
  userId: string;
  connectionId: string;
  deletionEpoch: number;
}>;

export function createWebullCallbackRepository(pool: DatabasePool) {
  return Object.freeze({
    consumeState: async (stateHash: string, consumedAt: Date) => {
      return withDatabaseTransaction(
        pool,
        "argus_runtime",
        async (database) => {
          const result = await database.query<{
            state_id: string;
            user_id: string;
            session_id: string;
            deletion_epoch: number;
            connection_id: string;
            return_target: WebullReturnTarget;
            contract_version: string;
            provider_environment: "sandbox" | "production";
          }>(
            `select * from argus_private.consume_webull_oauth_state($1,$2)`,
            [stateHash, consumedAt],
          );
          const row = result.rows[0];
          if (row === undefined) return null;
          return Object.freeze({
            stateId: row.state_id,
            userId: row.user_id,
            sessionId: row.session_id,
            deletionEpoch: row.deletion_epoch,
            connectionId: row.connection_id,
            returnTarget: row.return_target,
            contractVersion: row.contract_version,
            environment: row.provider_environment,
          });
        },
      );
    },
    complete: (
      state: ConsumedWebullState,
      credentials: ProtectedCallbackCredentials,
      accounts: readonly ProtectedCallbackAccount[],
      handleHash: string,
      expiresAt: Date,
    ) =>
      withRequestTransaction(
        {
          pool,
          verifiedClaims: {
            userId: state.userId,
            sessionId: state.sessionId,
            aal: "aal1",
          },
        },
        async (database) => {
          if (
            credentials.userId !== state.userId ||
            credentials.connectionId !== state.connectionId ||
            credentials.deletionEpoch !== state.deletionEpoch ||
            credentials.environment !== state.environment ||
            credentials.tokenVersion !== 1 ||
            accounts.some((account) =>
              account.userId !== state.userId ||
              account.connectionId !== state.connectionId ||
              account.deletionEpoch !== state.deletionEpoch ||
              account.keyVersion !== credentials.keyVersion
            )
          ) {
            throw new Error("webull_callback_envelope_owner_mismatch");
          }
          const valid = await database.query<{ id: string }>(
            `select state.id from argus_private.oauth_states state
              join argus_app.members member on member.user_id=state.user_id
              join argus_brokerage.connections connection
                on connection.id=state.connection_id
               and connection.user_id=state.user_id
             where state.id=$1 and state.user_id=auth.uid()
               and state.session_id=$2 and state.connection_id=$3
               and state.deletion_epoch=$4 and state.consumed_at is not null
               and member.status='active'
               and member.deletion_epoch=state.deletion_epoch
               and connection.status='pending'
             for update of connection`,
            [
              state.stateId,
              state.sessionId,
              state.connectionId,
              state.deletionEpoch,
            ],
          );
          if (valid.rows.length !== 1) {
            throw new BrokerageConnectionError("connection_not_found");
          }
          await database.query(
            `insert into argus_private.webull_credentials(
               connection_id,user_id,deletion_epoch,token_version,key_version,
               access_ciphertext,access_nonce,access_tag,
               refresh_ciphertext,refresh_nonce,refresh_tag,
               wrapped_data_key,wrapped_key_nonce,wrapped_key_tag,
               associated_data_hash,access_expires_at,refresh_expires_at
             ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
             on conflict (connection_id) do update set
               token_version=excluded.token_version,
               key_version=excluded.key_version,
               access_ciphertext=excluded.access_ciphertext,
               access_nonce=excluded.access_nonce,
               access_tag=excluded.access_tag,
               refresh_ciphertext=excluded.refresh_ciphertext,
               refresh_nonce=excluded.refresh_nonce,
               refresh_tag=excluded.refresh_tag,
               wrapped_data_key=excluded.wrapped_data_key,
               wrapped_key_nonce=excluded.wrapped_key_nonce,
               wrapped_key_tag=excluded.wrapped_key_tag,
               associated_data_hash=excluded.associated_data_hash,
               access_expires_at=excluded.access_expires_at,
               refresh_expires_at=excluded.refresh_expires_at,
               updated_at=now()`,
            [
              state.connectionId,
              state.userId,
              state.deletionEpoch,
              credentials.tokenVersion,
              credentials.keyVersion,
              credentials.accessCiphertext,
              credentials.accessNonce,
              credentials.accessTag,
              credentials.refreshCiphertext,
              credentials.refreshNonce,
              credentials.refreshTag,
              credentials.wrappedDataKey,
              credentials.wrappedKeyNonce,
              credentials.wrappedKeyTag,
              credentials.associatedDataHash,
              credentials.accessExpiresAt,
              credentials.refreshExpiresAt,
            ],
          );
          await database.query(
            `delete from argus_brokerage.accounts
              where user_id=auth.uid() and connection_id=$1`,
            [state.connectionId],
          );
          for (const account of accounts) {
            await database.query(
              `insert into argus_brokerage.accounts(
                 id,user_id,deletion_epoch,connection_id,display_label,
                 base_currency,status,capability_version,fetched_at,expires_at
               ) values ($1,$2,$3,$4,$5,$6,$7,$8,now(),now())`,
              [
                account.id,
                state.userId,
                state.deletionEpoch,
                state.connectionId,
                account.displayLabel,
                account.baseCurrency,
                account.status,
                account.capabilityVersion,
              ],
            );
            await database.query(
              `insert into argus_private.webull_account_mappings(
                 account_id,connection_id,user_id,deletion_epoch,
                 provider_account_id_ciphertext,provider_account_id_hash,key_version
               ) values ($1,$2,$3,$4,$5,$6,$7)`,
              [
                account.id,
                state.connectionId,
                state.userId,
                state.deletionEpoch,
                account.providerIdCiphertext,
                account.providerIdHash,
                account.keyVersion,
              ],
            );
          }
          await database.query(
            `update argus_brokerage.connections
                set status='connected',authorized_at=now(),disconnected_at=null,
                    last_error_code=null,updated_at=now()
              where id=$1 and user_id=auth.uid()`,
            [state.connectionId],
          );
          await database.query(
            `insert into argus_private.webull_completion_handles(
               user_id,session_id,deletion_epoch,connection_id,handle_hash,
               outcome,expires_at
             ) values ($1,$2,$3,$4,$5,'connected',$6)`,
            [
              state.userId,
              state.sessionId,
              state.deletionEpoch,
              state.connectionId,
              handleHash,
              expiresAt,
            ],
          );
        },
      ),
    fail: (
      state: ConsumedWebullState,
      outcome: "denied" | "failed" | "temporarily_unavailable",
      handleHash: string,
      expiresAt: Date,
    ) =>
      withRequestTransaction(
        {
          pool,
          verifiedClaims: {
            userId: state.userId,
            sessionId: state.sessionId,
            aal: "aal1",
          },
        },
        async (database) => {
          const valid = await database.query<{ id: string }>(
            `select state.id from argus_private.oauth_states state
               join argus_app.members member on member.user_id=state.user_id
               join argus_brokerage.connections connection
                 on connection.id=state.connection_id
                and connection.user_id=state.user_id
              where state.id=$1 and state.user_id=auth.uid()
                and state.session_id=$2 and state.connection_id=$3
                and state.deletion_epoch=$4 and state.consumed_at is not null
                and member.status='active'
                and member.deletion_epoch=state.deletion_epoch
                and connection.status='pending'
              for update of connection`,
            [
              state.stateId,
              state.sessionId,
              state.connectionId,
              state.deletionEpoch,
            ],
          );
          if (valid.rows.length !== 1) {
            throw new BrokerageConnectionError("connection_not_found");
          }
          await database.query(
            `delete from argus_private.webull_credentials
              where user_id=auth.uid() and connection_id=$1`,
            [state.connectionId],
          );
          await database.query(
            `delete from argus_private.refresh_leases
              where user_id=auth.uid() and connection_id=$1`,
            [state.connectionId],
          );
          await database.query(
            `update argus_brokerage.connections
                set status=$2,last_error_code=$2,updated_at=now()
              where id=$1 and user_id=auth.uid() and status='pending'`,
            [state.connectionId, outcome],
          );
          await database.query(
            `insert into argus_private.webull_completion_handles(
               user_id,session_id,deletion_epoch,connection_id,handle_hash,
               outcome,expires_at
             ) values ($1,$2,$3,$4,$5,$6,$7)`,
            [
              state.userId,
              state.sessionId,
              state.deletionEpoch,
              state.connectionId,
              handleHash,
              outcome,
              expiresAt,
            ],
          );
        },
      ),
    completionLifetimeMilliseconds,
  });
}

export {
  hash as hashWebullOpaqueValue,
  randomOpaqueValue as newWebullOpaqueValue,
};

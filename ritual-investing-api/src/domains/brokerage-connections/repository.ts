import type { DatabaseTransaction } from "../../db/database-port.ts";
import type {
  BrokerageConnectionRepository,
  ConsumedWebullState,
  ProtectedCallbackAccount,
  ProtectedCallbackCredentials,
  WebullCallbackRepository,
  WebullReturnTarget,
} from "./ports.ts";
import { BrokerageConnectionError } from "./service.ts";

export function createBrokerageConnectionRepository(
  database: DatabaseTransaction,
): BrokerageConnectionRepository {
  return Object.freeze({
    start: async (
      input: Parameters<BrokerageConnectionRepository["start"]>[0],
    ) => {
      const member = await database.query<{
        deletion_epoch: number;
      }>(
        `select deletion_epoch from argus_app.members
            where user_id = argus_private.trusted_request_user_id() and status = 'active' for update`,
      );
      const deletionEpoch = member.rows[0]?.deletion_epoch;
      if (deletionEpoch === undefined) {
        throw new BrokerageConnectionError("connection_not_found");
      }
      const existing = await database.query<{ id: string; status: string }>(
        `select id,status from argus_brokerage.connections
            where user_id = argus_private.trusted_request_user_id()
              and status not in ('denied','failed','disconnected')
            order by created_at desc limit 1 for update`,
      );
      let connectionId = existing.rows[0]?.id;
      if (existing.rows[0]?.status === "connected" && !input.reconnect) {
        throw new BrokerageConnectionError("connection_already_connected");
      }
      if (connectionId === undefined) {
        connectionId = crypto.randomUUID();
        await database.query(
          `insert into argus_brokerage.connections(
               id,user_id,deletion_epoch,status
             ) values ($1,argus_private.trusted_request_user_id(),$2,'pending')`,
          [connectionId, deletionEpoch],
        );
      } else {
        if (input.reconnect) {
          await database.query(
            `select argus_private.clear_webull_connection_materialization($1)`,
            [connectionId],
          );
        }
        await database.query(
          `update argus_brokerage.connections
                set status='pending',last_error_code=null,updated_at=$2
              where id=$1 and user_id=argus_private.trusted_request_user_id()`,
          [connectionId, input.startedAt],
        );
      }
      await database.query(
        `update argus_private.oauth_states set consumed_at=$1
            where user_id=argus_private.trusted_request_user_id() and consumed_at is null`,
        [input.startedAt],
      );
      await database.query(
        `insert into argus_private.oauth_states(
             id,user_id,session_id,deletion_epoch,connection_id,state_hash,
             return_target,contract_version,provider_environment,expires_at
           ) values ($1,argus_private.trusted_request_user_id(),$2,$3,$4,$5,$6,$7,$8,$9)`,
        [
          crypto.randomUUID(),
          input.sessionId,
          deletionEpoch,
          connectionId,
          input.stateHash,
          input.returnTarget,
          input.contractVersion,
          input.environment,
          input.expiresAt,
        ],
      );
      return connectionId;
    },
    issueStepUp: async (
      input: Parameters<BrokerageConnectionRepository["issueStepUp"]>[0],
    ) => {
      const inserted = await database.query(
        `insert into argus_private.step_up_receipts(
               user_id,session_id,deletion_epoch,action,receipt_hash,aal,expires_at
             ) select argus_private.trusted_request_user_id(),$1,member.deletion_epoch,$2,$3,$4,$5
                 from argus_app.members member
                where member.user_id=argus_private.trusted_request_user_id() and member.status='active'
             returning id`,
        [
          input.sessionId,
          input.action,
          input.receiptHash,
          input.aal,
          input.expiresAt,
        ],
      );
      if (inserted.rows.length !== 1) {
        throw new BrokerageConnectionError("step_up_required");
      }
      return undefined;
    },
    status: async () => {
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
              where connection.user_id=argus_private.trusted_request_user_id()
              group by connection.id
              order by connection.created_at desc limit 1`,
      );
      return result.rows[0] ?? {
        status: "disconnected",
        accounts: [],
      };
    },
    selectAccount: async (accountId: string) => {
      const result = await database.query<{ connection_id: string }>(
        `select account.connection_id
               from argus_brokerage.accounts account
               join argus_brokerage.connections connection
                 on connection.id=account.connection_id
                and connection.user_id=account.user_id
              where account.id=$1 and account.user_id=argus_private.trusted_request_user_id()
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
             ) select argus_private.trusted_request_user_id(),member.deletion_epoch,$1,$2
                 from argus_app.members member
                where member.user_id=argus_private.trusted_request_user_id() and member.status='active'
             on conflict (user_id) do update
               set deletion_epoch=excluded.deletion_epoch,
                   connection_id=excluded.connection_id,
                   account_id=excluded.account_id,
                   selected_at=now()`,
        [connectionId, accountId],
      );
      return Object.freeze({ account_id: accountId, selected: true });
    },
    redeemCompletion: async (handleHash: string, sessionId: string) => {
      const result = await database.query<Record<string, unknown>>(
        `update argus_private.webull_completion_handles completion
                set consumed_at=now()
              where completion.handle_hash=$1
                and completion.user_id=argus_private.trusted_request_user_id()
                and completion.session_id=$2
                and completion.consumed_at is null
                and completion.expires_at > now()
              returning connection_id,outcome,created_at`,
        [handleHash, sessionId],
      );
      const completion = result.rows[0];
      if (completion === undefined) {
        throw new BrokerageConnectionError("completion_not_found");
      }
      return completion;
    },
    disconnect: async (receiptHash: string, sessionId: string) => {
      const disconnected = await database.query<{
        connection_id: string;
        status: "disconnected";
        provider_grant_revoked: boolean;
      }>(
        "select * from argus_private.disconnect_webull_connection($1,$2)",
        [receiptHash, sessionId],
      );
      const result = disconnected.rows[0];
      if (result === undefined) {
        throw new BrokerageConnectionError("connection_not_found");
      }
      return Object.freeze(result);
    },
  });
}

export function createWebullCallbackRepository(
  database: DatabaseTransaction,
): WebullCallbackRepository {
  return Object.freeze({
    consumeState: async (stateHash: string, consumedAt: Date) => {
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
    complete: async (
      state: ConsumedWebullState,
      credentials: ProtectedCallbackCredentials,
      accounts: readonly ProtectedCallbackAccount[],
      handleHash: string,
      expiresAt: Date,
    ) => {
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
             where state.id=$1 and state.user_id=argus_private.trusted_request_user_id()
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
        `select argus_private.clear_webull_connection_materialization($1)`,
        [state.connectionId],
      );
      await database.query(
        `insert into argus_private.webull_credentials(
               connection_id,user_id,deletion_epoch,provider_environment,
               token_version,key_version,
               access_ciphertext,access_nonce,access_tag,
               refresh_ciphertext,refresh_nonce,refresh_tag,
               wrapped_data_key,wrapped_key_nonce,wrapped_key_tag,
               associated_data_hash,access_expires_at,refresh_expires_at
             ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)`,
        [
          state.connectionId,
          state.userId,
          state.deletionEpoch,
          credentials.environment,
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
      for (const account of accounts) {
        await database.query(
          `insert into argus_brokerage.accounts(
                 id,user_id,deletion_epoch,connection_id,display_label,
                 base_currency,status,capability_version,market_timezone,
                 capabilities,fetched_at,expires_at
               ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11,$12)`,
          [
            account.id,
            state.userId,
            state.deletionEpoch,
            state.connectionId,
            account.displayLabel,
            account.baseCurrency,
            account.status,
            account.capabilityVersion,
            account.marketTimezone,
            JSON.stringify(account.capabilities),
            account.fetchedAt,
            account.expiresAt,
          ],
        );
        await database.query(
          `insert into argus_private.webull_account_mappings(
                 account_id,connection_id,user_id,deletion_epoch,
                 provider_environment,provider_account_id_ciphertext,
                 provider_account_id_hash,key_version
               ) values ($1,$2,$3,$4,$5,$6,$7,$8)`,
          [
            account.id,
            state.connectionId,
            state.userId,
            state.deletionEpoch,
            credentials.environment,
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
              where id=$1 and user_id=argus_private.trusted_request_user_id()`,
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
    fail: async (
      state: ConsumedWebullState,
      outcome: "denied" | "failed" | "temporarily_unavailable",
      handleHash: string,
      expiresAt: Date,
    ) => {
      const valid = await database.query<{ id: string }>(
        `select state.id from argus_private.oauth_states state
               join argus_app.members member on member.user_id=state.user_id
               join argus_brokerage.connections connection
                 on connection.id=state.connection_id
                and connection.user_id=state.user_id
              where state.id=$1 and state.user_id=argus_private.trusted_request_user_id()
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
        `select argus_private.clear_webull_connection_materialization($1)`,
        [state.connectionId],
      );
      await database.query(
        `update argus_brokerage.connections
                set status=$2,last_error_code=$2,updated_at=now()
              where id=$1 and user_id=argus_private.trusted_request_user_id() and status='pending'`,
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
  });
}

export type {
  BrokerageConnectionRepository,
  ConsumedWebullState,
  ProtectedCallbackAccount,
  ProtectedCallbackCredentials,
  WebullCallbackRepository,
  WebullReturnTarget,
} from "./ports.ts";
export { BrokerageConnectionError } from "./service.ts";

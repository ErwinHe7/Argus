import type { DatabaseTransaction } from "../../db/database-port.ts";
import type { BrokerageProjectionRepository } from "./ports.ts";
import {
  type BrokerageAccountContext,
  type BrokerageAccountSummary,
  BrokerageProjectionError,
  type BrokerageProjectionResource,
  type ProviderProjection,
  type StoredProjection,
} from "./types.ts";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function date(value: unknown, field: string): Date {
  const parsed = value instanceof Date ? value : new Date(String(value));
  if (!Number.isFinite(parsed.getTime())) {
    throw new Error(`invalid_${field}`);
  }
  return parsed;
}

export function parseBrokerageSafeInteger(
  value: unknown,
  field: string,
  minimum = 0,
): number {
  const parsed = typeof value === "string" && /^\d+$/.test(value)
    ? Number(value)
    : value;
  if (!Number.isSafeInteger(parsed) || Number(parsed) < minimum) {
    throw new Error(`invalid_${field}`);
  }
  return Number(parsed);
}

function storedProjection(row: Record<string, unknown>): StoredProjection {
  return Object.freeze({
    id: String(row.id),
    generation: parseBrokerageSafeInteger(
      row.generation,
      "projection_generation",
      1,
    ),
    resource: row.resource_type as BrokerageProjectionResource,
    payload: row.payload,
    providerObservedAt: row.provider_observed_at === null
      ? null
      : date(row.provider_observed_at, "provider_observed_at"),
    fetchedAt: date(row.fetched_at, "fetched_at"),
    expiresAt: date(row.expires_at, "expires_at"),
    availability: row.availability as StoredProjection["availability"],
    reasonCode: row.reason_code === null ? null : String(row.reason_code),
  });
}

function safeCapabilities(value: unknown): readonly unknown[] {
  if (!Array.isArray(value) || value.length > 64) {
    throw new Error("invalid_account_capabilities");
  }
  return Object.freeze(value.map((entry) => {
    if (
      typeof entry !== "object" ||
      entry === null ||
      Array.isArray(entry) ||
      Object.keys(entry).sort().join(",") !==
        "available,capability,provider_code"
    ) {
      throw new Error("invalid_account_capabilities");
    }
    const capability = entry as Record<string, unknown>;
    if (
      typeof capability.available !== "boolean" ||
      typeof capability.capability !== "string" ||
      typeof capability.provider_code !== "string"
    ) {
      throw new Error("invalid_account_capabilities");
    }
    return Object.freeze({ ...capability });
  }));
}

export type { BrokerageProjectionRepository } from "./ports.ts";

export function createBrokerageProjectionRepository(
  database: DatabaseTransaction,
): BrokerageProjectionRepository {
  const account = async (
    accountId: string,
  ): Promise<BrokerageAccountContext> => {
    if (!uuidPattern.test(accountId)) {
      throw new BrokerageProjectionError("account_not_found");
    }
    const result = await database.query<Record<string, unknown>>(
      `select account.user_id,account.deletion_epoch,
                account.connection_id,connection.status connection_status,
                account.id account_id,account.status account_status,
                account.capability_version
           from argus_brokerage.accounts account
           join argus_brokerage.connections connection
             on connection.id=account.connection_id
            and connection.user_id=account.user_id
            and connection.deletion_epoch=account.deletion_epoch
          where account.id=$1 and account.user_id=argus_private.trusted_request_user_id()`,
      [accountId],
    );
    const row = result.rows[0];
    if (row === undefined) {
      throw new BrokerageProjectionError("account_not_found");
    }
    return Object.freeze({
      userId: String(row.user_id),
      deletionEpoch: parseBrokerageSafeInteger(
        row.deletion_epoch,
        "deletion_epoch",
      ),
      connectionId: String(row.connection_id),
      connectionStatus: row
        .connection_status as BrokerageAccountContext["connectionStatus"],
      accountId: String(row.account_id),
      accountStatus: row
        .account_status as BrokerageAccountContext["accountStatus"],
      capabilityVersion: parseBrokerageSafeInteger(
        row.capability_version,
        "capability_version",
      ),
    });
  };

  const repository: BrokerageProjectionRepository = {
    listAccounts: async () => {
      const result = await database.query<Record<string, unknown>>(
        `select account.id,account.connection_id,account.display_label,
                  account.base_currency,account.market_timezone,account.status,
                  account.capability_version,
                  coalesce((
                    select jsonb_agg(jsonb_build_object(
                      'capability',case capability.capability_code
                        when 'balances_read' then 'balances_read'
                        when 'positions_read' then 'positions_read'
                        when 'orders_read' then 'orders_read'
                        when 'manual_orders' then 'manual_orders'
                        else 'unsupported' end,
                      'provider_code',capability.provider_code,
                      'available',capability.available
                    ) order by capability.provider_code)
                    from argus_brokerage.account_capabilities capability
                    where capability.tenant_id=account.tenant_id
                      and capability.lifecycle_id=account.lifecycle_id
                      and capability.account_id=account.id
                      and capability.capability_version=account.capability_version
                  ),'[]'::jsonb) capabilities,
                  account.provider_observed_at,account.fetched_at,
                  account.expires_at,
                  case
                    when connection.status='reauthorization_required'
                      then 'reauthorization_required'
                    when connection.status='disconnected' then 'disconnected'
                    when account.status='unavailable' then 'unavailable'
                    when account.expires_at is null then 'unavailable'
                    when account.expires_at <= now() then 'stale'
                    else 'fresh'
                  end authority_state,
                  (selection.account_id is not null) selected
             from argus_brokerage.accounts account
             join argus_brokerage.connections connection
               on connection.id=account.connection_id
              and connection.user_id=account.user_id
              and connection.deletion_epoch=account.deletion_epoch
             left join argus_brokerage.active_account_selections selection
               on selection.user_id=account.user_id
              and selection.connection_id=account.connection_id
              and selection.account_id=account.id
            where account.user_id=argus_private.trusted_request_user_id()
              and connection.status not in ('denied','failed','disconnected')
            order by account.display_label,account.id`,
      );
      return Object.freeze(result.rows.map((row) =>
        Object.freeze({
          id: String(row.id),
          connection_id: String(row.connection_id),
          display_label: String(row.display_label),
          base_currency: String(row.base_currency),
          market_timezone: row.market_timezone === null
            ? null
            : String(row.market_timezone),
          status: row.status as BrokerageAccountSummary["status"],
          capability_version: parseBrokerageSafeInteger(
            row.capability_version,
            "capability_version",
          ),
          capabilities: safeCapabilities(row.capabilities),
          state: row.authority_state as BrokerageAccountSummary["state"],
          selected: row.selected === true,
          provider_observed_at: row.provider_observed_at === null
            ? null
            : date(row.provider_observed_at, "provider_observed_at")
              .toISOString(),
          fetched_at: row.fetched_at === null
            ? null
            : date(row.fetched_at, "fetched_at").toISOString(),
          expires_at: row.expires_at === null
            ? null
            : date(row.expires_at, "expires_at").toISOString(),
        })
      ));
    },
    account,
    latest: async (accountId, resource) => {
      // The owner predicate is repeated explicitly in addition to RLS so an
      // attacker-supplied UUID can never become a cross-owner filter oracle.
      const result = await database.query<Record<string, unknown>>(
        `select generation.id,generation.generation,
                  generation.resource_type,generation.provider_observed_at,
                  generation.fetched_at,generation.expires_at,
                  generation.availability,generation.reason_code,
                  argus_private.read_brokerage_projection_payload(
                    generation.id
                  ) payload
             from argus_brokerage.projection_generations generation
             join argus_brokerage.accounts account
               on account.tenant_id=generation.tenant_id
              and account.lifecycle_id=generation.lifecycle_id
              and account.id=generation.account_id
              and account.user_id=generation.user_id
            where generation.account_id=$1
              and generation.resource_type=$2
              and generation.user_id=argus_private.trusted_request_user_id()
              and generation.normalization_state='ready'
            order by generation.generation desc limit 1`,
        [accountId, resource],
      );
      return result.rows[0] === undefined
        ? null
        : storedProjection(result.rows[0]);
    },
    acquireRefreshLease: async ({
      context,
      resource,
      leaseToken,
      leasedUntil,
    }) => {
      const result = await database.query(
        `select argus_private.acquire_brokerage_projection_lease(
             $1,$5,$6,$2,$3,$4
           ) acquired`,
        [
          context.accountId,
          resource,
          leaseToken,
          leasedUntil,
          context.connectionId,
          context.deletionEpoch,
        ],
      );
      return result.rows[0]?.acquired === true;
    },
    appendGeneration: async ({
      context,
      resource,
      leaseToken,
      projection,
      purgeAfter,
    }) => {
      const result = await database.query<Record<string, unknown>>(
        `select result_id id,result_generation generation,
                  result_resource_type resource_type,
                  result_provider_observed_at provider_observed_at,
                  result_fetched_at fetched_at,result_expires_at expires_at,
                  result_availability availability,result_reason_code reason_code
             from argus_private.append_brokerage_projection_generation(
               $1,$4,$5,$2,$3,$6::jsonb,$7,$8,$9,$10,$11,$12
             )`,
        [
          context.accountId,
          resource,
          leaseToken,
          context.connectionId,
          context.deletionEpoch,
          JSON.stringify(projection.payload),
          projection.providerObservedAt,
          projection.fetchedAt,
          projection.expiresAt,
          projection.availability,
          projection.reasonCode ?? null,
          purgeAfter,
        ],
      );
      const header = result.rows[0];
      if (header === undefined) {
        throw new BrokerageProjectionError("refresh_fenced");
      }
      const typed = await database.query<{ payload: unknown }>(
        `select argus_private.read_brokerage_projection_payload($1) payload`,
        [header.id],
      );
      return storedProjection({
        ...header,
        payload: typed.rows[0]?.payload ?? null,
      });
    },
    releaseRefreshLease: async ({ accountId, resource, leaseToken }) => {
      await database.query(
        `select argus_private.release_brokerage_projection_lease($1,$2,$3)`,
        [accountId, resource, leaseToken],
      );
    },
    invalidateAccount: async (accountId) => {
      const result = await database.query<{ connection_id: string | null }>(
        `select argus_private.invalidate_brokerage_account_scoped($1)
             connection_id`,
        [accountId],
      );
      if (
        result.rows[0]?.connection_id === null || result.rows[0] === undefined
      ) {
        throw new BrokerageProjectionError("account_not_found");
      }
    },
    requireReauthorization: async (connectionId) => {
      await database.query(
        `select argus_private.require_brokerage_reauthorization_scoped($1)`,
        [connectionId],
      );
    },
  };
  return Object.freeze(repository);
}

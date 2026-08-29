import type { DatabaseTransaction } from "../../db/database-port.ts";
import type { BrokerageOrderRepository } from "./ports.ts";
import type {
  NormalizedCapability,
  NormalizedRestriction,
} from "../brokerage-accounts/normalization.ts";
import type { BrokerageProjectionAvailability } from "../brokerage-projections/types.ts";
import { normalizeBrokerageReasonCode } from "./reason-codes.ts";
import {
  type BrokerageOrderAuthority,
  type BrokerageOrderCommand,
  type BrokerageOrderDetail,
  BrokerageOrderError,
  type BrokerageOrderList,
  type BrokerageOrderOperation,
  type BrokerageOrderPreview,
  type BrokerageOrderReconciliation,
  type NormalizedBrokerageOrder,
  type NormalizedOrderIntent,
  type OwnedOrderTarget,
  type PreparedOrderCommand,
  type ProviderCommandResult,
  type ProviderOrderListProjection,
  type ProviderOrderPreview,
} from "./types.ts";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function date(value: unknown, field: string): Date {
  const result = value instanceof Date ? value : new Date(String(value));
  if (!Number.isFinite(result.getTime())) throw new Error(`invalid_${field}`);
  return result;
}

function integer(value: unknown, field: string, minimum = 0): number {
  const result = typeof value === "string" && /^\d+$/.test(value)
    ? Number(value)
    : value;
  if (!Number.isSafeInteger(result) || Number(result) < minimum) {
    throw new Error(`invalid_${field}`);
  }
  return Number(result);
}

function capabilities(value: unknown): readonly NormalizedCapability[] {
  if (!Array.isArray(value) || value.length > 64) {
    throw new BrokerageOrderError("brokerage_authority_stale");
  }
  return Object.freeze(value.map((entry) => {
    if (typeof entry !== "object" || entry === null || Array.isArray(entry)) {
      throw new BrokerageOrderError("brokerage_authority_stale");
    }
    const record = entry as Record<string, unknown>;
    if (
      ![
        "balances_read",
        "positions_read",
        "orders_read",
        "manual_orders",
        "unsupported",
      ]
        .includes(String(record.capability)) ||
      typeof record.provider_code !== "string" ||
      typeof record.available !== "boolean"
    ) {
      throw new BrokerageOrderError("brokerage_authority_stale");
    }
    return Object.freeze({
      capability: record.capability as NormalizedCapability["capability"],
      provider_code: record.provider_code,
      available: record.available,
    });
  }));
}

function restrictions(value: unknown): readonly NormalizedRestriction[] {
  if (!Array.isArray(value) || value.length > 256) {
    throw new BrokerageOrderError("brokerage_authority_stale");
  }
  return Object.freeze(value.map((entry) => {
    if (typeof entry !== "object" || entry === null || Array.isArray(entry)) {
      throw new BrokerageOrderError("brokerage_authority_stale");
    }
    const record = entry as Record<string, unknown>;
    if (
      ![
        "closing_only",
        "trading_disabled",
        "liquidation_only",
        "unsupported",
      ].includes(String(record.restriction)) ||
      typeof record.provider_code !== "string" ||
      typeof record.active !== "boolean" ||
      (record.detail !== null && typeof record.detail !== "string")
    ) {
      throw new BrokerageOrderError("brokerage_authority_stale");
    }
    return Object.freeze({
      restriction: record.restriction as NormalizedRestriction["restriction"],
      provider_code: record.provider_code,
      active: record.active,
      detail: record.detail as string | null,
    });
  }));
}

export function parseNormalizedOrderProjection(
  value: unknown,
): NormalizedBrokerageOrder {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BrokerageOrderError("provider_contract_unavailable");
  }
  const record = value as Record<string, unknown>;
  const keys = [
    "average_fill_price",
    "currency",
    "filled_quantity",
    "id",
    "instrument_id",
    "limit_price",
    "order_type",
    "provider_order_type",
    "provider_side",
    "provider_state",
    "provider_time_in_force",
    "quantity",
    "side",
    "state",
    "stop_price",
    "symbol",
    "terminal",
    "time_in_force",
  ];
  const decimalPattern = /^(?:0|[1-9]\d{0,37})(?:\.\d{1,18})?$/;
  const providerCodePattern = /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$/;
  const nullableDecimal = (entry: unknown) =>
    entry === null ||
    (typeof entry === "string" && decimalPattern.test(entry));
  const state = String(record.state);
  const terminal = ["filled", "cancelled", "rejected", "expired"].includes(
    state,
  );
  if (
    Object.keys(record).sort().join("\u001f") !== keys.join("\u001f") ||
    !uuidPattern.test(String(record.id)) ||
    !uuidPattern.test(String(record.instrument_id)) ||
    typeof record.symbol !== "string" ||
    !/^[A-Z0-9][A-Z0-9.-]{0,31}$/.test(record.symbol) ||
    !["buy", "sell", "unsupported"].includes(String(record.side)) ||
    !["market", "limit", "stop", "stop_limit", "unsupported"].includes(
      String(record.order_type),
    ) ||
    !["day", "gtc", "unsupported"].includes(String(record.time_in_force)) ||
    ![
      "pending",
      "partially_filled",
      "filled",
      "cancelled",
      "rejected",
      "expired",
      "unknown",
    ].includes(state) ||
    typeof record.quantity !== "string" ||
    !decimalPattern.test(record.quantity) ||
    typeof record.filled_quantity !== "string" ||
    !decimalPattern.test(record.filled_quantity) ||
    !nullableDecimal(record.limit_price) ||
    !nullableDecimal(record.stop_price) ||
    !nullableDecimal(record.average_fill_price) ||
    typeof record.currency !== "string" ||
    !/^[A-Z]{3}$/.test(record.currency) ||
    typeof record.terminal !== "boolean" ||
    record.terminal !== terminal ||
    ![
      record.provider_side,
      record.provider_order_type,
      record.provider_time_in_force,
      record.provider_state,
    ].every((entry) =>
      typeof entry === "string" && providerCodePattern.test(entry)
    )
  ) {
    throw new BrokerageOrderError("provider_contract_unavailable");
  }
  return Object.freeze({
    id: String(record.id),
    instrument_id: String(record.instrument_id),
    symbol: record.symbol,
    side: record.side as NormalizedBrokerageOrder["side"],
    provider_side: String(record.provider_side),
    order_type: record.order_type as NormalizedBrokerageOrder["order_type"],
    provider_order_type: String(record.provider_order_type),
    time_in_force: record
      .time_in_force as NormalizedBrokerageOrder["time_in_force"],
    provider_time_in_force: String(record.provider_time_in_force),
    quantity: record.quantity,
    filled_quantity: record.filled_quantity,
    limit_price: record.limit_price as string | null,
    stop_price: record.stop_price as string | null,
    average_fill_price: record.average_fill_price as string | null,
    currency: record.currency,
    state: record.state as NormalizedBrokerageOrder["state"],
    provider_state: String(record.provider_state),
    terminal: record.terminal,
  });
}

function publicListOrder(
  order: BrokerageOrderDetail,
): NormalizedBrokerageOrder {
  return Object.freeze({
    id: order.id,
    instrument_id: order.instrument_id,
    symbol: order.symbol,
    side: order.side,
    provider_side: order.provider_side,
    order_type: order.order_type,
    provider_order_type: order.provider_order_type,
    time_in_force: order.time_in_force,
    provider_time_in_force: order.provider_time_in_force,
    quantity: order.quantity,
    filled_quantity: order.filled_quantity,
    limit_price: order.limit_price,
    stop_price: order.stop_price,
    average_fill_price: order.average_fill_price,
    currency: order.currency,
    state: order.state,
    provider_state: order.provider_state,
    terminal: order.terminal,
  });
}

function command(row: Record<string, unknown>): BrokerageOrderCommand {
  return Object.freeze({
    id: String(row.id),
    account_id: String(row.account_id),
    operation: row.operation as BrokerageOrderOperation,
    target_order_id: row.target_order_id === null
      ? null
      : String(row.target_order_id),
    order_id: row.order_id === null ? null : String(row.order_id),
    state: row.state as BrokerageOrderCommand["state"],
    ambiguous: ["dispatching", "ambiguous", "reconciling", "manual_review"]
      .includes(String(row.state)),
    created_at: date(row.created_at, "command_created_at").toISOString(),
    updated_at: date(row.updated_at, "command_updated_at").toISOString(),
  });
}

function translateOrderDatabaseError(error: unknown): never {
  const message = error instanceof Error ? error.message : String(error);
  for (
    const code of [
      "account_not_found",
      "order_not_found",
      "command_not_found",
      "brokerage_authority_stale",
      "brokerage_restricted",
      "capability_unavailable",
      "unsupported_order",
      "preview_expired",
      "preview_replayed",
      "preview_mismatch",
      "idempotency_conflict",
      "account_command_blocked",
    ] as const
  ) {
    if (message.includes(code)) throw new BrokerageOrderError(code);
  }
  throw new BrokerageOrderError("provider_contract_unavailable");
}

export type { BrokerageOrderRepository } from "./ports.ts";

export function createBrokerageOrderRepository(
  database: DatabaseTransaction,
  verifiedUserId: string,
): BrokerageOrderRepository {
  const authority = async (
    accountId: string,
  ): Promise<BrokerageOrderAuthority> => {
    if (!uuidPattern.test(accountId)) {
      throw new BrokerageOrderError("account_not_found");
    }
    const result = await database.query<Record<string, unknown>>(
      `select account.user_id,account.deletion_epoch,account.connection_id,
                connection.status connection_status,account.id account_id,
                account.status account_status,account.capability_version,
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
                account.expires_at account_expires_at,
                restriction.generation restriction_generation,
                restriction.expires_at restriction_expires_at,
                restriction.availability restriction_availability,
                restriction.restrictions
           from argus_brokerage.accounts account
           join argus_brokerage.connections connection
             on connection.id=account.connection_id
            and connection.user_id=account.user_id
            and connection.deletion_epoch=account.deletion_epoch
           left join lateral (
             select generation.generation,generation.expires_at,
                    generation.availability,
                    argus_private.read_brokerage_projection_payload(
                      generation.id
                    ) restrictions
               from argus_brokerage.projection_generations generation
              where generation.tenant_id=account.tenant_id
                and generation.lifecycle_id=account.lifecycle_id
                and generation.user_id=account.user_id
                and generation.account_id=account.id
                and resource_type='restrictions'
                and generation.normalization_state='ready'
              order by generation.generation desc limit 1
           ) restriction on true
          where account.id=$1 and account.user_id=argus_private.trusted_request_user_id()`,
      [accountId],
    );
    const row = result.rows[0];
    if (row === undefined) throw new BrokerageOrderError("account_not_found");
    return Object.freeze({
      context: Object.freeze({
        userId: String(row.user_id),
        deletionEpoch: integer(row.deletion_epoch, "deletion_epoch"),
        connectionId: String(row.connection_id),
        connectionStatus: row
          .connection_status as BrokerageOrderAuthority["context"][
            "connectionStatus"
          ],
        accountId: String(row.account_id),
        accountStatus: row
          .account_status as BrokerageOrderAuthority["context"][
            "accountStatus"
          ],
        capabilityVersion: integer(
          row.capability_version,
          "capability_version",
        ),
      }),
      accountExpiresAt: row.account_expires_at === null
        ? null
        : date(row.account_expires_at, "account_expires_at"),
      capabilities: capabilities(row.capabilities),
      restrictionGeneration: row.restriction_generation === null
        ? null
        : integer(row.restriction_generation, "restriction_generation", 1),
      restrictionExpiresAt: row.restriction_expires_at === null
        ? null
        : date(row.restriction_expires_at, "restriction_expires_at"),
      restrictionAvailability: (row.restriction_availability ??
        "unavailable") as BrokerageProjectionAvailability,
      restrictions: restrictions(row.restrictions ?? []),
    });
  };

  const currentCommand = async (commandId: string) => {
    if (!uuidPattern.test(commandId)) {
      throw new BrokerageOrderError("command_not_found");
    }
    const result = await database.query<Record<string, unknown>>(
      `select id,account_id,operation,target_order_id,order_id,state,
              created_at,updated_at
         from argus_private.provider_commands
        where id=$1 and user_id=argus_private.trusted_request_user_id()`,
      [commandId],
    );
    if (result.rows[0] === undefined) {
      throw new BrokerageOrderError("command_not_found");
    }
    return command(result.rows[0]);
  };

  const finishDispatch = async (
    prepared: PreparedOrderCommand,
    state: "failed" | "ambiguous",
    outcome: "terminal_failure" | "ambiguous",
    reasonCode: string,
  ): Promise<BrokerageOrderCommand> => {
    const updated = await database.query<Record<string, unknown>>(
      `select command_id id,account_id,operation,target_order_id,order_id,
                state,created_at,updated_at
           from argus_private.record_provider_command_dispatch_outcome(
             $1,$2,$3,$4
           )`,
      [prepared.id, state, outcome, reasonCode],
    );
    if (updated.rows[0] === undefined) {
      throw new BrokerageOrderError("command_not_found");
    }
    return command(updated.rows[0]);
  };

  const repository: BrokerageOrderRepository = {
    authority,
    assertInstrumentOwned: async (accountId, instrumentId) => {
      if (!uuidPattern.test(accountId) || !uuidPattern.test(instrumentId)) {
        throw new BrokerageOrderError("unsupported_order");
      }
      const result = await database.query(
        `select 1
           from argus_private.webull_asset_mappings mapping
           join argus_brokerage.accounts account
             on account.id=mapping.account_id and account.user_id=mapping.user_id
            and account.connection_id=mapping.connection_id
            and account.deletion_epoch=mapping.deletion_epoch
          where mapping.account_id=$1 and mapping.instrument_id=$2
            and mapping.user_id=argus_private.trusted_request_user_id()
            and mapping.asset_kind in ('equity','etf')`,
        [accountId, instrumentId],
      );
      if (result.rows.length !== 1) {
        throw new BrokerageOrderError("unsupported_order");
      }
    },
    targetOrder: async (accountId, orderId) => {
      if (!uuidPattern.test(accountId) || !uuidPattern.test(orderId)) {
        throw new BrokerageOrderError("order_not_found");
      }
      const result = await database.query<Record<string, unknown>>(
        `select mapping.order_id,mapping.account_id,projection.state,
                  projection.instrument_id,asset.asset_kind
           from argus_private.webull_order_mappings mapping
           join lateral (
             select generation.state,generation.instrument_id
               from argus_brokerage.order_projection_generations generation
              where generation.tenant_id=mapping.tenant_id
                and generation.lifecycle_id=mapping.lifecycle_id
                and generation.user_id=mapping.user_id
                and generation.connection_id=mapping.connection_id
                and generation.account_id=mapping.account_id
                and generation.order_id=mapping.order_id
                and generation.normalization_state='ready'
              order by generation.generation desc limit 1
           ) projection on true
           left join argus_private.webull_asset_mappings asset
             on asset.tenant_id=mapping.tenant_id
            and asset.lifecycle_id=mapping.lifecycle_id
            and asset.user_id=mapping.user_id
            and asset.connection_id=mapping.connection_id
            and asset.account_id=mapping.account_id
            and asset.instrument_id=projection.instrument_id
          where mapping.order_id=$2 and mapping.account_id=$1
            and mapping.user_id=argus_private.trusted_request_user_id()`,
        [accountId, orderId],
      );
      const row = result.rows[0];
      if (row === undefined) throw new BrokerageOrderError("order_not_found");
      if (!["equity", "etf"].includes(String(row.asset_kind))) {
        throw new BrokerageOrderError("unsupported_order");
      }
      return Object.freeze({
        orderId: String(row.order_id),
        accountId: String(row.account_id),
        instrumentId: String(row.instrument_id),
        state: row.state as OwnedOrderTarget["state"],
      });
    },
    savePreview: async (preview) => {
      const result = await database.query<Record<string, unknown>>(
        `insert into argus_private.order_previews(
           id,user_id,deletion_epoch,connection_id,account_id,operation,
           target_order_id,capability_version,restriction_generation,
           policy_version,reviewed_payload_hash,normalized_payload,
           provider_preview_ref_ciphertext,provider_preview_ref_hash,
           provider_preview_key_version,estimated_total,currency,expires_at
         ) values (
           $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::jsonb,
           $13,$14,$15,$16,$17,$18
         ) returning id,account_id,operation,target_order_id,policy_version,
                     capability_version,restriction_generation,
                     reviewed_payload_hash,estimated_total,currency,expires_at`,
        [
          preview.id,
          preview.authority.context.userId,
          preview.authority.context.deletionEpoch,
          preview.authority.context.connectionId,
          preview.authority.context.accountId,
          preview.operation,
          preview.targetOrderId,
          preview.authority.context.capabilityVersion,
          preview.authority.restrictionGeneration,
          preview.policyVersion,
          preview.normalizedPayloadHash,
          JSON.stringify(preview.normalizedPayload),
          preview.provider.reference.ciphertext,
          preview.provider.reference.hash,
          preview.provider.reference.keyVersion,
          preview.provider.estimatedTotal,
          preview.provider.currency,
          preview.provider.expiresAt,
        ],
      );
      const row = result.rows[0]!;
      return Object.freeze({
        id: String(row.id),
        account_id: String(row.account_id),
        operation: row.operation as BrokerageOrderOperation,
        target_order_id: row.target_order_id === null
          ? null
          : String(row.target_order_id),
        policy_version: row
          .policy_version as BrokerageOrderPreview["policy_version"],
        capability_version: integer(
          row.capability_version,
          "capability_version",
        ),
        restriction_generation: integer(
          row.restriction_generation,
          "restriction_generation",
          1,
        ),
        reviewed_payload_hash: String(row.reviewed_payload_hash),
        estimated_total: row.estimated_total === null
          ? null
          : String(row.estimated_total),
        currency: row.currency === null ? null : String(row.currency),
        expires_at: date(row.expires_at, "preview_expires_at").toISOString(),
      });
    },
    prepareCommand: async (prepared) => {
      try {
        const result = await database.query<Record<string, unknown>>(
          `select * from argus_private.prepare_provider_order_command(
           $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12,$13
         )`,
          [
            prepared.previewId,
            prepared.commandId,
            prepared.authority.context.userId,
            prepared.authority.context.deletionEpoch,
            prepared.authority.context.connectionId,
            prepared.authority.context.accountId,
            prepared.operation,
            prepared.targetOrderId,
            prepared.clientOrderId,
            prepared.idempotencyKey,
            JSON.stringify(prepared.normalizedPayload),
            prepared.normalizedPayloadHash,
            prepared.policyVersion,
          ],
        );
        const row = result.rows[0];
        if (row === undefined) {
          throw new BrokerageOrderError("preview_mismatch");
        }
        return Object.freeze({
          id: String(row.command_id),
          userId: String(row.user_id),
          deletionEpoch: integer(row.deletion_epoch, "deletion_epoch"),
          connectionId: String(row.connection_id),
          accountId: String(row.account_id),
          operation: row.operation as BrokerageOrderOperation,
          targetOrderId: row.target_order_id === null
            ? null
            : String(row.target_order_id),
          clientOrderId: String(row.client_order_id),
          normalizedPayload: row.normalized_payload as NormalizedOrderIntent,
          normalizedPayloadHash: String(row.normalized_payload_hash),
          previewReference: Object.freeze({
            ciphertext: row.provider_preview_ref_ciphertext as Uint8Array,
            hash: String(row.provider_preview_ref_hash),
            keyVersion: integer(
              row.provider_preview_key_version,
              "preview_key_version",
              1,
            ),
          }),
          state: row.state as PreparedOrderCommand["state"],
          duplicate: row.is_duplicate === true,
          egressStartedAt: date(row.egress_started_at, "egress_started_at"),
        });
      } catch (error) {
        if (error instanceof BrokerageOrderError) throw error;
        return translateOrderDatabaseError(error);
      }
    },
    command: currentCommand,
    staffReconciliation: async (commandId) => {
      if (!uuidPattern.test(commandId)) {
        throw new BrokerageOrderError("command_not_found");
      }
      const result = await database.query<Record<string, unknown>>(
        `select command.id,command.account_id,command.operation,
                command.target_order_id,command.order_id,command.state,
                command.created_at,command.updated_at,command.egress_started_at,
                reconciliation.status reconciliation_status,
                reconciliation.attempts reconciliation_attempts,
                reconciliation.next_attempt_at,reconciliation.last_error_code,
                count(attempt.id)::bigint attempt_count
           from argus_private.provider_commands command
           left join argus_private.reconciliation_records reconciliation
             on reconciliation.command_id=command.id
            and reconciliation.user_id=command.user_id
           left join argus_private.provider_command_attempts attempt
             on attempt.command_id=command.id and attempt.user_id=command.user_id
          where command.id=$1
          group by command.id,reconciliation.status,reconciliation.attempts,
                   reconciliation.next_attempt_at,reconciliation.last_error_code`,
        [commandId],
      );
      const row = result.rows[0];
      if (row === undefined) {
        throw new BrokerageOrderError("command_not_found");
      }
      const lastError = row.last_error_code === null
        ? null
        : String(row.last_error_code);
      return Object.freeze({
        command: command(row),
        status: row.reconciliation_status === null ? null : row
          .reconciliation_status as BrokerageOrderReconciliation["status"],
        attempts: integer(row.attempt_count, "attempt_count"),
        next_attempt_at: row.next_attempt_at === null
          ? null
          : date(row.next_attempt_at, "next_attempt_at").toISOString(),
        last_error_code:
          lastError !== null && /^[a-z][a-z0-9_]{0,63}$/.test(lastError)
            ? lastError
            : lastError === null
            ? null
            : "provider_error_redacted",
        egress_started_at: date(row.egress_started_at, "egress_started_at")
          .toISOString(),
      });
    },
    recordAccepted: async (prepared, result) => {
      const order = result.order;
      const normalized = parseNormalizedOrderProjection(
        publicListOrder(order),
      );
      const recorded = await database.query<Record<string, unknown>>(
        `select argus_private.record_provider_order_acknowledgement(
           $1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11,$12,$13
         )`,
        [
          prepared.id,
          order.id,
          result.orderReference.ciphertext,
          result.orderReference.hash,
          result.orderReference.keyVersion,
          normalized.instrument_id,
          normalized.state,
          normalized.filled_quantity,
          order.source,
          JSON.stringify(normalized),
          order.provider_observed_at,
          order.fetched_at,
          prepared.normalizedPayloadHash,
        ],
      );
      if (recorded.rows.length !== 1) {
        throw new BrokerageOrderError("provider_contract_unavailable");
      }
      const updated = await database.query<Record<string, unknown>>(
        `select id,account_id,operation,target_order_id,order_id,state,
                created_at,updated_at
           from argus_private.provider_commands
          where id=$1 and user_id=argus_private.trusted_request_user_id()`,
        [prepared.id],
      );
      if (updated.rows[0] === undefined) {
        throw new BrokerageOrderError("command_not_found");
      }
      return command(updated.rows[0]);
    },
    recordRejected: (prepared, providerCode) =>
      finishDispatch(
        prepared,
        "failed",
        "terminal_failure",
        normalizeBrokerageReasonCode(providerCode, "provider_rejected"),
      ),
    recordAmbiguous: (prepared, reasonCode) =>
      finishDispatch(
        prepared,
        "ambiguous",
        "ambiguous",
        normalizeBrokerageReasonCode(reasonCode, "provider_outcome_unknown"),
      ),
    recordBeforeEgressFailure: (prepared, reasonCode) =>
      finishDispatch(
        prepared,
        "failed",
        "terminal_failure",
        normalizeBrokerageReasonCode(
          reasonCode,
          "provider_contract_unavailable",
        ),
      ),
    claimReconciliation: async (commandId) => {
      const result = await database.query<Record<string, unknown>>(
        `select * from argus_private.claim_provider_command_reconciliation($1)`,
        [commandId],
      );
      const row = result.rows[0];
      if (row === undefined) {
        throw new BrokerageOrderError("command_not_found");
      }
      if (row.claim_outcome === "manual_review") return null;
      if (row.claim_outcome !== "claimed") {
        throw new BrokerageOrderError("provider_contract_unavailable");
      }
      return Object.freeze({
        id: String(row.command_id),
        userId: String(row.user_id),
        deletionEpoch: integer(row.deletion_epoch, "deletion_epoch"),
        connectionId: String(row.connection_id),
        accountId: String(row.account_id),
        operation: row.operation as BrokerageOrderOperation,
        targetOrderId: row.target_order_id === null
          ? null
          : String(row.target_order_id),
        clientOrderId: String(row.client_order_id),
        normalizedPayload: row.normalized_payload as NormalizedOrderIntent,
        normalizedPayloadHash: String(row.normalized_payload_hash),
        previewReference: Object.freeze({
          ciphertext: row.provider_preview_ref_ciphertext as Uint8Array,
          hash: String(row.provider_preview_ref_hash),
          keyVersion: integer(
            row.provider_preview_key_version,
            "preview_key_version",
            1,
          ),
        }),
        state: "reconciling" as const,
        duplicate: true,
        egressStartedAt: date(row.egress_started_at, "egress_started_at"),
      });
    },
    recordReconciliationNotFound: async (prepared) => {
      await database.query(
        `select argus_private.record_provider_command_not_found($1)`,
        [prepared.id],
      );
      const updated = await database.query<Record<string, unknown>>(
        `select id,account_id,operation,target_order_id,order_id,state,
                created_at,updated_at
           from argus_private.provider_commands
          where id=$1 and user_id=argus_private.trusted_request_user_id()`,
        [prepared.id],
      );
      if (updated.rows[0] === undefined) {
        throw new BrokerageOrderError("command_not_found");
      }
      return command(updated.rows[0]);
    },
    recordReconciliationAmbiguous: async (prepared, reasonCode) => {
      await database.query(
        `select argus_private.record_provider_command_lookup_ambiguous($1,$2)`,
        [
          prepared.id,
          normalizeBrokerageReasonCode(
            reasonCode,
            "provider_lookup_unavailable",
          ),
        ],
      );
      const updated = await database.query<Record<string, unknown>>(
        `select id,account_id,operation,target_order_id,order_id,state,
                  created_at,updated_at
             from argus_private.provider_commands
            where id=$1 and user_id=argus_private.trusted_request_user_id()`,
        [prepared.id],
      );
      if (updated.rows[0] === undefined) {
        throw new BrokerageOrderError("command_not_found");
      }
      return command(updated.rows[0]);
    },
    recordReconciled: async (prepared, resolution, orderReference, order) => {
      const normalized = parseNormalizedOrderProjection(
        publicListOrder(order),
      );
      await database.query(
        `select argus_private.record_provider_order_reconciliation(
           $1,$2,$3,$4,$5,$6::jsonb,$7,$8,$9,$10,$11,$12
         )`,
        [
          prepared.id,
          resolution,
          order.id,
          normalized.state,
          normalized.filled_quantity,
          JSON.stringify(normalized),
          order.provider_observed_at,
          order.fetched_at,
          orderReference.ciphertext,
          orderReference.hash,
          orderReference.keyVersion,
          normalized.instrument_id,
        ],
      );
      const updated = await database.query<Record<string, unknown>>(
        `select id,account_id,operation,target_order_id,order_id,state,
                created_at,updated_at
           from argus_private.provider_commands
          where id=$1 and user_id=argus_private.trusted_request_user_id()`,
        [prepared.id],
      );
      if (updated.rows[0] === undefined) {
        throw new BrokerageOrderError("command_not_found");
      }
      return command(updated.rows[0]);
    },
    listOrders: async (accountId) => {
      if (!uuidPattern.test(accountId)) {
        throw new BrokerageOrderError("account_not_found");
      }
      const result = await database.query<Record<string, unknown>>(
        `select generation.orders,generation.provider_observed_at,
                generation.fetched_at,generation.expires_at,
                generation.availability,
                connection.status connection_status
           from argus_brokerage.accounts account
           join argus_brokerage.connections connection
             on connection.id=account.connection_id and connection.user_id=account.user_id
           left join lateral (
             select header.provider_observed_at,header.fetched_at,
                    header.expires_at,header.availability,
                    coalesce((
                      select jsonb_agg(
                        argus_private.read_brokerage_order_payload(detail.id)
                        order by detail.order_id
                      )
                      from argus_brokerage.order_projection_generations detail
                      where detail.tenant_id=header.tenant_id
                        and detail.lifecycle_id=header.lifecycle_id
                        and detail.user_id=header.user_id
                        and detail.connection_id=header.connection_id
                        and detail.account_id=header.account_id
                        and detail.source='list'
                        and detail.order_list_generation=header.generation
                        and detail.normalization_state='ready'
                    ),'[]'::jsonb) orders
               from argus_brokerage.projection_generations header
              where header.tenant_id=account.tenant_id
                and header.lifecycle_id=account.lifecycle_id
                and header.user_id=account.user_id
                and header.account_id=account.id
                and header.resource_type='orders'
                and header.normalization_state='ready'
              order by header.generation desc limit 1
           ) generation on true
          where account.id=$1 and account.user_id=argus_private.trusted_request_user_id()`,
        [accountId],
      );
      const row = result.rows[0];
      if (row === undefined) {
        throw new BrokerageOrderError("account_not_found");
      }
      const payload = row.orders;
      if (payload !== null && !Array.isArray(payload)) {
        throw new BrokerageOrderError("provider_contract_unavailable");
      }
      const orders = Object.freeze(
        (payload ?? []).map(parseNormalizedOrderProjection),
      );
      const expiresAt = row.expires_at === null
        ? null
        : date(row.expires_at, "orders_expires_at");
      const state: BrokerageOrderList["state"] =
        row.connection_status === "disconnected"
          ? "disconnected"
          : row.connection_status === "reauthorization_required"
          ? "reauthorization_required"
          : row.orders === null
          ? "unavailable"
          : expiresAt !== null && expiresAt <= new Date()
          ? "stale"
          : row.availability === "partial"
          ? "partial"
          : orders.length === 0
          ? "empty"
          : "fresh";
      return Object.freeze({
        account_id: accountId,
        state,
        provider_observed_at: row.provider_observed_at === null
          ? null
          : date(row.provider_observed_at, "orders_observed_at")
            .toISOString(),
        fetched_at: row.fetched_at === null
          ? null
          : date(row.fetched_at, "orders_fetched_at").toISOString(),
        expires_at: expiresAt?.toISOString() ?? null,
        orders,
      });
    },
    saveOrderList: async (savedAuthority, projection) => {
      const context = savedAuthority.context;
      if (
        context.userId !== verifiedUserId ||
        !uuidPattern.test(context.accountId) ||
        projection.observations.length > 10_000
      ) {
        throw new BrokerageOrderError("provider_contract_unavailable");
      }
      const generationResult = await database.query<{
        result_list_generation: unknown;
      }>(
        `select * from argus_private.begin_brokerage_order_list_ingestion(
             $1,$2,$3
           )`,
        [context.accountId, context.connectionId, context.deletionEpoch],
      );
      const listGeneration = integer(
        generationResult.rows[0]?.result_list_generation,
        "order_list_generation",
        1,
      );
      for (const observation of projection.observations) {
        const order = observation.order;
        const normalized = parseNormalizedOrderProjection(
          publicListOrder(order),
        );
        const reference = observation.orderReference;
        if (
          !uuidPattern.test(order.id) ||
          !uuidPattern.test(order.instrument_id) ||
          order.source !== "list" ||
          !/^[a-f0-9]{64}$/.test(reference.hash) ||
          !Number.isSafeInteger(reference.keyVersion) ||
          reference.keyVersion < 1 ||
          reference.ciphertext.length < 32 ||
          reference.ciphertext.length > 4096
        ) {
          throw new BrokerageOrderError("provider_contract_unavailable");
        }
        await database.query(
          `select argus_private.append_brokerage_order_list_observation(
               $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::jsonb,$13,$14
             )`,
          [
            context.accountId,
            context.connectionId,
            context.deletionEpoch,
            listGeneration,
            order.id,
            reference.ciphertext,
            reference.hash,
            reference.keyVersion,
            normalized.instrument_id,
            normalized.state,
            normalized.filled_quantity,
            JSON.stringify(normalized),
            order.provider_observed_at,
            order.fetched_at,
          ],
        );
      }
      const orders = Object.freeze(
        projection.observations.map((entry) => publicListOrder(entry.order)),
      );
      await database.query(
        `select argus_private.complete_brokerage_order_list_ingestion(
             $1,$2,$3,$4,$5::jsonb,$6,$7,$8,$9,$10
           )`,
        [
          context.accountId,
          context.connectionId,
          context.deletionEpoch,
          listGeneration,
          JSON.stringify(orders),
          projection.providerObservedAt,
          projection.fetchedAt,
          projection.expiresAt,
          projection.availability,
          projection.reasonCode ?? null,
        ],
      );
      return Object.freeze({
        account_id: context.accountId,
        state: projection.availability === "partial"
          ? "partial" as const
          : orders.length === 0
          ? "empty" as const
          : "fresh" as const,
        provider_observed_at: projection.providerObservedAt?.toISOString() ??
          null,
        fetched_at: projection.fetchedAt.toISOString(),
        expires_at: projection.expiresAt.toISOString(),
        orders,
      });
    },
    order: async (accountId, orderId) => {
      if (!uuidPattern.test(accountId) || !uuidPattern.test(orderId)) {
        throw new BrokerageOrderError("order_not_found");
      }
      const result = await database.query<Record<string, unknown>>(
        `select generation.generation,generation.source,
                argus_private.read_brokerage_order_payload(
                  generation.id
                ) payload,
                generation.provider_observed_at,generation.fetched_at
           from argus_brokerage.order_projection_generations generation
          where generation.account_id=$1 and generation.order_id=$2
            and generation.user_id=argus_private.trusted_request_user_id()
            and generation.normalization_state='ready'
          order by generation.generation desc limit 1`,
        [accountId, orderId],
      );
      const row = result.rows[0];
      if (row === undefined) throw new BrokerageOrderError("order_not_found");
      return Object.freeze({
        ...parseNormalizedOrderProjection(row.payload),
        generation: integer(row.generation, "order_generation", 1),
        source: row.source as "list" | "detail",
        provider_observed_at: date(
          row.provider_observed_at,
          "order_observed_at",
        ).toISOString(),
        fetched_at: date(row.fetched_at, "order_fetched_at").toISOString(),
      });
    },
  };
  return Object.freeze(repository);
}

import { z } from "@hono/zod-openapi";

import {
  nullableTimestampSchema,
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";

const brokerageStateSchema = z.enum([
  "fresh",
  "empty",
  "stale",
  "partial",
  "unavailable",
  "offline",
  "rate_limited",
  "disconnected",
  "reauthorization_required",
]);
const brokerageCapabilitySchema = z.object({
  capability: z.enum([
    "balances_read",
    "positions_read",
    "orders_read",
    "manual_orders",
    "unsupported",
  ]),
  provider_code: z.string().min(1).max(128),
  available: z.boolean(),
}).strict().openapi("BrokerageCapability");
const brokerageAccountSchema = z.object({
  id: uuidSchema,
  connection_id: uuidSchema,
  display_label: z.string().min(1).max(160),
  base_currency: z.string().regex(/^[A-Z]{3}$/),
  market_timezone: z.string().min(1).max(64).nullable(),
  status: z.enum(["available", "restricted", "closed", "unavailable"]),
  capability_version: z.number().int().nonnegative(),
  capabilities: z.array(brokerageCapabilitySchema).max(64),
  state: brokerageStateSchema,
  selected: z.boolean(),
  provider_observed_at: nullableTimestampSchema,
  fetched_at: nullableTimestampSchema,
  expires_at: nullableTimestampSchema,
}).strict().openapi("BrokerageAccount");
const brokerageAccountAuthoritySchema = z.object({
  display_label: z.string().min(1).max(160),
  base_currency: z.string().regex(/^[A-Z]{3}$/),
  market_timezone: z.string().min(1).max(64),
  status: z.enum(["available", "restricted", "closed", "unavailable"]),
  capability_version: z.number().int().nonnegative(),
  capabilities: z.array(brokerageCapabilitySchema).max(64),
}).strict().openapi("BrokerageAccountAuthority");
const decimalStringSchema = z.string().regex(
  /^-?(?:0|[1-9]\d*)(?:\.\d{1,18})?$/,
);
const brokerageBalanceSchema = z.object({
  currency: z.string().regex(/^[A-Z]{3}$/),
  cash: decimalStringSchema,
  buying_power: decimalStringSchema.nullable(),
  market_value: decimalStringSchema.nullable(),
  total_equity: decimalStringSchema,
}).strict().openapi("BrokerageBalance");
const brokerageAssetSchema = z.object({
  instrument_id: uuidSchema,
  symbol: z.string().min(1).max(32),
  name: z.string().min(1).max(160),
  asset_kind: z.enum(["equity", "etf", "unsupported"]),
  provider_asset_kind: z.string().min(1).max(128),
  supported: z.boolean(),
  currency: z.string().regex(/^[A-Z]{3}$/),
  exchange: z.string().max(32).nullable(),
  market_timezone: z.string().min(1).max(64),
}).strict().openapi("BrokerageAsset");
const brokeragePositionSchema = z.object({
  asset: brokerageAssetSchema,
  quantity: decimalStringSchema,
  available_quantity: decimalStringSchema,
  average_cost: decimalStringSchema.nullable(),
  market_value: decimalStringSchema.nullable(),
  currency: z.string().regex(/^[A-Z]{3}$/),
}).strict().openapi("BrokeragePosition");
const brokerageRestrictionSchema = z.object({
  restriction: z.enum([
    "closing_only",
    "trading_disabled",
    "liquidation_only",
    "unsupported",
  ]),
  provider_code: z.string().min(1).max(128),
  active: z.boolean(),
  detail: z.string().max(256).nullable(),
}).strict().openapi("BrokerageRestriction");

function brokerageProjectionResponseSchema(name: string, data: z.ZodType) {
  return z.object({
    account_id: uuidSchema,
    resource: z.enum(["account", "balance", "positions", "restrictions"]),
    generation: z.number().int().positive().nullable(),
    state: brokerageStateSchema,
    reason: z.string().max(64).nullable(),
    provider_observed_at: nullableTimestampSchema,
    fetched_at: nullableTimestampSchema,
    expires_at: nullableTimestampSchema,
    data: data.nullable(),
  }).strict().openapi(name);
}

const memberStepUpReceiptSchema = z.object({
  receipt: z.string().min(32).max(512).regex(/^[A-Za-z0-9_-]+$/),
  action: z.enum(["webull_disconnect", "argus_delete"]),
  user_id: uuidSchema,
  session_id: uuidSchema,
  expires_at: z.string().datetime(),
}).strict().openapi("MemberStepUpReceipt");
export const memberStepUpReceiptResponseSchema = retainedEnvelope(
  "MemberStepUpReceiptResponse",
  memberStepUpReceiptSchema,
);
const webullAuthorizationSessionSchema = z.object({
  connection_id: uuidSchema,
  authorization_url: z.string().url().refine((value) =>
    value.startsWith("https://")
  ),
  expires_at: z.string().datetime(),
}).strict().openapi("WebullAuthorizationSession");
export const webullAuthorizationSessionResponseSchema = retainedEnvelope(
  "WebullAuthorizationSessionResponse",
  webullAuthorizationSessionSchema,
);
const webullConnectionSchema = z.object({
  id: uuidSchema.nullable().optional(),
  status: z.enum([
    "disconnected",
    "pending",
    "connected",
    "denied",
    "failed",
    "temporarily_unavailable",
    "reauthorization_required",
  ]),
  capability_version: z.number().int().nonnegative().nullable().optional(),
  authorized_at: nullableTimestampSchema.optional(),
  disconnected_at: nullableTimestampSchema.optional(),
  last_error_code: z.string().min(1).max(128).nullable().optional(),
  updated_at: nullableTimestampSchema.optional(),
}).strict().openapi("WebullConnection");
export const webullConnectionResponseSchema = retainedEnvelope(
  "WebullConnectionResponse",
  webullConnectionSchema,
);
const webullAccountSelectionSchema = z.object({
  account_id: uuidSchema,
  selected: z.literal(true),
}).strict().openapi("WebullAccountSelection");
export const webullAccountSelectionResponseSchema = retainedEnvelope(
  "WebullAccountSelectionResponse",
  webullAccountSelectionSchema,
);
const webullCompletionSchema = z.object({
  connection_id: uuidSchema,
  outcome: z.enum(["connected", "denied", "failed", "temporarily_unavailable"]),
  created_at: z.string().datetime(),
}).strict().openapi("WebullCompletion");
export const webullCompletionResponseSchema = retainedEnvelope(
  "WebullCompletionResponse",
  webullCompletionSchema,
);
const webullDisconnectSchema = z.object({
  connection_id: uuidSchema,
  status: z.literal("disconnected"),
  provider_grant_revoked: z.literal(false),
}).strict().openapi("WebullDisconnectReceipt");
export const webullDisconnectResponseSchema = retainedEnvelope(
  "WebullDisconnectResponse",
  webullDisconnectSchema,
);
export const brokerageAccountsResponseSchema = retainedEnvelope(
  "BrokerageAccountsResponse",
  z.array(brokerageAccountSchema).max(100),
);
export const brokerageCapabilitiesResponseSchema = retainedEnvelope(
  "BrokerageCapabilitiesResponse",
  brokerageProjectionResponseSchema(
    "BrokerageCapabilitiesProjection",
    brokerageAccountAuthoritySchema,
  ),
);
export const brokerageBalancesResponseSchema = retainedEnvelope(
  "BrokerageBalancesResponse",
  brokerageProjectionResponseSchema(
    "BrokerageBalancesProjection",
    brokerageBalanceSchema,
  ),
);
export const brokeragePositionsResponseSchema = retainedEnvelope(
  "BrokeragePositionsResponse",
  brokerageProjectionResponseSchema(
    "BrokeragePositionsProjection",
    z.array(brokeragePositionSchema).max(10_000),
  ),
);
export const brokerageRestrictionsResponseSchema = retainedEnvelope(
  "BrokerageRestrictionsResponse",
  brokerageProjectionResponseSchema(
    "BrokerageRestrictionsProjection",
    z.array(brokerageRestrictionSchema).max(256),
  ),
);
const brokerageOrderStateSchema = z.enum([
  "pending",
  "partially_filled",
  "filled",
  "cancelled",
  "rejected",
  "expired",
  "unknown",
]);
const brokerageOrderSchema = z.object({
  id: uuidSchema,
  instrument_id: uuidSchema,
  symbol: z.string().min(1).max(32),
  side: z.enum(["buy", "sell", "unsupported"]),
  provider_side: z.string().min(1).max(128),
  order_type: z.enum(["market", "limit", "stop", "stop_limit", "unsupported"]),
  provider_order_type: z.string().min(1).max(128),
  time_in_force: z.enum(["day", "gtc", "unsupported"]),
  provider_time_in_force: z.string().min(1).max(128),
  quantity: decimalStringSchema,
  filled_quantity: decimalStringSchema,
  limit_price: decimalStringSchema.nullable(),
  stop_price: decimalStringSchema.nullable(),
  average_fill_price: decimalStringSchema.nullable(),
  currency: z.string().regex(/^[A-Z]{3}$/),
  state: brokerageOrderStateSchema,
  provider_state: z.string().min(1).max(128),
  terminal: z.boolean(),
}).strict().openapi("BrokerageOrder");
const brokerageOrderDetailSchema = brokerageOrderSchema.extend({
  generation: z.number().int().positive(),
  source: z.enum(["list", "detail"]),
  provider_observed_at: z.string().datetime(),
  fetched_at: z.string().datetime(),
}).strict().openapi("BrokerageOrderDetail");
export const brokerageOrdersResponseSchema = retainedEnvelope(
  "BrokerageOrdersResponse",
  z.object({
    account_id: uuidSchema,
    state: brokerageStateSchema,
    provider_observed_at: nullableTimestampSchema,
    fetched_at: nullableTimestampSchema,
    expires_at: nullableTimestampSchema,
    orders: z.array(brokerageOrderSchema).max(10_000),
  }).strict().openapi("BrokerageOrderList"),
);
export const brokerageOrderDetailResponseSchema = retainedEnvelope(
  "BrokerageOrderDetailResponse",
  brokerageOrderDetailSchema,
);
export const placeOrderIntentSchema = z.object({
  instrument_id: uuidSchema,
  side: z.enum(["buy", "sell"]),
  order_type: z.enum(["market", "limit"]),
  time_in_force: z.literal("day"),
  quantity: decimalStringSchema,
  limit_price: decimalStringSchema.nullable(),
}).strict().openapi("PlaceBrokerageOrderIntent");
export const modifyOrderIntentSchema = z.object({
  quantity: decimalStringSchema,
  limit_price: decimalStringSchema.nullable(),
}).strict().openapi("ModifyBrokerageOrderIntent");
const brokerageOrderPreviewSchema = z.object({
  id: uuidSchema,
  account_id: uuidSchema,
  operation: z.enum(["place", "modify", "cancel"]),
  target_order_id: uuidSchema.nullable(),
  policy_version: z.string().min(8).max(128),
  capability_version: z.number().int().nonnegative(),
  restriction_generation: z.number().int().positive(),
  reviewed_payload_hash: z.string().regex(/^[a-f0-9]{64}$/),
  estimated_total: decimalStringSchema.nullable(),
  currency: z.string().regex(/^[A-Z]{3}$/).nullable(),
  expires_at: z.string().datetime(),
}).strict().openapi("BrokerageOrderPreview");
export const brokerageOrderPreviewResponseSchema = retainedEnvelope(
  "BrokerageOrderPreviewResponse",
  brokerageOrderPreviewSchema,
);
export const confirmPlaceOrderSchema = z.object({
  preview_id: uuidSchema,
  confirmed: z.literal(true),
  intent: placeOrderIntentSchema,
}).strict().openapi("ConfirmPlaceBrokerageOrder");
export const confirmModifyOrderSchema = z.object({
  preview_id: uuidSchema,
  confirmed: z.literal(true),
  intent: modifyOrderIntentSchema,
}).strict().openapi("ConfirmModifyBrokerageOrder");
export const confirmCancelOrderSchema = z.object({
  preview_id: uuidSchema,
  confirmed: z.literal(true),
}).strict().openapi("ConfirmCancelBrokerageOrder");
const brokerageCommandStateSchema = z.enum([
  "dispatching",
  "accepted",
  "ambiguous",
  "reconciling",
  "resolved",
  "failed",
  "manual_review",
]);
const brokerageOrderCommandSchema = z.object({
  id: uuidSchema,
  account_id: uuidSchema,
  operation: z.enum(["place", "modify", "cancel"]),
  target_order_id: uuidSchema.nullable(),
  order_id: uuidSchema.nullable(),
  state: brokerageCommandStateSchema,
  ambiguous: z.boolean(),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
}).strict().openapi("BrokerageOrderCommand");
export const brokerageOrderCommandResponseSchema = retainedEnvelope(
  "BrokerageOrderCommandResponse",
  brokerageOrderCommandSchema,
);
export const brokerageOrderReconciliationResponseSchema = retainedEnvelope(
  "BrokerageOrderReconciliationResponse",
  z.object({
    command: brokerageOrderCommandSchema,
    status: z.enum([
      "pending",
      "running",
      "resolved",
      "manual_review",
      "exhausted",
    ]).nullable(),
    attempts: z.number().int().nonnegative(),
    next_attempt_at: nullableTimestampSchema,
    last_error_code: z.string().max(64).nullable(),
    egress_started_at: z.string().datetime(),
  }).strict().openapi("BrokerageOrderReconciliation"),
);

export const stepUpBodySchema = z.object({
  action: z.enum(["webull_disconnect", "argus_delete"]),
}).strict();
export const connectionStartBodySchema = z.object({
  return_target: z.enum(["webull_https", "webull_native"]),
}).strict();
export const selectAccountBodySchema = z.object({ account_id: uuidSchema })
  .strict();
export const completionBodySchema = z.object({
  completion: z.string().min(43).max(128).regex(/^[A-Za-z0-9_-]+$/),
}).strict();
export const disconnectBodySchema = z.object({
  step_up_receipt: z.string().min(32).max(512).regex(/^[A-Za-z0-9_-]+$/),
}).strict();

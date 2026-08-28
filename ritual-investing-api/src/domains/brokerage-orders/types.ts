import type { NormalizedRestriction } from "../brokerage-accounts/normalization.ts";
import type { NormalizedCapability } from "../brokerage-accounts/normalization.ts";
import type { BrokerageAccountContext } from "../brokerage-projections/types.ts";

export const BROKERAGE_ORDER_POLICY_VERSION =
  "webull-sandbox-manual-v1" as const;

export type BrokerageOrderOperation = "place" | "modify" | "cancel";
export type BrokerageOrderState =
  | "pending"
  | "partially_filled"
  | "filled"
  | "cancelled"
  | "rejected"
  | "expired"
  | "unknown";

export type BrokerageOrderCommandState =
  | "dispatching"
  | "accepted"
  | "ambiguous"
  | "reconciling"
  | "resolved"
  | "failed"
  | "manual_review";

export type NormalizedPlaceOrderIntent = Readonly<{
  instrument_id: string;
  side: "buy" | "sell";
  order_type: "market" | "limit";
  time_in_force: "day";
  quantity: string;
  limit_price: string | null;
}>;

export type NormalizedModifyOrderIntent = Readonly<{
  target_order_id: string;
  quantity: string;
  limit_price: string | null;
}>;

export type NormalizedCancelOrderIntent = Readonly<{
  target_order_id: string;
}>;

export type NormalizedOrderIntent =
  | NormalizedPlaceOrderIntent
  | NormalizedModifyOrderIntent
  | NormalizedCancelOrderIntent;

export type BrokerageOrderAuthority = Readonly<{
  context: BrokerageAccountContext;
  accountExpiresAt: Date | null;
  capabilities: readonly NormalizedCapability[];
  restrictionGeneration: number | null;
  restrictionExpiresAt: Date | null;
  restrictionAvailability: "available" | "partial" | "stale" | "unavailable";
  restrictions: readonly NormalizedRestriction[];
}>;

export type OwnedOrderTarget = Readonly<{
  orderId: string;
  accountId: string;
  instrumentId: string;
  state: BrokerageOrderState;
}>;

export type SealedProviderReference = Readonly<{
  ciphertext: Uint8Array;
  hash: string;
  keyVersion: number;
}>;

export type ProviderOrderPreview = Readonly<{
  reference: SealedProviderReference;
  expiresAt: Date;
  estimatedTotal: string | null;
  currency: string | null;
}>;

export type BrokerageOrderPreview = Readonly<{
  id: string;
  account_id: string;
  operation: BrokerageOrderOperation;
  target_order_id: string | null;
  policy_version: typeof BROKERAGE_ORDER_POLICY_VERSION;
  capability_version: number;
  restriction_generation: number;
  reviewed_payload_hash: string;
  estimated_total: string | null;
  currency: string | null;
  expires_at: string;
}>;

export type PreparedOrderCommand = Readonly<{
  id: string;
  userId: string;
  deletionEpoch: number;
  connectionId: string;
  accountId: string;
  operation: BrokerageOrderOperation;
  targetOrderId: string | null;
  clientOrderId: string;
  normalizedPayload: NormalizedOrderIntent;
  normalizedPayloadHash: string;
  previewReference: SealedProviderReference;
  state: BrokerageOrderCommandState;
  duplicate: boolean;
  egressStartedAt: Date;
}>;

export type BrokerageOrderCommand = Readonly<{
  id: string;
  account_id: string;
  operation: BrokerageOrderOperation;
  target_order_id: string | null;
  order_id: string | null;
  state: BrokerageOrderCommandState;
  ambiguous: boolean;
  created_at: string;
  updated_at: string;
}>;

export type BrokerageOrderReconciliation = Readonly<{
  command: BrokerageOrderCommand;
  status:
    | "pending"
    | "running"
    | "resolved"
    | "manual_review"
    | "exhausted"
    | null;
  attempts: number;
  next_attempt_at: string | null;
  last_error_code: string | null;
  egress_started_at: string;
}>;

export type NormalizedBrokerageOrder = Readonly<{
  id: string;
  instrument_id: string;
  symbol: string;
  side: "buy" | "sell" | "unsupported";
  provider_side: string;
  order_type: "market" | "limit" | "stop" | "stop_limit" | "unsupported";
  provider_order_type: string;
  time_in_force: "day" | "gtc" | "unsupported";
  provider_time_in_force: string;
  quantity: string;
  filled_quantity: string;
  limit_price: string | null;
  stop_price: string | null;
  average_fill_price: string | null;
  currency: string;
  state: BrokerageOrderState;
  provider_state: string;
  terminal: boolean;
}>;

export type BrokerageOrderDetail =
  & NormalizedBrokerageOrder
  & Readonly<{
    generation: number;
    source: "list" | "detail";
    provider_observed_at: string;
    fetched_at: string;
  }>;

export type BrokerageOrderList = Readonly<{
  account_id: string;
  state:
    | "fresh"
    | "empty"
    | "stale"
    | "partial"
    | "unavailable"
    | "offline"
    | "rate_limited"
    | "disconnected"
    | "reauthorization_required";
  provider_observed_at: string | null;
  fetched_at: string | null;
  expires_at: string | null;
  orders: readonly NormalizedBrokerageOrder[];
}>;

export type ProviderOrderObservation = Readonly<{
  orderReference: SealedProviderReference;
  order: BrokerageOrderDetail;
}>;

export type ProviderOrderListProjection = Readonly<{
  observations: readonly ProviderOrderObservation[];
  providerObservedAt: Date | null;
  fetchedAt: Date;
  expiresAt: Date;
  availability: "available" | "partial";
  reasonCode?: string;
}>;

export type ProviderCommandResult = Readonly<
  | {
    kind: "acknowledged";
    orderReference: SealedProviderReference;
    order: BrokerageOrderDetail;
  }
  | { kind: "rejected"; providerCode: string }
  | { kind: "ambiguous"; reasonCode: string }
>;

export type ProviderDetailResult = Readonly<
  | {
    kind: "resolved";
    resolution:
      | "applied"
      | "authoritative_not_applied"
      | "superseded_by_fill";
    orderReference: SealedProviderReference;
    order: BrokerageOrderDetail;
  }
  | { kind: "not_found" }
  | { kind: "ambiguous"; reasonCode: string }
>;

export class BrokerageOrderError extends Error {
  readonly code:
    | "account_not_found"
    | "order_not_found"
    | "command_not_found"
    | "brokerage_authority_stale"
    | "brokerage_restricted"
    | "capability_unavailable"
    | "unsupported_order"
    | "preview_expired"
    | "preview_replayed"
    | "preview_mismatch"
    | "idempotency_conflict"
    | "account_command_blocked"
    | "provider_contract_unavailable";
  readonly beforeEgress: boolean;

  constructor(
    code:
      | "account_not_found"
      | "order_not_found"
      | "command_not_found"
      | "brokerage_authority_stale"
      | "brokerage_restricted"
      | "capability_unavailable"
      | "unsupported_order"
      | "preview_expired"
      | "preview_replayed"
      | "preview_mismatch"
      | "idempotency_conflict"
      | "account_command_blocked"
      | "provider_contract_unavailable",
    beforeEgress = false,
  ) {
    super(code);
    this.name = "BrokerageOrderError";
    this.code = code;
    this.beforeEgress = beforeEgress;
  }
}

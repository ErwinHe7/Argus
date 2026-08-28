import {
  canonicalDecimal,
  normalizedCurrency,
  normalizedProviderCode,
  normalizedProviderTimestamp,
} from "../brokerage-assets/normalization.ts";
import {
  type BrokerageOrderState,
  type NormalizedBrokerageOrder,
  type NormalizedCancelOrderIntent,
  type NormalizedModifyOrderIntent,
  type NormalizedPlaceOrderIntent,
} from "./types.ts";
import { BrokerageOrderError } from "./types.ts";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const symbolPattern = /^[A-Z0-9][A-Z0-9.-]{0,31}$/;
const unsafeDisplayText = /[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]/;

function exactKeys(
  value: Record<string, unknown>,
  expected: readonly string[],
): boolean {
  return Object.keys(value).sort().join("\u001f") ===
    [...expected].sort().join("\u001f");
}

function compareNonnegativeDecimals(left: string, right: string): number {
  const [leftInteger, leftFraction = ""] = left.split(".");
  const [rightInteger, rightFraction = ""] = right.split(".");
  if (
    leftInteger === undefined || rightInteger === undefined ||
    left.startsWith("-") || right.startsWith("-")
  ) {
    throw new BrokerageOrderError("provider_contract_unavailable");
  }
  if (leftInteger.length !== rightInteger.length) {
    return leftInteger.length < rightInteger.length ? -1 : 1;
  }
  if (leftInteger !== rightInteger) return leftInteger < rightInteger ? -1 : 1;
  const length = Math.max(leftFraction.length, rightFraction.length);
  const normalizedLeft = leftFraction.padEnd(length, "0");
  const normalizedRight = rightFraction.padEnd(length, "0");
  if (normalizedLeft === normalizedRight) return 0;
  return normalizedLeft < normalizedRight ? -1 : 1;
}

function positiveWholeQuantity(value: unknown): string {
  let normalized: string;
  try {
    normalized = canonicalDecimal(value);
  } catch {
    throw new BrokerageOrderError("unsupported_order");
  }
  if (
    normalized.startsWith("-") || normalized === "0" || normalized.includes(".")
  ) {
    throw new BrokerageOrderError("unsupported_order");
  }
  return normalized;
}

function positivePrice(value: unknown): string {
  let normalized: string;
  try {
    normalized = canonicalDecimal(value);
  } catch {
    throw new BrokerageOrderError("unsupported_order");
  }
  if (normalized.startsWith("-") || normalized === "0") {
    throw new BrokerageOrderError("unsupported_order");
  }
  return normalized;
}

export function normalizePlaceOrderIntent(
  value: unknown,
): NormalizedPlaceOrderIntent {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BrokerageOrderError("unsupported_order");
  }
  const input = value as Record<string, unknown>;
  if (
    !exactKeys(input, [
      "instrument_id",
      "side",
      "order_type",
      "time_in_force",
      "quantity",
      "limit_price",
    ]) ||
    !uuidPattern.test(String(input.instrument_id)) ||
    !["buy", "sell"].includes(String(input.side)) ||
    !["market", "limit"].includes(String(input.order_type)) ||
    input.time_in_force !== "day"
  ) {
    throw new BrokerageOrderError("unsupported_order");
  }
  const orderType = input.order_type as "market" | "limit";
  const limitPrice =
    input.limit_price === null || input.limit_price === undefined
      ? null
      : positivePrice(input.limit_price);
  if (
    (orderType === "limit" && limitPrice === null) ||
    (orderType === "market" && limitPrice !== null)
  ) {
    throw new BrokerageOrderError("unsupported_order");
  }
  return Object.freeze({
    instrument_id: String(input.instrument_id).toLowerCase(),
    side: input.side as "buy" | "sell",
    order_type: orderType,
    time_in_force: "day" as const,
    quantity: positiveWholeQuantity(input.quantity),
    limit_price: limitPrice,
  });
}

export function normalizeModifyOrderIntent(
  targetOrderId: string,
  value: unknown,
): NormalizedModifyOrderIntent {
  if (
    !uuidPattern.test(targetOrderId) ||
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    throw new BrokerageOrderError("unsupported_order");
  }
  const input = value as Record<string, unknown>;
  if (!exactKeys(input, ["quantity", "limit_price"])) {
    throw new BrokerageOrderError("unsupported_order");
  }
  return Object.freeze({
    target_order_id: targetOrderId.toLowerCase(),
    quantity: positiveWholeQuantity(input.quantity),
    limit_price: input.limit_price === null || input.limit_price === undefined
      ? null
      : positivePrice(input.limit_price),
  });
}

export function normalizeCancelOrderIntent(
  targetOrderId: string,
): NormalizedCancelOrderIntent {
  if (!uuidPattern.test(targetOrderId)) {
    throw new BrokerageOrderError("unsupported_order");
  }
  return Object.freeze({ target_order_id: targetOrderId.toLowerCase() });
}

const sideMap = new Map(
  [
    ["BUY", "buy"],
    ["SELL", "sell"],
  ] as const,
);
const typeMap = new Map(
  [
    ["MARKET", "market"],
    ["LIMIT", "limit"],
    ["STOP", "stop"],
    ["STOP_LIMIT", "stop_limit"],
  ] as const,
);
const timeInForceMap = new Map(
  [
    ["DAY", "day"],
    ["GTC", "gtc"],
  ] as const,
);
const stateMap = new Map(
  [
    ["PENDING", "pending"],
    ["SUBMITTED", "pending"],
    ["PARTIALLY_FILLED", "partially_filled"],
    ["FILLED", "filled"],
    ["CANCELLED", "cancelled"],
    ["CANCELED", "cancelled"],
    ["REJECTED", "rejected"],
    ["EXPIRED", "expired"],
  ] as const,
);

function nullableDecimal(value: unknown): string | null {
  return value === null || value === undefined ? null : canonicalDecimal(value);
}

/**
 * Normalizes versioned provider fixtures without exposing either provider
 * order or asset identifiers. Unknown enums survive as provider codes and
 * never gain supported or terminal semantics.
 */
export function normalizeProviderOrder(
  value: unknown,
  input: Readonly<{
    mapOrderId: (providerOrderId: string) => string;
    mapAssetId: (providerAssetId: string) => string;
    fetchedAt: Date;
  }>,
): NormalizedBrokerageOrder & Readonly<{ provider_observed_at: string }> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BrokerageOrderError("provider_contract_unavailable");
  }
  const record = value as Record<string, unknown>;
  if (
    !exactKeys(record, [
      "provider_order_id",
      "provider_asset_id",
      "symbol",
      "side",
      "order_type",
      "time_in_force",
      "quantity",
      "filled_quantity",
      "limit_price",
      "stop_price",
      "average_fill_price",
      "currency",
      "state",
      "provider_observed_at",
    ])
  ) {
    throw new BrokerageOrderError("provider_contract_unavailable");
  }
  const providerOrderId = normalizedProviderCode(record.provider_order_id);
  const providerAssetId = normalizedProviderCode(record.provider_asset_id);
  const orderId = input.mapOrderId(providerOrderId);
  const instrumentId = input.mapAssetId(providerAssetId);
  const providerSide = normalizedProviderCode(record.side);
  const providerType = normalizedProviderCode(record.order_type);
  const providerTimeInForce = normalizedProviderCode(record.time_in_force);
  const providerState = normalizedProviderCode(record.state);
  if (
    !uuidPattern.test(orderId) ||
    !uuidPattern.test(instrumentId) ||
    typeof record.symbol !== "string" ||
    !symbolPattern.test(record.symbol) ||
    unsafeDisplayText.test(record.symbol)
  ) {
    throw new BrokerageOrderError("provider_contract_unavailable");
  }
  const state = stateMap.get(
    providerState as
      | "PENDING"
      | "SUBMITTED"
      | "PARTIALLY_FILLED"
      | "FILLED"
      | "CANCELLED"
      | "CANCELED"
      | "REJECTED"
      | "EXPIRED",
  ) ?? "unknown";
  const terminal: readonly BrokerageOrderState[] = [
    "filled",
    "cancelled",
    "rejected",
    "expired",
  ];
  const quantity = canonicalDecimal(record.quantity);
  const filledQuantity = canonicalDecimal(record.filled_quantity);
  if (
    compareNonnegativeDecimals(quantity, "0") <= 0 ||
    compareNonnegativeDecimals(filledQuantity, "0") < 0 ||
    compareNonnegativeDecimals(filledQuantity, quantity) > 0
  ) {
    throw new BrokerageOrderError("provider_contract_unavailable");
  }
  return Object.freeze({
    id: orderId.toLowerCase(),
    instrument_id: instrumentId.toLowerCase(),
    symbol: record.symbol,
    side: sideMap.get(providerSide as "BUY" | "SELL") ?? "unsupported",
    provider_side: providerSide,
    order_type: typeMap.get(
      providerType as "MARKET" | "LIMIT" | "STOP" | "STOP_LIMIT",
    ) ?? "unsupported",
    provider_order_type: providerType,
    time_in_force: timeInForceMap.get(providerTimeInForce as "DAY" | "GTC") ??
      "unsupported",
    provider_time_in_force: providerTimeInForce,
    quantity,
    filled_quantity: filledQuantity,
    limit_price: nullableDecimal(record.limit_price),
    stop_price: nullableDecimal(record.stop_price),
    average_fill_price: nullableDecimal(record.average_fill_price),
    currency: normalizedCurrency(record.currency),
    state,
    provider_state: providerState,
    terminal: terminal.includes(state),
    provider_observed_at: normalizedProviderTimestamp(
      record.provider_observed_at,
      input.fetchedAt,
    ),
  });
}

export function assertMonotonicOrderProjection(
  previous:
    | Readonly<{
      state: BrokerageOrderState;
      filledQuantity: string;
      providerObservedAt: Date;
      source: "list" | "detail";
    }>
    | null,
  next: Readonly<{
    state: BrokerageOrderState;
    filledQuantity: string;
    providerObservedAt: Date;
    source: "list" | "detail";
  }>,
): void {
  if (previous === null) return;
  const ranks: Record<BrokerageOrderState, number> = {
    unknown: 0,
    pending: 10,
    partially_filled: 20,
    rejected: 30,
    expired: 30,
    cancelled: 30,
    filled: 40,
  };
  const staleTimestamp = next.providerObservedAt < previous.providerObservedAt;
  const listCannotReplaceDetail = next.providerObservedAt.getTime() ===
      previous.providerObservedAt.getTime() &&
    previous.source === "detail" && next.source === "list";
  if (
    staleTimestamp ||
    listCannotReplaceDetail ||
    ranks[next.state] < ranks[previous.state] ||
    compareNonnegativeDecimals(next.filledQuantity, previous.filledQuantity) < 0
  ) {
    throw new BrokerageOrderError("provider_contract_unavailable");
  }
}

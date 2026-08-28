import {
  BrokerageReadContractError,
  normalizedCurrency,
  normalizedMarketTimezone,
  normalizedProviderCode,
} from "../brokerage-assets/normalization.ts";

export type NormalizedCapability = Readonly<{
  capability:
    | "balances_read"
    | "positions_read"
    | "orders_read"
    | "manual_orders"
    | "unsupported";
  provider_code: string;
  available: boolean;
}>;

const capabilityMap = new Map(
  [
    ["BALANCES_READ", "balances_read"],
    ["POSITIONS_READ", "positions_read"],
    ["ORDERS_READ", "orders_read"],
    ["MANUAL_ORDERS", "manual_orders"],
  ] as const,
);

export function normalizeCapability(value: unknown): NormalizedCapability {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BrokerageReadContractError("invalid_provider_capability");
  }
  const input = value as Record<string, unknown>;
  const providerCode = normalizedProviderCode(input.code);
  if (typeof input.available !== "boolean") {
    throw new BrokerageReadContractError("invalid_provider_capability");
  }
  const capability = capabilityMap.get(
    providerCode as
      | "BALANCES_READ"
      | "POSITIONS_READ"
      | "ORDERS_READ"
      | "MANUAL_ORDERS",
  );
  return Object.freeze({
    capability: capability ?? "unsupported",
    provider_code: providerCode,
    // Unknown provider capabilities are preserved but can never accidentally
    // opt the account into an Argus action.
    available: capability === undefined ? false : input.available,
  });
}

export type NormalizedRestriction = Readonly<{
  restriction:
    | "closing_only"
    | "trading_disabled"
    | "liquidation_only"
    | "unsupported";
  provider_code: string;
  active: boolean;
  detail: string | null;
}>;

const restrictionMap = new Map(
  [
    ["CLOSING_ONLY", "closing_only"],
    ["TRADING_DISABLED", "trading_disabled"],
    ["LIQUIDATION_ONLY", "liquidation_only"],
  ] as const,
);
const unsafeDisplayText = /[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]/;

export function normalizeRestriction(value: unknown): NormalizedRestriction {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BrokerageReadContractError("invalid_provider_restriction");
  }
  const input = value as Record<string, unknown>;
  const providerCode = normalizedProviderCode(input.code);
  if (
    typeof input.active !== "boolean" ||
    (input.detail !== null &&
      (typeof input.detail !== "string" ||
        input.detail.length > 256 ||
        unsafeDisplayText.test(input.detail)))
  ) {
    throw new BrokerageReadContractError("invalid_provider_restriction");
  }
  return Object.freeze({
    restriction: restrictionMap.get(
      providerCode as
        | "CLOSING_ONLY"
        | "TRADING_DISABLED"
        | "LIQUIDATION_ONLY",
    ) ?? "unsupported",
    provider_code: providerCode,
    active: input.active,
    detail: input.detail,
  });
}

export type NormalizedAccount = Readonly<{
  display_label: string;
  base_currency: string;
  market_timezone: string;
  status: "available" | "restricted" | "closed" | "unavailable";
  capability_version: number;
  capabilities: readonly NormalizedCapability[];
}>;

export function normalizeAccount(value: unknown): NormalizedAccount {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BrokerageReadContractError("invalid_provider_account");
  }
  const input = value as Record<string, unknown>;
  if (
    typeof input.display_label !== "string" ||
    input.display_label.length < 1 ||
    input.display_label.length > 160 ||
    unsafeDisplayText.test(input.display_label) ||
    !["available", "restricted", "closed", "unavailable"].includes(
      String(input.status),
    ) ||
    !Number.isSafeInteger(input.capability_version) ||
    Number(input.capability_version) < 0 ||
    !Array.isArray(input.capabilities) ||
    input.capabilities.length > 64
  ) {
    throw new BrokerageReadContractError("invalid_provider_account");
  }
  return Object.freeze({
    display_label: input.display_label,
    base_currency: normalizedCurrency(input.base_currency),
    market_timezone: normalizedMarketTimezone(input.market_timezone),
    status: input.status as NormalizedAccount["status"],
    capability_version: Number(input.capability_version),
    capabilities: Object.freeze(input.capabilities.map(normalizeCapability)),
  });
}

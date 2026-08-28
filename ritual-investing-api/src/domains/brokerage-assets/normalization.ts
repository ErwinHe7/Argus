const decimalPattern = /^-?(?:0|[1-9]\d*)(?:\.\d+)?$/;
const currencyPattern = /^[A-Z]{3}$/;
const providerCodePattern = /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$/;

export class BrokerageReadContractError extends Error {
  readonly code: string;

  constructor(code: string) {
    super(code);
    this.name = "BrokerageReadContractError";
    this.code = code;
  }
}

/**
 * Canonicalizes provider decimals using string operations only. Financial
 * values must never cross a JavaScript Number boundary.
 */
export function canonicalDecimal(value: unknown): string {
  if (typeof value !== "string" || !decimalPattern.test(value)) {
    throw new BrokerageReadContractError("invalid_provider_decimal");
  }
  const negative = value.startsWith("-");
  const unsigned = negative ? value.slice(1) : value;
  const [integer = "0", fraction = ""] = unsigned.split(".");
  if (integer.length > 38 || fraction.length > 18) {
    throw new BrokerageReadContractError("provider_decimal_out_of_range");
  }
  const trimmedFraction = fraction.replace(/0+$/, "");
  const magnitude = trimmedFraction.length === 0
    ? integer
    : `${integer}.${trimmedFraction}`;
  return negative && magnitude !== "0" ? `-${magnitude}` : magnitude;
}

export function normalizedCurrency(value: unknown): string {
  if (typeof value !== "string" || !currencyPattern.test(value)) {
    throw new BrokerageReadContractError("invalid_provider_currency");
  }
  return value;
}

export function normalizedProviderCode(value: unknown): string {
  if (typeof value !== "string" || !providerCodePattern.test(value)) {
    throw new BrokerageReadContractError("invalid_provider_code");
  }
  return value;
}

export function normalizedMarketTimezone(value: unknown): string {
  if (typeof value !== "string" || value.length > 64) {
    throw new BrokerageReadContractError("invalid_market_timezone");
  }
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value }).format(
      new Date("2026-01-01T00:00:00Z"),
    );
  } catch {
    throw new BrokerageReadContractError("invalid_market_timezone");
  }
  return value;
}

export function normalizedProviderTimestamp(
  value: unknown,
  fetchedAt: Date,
): string {
  if (
    typeof value !== "string" ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?Z$/.test(value)
  ) {
    throw new BrokerageReadContractError("invalid_provider_timestamp");
  }
  const observedAt = new Date(value);
  if (
    !Number.isFinite(observedAt.getTime()) ||
    observedAt.getTime() > fetchedAt.getTime() + 30_000
  ) {
    throw new BrokerageReadContractError("invalid_provider_timestamp");
  }
  return observedAt.toISOString();
}

export type NormalizedAsset = Readonly<{
  instrument_id: string;
  symbol: string;
  name: string;
  asset_kind: "equity" | "etf" | "unsupported";
  provider_asset_kind: string;
  supported: boolean;
  currency: string;
  exchange: string | null;
  market_timezone: string;
}>;

export type ProviderAssetIdentifierMapper = (
  providerAssetId: string,
) => string;

const supportedAssetKinds = new Map(
  [
    ["EQUITY", "equity"],
    ["ETF", "etf"],
  ] as const,
);
const unsafeDisplayText = /[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]/;

export function normalizeAssetKind(value: unknown): Readonly<{
  asset_kind: "equity" | "etf" | "unsupported";
  provider_asset_kind: string;
  supported: boolean;
}> {
  const providerKind = normalizedProviderCode(value);
  const kind = supportedAssetKinds.get(providerKind as "EQUITY" | "ETF");
  return Object.freeze({
    asset_kind: kind ?? "unsupported",
    provider_asset_kind: providerKind,
    supported: kind !== undefined,
  });
}

export function normalizeAsset(
  value: unknown,
  mapProviderAssetId: ProviderAssetIdentifierMapper,
): NormalizedAsset {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BrokerageReadContractError("invalid_provider_asset");
  }
  const input = value as Record<string, unknown>;
  const providerAssetId = normalizedProviderCode(input.provider_asset_id);
  const instrumentId = mapProviderAssetId(providerAssetId);
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(instrumentId)
  ) {
    throw new BrokerageReadContractError("invalid_argus_instrument_id");
  }
  const kind = normalizeAssetKind(input.asset_kind);
  if (
    typeof input.symbol !== "string" ||
    !/^[A-Z0-9][A-Z0-9.-]{0,31}$/.test(input.symbol) ||
    typeof input.name !== "string" ||
    input.name.length < 1 ||
    input.name.length > 160 ||
    unsafeDisplayText.test(input.name) ||
    (input.exchange !== null &&
      (typeof input.exchange !== "string" ||
        input.exchange.length > 32 ||
        unsafeDisplayText.test(input.exchange)))
  ) {
    throw new BrokerageReadContractError("invalid_provider_asset");
  }
  return Object.freeze({
    instrument_id: instrumentId,
    symbol: input.symbol,
    name: input.name,
    asset_kind: kind.asset_kind,
    provider_asset_kind: kind.provider_asset_kind,
    supported: kind.supported,
    currency: normalizedCurrency(input.currency),
    exchange: input.exchange,
    market_timezone: normalizedMarketTimezone(input.market_timezone),
  });
}

export type NormalizedPosition = Readonly<{
  asset: NormalizedAsset;
  quantity: string;
  available_quantity: string;
  average_cost: string | null;
  market_value: string | null;
  currency: string;
}>;

export function normalizePosition(
  value: unknown,
  mapProviderAssetId: ProviderAssetIdentifierMapper,
): NormalizedPosition {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BrokerageReadContractError("invalid_provider_position");
  }
  const input = value as Record<string, unknown>;
  return Object.freeze({
    asset: normalizeAsset(input.asset, mapProviderAssetId),
    quantity: canonicalDecimal(input.quantity),
    available_quantity: canonicalDecimal(input.available_quantity),
    average_cost: input.average_cost === null
      ? null
      : canonicalDecimal(input.average_cost),
    market_value: input.market_value === null
      ? null
      : canonicalDecimal(input.market_value),
    currency: normalizedCurrency(input.currency),
  });
}

export type NormalizedBalance = Readonly<{
  currency: string;
  cash: string;
  buying_power: string | null;
  market_value: string | null;
  total_equity: string;
}>;

export function normalizeBalance(value: unknown): NormalizedBalance {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BrokerageReadContractError("invalid_provider_balance");
  }
  const input = value as Record<string, unknown>;
  return Object.freeze({
    currency: normalizedCurrency(input.currency),
    cash: canonicalDecimal(input.cash),
    buying_power: input.buying_power === null
      ? null
      : canonicalDecimal(input.buying_power),
    market_value: input.market_value === null
      ? null
      : canonicalDecimal(input.market_value),
    total_equity: canonicalDecimal(input.total_equity),
  });
}

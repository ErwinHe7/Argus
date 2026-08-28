export type BrokerageProjectionResource =
  | "account"
  | "balance"
  | "positions"
  | "restrictions";

export type BrokerageProjectionAvailability =
  | "available"
  | "partial"
  | "stale"
  | "unavailable";

export type BrokerageReadState =
  | "fresh"
  | "empty"
  | "stale"
  | "partial"
  | "unavailable"
  | "offline"
  | "rate_limited"
  | "disconnected"
  | "reauthorization_required";

export type BrokerageAccountContext = Readonly<{
  userId: string;
  deletionEpoch: number;
  connectionId: string;
  connectionStatus:
    | "pending"
    | "connected"
    | "denied"
    | "failed"
    | "disconnected"
    | "temporarily_unavailable"
    | "reauthorization_required";
  accountId: string;
  accountStatus: "available" | "restricted" | "closed" | "unavailable";
  capabilityVersion: number;
}>;

export type StoredProjection = Readonly<{
  id: string;
  generation: number;
  resource: BrokerageProjectionResource;
  payload: unknown;
  providerObservedAt: Date | null;
  fetchedAt: Date;
  expiresAt: Date;
  availability: BrokerageProjectionAvailability;
  reasonCode: string | null;
}>;

export type ProviderProjection = Readonly<{
  payload: unknown;
  providerObservedAt: Date | null;
  fetchedAt: Date;
  expiresAt: Date;
  availability: Exclude<
    BrokerageProjectionAvailability,
    "stale" | "unavailable"
  >;
  reasonCode?: string;
}>;

export type BrokerageProjectionResponse = Readonly<{
  account_id: string;
  resource: BrokerageProjectionResource;
  generation: number | null;
  state: BrokerageReadState;
  reason: string | null;
  provider_observed_at: string | null;
  fetched_at: string | null;
  expires_at: string | null;
  data: unknown;
}>;

export type BrokerageAccountSummary = Readonly<{
  id: string;
  connection_id: string;
  display_label: string;
  base_currency: string;
  market_timezone: string | null;
  status: "available" | "restricted" | "closed" | "unavailable";
  capability_version: number;
  capabilities: readonly unknown[];
  state: BrokerageReadState;
  selected: boolean;
  provider_observed_at: string | null;
  fetched_at: string | null;
  expires_at: string | null;
}>;

export class BrokerageProjectionError extends Error {
  readonly code:
    | "account_not_found"
    | "refresh_fenced"
    | "provider_contract_unavailable"
    | "offline"
    | "rate_limited"
    | "reauthorization_required"
    | "account_removed";

  constructor(
    code:
      | "account_not_found"
      | "refresh_fenced"
      | "provider_contract_unavailable"
      | "offline"
      | "rate_limited"
      | "reauthorization_required"
      | "account_removed",
  ) {
    super(code);
    this.name = "BrokerageProjectionError";
    this.code = code;
  }
}

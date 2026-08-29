const stableReasonCodes = new Set([
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
  "provider_contract_unavailable",
  "provider_outcome_unknown",
  "provider_rejected",
  "provider_lookup_unavailable",
] as const);

export type StableBrokerageReasonCode =
  typeof stableReasonCodes extends Set<infer Value> ? Value : never;

/**
 * Provider reason strings are opaque evidence, not database contract values.
 * Only the reviewed internal vocabulary may cross into the U7 SQL routines.
 */
export function normalizeBrokerageReasonCode(
  value: unknown,
  fallback: StableBrokerageReasonCode,
): StableBrokerageReasonCode {
  return typeof value === "string" &&
      stableReasonCodes.has(value as StableBrokerageReasonCode)
    ? value as StableBrokerageReasonCode
    : fallback;
}

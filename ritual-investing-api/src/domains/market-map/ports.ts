import type {
  MarketMapHorizon,
  MarketMapSnapshot,
} from "./schemas.ts";

export type MarketMapProviderRequest = Readonly<{
  /** Omitted for the server-manifest-selected featured snapshot. */
  assetId?: string;
  horizon: MarketMapHorizon;
}>;

/**
 * The production quant runtime owns every value in the snapshot. The API port
 * deliberately returns unknown so the member boundary always validates the
 * complete upstream artifact before any bytes can reach a client.
 */
export interface MarketMapProvider {
  read(request: MarketMapProviderRequest): Promise<unknown>;
}

export interface MarketMapService {
  read(request: MarketMapProviderRequest): Promise<MarketMapSnapshot>;
}

export type MarketMapErrorCode =
  | "market_map_asset_not_found"
  | "market_map_not_entitled"
  | "market_map_provider_blocked"
  | "market_map_provider_unavailable"
  | "market_map_contract_invalid"
  | "market_map_request_mismatch"
  | "market_map_snapshot_expired"
  | "market_map_snapshot_not_yet_available"
  | "market_map_noncausal_snapshot"
  | "market_map_coverage_incomplete"
  | "market_map_required_input_incomplete"
  | "market_map_content_policy_violation";

export class MarketMapError extends Error {
  readonly code: MarketMapErrorCode;

  constructor(code: MarketMapErrorCode) {
    super(code);
    this.name = "MarketMapError";
    this.code = code;
  }
}

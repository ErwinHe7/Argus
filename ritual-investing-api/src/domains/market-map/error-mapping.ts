import { MarketMapError } from "./ports.ts";
import { HttpBoundaryError } from "../retained-http/boundary.ts";

export function mapMarketMapBoundaryError(
  error: unknown,
): HttpBoundaryError | undefined {
  if (!(error instanceof MarketMapError)) return undefined;
  const hidden = error.code === "market_map_asset_not_found" ||
    error.code === "market_map_not_entitled";
  const retryable = [
    "market_map_provider_blocked",
    "market_map_provider_unavailable",
    "market_map_snapshot_expired",
    "market_map_snapshot_not_yet_available",
    "market_map_coverage_incomplete",
    "market_map_required_input_incomplete",
  ].includes(error.code);
  return new HttpBoundaryError(
    hidden ? 404 : 503,
    error.code,
    hidden
      ? "The requested Market Map was not found."
      : "Market Map is offline.",
    retryable,
  );
}


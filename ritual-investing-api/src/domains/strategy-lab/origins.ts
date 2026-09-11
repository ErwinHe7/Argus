import { exactStrategyOrigins } from "./app.ts";

const productionOrigins = new Set([
  "https://leoinvesting.com",
  "https://leo.axio7.workers.dev",
]);

/** Strategy-only allowlist; the retained member API has its own origin policy. */
export function productionStrategyOrigins(value: string): readonly string[] {
  const origins = exactStrategyOrigins(value);
  if (origins.some((origin) => !productionOrigins.has(origin))) {
    throw new Error("strategy_origin_must_match_astra");
  }
  return origins;
}

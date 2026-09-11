import { z } from "@hono/zod-openapi";

import { mapMarketMapBoundaryError } from "./error-mapping.ts";
import type { MarketMapService } from "./ports.ts";
import {
  marketMapHorizonSchema,
  marketMapSnapshotResponseSchema,
} from "./schemas.ts";
import {
  dataResponse,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import { uuidSchema } from "../retained-http/schemas.ts";

const marketMapPathSchema = z.object({
  asset_id: uuidSchema,
}).strict();

const marketMapQuerySchema = z.object({
  horizon: marketMapHorizonSchema.default("20d"),
}).strict();

export function registerMarketMapRoutes(input: Readonly<{
  register: RetainedRouteRegistrar;
  service: MarketMapService;
}>): void {
  const featured = retainedRoute(
    "get",
    "/v1/discover/market-map",
    "getFeaturedDiscoverMarketMap",
    "Discover",
    {
      transaction: "none",
      query: marketMapQuerySchema,
      description: "Read the complete fresh Market Map selected by the server manifest. No client-selected default asset or fallback data.",
      response: marketMapSnapshotResponseSchema,
    },
  );
  input.register(featured, async (context) => {
    try {
      const horizon = marketMapHorizonSchema.default("20d").parse(context.req.query("horizon"));
      return dataResponse(context, await input.service.read({ horizon }));
    } catch (error) {
      throw mapMarketMapBoundaryError(error) ?? error;
    }
  });
  const read = retainedRoute(
    "get",
    "/v1/discover/market-map/{asset_id}",
    "getDiscoverMarketMap",
    "Discover",
    {
      transaction: "none",
      pathParams: marketMapPathSchema,
      query: marketMapQuerySchema,
      description:
        "Read one complete, server-computed market research snapshot. Incomplete, stale, unentitled, or non-causal artifacts fail closed.",
      response: marketMapSnapshotResponseSchema,
    },
  );

  input.register(read, async (context) => {
    try {
      const assetId = uuidSchema.parse(context.req.param("asset_id"));
      const horizon = marketMapHorizonSchema.default("20d").parse(
        context.req.query("horizon"),
      );
      return dataResponse(
        context,
        await input.service.read({ assetId, horizon }),
      );
    } catch (error) {
      throw mapMarketMapBoundaryError(error) ?? error;
    }
  });
}

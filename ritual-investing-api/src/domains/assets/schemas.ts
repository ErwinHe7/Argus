import { z } from "@hono/zod-openapi";

export const assetPageQuerySchema = z.object({
  asset_type: z.enum(["equity", "etf", "index", "cash"]).optional(),
  symbol_prefix: z.string().min(1).max(8).regex(/^[A-Za-z0-9.-]+$/).optional(),
  cursor: z.string().min(20).max(2_048).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
}).strict();

export const assetParamsSchema = z.object({ asset_id: z.uuid() }).strict();

export const assetMetricsQuerySchema = z.object({
  as_of: z.iso.datetime({ offset: true }).optional(),
}).strict();

export const assetCompareBodySchema = z.object({
  asset_ids: z.array(z.uuid()).min(2).max(5).refine(
    (values) => new Set(values).size === values.length,
    { message: "asset_ids must be unique" },
  ),
}).strict();

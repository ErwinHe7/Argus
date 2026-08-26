import { z } from "@hono/zod-openapi";

export const rowanQuerySchema = z.object({
  surface: z.enum(["daily_ritual", "evidence", "asset_codex", "coven"]),
  context_code: z.enum(["daily", "evidence", "asset", "coven"]),
  resource_id: z.uuid().optional(),
}).strict();

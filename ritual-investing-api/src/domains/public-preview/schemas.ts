import { z } from "@hono/zod-openapi";

import { modeSchema, publicDateSchema } from "../editorial/schemas.ts";

export const publicDailyQuerySchema = z.object({
  date: publicDateSchema.optional(),
  mode: modeSchema.default("tarot"),
}).strict();

export const publicPageQuerySchema = z.object({
  cursor: z.string().min(20).max(2_048).optional(),
  limit: z.coerce.number().int().min(1).max(20).default(20),
}).strict();

export const publicCovenQuerySchema = publicPageQuerySchema.extend({
  category: z.enum(["founder", "owner", "chief_executive"]).optional(),
}).strict();

export const publicCovenSlugSchema = z.object({
  slug: z.string().min(1).max(120).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
}).strict();

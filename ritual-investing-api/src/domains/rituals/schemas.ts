import { z } from "@hono/zod-openapi";

import { modeSchema, publicDateSchema } from "../editorial/schemas.ts";

export const ritualDailyQuerySchema = z.object({
  date: publicDateSchema.optional(),
  mode: modeSchema.default("tarot"),
}).strict();

export const assignmentParamsSchema = z.object({ assignment_id: z.uuid() }).strict();

export const assignmentVersionHeadersSchema = z.object({
  "if-match": z.string().regex(/^"v[1-9]\d*"$/),
});

export const historyQuerySchema = z.object({
  mode: modeSchema.optional(),
  from: publicDateSchema.optional(),
  to: publicDateSchema.optional(),
  cursor: z.string().min(20).max(2_048).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
}).strict();

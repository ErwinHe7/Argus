import { z } from "@hono/zod-openapi";

export const covenPageQuerySchema = z.object({
  category: z.enum(["founder", "owner", "chief_executive"]).optional(),
  verified_as_of: z.iso.date().optional(),
  cursor: z.string().min(20).max(2_048).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
}).strict();

export const covenParamsSchema = z.object({ entry_id: z.uuid() }).strict();

import { z } from "@hono/zod-openapi";

const cursorPage = {
  cursor: z.string().min(20).max(2_048).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
};

export const discoverQuerySchema = z.object({
  ...cursorPage,
  section: z.enum(["asset", "coven", "grimoire", "circle_template"]).optional(),
}).strict();

export const grimoireQuerySchema = z.object({
  ...cursorPage,
  theme: z.string().min(1).max(64).regex(/^[a-z0-9_]+$/).optional(),
}).strict();

export const creatorQuerySchema = z.object(cursorPage).strict();

export const templateQuerySchema = z.object({
  ...cursorPage,
  theme: z.string().min(1).max(64).regex(/^[a-z0-9_]+$/).optional(),
  creator: z.string().min(1).max(120).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/).optional(),
}).strict();

export const catalogIdParamsSchema = z.object({ id: z.uuid() }).strict();

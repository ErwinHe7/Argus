import { z } from "@hono/zod-openapi";

import {
  jsonObjectSchema,
  retainedCollectionEnvelope,
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";

export const publishedEditorialSchema = z.object({
  id: uuidSchema,
  kind: z.string().min(1).max(80),
  slug: z.string().min(1).max(120),
  revision_id: uuidSchema,
  revision_number: z.coerce.number().int().positive(),
  payload: jsonObjectSchema,
}).strict().openapi("PublishedEditorial");

export const editorialCollectionResponseSchema = retainedCollectionEnvelope(
  "EditorialCollectionResponse",
  z.array(publishedEditorialSchema).max(100),
);

export const editorialItemResponseSchema = retainedEnvelope(
  "EditorialItemResponse",
  publishedEditorialSchema.nullable(),
);

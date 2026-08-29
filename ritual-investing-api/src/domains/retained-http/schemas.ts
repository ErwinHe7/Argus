import { z } from "@hono/zod-openapi";

export const uuidSchema = z.string().uuid();
export const pageLimitSchema = z.coerce.number().int().min(1).max(100).default(25);
export const jsonObjectSchema = z.record(z.string(), z.unknown());
export const nullableTimestampSchema = z.string().datetime().nullable();
export const responseMetaSchema = z.object({ request_id: uuidSchema }).strict();
export const collectionMetaSchema = responseMetaSchema.extend({
  next_cursor: z.string().min(1).max(2048).nullable(),
  has_more: z.boolean(),
}).strict().openapi("CollectionMeta");
export const responseSchema = z
  .object({
    data: z.unknown(),
    meta: responseMetaSchema,
  })
  .strict();
export const errorSchema = z
  .object({
    error: z
      .object({
        code: z.string(),
        message: z.string(),
        request_id: uuidSchema,
        field_errors: z.array(z.unknown()),
        retryable: z.boolean(),
      })
      .strict(),
  })
  .strict();
export const idempotencyKeySchema = z
  .string()
  .min(16)
  .max(64)
  .regex(/^[\x21-\x7E]+$/);

export function retainedEnvelope(name: string, data: z.ZodType) {
  return z.object({ data, meta: responseMetaSchema }).strict().openapi(name);
}

export function retainedCollectionEnvelope(name: string, data: z.ZodType) {
  return z.object({ data, meta: collectionMetaSchema }).strict().openapi(name);
}

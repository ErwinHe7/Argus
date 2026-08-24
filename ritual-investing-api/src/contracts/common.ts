import { z } from "@hono/zod-openapi";

const decimalPattern = /^(?:0|[1-9]\d*)(?:\.\d{1,12})?$/;

export const requestIdSchema = z.uuid().openapi({
  description: "Server-assigned request correlation identifier.",
  example: "018f3c2a-4b67-7a89-8abc-1234567890ab",
});

export const responseMetaSchema = z
  .object({ request_id: requestIdSchema })
  .strict()
  .openapi("ResponseMeta");

export const collectionMetaSchema = responseMetaSchema
  .extend({
    next_cursor: z.string().min(1).max(2048).nullable(),
    has_more: z.boolean(),
  })
  .strict()
  .openapi("CollectionMeta");

export function objectResponse<T extends z.ZodType>(dataSchema: T) {
  return z.object({ data: dataSchema, meta: responseMetaSchema }).strict();
}

export function collectionResponse<T extends z.ZodType>(itemSchema: T) {
  return z.object({ data: z.array(itemSchema), meta: collectionMetaSchema }).strict();
}

export const objectResponseSchema = objectResponse(
  z.record(z.string(), z.unknown()),
).openapi("ObjectResponse");

export const collectionResponseSchema = collectionResponse(z.unknown()).openapi(
  "CollectionResponse",
);

export const fieldErrorSchema = z
  .object({
    path: z.string().min(1).max(256),
    code: z.string().min(1).max(64),
  })
  .strict()
  .openapi("FieldError");

export const errorResponseSchema = z
  .object({
    error: z
      .object({
        code: z.string().min(1).max(64),
        message: z.string().min(1).max(500),
        request_id: requestIdSchema,
        field_errors: z.array(fieldErrorSchema).max(50),
        retryable: z.boolean(),
        retry_after_seconds: z.number().int().positive().max(86_400).optional(),
      })
      .strict(),
  })
  .strict()
  .openapi("ErrorResponse");

export type ErrorResponse = z.infer<typeof errorResponseSchema>;

export const idempotencyKeySchema = z
  .string()
  .regex(/^[\x21-\x7E]{16,64}$/)
  .openapi({
    description: "A retry-stable, tenant-and-operation-scoped command key.",
    example: "order-01JY7W4M5GYJ2E47KCEPD88N2K",
  });

export const etagSchema = z.string().regex(/^"v[1-9]\d*"$/).openapi({ example: '"v3"' });

export const moneySchema = z
  .object({
    minor_units: z.number().int().nonnegative().max(Number.MAX_SAFE_INTEGER),
    currency: z.enum(["USD"]),
  })
  .strict()
  .openapi("Money");

export const quantitySchema = z
  .object({
    value: z.string().regex(decimalPattern),
    scale: z.number().int().min(0).max(12),
  })
  .strict()
  .superRefine((quantity, context) => {
    const fractionLength = quantity.value.split(".")[1]?.length ?? 0;
    if (fractionLength !== quantity.scale) {
      context.addIssue({
        code: "custom",
        path: ["scale"],
        message: "scale must match the decimal value",
      });
    }
  })
  .openapi("Quantity");

export const demoDisclosureSchema = z
  .object({
    is_demo: z.literal(true),
    observed_at: z.iso.datetime({ offset: true }),
    source_label: z.string().min(1).max(120),
    limitations: z.array(z.string().min(1).max(500)).min(1).max(20),
  })
  .strict()
  .openapi("DemoDisclosure");

import { z } from "@hono/zod-openapi";

export const mediaUploadRequestSchema = z
  .object({
    mime_type: z.enum(["image/jpeg", "image/png", "image/webp"]),
    byte_size: z
      .number()
      .int()
      .positive()
      .max(10 * 1024 * 1024),
    checksum: z.string().regex(/^[a-f0-9]{64}$/),
  })
  .strict();
export const mediaUploadIntentSchema = z
  .object({
    media_id: z.string().uuid(),
    quarantine_key: z.string().min(1).max(512),
    upload_url: z.string().url(),
    expires_at: z.string().datetime(),
  })
  .strict();
export const mediaCompleteSchema = z
  .object({ checksum: z.string().regex(/^[a-f0-9]{64}$/) })
  .strict();
export const mediaScanJobSchema = z
  .object({
    media_id: z.string().uuid(),
    status: z.literal("scanning"),
    outbox_id: z.string().uuid(),
  })
  .strict();
export const adminMediaSchema = z
  .object({
    id: z.string().uuid(),
    mime_type: z.enum(["image/jpeg", "image/png", "image/webp"]),
    byte_size: z.number().int().positive(),
    checksum: z.string().regex(/^[a-f0-9]{64}$/),
    upload_status: z.enum([
      "issued",
      "uploaded",
      "scanning",
      "accepted",
      "rejected",
      "expired",
    ]),
    quarantine_status: z.enum(["pending", "clear", "rejected"]),
    scan_result: z.string().max(64).nullable(),
    derivative_status: z.enum([
      "unavailable",
      "uploading",
      "active",
      "retired",
    ]),
    reference_count: z.number().int().nonnegative(),
    version: z.number().int().positive(),
  })
  .strict();
export const mediaDeleteSchema = z
  .object({ reason: z.string().trim().min(8).max(500) })
  .strict();

export type MediaUploadRequest = z.infer<typeof mediaUploadRequestSchema>;
export type AdminMedia = z.infer<typeof adminMediaSchema>;

import { z } from "@hono/zod-openapi";

export const privacyRequestSchema = z
  .object({
    id: z.string().uuid(),
    request_type: z.enum(["export", "delete"]),
    status: z.enum([
      "requested",
      "verified",
      "queued",
      "processing",
      "completed",
      "failed",
      "cancelled",
    ]),
    snapshot_at: z.string().datetime().nullable(),
    completed_at: z.string().datetime().nullable(),
    expires_at: z.string().datetime().nullable(),
    failure_code: z.string().max(64).nullable(),
    format: z.literal("zip"),
    download_link: z
      .object({ url: z.string().url(), expires_at: z.string().datetime() })
      .strict()
      .nullable(),
  })
  .strict();
export const exportCreateSchema = z
  .object({ format: z.literal("zip") })
  .strict();
export const exportLinkSchema = z
  .object({
    url: z.string().url(),
    expires_at: z.string().datetime(),
  })
  .strict();
export const deletionCreateSchema = z
  .object({ confirmation: z.literal("DELETE") })
  .strict();
export const deletionReceiptSchema = z
  .object({
    request_id: z.string().uuid(),
    tombstone_id: z.string().uuid(),
    status: z.literal("queued"),
    effective_at: z.string().datetime(),
    purge_by: z.string().datetime(),
    purge_generation: z.number().int().positive(),
  })
  .strict();

export type PrivacyRequest = z.infer<typeof privacyRequestSchema>;
export type DeletionReceipt = z.infer<typeof deletionReceiptSchema>;

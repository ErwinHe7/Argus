import { z } from "@hono/zod-openapi";

export const adminJobSchema = z
  .object({
    id: z.string().uuid(),
    outbox_id: z.string().uuid(),
    consumer: z.string().min(1).max(64),
    status: z.enum(["leased", "completed", "retry", "dead_letter"]),
    attempt: z.number().int().nonnegative(),
    correlation_id: z.string().uuid(),
    failure_code: z.string().max(64).nullable(),
    created_at: z.string().datetime(),
    completed_at: z.string().datetime().nullable(),
  })
  .strict();
export const adminPrivacySchema = z
  .object({
    id: z.string().uuid(),
    tenant_id: z.string().uuid(),
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
    queued_at: z.string().datetime().nullable(),
    completed_at: z.string().datetime().nullable(),
    failure_code: z.string().max(64).nullable(),
    purge_generation: z.number().int().positive().nullable(),
  })
  .strict();
export const adminRetrySchema = z
  .object({ reason: z.string().min(8).max(500) })
  .strict();
export type AdminJob = z.infer<typeof adminJobSchema>;
export type AdminPrivacy = z.infer<typeof adminPrivacySchema>;

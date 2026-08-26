import { z } from "@hono/zod-openapi";

export const adminMeSchema = z
  .object({
    staff_id: z.string().uuid(),
    display_label: z.string().min(1).max(120),
    permissions: z.array(z.string().min(1).max(128)).max(64),
    revocation_epoch: z.number().int().nonnegative(),
  })
  .strict()
  .openapi("AdminMe");

export const adminHealthSchema = z
  .object({
    status: z.enum(["ready", "degraded"]),
    dependencies: z
      .object({
        neon: z.enum(["configured", "missing"]),
        queue: z.enum(["configured", "missing"]),
        media: z.enum(["configured", "missing"]),
        identity: z.enum(["configured", "missing"]),
      })
      .strict(),
  })
  .strict()
  .openapi("AdminHealth");

export const adminAuditEventSchema = z
  .object({
    id: z.string().uuid(),
    actor_staff_id: z.string().uuid(),
    action: z.string().min(1).max(160),
    target_kind: z.string().min(1).max(80),
    target_id: z.string().uuid().nullable(),
    before_hash: z
      .string()
      .regex(/^[a-f0-9]{64}$/)
      .nullable(),
    after_hash: z
      .string()
      .regex(/^[a-f0-9]{64}$/)
      .nullable(),
    reason: z.string().min(1).max(500),
    request_id: z.string().uuid(),
    outcome: z.enum(["allowed", "denied", "failed"]),
    created_at: z.iso.datetime({ offset: true }),
  })
  .strict()
  .openapi("AdminAuditEvent");
export type AdminAuditEvent = z.infer<typeof adminAuditEventSchema>;

export const adminAuditQuerySchema = z
  .object({
    actor_staff_id: z.string().uuid().optional(),
    action: z.string().trim().min(1).max(120).optional(),
    target_kind: z.string().trim().min(1).max(80).optional(),
    from: z.iso.datetime({ offset: true }).optional(),
    to: z.iso.datetime({ offset: true }).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(1).max(2048).optional(),
  })
  .strict()
  .superRefine((value, context) => {
    if (value.from !== undefined && value.to !== undefined) {
      const from = new Date(value.from);
      const to = new Date(value.to);
      if (to <= from || to.getTime() - from.getTime() > 31 * 86_400_000)
        context.addIssue({
          code: "custom",
          path: ["to"],
          message: "audit ranges must be positive and at most 31 days",
        });
    }
  });

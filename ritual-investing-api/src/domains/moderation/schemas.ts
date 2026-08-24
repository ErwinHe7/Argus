import { z } from "@hono/zod-openapi";

const text = (max: number) =>
  z
    .string()
    .trim()
    .min(1)
    .max(max)
    .refine((value) => !/[<>\u0000]/.test(value));
export const moderationReportSchema = z
  .object({
    id: z.string().uuid(),
    target_kind: z.enum([
      "ritual",
      "asset_codex",
      "coven_entry",
      "grimoire",
      "circle_template",
    ]),
    target_id: z.string().uuid(),
    reason_code: z.string().min(1).max(64),
    detail: z.string().min(1).max(1_000).nullable(),
    status: z.enum(["open", "triaged", "resolved", "dismissed"]),
    created_at: z.iso.datetime({ offset: true }),
  })
  .strict()
  .openapi("AdminModerationReport");
export const moderationCaseSchema = z
  .object({
    id: z.string().uuid(),
    report: moderationReportSchema,
    status: z.enum(["open", "investigating", "resolved", "dismissed"]),
    assignee_id: z.string().uuid().nullable(),
    resolution_code: z.string().max(64).nullable(),
    resolved_at: z.iso.datetime({ offset: true }).nullable(),
    version: z.number().int().positive(),
    etag: z.string(),
    decisions: z
      .array(
        z
          .object({
            outcome: z.string().max(64),
            reason: text(500),
            decided_at: z.iso.datetime({ offset: true }),
          })
          .strict(),
      )
      .max(100),
  })
  .strict()
  .openapi("AdminModerationCase");
export const moderationQuerySchema = z
  .object({
    status: z.enum(["open", "triaged", "resolved", "dismissed"]).optional(),
    target_kind: z
      .enum([
        "ritual",
        "asset_codex",
        "coven_entry",
        "grimoire",
        "circle_template",
      ])
      .optional(),
    from: z.iso.datetime({ offset: true }).optional(),
    to: z.iso.datetime({ offset: true }).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(1).max(2048).optional(),
  })
  .strict();
export const createModerationCaseSchema = z
  .object({
    assignee_id: z.string().uuid().nullable().optional(),
    note: text(500),
  })
  .strict();
export const patchModerationCaseSchema = z
  .object({
    status: z.enum(["investigating", "resolved", "dismissed"]),
    resolution_code: z.string().trim().min(1).max(64).optional(),
    reason: text(500),
  })
  .strict();

export type AdminModerationReport = z.infer<typeof moderationReportSchema>;
export type AdminModerationCase = z.infer<typeof moderationCaseSchema>;

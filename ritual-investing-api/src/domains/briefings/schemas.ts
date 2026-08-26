import { z } from "@hono/zod-openapi";

export const briefingTypeSchema = z.enum(["daily", "weekly", "moon_cycle"]);
export const briefingSummarySchema = z
  .object({
    id: z.string().uuid(),
    briefing_type: briefingTypeSchema,
    period_start: z.string().date(),
    period_end: z.string().date(),
    generation: z.number().int().positive(),
    source_sequence: z.number().int().nonnegative(),
    generated_at: z.string().datetime(),
    read_at: z.string().datetime().nullable(),
  })
  .strict();
export const briefingSectionSchema = z
  .object({
    section_type: z.string().min(1).max(64),
    ordinal: z.number().int().positive(),
    payload: z.record(z.string(), z.unknown()),
    schema_version: z.number().int().positive(),
  })
  .strict();
export const briefingDetailSchema = briefingSummarySchema.extend({
  sections: z.array(briefingSectionSchema).max(32),
});
export const briefingReadStateSchema = z.object({ read: z.boolean() }).strict();

export type BriefingSummary = z.infer<typeof briefingSummarySchema>;
export type BriefingDetail = z.infer<typeof briefingDetailSchema>;

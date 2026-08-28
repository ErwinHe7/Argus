import { z } from "zod";

const optionalTimestamp = z
  .union([z.string(), z.date()])
  .transform((value) => new Date(value).toISOString())
  .nullable();

export const supabaseSessionSnapshotSchema = z
  .object({
    member: z.object({
      user_id: z.string().uuid(),
      status: z.literal("active"),
      deletion_epoch: z.coerce.number().int().nonnegative(),
      deletion_requested_at: optionalTimestamp,
      created_at: optionalTimestamp,
      updated_at: optionalTimestamp,
    }),
    profile: z
      .object({
        user_id: z.string().uuid(),
        deletion_epoch: z.coerce.number().int().nonnegative(),
        display_name: z.string().min(1).max(80),
        avatar_media_id: z.string().uuid().nullable(),
        locale: z.string(),
        updated_at: optionalTimestamp,
      })
      .nullable(),
    preferences: z
      .object({
        user_id: z.string().uuid(),
        deletion_epoch: z.coerce.number().int().nonnegative(),
        theme_mode: z.enum(["system", "light", "dark"]),
        ritual_mode: z.enum(["tarot", "astrology"]),
        timezone: z.string(),
        locale: z.string(),
        version: z.coerce.number().int().positive(),
      })
      .nullable(),
    onboarding: z
      .object({
        user_id: z.string().uuid(),
        deletion_epoch: z.coerce.number().int().nonnegative(),
        current_step: z.string(),
        completed_steps: z.array(z.string()),
        completed_at: optionalTimestamp,
        version: z.coerce.number().int().positive(),
      })
      .nullable(),
    investor_profile: z.record(z.string(), z.unknown()).nullable(),
    astrology_profile: z.record(z.string(), z.unknown()).nullable(),
    server_time: z
      .union([z.string(), z.date()])
      .transform((value) => new Date(value).toISOString()),
  })
  .strict();

export type SupabaseSessionSnapshot = z.infer<
  typeof supabaseSessionSnapshotSchema
>;

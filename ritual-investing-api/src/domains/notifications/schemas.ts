import { z } from "@hono/zod-openapi";

export const quietHoursSchema = z
  .object({
    enabled: z.boolean(),
    start: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
    end: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
    timezone: z
      .string()
      .min(1)
      .max(64)
      .refine((value) => {
        try {
          new Intl.DateTimeFormat("en-US", { timeZone: value });
          return true;
        } catch {
          return false;
        }
      }, "invalid IANA timezone"),
  })
  .strict();
export const notificationPreferencesSchema = z
  .object({
    daily_ritual: z.boolean(),
    weekly_recap: z.boolean(),
    moon_cycle: z.boolean(),
    quiet_hours: quietHoursSchema,
    version: z.number().int().positive(),
  })
  .strict();
export const notificationPreferencesPatchSchema = z
  .object({
    daily_ritual: z.boolean().optional(),
    weekly_recap: z.boolean().optional(),
    moon_cycle: z.boolean().optional(),
    quiet_hours: quietHoursSchema.optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0);
export const deviceCreateSchema = z
  .object({
    platform: z.enum(["ios", "android"]),
    push_token: z.string().min(16).max(4096),
  })
  .strict();
export const deviceSchema = z
  .object({
    id: z.string().uuid(),
    platform: z.enum(["ios", "android"]),
    status: z.enum(["active", "revoked"]),
  })
  .strict();
export const notificationSchema = z
  .object({
    id: z.string().uuid(),
    kind: z.string().min(1).max(64),
    title: z.string().min(1).max(160),
    body: z.string().min(1).max(1000),
    deep_link: z
      .string()
      .regex(/^\/[a-z0-9/_-]+$/)
      .nullable(),
    scheduled_at: z.string().datetime().nullable(),
    read_at: z.string().datetime().nullable(),
  })
  .strict();
export const notificationReadSchema = z.object({ read: z.boolean() }).strict();
export const notificationListQuerySchema = z
  .object({
    read: z.enum(["all", "read", "unread"]).default("all"),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(1).max(2048).optional(),
  })
  .strict();
export const notificationReadAllSchema = z
  .object({ before: z.string().datetime().optional() })
  .strict();
export const contentReportCreateSchema = z
  .object({
    target_kind: z.enum(["ritual", "codex", "coven", "grimoire"]),
    target_id: z.string().uuid(),
    reason_code: z.enum(["incorrect", "unsafe", "spam", "rights", "other"]),
    detail: z.string().min(1).max(1000).optional(),
  })
  .strict();
export const contentReportSchema = z
  .object({ id: z.string().uuid(), status: z.literal("received") })
  .strict();

export type NotificationPreferences = z.infer<
  typeof notificationPreferencesSchema
>;
export type NotificationPreferencesPatch = z.infer<
  typeof notificationPreferencesPatchSchema
>;
export type DeviceCreate = z.infer<typeof deviceCreateSchema>;
export type Notification = z.infer<typeof notificationSchema>;
export type ContentReportCreate = z.infer<typeof contentReportCreateSchema>;

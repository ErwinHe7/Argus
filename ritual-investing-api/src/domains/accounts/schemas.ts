import { z } from "@hono/zod-openapi";

import { boundedUserText } from "../../security/input-schemas.ts";

const localeSchema = z
  .string()
  .regex(/^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$/)
  .max(35);
const timezoneSchema = z
  .string()
  .min(1)
  .max(64)
  .refine((value) => {
    try {
      new Intl.DateTimeFormat("en-US", { timeZone: value }).format();
      return true;
    } catch {
      return false;
    }
  }, "timezone must be a valid IANA name");

export const versionedProfileSchema = z
  .object({
    display_name: boundedUserText({ maximum: 80 }),
    locale: localeSchema,
    version: z.number().int().positive(),
  })
  .strict()
  .openapi("MemberProfile");

export const accountViewSchema = z
  .object({
    account: z.object({ id: z.uuid(), status: z.literal("active") }).strict(),
    profile: versionedProfileSchema,
  })
  .strict()
  .openapi("MemberAccountView");

export const profilePatchSchema = z
  .object({
    display_name: boundedUserText({ maximum: 80 }).optional(),
    locale: localeSchema.optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0);

export const preferencesSchema = z
  .object({
    theme_mode: z.enum(["system", "light", "dark"]),
    ritual_mode: z.enum(["tarot", "astrology"]),
    timezone: timezoneSchema,
    locale: localeSchema,
    version: z.number().int().positive(),
  })
  .strict()
  .openapi("MemberPreferences");
export const preferencesPatchSchema = preferencesSchema
  .omit({ version: true })
  .partial()
  .strict()
  .refine((value) => Object.keys(value).length > 0);

export const onboardingSchema = z
  .object({
    current_step: z.enum(["welcome", "ritual", "profile", "complete"]),
    completed_steps: z
      .array(z.string().regex(/^(welcome|ritual|profile)$/))
      .max(3),
    completed_at: z.iso.datetime({ offset: true }).nullable(),
    version: z.number().int().positive(),
  })
  .strict()
  .openapi("OnboardingState");
export const onboardingPatchSchema = z
  .object({
    current_step: z.enum(["ritual", "profile", "complete"]),
    completed_steps: z
      .array(z.string().regex(/^(welcome|ritual|profile)$/))
      .max(3),
  })
  .strict();

export const astrologyProfileSchema = z
  .object({
    birth_date: z.iso.date(),
    derived_profile_code: z.enum([
      "lunar_patient",
      "solar_builder",
      "rising_explorer",
    ]),
    algorithm_version: z.enum(["v1"]),
    enabled_at: z.iso.datetime({ offset: true }),
    version: z.number().int().positive(),
  })
  .strict()
  .openapi("AstrologyProfile");
export const astrologyPutSchema = astrologyProfileSchema
  .omit({ enabled_at: true, version: true })
  .strict();

export const investorProfileSchema = z
  .object({
    goal_type: z.enum([
      "calm_fund",
      "long_term_growth",
      "income",
      "exploration",
    ]),
    time_horizon: z.enum(["short", "medium", "long"]),
    risk_comfort: z.enum(["low", "moderate", "high"]),
    version: z.number().int().positive(),
    is_demo: z.literal(true),
  })
  .strict()
  .openapi("InvestorProfile");
export const investorPutSchema = investorProfileSchema
  .omit({ version: true, is_demo: true })
  .strict();

export const consentRequestSchema = z
  .object({
    policy_code: z.enum(["terms", "privacy", "demo_disclosure", "astrology"]),
    policy_version: z.string().min(1).max(40),
    decision: z.enum(["accepted", "declined", "withdrawn"]),
  })
  .strict();
export const consentReceiptSchema = consentRequestSchema
  .extend({
    id: z.uuid(),
    recorded_at: z.iso.datetime({ offset: true }),
  })
  .strict()
  .openapi("ConsentReceipt");

export type AccountView = z.infer<typeof accountViewSchema>;
export type PreferencesView = z.infer<typeof preferencesSchema>;
export type OnboardingView = z.infer<typeof onboardingSchema>;
export type AstrologyProfile = z.infer<typeof astrologyProfileSchema>;
export type InvestorProfile = z.infer<typeof investorProfileSchema>;
export type ConsentRequest = z.infer<typeof consentRequestSchema>;

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

export const ritualInterestSchema = z
  .enum([
    "practical_research",
    "tarot",
    "astrology",
    "moon_cycles",
    "reflection",
  ])
  .openapi("RitualInterest");

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
    ritual_familiarity: z
      .enum(["new", "curious", "familiar", "practiced", "prefer_not_to_say"])
      .nullable(),
    ritual_language: z
      .enum(["practical", "balanced", "mystical", "prefer_not_to_say"])
      .nullable(),
    ritual_interests: z.array(ritualInterestSchema).max(5).nullable(),
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
    schema_version: z.number().int().min(1).max(2),
    cohort: z.enum(["legacy_complete_v1", "legacy_incomplete_v1", "member_v2"]),
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
  .pick({
    birth_date: true,
    derived_profile_code: true,
    algorithm_version: true,
  })
  .extend({
    derived_profile_code:
      astrologyProfileSchema.shape.derived_profile_code.optional(),
    algorithm_version: astrologyProfileSchema.shape.algorithm_version.optional(),
  })
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
    investing_experience: z
      .enum(["new", "some_experience", "experienced"])
      .nullable(),
    contribution_rhythm: z
      .enum(["weekly", "biweekly", "monthly", "irregular", "not_sure"])
      .nullable(),
    version: z.number().int().positive(),
    is_demo: z.literal(true),
  })
  .strict()
  .openapi("InvestorProfile");
export const investorPutSchema = investorProfileSchema
  .omit({ version: true, is_demo: true })
  .extend({
    investing_experience: investorProfileSchema.shape.investing_experience
      .unwrap()
      .optional(),
    contribution_rhythm: investorProfileSchema.shape.contribution_rhythm
      .unwrap()
      .optional(),
  })
  .strict();

export const activeOnboardingPolicyVersions = {
  terms: "2026-08",
  privacy: "2026-08",
  demo_disclosure: "2026-08",
  astrology: "2026-08",
} as const;

const acceptedPolicy = (version: string) =>
  z
    .object({
      policy_version: z.literal(version),
      decision: z.literal("accepted"),
    })
    .strict();

export const onboardingFinalizeRequestSchema = z
  .object({
    schema_version: z.number().int().min(2).max(2),
    expected_onboarding_version: z.number().int().positive(),
    investing: z
      .object({
        experience: z.enum(["new", "some_experience", "experienced"]),
        goal_type: investorProfileSchema.shape.goal_type,
        time_horizon: investorProfileSchema.shape.time_horizon,
        risk_comfort: investorProfileSchema.shape.risk_comfort,
        contribution_rhythm: z.enum([
          "weekly",
          "biweekly",
          "monthly",
          "irregular",
          "not_sure",
        ]),
      })
      .strict(),
    ritual: z
      .object({
        familiarity: preferencesSchema.shape.ritual_familiarity.unwrap(),
        language_preference: preferencesSchema.shape.ritual_language.unwrap(),
        interests: preferencesSchema.shape.ritual_interests
          .unwrap()
          .min(1),
      })
      .strict(),
    astrology: z
      .object({
        enabled: z.boolean(),
        birth_date: z.iso.date().optional(),
      })
      .strict(),
    consents: z
      .object({
        terms: acceptedPolicy(activeOnboardingPolicyVersions.terms),
        privacy: acceptedPolicy(activeOnboardingPolicyVersions.privacy),
        demo_disclosure: acceptedPolicy(
          activeOnboardingPolicyVersions.demo_disclosure,
        ),
        astrology: z
          .object({
            policy_version: z.literal(
              activeOnboardingPolicyVersions.astrology,
            ),
            decision: z.enum(["accepted", "declined"]),
          })
          .strict(),
      })
      .strict(),
  })
  .strict()
  .superRefine((value, context) => {
    if (value.astrology.enabled !== (value.consents.astrology.decision === "accepted")) {
      context.addIssue({
        code: "custom",
        path: ["consents", "astrology", "decision"],
        message: "astrology consent must match the personalization choice",
        input: value.consents.astrology.decision,
      });
    }
    if (value.astrology.enabled !== (value.astrology.birth_date !== undefined)) {
      context.addIssue({
        code: "custom",
        path: ["astrology", "birth_date"],
        message: "birth_date is required only when astrology is enabled",
        input: value.astrology.birth_date,
      });
    }
  })
  .openapi("FinalizeOnboardingRequest");

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
export type OnboardingFinalizeRequest = z.infer<
  typeof onboardingFinalizeRequestSchema
>;

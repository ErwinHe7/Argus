import { z } from "@hono/zod-openapi";

import { ritualInterestSchema } from "../accounts/schemas.ts";

export const sessionBootstrapDataSchema = z.object({
  account: z.object({
    id: z.uuid(),
    status: z.literal("active"),
  }).strict(),
  profile: z.object({
    display_name: z.string().min(1).max(80),
    locale: z.string().min(1).max(35),
  }).strict(),
  preferences: z.object({
    theme_mode: z.enum(["system", "light", "dark"]),
    ritual_mode: z.enum(["tarot", "astrology"]),
    ritual_familiarity: z
      .enum(["new", "curious", "familiar", "practiced", "prefer_not_to_say"])
      .nullable(),
    ritual_language: z
      .enum(["practical", "balanced", "mystical", "prefer_not_to_say"])
      .nullable(),
    ritual_interests: z
      .array(ritualInterestSchema)
      .min(1)
      .max(5)
      .nullable(),
    timezone: z.string().min(1).max(64),
    locale: z.string().min(1).max(35),
    version: z.number().int().positive(),
  }).strict(),
  investor_profile: z
    .object({
      experience: z.enum(["new", "some_experience", "experienced"]),
      goal_type: z.enum([
        "calm_fund",
        "long_term_growth",
        "income",
        "exploration",
      ]),
      time_horizon: z.enum(["short", "medium", "long"]),
      risk_comfort: z.enum(["low", "moderate", "high"]),
      contribution_rhythm: z.enum([
        "weekly",
        "biweekly",
        "monthly",
        "irregular",
        "not_sure",
      ]),
      version: z.number().int().positive(),
      is_demo: z.literal(true),
    })
    .strict()
    .nullable(),
  astrology_profile: z
    .object({
      birth_date: z.iso.date(),
      derived_profile_code: z.enum([
        "lunar_patient",
        "solar_builder",
        "rising_explorer",
      ]),
      algorithm_version: z.literal("v1"),
      enabled_at: z.iso.datetime({ offset: true }),
      version: z.number().int().positive(),
    })
    .strict()
    .nullable(),
  onboarding: z.object({
    current_step: z.string().min(1).max(64),
    completed_steps: z.array(z.string().min(1).max(64)).max(50),
    completed_at: z.iso.datetime({ offset: true }).nullable(),
    schema_version: z.number().int().min(1).max(2),
    cohort: z.enum(["legacy_complete_v1", "legacy_incomplete_v1", "member_v2"]),
    version: z.number().int().positive(),
  }).strict(),
  entitlement: z.object({
    plan_code: z.string().min(1).max(64),
    status: z.literal("active"),
  }).strict(),
  default_portfolio: z.object({
    id: z.uuid(),
    name: z.string().min(1).max(120),
    currency: z.literal("USD"),
    status: z.literal("active"),
    version: z.number().int().positive(),
  }).strict(),
  reset_generation: z.number().int().positive(),
  server_time: z.iso.datetime({ offset: true }),
  contract_version: z.literal("1.0.0"),
}).strict().openapi("SessionBootstrap");

export type SessionBootstrapData = z.infer<typeof sessionBootstrapDataSchema>;

export const adminSessionDataSchema = z.object({
  staff_id: z.uuid(),
  display_label: z.string().min(1).max(120),
}).strict().openapi("AdminSession");

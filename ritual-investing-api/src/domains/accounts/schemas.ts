import { z } from "@hono/zod-openapi";

import {
  nullableTimestampSchema,
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";

export const memberProfileSchema = z.object({
  user_id: uuidSchema,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  display_name: z.string().min(1).max(80),
  avatar_media_id: uuidSchema.nullable(),
  locale: z.string().min(2).max(35),
  updated_at: nullableTimestampSchema,
}).strict().openapi("MemberProfile");
export const memberPreferencesSchema = z.object({
  user_id: uuidSchema,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  theme_mode: z.enum(["system", "light", "dark"]),
  ritual_mode: z.enum(["tarot", "astrology"]),
  timezone: z.string().min(1).max(64),
  locale: z.string().min(2).max(35),
  version: z.coerce.number().int().positive(),
}).strict().openapi("MemberPreferences");
export const onboardingStateSchema = z.object({
  user_id: uuidSchema,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  current_step: z.string().min(1).max(80),
  completed_steps: z.array(z.string().min(1).max(80)).max(64),
  completed_at: nullableTimestampSchema,
  version: z.coerce.number().int().positive(),
}).strict().openapi("OnboardingState");
export const investorProfileSchema = z.object({
  user_id: uuidSchema,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  goal_type: z.enum(["calm_fund", "long_term_growth", "income", "exploration"]),
  time_horizon: z.enum(["short", "medium", "long"]),
  risk_comfort: z.enum(["low", "moderate", "high"]),
  version: z.coerce.number().int().positive(),
}).strict().openapi("InvestorProfile");
export const astrologyProfileSchema = z.object({
  user_id: uuidSchema,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  birth_date: z.string().date(),
  derived_profile_code: z.enum([
    "lunar_patient",
    "solar_builder",
    "rising_explorer",
  ]),
  algorithm_version: z.literal("v1"),
  enabled_at: z.string().datetime(),
  version: z.number().int().min(1).max(1),
}).strict().openapi("AstrologyProfile");
const memberAccountSchema = z.object({
  status: z.enum([
    "active",
    "suspended",
    "deletion_pending",
    "purging",
    "purged",
  ]),
  deletion_epoch: z.coerce.number().int().nonnegative(),
  profile: memberProfileSchema.nullable(),
  preferences: memberPreferencesSchema.nullable(),
  onboarding: onboardingStateSchema.nullable(),
  investor_profile: investorProfileSchema.nullable(),
  astrology_profile: astrologyProfileSchema.nullable(),
}).strict().openapi("MemberAccount");
export const memberAccountResponseSchema = retainedEnvelope(
  "MemberAccountResponse",
  memberAccountSchema,
);
const consentReceiptSchema = z.object({
  id: uuidSchema,
  policy_code: z.string().min(1).max(80),
  policy_version: z.string().min(1).max(40),
  decision: z.enum(["accepted", "declined", "withdrawn"]),
  recorded_at: z.string().datetime(),
}).strict().openapi("ConsentReceipt");
export const consentReceiptResponseSchema = retainedEnvelope(
  "ConsentReceiptResponse",
  consentReceiptSchema,
);
export const preferencesPatchSchema = z.object({
  themeMode: z.enum(["system", "light", "dark"]).optional(),
  ritualMode: z.enum(["tarot", "astrology"]).optional(),
  timezone: z.string().min(1).max(64).optional(),
  locale: z.string().min(2).max(35).optional(),
}).strict();
export const investorBodySchema = z.object({
  goalType: z.enum(["calm_fund", "long_term_growth", "income", "exploration"]),
  timeHorizon: z.enum(["short", "medium", "long"]),
  riskComfort: z.enum(["low", "moderate", "high"]),
}).strict().openapi("UpdateInvestorProfileRequest");
export const astrologyBodySchema = z.object({
  birthDate: z.string().date(),
}).strict().openapi("UpdateAstrologyProfileRequest");
export const consentBodySchema = z.object({
  policyCode: z.string().min(1).max(80),
  policyVersion: z.string().min(1).max(40),
  decision: z.enum(["accepted", "declined", "withdrawn"]),
}).strict();
export const updatePreferencesResponseSchema = retainedEnvelope(
  "UpdatePreferencesResponse",
  memberPreferencesSchema,
);
export const investorProfileResponseSchema = retainedEnvelope(
  "InvestorProfileResponse",
  investorProfileSchema,
);
export const astrologyProfileResponseSchema = retainedEnvelope(
  "AstrologyProfileResponse",
  astrologyProfileSchema,
);
export const deleteAstrologyProfileResponseSchema = retainedEnvelope(
  "DeleteAstrologyProfileResponse",
  z.object({ removed: z.literal(true) }).strict(),
);

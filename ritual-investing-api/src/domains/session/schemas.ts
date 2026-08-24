import { z } from "@hono/zod-openapi";

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
    timezone: z.string().min(1).max(64),
    locale: z.string().min(1).max(35),
    version: z.number().int().positive(),
  }).strict(),
  onboarding: z.object({
    current_step: z.string().min(1).max(64),
    completed_steps: z.array(z.string().min(1).max(64)).max(50),
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
  server_time: z.iso.datetime({ offset: true }),
  contract_version: z.literal("1.0.0"),
}).strict().openapi("SessionBootstrap");

export type SessionBootstrapData = z.infer<typeof sessionBootstrapDataSchema>;

export const adminSessionDataSchema = z.object({
  staff_id: z.uuid(),
  display_label: z.string().min(1).max(120),
}).strict().openapi("AdminSession");

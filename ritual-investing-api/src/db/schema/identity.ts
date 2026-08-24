import { sql } from "drizzle-orm";
import {
  boolean,
  check,
  date,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";

export const tenants = pgTable(
  "tenants",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    status: text("status").notNull().default("provisioning"),
    seedVersion: integer("seed_version").notNull().default(1),
    deletionScheduledAt: timestamp("deletion_scheduled_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    check(
      "tenants_status_check",
      sql`${table.status} in ('provisioning','active','suspended','deletion_pending','purging','purged')`,
    ),
  ],
);

export const accounts = pgTable(
  "accounts",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }),
    auth0Subject: text("auth0_subject").notNull(),
    status: text("status").notNull().default("active"),
    revocationEpoch: integer("revocation_epoch").notNull().default(0),
    lastSeenAt: timestamp("last_seen_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    unique("accounts_tenant_unique").on(table.tenantId),
    unique("accounts_auth0_subject_unique").on(table.auth0Subject),
    unique("accounts_tenant_id_id_unique").on(table.tenantId, table.id),
    index("accounts_tenant_idx").on(table.tenantId),
  ],
);

export const profiles = pgTable("profiles", {
  tenantId: uuid("tenant_id").primaryKey().references(() => tenants.id, { onDelete: "cascade" }),
  displayName: text("display_name").notNull(),
  avatarMediaId: uuid("avatar_media_id"),
  locale: text("locale").notNull().default("en-US"),
});

export const preferences = pgTable("preferences", {
  tenantId: uuid("tenant_id").primaryKey().references(() => tenants.id, { onDelete: "cascade" }),
  themeMode: text("theme_mode").notNull().default("system"),
  ritualMode: text("ritual_mode").notNull().default("tarot"),
  timezone: text("timezone").notNull().default("UTC"),
  locale: text("locale").notNull().default("en-US"),
  version: integer("version").notNull().default(1),
});

export const astrologyProfiles = pgTable("astrology_profiles", {
  tenantId: uuid("tenant_id").primaryKey().references(() => tenants.id, { onDelete: "cascade" }),
  birthDate: date("birth_date").notNull(),
  derivedProfileCode: text("derived_profile_code").notNull(),
  algorithmVersion: text("algorithm_version").notNull(),
  enabledAt: timestamp("enabled_at", { withTimezone: true }).notNull().defaultNow(),
});

export const investorProfiles = pgTable("investor_profiles", {
  tenantId: uuid("tenant_id").primaryKey().references(() => tenants.id, { onDelete: "cascade" }),
  goalType: text("goal_type").notNull(),
  timeHorizon: text("time_horizon").notNull(),
  riskComfort: text("risk_comfort").notNull(),
  version: integer("version").notNull().default(1),
});

export const onboardingStates = pgTable("onboarding_states", {
  tenantId: uuid("tenant_id").primaryKey().references(() => tenants.id, { onDelete: "cascade" }),
  currentStep: text("current_step").notNull(),
  completedSteps: jsonb("completed_steps").notNull().default([]),
  completedAt: timestamp("completed_at", { withTimezone: true }),
  version: integer("version").notNull().default(1),
});

export const consentRecords = pgTable(
  "consent_records",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }),
    policyCode: text("policy_code").notNull(),
    policyVersion: text("policy_version").notNull(),
    decision: text("decision").notNull(),
    recordedAt: timestamp("recorded_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    unique("consent_records_history_unique").on(
      table.tenantId,
      table.policyCode,
      table.policyVersion,
      table.recordedAt,
    ),
    index("consent_records_tenant_idx").on(table.tenantId, table.recordedAt),
  ],
);

export const deviceInstallations = pgTable(
  "device_installations",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id").notNull().references(() => tenants.id, { onDelete: "cascade" }),
    platform: text("platform").notNull(),
    pushTokenCiphertext: text("push_token_ciphertext").notNull(),
    pushTokenHash: text("push_token_hash").notNull(),
    status: text("status").notNull().default("active"),
    lastSeenAt: timestamp("last_seen_at", { withTimezone: true }),
  },
  (table) => [
    unique("device_installations_tenant_id_id_unique").on(table.tenantId, table.id),
    unique("device_installations_active_token_unique").on(table.tenantId, table.pushTokenHash),
  ],
);

export const notificationPreferences = pgTable("notification_preferences", {
  tenantId: uuid("tenant_id").primaryKey().references(() => tenants.id, { onDelete: "cascade" }),
  dailyRitual: boolean("daily_ritual").notNull().default(true),
  weeklyRecap: boolean("weekly_recap").notNull().default(true),
  moonCycle: boolean("moon_cycle").notNull().default(true),
  quietHours: jsonb("quiet_hours").notNull().default({}),
  version: integer("version").notNull().default(1),
});

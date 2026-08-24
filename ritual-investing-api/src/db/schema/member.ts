import {
  bigint,
  boolean,
  date,
  foreignKey,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";

import { editorialItems } from "./editorial";
import { deviceInstallations, tenants } from "./identity";
import {
  demoPortfolios,
  idempotencyRecords,
  ledgerTransactions,
  simulationCommands,
} from "./simulation";

export const intentions = pgTable(
  "intentions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    targetMinor: bigint("target_minor", { mode: "bigint" }).notNull(),
    targetDate: date("target_date"),
    status: text("status").notNull(),
    version: integer("version").notNull().default(1),
    resetGeneration: integer("reset_generation").notNull().default(1),
    portfolioId: uuid("portfolio_id").notNull(),
    currency: text("currency").notNull().default("USD"),
    currentProjectionRunId: uuid("current_projection_run_id"),
    currentProjectionWatermark: bigint("current_projection_watermark", {
      mode: "number",
    })
      .notNull()
      .default(0),
    currentProjectionGeneration: integer("current_projection_generation")
      .notNull()
      .default(0),
  },
  (t) => [
    // The reviewed migration adds the deferrable current-run FK after
    // projection_runs exists, avoiding a circular Drizzle inference edge.
    foreignKey({
      name: "intentions_tenant_portfolio_fk",
      columns: [t.tenantId, t.portfolioId],
      foreignColumns: [demoPortfolios.tenantId, demoPortfolios.id],
    }),
    unique("intentions_tenant_id_id_unique").on(t.tenantId, t.id),
  ],
);
export const projectionRuns = pgTable(
  "projection_runs",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    intentionId: uuid("intention_id").notNull(),
    asOfTransactionId: uuid("as_of_transaction_id").notNull(),
    projectionGeneration: integer("projection_generation").notNull(),
    inputHash: text("input_hash").notNull(),
    modelVersion: text("model_version").notNull(),
    generatedAt: timestamp("generated_at", { withTimezone: true }).notNull(),
    status: text("status").notNull(),
    resetGeneration: integer("reset_generation").notNull(),
    ledgerWatermark: bigint("ledger_watermark", { mode: "number" }).notNull(),
    assumptions: jsonb("assumptions").notNull().default({}),
    uncertaintyCopy: text("uncertainty_copy")
      .notNull()
      .default("Demo projection; not a guarantee."),
  },
  (t) => [
    foreignKey({
      name: "projection_runs_tenant_intention_fk",
      columns: [t.tenantId, t.intentionId],
      foreignColumns: [intentions.tenantId, intentions.id],
    }),
    foreignKey({
      name: "projection_runs_tenant_transaction_fk",
      columns: [t.tenantId, t.asOfTransactionId],
      foreignColumns: [ledgerTransactions.tenantId, ledgerTransactions.id],
    }),
    unique("projection_runs_tenant_generation_unique").on(
      t.tenantId,
      t.intentionId,
      t.projectionGeneration,
    ),
    unique("projection_runs_tenant_id_id_unique").on(t.tenantId, t.id),
    unique("projection_runs_aggregate_identity_unique").on(
      t.tenantId,
      t.intentionId,
      t.id,
    ),
  ],
);
export const projectionPoints = pgTable(
  "projection_points",
  {
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    runId: uuid("run_id").notNull(),
    pointDate: date("point_date").notNull(),
    lowMinor: bigint("low_minor", { mode: "bigint" }).notNull(),
    midMinor: bigint("mid_minor", { mode: "bigint" }).notNull(),
    highMinor: bigint("high_minor", { mode: "bigint" }).notNull(),
  },
  (t) => [
    foreignKey({
      name: "projection_points_tenant_run_fk",
      columns: [t.tenantId, t.runId],
      foreignColumns: [projectionRuns.tenantId, projectionRuns.id],
    }).onDelete("cascade"),
    unique("projection_points_tenant_run_date_unique").on(
      t.tenantId,
      t.runId,
      t.pointDate,
    ),
  ],
);
export const briefings = pgTable(
  "briefings",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    briefingType: text("briefing_type").notNull(),
    periodStart: date("period_start").notNull(),
    periodEnd: date("period_end").notNull(),
    generation: integer("generation").notNull(),
    supersedesId: uuid("supersedes_id"),
    sourceWatermark: uuid("source_watermark"),
    sourceHash: text("source_hash").notNull(),
    generatedAt: timestamp("generated_at", { withTimezone: true }).notNull(),
    readAt: timestamp("read_at", { withTimezone: true }),
    isCurrent: boolean("is_current").notNull().default(false),
  },
  (t) => [
    foreignKey({
      name: "briefings_tenant_supersedes_fk",
      columns: [t.tenantId, t.supersedesId],
      foreignColumns: [t.tenantId, t.id],
    }),
    unique("briefings_tenant_id_id_unique").on(t.tenantId, t.id),
    unique("briefings_source_generation_unique").on(
      t.tenantId,
      t.briefingType,
      t.periodStart,
      t.sourceHash,
    ),
  ],
);
export const briefingSections = pgTable(
  "briefing_sections",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    briefingId: uuid("briefing_id").notNull(),
    sectionType: text("section_type").notNull(),
    ordinal: integer("ordinal").notNull(),
    payload: jsonb("payload").notNull(),
    schemaVersion: integer("schema_version").notNull().default(1),
  },
  (t) => [
    foreignKey({
      name: "briefing_sections_tenant_briefing_fk",
      columns: [t.tenantId, t.briefingId],
      foreignColumns: [briefings.tenantId, briefings.id],
    }).onDelete("cascade"),
    unique("briefing_sections_tenant_briefing_ordinal_unique").on(
      t.tenantId,
      t.briefingId,
      t.ordinal,
    ),
    unique("briefing_sections_tenant_id_id_unique").on(t.tenantId, t.id),
  ],
);
export const demoPlans = pgTable("demo_plans", {
  id: uuid("id").defaultRandom().primaryKey(),
  code: text("code").notNull().unique(),
  displayName: text("display_name").notNull(),
  priceCopy: text("price_copy").notNull(),
  featureCodes: jsonb("feature_codes").notNull().default([]),
  status: text("status").notNull(),
});
export const tenantEntitlements = pgTable(
  "tenant_entitlements",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    planId: uuid("plan_id")
      .notNull()
      .references(() => demoPlans.id),
    status: text("status").notNull(),
    source: text("source").notNull().default("demo"),
    startsAt: timestamp("starts_at", { withTimezone: true }).notNull(),
    endsAt: timestamp("ends_at", { withTimezone: true }),
    version: integer("version").notNull().default(1),
    resetGeneration: integer("reset_generation").notNull().default(1),
  },
  (t) => [
    unique("tenant_entitlements_tenant_id_id_unique").on(t.tenantId, t.id),
  ],
);
export const entitlementEvents = pgTable(
  "entitlement_events",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    entitlementId: uuid("entitlement_id").notNull(),
    eventType: text("event_type").notNull(),
    occurredAt: timestamp("occurred_at", { withTimezone: true }).notNull(),
    commandId: uuid("command_id"),
  },
  (t) => [
    foreignKey({
      name: "entitlement_events_tenant_entitlement_fk",
      columns: [t.tenantId, t.entitlementId],
      foreignColumns: [tenantEntitlements.tenantId, tenantEntitlements.id],
    }),
    foreignKey({
      name: "entitlement_events_tenant_command_fk",
      columns: [t.tenantId, t.commandId],
      foreignColumns: [simulationCommands.tenantId, simulationCommands.id],
    }),
    unique("entitlement_events_tenant_id_id_unique").on(t.tenantId, t.id),
  ],
);
export const demoCheckoutSessions = pgTable(
  "demo_checkout_sessions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    planId: uuid("plan_id")
      .notNull()
      .references(() => demoPlans.id),
    status: text("status").notNull(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    idempotencyId: uuid("idempotency_id").notNull(),
    resetGeneration: integer("reset_generation").notNull().default(1),
    version: integer("version").notNull().default(1),
  },
  (t) => [
    foreignKey({
      name: "demo_checkout_sessions_tenant_idempotency_fk",
      columns: [t.tenantId, t.idempotencyId],
      foreignColumns: [idempotencyRecords.tenantId, idempotencyRecords.id],
    }),
    unique("demo_checkout_sessions_tenant_idempotency_unique").on(
      t.tenantId,
      t.idempotencyId,
    ),
    unique("demo_checkout_sessions_tenant_id_id_unique").on(t.tenantId, t.id),
  ],
);
export const notifications = pgTable(
  "notifications",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    kind: text("kind").notNull(),
    title: text("title").notNull(),
    body: text("body").notNull(),
    deepLink: text("deep_link"),
    scheduledAt: timestamp("scheduled_at", { withTimezone: true }),
    readAt: timestamp("read_at", { withTimezone: true }),
  },
  (t) => [unique("notifications_tenant_id_id_unique").on(t.tenantId, t.id)],
);
export const notificationDeliveries = pgTable(
  "notification_deliveries",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    notificationId: uuid("notification_id").notNull(),
    installationId: uuid("installation_id").notNull(),
    status: text("status").notNull(),
    attempt: integer("attempt").notNull().default(0),
    providerCode: text("provider_code"),
    sentAt: timestamp("sent_at", { withTimezone: true }),
  },
  (t) => [
    foreignKey({
      name: "notification_deliveries_tenant_notification_fk",
      columns: [t.tenantId, t.notificationId],
      foreignColumns: [notifications.tenantId, notifications.id],
    }),
    foreignKey({
      name: "notification_deliveries_tenant_installation_fk",
      columns: [t.tenantId, t.installationId],
      foreignColumns: [deviceInstallations.tenantId, deviceInstallations.id],
    }),
    unique("notification_deliveries_tenant_attempt_unique").on(
      t.tenantId,
      t.notificationId,
      t.installationId,
      t.attempt,
    ),
    unique("notification_deliveries_tenant_id_id_unique").on(t.tenantId, t.id),
  ],
);
export const privacyRequests = pgTable(
  "privacy_requests",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    requestType: text("request_type").notNull(),
    status: text("status").notNull(),
    snapshotAt: timestamp("snapshot_at", { withTimezone: true }),
    sourceWatermark: uuid("source_watermark"),
    archiveSchemaVersion: integer("archive_schema_version"),
    verifiedAt: timestamp("verified_at", { withTimezone: true }),
    queuedAt: timestamp("queued_at", { withTimezone: true }),
    completedAt: timestamp("completed_at", { withTimezone: true }),
    failureCode: text("failure_code"),
  },
  (t) => [unique("privacy_requests_tenant_id_id_unique").on(t.tenantId, t.id)],
);
export const privacyExportArtifacts = pgTable(
  "privacy_export_artifacts",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    requestId: uuid("request_id").notNull(),
    r2Key: text("r2_key").notNull().unique(),
    manifestChecksum: text("manifest_checksum").notNull(),
    publicationState: text("publication_state").notNull(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    downloadedAt: timestamp("downloaded_at", { withTimezone: true }),
  },
  (t) => [
    foreignKey({
      name: "privacy_export_artifacts_tenant_request_fk",
      columns: [t.tenantId, t.requestId],
      foreignColumns: [privacyRequests.tenantId, privacyRequests.id],
    }).onDelete("cascade"),
    unique("privacy_export_artifacts_tenant_request_unique").on(
      t.tenantId,
      t.requestId,
    ),
    unique("privacy_export_artifacts_tenant_id_id_unique").on(t.tenantId, t.id),
  ],
);
export const contentReports = pgTable(
  "content_reports",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    targetKind: text("target_kind").notNull(),
    targetId: uuid("target_id")
      .notNull()
      .references(() => editorialItems.id),
    reasonCode: text("reason_code").notNull(),
    detail: text("detail"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [unique("content_reports_tenant_id_id_unique").on(t.tenantId, t.id)],
);

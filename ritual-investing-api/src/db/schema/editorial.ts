import {
  bigint,
  boolean,
  date,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";

import { tenants } from "./identity";

export const staffPrincipals = pgTable("staff_principals", {
  id: uuid("id").defaultRandom().primaryKey(),
  auth0Subject: text("auth0_subject").notNull().unique(),
  accessIdentity: text("access_identity").notNull(),
  allowedClientId: text("allowed_client_id").notNull(),
  status: text("status").notNull().default("active"),
  revocationEpoch: integer("revocation_epoch").notNull().default(0),
  displayLabel: text("display_label").notNull(),
  lastVerifiedAt: timestamp("last_verified_at", { withTimezone: true }),
});

export const mediaUploadIntents = pgTable("media_upload_intents", {
  id: uuid("id").defaultRandom().primaryKey(),
  actorStaffId: uuid("actor_staff_id")
    .notNull()
    .references(() => staffPrincipals.id),
  r2Key: text("r2_key").notNull().unique(),
  expectedMime: text("expected_mime").notNull(),
  expectedByteSize: bigint("expected_byte_size", { mode: "number" }).notNull(),
  expectedChecksum: text("expected_checksum").notNull(),
  status: text("status").notNull().default("issued"),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  consumedAt: timestamp("consumed_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const mediaAssets = pgTable("media_assets", {
  id: uuid("id").defaultRandom().primaryKey(),
  r2Key: text("r2_key").notNull().unique(),
  mimeType: text("mime_type").notNull(),
  byteSize: bigint("byte_size", { mode: "number" }).notNull(),
  checksum: text("checksum").notNull(),
  width: integer("width"),
  height: integer("height"),
  quarantineStatus: text("quarantine_status").notNull(),
  scanResult: text("scan_result"),
  status: text("status").notNull(),
  uploadIntentId: uuid("upload_intent_id")
    .unique()
    .references(() => mediaUploadIntents.id),
  actorStaffId: uuid("actor_staff_id").references(() => staffPrincipals.id),
  schemaVersion: integer("schema_version").notNull().default(1),
  acceptedAt: timestamp("accepted_at", { withTimezone: true }),
  version: integer("version").notNull().default(1),
});

export const editorialItems = pgTable("editorial_items", {
  id: uuid("id").defaultRandom().primaryKey(),
  kind: text("kind").notNull(),
  slug: text("slug").notNull().unique(),
  currentPublishedRevisionId: uuid("current_published_revision_id"),
  status: text("status").notNull().default("draft"),
});

export const editorialRevisions = pgTable(
  "editorial_revisions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    itemId: uuid("item_id")
      .notNull()
      .references(() => editorialItems.id),
    revisionNumber: integer("revision_number").notNull(),
    state: text("state").notNull(),
    authorStaffId: uuid("author_staff_id")
      .notNull()
      .references(() => staffPrincipals.id),
    contentHash: text("content_hash").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [
    unique("editorial_revisions_item_revision_unique").on(
      table.itemId,
      table.revisionNumber,
    ),
  ],
);

export const editorialReviewRequests = pgTable("editorial_review_requests", {
  id: uuid("id").defaultRandom().primaryKey(),
  revisionId: uuid("revision_id")
    .notNull()
    .references(() => editorialRevisions.id),
  requestedBy: uuid("requested_by")
    .notNull()
    .references(() => staffPrincipals.id),
  requestedAt: timestamp("requested_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  highTrust: boolean("high_trust").notNull().default(false),
  status: text("status").notNull().default("open"),
});

export const editorialReviewDecisions = pgTable("editorial_review_decisions", {
  id: uuid("id").defaultRandom().primaryKey(),
  requestId: uuid("request_id")
    .notNull()
    .references(() => editorialReviewRequests.id),
  reviewerId: uuid("reviewer_id")
    .notNull()
    .references(() => staffPrincipals.id),
  decision: text("decision").notNull(),
  reason: text("reason").notNull(),
  decidedAt: timestamp("decided_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const publicationEvents = pgTable("publication_events", {
  id: uuid("id").defaultRandom().primaryKey(),
  itemId: uuid("item_id")
    .notNull()
    .references(() => editorialItems.id),
  revisionId: uuid("revision_id")
    .notNull()
    .references(() => editorialRevisions.id),
  action: text("action").notNull(),
  effectiveAt: timestamp("effective_at", { withTimezone: true }).notNull(),
  actorId: uuid("actor_id")
    .notNull()
    .references(() => staffPrincipals.id),
  reason: text("reason").notNull(),
});

export const assets = pgTable(
  "assets",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    slug: text("slug").notNull().unique(),
    symbol: text("symbol").notNull(),
    name: text("name").notNull(),
    assetType: text("asset_type").notNull(),
    currency: text("currency").notNull(),
    exchange: text("exchange"),
    isDemo: boolean("is_demo").notNull().default(true),
    status: text("status").notNull(),
  },
  (table) => [
    unique("assets_symbol_exchange_unique").on(table.symbol, table.exchange),
  ],
);

export const assetMetricSnapshots = pgTable(
  "asset_metric_snapshots",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    assetId: uuid("asset_id")
      .notNull()
      .references(() => assets.id),
    observedAt: timestamp("observed_at", { withTimezone: true }).notNull(),
    priceMinor: bigint("price_minor", { mode: "bigint" }).notNull(),
    changeBps: integer("change_bps"),
    expenseRatioBps: integer("expense_ratio_bps"),
    sourceLabel: text("source_label").notNull(),
    isDemo: boolean("is_demo").notNull().default(true),
  },
  (table) => [
    unique("asset_metric_snapshots_asset_observed_source_unique").on(
      table.assetId,
      table.observedAt,
      table.sourceLabel,
    ),
    unique("asset_metric_snapshots_asset_identity_unique").on(
      table.assetId,
      table.id,
    ),
  ],
);

export const evidenceSources = pgTable("evidence_sources", {
  id: uuid("id").defaultRandom().primaryKey(),
  canonicalUrl: text("canonical_url").notNull().unique(),
  title: text("title").notNull(),
  publisher: text("publisher").notNull(),
  publishedAt: timestamp("published_at", { withTimezone: true }),
  retrievedAt: timestamp("retrieved_at", { withTimezone: true }).notNull(),
  sourceKind: text("source_kind").notNull(),
  status: text("status").notNull(),
});

export const evidenceClaims = pgTable("evidence_claims", {
  id: uuid("id").defaultRandom().primaryKey(),
  sourceId: uuid("source_id")
    .notNull()
    .references(() => evidenceSources.id),
  claimType: text("claim_type").notNull(),
  summary: text("summary").notNull(),
  observedAt: timestamp("observed_at", { withTimezone: true }),
  uncertainty: text("uncertainty").notNull(),
  status: text("status").notNull(),
});

export const ritualScenarios = pgTable("ritual_scenarios", {
  id: uuid("id").defaultRandom().primaryKey(),
  editorialItemId: uuid("editorial_item_id")
    .notNull()
    .unique()
    .references(() => editorialItems.id),
  scenarioKey: text("scenario_key").notNull().unique(),
  mode: text("mode").notNull(),
  cadence: text("cadence").notNull(),
});
export const ritualScenarioRevisions = pgTable("ritual_scenario_revisions", {
  revisionId: uuid("revision_id")
    .primaryKey()
    .references(() => editorialRevisions.id),
  title: text("title").notNull(),
  interpretation: text("interpretation").notNull(),
  guidance: text("guidance").notNull(),
  marketLabel: text("market_label").notNull(),
  artMediaId: uuid("art_media_id").references(() => mediaAssets.id),
  observationAt: timestamp("observation_at", { withTimezone: true }).notNull(),
  uncertainty: text("uncertainty").notNull(),
});
export const ritualScenarioIdeas = pgTable(
  "ritual_scenario_ideas",
  {
    revisionId: uuid("revision_id")
      .notNull()
      .references(() => ritualScenarioRevisions.revisionId),
    assetId: uuid("asset_id")
      .notNull()
      .references(() => assets.id),
    ordinal: integer("ordinal").notNull(),
    appearanceReason: text("appearance_reason").notNull(),
    riskSummary: text("risk_summary").notNull(),
  },
  (table) => [
    unique("ritual_scenario_ideas_revision_ordinal_unique").on(
      table.revisionId,
      table.ordinal,
    ),
  ],
);
export const ritualScenarioEvidence = pgTable(
  "ritual_scenario_evidence",
  {
    revisionId: uuid("revision_id")
      .notNull()
      .references(() => ritualScenarioRevisions.revisionId),
    claimId: uuid("claim_id")
      .notNull()
      .references(() => evidenceClaims.id),
    ordinal: integer("ordinal").notNull(),
    factorLabel: text("factor_label").notNull(),
  },
  (table) => [
    unique("ritual_scenario_evidence_revision_ordinal_unique").on(
      table.revisionId,
      table.ordinal,
    ),
  ],
);
export const ritualSchedules = pgTable(
  "ritual_schedules",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    localDate: date("local_date").notNull(),
    mode: text("mode").notNull(),
    revisionId: uuid("revision_id")
      .notNull()
      .references(() => editorialRevisions.id),
    audience: text("audience").notNull(),
    state: text("state").notNull(),
    effectiveAt: timestamp("effective_at", { withTimezone: true }).notNull(),
  },
  (table) => [
    unique("ritual_schedules_date_mode_audience_unique").on(
      table.localDate,
      table.mode,
      table.audience,
    ),
  ],
);
export const dailyRitualAssignments = pgTable(
  "daily_ritual_assignments",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    localDate: date("local_date").notNull(),
    mode: text("mode").notNull(),
    scheduleId: uuid("schedule_id")
      .notNull()
      .references(() => ritualSchedules.id),
    revisionId: uuid("revision_id")
      .notNull()
      .references(() => editorialRevisions.id),
    rowanRevisionId: uuid("rowan_revision_id"),
    state: text("state").notNull(),
    revealedAt: timestamp("revealed_at", { withTimezone: true }),
    completedAt: timestamp("completed_at", { withTimezone: true }),
    version: integer("version").notNull().default(1),
  },
  (table) => [
    unique("daily_ritual_assignments_tenant_date_mode_unique").on(
      table.tenantId,
      table.localDate,
      table.mode,
    ),
  ],
);

export const rowanScripts = pgTable("rowan_scripts", {
  id: uuid("id").defaultRandom().primaryKey(),
  editorialItemId: uuid("editorial_item_id")
    .notNull()
    .unique()
    .references(() => editorialItems.id),
  scriptKey: text("script_key").notNull().unique(),
  surface: text("surface").notNull(),
});
export const rowanScriptRevisions = pgTable("rowan_script_revisions", {
  revisionId: uuid("revision_id")
    .primaryKey()
    .references(() => editorialRevisions.id),
  bodyTemplate: text("body_template").notNull(),
  allowedTokens: jsonb("allowed_tokens").notNull().default([]),
  riskFooter: text("risk_footer").notNull(),
});
export const rowanContextBindings = pgTable("rowan_context_bindings", {
  id: uuid("id").defaultRandom().primaryKey(),
  surface: text("surface").notNull(),
  contextKey: text("context_key").notNull(),
  scriptId: uuid("script_id")
    .notNull()
    .references(() => rowanScripts.id),
  priority: integer("priority").notNull(),
});
export const assetCodexEntries = pgTable("asset_codex_entries", {
  id: uuid("id").defaultRandom().primaryKey(),
  editorialItemId: uuid("editorial_item_id")
    .notNull()
    .unique()
    .references(() => editorialItems.id),
  assetId: uuid("asset_id")
    .notNull()
    .unique()
    .references(() => assets.id),
});
export const assetCodexRevisions = pgTable("asset_codex_revisions", {
  revisionId: uuid("revision_id")
    .primaryKey()
    .references(() => editorialRevisions.id),
  thesis: text("thesis").notNull(),
  appearanceReason: text("appearance_reason").notNull(),
  metricsAsOf: timestamp("metrics_as_of", { withTimezone: true }).notNull(),
  limitations: text("limitations").notNull(),
});
export const assetCodexRisks = pgTable(
  "asset_codex_risks",
  {
    revisionId: uuid("revision_id")
      .notNull()
      .references(() => assetCodexRevisions.revisionId),
    ordinal: integer("ordinal").notNull(),
    title: text("title").notNull(),
    detail: text("detail").notNull(),
    severity: text("severity").notNull(),
  },
  (t) => [
    unique("asset_codex_risks_revision_ordinal_unique").on(
      t.revisionId,
      t.ordinal,
    ),
  ],
);
export const assetCodexEvidence = pgTable("asset_codex_evidence", {
  revisionId: uuid("revision_id")
    .notNull()
    .references(() => assetCodexRevisions.revisionId),
  claimId: uuid("claim_id")
    .notNull()
    .references(() => evidenceClaims.id),
  ordinal: integer("ordinal").notNull(),
});
export const companies = pgTable("companies", {
  id: uuid("id").defaultRandom().primaryKey(),
  slug: text("slug").notNull().unique(),
  name: text("name").notNull(),
  assetId: uuid("asset_id").references(() => assets.id),
  focusLabel: text("focus_label"),
  websiteUrl: text("website_url"),
  isFictional: boolean("is_fictional").notNull().default(false),
  status: text("status").notNull(),
});
export const covenEntries = pgTable("coven_entries", {
  id: uuid("id").defaultRandom().primaryKey(),
  editorialItemId: uuid("editorial_item_id")
    .notNull()
    .unique()
    .references(() => editorialItems.id),
  companyId: uuid("company_id")
    .notNull()
    .unique()
    .references(() => companies.id),
});
export const covenEntryRevisions = pgTable("coven_entry_revisions", {
  revisionId: uuid("revision_id")
    .primaryKey()
    .references(() => editorialRevisions.id),
  summary: text("summary").notNull(),
  inclusionRationale: text("inclusion_rationale").notNull(),
  limitations: text("limitations").notNull(),
});
export const covenQualifications = pgTable("coven_qualifications", {
  id: uuid("id").defaultRandom().primaryKey(),
  entryId: uuid("entry_id")
    .notNull()
    .references(() => covenEntries.id),
  category: text("category").notNull(),
  personName: text("person_name").notNull(),
  validFrom: date("valid_from").notNull(),
  validTo: date("valid_to"),
  currentVerificationId: uuid("current_verification_id"),
});
export const covenVerifications = pgTable("coven_verifications", {
  id: uuid("id").defaultRandom().primaryKey(),
  qualificationId: uuid("qualification_id")
    .notNull()
    .references(() => covenQualifications.id),
  status: text("status").notNull(),
  effectiveAsOf: date("effective_as_of").notNull(),
  verifiedAt: timestamp("verified_at", { withTimezone: true }),
  verifiedBy: uuid("verified_by").references(() => staffPrincipals.id),
  supersedesId: uuid("supersedes_id"),
});
export const covenVerificationEvidence = pgTable(
  "coven_verification_evidence",
  {
    verificationId: uuid("verification_id")
      .notNull()
      .references(() => covenVerifications.id),
    claimId: uuid("claim_id")
      .notNull()
      .references(() => evidenceClaims.id),
    ordinal: integer("ordinal").notNull(),
  },
);

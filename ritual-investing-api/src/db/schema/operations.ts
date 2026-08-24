import {
  bigint,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";

import { staffPrincipals } from "./editorial";
import { tenants } from "./identity";
import { contentReports } from "./member";

export const moderationCases = pgTable("moderation_cases", {
  id: uuid("id").defaultRandom().primaryKey(),
  reportId: uuid("report_id")
    .notNull()
    .unique()
    .references(() => contentReports.id, { onDelete: "cascade" }),
  status: text("status").notNull(),
  assigneeId: uuid("assignee_id").references(() => staffPrincipals.id),
  resolutionCode: text("resolution_code"),
  resolvedAt: timestamp("resolved_at", { withTimezone: true }),
  version: integer("version").notNull().default(1),
});
export const moderationCaseDecisions = pgTable("moderation_case_decisions", {
  id: uuid("id").defaultRandom().primaryKey(),
  caseId: uuid("case_id")
    .notNull()
    .references(() => moderationCases.id),
  actorStaffId: uuid("actor_staff_id")
    .notNull()
    .references(() => staffPrincipals.id),
  outcome: text("outcome").notNull(),
  reason: text("reason").notNull(),
  decidedAt: timestamp("decided_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});
export const adminAuditEvents = pgTable("admin_audit_events", {
  id: uuid("id").defaultRandom().primaryKey(),
  actorStaffId: uuid("actor_staff_id")
    .notNull()
    .references(() => staffPrincipals.id),
  action: text("action").notNull(),
  targetKind: text("target_kind").notNull(),
  targetId: uuid("target_id"),
  beforeHash: text("before_hash"),
  afterHash: text("after_hash"),
  reason: text("reason").notNull(),
  requestId: uuid("request_id").notNull(),
  outcome: text("outcome").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});
export const adminAuditCheckpoints = pgTable("admin_audit_checkpoints", {
  id: uuid("id").defaultRandom().primaryKey(),
  cutoffAt: timestamp("cutoff_at", { withTimezone: true }).notNull().unique(),
  eventCount: bigint("event_count", { mode: "bigint" }).notNull(),
  deniedCount: bigint("denied_count", { mode: "bigint" }).notNull(),
  chainDigest: text("chain_digest").notNull(),
  recordedAt: timestamp("recorded_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});
export const securityEvents = pgTable("security_events", {
  id: uuid("id").defaultRandom().primaryKey(),
  principalHash: text("principal_hash"),
  routeClass: text("route_class").notNull(),
  eventType: text("event_type").notNull(),
  outcome: text("outcome").notNull(),
  ipPrefixHash: text("ip_prefix_hash"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});
export const outboxEvents = pgTable(
  "outbox_events",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    topic: text("topic").notNull(),
    aggregateKind: text("aggregate_kind").notNull(),
    aggregateId: uuid("aggregate_id").notNull(),
    aggregateVersion: integer("aggregate_version").notNull(),
    tenantId: uuid("tenant_id").references(() => tenants.id, {
      onDelete: "set null",
    }),
    resetGeneration: integer("reset_generation"),
    dedupeKey: text("dedupe_key").notNull(),
    payload: jsonb("payload").notNull(),
    availableAt: timestamp("available_at", { withTimezone: true }).notNull(),
    publishedAt: timestamp("published_at", { withTimezone: true }),
    schemaVersion: integer("schema_version").notNull().default(1),
    deletionGeneration: integer("deletion_generation").notNull().default(0),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [unique("outbox_events_topic_dedupe_unique").on(t.topic, t.dedupeKey)],
);
export const jobRuns = pgTable("job_runs", {
  id: uuid("id").defaultRandom().primaryKey(),
  outboxId: uuid("outbox_id")
    .notNull()
    .references(() => outboxEvents.id),
  consumer: text("consumer").notNull(),
  status: text("status").notNull(),
  attempt: integer("attempt").notNull().default(0),
  leaseUntil: timestamp("lease_until", { withTimezone: true }),
  nextAttemptAt: timestamp("next_attempt_at", { withTimezone: true }),
  correlationId: uuid("correlation_id").notNull(),
  failureCode: text("failure_code"),
  leaseOwner: uuid("lease_owner"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  completedAt: timestamp("completed_at", { withTimezone: true }),
});
export const consumerReceipts = pgTable(
  "consumer_receipts",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    outboxId: uuid("outbox_id")
      .notNull()
      .references(() => outboxEvents.id),
    consumer: text("consumer").notNull(),
    aggregateVersion: integer("aggregate_version").notNull(),
    outcomeHash: text("outcome_hash").notNull(),
    completedAt: timestamp("completed_at", { withTimezone: true }).notNull(),
    tenantId: uuid("tenant_id"),
    aggregateKind: text("aggregate_kind").notNull().default("legacy"),
    aggregateId: uuid("aggregate_id"),
    resetGeneration: integer("reset_generation").notNull().default(0),
    deletionGeneration: integer("deletion_generation").notNull().default(0),
  },
  (t) => [
    unique("consumer_receipts_event_consumer_unique").on(
      t.outboxId,
      t.consumer,
    ),
  ],
);
export const aggregateConsumerWatermarks = pgTable(
  "aggregate_consumer_watermarks",
  {
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    consumer: text("consumer").notNull(),
    aggregateKind: text("aggregate_kind").notNull(),
    aggregateId: uuid("aggregate_id").notNull(),
    aggregateVersion: integer("aggregate_version").notNull(),
    resetGeneration: integer("reset_generation").notNull(),
    deletionGeneration: integer("deletion_generation").notNull(),
    lastOutboxId: uuid("last_outbox_id")
      .notNull()
      .references(() => outboxEvents.id),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [
    unique("aggregate_consumer_watermarks_identity_unique").on(
      t.tenantId,
      t.consumer,
      t.aggregateKind,
      t.aggregateId,
    ),
  ],
);
export const deletionTombstones = pgTable(
  "deletion_tombstones",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id").notNull(),
    subjectHash: text("subject_hash").notNull(),
    effectiveAt: timestamp("effective_at", { withTimezone: true }).notNull(),
    purgeGeneration: integer("purge_generation").notNull(),
    status: text("status").notNull(),
  },
  (t) => [
    unique("deletion_tombstones_tenant_generation_unique").on(
      t.tenantId,
      t.purgeGeneration,
    ),
    unique("deletion_tombstones_subject_hash_unique").on(t.subjectHash),
  ],
);
export const purgeReceipts = pgTable(
  "purge_receipts",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tombstoneId: uuid("tombstone_id")
      .notNull()
      .references(() => deletionTombstones.id),
    purgeGeneration: integer("purge_generation").notNull(),
    startedAt: timestamp("started_at", { withTimezone: true }).notNull(),
    completedAt: timestamp("completed_at", { withTimezone: true }),
    outcomeHash: text("outcome_hash"),
    failureCode: text("failure_code"),
  },
  (t) => [
    unique("purge_receipts_tombstone_generation_unique").on(
      t.tombstoneId,
      t.purgeGeneration,
    ),
  ],
);
export const deletionJournalConfirmations = pgTable(
  "deletion_journal_confirmations",
  {
    tombstoneId: uuid("tombstone_id")
      .notNull()
      .references(() => deletionTombstones.id),
    purgeGeneration: integer("purge_generation").notNull(),
    r2Key: text("r2_key").notNull().unique(),
    bodyChecksum: text("body_checksum").notNull(),
    confirmedAt: timestamp("confirmed_at", { withTimezone: true }).notNull(),
  },
  (t) => [
    unique("deletion_journal_confirmations_identity_unique").on(
      t.tombstoneId,
      t.purgeGeneration,
    ),
  ],
);
export const deletionObjectReceipts = pgTable(
  "deletion_object_receipts",
  {
    tombstoneId: uuid("tombstone_id")
      .notNull()
      .references(() => deletionTombstones.id),
    purgeGeneration: integer("purge_generation").notNull(),
    objectClass: text("object_class").notNull(),
    prefix: text("prefix").notNull(),
    listingChecksum: text("listing_checksum").notNull(),
    confirmedEmptyAt: timestamp("confirmed_empty_at", {
      withTimezone: true,
    }).notNull(),
  },
  (t) => [
    unique("deletion_object_receipts_identity_unique").on(
      t.tombstoneId,
      t.purgeGeneration,
      t.objectClass,
    ),
  ],
);
export const deletionRestoreCheckpoints = pgTable(
  "deletion_restore_checkpoints",
  {
    restoreEpoch: text("restore_epoch").primaryKey(),
    journalPrefix: text("journal_prefix")
      .notNull()
      .default("deletion-deny/v1/"),
    highestEffectiveAt: timestamp("highest_effective_at", {
      withTimezone: true,
    }).notNull(),
    entryCount: bigint("entry_count", { mode: "bigint" }).notNull(),
    replayChecksum: text("replay_checksum").notNull(),
    completedAt: timestamp("completed_at", { withTimezone: true }).notNull(),
  },
);
export const memberCommandReceipts = pgTable(
  "member_command_receipts",
  {
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    operation: text("operation").notNull(),
    idempotencyKey: text("idempotency_key").notNull(),
    requestHash: text("request_hash").notNull(),
    response: jsonb("response").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [
    unique("member_command_receipts_identity_unique").on(
      t.tenantId,
      t.operation,
      t.idempotencyKey,
    ),
  ],
);
export const adminOperationReceipts = pgTable(
  "admin_operation_receipts",
  {
    actorStaffId: uuid("actor_staff_id")
      .notNull()
      .references(() => staffPrincipals.id),
    operation: text("operation").notNull(),
    idempotencyKey: text("idempotency_key").notNull(),
    requestHash: text("request_hash").notNull(),
    response: jsonb("response").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [
    unique("admin_operation_receipts_identity_unique").on(
      t.actorStaffId,
      t.operation,
      t.idempotencyKey,
    ),
  ],
);

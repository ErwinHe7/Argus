import {
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
  id: uuid("id").defaultRandom().primaryKey(), reportId: uuid("report_id").notNull().unique().references(() => contentReports.id, { onDelete: "cascade" }), status: text("status").notNull(),
  assigneeId: uuid("assignee_id").references(() => staffPrincipals.id), resolutionCode: text("resolution_code"), resolvedAt: timestamp("resolved_at", { withTimezone: true }),
});
export const adminAuditEvents = pgTable("admin_audit_events", {
  id: uuid("id").defaultRandom().primaryKey(), actorStaffId: uuid("actor_staff_id").notNull().references(() => staffPrincipals.id), action: text("action").notNull(), targetKind: text("target_kind").notNull(), targetId: uuid("target_id"),
  beforeHash: text("before_hash"), afterHash: text("after_hash"), reason: text("reason").notNull(), requestId: uuid("request_id").notNull(), outcome: text("outcome").notNull(), createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});
export const securityEvents = pgTable("security_events", {
  id: uuid("id").defaultRandom().primaryKey(), principalHash: text("principal_hash"), routeClass: text("route_class").notNull(), eventType: text("event_type").notNull(), outcome: text("outcome").notNull(),
  ipPrefixHash: text("ip_prefix_hash"), createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});
export const outboxEvents = pgTable("outbox_events", {
  id: uuid("id").defaultRandom().primaryKey(), topic: text("topic").notNull(), aggregateKind: text("aggregate_kind").notNull(), aggregateId: uuid("aggregate_id").notNull(), aggregateVersion: integer("aggregate_version").notNull(),
  tenantId: uuid("tenant_id").references(() => tenants.id, { onDelete: "cascade" }), resetGeneration: integer("reset_generation"), dedupeKey: text("dedupe_key").notNull(), payload: jsonb("payload").notNull(),
  availableAt: timestamp("available_at", { withTimezone: true }).notNull(), publishedAt: timestamp("published_at", { withTimezone: true }),
}, (t) => [unique("outbox_events_topic_dedupe_unique").on(t.topic, t.dedupeKey)]);
export const jobRuns = pgTable("job_runs", {
  id: uuid("id").defaultRandom().primaryKey(), outboxId: uuid("outbox_id").notNull().references(() => outboxEvents.id), consumer: text("consumer").notNull(), status: text("status").notNull(), attempt: integer("attempt").notNull().default(0),
  leaseUntil: timestamp("lease_until", { withTimezone: true }), nextAttemptAt: timestamp("next_attempt_at", { withTimezone: true }), correlationId: uuid("correlation_id").notNull(), failureCode: text("failure_code"),
});
export const consumerReceipts = pgTable("consumer_receipts", {
  id: uuid("id").defaultRandom().primaryKey(), outboxId: uuid("outbox_id").notNull().references(() => outboxEvents.id), consumer: text("consumer").notNull(), aggregateVersion: integer("aggregate_version").notNull(),
  outcomeHash: text("outcome_hash").notNull(), completedAt: timestamp("completed_at", { withTimezone: true }).notNull(),
}, (t) => [unique("consumer_receipts_event_consumer_unique").on(t.outboxId, t.consumer)]);
export const deletionTombstones = pgTable("deletion_tombstones", {
  id: uuid("id").defaultRandom().primaryKey(), tenantId: uuid("tenant_id").notNull(), subjectHash: text("subject_hash").notNull(), effectiveAt: timestamp("effective_at", { withTimezone: true }).notNull(), purgeGeneration: integer("purge_generation").notNull(), status: text("status").notNull(),
}, (t) => [unique("deletion_tombstones_tenant_generation_unique").on(t.tenantId, t.purgeGeneration), unique("deletion_tombstones_subject_hash_unique").on(t.subjectHash)]);
export const purgeReceipts = pgTable("purge_receipts", {
  id: uuid("id").defaultRandom().primaryKey(), tombstoneId: uuid("tombstone_id").notNull().references(() => deletionTombstones.id), purgeGeneration: integer("purge_generation").notNull(),
  startedAt: timestamp("started_at", { withTimezone: true }).notNull(), completedAt: timestamp("completed_at", { withTimezone: true }), outcomeHash: text("outcome_hash"), failureCode: text("failure_code"),
}, (t) => [unique("purge_receipts_tombstone_generation_unique").on(t.tombstoneId, t.purgeGeneration)]);

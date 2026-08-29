export type PrivacyExportCollectionRegistration = Readonly<{
  name: string;
  sourceRelation: `argus_${"app" | "brokerage"}.${string}`;
}>;

/** SQL owns each collection's allowlisted field projection and deterministic sealing. */
export const applicationPrivacyExportCollections = Object.freeze([
  { name: "member", sourceRelation: "argus_app.members" },
  { name: "profile", sourceRelation: "argus_app.profiles" },
  { name: "preferences", sourceRelation: "argus_app.preferences" },
  { name: "astrology_profile", sourceRelation: "argus_app.astrology_profiles" },
  { name: "investor_profile", sourceRelation: "argus_app.investor_profiles" },
  { name: "onboarding", sourceRelation: "argus_app.onboarding_states" },
  { name: "consents", sourceRelation: "argus_app.consent_records" },
  { name: "notification_preferences", sourceRelation: "argus_app.notification_preferences" },
  { name: "ritual_assignments", sourceRelation: "argus_app.daily_ritual_assignments" },
  { name: "circles", sourceRelation: "argus_app.circles" },
  { name: "circle_assets", sourceRelation: "argus_app.circle_assets" },
  { name: "saved_items", sourceRelation: "argus_app.member_saved_items" },
  { name: "intentions", sourceRelation: "argus_app.intentions" },
  { name: "future_mirror_runs", sourceRelation: "argus_app.future_mirror_runs" },
  { name: "future_mirror_points", sourceRelation: "argus_app.future_mirror_points" },
  { name: "briefings", sourceRelation: "argus_app.briefings" },
  { name: "briefing_sections", sourceRelation: "argus_app.briefing_sections" },
  { name: "notifications", sourceRelation: "argus_app.notifications" },
  { name: "privacy_requests", sourceRelation: "argus_app.privacy_requests" },
  { name: "content_reports", sourceRelation: "argus_app.content_reports" },
  { name: "onboarding_step_completions", sourceRelation: "argus_app.onboarding_step_completions" },
  { name: "notification_quiet_hours", sourceRelation: "argus_app.notification_quiet_hours" },
  { name: "briefing_read_states", sourceRelation: "argus_app.briefing_read_states" },
  { name: "content_report_targets", sourceRelation: "argus_app.content_report_targets" },
] as const satisfies readonly PrivacyExportCollectionRegistration[]);

/**
 * U5-owned member projections only. Provider credentials, raw snapshots,
 * mappings, commands, attempts, and reconciliation state live in private
 * relations and can never enter this registry.
 */
export const brokeragePrivacyExportCollections = Object.freeze([
  { name: "brokerage_connections", sourceRelation: "argus_brokerage.connections" },
  { name: "brokerage_accounts", sourceRelation: "argus_brokerage.accounts" },
  {
    name: "brokerage_active_account_selections",
    sourceRelation: "argus_brokerage.active_account_selections",
  },
  {
    name: "brokerage_account_capabilities",
    sourceRelation: "argus_brokerage.account_capabilities",
  },
  {
    name: "brokerage_projection_generations",
    sourceRelation: "argus_brokerage.projection_generations",
  },
  {
    name: "brokerage_projection_balance_facts",
    sourceRelation: "argus_brokerage.projection_balance_facts",
  },
  {
    name: "brokerage_projection_position_facts",
    sourceRelation: "argus_brokerage.projection_position_facts",
  },
  {
    name: "brokerage_projection_restriction_facts",
    sourceRelation: "argus_brokerage.projection_restriction_facts",
  },
  {
    name: "brokerage_projection_account_facts",
    sourceRelation: "argus_brokerage.projection_account_facts",
  },
  {
    name: "brokerage_order_projection_generations",
    sourceRelation: "argus_brokerage.order_projection_generations",
  },
] as const satisfies readonly PrivacyExportCollectionRegistration[]);

export const privacyExportCollections = Object.freeze([
  ...applicationPrivacyExportCollections,
  ...brokeragePrivacyExportCollections,
] as const satisfies readonly PrivacyExportCollectionRegistration[]);

import type { OutboxEvent } from "./consumer-receipts.ts";

export interface WorkerPrivacyExportSagaPort {
  exportGeneration(
    event: OutboxEvent,
    keepAlive?: () => Promise<void>,
  ): Promise<string>;
  expireGeneration(
    event: OutboxEvent,
    keepAlive?: () => Promise<void>,
  ): Promise<string>;
}

export function runPrivacyExport(
  event: OutboxEvent,
  port: WorkerPrivacyExportSagaPort,
  keepAlive?: () => Promise<void>,
): Promise<string> {
  if (event.handlerName !== "privacy-export" || event.userId === null ||
    event.tenantId === null || event.lifecycleId === null) {
    throw new Error("invalid_event_payload");
  }
  return port.exportGeneration(event, keepAlive);
}

export function runPrivacyExportRetention(
  event: OutboxEvent,
  port: WorkerPrivacyExportSagaPort,
  keepAlive?: () => Promise<void>,
): Promise<string> {
  if (event.handlerName !== "privacy-export-retention" || event.userId === null ||
    event.tenantId === null || event.lifecycleId === null) {
    throw new Error("invalid_event_payload");
  }
  return port.expireGeneration(event, keepAlive);
}

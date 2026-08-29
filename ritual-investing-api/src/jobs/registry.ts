export type DurableWorkOwner =
  | "briefings"
  | "notifications"
  | "media"
  | "moderation"
  | "privacy"
  | "brokerage";

export type DurableWorkEffect = "internal" | "external_saga";
export type DurableWorkDeadLetter = "redacted_terminal_record";
export type DurableWorkScope = "member" | "global";
export type DurableWorkSubject =
  | "briefing"
  | "media_upload"
  | "content_report"
  | "privacy_request"
  | "privacy_export_generation"
  | "deletion_tombstone"
  | "brokerage_connection"
  | "brokerage_account"
  | "provider_command";

export type DurableEventRegistration = Readonly<{
  payloadVersion: 1;
  handler: string;
  owner: DurableWorkOwner;
  scope: DurableWorkScope;
  subjectKind: DurableWorkSubject;
  effect: DurableWorkEffect;
  queue: "argus_jobs" | "brokerage_refresh" | "brokerage_reconcile";
  visibilitySeconds: number;
  maxAttempts: number;
  retryBaseSeconds: number;
  retryCapSeconds: number;
  deadLetter: DurableWorkDeadLetter;
}>;

export type DurableScheduleRegistration = Readonly<{
  cron: string;
  command: string;
  coordinator: string;
  maxBatchSize: number;
  retainedRunDays: number;
}>;

const internal = (
  handler: string,
  owner: DurableWorkOwner,
  subjectKind: DurableWorkSubject,
): DurableEventRegistration => Object.freeze({
  payloadVersion: 1,
  handler,
  owner,
  scope: "member",
  subjectKind,
  effect: "internal",
  queue: "argus_jobs",
  visibilitySeconds: 45,
  maxAttempts: 5,
  retryBaseSeconds: 15,
  retryCapSeconds: 900,
  deadLetter: "redacted_terminal_record",
});

const external = (
  handler: string,
  owner: DurableWorkOwner,
  subjectKind: DurableWorkSubject,
  maxAttempts = 5,
  queue: DurableEventRegistration["queue"] = "argus_jobs",
  scope: DurableWorkScope = "member",
): DurableEventRegistration => Object.freeze({
  payloadVersion: 1,
  handler,
  owner,
  scope,
  subjectKind,
  effect: "external_saga",
  queue,
  visibilitySeconds: 45,
  maxAttempts,
  retryBaseSeconds: 15,
  retryCapSeconds: 900,
  deadLetter: "redacted_terminal_record",
});

export const durableWorkRegistry = Object.freeze({
  version: 1 as const,
  events: Object.freeze({
    "briefing.daily.requested": internal(
      "briefing-generation-coordinator",
      "briefings",
      "briefing",
    ),
    "briefing.weekly.requested": internal(
      "briefing-generation-coordinator",
      "briefings",
      "briefing",
    ),
    "briefing.moon_cycle.requested": internal(
      "briefing-generation-coordinator",
      "briefings",
      "briefing",
    ),
    "briefing.daily.generated": internal(
      "notification-record-writer",
      "notifications",
      "briefing",
    ),
    "briefing.weekly.generated": internal(
      "notification-record-writer",
      "notifications",
      "briefing",
    ),
    "briefing.moon_cycle.generated": internal(
      "notification-record-writer",
      "notifications",
      "briefing",
    ),
    "media.structural_validation.requested": external(
      "media-structural-validation",
      "media",
      "media_upload",
    ),
    "media.quarantine.cleanup": external("media-cleanup", "media", "media_upload"),
    "content-report.created": internal("moderation-triage", "moderation", "content_report"),
    "privacy.export.requested": external("privacy-export", "privacy", "privacy_request"),
    "privacy.deletion.requested": external(
      "privacy-purge",
      "privacy",
      "deletion_tombstone",
      10,
      "argus_jobs",
      "global",
    ),
    "privacy.export.retention.requested": external(
      "privacy-export-retention",
      "privacy",
      "privacy_export_generation",
    ),
    "webull.token.refresh.requested": external(
      "webull-token-refresh",
      "brokerage",
      "brokerage_connection",
      5,
      "brokerage_refresh",
    ),
    "webull.projection.refresh.requested": external(
      "webull-projection-refresh",
      "brokerage",
      "brokerage_account",
      5,
      "brokerage_refresh",
    ),
    "webull.command.reconciliation.requested": external(
      "webull-reconciliation",
      "brokerage",
      "provider_command",
      4,
      "brokerage_reconcile",
    ),
  }),
  schedules: Object.freeze({
    "argus-durable-work-coordinate": Object.freeze({
      cron: "* * * * *",
      command: "select argus_private.coordinate_argus_durable_work(25);",
      coordinator: "coordinate_argus_durable_work",
      maxBatchSize: 25,
      retainedRunDays: 7,
    }),
    "argus-worker-dispatch-enqueue": Object.freeze({
      cron: "* * * * *",
      command: "select argus_private.enqueue_worker_dispatch();",
      coordinator: "enqueue_worker_dispatch",
      maxBatchSize: 1,
      retainedRunDays: 7,
    }),
    "argus-webull-recovery-coordinate": Object.freeze({
      cron: "*/5 * * * *",
      command: "select argus_private.coordinate_webull_recovery(25);",
      coordinator: "coordinate_webull_recovery",
      maxBatchSize: 25,
      retainedRunDays: 7,
    }),
  }),
});

export type DurableEventType = keyof typeof durableWorkRegistry.events;
export type DurableJobHandler =
  (typeof durableWorkRegistry.events)[DurableEventType]["handler"];

export function eventRegistration(
  eventType: string,
): DurableEventRegistration | null {
  return Object.prototype.hasOwnProperty.call(durableWorkRegistry.events, eventType)
    ? durableWorkRegistry.events[eventType as DurableEventType]
    : null;
}

export function validateDurableWorkRegistry(
  registry: typeof durableWorkRegistry,
): readonly string[] {
  const errors: string[] = [];
  const handlers = new Set<string>();
  for (const [eventType, registration] of Object.entries(registry.events)) {
    if (!/^[a-z][a-z0-9_.-]+$/.test(eventType)) errors.push(`${eventType}:event_type`);
    if (!/^[a-z][a-z0-9-]+$/.test(registration.handler)) {
      errors.push(`${eventType}:handler`);
    }
    handlers.add(registration.handler);
    if (registration.visibilitySeconds < 15 || registration.visibilitySeconds > 55) {
      errors.push(`${eventType}:visibility`);
    }
    if (registration.maxAttempts < 1 || registration.maxAttempts > 10) {
      errors.push(`${eventType}:max_attempts`);
    }
    if (
      registration.retryBaseSeconds < 1 ||
      registration.retryCapSeconds < registration.retryBaseSeconds
    ) errors.push(`${eventType}:retry`);
  }
  if (handlers.size < 1) errors.push("handlers:empty");
  return errors;
}

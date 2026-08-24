import type { Bindings } from "../config/env.ts";
import type { DatabasePoolFactory } from "../db/client.ts";
import { consumeWithReceipt } from "./consumer-receipts.ts";
import { handlerFor } from "./handlers.ts";
import { completeJob, failJob, leaseJob } from "./job-runs.ts";
import { parseQueueWork, type QueueWorkMessage } from "./queue-consumer.ts";
import { decideRetry } from "./retry-policy.ts";

const knownFailureCodes = new Set([
  "deletion_journal_verification_failed",
  "invalid_event_payload",
  "media_intent_missing",
  "media_intent_not_scanning",
  "media_intent_race",
  "media_quarantine_mismatch",
  "media_processor_unavailable",
  "media_scan_unavailable",
  "media_scanner_invalid_response",
  "media_scanner_unavailable",
  "notification_delivery_unavailable",
  "notification_provider_rate_limited",
  "notification_provider_unavailable",
  "privacy_export_unavailable",
  "privacy_purge_unavailable",
  "r2_purge_incomplete",
  "restore_journal_binding_missing",
  "tombstone_missing",
]);

function failureCode(error: unknown): string {
  return error instanceof Error && knownFailureCodes.has(error.message)
    ? error.message
    : "internal_failure";
}

function consumerKilled(
  environment: Bindings,
  message: QueueWorkMessage,
): boolean {
  if (environment.KILL_SWITCH_QUEUE === "on") return true;
  if (
    message.consumer.startsWith("notification-") &&
    environment.KILL_SWITCH_NOTIFICATIONS === "on"
  )
    return true;
  if (
    message.consumer === "privacy-export" &&
    environment.KILL_SWITCH_EXPORTS === "on"
  )
    return true;
  if (
    message.consumer === "privacy-purge" &&
    environment.KILL_SWITCH_PURGE === "on"
  )
    return true;
  if (
    message.consumer.startsWith("media-") &&
    environment.KILL_SWITCH_MEDIA === "on"
  )
    return true;
  return false;
}

export async function runQueue(
  batch: MessageBatch<unknown>,
  environment: Bindings,
  poolFactory?: DatabasePoolFactory,
) {
  const runtimeDatabaseUrl = environment.RUNTIME_DATABASE_URL;
  const schedulerDatabaseUrl = environment.SCHEDULER_DATABASE_URL;
  for (const raw of batch.messages) {
    let message: QueueWorkMessage;
    try {
      message = parseQueueWork(raw.body);
    } catch {
      raw.ack();
      continue;
    }
    const consumerDatabaseUrl =
      message.consumer === "privacy-purge"
        ? environment.PRIVACY_DATABASE_URL
        : message.consumer.startsWith("media-")
          ? environment.MEDIA_DATABASE_URL
          : runtimeDatabaseUrl;
    if (
      consumerDatabaseUrl === undefined ||
      schedulerDatabaseUrl === undefined ||
      consumerKilled(environment, message)
    ) {
      raw.retry({ delaySeconds: 300 });
      continue;
    }
    const lease = await leaseJob(
      schedulerDatabaseUrl,
      message,
      raw.attempts,
      poolFactory,
    );
    if (lease === null) {
      raw.retry({ delaySeconds: 10 });
      continue;
    }
    try {
      await consumeWithReceipt(
        consumerDatabaseUrl,
        message,
        handlerFor(message, environment),
        poolFactory,
      );
      await completeJob(schedulerDatabaseUrl, lease, poolFactory);
      raw.ack();
    } catch (error) {
      const decision = decideRetry(raw.attempts, failureCode(error));
      await failJob(schedulerDatabaseUrl, lease, decision, poolFactory);
      if (decision.action === "retry")
        raw.retry({ delaySeconds: decision.delaySeconds });
      else {
        await environment.JOBS_DLQ?.send({
          schema_version: 1,
          outbox_id: message.outbox_id,
          consumer: message.consumer,
          failure_code: decision.failureCode,
        });
        raw.ack();
      }
    }
  }
}

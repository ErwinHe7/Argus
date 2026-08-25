import {
  notificationDeliveryEnabled,
  notificationWriterEnabled,
  type Bindings,
} from "../config/env.ts";
import type { DatabasePoolFactory } from "../db/client.ts";
import { consumeWithReceipt } from "./consumer-receipts.ts";
import { handlerFor } from "./handlers.ts";
import { completeJob, failJob, leaseJob } from "./job-runs.ts";
import { parseQueueWork, type QueueWorkMessage } from "./queue-consumer.ts";
import { decideRetry } from "./retry-policy.ts";
import {
  emitOperationalTelemetry,
  type TelemetrySink,
} from "../observability/telemetry.ts";
import { sha256TextHex } from "../security/sha256.ts";

const MAX_BATCH_CONCURRENCY = 5;

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
  "delivery_lock_contended",
  "recurring_plan_delivery_failed",
  "privacy_export_retention_failed",
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
    message.consumer === "notification-writer" &&
    !notificationWriterEnabled(environment)
  )
    return true;
  if (
    message.consumer === "notification-delivery" &&
    !notificationDeliveryEnabled(environment)
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

async function redactedBodyHash(body: unknown): Promise<string> {
  let serialized: string;
  try {
    serialized = JSON.stringify(body) ?? typeof body;
  } catch {
    serialized = Object.prototype.toString.call(body);
  }
  return sha256TextHex(serialized);
}

async function parkDelivery(
  raw: Message<unknown>,
  message: QueueWorkMessage,
  queue: Queue | undefined,
): Promise<void> {
  if (queue === undefined) {
    raw.retry({ delaySeconds: 300 });
    return;
  }
  try {
    await queue.send(message, { delaySeconds: 300 });
    raw.ack();
  } catch {
    raw.retry({ delaySeconds: 300 });
  }
}

async function processMessage(
  raw: Message<unknown>,
  environment: Bindings,
  poolFactory?: DatabasePoolFactory,
  telemetrySink?: TelemetrySink,
): Promise<void> {
  let message: QueueWorkMessage;
  try {
    message = parseQueueWork(raw.body);
  } catch {
    await emitOperationalTelemetry(
      environment.ENVIRONMENT,
      {
        event_name: "queue.delivery",
        severity: "warn",
        outcome: "rejected",
        dependency: "queue",
        attempt: raw.attempts,
        failure_code: "invalid_event_payload",
      },
      telemetrySink,
    );
    try {
      if (environment.JOBS_DLQ === undefined)
        throw new Error("jobs_dlq_binding_missing");
      await environment.JOBS_DLQ.send({
        schema_version: 1,
        kind: "poison",
        failure_code: "invalid_event_payload",
        attempts: raw.attempts,
        body_hash: await redactedBodyHash(raw.body),
      });
      raw.ack();
    } catch {
      raw.retry({ delaySeconds: 60 });
    }
    return;
  }
  const runtimeDatabaseUrl = environment.RUNTIME_DATABASE_URL;
  const schedulerDatabaseUrl = environment.SCHEDULER_DATABASE_URL;
  const consumerDatabaseUrl =
    message.consumer === "privacy-purge"
      ? environment.PRIVACY_DATABASE_URL
      : message.consumer.startsWith("media-")
        ? environment.MEDIA_DATABASE_URL
        : runtimeDatabaseUrl;
  const killed = consumerKilled(environment, message);
  if (
    consumerDatabaseUrl === undefined ||
    schedulerDatabaseUrl === undefined ||
    killed
  ) {
    await emitOperationalTelemetry(
      environment.ENVIRONMENT,
      {
        event_name: "queue.delivery",
        severity: "warn",
        outcome: "deferred",
        dependency: "queue",
        consumer: message.consumer,
        attempt: raw.attempts,
        failure_code: killed
          ? "kill_switch_enabled"
          : "dependency_unavailable",
      },
      telemetrySink,
    );
    await parkDelivery(raw, message, environment.ASYNC_QUEUE);
    return;
  }
  const lease = await leaseJob(
    schedulerDatabaseUrl,
    message,
    raw.attempts,
    poolFactory,
  );
  if (lease === null) {
    await emitOperationalTelemetry(
      environment.ENVIRONMENT,
      {
        event_name: "queue.delivery",
        severity: "info",
        outcome: "lease_contended",
        dependency: "queue",
        consumer: message.consumer,
        attempt: raw.attempts,
      },
      telemetrySink,
    );
    raw.retry({ delaySeconds: 10 });
    return;
  }
  try {
    await consumeWithReceipt(
      consumerDatabaseUrl,
      message,
      handlerFor(message, environment),
      poolFactory,
    );
    await completeJob(schedulerDatabaseUrl, lease, poolFactory);
    await emitOperationalTelemetry(
      environment.ENVIRONMENT,
      {
        event_name: "queue.delivery",
        severity: "info",
        outcome: "success",
        dependency: "queue",
        consumer: message.consumer,
        attempt: raw.attempts,
      },
      telemetrySink,
    );
    raw.ack();
  } catch (error) {
    const decision = decideRetry(raw.attempts, failureCode(error));
    await emitOperationalTelemetry(
      environment.ENVIRONMENT,
      {
        event_name: "queue.delivery",
        severity: decision.action === "retry" ? "warn" : "error",
        outcome: decision.action === "retry" ? "retry" : "dead_lettered",
        dependency: "queue",
        consumer: message.consumer,
        attempt: raw.attempts,
        failure_code: decision.failureCode,
      },
      telemetrySink,
    );
    if (decision.action === "retry") {
      await failJob(schedulerDatabaseUrl, lease, decision, poolFactory);
      raw.retry({ delaySeconds: decision.delaySeconds });
      return;
    }
    try {
      if (environment.JOBS_DLQ === undefined)
        throw new Error("jobs_dlq_binding_missing");
      await environment.JOBS_DLQ.send({
        schema_version: 1,
        outbox_id: message.outbox_id,
        consumer: message.consumer,
        failure_code: decision.failureCode,
      });
      await failJob(
        schedulerDatabaseUrl,
        lease,
        decision,
        poolFactory,
      );
      raw.ack();
    } catch {
      raw.retry({ delaySeconds: 60 });
    }
  }
}

export async function runQueue(
  batch: MessageBatch<unknown>,
  environment: Bindings,
  poolFactory?: DatabasePoolFactory,
  telemetrySink?: TelemetrySink,
) {
  for (let offset = 0; offset < batch.messages.length; offset += MAX_BATCH_CONCURRENCY)
    await Promise.all(
      batch.messages
        .slice(offset, offset + MAX_BATCH_CONCURRENCY)
        .map((raw) => processMessage(raw, environment, poolFactory, telemetrySink)),
    );
}

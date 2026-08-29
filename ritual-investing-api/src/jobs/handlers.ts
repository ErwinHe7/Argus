import type { DatabaseClient } from "../db/database-port.ts";
import { sha256TextHex } from "../security/sha256.ts";
import type { OutboxEvent } from "./consumer-receipts.ts";
import {
  runMediaCleanup,
  runMediaStructuralValidation,
  type WorkerMediaSagaPort,
} from "./media.ts";
import {
  runPrivacyExport,
  runPrivacyExportRetention,
  type WorkerPrivacyExportSagaPort,
} from "./privacy-export.ts";
import type { WebullProjectionRefreshPort } from "./webull-projection-refresh.ts";
import type { WebullReconciliationPort } from "./webull-reconciliation.ts";
import type { WebullTokenRefreshPort } from "./webull-token-refresh.ts";

export interface WorkerPurgeSagaPort {
  run(tombstoneId: string, keepAlive?: () => Promise<void>): Promise<string>;
}

export type JobHandlerDependencies = Readonly<{
  media: WorkerMediaSagaPort;
  privacyExport: WorkerPrivacyExportSagaPort;
  purgeSaga: WorkerPurgeSagaPort;
  webull: Readonly<{
    tokenRefresh: WebullTokenRefreshPort;
    projectionRefresh: WebullProjectionRefreshPort;
    reconciliation: WebullReconciliationPort;
  }>;
}>;

export type JobEffect = (
  database: DatabaseClient,
  event: OutboxEvent,
) => Promise<string>;

function briefingGenerationCoordinator(): JobEffect {
  return async (database, event) => {
    const result = await database.query<{ outcome: string }>(
      "select argus_private.coordinate_briefing_generation($1) as outcome",
      [event.id],
    );
    return result.rows[0]?.outcome ?? "briefing-stale";
  };
}

function notificationRecordWriter(): JobEffect {
  return async (database, event) => {
    const result = await database.query<{ outcome: string }>(
      "select argus_private.record_in_app_notification($1) as outcome",
      [event.id],
    );
    return result.rows[0]?.outcome ?? "notification-stale";
  };
}

export async function runPrivacyPurge(
  event: OutboxEvent,
  purgeSaga: WorkerPurgeSagaPort,
  keepAlive?: () => Promise<void>,
): Promise<string> {
  if (event.userId !== null || event.tenantId !== null || event.lifecycleId !== null) {
    throw new Error("invalid_event_payload");
  }
  return purgeSaga.run(event.aggregateId, keepAlive);
}

function moderationTriage(): JobEffect {
  return async (database, event) => {
    const result = await database.query<{ outcome: string }>(
      "select argus_private.triage_content_report($1) as outcome",
      [event.id],
    );
    return result.rows[0]?.outcome ?? "global-job-stale";
  };
}

export function handlerFor(
  event: OutboxEvent,
  _dependencies: JobHandlerDependencies,
): JobEffect {
  switch (event.handlerName) {
    case "briefing-generation-coordinator":
      return briefingGenerationCoordinator();
    case "notification-record-writer":
      return notificationRecordWriter();
    case "moderation-triage":
      return moderationTriage();
    case "media-structural-validation":
    case "media-cleanup":
    case "privacy-export":
    case "privacy-export-retention":
    case "privacy-purge":
    case "webull-token-refresh":
    case "webull-projection-refresh":
    case "webull-reconciliation":
      throw new Error("external_handler_requires_saga");
    default:
      throw new Error("unsupported_job_handler");
  }
}

export function runExternalJobEffect(
  event: OutboxEvent,
  dependencies: JobHandlerDependencies,
  keepAlive?: () => Promise<void>,
): Promise<string> {
  switch (event.handlerName) {
    case "media-structural-validation":
      return runMediaStructuralValidation(event, dependencies.media, keepAlive);
    case "media-cleanup":
      return runMediaCleanup(event, dependencies.media, keepAlive);
    case "privacy-export":
      return runPrivacyExport(event, dependencies.privacyExport, keepAlive);
    case "privacy-export-retention":
      return runPrivacyExportRetention(event, dependencies.privacyExport, keepAlive);
    case "privacy-purge":
      return runPrivacyPurge(event, dependencies.purgeSaga, keepAlive);
    default:
      throw new Error("external_handler_requires_saga");
  }
}

export async function effectHash(effect: string): Promise<string> {
  return sha256TextHex(effect);
}

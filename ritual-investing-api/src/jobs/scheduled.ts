import { Pool } from "@neondatabase/serverless";

import type { Bindings } from "../config/env.ts";
import type { DatabasePoolFactory } from "../db/client.ts";
import {
  replayDeletionDenyJournal,
  restoreCutoverReady,
} from "./deletion-restore.ts";
import type { QueueWorkMessage } from "./queue-consumer.ts";
import {
  emitOperationalTelemetry,
  type TelemetrySink,
} from "../observability/telemetry.ts";

const consumersByTopic: ReadonlyArray<
  [RegExp, QueueWorkMessage["consumer"][]]
> = [
  [/^briefing\.(daily|weekly|moon_cycle)\.requested$/, ["briefing-builder"]],
  [/^briefing\.(daily|weekly|moon_cycle)\.generated$/, ["notification-writer"]],
  [/^notification\.delivery\.requested$/, ["notification-delivery"]],
  [/^media\.scan\.requested$/, ["media-scan"]],
  [/^media\.quarantine\.cleanup$/, ["media-cleanup"]],
  [/^media\.public\.cleanup$/, ["media-cleanup"]],
  [/^content-report\.created$/, ["moderation-triage"]],
  [/^privacy\.export\.requested$/, ["privacy-export"]],
  [/^privacy\.deletion\.requested$/, ["privacy-purge"]],
  [/^editorial\.publication\.scheduled$/, ["editorial-publisher"]],
  [/^recurring\.plan\.due$/, ["recurring-plan-delivery"]],
  [/^privacy\.export\.retention\.requested$/, ["privacy-export-retention"]],
];

const OUTBOX_BATCH_SIZE = 100;
const MAX_OUTBOX_BATCHES = 10;
const BRIEFING_CRONS = new Set(["0 5 * * *", "0 6 * * 1", "0 7 1,15 * *"]);

function scheduledFailureCode(error: unknown): string {
  return error instanceof Error &&
    [
      "audit_checkpoint_mismatch",
      "invalid_checkpoint_cutoff",
      "restore_journal_binding_missing",
      "privacy_database_binding_missing",
    ].includes(error.message)
    ? error.message
    : "internal_failure";
}

export function consumersForTopic(
  topic: string,
): QueueWorkMessage["consumer"][] {
  return consumersByTopic.find(([pattern]) => pattern.test(topic))?.[1] ?? [];
}

async function schedulerClient<T>(
  databaseUrl: string,
  callback: (
    client: Awaited<ReturnType<ReturnType<DatabasePoolFactory>["connect"]>>,
  ) => Promise<T>,
  poolFactory?: DatabasePoolFactory,
  role: "ritual_scheduler" | "ritual_audit_reconciler" = "ritual_scheduler",
) {
  const pool =
    poolFactory?.(databaseUrl) ??
    new Pool({ connectionString: databaseUrl, max: 1 });
  const client = await pool.connect();
  try {
    await client.query("begin");
    await client.query(`set local role ${role}`);
    await client.query("set local lock_timeout='5s'");
    await client.query("set local statement_timeout='45s'");
    const result = await callback(client);
    await client.query("commit");
    return result;
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

export async function scheduleDueRecurringPlans(
  databaseUrl: string,
  scheduledTime: number,
  poolFactory?: DatabasePoolFactory,
) {
  return schedulerClient(
    databaseUrl,
    async (client) =>
      client.query("select ritual_private.enqueue_due_recurring_plans(to_timestamp($1::double precision / 1000),100)", [scheduledTime]),
    poolFactory,
  );
}

export async function schedulePrivacyExportRetention(
  databaseUrl: string,
  scheduledTime: number,
  poolFactory?: DatabasePoolFactory,
) {
  return schedulerClient(
    databaseUrl,
    async (client) =>
      client.query("select ritual_private.enqueue_expired_privacy_exports(to_timestamp($1::double precision / 1000),100)", [scheduledTime]),
    poolFactory,
  );
}

export async function scheduleBriefings(
  databaseUrl: string,
  cron: string,
  scheduledTime: number,
  poolFactory?: DatabasePoolFactory,
) {
  const date = new Date(scheduledTime).toISOString().slice(0, 10);
  const type =
    cron === "0 6 * * 1"
      ? "weekly"
      : cron === "0 7 1,15 * *"
        ? "moon_cycle"
        : "daily";
  const sequence = Math.floor(scheduledTime / 1000);
  return schedulerClient(
    databaseUrl,
    async (client) => {
      await client.query(
        `select ritual_private.enqueue_scheduled_briefings($1,$2,$3)`,
        [type, date, sequence],
      );
    },
    poolFactory,
  );
}

export async function publishDueOutbox(
  databaseUrl: string,
  queue: Queue<QueueWorkMessage>,
  poolFactory?: DatabasePoolFactory,
) {
  let published = 0;
  for (let batchNumber = 0; batchNumber < MAX_OUTBOX_BATCHES; batchNumber += 1) {
    const due = await schedulerClient(
      databaseUrl,
      async (client) =>
        (
          await client.query<{ id: string; topic: string }>(
            `select id,topic from outbox_events where published_at is null and available_at<=now() order by available_at,id limit ${OUTBOX_BATCH_SIZE} for update skip locked`,
          )
        ).rows,
      poolFactory,
    );
    if (due.length === 0) break;
    const unroutable = due.filter(
      (event) => consumersForTopic(event.topic).length === 0,
    );
    if (unroutable.length > 0)
      await schedulerClient(
        databaseUrl,
        async (client) => {
          await client.query(
            "select ritual_private.terminalize_unroutable_outbox($1::uuid[])",
            [unroutable.map((event) => event.id)],
          );
        },
        poolFactory,
      );
    const routable = due.filter(
      (event) => consumersForTopic(event.topic).length > 0,
    );
    const messages = routable.flatMap((event) =>
      consumersForTopic(event.topic).map((consumer) => ({
        body: { schema_version: 1 as const, outbox_id: event.id, consumer },
      })),
    );
    for (let offset = 0; offset < messages.length; offset += OUTBOX_BATCH_SIZE)
      await queue.sendBatch(messages.slice(offset, offset + OUTBOX_BATCH_SIZE));
    if (routable.length > 0)
      await schedulerClient(
        databaseUrl,
        async (client) => {
          await client.query(
            `update outbox_events set published_at=coalesce(published_at,now()) where id=any($1::uuid[])`,
            [routable.map((event) => event.id)],
          );
        },
        poolFactory,
      );
    published += routable.length;
    if (due.length < OUTBOX_BATCH_SIZE) break;
  }
  return published;
}

export async function reconcileAdminAudit(
  databaseUrl: string,
  cutoff: number,
  poolFactory?: DatabasePoolFactory,
) {
  return schedulerClient(
    databaseUrl,
    async (client) =>
      (
        await client.query<{ checkpoint: Record<string, unknown> }>(
          "select ritual_private.record_admin_audit_checkpoint(to_timestamp($1::double precision / 1000))::jsonb checkpoint",
          [cutoff],
        )
      ).rows[0]?.checkpoint,
    poolFactory,
    "ritual_audit_reconciler",
  );
}

export async function runScheduled(
  controller: ScheduledController,
  environment: Bindings,
  poolFactory?: DatabasePoolFactory,
  telemetrySink?: TelemetrySink,
) {
  if (environment.KILL_SWITCH_SCHEDULED === "on") {
    await emitOperationalTelemetry(
      environment.ENVIRONMENT,
      {
        event_name: "scheduled.delivery",
        severity: "warn",
        outcome: "deferred",
        dependency: "queue",
        failure_code: "kill_switch_enabled",
      },
      telemetrySink,
    );
    return;
  }
  const databaseUrl = environment.SCHEDULER_DATABASE_URL;
  if (databaseUrl === undefined) {
    if (
      environment.ENVIRONMENT === "development" ||
      environment.ENVIRONMENT === "test"
    ) {
      await emitOperationalTelemetry(
        environment.ENVIRONMENT,
        {
          event_name: "scheduled.delivery",
          severity: "info",
          outcome: "skipped",
          dependency: "neon",
          failure_code: "dependency_unavailable",
        },
        telemetrySink,
      );
      return;
    }
    throw new Error("scheduler_database_binding_missing");
  }
  try {
    if (
      environment.EXPECTED_RESTORE_EPOCH !== undefined &&
      !(await restoreCutoverReady(
        environment.DELETION_DENY_JOURNAL,
        environment.EXPECTED_RESTORE_EPOCH,
      ))
    ) {
      if (environment.DELETION_DENY_JOURNAL === undefined)
        throw new Error("restore_journal_binding_missing");
      if (environment.PRIVACY_DATABASE_URL === undefined)
        throw new Error("privacy_database_binding_missing");
      await replayDeletionDenyJournal(
        environment.PRIVACY_DATABASE_URL,
        environment.DELETION_DENY_JOURNAL,
        environment.EXPECTED_RESTORE_EPOCH,
      );
    }
    if (BRIEFING_CRONS.has(controller.cron))
      await scheduleBriefings(
        databaseUrl,
        controller.cron,
        controller.scheduledTime,
        poolFactory,
      );
    if (controller.cron === "* * * * *") {
      await scheduleDueRecurringPlans(
        databaseUrl,
        controller.scheduledTime,
        poolFactory,
      );
      await schedulePrivacyExportRetention(
        databaseUrl,
        controller.scheduledTime,
        poolFactory,
      );
    }
    if (
      environment.KILL_SWITCH_QUEUE !== "on" &&
      environment.ASYNC_QUEUE !== undefined
    )
      await publishDueOutbox(databaseUrl, environment.ASYNC_QUEUE, poolFactory);
    if (
      controller.cron === "0 5 * * *" &&
      environment.AUDIT_DATABASE_URL !== undefined
    )
      await reconcileAdminAudit(
        environment.AUDIT_DATABASE_URL,
        controller.scheduledTime,
        poolFactory,
      );
    await emitOperationalTelemetry(
      environment.ENVIRONMENT,
      {
        event_name: "scheduled.delivery",
        severity: "info",
        outcome: "success",
        dependency: "queue",
      },
      telemetrySink,
    );
  } catch (error) {
    await emitOperationalTelemetry(
      environment.ENVIRONMENT,
      {
        event_name: "scheduled.delivery",
        severity: "error",
        outcome: "dependency_or_internal_failure",
        dependency: "neon",
        failure_code: scheduledFailureCode(error),
      },
      telemetrySink,
    );
    throw error;
  }
}

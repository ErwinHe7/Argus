import { Pool } from "@neondatabase/serverless";

import type { Bindings } from "../config/env.ts";
import type { DatabasePoolFactory } from "../db/client.ts";
import {
  replayDeletionDenyJournal,
  restoreCutoverReady,
} from "./deletion-restore.ts";
import type { QueueWorkMessage } from "./queue-consumer.ts";

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
];

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
) {
  const pool =
    poolFactory?.(databaseUrl) ??
    new Pool({ connectionString: databaseUrl, max: 1 });
  const client = await pool.connect();
  try {
    await client.query("begin");
    await client.query("set local role ritual_scheduler");
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
  const due = await schedulerClient(
    databaseUrl,
    async (client) =>
      (
        await client.query<{ id: string; topic: string }>(
          `select id,topic from outbox_events where published_at is null and available_at<=now() order by available_at,id limit 100 for update skip locked`,
        )
      ).rows,
    poolFactory,
  );
  let published = 0;
  for (const event of due) {
    const consumers = consumersForTopic(event.topic);
    if (consumers.length === 0) continue;
    for (const consumer of consumers)
      await queue.send({ schema_version: 1, outbox_id: event.id, consumer });
    await schedulerClient(
      databaseUrl,
      async (client) => {
        await client.query(
          `update outbox_events set published_at=coalesce(published_at,now()) where id=$1`,
          [event.id],
        );
      },
      poolFactory,
    );
    published += 1;
  }
  return published;
}

export async function runScheduled(
  controller: ScheduledController,
  environment: Bindings,
) {
  if (environment.KILL_SWITCH_SCHEDULED === "on") return;
  const databaseUrl = environment.SCHEDULER_DATABASE_URL;
  if (databaseUrl === undefined) {
    if (
      environment.ENVIRONMENT === "development" ||
      environment.ENVIRONMENT === "test"
    )
      return;
    throw new Error("scheduler_database_binding_missing");
  }
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
  await scheduleBriefings(
    databaseUrl,
    controller.cron,
    controller.scheduledTime,
  );
  if (environment.ASYNC_QUEUE !== undefined)
    await publishDueOutbox(databaseUrl, environment.ASYNC_QUEUE);
}

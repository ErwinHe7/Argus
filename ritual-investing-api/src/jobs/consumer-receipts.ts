import { Pool, type PoolClient } from "@neondatabase/serverless";

import type { DatabasePoolFactory } from "../db/client.ts";
import { sha256TextHex as outcomeHash } from "../security/sha256.ts";
import type { QueueWorkMessage } from "./queue-consumer.ts";

export type OutboxEvent = {
  id: string;
  topic: string;
  aggregate_kind: string;
  aggregate_id: string;
  aggregate_version: number;
  tenant_id: string | null;
  reset_generation: number;
  deletion_generation: number;
  payload: Record<string, unknown>;
};

export type DeliveryOutcome = "applied" | "duplicate" | "stale" | "deleted";
export type ConsumerEffect = (
  client: PoolClient,
  event: OutboxEvent,
) => Promise<string>;

function atOrBeyond(
  current: readonly [number, number, number],
  incoming: readonly [number, number, number],
): boolean {
  for (let index = 0; index < current.length; index += 1) {
    if (current[index]! > incoming[index]!) return true;
    if (current[index]! < incoming[index]!) return false;
  }
  return true;
}

export async function consumeWithReceipt(
  databaseUrl: string,
  message: QueueWorkMessage,
  effect: ConsumerEffect,
  poolFactory?: DatabasePoolFactory,
): Promise<DeliveryOutcome> {
  const pool =
    poolFactory?.(databaseUrl) ??
    new Pool({ connectionString: databaseUrl, max: 1 });
  const client = await pool.connect();
  let deliveryLock = false;
  try {
    await client.query("set statement_timeout='45s'");
    await client.query("select pg_advisory_lock(hashtextextended($1,0))", [
      message.outbox_id,
    ]);
    deliveryLock = true;
    await client.query("begin isolation level repeatable read");
    await client.query("set local lock_timeout='5s'");
    await client.query("set local statement_timeout='45s'");
    const privacyPurge = message.consumer === "privacy-purge";
    const editorialPublisher = message.consumer === "editorial-publisher";
    const mediaWorker = message.consumer.startsWith("media-");
    await client.query(
      privacyPurge
        ? "set local role ritual_privacy_purge"
        : editorialPublisher
          ? "set local role ritual_scheduler"
        : mediaWorker
          ? "set local role ritual_media_worker"
          : "set local role ritual_runtime",
    );
    const selected = await client.query<OutboxEvent>(
      `select id,topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,
              coalesce(reset_generation,0) reset_generation,deletion_generation,payload
         from outbox_events where id=$1`,
      [message.outbox_id],
    );
    const event = selected.rows[0];
    if (event === undefined) {
      await client.query("commit");
      return "deleted";
    }
    const prior = await client.query(
      `select 1 from consumer_receipts where outbox_id=$1 and consumer=$2`,
      [event.id, message.consumer],
    );
    if (prior.rowCount === 1) {
      await client.query("commit");
      return "duplicate";
    }
    let outcome: DeliveryOutcome = "applied";
    if (editorialPublisher) {
      if (
        event.tenant_id !== null ||
        event.topic !== "editorial.publication.scheduled"
      )
        outcome = "stale";
    } else if (mediaWorker) {
      if (event.tenant_id !== null) outcome = "stale";
    } else if (event.tenant_id === null) {
      outcome = "deleted";
    } else if (privacyPurge) {
      const authorized = await client.query<{ authorized: boolean }>(
        `select ritual_private.begin_privacy_purge_event($1,$2,$3) authorized`,
        [event.id, event.tenant_id, event.deletion_generation],
      );
      if (!authorized.rows[0]?.authorized) outcome = "stale";
    } else {
      await client.query(
        `select set_config('ritual.tenant_id',$1,true),
                set_config('ritual.principal','worker:' || $2,true),
                set_config('ritual.account_id','00000000-0000-0000-0000-000000000000',true),
                set_config('ritual.revocation_epoch','0',true)`,
        [event.tenant_id, message.consumer],
      );
      const tenant = await client.query<{ status: string }>(
        `select status from tenants where id=$1 for update`,
        [event.tenant_id],
      );
      const tenantStatus = tenant.rows[0]?.status;
      if (
        tenantStatus === undefined ||
        (message.consumer !== "privacy-purge" && tenantStatus !== "active")
      ) {
        outcome = "deleted";
      }
      if (outcome === "applied" && event.reset_generation > 0) {
        const generation = await client.query<{ reset_generation: number }>(
          `select reset_generation from tenant_demo_states where tenant_id=$1`,
          [event.tenant_id],
        );
        if (generation.rows[0]?.reset_generation !== event.reset_generation)
          outcome = "stale";
      }
      const deletion = await client.query<{ generation: number }>(
        `select ritual_private.current_deletion_generation($1) generation`,
        [event.tenant_id],
      );
      if (
        outcome === "applied" &&
        Number(deletion.rows[0]?.generation ?? 0) !== event.deletion_generation
      )
        outcome = "stale";
      if (outcome === "applied") {
        const watermark = await client.query<{
          aggregate_version: number;
          reset_generation: number;
          deletion_generation: number;
        }>(
          `select aggregate_version,reset_generation,deletion_generation
             from aggregate_consumer_watermarks
            where tenant_id=$1 and consumer=$2 and aggregate_kind=$3 and aggregate_id=$4
            for update`,
          [
            event.tenant_id,
            message.consumer,
            event.aggregate_kind,
            event.aggregate_id,
          ],
        );
        const current = watermark.rows[0];
        if (
          current !== undefined &&
          atOrBeyond(
            [
              current.reset_generation,
              current.deletion_generation,
              current.aggregate_version,
            ],
            [
              event.reset_generation,
              event.deletion_generation,
              event.aggregate_version,
            ],
          )
        )
          outcome = "stale";
      }
    }
    let effectHash = await outcomeHash(outcome);
    if (outcome === "applied")
      effectHash = await outcomeHash(await effect(client, event));
    await client.query(
      `insert into consumer_receipts(
         outbox_id,consumer,aggregate_version,outcome_hash,completed_at,tenant_id,
         aggregate_kind,aggregate_id,reset_generation,deletion_generation
       ) values ($1,$2,$3,$4,now(),$5,$6,$7,$8,$9)`,
      [
        event.id,
        message.consumer,
        event.aggregate_version,
        effectHash,
        event.tenant_id,
        event.aggregate_kind,
        event.aggregate_id,
        event.reset_generation,
        event.deletion_generation,
      ],
    );
    if (
      outcome === "applied" &&
      !privacyPurge &&
      !mediaWorker &&
      event.tenant_id !== null
    ) {
      await client.query(
        `insert into aggregate_consumer_watermarks(
           tenant_id,consumer,aggregate_kind,aggregate_id,aggregate_version,
           reset_generation,deletion_generation,last_outbox_id,updated_at
         ) values ($1,$2,$3,$4,$5,$6,$7,$8,now())
         on conflict (tenant_id,consumer,aggregate_kind,aggregate_id) do update
           set aggregate_version=excluded.aggregate_version,
               reset_generation=excluded.reset_generation,
               deletion_generation=excluded.deletion_generation,
               last_outbox_id=excluded.last_outbox_id,updated_at=now()`,
        [
          event.tenant_id,
          message.consumer,
          event.aggregate_kind,
          event.aggregate_id,
          event.aggregate_version,
          event.reset_generation,
          event.deletion_generation,
          event.id,
        ],
      );
    }
    await client.query("commit");
    return outcome;
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    if (deliveryLock)
      await client
        .query("select pg_advisory_unlock(hashtextextended($1,0))", [
          message.outbox_id,
        ])
        .catch(() => undefined);
    client.release();
    await pool.end();
  }
}

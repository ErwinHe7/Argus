import { Pool } from "@neondatabase/serverless";

import type { DatabasePoolFactory } from "../db/client.ts";
import type { QueueWorkMessage } from "./queue-consumer.ts";
import type { RetryDecision } from "./retry-policy.ts";

async function schedulerTransaction<T>(
  databaseUrl: string,
  callback: (
    client: Awaited<ReturnType<ReturnType<DatabasePoolFactory>["connect"]>>,
  ) => Promise<T>,
  poolFactory?: DatabasePoolFactory,
): Promise<T> {
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

export type JobLease = { id: string; owner: string };

export function leaseJob(
  databaseUrl: string,
  message: QueueWorkMessage,
  attempt: number,
  poolFactory?: DatabasePoolFactory,
): Promise<JobLease | null> {
  return schedulerTransaction(
    databaseUrl,
    async (client) => {
      const owner = crypto.randomUUID();
      const result = await client.query<{ id: string }>(
        `insert into job_runs(outbox_id,consumer,status,attempt,lease_until,correlation_id,lease_owner) values ($1,$2,'leased',$3,now()+interval '60 seconds',gen_random_uuid(),$4) on conflict (outbox_id,consumer,attempt) do nothing returning id`,
        [message.outbox_id, message.consumer, Math.max(0, attempt - 1), owner],
      );
      return result.rows[0] === undefined
        ? null
        : { id: result.rows[0].id, owner };
    },
    poolFactory,
  );
}

export function completeJob(
  databaseUrl: string,
  lease: JobLease,
  poolFactory?: DatabasePoolFactory,
): Promise<void> {
  return schedulerTransaction(
    databaseUrl,
    async (client) => {
      await client.query(
        `update job_runs set status='completed',completed_at=now(),lease_until=null where id=$1 and lease_owner=$2 and status='leased'`,
        [lease.id, lease.owner],
      );
    },
    poolFactory,
  );
}

export function failJob(
  databaseUrl: string,
  lease: JobLease,
  decision: RetryDecision,
  poolFactory?: DatabasePoolFactory,
): Promise<void> {
  return schedulerTransaction(
    databaseUrl,
    async (client) => {
      await client.query(
        `update job_runs set status=$3,failure_code=$4,lease_until=null,next_attempt_at=case when $3='retry' then now()+make_interval(secs=>$5) else null end,completed_at=case when $3='dead_letter' then now() else null end where id=$1 and lease_owner=$2 and status='leased'`,
        [
          lease.id,
          lease.owner,
          decision.action === "retry" ? "retry" : "dead_letter",
          decision.failureCode,
          decision.action === "retry" ? decision.delaySeconds : null,
        ],
      );
    },
    poolFactory,
  );
}

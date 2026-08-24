import type { DatabasePoolFactory } from "../db/client.ts";
import type { QueueWorkMessage } from "./queue-consumer.ts";
import type { RetryDecision } from "./retry-policy.ts";
import { withSchedulerTransaction } from "./scheduler-transaction.ts";

export type JobLease = { id: string; owner: string };

export function leaseJob(
  databaseUrl: string,
  message: QueueWorkMessage,
  attempt: number,
  poolFactory?: DatabasePoolFactory,
): Promise<JobLease | null> {
  return withSchedulerTransaction(
    databaseUrl,
    async (client) => {
      const owner = crypto.randomUUID();
      const attemptNumber = Math.max(0, attempt - 1);
      const claimed = await client.query<{ id: string }>(
        `update job_runs
            set status='leased',lease_owner=$4,lease_until=now()+interval '60 seconds',
                next_attempt_at=null,failure_code=null,completed_at=null
          where outbox_id=$1 and consumer=$2 and attempt=$3 and status='retry'
            and lease_owner is null and next_attempt_at<=now()
          returning id`,
        [message.outbox_id, message.consumer, attemptNumber, owner],
      );
      if (claimed.rows[0] !== undefined)
        return { id: claimed.rows[0].id, owner };
      const result = await client.query<{ id: string }>(
        `insert into job_runs(outbox_id,consumer,status,attempt,lease_until,correlation_id,lease_owner) values ($1,$2,'leased',$3,now()+interval '60 seconds',gen_random_uuid(),$4) on conflict (outbox_id,consumer,attempt) do nothing returning id`,
        [message.outbox_id, message.consumer, attemptNumber, owner],
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
  return withSchedulerTransaction(
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
  return withSchedulerTransaction(
    databaseUrl,
    async (client) => {
      await client.query(
        `select ritual_private.finish_job_attempt($1,$2,$3,$4,$5)`,
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

import type {
  DatabaseClient,
  DatabasePool,
} from "../../../../ritual-investing-api/src/db/database-port.ts";
import type { OutboxEvent } from "../../../../ritual-investing-api/src/jobs/consumer-receipts.ts";
import {
  effectHash,
  handlerFor,
  runPrivacyPurge,
  type JobHandlerDependencies,
} from "../../../../ritual-investing-api/src/jobs/handlers.ts";
import {
  redactedFailureCode,
  type QueueBatchResult,
  type SupabaseQueueRuntime,
  type WorkerLease,
} from "../../../../ritual-investing-api/src/jobs/queue-runtime.ts";
import {
  handlerForEventType,
  type RetainedEventType,
  type RetainedJobHandler,
} from "../../../../ritual-investing-api/src/jobs/scheduled.ts";
import { sha256TextHex } from "../../../../ritual-investing-api/src/security/sha256.ts";
import type { WorkerTransaction } from "./purge.ts";
import { runWebullProjectionRefresh } from "../../../../ritual-investing-api/src/jobs/webull-projection-refresh.ts";
import { runWebullReconciliation } from "../../../../ritual-investing-api/src/jobs/webull-reconciliation.ts";
import { runWebullTokenRefresh } from "../../../../ritual-investing-api/src/jobs/webull-token-refresh.ts";

type ClaimedJob = Readonly<{
  job_run_id: string;
  lease_token: string;
  queue_message_id: number;
  read_count: number;
  event_id: string;
  event_type: string;
  handler_name: string;
  aggregate_id: string;
  user_id: string | null;
  deletion_epoch: number | null;
}>;

type ProcessOutcome = "empty" | "succeeded" | "retry" | "dead_lettered";

const externalSagaHandlers = new Set<RetainedJobHandler>([
  "privacy-purge",
  "webull-token-refresh",
  "webull-projection-refresh",
  "webull-reconciliation",
]);

async function establishWorkerTransaction(database: DatabaseClient): Promise<void> {
  const session = await database.query<{ session_user: string }>(
    "select session_user::text as session_user",
  );
  if (session.rows[0]?.session_user !== "argus_worker_edge") {
    throw new Error("invalid_worker_database_identity");
  }
  await database.query("set local role argus_worker");
  const role = await database.query<{ current_user: string }>(
    "select current_user::text as current_user",
  );
  if (role.rows[0]?.current_user !== "argus_worker") {
    throw new Error("invalid_worker_database_role");
  }
}

export function createWorkerTransaction(pool: DatabasePool): WorkerTransaction {
  return async <T>(callback: (database: DatabaseClient) => Promise<T>) => {
    const database = await pool.connect();
    let active = false;
    try {
      await database.query("begin isolation level repeatable read");
      active = true;
      await establishWorkerTransaction(database);
      const result = await callback(database);
      await database.query("commit");
      active = false;
      return result;
    } catch (error) {
      if (active) await database.query("rollback").catch(() => undefined);
      throw error;
    } finally {
      database.release();
    }
  };
}

function eventFromClaim(claim: ClaimedJob): OutboxEvent {
  const handler = handlerForEventType(claim.event_type);
  if (handler === null || handler !== claim.handler_name) {
    throw new Error("handler_not_allowed");
  }
  return {
    id: claim.event_id,
    eventType: claim.event_type as RetainedEventType,
    handlerName: claim.handler_name as RetainedJobHandler,
    aggregateId: claim.aggregate_id,
    userId: claim.user_id,
    deletionEpoch: claim.deletion_epoch,
  };
}

async function failClaim(
  database: DatabaseClient,
  claim: ClaimedJob,
  eventId: string,
  error: unknown,
): Promise<"retry" | "dead_lettered"> {
  const failureCode = redactedFailureCode(error);
  const diagnosticHash = await sha256TextHex(`${failureCode}:${eventId}`);
  const failed = await database.query<{ outcome: "retry" | "dead_lettered" }>(
    "select argus_private.fail_argus_job($1,$2,$3,$4) as outcome",
    [claim.job_run_id, claim.lease_token, failureCode, diagnosticHash],
  );
  const outcome = failed.rows[0]?.outcome ?? "dead_lettered";
  if (outcome === "dead_lettered") {
    await database.query(
      "select argus_private.terminalize_webull_recovery_dead_letter($1,$2)",
      [eventId, failureCode],
    );
  }
  return outcome;
}

export function createSupabaseWorkerRuntime(config: Readonly<{
  pool: DatabasePool;
  dependencies: JobHandlerDependencies;
}>): SupabaseQueueRuntime & Readonly<{
  consumeInvocation(nonce: string, issuedAtSeconds: number): Promise<boolean>;
}> {
  const transaction = createWorkerTransaction(config.pool);
  let activeWorkerLeaseToken: string | null = null;

  async function renewActiveWorkerLease(): Promise<void> {
    const token = activeWorkerLeaseToken;
    if (token === null) throw new Error("worker_lease_lost");
    const renewed = await transaction(async (database) => {
      const result = await database.query<{ acquired: boolean }>(
        "select argus_private.acquire_worker_lease($1,50) as acquired",
        [token],
      );
      return result.rows[0]?.acquired === true;
    });
    if (!renewed) throw new Error("worker_lease_lost");
  }

  async function processOne(): Promise<ProcessOutcome> {
    const claimed = await transaction(async (database) => {
      const result = await database.query<ClaimedJob>(
        "select * from argus_private.claim_next_argus_job(45)",
      );
      const claim = result.rows[0];
      if (claim === undefined) return { kind: "empty" as const };
      await database.query("savepoint argus_handler_effect");
      try {
        const event = eventFromClaim(claim);
        await database.query(
          "select * from argus_private.set_worker_event_context($1,$2,$3)",
          [event.id, claim.job_run_id, claim.lease_token],
        );
        if (externalSagaHandlers.has(event.handlerName)) {
          return { kind: "external" as const, claim, event };
        }
        const effect = await handlerFor(event, config.dependencies)(database, event);
        await database.query("select argus_private.assert_worker_event_current($1)", [
          event.id,
        ]);
        await database.query("select argus_private.complete_argus_job($1,$2,$3)", [
          claim.job_run_id,
          claim.lease_token,
          await effectHash(effect),
        ]);
        return { kind: "succeeded" as const };
      } catch (error) {
        await database.query("rollback to savepoint argus_handler_effect");
        return {
          kind: await failClaim(database, claim, claim.event_id, error),
        } as const;
      }
    });

    if (claimed.kind !== "external") return claimed.kind;

    // The claim is committed before Storage and Auth calls, so no database row
    // lock or transaction survives across external purge boundaries.
    try {
      const keepAlive = () => transaction(async (database) => {
          const workerToken = activeWorkerLeaseToken;
          if (workerToken === null) throw new Error("worker_lease_lost");
          await database.query(
            "select argus_private.renew_argus_job_lease($1,$2,$3)",
            [
              claimed.claim.job_run_id,
              claimed.claim.lease_token,
              workerToken,
            ],
          );
        });
      const effect = claimed.event.handlerName === "privacy-purge"
        ? await runPrivacyPurge(
          claimed.event,
          config.dependencies.purgeSaga,
          keepAlive,
        )
        : claimed.event.handlerName === "webull-token-refresh"
        ? await runWebullTokenRefresh(
          claimed.event,
          config.dependencies.webull.tokenRefresh,
          keepAlive,
        )
        : claimed.event.handlerName === "webull-projection-refresh"
        ? await runWebullProjectionRefresh(
          claimed.event,
          config.dependencies.webull.projectionRefresh,
          keepAlive,
        )
        : await runWebullReconciliation(
          claimed.event,
          config.dependencies.webull.reconciliation,
          keepAlive,
        );
      await transaction(async (database) => {
        await database.query(
          "select * from argus_private.set_worker_event_context($1,$2,$3)",
          [
            claimed.event.id,
            claimed.claim.job_run_id,
            claimed.claim.lease_token,
          ],
        );
        await database.query("select argus_private.complete_argus_job($1,$2,$3)", [
          claimed.claim.job_run_id,
          claimed.claim.lease_token,
          await effectHash(effect),
        ]);
      });
      return "succeeded";
    } catch (error) {
      return transaction((database) =>
        failClaim(database, claimed.claim, claimed.event.id, error)
      );
    }
  }

  return Object.freeze({
    consumeInvocation: (nonce: string, issuedAtSeconds: number) =>
      transaction(async (database) => {
        const result = await database.query<{ consumed: boolean }>(
          "select argus_private.consume_worker_invocation($1,$2) as consumed",
          [nonce, issuedAtSeconds],
        );
        return result.rows[0]?.consumed === true;
      }),
    acquireLease: () =>
      transaction(async (database) => {
        const token = crypto.randomUUID();
        const result = await database.query<{ acquired: boolean }>(
          "select argus_private.acquire_worker_lease($1,50) as acquired",
          [token],
        );
        if (result.rows[0]?.acquired !== true) return null;
        activeWorkerLeaseToken = token;
        return { token };
      }),
    releaseLease: (lease: WorkerLease) =>
      transaction(async (database) => {
        try {
          await database.query("select argus_private.release_worker_lease($1)", [lease.token]);
        } finally {
          if (activeWorkerLeaseToken === lease.token) activeWorkerLeaseToken = null;
        }
      }),
    relayOutbox: (batchSize: number) =>
      transaction(async (database) => {
        const result = await database.query<{ count: number }>(
          "select argus_private.relay_outbox($1) as count",
          [batchSize],
        );
        return Number(result.rows[0]?.count ?? 0);
      }),
    recoverExpired: (batchSize: number) =>
      transaction(async (database) => {
        const result = await database.query<{ count: number }>(
          "select argus_private.recover_expired_work($1) as count",
          [batchSize],
        );
        return Number(result.rows[0]?.count ?? 0);
      }),
    processBatch: async (batchSize: number): Promise<QueueBatchResult> => {
      let processed = 0;
      let retried = 0;
      let deadLettered = 0;
      for (let index = 0; index < batchSize; index += 1) {
        await renewActiveWorkerLease();
        const outcome = await processOne();
        if (outcome === "empty") break;
        if (outcome === "succeeded") processed += 1;
        if (outcome === "retry") retried += 1;
        if (outcome === "dead_lettered") deadLettered += 1;
      }
      return { processed, retried, deadLettered };
    },
  });
}

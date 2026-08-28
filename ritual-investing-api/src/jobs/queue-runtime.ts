const MAX_WORKER_BATCH_SIZE = 25;

const persistedFailureCodes = new Set([
  "deletion_epoch_changed",
  "dependency_unavailable",
  "event_not_found",
  "handler_not_allowed",
  "invalid_event_payload",
  "invalid_message_version",
  "lease_expired",
  "media_object_invalid",
  "member_deleted",
  "storage_unavailable",
  "worker_killed",
]);

export type WorkerLease = Readonly<{ token: string }>;

export type QueueBatchResult = Readonly<{
  processed: number;
  retried: number;
  deadLettered: number;
}>;

export interface SupabaseQueueRuntime {
  acquireLease(): Promise<WorkerLease | null>;
  releaseLease(lease: WorkerLease): Promise<void>;
  relayOutbox(batchSize: number): Promise<number>;
  recoverExpired(batchSize: number): Promise<number>;
  processBatch(batchSize: number): Promise<QueueBatchResult>;
}

export type SupabaseQueueRunResult = QueueBatchResult &
  Readonly<{
    overlap: boolean;
    relayed: number;
    recovered: number;
  }>;

export function redactedFailureCode(error: unknown): string {
  return error instanceof Error && persistedFailureCodes.has(error.message)
    ? error.message
    : "internal_failure";
}

export async function runSupabaseQueue(
  runtime: SupabaseQueueRuntime,
  options: Readonly<{ batchSize: number }>,
): Promise<SupabaseQueueRunResult> {
  if (
    !Number.isInteger(options.batchSize) ||
    options.batchSize < 1 ||
    options.batchSize > MAX_WORKER_BATCH_SIZE
  ) {
    throw new Error("invalid_worker_batch_size");
  }

  const lease = await runtime.acquireLease();
  if (lease === null) {
    return {
      overlap: true,
      relayed: 0,
      recovered: 0,
      processed: 0,
      retried: 0,
      deadLettered: 0,
    };
  }

  try {
    const recovered = await runtime.recoverExpired(options.batchSize);
    const relayed = await runtime.relayOutbox(options.batchSize);
    const batch = await runtime.processBatch(options.batchSize);
    return { overlap: false, relayed, recovered, ...batch };
  } finally {
    await runtime.releaseLease(lease);
  }
}

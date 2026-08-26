const MAX_ATTEMPTS = 3;
const RETRY_DELAYS_MS = [250, 1_000] as const;
const OVERDUE_AFTER_MS = 48 * 60 * 60 * 1_000;

export type PurgeCapability = {
  purgeExpired(): Promise<void>;
};

export type RetentionCheckpoint = {
  readLastSuccess(): Promise<number | null>;
  recordSuccess(scheduledAt: number): Promise<void>;
};

export type RetentionTelemetryPoint = {
  event: "retention_purge_completed" | "retention_purge_failed" | "retention_purge_overdue";
  attempts: number;
  overdue: boolean;
};

export type ScheduledRetentionDependencies = {
  scheduledAt: number;
  purge: PurgeCapability;
  checkpoint: RetentionCheckpoint;
  emit(point: RetentionTelemetryPoint): void;
  sleep(milliseconds: number): Promise<void>;
};

export type ScheduledRetentionResult = {
  ok: boolean;
  attempts: number;
  overdue: boolean;
};

function wasOverdueBeforeRun(scheduledAt: number, lastSuccess: number | null): boolean {
  return lastSuccess === null || scheduledAt - lastSuccess > OVERDUE_AFTER_MS;
}

export async function runScheduledRetention(
  dependencies: ScheduledRetentionDependencies,
): Promise<ScheduledRetentionResult> {
  let lastSuccess: number | null = null;
  try {
    lastSuccess = await dependencies.checkpoint.readLastSuccess();
  } catch {
    // A missing checkpoint makes a failed run overdue; no provider detail is retained.
  }

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
    try {
      await dependencies.purge.purgeExpired();
      await dependencies.checkpoint.recordSuccess(dependencies.scheduledAt);
      const overdue = lastSuccess !== null && wasOverdueBeforeRun(dependencies.scheduledAt, lastSuccess);
      dependencies.emit({ event: "retention_purge_completed", attempts: attempt, overdue });
      if (overdue) {
        dependencies.emit({ event: "retention_purge_overdue", attempts: attempt, overdue: true });
      }
      return { ok: true, attempts: attempt, overdue };
    } catch {
      if (attempt < MAX_ATTEMPTS) {
        await dependencies.sleep(RETRY_DELAYS_MS[attempt - 1] ?? RETRY_DELAYS_MS.at(-1) ?? 1_000);
      }
    }
  }

  const overdue = wasOverdueBeforeRun(dependencies.scheduledAt, lastSuccess);
  dependencies.emit({ event: "retention_purge_failed", attempts: MAX_ATTEMPTS, overdue });
  if (overdue) {
    dependencies.emit({ event: "retention_purge_overdue", attempts: MAX_ATTEMPTS, overdue: true });
  }
  return { ok: false, attempts: MAX_ATTEMPTS, overdue };
}

import { z } from "zod";

const retryFailureCode = z
  .string()
  .regex(/^[a-z][a-z0-9_]{0,63}$/)
  .catch("internal_failure");

const RETRY_DELAYS_SECONDS = [10, 30, 120, 300] as const;

export type RetryDecision =
  | { action: "retry"; delaySeconds: number; failureCode: string }
  | { action: "dead_letter"; failureCode: string };

export function decideRetry(
  attempt: number,
  failureCode: string,
): RetryDecision {
  const safeFailureCode = retryFailureCode.parse(failureCode);
  const normalizedAttempt = Math.max(1, Math.trunc(attempt));
  const delaySeconds = RETRY_DELAYS_SECONDS[normalizedAttempt - 1];

  return delaySeconds === undefined
    ? { action: "dead_letter", failureCode: safeFailureCode }
    : { action: "retry", delaySeconds, failureCode: safeFailureCode };
}

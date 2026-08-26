import type { AnalyticsBinding } from "./config.ts";

export type WaitlistTelemetryPoint =
  | { event: "waitlist_disabled"; outcome: "disabled" }
  | { event: "waitlist_validation_failed"; outcome: "origin" | "host" | "method" | "media" | "body" | "schema" | "consent" | "notice" }
  | { event: "waitlist_dependency_failed"; outcome: "configuration" | "abuse_control" }
  | { event: "waitlist_throttled"; outcome: "source" | "route" }
  | { event: "waitlist_budget_alert"; outcome: "route_ceiling" }
  | { event: "waitlist_turnstile_failed"; outcome: "rejected" | "unavailable" }
  | { event: "waitlist_neon_failed"; outcome: "unavailable" }
  | { event: "waitlist_accepted"; outcome: "accepted" };

/**
 * The type is the allowlist: callers cannot attach request, environment,
 * provider, exception, database, or visitor fields to a point.
 */
export function emitWaitlistTelemetry(
  binding: AnalyticsBinding | undefined,
  point: WaitlistTelemetryPoint,
): void {
  try {
    binding?.writeDataPoint({
      indexes: [point.event],
      blobs: [point.outcome],
      doubles: [1],
    });
  } catch {
    // Telemetry carries no request data and cannot change the public result.
  }
}

import { describe, expect, it, vi } from "vitest";

import { emitWaitlistTelemetry, type WaitlistTelemetryPoint } from "../src/observability.ts";

describe("waitlist observability", () => {
  it("serializes only allowlisted aggregate dimensions", () => {
    const written: unknown[] = [];
    const binding = { writeDataPoint: vi.fn((point: unknown) => written.push(point)) };
    const points: WaitlistTelemetryPoint[] = [
      { event: "waitlist_validation_failed", outcome: "schema" },
      { event: "waitlist_dependency_failed", outcome: "configuration" },
      { event: "waitlist_turnstile_failed", outcome: "rejected" },
      { event: "waitlist_throttled", outcome: "route" },
      { event: "waitlist_budget_alert", outcome: "route_ceiling" },
      { event: "waitlist_neon_failed", outcome: "unavailable" },
      { event: "waitlist_accepted", outcome: "accepted" },
    ];

    for (const point of points) emitWaitlistTelemetry(binding, point);

    expect(written).toEqual(points.map((point) => ({
      indexes: [point.event],
      blobs: [point.outcome],
      doubles: [1],
    })));
    expect(JSON.stringify(written)).not.toMatch(/@|token|request|response|body|sql|postgres|user.?agent|connecting.?ip|header/i);
  });

  it("never lets an observability binding failure alter the request path", () => {
    expect(() => emitWaitlistTelemetry({
      writeDataPoint() { throw new Error("email token SQL connection URL"); },
    }, { event: "waitlist_accepted", outcome: "accepted" })).not.toThrow();
  });
});

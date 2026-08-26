import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import {
  createTelemetrySink,
  type TelemetrySink,
  type TelemetryEvent,
} from "../../src/observability/telemetry";
import { testBindings } from "../support/security-fixtures";

describe("redacted structured telemetry", () => {
  it("never emits request bodies, credentials, tokens, or raw resource identifiers", async () => {
    const events: TelemetryEvent[] = [];
    const sink: TelemetrySink = (event) => {
      events.push(event);
    };
    const app = createApp({ telemetrySink: sink });
    const secrets = [
      "Bearer raw-auth-token",
      "1990-01-01T04:05:06Z",
      "birthplace-secret",
      "push-token-secret",
      "privacy-download-secret",
      "member-profile-secret",
    ];
    const failures = [
      ["/v1/me", "GET", undefined],
      [
        "/v1/me/astrology-profile",
        "PUT",
        { birth_date: secrets[1], birthplace: secrets[2] },
      ],
      ["/v1/orders", "POST", { note: secrets[5] }],
      ["/v1/media/upload-requests", "POST", { token: secrets[3] }],
      ["/v1/me/privacy/exports", "POST", { nonce: secrets[4] }],
      ["/v1/admin/me", "GET", undefined],
    ] as const;

    for (const [path, method, body] of failures) {
      await app.request(
        `https://api.ritual-investing.test${path}`,
        {
          method,
          headers: {
            authorization: secrets[0]!,
            "content-type": "application/json",
          },
          ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        },
        testBindings(),
      );
    }

    expect(events).toHaveLength(failures.length);
    const serialized = JSON.stringify(events);
    for (const secret of secrets) expect(serialized).not.toContain(secret);
    expect(serialized).not.toMatch(
      /"(?:authorization|cookie|body|token|birth[^"]*)":/i,
    );
    expect(events.every((event) => event.event_version === 1)).toBe(true);
  });

  it("console serialization remains one redacted JSON object", () => {
    const log = vi.fn();
    const sink = createTelemetrySink(log);
    sink({
      event_version: 1,
      event_name: "dependency.health",
      severity: "error",
      environment: "test",
      outcome: "unavailable",
      dependency: "neon",
    });
    expect(log).toHaveBeenCalledWith(expect.stringMatching(/^\{.*\}$/));
    expect(JSON.parse(log.mock.calls[0]![0] as string)).toMatchObject({
      event_name: "dependency.health",
      dependency: "neon",
    });
  });
});

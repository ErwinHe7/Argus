import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

describe("U7 async bindings", () => {
  it("binds the Queue, DLQ, isolated R2 stores, and managed media services", () => {
    const bindings = env as unknown as Record<string, unknown>;
    for (const queue of ["ASYNC_QUEUE", "JOBS_DLQ"])
      expect(bindings[queue], queue).toHaveProperty("send");
    for (const bucket of [
      "MEDIA_QUARANTINE",
      "MEDIA_PUBLIC",
      "PRIVACY_EXPORTS",
      "DELETION_DENY_JOURNAL",
    ])
      expect(bindings[bucket], bucket).toMatchObject({
        get: expect.any(Function),
        put: expect.any(Function),
        delete: expect.any(Function),
      });
    for (const service of ["MEDIA_SCANNER", "MEDIA_PROCESSOR", "PUSH_PROVIDER"])
      expect(bindings[service], service).toHaveProperty("fetch");
  });

  it("declares every operational kill switch fail-closed value", () => {
    for (const name of [
      "KILL_SWITCH_SCHEDULED",
      "KILL_SWITCH_QUEUE",
      "KILL_SWITCH_NOTIFICATIONS",
      "KILL_SWITCH_EXPORTS",
      "KILL_SWITCH_PURGE",
      "KILL_SWITCH_MEDIA",
    ])
      expect((env as unknown as Record<string, unknown>)[name]).toBe("off");
  });
});

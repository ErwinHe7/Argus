import { describe, expect, it } from "vitest";

import { validateBindings } from "../../src/config/env";
import { testBindings } from "../support/security-fixtures";

describe("security binding validation", () => {
  it("requires every configured rate-limit binding", () => {
    const bindings = { ...testBindings() } as Record<string, unknown>;
    delete bindings.RL_ADMIN_HIGH;

    expect(() => validateBindings(bindings)).toThrow();
  });

  it("accepts only PostgreSQL database URLs", () => {
    expect(() => validateBindings({
      ...testBindings(),
      IDENTITY_DATABASE_URL: "https://database.example",
    })).toThrow();
    expect(validateBindings({
      ...testBindings(),
      IDENTITY_DATABASE_URL: "postgresql://user:password@database.example/ritual",
    }).IDENTITY_DATABASE_URL).toContain("database.example");
  });

  it("fails closed when a staging deployment omits an async dependency", () => {
    expect(() =>
      validateBindings({
        ...testBindings(),
        ENVIRONMENT: "staging",
      }),
    ).toThrow(/IDENTITY_DATABASE_URL.*required|required in staging/);
  });

  it("allows managed media and push providers to remain absent only behind kill switches", () => {
    const databaseUrl = "postgresql://role:password@database.example/ritual";
    const queue = { send: async () => undefined, sendBatch: async () => undefined };
    const bucket = { get: async () => null, put: async () => null };
    const bindings = {
      ...testBindings(),
      ENVIRONMENT: "production",
      IDENTITY_DATABASE_URL: databaseUrl,
      BOOTSTRAP_DATABASE_URL: databaseUrl,
      STAFF_DATABASE_URL: databaseUrl,
      PUBLIC_DATABASE_URL: databaseUrl,
      RUNTIME_DATABASE_URL: databaseUrl,
      SCHEDULER_DATABASE_URL: databaseUrl,
      PRIVACY_DATABASE_URL: databaseUrl,
      MEDIA_DATABASE_URL: databaseUrl,
      AUDIT_DATABASE_URL: databaseUrl,
      PUSH_TOKEN_ENCRYPTION_KEY:
        "ritual-test-push-token-encryption-key-material-43",
      ASYNC_QUEUE: queue,
      JOBS_DLQ: queue,
      MEDIA_QUARANTINE: bucket,
      MEDIA_PUBLIC: bucket,
      PRIVACY_EXPORTS: bucket,
      DELETION_DENY_JOURNAL: bucket,
      KILL_SWITCH_MEDIA: "on",
      KILL_SWITCH_NOTIFICATIONS: "on",
    };

    expect(() => validateBindings(bindings)).not.toThrow();
    expect(() =>
      validateBindings({ ...bindings, KILL_SWITCH_MEDIA: "off" }),
    ).toThrow(/MEDIA_SCANNER.*required/);
    expect(() =>
      validateBindings({ ...bindings, KILL_SWITCH_NOTIFICATIONS: "off" }),
    ).toThrow(/PUSH_PROVIDER.*required/);
  });
});

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
});

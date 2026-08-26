import { describe, expect, it } from "vitest";

import { deterministicAstrologyProfileCode } from "../../src/domains/accounts/repository.ts";

describe("deterministic astrology profile code", () => {
  it.each([
    ["1969-12-31", "rising_explorer"],
    ["1970-01-01", "lunar_patient"],
    ["1970-01-02", "solar_builder"],
  ] as const)("normalizes the epoch-day modulo for %s", (birthDate, expected) => {
    expect(deterministicAstrologyProfileCode(birthDate)).toBe(expected);
  });
});

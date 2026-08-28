import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.15";

import { parseWebullCallback } from "./handler.ts";

const state = "A".repeat(43);

Deno.test("callback accepts only exact canonical success and denied shapes", () => {
  assertEquals(
    parseWebullCallback(
      new URL(
        `https://project.test/callback?state=${state}&code=synthetic-code-1`,
      ),
    ),
    { state, code: "synthetic-code-1" },
  );
  assertEquals(
    parseWebullCallback(
      new URL(
        `https://project.test/callback?state=${state}&error=access_denied&error_description=synthetic`,
      ),
    ),
    { state, providerError: true },
  );
});

Deno.test("callback rejects duplicates, extra outcome data, and ambiguous encoding", () => {
  for (
    const query of [
      `state=${state}&state=${state}&code=synthetic-code-1`,
      `state=${state}&code=synthetic-code-1&error_description=unexpected`,
      `state=${state}&code=synthetic%2dcode`,
      `state=${state}&code=synthetic+code`,
      `state=${state}&code=synthetic-code-1&next=https%3A%2F%2Fattacker.test`,
    ]
  ) {
    assertThrows(() =>
      parseWebullCallback(new URL(`https://project.test/callback?${query}`))
    );
  }
});

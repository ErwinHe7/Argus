import {
  assertEquals,
  assertThrows,
} from "jsr:@std/assert@1.0.15";

import { requiredEnvironment, supabaseSecretKey } from "./environment.ts";

function reader(values: Readonly<Record<string, string>>) {
  return (name: string) => values[name];
}

Deno.test("hosted named Supabase secret key is selected without logging it", () => {
  assertEquals(
    supabaseSecretKey(reader({
      SUPABASE_SECRET_KEYS: JSON.stringify({ default: "sb_secret_fixture" }),
      SUPABASE_SECRET_KEY: "local-fallback",
    })),
    "sb_secret_fixture",
  );
});

Deno.test("local single-key environment remains supported", () => {
  assertEquals(
    supabaseSecretKey(reader({ SUPABASE_SECRET_KEY: "local-fixture" })),
    "local-fixture",
  );
});

Deno.test("missing or malformed environment fails closed", () => {
  assertThrows(
    () => requiredEnvironment("EDGE_RUNTIME_DATABASE_URL", reader({})),
    Error,
    "missing_edge_runtime_database_url",
  );
  assertThrows(
    () => supabaseSecretKey(reader({ SUPABASE_SECRET_KEYS: "{}" })),
    Error,
    "missing_supabase_secret_keys_default",
  );
});

import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.15";

import {
  requiredConsumerOrigins,
  requiredEnvironment,
  requiredExactOrigin,
  requiredWebAdmission,
  supabaseSecretKey,
} from "./environment.ts";

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

Deno.test("public-beta consumer origins are an exact bounded set", () => {
  const stagingPreviewOrigin =
    "https://staging-ritual-investing-member.xiaolonggao521.workers.dev";
  assertEquals(
    requiredConsumerOrigins(reader({
      ARGUS_CONSUMER_ORIGINS:
        `https://just-build-this.app,${stagingPreviewOrigin}`,
    })),
    ["https://just-build-this.app", stagingPreviewOrigin],
  );

  for (
    const value of [
      "",
      "*",
      "null",
      "https://just-build-this.app",
      "https://just-build-this.app,https://branch.pages.dev",
      "https://just-build-this.app,https://staging.just-build-this.app",
      `https://just-build-this.app,${stagingPreviewOrigin}/route`,
    ]
  ) {
    assertThrows(
      () => requiredConsumerOrigins(reader({ ARGUS_CONSUMER_ORIGINS: value })),
      Error,
      "invalid_argus_consumer_origins",
    );
  }
});

Deno.test("web admission accepts only explicit open or contained states", () => {
  assertEquals(
    requiredWebAdmission(reader({ ARGUS_WEB_ADMISSION: "open" })),
    "open",
  );
  assertEquals(
    requiredWebAdmission(reader({ ARGUS_WEB_ADMISSION: "contained" })),
    "contained",
  );
  for (const value of ["", "enabled", "maintenance", "OPEN"]) {
    assertThrows(
      () => requiredWebAdmission(reader({ ARGUS_WEB_ADMISSION: value })),
      Error,
      "invalid_argus_web_admission",
    );
  }
});

Deno.test("admin origin is independent and must be one exact origin", () => {
  assertEquals(
    requiredExactOrigin(
      "ARGUS_ADMIN_ORIGIN",
      reader({ ARGUS_ADMIN_ORIGIN: "https://admin.just-build-this.app" }),
    ),
    "https://admin.just-build-this.app",
  );
  for (const value of ["", "*", "null", "https://admin.example.test/path"]) {
    assertThrows(
      () =>
        requiredExactOrigin(
          "ARGUS_ADMIN_ORIGIN",
          reader({ ARGUS_ADMIN_ORIGIN: value }),
        ),
      Error,
    );
  }
});

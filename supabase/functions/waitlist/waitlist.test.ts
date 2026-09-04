import {
  assert,
  assertEquals,
  assertMatch,
  assertNotEquals,
  assertThrows,
} from "jsr:@std/assert@1.0.15";

import {
  createWaitlistHandler,
  type WaitlistEnvironment,
  type WaitlistRuntime,
} from "./index.ts";
import { createSupabaseWaitlistDatabasePool } from "../_shared/database.ts";

const ORIGIN = "https://just-build-this.app";
const DATABASE_URL =
  "postgresql://argus_waitlist_edge:synthetic-password@db.example.invalid/postgres";

function environment(
  overrides: Partial<WaitlistEnvironment> = {},
): WaitlistEnvironment {
  return {
    WAITLIST_SUBMISSIONS: "on",
    WAITLIST_ALLOWED_ORIGIN: ORIGIN,
    WAITLIST_SOURCE_HMAC_KEY: "s".repeat(32),
    TURNSTILE_SECRET: "synthetic-turnstile-secret",
    TURNSTILE_EXPECTED_HOSTNAME: "just-build-this.app",
    SUPABASE_DB_URL: DATABASE_URL,
    ...overrides,
  };
}

function body(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    email: " Person.Name+one@Example.COM ",
    consent: true,
    noticeVersion: "waitlist-v1-2026-08-25",
    turnstileToken: "synthetic-turnstile-token",
    ...overrides,
  };
}

function request(
  overrides: Readonly<{
    origin?: string;
    method?: string;
    body?: string;
    contentType?: string;
    source?: string;
  }> = {},
): Request {
  const method = overrides.method ?? "POST";
  return new Request(
    "https://synthetic-project.supabase.co/functions/v1/waitlist",
    {
      method,
      headers: {
        origin: overrides.origin ?? ORIGIN,
        ...(method === "POST"
          ? {
              "content-type": overrides.contentType ?? "application/json",
              "cf-connecting-ip": overrides.source ?? "203.0.113.18",
            }
          : {}),
      },
      ...(method === "POST"
        ? { body: overrides.body ?? JSON.stringify(body()) }
        : {}),
    },
  );
}

function harness(options: Readonly<{
  rate?: (call: number) => Promise<{
    allowed: boolean;
    retryAfterSeconds?: number;
  }>;
  submit?: (email: string, notice: string) => Promise<void>;
  turnstile?: () => Promise<
    | { ok: true }
    | { ok: false; kind: "rejected" | "unavailable" }
  >;
}> = {}) {
  const keys: string[] = [];
  const submissions: Array<{ email: string; notice: string }> = [];
  let rateCalls = 0;
  let turnstileCalls = 0;
  const runtime: WaitlistRuntime = {
    async allow(key) {
      keys.push(key);
      rateCalls += 1;
      return options.rate?.(rateCalls) ?? { allowed: true };
    },
    async submit(email, notice) {
      submissions.push({ email, notice });
      await options.submit?.(email, notice);
    },
  };
  return {
    keys,
    submissions,
    get turnstileCalls() {
      return turnstileCalls;
    },
    dependencies: {
      runtimeFactory(databaseUrl: string) {
        assertEquals(databaseUrl, DATABASE_URL);
        return runtime;
      },
      async verifyTurnstile() {
        turnstileCalls += 1;
        return await (options.turnstile?.() ?? Promise.resolve({ ok: true }));
      },
    },
  };
}

Deno.test("trusted submissions and normalized duplicates receive the same generic success", async () => {
  const fixture = harness();
  const handler = createWaitlistHandler(environment(), fixture.dependencies);
  const first = await handler(request());
  const duplicate = await handler(request());

  assertEquals(first.status, 202);
  assertEquals(await first.json(), { code: "accepted", retryable: false });
  assertEquals(duplicate.status, 202);
  assertEquals(await duplicate.json(), { code: "accepted", retryable: false });
  assertEquals(fixture.submissions, [
    {
      email: "person.name+one@example.com",
      notice: "waitlist-v1-2026-08-25",
    },
    {
      email: "person.name+one@example.com",
      notice: "waitlist-v1-2026-08-25",
    },
  ]);
  assertEquals(first.headers.get("access-control-allow-origin"), ORIGIN);
  assertEquals(first.headers.get("cache-control"), "no-store, max-age=0");
  assertEquals(first.headers.get("x-content-type-options"), "nosniff");
});

Deno.test("database pool accepts only the dedicated waitlist login", async () => {
  for (const user of [
    "argus_waitlist_edge",
    "argus_waitlist_edge.abcdefghijklmnopqrst",
  ]) {
    const pool = createSupabaseWaitlistDatabasePool(
      `postgresql://${user}:synthetic-password@db.example.invalid/postgres`,
    );
    await pool.end();
  }
  for (const user of [
    "argus_edge",
    "argus_runtime",
    "postgres",
    "argus_waitlist_edge_evil",
    "argus_waitlist_edge.abcdefghijklmnopqrs",
    "argus_waitlist_edge.abcdefghijklmnopqrs1",
    "argus_waitlist_edge.abcdefghijklmnopqrst.evil",
  ]) {
    assertThrows(
      () => createSupabaseWaitlistDatabasePool(
        `postgresql://${user}:synthetic-password@db.example.invalid/postgres`,
      ),
      Error,
      "invalid_supabase_database_role",
    );
  }
});

Deno.test("rate keys are stable pseudonyms and never retain the raw source", async () => {
  const fixture = harness();
  const handler = createWaitlistHandler(environment(), fixture.dependencies);
  await handler(request({ source: "2001:db8::25" }));

  assertEquals(fixture.keys.length, 2);
  for (const key of fixture.keys) {
    assertMatch(key, /^[a-f0-9]{64}$/);
    assert(!key.includes("2001:db8::25"));
  }
  assertNotEquals(fixture.keys[0], fixture.keys[1]);
});

Deno.test("CORS accepts only the configured exact landing origin", async () => {
  const fixture = harness();
  const handler = createWaitlistHandler(environment(), fixture.dependencies);
  const preflight = await handler(request({ method: "OPTIONS" }));
  assertEquals(preflight.status, 204);
  assertEquals(preflight.headers.get("access-control-allow-origin"), ORIGIN);
  assertEquals(
    preflight.headers.get("access-control-allow-methods"),
    "POST, OPTIONS",
  );

  const foreign = await handler(request({ origin: "https://evil.example" }));
  assertEquals(foreign.status, 403);
  assertEquals(foreign.headers.get("access-control-allow-origin"), null);
  assertEquals(fixture.submissions, []);
});

Deno.test("migrated landing origins retain exact CORS and Turnstile hostname checks", async () => {
  for (
    const hostname of [
      "leoinvesting.com",
      "staging.leoinvesting.com",
      "beta.leoinvesting.com",
    ]
  ) {
    const origin = `https://${hostname}`;
    const fixture = harness();
    const configuration = environment({
      WAITLIST_ALLOWED_ORIGIN: origin,
      TURNSTILE_EXPECTED_HOSTNAME: hostname,
    });
    let verifiedHostname: string | undefined;
    const handler = createWaitlistHandler(configuration, {
      ...fixture.dependencies,
      verifyTurnstile(input) {
        verifiedHostname = input.expectedHostname;
        return Promise.resolve({ ok: true });
      },
    });
    const accepted = await handler(request({ origin }));
    assertEquals(accepted.status, 202);
    assertEquals(accepted.headers.get("access-control-allow-origin"), origin);
    assertEquals(verifiedHostname, hostname);

    const foreign = await handler(
      request({ origin: `${origin}.evil.example` }),
    );
    assertEquals(foreign.status, 403);
    assertEquals(foreign.headers.get("access-control-allow-origin"), null);

    const mismatched = createWaitlistHandler({
      ...configuration,
      TURNSTILE_EXPECTED_HOSTNAME: "just-build-this.app",
    }, fixture.dependencies);
    assertEquals((await mismatched(request({ origin }))).status, 503);
  }
});

Deno.test("disabled previews fail before constructing database or Turnstile dependencies", async () => {
  let constructed = false;
  const handler = createWaitlistHandler(
    environment({ WAITLIST_SUBMISSIONS: "off" }),
    {
      runtimeFactory() {
        constructed = true;
        throw new Error("must_not_run");
      },
      async verifyTurnstile() {
        throw new Error("must_not_run");
      },
    },
  );
  const response = await handler(request());
  assertEquals(response.status, 503);
  assertEquals(await response.json(), {
    code: "waitlist_unavailable",
    retryable: true,
  });
  assertEquals(constructed, false);
});

Deno.test("invalid request, consent, notice, media, and body size fail before dependencies", async () => {
  const fixture = harness();
  const handler = createWaitlistHandler(environment(), fixture.dependencies);
  const cases = [
    [request({ body: JSON.stringify(body({ extra: true })) }), 400, "invalid_request"],
    [request({ body: JSON.stringify(body({ consent: false })) }), 400, "consent_required"],
    [request({ body: JSON.stringify(body({ noticeVersion: "waitlist-v0-2020-01-01" })) }), 409, "stale_notice"],
    [request({ contentType: "text/plain" }), 415, "unsupported_media_type"],
    [request({ body: "x".repeat(4_097) }), 413, "payload_too_large"],
  ] as const;
  for (const [incoming, status, code] of cases) {
    const response = await handler(incoming);
    assertEquals(response.status, status);
    assertEquals((await response.json()).code, code);
  }
  assertEquals(fixture.keys, []);
  assertEquals(fixture.submissions, []);
});

Deno.test("rate denial is generic, bounded, and precedes Turnstile and persistence", async () => {
  const fixture = harness({
    rate: async () => ({ allowed: false, retryAfterSeconds: 17 }),
  });
  const response = await createWaitlistHandler(
    environment(),
    fixture.dependencies,
  )(request());
  assertEquals(response.status, 429);
  assertEquals(response.headers.get("retry-after"), "17");
  assertEquals(await response.json(), { code: "rate_limited", retryable: true });
  assertEquals(fixture.turnstileCalls, 0);
  assertEquals(fixture.submissions, []);
});

Deno.test("Turnstile rejection and outage remain distinct but non-enumerating", async () => {
  for (const [result, expectedStatus] of [
    [{ ok: false, kind: "rejected" }, 422],
    [{ ok: false, kind: "unavailable" }, 503],
  ] as const) {
    const fixture = harness({ turnstile: async () => result });
    const response = await createWaitlistHandler(
      environment(),
      fixture.dependencies,
    )(request());
    assertEquals(response.status, expectedStatus);
    assertEquals(fixture.submissions, []);
    assert(!JSON.stringify(await response.json()).includes("example.com"));
  }
});

Deno.test("database failure returns only the fixed dependency response", async () => {
  const fixture = harness({
    submit: async () => {
      throw new Error("synthetic database detail person@example.com");
    },
  });
  const response = await createWaitlistHandler(
    environment(),
    fixture.dependencies,
  )(request());
  assertEquals(response.status, 503);
  const serialized = JSON.stringify(await response.json());
  assertEquals(serialized, '{"code":"dependency_unavailable","retryable":true}');
  assert(!serialized.includes("database"));
  assert(!serialized.includes("example.com"));
});

Deno.test("missing abuse source or malformed activation configuration fails closed", async () => {
  const fixture = harness();
  const missingSource = await createWaitlistHandler(
    environment(),
    fixture.dependencies,
  )(request({ source: "not-an-ip" }));
  assertEquals(missingSource.status, 503);

  const wrongOriginContract = await createWaitlistHandler(
    environment({ WAITLIST_ALLOWED_ORIGIN: "https://preview.pages.dev" }),
    fixture.dependencies,
  )(request());
  assertEquals(wrongOriginContract.status, 503);
  assertEquals(wrongOriginContract.headers.get("access-control-allow-origin"), null);
});

import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert@1.0.15";

import type {
  DatabaseClient,
  DatabasePool,
} from "../../../ritual-investing-api/src/db/database-port.ts";
import { createSupabaseWorkerDatabasePool } from "../_shared/database.ts";
import { createSupabaseAuthAdmin } from "../_shared/jobs/auth-admin.ts";
import {
  authenticateWorkerRequest,
  signWorkerInvocation,
} from "../_shared/jobs/auth.ts";
import { createMemberPurgeSaga, type PurgeFaultPoint, type PurgePhase } from "../_shared/jobs/purge.ts";
import { createPrivateSupabaseStorage } from "../_shared/jobs/storage.ts";
import { createWorkerTransaction } from "../_shared/jobs/runtime.ts";
import { createWorkerHandler, type WorkerInvocationRuntime } from "./index.ts";

const current = "current-worker-secret-at-least-32-characters";
const next = "next-worker-secret-at-least-32-characters";

Deno.test("worker database pool accepts only its local or Supavisor login", async () => {
  for (const user of [
    "argus_worker_edge",
    "argus_worker_edge.abcdefghijklmnopqrst",
  ]) {
    const pool = createSupabaseWorkerDatabasePool(
      `postgresql://${user}:synthetic-password@db.example.invalid/postgres`,
    );
    await pool.end();
  }
  for (const user of [
    "argus_edge",
    "argus_worker",
    "postgres",
    "argus_worker_edge_evil",
    "argus_worker_edge.abcdefghijklmnopqrs",
    "argus_worker_edge.abcdefghijklmnopqrs1",
    "argus_worker_edge.abcdefghijklmnopqrst.evil",
  ]) {
    assertThrows(
      () => createSupabaseWorkerDatabasePool(
        `postgresql://${user}:synthetic-password@db.example.invalid/postgres`,
      ),
      Error,
      "invalid_supabase_database_role",
    );
  }
});

Deno.test("worker secret accepts current and a bounded next overlap", async () => {
  const now = new Date("2026-08-28T12:00:00.000Z");
  const timestamp = Math.floor(now.getTime() / 1_000);
  const nonce = "0123456789abcdef0123456789abcdef";
  const request = async (secret: string) => new Request("https://worker.invalid/", {
    method: "POST",
    headers: {
      "x-argus-worker-timestamp": String(timestamp),
      "x-argus-worker-nonce": nonce,
      "x-argus-worker-proof": await signWorkerInvocation(secret, timestamp, nonce),
    },
  });
  const config = {
    current,
    next,
    nextValidUntil: new Date(now.getTime() + 5 * 60_000),
  };
  assertEquals(await authenticateWorkerRequest(await request(current), config, now), true);
  assertEquals(await authenticateWorkerRequest(await request(next), config, now), true);
  assertEquals(
    await authenticateWorkerRequest(await request(next), config, new Date(now.getTime() + 6 * 60_000)),
    false,
  );
  assertEquals(await authenticateWorkerRequest(await request("forged-worker-secret-at-least-32-chars"), config, now), false);
});

Deno.test("worker secret rejects an overlap longer than ten minutes", async () => {
  const now = new Date("2026-08-28T12:00:00.000Z");
  assertEquals(
    await authenticateWorkerRequest(
      new Request("https://worker.invalid/", { method: "POST", headers: {
        "x-argus-worker-timestamp": String(Math.floor(now.getTime() / 1_000)),
        "x-argus-worker-nonce": "0123456789abcdef0123456789abcdef",
        "x-argus-worker-proof": await signWorkerInvocation(
          next,
          Math.floor(now.getTime() / 1_000),
          "0123456789abcdef0123456789abcdef",
        ),
      } }),
      { current, next, nextValidUntil: new Date(now.getTime() + 11 * 60_000) },
      now,
    ),
    false,
  );
});

function fakeRuntime(): WorkerInvocationRuntime {
  const nonces = new Set<string>();
  return {
    async consumeInvocation(nonce) {
      if (nonces.has(nonce)) return false;
      nonces.add(nonce);
      return true;
    },
    async acquireLease() {
      return { token: crypto.randomUUID() };
    },
    async releaseLease() {},
    async relayOutbox(batchSize) {
      return batchSize;
    },
    async recoverExpired() {
      return 0;
    },
    async processBatch() {
      return { processed: 1, retried: 0, deadLettered: 0 };
    },
  };
}

async function signedRequest(
  body: string,
  now: Date,
  nonce = crypto.randomUUID().replaceAll("-", ""),
): Promise<Request> {
  const timestamp = Math.floor(now.getTime() / 1_000);
  return new Request("https://worker.invalid/", {
    method: "POST",
    headers: {
      "content-type": "application/json; charset=utf-8",
      "x-argus-worker-timestamp": String(timestamp),
      "x-argus-worker-nonce": nonce,
      "x-argus-worker-proof": await signWorkerInvocation(current, timestamp, nonce),
    },
    body,
  });
}

Deno.test("worker endpoint accepts one strict bounded invocation and rejects replay", async () => {
  const now = new Date("2026-08-28T12:00:00.000Z");
  const runtime = fakeRuntime();
  const handler = createWorkerHandler({ secrets: { current }, runtime, now: () => now });
  const nonce = "0123456789abcdef0123456789abcdef";
  const first = await handler(await signedRequest('{"batch_size":3}', now, nonce));
  assertEquals(first.status, 200);
  assertEquals(await first.json(), {
    overlap: false,
    relayed: 3,
    recovered: 0,
    processed: 1,
    retried: 0,
    deadLettered: 0,
  });
  const replay = await handler(await signedRequest('{"batch_size":3}', now, nonce));
  assertEquals(replay.status, 401);
});

Deno.test("worker endpoint rejects method, media type, unknown fields, and oversized bodies", async () => {
  const now = new Date("2026-08-28T12:00:00.000Z");
  const handler = createWorkerHandler({
    secrets: { current },
    runtime: fakeRuntime(),
    now: () => now,
  });
  assertEquals((await handler(new Request("https://worker.invalid/"))).status, 405);
  assertEquals((await handler(new Request("https://worker.invalid/", {
    method: "POST",
    headers: { "content-type": "text/plain" },
    body: "{}",
  }))).status, 415);
  assertEquals((await handler(await signedRequest('{"batch_size":1,"extra":true}', now))).status, 400);
  assertEquals((await handler(await signedRequest(JSON.stringify({ padding: "x".repeat(1_100) }), now))).status, 413);
});

Deno.test("server Storage and Auth adapters use sb_secret only as apikey", async () => {
  const secret = "sb_secret_canary-never-a-bearer-token";
  const calls: Array<{ url: string; headers: Headers }> = [];
  const fetcher: typeof fetch = (input, init) => {
    const requestInit = init as globalThis.RequestInit | undefined;
    calls.push({
      url: String(input),
      headers: new Headers(requestInit?.headers),
    });
    const authCall = String(input).includes("/auth/");
    return Promise.resolve(new Response(authCall ? null : new Uint8Array([1]), {
      status: authCall ? 204 : 200,
      headers: { "content-type": "image/png" },
    }));
  };
  const storage = createPrivateSupabaseStorage({
    supabaseUrl: "https://project.supabase.co",
    secretKey: secret,
    fetch: fetcher,
  });
  await storage.get("member-media", `${userId}/avatar.png`);
  await createSupabaseAuthAdmin({
    supabaseUrl: "https://project.supabase.co",
    secretKey: secret,
    fetch: fetcher,
  }).deleteUser(userId);
  assertEquals(calls.length, 2);
  for (const call of calls) {
    assertEquals(call.headers.get("apikey"), secret);
    assertEquals(call.headers.get("authorization"), null);
  }
});

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const tombstoneId = "018f3c2a-4b67-7a89-8abc-123456789002";

function purgeFixture(initial: PurgePhase = "requested", objectCount = 3) {
  let phase = initial;
  let authDeletes = 0;
  const batches: number[] = [];
  const objects = Array.from({ length: objectCount }, (_, index) => ({
    bucket_id: "member-media",
    object_path: `${userId}/object-${index}.webp`,
  }));
  const database: DatabaseClient = {
    async query<Row>(sql: string) {
      if (sql.includes("prepare_member_purge")) {
        if (phase === "requested") phase = "neutralized";
        return { rows: [{ user_id: userId, deletion_epoch: 1, purge_phase: phase } as Row] };
      }
      if (sql.includes("list_member_purge_objects")) {
        return { rows: (phase === "neutralized" ? objects : []) as Row[] };
      }
      if (sql.includes("mark_member_storage_purged")) phase = "storage_purged";
      if (sql.includes("purge_member_argus_data")) phase = "data_purged";
      if (sql.includes("complete_member_purge")) phase = "complete";
      return { rows: [] };
    },
    release() {},
  };
  const transaction = async <T>(callback: (client: DatabaseClient) => Promise<T>) =>
    callback(database);
  const storage = {
    async get() { return null; },
    async put() {},
    async remove(_bucket: string, paths: readonly string[]) { batches.push(paths.length); },
    async createSignedUrl() { return "https://signed.invalid"; },
  };
  const authAdmin = {
    async deleteUser() { authDeletes += 1; },
  };
  return {
    config: { storage, authAdmin, transaction },
    state: () => ({ phase, authDeletes, batches }),
  };
}

for (const faultPoint of [
  "after_prepare",
  "after_storage",
  "after_data",
  "after_auth",
  "after_complete",
] as const satisfies readonly PurgeFaultPoint[]) {
  Deno.test(`privacy purge resumes after ${faultPoint}`, async () => {
    const fixture = purgeFixture();
    let injected = false;
    const first = createMemberPurgeSaga({
      ...fixture.config,
      fault(point) {
        if (!injected && point === faultPoint) {
          injected = true;
          throw new Error("fault_injected");
        }
      },
    });
    await assertRejects(() => first.run(tombstoneId), Error, "fault_injected");
    await createMemberPurgeSaga(fixture.config).run(tombstoneId);
    assertEquals(fixture.state().phase, "complete");
    assertEquals(fixture.state().authDeletes >= 1, true);
  });
}

Deno.test("large purge batches renew beyond the original visibility deadline", async () => {
  const fixture = purgeFixture("requested", 250);
  let elapsedSeconds = 0;
  let lastRenewedAt = 0;
  fixture.config.storage.remove = async (_bucket, paths) => {
    assertEquals(paths.length <= 100, true);
    elapsedSeconds += 20;
  };
  const saga = createMemberPurgeSaga(fixture.config);
  await saga.run(tombstoneId, async () => {
    if (elapsedSeconds - lastRenewedAt > 45) throw new Error("lease_expired");
    lastRenewedAt = elapsedSeconds;
  });
  assertEquals(elapsedSeconds > 45, true);
  assertEquals(fixture.state().phase, "complete");
});

Deno.test("privacy export pages remain on one repeatable-read snapshot", async () => {
  let committedVersion = 1;
  let snapshotVersion: number | null = null;
  const statements: string[] = [];
  const client: DatabaseClient = {
    async query<Row>(sql: string) {
      statements.push(sql);
      if (sql === "begin isolation level repeatable read") snapshotVersion = committedVersion;
      if (sql.includes("session_user::text")) {
        return { rows: [{ session_user: "argus_worker_edge" } as Row] };
      }
      if (sql.includes("current_user::text")) {
        return { rows: [{ current_user: "argus_worker" } as Row] };
      }
      if (sql === "select exported_version") {
        return { rows: [{ exported_version: snapshotVersion } as Row] };
      }
      return { rows: [] };
    },
    release() {},
  };
  const pool: DatabasePool = {
    async connect() { return client; },
    async end() {},
  };
  const transaction = createWorkerTransaction(pool);
  await transaction(async (database) => {
    const first = await database.query<{ exported_version: number }>("select exported_version");
    committedVersion = 2; // Models a concurrent commit between export pages.
    const second = await database.query<{ exported_version: number }>("select exported_version");
    assertEquals(first.rows[0]?.exported_version, 1);
    assertEquals(second.rows[0]?.exported_version, 1);
  });
  assertEquals(statements.slice(0, 4), [
    "begin isolation level repeatable read",
    "select session_user::text as session_user",
    "set local role argus_worker",
    "select current_user::text as current_user",
  ]);
  assertEquals(statements.at(-1), "commit");
});

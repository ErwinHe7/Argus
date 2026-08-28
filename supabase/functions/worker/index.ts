import { createSupabaseWorkerDatabasePool } from "../_shared/database.ts";
import {
  requiredEnvironment,
  supabaseSecretKey,
} from "../_shared/environment.ts";
import { createSupabaseAuthAdmin } from "../_shared/jobs/auth-admin.ts";
import {
  authenticateWorkerRequest,
  type WorkerSecretConfiguration,
} from "../_shared/jobs/auth.ts";
import { createMemberPurgeSaga } from "../_shared/jobs/purge.ts";
import {
  createSupabaseWorkerRuntime,
  createWorkerTransaction,
} from "../_shared/jobs/runtime.ts";
import { createPrivateSupabaseStorage } from "../_shared/jobs/storage.ts";
import {
  createBlockedWebullRecoveryPorts,
  createBlockedWebullRecoveryProvider,
  createWebullRecoveryPorts,
} from "../_shared/jobs/webull-recovery.ts";
import {
  parseWebullMasterKeyRing,
  WebullTokenVault,
} from "../_shared/webull/tokens.ts";
import {
  runSupabaseQueue,
  type SupabaseQueueRuntime,
} from "../../../ritual-investing-api/src/jobs/queue-runtime.ts";

const MAX_BODY_BYTES = 1_024;

export type WorkerInvocationRuntime = SupabaseQueueRuntime & Readonly<{
  consumeInvocation(nonce: string, issuedAtSeconds: number): Promise<boolean>;
}>;

function response(status: number, body: Record<string, unknown>): Response {
  return Response.json(body, {
    status,
    headers: {
      "cache-control": "no-store",
      "content-type": "application/json; charset=utf-8",
    },
  });
}

async function boundedJson(request: Request): Promise<unknown> {
  const declaredLength = request.headers.get("content-length");
  if (declaredLength !== null && (
    !/^\d{1,10}$/.test(declaredLength) || Number(declaredLength) > MAX_BODY_BYTES
  )) throw new Error("request_body_too_large");
  if (request.body === null) throw new Error("invalid_request_body");
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const result = await reader.read();
    if (result.done) break;
    size += result.value.byteLength;
    if (size > MAX_BODY_BYTES) {
      await reader.cancel();
      throw new Error("request_body_too_large");
    }
    chunks.push(result.value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    throw new Error("invalid_request_body");
  }
}

function batchSizeFrom(body: unknown): number {
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new Error("invalid_request_body");
  }
  const keys = Object.keys(body);
  if (keys.some((key) => key !== "batch_size") || keys.length > 1) {
    throw new Error("invalid_request_body");
  }
  const batchSize = (body as { batch_size?: unknown }).batch_size ?? 25;
  if (!Number.isInteger(batchSize) || Number(batchSize) < 1 || Number(batchSize) > 25) {
    throw new Error("invalid_request_body");
  }
  return Number(batchSize);
}

export function createWorkerHandler(config: Readonly<{
  secrets: WorkerSecretConfiguration;
  runtime: WorkerInvocationRuntime;
  now?: () => Date;
}>): (request: Request) => Promise<Response> {
  return async (request: Request) => {
    if (request.method !== "POST") {
      const denied = response(405, { error: "method_not_allowed" });
      denied.headers.set("allow", "POST");
      return denied;
    }
    const contentType = request.headers.get("content-type")?.split(";", 1)[0]
      ?.trim().toLowerCase();
    if (contentType !== "application/json") {
      return response(415, { error: "unsupported_media_type" });
    }
    const now = config.now?.() ?? new Date();
    if (!await authenticateWorkerRequest(request, config.secrets, now)) {
      return response(401, { error: "unauthorized" });
    }

    let batchSize: number;
    try {
      batchSize = batchSizeFrom(await boundedJson(request));
    } catch (error) {
      return response(
        error instanceof Error && error.message === "request_body_too_large" ? 413 : 400,
        { error: "invalid_request" },
      );
    }

    const nonce = request.headers.get("x-argus-worker-nonce") ?? "";
    const issuedAtSeconds = Number(
      request.headers.get("x-argus-worker-timestamp") ?? "",
    );
    try {
      if (!await config.runtime.consumeInvocation(nonce, issuedAtSeconds)) {
        return response(401, { error: "unauthorized" });
      }
      const result = await runSupabaseQueue(config.runtime, { batchSize });
      return response(200, result);
    } catch {
      return response(503, { error: "worker_unavailable" });
    }
  };
}

function productionHandler(): (request: Request) => Promise<Response> {
  const pool = createSupabaseWorkerDatabasePool(
    requiredEnvironment("EDGE_WORKER_DATABASE_URL"),
  );
  const storage = createPrivateSupabaseStorage({
    supabaseUrl: requiredEnvironment("SUPABASE_URL"),
    secretKey: supabaseSecretKey(),
  });
  const authAdmin = createSupabaseAuthAdmin({
    supabaseUrl: requiredEnvironment("SUPABASE_URL"),
    secretKey: supabaseSecretKey(),
  });
  const purgeSaga = createMemberPurgeSaga({
    storage,
    authAdmin,
    transaction: createWorkerTransaction(pool),
  });
  const webullKeyRing = Deno.env.get("WEBULL_MASTER_KEY_RING");
  const webullEnvironment = Deno.env.get("WEBULL_ENVIRONMENT");
  const webull = webullKeyRing !== undefined &&
      (webullEnvironment === "sandbox" || webullEnvironment === "production")
    ? createWebullRecoveryPorts({
      transaction: createWorkerTransaction(pool),
      vault: new WebullTokenVault(
        webullEnvironment,
        parseWebullMasterKeyRing(webullKeyRing),
      ),
      // U5 remains unresolved. A partner-confirmed recovery transport can be
      // injected here without changing any queue or database authority.
      provider: createBlockedWebullRecoveryProvider(),
    })
    : createBlockedWebullRecoveryPorts();
  const runtime = createSupabaseWorkerRuntime({
    pool,
    dependencies: { storage, purgeSaga, webull },
  });
  const next = Deno.env.get("WORKER_SECRET_NEXT") || undefined;
  const nextValidUntilText = Deno.env.get("WORKER_SECRET_NEXT_VALID_UNTIL");
  return createWorkerHandler({
    runtime,
    secrets: {
      current: requiredEnvironment("WORKER_SECRET_CURRENT"),
      next,
      nextValidUntil: nextValidUntilText === undefined
        ? undefined
        : new Date(nextValidUntilText),
    },
  });
}

if (import.meta.main) Deno.serve(productionHandler());

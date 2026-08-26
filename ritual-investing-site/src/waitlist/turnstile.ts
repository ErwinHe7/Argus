const SITEVERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify";
const DEFAULT_TIMEOUT_MS = 2_500;
const MAX_ATTEMPTS = 2;
const MAX_TOKEN_BYTES = 2_048;
const INTERNAL_ERROR = "internal-error";

export type TurnstileVerificationInput = {
  token: string;
  secret: string;
  expectedHostname: string;
  expectedAction: "waitlist";
};

export type TurnstileVerificationResult =
  | { ok: true }
  | { ok: false; kind: "rejected" | "unavailable" };

type TurnstileDependencies = {
  fetcher?: typeof fetch;
  createIdempotencyKey?: () => string;
  timeoutMs?: number;
};

type SiteverifyPayload = {
  success?: unknown;
  hostname?: unknown;
  action?: unknown;
  "error-codes"?: unknown;
};

function isInternalError(payload: SiteverifyPayload): boolean {
  return Array.isArray(payload["error-codes"]) && payload["error-codes"].includes(INTERNAL_ERROR);
}

function isSiteverifyPayload(value: unknown): value is SiteverifyPayload {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

async function siteverifyAttempt(
  fetcher: typeof fetch,
  body: URLSearchParams,
  timeoutMs: number,
): Promise<
  | { kind: "response"; ok: boolean; status: number; payload: SiteverifyPayload }
  | { kind: "unavailable" }
> {
  const controller = new AbortController();
  let timeout: ReturnType<typeof setTimeout> | undefined;
  const deadline = new Promise<{ kind: "unavailable" }>((resolve) => {
    timeout = setTimeout(() => {
      controller.abort();
      resolve({ kind: "unavailable" });
    }, timeoutMs);
  });
  try {
    const operation = (async () => {
      const response = await fetcher(SITEVERIFY_URL, {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: body.toString(),
        signal: controller.signal,
      });
      const payload: unknown = await response.json();
      if (!isSiteverifyPayload(payload)) throw new Error("Malformed Siteverify response.");
      return {
        kind: "response" as const,
        ok: response.ok,
        status: response.status,
        payload,
      };
    })();
    return await Promise.race([operation, deadline]);
  } catch {
    return { kind: "unavailable" };
  } finally {
    if (timeout !== undefined) clearTimeout(timeout);
  }
}

export async function verifyTurnstile(
  input: TurnstileVerificationInput,
  dependencies: TurnstileDependencies = {},
): Promise<TurnstileVerificationResult> {
  const tokenBytes = new TextEncoder().encode(input.token).byteLength;
  if (tokenBytes === 0 || tokenBytes > MAX_TOKEN_BYTES) return { ok: false, kind: "rejected" };
  if (input.secret.length === 0) return { ok: false, kind: "unavailable" };

  let idempotencyKey: string;
  try {
    idempotencyKey = (dependencies.createIdempotencyKey ?? (() => crypto.randomUUID()))();
  } catch {
    return { ok: false, kind: "unavailable" };
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(idempotencyKey)) {
    return { ok: false, kind: "unavailable" };
  }
  const body = new URLSearchParams({
    secret: input.secret,
    response: input.token,
    idempotency_key: idempotencyKey,
  });
  const fetcher = dependencies.fetcher ?? fetch;
  const timeoutMs = Math.max(1, Math.min(dependencies.timeoutMs ?? DEFAULT_TIMEOUT_MS, DEFAULT_TIMEOUT_MS));

  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt += 1) {
    const result = await siteverifyAttempt(fetcher, body, timeoutMs);
    if (result.kind === "unavailable") {
      if (attempt + 1 < MAX_ATTEMPTS) continue;
      return { ok: false, kind: "unavailable" };
    }
    if (!result.ok) {
      if (result.status >= 500 && attempt + 1 < MAX_ATTEMPTS) continue;
      return { ok: false, kind: "unavailable" };
    }
    const payload = result.payload;
    if (isInternalError(payload)) {
      if (attempt + 1 < MAX_ATTEMPTS) continue;
      return { ok: false, kind: "unavailable" };
    }
    if (
      payload.success === true &&
      payload.hostname === input.expectedHostname &&
      payload.action === input.expectedAction
    ) return { ok: true };
    return { ok: false, kind: "rejected" };
  }

  return { ok: false, kind: "unavailable" };
}

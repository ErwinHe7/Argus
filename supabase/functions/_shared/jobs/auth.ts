const MAX_ROTATION_OVERLAP_MS = 10 * 60_000;
const MAX_REQUEST_AGE_MS = 60_000;
const secretPattern = /^[\x21-\x7e]{32,256}$/;
const noncePattern = /^[a-f0-9]{32}$/;
const proofPattern = /^[a-f0-9]{64}$/;

export type WorkerSecretConfiguration = Readonly<{
  current: string;
  next?: string;
  nextValidUntil?: Date;
}>;

function constantTimeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length, 1);
  let mismatch = leftBytes.length ^ rightBytes.length;
  for (let index = 0; index < length; index += 1) {
    mismatch |= (leftBytes[index % leftBytes.length] ?? 0) ^
      (rightBytes[index % rightBytes.length] ?? 0);
  }
  return mismatch === 0;
}

function hex(bytes: ArrayBuffer): string {
  return [...new Uint8Array(bytes)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function signWorkerInvocation(
  secret: string,
  issuedAtSeconds: number,
  nonce: string,
): Promise<string> {
  if (!secretPattern.test(secret) || !Number.isInteger(issuedAtSeconds) || !noncePattern.test(nonce)) {
    throw new Error("invalid_worker_signature_input");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return hex(await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${issuedAtSeconds}.${nonce}`),
  ));
}

function validConfiguration(config: WorkerSecretConfiguration): boolean {
  if (!secretPattern.test(config.current)) return false;
  if (config.next === undefined) return config.nextValidUntil === undefined;
  return secretPattern.test(config.next) &&
    config.nextValidUntil !== undefined &&
    Number.isFinite(config.nextValidUntil.getTime());
}

export async function authenticateWorkerRequest(
  request: Request,
  config: WorkerSecretConfiguration,
  now = new Date(),
): Promise<boolean> {
  const issuedAtText = request.headers.get("x-argus-worker-timestamp") ?? "";
  const nonce = request.headers.get("x-argus-worker-nonce") ?? "";
  const suppliedProof = request.headers.get("x-argus-worker-proof") ?? "";
  if (!validConfiguration(config) || !/^\d{10}$/.test(issuedAtText) ||
    !noncePattern.test(nonce) || !proofPattern.test(suppliedProof)) return false;
  const issuedAtSeconds = Number(issuedAtText);
  const age = now.getTime() - issuedAtSeconds * 1_000;
  if (age < -5_000 || age > MAX_REQUEST_AGE_MS) return false;

  const currentProof = await signWorkerInvocation(config.current, issuedAtSeconds, nonce);
  const currentMatches = constantTimeEqual(suppliedProof, currentProof);
  const nextExpiry = config.nextValidUntil?.getTime();
  const nextIsBounded =
    config.next !== undefined &&
    nextExpiry !== undefined &&
    Number.isFinite(nextExpiry) &&
    nextExpiry >= now.getTime() &&
    nextExpiry - now.getTime() <= MAX_ROTATION_OVERLAP_MS;
  const nextProof = await signWorkerInvocation(
    config.next ?? config.current,
    issuedAtSeconds,
    nonce,
  );
  const nextMatches = constantTimeEqual(suppliedProof, nextProof);
  return currentMatches || (nextIsBounded && nextMatches);
}

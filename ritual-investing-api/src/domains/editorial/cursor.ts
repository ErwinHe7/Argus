import { z } from "zod";

const cursorPayloadSchema = z.object({
  v: z.literal(1),
  scope: z.string().min(1).max(256),
  after: z.string().min(1).max(512),
}).strict();

export class InvalidCursorError extends Error {
  constructor() {
    super("invalid_cursor");
    this.name = "InvalidCursorError";
  }
}

function base64UrlEncode(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function base64UrlDecode(value: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) throw new InvalidCursorError();
  const padded = value.replaceAll("-", "+").replaceAll("_", "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  try {
    return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
  } catch {
    throw new InvalidCursorError();
  }
}

async function signingKey(secret: string, usage: Array<"sign" | "verify">): Promise<CryptoKey> {
  if (secret.length < 32 || secret.length > 512) throw new InvalidCursorError();
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    usage,
  );
}

export async function encodeCursor(
  secret: string,
  scope: string,
  after: string,
): Promise<string> {
  const payload = new TextEncoder().encode(JSON.stringify({ v: 1, scope, after }));
  const signature = await crypto.subtle.sign(
    "HMAC",
    await signingKey(secret, ["sign"]),
    payload,
  );
  return `${base64UrlEncode(payload)}.${base64UrlEncode(new Uint8Array(signature))}`;
}

export async function decodeCursor(
  secret: string,
  expectedScope: string,
  cursor: string | undefined,
): Promise<string | undefined> {
  if (cursor === undefined) return undefined;
  const [encodedPayload, encodedSignature, extra] = cursor.split(".");
  if (encodedPayload === undefined || encodedSignature === undefined || extra !== undefined) {
    throw new InvalidCursorError();
  }
  const payload = base64UrlDecode(encodedPayload);
  const signature = base64UrlDecode(encodedSignature);
  const valid = await crypto.subtle.verify(
    "HMAC",
    await signingKey(secret, ["verify"]),
    signature,
    payload,
  );
  if (!valid) throw new InvalidCursorError();
  try {
    const parsed = cursorPayloadSchema.parse(JSON.parse(new TextDecoder().decode(payload)));
    if (parsed.scope !== expectedScope) throw new InvalidCursorError();
    return parsed.after;
  } catch (error) {
    if (error instanceof InvalidCursorError) throw error;
    throw new InvalidCursorError();
  }
}

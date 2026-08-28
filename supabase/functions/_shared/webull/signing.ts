import { createHash, createHmac } from "node:crypto";

const signedHeaderNames = Object.freeze([
  "host",
  "x-app-key",
  "x-signature-algorithm",
  "x-signature-nonce",
  "x-signature-version",
  "x-timestamp",
]);

export type WebullSigningInput = Readonly<{
  path: string;
  query: Readonly<Record<string, string>>;
  headers: Readonly<Record<string, string>>;
  bodyBytes?: Uint8Array;
  appSecret: string;
}>;

export type WebullSignature = Readonly<{
  canonical: string;
  encoded: string;
  bodyMd5: string | null;
  value: string;
}>;

function strictPercentEncode(value: string): string {
  return encodeURIComponent(value).replace(
    /[!'()*]/g,
    (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

function validPath(path: string): boolean {
  return path.startsWith("/") &&
    !path.startsWith("//") &&
    !path.includes("..") &&
    !path.includes("\\") &&
    !path.includes(":") &&
    !path.includes("?") &&
    !path.includes("#") &&
    !/%2f|%5c/i.test(path);
}

function safeEntry(name: string, value: string): void {
  if (
    !/^[A-Za-z0-9][A-Za-z0-9._~-]{0,127}$/.test(name) ||
    value.length > 4_096 ||
    /[\u0000-\u001f\u007f]/.test(value)
  ) {
    throw new Error("invalid_webull_signing_component");
  }
}

/**
 * Implements the current official Webull HMAC-SHA1 worked example exactly.
 * The body digest is computed from the same immutable bytes returned to the
 * caller; adapters must send those bytes without reserializing them.
 */
export function signWebullRequest(input: WebullSigningInput): WebullSignature {
  if (!validPath(input.path)) throw new Error("invalid_webull_signing_path");
  if (!/^[\x21-\x7e]{16,512}$/.test(input.appSecret)) {
    throw new Error("invalid_webull_app_secret");
  }

  const normalizedHeaders = Object.fromEntries(
    Object.entries(input.headers).map(([name, value]) => [
      name.toLowerCase(),
      value,
    ]),
  );
  const entries: [string, string][] = [];
  for (const [name, value] of Object.entries(input.query)) {
    safeEntry(name, value);
    entries.push([name, value]);
  }
  for (const name of signedHeaderNames) {
    const value = normalizedHeaders[name];
    if (value === undefined) throw new Error(`missing_webull_signing_${name}`);
    safeEntry(name, value);
    entries.push([name, value]);
  }
  const duplicateNames = new Set<string>();
  for (const [name] of entries) {
    if (duplicateNames.has(name)) {
      throw new Error("duplicate_webull_signing_name");
    }
    duplicateNames.add(name);
  }
  entries.sort(([left], [right]) => left < right ? -1 : left > right ? 1 : 0);
  const joined = entries.map(([name, value]) => `${name}=${value}`).join("&");
  const bodyMd5 =
    input.bodyBytes === undefined || input.bodyBytes.byteLength === 0
      ? null
      : createHash("md5").update(input.bodyBytes).digest("hex").toUpperCase();
  const canonical = bodyMd5 === null
    ? `${input.path}&${joined}`
    : `${input.path}&${joined}&${bodyMd5}`;
  const encoded = strictPercentEncode(canonical);
  const value = createHmac("sha1", `${input.appSecret}&`)
    .update(encoded)
    .digest("base64");
  return Object.freeze({ canonical, encoded, bodyMd5, value });
}

export function exactJsonBody(value: unknown): Uint8Array {
  const text = JSON.stringify(value);
  if (text === undefined) throw new Error("invalid_webull_json_body");
  return new TextEncoder().encode(text);
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

function base64ToBytes(value: string): Uint8Array {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const binary = atob(
    normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "="),
  );
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

export async function protectPushToken(token: string, encodedKey: string) {
  const keyBytes = base64ToBytes(encodedKey);
  if (keyBytes.byteLength !== 32) throw new Error("invalid_push_token_key");
  const hash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(token),
  );
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await crypto.subtle.importKey("raw", keyBytes, "AES-GCM", false, [
    "encrypt",
  ]);
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    new TextEncoder().encode(token),
  );
  return {
    tokenHash: bytesToBase64(new Uint8Array(hash)),
    tokenCiphertext: `v1.${bytesToBase64(iv)}.${bytesToBase64(new Uint8Array(ciphertext))}`,
  };
}

export async function unprotectPushToken(
  protectedToken: string,
  encodedKey: string,
): Promise<string> {
  const keyBytes = base64ToBytes(encodedKey);
  if (keyBytes.byteLength !== 32) throw new Error("invalid_push_token_key");
  const [version, encodedIv, encodedCiphertext, ...extra] =
    protectedToken.split(".");
  if (
    version !== "v1" ||
    encodedIv === undefined ||
    encodedCiphertext === undefined ||
    extra.length !== 0
  )
    throw new Error("invalid_push_token_ciphertext");
  const iv = base64ToBytes(encodedIv);
  if (iv.byteLength !== 12) throw new Error("invalid_push_token_ciphertext");
  const key = await crypto.subtle.importKey("raw", keyBytes, "AES-GCM", false, [
    "decrypt",
  ]);
  try {
    const plaintext = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv },
      key,
      base64ToBytes(encodedCiphertext),
    );
    const token = new TextDecoder("utf-8", {
      fatal: true,
      ignoreBOM: false,
    }).decode(plaintext);
    if (token.length < 16 || token.length > 4096)
      throw new Error("invalid_push_token_ciphertext");
    return token;
  } catch {
    throw new Error("invalid_push_token_ciphertext");
  }
}

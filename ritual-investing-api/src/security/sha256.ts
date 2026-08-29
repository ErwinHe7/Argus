export async function sha256TextHex(value: string): Promise<string> {
  return sha256BytesHex(new TextEncoder().encode(value));
}

export async function sha256BytesHex(value: Uint8Array): Promise<string> {
  const digestInput = new Uint8Array(value.byteLength);
  digestInput.set(value);
  const digest = await crypto.subtle.digest(
    "SHA-256",
    digestInput.buffer,
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

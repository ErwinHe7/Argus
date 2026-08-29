import { createHash } from "node:crypto";

import { sha256BytesHex } from "../../../../ritual-investing-api/src/security/sha256.ts";

const privateBuckets = new Set([
  "member-media",
  "media-quarantine",
  "privacy-exports",
]);
const objectPathPattern = /^[0-9a-f-]{36}\/[A-Za-z0-9._/-]{1,512}$/i;

export type PrivateObject = Readonly<{
  body: Uint8Array;
  contentType: string;
}>;

export type PrivateObjectStream = Readonly<{
  body: ReadableStream<Uint8Array>;
  contentType: string;
}>;

export type PrivateUploadBody = Uint8Array | ReadableStream<Uint8Array>;

export interface PrivateStorage {
  get(bucket: string, path: string): Promise<PrivateObject | null>;
  getStream(bucket: string, path: string): Promise<PrivateObjectStream | null>;
  putImmutable(
    bucket: string,
    path: string,
    body: PrivateUploadBody,
    contentType: string,
    expectedChecksum: string,
    expectedByteLength?: number,
  ): Promise<"created" | "reconciled">;
  remove(bucket: string, paths: readonly string[]): Promise<void>;
  createSignedUrl(
    bucket: string,
    path: string,
    expiresInSeconds: number,
  ): Promise<string>;
}

function objectPath(bucket: string, path: string): string {
  if (
    !privateBuckets.has(bucket) || !objectPathPattern.test(path) ||
    path.includes("..")
  ) {
    throw new Error("invalid_storage_object");
  }
  return `${encodeURIComponent(bucket)}/${
    path.split("/").map(encodeURIComponent).join("/")
  }`;
}

async function successful(response: Response): Promise<Response> {
  if (!response.ok) throw new Error("storage_unavailable");
  return response;
}

function verifiedUploadStream(
  body: ReadableStream<Uint8Array>,
  expectedChecksum: string,
  expectedByteLength: number,
): Readonly<{
  body: ReadableStream<Uint8Array>;
  verified: Promise<void>;
}> {
  if (!Number.isSafeInteger(expectedByteLength) || expectedByteLength < 0) {
    throw new Error("storage_object_checksum_mismatch");
  }
  const reader = body.getReader();
  const digest = createHash("sha256");
  let byteLength = 0;
  let released = false;
  let settled = false;
  let resolveVerified!: () => void;
  let rejectVerified!: (reason: unknown) => void;
  const verified = new Promise<void>((resolve, reject) => {
    resolveVerified = resolve;
    rejectVerified = reject;
  });
  void verified.catch(() => undefined);
  const settleFailure = (reason: unknown) => {
    if (settled) return;
    settled = true;
    rejectVerified(reason);
  };
  const release = () => {
    if (released) return;
    released = true;
    reader.releaseLock();
  };
  const uploadBody = new ReadableStream<Uint8Array>({
    async pull(controller) {
      try {
        const next = await reader.read();
        if (next.done) {
          const checksum = digest.digest("hex");
          if (
            byteLength !== expectedByteLength ||
            checksum !== expectedChecksum
          ) {
            throw new Error("storage_object_checksum_mismatch");
          }
          settled = true;
          resolveVerified();
          controller.close();
          release();
          return;
        }
        if (byteLength > expectedByteLength - next.value.byteLength) {
          throw new Error("storage_object_checksum_mismatch");
        }
        byteLength += next.value.byteLength;
        digest.update(next.value);
        controller.enqueue(next.value);
      } catch (error) {
        settleFailure(error);
        controller.error(error);
        try {
          await reader.cancel(error);
        } finally {
          release();
        }
      }
    },
    async cancel(reason) {
      settleFailure(reason);
      try {
        await reader.cancel(reason);
      } finally {
        release();
      }
    },
  });
  return { body: uploadBody, verified };
}

export function createPrivateSupabaseStorage(
  config: Readonly<{
    supabaseUrl: string;
    secretKey: string;
    fetch?: typeof fetch;
  }>,
): PrivateStorage {
  const base = new URL("/storage/v1/", config.supabaseUrl);
  const fetcher = config.fetch ?? fetch;
  const headers = Object.freeze({
    apikey: config.secretKey,
  });
  const request = (path: string, init: RequestInit) =>
    fetcher(new URL(path, base), {
      ...init,
      headers: { ...headers, ...init.headers },
      signal: AbortSignal.timeout(10_000),
    });
  const readObjectResponse = async (
    bucket: string,
    path: string,
  ): Promise<Response | null> => {
    const response = await request(`object/${objectPath(bucket, path)}`, {
      method: "GET",
    });
    if (response.status === 404) return null;
    return await successful(response);
  };
  const readObject = async (
    bucket: string,
    path: string,
  ): Promise<PrivateObject | null> => {
    const response = await readObjectResponse(bucket, path);
    if (response === null) return null;
    return {
      body: new Uint8Array(await response.arrayBuffer()),
      contentType: response.headers.get("content-type") ??
        "application/octet-stream",
    };
  };

  return Object.freeze({
    async get(bucket: string, path: string) {
      return readObject(bucket, path);
    },
    async getStream(bucket: string, path: string) {
      const response = await readObjectResponse(bucket, path);
      if (response === null) return null;
      return {
        body: response.body ?? new ReadableStream<Uint8Array>({
          start(controller) {
            controller.close();
          },
        }),
        contentType: response.headers.get("content-type") ??
          "application/octet-stream",
      };
    },
    async putImmutable(
      bucket: string,
      path: string,
      body: PrivateUploadBody,
      contentType: string,
      expectedChecksum: string,
      expectedByteLength?: number,
    ) {
      if (!/^[a-f0-9]{64}$/.test(expectedChecksum)) {
        throw new Error("storage_object_checksum_mismatch");
      }
      let uploadBody: BodyInit;
      let verified: Promise<void>;
      if (body instanceof Uint8Array) {
        if (
          (expectedByteLength !== undefined &&
            expectedByteLength !== body.byteLength) ||
          await sha256BytesHex(body) !== expectedChecksum
        ) {
          throw new Error("storage_object_checksum_mismatch");
        }
        uploadBody = body.slice().buffer as ArrayBuffer;
        verified = Promise.resolve();
      } else {
        if (expectedByteLength === undefined) {
          throw new Error("storage_object_checksum_mismatch");
        }
        const streaming = verifiedUploadStream(
          body,
          expectedChecksum,
          expectedByteLength,
        );
        uploadBody = streaming.body as BodyInit;
        verified = streaming.verified;
      }
      const [response] = await Promise.all([
        request(`object/${objectPath(bucket, path)}`, {
          method: "POST",
          headers: { "content-type": contentType, "x-upsert": "false" },
          body: uploadBody,
        }),
        verified,
      ]);
      if (response.ok) return "created";
      if (response.status !== 400 && response.status !== 409) {
        throw new Error("storage_unavailable");
      }
      const existing = await readObject(bucket, path);
      if (
        existing === null ||
        await sha256BytesHex(existing.body) !== expectedChecksum
      ) {
        throw new Error("storage_object_conflict");
      }
      return "reconciled";
    },
    async remove(bucket: string, paths: readonly string[]) {
      if (paths.length < 1 || paths.length > 100) {
        throw new Error("invalid_storage_batch");
      }
      for (const path of paths) objectPath(bucket, path);
      await successful(
        await request(`object/${encodeURIComponent(bucket)}`, {
          method: "DELETE",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ prefixes: paths }),
        }),
      );
    },
    async createSignedUrl(
      bucket: string,
      path: string,
      expiresInSeconds: number,
    ) {
      if (
        !Number.isInteger(expiresInSeconds) || expiresInSeconds < 1 ||
        expiresInSeconds > 300
      ) {
        throw new Error("invalid_signed_url_expiry");
      }
      const response = await successful(
        await request(
          `object/sign/${objectPath(bucket, path)}`,
          {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({ expiresIn: expiresInSeconds }),
          },
        ),
      );
      const payload = await response.json() as { signedURL?: unknown };
      if (
        typeof payload.signedURL !== "string" ||
        !payload.signedURL.startsWith("/storage/v1/object/sign/")
      ) {
        throw new Error("storage_unavailable");
      }
      return new URL(payload.signedURL, config.supabaseUrl).toString();
    },
  });
}

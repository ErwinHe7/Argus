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

export interface PrivateStorage {
  get(bucket: string, path: string): Promise<PrivateObject | null>;
  put(
    bucket: string,
    path: string,
    body: BodyInit,
    contentType: string,
  ): Promise<void>;
  remove(bucket: string, paths: readonly string[]): Promise<void>;
  createSignedUrl(bucket: string, path: string, expiresInSeconds: number): Promise<string>;
}

function objectPath(bucket: string, path: string): string {
  if (!privateBuckets.has(bucket) || !objectPathPattern.test(path) || path.includes("..")) {
    throw new Error("invalid_storage_object");
  }
  return `${encodeURIComponent(bucket)}/${path.split("/").map(encodeURIComponent).join("/")}`;
}

async function successful(response: Response): Promise<Response> {
  if (!response.ok) throw new Error("storage_unavailable");
  return response;
}

export function createPrivateSupabaseStorage(config: Readonly<{
  supabaseUrl: string;
  secretKey: string;
  fetch?: typeof fetch;
}>): PrivateStorage {
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

  return Object.freeze({
    async get(bucket: string, path: string) {
      const response = await request(`object/${objectPath(bucket, path)}`, {
        method: "GET",
      });
      if (response.status === 404) return null;
      await successful(response);
      return {
        body: new Uint8Array(await response.arrayBuffer()),
        contentType: response.headers.get("content-type") ?? "application/octet-stream",
      };
    },
    async put(bucket: string, path: string, body: BodyInit, contentType: string) {
      await successful(await request(`object/${objectPath(bucket, path)}`, {
        method: "POST",
        headers: { "content-type": contentType, "x-upsert": "true" },
        body,
      }));
    },
    async remove(bucket: string, paths: readonly string[]) {
      if (paths.length < 1 || paths.length > 100) throw new Error("invalid_storage_batch");
      for (const path of paths) objectPath(bucket, path);
      await successful(await request(`object/${encodeURIComponent(bucket)}`, {
        method: "DELETE",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ prefixes: paths }),
      }));
    },
    async createSignedUrl(bucket: string, path: string, expiresInSeconds: number) {
      if (!Number.isInteger(expiresInSeconds) || expiresInSeconds < 1 || expiresInSeconds > 300) {
        throw new Error("invalid_signed_url_expiry");
      }
      const response = await successful(await request(
        `object/sign/${objectPath(bucket, path)}`,
        {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ expiresIn: expiresInSeconds }),
        },
      ));
      const payload = await response.json() as { signedURL?: unknown };
      if (typeof payload.signedURL !== "string" || !payload.signedURL.startsWith("/storage/v1/object/sign/")) {
        throw new Error("storage_unavailable");
      }
      return new URL(payload.signedURL, config.supabaseUrl).toString();
    },
  });
}

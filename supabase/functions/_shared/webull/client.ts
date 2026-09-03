import {
  assertPartnerConfirmedContract,
  type PartnerConfirmedWebullContract,
  WebullProtocolGateError,
  type WebullPublicContract,
} from "./contract.ts";
import { exactJsonBody, signWebullRequest } from "./signing.ts";
import type {
  PlainWebullCredentials,
  WebullRefreshProvider,
} from "./tokens.ts";

export type WebullAuthorizedAccount = Readonly<{
  providerAccountId: string;
  displayLabel: string;
  baseCurrency: string;
  status: "available" | "restricted" | "closed" | "unavailable";
  capabilityVersion: number;
  marketTimezone: string;
  capabilities: readonly Readonly<{ code: string; available: boolean }>[];
}>;

export interface WebullAuthorizationProvider extends WebullRefreshProvider {
  authorizationUrl(state: string): URL;
  exchangeAuthorizationCode(
    code: string,
    rateLimitOwnerScope: string,
  ): Promise<PlainWebullCredentials>;
  listAccounts(
    accessToken: string,
    rateLimitOwnerScope: string,
  ): Promise<readonly WebullAuthorizedAccount[]>;
}

export type WebullProviderRateLimit = Readonly<{
  consume(
    input: Readonly<{
      scope: string;
      limit: number;
      windowSeconds: number;
    }>,
  ): Promise<boolean>;
}>;

export type WebullClientCredentials = Readonly<{
  clientSecret: string;
  appKey: string;
  appSecret: string;
}>;

export type WebullAccountParser = (
  payload: unknown,
) => readonly WebullAuthorizedAccount[];

export class WebullTransientProviderError extends Error {
  constructor() {
    super("webull_temporarily_unavailable");
    this.name = "WebullTransientProviderError";
  }
}

function strictToken(value: unknown, name: string): string {
  if (typeof value !== "string" || !/^[\x21-\x7e]{8,8192}$/.test(value)) {
    throw new Error(`invalid_webull_${name}`);
  }
  return value;
}

function positiveSeconds(value: unknown, name: string): number {
  const parsed = typeof value === "string" && /^\d+$/.test(value)
    ? Number(value)
    : value;
  if (!Number.isInteger(parsed) || Number(parsed) < 1) {
    throw new Error(`invalid_webull_${name}`);
  }
  return Number(parsed);
}

function tokenResponse(payload: unknown, now: Date): PlainWebullCredentials {
  if (typeof payload !== "object" || payload === null) {
    throw new Error("invalid_webull_token_response");
  }
  const record = payload as Record<string, unknown>;
  if (record.token_type !== "Bearer") {
    throw new Error("invalid_webull_token_type");
  }
  const accessSeconds = positiveSeconds(record.expires_in, "access_expiry");
  const refreshSeconds = positiveSeconds(
    record.rt_expires_in,
    "refresh_expiry",
  );
  return Object.freeze({
    accessToken: strictToken(record.access_token, "access_token"),
    refreshToken: strictToken(record.refresh_token, "refresh_token"),
    accessExpiresAt: new Date(now.getTime() + accessSeconds * 1_000),
    refreshExpiresAt: new Date(now.getTime() + refreshSeconds * 1_000),
  });
}

function validateProviderUrl(
  origin: string,
  path: string,
  query: Readonly<Record<string, string>> = {},
): URL {
  if (
    !path.startsWith("/") ||
    path.startsWith("//") ||
    path.includes("..") ||
    path.includes("\\") ||
    path.includes(":") ||
    path.includes("?") ||
    path.includes("#") ||
    /%2f|%5c/i.test(path)
  ) {
    throw new WebullProtocolGateError("invalid_webull_provider_path");
  }
  const base = new URL(origin);
  const url = new URL(path, base);
  if (
    url.origin !== base.origin ||
    url.protocol !== "https:" ||
    url.port !== "" ||
    url.username !== "" ||
    url.password !== ""
  ) {
    throw new WebullProtocolGateError("invalid_webull_provider_url");
  }
  for (const [name, value] of Object.entries(query)) {
    if (
      !/^[A-Za-z0-9_~-]{1,64}$/.test(name) ||
      /[\u0000-\u001f\u007f]/.test(value)
    ) {
      throw new WebullProtocolGateError("invalid_webull_provider_query");
    }
    url.searchParams.set(name, value);
  }
  return url;
}

async function boundedJson(response: Response): Promise<unknown> {
  const maximum = 1024 * 1024;
  const declared = Number(response.headers.get("content-length"));
  if (Number.isFinite(declared) && declared > maximum) {
    throw new Error("webull_response_too_large");
  }
  if (response.body === null) throw new Error("empty_webull_response");
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      length += next.value.length;
      if (length > maximum) throw new Error("webull_response_too_large");
      chunks.push(next.value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return JSON.parse(
    new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(bytes),
  );
}

/**
 * A real adapter can only be constructed from a complete partner-confirmed
 * contract. Public documentation alone intentionally produces a hard error.
 */
export function createWebullClient(
  input: Readonly<{
    contract: PartnerConfirmedWebullContract | WebullPublicContract;
    credentials: WebullClientCredentials;
    rateLimit: WebullProviderRateLimit;
    parseAccounts?: WebullAccountParser;
    fetch?: typeof globalThis.fetch;
    now?: () => Date;
    nonce?: () => string;
  }>,
): WebullAuthorizationProvider {
  assertPartnerConfirmedContract(input.contract);
  const contract = input.contract;
  if (input.parseAccounts === undefined) {
    throw new WebullProtocolGateError("partner_account_fixture_missing");
  }
  if (
    !/^[\x21-\x7e]{16,512}$/.test(input.credentials.clientSecret) ||
    !/^[A-Za-z0-9._~-]{8,255}$/.test(input.credentials.appKey) ||
    !/^[\x21-\x7e]{16,512}$/.test(input.credentials.appSecret)
  ) {
    throw new WebullProtocolGateError("invalid_webull_credentials");
  }
  const send = input.fetch ?? globalThis.fetch;
  const now = input.now ?? (() => new Date());
  const nonce = input.nonce ?? (() => crypto.randomUUID().replaceAll("-", ""));

  const authorizationUrl = (state: string): URL => {
    if (!/^[A-Za-z0-9_-]{43,128}$/.test(state)) {
      throw new Error("invalid_webull_oauth_state");
    }
    const publicContract = contract.publicContract;
    const origin = contract.authorizationEntrypoint === "passport_login"
      ? publicContract.authorizationOrigin
      : publicContract.apiOrigin;
    const path = contract.authorizationEntrypoint === "passport_login"
      ? publicContract.authorizationPath
      : publicContract.authorizationCodePath;
    return validateProviderUrl(origin, path, {
      response_type: "code",
      client_id: contract.clientId,
      scope: contract.authorizationScope,
      state,
      redirect_uri: contract.redirectUri,
    });
  };

  const signedFetch = async (
    path: string,
    init: Readonly<{
      method: "GET" | "POST";
      query?: Readonly<Record<string, string>>;
      body?: Uint8Array;
      contentType?: string;
      accessToken?: string;
      includeClientSecret?: boolean;
      rateLimitOwnerScope: string;
    }>,
  ): Promise<unknown> => {
    const publicContract = contract.publicContract;
    const url = validateProviderUrl(publicContract.apiOrigin, path, init.query);
    const timestamp = now().toISOString().replace(/\.\d{3}Z$/, "Z");
    const headers: Record<string, string> = {
      host: url.host,
      "x-app-key": input.credentials.appKey,
      "x-signature-algorithm": "HMAC-SHA1",
      "x-signature-version": "1.0",
      "x-signature-nonce": nonce(),
      "x-timestamp": timestamp,
      "x-version": "v2",
      accept: "application/json",
    };
    if (init.contentType !== undefined) {
      headers["content-type"] = init.contentType;
    }
    if (init.accessToken !== undefined) {
      headers.authorization = `Bearer ${
        strictToken(init.accessToken, "access_token")
      }`;
    }
    if (init.includeClientSecret === true) {
      headers["x-app-secret"] = input.credentials.appSecret;
    }
    const signature = signWebullRequest({
      path,
      query: init.query ?? {},
      headers,
      ...(init.body === undefined ? {} : { bodyBytes: init.body }),
      appSecret: input.credentials.appSecret,
    });
    headers["x-signature"] = signature.value;

    if (!/^[a-f0-9]{64}$/.test(init.rateLimitOwnerScope)) {
      throw new Error("invalid_webull_rate_limit_owner");
    }
    const aggregateAllowed = await input.rateLimit.consume({
      scope:
        `webull:${publicContract.environment}:user:${init.rateLimitOwnerScope}`,
      limit: publicContract.aggregateRequestsPerUserPerMinute,
      windowSeconds: 60,
    });
    const endpointAllowed = aggregateAllowed && await input.rateLimit.consume({
      scope:
        `webull:${publicContract.environment}:user:${init.rateLimitOwnerScope}:path:${path}`,
      limit: contract.endpointRequestsPerWindow.limit,
      windowSeconds: contract.endpointRequestsPerWindow.windowSeconds,
    });
    if (!endpointAllowed) {
      throw new WebullTransientProviderError();
    }
    const requestBody = init.body === undefined
      ? undefined
      : Uint8Array.from(init.body);
    let response: Response;
    try {
      response = await send(url, {
        method: init.method,
        headers,
        ...(requestBody === undefined ? {} : { body: requestBody }),
        redirect: "error",
        signal: AbortSignal.timeout(10_000),
      });
    } catch {
      throw new WebullTransientProviderError();
    }
    if (response.status === 429 || response.status >= 500) {
      throw new WebullTransientProviderError();
    }
    if (!response.ok) throw new Error("webull_provider_rejected_request");
    const contentType = response.headers.get("content-type")?.split(";", 1)[0];
    if (contentType !== "application/json") {
      throw new Error("invalid_webull_response_content_type");
    }
    return boundedJson(response);
  };

  const tokenCall = async (
    values: Readonly<Record<string, string>>,
    rateLimitOwnerScope: string,
  ): Promise<PlainWebullCredentials> => {
    const isJson = contract.tokenContentType === "application/json";
    const body = isJson
      ? exactJsonBody(values)
      : new TextEncoder().encode(new URLSearchParams(values).toString());
    const payload = await signedFetch(contract.publicContract.tokenPath, {
      method: "POST",
      body,
      contentType: contract.tokenContentType,
      includeClientSecret: contract.tokenSecretTransport === "x-app-secret",
      rateLimitOwnerScope,
    });
    return tokenResponse(payload, now());
  };

  return Object.freeze({
    authorizationUrl,
    exchangeAuthorizationCode: (code: string, rateLimitOwnerScope: string) =>
      tokenCall({
        client_id: contract.clientId,
        client_secret: input.credentials.clientSecret,
        grant_type: "authorization_code",
        code: strictToken(code, "authorization_code"),
      }, rateLimitOwnerScope),
    refresh: (refreshToken: string, rateLimitOwnerScope: string) =>
      tokenCall({
        client_id: contract.clientId,
        client_secret: input.credentials.clientSecret,
        grant_type: "refresh_token",
        refresh_token: strictToken(refreshToken, "refresh_token"),
      }, rateLimitOwnerScope),
    listAccounts: async (accessToken: string, rateLimitOwnerScope: string) => {
      const payload = await signedFetch(contract.accountListPath, {
        method: "GET",
        accessToken,
        rateLimitOwnerScope,
      });
      const accounts = input.parseAccounts!(payload);
      if (accounts.length < 1 || accounts.length > 100) {
        throw new Error("invalid_webull_account_count");
      }
      return Object.freeze([...accounts]);
    },
  });
}

export function createBlockedWebullProvider(
  contract: WebullPublicContract,
): WebullAuthorizationProvider {
  const blocked = () => {
    throw new WebullProtocolGateError(
      `${contract.version}:partner_confirmation_required`,
    );
  };
  return Object.freeze({
    authorizationUrl: blocked,
    exchangeAuthorizationCode: async () => blocked(),
    refresh: async () => blocked(),
    listAccounts: async () => blocked(),
  });
}

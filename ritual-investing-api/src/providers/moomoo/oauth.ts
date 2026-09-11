/** Pure, server-only public-client OAuth contract. This module performs no I/O. */
export const MOOMOO_OAUTH_CONTRACT = Object.freeze({
  version: "moomoo-public-oauth-2026-09-05",
  authorizationUrl: "https://webapi.moomoo.com/oauth2/authorize/confirm",
  tokenUrl: "https://webapi.moomoo.com/oauth2/token",
  pendingLifetimeMs: 300_000,
} as const);

export type MoomooClient = Readonly<{
  clientId: string;
  registeredRedirectUri: string;
  /** Local development only; permits exact HTTP loopback callbacks. */
  allowHttpLoopback?: boolean;
}>;

export type MoomooAuthorizationOwner = Readonly<{
  userId: string;
  sessionId: string;
  connectionId: string;
  deletionEpoch: number;
}>;

/** Persist the verifier encrypted, bound to this owner; never expose this record. */
export type PendingMoomooAuthorization = Readonly<{
  contractVersion: typeof MOOMOO_OAUTH_CONTRACT.version;
  client: MoomooClient;
  owner: MoomooAuthorizationOwner;
  stateHash: string;
  codeVerifier: string;
  createdAtMs: number;
  expiresAtMs: number;
}>;

/** Contains credentials in body: server-only, never log or return to a browser. */
export type MoomooTokenRequest = Readonly<{
  url: typeof MOOMOO_OAUTH_CONTRACT.tokenUrl;
  method: "POST";
  headers: Readonly<{ "Content-Type": "application/x-www-form-urlencoded" }>;
  body: string;
  redirect: "error";
  cache: "no-store";
  credentials: "omit";
}>;

export type MoomooTokens = Readonly<{
  accessToken: string;
  refreshToken: string;
  accessExpiresAtMs: number;
  grantedScopes: readonly string[];
}>;

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const encoder = new TextEncoder();

function fail(reason: string): never {
  // Static messages only. Never interpolate provider payloads or credentials.
  throw new Error(reason);
}

function opaque(value: unknown, maxLength = 8_192): value is string {
  return typeof value === "string" && value.length > 0 &&
    value.length <= maxLength && /^[\x21-\x7e]+$/.test(value);
}

function validateOwner(owner: MoomooAuthorizationOwner): void {
  if (!uuidPattern.test(owner.userId) || !uuidPattern.test(owner.sessionId) ||
    !uuidPattern.test(owner.connectionId) ||
    !Number.isSafeInteger(owner.deletionEpoch) || owner.deletionEpoch < 0) {
    fail("invalid_moomoo_authorization_owner");
  }
}

function validateClient(client: MoomooClient): URL {
  if (!opaque(client.clientId, 255)) fail("invalid_moomoo_client");
  let url: URL;
  try {
    url = new URL(client.registeredRedirectUri);
  } catch {
    return fail("invalid_moomoo_callback");
  }
  const loopback = ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname);
  const permittedHttp = client.allowHttpLoopback === true && loopback && url.protocol === "http:";
  if ((!permittedHttp && (url.protocol !== "https:" || url.port !== "")) ||
    url.username !== "" || url.password !== "" || url.search !== "" ||
    url.hash !== "" || url.href !== client.registeredRedirectUri ||
    /%2f|%5c|%2e/i.test(url.pathname)) {
    fail("invalid_moomoo_callback");
  }
  return url;
}

function validTime(value: number): boolean {
  return Number.isSafeInteger(value) && value >= 0 &&
    Number.isFinite(new Date(value).getTime());
}

function base64Url(value: Uint8Array): string {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function stateHash(value: string): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(value)));
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function moomooPkceChallenge(codeVerifier: string): Promise<string> {
  if (!/^[A-Za-z0-9._~-]{43,128}$/.test(codeVerifier)) fail("invalid_moomoo_pkce");
  return base64Url(new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(codeVerifier))));
}

export async function createMoomooAuthorization(
  client: MoomooClient,
  owner: MoomooAuthorizationOwner,
  nowMs: number,
): Promise<Readonly<{ authorizationUrl: string; pending: PendingMoomooAuthorization }>> {
  validateClient(client);
  validateOwner(owner);
  if (!validTime(nowMs) || !validTime(nowMs + MOOMOO_OAUTH_CONTRACT.pendingLifetimeMs)) {
    fail("invalid_moomoo_authorization_time");
  }
  const state = base64Url(crypto.getRandomValues(new Uint8Array(32)));
  const codeVerifier = base64Url(crypto.getRandomValues(new Uint8Array(32)));
  const url = new URL(MOOMOO_OAUTH_CONTRACT.authorizationUrl);
  url.search = new URLSearchParams({
    client_id: client.clientId,
    code_challenge: await moomooPkceChallenge(codeVerifier),
    code_challenge_method: "S256",
    redirect_uri: client.registeredRedirectUri,
    response_type: "code",
    state,
  }).toString();
  return Object.freeze({
    authorizationUrl: url.href,
    pending: Object.freeze({
      contractVersion: MOOMOO_OAUTH_CONTRACT.version,
      client: Object.freeze({ ...client }),
      owner: Object.freeze({ ...owner }),
      stateHash: await stateHash(state),
      codeVerifier,
      createdAtMs: nowMs,
      expiresAtMs: nowMs + MOOMOO_OAUTH_CONTRACT.pendingLifetimeMs,
    }),
  });
}

function tokenRequest(fields: Record<string, string>): MoomooTokenRequest {
  return Object.freeze({
    url: MOOMOO_OAUTH_CONTRACT.tokenUrl,
    method: "POST",
    headers: Object.freeze({ "Content-Type": "application/x-www-form-urlencoded" }),
    body: new URLSearchParams(fields).toString(),
    redirect: "error",
    cache: "no-store",
    credentials: "omit",
  });
}

/**
 * Validates a callback and prepares bytes only. The caller MUST atomically consume
 * the pending record once, verifying active owner/session/deletion epoch, before
 * any exchange. Pure validation alone does not prevent callback replay.
 */
export async function prepareMoomooAuthorizationCodeExchange(input: Readonly<{
  pending: PendingMoomooAuthorization;
  callbackUrl: string;
  currentOwner: MoomooAuthorizationOwner;
  nowMs: number;
}>): Promise<MoomooTokenRequest> {
  const { pending, currentOwner, nowMs } = input;
  const registered = validateClient(pending.client);
  validateOwner(currentOwner);
  validateOwner(pending.owner);
  if (pending.contractVersion !== MOOMOO_OAUTH_CONTRACT.version ||
    !validTime(nowMs) || !validTime(pending.createdAtMs) ||
    pending.expiresAtMs !== pending.createdAtMs + MOOMOO_OAUTH_CONTRACT.pendingLifetimeMs ||
    nowMs < pending.createdAtMs || nowMs >= pending.expiresAtMs ||
    currentOwner.userId !== pending.owner.userId ||
    currentOwner.sessionId !== pending.owner.sessionId ||
    currentOwner.connectionId !== pending.owner.connectionId ||
    currentOwner.deletionEpoch !== pending.owner.deletionEpoch) {
    fail("invalid_moomoo_authorization_binding");
  }
  let callback: URL;
  try {
    callback = new URL(input.callbackUrl);
  } catch {
    return fail("invalid_moomoo_callback");
  }
  if (callback.origin !== registered.origin || callback.pathname !== registered.pathname ||
    callback.username !== "" || callback.password !== "" || callback.hash !== "" ||
    callback.href !== input.callbackUrl) fail("invalid_moomoo_callback");
  const parameters = callback.searchParams;
  const keys = [...parameters.keys()].sort();
  const success = keys.join(",") === "code,state";
  const denial = keys.join(",") === "error,state" || keys.join(",") === "error,error_description,state";
  if (!success && !denial) fail("invalid_moomoo_callback");
  const state = parameters.get("state");
  if (state === null || !/^[A-Za-z0-9_-]{43}$/.test(state) ||
    !/^[a-f0-9]{64}$/.test(pending.stateHash) || await stateHash(state) !== pending.stateHash) {
    fail("invalid_moomoo_authorization_state");
  }
  if (denial) fail("moomoo_authorization_denied");
  const code = parameters.get("code");
  if (!opaque(code, 4_096)) fail("invalid_moomoo_authorization_code");
  await moomooPkceChallenge(pending.codeVerifier);
  return tokenRequest({
    grant_type: "authorization_code",
    code,
    client_id: pending.client.clientId,
    redirect_uri: pending.client.registeredRedirectUri,
    code_verifier: pending.codeVerifier,
  });
}

/** Public client + PKCE only. Confidential client authentication is out of scope. */
export function prepareMoomooRefresh(client: MoomooClient, refreshToken: string): MoomooTokenRequest {
  validateClient(client);
  if (!opaque(refreshToken)) fail("invalid_moomoo_refresh_token");
  return tokenRequest({ grant_type: "refresh_token", refresh_token: refreshToken, client_id: client.clientId });
}

export function normalizeMoomooTokenResponse(
  response: unknown,
  context: Readonly<
    | { grantType: "authorization_code"; receivedAtMs: number }
    | { grantType: "refresh_token"; receivedAtMs: number; previousRefreshToken: string }
  >,
): MoomooTokens {
  if (typeof response !== "object" || response === null || Array.isArray(response)) {
    fail("invalid_moomoo_token_response");
  }
  const payload = response as Record<string, unknown>;
  // The documented refresh example omits token_type; initial exchange requires it.
  const validTokenType = payload.token_type === "Bearer" ||
    (context.grantType === "refresh_token" && payload.token_type === undefined);
  if ("error" in payload || !validTokenType ||
    !opaque(payload.access_token) || typeof payload.expires_in !== "number" ||
    !Number.isSafeInteger(payload.expires_in) || payload.expires_in <= 0 ||
    !validTime(context.receivedAtMs) ||
    typeof payload.scope !== "string" || payload.scope.length > 4_096 ||
    !/^[\x21\x23-\x5b\x5d-\x7e]+(?: [\x21\x23-\x5b\x5d-\x7e]+)*$/.test(payload.scope)) {
    fail("invalid_moomoo_token_response");
  }
  const accessExpiresAtMs = context.receivedAtMs + payload.expires_in * 1_000;
  if (!validTime(accessExpiresAtMs)) fail("invalid_moomoo_token_response");
  let refreshToken: string;
  if (context.grantType === "refresh_token") {
    if (!opaque(context.previousRefreshToken) ||
      (payload.refresh_token !== undefined && payload.refresh_token !== context.previousRefreshToken)) {
      fail("unexpected_moomoo_refresh_rotation");
    }
    refreshToken = context.previousRefreshToken;
  } else {
    if (!opaque(payload.refresh_token)) fail("invalid_moomoo_token_response");
    refreshToken = payload.refresh_token;
  }
  return Object.freeze({
    accessToken: payload.access_token,
    refreshToken,
    accessExpiresAtMs,
    grantedScopes: Object.freeze([...new Set(payload.scope.split(" "))]),
  });
}

import type {
  ConsumedWebullState,
  ProtectedCallbackAccount,
  WithWebullCallbackRepository,
} from "../../../ritual-investing-api/src/domains/brokerage-connections/ports.ts";
import {
  hashWebullOpaqueValue,
  newWebullOpaqueValue,
  webullCompletionLifetimeMilliseconds,
} from "../../../ritual-investing-api/src/domains/brokerage-connections/service.ts";
import type {
  WebullAuthorizationProvider,
  WebullAuthorizedAccount,
} from "../_shared/webull/client.ts";
import {
  normalizeCapability,
} from "../../../ritual-investing-api/src/domains/brokerage-accounts/normalization.ts";
import { normalizedMarketTimezone } from "../../../ritual-investing-api/src/domains/brokerage-assets/normalization.ts";
import { WebullTransientProviderError } from "../_shared/webull/client.ts";
import {
  WEBULL_PUBLIC_CONTRACT_VERSION,
  WebullProtocolGateError,
} from "../_shared/webull/contract.ts";
import type { WebullTokenVault } from "../_shared/webull/tokens.ts";

const callbackHeaders = Object.freeze({
  "cache-control": "no-store, max-age=0",
  pragma: "no-cache",
  "referrer-policy": "no-referrer",
  "x-content-type-options": "nosniff",
  "x-frame-options": "DENY",
  "content-security-policy": "default-src 'none'; frame-ancestors 'none'",
});

type ParsedCallback = Readonly<{
  state: string;
  code?: string;
  providerError?: true;
}>;

function canonicalComponent(raw: string): string {
  if (
    raw.length === 0 ||
    raw.includes("+") ||
    /%(?![0-9A-F]{2})/.test(raw) ||
    /%[0-9a-f][0-9A-Fa-f]|%[0-9A-F][0-9a-f]/.test(raw)
  ) {
    throw new Error("invalid_webull_callback_encoding");
  }
  const decoded = decodeURIComponent(raw);
  const encoded = encodeURIComponent(decoded).replace(
    /[!'()*]/g,
    (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
  );
  if (encoded !== raw) throw new Error("ambiguous_webull_callback_encoding");
  return decoded;
}

export function parseWebullCallback(url: URL): ParsedCallback {
  const raw = url.search.startsWith("?") ? url.search.slice(1) : url.search;
  if (raw.length === 0 || raw.length > 16_384) {
    throw new Error("invalid_webull_callback_query");
  }
  const fields = new Map<string, string>();
  for (const pair of raw.split("&")) {
    const separator = pair.indexOf("=");
    if (separator < 1 || pair.indexOf("=", separator + 1) !== -1) {
      throw new Error("invalid_webull_callback_field");
    }
    const rawName = pair.slice(0, separator);
    if (!/^(state|code|error|error_description)$/.test(rawName)) {
      throw new Error("unknown_webull_callback_field");
    }
    if (fields.has(rawName)) throw new Error("duplicate_webull_callback_field");
    fields.set(rawName, canonicalComponent(pair.slice(separator + 1)));
  }
  const state = fields.get("state");
  if (state === undefined || !/^[A-Za-z0-9_-]{43,128}$/.test(state)) {
    throw new Error("invalid_webull_callback_state");
  }
  const code = fields.get("code");
  const providerError = fields.has("error");
  if ((code === undefined) === !providerError) {
    throw new Error("invalid_webull_callback_outcome");
  }
  if (code !== undefined && !/^[\x21-\x7e]{8,8192}$/.test(code)) {
    throw new Error("invalid_webull_authorization_code");
  }
  if (code !== undefined && fields.has("error_description")) {
    throw new Error("unexpected_webull_error_description");
  }
  if (providerError && fields.get("error")!.length > 256) {
    throw new Error("invalid_webull_provider_error");
  }
  if ((fields.get("error_description")?.length ?? 0) > 1_024) {
    throw new Error("invalid_webull_provider_error_description");
  }
  return Object.freeze({
    state,
    ...(code === undefined ? {} : { code }),
    ...(providerError ? { providerError: true as const } : {}),
  });
}

function returnTargetUrl(
  target: ConsumedWebullState["returnTarget"],
  handle: string,
): URL {
  const value = target === "webull_https"
    ? "https://just-build-this.app/mobile/webull/complete"
    : "com.ritualinvesting.ritual-investing-app.webull://webull/complete";
  const url = new URL(value);
  url.searchParams.set("completion", handle);
  return url;
}

async function hmacIdentifier(
  value: string,
  state: ConsumedWebullState,
  pepper: string,
): Promise<string> {
  if (!/^[\x21-\x7e]{32,512}$/.test(pepper)) {
    throw new Error("invalid_webull_account_pepper");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(pepper),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(
        `${state.userId}\u001f${state.connectionId}\u001f${value}`,
      ),
    ),
  );
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function validateAccount(account: WebullAuthorizedAccount): void {
  if (
    !/^[\x21-\x7e]{1,512}$/.test(account.providerAccountId) ||
    account.displayLabel.length < 1 ||
    account.displayLabel.length > 160 ||
    /[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]/i.test(
      account.displayLabel,
    ) ||
    !/^[A-Z]{3}$/.test(account.baseCurrency) ||
    !["available", "restricted", "closed", "unavailable"].includes(
      account.status,
    ) ||
    !Number.isInteger(account.capabilityVersion) ||
    account.capabilityVersion < 0 ||
    !Number.isSafeInteger(account.capabilityVersion) ||
    !Array.isArray(account.capabilities) ||
    account.capabilities.length > 64
  ) {
    throw new Error("invalid_webull_account");
  }
  normalizedMarketTimezone(account.marketTimezone);
  account.capabilities.forEach(normalizeCapability);
}

function generic(status: 400 | 404 | 503): Response {
  return Response.json(
    {
      error: {
        code: status === 503 ? "temporarily_unavailable" : "invalid_callback",
      },
    },
    { status, headers: callbackHeaders },
  );
}

export function createWebullCallbackHandler(
  input: Readonly<{
    withRepository: WithWebullCallbackRepository;
    provider: WebullAuthorizationProvider;
    providerEnvironment: ConsumedWebullState["environment"];
    tokenVault: WebullTokenVault;
    accountIdPepper: string;
    now?: () => Date;
  }>,
): (request: Request) => Promise<Response> {
  const now = input.now ?? (() => new Date());
  return async (request) => {
    if (request.method !== "GET") return generic(404);
    let parsed: ParsedCallback;
    try {
      parsed = parseWebullCallback(new URL(request.url));
    } catch {
      return generic(400);
    }
    let state: ConsumedWebullState | null;
    try {
      const stateHash = await hashWebullOpaqueValue(parsed.state);
      state = await input.withRepository(
        null,
        (repository) => repository.consumeState(stateHash, now()),
      );
    } catch {
      return generic(503);
    }
    if (
      state === null ||
      state.contractVersion !== WEBULL_PUBLIC_CONTRACT_VERSION ||
      state.environment !== input.providerEnvironment
    ) {
      return generic(400);
    }

    const handle = newWebullOpaqueValue();
    const handleHash = await hashWebullOpaqueValue(handle);
    const expiresAt = new Date(
      now().getTime() + webullCompletionLifetimeMilliseconds,
    );
    const callbackClaims = Object.freeze({
      userId: state.userId,
      sessionId: state.sessionId,
      aal: "aal1" as const,
    });
    if (parsed.providerError === true) {
      try {
        await input.withRepository(
          callbackClaims,
          (repository) =>
            repository.fail(state, "denied", handleHash, expiresAt),
        );
      } catch {
        return generic(503);
      }
      return new Response(null, {
        status: 303,
        headers: {
          ...callbackHeaders,
          location: returnTargetUrl(state.returnTarget, handle).toString(),
        },
      });
    }

    try {
      const ownerScope = await hashWebullOpaqueValue(state.userId);
      const plain = await input.provider.exchangeAuthorizationCode(
        parsed.code!,
        ownerScope,
      );
      const providerAccounts = await input.provider.listAccounts(
        plain.accessToken,
        ownerScope,
      );
      if (providerAccounts.length < 1 || providerAccounts.length > 100) {
        throw new Error("invalid_webull_account_count");
      }
      const protectedCredentials = await input.tokenVault.protectCredentials({
        userId: state.userId,
        connectionId: state.connectionId,
        deletionEpoch: state.deletionEpoch,
        tokenVersion: 1,
        ...plain,
      });
      const accounts: ProtectedCallbackAccount[] = [];
      const accountsFetchedAt = now();
      const accountsExpireAt = new Date(accountsFetchedAt.getTime() + 60_000);
      for (const providerAccount of providerAccounts) {
        validateAccount(providerAccount);
        const id = crypto.randomUUID();
        accounts.push(Object.freeze({
          id,
          displayLabel: providerAccount.displayLabel,
          baseCurrency: providerAccount.baseCurrency,
          status: providerAccount.status,
          capabilityVersion: providerAccount.capabilityVersion,
          marketTimezone: normalizedMarketTimezone(
            providerAccount.marketTimezone,
          ),
          capabilities: Object.freeze(
            providerAccount.capabilities.map(normalizeCapability),
          ),
          fetchedAt: accountsFetchedAt,
          expiresAt: accountsExpireAt,
          providerIdCiphertext: await input.tokenVault
            .protectProviderIdentifier(
              {
                environment: protectedCredentials.environment,
                userId: state.userId,
                connectionId: state.connectionId,
                deletionEpoch: state.deletionEpoch,
              },
              id,
              providerAccount.providerAccountId,
            ),
          providerIdHash: await hmacIdentifier(
            providerAccount.providerAccountId,
            state,
            input.accountIdPepper,
          ),
          keyVersion: protectedCredentials.keyVersion,
          userId: state.userId,
          connectionId: state.connectionId,
          deletionEpoch: state.deletionEpoch,
        }));
      }
      await input.withRepository(
        callbackClaims,
        (repository) =>
          repository.complete(
            state,
            protectedCredentials,
            accounts,
            handleHash,
            expiresAt,
          ),
      );
    } catch (error) {
      const outcome = error instanceof WebullProtocolGateError ||
          error instanceof WebullTransientProviderError
        ? "temporarily_unavailable"
        : "failed";
      try {
        await input.withRepository(
          callbackClaims,
          (repository) =>
            repository.fail(state, outcome, handleHash, expiresAt),
        );
      } catch {
        return generic(503);
      }
    }
    return new Response(null, {
      status: 303,
      headers: {
        ...callbackHeaders,
        location: returnTargetUrl(state.returnTarget, handle).toString(),
      },
    });
  };
}

export const WEBULL_PUBLIC_CONTRACT_VERSION =
  "webull-connect-public-docs-2026-08-28" as const;

export type WebullEnvironment = "sandbox" | "production";

export type WebullPublicContract = Readonly<{
  version: typeof WEBULL_PUBLIC_CONTRACT_VERSION;
  environment: WebullEnvironment;
  authorizationOrigin: "https://passport.webull.com";
  authorizationPath:
    | "/oauth2/sandbox/authenticate/login"
    | "/oauth2/authenticate/login";
  apiOrigin:
    | "https://oauth-open-api.sandbox.webull.com"
    | "https://us-oauth-open-api.webull.com";
  authorizationCodePath: "/oauth2/auth-codes/get";
  tokenPath: "/oauth2/tokens/create";
  authorizationCodeLifetimeSeconds: 60;
  accessTokenLifetimeSeconds: 1_800;
  refreshTokenLifetimeSeconds: 1_296_000;
  aggregateRequestsPerUserPerMinute: 89;
  unresolved: readonly [
    "token_secret_transport",
    "token_content_type",
    "authorization_entrypoint",
    "connect_account_list_path",
    "registered_redirect_uri",
    "approved_scopes",
    "pkce_support",
    "revocation_endpoint",
    "sandbox_entitlement",
    "endpoint_rate_limit_intersection",
  ];
}>;

export type PartnerConfirmedWebullContract = Readonly<{
  publicContract: WebullPublicContract;
  confirmationReference: string;
  confirmedAt: string;
  clientId: string;
  redirectUri: string;
  authorizationScope: string;
  authorizationEntrypoint: "passport_login" | "authorization_code_endpoint";
  tokenSecretTransport: "signed_only" | "x-app-secret";
  tokenContentType: "application/json" | "application/x-www-form-urlencoded";
  accountListPath: string;
  pkce: "unsupported" | "s256";
  revocation: Readonly<
    | { supported: false }
    | { supported: true; path: string; method: "POST" }
  >;
  endpointRequestsPerWindow: Readonly<{
    limit: number;
    windowSeconds: number;
  }>;
}>;

export class WebullProtocolGateError extends Error {
  constructor(readonly reason = "webull_partner_contract_unconfirmed") {
    super(reason);
    this.name = "WebullProtocolGateError";
  }
}

export function publicWebullContract(
  environment: WebullEnvironment,
): WebullPublicContract {
  return Object.freeze({
    version: WEBULL_PUBLIC_CONTRACT_VERSION,
    environment,
    authorizationOrigin: "https://passport.webull.com",
    authorizationPath: environment === "sandbox"
      ? "/oauth2/sandbox/authenticate/login"
      : "/oauth2/authenticate/login",
    apiOrigin: environment === "sandbox"
      ? "https://oauth-open-api.sandbox.webull.com"
      : "https://us-oauth-open-api.webull.com",
    authorizationCodePath: "/oauth2/auth-codes/get",
    tokenPath: "/oauth2/tokens/create",
    authorizationCodeLifetimeSeconds: 60,
    accessTokenLifetimeSeconds: 1_800,
    refreshTokenLifetimeSeconds: 1_296_000,
    // The public Connect overview says fewer than 90 calls per user/minute.
    // 89 is the strict literal upper bound; endpoint limits are intersected
    // only after their Connect paths are partner-confirmed.
    aggregateRequestsPerUserPerMinute: 89,
    unresolved: [
      "token_secret_transport",
      "token_content_type",
      "authorization_entrypoint",
      "connect_account_list_path",
      "registered_redirect_uri",
      "approved_scopes",
      "pkce_support",
      "revocation_endpoint",
      "sandbox_entitlement",
      "endpoint_rate_limit_intersection",
    ] as const,
  });
}

function exactHttpsUrl(value: string): URL {
  const url = new URL(value);
  if (
    url.protocol !== "https:" ||
    url.username !== "" ||
    url.password !== "" ||
    url.port !== "" ||
    url.hash !== "" ||
    url.search !== ""
  ) {
    throw new WebullProtocolGateError("invalid_partner_redirect_uri");
  }
  return url;
}

export function assertPartnerConfirmedContract(
  contract: PartnerConfirmedWebullContract | WebullPublicContract,
): asserts contract is PartnerConfirmedWebullContract {
  if (!("confirmationReference" in contract)) {
    throw new WebullProtocolGateError();
  }
  if (
    !/^[A-Za-z0-9][A-Za-z0-9._:/-]{7,255}$/.test(
      contract.confirmationReference,
    ) ||
    !Number.isFinite(Date.parse(contract.confirmedAt)) ||
    !/^[A-Za-z0-9._~-]{8,255}$/.test(contract.clientId) ||
    !/^[\x21-\x7e]{1,512}$/.test(contract.authorizationScope) ||
    Date.parse(contract.confirmedAt) > Date.now() + 300_000 ||
    !Number.isInteger(contract.endpointRequestsPerWindow.limit) ||
    !Number.isInteger(contract.endpointRequestsPerWindow.windowSeconds) ||
    contract.endpointRequestsPerWindow.limit < 1 ||
    contract.endpointRequestsPerWindow.windowSeconds < 1
  ) {
    throw new WebullProtocolGateError("invalid_partner_confirmation");
  }
  exactHttpsUrl(contract.redirectUri);
  const path = contract.accountListPath;
  if (
    !path.startsWith("/") ||
    path.startsWith("//") ||
    path.includes("..") ||
    path.includes("\\") ||
    path.includes(":") ||
    path.includes("?") ||
    path.includes("#")
  ) {
    throw new WebullProtocolGateError("invalid_partner_account_path");
  }
}

export function parsePartnerConfirmedContractFromEnvironment(
  read: (name: string) => string | undefined,
): PartnerConfirmedWebullContract | WebullPublicContract {
  const environmentValue = read("WEBULL_ENVIRONMENT") ?? "sandbox";
  if (!["sandbox", "production"].includes(environmentValue)) {
    throw new WebullProtocolGateError("invalid_webull_environment");
  }
  const environment = environmentValue as WebullEnvironment;
  const publicContract = publicWebullContract(environment);
  if (read("WEBULL_CONTRACT_STATUS") !== "partner_confirmed") {
    return publicContract;
  }

  const confirmationReference = read("WEBULL_CONFIRMATION_REFERENCE")?.trim();
  const confirmedAt = read("WEBULL_CONFIRMED_AT")?.trim();
  const clientId = read("WEBULL_CLIENT_ID")?.trim();
  const redirectUri = read("WEBULL_REDIRECT_URI")?.trim();
  const authorizationScope = read("WEBULL_AUTHORIZATION_SCOPE")?.trim();
  const tokenSecretTransport = read("WEBULL_TOKEN_SECRET_TRANSPORT");
  const tokenContentType = read("WEBULL_TOKEN_CONTENT_TYPE");
  const authorizationEntrypoint = read("WEBULL_AUTHORIZATION_ENTRYPOINT");
  const accountListPath = read("WEBULL_ACCOUNT_LIST_PATH")?.trim();
  const pkce = read("WEBULL_PKCE");
  const revocation = read("WEBULL_REVOCATION");
  const endpointLimit = Number(read("WEBULL_ACCOUNT_LIST_LIMIT"));
  const endpointWindow = Number(read("WEBULL_ACCOUNT_LIST_WINDOW_SECONDS"));

  if (
    confirmationReference === undefined ||
    confirmedAt === undefined ||
    clientId === undefined ||
    redirectUri === undefined ||
    authorizationScope === undefined ||
    accountListPath === undefined ||
    !["signed_only", "x-app-secret"].includes(tokenSecretTransport ?? "") ||
    !["application/json", "application/x-www-form-urlencoded"].includes(
      tokenContentType ?? "",
    ) ||
    !["passport_login", "authorization_code_endpoint"].includes(
      authorizationEntrypoint ?? "",
    ) ||
    !["unsupported", "s256"].includes(pkce ?? "") ||
    !["unsupported"].includes(revocation ?? "")
  ) {
    throw new WebullProtocolGateError("incomplete_partner_confirmation");
  }

  const contract: PartnerConfirmedWebullContract = Object.freeze({
    publicContract,
    confirmationReference,
    confirmedAt,
    clientId,
    redirectUri,
    authorizationScope,
    authorizationEntrypoint: authorizationEntrypoint as
      | "passport_login"
      | "authorization_code_endpoint",
    tokenSecretTransport: tokenSecretTransport as
      | "signed_only"
      | "x-app-secret",
    tokenContentType: tokenContentType as
      | "application/json"
      | "application/x-www-form-urlencoded",
    accountListPath,
    pkce: pkce as "unsupported" | "s256",
    revocation: { supported: false as const },
    endpointRequestsPerWindow: {
      limit: endpointLimit,
      windowSeconds: endpointWindow,
    },
  });
  assertPartnerConfirmedContract(contract);
  return contract;
}

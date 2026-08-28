# Webull Connect contract gate

Status: **blocked for real egress**  
Recorded: 2026-08-28  
Code contract: `webull-connect-public-docs-2026-08-28`

Argus implements the Webull connection lifecycle against sanitized fixtures,
but it does not send a real Webull request yet. Public Webull documentation is
not partner approval, and the current pages conflict on security-relevant
details. `WEBULL_CONTRACT_STATUS=partner_confirmed` must not be set until every
item in the promotion checklist has written Webull confirmation and a hosted
sandbox fixture.

## Public facts frozen in code

The current official Webull pages establish these facts:

- Connect is the OAuth 2.0 integration for a third-party platform acting for an
  existing Webull customer.
- Sandbox login is on `https://passport.webull.com` at
  `/oauth2/sandbox/authenticate/login`; production uses the same origin at
  `/oauth2/authenticate/login`.
- Sandbox API traffic uses `https://oauth-open-api.sandbox.webull.com`;
  production uses `https://us-oauth-open-api.webull.com`.
- The authorization-code reference names `GET /oauth2/auth-codes/get`. The
  callback contains `code` and `state`, and the registered redirect URI must
  match exactly. Authorization codes are one use and expire after 60 seconds.
- The token reference names `POST /oauth2/tokens/create`. Access tokens last 30
  minutes. Refresh tokens last 15 days and rotate on refresh.
- Connect API calls use bearer access tokens. The public Connect guide currently
  shows account enumeration at `GET /oauth-openapi/account/list`.
- The signature guide signs the exact path, query, selected headers, and the
  uppercase MD5 of the exact body bytes with HMAC-SHA1. Its published worked
  fixture produces `kvlS6opdZDhEBo5jq40nHYXaLvM=`.
- The Connect overview states fewer than 90 requests per individual user per
  minute. The separate rate-limit page describes per-user, per-endpoint limits
  and HTTP 429 behavior.

Sources:

- [About Connect API](https://developer.webull.com/apis/docs/connect-api/about-connect-api/)
- [OAuth integration guide](https://developer.webull.com/apis/docs/connect-api/authentication/)
- [Signature](https://developer.webull.com/apis/docs/authentication/signature/)
- [Rate limits](https://developer.webull.com/apis/docs/rate-limits/)
- [Change logs](https://developer.webull.com/apis/docs/changelog/)

These values are allowlisted constants, not remotely supplied URLs. Provider
redirects are disabled. The app secret, client secret, provider tokens, raw
account IDs, authorization codes, and raw responses never enter client code,
logs, analytics, queue messages, or exposed schemas.

## Conflicts and unknowns that block egress

| Gate | Current evidence | Required resolution |
|---|---|---|
| Authorization entrypoint | The overview publishes a passport H5 path; the authorization-code reference publishes `/oauth2/auth-codes/get`. The public docs do not unambiguously say which Argus constructs first. | Webull confirms the exact sandbox and production browser URL, method, query serialization, and redirect sequence. |
| Token secret transport | The OAuth/reference material marks `x-app-secret` required, while the signature guide says `app_secret` is never sent and is used only for signing. | Webull confirms whether the app secret is signing-only or also a header. `client_secret` remains a distinct OAuth credential. |
| Token body and signing | The token reference uses `application/x-www-form-urlencoded`; the signature guide says POST requests use `application/json`. | Webull confirms exact content type, field encoding, signing input, and exact bytes sent. |
| Account list path | The Connect guide shows `/oauth-openapi/account/list`; the current rate-limit/reference material names `/trading/accounts/list`. | Webull confirms the Connect path/version and provides a sanitized response fixture. |
| Scopes | Scopes are assigned during partner registration, but Argus has no approved value. | Record the exact assigned scope string; do not combine or infer scopes. |
| PKCE | No current official Connect page located by this review documents `code_challenge` or `code_verifier`. | Webull confirms whether PKCE is supported and, if so, exact S256 fields. Absence in public docs is not treated as unsupported. |
| Revocation | No current official Connect page located by this review publishes a revocation endpoint. | Webull confirms endpoint and semantics, or confirms that only local credential destruction is available. Argus never claims to revoke the provider grant without this. |
| Redirects/IPs | Registered callback and network allowlisting details are partner-specific. | Confirm exact redirect, environment registration, outbound IP rules, TLS, and redirect behavior. |
| Rate limits | The aggregate statement and endpoint table use different dimensions; the published account path also conflicts. | Confirm the Connect endpoint bucket and apply the stricter intersection with 89/user/minute. |
| Sandbox capabilities | Public feature lists are broader than Argus's approved product subset. | Hosted sandbox evidence must enumerate approved accounts and later the exact read/manual-order capability matrix. |

## Promotion checklist

Promotion requires a reviewed config and fixture change, not only secrets:

1. Record a Webull confirmation reference and non-future confirmation time.
2. Select `sandbox` or `production`; unknown environments fail closed.
3. Record the exact authorization entrypoint, client ID, exact registered HTTPS
   redirect URI, and exact assigned scope string.
4. Resolve token secret transport and token content type/signing conflicts.
5. Pin the confirmed account-list path, exact endpoint bucket, and a sanitized
   versioned request/response fixture with no identifier or credential from a
   real user.
6. Record PKCE, revocation, redirect, IP, and sandbox capability answers.
7. Reproduce the Webull signing fixture and prove that the body bytes hashed are
   the body bytes sent.
8. Pass hosted sandbox connection, account enumeration, rotation, reconnect,
   disconnect, callback replay, wrong-session completion, redaction, and 429
   tests against the serialized development project.

Until all eight pass, `createBlockedWebullProvider` throws before authorization
state is persisted or network egress begins. Callback attempts that reach the
function with a valid pre-existing fixture state end in a generic
`temporarily_unavailable` completion.

## Argus callback and custody contract

- Start stores only `SHA-256(state)` with the verified Supabase user, session,
  deletion epoch, pending connection, five-minute expiry, contract version, and
  the `webull_https` or `webull_native` return-target enum. A new attempt consumes
  earlier pending state.
- The public Edge callback accepts one canonical query representation: exactly
  `state` plus `code`, or `state` plus `error` and optional bounded
  `error_description`. Duplicate/unknown fields, noncanonical percent encoding,
  alternate outcomes, and replay fail generically.
- State consumption is a narrow, fixed-search-path private database function.
  It atomically checks expiry, active deletion epoch, pending ownership, and
  one-use status. Anon/authenticated roles cannot execute it or access its table.
- Tokens use AES-256-GCM envelope encryption. A versioned master key wraps a
  random per-credential data key. AEAD associated data binds environment, user,
  connection, deletion epoch, token version, key version, and token purpose.
- Provider account IDs are encrypted with account-resource-bound AEAD and their
  lookup hashes are HMAC-bound to the Argus user and connection.
- Completion handles are high entropy and stored only as SHA-256 hashes. They
  expire after five minutes, are one use, and redeem only for the original
  verified Supabase user and session.
- Refresh acquires a 30-second database lease against the expected token
  version and persists rotation with compare-and-swap. A lost response or
  rejected/expired refresh moves the connection to reauthorization-required;
  the adapter never retries a token rotation blindly.
- Disconnect consumes an action-bound, user/session-bound server-issued step-up
  receipt, deletes local tokens, account mappings, refresh leases, accounts and
  projections, and reports `provider_grant_revoked: false` until revocation is
  confirmed.

# Ritual Investing Auth0 setup

## Applications and APIs

Create separate Auth0 applications for the Flutter mobile client and Flutter Web staff dashboard. Never reuse either client ID for the other audience.

- Mobile: native application, Authorization Code + PKCE, exact Android/iOS callback and logout URLs from the application manifests, refresh-token rotation enabled, no client secret.
- Admin: regular web/SPA application for the staff hostname, exact HTTPS callback/logout/origin allowlists, MFA required, and only the admin client ID accepted by the API.
- API: one explicit audience. Member tokens receive `read:self`, `write:self`, `simulate:self`, and `privacy:self`; route middleware still requires only the least privilege declared in OpenAPI. Staff permissions use the `admin:*` allowlist in OpenAPI.

## Recent-authentication claim

Sensitive privacy routes require the credential authentication event to be no more than five minutes old. Token issuance time (`iat`) is not sufficient because a refresh token can mint a new access token without a new credential challenge.

Configure a post-login Auth0 Action to copy the transaction's credential authentication time into the namespaced numeric access-token claim `https://ritual-investing.app/authenticated_at`. Step-up login must use `prompt=login` or `max_age=300` and return a token containing a refreshed claim. The API fails closed when the claim is absent, in the future, or older than five minutes. The standard OIDC `auth_time` claim is accepted as a compatibility fallback, but the namespaced Action claim is the production contract.

Cloudflare Access is an independent staff factor. The API requires both a valid Access assertion and an Auth0 staff token, then resolves an active staff mapping and revocation epoch. Neither identity may substitute for the other.

## Rotation and verification

1. Add the new signing key and wait for JWKS propagation.
2. Exercise anonymous, wrong audience, wrong `azp`, expired, revoked, missing-permission, and allowed-role cases in staging.
3. Rotate application credentials only through the environment secret store. Do not place tokens or subjects in CI output, telemetry, screenshots, or evidence files.
4. Remove the old key only after the maximum token lifetime and cache window have elapsed.

Monitor `auth0.available` and `http.authorization_denial_ratio`. On an outage, do not bypass verification. Existing authenticated operations fail closed; public allowlisted projections remain independent. See [Cloudflare operations](cloudflare-runbook.md) for kill switches and alert response.

## Promotion evidence

Record only application names, audience, callback hostname checks, permission-matrix results, MFA policy status, JWKS key IDs, and timestamps in the [staging evidence template](staging-evidence-template.md). Never record client secrets, access assertions, bearer tokens, raw Auth0 subjects, or member data.

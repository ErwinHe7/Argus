# Ritual Investing Auth0 setup

## Applications and APIs

Create separate Auth0 applications for the Flutter mobile client and Flutter Web staff dashboard. Never reuse either client ID for the other audience.

- Mobile: native application, Authorization Code + PKCE, exact Android/iOS callback and logout URLs from the application manifests, refresh-token rotation enabled, no client secret.
- Admin: regular web/SPA application for the staff hostname, exact HTTPS callback/logout/origin allowlists, MFA required, and only the admin client ID accepted by the API.
- API: one explicit audience. Member tokens receive only `read:self` and `write:self`. Staff permissions use the `admin:*` allowlist in OpenAPI.

Cloudflare Access is an independent staff factor. The API requires both a valid Access assertion and an Auth0 staff token, then resolves an active staff mapping and revocation epoch. Neither identity may substitute for the other.

## Rotation and verification

1. Add the new signing key and wait for JWKS propagation.
2. Exercise anonymous, wrong audience, wrong `azp`, expired, revoked, missing-permission, and allowed-role cases in staging.
3. Rotate application credentials only through the environment secret store. Do not place tokens or subjects in CI output, telemetry, screenshots, or evidence files.
4. Remove the old key only after the maximum token lifetime and cache window have elapsed.

Monitor `auth0.available` and `http.authorization_denial_ratio`. On an outage, do not bypass verification. Existing authenticated operations fail closed; public allowlisted projections remain independent. See [Cloudflare operations](cloudflare-runbook.md) for kill switches and alert response.

## Promotion evidence

Record only application names, audience, callback hostname checks, permission-matrix results, MFA policy status, JWKS key IDs, and timestamps in the [staging evidence template](staging-evidence-template.md). Never record client secrets, access assertions, bearer tokens, raw Auth0 subjects, or member data.

# Ritual Investing Auth0 setup

## Applications and APIs

Create separate Auth0 applications for the Flutter mobile client and Flutter Web staff dashboard. Never reuse either client ID for the other audience.

- Mobile: native application, Authorization Code + PKCE, exact Android/iOS callback and logout URLs from the application manifests, refresh-token rotation enabled, no client secret.
- Admin: regular web/SPA application for the staff hostname, exact HTTPS callback/logout/origin allowlists, MFA required, and only the admin client ID accepted by the API.
- API: one explicit audience. Member tokens receive `read:self`, `write:self`, `simulate:self`, and `privacy:self`; route middleware still requires only the least privilege declared in OpenAPI. Staff permissions use the `admin:*` allowlist in OpenAPI.

## Member client identity

Every member access token must contain an `azp` equal to an explicitly
allowlisted native application client ID in `AUTH0_MEMBER_CLIENT_IDS`. The API
checks that authorized party on bootstrap and every protected member route.
Missing `azp`, a staff client ID, or an old client ID outside a declared
compatibility window fails closed. The Flutter repository exposes the configured
member client expectation without leaking Auth0 SDK types into navigation or
feature code.

When rotating the native application, temporarily list the old and new member
client IDs only for the migration window. Build the candidate with the new
`AUTH0_CLIENT_ID`, prove its access token has the new `azp`, and remove the old
ID after released-client drain and logout/recovery checks. Never add the admin
client ID to the member allowlist.

## HTTPS callback migration and rollback

The app defaults to Auth0's verified HTTPS callback mode. Android declares an
auto-verified link at
`https://<domain>/android/<application-id>/callback`; iOS uses the Auth0 domain
associated-domain entitlement and the corresponding
`https://<domain>/ios/<bundle-id>/callback`. Register the exact callback and
logout URLs in the matching native Auth0 application and configure the required
Android asset-link and Apple association files before enabling the candidate.

Migration procedure:

1. Keep the existing custom-scheme callback/logout URLs registered while adding
   the HTTPS URLs and association files. Do not reuse the staff application.
2. Build with `AUTH0_USE_HTTPS=true`, the target domain, audience, and native
   client ID. On real iOS and Android devices, prove sign-up, sign-in,
   cancellation, process recovery, recent-auth, logout, and verified-link return.
3. Confirm the API observes the expected member `azp`, then monitor callback and
   authorization-denial failures through the compatibility window.
4. Remove the custom-scheme URLs only after the supported-device cohort and
   rollback evidence are accepted.

For rollback, restore the last verified build with `AUTH0_USE_HTTPS=false`; pass
the bundle/application ID as Android `auth0Scheme` and retain the iOS bundle URL
scheme. Restore only the exact custom-scheme callback/logout allowlist. Rolling
back the callback must not broaden `AUTH0_MEMBER_CLIENT_IDS`, weaken PKCE, or
skip server bootstrap. A simulator build or loopback auth harness is not hosted
Auth0 proof; the real-device checklist in
[Member release gates](member-release-gates.md) remains mandatory.

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

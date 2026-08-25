# Ritual Investing API consumer guide

## Contract and version support

OpenAPI is canonical; the Dart package is generated and carries `.ritual-contract.json` with the exact OpenAPI digest. Do not hand-edit generated files. Unknown response enum values must degrade safely in clients; request schemas remain strict.

The mobile release manifest at `ritual-investing-api/compatibility/mobile-client-n-minus-1.json` defines the released N-1 client, structural request/response fingerprints, and operations it uses. A server release must retain those fingerprints for at least 90 days. Contract retirement additionally requires N at 99% adoption, 14 consecutive days with zero N-1 traffic, and the 30-day maximum refresh-token drain. Only then may a marked contract migration remove old behavior. Emergency security revocation may shorten the window, with a forced-upgrade release and incident record.

## Request rules

- Use Auth0 Authorization Code + PKCE and send the API audience token as `Bearer` authorization.
- Generate a new idempotency key for each intentional mutation; retain it across transport retries. A later intentional command needs a new key.
- Send `If-Match` on versioned mutations and handle `409` by refreshing and reconciling user intent.
- Treat cursors as opaque, bounded, signed, and filter-specific.
- Money uses integer minor units; quantities use the documented decimal string/scale contract. Never use floating point for financial state.
- Respect `429 Retry-After`. Retry only responses marked retryable, with bounded jittered backoff.
- Do not infer resource existence from `403`/`404`; tenant resources intentionally return nonenumerating errors.

Member/admin responses are `private, no-store`. Public projections may return `ETag` and support conditional GET. Never persist access tokens, export download tokens, push tokens, raw error bodies, or staff assertions in application logs.

Member onboarding answers are presentation/default inputs, not authorization.
The API remains authoritative for onboarding completion, tenant scope, version
checks, idempotency, and confirmed Demo commands. See the
[member data inventory](member-data-inventory.md) for the sensitive-field,
consent, retention, export, and deletion contract.

## Provider-free runtime boundary

The member app may call only the configured Ritual API and Auth0. It has no
banking, brokerage, payment, market-data, purchase, push-delivery, or media
provider SDK. API runtime network effects are limited to reviewed entry points
and disabled internal provider seams. Run both provider-boundary scripts for
every dependency, URL, Worker effect, or runtime configuration change.

In-app notifications are database records delivered through the Ritual API.
They need no push provider, device push token, or token-encryption binding.
External delivery stays disabled independently from notification writing. See
[Member release gates](member-release-gates.md) for the per-capability readiness
and rollback checklist.

## Release checks

Run `npm run openapi:check`, `npm run drift:check`, the mobile compatibility
test, generated Dart analyze/test, mobile analyze/test, generated-Dio member
integration, Android/iOS builds, and the provider-boundary checks. A contract
edit is incomplete unless OpenAPI and generated client change together and N-1
compatibility still passes. Hosted Auth0 and beta processors remain separate
environment gates; CI does not claim them.

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

## Release checks

Run `npm run openapi:check`, `npm run drift:check`, the mobile compatibility test, generated Dart analyze/test, mobile analyze/test, and Android/iOS builds. A contract edit is incomplete unless OpenAPI and generated client change together and N-1 compatibility still passes.

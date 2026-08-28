# Ritual Investing API consumer guide

## Contract and version support

OpenAPI is canonical; the Dart package is generated and carries
`.ritual-contract.json` with the exact OpenAPI digest. Do not hand-edit generated
files. Unknown response enum values must degrade safely in clients; request
schemas remain strict. A release must run the OpenAPI and generated-client drift
checks together.

## Request rules

- Use Supabase Auth Authorization Code + PKCE and send the authenticated access
  token as `Bearer` authorization.
- Generate a new idempotency key for each intentional mutation; retain it across transport retries. A later intentional command needs a new key.
- Send `If-Match` on versioned mutations and handle `409` by refreshing and reconciling user intent.
- Treat cursors as opaque, bounded, signed, and filter-specific.
- Money uses integer minor units; quantities use the documented decimal string/scale contract. Never use floating point for financial state.
- Respect `429 Retry-After`. Retry only responses marked retryable, with bounded jittered backoff.
- Do not infer resource existence from `403`/`404`; tenant resources intentionally return nonenumerating errors.

Member/admin responses are `private, no-store`. Public projections may return `ETag` and support conditional GET. Never persist access tokens, export download tokens, push tokens, raw error bodies, or staff assertions in application logs.

Member onboarding answers are presentation/default inputs, not authorization.
The API remains authoritative for onboarding completion, owner scope, version
checks, idempotency, and capability-gated brokerage commands. See the
[member data inventory](member-data-inventory.md) for the sensitive-field,
consent, retention, export, and deletion contract.

## Provider boundary

The member app may call only Supabase Auth, approved private Supabase Storage,
and the configured Supabase Edge API. It has no
banking, brokerage, payment, market-data, purchase, push-delivery, or media
provider SDK and never contacts Webull directly. Edge runtime network effects
are limited to reviewed entry points and disabled provider seams. Run both
provider-boundary scripts for every dependency, URL, effect, or runtime
configuration change.

In-app notifications are database records delivered through the Ritual API.
They need no push provider, device push token, or token-encryption binding.
External delivery stays disabled independently from notification writing. See
[Member release gates](member-release-gates.md) for the per-capability readiness
and rollback checklist.

## Release checks

Run `npm run openapi:check`, `npm run drift:check`, generated Dart
analyze/test, mobile analyze/test, generated-Dio member integration,
Android/iOS builds, and the provider-boundary checks. A contract edit is
incomplete unless OpenAPI and generated client change together. Hosted
Supabase Auth and worker acceptance remain separate environment gates; local CI
does not claim them.

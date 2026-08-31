# `just-build-this.app` static site, Demo, and waitlist runbook

Status date: 2026-08-28

Cloudflare Pages publishes landing and Demo static assets only. It has no
Functions directory, `_worker.js`, Worker route, service binding, Queue
binding, KV namespace, R2 bucket, D1 database, scheduled handler, or backend
secret. Custom domains and the `www` canonical redirect are configured in the
Pages/DNS control plane and verified after deployment.

The public waitlist is a separate Supabase Edge Function. Cloudflare Pages
never proxies, computes, stores, or logs a waitlist request. The browser sends
the reviewed JSON request directly to the exact injected function endpoint.

## Fail-closed activation

Pages previews and ordinary repository builds have no endpoint or Turnstile
site key injected. Their form remains visibly disabled. A release build must
provide all four public values together:

- `TURNSTILE_SITE_KEY_PROD`
- `TURNSTILE_SITE_KEY_STAGING`
- `WAITLIST_FUNCTION_URL_PROD`
- `WAITLIST_FUNCTION_URL_STAGING`

Each URL must be the exact HTTPS Supabase Edge Function path
`/functions/v1/waitlist`; query strings, fragments, credentials, alternate
hosts, and alternate paths fail assembly. `assets:build:release` fails if any
of the four values is missing. The generated landing CSP adds only that exact
function origin to `connect-src` and `form-action`.

The Supabase function remains `WAITLIST_SUBMISSIONS=off` until the environment
has all of the following secrets and reviewed public configuration:

- `WAITLIST_ALLOWED_ORIGIN`, equal to the exact landing origin;
- `TURNSTILE_EXPECTED_HOSTNAME`, equal to that origin's hostname;
- `TURNSTILE_SECRET` and a matching host-scoped widget/action `waitlist`;
- `WAITLIST_SOURCE_HMAC_KEY`, 32–128 bytes, stored only as an Edge secret; and
- `SUPABASE_DB_URL`, using the dedicated non-inheriting `argus_waitlist_edge` pooler
  login rather than an owner or Data API credential.

Do not inject a Supabase key, database URL, Turnstile secret, HMAC key, Webull
credential, Auth token, or member API URL into Pages. The function accepts only
the exact landing origin, exact JSON fields, current consent notice, a bounded
body, a platform source address, and a successful server-side Turnstile proof.
Source and route rate keys are HMAC pseudonyms; raw addresses are never stored
or logged. Duplicate and first-time submissions both return the same generic
`202 accepted` response.

Dependency timeout, malformed configuration, rate-state failure, Turnstile
outage, and database failure return fixed non-enumerating responses. Do not log
request bodies, email addresses, raw source addresses, tokens, secrets, or
database errors. Real Webull egress remains fail-closed and is unrelated to
this public function.

## Build and verify

Build the provider-neutral Demo first, then assemble all Pages artifacts:

```sh
cd ritual-investing-demo
flutter build web --release --no-web-resources-cdn --no-source-maps \
  --no-wasm-dry-run --pwa-strategy=none

cd ../ritual-investing-site
npm ci
npm run typecheck
npm test
npm run assets:build
npm run test:browser
```

For a release build, inject the four public values above and run
`npm run assets:build:release`. Inspect every `dist/*/asset-manifest.json` and
require no `_worker.js`, root `functions`, `_routes.json`, source map, backend
binding, Neon identifier, Auth0 identifier, secret-shaped Supabase value, or
Webull credential. The Demo artifact must contain no Supabase or waitlist
endpoint at all.

From `supabase/functions/waitlist`, run `deno task check` and `deno task test`.
Apply the reviewed Supabase migration and pgTAP suite before enabling traffic.
The migration stores only normalized email, accepted notice version, and the
database submission timestamp. Supabase Cron calls the database-owned purge at
`17 4 * * *`; the cutoff is 23 months 29 days so no active row reaches the
published 24-month limit.

## Deploy and promote

Deploy the four `dist` directories to their matching Pages projects. Pages
preview deployments must use the default disabled artifact. Promote staging
Demo, staging landing, production Demo, and production landing in that order. Custom
domain setup must preserve:

- `staging.just-build-this.app` and `demo-staging.just-build-this.app`;
- `just-build-this.app` and `demo.just-build-this.app`; and
- `www.just-build-this.app` as an exact `308` redirect to the apex path/query.

After each promotion, verify static unknown-route behavior, security headers,
no cookies, pairwise iframe CSP, no service worker, and no unexpected network
request. A fresh Demo session may use memory only and must not contact
Supabase, Webull, Auth0, Neon, or Cloudflare compute.

Enable staging writes first. Prove trusted-origin success and duplicate parity,
then prove foreign origin, stale notice, missing consent, invalid Turnstile,
rate breach, and database failure. Inspect only aggregate provider evidence.
If any response reveals an address or dependency detail, or any rejected case
creates a row, set `WAITLIST_SUBMISSIONS=off` immediately.

The privacy contact remains `privacy@just-build-this.app`. Verify mailbox
possession before any removal operation. Until the reviewed Supabase removal
procedure is separately activated, keep submissions off rather than manually
editing rows.

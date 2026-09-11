# Strategy API hosted deployment — 2026-09-10 ET

The isolated paper-strategy control plane is deployed to the existing **Leo
Investing** project, `katwbobjiyzipqlzarus` (us-east-1). The CLI's existing
credential-store session provided access. No account password or privileged key
was added to source, the client or receipts. The separately connected Supabase
MCP account listed a different project and was not used for mutations.

## Applied changes

- Applied only `20260908003020_strategy_lab_control_plane.sql`. The dry run listed
  this one migration. Retained identity, lifecycle, trusted context, rate-limit
  tables and restricted `argus_edge` login were present beforehand. No seed,
  role replacement, unrelated migration or vault update was applied.
- Deployed only `strategy-api`, version **1**, artifact SHA-256
  `2eb9c9cb5b67fe8623f0a3e169dd6ed1e298b83e6a2aead6dacb7008debfed3f`.
  Gateway JWT verification remains disabled for its custom device credentials;
  member requests retain explicit JWT and live membership/session verification.
- Configured the strategy-only exact origin list as
  `https://leoinvesting.com,https://leo.axio7.workers.dev`. Wildcards, sibling
  hosts, arbitrary ports and paths are rejected.
- Added Auth redirects `https://leoinvesting.com/strategy-auth/callback` and
  `https://leo.axio7.workers.dev/strategy-auth/callback`. Preserved
  `https://leoinvesting.com/mobile/argus-auth/callback`, the existing site URL,
  Google provider, MFA and other settings. A minimal isolated config declared
  only redirects; post-push comparison found zero unapplied declared changes.

Retained `api` and `worker` code was not replaced. Their hashes remain
`fe36456921d80d8ea11cc501bf28c9f2cff681d44dfdbfc91d91df749180f446` and
`a3ed1dffe714d8288c9249d0cf4798bd8592c802c51f3dcf5884bbbbbc384611`.
After project secret configuration, Supabase reported versions 4 and 3, while
their artifact hashes and code-update timestamps remained unchanged.

## Verification

- `npm exec -- vitest run test/strategy-lab/control-plane.test.ts test/strategy-lab/origins.test.ts`
  in `ritual-investing-api`: **19 tests passed**. API TypeScript and pinned Deno
  2.5.6 entrypoint checks passed.
- Hosted catalog **200**, MR-v1/MOM-v1, dry-run/paper, `liveExecution:false`.
  This also exercised the restricted database rate limiter.
- Both exact strategy-origin preflights **204**. Attacker-suffixed origin **403**
  with no CORS allow-origin. Status without a session or with an invalid token
  **401**.
- Hosted SQL: RLS enabled and forced; zero strategy records; no direct
  anon/authenticated SELECT; member scoped access retained. Pairing function
  executable by `argus_edge`, not `anon`.
- Auth reports Google enabled, anonymous sign-in disabled. PKCE authorization
  requests for both callbacks returned **302** to `accounts.google.com`.
  This verifies initiation, not completion of Google sign-in.
- Retained member API exclusive origin policy unchanged: leoinvesting.com
  preflight **204**, Worker-origin preflight **403**. The strategy allowlist does
  not widen that member API. Retained website strategy callback **200**.
- Hosted security advisors: no database errors; existing Auth warning
  `auth_leaked_password_protection` retained without unrelated policy changes.

CLI **2.117.0**, Node **22.20.0**. Current Supabase changelog and redirect docs
were checked. The listed self-hosted SAML change does not affect this hosted
Google OAuth configuration.

## Remaining acceptance

No real user was created or impersonated for verification. A complete Google
sign-in, resulting server-verified member workspace, device pairing and
broker-backed paper lifecycle remain for actual-user acceptance. Passing local
owner/session/lease tests does not establish those hosted workflow results.

An enabled client configuration candidate with only a publishable key is in
`release-work/leo-supabase-strategy-20260910/strategy-config.candidate.json`.
It enables sign-in/client controls; it does not create or resume a mandate, pair
a device, install OpenD or enable real-money execution. No supervisor provider
credential or paid fallback was configured. Static-overlay publication is owned
by the website release. This receipt does not claim DNS/TLS deployment, signed
connector distribution, historical-data entitlement or a broker paper cycle.

Do not drop strategy tables or erase connector journals as a web rollback.
Preserve control routes for existing mandates and use acknowledged pause/retire
plus local reconciliation. A static rollback is not a broker stop. Real-money
and options execution remain unavailable.

References: [Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls),
[Supabase CLI](https://supabase.com/docs/reference/cli/introduction).

# Google sign-in and welcome page

Published on September 11, 2026 to
[the Leo welcome page](https://leo.axio7.workers.dev/#/welcome), Worker version
`f0bcd54a-b873-4524-94ed-4d13a6d1c5ca`. All 12 production HTTP checks passed;
the live Google action reached the provider's account chooser with the expected
callback and email/profile scopes. No account was selected or consent completed
during that check. The custom-domain cutover remains blocked by access to the
domain-owning Cloudflare account; see the canonical
[domain publication runbook](domain-publication.md) and
[release receipt](releases/google-welcome-20260911.json). This does not claim a
completed user login or a new `leoinvesting.com` release.

## User flow and identity

`/#/welcome` offers one **Sign in with Google** action for both account creation
and returning users. The header's Sign in/My account control opens this page.
Signed-in users can open Picks or Strategies and sign out. Picks remains the
default homepage and public research remains available without signing in.

The welcome page and strategy workspace share `IdentityProvider` and the
feature-specific Supabase session key `leo.strategy-lab.auth.v1`. Supabase keeps
the persistent session in browser local storage; the selected return path uses
session storage. This does not replace the retained member application's session.

OAuth uses Google's provider through Supabase with PKCE/S256 and the exact
same-origin `/strategy-auth/callback`. Only `/#/home` and `/#/strategies` are valid
return destinations; missing or untrusted values resolve to Picks. The callback
removes the single-use code/provider error from the address before exchanging it,
keeps the welcome screen mounted without chart frames, then changes the hash after
successful exchange. Interrupted, expired and unavailable-config states offer
recovery instead of granting access.

Account display does not grant membership or trading permission. The strategy API
still verifies the token and active membership server-side. Anonymous identities
are ignored. Sign-out or identity changes clear private strategy evidence; an
older in-flight response cannot populate the next user's view. Archive failures
do not prevent sign-in, account recovery or strategy controls from rendering.

## Configuration and assets

Read-only verification confirmed Google enabled in the existing Leo Investing
Supabase project `katwbobjiyzipqlzarus`, with email/profile identity scope only.
The welcome-page work made no Supabase backend changes. The earlier
[strategy deployment receipt](../platform/docs/strategy-lab/SUPABASE-DEPLOYMENT-20260910.md)
records the existing control plane and allowed callbacks:

- `https://leo.axio7.workers.dev/strategy-auth/callback`
- `https://leoinvesting.com/strategy-auth/callback`

Production builds need an enabled, validated public-client configuration supplied
through `LEO_STRATEGY_PUBLIC_CONFIG`; the checked-in example remains disabled.
Only the publishable key belongs in that file. Google client secrets and privileged
Supabase credentials stay server-side. A complete actual-user login, resulting
membership access and custom-domain callback remain separate acceptance checks.

The Google action uses Google's unmodified pre-approved PNG from its official
sign-in asset archive, preserving its aspect ratio. The current G and Google Sans
lettering belong to that provider asset; Leo's Lion, Inter type and aubergine/gold
system remain unchanged. The exact archive entry and source are recorded in
[the PNG provenance](../platform/features/research-desk/account/google-signin.png.json),
following [Google's branding guidance](https://developers.google.com/identity/branding-guidelines).
No generated or edited Google logo is used.

## Verification and reproduction

Completed local checks: **7 strategy/auth contract tests, 9 auth browser groups,
5 existing strategy browser groups, 17 routing tests**, scoped TypeScript and the
static asset build. Browser fixtures cover real SDK PKCE initiation, bounded
returns, exchange timing, code stripping, denial/expiry/config recovery,
reload/logout, anonymous exclusion and cross-user response isolation. They stub
all authentication/API responses and perform no real login, brokerage connection
or trade. Desktop 1536×960 and mobile 390×844 captures, signed-in/error states and
the receipt live under `platform/.impeccable/review/account-auth/`.

With the repository dependencies, Rust WASM target and Playwright installed, run
from `platform`:

```powershell
node scripts/grid-research-build.mjs
node --import tsx scripts/research-desk-build.mjs
node node_modules/typescript/bin/tsc --noEmit --project features/research-desk/tsconfig.json
node --import tsx --test features/strategy-lab/tests/contracts.test.ts features/research-desk/worker-routing.test.cjs
$env:PORT='3220'
node features/strategy-lab/tests/preview-server.mjs
```

In a second terminal, also from `platform`:

```powershell
$env:LEO_AUTH_TEST_BASE='http://127.0.0.1:3220'
# Set LEO_PLAYWRIGHT_MODULE to an installed Playwright package's absolute path
# only when it is not resolvable by its normal package name.
node --import tsx features/research-desk/account/auth-browser.cjs
node --import tsx features/strategy-lab/tests/browser.cjs
```

These browser tests inject public configuration, including an explicitly disabled
first strategy case, so their result does not depend on a production auth setting.
The retained backend is published through the existing static-overlay process;
do not replace it with a wholesale Next.js rebuild for this UI change. This flow
needs no VPS and makes no recurring AI calls. Real-money execution stays disabled.

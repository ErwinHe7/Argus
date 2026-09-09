# Leo Investing backend deployment — September 5, 2026

Fresh Supabase project `katwbobjiyzipqlzarus` (“Leo Investing”) was created in
ErwinHe7's Org (`cybfuwoayykjdqgurmbe`), on the Free plan, in `us-east-1`.
The prior Supabase projects were not changed. This is fresh application data;
no user accounts, progress, or other data were migrated from the inaccessible
original backend. Generated local credentials are persisted only in Windows
Credential Manager, with runtime copies installed in Supabase secrets/Vault;
no secret credentials were written into source, deployment artifacts, or receipts.

| Resource | Value |
| --- | --- |
| Required website | https://leoinvesting.com |
| Supabase | https://katwbobjiyzipqlzarus.supabase.co |
| API | https://katwbobjiyzipqlzarus.supabase.co/functions/v1/api |
| Google provider callback | https://katwbobjiyzipqlzarus.supabase.co/auth/v1/callback |
| App OAuth callback | https://leoinvesting.com/mobile/argus-auth/callback |
| Public publishable-key SHA-256 | `a49ca33d5d726c61237f80c1d6849381cde11db90722e409fb7cc9ad5fb251a5` |

## Deployed scope

- Clean backend source was extracted from commit
  `54587fa68aadebe5ce56bc8d02b0e68524d18848`. Only the exact new consumer-origin
  allowlist change was added before deploying the API and worker.
- Supabase CLI `2.115.0` applied all 35 baseline migrations, followed by
  `20260905135500_allow_jobs_owner_vault_decryption.sql`: 36 migrations total.
  The new migration supplies the current Vault view's decrypt-function dependency
  to its existing NOLOGIN dispatch owner. Its SHA-256 is
  `a13dd09be3006814218b4240bf5b9ecb603d023e5078e8477f0e78c7f5c4ee88`.
- `api` version 3 and `worker` version 2 are ACTIVE after the exact-domain
  correction below. Gateway JWT verification is off
  intentionally: the API validates Supabase JWTs against JWKS; the worker requires
  HMAC authentication, a fresh nonce, and a registered durable dispatch.
- Local `seed.sql` was not applied. Baseline migrations include the clearly
  labeled synthetic Daily Ritual reference content and its permanently banned,
  passwordless editorial system actor.
- Runtime uses `ARGUS_ENVIRONMENT=staging`, open web admission, and only
  `https://leoinvesting.com` for this deployment's consumer origin.
  Staging selects `draft-preview-starpath-curriculum-v2` and advertises Starpath
  to members. The prepared frontend provides the supplementary four Leonidas
  stories; that frontend has not been published to the requested domain.
- `argus_edge` and `argus_worker_edge` use dedicated pooler credentials. They
  have NOINHERIT, NOBYPASSRLS, and no superuser rights. `argus_jobs_owner` is also
  NOLOGIN, NOINHERIT, NOBYPASSRLS, and not a superuser.
- Internal background jobs are enabled. Provider egress and order mutations
  remain blocked by their existing kill switches. Brokerage callbacks and the
  standalone waitlist function were not deployed because this lesson pilot
  does not require their external provider/Turnstile configuration.

## Verification

- API and worker passed frozen Deno type checks; six environment tests passed.
- 145 distinct rollback-only database assertions passed: Daily Ritual content,
  trusted request context, member lifecycle, grants/RLS, Starpath state, and the
  new Vault dependency grants. Grants/RLS were rerun after the new migration.
- Twelve draft Starpath, branch capability, and onboarding schema tests passed.
- A synthetic member was inserted inside a rolled-back transaction. The actual
  member trigger and session repository produced an active member and welcome
  onboarding state; birthday onboarding completed; Starpath stayed available
  with the expected draft manifest. Cleanup verified that the synthetic member's
  auth row was absent after rollback. No real member was used for this check.
- Public ritual API returned HTTP 200 and the two seeded educational items.
  Unauthenticated `POST /v1/session/bootstrap` and Starpath requests returned
  HTTP 401. Responses allowed the exact new website origin.
- Normal database worker dispatch request 1 was acknowledged and returned
  HTTP 200, with zero retries or dead letters. This confirms Vault, pg_net,
  worker authentication, the dedicated worker DB login, and queue access.

## Google OAuth connected — September 5, 2026

The earlier pending Google setup was completed after the user requested
autonomous client creation and connection. A Google web OAuth client was created
at 10:19 ET in the Gmail project `project-b39fbc75-fb33-441f-94a`:
`910232806303-1ia5hbbr821tku4392ro4h4jl8l6a3sb.apps.googleusercontent.com`.
Branding was already saved when setup resumed. The agent did not accept a Google
agreement.

- Authorized JavaScript origin: `https://leoinvesting.com`.
- Google redirect URI: `https://katwbobjiyzipqlzarus.supabase.co/auth/v1/callback`.
- Supabase site URL: `https://leoinvesting.com/`; app redirect allowlist:
  `https://leoinvesting.com/mobile/argus-auth/callback`.
- Google is enabled, email login is disabled, and nonce checks remain enabled.
- Google Data Access is saved with exactly `email`, `profile`, and `openid`;
  no sensitive or restricted scopes are configured.

The Google client secret is retained in Windows Credential Manager at
`Supabase Leo Investing:google-oauth-client-secret-910232806303`. The initial
downloaded Google JSON was deleted after storage was verified. No secret values
were printed or included in source, receipts, or frontend build credentials.
The Management API returns an opaque 64-character hexadecimal value for the
saved secret, causing the initial literal equality check to return false. The
helper was corrected to handle that opaque representation. An independent API
read confirmed the new client ID, Google-only provider state, callbacks, and nonce
checks; the temporary Google JSON was also confirmed absent. A real browser
flow subsequently succeeded through Google → Supabase → the exact
`leoinvesting.com` app callback with an authorization code at approximately
14:22 UTC. The code is redacted; consent requested only name, picture, and email.

The audience is still **Testing**. Basic-only sign-in is exempt from the test-user
restriction under [Google's testing guidance](https://support.google.com/cloud/answer/15549945).
Full brand publication is blocked by missing public policy pages. End-to-end
frontend session completion, onboarding, and Starpath access remain unverified:
the original requested-domain frontend is unchanged and bound to its old backend.
Access to the shared Cloudflare Worker's owning account is still blocked, and
the incorrect alternate site's public and preview routes remain disabled.

## Local authentication helpers

Local operational helpers are in `release-work` outside the repository:

- `leo-backend-authority.ps1` reads the existing Supabase CLI credential from
  Windows Credential Manager; generated owner/runtime credentials are retained
  there under names beginning `Supabase Leo Investing:`.
- `configure-leo-google.ps1` defines `Set-LeoGoogleAuth -ClientId <public-id>
  -ClientSecretCredentialTarget <exact-Windows-credential-target>`. Dot-sourcing
  the file does not change remote configuration. Explicit invocation reads the
  secret in memory, configures the new project only, enables Google, disables
  email login, retains nonce checking, sets the exact site/app callbacks above,
  and checks the saved configuration without printing secret values. The final
  provider update is now complete; the successful browser callback flow above
  verifies the connection beyond the API's opaque secret representation.

## Exact-domain correction

The user reaffirmed that the deployment must use `https://leoinvesting.com`.
The alternate Workers hostname was not the requested destination. This backend
receipt does not claim that the custom-domain frontend is published.

- The new Leo consumer-origin group was changed to the exact HTTPS origin
  `https://leoinvesting.com`; legacy origin groups were preserved. The alternate
  `https://leo-investing.axio7.workers.dev` is now explicitly rejected by tests.
- The API was redeployed from the clean backend archive using Supabase CLI
  `2.116.0`, with `functions deploy api --project-ref katwbobjiyzipqlzarus
  --use-api`. No migrations, member data, or original backend were changed.
- Only `ARGUS_CONSUMER_ORIGINS` and `ARGUS_ADMIN_ORIGIN` were updated to the exact
  requested origin. Both previously matched the alternate hostname, verified
  through their saved secret digests. Other runtime secrets and kill switches
  were preserved.
- Auth Site URL is `https://leoinvesting.com/`; its redirect allowlist is exactly
  the app OAuth callback above. During the earlier September 5 domain correction,
  Google was still disabled pending valid client setup and provider settings
  were preserved. The subsequent provider connection described above enabled
  Google, disabled email login, and retained nonce checks. Local provisioning
  and Google configuration helpers use the corrected origin too.
- Six environment tests passed, including rejecting the alternate hostname,
  duplicate/mixed origins, HTTP, trailing paths, and deceptive suffixes. The API
  passed its frozen Deno type check. The deployed environment source SHA-256 is
  `1e0011f4c4f48c2b4b4003ec9e4d6fed69722ed1545b97a77cf830841326a952`.
- The live public ritual endpoint returned HTTP 200 and two items with
  `Access-Control-Allow-Origin: https://leoinvesting.com`. Exact-origin preflight
  returned 204. Alternate-hostname and deceptive-suffix preflights returned 403
  without an allow-origin header. Unauthenticated session bootstrap and Starpath
  requests returned 401.

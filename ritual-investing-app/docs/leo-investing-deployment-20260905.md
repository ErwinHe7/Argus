# Leo Investing deployment — September 5, 2026

## Corrected deployment target

The user requires **only** <https://leoinvesting.com/#/welcome>. The alternate
Workers address was an incorrect interpretation of the request. Its public
`workers.dev` route and all preview URLs were disabled on September 5; a public
HTTP check now returns 404. The retained Worker configuration also disables both.
The saved Worker assets below are historical staging evidence, not a delivery.

The exact-domain release is prepared with `config/leoinvesting-fresh.json`.
Its asset manifest SHA-256 is
`30d220722bd889597ab65131193d13b7f4fbd52195ae355480cf83699a7d6728`
(111 files, 101,430,746 bytes). This includes the first chapter's Blender artwork
and gentle scene motion. The compiled OAuth app callback is exactly
`https://leoinvesting.com/mobile/argus-auth/callback`; the bundle contains no
alternate Workers site URL, source maps, or service worker. Build and assembly
passed, and the manifest's file hashes were verified. It is not yet published.
The existing `leoinvesting.com` deployment has not been modified. Latest remote
main's `docs/ritual-investing/leoinvesting-domain-migration.md` confirms account
`5cc3bc33ca089258d20b6e80e67e5333`, zone
`84e6285e3d2a72d9fd9b4676346b96ed`, and Worker `ritual-investing-member`.
That Worker also serves the old site; verify its live domain mappings before
changing it so the requested deployment does not alter another domain.

Available local Cloudflare credentials do not access that account. A restricted,
GET-only GitHub investigation workflow on `codex/leoinvesting-domain-access`
was blocked before any step ran by GitHub account billing; no Cloudflare API
operation occurred. Run: <https://github.com/ErwinHe7/Argus/actions/runs/33970594900>.

Google OAuth is now configured on the fresh backend. A real browser flow through
Google and Supabase reached the exact `leoinvesting.com` app callback with an
authorization code at approximately 14:22 UTC on September 5. The code is not
recorded here. Frontend sign-in completion, onboarding, and Starpath access are
still unverified: the requested-domain frontend is unchanged and remains bound
to the original backend. Cloudflare account access remains the deployment blocker.

## Blender pilot release verification

The refreshed isolated member release build and asset assembly passed. All 111
manifest entries were verified by length and SHA-256, including
`assets/assets/images/leonidas/leonidas-garden-blender-v1.png` with SHA-256
`03f22f05c1368819ec5543d8bdae88ddeaafd2d70d9085ecd0a3c5d45ac2568c`.
The exact-domain callback remains embedded, with no alternate Worker address,
source maps, or service worker in the package.

The separate local story preview was checked in desktop and phone layouts.
Presentation and integration tests passed; four focused garden tests cover
motion, fallback, chapter changes, and a phone layout with doubled text size.
Browser checks exercised pause/resume, replay, and incorrect/correct choices.
The original Blender scene and reproducible authoring script are retained under
`art/leonidas/blender/`; only its PNG is shipped to the app. This verification
does not establish publication to the requested domain.

## Original backend access recovered — September 5, 2026

A new read-only investigation of GitHub main confirmed migration commit
`a3c2311be394f64deb7f6030b54f3e2beffbd3c4`. Its original backend is organization
`RitualInvestment` (`urpivisceveacabjrtnz`), parent project `punuomgshlypbntanomz`,
and persistent beta branch `zbgjjufjkhfhirbuuolv`.

The current Supabase connector now has usable access to that original backend.
Listing the parent's branches returned beta as `ACTIVE_HEALTHY`; listing the
beta branch's Edge Functions succeeded with `api` v44, `waitlist` v26, `worker`
v26, and `webull-callback` v25, all active. The API and waitlist hashes match the
September 4 migration receipt. No original backend settings, data, or Auth
providers were changed during this investigation. The prepared release still
targets the fresh backend described above.

GitHub's signed-in repository settings show one repository secret,
`CLOUDFLARE_CONTENT_API_TOKEN`, and no deployment environments. The existing web
release workflow references an absent `ritual-investing-web-release` environment
and different credential names. Secret values were not retrieved. The existing
access-check run still reports that it did not start because recent account
payments failed or the spending limit needs increasing; no new run was dispatched.
The owning Cloudflare dashboard currently redirects the Chrome session to login.
Original Supabase access is therefore resolved; exact-domain hosting access is
still unresolved.

Sources: [migration record](https://github.com/ErwinHe7/Argus/blob/a3c2311be394f64deb7f6030b54f3e2beffbd3c4/docs/ritual-investing/leoinvesting-domain-migration.md),
[repository secrets](https://github.com/ErwinHe7/Argus/settings/secrets/actions),
[environments](https://github.com/ErwinHe7/Argus/settings/environments), and
[access-check run](https://github.com/ErwinHe7/Argus/actions/runs/33970594900).

## Historical alternate release (public routing disabled)

- Cloudflare account: `b1c5a45c69c6c16796c586a23d685a8a`
- Worker: `leo-investing`
- Version: `db6a82b2-56c5-46f6-98ba-bf436d75e900`
- Supabase organization: `cybfuwoayykjdqgurmbe` (ErwinHe7's Org, Free)
- New project: `katwbobjiyzipqlzarus`, US East
- App configuration: `config/leo-investing.json`
- Worker configuration: `../ritual-investing-site/wrangler.leo-investing.jsonc`
- Asset manifest SHA-256:
  `38b02c782f695f0670cb31665641e0f8f2be4993431e35a1d2cf8c36c12bc127`
- Package: 110 files, 99,063,540 bytes

The release uses a clean archive of commit
`54587fa68aadebe5ce56bc8d02b0e68524d18848` with the selected Leonidas feature,
lion icon references, and fresh deployment configurations overlaid. Unrelated
unfinished Market Map work is excluded. The clean workspace is
`release-work/leo-web-20260905` beside the repository.

The first four Leonidas chapters appear through Investment → Stories with
Leonidas as supplementary practice. They preserve the hosted curriculum and its
server-authoritative progress. Details are in `leonidas-story-pilot.md`.

## Verification

The live-site observations below describe the historical alternate release
before its public routing was disabled. They do not describe the unchanged
`leoinvesting.com` frontend.

- 48 focused story and Starpath tests passed; full isolated Flutter analysis clean.
- Full web release build, asset assembly, and Wrangler dry-run passed.
- All 110 asset manifest entries verified by length and SHA-256.
- Live root HTML, OAuth callback HTML, JavaScript bundle, manifest, and lion favicon
  match the packaged release byte for byte and return HTTP 200.
- Live browser welcome screen renders the canonical lion and sole Google entry.
- CSP connects only to the fresh backend; no service worker or source maps shipped.
- New backend member-state, permissions/RLS, lifecycle, seeded-content, and
  Starpath checks passed 145 distinct database assertions and 12 schema/branch
  tests. Public educational content
  returns HTTP 200; unauthenticated member routes return HTTP 401.
- Normal background worker dispatch returns HTTP 200 with no errors or retries.
- This is fresh data: accounts and progress from the inaccessible original project
  were not migrated. Backend details are in
  `../../docs/ritual-investing/leo-investing-backend-deployment-20260905.md`.

## Google OAuth connected — September 5, 2026

At the user's request to create and connect the client autonomously, a Google
web OAuth client was created at 10:19 ET in the Gmail project
`project-b39fbc75-fb33-441f-94a`. Branding was already saved when setup resumed;
the agent did not accept a Google agreement.

| Setting | Saved value |
| --- | --- |
| Public client ID | `910232806303-1ia5hbbr821tku4392ro4h4jl8l6a3sb.apps.googleusercontent.com` |
| Authorized JavaScript origin | `https://leoinvesting.com` |
| Google redirect URI | `https://katwbobjiyzipqlzarus.supabase.co/auth/v1/callback` |
| Supabase site URL | `https://leoinvesting.com/` |
| Supabase app redirect | `https://leoinvesting.com/mobile/argus-auth/callback` |
| Google Data Access scopes | `email`, `profile`, `openid` only |
| Supabase provider state | Google enabled; email login disabled; nonce checks retained |

The client secret is stored in Windows Credential Manager under
`Supabase Leo Investing:google-oauth-client-secret-910232806303`. The initial
downloaded Google JSON was deleted after the credential store was verified.
No secret was printed or added to source, receipts, or frontend build credentials.
The Supabase Management API returns an opaque 64-character hexadecimal value
for the saved secret, so the initial literal equality check returned false;
the helper was then corrected to handle that opaque representation. An independent
API read confirmed the client ID, Google-only provider state, callbacks, and nonce
checks. The subsequent
real Google → Supabase → exact app callback flow succeeded at approximately
14:22 UTC; the consent screen requested only name, picture, and email.

The Google audience remains **Testing**. Data Access contains no sensitive or
restricted scope. Basic-only sign-in is exempt from the test-user restriction
under [Google's testing guidance](https://support.google.com/cloud/answer/15549945).
Full brand publication remains blocked by missing public policy pages. This
provider verification does not establish frontend session completion or a working
member experience. After the exact-domain frontend is published, verify sign-in
through onboarding to Starpath.

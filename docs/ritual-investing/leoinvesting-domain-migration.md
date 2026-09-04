# leoinvesting.com domain migration

Verified: 2026-09-04 06:10 UTC.

Status: **The member app is working on `https://leoinvesting.com` against the
verified Supabase beta branch.** Login with the owner's supplied beta test
account succeeded, authenticated Ritual data loaded, and the session survived
reloading the newly deployed app. `www.leoinvesting.com` redirects to the apex
while preserving paths and query parameters. Ancillary legacy landing-page,
staging, and infrastructure reconciliation work is listed below; the old domain
has not been globally redirected or retired.

The owner authorized this migration, explicitly waived an IP restriction on the
new beta API hostname, selected Supabase beta, and supplied a test account for
login verification. Production Supabase was not modified. No database migration,
data deletion, credential rotation, or waitlist activation was performed.
Unrelated dirty-worktree changes were preserved.

## Live mappings

Account: `5cc3bc33ca089258d20b6e80e67e5333`.

Old zone: `04a8ca6b28678d4a4018308a5c23d30c` (`just-build-this.app`).

New zone: `84e6285e3d2a72d9fd9b4676346b96ed` (`leoinvesting.com`).

Each new address uses the same service as its old-domain counterpart.

| New hostname | Existing service | Verified state |
| --- | --- | --- |
| `leoinvesting.com` | Worker `ritual-investing-member` | Enabled; member entry screen rendered over HTTPS |
| `www.leoinvesting.com` | Zone redirect, existing Worker attachment retained | HTTP 301 to `leoinvesting.com`, path/query preserved |
| `demo.leoinvesting.com` | Worker `ritual-investing-demo` | Enabled; simulated demo rendered |
| `beta.leoinvesting.com` | Worker `ritual-investing-site-beta` | Enabled; landing page loaded |
| `demo-beta.leoinvesting.com` | Worker `ritual-investing-demo-beta` | Enabled; demo document loaded |
| `api.leoinvesting.com` | Worker `ritual-investing-api` | Enabled; application health not verified |
| `api-beta.leoinvesting.com` | Worker `ritual-investing-api-beta` | Enabled without a new IP restriction; application health not verified |
| `staging.leoinvesting.com` | Pages `ritual-investing-site-staging` | Custom domain active; HTTP 522, also present on old staging hostname |
| `demo-staging.leoinvesting.com` | Pages `ritual-investing-demo-staging` | Custom domain active; demo document loaded |

The staging landing Pages project has no canonical deployment. The production
apex and production demo are currently Workers, despite the repository's
planned production Pages infrastructure. Do not repoint them to undeployed
Pages projects during reconciliation.

## Other Cloudflare changes

- Added the two proxied Pages CNAME records. Worker custom-domain attachment
  generated its own DNS records and certificate references.
- Confirmed active certificates for the apex and wildcard on the new zone.
- Enabled `always_use_https` on the new zone. Other inspected TLS and security
  settings already matched the old zone.
- Extended `ritual-waitlist-prod-widget-v1` to include `leoinvesting.com`,
  retaining `just-build-this.app`.
- Extended `ritual-waitlist-beta-widget-v1` to include
  `beta.leoinvesting.com`, retaining `beta.just-build-this.app`.
- Enabled Email Routing with its generated MX, SPF, and DKIM records.
- Created `privacy@leoinvesting.com`, forwarding to the same existing verified
  destination as `privacy@just-build-this.app`. Email Routing reports
  `enabled=true`, `status=ready`, and `synced=true`. No delivery test was sent.
- The old custom WAF ruleset describes an IP restriction, but its API reads
  contained no rules and the dashboard showed zero custom rules. Automatic
  approval review initially rejected the beta API alias and a proposed
  containment rule. Neither rejected action changed the account. After the
  owner explicitly waived IP restrictions, the alias was attached successfully.
  No new custom WAF rule was created.
- The two Ritual public-media R2 buckets have no custom domains to migrate.

## Remaining ancillary migration work

- The legacy `beta` landing and demo surfaces are attached to new hostnames, but
  their old-domain embedded links, CSP, canonical/sitemap URLs, privacy text,
  and legacy Worker bindings still need coordinated migration. The member app
  uses Supabase directly; it does not depend on those legacy API Workers.
- The staging landing Pages project has no deployment and returns HTTP 522 on
  both old and new hostnames. Resolve through its release process.
- Reconcile existing Terraform and release profiles with the new zone and
  additive aliases. Several relevant files already had unrelated uncommitted
  changes; do not replace protected domain resources blindly.
- Native associated-domain files and app-store releases, Google-provider consent
  configuration for future Google-only app releases, real OAuth/password-email
  callback completion, and privacy email delivery are not verified by this web
  login test. The live member app retains the existing email/password flow.
- `WAITLIST_SUBMISSIONS` remains off. Activating waitlist collection, sending
  email, and changing credentials were not part of this change.
- Keep the old domain and callback allowlist during transition. Apply old-to-new
  redirects only with callback, native-link, and legacy embedded-demo behavior
  accounted for; no global old-domain redirect was added.

## Completed Supabase beta deployment

Verified in the signed-in dashboard:

- Organization: `RitualInvestment` (`urpivisceveacabjrtnz`).
- Parent project: `Ritual Investment`; production/main ref
  `punuomgshlypbntanomz`, untouched.
- Selected branch: `beta`, persistent, ref `zbgjjufjkhfhirbuuolv`.
- The public `leoinvesting.com/main.dart.js` artifact independently confirms
  that this beta ref is its Supabase and API target.
- Auth Site URL is now `https://leoinvesting.com`.
- Both exact Auth callbacks remain saved:
  `https://leoinvesting.com/mobile/argus-auth/callback` and
  `https://just-build-this.app/mobile/argus-auth/callback`.

Deployed changes:

- `_shared/environment.ts` accepts the exact old/new/preview migration set
  while preserving existing profiles. Duplicate, missing, path-bearing and
  lookalike origins still fail closed.
- `waitlist/index.ts` recognizes the migrated landing hostnames while retaining
  its single configured exact origin and matching Turnstile hostname checks.
- `ARGUS_CONSUMER_ORIGINS` now contains exactly:
  `https://just-build-this.app,https://leoinvesting.com,https://staging-ritual-investing-member.xiaolonggao521.workers.dev`.
- `WAITLIST_ALLOWED_ORIGIN=https://beta.leoinvesting.com` and
  `TURNSTILE_EXPECTED_HOSTNAME=beta.leoinvesting.com` were updated together.
  `WAITLIST_SUBMISSIONS=off` was preserved.

The CLI worked after the owner completed `supabase login` and it was run outside
its filesystem sandbox to access saved credentials. Earlier connector and
dashboard failures are resolved for this task by using the authenticated CLI.

Before deployment, the current API and waitlist were downloaded to
`/private/tmp/leoinvesting-beta-migration-20260904/before` and hashed in
`before-sha256.json`. Every downloaded file matched repository HEAD
`2607286dbd94325dfc1a9efa3fb3d0330b24f940`. The deployment copy in `source` changed
only the two runtime files above; 24 source files omitted from the runtime
bundle were restored from that matching HEAD for type checking.
No broad remediation or database-migration workflow was dispatched.

After function deployment and the shared environment update:

| Function | Version | Runtime bundle SHA-256 |
| --- | --- | --- |
| `api` | 44 | `6c5d5d08715e824a39ac4c8e22f7cebba8087d54130b4bba0582537a3927486c` |
| `waitlist` | 26 | `5fe1a14807078c228b973545ee8962529e52c6fd50c2115f6e1c5c16f9c2f18b` |

The environment update also incremented the untouched `webull-callback` and
`worker` function version numbers, while their runtime bundle hashes stayed
unchanged. Application authentication verification remains in the API; its
pre-existing `verify_jwt=false` gateway setting was preserved.

## Completed member web deployment

The deployed app's Cloudflare metadata identified source commit
`e3ffd5385dc27921a133299d112563137eb9ed12`. A clean archive of that source was
rebuilt in `/private/tmp/leoinvesting-web-migration-20260904` with the new exact
Auth and Webull callback URLs, retaining old and native callbacks and the same
beta backend/public key. The current workspace's unreleased Google-only and
audio changes were not deployed.

The resulting manifest differed from the prior live app only in `main.dart.js`;
all other assets matched byte-for-byte. Its complete assembled manifest hash is
`65a01eaa65f62c086dba27fbfa119274cb002f4fd8c001bbf5ac38cc2cd64dc2`.
Only `main.dart.js` and the updated asset manifest needed uploading.

- New live Worker version: `4132c697-4656-49d1-9fa4-5e6fa2a29ffd` (100%).
- Prior rollback version: `478c0340-a131-49f6-9b6f-0187fe94a053`.
- The candidate was staged at zero percent before activation. Existing
  workers.dev/preview URLs were disabled and remain disabled.
- Local `runtime_config.dart`, `config/beta.json`, and the member web release
  workflow now carry the new domain. The beta profile points to the verified
  branch and contains only its client-safe publishable key and fingerprint.
- New-zone canonical redirect ruleset: `a53f43768bd940d3919b8d888bfd5012`;
  rule `235356ce90ea474a950436199baf93c3`, ref `leoinvesting_www_to_apex`.

## Verification

- `deno test --config supabase/functions/api/deno.json --allow-env supabase/functions/_shared/environment_test.ts`: 6 passed.
- `deno task --config supabase/functions/api/deno.json check`: passed on the
  deployment copy after restoring type-only source dependencies omitted by the
  downloaded bundle.
- `deno task --config supabase/functions/waitlist/deno.json test`: 11 passed.
- `flutter test test/runtime_config_test.dart test/member_auth_test.dart`: 13 passed.
- `flutter build web --release --no-web-resources-cdn --no-source-maps --no-wasm-dry-run --pwa-strategy=none --dart-define-from-file=.../member-defines.json`: passed.
- Historical `build-assets.ts member-staging`: passed, 93 files assembled.
- Scoped `git diff --check`: passed.
- Live beta API health: HTTP 200, `status=ok`.
- API preflight from `https://leoinvesting.com`: changed from HTTP 403
  `origin_denied` to HTTP 204 with the exact allow-origin header.
- Old apex and the configured preview origin: HTTP 204, exact allow-origin.
- Lookalike `https://leoinvesting.com.evil.example`: HTTP 403, no allow-origin.
- Beta waitlist: expected HTTP 503 `waitlist_unavailable` while disabled, with
  the exact new beta allow-origin header.
- `www` redirect: HTTP 301, preserving the test query string.
- Live web manifest and `main.dart.js` hashes match the newly uploaded artifact;
  the compiled Auth/Webull callbacks contain the new domain and the backend
  remains `zbgjjufjkhfhirbuuolv`.
- Browser login with the owner's beta test account succeeded. Authenticated
  Ritual data loaded; a reload after the new deployment retained the session.
  Credentials and session tokens were not saved in this record or source files.

## Verification limits and recovery

Cloudflare API reads confirmed all seven new Worker attachments, both active
Pages domains, DNS records, certificates, Turnstile hostnames, HTTPS setting,
and email routing. Browser checks confirmed the web states listed above.
The browser blocked the legacy Cloudflare API health URL with
`ERR_BLOCKED_BY_CLIENT`; its health remains unverified. Subsequent shell probes
verified Supabase beta health and the successful new-origin CORS checks above.
Email delivery and external provider/native callback completion remain unverified.

The old Worker and Pages domain attachments remain enabled. Recovery from a
new-domain problem is to continue using the old addresses while correcting the
new configuration. The prior member Worker version can be redeployed if needed.
Backend originals and the prior origin settings are recorded above. No database
restore is required for these domain-only changes. Remove only specifically
identified new resources if a later rollback is required, after checking that
they have not been adopted elsewhere.

Cloudflare references: [Worker custom domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/),
[Pages custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/),
and [Turnstile widget management](https://developers.cloudflare.com/turnstile/get-started/widget-management/api/).

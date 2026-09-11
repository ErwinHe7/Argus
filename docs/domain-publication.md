# Leo website and model publication

The current research application is the reviewed `leo` Worker in Cloudflare
account `b1c5a45c69c6c16796c586a23d685a8a`. The registered `leoinvesting.com` zone
belongs to account `5cc3bc33ca089258d20b6e80e67e5333`, with zone ID
`84e6285e3d2a72d9fd9b4676346b96ed`. These are distinct accounts.

The publication workflow creates **a new `leo-domain-proxy` Worker** in the domain
account and attaches only the apex to it. Its fixed upstream is
`https://leo.axio7.workers.dev`. The existing `ritual-investing-member` Worker,
its versions/assets, the old domain, `www` redirect, API/demo subdomains and email
records remain intact. No model, database, trading permission or billing setting
is altered by this gateway.

## Scope and current state

Source and tests are in `platform/workers/domain-proxy`. The controller is
`.github/workflows/leo-domain-publication.yml`, invoked manually on `main` with
the required `reviewed_sha` input. The job runs only when that input matches the
exact commit selected by GitHub. Normal pushes do not deploy the domain. It uses
the existing repository `CLOUDFLARE_CONTENT_API_TOKEN` secret and
`CLOUDFLARE_ACCOUNT_ID` variable. Credentials never appear in source or receipts.

The local Wrangler OAuth session can access the application account but cannot
see the domain account. The retained September 5 domain-inspection Actions run
`33970594900` failed before executing any step because GitHub reported failed
payments or an insufficient spending limit. Consequently that run proves nothing
about the stored Cloudflare token's permissions. Publication is complete only
after a new successful workflow receipt and independent HTTPS checks.

The current hosted-runner attempt, run `34558356755` at source `072ee1f`, was
also rejected before any job step for the same billing reason. GitHub's supported
self-hosted runner path is being used for the reviewed deployment without changing
account billing. The workflow selects one unique runner label, with no default
labels or installed background service. A local start hook restricts execution to
the exact reviewed repository, workflow, branch and commit; the runner unregisters
after one job. Future retries need a newly provisioned, explicitly scoped runner.
Documentation changes alone do not trigger another domain deployment.

The self-hosted retry of run `34558596593` checked out the exact reviewed source
and passed all 17 gateway/controller tests. Its generic user-token verification
returned HTTP 401 before any Cloudflare write or domain attachment. Account-owned
tokens use a separate verification endpoint, so that response alone does not prove
the stored credential has expired. The controller now tries the official account
verification endpoint only after a 401/403 from user verification; all ownership,
active-token and write restrictions remain mandatory. The temporary runner was
removed after the attempt. A retry requires a fresh runner and the exact new SHA.

Run `34559484288` on `main` revision `b04b691` passed all 23 tests and verified
the existing credential as an active account-owned token. It then stopped at
`owning_zone_not_accessible_or_active`, before any Worker or domain write. The
runner, private runtime and dedicated local user were removed. The token is
active; the exact zone's visibility or ownership still needs resolution.

The separate `leo-domain-diagnostic.yml` workflow performs a bounded,
manual diagnostic on an exact reviewed main revision. It uses only GET requests
and emits sanitized zone/account identifiers, status, domain mappings and error
codes. It cannot deploy, attach a domain, change DNS or expose the credential.

Diagnostic run `34559821880` at `c83e5dc` resolved the access ambiguity:

| Read-only probe | Result |
| --- | --- |
| Account token verification | HTTP 200, active |
| Exact account identity | HTTP 403, code 9109 |
| Zone list by name, with and without account filter | HTTP 200, zero zones |
| Exact known zone | HTTP 403, code 9109 |
| Account Workers custom-domain inventory | HTTP 403, code 10000 |

There is no permitted alternative attachment metadata available through this
credential. No deployment retry should run until the domain account's access is
resolved. The apex continues serving the retained Ritual member app; the updated
Leo app remains available at `https://leo.axio7.workers.dev`. The diagnostic made
no Cloudflare writes. Its sanitized evidence is private Actions artifact
`10183928447`. Future runs check out only the gateway directory, avoiding an
unnecessary download of the repository's model artifacts.

All temporary runners and their dedicated local users/private runtimes have
been removed. To retry, configure the repository secret with a credential for
the existing domain account that grants Workers Scripts Edit and Zone Read for
`leoinvesting.com`. Do not post the credential in chat or commit it. The deployed
website and isolated Supabase API need no rollback; the domain was never switched.

The source branch has been merged and pushed directly to `origin/main`; the draft
PR was closed at the owner's request. The reviewed `leo` website and isolated
Supabase strategy API are deployed. The custom domain remains a separate cutover
until a successful receipt confirms it.

The source `release.json` pins the reviewed upstream JavaScript, CSS, Google
button/provenance and public strategy configuration hashes at Worker version
`f0bcd54a-b873-4524-94ed-4d13a6d1c5ca`. The September 11 Google welcome update
passed 12 production checks and reached Google's account chooser through the
live button; complete provider sign-in was not performed. See
[Google sign-in](google-sign-in.md) for the separate fixture and live evidence.
The domain-owning account's access remains unresolved; the apex was not changed.
A later upstream build requires an explicit reviewed manifest update.
Uploading source code does not activate native models, refresh stale market
history, validate profitability or enable real-money trading.

## How the cutover is bounded

1. Test ordinary HTTP forwarding, exact upstream isolation, redirect handling,
   cookies, callback privacy, stream preservation and all rollback paths.
2. Verify the active token, exact owner account and active zone, and require the
   current apex to be attached to `ritual-investing-member`. A missing or changed
   mapping stops the job before any mutation.
3. Record the complete custom-domain mapping, prior member deployment/version
   IDs, public NS/MX records and `www` redirect. Verify the upstream asset hashes,
   homepage, original/app/pricing/callback routes and both JSON feeds.
4. Create only the new proxy Worker; refuse to overwrite a preexisting Worker of
   that name. Disable its separate workers.dev and preview URLs. No asset upload,
   backend rebuild, secret copy or storage binding is needed.
5. Recheck domain mappings, then attach only `leoinvesting.com`. Verify its asset
   bytes/content types and routes, retained DNS/mail/redirect behavior and unchanged
   member Worker version. Keep the original `leo.axio7.workers.dev` available.
6. If attachment or verification fails, reconcile the actual mapping, including
   ambiguous timeout outcomes. Restore the prior service only if the apex still
   points to this proxy; never overwrite a different operator's newer target.

The job uploads `leo-domain-receipt.json` as a private Actions artifact, retaining
source revision, before/after mappings, the untouched legacy version and rollback
outcome. Remote error bodies, request headers, cookies, query strings and credentials
are omitted. A new unused proxy may remain after a pre-attachment failure; subsequent
runs stop for review rather than silently overwrite it.

## HTTP and account behavior

The gateway forwards methods, request bodies and application credentials solely
to the fixed, owner-operated Leo origin. It follows no upstream redirects. Same-origin
redirect destinations become `leoinvesting.com`; external redirects reach the browser
without server-side credential replay. Only cookies explicitly scoped to the exact
upstream host become host-only cookies for the public domain. Upstream CORS,
authorization responses, cache policy and financial behavior are preserved.

It streams response bytes without HTML/model rewriting. Invocation logs and traces
are disabled in this gateway, and no request content is logged. The dedicated
Strategy callback's code stays in the browser; fetching its HTML shell forwards no
callback query to the upstream. No catch-all URL parameter can change the destination.

The domain transition requires the separately owned authentication configuration
to allow the exact public origin and callback. It does not automatically move
browser-local plans or sign-in sessions between hostnames. The earlier Flutter
member application remains on its retained old-domain attachment; it is not rebuilt
as part of this new research homepage publication. Native/mobile callbacks and a
complete paid checkout must be validated separately if those flows are enabled.

## Recovery and operations

The recorded previous attachment can be restored with Cloudflare's domain API by
setting only `leoinvesting.com` back to `ritual-investing-member` in the same zone.
No database restore or model rebuild is needed. Never change nameservers, email
routing, unrelated domains or the legacy Worker to recover this gateway.

This website gateway and hosted event polling require no VPS. Native Rust/Python
research loops and the locally authenticated OpenD connector still need a suitable
always-on computer or separately provisioned VPS. Their data and account prerequisites
remain unchanged.

References: [Cloudflare Custom Domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/),
[domain attachment API](https://developers.cloudflare.com/api/resources/workers/subresources/domains/methods/update/),
[Worker module upload](https://developers.cloudflare.com/api/resources/workers/subresources/scripts/methods/update/).

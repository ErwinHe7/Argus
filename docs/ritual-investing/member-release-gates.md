# Ritual Investing member release gates

Status date: 2026-08-30

Repository proof does not claim that a hosted Supabase migration, native OAuth
callback, background worker, or Webull partner contract has passed. Record
hosted evidence separately and keep every capability fail-closed until its gate
is satisfied.

## Self-service public web beta

The mobile-web beta may launch ahead of native store release without
redesigning the retained landing artifact, standalone Demo, or member product
behavior. The compiled Flutter artifact may replace the landing at the apex
through Cloudflare Workers Static Assets; the unchanged landing remains the
tested rollback artifact and Pages-hosted recovery surface. Cloudflare gains no
request handler, binding, authentication, database, provider, or stateful
backend authority. The browser uses Supabase directly only for staging Auth and
sends application data through the public-beta Argus API backed by the private
staging data boundary. `beta` in capability labels below describes product
lifecycle; deployment environments remain exactly `dev`, `staging`, and `prod`.

The release manifest uses one central capability state:

| State | Public-beta meaning |
| --- | --- |
| `beta-backed` | Supported public-beta behavior uses the exact staging API and private staging data boundary; privacy deletion may use an API-backed request/status path with a verified manual completion SLA. |
| `unavailable` | The surface is visibly incomplete and issues no provider or financial request. |
| `standalone Demo handoff` | The member leaves through an explicit Demo-labeled link to the independent synthetic artifact. |

For this beta, authorized privacy export is `beta-backed`. Deletion must be
`beta-backed` through the idempotent automated path or an API-backed
request/status path with a verified manual completion SLA. If neither deletion
path passes acceptance, the member beta is NO-GO; privacy must not be relabeled
`unavailable` to ship. Brokerage reads and mutations, provider connection, and
funding remain `unavailable`. Demo fixtures are never a fallback, and failures
never redirect automatically to Demo. Every authenticated surface identifies
the experience as a public beta, discloses the unavailable financial authority,
and keeps privacy, support, about, beta-feedback, and legal information
reachable.

Open signup is the standard entry path; invitation-only entry is not supported.
Before public promotion, retain dated evidence for custom SMTP, hosted email
confirmation, recovery delivery and expiry, fresh-context recovery callbacks,
enumeration-safe errors, CAPTCHA or equivalent abuse protection, rate limits
and abuse thresholds, deletion, alert and support ownership, and a reachable
support path.

Every unresolved hardening and product-definition concern is a P1 follow-up in
[`public-beta-web-p1-follow-up-register.md`](public-beta-web-p1-follow-up-register.md).
Those entries do not authorize enabling an unavailable capability.

## Required repository proof

Before producing a member build:

1. Run API typecheck and tests, OpenAPI/client drift checks, every Edge Function
   Deno check/test, migration replay, and pgTAP against a disposable local
   Supabase stack.
2. Run the full Flutter suite, generated-Dio integration target, Android debug
   build, iOS no-codesign build, and both provider-boundary scripts.
3. Verify the app contains no direct Webull egress, provider credentials,
   legacy Auth0 configuration, Neon dependency, or Cloudflare backend binding.
4. Preserve accessibility proof at 2× text in both themes, reduced-motion and
   accessible-navigation behavior, platform tap targets, labeled controls,
   focused confirmation routes, and platform back behavior.
5. Preserve the ritual-first hierarchy. Brokerage screens must display source
   and freshness; stale or incoherent authority disables mutation.

PRs and forks use only local Supabase and non-secret fixtures. Hosted
credentials, project tokens, database passwords, member tokens, and provider
credentials are available only to the protected serialized deployment job.

## Hosted Supabase gates

The protected staging remediation must pass the exact project/ref/DB
target guard before mutation. It fences `background_workers`,
`provider_egress`, and `order_mutations`, applies migrations, deploys the four
Edge Functions, and then runs
`scripts/check-supabase-hosted-acceptance.sh`. That hook proves:

- hosted Auth health and the exact Edge build revision;
- the linked pgTAP suite against the just-pushed hosted schema;
- the `webull-supabase-v1` schema contract;
- the exact PGMQ queue inventory;
- private Storage buckets and their size limits;
- runtime and worker statement timeouts; and
- all three deployment/provider fences remain enabled during acceptance.

Only `background_workers` may be resumed by that deployment. Privacy
export/deletion may be exposed only after their public-beta launch acceptance
passes, with the verified manual deletion completion path allowed where
automation is not ready. Provider egress and order mutations remain blocked.

On real iOS and Android devices, separately record Supabase sign-up/sign-in,
PKCE callback recovery, session restoration and refresh, recent-auth proof,
local/global logout, wrong-account rejection, and malformed/cross-lifecycle
link rejection. Never retain bearer, refresh, callback, or step-up tokens in
logs or evidence.

## Capability gates

| Capability | Required proof | Fail-closed state |
| --- | --- | --- |
| Background Argus work | Queue claim/receipt/retry/DLQ, Cron lease, revision, privacy and Storage lifecycle evidence | `background_workers=true` |
| Webull connection and reads | Partner-confirmed protocol plus hosted sandbox authorization, refresh, disconnect, projection, rate-limit, and reauthorization evidence | `provider_egress=true` |
| Manual Webull commands | Partner-confirmed signing/idempotency semantics plus preview/review/confirm, ambiguous-response reconciliation, and no-resubmission proof | `order_mutations=true` |
| Privacy export/deletion | Authorized private export lifecycle plus idempotent deletion epoch, credential destruction, object receipts, Auth-last deletion, and crash-resume proof; a verified manual completion SLA may satisfy deletion where automation is not ready | Block the member beta; keep any unproved automated route/worker closed rather than hiding the requirement |
| External notifications or media processing | Approved provider, consent, allowlist, redaction, bounded retry, and rollback evidence | No provider secret or binding |

Funding, account opening, recurring financial execution, autonomous trading,
and rebalance execution have no enablement gate because they are outside the
product.

## Starpath release contract

Starpath consumes, but does not own, the separate release-control system. That
system must provide a server-authoritative, versioned branch-capability set in
authenticated bootstrap and enforce the same decision at protected APIs. Its
Supabase feature-flag table, evaluation engine, cache, administration, and
operator workflow remain RC1 work outside the Starpath change set.

| Environment | Required branch order | Starpath content gate |
| --- | --- | --- |
| Beta | Ritual → Starpath → Discover → Coven → You | Exactly eight functional nodes in four pathways, each bound to one immutable manifest and distinct factual/compliance attestations |
| Production | Ritual → Starpath → You | Beta gate plus current legal approval for the exact no-advice policy hash, `US` jurisdiction, effective/expiry window, and R20 trigger snapshot |
| Missing, expired, unknown, or rollback | Ritual only unless a fresh capability set explicitly retains Starpath | Starpath protected reads and commands deny access; cached UI is never API authority |

Before beta enablement, retain sanitized evidence for the capability schema and
version, trusted environment, evaluation/expiry timestamps, exact branch set,
protected-route mapping, eight-node manifest identity, API revision, source
dates, dual reviews, export/purge coverage, and rollback owner. Direct and
restored production locations under Discover or Coven must replace to Starpath
when Starpath remains enabled and to Ritual when it does not; no hidden resource
response may be fetched first.

Rollback changes release-control capability only. It does not reverse Starpath
schema, delete historical learning state, weaken export or purge, or unpublish
the approved manifest. Re-enable must use the same still-valid capability and
manifest identities and prove no dangling manifest, session, attempt, recall,
or idempotency reference.

The first `learning_retention_within_7d_v1` baseline is captured only after a
matured hosted cohort exists. It records one fixed server `as_of`, cohort
bounds, matured denominator, retained count, definition version, and checksum;
it exposes no member rows, joins no profile or financial data, and sets no
success target. Lawful deletion may change a later live recomputation without
changing the recorded non-identifying snapshot.

## Roll forward and rollback

1. Turn on the narrow affected kill switch and stop new producers.
2. Preserve receipts, leases, deletion fencing, idempotency, and ambiguous
   provider outcomes; never bypass them to recover traffic.
3. Fix forward with a reviewed migration/function revision, or use the approved
   Supabase restore procedure. Do not point clients at Auth0, Neon, or a legacy
   Cloudflare API as rollback.
4. Resume background work only after the exact hosted acceptance hook passes.
5. Open provider egress or order mutations only through the separate Webull
   launch gate in `webull-operations-runbook.md`.

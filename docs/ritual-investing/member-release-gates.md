# Ritual Investing member release gates

Status date: 2026-08-28

Repository proof does not claim that a hosted Supabase migration, native OAuth
callback, background worker, or Webull partner contract has passed. Record
hosted evidence separately and keep every capability fail-closed until its gate
is satisfied.

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

The protected hosted-development promotion must pass the exact project/ref/DB
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

Only `background_workers` may be resumed by that deployment. Provider egress
and order mutations remain blocked.

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
| Privacy export/deletion | Private export lifecycle, deletion epoch, credential destruction, object receipts, Auth-last deletion, and crash-resume proof | Keep privacy route/worker gate closed |
| External notifications or media processing | Approved provider, consent, allowlist, redaction, bounded retry, and rollback evidence | No provider secret or binding |

Funding, account opening, recurring financial execution, autonomous trading,
and rebalance execution have no enablement gate because they are outside the
product.

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

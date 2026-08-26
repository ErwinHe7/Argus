# `just-build-this.app` site, Demo, and waitlist runbook

Status date: 2026-08-26

This runbook is the executable release authority for the public landing page,
auth-free embedded Demo, and provisional waitlist. It supplements the broader
[Cloudflare](cloudflare-runbook.md), [Neon](neon-runbook.md),
[beta](beta-environment.md), and [production handoff](deployment-handoff.md)
documents. Never copy member-API credentials or production member data into
this release. Per the 2026-08-26 owner decision, the four referenced documents
retain their pre-existing edits untouched; this file remains the site/Demo
release authority.

## Current release state and stop conditions

The landing and Demo hosts were activated on 2026-08-26 with submissions off.
Do not enable waitlist writes until every remaining stop condition below is
resolved and recorded in the signed release baseline:

- The Neon control-plane connection is authorized. The dedicated projects were
  created and migrated on 2026-08-26: production `broad-unit-31027461`
  (`br-plain-wave-a6ggfbqa`) and beta `cool-resonance-84878378`
  (`br-red-flower-aun5zcsw`). Both are empty and record migration checksum
  `789b078c8baebfd608aaed004ae1d2f8dcd5bfb4b03433cb8e00d76737cc4a76`.
- Cloudflare Email Routing is enabled with verified destination resource
  `8997391707054df9855931bdf64e5530` and exact active forwarding rule
  `7c494637fa3549eeadff31f0f1178169`. Before waitlist traffic is enabled, send
  a synthetic message through `privacy@just-build-this.app` and record only a
  delivery fingerprint and timestamp.
- Cloudflare Analytics Engine is enabled. Both telemetry bindings accepted
  their first disabled-request event: `ritual_waitlist_beta_events_v1` and
  `ritual_waitlist_prod_events_v1` each returned an aggregate count of one.
- Production and beta have installed Worker secrets, confirmed source and route
  rate-limit bindings, and host-scoped Turnstile widgets. The approved pair of
  exact-host WAF rules (60 requests per minute with a one-minute block) remains
  absent: Cloudflare's Free plan permits only one IP-based rule with a 10-second
  period and mitigation timeout. Keep submissions off until the intended rules
  are installed after a plan upgrade or the owner explicitly approves a
  materially different Free-plan approximation.
- The production and beta retention KV namespaces were provisioned on
  2026-08-26 as `fc10e9eaa5024cc6b3d79c59ecb6afad` and
  `840400a6dd244116888da7c7467dce02`. Re-list and match their titles before any
  upload; never swap their bindings.
- The maintenance-only denial journals were provisioned as production
  `6ca06cd7239b46859bc47e34f2e0e8a4` and beta
  `992455a9fbfd47688582657d781e44b6`. They must never be bound to a landing
  Worker.
- `WAITLIST_SUBMISSIONS` remains `off`. Disabled synthetic requests returned
  `503 waitlist_unavailable`, and both dedicated Neon tables remained at zero
  rows after the beta and production probes.
- The active versions are beta Demo
  `d54c83dd-9f2b-4ce2-a452-d09f930a729f`, beta landing
  `de5ad78b-f814-4aa6-816e-78bcbffac251`, production Demo
  `202728dc-a48e-4bec-87c1-0770041a2957`, and production landing
  `b412e88a-55e4-433d-911a-76544171450d`, each at 100 percent. All four
  Workers retain disabled `workers.dev` and preview subdomains.
- `beta.just-build-this.app`, `demo-beta.just-build-this.app`,
  `just-build-this.app`, and `demo.just-build-this.app` are attached to their
  exact services. `www.just-build-this.app` is attached to the production
  landing Worker and returns `308` to the same apex path and query.
- Beta has the reviewed `17 4 * * *` purge trigger. The owner approved the
  equivalent production trigger, but Cloudflare rejected its installation
  because all five Workers Free cron slots are already occupied: four by
  `ritual-investing-api` and one by `ritual-investing-site-beta`. Do not remove
  or repurpose an existing trigger without a separate, exact owner decision.

The Cloudflare zone was active at the 2026-08-26 activation. The existing API
Custom Domains remained attached throughout. Their required preserved health
contracts were:

| Host | Required response before and after every site mutation |
| --- | --- |
| `api.just-build-this.app/health` | `503`, code `runtime_configuration_unavailable` |
| `api-beta.just-build-this.app/health` | `200` |

An API mismatch is an immediate stop; this release does not repair or otherwise
change either API.

## Environment and ownership record

| Boundary | Production | Beta |
| --- | --- | --- |
| Landing Worker | `ritual-investing-site` / `just-build-this.app` | `ritual-investing-site-beta` / `beta.just-build-this.app` |
| Demo Worker | `ritual-investing-demo` / `demo.just-build-this.app` | `ritual-investing-demo-beta` / `demo-beta.just-build-this.app` |
| Active landing version | `b412e88a-55e4-433d-911a-76544171450d` | `de5ad78b-f814-4aa6-816e-78bcbffac251` |
| Active Demo version | `202728dc-a48e-4bec-87c1-0770041a2957` | `d54c83dd-9f2b-4ce2-a452-d09f930a729f` |
| Canonical redirect | `www.just-build-this.app` → apex, `308` | none |
| Demo protocol | current `2`, previous `1` | current `2`, previous `1` |
| Neon project | `broad-unit-31027461` / `br-plain-wave-a6ggfbqa` | `cool-resonance-84878378` / `br-red-flower-aun5zcsw` |
| Migration | `0000_waitlist.sql` / `789b078c…37cc4a76` | identical reviewed checksum |
| Turnstile site key | `0x4AAAAAAEccvtBiad9oECpT` | `0x4AAAAAAEccvUF7AG0OJIRh` |
| Denial journal KV | `6ca06cd7239b46859bc47e34f2e0e8a4` | `992455a9fbfd47688582657d781e44b6` |
| Privacy contact | `privacy@just-build-this.app` | same monitored operator, separate beta data |
| Release owners | Xiaolong for release, privacy, database, Cloudflare, and go/no-go | same owner |
| Submission state at activation | `off` | `off` |

Copy `ritual-investing-site/ops/release-baseline.example.json` to a private
working location. Fill every blank using read-only provider inspection and name
the landing/Demo release owner, Cloudflare/DNS owner, Neon security owner,
privacy data steward, and final go/no-go owner. One person may hold several
roles, but no role may be unnamed. Record only resource identifiers and
fingerprints—never URLs containing credentials, emails other than the public
privacy address, tokens, request bodies, raw IP addresses, or user agents.

Seal the completed record with a managed key of at least 32 bytes:

```sh
cd ritual-investing-site
RELEASE_BASELINE_SIGNING_KEY='<managed-value>' npm run release:baseline -- \
  --input /private/path/release-baseline.json \
  > /private/path/release-baseline.sealed.json
```

The command rejects a missing fingerprint, owner, host, rollback version,
migration checksum, role, secret resource, rate/WAF resource, Turnstile pair,
denial journal, retention resource, protocol peer, privacy contact, API
contract, or production/beta resource overlap. Keep the signing key out of the
record and shell history in a real release; inject it from the approved secret
manager.

## Preflight

1. Freeze unrelated credential, API, DNS, WAF, and zone-rule changes for the
   release window.
2. Resolve and inventory the apex, `www`, demo, beta, demo-beta, API, and
   API-beta names. Stop on a wildcard or existing record not in the baseline.
3. List Worker Custom Domains and versions. Record both the intended version
   and one immediately previous compatible rollback version for every service.
4. Verify the zone has no cookie scoped to `.just-build-this.app`. Any security
   cookie must be HostOnly and use the `__Host-` contract.
5. Verify Workers invocation logs are disabled in all four site configurations.
   Provider-console and allowlisted event inspection must contain no email,
   token, request body, connection string, raw IP, or user agent.
6. Verify the production and beta privacy inbox workflow with a synthetic
   message. Record delivery time and operator, not the destination address.
7. Run the repository gates from `ritual-investing-site`:

```sh
npm ci
npm run typecheck
npm run types:check
npm run resources:check
npm test
npm run test:postgres
npm run assets:build
npm run deploy:dry-run:all
npm run test:browser
npm audit --audit-level=high
```

From the repository root, also run both provider-boundary scripts and the
Flutter app/demo analyzer, test, release-build, and Chrome integration gates.
Do not substitute a preview or unit mock for the release artifact.

## Provision data and abuse-control resources

Provision beta first, then production. Use the identifiers in
`scripts/resource-manifest.ts`; replace placeholder control-plane IDs only after
the real resource exists.

For each dedicated Neon waitlist project:

1. Create a distinct project, branch, database, migration owner, and advisory
   lock namespace. Do not use the member-data Neon project.
2. Provision only `waitlist_runtime` and `waitlist_maintenance` as
   environment-local login capabilities with their final attributes and
   private passwords, following `scripts/provision-waitlist-role.sql.example`.
   Neon managed owners cannot `ALTER ROLE`; do not create placeholder roles.
3. Apply `drizzle/0000_waitlist.sql` with the direct owner URL using
   `npm run db:migrate`. Apply it a second time and require a no-op. The
   migration creates `waitlist_function_owner` as `NOLOGIN`.
4. Run `npm run test:postgres` against PostgreSQL 17.
5. Prove runtime has only `EXECUTE` on `submit_provisional` and
   `purge_expired`; maintenance has only the reviewed purge/removal/replay
   functions. Direct table access, object creation, inheritance, and public
   privileges must fail.
6. Record migration head `0000_waitlist.sql`, its SHA-256 checksum, effective
   grants, and a zero-or-known aggregate table baseline.

On Neon PostgreSQL 18, the managed role creator retains a provider-created
`ADMIN` link to `waitlist_function_owner` granted by `cloud_admin`. The accepted
effective contract requires `INHERIT=false` and `SET=false`; the function owner
remains `NOLOGIN`, owns the bounded functions/table, and has no schema `CREATE`.
Record this provider-managed link in the grant fingerprint rather than treating
it as runtime membership.

For each Cloudflare environment:

1. Create the exact host/action Turnstile widget. Production may trust only
   `just-build-this.app`; beta may trust only `beta.just-build-this.app`; action
   is exactly `waitlist`.
2. Create separate source and route rate limits, WAF budget/ceiling, Analytics
   Engine dataset, retention KV namespace, and daily `17 4 * * *` trigger.
3. Store `TURNSTILE_SECRET`, `WAITLIST_NEON_URL`, and
   `WAITLIST_SOURCE_HMAC_KEY` only as Worker secrets. The owner and maintenance
   URLs and denial HMAC key never bind to the landing Worker.
4. Keep the keyed denial journal outside Neon and unavailable to the landing
   runtime. Record only its opaque resource identifier in evidence.
5. Re-run `npm run resources:check`, `npm run types:check`, all four dry-runs,
   and the signed-baseline validation after inserting the real control-plane
   identifiers.

## Upload without traffic

Build the artifact once from the reviewed commit. Use private temporary secret
files with mode `0600`; delete them after the upload and provider verification.
`wrangler versions upload` creates inactive versions, while `versions deploy`
is the separate traffic step.

```sh
cd ritual-investing-site
TURNSTILE_SITE_KEY_PRODUCTION="$PRODUCTION_TURNSTILE_SITE_KEY" \
TURNSTILE_SITE_KEY_BETA="$BETA_TURNSTILE_SITE_KEY" \
  npm run assets:build:release

npx wrangler versions upload --config wrangler.demo-beta.jsonc \
  --tag "$RELEASE_TAG" --message "beta Demo $GITHUB_SHA" --strict
npx wrangler versions upload --config wrangler.beta.jsonc \
  --tag "$RELEASE_TAG" --message "beta landing $GITHUB_SHA" --strict \
  --secrets-file "$BETA_SITE_SECRETS_FILE"
npx wrangler versions upload --config wrangler.demo.jsonc \
  --tag "$RELEASE_TAG" --message "production Demo $GITHUB_SHA" --strict
npx wrangler versions upload --config wrangler.jsonc \
  --tag "$RELEASE_TAG" --message "production landing $GITHUB_SHA" --strict \
  --secrets-file "$PRODUCTION_SITE_SECRETS_FILE"
```

Record each returned version ID and compare the uploaded settings, asset count,
bindings, compatibility date, disabled previews, and disabled invocation logs
with the signed baseline. Do not attach a Custom Domain yet.

## Activate in the required order

The order is beta Demo, beta landing, production Demo, production landing, then
`www`. For a service, deploy the already-uploaded version to 100 percent while
the hostname is still unattached:

```sh
npx wrangler versions deploy --config wrangler.demo-beta.jsonc \
  --version-id "$BETA_DEMO_VERSION" --percentage 100 \
  --message "activate reviewed beta Demo" --yes
```

Attach only the current step's exact Custom Domain with the Cloudflare Workers
Domains API (`PUT /accounts/{account_id}/workers/domains`) or the equivalent
dashboard control. The request body contains only `hostname`, `service`, and the
known `zone_id`; never print the API token. Re-list domains immediately and
require the exact hostname/service pair before continuing. Repeat the same
version-deploy and exact-domain attachment for each subsequent host.

After every domain attachment:

1. Run both preserved API health probes first.
2. Capture DNS, TLS, status, response, cookie, and effective-header evidence.
3. Run the deployed browser flow. The landing must remain useful if Demo,
   Turnstile, or Neon fails; the Demo must navigate and reset without auth or
   persistent browser state.
4. Record the exact version and Custom Domain owner. Stop rather than inferring
   a target from a hostname or wildcard.

Once the phase baseline contains the observed fingerprints, run:

```sh
cd ritual-investing-site
npm run release:smoke -- \
  --baseline /private/path/release-baseline.sealed.json \
  --environment beta
```

The smoke command fails on DNS, TLS, status, response, CSP, indexing, or cookie
drift and includes both API hosts in every run. Use `--environment production`
for the production phase. `www.just-build-this.app` is attached last to the
production landing Worker and must return `308` to the same apex path/query.

## Beta waitlist and rollback rehearsal

Keep `WAITLIST_SUBMISSIONS=off` until static, Demo, security-header, provider-
console, grant, retention, and privacy-delivery evidence is accepted. Then use a
synthetic `.invalid` address and the real beta Turnstile widget to prove:

- valid submission creates one immutable row;
- a normalized duplicate preserves the original notice version and timestamp;
- malformed, replayed, wrong-host, wrong-action, throttled, disabled, and
  abuse-control-outage requests write zero rows;
- Neon outage returns only the sanitized retryable response and retains no PII
  in application or provider logs;
- re-disabling submissions preserves the landing and Demo.

Rehearse both landing and Demo rollback while beta submissions are off:

```sh
npx wrangler rollback "$BETA_LANDING_ROLLBACK_VERSION" \
  --config wrangler.beta.jsonc --message "beta landing compatibility rehearsal" --yes
npx wrangler rollback "$BETA_DEMO_ROLLBACK_VERSION" \
  --config wrangler.demo-beta.jsonc --message "beta Demo compatibility rehearsal" --yes
```

Prove current/previous protocol `2`/`1` interoperability, pairwise framing, API
preservation, unchanged Neon schema/rows, and return to the reviewed current
versions. An incompatible pair cannot advance to production.

## Production activation and synthetic-row cleanup

Before enabling production submissions, use the owner connection to record the
aggregate table count. It must equal the signed baseline. Within five minutes of
enabling submissions:

1. submit one synthetic `.invalid` address;
2. prove duplicate immutability and invalid zero-write cases;
3. verify mailbox possession through the reviewed privacy procedure;
4. run `npm run waitlist:remove` using a private email file;
5. prove the aggregate count returned to baseline; and
6. inspect the denial journal/evidence to confirm it contains only the keyed
   digest and database-owned timestamp, never the address.

If the count does not return to baseline, turn submissions off and stop. Do not
delete rows directly or edit the journal.

## Retention, removal, and restore

The database cutoff is fixed at 23 months 29 days so active rows cannot reach 24
months. The Worker retries the daily purge three times and emits an overdue
event after a 48-hour checkpoint gap. Check the owner aggregate and the external
checkpoint without serializing any row:

```sh
cd ritual-investing-site
WAITLIST_OWNER_DATABASE_URL='<managed-owner-url>' \
RETENTION_LAST_SUCCESS_AT='<canonical-KV-checkpoint>' \
npm run retention:check
```

The command prints only active, expiring-within-seven-days, and expired counts.
Any expired row or overdue checkpoint is a failure and alert.

For mailbox-possession removal, accept the address only in a mode-`0600` private
file. Run `waitlist:remove` with the environment's maintenance URL and denial
HMAC key, then destroy the private input. A response is non-enumerating whether
or not the row existed.

After any Neon restore:

1. keep the restored branch and waitlist host isolated;
2. set submissions off and rotate the restored runtime capability;
3. supply every denial address through the approved secure replay input;
4. run `waitlist:restore-replay -- --traffic-gated`;
5. run the fixed-cutoff purge and `retention:check`;
6. verify denial-journal completeness/checksum and effective grants; and
7. permit traffic only after the privacy data steward and go/no-go owner sign
   the replay evidence.

Missing, corrupt, or incomplete denial input is a cutover blocker. Never waive
replay because the provider restore appears recent.

## Stop, rollback, and evidence cadence

- Preflight stop: unexplained DNS/wildcard state, migration/checksum or grant
  drift, domain-scoped credential, missing privacy delivery, environment
  overlap, or API baseline mismatch.
- Activation stop: any forbidden Demo request, invalid-request database write,
  PII/token log, trust/CSP failure, or API synthetic failure.
- Roll back the affected Worker after three consecutive synthetic failures, or
  when relevant Worker/Neon/Turnstile failures exceed 1 percent for five minutes
  with at least 20 attempts.
- Investigate Demo ready timeouts above 1 percent for 15 minutes with at least 20
  sessions, or endpoint p95 above twice the beta baseline for 15 minutes with at
  least 50 attempts.
- Record redacted proof before activation, within five minutes of every host
  activation, and at +1 hour, +4 hours, and +24 hours.

Rollback only the affected Worker version first. Keep the additive waitlist
schema and provisional rows. If writes must stop, restore the previous landing
version and keep submissions off; rotate/revoke only the compromised waitlist
capability. A partially applied migration requires reviewed forward repair.
Custom Domain detachment is a last resort because it changes DNS/TLS state; if
used, identify the exact domain ID from a fresh read-only list and recheck both
API hosts immediately.

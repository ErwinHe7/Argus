# Public beta web deployment handoff

Status date: 2026-08-30

Current status: **NO-GO / not executed**. Empty, `pending`, stale, or
mismatched evidence is a stop condition; an upload is not launch evidence.

Read-only Cloudflare inventory currently shows no Pages projects. The apex is
served by asset-only Worker `ritual-investing-site`, active deployment
`6f961977-758a-45af-aba0-7be48dd0cb3c`, version
`0c7ea422-d2b6-4243-92f9-f2cc8d013b79`, tag `retention-a2bdeb9`. Recapture
those values at cutover. The new Worker is `ritual-investing-member`; its
landing and member bundles must be immutable versions of that same asset-only
Worker. Cloudflare gains no compute, binding, secret, storage, Auth, or data
authority.

## Frozen release record

| Evidence | Owner | Status/value |
| --- | --- | --- |
| Release commander, Cloudflare operator, Supabase operator, support/privacy owner | Product/operations | `pending` |
| UTC window, exact Git revision, protected workflow run IDs | Release operator | `pending` |
| Legacy Worker/domain ID, deployment, version, tag | Cloudflare operator | Values above; domain ID `pending` |
| New Worker landing/member versions and deployment IDs | Cloudflare operator | `pending` |
| Before/after DNS and TLS captures | Cloudflare operator | `pending` |
| Dedicated beta project/schema/Edge/Auth/CORS/content fingerprints | Supabase operator | `pending` |
| Backup freshness, restore drill, approved RPO/RTO and quotas | Supabase operator | `pending` |
| Durable counts, privacy queue/SLA, admission and fence states | Supabase operator | `pending` |

The `argus-member-web-release/v1` manifest has exactly these workflow-validated
keys:

```text
artifact_manifest_sha256  auth_sha256          background_workers
backup_id                 content_sha256       contract_version
cors_sha256               edge_revision        git_revision
landing_artifact_sha256   landing_rollback_version_id
order_mutations           preview_accepted     provider_egress
restore_drill_id          schema_sha256         supabase_project_ref
worker_name               worker_version_id
```

The three fence fields must be `true`. `worker_version_id` is null only for
preview upload. Approve a promotion manifest with `preview_accepted=true` only
after acceptance actually passes. Retain the stable preview URL, domain
snapshots, workflow artifacts, browser/accessibility/network evidence,
observations, and approvals beside the manifest, without credentials or member
identifiers.

The protected variable `BETA_MEMBER_PREVIEW_ORIGIN` must be the exact stable
Wrangler alias origin,
`https://beta-ritual-investing-member.<account-subdomain>.workers.dev`. The
same exact origin must appear in Edge CORS and Supabase Auth redirects. Wildcard
and per-version preview origins are forbidden.

## Dedicated beta prerequisites

Before domain cutover, the Supabase operator must prove the target is a
dedicated durable beta project—not production or the replaceable staging
branch—and record:

- invite-only Auth with custom SMTP, resend, enumeration-resistant recovery,
  rate limits, exact apex/preview `/mobile/argus-auth/callback` redirects, a
  recovery email template that sends `token_hash` with `type=recovery`, and the
  accepted deletion path;
- the reviewed publishable-key digest and exact `/functions/v1/api` URL on the
  same beta Supabase origin; no elevated key in the bundle;
- exact apex/preview/admin CORS, no browser application-table grants, private
  RLS, indexes, tenant denial, session validation, and Data API denial;
- old Edge/new schema and new Edge/new schema bootstrap and supported
  read/write compatibility using additive changes only;
- content, privacy, cleanup parity, queues, advisors, backup/restore, RPO/RTO,
  quotas, and named support ownership; and
- `provider_egress` and `order_mutations` still fenced. Only the protected
  Supabase workflow may resume background work.

Use [`supabase-operations-runbook.md`](supabase-operations-runbook.md). Do not
migrate, restore, or deploy from a laptop.

## Exact landing-to-member sequence

All mutations use protected credentials and pinned Wrangler. Replace angle
brackets only from the reviewed record.

1. While `ritual-investing-site` owns the apex, run the protected web workflow
   with `action=preview`. Record the stable `beta` preview and member version.
   On mobile Safari and Chrome, accept invitation, recovery, refresh,
   onboarding, bodyless bootstrap, direct reload, supported routes, export,
   deletion/manual SLA, cross-tab logout, 200% text, reduced motion, narrow
   landscape, focus/history, screen reader, cache, CSP, and network allowlist.

2. Upload the unchanged landing to `ritual-investing-member` and deploy it at
   100% before moving the domain:

   ```sh
   cd ritual-investing-site
   npx --no-install wrangler versions upload --config wrangler.landing.jsonc \
     --name ritual-investing-member --tag "<landing-artifact-sha256>" \
     --message "landing:<release-manifest-sha256>" --strict
   npx --no-install wrangler versions deploy \
     "<landing-version-id>@100%" --name ritual-investing-member \
     --message "landing-domain-soak:<release-manifest-sha256>" --yes
   npx --no-install wrangler versions view "<landing-version-id>" \
     --name ritual-investing-member --json
   ```

3. Record Worker-domain JSON, DNS, and TLS. Repoint only the apex custom domain
   from `ritual-investing-site` to `ritual-investing-member`; keep the legacy
   Worker/version intact as the separate domain recovery target:

   ```sh
   curl -sS "https://api.cloudflare.com/client/v4/accounts/<account-id>/workers/domains" \
     -X PUT -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     -H 'Content-Type: application/json' \
     --data '{"hostname":"just-build-this.app","service":"ritual-investing-member","zone_id":"<zone-id>","zone_name":"just-build-this.app"}'
   ```

   Soak the landing at the apex and verify DNS, TLS, root, callback,
   privacy/legal, support, cache, and unknown routes.

4. On `ritual-investing-member`, keep landing at 100%, add the frozen member
   at 0%, and smoke the member explicitly in apex context:

   ```sh
   cd ritual-investing-site
   npx --no-install wrangler versions deploy \
     "<landing-version-id>@100%" "<member-version-id>@0%" \
     --name ritual-investing-member \
     --message "apex-smoke:<release-manifest-sha256>" --yes
   curl -sS https://just-build-this.app/ \
     -H 'Cloudflare-Workers-Version-Overrides: ritual-investing-member="<member-version-id>"'
   ```

   Prove the override applied and repeat callback, direct-route, legal,
   support, cache, CSP, and network checks. Any manifest drift is NO-GO.

5. Reconfirm all gates, then run the protected web workflow with
   `action=promote`. It must deploy the recorded member version at 100% without
   rebuilding, uploading, moving the preview alias, or changing the backend.

## Go/no-go and observation

| Boundary | Go only when | Status |
| --- | --- | --- |
| Backend | Dedicated-beta prerequisites and mixed-version checks have signed evidence | `NO-GO: exact project unknown` |
| Preview | Auth/privacy/tenant/fence/mobile/cache/CSP/network acceptance passes | `NO-GO: not observed` |
| Domain | New Worker landing is active and legacy recovery values are frozen | `NO-GO: not executed` |
| Promotion | Domain soak and 0% apex override smoke pass unchanged manifest/backend checks | `NO-GO: not observed` |
| Closure | Four checkpoints and three recovery rehearsals pass | `NO-GO: pending` |

Each checkpoint records planned/actual UTC, owner, result, evidence link,
Cloudflare availability/asset coherence, Auth/invite/recovery, Edge revision
and errors, schema/database health, queue depth/age and expired leases, privacy
queue/SLA, admission and all fences, sensitive/network violations, and support
incidents.

| Checkpoint | Owner | Status |
| --- | --- | --- |
| Immediate | `<release-operator>` | `pending` |
| +1h | `<supabase-operator>` | `pending` |
| +4h | `<release-operator>` | `pending` |
| +24h | `<release-commander>` | `pending` |

Immediately contain any security, cross-tenant/data, sensitive-log, CORS, or
financial-fence breach. Restore the landing after two consecutive critical
synthetic failures within five minutes.

## Separate recovery rehearsals

Record UTC start/end, owner, exact target, action, result, and evidence.

| Rehearsal | Owner | Command/action | Status |
| --- | --- | --- | --- |
| Frontend | `<release-operator>` | Run protected web workflow `action=rollback` with the frozen manifest/digest and `landing_rollback_version_id`; verify apex landing and active deployment | `pending` |
| Domain | `<cloudflare-operator>` | PUT the apex Worker domain back to `ritual-investing-site`; verify its frozen deployment/version/tag, DNS, TLS, and root/legal/support routes | `pending` |
| Backend/Auth/data | `<supabase-operator>` | Set exact-beta `ARGUS_WEB_ADMISSION=contained`; if effects may be unsafe run `psql "$SUPABASE_DB_URL" -X -v ON_ERROR_STOP=1 -f scripts/fence-supabase-deployment.sql`; prove privacy request/status remains reachable, then fix forward or use only the manifest-bound managed restore | `pending` |

Domain rollback command:

```sh
curl -sS "https://api.cloudflare.com/client/v4/accounts/<account-id>/workers/domains" \
  -X PUT -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H 'Content-Type: application/json' \
  --data '{"hostname":"just-build-this.app","service":"ritual-investing-site","zone_id":"<zone-id>","zone_name":"just-build-this.app"}'
```

Backend containment is not data rollback. Preserve privacy requests, receipts,
leases, idempotency, and ambiguous effects. Managed restore is allowed only
with the exact backup, restore drill, recovery coverage, RPO/RTO,
reconciliation, and approvals in
[`supabase-recovery-coverage.md`](supabase-recovery-coverage.md).

## External blockers

- Supabase login awaits user verification; the dedicated beta project,
  hosted acceptance, backup, restore drill, and recovery posture are unknown.
- Protected workflow runs and operator approvals have not been supplied.
- No landing/member versions on `ritual-investing-member`, domain cutover,
  preview/apex acceptance, checkpoint, or recovery rehearsal is recorded.

Until those blockers close, do not move or promote the apex.

# Production launch gates

Production is blocked until every item below has a named owner, dated evidence,
and rollback authority. A pre-production deployment does not waive a gate.

The invite-first public web beta is not a production launch and does not
redesign the retained landing artifact, standalone Demo, or member product
behavior. The clearly labeled member Worker may own the apex while the
unchanged landing stays available as the tested rollback and Pages-hosted
recovery surface. Cloudflare's member role is limited to compiled static
assets, and the browser uses only the persistent `beta` branch of the Ritual
Investment Supabase project, versioned beta Argus API, and canonical private
tables. Supported routes,
including authorized privacy export and API-backed or verified-manual-SLA
deletion, are beta-backed launch requirements. Brokerage connection and reads,
funding, and order mutations remain visibly unavailable and fail closed; any
standalone Demo handoff is explicit and never a failure fallback. Open signup
remains disabled until the additional hosted confirmation and abuse gates pass.
The beta's unresolved review work is uniformly tracked as P1 in
[`public-beta-web-p1-follow-up-register.md`](public-beta-web-p1-follow-up-register.md);
that priority classification does not waive the privacy launch requirement,
these production gates, or unavailable financial capability fences.

- Provision a separate production Supabase project and confirm its exact ref,
  database hostname, quotas, network policy, and protected deployment environment.
- Select and test production SMTP, account recovery, and abuse controls.
- Select backup/PITR, restore-drill cadence, retention, deletion evidence, and
  recovery-time/recovery-point objectives. The Free plan is not assumed to meet
  these requirements; record the Free-to-Pro trigger before launch.
- Select monitoring, paging, log retention, queue/DLQ ownership, and incident
  response for Auth, Postgres, Storage, Cron, and Edge Functions.
- Select and secure the production admin hosting boundary. Cloudflare Pages is
  reserved for the public static landing/Demo sites and is not the default admin
  authority.
- Complete the Webull partner protocol gate described in
  `webull-operations-runbook.md`. Until then, real Webull egress and every order
  mutation remain blocked.
- Verify the static Pages inventory contains no Functions, `_worker.js`, route,
  Queue, R2, D1, service, Durable Object, or cron binding.
- Revoke Auth0, Neon, API Worker, Queue, R2, and obsolete Cloudflare credentials;
  prove old routes fail; then remove the resources. Do not run dual auth or dual
  database authority during rollback.
- Run the complete CI matrix, clean migration replay, pgTAP suite, Edge tests,
  generated-contract drift check, hosted revision handshake, member/admin smoke,
  privacy export/delete proof, and recovery drills.
- Run `scripts/check-supabase-hosted-acceptance.sh` against the exact production
  target and retain its Auth, queue, Storage, schema, limit, fence, and Edge
  revision evidence.
- Keep Starpath production capability disabled until RC1 proves the fresh,
  server-authoritative production branch order Ritual → Starpath → You at both
  bootstrap and protected APIs. Discover and Coven must be absent from tabs,
  restored state, deep links, and protected resources. Missing, expired,
  unknown, or downgraded capability data must fail closed, and the release
  operator must retain a tested rollback/re-enable record.
- Keep Starpath production capability disabled until all eight exact lesson
  revisions have distinct factual and compliance attestations, the immutable
  manifest projection matches `starpath-curriculum-v1.md`, and legal counsel has
  approved the exact `starpath-no-advice-v1` document hash for production, US,
  its effective/expiry window, and the current R20 trigger snapshot. Missing,
  stale, superseded, invalidated, or differently scoped evidence is a NO-GO;
  dashboard or beta completion is not production approval. Legal validates the
  versioned policy boundary, not each routine factual lesson revision.
- Confirm the served Starpath response, Rowan copy, telemetry, and aggregate
  retention snapshot contain no holdings, balances, orders, investor-profile
  answers, astrology profile, security preference, inferred investment intent,
  recommendation, ranking, guarantee, urgency, or investment action. Record the
  first `learning_retention_within_7d_v1` checksummed baseline without inventing
  a target or exposing member-level output.
- Exercise Starpath rollback by disabling its release capability without
  reversing schema or weakening reads, export, purge, or deletion fencing.
  Re-enable the same still-valid manifest and prove zero dangling references.

Launch remains **NO-GO** while any item is missing. In particular, the current
Webull partner protocol decision is unresolved, RC1 release-control evidence is
external and not yet attached, and RC3 legal evidence has not been supplied in
the repository. Therefore real brokerage egress and Starpath production
enablement remain blocked.

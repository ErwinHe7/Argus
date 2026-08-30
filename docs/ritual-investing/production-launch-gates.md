# Production launch gates

Production is blocked until every item below has a named owner, dated evidence,
and rollback authority. A pre-production deployment does not waive a gate.

The invite-first public web beta is not a production launch and does not
redesign the retained landing artifact, standalone Demo, or member product
behavior. The clearly labeled member Worker may own the apex while the
unchanged landing stays available as the tested rollback and Pages-hosted
recovery surface. Cloudflare's member role is limited to compiled static
assets, and the browser uses only the dedicated beta Supabase project,
versioned beta Argus API, and canonical private tables. Supported routes,
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

Launch remains **NO-GO** while any item is missing. In particular, the current
Webull partner protocol decision is unresolved, so real brokerage egress cannot
be enabled.

# Ritual Investing Cloudflare runbook

## Production bindings

The Worker requires explicit environment-specific bindings for rate limiters, Queue and DLQ, R2 quarantine/public/export buckets, admin static assets, restricted database URLs (including `AUDIT_DATABASE_URL`), deletion-deny journal, Auth0 and Access issuers/audiences, and cursor signing. `wrangler deploy --dry-run` and Worker tests must pass before promotion. Production secrets belong in managed bindings, never `wrangler.toml`, logs, or build artifacts.

Public projections alone may use shared caching. Cache keys use the API origin, normalized allowlisted query parameters, and published revision. Member and staff responses are `private, no-store`. Authorization, cookies, tenant identifiers, and request bodies never enter public cache keys or telemetry.

## Queue, DLQ, and kill switches

Start a new consumer at low concurrency, observe receipts/backlog, then raise toward the checked envelope of 20 consumers. Delivery is at-least-once: consumer receipts, aggregate watermarks, generation/deletion fences, and deterministic object keys make retries safe. Acknowledgement occurs only after the durable receipt. Inspect DLQ metadata by outbox ID, consumer, attempt, and allowlisted failure code; do not inspect or replay raw provider bodies.

The staging load job uses a managed pool of at least 100 non-production actors, never one shared bearer token. Commands group four concurrent requests per actor/portfolio and rotate groups to remain inside the declared command-rate budget. Public traffic must be launched through the approved distributed load runner so the production IP rate limiter is exercised across visitors rather than bypassed. The allowlisted capacity probe independently reports seeded tenant count, minimum ledger depth, Queue backlog, consumer concurrency, drain time, and p95 lag.

Kill switches are route-scoped and default off: scheduled work, Queue, notifications, exports, purge, and media. Turning one on pauses new effects but does not loosen authentication or database policy. Record operator, reason, timestamp, affected consumers, and rollback condition in immutable staff audit. Resume at low concurrency and confirm monotonic watermarks.

## Alert response

Fixtures in `ritual-investing-api/ops/alert-fixtures.v1.json` cover HTTP error/latency/rate-limit ratios, authorization denials, dependency health, Queue age/DLQ, RLS/idempotency/stale work, privacy deadlines, quarantine age, publication/cache purge, and audit parity.

1. Confirm the alert is not a telemetry ingestion failure using request IDs and allowlisted codes only.
2. For dependency loss, preserve fail-closed behavior and enable the narrow kill switch if retries could increase harm.
3. For DLQ or stale-work spikes, stop the affected consumer, verify reset/deletion generations, then use the audited admin retry seam.
4. For publication/cache-purge failure, execute emergency withdrawal and purge the exact publication cache tag. Objective: prior revision unavailable at the edge within five minutes.
5. For latency, run the capacity envelope and compare cache hit/miss, database, and Queue segments. Do not raise limits before finding the constrained segment.

## Promotion and rollback

Promote development → staging → production. Apply database expand/backfill/verify first, deploy an N-1/N-compatible Worker canary, verify cache and consumers, switch traffic, then contract only after the released-client drain gate. Prefer roll-forward. Worker rollback is allowed only while schema compatibility remains; migrations are not rolled back destructively. Store external-binding proof using the redacted staging template.

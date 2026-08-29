# Supabase performance and operations budget v1

contract_version: supabase-performance-operations-budget-v1

These are release gates. U1 had no disposable local stack or hosted
authorization, so every initially unmeasured threshold was recorded as an
explicitly owned TBD gate. U4 now supplies the local, single-session evidence
below for its owner-list and publication-read slices. U4-U8 must still complete
the stated concurrency and hosted measurements before each capability can pass
U9.

## Representative workload v1

| Family | Fixture volume and concurrency | Latency / plan budget | Owner and unresolved gate |
|---|---|---|---|
| Owner lists | 100k members; heavy member has 10k notifications, 2k saved items, 1k briefings, 1k ritual assignments and 1k Circles; 100 concurrent API requests | p95 <= 250 ms, p99 <= 750 ms; keyset page <= 100; no sequential scan over tenant table; local index/buffer baseline below | U4 local plan gate is measured; U8/U9 still own concurrent API p95 and hosted-plan confirmation. |
| Editorial publication/render | 25k items, 10 revisions/item, 50 ordered children/revision; 10 concurrent publishers and 200 readers | publication transaction p95 <= 500 ms and <= 2 s hard; public render p95 <= 200 ms; no cross-revision nested loop explosion; local read baseline below | U4 local current-publication read gate is measured; concurrent publish/read and 50-child transaction volume remain U9 gates. |
| Discovery/search | 250k searchable entities across categories, 1m relationship rows; 100 concurrent readers | p95 <= 300 ms, p99 <= 900 ms; stable keyset page <= 50; no application concatenation/offset scan | U8 search owner selects index and approves buffer ceiling. |
| Outbox relay | 1m total, 100k due, batch 25; 8 concurrent relays | claim transaction p95 <= 100 ms, hard <= 1 s; `SKIP LOCKED`; <= 500 shared buffers TBD | U6 jobs owner measures duplicate relay and lock wait. |
| Job claims/retries | 1m runs/5m attempts, 100k queued/retry; 16 worker deliveries | claim/complete p95 <= 150 ms, hard <= 1 s; one row lock order; no table scan | U6 jobs owner replaces buffer TBD. |
| Privacy export/purge | heavy lifecycle: 100k product rows and 10k objects; 4 concurrent generations/purges | prepare transaction <= 2 s; each page <= 500 rows and p95 <= 250 ms; external assembly deadline/batch TBD | U6 privacy owner selects batch/time budget after measurement. |
| Brokerage projections | 100 accounts/member max fixture, 1m general and 2m order generations; 100 read requests, 8 refreshes | latest projection p95 <= 200 ms; append transaction <= 500 ms; no stale-provider timestamp substitution | U5 brokerage owner approves buffer ceiling. |
| Webull recovery | 100k commands, 10k ambiguous, 16 concurrent reconcilers | claim/transition p95 <= 150 ms, hard <= 1 s; account lock wait <= 3 s; lookup age gate below | U5 local 16-way claim and lock-order gates are measured; hosted contention and provider lookup latency remain U9 gates. |
| Waitlist | 1m retained submissions; 100 requests/s burst | DB submit p95 <= 150 ms; Edge p95 <= 1 s excluding Turnstile, hard dependency deadline 3 s | Platform owner validates advisory-lock contention. |

## U4 local representative plan evidence

On 2026-08-29, PostgreSQL 17 on the disposable local Supabase stack was reset
with pinned CLI `2.115.0` and U4 migration SHA-256
`75db53a7b0c7b806d00c315cf5607a132a28da7d6de5994ae66b716c9d0ec9b6`.
A rollback-only fixture loaded 100k lifecycle/member roots, the heavy-owner
volumes above, 25k editorial items, 250k revisions, and 25k current sealed
render documents. Every query returned a page of 100; all critical returned
nodes estimated 100 rows, all owner paths used the named lifecycle-leading
index, and no plan spilled to temporary storage.

| U4 query slice | Index / boundary | Execution | Shared hit + read blocks | Remaining gate |
|---|---|---:|---:|---|
| Notifications owner page | `notifications_u4_owner_order_idx` | 33.633 ms cold | 369 + 36 | Concurrent/API p95 and warm hosted plan in U9. |
| Ready briefings owner page | `briefings_u4_owner_ready_order_idx` | 0.792 ms | 40 + 1 | Concurrent/API p95 in U9. |
| Typed saved-items owner page | `member_saved_items_owner_order_idx` | 0.461 ms | 75 + 1 | Concurrent/API p95 in U9. |
| Ritual-assignment owner page | `daily_ritual_assignments_u4_owner_order_idx` | 0.337 ms | 40 + 1 | Concurrent/API p95 in U9. |
| Circle owner page | `circles_u4_owner_order_idx` | 0.558 ms | 127 + 0 | Concurrent/API p95 in U9. |
| Current published editorial page | bounded `list_current_published_editorial(text,integer)` function | 6.320 ms | 1229 + 14 | Concurrent readers/publishers and 50 ordered children per revision in U9. |

These values are approved as the U4 local regression baseline, not as hosted
p95 evidence. The general 2x buffer-regression gate below applies to these
baselines; the concurrency rows remain blocking until U9 records them.

## U5 local representative plan evidence

U5 uses two disposable-local, self-cleaning harnesses. Run
`scripts/measure-u5-brokerage-plans.sql` with `psql -X -f` after a clean replay;
its single transaction loads 100 members with 100 accounts each, 1m general
projection generations, 2m typed order generations, 100k provider commands,
and 10k due ambiguous reconciliations, captures `EXPLAIN (ANALYZE, BUFFERS)`
for the four critical query slices below, and rolls back. Then run
`ritual-investing-api/scripts/verify-u5-brokerage-lock-order.mjs` against the
same local database. It measures 16 simultaneous bounded reconciliation
claims, exercises token-refresh, projection-refresh, and command-recovery
scope guards concurrently, proves list ingestion serializes with a connection
fence, removes its fixed fixture, and refuses a non-loopback database URL.

| U5 query slice | Required boundary | Local execution / buffers |
|---|---|---|
| Latest ready typed projection | Lifecycle-leading latest-generation index; <= 200 ms | 16.104 ms; `projection_generations_u5_latest_idx`; shared hit 631/read 47/dirtied 1; local hit 10/read 2. |
| Append next-generation lookup | Parent-qualified generation lookup; append transaction <= 500 ms | 46.037 ms; `projection_generations_u5_parent_unique`; 100 rows scanned; shared hit 1/read 287/dirtied 1; local hit 9. |
| Account-scoped ambiguity gate | Lifecycle/user/account/state index; <= 150 ms | 0.098 ms; `one_ambiguous_command_per_account`; shared hit 3; local hit 12. |
| Due reconciliation queue claim | Due partial index plus command identity; <= 150 ms and `SKIP LOCKED` only here | 17.353 ms; 10k due rows, 25 locked; shared hit 783/read 2; 931 kB quicksort, no spill. |

The local 16-way bounded reconciliation claim p95 was 91.130 ms. Token refresh,
projection refresh, and command recovery acquired their common guards without
deadlock; list ingestion completed before reauthorization, and the post-fence
list write was rejected. Loading 1m general generations took 210736.696 ms and
2m typed order generations took 653029.291 ms; those rollback-only fixture-load
times are informational and are not application query budgets. The
100-read/8-refresh concurrency mix, hosted plans, and provider lookup latency
remain explicit U9 gates; local evidence does not claim them.

## U6 durable-work measurement status

U6 does not increase relay, claim, or worker concurrency. It replaces the
mixed runtime paths with bounded `SKIP LOCKED` queue claims, a registry-owned
maximum-attempt/visibility policy, short prepare/effect/complete checkpoints,
and one redacted staff signal surface. The signal inventory covers queue depth
and oldest age, expired leases, attempts, dead letters, Cron/dispatch failures,
external-effect and Storage reconciliation, lock waits, and worker runtime p95.

The focused disposable-local pgTAP contract proves registry/Cron parity,
duplicate relay and delivery idempotency, poison-message handling, immutable
effect identities, lease-loss denial, deterministic sealed export generations,
and truthful Storage/media state. Representative 1m-outbox, 5m-attempt,
100k-row/10k-object export volumes and 8/16-way concurrency timings are not
fabricated from that behavioral suite: they remain blocking U9 load gates
against the budgets above. Hosted PGMQ visibility/delay/archive behavior,
Cron execution, Auth/Storage effects, orphan reconciliation, and dashboard
signal collection likewise require managed-service evidence before promotion.

## Database, pool and transaction budgets

| Signal | Warning | Hard gate |
|---|---|---|
| API statement timeout | 10 s | Existing role hard limit 15 s; any request reaching it fails U9. |
| Worker statement timeout | 30 s | Existing role hard limit 45 s; effect calls must not consume this inside a transaction. |
| Waitlist statement timeout | 5 s | Existing role hard limit 10 s. |
| Lock wait | p95 <= 100 ms; any p99 > 500 ms reviewed | Role `lock_timeout`: API/worker 3 s, waitlist 2 s; any timeout rate > 0.1% over 5 min is no-go. |
| Transaction duration | p95 <= 500 ms API/worker claims | 2 s hard for privacy/editorial prepare; no external HTTP/Auth/Storage/Webull call while open. |
| Idle in transaction | zero expected | Existing role hard limit 15 s API/worker, 10 s waitlist. |
| Pool use | warning at 70% of per-role pool; queue rather than open owner connection | Local baseline 20 server / 100 client; hosted per-role pool and max-client values are U2 TBD and must be recorded before load test. |
| Connection checkout | p95 <= 50 ms | p99 <= 250 ms for 5 min; reject promotion on saturation/owner-DSN use. |
| Trusted request context age | warning at 10 s from installation | 60 s hard expiry; missing/malformed context, a closed lifecycle, a changed backend/transaction, or context reuse after completion denies authority. |
| Query estimates | <= 10x actual on critical families | > 100x or plan flip to full tenant scan is no-go. |
| Shared buffers | Per-family ceilings are owned TBD above | Any regression > 2x the approved baseline or temp spill on keyset/claim paths is no-go. |

## Queue, retry and dead-letter budgets

| Signal | Warning | Hard gate |
|---|---|---|
| Oldest due outbox age | 30 s | 120 s for 5 min. |
| Oldest visible queue age | 60 s | 300 s for retained jobs; 60 s for Webull ambiguity work. |
| Ready queue depth | 1,000 retained / 100 brokerage | 10,000 retained or 1,000 brokerage for 5 min. |
| Duplicate delivery | Expected and idempotently absorbed | Any duplicate external effect or duplicate financial submission. |
| Retry rate | > 2%/5 min warning | > 10%/5 min or max-attempt exhaustion above 0.1%. |
| Dead-letter rate | Any event pages owner | > 0.1%/15 min or any unclassified reason/handler. |
| Lease expiry | > 0.5% warning | > 2%/15 min or completion after lease loss. |
| Consumer receipt conflict | Expected only for true duplicate | Any mismatched effect hash for the same event/handler. |

## Edge, Auth, Storage and provider budgets

| Signal | Warning | Hard gate |
|---|---|---|
| API 5xx | > 0.5%/5 min | > 2%/5 min; auth/config failures are separated from product 4xx. |
| Worker 5xx | > 1%/5 min | > 5%/5 min or unavailable for 2 consecutive Cron intervals. |
| Callback invalid/5xx | invalid spikes > 3x baseline; any 5xx warning | Any state replay accepted, wrong-environment completion, or 5xx > 2%/5 min. |
| Waitlist 5xx | > 1%/5 min | > 5%/5 min; 429 and Turnstile rejection remain separate. |
| Auth token verification errors | > 1% by stable reason warning | Any wrong issuer/audience/session accepted; JWKS outage > 60 s blocks traffic. |
| Auth admin deletion | any unknown outcome warning | Completion cannot be recorded until absence reconciles. |
| Storage errors | > 1% per effect type warning | Changed hash/key, cross-lifecycle signed URL, or generation marked complete with missing object. |
| Webull read latency | Provider p95 TBD from approved sandbox fixture | Adapter deadline/retry count owned by U5 before opening egress; stale/partial truth never presented as fresh. |
| Webull ambiguous command rate | Any event is reviewed; > 0.1% warning | Any second submit, generic worker execute path, or ambiguity fence failure. |
| Webull ambiguity age | 5 min warning | 15 min to manual review unless approved provider contract sets a stricter bound. |
| Webull refresh ambiguity | Any event warning | Old refresh credential is never retried after unknown post-response outcome. |

## Observation and ownership

U9 records each signal at immediate, +1h, +4h and +24h checkpoints. The
database performance owner approves query/buffer/lock/pool gates; the jobs
owner approves queue/retry/DLQ gates; identity/security approves Auth/Edge
errors; privacy approves manifests and Storage; brokerage approves provider
latency and ambiguity. A TBD blocks only its capability, never silently adopts
an inferred default. Cross-tenant access, duplicate financial effect,
schema/build mismatch, unexplained drift, or any hard gate is an immediate
no-go regardless of aggregate latency.

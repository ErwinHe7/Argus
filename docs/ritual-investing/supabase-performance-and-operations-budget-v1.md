# Supabase performance and operations budget v1

contract_version: supabase-performance-operations-budget-v1

These are release gates, not U1 measurements. U1 had no disposable local stack
or hosted authorization, so every unmeasured threshold is an explicitly owned
TBD gate. U4-U8 must seed representative data, capture `EXPLAIN (ANALYZE,
BUFFERS)`, and replace TBDs before the affected capability can pass U9.

## Representative workload v1

| Family | Fixture volume and concurrency | Latency / plan budget | Owner and unresolved gate |
|---|---|---|---|
| Owner lists | 100k members; heavy member has 10k notifications, 2k saved items, 1k briefings; 100 concurrent API requests | p95 <= 250 ms, p99 <= 750 ms; keyset page <= 100; no sequential scan over tenant table; shared reads TBD after seed | U4/U8 database owner must approve buffers and row-estimate error <= 10x. |
| Editorial publication/render | 25k items, 10 revisions/item, 50 ordered children/revision; 10 concurrent publishers and 200 readers | publication transaction p95 <= 500 ms and <= 2 s hard; public render p95 <= 200 ms; no cross-revision nested loop explosion | U4 editorial owner sets buffer ceiling after normalized schema. |
| Discovery/search | 250k searchable entities across categories, 1m relationship rows; 100 concurrent readers | p95 <= 300 ms, p99 <= 900 ms; stable keyset page <= 50; no application concatenation/offset scan | U8 search owner selects index and approves buffer ceiling. |
| Outbox relay | 1m total, 100k due, batch 25; 8 concurrent relays | claim transaction p95 <= 100 ms, hard <= 1 s; `SKIP LOCKED`; <= 500 shared buffers TBD | U6 jobs owner measures duplicate relay and lock wait. |
| Job claims/retries | 1m runs/5m attempts, 100k queued/retry; 16 worker deliveries | claim/complete p95 <= 150 ms, hard <= 1 s; one row lock order; no table scan | U6 jobs owner replaces buffer TBD. |
| Privacy export/purge | heavy lifecycle: 100k product rows and 10k objects; 4 concurrent generations/purges | prepare transaction <= 2 s; each page <= 500 rows and p95 <= 250 ms; external assembly deadline/batch TBD | U6 privacy owner selects batch/time budget after measurement. |
| Brokerage projections | 100 accounts/member max fixture, 1m general and 2m order generations; 100 read requests, 8 refreshes | latest projection p95 <= 200 ms; append transaction <= 500 ms; no stale-provider timestamp substitution | U5 brokerage owner approves buffer ceiling. |
| Webull recovery | 100k commands, 10k ambiguous, 16 concurrent reconcilers | claim/transition p95 <= 150 ms, hard <= 1 s; account lock wait <= 3 s; lookup age gate below | U5 owner measures ambiguity contention and lookup provider budget. |
| Waitlist | 1m retained submissions; 100 requests/s burst | DB submit p95 <= 150 ms; Edge p95 <= 1 s excluding Turnstile, hard dependency deadline 3 s | Platform owner validates advisory-lock contention. |

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

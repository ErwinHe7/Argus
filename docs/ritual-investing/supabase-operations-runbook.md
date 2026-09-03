# Supabase operations runbook

Supabase is the only backend authority for Ritual Investing. Postgres, Auth,
Storage, Edge Functions, Cron, and Queues are deployed from `supabase/`.
Cloudflare hosts static Pages artifacts only; it has no API, authentication,
database, queue, object-storage, or scheduled-compute authority.

## Pull-request workflow

Pull requests and forks use no hosted credentials. CI starts a disposable local
Supabase stack, runs `supabase db reset`, executes `supabase test db`, repeats
the reset, and compares normalized replay manifests to prove exact replay
safety. It also runs error-level lint, local security and performance advisors,
and checks/tests every Edge Function with Deno. Flutter, generated-client, API,
admin, Demo, and static Pages checks run against local fixtures or the local
stack. A PR must never receive
`SUPABASE_ACCESS_TOKEN`, a database password, a secret key, or a hosted member
token.

Pull requests, pushes, and ordinary manual CI runs continue to use fresh local
stacks so untrusted or unapproved code never receives hosted credentials. The
ordinary `.github/workflows/ritual-investing-ci.yml` workflow has no hosted
schema, Edge, secret, fence, or deployment mutation authority. Approved
remediation promotions use only the separate manual
`.github/workflows/ritual-investing-supabase-remediation.yml` workflow and
target the dedicated Supabase staging project. The provider still exposes the
historical physical branch label `beta` for project ref `zbgjjufjkhfhirbuuolv`;
that unrenameable provider identity maps only to logical `staging` and is not a
fourth environment. The production project is a forbidden remediation target.
The staging project has its own database, Auth, API credentials, Edge secrets,
Cron, Queues, and Storage boundary.

## Hosted staging remediation

Only an explicit `workflow_dispatch` run may enter the protected
`ritual-supabase-remediation` GitHub authority environment. This is an
existing protected authority lane, not a fourth deployment environment, and
pushes never run this backend remediation. The
credential-free preflight selects one canonical main Fast CI run, its exact
attempt, retained artifact ID, source SHA, archive digest, and manifest digest.
It verifies the release contract, independently checks out the source and
workflow controller, and byte-compares the frozen migrations, functions, and
inventories. Only that independent source checkout may execute. The serialized
staging job then rechecks those bytes before any mutation. Existing authority
reviewers approve the exact manifest-bound values; no branch protection,
required status check, or push gate is added.

Staging variables and credentials must resolve to the logical staging project
(the legacy physical provider label described above), never production.
Promotions never cancel an in-flight deployment. A frozen source inventory is
provenance, not proof that hosted schema or functions are current: static
content requiring new backend behavior remains blocked until a matching,
unexpired staging backend receipt exists.

Before any fence or remote mutation, the operator prepares the canonical JSON
specified by `supabase-promotion-manifest.md`. The workflow recomputes its
SHA-256, requires the exact key set, and compares every approved value with the
protected environment. `scripts/check-supabase-deploy-target.ts` then verifies:

- the exact repository and `refs/heads/main` ref;
- a manual event and exact checked-out Git revision;
- the exact hosted project ref;
- a direct database hostname derived from that ref, or an explicitly
  allowlisted transaction-pooler hostname; and
- a matching `postgres` / `postgres.<project-ref>` owner username, direct port
  `5432` or transaction-pooler port `6543`, and required TLS mode;
- the migration-inventory checksum, source and target fingerprints, boundary
  inventory checksum, backup and restore-drill records, recovery-coverage
  checksum, release/recovery/security approvals, maintenance admission, and
  three independent fence states.

The workflow first captures and verifies the existing normalized hosted target,
then independently enables `background_workers`, `provider_egress`, and
`order_mutations`. It applies forward-only migrations without the repository
seed and reasserts every fence. The executable hosted acceptance hook proves
the old Edge/new schema state before any function deploy. All linked pgTAP,
lint, advisor, and hosted acceptance work runs while the three fences remain
enabled. The workflow then binds the Git revision and deploys callback, worker,
waitlist, and API functions before proving the new Edge/new schema state.

Hosted suites use the manifest's run-unique isolated synthetic namespace for
identities, objects, queues, schedules, roles, rows, and configuration. Capture
the fixture inventory before the suite. After suite-owned cleanup, capture it
again and require both zero namespaced residue and byte-for-byte before/after
parity. Cleanup or parity failure is a no-go and leaves every fence enabled.
Only `background_workers` is resumed after every check passes.
Provider egress and order mutations remain enabled (blocked) until the Webull
launch gate is separately satisfied.

The uploaded evidence artifact contains the canonical manifest, before/after
target fingerprints, fixture inventories, recovery coverage, and an immediate
observation record. Append the +1h, +4h, and +24h observations to the same
manifest-keyed release record. Each checkpoint records queue depth/age, expired
leases, unknown external effects, cleanup residue, Auth/Storage health, Edge
revision, schema fingerprint, and all fence states. A pending or failed
checkpoint is visible release evidence and never authorizes financial fences.

If manifest binding, target guard, kill-switch write, migration, mixed-version
check, function deployment, fixture cleanup/parity, or revision handshake
fails, stop. Keep all fences enabled. Do not point clients at an older backend,
a second auth system, or a legacy database as rollback. Fix forward from the
last reviewed migration or restore the Supabase project using the exact backup,
restore drill, and recovery approval bound in
`supabase-recovery-coverage.md`.

## U2 toolchain and forward-only history gate

Supabase CLI `2.115.0` is pinned exactly in CI and in the migration inventory.
Do not replace or depend on a machine-wide installation. Use an isolated binary
or project tool cache at the exact version, then verify it before database work:

```sh
supabase --version
scripts/check-supabase-migration-inventory.sh --check-cli
```

U1 recorded `destructive_reset_eligible = false`; forward-only history is now
the sole selected artifact. Every applied migration through
`20260829043359` is checksum-locked in
`supabase-migration-inventory-v1.txt`; the U4 forward candidate is appended
after that immutable boundary. No clean-history SQL artifact is retained.
The clean option is documented only as rejected decision logic in
`supabase-schema-authoring.md` and cannot execute without a new complete
eligibility record and separate approval.

Before authoring or reviewing a migration, run:

```sh
scripts/test-check-supabase-migration-inventory.sh
scripts/check-supabase-migration-inventory.sh --offline
```

The checker refuses an edited, missing, renamed, reordered, duplicated,
backdated or unregistered migration; a nonempty declarative `schema_paths`; a
second SQL schema/history directory; the wrong CI or executable CLI; a zero-plan
pgTAP suite; or an unclassified managed-resource family, extension or custom
role. It does not inspect a database unless an explicit URL and target-manifest
mode are supplied. Database mode is read-only and never prints the URL or Vault
values.

CI records the normalized target after the first disposable reset and compares
it byte-for-byte after the second. The target includes definitions, ACLs,
function properties, roles/settings, deterministic reference data, extension
behavior, the migration ledger, queues, schedules, buckets and Vault names.
The temporary target is replay evidence only, not a committed schema authority.
See `supabase-schema-authoring.md` for dependency order, role classification,
managed-resource ownership and the append-only workflow.

## U3 trusted request transaction and compatibility boundary

Authenticated API work uses one checked-out transaction-pooler connection for
the complete sequence: `BEGIN`, `install_request_context`, `SET LOCAL ROLE`,
all repository statements, and `COMMIT` or `ROLLBACK`. The installer is granted
only to the `argus_edge` login and runs before it assumes a capability. It
derives tenant and lifecycle from the active member root, then delegates to the
identity-owned lifecycle-lock primitive. That primitive rechecks the open
lifecycle under `FOR SHARE`, held until request transaction completion, before
the installer stores context in a random temporary relation owned by
`argus_identity_owner` with `ON COMMIT DROP`. Policy helpers reject a missing,
malformed, caller-owned, wrong-backend, wrong-transaction,
older-than-one-minute, or closed-lifecycle context. Repositories cannot issue
transaction/role control or release the reserved connection.

`argus_member`, `argus_staff`, `argus_callback`, and `argus_migration` are
empty-by-default NOLOGIN capabilities. U3 grants only current-lifecycle reads
to member/staff and leaves callback/migration unbound. `argus_runtime` and
`argus_worker`, the legacy JWT-claims GUC, their broad relation grants, and the
universal `enforce_live_member_epoch` trigger remain explicitly compatible for
uncut-over U4-U6 relations. Do not treat them as the target model or add new
consumers. U4 owns Argus relation bindings, U5 owns brokerage/callback bindings,
and U6 owns job, receipt, Storage, privacy, and durable-work bindings; each unit
removes only the compatibility it replaces.

Run `request_context.test.sql`, `function_security.test.sql`,
`member_lifecycle.test.sql`, and `grants_and_rls.test.sql` together after every
foundation change. Then run the local two-session serialization proof:

```sh
ARGUS_LOCAL_DB_CONTAINER=supabase_db_argus \
  sh supabase/tests/request_context_concurrency.test.sh
```

The harness refuses a non-loopback URL or non-`postgres` session, temporarily
adds only postgres-grantor `SET` rows for the Edge and identity roles, and
preserves Supabase's admin-only membership rows. It signals only after the
owning session has acquired its row lock and verifies both orders: lifecycle
close waits while a context transaction is open, and context installation
waits then fails closed when lifecycle close owns the row first. Startup and
final cleanup are fixed-subject, dependency ordered, and fail unless all role,
policy, and fixture residue is gone. Full AE4 stale
job/callback/object/receipt/provider proof is not complete until U4-U6 bind
those artifacts.

## U4 application and publication boundary

U4 member-facing children carry `(tenant_id,lifecycle_id)` composite foreign
keys to `member_lifecycles`; their forced-RLS policies use only U3 trusted
context and deny closed or cross-owner lifecycles. `argus_app_owner` is a
NOLOGIN function/table owner with exact command dependencies, not a connection
role. Member and editorial repository work assumes `argus_member` or
`argus_staff` inside the reserved request transaction.

Public and member editorial reads call only the bounded current-publication
functions owned by NOLOGIN `argus_publication_owner`. That role has SELECT on
exactly `editorial_items`, `editorial_revisions`, and
`editorial_render_documents`; the runtime has no direct publication-table
grant. Normalized draft/relationship rows are editable authority and sealed
render documents are immutable historical presentation.

Legacy U4 arrays, payload relationship fields, `saved_items`, and report target
pairs are read-only compatibility projections through U9 observation and are
removed by U10. Do not add an independent writer. The remaining compatibility
bridge is deliberately outside U4: U5 owns brokerage/callback relations; U6
owns queues, jobs, receipts, Storage, privacy and private durable work. Until
U6 replaces its transaction seams, runtime retains the exact onboarding/
scenario relations used with member idempotency, worker retains read-only open
lifecycle resolution for the binding trigger, and the private purge definer
retains DELETE-only access to `member_saved_items`.

## U5 brokerage authority and recovery boundary

U5 brokerage rows are qualified by immutable tenant, lifecycle, user,
connection, and account identity. The application uses `argus_member` for
member reads and commands, `argus_callback` for Webull completion, and
`argus_staff` for reviewed diagnostics. These capabilities run only inside the
reserved request transaction after trusted context installation. The legacy
runtime must not be used by a brokerage repository.

Webull remains authoritative for provider account and order outcomes. Typed
capability, balance, position, restriction, account, and order facts serve
Argus reads; private bounded/versioned/hashed snapshots are diagnostic evidence
only. Never use a raw snapshot as authorization, feature-gate, freshness, or
financial-command truth, and never expose credential-shaped fields through a
snapshot or member grant.

All worker and callback mutations take locks in this order: lifecycle,
connection, account, then command or lease. Lifecycle closure and connection
cleanup use the same parent guards. A lock timeout is a retriable operation
failure; it is not permission to skip a parent or acquire children out of
order. `SKIP LOCKED` remains restricted to queue-like batch claims and is not a
substitute for serialization of a named brokerage command.

Before any financial provider request, the prepare transaction commits one
durable command and one immutable `egress/started` attempt and marks the command
`dispatching`. A crash before the actual send may sacrifice liveness. It must
not restore submit authority. The bounded recovery coordinator schedules every
`dispatching` checkpoint older than 30 seconds into the same lookup-only saga,
even when no reconciliation row was committed by the request path. Recovery may
only record a definitive response or perform provider lookup/reconciliation
against the same command identity. Provider not-found stays ambiguous until the
configured visibility window and then moves to manual review; it never permits
a second submit.

Reconnect, failure, disconnect, lifecycle close, or deletion must call the
scoped materialization cleanup boundary. Cleanup refuses a connection with a
nonterminal command; it destroys credential and provider-identifier material
while retaining the minimum account parent needed for immutable command audit.
It does not claim to close or alter the Webull account itself.

After a disposable-local clean replay, capture the U5 database evidence with:

```sh
docker exec -i supabase_db_argus psql -U postgres -d postgres -X \
  < scripts/measure-u5-brokerage-plans.sql
cd ritual-investing-api
ARGUS_LOCAL_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  node scripts/verify-u5-brokerage-lock-order.mjs
```

The SQL harness is rollback-only. The concurrency harness refuses non-local
hosts and removes its fixed synthetic identity and brokerage fixture even when
an assertion fails.

## U6 durable work, privacy, and managed Storage boundary

`argus_private.job_event_registry` and `job_schedule_registry` are the deployed
versioned contract. `src/jobs/registry.ts` is parity-checked against them; an
event, handler, payload version, topic, retry limit, visibility timeout,
dead-letter policy, or schedule added in only one layer is a release failure.
Member events must carry tenant, lifecycle, and identity scope. The global
privacy-deletion event must carry none and resolves its subject only through
its tombstone.

`argus_jobs_owner` is the NOLOGIN owner for the durable-work tables and
capabilities. PGMQ is private to its six-operation queue adapter. The worker
can relay, claim, renew, complete, fail, and recover through higher-level
commands, but has no PGMQ schema access or job/storage table DML. Cron deploys
only these reviewed coordination/enqueue schedules:

- `argus-durable-work-coordinate` every minute;
- `argus-worker-dispatch-enqueue` every minute; and
- `argus-webull-recovery-coordinate` every five minutes.

Each retains seven days of its own `cron.job_run_details`. Waitlist retention
remains independently owned. Never add provider, Auth, or Storage work to a
Cron command.

External handlers use prepare/effect/complete sagas. A claim commits before
Auth, Storage, or provider I/O. Every short effect checkpoint installs and
revalidates the exact event, run, and lease token; lease renewal and terminal
failure use an unscoped control transaction so a lost lease cannot prevent
recovery. Do not pass a transaction-bound database client to an HTTP, Auth,
Storage, or provider port.

Media upload commands allocate a non-reusable lifecycle-qualified object path.
Objects move through `quarantined`, `structurally_verified`, `published`,
`rejected`, `tombstoned`, `deletion_pending`, `deleted`, or `reconciliation`.
Only the exact observed checksum can publish, and authenticated clients have no
replace/delete path. Structural inspection validates the declared image
format, dimensions, size, and checksum. It is not malware scanning and no
malware-clear state may be inferred until a real scanner attestation is added.

Privacy export preparation runs in one repeatable-read transaction. It writes
ordered normalized rows, per-collection counts and fingerprints, bound object
hashes, a cutoff, and one manifest checksum before assembly. Assembly pages
only sealed rows. Missing or changed source content fails that generation; a
retry receives a new generation and immutable Storage identity. Published
exports are member-accessible only through a one-time URL-issuance lease. The
issued Supabase signed URL is reusable for a disclosed residual lifetime of at
most 30 seconds; it is not described as single-use. Deletion similarly preserves its own leased event/run until the
tombstone, Storage receipts, product purge, Auth-last deletion, lifecycle
closure, and terminal consumer receipt are complete.

For diagnosis, an `argus_staff` transaction with `operations:read` may call
`argus_private.read_job_operational_signals()`. It returns bounded counts for
queue depth/age, expired leases, attempts, dead letters, Cron and dispatch
failures, external-effect and Storage reconciliation, database lock waits, and
worker runtime p95. It exposes no payload, object path, credential, or member
identity. Fence `background_workers` before manual recovery. Resume only after
the registry/schedule inventory matches, expired claims converge, every
unknown external effect is reconciled from its immutable evidence, and queue
age/depth return below the versioned budget.

The admin operations API reads jobs and privacy requests only through
`list_job_diagnostics(integer)` and
`list_privacy_request_diagnostics(integer)`; both are bounded to 100 and
redact failure detail. A retry requires the corresponding write permission and
a one-use AAL2 step-up receipt. It republishes the exact registered source
event under a new dedupe key, preserving lifecycle and aggregate authority;
the staff role has no direct job, outbox, or privacy-request table DML.

After a disposable-local clean replay, run the full pgTAP suite, error-level
lint, and both advisors. The focused U6 behavioral contracts are
`job_contracts.test.sql`, `privacy_inventory.test.sql`,
`queues_and_cron.test.sql`, `storage_policies.test.sql`, and
`u10_privacy_jobs.test.sql`. Also run API typecheck/job tests and the worker
Deno check/test. Hosted queue visibility/delay, Storage/Auth effects, Cron
execution, concurrency budgets, and orphan reconciliation remain U9 launch
gates; local source or pgTAP success does not satisfy them.

## U1 architecture evidence gate

Before selecting migration history or requesting hosted credentials, run:

```sh
scripts/check-supabase-architecture-contract.sh --offline
scripts/test-check-supabase-architecture-contract.sh
```

The U1 remediation register retains the discovery-time checksum snapshot as
evidence; the U2 migration inventory is the sole active migration checksum
authority. The versioned boundary manifest binds the exact path set of every
directly detected Supabase-facing source surface; broad register patterns assign
owner groups but never approve a direct file. Narrow reviewed module roots
classify generated contracts and consumers reached through local adapters
without hashing all of their unrelated source. The target-model contract
classifies every current array, JSON and polymorphic relationship, and the versioned
performance/operations budget owns every unmeasured release gate. Adding,
removing, or renaming a direct boundary must make the checker fail, including a
new Supabase-facing file inside an already-owned source tree.

When a boundary change is intentional, generate the proposed inventory for
review without modifying repository state:

```sh
scripts/check-supabase-architecture-contract.sh --print-boundary-manifest
```

Compare the output to
`docs/ritual-investing/supabase-boundary-manifest-v1.txt`, review each path and
module-classification delta with its domain owner, then update the versioned
manifest or transitive-module register in the same change. Re-running the
offline checker must be green; a broad owner-group pattern is never sufficient
evidence. Ordinary edits to an already classified file do not require a
manifest update unless the direct-boundary path set changes.

The U1 hosted eligibility result is destructive-reset ineligible because the
exact project/branch, retained data, dependencies, recovery coverage and
approval are unknown. Do not infer eligibility from “development,” “beta,” or
repository age. U2 must produce a fresh non-secret identity/count/checksum
record. Any real-user activity or non-synthetic dependency requires the
retention and zero-downtime path.

For a database that has been explicitly selected and proven disposable, the
read-only catalog inventory can be run without printing or inferring its URL:

```sh
scripts/check-supabase-architecture-contract.sh --database-url "$EXPLICIT_DATABASE_URL"
```

This is inventory only. It does not authorize `db reset`, migration repair,
hosted SQL, secret reads, or managed-service mutation. Capture Vault names only,
never values. Run pgTAP through the pinned Supabase CLI separately; an absent
Docker daemon, an unpinned CLI, a zero-test result, or a missing restore drill
is a blocker, not a waiver.

## Hosted secrets

Hosted secrets live only in the protected GitHub environment or Supabase secret
store. Never commit them, expose them to pull requests/forks, pass them as test
fixtures, or print them. Rotate Edge database logins, worker HMAC keys, Webull
credential-encryption keys, and Supabase secret keys using their versioned
overlap procedures. A lost or ambiguous Webull refresh response is fenced to
reauthorization; it is never blindly retried.

## Cutover inventory

The required deployed inventory is four Edge Functions (`api`, `worker`,
`webull-callback`, `waitlist`), the migrations and pgTAP tests under
`supabase/`, Supabase Auth, private Storage, Cron, and PGMQ. The prohibited
inventory is any API Cloudflare Worker, Neon database or role, Auth0 tenant used
by the app, Cloudflare Queue/R2 binding, Pages Function, `_worker.js`, or
simulation command endpoint.

After revoking legacy credentials and routes, run
`scripts/check-legacy-backend-removal.sh`. Record negative probes showing the
old API host and bindings cannot serve requests before removing the final
provider-side resources.

### Edge runtime bindings

Supabase supplies `SUPABASE_URL`, `SUPABASE_DB_URL`,
`SUPABASE_PUBLISHABLE_KEYS`, and `SUPABASE_SECRET_KEYS` automatically. The
functions use the named `default` secret key for private Auth and Storage calls,
but deliberately reject the automatic owner database URL.

Provision these project secrets out of band before the first function deploy:

- `EDGE_RUNTIME_DATABASE_URL`: transaction-pooler DSN for `argus_edge` (API
  and Webull callback only).
- `EDGE_WORKER_DATABASE_URL`: transaction-pooler DSN for
  `argus_worker_edge`.
- `EDGE_WAITLIST_DATABASE_URL`: transaction-pooler DSN for
  `argus_waitlist_edge`.

Each role password is independently generated and rotated. The migration
baseline intentionally leaves all three passwords null; never substitute the
automatic `postgres` owner DSN or reuse the deployment-owner password.

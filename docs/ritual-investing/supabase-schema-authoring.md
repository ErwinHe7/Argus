# Supabase schema-authoring contract

This is the U2 authority for authoring and replaying the Ritual Investing
schema. `supabase/migrations/` is the only deployable schema history, and
`docs/ritual-investing/supabase-migration-inventory-v1.txt` is its exact
path/order/checksum and ownership manifest.

## Selected history strategy

U1 recorded `destructive_reset_eligible = false`, so the selected KTD1 path is
forward-only. Every migration through version `20260828220113` is applied
history and must remain byte-for-byte unchanged. Later units append migrations
with greater versions; they never edit, delete, rename, reorder, squash, or
repair an applied file. There is no clean-history directory or declarative
schema mirror in the repository.

The rejected clean-history branch remains decision logic only: it would require
a new dated evidence bundle proving the exact project and branch, ledger and
checksums, synthetic-only dependencies, complete recovery coverage, and
explicit disposal approval for every retained environment. A missing or changed
field refuses the branch. U2 does not create an executable clean artifact, and
promotion must never switch history strategies.

## Toolchain and command boundary

Supabase CLI `2.115.0` is exact, not a minimum. CI installs that version with
`supabase/setup-cli@v1`; developers must use the same version without replacing
or relying on a machine-wide installation. Verify the executable before schema
work:

```sh
supabase --version
scripts/check-supabase-migration-inventory.sh --check-cli
```

Version 2.115.0 makes pg-delta the default diff engine and makes
`supabase test db` fail when no pgTAP tests execute. `schema_paths = []` remains
set in `supabase/config.toml`: pg-delta or declarative output may be generated
only into an ignored temporary directory for review. The review must list
unsupported coverage, including publications, managed resources, security
properties, bucket behavior, and any definition it omits. Generated output is
never copied into a deployable path and never becomes a second authority.

Discover CLI syntax from the pinned binary's `--help`. Create every appended
migration with `supabase migration new <name>`, then author the smallest
forward-only expand/verify/contract step. Do not run `migration repair`, reset a
hosted target, or use dashboard SQL as an unrecorded write path.

## Dependency and ownership order

New modules follow one direction. A later layer may depend on an earlier layer;
the reverse dependency is prohibited.

| Order | Layer | Owner |
|---|---|---|
| 01 | Extensions, Supabase-owned prerequisites, ownership and login-role shells | Platform |
| 10 | Private schemas, domains and shared types | Platform plus declaring domain |
| 20 | Identity lifecycle | Identity |
| 30 | Argus application domains | Each bounded-context domain |
| 40 | Brokerage state and command fences | Brokerage |
| 50 | Cross-table constraints and measured indexes | Referencing domain |
| 60 | Private atomic primitives | Domain that owns the state transition |
| 70 | Exact capability entrypoints | Calling bounded context |
| 80 | Grants, default privileges and RLS | Platform security plus domain owner |
| 90 | Supported managed-service bootstrap | Named managed-resource owner |
| 95 | Deterministic, non-brokerage synthetic seed | Platform test data |

Tables own state and declarative integrity. Private routines own atomic
transitions. Capability routines expose only reviewed transactions. Edge/Hono
owns network I/O, orchestration, retry classification and response shaping. A
new table, constraint, policy, function, trigger, queue, schedule, bucket,
secret-name contract, role, grant, default privilege or seed must declare one
row or owning family in the migration inventory and one verification boundary.

## Managed Supabase ownership

The `[managed-resources]` rows in the machine-checked inventory are the desired
state allowlist. The authority values mean:

- `supabase-managed`: Supabase owns internals; Argus uses supported configuration
  or APIs and records only its desired boundary.
- `migration-supported-api`: a migration invokes the extension or managed
  product's supported public contract; replay is idempotent and exact.
- `out-of-band`: a protected operator provisions the resource and CI verifies
  its name/revision. Values and credentials never enter the inventory.

Auth internals, `storage.objects`, Realtime internals, PGMQ implementation
tables, Cron internals, `net` internals, and Vault values are never directly
mutated. Bucket definitions, queue creation, schedules and extensions use their
reviewed public contracts. Vault inventory contains names only. Edge Functions
and secrets are deployed out of band from an exact Git revision.

The current `argus_runtime`, `argus_worker`, and `argus_waitlist` NOLOGIN roles
are classified as legacy capability containers because they own no objects;
U3 must preserve their capability shape while narrowing or replacing them.
`argus_edge`, `argus_worker_edge`, and `argus_waitlist_edge` are runtime logins
with null migration-time passwords, exact membership, connection limits and
timeouts. A future non-login owner role may own one domain module but may not be
used as an Edge login. Supabase-managed roles are never recreated by Argus.
Role rows are ordered as name, classification, domain owner, login state,
membership, owned-object/grant disposition, and connection settings. The replay
target fingerprints the normalized object/function/default ACLs that implement
each `target-acl` disposition.

## Authoring and replay gates

Before review, an author must:

1. Run the two checker self-tests, the offline architecture gate, and the
   migration inventory gate. Update the exact boundary manifest for every
   legitimate new Supabase-facing path.
2. Append the migration checksum to the sole migration inventory. The checker
   rejects any missing, backdated, renamed, reordered, duplicated or changed
   file and rejects SQL schema artifacts outside migrations, tests and seed.
3. Start a disposable local stack with the pinned CLI, reset once, run the
   nonzero pgTAP suite, lint at error level, and run local security and
   performance advisors. Unexpected preexisting objects must fail; do not add
   broad `IF NOT EXISTS` guards to hide drift.
4. Render the first read-only replay target, reset a second time, and compare
   the second target byte-for-byte:

   ```sh
   scripts/check-supabase-migration-inventory.sh \
     --database-url "$EXPLICIT_LOCAL_DATABASE_URL" \
     --print-target-manifest >"$FIRST_REPLAY_MANIFEST"
   scripts/check-supabase-migration-inventory.sh \
     --database-url "$EXPLICIT_LOCAL_DATABASE_URL" \
     --compare-target-manifest "$FIRST_REPLAY_MANIFEST"
   ```

The replay target fingerprints normalized schemas, relations, columns,
constraints, indexes, policies, routines and properties, triggers, ACL/default
ACL state, roles/memberships/settings, deterministic reference data,
extensions, the migration ledger, queues, schedules, private buckets and Vault
names. It never prints the database URL or a Vault value. CI creates the first
manifest in runner temp storage only; it is evidence, not a committed second
schema authority.

Hosted lint, advisors, ledger comparison, target fingerprint, managed-resource
acceptance and promotion remain protected gates. A local replay never grants
authority to inspect, repair, reset or mutate a hosted project.

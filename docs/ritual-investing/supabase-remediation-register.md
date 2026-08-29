# Supabase remediation register

contract_version: supabase-remediation-register-v1

This is the U1 characterization register for the Supabase-backed Ritual
Investing product. It remains evidence, not migration authority. U2 selected
the forward-only strategy after U1 recorded `destructive_reset_eligible =
false`; `supabase-migration-inventory-v1.txt` is now the sole active
path/order/checksum authority. Every applied migration in this snapshot remains
immutable. Every `redesign` or `replace` entry is a later-unit obligation, not
authorization to rewrite applied history.

## Snapshot and destructive eligibility

| Field | U1 evidence | Consequence |
|---|---|---|
| Repository Git revision | `d65f0b68725388d4a3c588b8352c3e19053dbe92` with an intentionally dirty developer checkout | Bind future hosted evidence to a fresh reviewed revision, not this working tree. |
| Inventory date | 2026-08-28, America/New_York | Refresh before U2 history selection and every U9 promotion. |
| Local CLI | 2.65.5 observed; required 2.115.0 is not installed | U2 owns the isolated upgrade; U1 does not rely on newer CLI behavior. |
| Local stack | Docker daemon unavailable during U1 | Catalog SQL and pgTAP are reviewable but not locally executed in this checkout. |
| Hosted project/branch identity | Not discovered or recorded | Unknown is ineligible for destructive reset. |
| Hosted migration ledger and counts | Not discovered | Unknown is ineligible for destructive reset. |
| Real-user and non-synthetic dependency proof | Absent | Treat all retained state as potentially non-disposable. |
| Restore drill | No isolated Auth/Storage/queue/Cron/role/Vault/Edge restore evidence | Destructive reset is prohibited. |
| Approval | No reviewed disposal approval | KTD1 safe default is forward-only remediation. |

**Eligibility result: `destructive_reset_eligible = false`.** U1 does not
mutate or inspect hosted state. U2 therefore locked the forward-only branch and
did not replace this record. The clean branch remains decision logic only and
would require a separate dated, non-secret evidence bundle proving project
identity, branch identity, data classification, migration checksums, recovery
coverage, synthetic-only dependencies, and explicit approval. Any real-user
activity or non-synthetic dependency routes to the separate retention and
zero-downtime plan.

## Exact boundary closure and owner-group metadata

`supabase-boundary-manifest-v1.txt` is the closed, versioned repository
inventory. It records the exact path of every file discovered by the
repository-wide Supabase/Argus/Auth/Storage/PGMQ/Cron boundary scan. The checker
regenerates that path set and compares it byte-for-byte, so an added, removed,
or renamed direct boundary fails until its individual row is reviewed. It does
not hash whole source files: editing an already classified surface does not
create unrelated contract churn. Applied migration checksums remain separately
immutable below.

The broad patterns below assign domain/consumer owner groups after exact
inventory closure. They are metadata only: matching `scripts/*`, `supabase/*`,
or an application source tree never registers or approves a direct boundary.
Files which consume the boundary only through a local adapter are classified by
the reviewed, narrow module roots below; the checker verifies every declared
module still exists. Adding a new direct Supabase-facing file inside one of
those modules still changes the exact path manifest and fails closed.

<!-- transitive:supabase/functions -->
<!-- transitive:supabase/migrations -->
<!-- transitive:supabase/tests -->
<!-- transitive:ritual-investing-api/src/db -->
<!-- transitive:ritual-investing-api/src/jobs -->
<!-- transitive:ritual-investing-api/src/domains/accounts -->
<!-- transitive:ritual-investing-api/src/domains/admin -->
<!-- transitive:ritual-investing-api/src/domains/admin-operations -->
<!-- transitive:ritual-investing-api/src/domains/assets -->
<!-- transitive:ritual-investing-api/src/domains/briefings -->
<!-- transitive:ritual-investing-api/src/domains/brokerage-accounts -->
<!-- transitive:ritual-investing-api/src/domains/brokerage-assets -->
<!-- transitive:ritual-investing-api/src/domains/brokerage-connections -->
<!-- transitive:ritual-investing-api/src/domains/brokerage-orders -->
<!-- transitive:ritual-investing-api/src/domains/brokerage-projections -->
<!-- transitive:ritual-investing-api/src/domains/brokerage -->
<!-- transitive:ritual-investing-api/src/domains/circles -->
<!-- transitive:ritual-investing-api/src/domains/content -->
<!-- transitive:ritual-investing-api/src/domains/coven -->
<!-- transitive:ritual-investing-api/src/domains/discover -->
<!-- transitive:ritual-investing-api/src/domains/editorial -->
<!-- transitive:ritual-investing-api/src/domains/engagement -->
<!-- transitive:ritual-investing-api/src/domains/intentions -->
<!-- transitive:ritual-investing-api/src/domains/media -->
<!-- transitive:ritual-investing-api/src/domains/moderation -->
<!-- transitive:ritual-investing-api/src/domains/notifications -->
<!-- transitive:ritual-investing-api/src/domains/platform -->
<!-- transitive:ritual-investing-api/src/domains/privacy -->
<!-- transitive:ritual-investing-api/src/domains/public-preview -->
<!-- transitive:ritual-investing-api/src/domains/retained-http -->
<!-- transitive:ritual-investing-api/src/domains/rituals -->
<!-- transitive:ritual-investing-api/src/domains/rowan -->
<!-- transitive:ritual-investing-api/src/domains/search -->
<!-- transitive:ritual-investing-api/src/domains/session -->
<!-- transitive:ritual-investing-api/openapi -->
<!-- transitive:ritual-investing-api/scripts -->
<!-- transitive:ritual-investing-api-client/doc -->
<!-- transitive:ritual-investing-api-client/lib/generated -->
<!-- transitive:ritual-investing-api-client/test -->
<!-- transitive:ritual-investing-app/lib/core/api -->
<!-- transitive:ritual-investing-app/lib/core/auth -->
<!-- transitive:ritual-investing-app/lib/core/bootstrap -->
<!-- transitive:ritual-investing-app/lib/features/auth -->
<!-- transitive:ritual-investing-app/lib/features/asset_codex/data -->
<!-- transitive:ritual-investing-app/lib/features/briefings/data -->
<!-- transitive:ritual-investing-app/lib/features/brokerage_connection/data -->
<!-- transitive:ritual-investing-app/lib/features/circles/data -->
<!-- transitive:ritual-investing-app/lib/features/coven/data -->
<!-- transitive:ritual-investing-app/lib/features/creators/data -->
<!-- transitive:ritual-investing-app/lib/features/discover/data -->
<!-- transitive:ritual-investing-app/lib/features/grimoires/data -->
<!-- transitive:ritual-investing-app/lib/features/intentions/data -->
<!-- transitive:ritual-investing-app/lib/features/notifications/data -->
<!-- transitive:ritual-investing-app/lib/features/onboarding/data -->
<!-- transitive:ritual-investing-app/lib/features/orders/data -->
<!-- transitive:ritual-investing-app/lib/features/portfolio/data -->
<!-- transitive:ritual-investing-app/lib/features/privacy/data -->
<!-- transitive:ritual-investing-app/lib/features/profile/data -->
<!-- transitive:ritual-investing-app/lib/features/ritual/data -->
<!-- transitive:ritual-investing-app/lib/features/rowan/data -->
<!-- transitive:ritual-investing-app/lib/features/search/data -->
<!-- transitive:ritual-investing-admin/lib -->
<!-- transitive:ritual-investing-admin/integration_test -->
<!-- transitive:ritual-investing-demo/lib -->
<!-- transitive:ritual-investing-demo/tool/provider_stubs -->
<!-- transitive:ritual-investing-site/public/privacy/waitlist -->

| Transitive classification | Reviewed module roots |
|---|---|
| Supabase definitions and runtime | `supabase/functions`, `supabase/migrations`, `supabase/tests` |
| API composition | `ritual-investing-api/src/db`, `src/jobs`, every explicitly listed bounded-context directory, `openapi`, and API scripts |
| Generated contract | `ritual-investing-api-client/doc`, `lib/generated`, and its contract test |
| Member consumer | `core/api`, `core/auth`, `core/bootstrap`, Auth presentation, and each listed feature `data` adapter module |
| Admin consumer | `ritual-investing-admin/lib` and its integration contract |
| Demo/site boundaries | Demo provider stubs and composition, plus the waitlist landing module |

<!-- scope:CONCEPTS.md -->
<!-- scope:MODEL_SOURCE_MAP.zh-CN.md -->
<!-- scope:.github/workflows/ritual-investing-supabase-remediation.yml -->
<!-- scope:.github/workflows/ritual-investing.yml -->
<!-- scope:docs/ritual-investing/* -->
<!-- scope:docs/solutions/architecture-patterns/* -->
<!-- scope:scripts/* -->
<!-- scope:supabase/config.toml -->
<!-- scope:supabase/seed.sql -->
<!-- scope:supabase/migrations/* -->
<!-- scope:supabase/tests/* -->
<!-- scope:supabase/functions/* -->
<!-- scope:supabase/* -->
<!-- scope:ritual-investing-api/src/* -->
<!-- scope:ritual-investing-api/test/* -->
<!-- scope:ritual-investing-api/openapi/* -->
<!-- scope:ritual-investing-api/scripts/* -->
<!-- scope:ritual-investing-api/package.json -->
<!-- scope:ritual-investing-api/vitest.config.ts -->
<!-- scope:ritual-investing-api-client/* -->
<!-- scope:ritual-investing-app/lib/* -->
<!-- scope:ritual-investing-app/test/* -->
<!-- scope:ritual-investing-app/integration_test/* -->
<!-- scope:ritual-investing-app/pubspec.yaml -->
<!-- scope:ritual-investing-app/* -->
<!-- scope:ritual-investing-admin/lib/* -->
<!-- scope:ritual-investing-admin/test/* -->
<!-- scope:ritual-investing-admin/integration_test/* -->
<!-- scope:ritual-investing-admin/pubspec.yaml -->
<!-- scope:ritual-investing-demo/* -->
<!-- scope:ritual-investing-site/* -->

| Surface | Current composition and consumers | Disposition / owner |
|---|---|---|
| Edge `api` composition root | Imports every retained repository, scenario and brokerage adapter; authenticates Supabase JWTs; serves the versioned Hono API. | Redesign composition by bounded context in U7; preserve routes through U8/U9. |
| Retained repository monolith | `ritual-investing-api/src/db/supabase-repositories.ts` owns session, account, assets, circles, editorial, briefings, notifications, media, moderation, privacy, rituals, search, admin, public preview, coven, discovery, and Rowan SQL. | Redesign into policy/ports/adapters/services in U7. |
| Domain repositories | Intentions/scenarios and brokerage connections, accounts, assets, projections, and orders already use narrower modules. | Preserve as reference; U4/U5 review keys and snapshots. |
| Jobs | Queue consumer/runtime, scheduled registry, consumer receipts, handlers, privacy, briefing, Webull refresh/projection/reconciliation. | Replace duplicate SQL/TypeScript registries in U6; preserve financial fences. |
| Generated contract | OpenAPI source, generated Dart client, generated docs, revision/drift scripts. | Preserve atomically; U8 owns versioned changes. |
| Member consumer | Flutter Supabase PKCE session, generated client, bootstrap mappers, repositories, step-up and production composition. | Preserve behavior; U3 binds lifecycle and U8 adopts contract changes. |
| Admin consumer | Supabase staff session, generated client gateway, browser/integration workflows. | Preserve behavior; U3 narrows capabilities and U8 adopts contract changes. |
| Cross-boundary bypass guards | Provider-boundary scripts, legacy-removal guard, deploy target guard, fence SQL, hosted acceptance, static Pages checks. | Preserve and extend through U9; never grant a client direct private-schema path. |
| Managed Supabase | Auth, private Storage, Edge, PGMQ, Cron, Vault-name contracts, `pg_net`, roles and extensions. | Use supported contracts only; U2/U3/U6/U9 own changes. |

## Migration evidence and disposition

The SHA-256 lines below preserve U1's discovery snapshot. They are no longer
consumed as an active schema authority; U2 moved that responsibility to the
single forward-only `supabase-migration-inventory-v1.txt` manifest and its
fail-closed checker. “Preserve evidence” means the file is not rewritten. The
live object inventory is produced from the catalog by
`scripts/audit-supabase-architecture.sql`, so altered, replaced, and overloaded
objects appear in their final installed form rather than being mistaken for
independent authorities.

| Migration | Object families / replacement history | Domain owner | Downstream consumers, managed dependency and security mode | Disposition |
|---|---|---|---|---|
| `20260828054740_argus_private_baseline.sql` | Schemas, roles, 74 initial relations, RLS/grants/default privileges, helper/command/outbox functions, triggers, Storage policies, PGMQ/Cron, seeds | Platform plus all domains | Member/admin API, worker and generated contract; Auth, Storage, PGMQ, Cron, Vault, `pg_net`; forced RLS, capability roles and reviewed definers | Preserve evidence; redesign into cohesive U2 modules. |
| `20260828062806_u14_retained_repository_primitives.sql` | Member provisioning trigger, staff retained read/retry policies and function, published-content policies | Identity, operations, editorial | Retained repository, admin and public/member readers; Auth trigger; forced RLS and staff-gated definer | Preserve behavior; replace monolithic ownership in U3/U4/U7. |
| `20260828070859_u3_gateway_rate_limit_contract.sql` | Gateway rate-limit relation/policy/grants | Platform security | API request middleware; Postgres only; capability-role RLS and atomic definer | Preserve behavior; review pool/concurrency budget in U3/U9. |
| `20260828074336_u3_edge_login_role.sql` | `argus_edge` login role, timeouts, exact membership | Platform security | API Edge pool; Supavisor transaction pooler; login shell inherits only `argus_runtime` | Preserve least privilege; re-author in U2/U3. |
| `20260828083020_u5_webull_connection_security.sql` | OAuth state constraints/index, completion handles, state consumer | Brokerage connection | API and Webull callback; Webull/Auth identity context; forced RLS plus one-use definer | Preserve contract; lifecycle-key redesign in U3/U5. |
| `20260828091200_u6_brokerage_projections.sql` | Projection retention/indexes, account capabilities JSON, asset mappings, leases | Brokerage reads | Brokerage member API and worker refresh; Webull; forced RLS and worker-only capability routines | Preserve current output; normalize reviewed facts in U5. |
| `20260828095121_u7_manual_order_commands.sql` | Order mapping/projection relations, command functions, immutable triggers and ambiguity fences | Brokerage orders | Order API and lookup-only recovery; Webull; forced RLS, immutable triggers and narrow definers | Preserve exactly until U5; no generic execution recovery. |
| `20260828123228_u9b_hypothetical_scenarios.sql` | Scenario constraints, deterministic amount bands, owner indexes/RLS | Intentions | Member API/app and generated client; no managed dependency; owner RLS and constrained writes | Preserve behavior; review normalized document fields in U4. |
| `20260828132056_u10_supabase_jobs_storage.sql` | Worker role, job attempts/DLQ/nonces, queue functions, privacy/media sagas, managed bootstrap | Jobs, privacy, media | Worker, privacy/member API and Cron; Auth admin, Storage, PGMQ, Cron, Vault, `pg_net`; worker role, forced RLS and saga definers | Redesign registry/effects in U6; preserve current fences. |
| `20260828145716_u11_admin_supabase_auth.sql` | Editorial transition/materialization functions, staff step-up, retry and diagnostics capabilities | Staff/editorial/operations | Admin API/app, public/member rendering; Supabase Auth staff sessions; staff-permission RLS and definers | Redesign materialization in U4/U7; narrow security in U3. |
| `20260828145737_u12_waitlist.sql` | Dedicated roles/table/functions/policy/Cron retention | Waitlist | Public waitlist Edge/site; Turnstile plus Cron/`pg_net`; dedicated login/capability role and exact definer | Preserve external contract; verify managed ingress in U9. |
| `20260828152000_u15_webull_recovery.sql` | Webull-only claims/effect completion/reconciliation, deletion fences and schedule | Brokerage recovery | Worker recovery and order diagnostics; Webull plus Cron; worker-only definers and account ambiguity locks | Preserve lookup-only semantics; compose in U5/U6. |
| `20260828163000_u13_briefing_read_states.sql` | Normalized read-state relation, composite parent FK, RLS/trigger | Briefings | Briefing member API/app; no managed dependency; parent-qualified FK, forced owner RLS and epoch trigger | Preserve; reference model for U3/U4. |
| `20260828170000_u16_unambiguous_job_attempt_conflict.sql` | Replacement `claim_next_argus_job` | Jobs | Worker queue runtime; PGMQ delivery contract; worker-only security definer | Replace with final U6-owned function; preserve evidence. |
| `20260828171500_u17_atomic_deletion_epoch_transition.sql` | Replacement deletion transition | Privacy/identity | Privacy API and purge worker; Auth lifecycle; owner-invoked atomic definer | Replace with lifecycle incarnation in U3/U6. |
| `20260828173000_u18_deletion_webull_fence_order.sql` | Replacement deletion ordering | Privacy/brokerage | Privacy worker and Webull jobs; Auth/Webull; worker definer with command/credential fence order | Replace with final composed saga; preserve order invariant. |
| `20260828174500_u19_unambiguous_purge_phase.sql` | Replacement purge preparation | Privacy | Privacy worker; Storage/Auth sequencing; worker definer with explicit phase | Replace with KTD12 manifest saga in U6. |
| `20260828180000_u20_deletion_connection_fence_transition.sql` | Replacement live-epoch trigger | Identity/brokerage | Brokerage API/callback/worker; Webull; forced-RLS write trigger | Replace with immutable lifecycle key in U3. |
| `20260828181500_u21_deletion_retry_transition.sql` | Replacement live-epoch retry semantics | Identity/privacy | Privacy API/worker; Auth lifecycle; owner/worker capability routine | Replace with immutable lifecycle key in U3. |
| `20260828183000_u22_hosted_security_advisor_hardening.sql` | Waitlist direct-access deny policy, function search paths | Platform security | Waitlist and all definer consumers; Supabase security advisor; deny policy and pinned search paths | Preserve behavior; re-author in U2/U3. |
| `20260828220113_grant_extension_usage_to_capability_roles.sql` | Extension usage grants | Platform security | API/worker/waitlist routines; `extensions` schema (`pgcrypto`, PGMQ helpers as used); capability-role schema usage only | Preserve evidence; reduce to exact supported capabilities in U3. |
| `20260829043359_u3_identity_security_foundation.sql` | Immutable member lifecycle parent, derived temporary request context, narrow identity owner, use-case capability shells, exact foundation grants/RLS/functions | Identity and platform security | API reserved transaction connection; Auth provisioning trigger; no managed-schema mutation or external I/O | U3 target foundation. U4-U6 own every dependent relation binding and compatibility removal. |
| `20260829051338_u4_normalize_argus_domains.sql` | Lifecycle-bound Argus application children; typed saved/report targets; ordered ritual, Grimoire, Circle-template, Coven and Asset Codex relations; immutable render documents; atomic domain synchronization/publication | Argus application and editorial domains | Member/editorial/public API; U3 trusted context; forced RLS; no external I/O | U4 target model. Legacy relationship columns remain fenced compatibility-only through U9; U5/U6 bridges remain explicitly owned by those units. |
| `20260829073116_u5_strengthen_brokerage_relations.sql` | Dual-identity connection root; lifecycle/user/connection/account-qualified brokerage children; typed capabilities/projection facts; bounded provider snapshots; ordered command/recovery guards; exact brokerage capabilities | Brokerage connection, reads, orders and recovery | Member API, callback, staff diagnostics and lookup-only worker recovery; Webull; forced RLS and narrow definer commands | U5 target model. Webull remains authoritative; a dispatching command is never resubmitted, and only U6 durable-work composition remains compatible. |
| `20260829140000_u6_compose_durable_external_work.sql` | Versioned job/schedule registry; private PGMQ adapter; lifecycle-bound work; queue claims/attempts/DLQ; sealed export generations; immutable Storage/effect identities; media, privacy and purge sagas; bounded diagnostics | Jobs, privacy, media, retained brokerage recovery coordination | Member/staff API, worker and Cron; Auth admin, Storage, PGMQ, Vault-name contract and `pg_net`; NOLOGIN jobs owner, FORCE RLS and exact capabilities | U6 target model. Cron coordinates/enqueues only, external calls occur between committed checkpoints, and structural validation makes no malware claim. |
| `20260829102909_u3_serialize_request_context_lifecycle.sql` | Forward replacement of trusted context installation through the identity-owned shared lifecycle-lock primitive | Identity and platform security | API/Edge reserved request transaction; PostgreSQL row locking; security definer with empty search path and exact login-only execution | U3 correction. An installed request holds the lifecycle `FOR SHARE` lock to commit; a close that locks first makes installation wait and fail closed. |
| `20260829150000_u6_application_purge_owner.sql` | Dedicated application-purge owner; exact tombstone/read/delete purge matrix; scalar-initPlan legacy staff step-up policy | Privacy application purge and retained staff step-up | Jobs orchestration and legacy staff runtime; NOLOGIN/NOBYPASSRLS owner, fixed SECURITY DEFINER port and exact RLS/ACLs | Removes the U6 application-owner purge shortcut without changing U10 compatibility surfaces. |
| `20260829160000_u7_member_event_scope.sql` | Lifecycle-scoped member event producers; normalized internal provider reason codes; composed stale-dispatch reconciliation scheduler | Application events and brokerage recovery | Member API, Cron, outbox and lookup-only worker; exact domain owners, bounded batch and no provider-submit capability | U7 closes event identity gaps and ensures a committed `dispatching` checkpoint cannot be stranded after the request process exits. |
| `20260829170000_u8_normalized_query_contracts.sql` | Typed content authorities; deterministic keyset query ports; creator registry; public-preview capability; complete foreign-key and diagnostics indexes; command-composed compatibility RLS | Content/search and operational reads | Member/public/staff API and admin diagnostics; forced RLS, bounded projections and exact query indexes | U8 removes JSON predicate/ranking authority, unbounded list merges, every remaining unindexed foreign-key scan, and overlapping permissive runtime policies. |

0975bf24b33bbe92871737b3f9753fa47cfda327144594893ce3e504abb9fd91  supabase/migrations/20260828054740_argus_private_baseline.sql
420520cb742ee93fc818fc3ddccc529ae2ca050054cb4500ace2b1cc1b3258f2  supabase/migrations/20260828062806_u14_retained_repository_primitives.sql
e30317295f5f507b73b285443b6d8c352bbca2a04105deacf32af193534079dc  supabase/migrations/20260828070859_u3_gateway_rate_limit_contract.sql
45a37b7287ad8fe147cbab056a0cb65e737e20c025bcdbf4f4117053bedb0046  supabase/migrations/20260828074336_u3_edge_login_role.sql
7e7fe21cd3a6859910fc1177c9c21346fcf2d1f68d446d67a8e51515852264e4  supabase/migrations/20260828083020_u5_webull_connection_security.sql
d585a5d145677ec3e5562cabc15929f99adf5f1a8f8db9b0d0a21b531ed34ddf  supabase/migrations/20260828091200_u6_brokerage_projections.sql
1cd1447f36f23cae59fc5b53b3a2055ec82ef15a84125fb7e03950d9ae264211  supabase/migrations/20260828095121_u7_manual_order_commands.sql
4335d7498f71b890ab408d8c35d88242307eeb01267b85c39042205c87599316  supabase/migrations/20260828123228_u9b_hypothetical_scenarios.sql
06783aec4322fcbac930b1d791b157d19d749718acb003160dae464fec46a806  supabase/migrations/20260828132056_u10_supabase_jobs_storage.sql
5a56fdb815bb7fbfbd38228bfd71b1ce6089a549fa5a17925774bafba6dcdf1a  supabase/migrations/20260828145716_u11_admin_supabase_auth.sql
3c9c9414efceba22c79430215652a6390868bd9caeffd5c4512d50ba5f6b4bb0  supabase/migrations/20260828145737_u12_waitlist.sql
9986846abf1f15472d9e84f54e505872b3a3e9f44fb14f135c80b1f09bb9fe92  supabase/migrations/20260828152000_u15_webull_recovery.sql
74c545e95e42228752804fefe2f9e8573aa668d0fda28685c414ed3dc48b2351  supabase/migrations/20260828163000_u13_briefing_read_states.sql
33ee7b50c1b1cadd13bc78113c539cef6cb16d3fc074df0e8f0651a2fb6f765a  supabase/migrations/20260828170000_u16_unambiguous_job_attempt_conflict.sql
908d3ac0c068324bef4ff510f132a0995a6e40f877343ba5d6478ff5cad06052  supabase/migrations/20260828171500_u17_atomic_deletion_epoch_transition.sql
2e756624427800691ddd028f832684cabe973186a99c56d288b05a80c708f09e  supabase/migrations/20260828173000_u18_deletion_webull_fence_order.sql
74d83d4c154d990fc6c4ddc7ffef627ef18905d3be161e782cc195bd7b6012f5  supabase/migrations/20260828174500_u19_unambiguous_purge_phase.sql
eaf80efcc1602dc5b698486f9593d7ad53306aa1099253765cfc0c242b7221d1  supabase/migrations/20260828180000_u20_deletion_connection_fence_transition.sql
5596cb169277513a9f106ba4a3690ec939da58e50d17de85edb2a41d4f24ba59  supabase/migrations/20260828181500_u21_deletion_retry_transition.sql
cb239ca1bb49bae7a5abb8edf1faa830e26ae586e48119e5b2400402a3160720  supabase/migrations/20260828183000_u22_hosted_security_advisor_hardening.sql
3b19d75b915e51bb6ce60293f416459f56b561304283ce4b74982308e71d1c1e  supabase/migrations/20260828220113_grant_extension_usage_to_capability_roles.sql
5804702200889492c115d0690227015c2df6736c4d8921430afe1c8ff4863696  supabase/migrations/20260829043359_u3_identity_security_foundation.sql
ed0f90a92fc8f5c42d73d1258abb272c5fd08af0bf6a4db1f7aeabe04c17f36b  supabase/migrations/20260829051338_u4_normalize_argus_domains.sql
1507abee32710bdcb0313a2f058a3311a65855d650c375e841927efe3ed94379  supabase/migrations/20260829073116_u5_strengthen_brokerage_relations.sql
d9f264b47f761a9af226919b2278f28fc1677af74ec11477f7a3cd79d5057114  supabase/migrations/20260829102909_u3_serialize_request_context_lifecycle.sql
4d941c494dfc4fe40e7e049d1f9098ec473a522c5dd4ba5442bc1d3e1a086370  supabase/migrations/20260829140000_u6_compose_durable_external_work.sql
347d2dd76b6ff1e6aeb712872114470787f8ebe8f0a3bf70dbbf324d58bc1141  supabase/migrations/20260829150000_u6_application_purge_owner.sql
d5445f403171ce83782be75aa68a06f64a6311c3b5eea3afd30907bb73ce9a07  supabase/migrations/20260829160000_u7_member_event_scope.sql
3fd8a9b72a6f73b4615bc949e4b2064c653c4773106c4c5f91c816bcdd4d221f  supabase/migrations/20260829170000_u8_normalized_query_contracts.sql

## Installed object register

The U1 audit enumerates every relation, column, constraint, index, policy,
grant, routine signature and property, trigger, role/membership, extension,
queue, schedule, bucket, Vault **name**, and exposed-schema object. These
groupings assign one target owner and disposition to every returned row.

| Objects | Current owner / consumers | Disposition |
|---|---|---|
| `argus_app`: 58 relations including immutable `member_lifecycles`, lifecycle-bound member children, normalized editorial/ritual/community relations, and sealed render documents | Identity, content, member API/admin API | U3 owns the lifecycle parent/security foundation; U4 owns dependent Argus relations and exact application/editorial capabilities; U7 owns broader composition. |
| `argus_brokerage`: 10 lifecycle-qualified connection/account/selection and typed capability/projection relations, with private diagnostic snapshots | Brokerage APIs, callback and lookup-only worker recovery | U5 target model; preserve Webull authority and at-most-once command boundary. |
| `argus_private`: 56 operational, credential, command, mapping, job, privacy, export-generation, Storage-authority, audit, waitlist and rate-limit relations | API/worker/waitlist capabilities only | U5 owns brokerage credentials/mappings/commands; U6 owns the job registry, queue adapter, sealed exports and external-effect sagas behind exact capabilities. |
| 201 distinct routine names across the three Argus schemas and their overloads | Triggers, API adapters, worker, Cron/`pg_net` | U3-U6 foundation, domain, brokerage and durable-work routines are exact-signature, pinned-search-path and narrowly owned. |
| Application policies and triggers | New lifecycle policies plus compatibility `argus_runtime`, `argus_worker`, `argus_waitlist` policies/triggers | U3 foundation is command-specific and fail-closed; U4-U6 remove generic owner policies and the universal epoch trigger as their relations cut over. |
| Roles | `argus_identity_owner`, `argus_app_owner`, `argus_application_purge_owner`, `argus_publication_owner`, `argus_brokerage_owner`, `argus_jobs_owner`; `argus_member`, `argus_staff`, `argus_callback`, `argus_migration`; compatibility runtime/worker/waitlist roles and login shells | U3 owns identity; U4 owns application/publication; U5 owns brokerage; U6's NOLOGIN jobs owner is constrained by FORCE RLS and exact durable-work capabilities, while the separate NOLOGIN/NOBYPASSRLS application-purge owner holds only the fixed tombstone-scoped purge port and its exact relation actions. |
| Extensions | `pgcrypto`, `pgmq`, `pg_cron`, `pg_net`, `supabase_vault`, test-only `pgtap` | Preserve supported APIs. Do not pin extension versions; 2026-08 changelog says explicit version clauses are ignored. |
| Queues | `argus_jobs`, `brokerage_refresh`, `brokerage_reconcile` | Preserve opaque event-id transport; U6 single-sources registry. |
| Cron | outbox relay, expired-work recovery, retained scheduling, Webull recovery, worker invoke, waitlist retention | Preserve bounded schedules; U6 owns parity and failure handling. |
| Storage | private `member-media`, `media-quarantine`, `privacy-exports`; policies only on `storage.objects` | Preserve supported Storage APIs; U3/U6 bind lifecycle and truthful validation. |
| Vault and Edge secrets | Worker URL/proof and provider key **names only**; values are never inventoried | Preserve out-of-band provisioning; U9 verifies names and reconstruction. |
| Exposed schemas | `public`, `graphql_public`; no Argus relation or routine is permitted | Preserve. Any Argus object or grant here is a hard failure. |

### Member lifecycle inventory

`argus_app.member_lifecycles(id,tenant_id,identity_subject_id)` is the immutable
identity parent. `argus_app.members` has a non-replaceable tenant/lifecycle FK;
Auth provisioning creates one open lifecycle and member-root deletion closes
without erasing it. Trusted API context accepts only user/session/AAL from the
verified server boundary and derives tenant/lifecycle from that open parent.

U4 application rows, U5 brokerage state, and U6 member-owned outbox, job,
receipt, privacy, export-generation, media-intent, managed-object and effect
state are lifecycle-qualified. Global deletion work is deliberately unscoped
and can execute only against its lifecycle-qualified tombstone. U6 removes
request/worker table DML for durable work and exposes bounded member, worker,
and staff capabilities. Cross-system AE4 remains a U9 hosted race gate rather
than an unverified deployment claim.

| Class | Read/write | Export | Purge/retention | Storage/provider behavior |
|---|---|---|---|---|
| Profile/preferences/onboarding/consent/notifications/intentions/social state | Owner runtime plus reviewed staff cases | Included where classified | Cascade/purge by current epoch | Avatar/media links require lifecycle-qualified object authority. |
| Briefings and read state | Owner; generation requests and notifications are recorded only after their internal facts exist | Included in one sealed generation | Lifecycle purge through the jobs-owner phase | No placeholder state is called generated or delivered. |
| Privacy requests/artifacts/tombstones/receipts | Owner or narrow worker/staff capability | Deterministic, cutoff-bound sealed generation | Tombstone survives Auth deletion; immutable object receipts; Auth deletion last | Private immutable object identity; one-time URL issuance with a disclosed reusable signed-URL lifetime of at most 30 seconds. |
| Brokerage connections/projections/mappings/credentials/commands | Member/callback/staff exact capabilities; worker only through lookup/recovery routines | Redacted state only; no provider secrets | Fence then cryptographic destruction, preserve command audit parents, and bounded projection purge | Webull remains authoritative; ambiguity is never generic retry or resubmit. |
| Outbox/jobs/attempts/receipts/DLQ | Jobs-owner commands; worker lifecycle capabilities; bounded redacted staff diagnostics | Operational evidence only | Registry-bounded retry/DLQ and seven-day Cron run-detail retention | Opaque event id; lifecycle and lease checked on every claim/effect checkpoint/completion. |
| Media upload/asset state | Member allocation/finalization capabilities and worker saga checkpoints | Immutable object identifier/hash only | Tombstone, bounded cleanup and reconciliation | Structural validation is explicitly not malware-clear; only the verified object version may publish. |
| OAuth states, completion handles, step-up and staff receipts | Narrow capability routines | Excluded from export | Short TTL/consume/revoke | Old lifecycle and stale sessions must never authorize. |
| Waitlist | Dedicated unauthenticated Edge capability | Separate provisional data class | 23m29d Cron retention; verified removal out of band | No member lifecycle until conversion is explicitly designed. |

The reviewed array, JSON and polymorphic target model is versioned separately
in `supabase-target-model-contract-v1.md`.

## Edge ingress controls and negative probes

All four functions currently set `verify_jwt = false`; that fact is not an
authorization waiver. Each handler owns a different explicit ingress contract.
Supabase’s 2026 function guidance distinguishes platform JWT verification from
handler authorization, so U2/U3 must re-verify the reviewed configuration
against the upgraded runtime before promotion.

### api ingress

- Control: exact Supabase issuer/audience/signature/expiry/session/role/AAL
  verification against Auth JWKS; `user_metadata` is ignored; CORS and route
  rate limits are applied by the Hono application; dedicated `argus_edge`
  transaction-pooler login only.
- Negative probes: absent/malformed/expired/wrong-audience/wrong-issuer JWT,
  future AMR, deleted session, foreign origin, oversized/invalid body, direct
  private-schema/Data API access, and owner-field injection all fail closed.

### worker ingress

- Control: POST plus JSON only, 1,024-byte body, bounded batch 1..25, HMAC
  timestamp/proof, 60-second age, bounded secret overlap, one-use nonce, opaque
  event id, dedicated `argus_worker_edge`, and background/provider fences.
- Negative probes: method/media/body/unknown-field rejection, missing/forged/
  stale/future proof, replayed nonce, overlap over ten minutes, member JWT,
  handler not allowlisted, financial execute capability, lease loss, and stale
  lifecycle work.

### webull-callback ingress

- Control: GET only, canonical query encoding, exact field allowlist, one-use
  high-entropy state hash, contract/environment match, generic non-cacheable
  responses, dedicated Edge DB role, and blocked provider until partner gate.
- Negative probes: duplicate/unknown/query-smuggling fields, missing or reused
  state, mixed success/error outcome, ambiguous percent/plus encoding, wrong
  environment/version, oversized code/query, cross-lifecycle state, and
  unapproved return target.

### waitlist ingress

- Control: exact configured production/beta origin, POST/OPTIONS only, JSON and
  4,096-byte body, strict shape/consent/notice version, pseudonymous source and
  route rate limits, Turnstile hostname proof, dedicated role/function, and
  non-enumerating responses.
- Negative probes: foreign/null origin, disabled switch, wrong method/media/
  encoding, oversized or augmented body, stale notice, no consent, malformed
  source, missing secrets, source/route limit, Turnstile reject/outage, DB
  timeout, and direct table/Data API access.

## External-effect capability and intended guarantee

| Effect key | Current capability / provider behavior | Intended guarantee and owner |
|---|---|---|
| auth-jwks-read | API verifier performs cached HTTPS JWKS reads; provider supports idempotent reads | Fail closed on timeout/key/claim error; no DB transaction held. U3/U7. |
| auth-admin-delete | Worker secret-key adapter deletes one Auth user; repeat outcome may be not-found | Prepare/fence/purge first, Auth deletion last, completion reconciles absence. U6. |
| storage-read | Worker/API secret-key adapters inspect or download private objects | Read immutable key/hash from sealed generation; changed/missing object fails that generation. U6. |
| storage-write | Privacy/media worker writes private object through Storage API | Deterministic generation/object key plus checksum; retry reconciles exact object, never overwrites another lifecycle. U6. |
| storage-delete | Worker removes bounded batches; provider supports repeated missing-object deletion | Persist intended object list first; delete outside transaction; record per-object receipt; reconcile missing as success only for exact key. U6. |
| storage-sign | API creates short-lived private signed URL | Lifecycle/current-owner check immediately before mint; at most 30 seconds residual URL lifetime; no raw object coordinates in API; issuance receipt is single-use but the signed URL itself is reusable until expiry. U3/U6. |
| turnstile-verify | Waitlist POST with provider idempotency key; response can reject or be unavailable | Two bounded attempts only for provider internal/transient failure; no submission before positive hostname-bound proof. Waitlist/platform. |
| webull-authorization-exchange | Callback exchanges one authorization code and reads accounts; exact partner contract currently blocked | One-use state; no replay; failure is generic and connection state is durable. U5. |
| webull-token-refresh | Provider may rotate/invalidate refresh tokens and has ambiguous post-response failures | Persist egress marker first; unknown outcome fences old credential and requires reauthorization; never blind retry. U5/U6. |
| webull-projection-read | Account/balance/position/restriction/order reads are idempotent but provider freshness/partial responses vary | Lease, read outside transaction, validate contract, append immutable generation with explicit availability/timestamps. U5/U6. |
| webull-command-submit | Provider command can succeed with lost response; no assumed provider idempotency beyond confirmed contract | Durable command and attempt before exactly one submit; account ambiguity fence; no worker submit path. U5. |
| webull-command-lookup | Exact existing-order lookup is read-only but not-found can remain ambiguous | Original identifier/economics only; bounded lookup, positive match resolves, otherwise retry/manual review; never resubmit. U5/U6. |

## Recovery coverage matrix

| State class | Backup includes | Excluded / reconstruction | U1 evidence and gate |
|---|---|---|---|
| Postgres application/private state | Hosted database backup when configured | Runtime secrets and managed-service config | Restore drill absent; U2/U9 owner. |
| Auth users/sessions/metadata | Product-dependent; do not assume DB backup is sufficient | OAuth provider config, SMTP, signing keys/sessions may require supported export/config | Hosted discovery and isolated drill required before eligibility. |
| Storage objects | Separate object backup/versioning policy | DB rows alone do not restore bytes | Reconcile manifest keys/hashes in isolated restore. |
| PGMQ | Queue tables may be in DB backup | In-flight visibility and worker invocation state need reconciliation | Drain/fence/replay procedure required U6/U9. |
| Cron | Catalog may be in DB backup | Schedule enablement and deployed worker URL/proof names | Recreate from reviewed migration and verify exactly. |
| Roles/grants/default privileges | Database backup/DDL | Login passwords are out-of-band | Recreate roles with null password, rotate secrets, compare catalog. |
| Vault | Never inventory values | Recreate reviewed secret names and rotate values | Name-only contract plus invocation negative probe. |
| Edge secrets/functions | Not database state | Re-deploy exact Git revision and re-provision secret names | Revision handshake and four-function inventory required. |

No recovery row is “proven” in U1. Therefore restoration, disposal and
destructive-reset claims remain blocked.

## Performance and query-plan baseline

`scripts/audit-supabase-architecture.sql` emits read-only `EXPLAIN (FORMAT
JSON)` plans for owner lists, editorial publication, discovery/search, outbox
and job claims, privacy export, and brokerage projections. Because U5 denies
retained postgres direct command/reconciliation reads, the permanent audit
records deterministic Webull-recovery relation statistics plus exact index
keys, predicates, and valid/ready/live flags instead; the rollback-only U5
harness owns its representative-volume `EXPLAIN (ANALYZE, BUFFERS)` evidence.
The representative-volume/concurrency gates and thresholds are versioned in
`supabase-performance-and-operations-budget-v1.md`. U1 could not supply
`ANALYZE, BUFFERS` evidence. U4 now records a rollback-only local baseline at
100k members, the heavy-owner fixture, 25k editorial items, 250k revisions and
25k sealed documents: the five owner pages use their U4 indexes in 0.337-33.633
ms, and the bounded publication page returns 100 rows in 6.320 ms with an exact
100-row returned-node estimate. No plan spills. Concurrent/hosted p95 and the
50-ordered-child publication transaction remain explicit U9 gates.

U5's rollback-only representative fixture measured the latest typed projection
at 16.104 ms, append-supporting generation lookup at 46.037 ms, the
account-scoped ambiguity gate at 0.098 ms, and the 10k-due-row reconciliation
claim at 17.353 ms with 25 rows locked and no sort spill. The 16-way bounded
reconciliation claim p95 was 91.130 ms; token refresh, projection refresh, and
command recovery completed without deadlock, list ingestion serialized before
reauthorization, and a post-fence write was rejected. Hosted plans, the
100-read/8-refresh mix, and provider lookup latency remain U9 gates.

Local security advisors, performance advisors, and error-level database lint
are empty. U6 removes the `auth_rls_initplan` warning on
`argus_private.staff_step_up_receipts` and the application-purge-owner policy
overlap. U8 then composes the five remaining owner/staff compatibility-policy
overlaps into one predicate per command without broadening member or staff
authority. A catalog pgTAP assertion prevents an `argus_runtime` overlap from
being reintroduced.

## Open remediation items

| ID | Current shortcut/gap | Disposition and owner |
|---|---|---|
| U1-G01 | Mutable deletion epoch is not an immutable member lifecycle; stale rows can remain structurally addressable. | Resolved locally through U6: U3 supplies the immutable parent, U4 binds application children, U5 binds brokerage, and U6 binds member-owned durable work while global purge events require an exact tombstone. Hosted AE4 remains U9. |
| U1-G02 | Generic generated owner policies and broad table grants obscure exact capabilities. | Resolved for U3-U6-owned surfaces: application, brokerage and durable work use NOLOGIN owners, exact actions and narrow commands. Remaining compatibility roles are assigned to U7/U8/U10, not used for U6 job/privacy authority. |
| U1-G03 | UUID arrays, JSON-backed editorial relations and polymorphic IDs lack parent-qualified relational enforcement. | Resolved for U4 application/editorial, U5 brokerage, and U6 lifecycle/job/export/Storage authority. Remaining downstream compatibility payloads are U7/U8/U10-owned. |
| U1-G04 | Provider projection JSON is both convenient output and weakly bounded storage. | Resolved U5: typed facts serve reads and feature gates; opaque provider snapshots are private, bounded, versioned, hashed, quarantinable diagnostic evidence only. |
| U1-G05 | SQL and TypeScript event/handler registries are independently maintained. | Resolved U6 with one versioned SQL registry and exact TypeScript parity tests for event, handler, topic, owner, effect and retry metadata. |
| U1-G06 | Privacy export currently relies on runtime snapshot behavior rather than immutable generation manifests. | Resolved U6 with one repeatable-read preparation transaction, ordered normalized rows, collection fingerprints, immutable object hashes, a cutoff and a sealed manifest checksum; a failed retry creates a new generation. |
| U1-G07 | Retained repository SQL remains centralized in one large adapter. | Resolved U7: the compatibility facade only re-exports bounded-context repositories, and cross-domain behavior composes through ports and services. |
| U1-G08 | Discovery/search uses retained compatibility behavior without final indexed keyset contract. | Resolved U8: typed predicates, deterministic keyset functions, one-row overfetch guards, source-bounded diagnostics, and complete supporting indexes are enforced. |
| U1-G09 | CLI pin 2.65.5 was below the reviewed 2.115.0 gate. | Resolved U2: CI, inventory and developer operations pin exact 2.115.0 without changing the machine-wide install. |
| U1-G10 | Hosted identity, counts, advisors, recovery drill and disposability are unknown. | Forward-only selected U2 without hosted inspection; U9 owns fresh hosted evidence before promotion and destructive action remains forbidden. |
| U1-G11 | Existing tests still include some migration-source assertions where catalog behavior is observable. | Resolved for U3-U9 local scope: critical privileges, registries, lifecycle relationships, queue/storage states, keyset contracts, stale-command recovery, and all foreign-key indexes have catalog or black-box coverage. Promotion-file structure remains source-tested because it is not a database object. |
| U1-G12 | Current `media_assets.quarantine_status = clear` vocabulary can overstate structural validation. | Resolved U6: new state uses `structurally_verified`, publish is checksum/version-bound, and neither code nor event vocabulary claims malware clearance without a real attestation. |

Run `scripts/check-supabase-architecture-contract.sh --offline` on every
inventory change. With an explicitly selected disposable database and `psql`
available, add `--database-url "$URL"`; the checker never infers a hosted URL
or prints it.

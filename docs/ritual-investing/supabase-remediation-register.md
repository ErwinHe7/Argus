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
<!-- transitive:ritual-investing-api/src/domains/brokerage-accounts -->
<!-- transitive:ritual-investing-api/src/domains/brokerage-assets -->
<!-- transitive:ritual-investing-api/src/domains/brokerage-connections -->
<!-- transitive:ritual-investing-api/src/domains/brokerage-orders -->
<!-- transitive:ritual-investing-api/src/domains/brokerage-projections -->
<!-- transitive:ritual-investing-api/src/domains/intentions -->
<!-- transitive:ritual-investing-api/src/domains/media -->
<!-- transitive:ritual-investing-api/src/domains/privacy -->
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
| API composition | `ritual-investing-api/src/db`, `src/jobs`, the listed brokerage/intentions/media/privacy/session domain directories, `openapi`, and API scripts |
| Generated contract | `ritual-investing-api-client/doc`, `lib/generated`, and its contract test |
| Member consumer | `core/api`, `core/auth`, `core/bootstrap`, Auth presentation, and each listed feature `data` adapter module |
| Admin consumer | `ritual-investing-admin/lib` and its integration contract |
| Demo/site boundaries | Demo provider stubs and composition, plus the waitlist landing module |

<!-- scope:CONCEPTS.md -->
<!-- scope:MODEL_SOURCE_MAP.zh-CN.md -->
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

## Installed object register

The U1 audit enumerates every relation, column, constraint, index, policy,
grant, routine signature and property, trigger, role/membership, extension,
queue, schedule, bucket, Vault **name**, and exposed-schema object. These
groupings assign one target owner and disposition to every returned row.

| Objects | Current owner / consumers | Disposition |
|---|---|---|
| `argus_app`: 41 relations from `members` through content/editorial, ritual, social, intention, briefing, privacy and moderation state | Identity, content, member API/admin API | Preserve product meaning; U3 owns lifecycle/security, U4 relational model, U7 composition. |
| `argus_brokerage`: connections, accounts, active selection, general and order projection generations | Brokerage APIs, callback and worker | Preserve Webull authority boundary; U5 owns redesign. |
| `argus_private`: 40 operational, credential, command, mapping, job, privacy, audit, waitlist and rate-limit relations | API/worker/waitlist capabilities only | Keep private; U3/U5/U6 own replacements. |
| 80 distinct `argus_private` routine names and their overloads | Triggers, API adapters, worker, Cron/`pg_net` | Preserve current semantics; replace by domain module, exact signature and least privilege. |
| Application policies and triggers | `argus_runtime`, `argus_worker`, `argus_waitlist`; member/staff/API jobs | Preserve deny-by-default; U3 replaces generic owner policy generation. |
| Roles | `argus_runtime`, `argus_worker`, `argus_waitlist`; login shells `argus_edge`, `argus_worker_edge`, `argus_waitlist_edge` | Preserve capability shape; narrow membership/grants in U3. |
| Extensions | `pgcrypto`, `pgmq`, `pg_cron`, `pg_net`, `supabase_vault`, test-only `pgtap` | Preserve supported APIs. Do not pin extension versions; 2026-08 changelog says explicit version clauses are ignored. |
| Queues | `argus_jobs`, `brokerage_refresh`, `brokerage_reconcile` | Preserve opaque event-id transport; U6 single-sources registry. |
| Cron | outbox relay, expired-work recovery, retained scheduling, Webull recovery, worker invoke, waitlist retention | Preserve bounded schedules; U6 owns parity and failure handling. |
| Storage | private `member-media`, `media-quarantine`, `privacy-exports`; policies only on `storage.objects` | Preserve supported Storage APIs; U3/U6 bind lifecycle and truthful validation. |
| Vault and Edge secrets | Worker URL/proof and provider key **names only**; values are never inventoried | Preserve out-of-band provisioning; U9 verifies names and reconstruction. |
| Exposed schemas | `public`, `graphql_public`; no Argus relation or routine is permitted | Preserve. Any Argus object or grant here is a hard failure. |

### Member lifecycle inventory

`argus_app.members(user_id, deletion_epoch)` is the current mutable epoch root.
All member-owned application, brokerage and private rows with `user_id` plus
`deletion_epoch`, as well as Storage object prefixes, JWT/session callbacks,
job/outbox ownership, receipts, caches and provider credentials, are in scope.
The current epoch closes writes but does not provide the required immutable
incarnation identity; `member_lifecycle.test.sql` records that gap as TODO/red
characterization. U3 owns the replacement and U6 owns export/purge sagas.

| Class | Read/write | Export | Purge/retention | Storage/provider behavior |
|---|---|---|---|---|
| Profile/preferences/onboarding/consent/notifications/intentions/social state | Owner runtime plus reviewed staff cases | Included where classified | Cascade/purge by current epoch | Avatar/media links require lifecycle-qualified object authority. |
| Briefings and read state | Owner; generated rows immutable, read state mutable | Included | Owner purge; generated retention TBD U6 | Export must use one sealed generation. |
| Privacy requests/artifacts/tombstones/receipts | Owner or narrow worker/staff capability | Process authority | Tombstone survives Auth deletion; artifacts expire/revoke | Private bucket; Auth deletion last. |
| Brokerage connections/projections/mappings/credentials/commands | Owner API; worker only through exact routines | Redacted state only; no provider secrets | Fence then cryptographic destruction and bounded projection purge | Webull remains authoritative; ambiguity is never generic retry. |
| Outbox/jobs/attempts/receipts/DLQ | Narrow worker, staff diagnostics read | Operational evidence only | Bounded retries/dead-letter retention TBD U6 | Opaque event id; lifecycle checked on claim/completion. |
| Media upload/asset state | Owner API and worker | Object identifier/hash only | Quarantine/orphan sweep/purge | Structural validation is not malware-clear. |
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
| storage-sign | API creates short-lived private signed URL | Lifecycle/current-owner check immediately before mint; five-minute maximum; no raw object coordinates in API. U3/U6. |
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
and job claims, privacy export, brokerage projections and Webull recovery. The
representative-volume/concurrency gates and thresholds are versioned in
`supabase-performance-and-operations-budget-v1.md`. U1 cannot supply
`ANALYZE, BUFFERS` evidence without a disposable seeded stack; those gates are
owned TBDs rather than invented measurements.

## Open remediation items

| ID | Current shortcut/gap | Disposition and owner |
|---|---|---|
| U1-G01 | Mutable deletion epoch is not an immutable member lifecycle; stale rows can remain structurally addressable. | Redesign U3; lifecycle TODO/red characterization retained. |
| U1-G02 | Generic generated owner policies and broad table grants obscure exact capabilities. | Replace U3 with exact policies/grants/signatures. |
| U1-G03 | UUID arrays, JSON-backed editorial relations and polymorphic IDs lack parent-qualified relational enforcement. | Replace U4 per target-model contract. |
| U1-G04 | Provider projection JSON is both convenient output and weakly bounded storage. | Preserve opaque versioned snapshots only; normalize addressable facts in U5. |
| U1-G05 | SQL and TypeScript event/handler registries are independently maintained. | Single-source or generated parity in U6. |
| U1-G06 | Privacy export currently relies on runtime snapshot behavior rather than immutable generation manifests. | Replace U6 per KTD12. |
| U1-G07 | Retained repository SQL remains centralized in one large adapter. | Compose by bounded context in U7. |
| U1-G08 | Discovery/search uses retained compatibility behavior without final indexed keyset contract. | Replace U8. |
| U1-G09 | CLI pin 2.65.5 was below the reviewed 2.115.0 gate. | Resolved U2: CI, inventory and developer operations pin exact 2.115.0 without changing the machine-wide install. |
| U1-G10 | Hosted identity, counts, advisors, recovery drill and disposability are unknown. | Forward-only selected U2 without hosted inspection; U9 owns fresh hosted evidence before promotion and destructive action remains forbidden. |
| U1-G11 | Existing tests still include some migration-source assertions where catalog behavior is observable. | Keep as evidence for now; migrate to catalog/black-box coverage in U2-U6. |
| U1-G12 | Current `media_assets.quarantine_status = clear` vocabulary can overstate structural validation. | Truthful state replacement U6; no malware-clear claim before approved scanner attestation. |

Run `scripts/check-supabase-architecture-contract.sh --offline` on every
inventory change. With an explicitly selected disposable database and `psql`
available, add `--database-url "$URL"`; the checker never infers a hosted URL
or prints it.

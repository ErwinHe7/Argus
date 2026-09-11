# LeoInvestment destination provisioning

Humans and AI agents use `provision.sh` to prepare and reconcile Ritual's empty,
inactive destination infrastructure. Terraform owns resource, state, and lock
mutations; read-only Cloudflare and R2 APIs verify the destination and
postconditions. No Cloudflare plugin, CI job, daemon, or application release is
needed.

**Live provisioning is pending.** As of 2026-09-11, the checked-in profile has
`account_id: null`, `settings_verified: false`, and `bootstrap_host: null`.
An administrator must verify those values and the catalogs, and supply destination
provider and R2 credentials. No live resource creation, state migration, or R2
locking success is recorded here. Offline checks cannot establish that resources
exist.

| Target | Planned resources | Contents |
| --- | ---: | --- |
| `bootstrap` | 2 | Private prod and staging Terraform state buckets |
| `staging` | 15 | 4 Workers, 2 Pages projects, 2 KV namespaces, 4 application R2 buckets, 2 queues, 1 Turnstile widget |
| `prod` | 13 | 4 Workers, 2 KV namespaces, 4 application R2 buckets, 2 queues, 1 Turnstile widget |

Exact names and nonsecret settings are in the [staging catalog](environments/staging/catalog.json)
and [prod catalog](environments/prod/catalog.json). Workers remain never deployed
with subdomain and preview URLs disabled. Pages have no build source, deployments,
or custom domains; their platform `pages.dev` hostname is allowed. R2 buckets stay
private, including buckets named `public`. Queues stay paused without producers
or consumers. Turnstile widgets are unused with pre-clearance off; their new
secrets remain in protected Terraform artifacts.

Application uploads, Worker versions/deployments/bindings, cron, data copying,
source-secret migration, source changes, zones/Registrar, DNS, custom domains,
email routing, and traffic cutover are excluded. Supabase retains its current
backend role. These resource identities do not constitute a deployed or migrated
app. Code uploads require a separate deployment workflow.

## Prepare the designated host

Run from the repository root with Python **3.10 or later**, Git, and Terraform
**1.15.x**. Committed provider locks resolve Cloudflare **5.24.0**; normal
initialization uses `-lockfile=readonly`.

```sh
python3 --version
git --version
"${RITUAL_TERRAFORM_BIN:-terraform}" version
python3 -c 'import socket; print(socket.gethostname())'
git rev-parse HEAD
```

The CLI selects `terraform` from `PATH`, or the installed executable named by
`RITUAL_TERRAFORM_BIN`. Its resolved path, digest, and version are bound to each
plan; changing the executable requires a fresh plan. This variable is also the
local test seam. There is no API URL, backend, profile-path, or revision override.

An administrator must review and commit [profiles/leoinvestment.json](profiles/leoinvestment.json)
and both catalogs before remote planning:

- Set the actual verified 32-character lowercase hexadecimal account ID and retain
  the exact account name `LeoInvestment`. The source account is rejected.
- Confirm catalog names/settings, Turnstile allowlists, R2 locations/jurisdictions,
  and account entitlement for the beta Worker identity API; set
  `settings_verified` to `true`.
- Set `bootstrap_host` to the exact hostname printed above. The current CLI
  requires this host for every target. Keep one operator host and its persistent
  recovery directory; a local filesystem lock cannot serialize another host.

Supply credentials only through the process environment using your normal secret
delivery method. Never place them in arguments, chat, profiles, tfvars, backend
files, fixtures, or commits.

| Environment variable | Purpose |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Destination provider operations and verification reads |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | Separate R2 S3 object credentials for both state buckets |
| `AWS_SESSION_TOKEN` | Optional R2 session credential |

Scope the provider token to LeoInvestment with Account Settings Read and resource read/edit
permissions for Workers Scripts, Pages, Workers KV Storage, Workers R2 Storage,
Queues, and Turnstile. API documentation uses Write or Edit labels; see
[Workers](https://developers.cloudflare.com/api/resources/workers/subresources/beta/subresources/workers/methods/create/),
[Pages](https://developers.cloudflare.com/api/resources/pages/subresources/projects/methods/create/),
[R2](https://developers.cloudflare.com/api/resources/r2/subresources/buckets/methods/create/),
[Queues](https://developers.cloudflare.com/api/resources/queues/methods/create/), and
[Turnstile](https://developers.cloudflare.com/turnstile/get-started/widget-management/api/).
Verification also needs Zone Read and Workers Routes Read across destination
zones to prove these Workers have no routes; no zone/DNS writes are needed.
R2 credentials need Object Read & Write on both state buckets, including Terraform
lock creation/deletion. Bucket-specific object credentials can arrive after
bucket creation; use bootstrap resume below.

Remove inherited `TF_*`, alternate `CLOUDFLARE_*`, noncredential `AWS_*`, and
`GIT_*` variables (`GIT_PAGER` is allowed). The CLI rejects these overrides,
including `TF_VAR_*`, and uses its own private Terraform CLI configuration instead
of the default `.terraformrc`. Each remote action verifies the exact account ID
and name. Failed authorization, transport errors, and incomplete inventories
cannot establish absence. Existing names without matching destination state are
not adopted.

## Plan, apply, and verify

Use an explicit action, `--profile leoinvestment`, and one `--target bootstrap`,
`staging`, or `prod`. Apply requires the absolute artifact directory returned by
plan; other actions reject `--artifact`. Resume is bootstrap-only. Omit `--json`
for the same decision and plan identity in human format. Unknown, abbreviated, or
duplicate arguments fail.

“Latest infrastructure code” means the selected checked-in `HEAD` when planning.
The CLI never pulls or selects the latest branch. Relevant CLI/policy code,
profile, root configuration, catalogs, backend settings, module, and provider
locks must match `HEAD` in both index and working tree. Relevant untracked/ignored
Terraform inputs are rejected; unrelated work may remain dirty. Any new commit
changes the revision binding and requires a fresh plan before apply.

Start with bootstrap:

```sh
sh infra/terraform/ritual-investing-destination/provision.sh plan \
  --profile leoinvestment --target bootstrap --json
```

Review the receipt's destination, revision, counts, and plan identity. Set
`bootstrap_artifact` to that receipt's exact `artifact` value, then run:

```sh
sh infra/terraform/ritual-investing-destination/provision.sh apply \
  --profile leoinvestment --target bootstrap --artifact "${bootstrap_artifact:?Set from the plan receipt}" --json
sh infra/terraform/ritual-investing-destination/provision.sh verify \
  --profile leoinvestment --target bootstrap --json
```

Bootstrap creates two private buckets using durable local state, migrates its
state to the prod bucket, verifies read-back, and runs **two actual Terraform
locking probes**, one per state bucket. Each must reject a second contender,
release normally, and permit later acquisition. Ownership/privacy checks and a
refreshed remote no-change plan must also pass.

| Target | State bucket | State key |
| --- | --- | --- |
| `bootstrap` | `ritual-investing-terraform-state-prod` | `bootstrap/terraform.tfstate` |
| `staging` | `ritual-investing-terraform-state-staging` | `workloads/terraform.tfstate` |
| `prod` | `ritual-investing-terraform-state-prod` | `workloads/terraform.tfstate` |

Provision staging next. Set `staging_artifact` from its plan receipt before apply:

```sh
sh infra/terraform/ritual-investing-destination/provision.sh plan \
  --profile leoinvestment --target staging --json
sh infra/terraform/ritual-investing-destination/provision.sh apply \
  --profile leoinvestment --target staging --artifact "${staging_artifact:?Set from the staging plan receipt}" --json
sh infra/terraform/ritual-investing-destination/provision.sh verify \
  --profile leoinvestment --target staging --json
```

After staging succeeds, use a separate prod plan and its `prod_artifact` value:

```sh
sh infra/terraform/ritual-investing-destination/provision.sh plan \
  --profile leoinvestment --target prod --json
sh infra/terraform/ritual-investing-destination/provision.sh apply \
  --profile leoinvestment --target prod --artifact "${prod_artifact:?Set from the prod plan receipt}" --json
sh infra/terraform/ritual-investing-destination/provision.sh verify \
  --profile leoinvestment --target prod --json
```

Every workload operation requires both recorded lock proofs and a fresh remote
no-change bootstrap plan; `RemoteReady` alone is insufficient. Apply rechecks the
saved binary, manifest, snapshot, executable, current inputs, state, and remote
postconditions before consuming that exact plan. It never regenerates the plan.
Successful apply includes independent resource checks and a refreshed no-change
plan. Verification failure cannot return success.

After complete initial verification, supported resource updates are limited to
queue `delivery_delay` (integer seconds, 0–86400) and `message_retention_period`
(integer seconds, 60–1209600, subject to account entitlement). Commit the catalog
change, then use the same plan/apply/verify sequence. Queues must remain paused
and unattached. Partial initial provisioning does not enable updates. Deletion,
replacement, imports, moves, unsupported fields, hidden resources/drift, and
unknown safety-critical values fail closed.

A concrete agent instruction:

> Read AGENTS.md and the destination provisioning README. Use the selected
> checked-in HEAD on the designated host to plan staging with profile
> leoinvestment. Report the sanitized receipt and, within the authorized
> provisioning scope, apply that exact artifact and verify staging. Preserve
> unrelated work and private recovery files. Stop on prerequisite, policy,
> state-authority, locking, or verification failures and report the receipt's
> recovery instruction. Do not fetch code or deploy application assets.

## Receipts and recovery

JSON mode prints one object to stdout without human diagnostics on stderr. Exit
0 means `planned-changes`, `planned-no-change`, `applied`, `verified`, or `resumed`;
other outcomes exit 1. A no-change **plan** alone does not establish independent
hosted verification.

Receipts contain only `schema_version`, `action`, `profile`, `target`, `account`,
`revision`, `plan_identity`, `counts`, `artifact`, `outcome`, and `recovery`.
Unavailable metadata is `null`. Counts are `create`, `no-op`, `update`, and
`delete`; apply retains the saved plan's counts. Raw Terraform/API output,
resource secrets, and credentials are excluded.

| Outcome | Next step |
| --- | --- |
| `planned-changes`, `planned-no-change` | Review and retain the artifact; apply explicitly if needed. |
| `applied`, `verified` | Postconditions and refreshed no-change verification passed; retain evidence. |
| `resumed` | Original bootstrap snapshot migrated and verified; reconcile the current checkout before workloads. |
| `invalid-arguments`, `prerequisite-failure`, `unsafe-environment` | Correct syntax, committed profile/host/tools/credentials, or inherited overrides. |
| `stale-inputs`, `unsafe-plan` | Review intended inputs/policy and obtain a fresh safe plan. |
| `bootstrap-incomplete` | Complete bootstrap recovery and verify remote state. |
| `consumed-plan`, `partial-apply` | Preserve state; resume or obtain a fresh plan as described below. Never replay. |
| `lock-contention` | Wait for the existing operator to finish, then retry; do not force-unlock. |
| `recovery-required` | Stop remote operations and resolve state authority from retained evidence. |
| `verification-failure`, `outside-provisioning-scope` | Investigate permissions, ownership, drift, or activation; no automatic adoption or cleanup. |
| `terraform-failure`, `internal-failure` | Inspect protected diagnostics and follow the receipt's recovery instruction. |

An apply artifact is consumed before Terraform starts, including failed or
interrupted attempts. Cancellation waits for Terraform to exit before releasing
the account lock; private state and logs remain available. For a partial workload
apply, obtain a fresh plan from retained state. For partial **local bootstrap**,
a fresh plan must use the original
revision, snapshot, and valid local state. If prod exists, R2 credentials must
prove the remote bootstrap key absent. Restore the original checkout without
discarding unrelated work when necessary. A changed checkout cannot replace a
consumed bootstrap snapshot.

If both buckets exist but R2 credentials are missing, bootstrap records
`AwaitingBackendCredentials` and returns `bootstrap-incomplete`. Supply the R2
environment credentials and run:

```sh
sh infra/terraform/ritual-investing-destination/provision.sh resume \
  --profile leoinvestment --target bootstrap --json
```

Resume never applies again. It uses the original snapshot and Terraform executable
identity even after a checkout change, and reports the original revision. The
current profile must remain committed and match the account and host. After
resume, plan and verify bootstrap against the intended current checkout before
workloads. [Bootstrap recovery](bootstrap/README.md) explains migration and state
authority in detail.

## Private artifacts

The canonical account storage is outside the repository at
`~/.local/state/ritual-investing-destination/accounts/<verified-account-id>/`.
Directories use `0700`; files use `0600`. It contains the account lock, phase
metadata, bootstrap `snapshot/` and `work/`, local state authority, backups,
locking evidence, and per-action `plans/<random-id>/` directories.

Plan directories retain sensitive binary/JSON plans, exact input snapshots,
working files, API responses, logs, `manifest.json`, and `receipt.json`. The
manifest binds revision, input digests, schema/CLI version, profile/target/account,
backend, Terraform executable, plan digest, state digest, and local/remote mode into
`plan_identity`. Integrity evidence never replaces current state and remote checks.

Keep bootstrap recovery storage and referenced original plans on the designated
host. Preserve normal, backup, and emergency state, snapshots, phase metadata,
probe evidence, and logs through recovery and verification. Do not commit or
paste raw artifacts into agent context. Retire completed plan artifacts only once
verification passes and recovery no longer depends on them; cleanup is not
automatic.

Emergency `errored.tfstate`, divergent local/remote state, failed locking, or
unexpected provider behavior requires a stop. Never delete state or phase files
to restart, overwrite divergent remote state, fall back to an older normal state,
or force-unlock. A phase marker records progress, not state authority.

## Offline checks and prerequisite example

Run the CLI suite with synthetic inputs and fake external operations:

```sh
bash infra/terraform/ritual-investing-destination/tests/provision.test.sh
sh -n infra/terraform/ritual-investing-destination/provision.sh
```

The harness invokes the same shell CLI in disposable committed repositories and
checks human/JSON decisions, artifact identity, policy, redaction, and recovery.
It preserves the canonical checkout and index. To include the two optional real
Terraform local-backend checks, use the installed Terraform 1.15.x executable:

```sh
TEST_TERRAFORM_BIN="${RITUAL_TERRAFORM_BIN:-terraform}" \
  bash infra/terraform/ritual-investing-destination/tests/provision.test.sh
```

These tests make no Cloudflare mutations. On 2026-09-11 the complete CLI suite
passed 59 tests with no skips, including those local-backend checks. This is
offline evidence; hosted migration, R2 locking, and provisioning remain pending.

To see a sanitized prerequisite receipt without a remote request, run in an
environment without the rejected overrides described above:

```sh
env -u CLOUDFLARE_API_TOKEN sh infra/terraform/ritual-investing-destination/provision.sh plan \
  --profile leoinvestment --target bootstrap --json
```

With the current unconfigured profile, this returns `prerequisite-failure`, exit
1, and `null` account/revision/plan metadata. The missing token also prevents
remote execution after a valid profile is committed. Human and agent callers
receive the same decision. Live completion still needs verified account/settings,
credentials, actual migration and locking evidence, and resource/no-change
verification for bootstrap, staging, and prod.

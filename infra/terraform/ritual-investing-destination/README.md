# LeoInvestment destination provisioning

This feature provisions empty destination infrastructure through Terraform. The
current shared CLI supports **plan**. Apply, verify, and bootstrap resume are
recognized and fail closed with `action-unavailable` until the safe execution
unit is installed. Workload plans also fail closed until bootstrap has a freshly
verified remote no-change gate. A `RemoteReady` phase marker alone is insufficient.

Run the same command from a terminal or an AI agent:

```sh
sh infra/terraform/ritual-investing-destination/provision.sh plan \
  --profile leoinvestment --target bootstrap --json
```

The action must be `plan`, `apply`, `verify`, or `resume`. Supply exactly one
`--profile leoinvestment` and `--target bootstrap|staging|prod`. Apply requires
`--artifact /absolute/path/to/the/plan-directory`; other actions reject that
argument. Resume is bootstrap-only. Duplicate, abbreviated, unknown, and ambiguous
arguments fail. Omit `--json` for the equivalent human-readable decision and plan
identity. Neither mode displays Terraform or API payloads.

## Administrator prerequisites

`profiles/leoinvestment.json` intentionally has no usable destination defaults.
An administrator must supply and commit a verified 32-character lowercase
hexadecimal account ID, retain the exact account name `LeoInvestment`, confirm
the catalogs with `settings_verified: true`, and set `bootstrap_host` to the exact
value of Python `socket.gethostname()` on the designated bootstrap machine. The
personal source account is explicitly rejected. Each remote operation checks
`GET /accounts/{account_id}` for the same ID and name.

Use Python 3.10 or later, Git, and Terraform 1.15.x. Supply
`CLOUDFLARE_API_TOKEN` only through the environment. Backend operations also need
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and optionally `AWS_SESSION_TOKEN`.
No credentials belong in the profile, tfvars, command arguments, backend files,
or commits. The token needs the selected destination resource permissions; API
inventory reads must also succeed. The bootstrap plan requires a completely
paginated bucket list proving both destination state-bucket names absent. An
existing bucket is a collision requiring an explicit recovery/adoption decision.

The HTTP transport only issues GET requests to
`https://api.cloudflare.com/client/v4`; redirects and environment proxies are
disabled. Bucket reads follow the documented cursor pagination in
[Cloudflare List Buckets](https://developers.cloudflare.com/api/resources/r2/subresources/buckets/methods/list/).
Failed authorization, malformed responses, repeated cursors, or incomplete
pagination never establish absence.

Inherited `TF_*` variables are rejected, including `TF_VAR_*`, CLI argument/config
overrides, logging, workspace, data-directory, and provider-reattach settings.
AWS variables other than the three credential variables above are rejected, as
are alternate Cloudflare settings and inherited `GIT_*` selectors. The wrapper
sets the sole account variable itself and creates a private fixed Terraform CLI
config, so a user's default `.terraformrc` cannot enable provider overrides.
Normal Terraform initialization uses `-lockfile=readonly`; plans retain locking.

`RITUAL_TERRAFORM_BIN` is the existing local testing seam for selecting a Terraform
executable. The selected executable must report version 1.15.x; its resolved path,
file SHA-256, and version are bound into each manifest. There is no production
API URL, artifact-base, Git-revision, profile-path, or backend override. Offline
tests replace HTTP in a test interpreter and invoke a fake Terraform executable;
they cannot establish hosted Cloudflare or R2 behavior.

## Saved plan and recovery artifacts

Artifacts live outside the checkout at:

```text
~/.local/state/ritual-investing-destination/accounts/<account-id>/
  account.lock
  phase.json
  snapshot/                  preserved bootstrap configuration
  work/                      bootstrap working state and private command logs
  plans/<random-id>/
    manifest.json
    receipt.json
    plan.tfplan              sensitive binary saved plan
    plan.private.json        sensitive private plan inspection data
    terraform.rc
    snapshot/<repo-paths>    exact selected input bytes, preserving module paths
    api/                     private API responses
    logs/                    private version diagnostics
```

Directories use mode 0700 and files 0600. Account storage rejects symlink
traversal, shared ownership, and paths inside the checkout. One account-scoped
filesystem lock serializes local operations. Keep bootstrap on its designated
host and preserve this directory after any failure. The existing
[bootstrap recovery contract](bootstrap/README.md) describes state authority and
the later migration sequence. Bootstrap retains its consumed-plan prohibition;
partial bootstrap replanning belongs to the safe execution unit.

`manifest.json` schema version 1 contains:

| Field | Binding |
| --- | --- |
| `revision` | Exact checked-in `HEAD` selected when planning |
| `inputs` | Repository-relative file paths mapped to SHA-256 |
| `cli_version` | Shared interface version |
| `profile`, `target`, `account` | Explicit verified destination selection |
| `backend` | Account, target, fixed R2 endpoint, bucket, and state key |
| `terraform` | Resolved executable path, SHA-256, and version |
| `plan_sha256` | Saved binary plan SHA-256 |
| `plan_identity` | SHA-256 of the canonical binding fields above |

The input inventory includes all feature CLI/policy Python and shell files, the
selected profile, selected root configuration/catalog/backend/template/lock,
and shared resource module. HEAD blobs, index, and filesystem bytes must match.
Relevant untracked and ignored Terraform input files are rejected; unrelated app
work may remain dirty. Bootstrap currently rejects tracked `.tf.json`, `.tfvars`,
and `.tfvars.json` forms that the bootstrap helper cannot preserve, instead of
silently excluding them from execution. No command fetches code or accepts a
naked plan file.

`validate_artifact(...)` is the safe execution unit's integrity entry point. It
recomputes current inputs, revision, executable digest, snapshot inventory and
bytes, fixed CLI configuration, and binary-plan digest. Artifact paths must be
direct plan directories under the canonical account. Manifest booleans are never
authority. Integrity validation still requires fresh account, state, policy, and
hosted postcondition checks before any future apply; it cannot authorize mutation.

## Receipts and initial plan policy

JSON mode prints exactly one JSON object to stdout and no human diagnostics to
stderr. Exit 0 means a successfully inspected Terraform plan (Terraform exit 0 or
2); exit 1 means failure. Human mode uses the same decision and plan identity.
The receipt contains only `schema_version`, `action`, `profile`, `target`,
`account`, `revision`, `plan_identity`, `counts`, `artifact`, `outcome`, and
`recovery`. Metadata unavailable before preflight is `null`. The counts are
`create`, `no-op`, `update`, and `delete`. Recovery strings are fixed safe messages.

Plan outcomes are `planned-changes` or `planned-no-change`; the latter does not
claim independent hosted verification. Failures distinguish `invalid-arguments`,
`prerequisite-failure`, `unsafe-environment`, `stale-inputs`, `unsafe-plan`,
`bootstrap-incomplete`, `recovery-required`, `lock-contention`, `terraform-failure`,
`verification-failure`, `action-unavailable`, and `internal-failure`.

The initial policy checks the complete catalog resource address set, account,
provider, known inactive critical values, and create/no-op actions. It rejects
delete, replace, move, import, unsupported update/resource/configuration fields,
and incomplete plans. The pinned schema has computed create fields, so omitted
Pages build/deployment defaults, optional queue/R2 defaults, and disabled Worker
observability defaults may remain unknown. Configuration expressions must still
omit Pages integration. Worker subdomain and previews must be known false; queues
must be known paused. Computed IDs, dates, URLs, and Turnstile secrets are never
required known on create or emitted in the receipt. New Turnstile secrets remain
sensitive in the protected Terraform artifacts.

The provisioning boundary excludes application upload/deployment, bindings,
source-secret or data migration, source changes, zones, DNS, domains, email,
routes, and traffic cutover. Hosted postconditions and safe reconciliation remain
required before apply can report successful provisioning.

## Focused offline checks

```sh
bash infra/terraform/ritual-investing-destination/tests/provision.test.sh
sh -n infra/terraform/ritual-investing-destination/provision.sh
```

Tests invoke the real shell CLI in disposable committed repositories, preserving
the canonical checkout and index. The HTTP test interpreter uses a task-specific
private-home dependency; it never changes `HOME`. Retained synthetic create-plan
fixtures were generated by Terraform 1.15.0 with Cloudflare provider 5.24.0 and a
local backend. Existing backend recovery tests remain part of the same discovery
command. Hosted migration, locking, and provisioning require separate evidence.

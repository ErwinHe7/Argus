# Ritual Investing Terraform

This feature owns the stable hosting control plane for the exact `staging` and
`prod` environments. There is intentionally no Terraform root for `dev`: local
development remains local-only.

Terraform owns only the Cloudflare Pages project, custom domain, and DNS record.
GitHub Actions variables and secrets stay outside this stack so automatic
staging does not require repository-admin environment management. Wrangler owns
Pages content uploads and is explicitly excluded from this stack. Supabase
resources and mutations are also explicitly excluded. Credentials, runtime
values, live inventory values, saved plans, and deployment artifacts must never
be committed to these roots.

## Current enablement blocker

Remote Terraform adoption is **disabled**. There is no complete live inventory
or R2 state-lock proof in this repository, and neither root contains a readiness
receipt. The declarations and conditional imports are inert by default:
`adoption_phase` is `disabled`, `enable_brownfield_imports` is `false`, and
`enable_remote_changes` is `false`. Staging declarations are ready for a future
reviewed bootstrap, but remote create remains disabled. Automatic staging
content publication is a separate Wrangler path and does not enable a Terraform
apply. Prod must remain disabled until exact live inventory inputs, backend lock
proof, an import-only plan, a following no-op plan, and a readiness receipt are
recorded outside the repository.

## Roots and state

Each environment is a separate Terraform root. CLI workspaces are prohibited.

| Environment | Root | Backend configuration | R2 bucket | State key |
| --- | --- | --- | --- | --- |
| `staging` | `environments/staging` | `backends/staging.hcl` | `ritual-investing-terraform-state-staging` | `ritual-investing/staging/terraform.tfstate` |
| `prod` | `environments/prod` | `backends/prod.hcl` | `ritual-investing-terraform-state-prod` | `ritual-investing/prod/terraform.tfstate` |

Staging and prod each use a separate bucket, state key, and principal. Backend
credentials and the R2 S3 endpoint are supplied by the operator environment;
they do not belong in HCL, saved plans, logs, fixtures, or receipts.

Typical local initialization, after the live safety gate below is satisfied:

```sh
AWS_ENDPOINT_URL_S3=https://ACCOUNT_ID.r2.cloudflarestorage.com \
  terraform -chdir=infra/terraform/ritual-investing/environments/staging \
  init -backend-config=../../backends/staging.hcl
```

Use the corresponding prod root and backend file for prod. Authentication uses
short-lived, environment-scoped process environment variables. Never put an
access key, secret key, Cloudflare token, or GitHub token on a command line.

## Out-of-stack backend bootstrap

The backend is security infrastructure and must be created outside this Terraform
stack by the named backend owner before any import, plan, or apply:

1. Create the two R2 buckets named above with object versioning, encryption at
   rest, TLS in transit, and an approved retention/lifecycle policy. Record the
   effective configuration in the evidence system.
2. Create separate principals for staging and prod. Scope each principal to its
   one bucket and key namespace, including the sibling `.tflock` object. Neither
   principal may list, read, write, lock, restore, or delete the other bucket.
3. Store credentials only in the corresponding protected mutation environment.
   The content-upload principal must be different from both state principals.
4. Name the backend owner who can recover an earlier object version without
   broadening either Terraform principal.

R2 supplies server-side encryption at rest; `encrypt = true` is also explicit in
both backend configurations. State buckets, access policies, and credentials are
deliberately not represented in either managed root, preventing a stack from
destroying or weakening its own state controls.

## Content-only staging verification

Automatic staging needs current Cloudflare infrastructure evidence, but it does
not run Terraform or authorize Terraform mutation. An operator may build that
evidence with an isolated, operator-local state outside the checkout: inventory
the live APIs, import the six exact staging resources into the temporary state,
and produce a no-op plan while `enable_remote_changes = false`. Record the live
inventory digest, no-op plan digest, provider-lock digest, state lineage/serial,
and the digest of evidence that the remote-change gate remained disabled. Those
values populate the workflow-facing receipt described below.

The temporary state and plans are evidence only. They must remain outside the
repository, contain no credentials or secret Pages variables, and be discarded
after the receipt is stored. This path authorizes Wrangler content deployment
only; it does not authorize a Terraform apply or satisfy the remote-backend gate.

## Mandatory live state-safety gate

The following evidence is a prerequisite for a Terraform remote backend or
remote apply. It is not satisfied by this static configuration and must be
repeated for both roots before Terraform mutation:

- **Two-client lock:** start two independently authenticated clients against the
  same root and key. Hold a write lock with client A; prove client B fails to
  acquire the `.tflock` object and cannot write until A releases it. Record the
  client identities, UTC window, lock object version, and outcomes.
- **Cross-environment access denial:** using staging credentials, prove that
  list, read, write, lock, delete, and version-recovery operations against the
  prod bucket/key are denied. Repeat in the opposite direction.
- **Version recovery:** create a disposable state generation in each bucket,
  advance it, and have the named backend owner recover the prior version. Prove
  lineage and serial match the expected restored object before cleanup.
- **Retention:** prove bucket versioning and the approved retention/lifecycle
  policy remain enabled, and record the effective policy and recovery owner.

The receipt must identify both bucket and key fingerprints, the two principals,
encryption and versioning status, retention policy, both lock attempts,
cross-environment denial results, recovered version IDs, state lineage/serial,
UTC window, operator, recovery owner, and next action. Missing, stale, partial,
or sanitized-beyond-verification evidence means **stop**: do not import, plan,
or apply.

### Fail-closed fallback

If R2 S3 lock-file compatibility or any proof above fails, stop R2 adoption.
Use two separate HCP Terraform **state-only** workspaces, one per environment,
with **local execution**, state sharing disabled, and separate principals. Do
not use remote execution and do not let either workspace read the other's
state. Re-run the same two-client lock, cross-environment access denial,
version recovery, retention, and encryption evidence before proceeding. There
is no shared-state or unlocked fallback.

## Manual inventory and brownfield adoption

Never derive an account, zone, project, DNS, or provider import ID from a file
name. A future operator must inventory the live APIs first. The operator-only
inventory must cover Pages project mode and variables, Functions or
`_worker.js`, bindings, domains, DNS records, deployment IDs, physical legacy
IDs, GitHub Actions settings, state lineage/serial, and known nonsecret
variables. A secret environment variable, Function, binding, or unknown setting
leaves that project unmanaged and blocks enablement.

Capture sanitized, read-only GitHub evidence with the checker below. It never
creates or updates branch protection, rulesets, required checks, reviewers,
wait timers, or deployment-branch policies, and it fails if any exist.

```sh
GITHUB_REPOSITORY=OWNER/REPOSITORY GITHUB_TOKEN="$GITHUB_TOKEN" \
  node --experimental-strip-types \
  ritual-investing-site/scripts/release/check-github-settings.ts \
  > /operator-evidence/github-settings-before.json
```

Keep exact import IDs in an operator-only variable file outside the checkout.
Cloudflare project and DNS IDs remain opaque provider inputs. With the pinned
provider, Pages projects import as `account_id/project_name`, Pages domains as
`account_id/project_name/domain_name`, and DNS records as `zone_id/record_id`.
Never put token values or secret Pages variable values in the file.

Once the state-safety gate has a reviewed receipt, these future manual commands
produce the import-only evidence; they do not describe current readiness:

```sh
terraform -chdir=infra/terraform/ritual-investing/environments/prod \
  init -backend-config=../../backends/prod.hcl
terraform -chdir=infra/terraform/ritual-investing/environments/prod \
  plan -var-file=/operator-evidence/prod-import.tfvars.json \
  -out=/operator-evidence/prod-import.tfplan
terraform -chdir=infra/terraform/ritual-investing/environments/prod \
  show -json /operator-evidence/prod-import.tfplan \
  > /operator-evidence/prod-import-plan.json
```

The operator-only file selects `inventory-import-plan`, enables conditional
imports, keeps `enable_remote_changes = false`, supplies exact inventory IDs,
and records SHA-256 digests for live inventory, backend lock proof, and the
provider lock. The JSON must contain no create, update, delete, replacement,
unknown resource type, compute, binding, or secret-bearing resource action.
Import prod one resource type at a time and stop on drift; never remove live
configuration to make an import fit.

After imports are applied manually to state, disable imports and produce a
second saved plan from the same inventory. It must be a no-op. Record both plan
digests, inventory and provider-lock digests, backend proof, state
lineage/serial, operator, UTC window, and recovery owner in the versioned
readiness receipt. Only then may an operator select `ready` and explicitly set
`enable_remote_changes = true`. Repeat the GitHub checker for the after receipt.

The workflow-facing infrastructure receipt uses `schemaVersion: 2`. In
addition to the live no-op, inventory, lock, state, Pages, profile, and expiry
fields enforced by the workflow, it must include `terraformSnapshotSha256`
equal to the `terraform` snapshot SHA-256 in the exact immutable release
manifest. This prevents a receipt for one Terraform source tree from
authorizing another. Store the compact receipt and its SHA-256 only in the
environment-prefixed, repository-level GitHub Actions variables described in
`docs/ritual-investing/production-release-runbook.md`; the credential-free
staging preflight intentionally runs before any environment-scoped job.

## Plans and destructive-change gate

Plans are transient and must not be committed. Render a saved plan with
`terraform show -json`, inspect every `resource_changes[].change.actions`
entry, and reject the summary unless it contains only non-destructive actions.
Any delete or replacement action must stop before apply. Production requires a
separately reviewed zero-delete, zero-replacement plan; U3 performs no import or
remote apply.

Prefer `moved` blocks for later address refactors. U4 imports remain
configuration-driven and disabled unless exact operator inventory is supplied.

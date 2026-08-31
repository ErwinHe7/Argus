# Ritual Investing Terraform

This feature owns the stable hosting control plane for the exact `staging` and
`prod` environments. There is intentionally no Terraform root for `dev`: local
development remains local-only.

Terraform owns only the Cloudflare Pages project, custom domain, DNS record,
GitHub environment metadata, and known nonsecret GitHub environment variables.
Wrangler owns Pages content uploads and is explicitly excluded from this stack.
Supabase resources and mutations are also explicitly excluded. Credentials,
GitHub environment secrets, runtime values, import blocks, and deployment
artifacts must never be added to these roots.

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

## Mandatory live state-safety gate

The following evidence is a prerequisite. It is not satisfied by this static
configuration and must be repeated for both roots before any live import or
mutation:

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

## Plans and destructive-change gate

Plans are transient and must not be committed. Render a saved plan with
`terraform show -json`, inspect every `resource_changes[].change.actions`
entry, and reject the summary unless it contains only non-destructive actions.
Any delete or replacement action must stop before apply. Production requires a
separately reviewed zero-delete, zero-replacement plan; U3 performs no import or
remote apply.

Prefer `moved` blocks for later address refactors and explicit imports during
the brownfield adoption unit. Neither is part of this foundation.

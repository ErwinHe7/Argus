# Ritual Investing release runbook

## Release flow

The only deployment environments are `dev`, `staging`, and `prod`. `dev` is a
local build/run environment and has no hosted target. A canonical push to
`main` runs the fast, secret-free workflow, builds one immutable release, and
automatically attempts staging deployment. Direct pushes remain allowed: this
repository does not configure branch protection, rulesets, required checks,
or deployment branch policies. The static `staging` and `prod` environments
have no reviewers or wait timers. Existing separately named protected
authority environments for manual Supabase remediation and member-web release
remain intact; they are not deployment-stage names and do not gate pushes.

Integration, browser, device, simulator, hosted acceptance, restore, and
production-readiness checks run only through the manual evidence workflow.
After that evidence and the staging deployment receipt describe the same
retained artifact, an operator may manually dispatch prod promotion. Prod
downloads the same artifact; it never rebuilds it.

`public beta` and `beta-backed` describe product lifecycle and capability, not
deployment stage. The provider's legacy physical Supabase branch label `beta`
for ref `zbgjjufjkhfhirbuuolv` maps only to logical staging.

## Evidence required before prod

- Exact source run ID and attempt, artifact ID, source SHA, archive digest, and
  release-manifest digest from the canonical main Fast CI run.
- Successful staging receipt for that exact identity, including actor, UTC
  start/end, owning run, infrastructure receipt, backend receipt when landing
  depends on it, prior/attempted/resulting/final deployment IDs, recovery
  owner, outcome, and next action.
- Manual production evidence for the same release: Rust, Python, TypeScript,
  Docker, available native checks, and a fresh live-data readiness receipt.
- Current prod infrastructure and backend receipts matching the physical
  targets and the immutable release profiles.

A static deployment receipt is not production-readiness evidence. A frozen
Supabase migration/function inventory proves source provenance only; it does
not prove that the hosted backend is deployed or healthy.

## Failure and recovery

- **Artifact expired or missing:** terminal NO-GO. Build a new canonical main
  release; never reconstruct the old artifact.
- **Preflight mismatch:** terminal before credentials. Record the rejected
  subject/controller/artifact/target field and dispatch again only with one
  coherent release.
- **Partial content deployment:** retain all deployment IDs and probe results,
  roll each changed Pages surface back to its exact prior deployment, and
  record whether recovery succeeded. Never report a Demo-only deployment as a
  full release.
- **Content rollback fails:** keep the truthful failed terminal receipt,
  contain traffic through the named Cloudflare owner, and fix forward from the
  retained artifact.
- **Terraform failure:** do not mutate content. Preserve state lineage/serial,
  plan and lock evidence; the infrastructure owner fixes forward. Do not delete
  or recreate state as recovery.
- **Supabase failure:** leave `background_workers`, `provider_egress`, and
  `order_mutations` fenced. Frontend rollback may coexist with a newer additive
  backend. Fix forward, or use only the manifest-bound managed restore; never
  run an automatic schema rollback.

## Ownership

| Boundary | Owner | Required action/evidence |
| --- | --- | --- |
| Terraform state/backend | Infrastructure owner | Lock/isolation/recovery proof, lineage/serial, safe plan, fix-forward |
| Automatic staging incident | Staging release operator | Inspect preflight/deployment receipt and take incident ownership |
| Cloudflare content recovery | Cloudflare operator | Prior/final deployment IDs, probes, rollback result |
| Supabase remediation/restore | Supabase operator | Exact target, fences, backup/restore approval, hosted acceptance |
| Prod dispatch | Release commander | One coherent staging/artifact/evidence/prod-target identity |
| Evidence custody | Release operator | Retain receipts and SHA-256 files for 30 days without secrets/member data |
| Legacy domains/aliases | Cloudflare operator | Remove only after DNS/TLS/rollback evidence and an approved change |

Production remains NO-GO while the project contract's research-runtime and
live-data readiness gates, the production Supabase target, or any product
launch gate is missing.

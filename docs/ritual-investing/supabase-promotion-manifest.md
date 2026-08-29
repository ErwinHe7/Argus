# Supabase promotion manifest contract

Every hosted remediation is authorized by one immutable
`argus-supabase-promotion/v1` manifest. The protected GitHub environment binds
the supplied manifest digest to separately reviewed environment values. Any
bound change invalidates the approval and requires a new manifest; an operator
must never infer a missing value from a branch name, project label, or prior
run.

The workflow accepts JSON, canonicalizes it with `jq -S -c` (including its
trailing newline), and verifies `promotion_manifest_sha256` before reading any
hosted state or enabling a fence. The canonical object has exactly these keys:

| Field | Required binding |
|---|---|
| `contract_version` | Literal `argus-supabase-promotion/v1` |
| `project_ref` | Exact protected Supabase project ID/project ref |
| `branch_ref` | Literal `refs/heads/main` |
| `git_revision` | Exact 40-character `GITHUB_SHA` checked out for the run |
| `migration_checksum` | SHA-256 of the reviewed migration-checksum inventory; the offline inventory checker also verifies every migration |
| `source_target_fingerprint` | SHA-256 of the normalized hosted target manifest captured before mutation |
| `target_fingerprint` | Approved SHA-256 of the normalized new-schema target manifest, rechecked after migration |
| `inventory_sha256` | SHA-256 of the reviewed boundary inventory, including roles and managed resources |
| `captured_at` | UTC capture time in `YYYY-MM-DDTHH:MM:SSZ` form |
| `backup_id` | Immutable hosted backup identifier |
| `restore_drill_id` | Passed restore-drill evidence identifier |
| `recovery_coverage_sha256` | SHA-256 of `supabase-recovery-coverage.md` |
| `release_approval` | Release commander approval record |
| `recovery_approval` | Recovery owner approval record |
| `security_approval` | Security approver record |
| `traffic_admission` | Literal `maintenance`; normal traffic is not inferred |
| `background_workers` | Boolean `true` |
| `provider_egress` | Boolean `true` |
| `order_mutations` | Boolean `true` |
| `fixture_namespace` | Run-unique isolated synthetic fixture namespace |
| `old_edge_revision` | Exact deployed Edge revision expected before the function deployment |

The three fence states are independently bound in this order:
`background_workers`, `provider_egress`, `order_mutations`. A single blanket
“financial work enabled” flag is prohibited. The workflow may resume only
`background_workers`; provider egress and order mutations require their own
later launch approvals.

## Gate results and test evidence

Before the first fence or hosted mutation, the workflow revalidates the
manifest digest, exact target, branch identity, Git revision, migration
checksums, source fingerprint, boundary inventory, backup, restore drill,
recovery coverage, and all three approvals. It then:

1. fences all external effects;
2. applies only forward-only migrations;
3. proves the old Edge/new schema state;
4. runs hosted tests and acceptance with every external-effect fence enabled;
5. deploys the exact new Edge revision;
6. proves the new Edge/new schema state;
7. proves synthetic fixture cleanup and before/after inventory parity; and
8. resumes background work only.

Failure at any point is a no-go. All fences remain enabled, and recovery is
fix-forward or an approved managed restore—not migration repair, history
rewriting, or automatic rollback to a legacy backend.

## Observation artifact

The immutable observation evidence artifact is keyed by manifest digest and Git
revision. It records an **immediate** checkpoint during promotion and explicit
follow-up checkpoints at **+1h**, **+4h**, and **+24h**. Each checkpoint records
the gate results, queue/lease and external-effect signals, Storage/Auth cleanup
status, Edge revision, schema fingerprint, and fence states. A pending or
failed checkpoint is visible evidence, never permission to resume provider
egress or order mutations.

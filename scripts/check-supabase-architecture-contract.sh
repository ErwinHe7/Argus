#!/bin/sh
set -eu

architecture_root=${ARGUS_ARCHITECTURE_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
architecture_root=$(CDPATH= cd -- "$architecture_root" && pwd)
database_url=
print_boundary_manifest=false

fail() {
  printf '%s\n' "Supabase architecture contract failed: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/check-supabase-architecture-contract.sh [--offline | --database-url URL | --print-boundary-manifest]

The default is offline repository parity. --database-url additionally runs the
read-only catalog audit against an explicitly selected database. The URL is
never printed or inferred from hosted credentials. --print-boundary-manifest
prints the exact current direct-boundary path inventory for explicit review;
it does not update the committed manifest.
EOF
}

while test "$#" -gt 0; do
  case "$1" in
    --offline)
      database_url=
      ;;
    --database-url)
      test "$#" -ge 2 || fail "--database-url requires a value"
      database_url=$2
      shift
      ;;
    --print-boundary-manifest)
      print_boundary_manifest=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *) fail "unknown argument: $1" ;;
  esac
  shift
done

command -v rg >/dev/null 2>&1 || fail "ripgrep (rg) is required"
command -v shasum >/dev/null 2>&1 || fail "shasum is required"
command -v cmp >/dev/null 2>&1 || fail "cmp is required"
command -v diff >/dev/null 2>&1 || fail "diff is required"

register="$architecture_root/docs/ritual-investing/supabase-remediation-register.md"
boundary_manifest="$architecture_root/docs/ritual-investing/supabase-boundary-manifest-v1.txt"
target_model="$architecture_root/docs/ritual-investing/supabase-target-model-contract-v1.md"
operations_budget="$architecture_root/docs/ritual-investing/supabase-performance-and-operations-budget-v1.md"
runbook="$architecture_root/docs/ritual-investing/supabase-operations-runbook.md"
audit_sql="$architecture_root/scripts/audit-supabase-architecture.sql"
architecture_test="$architecture_root/supabase/tests/architecture_contract.test.sql"
lifecycle_test="$architecture_root/supabase/tests/member_lifecycle.test.sql"

discover_supabase_surfaces() {
  (
    CDPATH= cd -- "$architecture_root"
    rg -l -i \
      --hidden \
      --glob '!.git/**' \
      --glob '!**/node_modules/**' \
      --glob '!**/.dart_tool/**' \
      --glob '!**/.next/**' \
      --glob '!**/.symlinks/**' \
      --glob '!**/.wrangler/**' \
      --glob '!**/ios/Pods/**' \
      --glob '!**/build/**' \
      --glob '!**/output/**' \
      --glob '!docs/plans/**' \
      --glob '!docs/superpowers/**' \
      --glob '!axio7-model-review/**' \
      --glob '!*.lock' \
      --glob '!docs/ritual-investing/supabase-boundary-manifest-v1.txt' \
      --glob '!docs/ritual-investing/supabase-remediation-register.md' \
      --glob '!docs/ritual-investing/supabase-target-model-contract-v1.md' \
      --glob '!docs/ritual-investing/supabase-performance-and-operations-budget-v1.md' \
      'supabase|argus_(app|private|brokerage)|storage\.objects|auth\.users|pgmq|cron\.' \
      . \
      | sed 's#^\./##' \
      | sort -u
  ) || true
}

if test "$print_boundary_manifest" = true; then
  test -z "$database_url" || fail "--print-boundary-manifest cannot run with --database-url"
  printf '%s\n\n' 'contract_version: supabase-boundary-manifest-v1'
  discover_supabase_surfaces
  exit 0
fi

for required_file in \
  "$register" \
  "$boundary_manifest" \
  "$target_model" \
  "$operations_budget" \
  "$runbook" \
  "$audit_sql" \
  "$architecture_test" \
  "$lifecycle_test"
do
  test -f "$required_file" || fail "missing ${required_file#"$architecture_root"/}"
done

rg -q '^contract_version: supabase-remediation-register-v1$' "$register" ||
  fail "remediation register version is absent or changed"
test "$(sed -n '1p' "$boundary_manifest")" = \
  'contract_version: supabase-boundary-manifest-v1' ||
  fail "boundary manifest version is absent or changed"
test -z "$(sed -n '2p' "$boundary_manifest")" ||
  fail "boundary manifest must have one blank line after its version"
rg -q '^contract_version: supabase-target-model-v1$' "$target_model" ||
  fail "target-model contract version is absent or changed"
rg -q '^contract_version: supabase-performance-operations-budget-v1$' "$operations_budget" ||
  fail "performance/operations budget version is absent or changed"

migration_count=0
for migration in "$architecture_root"/supabase/migrations/*.sql; do
  test -f "$migration" || fail "no Supabase migrations found"
  migration_count=$((migration_count + 1))
  relative=${migration#"$architecture_root"/}
  checksum=$(shasum -a 256 "$migration" | awk '{print $1}')
  grep -F "$checksum  $relative" "$register" >/dev/null ||
    fail "migration checksum or disposition missing for $relative"
done
test "$migration_count" -gt 0 || fail "no Supabase migrations found"

scope_file=$(mktemp "${TMPDIR:-/tmp}/argus-architecture-scopes.XXXXXX")
transitive_file=$(mktemp "${TMPDIR:-/tmp}/argus-architecture-transitive.XXXXXX")
surface_file=$(mktemp "${TMPDIR:-/tmp}/argus-supabase-surfaces.XXXXXX")
recorded_inventory=$(mktemp "${TMPDIR:-/tmp}/argus-supabase-recorded.XXXXXX")
trap 'rm -f "$scope_file" "$transitive_file" "$surface_file" "$recorded_inventory"' EXIT HUP INT TERM

sed -n 's/^<!-- scope:\([^ ][^ ]*\) -->$/\1/p' "$register" >"$scope_file"
test -s "$scope_file" || fail "remediation register has no owner-group metadata"
if rg -n -v '^[A-Za-z0-9_.*/-]+$' "$scope_file"; then
  fail "owner-group patterns contain unsupported characters"
fi
sed -n 's/^<!-- transitive:\([^ ][^ ]*\) -->$/\1/p' "$register" >"$transitive_file"
test -s "$transitive_file" || fail "remediation register has no reviewed transitive modules"
if rg -n -v '^[A-Za-z0-9_./-]+$' "$transitive_file"; then
  fail "transitive module paths contain unsupported characters"
fi
while IFS= read -r transitive_module; do
  test -e "$architecture_root/$transitive_module" ||
    fail "reviewed transitive module is absent: $transitive_module"
done <"$transitive_file"

discover_supabase_surfaces >"$surface_file"
sed -n '3,$p' "$boundary_manifest" >"$recorded_inventory"
test -s "$recorded_inventory" || fail "boundary manifest has no registered surfaces"
if rg -n -v '^[A-Za-z0-9_.@/+ -]+$' "$recorded_inventory"; then
  fail "boundary manifest contains a malformed direct-surface path"
fi
if ! cmp -s "$surface_file" "$recorded_inventory"; then
  diff -u "$recorded_inventory" "$surface_file" >&2 || true
  fail "exact direct-boundary path inventory differs; review --print-boundary-manifest output"
fi

while IFS= read -r surface; do
  test -n "$surface" || continue
  covered=false
  while IFS= read -r pattern; do
    case "$surface" in
      $pattern)
        covered=true
        break
        ;;
    esac
  done <"$scope_file"
  test "$covered" = true ||
    fail "Supabase-facing surface has no owner-group metadata: $surface"
done <"$surface_file"

for ingress in api worker webull-callback waitlist; do
  rg -q "^### $ingress ingress$" "$register" ||
    fail "missing reviewed $ingress ingress contract"
done

for effect in \
  auth-jwks-read \
  auth-admin-delete \
  storage-read \
  storage-write \
  storage-delete \
  storage-sign \
  turnstile-verify \
  webull-authorization-exchange \
  webull-token-refresh \
  webull-projection-read \
  webull-command-submit \
  webull-command-lookup
do
  rg -q "^| $effect |" "$register" ||
    fail "missing external-effect capability contract: $effect"
done

if test -n "$database_url"; then
  command -v psql >/dev/null 2>&1 || fail "psql is required for --database-url"
  PGAPPNAME=argus_architecture_audit \
    psql "$database_url" -X -v ON_ERROR_STOP=1 -f "$audit_sql"
fi

printf '%s\n' \
  "Supabase architecture contract passed: $migration_count migration checksums and $(wc -l <"$surface_file" | tr -d ' ') Supabase-facing surfaces are registered"

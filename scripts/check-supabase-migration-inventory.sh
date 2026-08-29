#!/bin/sh
set -eu

repository_root=${ARGUS_SUPABASE_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
repository_root=$(CDPATH= cd -- "$repository_root" && pwd)
required_cli_version=2.115.0
database_url=
check_cli=false
print_target_manifest=false
compare_target_manifest=

fail() {
  printf '%s\n' "Supabase migration inventory failed: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/check-supabase-migration-inventory.sh [--offline | --check-cli]
       scripts/check-supabase-migration-inventory.sh --database-url URL --print-target-manifest
       scripts/check-supabase-migration-inventory.sh --database-url URL --compare-target-manifest FILE

Offline mode verifies the forward-only migration ledger, immutable checksums,
managed-resource and role ownership, the exact CI CLI pin, nonzero pgTAP
coverage, and the absence of a second declarative SQL authority. --check-cli
also requires the executable CLI to be exactly 2.115.0. Database modes render
or compare a read-only normalized replay manifest for an explicitly selected
database. The database URL is never printed or inferred.
EOF
}

while test "$#" -gt 0; do
  case "$1" in
    --offline)
      ;;
    --check-cli)
      check_cli=true
      ;;
    --database-url)
      test "$#" -ge 2 || fail "--database-url requires a value"
      database_url=$2
      shift
      ;;
    --print-target-manifest)
      print_target_manifest=true
      ;;
    --compare-target-manifest)
      test "$#" -ge 2 || fail "--compare-target-manifest requires a file"
      compare_target_manifest=$2
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *) fail "unknown argument: $1" ;;
  esac
  shift
done

test "$print_target_manifest" = false || test -z "$compare_target_manifest" ||
  fail "choose either --print-target-manifest or --compare-target-manifest"
if test "$print_target_manifest" = true || test -n "$compare_target_manifest"; then
  test -n "$database_url" || fail "database modes require --database-url"
else
  test -z "$database_url" || fail "--database-url requires a target-manifest mode"
fi

for command_name in rg shasum awk sed sort cmp diff mktemp; do
  command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required"
done

inventory="$repository_root/docs/ritual-investing/supabase-migration-inventory-v1.txt"
authoring_contract="$repository_root/docs/ritual-investing/supabase-schema-authoring.md"
workflow="$repository_root/.github/workflows/ritual-investing.yml"
config="$repository_root/supabase/config.toml"
target_sql="$repository_root/scripts/render-supabase-target-manifest.sql"
architecture_test="$repository_root/supabase/tests/architecture_contract.test.sql"

for required_file in \
  "$inventory" \
  "$authoring_contract" \
  "$workflow" \
  "$config" \
  "$target_sql" \
  "$architecture_test"
do
  test -f "$required_file" || fail "missing ${required_file#"$repository_root"/}"
done

header_value() {
  key=$1
  sed -n "s/^$key: //p" "$inventory"
}

test "$(header_value contract_version)" = "supabase-migration-inventory-v1" ||
  fail "migration inventory contract version is absent or changed"
test "$(header_value history_strategy)" = "forward-only" ||
  fail "only the selected forward-only history strategy is permitted"
test "$(header_value destructive_reset_eligible)" = "false" ||
  fail "destructive reset remains ineligible"
test "$(header_value supabase_cli_version)" = "$required_cli_version" ||
  fail "inventory CLI version must be $required_cli_version"
test "$(header_value schema_authority)" = "supabase/migrations" ||
  fail "supabase/migrations must be the sole schema authority"
test "$(header_value declarative_schema_authority)" = "disabled" ||
  fail "declarative schema authority must remain disabled"
anchor=$(header_value forward_only_anchor)
printf '%s\n' "$anchor" | rg -q '^[0-9]{14}$' ||
  fail "forward-only anchor must be one 14-digit migration version"

pin_count=$(awk -v version="$required_cli_version" \
  '$0 == "  SUPABASE_CLI_VERSION: " version {count++} END {print count+0}' \
  "$workflow")
test "$pin_count" -eq 1 ||
  fail "CI must declare SUPABASE_CLI_VERSION exactly once as $required_cli_version"

schema_paths=$(awk '
  /^\[db\.migrations\]$/ {inside=1; next}
  /^\[/ {inside=0}
  inside && /^schema_paths[[:space:]]*=/ {print; count++}
  END {if (count != 1) exit 1}
' "$config") || fail "[db.migrations] must declare schema_paths exactly once"
test "$schema_paths" = "schema_paths = []" ||
  fail "schema_paths must remain disabled; generated pg-delta output is review-only"

if rg --files "$repository_root/supabase" -g '*.sql' \
  | sed "s#^$repository_root/##" \
  | rg -v '^(supabase/migrations/[^/]+\.sql|supabase/tests/[^/]+\.sql|supabase/seed\.sql)$' \
  >"${TMPDIR:-/tmp}/argus-unapproved-sql.$$"; then
  if test -s "${TMPDIR:-/tmp}/argus-unapproved-sql.$$"; then
    cat "${TMPDIR:-/tmp}/argus-unapproved-sql.$$" >&2
    rm -f "${TMPDIR:-/tmp}/argus-unapproved-sql.$$"
    fail "a second SQL schema/history authority is present"
  fi
fi
rm -f "${TMPDIR:-/tmp}/argus-unapproved-sql.$$"

expected_migrations=$(mktemp "${TMPDIR:-/tmp}/argus-expected-migrations.XXXXXX")
actual_migrations=$(mktemp "${TMPDIR:-/tmp}/argus-actual-migrations.XXXXXX")
timestamps=$(mktemp "${TMPDIR:-/tmp}/argus-migration-timestamps.XXXXXX")
manifest_resources=$(mktemp "${TMPDIR:-/tmp}/argus-managed-resources.XXXXXX")
manifest_roles=$(mktemp "${TMPDIR:-/tmp}/argus-role-inventory.XXXXXX")
source_roles=$(mktemp "${TMPDIR:-/tmp}/argus-source-roles.XXXXXX")
source_extensions=$(mktemp "${TMPDIR:-/tmp}/argus-source-extensions.XXXXXX")
source_queues=$(mktemp "${TMPDIR:-/tmp}/argus-source-queues.XXXXXX")
source_cron=$(mktemp "${TMPDIR:-/tmp}/argus-source-cron.XXXXXX")
source_buckets=$(mktemp "${TMPDIR:-/tmp}/argus-source-buckets.XXXXXX")
source_vault=$(mktemp "${TMPDIR:-/tmp}/argus-source-vault.XXXXXX")
source_edge=$(mktemp "${TMPDIR:-/tmp}/argus-source-edge.XXXXXX")
live_managed=$(mktemp "${TMPDIR:-/tmp}/argus-live-managed.XXXXXX")
target_output=$(mktemp "${TMPDIR:-/tmp}/argus-target-manifest.XXXXXX")
trap 'rm -f "$expected_migrations" "$actual_migrations" "$timestamps" "$manifest_resources" "$manifest_roles" "$source_roles" "$source_extensions" "$source_queues" "$source_cron" "$source_buckets" "$source_vault" "$source_edge" "$live_managed" "$target_output"' EXIT HUP INT TERM

awk '
  /^\[migrations\]$/ {inside=1; next}
  /^\[/ {inside=0}
  inside && NF {print}
' "$inventory" >"$expected_migrations"
test -s "$expected_migrations" || fail "migration inventory has no migration rows"
if rg -n -v '^[0-9a-f]{64}  supabase/migrations/[0-9]{14}_[a-z0-9_]+\.sql$' \
  "$expected_migrations"; then
  fail "migration inventory contains a malformed checksum row"
fi

: >"$actual_migrations"
: >"$timestamps"
migration_count=0
for migration in "$repository_root"/supabase/migrations/*.sql; do
  test -f "$migration" || fail "no Supabase migrations found"
  migration_count=$((migration_count + 1))
  basename=${migration##*/}
  timestamp=${basename%%_*}
  printf '%s\n' "$basename" | rg -q '^[0-9]{14}_[a-z0-9_]+\.sql$' ||
    fail "malformed migration filename: $basename"
  checksum=$(shasum -a 256 "$migration" | awk '{print $1}')
  printf '%s  supabase/migrations/%s\n' "$checksum" "$basename" >>"$actual_migrations"
  printf '%s\n' "$timestamp" >>"$timestamps"
done
test "$migration_count" -gt 0 || fail "no Supabase migrations found"
if test -n "$(sort "$timestamps" | uniq -d)"; then
  fail "migration versions must be unique"
fi
if ! cmp -s "$expected_migrations" "$actual_migrations"; then
  diff -u "$expected_migrations" "$actual_migrations" >&2 || true
  fail "migration path/order/checksum inventory differs"
fi
rg -q "  supabase/migrations/${anchor}_" "$expected_migrations" ||
  fail "forward-only anchor is absent from the authoritative history"

awk '
  /^\[managed-resources\]$/ {inside=1; next}
  /^\[/ {inside=0}
  inside && NF {print}
' "$inventory" >"$manifest_resources"
test -s "$manifest_resources" || fail "managed-resource inventory is empty"
if awk -F '|' '
  NF != 6 {print NR ":" $0; bad=1; next}
  $1 !~ /^(auth|storage|realtime|extension|pgmq|cron|pg_net|vault|edge|roles)$/ {print NR ":" $0; bad=1}
  $2 !~ /^[a-z0-9_.-]+$/ {print NR ":" $0; bad=1}
  $3 !~ /^[a-z0-9_.-]+$/ {print NR ":" $0; bad=1}
  $4 !~ /^(supabase-managed|migration-supported-api|out-of-band)$/ {print NR ":" $0; bad=1}
  $5 !~ /^[0-9][0-9]$/ {print NR ":" $0; bad=1}
  $6 == "" {print NR ":" $0; bad=1}
  {key=$1 "|" $2; if (seen[key]++) {print NR ":" $0; bad=1}}
  END {exit bad}
' "$manifest_resources"; then :; else
  fail "managed-resource inventory contains an invalid or duplicate row"
fi
for resource_class in auth storage realtime extension pgmq cron pg_net vault edge roles; do
  awk -F '|' -v required="$resource_class" '$1 == required {found=1} END {exit !found}' \
    "$manifest_resources" || fail "managed-resource family is unclassified: $resource_class"
done

awk '
  /^\[roles\]$/ {inside=1; next}
  /^\[/ {inside=0}
  inside && NF {print}
' "$inventory" >"$manifest_roles"
test -s "$manifest_roles" || fail "custom-role inventory is empty"
if awk -F '|' '
  NF != 7 {print NR ":" $0; bad=1; next}
  $1 !~ /^[a-z][a-z0-9_]*$/ {print NR ":" $0; bad=1}
  $2 !~ /^(supabase-managed|non-login-owner|runtime-login|legacy)$/ {print NR ":" $0; bad=1}
  $3 !~ /^[a-z0-9_.-]+$/ {print NR ":" $0; bad=1}
  $4 !~ /^(login|nologin)$/ {print NR ":" $0; bad=1}
  {if (seen[$1]++) {print NR ":" $0; bad=1}}
  END {exit bad}
' "$manifest_roles"; then :; else
  fail "custom-role inventory contains an invalid or duplicate row"
fi
sed 's/|.*//' "$manifest_roles" | sort -u >"$manifest_roles.names"
sed -n 's/^[[:space:]]*create role \([a-z][a-z0-9_]*\).*$/\1/p' \
  "$repository_root"/supabase/migrations/*.sql | sort -u >"$source_roles"
if ! cmp -s "$source_roles" "$manifest_roles.names"; then
  diff -u "$source_roles" "$manifest_roles.names" >&2 || true
  fail "migration-created custom roles differ from the role inventory"
fi
rm -f "$manifest_roles.names"

sed -n 's/^[[:space:]]*create extension if not exists \([a-zA-Z0-9_]*\).*$/\1/p' \
  "$repository_root"/supabase/migrations/*.sql | sort -u >"$source_extensions"
while IFS= read -r extension_name; do
  test -n "$extension_name" || continue
  awk -F '|' -v name="$extension_name" \
    '$1 == "extension" && $2 == name {found=1} END {exit !found}' \
    "$manifest_resources" || fail "migration extension is unclassified: $extension_name"
done <"$source_extensions"

sed -n "s/.*pgmq\.create('\([^']*\)').*/\1/p" \
  "$repository_root"/supabase/migrations/*.sql | sort -u >"$source_queues"
awk '
  /cron[.]schedule[(]/ {capture=1}
  capture && match($0, /\047[^\047]+\047/) {
    value=substr($0, RSTART + 1, RLENGTH - 2)
    print value
    capture=0
  }
' "$repository_root"/supabase/migrations/*.sql | sort -u >"$source_cron"
awk '
  /insert into storage[.]buckets/ {capture=1; next}
  capture && /on conflict/ {capture=0}
  capture && match($0, /[(][[:space:]]*\047[^\047]+\047/) {
    value=substr($0, RSTART, RLENGTH)
    sub(/^[(][[:space:]]*\047/, "", value)
    sub(/\047$/, "", value)
    print value
  }
' "$repository_root"/supabase/migrations/*.sql | sort -u >"$source_buckets"
rg -o --no-filename \
  'argus_worker_(url|secret_current|secret_next|secret_next_valid_until)' \
  "$repository_root"/supabase/migrations/*.sql | sort -u >"$source_vault" || true
(
  CDPATH= cd -- "$repository_root"
  for function_entry in supabase/functions/*/index.ts; do
    test -f "$function_entry" || continue
    function_name=${function_entry#supabase/functions/}
    function_name=${function_name%/index.ts}
    test "$function_name" = "_shared" || printf '%s\n' "$function_name"
  done
) | sort -u >"$source_edge"

require_managed_source() {
  resource_class=$1
  source_file=$2
  while IFS= read -r resource_name; do
    test -n "$resource_name" || continue
    awk -F '|' -v class="$resource_class" -v name="$resource_name" \
      '$1 == class && $2 == name {found=1} END {exit !found}' \
      "$manifest_resources" ||
      fail "$resource_class resource is absent from the ownership allowlist: $resource_name"
  done <"$source_file"
}

require_managed_source pgmq "$source_queues"
require_managed_source cron "$source_cron"
require_managed_source storage "$source_buckets"
require_managed_source vault "$source_vault"
require_managed_source edge "$source_edge"

rg -q -i 'select[[:space:]]+plan\([1-9][0-9]*\)' \
  "$repository_root"/supabase/tests/*.sql ||
  fail "the pgTAP suite must declare a nonzero plan"

if test "$check_cli" = true; then
  command -v supabase >/dev/null 2>&1 || fail "Supabase CLI is required for --check-cli"
  observed_cli_version=$(SUPABASE_TELEMETRY_DISABLED=1 supabase --version |
    awk 'NR == 1 {print $1}')
  test "$observed_cli_version" = "$required_cli_version" ||
    fail "Supabase CLI $required_cli_version required; observed $observed_cli_version"
fi

if test "$print_target_manifest" = true || test -n "$compare_target_manifest"; then
  command -v psql >/dev/null 2>&1 || fail "psql is required for database modes"
  PGAPPNAME=argus_replay_manifest \
    psql "$database_url" -X -A -t -v ON_ERROR_STOP=1 -f "$target_sql" \
    >"$target_output"
  test "$(sed -n '1p' "$target_output")" = \
    "contract_version: supabase-replay-target-v1" ||
    fail "database did not produce the expected replay-manifest contract"
  rg -q '^target_fingerprint\|[0-9a-f]{64}$' "$target_output" ||
    fail "database replay manifest has no SHA-256 target fingerprint"

  for mapping in 'queue:pgmq' 'cron:cron' 'bucket:storage' \
    'vault-name:vault' 'extension:extension'; do
    live_prefix=${mapping%%:*}
    resource_class=${mapping#*:}
    awk -F '|' -v prefix="$live_prefix" '$1 == prefix {print $2}' \
      "$target_output" >"$live_managed"
    while IFS= read -r resource_name; do
      test -n "$resource_name" || continue
      awk -F '|' -v class="$resource_class" -v name="$resource_name" \
        '$1 == class && $2 == name {found=1} END {exit !found}' \
        "$manifest_resources" ||
        fail "live $resource_class resource is outside the desired-state allowlist: $resource_name"
    done <"$live_managed"
  done
  awk -F '|' '$1 == "role" && $2 ~ /^argus_/ {print $2}' \
    "$target_output" >"$live_managed"
  while IFS= read -r role_name; do
    awk -F '|' -v name="$role_name" \
      '$1 == name {found=1} END {exit !found}' "$manifest_roles" ||
      fail "live custom role is outside the desired-state allowlist: $role_name"
  done <"$live_managed"
  if rg -q '^publication\|' "$target_output"; then
    fail "an Argus relation is unexpectedly present in a Realtime publication"
  fi
fi

if test "$print_target_manifest" = true; then
  cat "$target_output"
  exit 0
fi
if test -n "$compare_target_manifest"; then
  test -f "$compare_target_manifest" || fail "comparison target does not exist"
  if ! cmp -s "$compare_target_manifest" "$target_output"; then
    diff -u "$compare_target_manifest" "$target_output" >&2 || true
    fail "database replay target differs from the reviewed first replay"
  fi
fi

printf '%s\n' \
  "Supabase migration inventory passed: $migration_count forward-only migrations, CLI pin $required_cli_version, and all managed-resource families classified"

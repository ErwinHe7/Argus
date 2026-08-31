#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
checker="$repository_root/scripts/check-supabase-migration-inventory.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/argus-migration-inventory.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

u8_migration="$repository_root/supabase/migrations/20260829170000_u8_normalized_query_contracts.sql"
test -f "$u8_migration"
first_u8_statement=$(sed -e '/^[[:space:]]*--/d' -e '/^[[:space:]]*$/d' "$u8_migration" | sed -n '1p')
last_u8_statement=$(sed -e '/^[[:space:]]*--/d' -e '/^[[:space:]]*$/d' "$u8_migration" | tail -n 1)
test "$first_u8_statement" = 'begin;' || {
  printf '%s\n' 'expected U8 migration to begin an explicit outer transaction' >&2
  exit 1
}
test "$last_u8_statement" = 'commit;' || {
  printf '%s\n' 'expected U8 migration to commit its explicit outer transaction' >&2
  exit 1
}

if rg -n -U \
  '(?is)^[ \t]*(grant|revoke)\b[^;]*(current_user|session_user)[^;]*;' \
  "$repository_root/supabase/migrations" "$repository_root/supabase/tests"; then
  printf '%s\n' \
    'role membership must resolve the executor to an explicit quoted role before GRANT or REVOKE' >&2
  exit 1
fi

write_fixture() {
  rm -rf "$fixture"
  mkdir -p \
    "$fixture/.github/workflows" \
    "$fixture/docs/ritual-investing" \
    "$fixture/scripts" \
    "$fixture/supabase/migrations" \
    "$fixture/supabase/tests"

  printf '%s\n' \
    'create extension if not exists pgcrypto with schema extensions;' \
    'create role argus_runtime nologin;' \
    'select 1;' \
    >"$fixture/supabase/migrations/20260828000000_baseline.sql"
  checksum=$(shasum -a 256 \
    "$fixture/supabase/migrations/20260828000000_baseline.sql" | awk '{print $1}')

  cat >"$fixture/.github/workflows/ritual-investing-supabase-remediation.yml" <<'EOF'
env:
  SUPABASE_CLI_VERSION: 2.115.0
EOF
  cat >"$fixture/supabase/config.toml" <<'EOF'
[db.migrations]
enabled = true
schema_paths = []
EOF
  cat >"$fixture/docs/ritual-investing/supabase-schema-authoring.md" <<'EOF'
# Fixture schema-authoring contract

Forward-only migrations are the sole schema authority.
EOF
  cat >"$fixture/docs/ritual-investing/supabase-migration-inventory-v1.txt" <<EOF
contract_version: supabase-migration-inventory-v1
history_strategy: forward-only
destructive_reset_eligible: false
supabase_cli_version: 2.115.0
schema_authority: supabase/migrations
declarative_schema_authority: disabled
forward_only_anchor: 20260828000000

[migrations]
$checksum  supabase/migrations/20260828000000_baseline.sql

[managed-resources]
auth|project-auth|identity|supabase-managed|00|supported configuration
storage|private-buckets|media-privacy|migration-supported-api|10|create-or-verify
realtime|no-argus-publication|platform|supabase-managed|10|deny-unreviewed
extension|pgcrypto|platform|migration-supported-api|01|create-or-verify
pgmq|argus-jobs|jobs|migration-supported-api|90|create-or-verify
cron|argus-jobs|jobs|migration-supported-api|90|replace-by-name
pg_net|worker-invocation|jobs|migration-supported-api|90|create-or-verify
vault|worker-secret-names|operations|out-of-band|90|name-only
edge|api-worker|platform|out-of-band|90|deploy-exact-revision
roles|argus-runtime|platform|migration-supported-api|01|create-or-verify

[roles]
argus_runtime|legacy|platform|nologin|none|none|statement=15s,idle_tx=15s
EOF
  cp "$repository_root/scripts/render-supabase-target-manifest.sql" \
    "$fixture/scripts/render-supabase-target-manifest.sql"
  printf '%s\n' 'select plan(1);' 'select ok(true);' 'select * from finish();' \
    >"$fixture/supabase/tests/architecture_contract.test.sql"
}

expect_failure() {
  label=$1
  shift
  if ARGUS_SUPABASE_ROOT="$fixture" "$checker" "$@" >"$fixture-output" 2>&1; then
    printf '%s\n' "expected migration inventory to reject $label" >&2
    exit 1
  fi
}

write_fixture
ARGUS_SUPABASE_ROOT="$fixture" "$checker" --offline >"$fixture-output"
grep -F "Supabase migration inventory passed" "$fixture-output" >/dev/null

printf '%s\n' 'select 2;' >"$fixture/supabase/migrations/20260828000000_baseline.sql"
expect_failure "a changed anchored migration" --offline

write_fixture
printf '%s\n' 'select 2;' >"$fixture/supabase/migrations/20260827000000_backdated.sql"
expect_failure "an unregistered backdated migration" --offline

write_fixture
mkdir -p "$fixture/supabase/schemas"
printf '%s\n' 'create table clean_history_copy(id bigint);' \
  >"$fixture/supabase/schemas/clean_history.sql"
expect_failure "a second declarative schema authority" --offline

write_fixture
sed 's/SUPABASE_CLI_VERSION: 2.115.0/SUPABASE_CLI_VERSION: 2.114.0/' \
  "$fixture/.github/workflows/ritual-investing-supabase-remediation.yml" \
  >"$fixture/.github/workflows/ritual-investing.next"
mv "$fixture/.github/workflows/ritual-investing.next" \
  "$fixture/.github/workflows/ritual-investing-supabase-remediation.yml"
expect_failure "a mismatched CI CLI pin" --offline

write_fixture
sed '/^vault|/d' \
  "$fixture/docs/ritual-investing/supabase-migration-inventory-v1.txt" \
  >"$fixture/docs/ritual-investing/supabase-migration-inventory-v1.next"
mv "$fixture/docs/ritual-investing/supabase-migration-inventory-v1.next" \
  "$fixture/docs/ritual-investing/supabase-migration-inventory-v1.txt"
expect_failure "an unclassified managed-resource family" --offline

write_fixture
printf '%s\n' "select pgmq.create('unowned_queue');" \
  >>"$fixture/supabase/migrations/20260828000000_baseline.sql"
checksum=$(shasum -a 256 \
  "$fixture/supabase/migrations/20260828000000_baseline.sql" | awk '{print $1}')
sed "s#^[0-9a-f]\{64\}  supabase/migrations/20260828000000_baseline.sql\$#$checksum  supabase/migrations/20260828000000_baseline.sql#" \
  "$fixture/docs/ritual-investing/supabase-migration-inventory-v1.txt" \
  >"$fixture/docs/ritual-investing/supabase-migration-inventory-v1.next"
mv "$fixture/docs/ritual-investing/supabase-migration-inventory-v1.next" \
  "$fixture/docs/ritual-investing/supabase-migration-inventory-v1.txt"
expect_failure "a source-declared queue missing from the ownership allowlist" --offline

write_fixture
mkdir -p "$fixture/bin"
cat >"$fixture/bin/supabase" <<'EOF'
#!/bin/sh
printf '%s\n' '2.114.0'
EOF
chmod +x "$fixture/bin/supabase"
if PATH="$fixture/bin:$PATH" ARGUS_SUPABASE_ROOT="$fixture" \
  "$checker" --check-cli >"$fixture-output" 2>&1; then
  printf '%s\n' "expected migration inventory to reject the wrong executable CLI" >&2
  exit 1
fi

cat >"$fixture/bin/supabase" <<'EOF'
#!/bin/sh
printf '%s\n' '2.115.0'
EOF
chmod +x "$fixture/bin/supabase"
PATH="$fixture/bin:$PATH" ARGUS_SUPABASE_ROOT="$fixture" \
  "$checker" --check-cli >"$fixture-output"

cat >"$fixture/bin/psql" <<'EOF'
#!/bin/sh
printf '%s\n' \
  'contract_version: supabase-replay-target-v1' \
  'migration|20260828000000|baseline' \
  'target_fingerprint|aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
EOF
chmod +x "$fixture/bin/psql"
PATH="$fixture/bin:$PATH" ARGUS_SUPABASE_ROOT="$fixture" \
  "$checker" --database-url postgresql://fixture --print-target-manifest \
  >"$fixture/first-target.txt"
PATH="$fixture/bin:$PATH" ARGUS_SUPABASE_ROOT="$fixture" \
  "$checker" --database-url postgresql://fixture \
  --compare-target-manifest "$fixture/first-target.txt" >"$fixture-output"

cat >"$fixture/bin/psql" <<'EOF'
#!/bin/sh
printf '%s\n' \
  'contract_version: supabase-replay-target-v1' \
  'queue|unowned_queue' \
  'target_fingerprint|cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'
EOF
chmod +x "$fixture/bin/psql"
if PATH="$fixture/bin:$PATH" ARGUS_SUPABASE_ROOT="$fixture" \
  "$checker" --database-url postgresql://fixture --print-target-manifest \
  >"$fixture-output" 2>&1; then
  printf '%s\n' "expected migration inventory to reject an unexpected live queue" >&2
  exit 1
fi

printf '%s\n' 'contract_version: supabase-replay-target-v1' \
  'target_fingerprint|bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' \
  >"$fixture/different-target.txt"
if PATH="$fixture/bin:$PATH" ARGUS_SUPABASE_ROOT="$fixture" \
  "$checker" --database-url postgresql://fixture \
  --compare-target-manifest "$fixture/different-target.txt" \
  >"$fixture-output" 2>&1; then
  printf '%s\n' "expected migration inventory to reject replay drift" >&2
  exit 1
fi

echo "Supabase migration inventory regression tests passed"

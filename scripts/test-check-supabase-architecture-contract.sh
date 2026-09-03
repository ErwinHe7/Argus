#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
checker="$repository_root/scripts/check-supabase-architecture-contract.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/argus-architecture-contract.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

write_fixture() {
  rm -rf "$fixture"
  mkdir -p \
    "$fixture/.github/workflows" \
    "$fixture/docs/ritual-investing" \
    "$fixture/platform/app/events/[id]" \
    "$fixture/scripts" \
    "$fixture/supabase/migrations" \
    "$fixture/supabase/functions/api" \
    "$fixture/supabase/tests"

  printf '%s\n' \
    'create extension if not exists pgcrypto with schema extensions;' \
    'create role argus_runtime nologin;' \
    'select 1;' \
    >"$fixture/supabase/migrations/20260828000000_baseline.sql"
  checksum=$(shasum -a 256 \
    "$fixture/supabase/migrations/20260828000000_baseline.sql" | awk '{print $1}')

  cat >"$fixture/docs/ritual-investing/supabase-remediation-register.md" <<EOF
# Fixture remediation register

contract_version: supabase-remediation-register-v1

<!-- scope:supabase/config.toml -->
<!-- scope:supabase/migrations/* -->
<!-- scope:supabase/functions/* -->
<!-- scope:supabase/tests/* -->
<!-- scope:scripts/* -->
<!-- scope:docs/ritual-investing/* -->
<!-- scope:platform/* -->
<!-- scope:.github/workflows/ritual-investing.yml -->
<!-- scope:.github/workflows/ritual-investing-supabase-remediation.yml -->
<!-- scope:.github/workflows/ritual-investing-*.yml -->
<!-- transitive:supabase/functions/api -->

### api ingress
### worker ingress
### webull-callback ingress
### waitlist ingress

| auth-jwks-read |
| auth-admin-delete |
| storage-read |
| storage-write |
| storage-delete |
| storage-sign |
| turnstile-verify |
| webull-authorization-exchange |
| webull-token-refresh |
| webull-projection-read |
| webull-command-submit |
| webull-command-lookup |
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
edge|api|platform|out-of-band|90|deploy-exact-revision
roles|argus-runtime|platform|migration-supported-api|01|create-or-verify

[roles]
argus_runtime|legacy|platform|nologin|none|none|statement=15s,idle_tx=15s
EOF
  cat >"$fixture/docs/ritual-investing/supabase-schema-authoring.md" <<'EOF'
# Fixture schema-authoring contract

Forward-only migrations are the sole schema authority.
EOF
  cat >"$fixture/docs/ritual-investing/supabase-target-model-contract-v1.md" <<'EOF'
# Fixture target model

contract_version: supabase-target-model-v1
EOF
  cat >"$fixture/docs/ritual-investing/supabase-performance-and-operations-budget-v1.md" <<'EOF'
# Fixture operations budget

contract_version: supabase-performance-operations-budget-v1
EOF
  cat >"$fixture/docs/ritual-investing/supabase-operations-runbook.md" <<'EOF'
# Fixture runbook

The remediation register, target model, and operations budget are promotion inputs.
EOF
  cat >"$fixture/supabase/config.toml" <<'EOF'
[db.migrations]
enabled = true
schema_paths = []

[functions.api]
verify_jwt = false
EOF
  cat >"$fixture/supabase/functions/api/index.ts" <<'EOF'
// Supabase-facing fixture entrypoint.
EOF
  cat >"$fixture/platform/app/events/[id]/page.tsx" <<'EOF'
// Supabase-facing dynamic-route fixture.
EOF
  cat >"$fixture/.github/workflows/ritual-investing.yml" <<'EOF'
env:
  SUPABASE_CLI_VERSION: 2.115.0
EOF
  cat >"$fixture/.github/workflows/ritual-investing-supabase-remediation.yml" <<'EOF'
env:
  SUPABASE_CLI_VERSION: 2.115.0
EOF
  cp "$repository_root/scripts/check-supabase-migration-inventory.sh" \
    "$fixture/scripts/check-supabase-migration-inventory.sh"
  cp "$repository_root/scripts/render-supabase-target-manifest.sql" \
    "$fixture/scripts/render-supabase-target-manifest.sql"
  chmod +x "$fixture/scripts/check-supabase-migration-inventory.sh"
  : >"$fixture/scripts/audit-supabase-architecture.sql"
  printf '%s\n' 'select plan(1);' 'select ok(true);' 'select * from finish();' \
    >"$fixture/supabase/tests/architecture_contract.test.sql"
  : >"$fixture/supabase/tests/member_lifecycle.test.sql"
  ARGUS_ARCHITECTURE_ROOT="$fixture" "$checker" --print-boundary-manifest \
    >"$fixture/docs/ritual-investing/supabase-boundary-manifest-v1.txt"
}

expect_failure() {
  label=$1
  if ARGUS_ARCHITECTURE_ROOT="$fixture" "$checker" --offline >"$fixture-output" 2>&1; then
    printf '%s\n' "expected architecture contract to reject $label" >&2
    exit 1
  fi
}

write_fixture

# The first implementation run was deliberately red because the checker did
# not exist. This branch now proves the reviewed fixture is accepted.
ARGUS_ARCHITECTURE_ROOT="$fixture" "$checker" --offline >"$fixture-output"
grep -F "Supabase architecture contract passed" "$fixture-output" >/dev/null

printf '%s\n' 'select 2;' >"$fixture/supabase/migrations/0002_unregistered.sql"
expect_failure "an unregistered migration"

write_fixture
printf '%s\n' '// New Supabase shortcut through an existing local adapter.' \
  >"$fixture/supabase/functions/api/unregistered.ts"
expect_failure "a new source surface inside a registered owner group"

write_fixture
printf '%s\n' '// Modified Supabase-facing fixture entrypoint.' \
  >"$fixture/supabase/functions/api/index.ts"
ARGUS_ARCHITECTURE_ROOT="$fixture" "$checker" --offline >"$fixture-output"
grep -F "Supabase architecture contract passed" "$fixture-output" >/dev/null

write_fixture
mkdir -p "$fixture/unowned-service"
printf '%s\n' '// Direct Supabase bypass.' >"$fixture/unowned-service/index.ts"
expect_failure "an unregistered Supabase-facing source surface"

echo "Supabase architecture contract regression tests passed"

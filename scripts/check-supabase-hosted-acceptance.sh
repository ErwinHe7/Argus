#!/bin/sh
set -eu

required() {
  eval "value=\${$1-}"
  test -n "$value" || {
    printf '%s\n' "hosted-acceptance: missing $1" >&2
    exit 1
  }
}

curl_bounded() {
  curl --connect-timeout 5 --max-time 15 --silent --show-error "$@"
}

assert_bundle_revision() {
  bundle_name=$1
  expected_status=$2
  bundle_url=$3
  headers_file=$(mktemp "${TMPDIR:-/tmp}/argus-${bundle_name}-headers.XXXXXX")
  trap 'rm -f "$headers_file"' EXIT HUP INT TERM
  observed_status=$(curl_bounded -X GET -D "$headers_file" -o /dev/null -w '%{http_code}' "$bundle_url")
  test "$observed_status" = "$expected_status" || {
    printf '%s\n' "hosted-acceptance: ${bundle_name} probe status mismatch" >&2
    exit 1
  }
  observed_revision=$(awk -F': *' 'tolower($1)=="x-argus-build-revision" { gsub("\\r", "", $2); print $2; exit }' "$headers_file")
  assert_observed_revision "$bundle_name" "$observed_revision"
  rm -f "$headers_file"
  trap - EXIT HUP INT TERM
}

assert_observed_revision() {
  bundle_name=$1
  observed_revision=$2
  if test -z "$observed_revision"; then
    test "$mode" = "--old-edge-new-schema" && return
    printf '%s\n' "hosted-acceptance: ${bundle_name} revision header missing" >&2
    exit 1
  fi
  test "$observed_revision" = "$expected_edge_revision" || {
    printf '%s\n' "hosted-acceptance: ${bundle_name} revision mismatch" >&2
    exit 1
  }
}

validate_project_identity() {
  required SUPABASE_DB_URL
  required SUPABASE_PROJECT_ID
  required SUPABASE_PROJECT_URL
  test "$SUPABASE_PROJECT_URL" = "https://$SUPABASE_PROJECT_ID.supabase.co" || {
    printf '%s\n' "hosted-acceptance: project URL/ref mismatch" >&2
    exit 1
  }
}

capture_fixture_inventory() {
  required RITUAL_FIXTURE_NAMESPACE
  case "$RITUAL_FIXTURE_NAMESPACE" in
    u9-*)
      ;;
    *)
      printf '%s\n' "hosted-acceptance: invalid fixture namespace" >&2
      exit 1
      ;;
  esac
  case "$RITUAL_FIXTURE_NAMESPACE" in
    *[!a-z0-9-]*)
      printf '%s\n' "hosted-acceptance: invalid fixture namespace" >&2
      exit 1
      ;;
  esac
  test "${#RITUAL_FIXTURE_NAMESPACE}" -ge 8 &&
    test "${#RITUAL_FIXTURE_NAMESPACE}" -le 63 || {
    printf '%s\n' "hosted-acceptance: invalid fixture namespace length" >&2
    exit 1
  }

  psql "$SUPABASE_DB_URL" -X -A -t -v ON_ERROR_STOP=1 \
    -v fixture_namespace="$RITUAL_FIXTURE_NAMESPACE" <<'SQL'
select 'fixture_inventory_version=u9-isolated-synthetic-v1'
union all select 'fixture_namespace=' || :'fixture_namespace'
union all select 'identities=' || count(*)::text
  from auth.users
 where email like :'fixture_namespace' || '%'
    or raw_user_meta_data ->> 'fixture_namespace' = :'fixture_namespace'
union all select 'objects=' || count(*)::text
  from storage.objects
 where name like :'fixture_namespace' || '/%'
union all select 'queues=' || count(*)::text
  from pgmq.meta
 where queue_name like :'fixture_namespace' || '%'
union all select 'schedules=' || count(*)::text
  from cron.job
 where jobname like :'fixture_namespace' || '%'
union all select 'roles=' || count(*)::text
  from pg_roles
 where rolname like :'fixture_namespace' || '%'
union all select 'rows=' || count(*)::text
  from argus_private.outbox_events
 where dedupe_key like :'fixture_namespace' || '%'
union all select 'configuration=' || (
  (select count(*) from vault.secrets
    where name like :'fixture_namespace' || '%')
  +
  (select count(*) from storage.buckets
    where id like :'fixture_namespace' || '%')
)::text;
SQL
}

assert_fixture_inventory_clean() {
  inventory_path=$1
  test -f "$inventory_path" || {
    printf '%s\n' "hosted-acceptance: missing fixture inventory" >&2
    exit 1
  }
  if ! awk -F= '
    BEGIN {
      expected[1] = "fixture_inventory_version"
      expected[2] = "fixture_namespace"
      expected[3] = "identities"
      expected[4] = "objects"
      expected[5] = "queues"
      expected[6] = "schedules"
      expected[7] = "roles"
      expected[8] = "rows"
      expected[9] = "configuration"
    }
    $1 != expected[NR] { exit 1 }
    NR == 1 && $2 != "u9-isolated-synthetic-v1" { exit 1 }
    NR > 2 && ($2 !~ /^[0-9]+$/ || $2 != "0") { exit 1 }
    END { if (NR != 9) exit 1 }
  ' "$inventory_path"; then
    printf '%s\n' \
      "hosted-acceptance: synthetic fixture cleanup no-go; leave every fence enabled" >&2
    exit 1
  fi
}

mode=${1---acceptance}
case "$mode" in
  --capture-fixture-inventory)
    validate_project_identity
    capture_fixture_inventory
    exit 0
    ;;
  --assert-fixture-clean)
    validate_project_identity
    fixture_tmp=$(mktemp "${TMPDIR:-/tmp}/argus-u9-fixtures.XXXXXX")
    trap 'rm -f "$fixture_tmp"' EXIT HUP INT TERM
    capture_fixture_inventory >"$fixture_tmp"
    assert_fixture_inventory_clean "$fixture_tmp"
    printf '%s\n' "Hosted isolated synthetic fixture cleanup passed."
    exit 0
    ;;
  --assert-fixture-parity)
    test "$#" -eq 3 || {
      printf '%s\n' "usage: $0 --assert-fixture-parity BEFORE AFTER" >&2
      exit 2
    }
    before_path=$2
    after_path=$3
    test -f "$before_path" && test -f "$after_path" || {
      printf '%s\n' "hosted-acceptance: missing fixture inventory artifact" >&2
      exit 1
    }
    assert_fixture_inventory_clean "$after_path"
    cmp -s "$before_path" "$after_path" || {
      printf '%s\n' \
        "hosted-acceptance: fixture inventory parity failed; no-go and leave every fence enabled" >&2
      exit 1
    }
    printf '%s\n' "Hosted fixture inventory before/after parity passed."
    exit 0
    ;;
  --acceptance|--old-edge-new-schema|--new-edge-new-schema)
    ;;
  *)
    printf '%s\n' "hosted-acceptance: unsupported mode" >&2
    exit 2
    ;;
esac

required GITHUB_SHA
required RITUAL_HOSTED_API_URL
validate_project_identity

expected_edge_revision=$GITHUB_SHA
state_label="new Edge/new schema"
if test "$mode" = "--old-edge-new-schema"; then
  required RITUAL_OLD_EDGE_REVISION
  expected_edge_revision=$RITUAL_OLD_EDGE_REVISION
  state_label="old Edge/new schema"
fi

# GoTrue health proves the hosted Auth service is reachable. No member token or
# service-role key is sent, logged, or stored by this acceptance hook.
curl_bounded --fail \
  "$SUPABASE_PROJECT_URL/auth/v1/health" >/dev/null

response=$(curl_bounded --fail \
  "$RITUAL_HOSTED_API_URL/v1/health/live")
observed=$(printf '%s' "$response" | jq -r '.data.build_revision')
test "$observed" = "$expected_edge_revision" || {
  printf '%s\n' "hosted-acceptance: Edge revision mismatch" >&2
  exit 1
}

# This anonymous bounded read exists in both mixed versions and proves an
# application query path, not just static inventory. It cannot mutate data.
api_headers=$(mktemp "${TMPDIR:-/tmp}/argus-api-headers.XXXXXX")
trap 'rm -f "$api_headers"' EXIT HUP INT TERM
public_editorial=$(curl_bounded --fail -X GET -D "$api_headers" \
  "$RITUAL_HOSTED_API_URL/v1/public/editorial/ritual?limit=1")
api_revision=$(awk -F': *' 'tolower($1)=="x-argus-build-revision" { gsub("\\r", "", $2); print $2; exit }' "$api_headers")
assert_observed_revision api "$api_revision"
if test "$mode" = "--old-edge-new-schema"; then
  public_editorial_contract='(.data | type == "array" and length <= 1) and
    (if has("meta") then
      (.meta | type == "object" and (.next_cursor == null or (.next_cursor | type == "string")) and (.has_more | type == "boolean"))
    else true end)'
else
  public_editorial_contract='(.data | type == "array" and length <= 1) and
    (.meta | type == "object" and (.next_cursor == null or (.next_cursor | type == "string")) and (.has_more | type == "boolean"))'
fi
printf '%s' "$public_editorial" | jq -e "$public_editorial_contract" >/dev/null || {
  printf '%s\n' "hosted-acceptance: public editorial envelope mismatch" >&2
  exit 1
}
rm -f "$api_headers"
trap - EXIT HUP INT TERM

# These unauthenticated probes deliberately select non-effect paths: callback
# has no state, worker uses GET, and waitlist has no allowed Origin.
assert_bundle_revision webull-callback 400 \
  "$SUPABASE_PROJECT_URL/functions/v1/webull-callback"
assert_bundle_revision worker 405 \
  "$SUPABASE_PROJECT_URL/functions/v1/worker"
assert_bundle_revision waitlist 403 \
  "$SUPABASE_PROJECT_URL/functions/v1/waitlist"

# This single read-only assertion proves the reviewed schema contract, exact
# queues, private bounded Storage buckets, role timeouts, and three independent
# external-effect fences.
database_contract=$(psql "$SUPABASE_DB_URL" -X -A -t -v ON_ERROR_STOP=1 -c "
  select concat_ws('|',
    exists (
      select 1 from argus_private.schema_contract_versions
      where version='webull-supabase-v1'
    ),
    (
      select coalesce(array_agg(queue_name order by queue_name), '{}')
      from pgmq.meta
      where queue_name in ('argus_jobs','brokerage_reconcile','brokerage_refresh')
    ) = array['argus_jobs','brokerage_reconcile','brokerage_refresh'],
    (
      select count(*)=3 and bool_and(not public) and
        bool_and(file_size_limit = case id
          when 'privacy-exports' then 52428800 else 10485760 end)
      from storage.buckets
      where id in ('member-media','media-quarantine','privacy-exports')
    ),
    coalesce((select rolconfig @> array['statement_timeout=15s']
      from pg_roles where rolname='argus_runtime'),false),
    coalesce((select rolconfig @> array['statement_timeout=45s']
      from pg_roles where rolname='argus_worker'),false),
    coalesce((select enabled from argus_private.kill_switches
      where name='background_workers'),false),
    coalesce((select enabled from argus_private.kill_switches
      where name='provider_egress'),false),
    coalesce((select enabled from argus_private.kill_switches
      where name='order_mutations'),false)
  );")

test "$database_contract" = "true|true|true|true|true|true|true|true" || {
  printf '%s\n' "hosted-acceptance: database inventory, limits, or fences mismatch" >&2
  exit 1
}

printf '%s\n' \
  "Hosted Supabase $state_label Auth, queue, Storage, limit, fence, and revision acceptance passed."

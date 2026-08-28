#!/bin/sh
set -eu

required() {
  eval "value=\${$1-}"
  test -n "$value" || {
    printf '%s\n' "hosted-acceptance: missing $1" >&2
    exit 1
  }
}

for variable in \
  GITHUB_SHA \
  RITUAL_HOSTED_API_URL \
  SUPABASE_DB_URL \
  SUPABASE_PROJECT_ID \
  SUPABASE_PROJECT_URL
do
  required "$variable"
done

test "$SUPABASE_PROJECT_URL" = "https://$SUPABASE_PROJECT_ID.supabase.co" || {
  printf '%s\n' "hosted-acceptance: project URL/ref mismatch" >&2
  exit 1
}

# GoTrue health proves the hosted Auth service is reachable. No member token or
# service-role key is sent, logged, or stored by this acceptance hook.
curl --fail --silent --show-error \
  "$SUPABASE_PROJECT_URL/auth/v1/health" >/dev/null

response=$(curl --fail --silent --show-error \
  "$RITUAL_HOSTED_API_URL/v1/health/live")
observed=$(printf '%s' "$response" | jq -r '.data.build_revision')
test "$observed" = "$GITHUB_SHA" || {
  printf '%s\n' "hosted-acceptance: Edge revision mismatch" >&2
  exit 1
}

# This single read-only assertion proves the reviewed schema contract, exact
# queues, private bounded Storage buckets, role timeouts, and deployment fences.
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
    (
      select count(*)=3 and bool_and(enabled)
      from argus_private.kill_switches
      where name in ('background_workers','provider_egress','order_mutations')
    )
  );")

test "$database_contract" = "true|true|true|true|true|true" || {
  printf '%s\n' "hosted-acceptance: database inventory or limits mismatch" >&2
  exit 1
}

printf '%s\n' "Hosted Supabase Auth, queue, Storage, limit, fence, and Edge revision acceptance passed."

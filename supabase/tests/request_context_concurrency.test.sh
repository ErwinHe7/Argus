#!/bin/sh
set -eu

fail() {
  printf '%s\n' "request-context concurrency proof failed: $*" >&2
  exit 1
}

local_database_url=${ARGUS_LOCAL_DB_URL:-}
local_database_container=${ARGUS_LOCAL_DB_CONTAINER:-supabase_db_argus}

if test -n "$local_database_url"; then
  case "$local_database_url" in
    postgres://*@127.0.0.1:*/*|postgresql://*@127.0.0.1:*/*|postgres://*@localhost:*/*|postgresql://*@localhost:*/*) ;;
    *) fail "ARGUS_LOCAL_DB_URL must target loopback" ;;
  esac
  command -v psql >/dev/null 2>&1 ||
    fail "psql is required when ARGUS_LOCAL_DB_URL is set"
  database() {
    psql "$local_database_url" -X -v ON_ERROR_STOP=1 "$@"
  }
else
  case "$local_database_container" in
    *[!A-Za-z0-9_.-]*) fail "ARGUS_LOCAL_DB_CONTAINER is malformed" ;;
  esac
  command -v docker >/dev/null 2>&1 ||
    fail "set ARGUS_LOCAL_DB_URL or install Docker"
  docker inspect "$local_database_container" >/dev/null 2>&1 ||
    fail "local Supabase database container is not running"
  database() {
    docker exec -i "$local_database_container" \
      psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
  }
fi

test "$(database -Atq -c \
  "select current_user||':'||session_user")" = postgres:postgres ||
  fail "harness requires a local postgres session"

lock_first_user=91919191-9191-4191-8191-919191919191
close_first_user=92929292-9292-4292-8292-929292929292
lock_first_session=91919191-0000-4000-8000-000000000001
close_first_session=92929292-0000-4000-8000-000000000001
lock_first_signal=9026082901
close_first_signal=9026082902
cleanup_policy=u3_request_context_concurrency_lifecycle_delete
proof_directory=$(mktemp -d "${TMPDIR:-/tmp}/argus-context-lock.XXXXXX")
lock_session_pid=
close_session_pid=
database_cleanup_complete=0

assert_supabase_admin_baseline() {
  database -q <<'SQL'
do $$
begin
  if current_user<>'postgres' or session_user<>'postgres' then
    raise exception 'request_context_concurrency_requires_postgres';
  end if;
  if (
    select count(*)
      from pg_catalog.pg_auth_members membership
      join pg_catalog.pg_roles granted_role
        on granted_role.oid=membership.roleid
      join pg_catalog.pg_roles member_role
        on member_role.oid=membership.member
      join pg_catalog.pg_roles grantor_role
        on grantor_role.oid=membership.grantor
     where granted_role.rolname in ('argus_edge','argus_identity_owner')
       and member_role.rolname='postgres'
       and grantor_role.rolname='supabase_admin'
       and membership.admin_option
       and not membership.inherit_option
       and not membership.set_option
  )<>2 then
    raise exception 'request_context_concurrency_admin_baseline_changed';
  end if;
end
$$;
SQL
}

cleanup_database() {
  assert_supabase_admin_baseline || return 1
  database -q <<SQL || return 1
begin;
grant argus_edge,argus_identity_owner to postgres
  with inherit false,set true,admin false granted by postgres;
set local role argus_identity_owner;
drop policy if exists $cleanup_policy
  on argus_app.member_lifecycles;
create policy $cleanup_policy
  on argus_app.member_lifecycles
  for delete to argus_identity_owner
  using (identity_subject_id in (
    '$lock_first_user'::uuid,'$close_first_user'::uuid
  ));
reset role;

-- The Auth fixture creates U4 children by cascade-owned provisioning and no
-- U5 children. Remove the retained postgres-owned member root first; any
-- unexpected dependent row makes this transaction fail instead of broadening
-- test cleanup into another domain.
delete from argus_app.members
 where user_id in ('$lock_first_user'::uuid,'$close_first_user'::uuid);

-- FORCE RLS requires the identity owner plus this fixed-subject test policy.
set local role argus_identity_owner;
delete from argus_app.member_lifecycles
 where identity_subject_id in (
   '$lock_first_user'::uuid,'$close_first_user'::uuid
 );
drop policy $cleanup_policy on argus_app.member_lifecycles;
reset role;

-- Auth is last so its member-delete cascade cannot strand the lifecycle root.
delete from auth.users
 where id in ('$lock_first_user'::uuid,'$close_first_user'::uuid);
revoke argus_edge,argus_identity_owner from postgres granted by postgres;
commit;
SQL
  assert_supabase_admin_baseline || return 1
  database -q <<SQL || return 1
do \$\$
begin
  if pg_catalog.pg_has_role('postgres','argus_edge','set')
     or pg_catalog.pg_has_role('postgres','argus_identity_owner','set') then
    raise exception 'request_context_concurrency_set_residue';
  end if;
  if exists (
    select 1
      from pg_catalog.pg_auth_members membership
      join pg_catalog.pg_roles granted_role
        on granted_role.oid=membership.roleid
      join pg_catalog.pg_roles member_role
        on member_role.oid=membership.member
      join pg_catalog.pg_roles grantor_role
        on grantor_role.oid=membership.grantor
     where granted_role.rolname in ('argus_edge','argus_identity_owner')
       and member_role.rolname='postgres'
       and grantor_role.rolname='postgres'
       and (membership.set_option or membership.inherit_option)
  ) then
    raise exception 'request_context_concurrency_membership_residue';
  end if;
  if exists (
    select 1 from pg_catalog.pg_policies policy
     where policy.schemaname='argus_app'
       and policy.tablename='member_lifecycles'
       and policy.policyname='$cleanup_policy'
  ) then
    raise exception 'request_context_concurrency_policy_residue';
  end if;
  if exists (
    select 1 from auth.users user_row
     where user_row.id in (
       '$lock_first_user'::uuid,'$close_first_user'::uuid
     )
  ) or exists (
    select 1 from argus_app.members member
     where member.user_id in (
       '$lock_first_user'::uuid,'$close_first_user'::uuid
     )
  ) or exists (
    select 1 from argus_app.member_lifecycles lifecycle
     where lifecycle.identity_subject_id in (
       '$lock_first_user'::uuid,'$close_first_user'::uuid
     )
  ) then
    raise exception 'request_context_concurrency_fixture_residue';
  end if;
end
\$\$;
SQL
}

install_harness_authority() {
  assert_supabase_admin_baseline || return 1
  database -q <<SQL || return 1
begin;
grant argus_edge,argus_identity_owner to postgres
  with inherit false,set true,admin false granted by postgres;
set local role argus_identity_owner;
create policy $cleanup_policy
  on argus_app.member_lifecycles
  for delete to argus_identity_owner
  using (identity_subject_id in (
    '$lock_first_user'::uuid,'$close_first_user'::uuid
  ));
reset role;
commit;

do \$\$
begin
  if not pg_catalog.pg_has_role('postgres','argus_edge','set')
     or not pg_catalog.pg_has_role(
       'postgres','argus_identity_owner','set'
     ) then
    raise exception 'request_context_concurrency_set_install_failed';
  end if;
  if (
    select count(*)
      from pg_catalog.pg_auth_members membership
      join pg_catalog.pg_roles granted_role
        on granted_role.oid=membership.roleid
      join pg_catalog.pg_roles member_role
        on member_role.oid=membership.member
      join pg_catalog.pg_roles grantor_role
        on grantor_role.oid=membership.grantor
     where granted_role.rolname in ('argus_edge','argus_identity_owner')
       and member_role.rolname='postgres'
       and grantor_role.rolname='postgres'
       and not membership.admin_option
       and not membership.inherit_option
       and membership.set_option
  )<>2 then
    raise exception 'request_context_concurrency_grantor_scope_failed';
  end if;
end
\$\$;
SQL
  assert_supabase_admin_baseline || return 1
}

stop_background_sessions() {
  for process_id in "$lock_session_pid" "$close_session_pid"; do
    if test -n "$process_id" && kill -0 "$process_id" 2>/dev/null; then
      kill "$process_id" 2>/dev/null || true
      wait "$process_id" 2>/dev/null || true
    fi
  done
}

finish() {
  proof_status=$?
  trap - EXIT HUP INT TERM
  stop_background_sessions
  if test "$database_cleanup_complete" -ne 1; then
    if ! cleanup_database; then
      printf '%s\n' \
        'request-context concurrency proof cleanup failed' >&2
      proof_status=1
    fi
  fi
  rm -f "$proof_directory/lock-session.log" \
    "$proof_directory/blocked-close.log" \
    "$proof_directory/close-session.log" \
    "$proof_directory/blocked-install.log"
  rmdir "$proof_directory"
  exit "$proof_status"
}
trap finish EXIT
trap 'exit 1' HUP INT TERM

wait_for_session_signal() {
  signal_key=$1
  attempts=0
  while test "$attempts" -lt 100; do
    signal_state=$(database -Atq -c "
      select case
        when pg_catalog.pg_try_advisory_lock($signal_key) then
          case when pg_catalog.pg_advisory_unlock($signal_key)
            then 'waiting' else 'waiting' end
        else 'ready'
      end
    ")
    test "$signal_state" = ready && return 0
    attempts=$((attempts + 1))
    sleep 0.05
  done
  fail "session signal $signal_key was not acquired"
}

# Startup cleanup is deliberate and idempotent: it removes only the fixed
# subjects, named policy, and postgres-grantor memberships owned by this proof.
cleanup_database
install_harness_authority

database -q <<SQL
insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','$lock_first_user',
   'authenticated','authenticated','context-lock-first@example.test','',
   pg_catalog.clock_timestamp(),'{"provider":"email","providers":["email"]}',
   '{}',pg_catalog.clock_timestamp(),pg_catalog.clock_timestamp()),
  ('00000000-0000-0000-0000-000000000000','$close_first_user',
   'authenticated','authenticated','context-close-first@example.test','',
   pg_catalog.clock_timestamp(),'{"provider":"email","providers":["email"]}',
   '{}',pg_catalog.clock_timestamp(),pg_catalog.clock_timestamp());
SQL

# Lock-first: installation must hold the lifecycle FOR SHARE lock until the
# request transaction commits, so a concurrent close times out while waiting.
database -q >"$proof_directory/lock-session.log" 2>&1 <<SQL &
begin;
set local role argus_edge;
select argus_private.install_request_context(
  '$lock_first_user'::uuid,'$lock_first_session'::uuid,'aal1'
);
select pg_catalog.pg_advisory_lock($lock_first_signal);
select pg_catalog.pg_sleep(3);
commit;
select pg_catalog.pg_advisory_unlock($lock_first_signal);
SQL
lock_session_pid=$!
wait_for_session_signal "$lock_first_signal"

set +e
database -q >"$proof_directory/blocked-close.log" 2>&1 <<SQL
begin;
set local role argus_identity_owner;
set local statement_timeout='500ms';
select argus_private.close_member_lifecycle(
  (select lifecycle_id from argus_app.members
    where user_id='$lock_first_user'::uuid),
  'concurrency-close'
);
commit;
SQL
blocked_close_status=$?
set -e
test "$blocked_close_status" -ne 0 ||
  fail "lifecycle close did not wait for installed context"
grep -q 'canceling statement due to statement timeout' \
  "$proof_directory/blocked-close.log" ||
  fail "blocked close did not fail through statement timeout"
wait "$lock_session_pid"
lock_session_pid=
test "$(database -Atq -c "
  select lifecycle.state from argus_app.member_lifecycles lifecycle
   where lifecycle.identity_subject_id='$lock_first_user'::uuid
")" = open || fail "timed-out close changed the lifecycle"

# Close-first: the uncommitted close owns the row first. Installation may see
# the prior snapshot, but its shared-lock helper waits, rechecks after commit,
# and must fail closed instead of installing stale context.
database -q >"$proof_directory/close-session.log" 2>&1 <<SQL &
begin;
set local role argus_identity_owner;
select argus_private.close_member_lifecycle(
  (select lifecycle_id from argus_app.members
    where user_id='$close_first_user'::uuid),
  'concurrency-close-first'
);
select pg_catalog.pg_advisory_lock($close_first_signal);
select pg_catalog.pg_sleep(2);
commit;
select pg_catalog.pg_advisory_unlock($close_first_signal);
SQL
close_session_pid=$!
wait_for_session_signal "$close_first_signal"

set +e
database -q >"$proof_directory/blocked-install.log" 2>&1 <<SQL
set statement_timeout='5s';
begin;
set local role argus_edge;
select argus_private.install_request_context(
  '$close_first_user'::uuid,'$close_first_session'::uuid,'aal1'
);
commit;
SQL
blocked_install_status=$?
set -e
test "$blocked_install_status" -ne 0 ||
  fail "close-first installation unexpectedly succeeded"
grep -q 'inactive_member_lifecycle' \
  "$proof_directory/blocked-install.log" ||
  fail "close-first installation did not fail as inactive"
wait "$close_session_pid"
close_session_pid=
test "$(database -Atq -c "
  select lifecycle.state from argus_app.member_lifecycles lifecycle
   where lifecycle.identity_subject_id='$close_first_user'::uuid
")" = closed || fail "close-first lifecycle did not commit"

cleanup_database
database_cleanup_complete=1
printf '%s\n' \
  'request-context concurrency proof passed: close waits; close-first install denies'

-- U12: public waitlist state now lives behind a dedicated Supabase Edge
-- function. The table is not exposed through PostgREST and the unauthenticated
-- browser never receives a database credential.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'argus_waitlist') then
    create role argus_waitlist
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'argus_waitlist_edge') then
    create role argus_waitlist_edge
      login noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
end
$$;

alter role argus_waitlist_edge password null;
alter role argus_waitlist_edge set statement_timeout = '10s';
alter role argus_waitlist_edge set lock_timeout = '2s';
alter role argus_waitlist_edge set idle_in_transaction_session_timeout = '10s';
alter role argus_waitlist_edge set idle_session_timeout = '5min';

revoke all on schema argus_app, argus_brokerage, argus_private
  from argus_waitlist, argus_waitlist_edge;
revoke all on all tables in schema argus_app, argus_brokerage, argus_private
  from argus_waitlist, argus_waitlist_edge;
revoke all on all sequences in schema argus_app, argus_brokerage, argus_private
  from argus_waitlist, argus_waitlist_edge;
revoke all on all functions in schema argus_app, argus_brokerage, argus_private
  from argus_waitlist, argus_waitlist_edge;
revoke argus_runtime, argus_worker from argus_waitlist_edge;
grant argus_waitlist to argus_waitlist_edge;

create table argus_private.waitlist_submissions (
  normalized_email text primary key,
  notice_version text not null,
  submitted_at timestamptz not null default clock_timestamp(),
  check (
    normalized_email = lower(btrim(normalized_email))
    and char_length(normalized_email) between 3 and 254
    and normalized_email ~ '^[^[:space:]@]+@[^[:space:]@]+$'
  ),
  check (
    char_length(notice_version) between 1 and 128
    and notice_version ~ '^waitlist-v[0-9]+-[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  )
);

alter table argus_private.waitlist_submissions enable row level security;
alter table argus_private.waitlist_submissions force row level security;

create function argus_private.submit_waitlist(
  p_normalized_email text,
  p_notice_version text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, argus_private
as $$
begin
  if p_normalized_email is null
     or p_normalized_email <> lower(btrim(p_normalized_email))
     or char_length(p_normalized_email) not between 3 and 254
     or p_normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+$'
     or p_notice_version is null
     or p_notice_version !~ '^waitlist-v[0-9]+-[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  then
    raise exception 'invalid_waitlist_submission' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('argus:waitlist:v1:' || p_normalized_email, 0)
  );
  insert into argus_private.waitlist_submissions(
    normalized_email,
    notice_version,
    submitted_at
  ) values (
    p_normalized_email,
    p_notice_version,
    clock_timestamp()
  ) on conflict (normalized_email) do nothing;
end
$$;

create function argus_private.purge_expired_waitlist_submissions()
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, argus_private
as $$
declare
  purged bigint;
begin
  delete from argus_private.waitlist_submissions
   where submitted_at <= clock_timestamp() - interval '23 months 29 days';
  get diagnostics purged = row_count;
  return purged;
end
$$;

create function argus_private.remove_waitlist_submission(
  p_normalized_email text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, argus_private
as $$
begin
  if p_normalized_email is null
     or p_normalized_email <> lower(btrim(p_normalized_email))
     or char_length(p_normalized_email) not between 3 and 254
     or p_normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+$'
  then
    raise exception 'invalid_waitlist_removal' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended('argus:waitlist:v1:' || p_normalized_email, 0)
  );
  delete from argus_private.waitlist_submissions
   where normalized_email = p_normalized_email;
end
$$;

revoke all on argus_private.waitlist_submissions
  from public, anon, authenticated, argus_runtime, argus_waitlist, argus_worker;
revoke all on function argus_private.submit_waitlist(text, text),
  argus_private.purge_expired_waitlist_submissions(),
  argus_private.remove_waitlist_submission(text)
  from public, anon, authenticated, argus_runtime, argus_waitlist, argus_worker;
grant execute on function argus_private.submit_waitlist(text, text)
  to argus_waitlist;

create policy waitlist_gateway_rate_limit
  on argus_private.gateway_rate_limits
  for all
  to argus_waitlist
  using (true)
  with check (true);
grant usage on schema argus_private to argus_waitlist;
grant select, insert, update on argus_private.gateway_rate_limits
  to argus_waitlist;

select cron.unschedule(jobid)
  from cron.job
 where jobname = 'argus-waitlist-retention';
select cron.schedule(
  'argus-waitlist-retention',
  '17 4 * * *',
  'select argus_private.purge_expired_waitlist_submissions();'
);

comment on table argus_private.waitlist_submissions is
  'Provisional, unverified launch requests. Duplicate insertion is deliberately non-enumerating.';
comment on function argus_private.submit_waitlist(text, text) is
  'Minimal waitlist write capability for the public Edge function; direct table access remains denied.';
comment on function argus_private.remove_waitlist_submission(text) is
  'Owner-only, non-enumerating deletion after mailbox possession is verified out of band.';

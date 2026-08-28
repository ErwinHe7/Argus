-- U10: private Supabase Queues/Cron/Storage runtime for retained, non-financial work.
-- Worker URL and invocation credentials are provisioned into Vault out of band.

create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'argus_worker_edge') then
    create role argus_worker_edge
      login noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
end
$$;

alter role argus_worker_edge password null;
alter role argus_worker_edge set statement_timeout = '45s';
alter role argus_worker_edge set lock_timeout = '3s';
alter role argus_worker_edge set idle_in_transaction_session_timeout = '15s';
alter role argus_worker_edge set idle_session_timeout = '5min';
revoke all on schema argus_app, argus_brokerage, argus_private from argus_worker_edge;
revoke all on all tables in schema argus_app, argus_brokerage, argus_private from argus_worker_edge;
revoke all on all functions in schema argus_app, argus_brokerage, argus_private from argus_worker_edge;
grant argus_worker to argus_worker_edge;

-- Queue bodies are opaque. Handler selection and ownership are recovered from
-- this private outbox row after the message is leased.
alter table argus_private.outbox_events
  drop constraint if exists outbox_events_retained_event_type_check;
alter table argus_private.outbox_events
  add constraint outbox_events_retained_event_type_check check (
    topic <> 'argus_jobs' or event_type in (
      'briefing.daily.requested',
      'briefing.weekly.requested',
      'briefing.moon_cycle.requested',
      'briefing.daily.generated',
      'briefing.weekly.generated',
      'briefing.moon_cycle.generated',
      'media.scan.requested',
      'media.quarantine.cleanup',
      'content-report.created',
      'privacy.export.requested',
      'privacy.deletion.requested',
      'privacy.export.retention.requested'
    )
  );

alter table argus_private.media_upload_intents
  add constraint media_upload_intents_owner_path_check check (
    object_path like user_id::text || '/%'
    and object_path not like '%..%'
    and char_length(object_path) <= 549
  );
alter table argus_private.privacy_export_artifacts
  add constraint privacy_export_artifacts_owner_path_check check (
    object_path like user_id::text || '/%'
    and object_path not like '%..%'
    and char_length(object_path) <= 549
  );

alter table argus_private.job_runs
  add column if not exists queue_message_id bigint,
  add column if not exists handler_name text,
  add column if not exists max_attempts integer not null default 5
    check (max_attempts between 1 and 10),
  add column if not exists diagnostic_hash text
    check (diagnostic_hash is null or diagnostic_hash ~ '^[a-f0-9]{64}$');

create unique index if not exists job_runs_source_event_unique
  on argus_private.job_runs(source_event_id) where source_event_id is not null;

create table argus_private.job_attempts (
  id uuid primary key default gen_random_uuid(),
  job_run_id uuid not null references argus_private.job_runs(id) on delete cascade,
  attempt_number integer not null check (attempt_number > 0),
  outcome text not null check (outcome in ('started','succeeded','retry','dead_lettered','cancelled')),
  failure_code text,
  diagnostic_hash text check (diagnostic_hash is null or diagnostic_hash ~ '^[a-f0-9]{64}$'),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (job_run_id, attempt_number)
);

create table argus_private.dead_letter_events (
  id uuid primary key default gen_random_uuid(),
  outbox_event_id uuid references argus_private.outbox_events(id) on delete set null,
  queue_message_id bigint,
  handler_name text,
  reason_code text not null,
  diagnostic_hash text not null check (diagnostic_hash ~ '^[a-f0-9]{64}$'),
  occurred_at timestamptz not null default now()
);

create table argus_private.worker_invocation_nonces (
  nonce_hash text primary key check (nonce_hash ~ '^[a-f0-9]{64}$'),
  issued_at timestamptz not null,
  consumed_at timestamptz not null default now(),
  check (issued_at >= consumed_at - interval '65 seconds' and issued_at <= consumed_at + interval '5 seconds')
);
create index worker_invocation_nonces_expiry_idx
  on argus_private.worker_invocation_nonces(consumed_at);

alter table argus_private.deletion_tombstones
  add column if not exists purge_phase text not null default 'requested'
    check (purge_phase in ('requested','neutralized','storage_purged','data_purged','complete')),
  add column if not exists auth_deleted_at timestamptz,
  add column if not exists purged_tables_count integer not null default 0
    check (purged_tables_count >= 0);

drop table argus_private.consumer_receipts cascade;
create table argus_private.consumer_receipts (
  outbox_event_id uuid not null references argus_private.outbox_events(id) on delete cascade,
  handler_name text not null,
  user_id uuid,
  deletion_epoch bigint,
  effect_hash text not null check (effect_hash ~ '^[a-f0-9]{64}$'),
  completed_at timestamptz not null default now(),
  primary key (outbox_event_id, handler_name),
  check ((user_id is null) = (deletion_epoch is null))
);

alter table argus_private.job_attempts enable row level security;
alter table argus_private.job_attempts force row level security;
alter table argus_private.dead_letter_events enable row level security;
alter table argus_private.dead_letter_events force row level security;
alter table argus_private.worker_invocation_nonces enable row level security;
alter table argus_private.worker_invocation_nonces force row level security;
alter table argus_private.consumer_receipts enable row level security;
alter table argus_private.consumer_receipts force row level security;

create policy worker_internal on argus_private.job_attempts
  for all to argus_worker using (true) with check (true);
create policy worker_internal on argus_private.dead_letter_events
  for all to argus_worker using (true) with check (true);
create policy worker_internal on argus_private.worker_invocation_nonces
  for all to argus_worker using (true) with check (true);
create policy worker_internal on argus_private.consumer_receipts
  for all to argus_worker using (true) with check (true);

grant select, insert, update, delete on
  argus_private.job_attempts,
  argus_private.dead_letter_events,
  argus_private.worker_invocation_nonces
to argus_worker;
grant select on argus_private.consumer_receipts to argus_worker;
revoke insert, update, delete on argus_private.consumer_receipts from argus_worker;

-- Only the active event owner and epoch become visible to a worker. The
-- setting is transaction-local and can be established only for a leased event.
create or replace function argus_private.worker_user_id()
returns uuid
language sql stable security invoker
set search_path = pg_catalog
as $$
  select nullif(current_setting('argus.worker_user_id', true), '')::uuid
$$;

create or replace function argus_private.worker_deletion_epoch()
returns bigint
language sql stable security invoker
set search_path = pg_catalog
as $$
  select nullif(current_setting('argus.worker_deletion_epoch', true), '')::bigint
$$;

create or replace function argus_private.assert_worker_event_current(p_event_id uuid)
returns boolean
language plpgsql security definer
set search_path = pg_catalog, argus_private, argus_app
as $$
declare
  event_record argus_private.outbox_events%rowtype;
begin
  select * into event_record from argus_private.outbox_events where id = p_event_id;
  if event_record.id is null then
    return false;
  end if;
  if event_record.user_id is null then
    return true;
  end if;
  return exists (
    select 1 from argus_app.members member
     where member.user_id = event_record.user_id
       and member.status in ('active','deletion_pending','purging')
       and member.deletion_epoch = event_record.deletion_epoch
  );
end
$$;

create or replace function argus_private.set_worker_event_context(
  p_event_id uuid,
  p_job_run_id uuid,
  p_lease_token uuid
)
returns table(event_type text, aggregate_id uuid, user_id uuid, deletion_epoch bigint)
language plpgsql security definer
set search_path = pg_catalog, argus_private, argus_app
as $$
declare
  event_record argus_private.outbox_events%rowtype;
begin
  select event.* into event_record
    from argus_private.outbox_events event
    join argus_private.job_runs run on run.source_event_id = event.id
   where event.id = p_event_id and event.topic = 'argus_jobs'
     and run.id = p_job_run_id and run.lease_token = p_lease_token
     and run.status = 'leased' and run.leased_until > clock_timestamp();
  if event_record.id is null then
    raise exception 'event_not_found';
  end if;
  if event_record.user_id is not null and not argus_private.assert_worker_event_current(p_event_id) then
    raise exception 'deletion_epoch_changed';
  end if;
  perform set_config('argus.worker_event_id', p_event_id::text, true);
  perform set_config('argus.worker_user_id', coalesce(event_record.user_id::text, ''), true);
  perform set_config('argus.worker_deletion_epoch', coalesce(event_record.deletion_epoch::text, ''), true);
  return query select event_record.event_type, event_record.aggregate_id,
    event_record.user_id, event_record.deletion_epoch;
end
$$;

revoke all on function argus_private.worker_user_id(),
  argus_private.worker_deletion_epoch(),
  argus_private.assert_worker_event_current(uuid),
  argus_private.set_worker_event_context(uuid,uuid,uuid)
from public, anon, authenticated, argus_runtime;
grant execute on function argus_private.worker_user_id(),
  argus_private.worker_deletion_epoch(),
  argus_private.assert_worker_event_current(uuid),
  argus_private.set_worker_event_context(uuid,uuid,uuid)
to argus_worker;

alter function argus_private.assert_worker_event_current(uuid) owner to postgres;
alter function argus_private.set_worker_event_context(uuid,uuid,uuid) owner to postgres;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'members','profiles','preferences','astrology_profiles','investor_profiles',
    'onboarding_states','consent_records','notification_preferences',
    'daily_ritual_assignments','circles','circle_assets','saved_items','intentions',
    'future_mirror_runs','future_mirror_points','briefings','briefing_sections',
    'notifications','privacy_requests','content_reports'
  ]
  loop
    execute format(
      'create policy worker_event_owner on argus_app.%I for all to argus_worker using (user_id = (select argus_private.worker_user_id()) and deletion_epoch = (select argus_private.worker_deletion_epoch())) with check (user_id = (select argus_private.worker_user_id()) and deletion_epoch = (select argus_private.worker_deletion_epoch()))',
      table_name
    );
  end loop;
end
$$;

create policy worker_event_owner on argus_private.media_upload_intents
  for all to argus_worker
  using (user_id = (select argus_private.worker_user_id()) and deletion_epoch = (select argus_private.worker_deletion_epoch()))
  with check (user_id = (select argus_private.worker_user_id()) and deletion_epoch = (select argus_private.worker_deletion_epoch()));
create policy worker_event_owner on argus_private.privacy_export_artifacts
  for all to argus_worker
  using (user_id = (select argus_private.worker_user_id()) and deletion_epoch = (select argus_private.worker_deletion_epoch()))
  with check (user_id = (select argus_private.worker_user_id()) and deletion_epoch = (select argus_private.worker_deletion_epoch()));

grant select, insert, update, delete on
  argus_app.members,
  argus_app.profiles,
  argus_app.preferences,
  argus_app.astrology_profiles,
  argus_app.investor_profiles,
  argus_app.onboarding_states,
  argus_app.consent_records,
  argus_app.notification_preferences,
  argus_app.daily_ritual_assignments,
  argus_app.circles,
  argus_app.circle_assets,
  argus_app.saved_items,
  argus_app.intentions,
  argus_app.future_mirror_runs,
  argus_app.future_mirror_points,
  argus_app.briefings,
  argus_app.briefing_sections,
  argus_app.notifications,
  argus_app.privacy_requests,
  argus_app.content_reports
to argus_worker;
grant select, insert, update, delete on
  argus_private.media_upload_intents,
  argus_private.privacy_export_artifacts
to argus_worker;

-- media_assets and moderation_cases are global editorial tables. Workers never
-- receive table-wide access: these owner functions bind the row to the active
-- leased event and its transaction-local owner context.
create or replace function argus_private.get_media_scan_target(p_event_id uuid)
returns table(
  bucket_id text,
  object_path text,
  mime_type text,
  max_bytes bigint,
  status text,
  checksum text
)
language plpgsql security definer
set search_path = pg_catalog, argus_private, argus_app
as $$
begin
  if current_setting('argus.worker_event_id', true) is distinct from p_event_id::text then
    raise exception 'worker_event_context_missing';
  end if;
  return query
    select intent.bucket_id,intent.object_path,intent.mime_type,intent.max_bytes,
           intent.status,asset.checksum
      from argus_private.outbox_events event
      join argus_private.media_upload_intents intent
        on intent.id = event.aggregate_id
       and intent.user_id = event.user_id
       and intent.deletion_epoch = event.deletion_epoch
      left join argus_app.media_assets asset
        on asset.storage_bucket = intent.bucket_id
       and asset.storage_path = intent.object_path
     where event.id = p_event_id
       and event.topic = 'argus_jobs'
       and event.event_type = 'media.scan.requested'
       and argus_private.assert_worker_event_current(event.id)
     for update of intent;
end
$$;

create or replace function argus_private.complete_media_scan(
  p_event_id uuid,
  p_accepted boolean,
  p_checksum text
)
returns boolean
language plpgsql security definer
set search_path = pg_catalog, argus_private, argus_app
as $$
declare event_record argus_private.outbox_events%rowtype;
declare affected integer;
begin
  if current_setting('argus.worker_event_id', true) is distinct from p_event_id::text
     or p_checksum !~ '^[a-f0-9]{64}$'
     or not argus_private.assert_worker_event_current(p_event_id) then
    raise exception 'deletion_epoch_changed';
  end if;
  select * into event_record from argus_private.outbox_events
   where id = p_event_id and event_type = 'media.scan.requested';
  if event_record.id is null then raise exception 'event_not_found'; end if;
  update argus_private.media_upload_intents
     set status = case when p_accepted then 'accepted' else 'rejected' end
   where id = event_record.aggregate_id
     and user_id = event_record.user_id
     and deletion_epoch = event_record.deletion_epoch
     and status in ('uploaded','scanning');
  get diagnostics affected = row_count;
  if affected <> 1 then return false; end if;
  update argus_app.media_assets asset
     set quarantine_status = case when p_accepted then 'clear' else 'rejected' end,
         status = case when p_accepted then 'active' else 'retired' end,
         checksum = p_checksum
    from argus_private.media_upload_intents intent
   where intent.id = event_record.aggregate_id
     and asset.storage_bucket = intent.bucket_id
     and asset.storage_path = intent.object_path;
  return found;
end
$$;

create or replace function argus_private.triage_content_report(p_event_id uuid)
returns text
language plpgsql security definer
set search_path = pg_catalog, argus_private, argus_app
as $$
declare event_record argus_private.outbox_events%rowtype;
begin
  if current_setting('argus.worker_event_id', true) is distinct from p_event_id::text
     or not argus_private.assert_worker_event_current(p_event_id) then
    raise exception 'deletion_epoch_changed';
  end if;
  select * into event_record from argus_private.outbox_events
   where id = p_event_id and event_type = 'content-report.created';
  if event_record.id is null then raise exception 'event_not_found'; end if;
  insert into argus_app.moderation_cases(report_id)
  select report.id from argus_app.content_reports report
   where report.id = event_record.aggregate_id
     and report.user_id = event_record.user_id
     and report.deletion_epoch = event_record.deletion_epoch
  on conflict (report_id) do nothing;
  if not found and not exists (
    select 1 from argus_app.moderation_cases where report_id = event_record.aggregate_id
  ) then
    raise exception 'invalid_event_payload';
  end if;
  return 'moderation:' || event_record.aggregate_id::text;
end
$$;

alter function argus_private.get_media_scan_target(uuid) owner to postgres;
alter function argus_private.complete_media_scan(uuid,boolean,text) owner to postgres;
alter function argus_private.triage_content_report(uuid) owner to postgres;
revoke all on function argus_private.get_media_scan_target(uuid),
  argus_private.complete_media_scan(uuid,boolean,text),
  argus_private.triage_content_report(uuid)
from public, anon, authenticated, argus_runtime;
grant execute on function argus_private.get_media_scan_target(uuid),
  argus_private.complete_media_scan(uuid,boolean,text),
  argus_private.triage_content_report(uuid)
to argus_worker;

create or replace function argus_private.relay_outbox(p_batch_size integer default 25)
returns integer
language plpgsql security definer
set search_path = pg_catalog, argus_private, pgmq
as $$
declare
  event_record argus_private.outbox_events%rowtype;
  sent integer := 0;
begin
  if p_batch_size < 1 or p_batch_size > 25 then
    raise exception 'invalid_batch_size';
  end if;
  if exists (select 1 from argus_private.kill_switches where name = 'background_workers' and enabled) then
    return 0;
  end if;
  for event_record in
    select * from argus_private.outbox_events
     where topic = 'argus_jobs'
       and published_at is null and available_at <= clock_timestamp()
     order by available_at, id for update skip locked limit p_batch_size
  loop
    perform pgmq.send(
      event_record.topic,
      jsonb_build_object('version', 1, 'event_id', event_record.id)
    );
    update argus_private.outbox_events
       set published_at = clock_timestamp(), publish_attempts = publish_attempts + 1,
           last_error_code = null
     where id = event_record.id;
    sent := sent + 1;
  end loop;
  return sent;
end
$$;

create or replace function argus_private.acquire_worker_lease(
  p_token uuid,
  p_lease_seconds integer default 50
)
returns boolean
language plpgsql security invoker
set search_path = pg_catalog, argus_private
as $$
begin
  if p_lease_seconds < 5 or p_lease_seconds > 55 then
    raise exception 'invalid_lease_duration';
  end if;
  insert into argus_private.cron_leases(lease_name, lease_token, leased_until, updated_at)
  values ('argus-worker', p_token, clock_timestamp() + make_interval(secs => p_lease_seconds), clock_timestamp())
  on conflict (lease_name) do update
    set lease_token = excluded.lease_token,
        leased_until = excluded.leased_until,
        updated_at = excluded.updated_at
    where cron_leases.lease_token = p_token
       or cron_leases.leased_until is null
       or cron_leases.leased_until <= clock_timestamp();
  return exists (
    select 1 from argus_private.cron_leases
     where lease_name = 'argus-worker' and lease_token = p_token
       and leased_until > clock_timestamp()
  );
end
$$;

create or replace function argus_private.release_worker_lease(p_token uuid)
returns void
language sql security invoker
set search_path = pg_catalog, argus_private
as $$
  update argus_private.cron_leases
     set lease_token = null, leased_until = null, updated_at = clock_timestamp()
   where lease_name = 'argus-worker' and lease_token = p_token
$$;

create or replace function argus_private.renew_argus_job_lease(
  p_job_run_id uuid,
  p_job_token uuid,
  p_worker_token uuid
)
returns void
language plpgsql security invoker
set search_path = pg_catalog, argus_private
as $$
begin
  update argus_private.cron_leases
     set leased_until = clock_timestamp() + interval '50 seconds',
         updated_at = clock_timestamp()
   where lease_name = 'argus-worker' and lease_token = p_worker_token
     and leased_until > clock_timestamp();
  if not found then raise exception 'worker_lease_lost'; end if;
  update argus_private.job_runs
     set leased_until = clock_timestamp() + interval '45 seconds',
         updated_at = clock_timestamp()
   where id = p_job_run_id and lease_token = p_job_token and status = 'leased'
     and leased_until > clock_timestamp();
  if not found then raise exception 'job_lease_lost'; end if;
end
$$;

create or replace function argus_private.recover_expired_work(p_batch_size integer default 25)
returns integer
language plpgsql security invoker
set search_path = pg_catalog, argus_private, pgmq, extensions
as $$
declare recovered integer := 0;
declare run_record argus_private.job_runs%rowtype;
declare diagnostic text := encode(extensions.digest('lease_expired', 'sha256'), 'hex');
begin
  if p_batch_size < 1 or p_batch_size > 25 then raise exception 'invalid_batch_size'; end if;
  for run_record in
    select * from argus_private.job_runs
     where status in ('leased','running') and leased_until < clock_timestamp()
     order by leased_until, id for update skip locked limit p_batch_size
  loop
    if run_record.attempts >= run_record.max_attempts then
      update argus_private.job_attempts
         set outcome = 'dead_lettered', failure_code = 'lease_expired',
             diagnostic_hash = diagnostic, completed_at = clock_timestamp()
       where job_run_id = run_record.id and attempt_number = run_record.attempts;
      update argus_private.job_runs
         set status = 'dead_lettered', lease_token = null, leased_until = null,
             next_attempt_at = null, updated_at = clock_timestamp(),
             last_error_code = 'lease_expired', diagnostic_hash = diagnostic
       where id = run_record.id;
      insert into argus_private.dead_letter_events(
        outbox_event_id, queue_message_id, handler_name, reason_code, diagnostic_hash
      ) values (
        run_record.source_event_id, run_record.queue_message_id,
        run_record.handler_name, 'lease_expired', diagnostic
      );
      perform pgmq.archive('argus_jobs', run_record.queue_message_id);
    else
      update argus_private.job_attempts
         set outcome = 'retry', failure_code = 'lease_expired',
             diagnostic_hash = diagnostic, completed_at = clock_timestamp()
       where job_run_id = run_record.id and attempt_number = run_record.attempts;
      update argus_private.job_runs
         set status = 'retry', lease_token = null, leased_until = null,
             next_attempt_at = clock_timestamp(), updated_at = clock_timestamp(),
             last_error_code = 'lease_expired', diagnostic_hash = diagnostic
       where id = run_record.id;
      perform pgmq.set_vt('argus_jobs', run_record.queue_message_id, 0);
    end if;
    recovered := recovered + 1;
  end loop;
  return recovered;
end
$$;

revoke all on function argus_private.relay_outbox(integer),
  argus_private.acquire_worker_lease(uuid,integer),
  argus_private.release_worker_lease(uuid),
  argus_private.renew_argus_job_lease(uuid,uuid,uuid),
  argus_private.recover_expired_work(integer)
from public, anon, authenticated, argus_runtime;
grant execute on function argus_private.relay_outbox(integer),
  argus_private.acquire_worker_lease(uuid,integer),
  argus_private.release_worker_lease(uuid),
  argus_private.renew_argus_job_lease(uuid,uuid,uuid),
  argus_private.recover_expired_work(integer)
to argus_worker;

create or replace function argus_private.retained_job_handler(p_event_type text)
returns text
language sql immutable security invoker
set search_path = pg_catalog
as $$
  select case p_event_type
    when 'briefing.daily.requested' then 'briefing-builder'
    when 'briefing.weekly.requested' then 'briefing-builder'
    when 'briefing.moon_cycle.requested' then 'briefing-builder'
    when 'briefing.daily.generated' then 'notification-writer'
    when 'briefing.weekly.generated' then 'notification-writer'
    when 'briefing.moon_cycle.generated' then 'notification-writer'
    when 'media.scan.requested' then 'media-scan'
    when 'media.quarantine.cleanup' then 'media-cleanup'
    when 'content-report.created' then 'moderation-triage'
    when 'privacy.export.requested' then 'privacy-export'
    when 'privacy.deletion.requested' then 'privacy-purge'
    when 'privacy.export.retention.requested' then 'privacy-export-retention'
    else null
  end
$$;

create or replace function argus_private.validate_consumer_receipt()
returns trigger
language plpgsql security definer
set search_path = pg_catalog, argus_private, extensions
as $$
declare event_record argus_private.outbox_events%rowtype;
begin
  select * into event_record from argus_private.outbox_events where id = new.outbox_event_id;
  if event_record.id is null
     or current_setting('argus.worker_event_id', true) is distinct from new.outbox_event_id::text
     or new.handler_name is distinct from argus_private.retained_job_handler(event_record.event_type)
     or new.user_id is distinct from event_record.user_id
     or new.deletion_epoch is distinct from event_record.deletion_epoch then
    raise exception 'invalid_consumer_receipt';
  end if;
  return new;
end
$$;

drop trigger if exists consumer_receipts_validate on argus_private.consumer_receipts;
create trigger consumer_receipts_validate
before insert or update on argus_private.consumer_receipts
for each row execute function argus_private.validate_consumer_receipt();
alter function argus_private.validate_consumer_receipt() owner to postgres;
revoke all on function argus_private.validate_consumer_receipt()
from public, anon, authenticated, argus_runtime, argus_worker;

create or replace function argus_private.consume_worker_invocation(
  p_nonce text,
  p_issued_at_seconds bigint
)
returns boolean
language plpgsql security invoker
set search_path = pg_catalog, argus_private, extensions
as $$
declare issued_at timestamptz;
begin
  delete from argus_private.worker_invocation_nonces
   where consumed_at < clock_timestamp() - interval '10 minutes';
  if p_nonce !~ '^[a-f0-9]{32}$' then return false; end if;
  issued_at := to_timestamp(p_issued_at_seconds);
  if issued_at < clock_timestamp() - interval '60 seconds'
     or issued_at > clock_timestamp() + interval '5 seconds' then
    return false;
  end if;
  insert into argus_private.worker_invocation_nonces(nonce_hash, issued_at)
  values (encode(extensions.digest(p_nonce, 'sha256'), 'hex'), issued_at)
  on conflict do nothing;
  return found;
end
$$;

create or replace function argus_private.dead_letter_queue_message(
  p_message_id bigint,
  p_event_id uuid,
  p_handler_name text,
  p_reason_code text,
  p_diagnostic_hash text
)
returns void
language plpgsql security invoker
set search_path = pg_catalog, argus_private, pgmq
as $$
begin
  if p_reason_code not in (
       'deletion_epoch_changed','dependency_unavailable','event_not_found',
       'handler_not_allowed','internal_failure','invalid_event_payload',
       'invalid_message_version','lease_expired','media_object_invalid','member_deleted',
       'storage_unavailable','worker_killed'
     )
     or p_diagnostic_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'invalid_dead_letter';
  end if;
  insert into argus_private.dead_letter_events(
    outbox_event_id, queue_message_id, handler_name, reason_code, diagnostic_hash
  ) values (p_event_id, p_message_id, p_handler_name, p_reason_code, p_diagnostic_hash);
  -- Poison content is never copied into an archive. The redacted diagnostic
  -- row is the only retained terminal evidence.
  perform pgmq.delete('argus_jobs', p_message_id);
end
$$;

create or replace function argus_private.claim_next_argus_job(p_visibility_seconds integer default 45)
returns table(
  job_run_id uuid,
  lease_token uuid,
  queue_message_id bigint,
  read_count integer,
  event_id uuid,
  event_type text,
  handler_name text,
  aggregate_id uuid,
  user_id uuid,
  deletion_epoch bigint
)
language plpgsql security invoker
set search_path = pg_catalog, argus_private, argus_app, pgmq, extensions
as $$
declare
  queued record;
  event_record argus_private.outbox_events%rowtype;
  parsed_event_id uuid;
  parsed_handler text;
  token uuid;
  run_id uuid;
  diagnostic text;
begin
  if p_visibility_seconds < 15 or p_visibility_seconds > 55 then
    raise exception 'invalid_visibility_timeout';
  end if;
  for queued in select * from pgmq.read('argus_jobs', p_visibility_seconds, 1)
  loop
    diagnostic := encode(extensions.digest(queued.message::text, 'sha256'), 'hex');
    if jsonb_typeof(queued.message) <> 'object'
       or (select count(*) from jsonb_object_keys(queued.message)) <> 2
       or not (queued.message ? 'version' and queued.message ? 'event_id')
       or queued.message ->> 'version' <> '1'
       or queued.message ->> 'event_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
      perform argus_private.dead_letter_queue_message(
        queued.msg_id, null, null, 'invalid_event_payload', diagnostic
      );
      continue;
    end if;

    parsed_event_id := (queued.message ->> 'event_id')::uuid;
    select * into event_record from argus_private.outbox_events event
     where event.id = parsed_event_id and event.topic = 'argus_jobs';
    parsed_handler := argus_private.retained_job_handler(event_record.event_type);
    if event_record.id is null or parsed_handler is null then
      perform argus_private.dead_letter_queue_message(
        queued.msg_id, event_record.id, parsed_handler,
        case when event_record.id is null then 'event_not_found' else 'handler_not_allowed' end,
        diagnostic
      );
      continue;
    end if;

    if exists (
      select 1 from argus_private.consumer_receipts receipt
       where receipt.outbox_event_id = event_record.id
         and receipt.handler_name = parsed_handler
    ) then
      perform pgmq.archive('argus_jobs', queued.msg_id);
      continue;
    end if;

    if event_record.user_id is not null and not argus_private.assert_worker_event_current(event_record.id) then
      perform pgmq.archive('argus_jobs', queued.msg_id);
      continue;
    end if;

    token := gen_random_uuid();
    insert into argus_private.job_runs(
      user_id, deletion_epoch, job_type, source_event_id, status, attempts,
      lease_token, leased_until, queue_message_id, handler_name
    ) values (
      event_record.user_id, event_record.deletion_epoch, parsed_handler,
      event_record.id, 'leased', queued.read_ct, token,
      clock_timestamp() + make_interval(secs => p_visibility_seconds),
      queued.msg_id, parsed_handler
    )
    on conflict (source_event_id) where source_event_id is not null do update
      set status = 'leased', attempts = excluded.attempts,
          lease_token = excluded.lease_token, leased_until = excluded.leased_until,
          queue_message_id = excluded.queue_message_id,
          handler_name = excluded.handler_name, updated_at = clock_timestamp()
      where job_runs.status in ('queued','leased','retry')
        and (job_runs.leased_until is null or job_runs.leased_until <= clock_timestamp())
    returning id into run_id;
    if run_id is null then
      if exists (
        select 1 from argus_private.job_runs existing
         where existing.source_event_id = event_record.id
           and existing.status in ('succeeded','dead_lettered','cancelled')
      ) then
        perform pgmq.archive('argus_jobs', queued.msg_id);
      else
        perform pgmq.set_vt('argus_jobs', queued.msg_id, 10);
      end if;
      continue;
    end if;

    insert into argus_private.job_attempts(
      job_run_id, attempt_number, outcome
    ) values (run_id, queued.read_ct, 'started')
    on conflict (job_run_id, attempt_number) do update
      set outcome = 'started', failure_code = null, diagnostic_hash = null,
          started_at = clock_timestamp(), completed_at = null;

    return query select run_id, token, queued.msg_id, queued.read_ct,
      event_record.id, event_record.event_type, parsed_handler,
      event_record.aggregate_id, event_record.user_id, event_record.deletion_epoch;
    return;
  end loop;
end
$$;

create or replace function argus_private.complete_argus_job(
  p_job_run_id uuid,
  p_lease_token uuid,
  p_effect_hash text
)
returns void
language plpgsql security definer
set search_path = pg_catalog, argus_private, pgmq
as $$
declare run_record argus_private.job_runs%rowtype;
begin
  if p_effect_hash !~ '^[a-f0-9]{64}$' then raise exception 'invalid_effect_hash'; end if;
  select * into run_record from argus_private.job_runs
   where id = p_job_run_id and lease_token = p_lease_token and status = 'leased'
   for update;
  if run_record.id is null then raise exception 'job_lease_lost'; end if;
  if not argus_private.assert_worker_event_current(run_record.source_event_id) then
    raise exception 'deletion_epoch_changed';
  end if;
  insert into argus_private.consumer_receipts(
    outbox_event_id, handler_name, user_id, deletion_epoch, effect_hash
  ) values (
    run_record.source_event_id, run_record.handler_name,
    run_record.user_id, run_record.deletion_epoch, p_effect_hash
  ) on conflict (outbox_event_id, handler_name) do nothing;
  update argus_private.job_attempts
     set outcome = 'succeeded', completed_at = clock_timestamp()
   where job_run_id = run_record.id and attempt_number = run_record.attempts;
  update argus_private.job_runs
     set status = 'succeeded', lease_token = null, leased_until = null,
         last_error_code = null, diagnostic_hash = null, updated_at = clock_timestamp()
   where id = run_record.id;
  perform pgmq.archive('argus_jobs', run_record.queue_message_id);
end
$$;

create or replace function argus_private.fail_argus_job(
  p_job_run_id uuid,
  p_lease_token uuid,
  p_failure_code text,
  p_diagnostic_hash text
)
returns text
language plpgsql security invoker
set search_path = pg_catalog, argus_private, pgmq
as $$
declare run_record argus_private.job_runs%rowtype;
declare delay_seconds integer;
begin
  if p_failure_code not in (
       'deletion_epoch_changed','dependency_unavailable','event_not_found',
       'handler_not_allowed','internal_failure','invalid_event_payload',
       'invalid_message_version','lease_expired','media_object_invalid','member_deleted',
       'storage_unavailable','worker_killed'
     )
     or p_diagnostic_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'invalid_failure_record';
  end if;
  select * into run_record from argus_private.job_runs
   where id = p_job_run_id and lease_token = p_lease_token and status = 'leased'
   for update;
  if run_record.id is null then raise exception 'job_lease_lost'; end if;
  if run_record.attempts >= run_record.max_attempts then
    update argus_private.job_attempts
       set outcome = 'dead_lettered', failure_code = p_failure_code,
           diagnostic_hash = p_diagnostic_hash, completed_at = clock_timestamp()
     where job_run_id = run_record.id and attempt_number = run_record.attempts;
    update argus_private.job_runs
       set status = 'dead_lettered', lease_token = null, leased_until = null,
           last_error_code = p_failure_code, diagnostic_hash = p_diagnostic_hash,
           updated_at = clock_timestamp()
     where id = run_record.id;
    perform argus_private.dead_letter_queue_message(
      run_record.queue_message_id, run_record.source_event_id,
      run_record.handler_name, p_failure_code, p_diagnostic_hash
    );
    return 'dead_lettered';
  end if;
  delay_seconds := least(300, 10 * (2 ^ greatest(0, run_record.attempts - 1))::integer);
  update argus_private.job_attempts
     set outcome = 'retry', failure_code = p_failure_code,
         diagnostic_hash = p_diagnostic_hash, completed_at = clock_timestamp()
   where job_run_id = run_record.id and attempt_number = run_record.attempts;
  update argus_private.job_runs
     set status = 'retry', lease_token = null, leased_until = null,
         next_attempt_at = clock_timestamp() + make_interval(secs => delay_seconds),
         last_error_code = p_failure_code, diagnostic_hash = p_diagnostic_hash,
         updated_at = clock_timestamp()
   where id = run_record.id;
  perform pgmq.set_vt('argus_jobs', run_record.queue_message_id, delay_seconds);
  return 'retry';
end
$$;

revoke all on function argus_private.retained_job_handler(text),
  argus_private.consume_worker_invocation(text,bigint),
  argus_private.dead_letter_queue_message(bigint,uuid,text,text,text),
  argus_private.claim_next_argus_job(integer),
  argus_private.complete_argus_job(uuid,uuid,text),
  argus_private.fail_argus_job(uuid,uuid,text,text)
from public, anon, authenticated, argus_runtime;
grant execute on function argus_private.retained_job_handler(text),
  argus_private.consume_worker_invocation(text,bigint),
  argus_private.dead_letter_queue_message(bigint,uuid,text,text,text),
  argus_private.claim_next_argus_job(integer),
  argus_private.complete_argus_job(uuid,uuid,text),
  argus_private.fail_argus_job(uuid,uuid,text,text)
to argus_worker;
alter function argus_private.complete_argus_job(uuid,uuid,text) owner to postgres;

create or replace function argus_private.begin_member_deletion(
  p_receipt_hash text,
  p_session_id uuid,
  p_dedupe_key text
)
returns uuid
language plpgsql security definer
set search_path = pg_catalog, argus_private, argus_app
as $$
declare
  member_record argus_app.members%rowtype;
  request_id uuid;
  tombstone_id uuid;
  consumed_receipt_id uuid;
  next_epoch bigint;
  existing_owner_id uuid;
begin
  if p_receipt_hash !~ '^[a-f0-9]{64}$' or p_dedupe_key !~ '^[!-~]{16,128}$' then
    raise exception 'invalid_deletion_request';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('privacy.deletion.requested:' || p_dedupe_key, 0)
  );
  select request.id, tombstone.user_id into request_id, existing_owner_id
    from argus_private.outbox_events event
    join argus_private.deletion_tombstones tombstone on tombstone.id = event.aggregate_id
    join argus_app.privacy_requests request
      on request.user_id = tombstone.user_id
     and request.deletion_epoch = tombstone.deletion_epoch
     and request.request_type = 'deletion'
   where event.topic = 'argus_jobs'
     and event.event_type = 'privacy.deletion.requested'
     and event.dedupe_key = p_dedupe_key;
  if existing_owner_id is not null
     and existing_owner_id is distinct from argus_private.request_user_id() then
    raise exception 'step_up_required' using errcode = '42501';
  end if;
  if request_id is not null then return request_id; end if;
  select * into member_record from argus_app.members member
   where member.user_id = argus_private.request_user_id()
     and member.status = 'active' for update;
  if member_record.user_id is null then
    select request.id into request_id
      from argus_private.outbox_events event
      join argus_private.deletion_tombstones tombstone on tombstone.id = event.aggregate_id
      join argus_app.privacy_requests request
        on request.user_id = tombstone.user_id
       and request.deletion_epoch = tombstone.deletion_epoch
       and request.request_type = 'deletion'
     where event.topic = 'argus_jobs'
       and event.event_type = 'privacy.deletion.requested'
       and event.dedupe_key = p_dedupe_key
       and tombstone.user_id = argus_private.request_user_id();
    if request_id is not null then return request_id; end if;
    raise exception 'member_not_active';
  end if;
  update argus_private.step_up_receipts receipt
     set consumed_at = clock_timestamp()
   where receipt.receipt_hash = p_receipt_hash
     and receipt.user_id = member_record.user_id
     and receipt.session_id = p_session_id
     and receipt.deletion_epoch = member_record.deletion_epoch
     and receipt.action = 'argus_delete'
     and receipt.aal = 'aal2'
     and receipt.consumed_at is null
     and receipt.expires_at > clock_timestamp()
  returning id into consumed_receipt_id;
  if consumed_receipt_id is null then
    raise exception 'step_up_required' using errcode = '42501';
  end if;
  next_epoch := member_record.deletion_epoch + 1;
  update argus_app.members
     set status = 'deletion_pending', deletion_epoch = next_epoch,
         deletion_requested_at = clock_timestamp()
   where user_id = member_record.user_id;
  insert into argus_app.privacy_requests(
    user_id, deletion_epoch, request_type, status
  ) values (member_record.user_id, next_epoch, 'deletion', 'queued')
  returning id into request_id;
  insert into argus_private.deletion_tombstones(
    user_id, deletion_epoch, status
  ) values (member_record.user_id, next_epoch, 'pending')
  returning id into tombstone_id;
  insert into argus_private.outbox_events(
    user_id, deletion_epoch, topic, event_type, aggregate_id, dedupe_key
  ) values (
    null, null, 'argus_jobs', 'privacy.deletion.requested', tombstone_id,
    p_dedupe_key
  );
  return request_id;
end
$$;

create or replace function argus_private.prepare_member_purge(p_tombstone_id uuid)
returns table(user_id uuid, deletion_epoch bigint, purge_phase text)
language plpgsql security definer
set search_path = pg_catalog, argus_private, argus_app
as $$
declare tombstone argus_private.deletion_tombstones%rowtype;
begin
  select * into tombstone from argus_private.deletion_tombstones
   where id = p_tombstone_id and status in ('pending','purging','failed','purged') for update;
  if tombstone.id is null then raise exception 'tombstone_missing'; end if;
  if tombstone.purge_phase = 'requested' and not exists (
    select 1 from argus_app.members member
     where member.user_id = tombstone.user_id
       and member.deletion_epoch = tombstone.deletion_epoch
       and member.status in ('deletion_pending','purging')
  ) then raise exception 'deletion_epoch_changed'; end if;
  update argus_app.members set status = 'purging'
   where members.user_id = tombstone.user_id;
  update argus_private.deletion_tombstones set status = 'purging'
      , purge_phase = case when purge_phase = 'requested' then 'neutralized' else purge_phase end
   where id = tombstone.id and purge_phase <> 'complete';
  update argus_private.job_runs
     set status = 'cancelled', lease_token = null, leased_until = null,
         last_error_code = 'member_deleted', updated_at = clock_timestamp()
   where job_runs.user_id = tombstone.user_id
     and job_runs.deletion_epoch < tombstone.deletion_epoch
     and status not in ('succeeded','dead_lettered','cancelled');
  delete from argus_private.outbox_events
   where outbox_events.user_id = tombstone.user_id;
  select * into tombstone from argus_private.deletion_tombstones where id = p_tombstone_id;
  return query select tombstone.user_id, tombstone.deletion_epoch, tombstone.purge_phase;
end
$$;

create or replace function argus_private.list_member_purge_objects(p_tombstone_id uuid)
returns table(bucket_id text, object_path text)
language plpgsql security definer
set search_path = pg_catalog, argus_private
as $$
declare tombstone argus_private.deletion_tombstones%rowtype;
begin
  select * into tombstone from argus_private.deletion_tombstones
   where id = p_tombstone_id and purge_phase in ('neutralized','storage_purged');
  if tombstone.id is null then return; end if;
  return query
    select intent.bucket_id,intent.object_path
      from argus_private.media_upload_intents intent
     where intent.user_id = tombstone.user_id
    union all
    select artifact.bucket_id,artifact.object_path
      from argus_private.privacy_export_artifacts artifact
     where artifact.user_id = tombstone.user_id;
end
$$;

create or replace function argus_private.mark_member_storage_purged(
  p_tombstone_id uuid,
  p_object_receipts jsonb
)
returns void
language plpgsql security definer
set search_path = pg_catalog, argus_private, extensions
as $$
declare entry record;
begin
  if exists (
    select 1 from argus_private.deletion_tombstones
     where id = p_tombstone_id and purge_phase in ('storage_purged','data_purged','complete')
  ) then
    return;
  end if;
  if jsonb_typeof(p_object_receipts) <> 'array'
     or jsonb_array_length(p_object_receipts) > 1000 then
    raise exception 'invalid_object_receipts';
  end if;
  for entry in
    select value ->> 'bucket_id' bucket_id, value ->> 'path_hash' path_hash
      from jsonb_array_elements(p_object_receipts)
  loop
    if entry.bucket_id not in ('member-media','media-quarantine','privacy-exports')
       or entry.path_hash !~ '^[a-f0-9]{64}$' then
      raise exception 'invalid_object_receipts';
    end if;
    insert into argus_private.deletion_object_receipts(
      tombstone_id,bucket_id,object_path_hash
    ) values (p_tombstone_id,entry.bucket_id,entry.path_hash)
    on conflict do nothing;
  end loop;
  if exists (
    select 1 from argus_private.deletion_tombstones tombstone
    join argus_private.media_upload_intents intent on intent.user_id=tombstone.user_id
   where tombstone.id=p_tombstone_id
     and not exists (
       select 1 from argus_private.deletion_object_receipts receipt
        where receipt.tombstone_id=tombstone.id
          and receipt.bucket_id=intent.bucket_id
          and receipt.object_path_hash=encode(extensions.digest(intent.object_path,'sha256'),'hex')
     )
    union all
    select 1 from argus_private.deletion_tombstones tombstone
    join argus_private.privacy_export_artifacts artifact on artifact.user_id=tombstone.user_id
   where tombstone.id=p_tombstone_id
     and not exists (
       select 1 from argus_private.deletion_object_receipts receipt
        where receipt.tombstone_id=tombstone.id
          and receipt.bucket_id=artifact.bucket_id
          and receipt.object_path_hash=encode(extensions.digest(artifact.object_path,'sha256'),'hex')
     )
  ) then
    raise exception 'storage_receipt_missing';
  end if;
  update argus_private.deletion_tombstones
     set purge_phase = 'storage_purged'
   where id = p_tombstone_id and purge_phase in ('neutralized','storage_purged');
  if not found then raise exception 'invalid_purge_phase'; end if;
end
$$;

create or replace function argus_private.purge_member_argus_data(p_tombstone_id uuid)
returns integer
language plpgsql security definer
set search_path = pg_catalog, argus_private, argus_app, argus_brokerage
as $$
declare
  tombstone argus_private.deletion_tombstones%rowtype;
  table_record record;
  purged_tables integer := 0;
  affected integer;
begin
  select * into tombstone from argus_private.deletion_tombstones
   where id = p_tombstone_id and status = 'purging'
     and purge_phase in ('storage_purged','data_purged') for update;
  if tombstone.id is null then raise exception 'tombstone_missing'; end if;
  if tombstone.purge_phase = 'storage_purged' then
    delete from argus_app.moderation_cases moderation
     using argus_app.content_reports report
     where moderation.report_id = report.id and report.user_id = tombstone.user_id;
    if found then purged_tables := purged_tables + 1; end if;
    delete from argus_app.media_assets asset
     using argus_private.media_upload_intents intent
     where intent.user_id = tombstone.user_id
       and asset.storage_bucket = intent.bucket_id
       and asset.storage_path = intent.object_path;
    if found then purged_tables := purged_tables + 1; end if;
    for table_record in
      select n.nspname schema_name, c.relname table_name
        from pg_class c join pg_namespace n on n.oid = c.relnamespace
        join pg_attribute a on a.attrelid = c.oid and a.attname = 'user_id' and not a.attisdropped
       where n.nspname in ('argus_app','argus_brokerage')
         and c.relkind = 'r' and c.relname <> 'members'
    loop
      execute format('delete from %I.%I where user_id = $1', table_record.schema_name, table_record.table_name)
        using tombstone.user_id;
      get diagnostics affected = row_count;
      if affected > 0 then purged_tables := purged_tables + 1; end if;
    end loop;
    for table_record in
      select n.nspname schema_name, c.relname table_name
        from pg_class c join pg_namespace n on n.oid = c.relnamespace
        join pg_attribute a on a.attrelid = c.oid and a.attname = 'user_id' and not a.attisdropped
       where n.nspname = 'argus_private'
         and c.relkind = 'r'
         and c.relname not in ('deletion_tombstones','deletion_restore_checkpoints')
    loop
      execute format('delete from %I.%I where user_id = $1', table_record.schema_name, table_record.table_name)
        using tombstone.user_id;
      get diagnostics affected = row_count;
      if affected > 0 then purged_tables := purged_tables + 1; end if;
    end loop;
    delete from argus_private.admin_audit_events where actor_user_id = tombstone.user_id;
    if found then purged_tables := purged_tables + 1; end if;
    update argus_private.deletion_tombstones
       set purge_phase = 'data_purged', purged_tables_count = purged_tables
     where id = tombstone.id;
  end if;
  return purged_tables;
end
$$;

create or replace function argus_private.complete_member_purge(p_tombstone_id uuid)
returns uuid
language plpgsql security definer
set search_path = pg_catalog, argus_private, auth
as $$
declare tombstone argus_private.deletion_tombstones%rowtype;
declare receipt_id uuid;
declare object_count integer;
begin
  select * into tombstone from argus_private.deletion_tombstones
   where id = p_tombstone_id and purge_phase in ('data_purged','complete') for update;
  if tombstone.id is null then raise exception 'tombstone_missing'; end if;
  if tombstone.purge_phase = 'complete' then
    return (select id from argus_private.purge_receipts where tombstone_id=tombstone.id);
  end if;
  if exists (select 1 from auth.users where id = tombstone.user_id) then
    raise exception 'auth_identity_still_present';
  end if;
  select count(*) into object_count from argus_private.deletion_object_receipts
   where tombstone_id = tombstone.id;
  update argus_private.deletion_tombstones
     set status = 'purged', purge_phase = 'complete',
         auth_deleted_at = clock_timestamp(), completed_at = clock_timestamp()
   where id = tombstone.id;
  insert into argus_private.purge_receipts(
    tombstone_id, purged_tables, purged_objects
  ) values (tombstone.id, tombstone.purged_tables_count, object_count)
  on conflict (tombstone_id) do update
    set purged_tables = excluded.purged_tables,
        purged_objects = excluded.purged_objects,
        completed_at = clock_timestamp()
  returning id into receipt_id;
  return receipt_id;
end
$$;

revoke all on function argus_private.begin_member_deletion(text,uuid,text)
from public, anon, authenticated, argus_worker;
grant execute on function argus_private.begin_member_deletion(text,uuid,text) to argus_runtime;
alter function argus_private.begin_member_deletion(text,uuid,text) owner to postgres;
revoke all on function argus_private.prepare_member_purge(uuid),
  argus_private.list_member_purge_objects(uuid),
  argus_private.mark_member_storage_purged(uuid,jsonb),
  argus_private.purge_member_argus_data(uuid),
  argus_private.complete_member_purge(uuid)
from public, anon, authenticated, argus_runtime;
grant execute on function argus_private.prepare_member_purge(uuid),
  argus_private.list_member_purge_objects(uuid),
  argus_private.mark_member_storage_purged(uuid,jsonb),
  argus_private.purge_member_argus_data(uuid),
  argus_private.complete_member_purge(uuid)
to argus_worker;
alter function argus_private.prepare_member_purge(uuid) owner to postgres;
alter function argus_private.list_member_purge_objects(uuid) owner to postgres;
alter function argus_private.mark_member_storage_purged(uuid,jsonb) owner to postgres;
alter function argus_private.purge_member_argus_data(uuid) owner to postgres;
alter function argus_private.complete_member_purge(uuid) owner to postgres;

-- Cron creates only deterministic, retained Argus work. It never carries a
-- financial operation and each dedupe key makes repeated ticks harmless.
create or replace function argus_private.enqueue_due_retained_jobs(
  p_batch_size integer default 25
)
returns integer
language plpgsql security definer
set search_path = pg_catalog, argus_private, argus_app
as $$
declare enqueued integer := 0;
begin
  if p_batch_size < 1 or p_batch_size > 25 then raise exception 'invalid_batch_size'; end if;
  if exists (
    select 1 from argus_private.kill_switches
     where name = 'background_workers' and enabled
  ) then return 0; end if;

  insert into argus_app.briefings(
    user_id,deletion_epoch,briefing_type,period_start,period_end,status
  )
  select candidate.user_id,candidate.deletion_epoch,candidate.briefing_type,
         candidate.period_start,candidate.period_end,'queued'
    from (
      select member.user_id,member.deletion_epoch,'daily'::text briefing_type,
             current_date period_start,current_date period_end
        from argus_app.members member
        join argus_app.notification_preferences preference using (user_id)
       where member.status = 'active' and preference.daily_ritual
      union all
      select member.user_id,member.deletion_epoch,'weekly',
             date_trunc('week',current_date)::date,
             (date_trunc('week',current_date)::date + 6)
        from argus_app.members member
        join argus_app.notification_preferences preference using (user_id)
       where member.status = 'active' and preference.weekly_recap
         and extract(isodow from current_date) = 1
      union all
      select member.user_id,member.deletion_epoch,'moon_cycle',
             case when extract(day from current_date) = 1
               then date_trunc('month',current_date)::date
               else date_trunc('month',current_date)::date + 14 end,
             case when extract(day from current_date) = 1
               then date_trunc('month',current_date)::date + 13
               else (date_trunc('month',current_date) + interval '1 month - 1 day')::date end
        from argus_app.members member
        join argus_app.notification_preferences preference using (user_id)
       where member.status = 'active' and preference.moon_cycle
         and extract(day from current_date) in (1,15)
    ) candidate
   where not exists (
     select 1 from argus_app.briefings existing
      where existing.user_id = candidate.user_id
        and existing.briefing_type = candidate.briefing_type
        and existing.period_start = candidate.period_start
        and existing.period_end = candidate.period_end
   )
   order by candidate.user_id,candidate.briefing_type
   limit p_batch_size
  on conflict (user_id,briefing_type,period_start,period_end) do nothing;

  update argus_private.media_upload_intents
     set status = 'expired'
   where status in ('pending','uploaded','rejected') and expires_at <= clock_timestamp();

  with due as (
    select briefing.user_id,briefing.deletion_epoch,
           ('briefing.' || briefing.briefing_type || '.requested')::text event_type,
           briefing.id aggregate_id,
           ('briefing:' || briefing.id::text) dedupe_key
      from argus_app.briefings briefing
     where briefing.status = 'queued'
    union all
    select artifact.user_id,artifact.deletion_epoch,'privacy.export.retention.requested',
           artifact.id,('privacy-export-retention:' || artifact.id::text)
      from argus_private.privacy_export_artifacts artifact
     where artifact.expires_at <= clock_timestamp() and artifact.revoked_at is null
    union all
    select intent.user_id,intent.deletion_epoch,'media.quarantine.cleanup',
           intent.id,('media-cleanup:' || intent.id::text)
      from argus_private.media_upload_intents intent
     where intent.bucket_id = 'media-quarantine' and intent.status = 'expired'
  ), bounded as (
    select * from due order by dedupe_key limit p_batch_size
  )
  insert into argus_private.outbox_events(
    user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
  )
  select user_id,deletion_epoch,'argus_jobs',event_type,aggregate_id,dedupe_key
    from bounded
  on conflict (topic,dedupe_key) do nothing;
  get diagnostics enqueued = row_count;
  return enqueued;
end
$$;

alter function argus_private.enqueue_due_retained_jobs(integer) owner to postgres;
revoke all on function argus_private.enqueue_due_retained_jobs(integer)
from public, anon, authenticated, argus_runtime, argus_worker;

-- Vault access is isolated to these owner-executed functions. No caller can
-- retrieve a credential, and cron.job stores only the function invocation.
create or replace function argus_private.resolve_worker_invocation_config()
returns table(worker_url text, current_secret text, next_secret text, next_valid_until timestamptz)
language plpgsql security definer
set search_path = pg_catalog, vault
as $$
begin
  select
    max(decrypted_secret) filter (where name = 'argus_worker_url'),
    max(decrypted_secret) filter (where name = 'argus_worker_secret_current'),
    max(decrypted_secret) filter (where name = 'argus_worker_secret_next'),
    (max(decrypted_secret) filter (where name = 'argus_worker_secret_next_valid_until'))::timestamptz
  into worker_url, current_secret, next_secret, next_valid_until
  from vault.decrypted_secrets
  where name in (
    'argus_worker_url', 'argus_worker_secret_current',
    'argus_worker_secret_next', 'argus_worker_secret_next_valid_until'
  );
  if worker_url is null or worker_url !~ '^https://[^[:space:]]+$'
     or current_secret is null or length(current_secret) < 32 then
    raise exception 'worker_invocation_configuration_missing';
  end if;
  if next_secret is not null and (
    length(next_secret) < 32 or next_valid_until is null
    or next_valid_until <= clock_timestamp()
    or next_valid_until > clock_timestamp() + interval '10 minutes'
  ) then
    raise exception 'worker_rotation_configuration_invalid';
  end if;
  return next;
end
$$;

create or replace function argus_private.invoke_worker()
returns bigint
language plpgsql security definer
set search_path = pg_catalog, argus_private, net, extensions
as $$
declare
  config record;
  request_id bigint;
  issued_at_seconds bigint;
  nonce text;
  proof text;
begin
  if exists (
    select 1 from argus_private.kill_switches
     where name = 'background_workers' and enabled
  ) then
    return null;
  end if;
  select * into config from argus_private.resolve_worker_invocation_config();
  issued_at_seconds := extract(epoch from clock_timestamp())::bigint;
  nonce := encode(extensions.gen_random_bytes(16), 'hex');
  proof := encode(extensions.hmac(
    issued_at_seconds::text || '.' || nonce,
    config.current_secret,
    'sha256'
  ), 'hex');
  select net.http_post(
    url := config.worker_url,
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-argus-worker-timestamp', issued_at_seconds::text,
      'x-argus-worker-nonce', nonce,
      'x-argus-worker-proof', proof
    ),
    body := jsonb_build_object('batch_size', 25),
    timeout_milliseconds := 10000
  ) into request_id;
  return request_id;
end
$$;

alter function argus_private.resolve_worker_invocation_config() owner to postgres;
alter function argus_private.invoke_worker() owner to postgres;

revoke all on function argus_private.resolve_worker_invocation_config(),
  argus_private.invoke_worker()
from public, anon, authenticated, argus_runtime, argus_worker;
revoke all on schema net, vault from public, anon, authenticated, argus_runtime, argus_worker;

select cron.unschedule(jobid)
  from cron.job
 where jobname in (
   'argus-outbox-relay', 'argus-recovery-sweep', 'argus-worker-dispatch',
   'argus-retained-enqueue'
 );
select cron.schedule(
  'argus-retained-enqueue',
  '*/15 * * * *',
  'select argus_private.enqueue_due_retained_jobs(25);'
);
select cron.schedule(
  'argus-worker-dispatch',
  '* * * * *',
  'select argus_private.invoke_worker();'
);

-- Privacy exports are delivered only by a short-lived signed URL minted by a
-- server-side Storage adapter. There is no direct authenticated read policy.
drop policy if exists argus_privacy_exports_select on storage.objects;

comment on table argus_private.dead_letter_events is
  'Redacted terminal outcomes only; queue bodies and source values are never copied here.';
comment on function argus_private.resolve_worker_invocation_config() is
  'Vault-only worker invocation configuration. EXECUTE remains owner-only.';

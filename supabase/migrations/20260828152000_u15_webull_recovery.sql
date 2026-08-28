-- U15: bounded Webull credential/read/reconciliation recovery.
--
-- Every queue message remains {version,event_id}. Provider recovery functions
-- can inspect existing state only; none can create or execute a command.

begin;

delete from argus_private.outbox_events
 where topic in ('brokerage_refresh','brokerage_reconcile');

alter table argus_private.outbox_events
  drop constraint if exists outbox_events_retained_event_type_check;
alter table argus_private.outbox_events
  add constraint outbox_events_retained_event_type_check check (
    (topic = 'argus_jobs' and event_type in (
      'briefing.daily.requested','briefing.weekly.requested',
      'briefing.moon_cycle.requested','briefing.daily.generated',
      'briefing.weekly.generated','briefing.moon_cycle.generated',
      'media.scan.requested','media.quarantine.cleanup',
      'content-report.created','privacy.export.requested',
      'privacy.deletion.requested','privacy.export.retention.requested'
    )) or
    (topic = 'brokerage_refresh' and event_type in (
      'webull.token.refresh.requested',
      'webull.projection.refresh.requested'
    )) or
    (topic = 'brokerage_reconcile' and
      event_type = 'webull.command.reconciliation.requested')
  );

alter table argus_brokerage.connections
  add column egress_fenced_at timestamptz;

alter table argus_private.refresh_leases
  add column event_id uuid references argus_private.outbox_events(id) on delete cascade,
  add column key_version integer check (key_version is null or key_version > 0),
  add column credential_aad_hash text
    check (credential_aad_hash is null or credential_aad_hash ~ '^[a-f0-9]{64}$'),
  add column egress_started_at timestamptz;

alter table argus_private.projection_refresh_leases
  add column id uuid not null default gen_random_uuid();
alter table argus_private.projection_refresh_leases
  add constraint projection_refresh_leases_id_unique unique (id);

alter table argus_private.deletion_tombstones
  add column webull_fenced_at timestamptz,
  add column webull_credentials_destroyed_at timestamptz;

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
    when 'webull.token.refresh.requested' then 'webull-token-refresh'
    when 'webull.projection.refresh.requested' then 'webull-projection-refresh'
    when 'webull.command.reconciliation.requested' then 'webull-reconciliation'
    else null
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
declare event_record argus_private.outbox_events%rowtype;
begin
  select event.* into event_record
    from argus_private.outbox_events event
    join argus_private.job_runs run on run.source_event_id = event.id
   where event.id = p_event_id
     and argus_private.retained_job_handler(event.event_type) = run.handler_name
     and run.id = p_job_run_id and run.lease_token = p_lease_token
     and run.status = 'leased' and run.leased_until > clock_timestamp();
  if event_record.id is null then raise exception 'event_not_found'; end if;
  if event_record.user_id is not null
     and not argus_private.assert_worker_event_current(p_event_id) then
    raise exception 'deletion_epoch_changed';
  end if;
  perform set_config('argus.worker_event_id', p_event_id::text, true);
  perform set_config('argus.worker_user_id', coalesce(event_record.user_id::text, ''), true);
  perform set_config('argus.worker_deletion_epoch', coalesce(event_record.deletion_epoch::text, ''), true);
  return query select event_record.event_type, event_record.aggregate_id,
    event_record.user_id, event_record.deletion_epoch;
end
$$;

create or replace function argus_private.relay_outbox(p_batch_size integer default 25)
returns integer
language plpgsql security definer
set search_path = pg_catalog, argus_private, pgmq
as $$
declare event_record argus_private.outbox_events%rowtype;
declare sent integer := 0;
begin
  if p_batch_size < 1 or p_batch_size > 25 then raise exception 'invalid_batch_size'; end if;
  if exists (select 1 from argus_private.kill_switches where name='background_workers' and enabled) then
    return 0;
  end if;
  for event_record in
    select * from argus_private.outbox_events event
     where event.published_at is null and event.available_at <= clock_timestamp()
       and argus_private.retained_job_handler(event.event_type) is not null
       and (event.topic='argus_jobs' or not exists (
         select 1 from argus_private.kill_switches
          where name='provider_egress' and enabled
       ))
     order by event.available_at,event.id for update skip locked limit p_batch_size
  loop
    perform pgmq.send('argus_jobs',jsonb_build_object('version',1,'event_id',event_record.id));
    update argus_private.outbox_events
       set published_at=clock_timestamp(),publish_attempts=publish_attempts+1,last_error_code=null
     where id=event_record.id;
    sent := sent+1;
  end loop;
  return sent;
end
$$;

-- The physical queue is shared. Topic/type correctness is enforced by the
-- outbox constraint above before a handler can be selected here.
create or replace function argus_private.claim_next_argus_job(p_visibility_seconds integer default 45)
returns table(
  job_run_id uuid,lease_token uuid,queue_message_id bigint,read_count integer,
  event_id uuid,event_type text,handler_name text,aggregate_id uuid,
  user_id uuid,deletion_epoch bigint
)
language plpgsql security invoker
set search_path = pg_catalog,argus_private,argus_app,pgmq,extensions
as $$
declare queued record;
declare event_record argus_private.outbox_events%rowtype;
declare parsed_event_id uuid;
declare parsed_handler text;
declare token uuid;
declare run_id uuid;
declare diagnostic text;
begin
  if p_visibility_seconds < 15 or p_visibility_seconds > 55 then
    raise exception 'invalid_visibility_timeout';
  end if;
  for queued in select * from pgmq.read('argus_jobs',p_visibility_seconds,1)
  loop
    diagnostic := encode(extensions.digest(queued.message::text,'sha256'),'hex');
    if jsonb_typeof(queued.message)<>'object'
       or (select count(*) from jsonb_object_keys(queued.message))<>2
       or not (queued.message?'version' and queued.message?'event_id')
       or queued.message->>'version'<>'1'
       or queued.message->>'event_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
      perform argus_private.dead_letter_queue_message(
        queued.msg_id,null,null,'invalid_event_payload',diagnostic
      );
      continue;
    end if;
    parsed_event_id := (queued.message->>'event_id')::uuid;
    select * into event_record from argus_private.outbox_events event
     where event.id=parsed_event_id;
    parsed_handler := argus_private.retained_job_handler(event_record.event_type);
    if event_record.id is null or parsed_handler is null then
      perform argus_private.dead_letter_queue_message(
        queued.msg_id,event_record.id,parsed_handler,
        case when event_record.id is null then 'event_not_found' else 'handler_not_allowed' end,
        diagnostic
      );
      continue;
    end if;
    if exists (
      select 1 from argus_private.consumer_receipts receipt
       where receipt.outbox_event_id=event_record.id and receipt.handler_name=parsed_handler
    ) then
      perform pgmq.archive('argus_jobs',queued.msg_id);
      continue;
    end if;
    if event_record.user_id is not null
       and not argus_private.assert_worker_event_current(event_record.id) then
      perform pgmq.archive('argus_jobs',queued.msg_id);
      continue;
    end if;
    token := gen_random_uuid();
    insert into argus_private.job_runs(
      user_id,deletion_epoch,job_type,source_event_id,status,attempts,
      lease_token,leased_until,queue_message_id,handler_name
    ) values (
      event_record.user_id,event_record.deletion_epoch,parsed_handler,event_record.id,
      'leased',queued.read_ct,token,
      clock_timestamp()+make_interval(secs=>p_visibility_seconds),
      queued.msg_id,parsed_handler
    ) on conflict (source_event_id) where source_event_id is not null do update
      set status='leased',attempts=excluded.attempts,lease_token=excluded.lease_token,
          leased_until=excluded.leased_until,queue_message_id=excluded.queue_message_id,
          handler_name=excluded.handler_name,updated_at=clock_timestamp()
      where job_runs.status in ('queued','leased','retry')
        and (job_runs.leased_until is null or job_runs.leased_until<=clock_timestamp())
    returning id into run_id;
    if run_id is null then
      if exists (
        select 1 from argus_private.job_runs existing
         where existing.source_event_id=event_record.id
           and existing.status in ('succeeded','dead_lettered','cancelled')
      ) then perform pgmq.archive('argus_jobs',queued.msg_id);
      else perform pgmq.set_vt('argus_jobs',queued.msg_id,10);
      end if;
      continue;
    end if;
    insert into argus_private.job_attempts(job_run_id,attempt_number,outcome)
    values (run_id,queued.read_ct,'started')
    on conflict (job_run_id,attempt_number) do update
      set outcome='started',failure_code=null,diagnostic_hash=null,
          started_at=clock_timestamp(),completed_at=null;
    return query select run_id,token,queued.msg_id,queued.read_ct,event_record.id,
      event_record.event_type,parsed_handler,event_record.aggregate_id,
      event_record.user_id,event_record.deletion_epoch;
    return;
  end loop;
end
$$;

create or replace function argus_private.claim_webull_token_refresh(
  p_event_id uuid,p_lease_token uuid,p_lease_seconds integer
)
returns table(
  claim_outcome text,user_id uuid,deletion_epoch bigint,connection_id uuid,
  provider_environment text,token_version bigint,key_version integer,
  access_ciphertext bytea,access_nonce bytea,access_tag bytea,
  refresh_ciphertext bytea,refresh_nonce bytea,refresh_tag bytea,
  wrapped_data_key bytea,wrapped_key_nonce bytea,wrapped_key_tag bytea,
  associated_data_hash text,access_expires_at timestamptz,
  refresh_expires_at timestamptz
)
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare event_record argus_private.outbox_events%rowtype;
declare credential argus_private.webull_credentials%rowtype;
declare prior argus_private.refresh_leases%rowtype;
begin
  if p_lease_seconds<15 or p_lease_seconds>55 then raise exception 'invalid_lease_duration'; end if;
  select event.* into event_record from argus_private.outbox_events event
   where event.id=p_event_id and event.topic='brokerage_refresh'
     and event.event_type='webull.token.refresh.requested'
     and event.aggregate_id in (
       select connection.id from argus_brokerage.connections connection
        where connection.user_id=event.user_id
          and connection.deletion_epoch=event.deletion_epoch
     ) and exists (
       select 1 from argus_private.job_runs run
        where run.source_event_id=event.id and run.handler_name='webull-token-refresh'
          and run.status='leased' and run.leased_until>clock_timestamp()
     );
  if event_record.id is null or not argus_private.assert_worker_event_current(p_event_id) then return; end if;
  if exists (select 1 from argus_private.kill_switches where name='provider_egress' and enabled) then
    raise exception 'worker_killed';
  end if;
  select * into credential from argus_private.webull_credentials current_credential
   where current_credential.connection_id=event_record.aggregate_id
     and current_credential.user_id=event_record.user_id
     and current_credential.deletion_epoch=event_record.deletion_epoch
     and exists (
       select 1 from argus_brokerage.connections connection
        where connection.id=current_credential.connection_id
          and connection.user_id=current_credential.user_id
          and connection.deletion_epoch=current_credential.deletion_epoch
          and connection.status='connected' and connection.egress_fenced_at is null
     ) for update;
  if credential.connection_id is null then return; end if;
  select * into prior from argus_private.refresh_leases lease
   where lease.connection_id=credential.connection_id for update;
  if prior.connection_id is not null and prior.token_version<>credential.token_version then
    delete from argus_private.refresh_leases where connection_id=prior.connection_id;
    prior.connection_id:=null;
  end if;
  if prior.connection_id is not null and prior.egress_started_at is not null then
    update argus_brokerage.connections set status='reauthorization_required',
      last_error_code='refresh_outcome_unknown',updated_at=clock_timestamp()
     where id=credential.connection_id and user_id=credential.user_id
       and deletion_epoch=credential.deletion_epoch and status='connected';
    delete from argus_brokerage.active_account_selections
     where user_id=credential.user_id and connection_id=credential.connection_id;
    delete from argus_private.webull_credentials
     where connection_id=credential.connection_id and token_version=credential.token_version;
    delete from argus_private.refresh_leases where connection_id=credential.connection_id;
    return query select 'reauthorization_required'::text,credential.user_id,
      credential.deletion_epoch,credential.connection_id,credential.provider_environment,
      credential.token_version,credential.key_version,null::bytea,null::bytea,null::bytea,
      null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,
      credential.associated_data_hash,credential.access_expires_at,credential.refresh_expires_at;
    return;
  end if;
  if prior.connection_id is not null and prior.leased_until>clock_timestamp() then return; end if;
  delete from argus_private.refresh_leases where connection_id=credential.connection_id;
  insert into argus_private.refresh_leases(
    connection_id,user_id,deletion_epoch,lease_token,token_version,leased_until,
    event_id,key_version,credential_aad_hash,egress_started_at
  ) values (
    credential.connection_id,credential.user_id,credential.deletion_epoch,
    p_lease_token,credential.token_version,
    clock_timestamp()+make_interval(secs=>p_lease_seconds),p_event_id,
    credential.key_version,credential.associated_data_hash,null
  );
  return query select 'claimed'::text,credential.user_id,credential.deletion_epoch,
    credential.connection_id,credential.provider_environment,credential.token_version,
    credential.key_version,credential.access_ciphertext,credential.access_nonce,
    credential.access_tag,credential.refresh_ciphertext,credential.refresh_nonce,
    credential.refresh_tag,credential.wrapped_data_key,credential.wrapped_key_nonce,
    credential.wrapped_key_tag,credential.associated_data_hash,
    credential.access_expires_at,credential.refresh_expires_at;
end
$$;

create or replace function argus_private.mark_webull_refresh_egress_started(
  p_event_id uuid,p_connection_id uuid,p_token_version bigint,
  p_key_version integer,p_lease_token uuid
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
begin
  if exists (
    select 1 from argus_private.kill_switches
     where name='provider_egress' and enabled
  ) then raise exception 'worker_killed'; end if;
  update argus_private.refresh_leases lease set egress_started_at=clock_timestamp()
   where lease.connection_id=p_connection_id and lease.event_id=p_event_id
     and lease.lease_token=p_lease_token and lease.token_version=p_token_version
     and lease.key_version=p_key_version and lease.egress_started_at is null
     and lease.leased_until>clock_timestamp()
     and exists (
       select 1 from argus_private.outbox_events event
       join argus_private.job_runs run on run.source_event_id=event.id
        and run.handler_name='webull-token-refresh' and run.status='leased'
        and run.leased_until>clock_timestamp()
       join argus_app.members member on member.user_id=event.user_id
        and member.deletion_epoch=event.deletion_epoch and member.status='active'
       join argus_brokerage.connections connection on connection.id=event.aggregate_id
        and connection.user_id=event.user_id and connection.deletion_epoch=event.deletion_epoch
        and connection.status='connected' and connection.egress_fenced_at is null
       join argus_private.webull_credentials credential on credential.connection_id=connection.id
        and credential.user_id=connection.user_id and credential.deletion_epoch=connection.deletion_epoch
      where event.id=p_event_id and event.topic='brokerage_refresh'
        and event.event_type='webull.token.refresh.requested'
        and event.aggregate_id=p_connection_id
        and credential.token_version=p_token_version and credential.key_version=p_key_version
        and credential.associated_data_hash=lease.credential_aad_hash
     );
  return found;
end
$$;

create or replace function argus_private.reset_webull_refresh_before_egress(
  p_event_id uuid,p_connection_id uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text,p_lease_token uuid
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private
as $$
begin
  update argus_private.refresh_leases lease set egress_started_at=null
   where lease.connection_id=p_connection_id and lease.event_id=p_event_id
     and lease.lease_token=p_lease_token and lease.token_version=p_token_version
     and lease.key_version=p_key_version and lease.credential_aad_hash=p_aad_hash
     and lease.egress_started_at is not null;
  return found;
end
$$;

create or replace function argus_private.release_webull_token_refresh(
  p_connection_id uuid,p_lease_token uuid
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private
as $$
begin
  delete from argus_private.refresh_leases lease
   where lease.connection_id=p_connection_id and lease.lease_token=p_lease_token
     and lease.egress_started_at is null;
  return found;
end
$$;

create or replace function argus_private.fence_webull_refresh_outcome(
  p_event_id uuid,p_connection_id uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text,p_reason text
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare owner_id uuid;
begin
  if p_reason not in ('refresh_expired','refresh_rejected','refresh_outcome_unknown') then
    raise exception 'invalid_refresh_outcome';
  end if;
  select event.user_id into owner_id from argus_private.outbox_events event
   join argus_private.webull_credentials credential
     on credential.connection_id=p_connection_id and credential.user_id=event.user_id
    and credential.deletion_epoch=event.deletion_epoch
    and credential.token_version=p_token_version and credential.key_version=p_key_version
    and credential.associated_data_hash=p_aad_hash
   where event.id=p_event_id and event.topic='brokerage_refresh'
     and event.event_type='webull.token.refresh.requested'
     and event.aggregate_id=p_connection_id for update of credential;
  if owner_id is null then return false; end if;
  update argus_brokerage.connections set status='reauthorization_required',
    last_error_code=p_reason,updated_at=clock_timestamp()
   where id=p_connection_id and user_id=owner_id and status='connected';
  delete from argus_brokerage.active_account_selections
   where user_id=owner_id and connection_id=p_connection_id;
  delete from argus_private.webull_credentials
   where connection_id=p_connection_id and user_id=owner_id
     and token_version=p_token_version and key_version=p_key_version
     and associated_data_hash=p_aad_hash;
  delete from argus_private.refresh_leases where connection_id=p_connection_id;
  return true;
end
$$;

create or replace function argus_private.commit_webull_token_refresh(
  p_event_id uuid,p_connection_id uuid,p_expected_token_version bigint,
  p_expected_key_version integer,p_expected_aad_hash text,p_lease_token uuid,
  p_next_token_version bigint,p_next_key_version integer,
  p_access_ciphertext bytea,p_access_nonce bytea,p_access_tag bytea,
  p_refresh_ciphertext bytea,p_refresh_nonce bytea,p_refresh_tag bytea,
  p_wrapped_data_key bytea,p_wrapped_key_nonce bytea,p_wrapped_key_tag bytea,
  p_next_aad_hash text,p_access_expires_at timestamptz,p_refresh_expires_at timestamptz
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare affected integer;
begin
  if p_next_token_version<>p_expected_token_version+1 or p_next_key_version<1
     or p_expected_aad_hash !~ '^[a-f0-9]{64}$' or p_next_aad_hash !~ '^[a-f0-9]{64}$'
     or octet_length(p_access_nonce)<>12 or octet_length(p_refresh_nonce)<>12
     or octet_length(p_wrapped_key_nonce)<>12 or octet_length(p_access_tag)<>16
     or octet_length(p_refresh_tag)<>16 or octet_length(p_wrapped_key_tag)<>16
     or p_access_expires_at<=clock_timestamp()
     or p_refresh_expires_at<=p_access_expires_at then
    raise exception 'invalid_event_payload';
  end if;
  update argus_private.webull_credentials credential set
    token_version=p_next_token_version,key_version=p_next_key_version,
    access_ciphertext=p_access_ciphertext,access_nonce=p_access_nonce,access_tag=p_access_tag,
    refresh_ciphertext=p_refresh_ciphertext,refresh_nonce=p_refresh_nonce,refresh_tag=p_refresh_tag,
    wrapped_data_key=p_wrapped_data_key,wrapped_key_nonce=p_wrapped_key_nonce,
    wrapped_key_tag=p_wrapped_key_tag,associated_data_hash=p_next_aad_hash,
    access_expires_at=p_access_expires_at,refresh_expires_at=p_refresh_expires_at,
    updated_at=clock_timestamp()
   where credential.connection_id=p_connection_id
     and credential.token_version=p_expected_token_version
     and credential.key_version=p_expected_key_version
     and credential.associated_data_hash=p_expected_aad_hash
     and exists (
       select 1 from argus_private.refresh_leases lease
       join argus_private.outbox_events event on event.id=lease.event_id
       join argus_private.job_runs run on run.source_event_id=event.id
        and run.handler_name='webull-token-refresh' and run.status='leased'
        and run.leased_until>clock_timestamp()
       join argus_app.members member on member.user_id=event.user_id
        and member.deletion_epoch=event.deletion_epoch and member.status='active'
       join argus_brokerage.connections connection on connection.id=credential.connection_id
        and connection.user_id=event.user_id and connection.deletion_epoch=event.deletion_epoch
        and connection.status='connected' and connection.egress_fenced_at is null
      where lease.connection_id=p_connection_id and lease.event_id=p_event_id
        and lease.lease_token=p_lease_token and lease.token_version=p_expected_token_version
        and lease.key_version=p_expected_key_version
        and lease.credential_aad_hash=p_expected_aad_hash
        and lease.egress_started_at is not null and lease.leased_until>clock_timestamp()
        and event.topic='brokerage_refresh'
        and event.event_type='webull.token.refresh.requested'
        and event.aggregate_id=p_connection_id
        and not exists (
          select 1 from argus_private.kill_switches where name='provider_egress' and enabled
        )
     );
  get diagnostics affected=row_count;
  if affected=1 then
    delete from argus_private.refresh_leases
     where connection_id=p_connection_id and event_id=p_event_id and lease_token=p_lease_token;
  end if;
  return affected=1;
end
$$;

create or replace function argus_private.claim_webull_projection_refresh(
  p_event_id uuid,p_lease_id uuid,p_lease_token uuid,p_lease_seconds integer
)
returns table(
  claim_outcome text,lease_id uuid,user_id uuid,deletion_epoch bigint,
  connection_id uuid,account_id uuid,resource_type text,
  provider_environment text,token_version bigint,key_version integer,
  access_ciphertext bytea,access_nonce bytea,access_tag bytea,
  refresh_ciphertext bytea,refresh_nonce bytea,refresh_tag bytea,
  wrapped_data_key bytea,wrapped_key_nonce bytea,wrapped_key_tag bytea,
  associated_data_hash text,access_expires_at timestamptz,refresh_expires_at timestamptz,
  provider_account_id_ciphertext bytea,provider_account_key_version integer
)
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare event_record argus_private.outbox_events%rowtype;
declare lease_record argus_private.projection_refresh_leases%rowtype;
declare credential argus_private.webull_credentials%rowtype;
declare mapping argus_private.webull_account_mappings%rowtype;
begin
  if p_lease_seconds<15 or p_lease_seconds>55 then raise exception 'invalid_lease_duration'; end if;
  select * into event_record from argus_private.outbox_events event
   where event.id=p_event_id and event.topic='brokerage_refresh'
     and event.event_type='webull.projection.refresh.requested'
     and event.aggregate_id=p_lease_id
     and exists (
       select 1 from argus_private.job_runs run
        where run.source_event_id=event.id and run.handler_name='webull-projection-refresh'
          and run.status='leased' and run.leased_until>clock_timestamp()
     );
  if event_record.id is null or not argus_private.assert_worker_event_current(p_event_id) then return; end if;
  if exists (select 1 from argus_private.kill_switches where name='provider_egress' and enabled) then
    raise exception 'worker_killed';
  end if;
  select * into lease_record from argus_private.projection_refresh_leases lease
   where lease.id=p_lease_id and lease.user_id=event_record.user_id
     and lease.deletion_epoch=event_record.deletion_epoch for update;
  if lease_record.id is null or lease_record.resource_type not in ('account','balance','positions','restrictions')
     or lease_record.leased_until>clock_timestamp() then return; end if;
  update argus_private.projection_refresh_leases lease
     set lease_token=p_lease_token,
         leased_until=clock_timestamp()+make_interval(secs=>p_lease_seconds),
         acquired_at=clock_timestamp()
   where lease.id=p_lease_id;
  select * into credential from argus_private.webull_credentials current_credential
   where current_credential.connection_id=lease_record.connection_id
     and current_credential.user_id=lease_record.user_id
     and current_credential.deletion_epoch=lease_record.deletion_epoch;
  select * into mapping from argus_private.webull_account_mappings account_mapping
   where account_mapping.account_id=lease_record.account_id
     and account_mapping.connection_id=lease_record.connection_id
     and account_mapping.user_id=lease_record.user_id
     and account_mapping.deletion_epoch=lease_record.deletion_epoch;
  if credential.connection_id is null or mapping.account_id is null or not exists (
    select 1 from argus_app.members member
    join argus_brokerage.connections connection on connection.user_id=member.user_id
     and connection.deletion_epoch=member.deletion_epoch
    join argus_brokerage.accounts account on account.connection_id=connection.id
     and account.user_id=connection.user_id and account.deletion_epoch=connection.deletion_epoch
   where member.user_id=lease_record.user_id and member.status='active'
     and connection.id=lease_record.connection_id and connection.status='connected'
     and connection.egress_fenced_at is null and account.id=lease_record.account_id
  ) then
    delete from argus_private.projection_refresh_leases where id=p_lease_id;
    return;
  end if;
  return query select 'claimed'::text,lease_record.id,credential.user_id,
    credential.deletion_epoch,credential.connection_id,lease_record.account_id,
    lease_record.resource_type,credential.provider_environment,credential.token_version,
    credential.key_version,credential.access_ciphertext,credential.access_nonce,
    credential.access_tag,credential.refresh_ciphertext,credential.refresh_nonce,
    credential.refresh_tag,credential.wrapped_data_key,credential.wrapped_key_nonce,
    credential.wrapped_key_tag,credential.associated_data_hash,
    credential.access_expires_at,credential.refresh_expires_at,
    mapping.provider_account_id_ciphertext,mapping.key_version;
end
$$;

create or replace function argus_private.release_webull_projection_refresh(
  p_event_id uuid,p_lease_id uuid,p_lease_token uuid,p_preserve_for_retry boolean
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private
as $$
begin
  if p_preserve_for_retry then
    update argus_private.projection_refresh_leases lease
       set leased_until=clock_timestamp(),lease_token=gen_random_uuid()
      from argus_private.outbox_events event
     where lease.id=p_lease_id and lease.lease_token=p_lease_token
       and event.id=p_event_id and event.aggregate_id=lease.id
       and event.topic='brokerage_refresh'
       and event.event_type='webull.projection.refresh.requested';
    return found;
  end if;
  delete from argus_private.projection_refresh_leases lease
    using argus_private.outbox_events event
   where lease.id=p_lease_id and lease.lease_token=p_lease_token
     and event.id=p_event_id and event.aggregate_id=lease.id
     and event.topic='brokerage_refresh'
     and event.event_type='webull.projection.refresh.requested';
  return found;
end
$$;

create or replace function argus_private.authorize_webull_projection_egress(
  p_event_id uuid,p_lease_id uuid,p_lease_token uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text
)
returns boolean
language plpgsql volatile security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
begin
  if exists (
    select 1 from argus_private.kill_switches
     where name='provider_egress' and enabled
  ) then raise exception 'worker_killed'; end if;
  return exists (
    select 1 from argus_private.outbox_events event
    join argus_private.job_runs run on run.source_event_id=event.id
     and run.handler_name='webull-projection-refresh' and run.status='leased'
     and run.leased_until>clock_timestamp()
    join argus_private.projection_refresh_leases lease on lease.id=event.aggregate_id
     and lease.user_id=event.user_id and lease.deletion_epoch=event.deletion_epoch
     and lease.lease_token=p_lease_token and lease.leased_until>clock_timestamp()
    join argus_app.members member on member.user_id=event.user_id
     and member.deletion_epoch=event.deletion_epoch and member.status='active'
    join argus_brokerage.connections connection on connection.id=lease.connection_id
     and connection.user_id=event.user_id and connection.deletion_epoch=event.deletion_epoch
     and connection.status='connected' and connection.egress_fenced_at is null
    join argus_brokerage.accounts account on account.id=lease.account_id
     and account.connection_id=connection.id and account.user_id=connection.user_id
     and account.deletion_epoch=connection.deletion_epoch
    join argus_private.webull_credentials credential on credential.connection_id=connection.id
     and credential.user_id=connection.user_id and credential.deletion_epoch=connection.deletion_epoch
     and credential.token_version=p_token_version and credential.key_version=p_key_version
     and credential.associated_data_hash=p_aad_hash
   where event.id=p_event_id and event.topic='brokerage_refresh'
     and event.event_type='webull.projection.refresh.requested'
     and event.aggregate_id=p_lease_id
  );
end
$$;

create or replace function argus_private.mark_webull_reauthorization(
  p_event_id uuid,p_connection_id uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare owner_id uuid;
begin
  select event.user_id into owner_id from argus_private.outbox_events event
   join argus_private.webull_credentials credential
     on credential.connection_id=p_connection_id and credential.user_id=event.user_id
    and credential.deletion_epoch=event.deletion_epoch
    and credential.token_version=p_token_version and credential.key_version=p_key_version
    and credential.associated_data_hash=p_aad_hash
   where event.id=p_event_id and event.topic='brokerage_refresh'
     and event.event_type='webull.projection.refresh.requested'
   for update of credential;
  if owner_id is null then return false; end if;
  update argus_brokerage.connections set status='reauthorization_required',
    last_error_code='provider_authorization_invalid',updated_at=clock_timestamp()
   where id=p_connection_id and user_id=owner_id and status='connected';
  delete from argus_brokerage.active_account_selections
   where user_id=owner_id and connection_id=p_connection_id;
  return true;
end
$$;

create or replace function argus_private.commit_webull_projection_refresh(
  p_event_id uuid,p_lease_id uuid,p_lease_token uuid,
  p_token_version bigint,p_key_version integer,p_aad_hash text,
  p_resource_type text,p_payload jsonb,p_provider_observed_at timestamptz,
  p_fetched_at timestamptz,p_expires_at timestamptz,p_availability text,
  p_reason_code text
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare lease_record argus_private.projection_refresh_leases%rowtype;
declare next_generation bigint;
begin
  if p_resource_type not in ('account','balance','positions','restrictions')
     or jsonb_typeof(p_payload) not in ('object','array')
     or p_payload::text ~* '"((access|refresh)_?token|secret|raw_payload|provider_(account|asset|order)_(id|ref))"[[:space:]]*:'
     or p_fetched_at>clock_timestamp()+interval '30 seconds'
     or p_expires_at<p_fetched_at or p_expires_at>p_fetched_at+interval '5 minutes'
     or p_provider_observed_at>p_fetched_at or p_availability not in ('available','partial')
     or (p_reason_code is not null and p_reason_code !~ '^[a-z][a-z0-9_]{0,63}$') then
    raise exception 'invalid_event_payload';
  end if;
  select lease.* into lease_record from argus_private.projection_refresh_leases lease
   join argus_private.outbox_events event on event.id=p_event_id
    and event.aggregate_id=lease.id and event.topic='brokerage_refresh'
    and event.event_type='webull.projection.refresh.requested'
   join argus_app.members member on member.user_id=event.user_id
    and member.deletion_epoch=event.deletion_epoch and member.status='active'
   join argus_brokerage.connections connection on connection.id=lease.connection_id
    and connection.user_id=event.user_id and connection.deletion_epoch=event.deletion_epoch
    and connection.status='connected' and connection.egress_fenced_at is null
   join argus_brokerage.accounts account on account.id=lease.account_id
    and account.connection_id=connection.id and account.user_id=connection.user_id
    and account.deletion_epoch=connection.deletion_epoch
   join argus_private.webull_credentials credential on credential.connection_id=connection.id
    and credential.user_id=connection.user_id and credential.deletion_epoch=connection.deletion_epoch
    and credential.token_version=p_token_version and credential.key_version=p_key_version
    and credential.associated_data_hash=p_aad_hash
   where lease.id=p_lease_id and lease.lease_token=p_lease_token
     and lease.leased_until>clock_timestamp() and lease.resource_type=p_resource_type
     and not exists (
       select 1 from argus_private.kill_switches where name='provider_egress' and enabled
     ) for update of lease,account;
  if lease_record.id is null then return false; end if;
  select coalesce(max(generation.generation),0)+1 into next_generation
    from argus_brokerage.projection_generations generation
   where generation.account_id=lease_record.account_id
     and generation.resource_type=p_resource_type;
  insert into argus_brokerage.projection_generations(
    user_id,deletion_epoch,connection_id,account_id,resource_type,generation,
    normalized_payload,provider_observed_at,fetched_at,expires_at,availability,
    reason_code,purge_after
  ) values (
    lease_record.user_id,lease_record.deletion_epoch,lease_record.connection_id,
    lease_record.account_id,p_resource_type,next_generation,p_payload,
    p_provider_observed_at,p_fetched_at,p_expires_at,p_availability,p_reason_code,
    p_fetched_at+interval '30 days'
  );
  delete from argus_private.projection_refresh_leases where id=lease_record.id;
  return true;
end
$$;

create or replace function argus_private.claim_webull_command_reconciliation(
  p_event_id uuid,p_command_id uuid
)
returns table(
  claim_outcome text,user_id uuid,deletion_epoch bigint,connection_id uuid,
  account_id uuid,command_id uuid,operation text,client_order_id text,
  target_order_id uuid,provider_environment text,token_version bigint,
  key_version integer,access_ciphertext bytea,access_nonce bytea,access_tag bytea,
  refresh_ciphertext bytea,refresh_nonce bytea,refresh_tag bytea,
  wrapped_data_key bytea,wrapped_key_nonce bytea,wrapped_key_tag bytea,
  associated_data_hash text,access_expires_at timestamptz,refresh_expires_at timestamptz,
  provider_account_id_ciphertext bytea,provider_account_key_version integer,
  target_order_ref_ciphertext bytea,target_order_ref_key_version integer
)
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare event_record argus_private.outbox_events%rowtype;
declare command_record argus_private.provider_commands%rowtype;
declare reconciliation argus_private.reconciliation_records%rowtype;
declare credential argus_private.webull_credentials%rowtype;
declare account_mapping argus_private.webull_account_mappings%rowtype;
declare target_mapping argus_private.webull_order_mappings%rowtype;
declare attempt_number integer;
declare force_manual boolean:=false;
begin
  select * into event_record from argus_private.outbox_events event
   where event.id=p_event_id and event.topic='brokerage_reconcile'
     and event.event_type='webull.command.reconciliation.requested'
     and event.aggregate_id=p_command_id
     and exists (
       select 1 from argus_private.job_runs run
        where run.source_event_id=event.id and run.handler_name='webull-reconciliation'
          and run.status='leased' and run.leased_until>clock_timestamp()
     );
  if event_record.id is null or not argus_private.assert_worker_event_current(p_event_id) then return; end if;
  if exists (select 1 from argus_private.kill_switches where name='provider_egress' and enabled) then
    raise exception 'worker_killed';
  end if;
  select * into command_record from argus_private.provider_commands command
   where command.id=p_command_id and command.user_id=event_record.user_id
     and command.deletion_epoch=event_record.deletion_epoch for update;
  if command_record.id is null
     or command_record.state not in ('dispatching','ambiguous','reconciling')
     or (command_record.state='dispatching'
         and command_record.egress_started_at>clock_timestamp()-interval '30 seconds') then return; end if;
  insert into argus_private.reconciliation_records(
    user_id,deletion_epoch,command_id,status,next_attempt_at
  ) values (
    command_record.user_id,command_record.deletion_epoch,command_record.id,'pending',clock_timestamp()
  ) on conflict (command_id) do nothing;
  select * into reconciliation from argus_private.reconciliation_records record
   where record.command_id=command_record.id for update;
  -- U10 dead-letters delivery five. Stop before that final provider lookup so
  -- even a failure before result-recording cannot strand a reconciling row.
  force_manual := reconciliation.attempts>=4
    or reconciliation.status in ('manual_review','exhausted');
  if force_manual then
    if command_record.state='dispatching' then
      update argus_private.provider_commands set state='ambiguous',updated_at=clock_timestamp()
       where id=command_record.id;
      command_record.state:='ambiguous';
    end if;
    update argus_private.provider_commands set state='manual_review',updated_at=clock_timestamp()
     where id=command_record.id and state in ('ambiguous','reconciling');
    update argus_private.reconciliation_records set status='manual_review',
      next_attempt_at=clock_timestamp(),last_error_code='reconciliation_exhausted',
      updated_at=clock_timestamp() where command_id=command_record.id;
    return query select 'manual_review'::text,command_record.user_id,
      command_record.deletion_epoch,command_record.connection_id,command_record.account_id,
      command_record.id,command_record.operation,command_record.client_order_id,
      command_record.target_order_id,null::text,null::bigint,null::integer,
      null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,
      null::bytea,null::bytea,null::bytea,null::text,null::timestamptz,null::timestamptz,
      null::bytea,null::integer,null::bytea,null::integer;
    return;
  end if;
  if reconciliation.next_attempt_at>clock_timestamp() then
    raise exception 'dependency_unavailable';
  end if;
  select * into credential from argus_private.webull_credentials current_credential
   where current_credential.connection_id=command_record.connection_id
     and current_credential.user_id=command_record.user_id
     and current_credential.deletion_epoch=command_record.deletion_epoch;
  select * into account_mapping from argus_private.webull_account_mappings mapping
   where mapping.account_id=command_record.account_id
     and mapping.connection_id=command_record.connection_id
     and mapping.user_id=command_record.user_id
     and mapping.deletion_epoch=command_record.deletion_epoch;
  if command_record.target_order_id is not null then
    select * into target_mapping from argus_private.webull_order_mappings mapping
     where mapping.order_id=command_record.target_order_id
       and mapping.account_id=command_record.account_id
       and mapping.connection_id=command_record.connection_id
       and mapping.user_id=command_record.user_id
       and mapping.deletion_epoch=command_record.deletion_epoch;
  end if;
  if credential.connection_id is null or account_mapping.account_id is null
     or (command_record.target_order_id is not null and target_mapping.order_id is null)
     or not exists (
       select 1 from argus_app.members member
       join argus_brokerage.connections connection on connection.user_id=member.user_id
        and connection.deletion_epoch=member.deletion_epoch
       join argus_brokerage.accounts account on account.connection_id=connection.id
        and account.user_id=connection.user_id and account.deletion_epoch=connection.deletion_epoch
      where member.user_id=command_record.user_id and member.status='active'
        and connection.id=command_record.connection_id and connection.status='connected'
        and connection.egress_fenced_at is null and account.id=command_record.account_id
     ) then
    if command_record.state='dispatching' then
      update argus_private.provider_commands set state='ambiguous',updated_at=clock_timestamp()
       where id=command_record.id;
    end if;
    update argus_private.provider_commands set state='manual_review',updated_at=clock_timestamp()
     where id=command_record.id and state in ('ambiguous','reconciling');
    update argus_private.reconciliation_records set status='manual_review',
      last_error_code='reconciliation_fenced',updated_at=clock_timestamp()
     where command_id=command_record.id;
    return query select 'manual_review'::text,command_record.user_id,
      command_record.deletion_epoch,command_record.connection_id,command_record.account_id,
      command_record.id,command_record.operation,command_record.client_order_id,
      command_record.target_order_id,null::text,null::bigint,null::integer,
      null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,
      null::bytea,null::bytea,null::bytea,null::text,null::timestamptz,null::timestamptz,
      null::bytea,null::integer,null::bytea,null::integer;
    return;
  end if;
  if command_record.state='dispatching' then
    update argus_private.provider_commands set state='ambiguous',updated_at=clock_timestamp()
     where id=command_record.id;
    command_record.state:='ambiguous';
  end if;
  if command_record.state='ambiguous' then
    update argus_private.provider_commands set state='reconciling',updated_at=clock_timestamp()
     where id=command_record.id;
  end if;
  update argus_private.reconciliation_records set status='running',attempts=attempts+1,
    next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
   where command_id=command_record.id;
  select coalesce(max(attempt.attempt_number),0)+1 into attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=command_record.id;
  insert into argus_private.provider_command_attempts(
    user_id,deletion_epoch,command_id,attempt_number,attempt_kind,outcome
  ) values (
    command_record.user_id,command_record.deletion_epoch,command_record.id,
    attempt_number,'detail_lookup','started'
  );
  return query select 'claimed'::text,credential.user_id,credential.deletion_epoch,
    credential.connection_id,command_record.account_id,command_record.id,
    command_record.operation,command_record.client_order_id,command_record.target_order_id,
    credential.provider_environment,credential.token_version,credential.key_version,
    credential.access_ciphertext,credential.access_nonce,credential.access_tag,
    credential.refresh_ciphertext,credential.refresh_nonce,credential.refresh_tag,
    credential.wrapped_data_key,credential.wrapped_key_nonce,credential.wrapped_key_tag,
    credential.associated_data_hash,credential.access_expires_at,credential.refresh_expires_at,
    account_mapping.provider_account_id_ciphertext,account_mapping.key_version,
    target_mapping.provider_order_ref_ciphertext,target_mapping.key_version;
end
$$;

create or replace function argus_private.authorize_webull_reconciliation_egress(
  p_event_id uuid,p_command_id uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text
)
returns boolean
language plpgsql volatile security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
begin
  if exists (
    select 1 from argus_private.kill_switches
     where name='provider_egress' and enabled
  ) then raise exception 'worker_killed'; end if;
  return exists (
    select 1 from argus_private.outbox_events event
    join argus_private.job_runs run on run.source_event_id=event.id
     and run.handler_name='webull-reconciliation' and run.status='leased'
     and run.leased_until>clock_timestamp()
    join argus_private.provider_commands command on command.id=event.aggregate_id
     and command.user_id=event.user_id and command.deletion_epoch=event.deletion_epoch
     and command.state='reconciling'
    join argus_private.reconciliation_records reconciliation on reconciliation.command_id=command.id
     and reconciliation.status='running' and reconciliation.attempts between 1 and 4
    join argus_app.members member on member.user_id=command.user_id
     and member.deletion_epoch=command.deletion_epoch and member.status='active'
    join argus_brokerage.connections connection on connection.id=command.connection_id
     and connection.user_id=command.user_id and connection.deletion_epoch=command.deletion_epoch
     and connection.status='connected' and connection.egress_fenced_at is null
    join argus_brokerage.accounts account on account.id=command.account_id
     and account.connection_id=connection.id and account.user_id=connection.user_id
     and account.deletion_epoch=connection.deletion_epoch
    join argus_private.webull_credentials credential on credential.connection_id=connection.id
     and credential.user_id=connection.user_id and credential.deletion_epoch=connection.deletion_epoch
     and credential.token_version=p_token_version and credential.key_version=p_key_version
     and credential.associated_data_hash=p_aad_hash
   where event.id=p_event_id and event.topic='brokerage_reconcile'
     and event.event_type='webull.command.reconciliation.requested'
     and event.aggregate_id=p_command_id
  );
end
$$;

create or replace function argus_private.record_webull_reconciliation_retry(
  p_event_id uuid,p_command_id uuid,p_token_version bigint,p_key_version integer,
  p_aad_hash text,p_reason text
)
returns text
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare command_record argus_private.provider_commands%rowtype;
declare reconciliation argus_private.reconciliation_records%rowtype;
declare attempt_number integer;
declare exhausted boolean;
begin
  if p_reason not in ('provider_order_not_found','provider_lookup_unavailable','provider_rate_limited','provider_temporarily_unavailable') then
    p_reason:='provider_lookup_unavailable';
  end if;
  select command.* into command_record from argus_private.provider_commands command
   join argus_private.outbox_events event on event.id=p_event_id
    and event.topic='brokerage_reconcile'
    and event.event_type='webull.command.reconciliation.requested'
    and event.aggregate_id=command.id and event.user_id=command.user_id
    and event.deletion_epoch=command.deletion_epoch
   join argus_private.webull_credentials credential on credential.connection_id=command.connection_id
    and credential.user_id=command.user_id and credential.deletion_epoch=command.deletion_epoch
    and credential.token_version=p_token_version and credential.key_version=p_key_version
    and credential.associated_data_hash=p_aad_hash
   join argus_app.members member on member.user_id=command.user_id
    and member.deletion_epoch=command.deletion_epoch and member.status='active'
   join argus_brokerage.connections connection on connection.id=command.connection_id
    and connection.user_id=command.user_id and connection.deletion_epoch=command.deletion_epoch
    and connection.status='connected' and connection.egress_fenced_at is null
   where command.id=p_command_id and command.state='reconciling' for update of command;
  if command_record.id is null then return 'manual_review'; end if;
  select * into reconciliation from argus_private.reconciliation_records record
   where record.command_id=command_record.id for update;
  select coalesce(max(attempt.attempt_number),0)+1 into attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=command_record.id;
  insert into argus_private.provider_command_attempts(
    user_id,deletion_epoch,command_id,attempt_number,attempt_kind,outcome,provider_error_code
  ) values (
    command_record.user_id,command_record.deletion_epoch,command_record.id,
    attempt_number,'detail_lookup',
    case when p_reason='provider_order_not_found' then 'not_found' else 'ambiguous' end,
    p_reason
  );
  exhausted:=reconciliation.attempts>=4;
  if exhausted then
    update argus_private.provider_commands set state='manual_review',updated_at=clock_timestamp()
     where id=command_record.id;
    update argus_private.reconciliation_records set status='manual_review',
      last_error_code=p_reason,updated_at=clock_timestamp()
     where command_id=command_record.id;
    return 'manual_review';
  end if;
  update argus_private.reconciliation_records set status='pending',
    next_attempt_at=clock_timestamp(),last_error_code=p_reason,
    updated_at=clock_timestamp() where command_id=command_record.id;
  return 'retry';
end
$$;

create or replace function argus_private.mark_webull_reconciliation_reauthorization(
  p_event_id uuid,p_command_id uuid,p_token_version bigint,p_key_version integer,
  p_aad_hash text,p_reason text
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_brokerage
as $$
declare command_record argus_private.provider_commands%rowtype;
begin
  select command.* into command_record from argus_private.provider_commands command
   join argus_private.outbox_events event on event.id=p_event_id
    and event.topic='brokerage_reconcile'
    and event.event_type='webull.command.reconciliation.requested'
    and event.aggregate_id=command.id and event.user_id=command.user_id
   join argus_private.webull_credentials credential on credential.connection_id=command.connection_id
    and credential.user_id=command.user_id and credential.deletion_epoch=command.deletion_epoch
    and credential.token_version=p_token_version and credential.key_version=p_key_version
    and credential.associated_data_hash=p_aad_hash
   where command.id=p_command_id and command.state='reconciling' for update of command;
  if command_record.id is null then return false; end if;
  update argus_brokerage.connections set status='reauthorization_required',
    last_error_code='provider_authorization_invalid',updated_at=clock_timestamp()
   where id=command_record.connection_id and user_id=command_record.user_id
     and deletion_epoch=command_record.deletion_epoch and status='connected';
  delete from argus_brokerage.active_account_selections
   where user_id=command_record.user_id and connection_id=command_record.connection_id;
  update argus_private.provider_commands set state='manual_review',updated_at=clock_timestamp()
   where id=command_record.id;
  update argus_private.reconciliation_records set status='manual_review',
    last_error_code=case when p_reason~'^[a-z][a-z0-9_]{0,63}$' then p_reason else 'provider_authorization_invalid' end,
    updated_at=clock_timestamp() where command_id=command_record.id;
  return true;
end
$$;

create or replace function argus_private.commit_webull_reconciliation(
  p_event_id uuid,p_command_id uuid,p_token_version bigint,p_key_version integer,
  p_aad_hash text,p_resolution text,p_order_id uuid,p_state text,
  p_filled_quantity numeric,p_payload jsonb,p_provider_observed_at timestamptz,
  p_fetched_at timestamptz,p_reference_ciphertext bytea,p_reference_hash text,
  p_reference_key_version integer,p_instrument_id uuid
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare command_record argus_private.provider_commands%rowtype;
begin
  if p_payload::text ~* '"((access|refresh)_?token|secret|raw_payload|reviewed_payload|normalized_payload)"[[:space:]]*:'
     or octet_length(p_reference_ciphertext) not between 32 and 4096
     or p_reference_hash !~ '^[a-f0-9]{64}$' or p_reference_key_version<1 then
    raise exception 'invalid_event_payload';
  end if;
  select command.* into command_record from argus_private.provider_commands command
   join argus_private.outbox_events event on event.id=p_event_id
    and event.topic='brokerage_reconcile'
    and event.event_type='webull.command.reconciliation.requested'
    and event.aggregate_id=command.id and event.user_id=command.user_id
    and event.deletion_epoch=command.deletion_epoch
   join argus_private.webull_credentials credential on credential.connection_id=command.connection_id
    and credential.user_id=command.user_id and credential.deletion_epoch=command.deletion_epoch
    and credential.token_version=p_token_version and credential.key_version=p_key_version
    and credential.associated_data_hash=p_aad_hash
   join argus_app.members member on member.user_id=command.user_id
    and member.deletion_epoch=command.deletion_epoch and member.status='active'
   join argus_brokerage.connections connection on connection.id=command.connection_id
    and connection.user_id=command.user_id and connection.deletion_epoch=command.deletion_epoch
    and connection.status='connected' and connection.egress_fenced_at is null
   join argus_brokerage.accounts account on account.id=command.account_id
    and account.connection_id=connection.id and account.user_id=connection.user_id
    and account.deletion_epoch=connection.deletion_epoch
   where command.id=p_command_id and command.state='reconciling'
     and not exists (
       select 1 from argus_private.kill_switches where name='provider_egress' and enabled
     ) for update of command,account;
  if command_record.id is null then return false; end if;
  perform set_config('request.jwt.claim.sub',command_record.user_id::text,true);
  perform argus_private.record_provider_order_reconciliation(
    p_command_id,p_resolution,p_order_id,p_state,p_filled_quantity,p_payload,
    p_provider_observed_at,p_fetched_at,p_reference_ciphertext,p_reference_hash,
    p_reference_key_version,p_instrument_id
  );
  return true;
end
$$;

create or replace function argus_private.terminalize_webull_recovery_dead_letter(
  p_event_id uuid,p_reason text
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_brokerage
as $$
declare command_id uuid;
declare command_state text;
declare target_connection_id uuid;
declare target_owner_id uuid;
begin
  select connection.id,event.user_id into target_connection_id,target_owner_id
    from argus_private.outbox_events event
    join argus_brokerage.connections connection
      on connection.id=event.aggregate_id and connection.user_id=event.user_id
     and connection.deletion_epoch=event.deletion_epoch
    join argus_private.webull_credentials credential
      on credential.connection_id=connection.id and credential.user_id=connection.user_id
     and credential.deletion_epoch=connection.deletion_epoch
     and event.dedupe_key='webull-token:'||credential.connection_id::text||':'||credential.token_version::text
   where event.id=p_event_id and event.topic='brokerage_refresh'
     and event.event_type='webull.token.refresh.requested'
   for update of connection,credential;
  if target_connection_id is not null then
    update argus_brokerage.connections set status='reauthorization_required',
      last_error_code='token_refresh_exhausted',updated_at=clock_timestamp()
     where id=target_connection_id and user_id=target_owner_id and status='connected';
    delete from argus_brokerage.active_account_selections
     where user_id=target_owner_id
       and active_account_selections.connection_id=target_connection_id;
    delete from argus_private.refresh_leases
     where refresh_leases.connection_id=target_connection_id
       and user_id=target_owner_id;
    delete from argus_private.webull_credentials
     where webull_credentials.connection_id=target_connection_id
       and user_id=target_owner_id;
    return true;
  end if;
  if exists (
    select 1 from argus_private.outbox_events event
     where event.id=p_event_id and event.topic='brokerage_refresh'
       and event.event_type='webull.projection.refresh.requested'
  ) then
    delete from argus_private.projection_refresh_leases lease
     using argus_private.outbox_events event
     where event.id=p_event_id and event.aggregate_id=lease.id;
    return true;
  end if;
  select command.id,command.state into command_id,command_state
    from argus_private.outbox_events event
    join argus_private.provider_commands command
      on command.id=event.aggregate_id and command.user_id=event.user_id
     and command.deletion_epoch=event.deletion_epoch
   where event.id=p_event_id and event.topic='brokerage_reconcile'
     and event.event_type='webull.command.reconciliation.requested'
   for update of command;
  if command_id is null then return false; end if;
  if command_state not in ('dispatching','ambiguous','reconciling','manual_review') then
    return true;
  end if;
  if command_state='dispatching' then
    update argus_private.provider_commands set state='ambiguous',updated_at=clock_timestamp()
     where id=command_id;
    command_state:='ambiguous';
  end if;
  if command_state in ('ambiguous','reconciling') then
    update argus_private.provider_commands set state='manual_review',updated_at=clock_timestamp()
     where id=command_id;
  end if;
  insert into argus_private.reconciliation_records(
    user_id,deletion_epoch,command_id,status,next_attempt_at,last_error_code
  ) select user_id,deletion_epoch,id,'manual_review',clock_timestamp(),
      case when p_reason~'^[a-z][a-z0-9_]{0,63}$' then p_reason else 'reconciliation_exhausted' end
    from argus_private.provider_commands where id=command_id
  on conflict (command_id) do update set status='manual_review',
    last_error_code=excluded.last_error_code,updated_at=clock_timestamp();
  return true;
end
$$;

create or replace function argus_private.disconnect_webull_connection(
  p_receipt_hash text,p_session_id uuid
)
returns table(connection_id uuid,status text,provider_grant_revoked boolean)
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare owner_id uuid:=argus_private.request_user_id();
declare selected_connection uuid;
begin
  if owner_id is null or p_receipt_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'step_up_required' using errcode='42501';
  end if;
  update argus_private.step_up_receipts receipt set consumed_at=clock_timestamp()
   where receipt.receipt_hash=p_receipt_hash and receipt.user_id=owner_id
     and receipt.session_id=p_session_id and receipt.action='webull_disconnect'
     and receipt.aal='aal2' and receipt.consumed_at is null
     and receipt.expires_at>clock_timestamp();
  if not found then raise exception 'step_up_required' using errcode='42501'; end if;
  select connection.id into selected_connection from argus_brokerage.connections connection
   where connection.user_id=owner_id and connection.status<>'disconnected'
   order by connection.created_at desc limit 1 for update;
  if selected_connection is null then raise exception 'connection_not_found'; end if;
  update argus_brokerage.connections set status='disconnected',
    egress_fenced_at=clock_timestamp(),disconnected_at=clock_timestamp(),
    last_error_code=null,updated_at=clock_timestamp()
   where id=selected_connection and user_id=owner_id;
  update argus_private.job_runs run set status='cancelled',lease_token=null,
    leased_until=null,last_error_code='member_deleted',updated_at=clock_timestamp()
   where run.source_event_id in (
     select event.id from argus_private.outbox_events event
      where event.user_id=owner_id
        and event.topic in ('brokerage_refresh','brokerage_reconcile')
   ) and run.status not in ('succeeded','dead_lettered','cancelled');
  delete from argus_private.outbox_events event
   where event.user_id=owner_id and event.topic in ('brokerage_refresh','brokerage_reconcile');
  delete from argus_private.oauth_states
   where user_id=owner_id and connection_id=selected_connection;
  delete from argus_private.webull_completion_handles
   where user_id=owner_id and connection_id=selected_connection;
  delete from argus_private.refresh_leases
   where user_id=owner_id and connection_id=selected_connection;
  delete from argus_private.projection_refresh_leases
   where user_id=owner_id and connection_id=selected_connection;
  delete from argus_private.webull_credentials
   where user_id=owner_id and connection_id=selected_connection;
  delete from argus_brokerage.accounts
   where user_id=owner_id and connection_id=selected_connection;
  return query select selected_connection,'disconnected'::text,false;
end
$$;

create or replace function argus_private.fence_webull_member_for_deletion(
  p_tombstone_id uuid
)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare tombstone argus_private.deletion_tombstones%rowtype;
begin
  select * into tombstone from argus_private.deletion_tombstones
   where id=p_tombstone_id for update;
  if tombstone.id is null then raise exception 'tombstone_missing'; end if;
  if tombstone.webull_credentials_destroyed_at is not null then return true; end if;
  if not exists (
    select 1 from argus_app.members member where member.user_id=tombstone.user_id
      and member.deletion_epoch=tombstone.deletion_epoch
      and member.status in ('deletion_pending','purging')
  ) then raise exception 'deletion_epoch_changed'; end if;
  update argus_brokerage.connections set status='disconnected',
    egress_fenced_at=clock_timestamp(),disconnected_at=clock_timestamp(),
    last_error_code=null,updated_at=clock_timestamp()
   where user_id=tombstone.user_id and status<>'disconnected';
  update argus_private.job_runs run set status='cancelled',lease_token=null,
    leased_until=null,last_error_code='member_deleted',updated_at=clock_timestamp()
   where run.source_event_id in (
     select event.id from argus_private.outbox_events event
      where event.user_id=tombstone.user_id
        and event.topic in ('brokerage_refresh','brokerage_reconcile')
   ) and run.status not in ('succeeded','dead_lettered','cancelled');
  delete from argus_private.outbox_events event
   where event.user_id=tombstone.user_id
     and event.topic in ('brokerage_refresh','brokerage_reconcile');
  update argus_private.oauth_states set consumed_at=coalesce(consumed_at,clock_timestamp())
   where user_id=tombstone.user_id;
  delete from argus_private.webull_completion_handles where user_id=tombstone.user_id;
  delete from argus_private.refresh_leases where user_id=tombstone.user_id;
  delete from argus_private.projection_refresh_leases where user_id=tombstone.user_id;
  delete from argus_private.webull_credentials where user_id=tombstone.user_id;
  delete from argus_brokerage.accounts where user_id=tombstone.user_id;
  delete from argus_private.oauth_states where user_id=tombstone.user_id;
  update argus_private.deletion_tombstones set
    webull_fenced_at=coalesce(webull_fenced_at,clock_timestamp()),
    webull_credentials_destroyed_at=coalesce(webull_credentials_destroyed_at,clock_timestamp())
   where id=tombstone.id;
  return true;
end
$$;

create or replace function argus_private.fence_webull_on_tombstone()
returns trigger
language plpgsql security definer
set search_path=pg_catalog,argus_private
as $$
begin
  perform argus_private.fence_webull_member_for_deletion(new.id);
  return new;
end
$$;

drop trigger if exists deletion_tombstone_webull_fence on argus_private.deletion_tombstones;
create trigger deletion_tombstone_webull_fence
after insert on argus_private.deletion_tombstones
for each row execute function argus_private.fence_webull_on_tombstone();

create or replace function argus_private.prepare_member_purge(p_tombstone_id uuid)
returns table(user_id uuid,deletion_epoch bigint,purge_phase text)
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app
as $$
declare tombstone argus_private.deletion_tombstones%rowtype;
begin
  perform argus_private.fence_webull_member_for_deletion(p_tombstone_id);
  select * into tombstone from argus_private.deletion_tombstones
   where id=p_tombstone_id and status in ('pending','purging','failed','purged') for update;
  if tombstone.id is null then raise exception 'tombstone_missing'; end if;
  if tombstone.webull_fenced_at is null or tombstone.webull_credentials_destroyed_at is null then
    raise exception 'webull_fence_incomplete';
  end if;
  if tombstone.purge_phase='requested' and not exists (
    select 1 from argus_app.members member where member.user_id=tombstone.user_id
      and member.deletion_epoch=tombstone.deletion_epoch
      and member.status in ('deletion_pending','purging')
  ) then raise exception 'deletion_epoch_changed'; end if;
  update argus_app.members set status='purging' where members.user_id=tombstone.user_id;
  update argus_private.deletion_tombstones set status='purging',
    purge_phase=case when purge_phase='requested' then 'neutralized' else purge_phase end
   where id=tombstone.id and purge_phase<>'complete';
  update argus_private.job_runs set status='cancelled',lease_token=null,leased_until=null,
    last_error_code='member_deleted',updated_at=clock_timestamp()
   where job_runs.user_id=tombstone.user_id
     and job_runs.deletion_epoch<tombstone.deletion_epoch
     and status not in ('succeeded','dead_lettered','cancelled');
  delete from argus_private.outbox_events where outbox_events.user_id=tombstone.user_id;
  select * into tombstone from argus_private.deletion_tombstones where id=p_tombstone_id;
  return query select tombstone.user_id,tombstone.deletion_epoch,tombstone.purge_phase;
end
$$;

create or replace function argus_private.complete_member_purge(p_tombstone_id uuid)
returns uuid
language plpgsql security definer
set search_path=pg_catalog,argus_private,auth
as $$
declare tombstone argus_private.deletion_tombstones%rowtype;
declare receipt_id uuid;
declare object_count integer;
begin
  select * into tombstone from argus_private.deletion_tombstones
   where id=p_tombstone_id and purge_phase in ('data_purged','complete') for update;
  if tombstone.id is null then raise exception 'tombstone_missing'; end if;
  if tombstone.purge_phase='complete' then
    return (select id from argus_private.purge_receipts where tombstone_id=tombstone.id);
  end if;
  if tombstone.webull_fenced_at is null or tombstone.webull_credentials_destroyed_at is null then
    raise exception 'webull_fence_incomplete';
  end if;
  if exists (select 1 from auth.users where id=tombstone.user_id) then
    raise exception 'auth_identity_still_present';
  end if;
  select count(*) into object_count from argus_private.deletion_object_receipts
   where tombstone_id=tombstone.id;
  update argus_private.deletion_tombstones set status='purged',purge_phase='complete',
    auth_deleted_at=clock_timestamp(),completed_at=clock_timestamp()
   where id=tombstone.id;
  insert into argus_private.purge_receipts(tombstone_id,purged_tables,purged_objects)
  values (tombstone.id,tombstone.purged_tables_count,object_count)
  on conflict (tombstone_id) do update set purged_tables=excluded.purged_tables,
    purged_objects=excluded.purged_objects,completed_at=clock_timestamp()
  returning id into receipt_id;
  return receipt_id;
end
$$;

create or replace function argus_private.enqueue_due_webull_recovery_jobs(
  p_batch_size integer default 25
)
returns integer
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage
as $$
declare enqueued integer:=0;
declare added integer:=0;
begin
  if p_batch_size<1 or p_batch_size>25 then raise exception 'invalid_batch_size'; end if;
  if exists (
    select 1 from argus_private.kill_switches
     where name in ('background_workers','provider_egress') and enabled
  ) then
    return 0;
  end if;
  insert into argus_private.outbox_events(
    user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
  )
  select credential.user_id,credential.deletion_epoch,'brokerage_refresh',
    'webull.token.refresh.requested',credential.connection_id,
    'webull-token:'||credential.connection_id::text||':'||credential.token_version::text
   from argus_private.webull_credentials credential
   join argus_app.members member on member.user_id=credential.user_id
    and member.deletion_epoch=credential.deletion_epoch and member.status='active'
   join argus_brokerage.connections connection on connection.id=credential.connection_id
    and connection.user_id=credential.user_id and connection.deletion_epoch=credential.deletion_epoch
    and connection.status='connected' and connection.egress_fenced_at is null
  where credential.access_expires_at<=clock_timestamp()+interval '5 minutes'
  order by credential.access_expires_at,credential.connection_id limit p_batch_size
  on conflict (topic,dedupe_key) do nothing;
  get diagnostics added=row_count;
  enqueued:=enqueued+added;

  if enqueued<p_batch_size then
    insert into argus_private.outbox_events(
      user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
    )
    select command.user_id,command.deletion_epoch,'brokerage_reconcile',
      'webull.command.reconciliation.requested',command.id,
      'webull-reconcile:'||command.id::text
     from argus_private.provider_commands command
     join argus_private.reconciliation_records reconciliation
       on reconciliation.command_id=command.id
     join argus_app.members member on member.user_id=command.user_id
      and member.deletion_epoch=command.deletion_epoch and member.status='active'
     join argus_brokerage.connections connection on connection.id=command.connection_id
      and connection.user_id=command.user_id and connection.deletion_epoch=command.deletion_epoch
      and connection.status='connected' and connection.egress_fenced_at is null
    where command.state in ('ambiguous','reconciling')
      and reconciliation.status in ('pending','running')
      and reconciliation.attempts<5 and reconciliation.next_attempt_at<=clock_timestamp()
    order by reconciliation.next_attempt_at,command.id
    limit (p_batch_size-enqueued)
    on conflict (topic,dedupe_key) do nothing;
    get diagnostics added=row_count;
    enqueued:=enqueued+added;
  end if;

  if enqueued<p_batch_size then
    with candidates as (
      select gen_random_uuid() id,account.id account_id,account.connection_id,
        account.user_id,account.deletion_epoch,resource.resource_type
       from argus_brokerage.accounts account
       join argus_app.members member on member.user_id=account.user_id
        and member.deletion_epoch=account.deletion_epoch and member.status='active'
       join argus_brokerage.connections connection on connection.id=account.connection_id
        and connection.user_id=account.user_id and connection.deletion_epoch=account.deletion_epoch
        and connection.status='connected' and connection.egress_fenced_at is null
       join argus_private.webull_credentials credential on credential.connection_id=connection.id
        and credential.user_id=connection.user_id and credential.deletion_epoch=connection.deletion_epoch
       cross join (values ('account'::text),('balance'),('positions'),('restrictions')) resource(resource_type)
      where credential.access_expires_at>clock_timestamp()
        and coalesce((
          select latest.expires_at from argus_brokerage.projection_generations latest
           where latest.account_id=account.id and latest.resource_type=resource.resource_type
           order by latest.generation desc limit 1
        ),'-infinity'::timestamptz)<=clock_timestamp()
      order by account.id,resource.resource_type limit (p_batch_size-enqueued)
    ), leased as (
      insert into argus_private.projection_refresh_leases(
        id,account_id,connection_id,user_id,deletion_epoch,resource_type,
        lease_token,leased_until,acquired_at
      ) select id,account_id,connection_id,user_id,deletion_epoch,resource_type,
        gen_random_uuid(),clock_timestamp(),clock_timestamp() from candidates
      on conflict (account_id,resource_type) do update
        set id=excluded.id,connection_id=excluded.connection_id,
            user_id=excluded.user_id,deletion_epoch=excluded.deletion_epoch,
            lease_token=excluded.lease_token,leased_until=excluded.leased_until,
            acquired_at=excluded.acquired_at
        where projection_refresh_leases.leased_until<=clock_timestamp()
      returning id,account_id,user_id,deletion_epoch,resource_type
    )
    insert into argus_private.outbox_events(
      user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
    ) select user_id,deletion_epoch,'brokerage_refresh',
      'webull.projection.refresh.requested',id,
      'webull-projection:'||id::text from leased
    on conflict (topic,dedupe_key) do nothing;
    get diagnostics added=row_count;
    enqueued:=enqueued+added;
  end if;
  return enqueued;
end
$$;

alter function argus_private.retained_job_handler(text) owner to postgres;
alter function argus_private.set_worker_event_context(uuid,uuid,uuid) owner to postgres;
alter function argus_private.relay_outbox(integer) owner to postgres;
alter function argus_private.claim_next_argus_job(integer) owner to postgres;
alter function argus_private.claim_webull_token_refresh(uuid,uuid,integer) owner to postgres;
alter function argus_private.mark_webull_refresh_egress_started(uuid,uuid,bigint,integer,uuid) owner to postgres;
alter function argus_private.reset_webull_refresh_before_egress(uuid,uuid,bigint,integer,text,uuid) owner to postgres;
alter function argus_private.release_webull_token_refresh(uuid,uuid) owner to postgres;
alter function argus_private.fence_webull_refresh_outcome(uuid,uuid,bigint,integer,text,text) owner to postgres;
alter function argus_private.commit_webull_token_refresh(
  uuid,uuid,bigint,integer,text,uuid,bigint,integer,bytea,bytea,bytea,
  bytea,bytea,bytea,bytea,bytea,bytea,text,timestamptz,timestamptz
) owner to postgres;
alter function argus_private.claim_webull_projection_refresh(uuid,uuid,uuid,integer) owner to postgres;
alter function argus_private.release_webull_projection_refresh(uuid,uuid,uuid,boolean) owner to postgres;
alter function argus_private.authorize_webull_projection_egress(uuid,uuid,uuid,bigint,integer,text) owner to postgres;
alter function argus_private.mark_webull_reauthorization(uuid,uuid,bigint,integer,text) owner to postgres;
alter function argus_private.commit_webull_projection_refresh(
  uuid,uuid,uuid,bigint,integer,text,text,jsonb,timestamptz,timestamptz,
  timestamptz,text,text
) owner to postgres;
alter function argus_private.claim_webull_command_reconciliation(uuid,uuid) owner to postgres;
alter function argus_private.authorize_webull_reconciliation_egress(uuid,uuid,bigint,integer,text) owner to postgres;
alter function argus_private.record_webull_reconciliation_retry(uuid,uuid,bigint,integer,text,text) owner to postgres;
alter function argus_private.mark_webull_reconciliation_reauthorization(uuid,uuid,bigint,integer,text,text) owner to postgres;
alter function argus_private.commit_webull_reconciliation(
  uuid,uuid,bigint,integer,text,text,uuid,text,numeric,jsonb,timestamptz,
  timestamptz,bytea,text,integer,uuid
) owner to postgres;
alter function argus_private.terminalize_webull_recovery_dead_letter(uuid,text) owner to postgres;
alter function argus_private.disconnect_webull_connection(text,uuid) owner to postgres;
alter function argus_private.fence_webull_member_for_deletion(uuid) owner to postgres;
alter function argus_private.fence_webull_on_tombstone() owner to postgres;
alter function argus_private.prepare_member_purge(uuid) owner to postgres;
alter function argus_private.complete_member_purge(uuid) owner to postgres;
alter function argus_private.enqueue_due_webull_recovery_jobs(integer) owner to postgres;

revoke all on function argus_private.claim_webull_token_refresh(uuid,uuid,integer),
  argus_private.mark_webull_refresh_egress_started(uuid,uuid,bigint,integer,uuid),
  argus_private.reset_webull_refresh_before_egress(uuid,uuid,bigint,integer,text,uuid),
  argus_private.release_webull_token_refresh(uuid,uuid),
  argus_private.fence_webull_refresh_outcome(uuid,uuid,bigint,integer,text,text),
  argus_private.commit_webull_token_refresh(
    uuid,uuid,bigint,integer,text,uuid,bigint,integer,bytea,bytea,bytea,
    bytea,bytea,bytea,bytea,bytea,bytea,text,timestamptz,timestamptz
  ),argus_private.claim_webull_projection_refresh(uuid,uuid,uuid,integer),
  argus_private.release_webull_projection_refresh(uuid,uuid,uuid,boolean),
  argus_private.authorize_webull_projection_egress(uuid,uuid,uuid,bigint,integer,text),
  argus_private.mark_webull_reauthorization(uuid,uuid,bigint,integer,text),
  argus_private.commit_webull_projection_refresh(
    uuid,uuid,uuid,bigint,integer,text,text,jsonb,timestamptz,timestamptz,
    timestamptz,text,text
  ),argus_private.claim_webull_command_reconciliation(uuid,uuid),
  argus_private.authorize_webull_reconciliation_egress(uuid,uuid,bigint,integer,text),
  argus_private.record_webull_reconciliation_retry(uuid,uuid,bigint,integer,text,text),
  argus_private.mark_webull_reconciliation_reauthorization(uuid,uuid,bigint,integer,text,text),
  argus_private.commit_webull_reconciliation(
    uuid,uuid,bigint,integer,text,text,uuid,text,numeric,jsonb,timestamptz,
    timestamptz,bytea,text,integer,uuid
  ),argus_private.terminalize_webull_recovery_dead_letter(uuid,text)
  from public,anon,authenticated,argus_runtime;

grant execute on function argus_private.claim_webull_token_refresh(uuid,uuid,integer),
  argus_private.mark_webull_refresh_egress_started(uuid,uuid,bigint,integer,uuid),
  argus_private.reset_webull_refresh_before_egress(uuid,uuid,bigint,integer,text,uuid),
  argus_private.release_webull_token_refresh(uuid,uuid),
  argus_private.fence_webull_refresh_outcome(uuid,uuid,bigint,integer,text,text),
  argus_private.commit_webull_token_refresh(
    uuid,uuid,bigint,integer,text,uuid,bigint,integer,bytea,bytea,bytea,
    bytea,bytea,bytea,bytea,bytea,bytea,text,timestamptz,timestamptz
  ),argus_private.claim_webull_projection_refresh(uuid,uuid,uuid,integer),
  argus_private.release_webull_projection_refresh(uuid,uuid,uuid,boolean),
  argus_private.authorize_webull_projection_egress(uuid,uuid,uuid,bigint,integer,text),
  argus_private.mark_webull_reauthorization(uuid,uuid,bigint,integer,text),
  argus_private.commit_webull_projection_refresh(
    uuid,uuid,uuid,bigint,integer,text,text,jsonb,timestamptz,timestamptz,
    timestamptz,text,text
  ),argus_private.claim_webull_command_reconciliation(uuid,uuid),
  argus_private.authorize_webull_reconciliation_egress(uuid,uuid,bigint,integer,text),
  argus_private.record_webull_reconciliation_retry(uuid,uuid,bigint,integer,text,text),
  argus_private.mark_webull_reconciliation_reauthorization(uuid,uuid,bigint,integer,text,text),
  argus_private.commit_webull_reconciliation(
    uuid,uuid,bigint,integer,text,text,uuid,text,numeric,jsonb,timestamptz,
    timestamptz,bytea,text,integer,uuid
  ),argus_private.terminalize_webull_recovery_dead_letter(uuid,text)
  to argus_worker;

revoke all on function argus_private.disconnect_webull_connection(text,uuid)
  from public,anon,authenticated,argus_worker;
grant execute on function argus_private.disconnect_webull_connection(text,uuid)
  to argus_runtime;

revoke all on function argus_private.fence_webull_member_for_deletion(uuid),
  argus_private.fence_webull_on_tombstone(),
  argus_private.enqueue_due_webull_recovery_jobs(integer)
from public,anon,authenticated,argus_runtime,argus_worker;

revoke all on argus_private.webull_credentials,
  argus_private.webull_account_mappings,argus_private.webull_order_mappings,
  argus_private.refresh_leases,argus_private.projection_refresh_leases,
  argus_private.provider_commands,argus_private.provider_command_attempts,
  argus_private.reconciliation_records
from argus_worker;

select cron.unschedule(jobid) from cron.job where jobname='argus-webull-recovery-enqueue';
select cron.schedule(
  'argus-webull-recovery-enqueue','* * * * *',
  'select argus_private.enqueue_due_webull_recovery_jobs(25);'
);

comment on function argus_private.claim_webull_command_reconciliation(uuid,uuid) is
  'Returns only existing lookup identifiers and encrypted ownership material; never a reviewed payload or financial execute capability.';
comment on function argus_private.enqueue_due_webull_recovery_jobs(integer) is
  'Bounded read/credential/detail recovery only. This function cannot create a provider command.';

commit;

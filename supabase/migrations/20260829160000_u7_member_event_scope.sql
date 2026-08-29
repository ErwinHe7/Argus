-- Preserve U4/U5 member commands after U6 made lifecycle-scoped events
-- mandatory. Each producer copies identity from its persisted aggregate; the
-- registry trigger remains the fail-closed final check.

begin;

do $membership$
begin
  execute pg_catalog.format(
    'grant argus_app_owner,argus_brokerage_owner to %1$I with inherit true,set true,admin false granted by %1$I',
    current_user
  );
end
$membership$;

-- CREATE OR REPLACE is executed as each function's established domain owner.
-- CREATE on the containing schema exists only for this transaction.
grant create on schema argus_private
  to argus_app_owner,argus_brokerage_owner;

set local role argus_app_owner;

create or replace function argus_private.create_content_report(
  p_target_kind text,p_target_id uuid,p_reason_code text,p_details text
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare retained_user_id uuid;
declare retained_tenant_id uuid;
declare retained_lifecycle_id uuid;
declare retained_epoch bigint;
declare report_record argus_app.content_reports%rowtype;
declare target_editorial uuid;
declare target_asset uuid;
declare target_grimoire uuid;
declare target_template uuid;
declare target_coven uuid;
begin
  select context.user_id,context.tenant_id,context.lifecycle_id
    into retained_user_id,retained_tenant_id,retained_lifecycle_id
    from argus_private.read_trusted_request_context() context;
  select member.deletion_epoch into retained_epoch
    from argus_app.members member
   where member.user_id=retained_user_id
     and member.lifecycle_id=retained_lifecycle_id;
  if retained_epoch is null or p_target_kind not in (
    'editorial','asset','grimoire','circle_template','coven'
  ) or nullif(p_reason_code,'') is null then
    raise exception 'resource_not_found' using errcode='P0002';
  end if;
  if p_target_kind='editorial' then
    select item.id into target_editorial from argus_app.editorial_items item
     where item.id=p_target_id and item.status='published';
  elsif p_target_kind='asset' then
    select asset.id into target_asset from argus_app.catalog_assets asset
     where asset.id=p_target_id and asset.status='active';
  elsif p_target_kind='grimoire' then
    select grimoire.id into target_grimoire from argus_app.grimoires grimoire
    join argus_app.editorial_items item on item.id=grimoire.editorial_item_id
     where grimoire.id=p_target_id and item.status='published';
  elsif p_target_kind='circle_template' then
    select template.id into target_template
      from argus_app.community_templates template
      join argus_app.editorial_items item on item.id=template.editorial_item_id
     where template.id=p_target_id and item.status='published';
  else
    select coven.id into target_coven from argus_app.coven_entries coven
    join argus_app.editorial_items item on item.id=coven.editorial_item_id
     where coven.id=p_target_id and item.status='published';
  end if;
  if pg_catalog.num_nonnulls(
    target_editorial,target_asset,target_grimoire,target_template,target_coven
  )<>1 then
    raise exception 'resource_not_found' using errcode='P0002';
  end if;
  insert into argus_app.content_reports as report(
    user_id,deletion_epoch,tenant_id,lifecycle_id,target_kind,target_id,
    reason_code,details
  ) values (
    retained_user_id,retained_epoch,retained_tenant_id,retained_lifecycle_id,
    p_target_kind,p_target_id,p_reason_code,p_details
  ) returning report.* into report_record;
  insert into argus_app.content_report_targets(
    report_id,tenant_id,lifecycle_id,target_kind,editorial_item_id,asset_id,
    grimoire_id,circle_template_id,coven_entry_id
  ) values (
    report_record.id,report_record.tenant_id,report_record.lifecycle_id,
    p_target_kind,target_editorial,target_asset,target_grimoire,
    target_template,target_coven
  );
  insert into argus_private.outbox_events(
    tenant_id,lifecycle_id,user_id,deletion_epoch,event_version,
    topic,event_type,aggregate_id,dedupe_key
  ) values (
    report_record.tenant_id,report_record.lifecycle_id,report_record.user_id,
    report_record.deletion_epoch,1,'argus_jobs','content-report.created',
    report_record.id,'content-report:'||report_record.id::text
  );
  return report_record.id;
end
$$;

set local role postgres;
set local role argus_brokerage_owner;

create or replace function argus_private.record_provider_command_dispatch_outcome(
  p_command_id uuid,p_state text,p_outcome text,p_reason_code text
)
returns table(
  command_id uuid,account_id uuid,operation text,target_order_id uuid,
  order_id uuid,state text,created_at timestamptz,updated_at timestamptz
)
language plpgsql
security definer
set search_path=''
as $$
declare command_record argus_private.provider_commands%rowtype;
declare next_attempt_number integer;
declare request_user_id uuid;
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
begin
  select context.user_id,context.tenant_id,context.lifecycle_id
    into request_user_id,request_tenant_id,request_lifecycle_id
    from argus_private.read_trusted_request_context() context;
  if p_state not in ('failed','ambiguous')
     or (p_state='failed' and p_outcome<>'terminal_failure')
     or (p_state='ambiguous' and p_outcome<>'ambiguous')
     or p_reason_code !~ '^[a-z][a-z0-9_]{0,63}$' then
    raise exception 'invalid_dispatch_outcome' using errcode='22023';
  end if;
  select command.* into command_record
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.tenant_id=request_tenant_id
     and command.lifecycle_id=request_lifecycle_id
     and command.user_id=request_user_id;
  if command_record.id is null then raise exception 'command_not_found'; end if;
  perform argus_private.lock_brokerage_scope(
    command_record.tenant_id,command_record.lifecycle_id,
    command_record.user_id,command_record.connection_id,
    command_record.account_id
  );
  select command.* into command_record
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.tenant_id=request_tenant_id
     and command.lifecycle_id=request_lifecycle_id
     and command.user_id=request_user_id
     and command.state='dispatching'
   for update;
  if command_record.id is null then raise exception 'command_not_found'; end if;
  update argus_private.provider_commands command
     set state=p_state,updated_at=pg_catalog.clock_timestamp()
   where command.id=command_record.id;
  select coalesce(pg_catalog.max(attempt.attempt_number),0)+1
    into next_attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=command_record.id;
  insert into argus_private.provider_command_attempts(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    command_id,attempt_number,attempt_kind,outcome,provider_error_code
  ) values (
    command_record.tenant_id,command_record.lifecycle_id,
    command_record.user_id,command_record.deletion_epoch,
    command_record.connection_id,command_record.account_id,command_record.id,
    next_attempt_number,'egress',p_outcome,p_reason_code
  );
  if p_state='ambiguous' then
    insert into argus_private.reconciliation_records(
      tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
      command_id,status,next_attempt_at
    ) values (
      command_record.tenant_id,command_record.lifecycle_id,
      command_record.user_id,command_record.deletion_epoch,
      command_record.connection_id,command_record.account_id,
      command_record.id,'pending',pg_catalog.clock_timestamp()
    ) on conflict on constraint reconciliation_records_command_id_key do update
      set status='pending',next_attempt_at=pg_catalog.clock_timestamp(),
          updated_at=pg_catalog.clock_timestamp();
    insert into argus_private.outbox_events(
      tenant_id,lifecycle_id,user_id,deletion_epoch,event_version,
      topic,event_type,aggregate_id,dedupe_key
    ) values (
      command_record.tenant_id,command_record.lifecycle_id,
      command_record.user_id,command_record.deletion_epoch,1,
      'brokerage_reconcile','webull.command.reconciliation.requested',
      command_record.id,'webull-reconcile:'||command_record.id::text
    ) on conflict (topic,dedupe_key) do nothing;
  end if;
  return query
    select command_record.id,command_record.account_id,
           command_record.operation,command_record.target_order_id,
           command_record.order_id,p_state,command_record.created_at,
           pg_catalog.clock_timestamp();
end
$$;

set local role postgres;

comment on function argus_private.create_content_report(text,uuid,text,text) is
  'Creates one typed content report and atomically emits its lifecycle-scoped registered event.';
comment on function argus_private.record_provider_command_dispatch_outcome(uuid,text,text,text) is
  'Records one terminal or ambiguous dispatch outcome; ambiguity atomically emits a lifecycle-scoped reconciliation event.';

-- U5 deliberately prevents a dispatching command from ever being submitted
-- again. Compose a lookup-only recovery source around the existing coordinator
-- so a crash after the durable egress checkpoint cannot strand that command.
set local role argus_brokerage_owner;
alter function argus_private.coordinate_webull_recovery(integer)
  rename to coordinate_registered_webull_work;

create function argus_private.enqueue_stale_provider_command_reconciliation(
  p_batch_size integer default 25
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare enqueued integer;
begin
  if p_batch_size<1 or p_batch_size>25 then
    raise exception 'invalid_batch_size' using errcode='22023';
  end if;
  insert into argus_private.outbox_events(
    tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
    aggregate_id,dedupe_key
  )
  select command.tenant_id,command.lifecycle_id,command.user_id,
    command.deletion_epoch,'brokerage_reconcile',
    'webull.command.reconciliation.requested',1,command.id,
    'webull-reconcile:'||command.id::text
    from argus_private.provider_commands command
    join argus_app.member_lifecycles lifecycle
      on lifecycle.tenant_id=command.tenant_id
     and lifecycle.id=command.lifecycle_id
     and lifecycle.identity_subject_id=command.user_id
     and lifecycle.state='open'
   where command.state='dispatching'
     and command.egress_started_at<=pg_catalog.clock_timestamp()-interval '30 seconds'
     and not exists (
       select 1 from argus_private.outbox_events existing
        where existing.topic='brokerage_reconcile'
          and existing.dedupe_key='webull-reconcile:'||command.id::text
     )
   order by command.egress_started_at,command.id
   limit p_batch_size
  on conflict (topic,dedupe_key) do nothing;
  get diagnostics enqueued=row_count;
  return enqueued;
end
$$;

create function argus_private.coordinate_webull_recovery(
  p_batch_size integer default 25
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare enqueued integer;
begin
  if p_batch_size<1 or p_batch_size>25 then
    raise exception 'invalid_batch_size' using errcode='22023';
  end if;
  if exists (
    select 1 from argus_private.kill_switches
     where name in ('background_workers','provider_egress') and enabled
  ) then
    return 0;
  end if;
  enqueued:=argus_private.enqueue_stale_provider_command_reconciliation(
    p_batch_size
  );
  if enqueued<p_batch_size then
    enqueued:=enqueued+argus_private.coordinate_registered_webull_work(
      p_batch_size-enqueued
    );
  end if;
  return enqueued;
end
$$;

comment on function argus_private.enqueue_stale_provider_command_reconciliation(integer) is
  'Enqueues bounded lookup-only recovery for stale dispatch checkpoints without restoring provider submit authority.';
comment on function argus_private.coordinate_webull_recovery(integer) is
  'Composes stale dispatch recovery ahead of the registered token, reconciliation, and projection work under one batch bound.';

revoke all on function
  argus_private.coordinate_registered_webull_work(integer),
  argus_private.enqueue_stale_provider_command_reconciliation(integer),
  argus_private.coordinate_webull_recovery(integer)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,postgres;
grant execute on function argus_private.coordinate_webull_recovery(integer)
  to postgres;
set local role postgres;

revoke create on schema argus_private
  from argus_app_owner,argus_brokerage_owner;
do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_app_owner,argus_brokerage_owner from %1$I granted by %1$I',
    current_user
  );
end
$membership$;

commit;

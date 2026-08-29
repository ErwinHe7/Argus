-- U6: compose retained jobs, privacy exports, and managed Storage effects.
--
-- External calls are never made by a transaction-bound handler.  Database
-- routines prepare or complete an effect; the Edge worker performs the effect
-- between those committed checkpoints.  Legacy deletion_epoch and payload
-- columns remain grant-free compatibility data until U10, but lifecycle keys
-- are authoritative from this migration forward.

begin;

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_roles where rolname='argus_jobs_owner'
  ) then
    create role argus_jobs_owner
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
end
$$;

-- PostgreSQL requires inherited owner authority for policy and RLS DDL, and
-- SET authority for ownership transfer. U6 touches jobs-owned objects plus
-- existing identity- and application-owned relations, so inherit only those
-- three owners for this transaction. Attribute each temporary membership to
-- this migration role so the grantor-scoped revokes below cannot remove any
-- Supabase-managed membership.
do $membership$
begin
  execute pg_catalog.format(
    'grant argus_jobs_owner,argus_identity_owner,argus_app_owner to %1$I with inherit true,set true,admin false granted by %1$I',
    current_user
  );
end
$membership$;

alter role argus_jobs_owner set statement_timeout='30s';
alter role argus_jobs_owner set lock_timeout='3s';
alter role argus_jobs_owner set idle_in_transaction_session_timeout='15s';
grant usage on schema argus_app,argus_private,extensions,pgmq to argus_jobs_owner;
grant create on schema argus_private to argus_jobs_owner;

-- Retire legacy vocabulary that implied an unattested malware scan.  U6 only
-- performs bounded structural validation (type, dimensions, size, checksum),
-- so both compatibility columns must describe that narrower evidence.
alter table argus_app.media_assets
  drop constraint media_assets_quarantine_status_check;
update argus_app.media_assets
   set quarantine_status=case quarantine_status
     when 'pending' then 'quarantined'
     when 'clear' then 'structurally_verified'
     else quarantine_status
   end;
alter table argus_app.media_assets
  alter column quarantine_status set default 'quarantined',
  add constraint media_assets_quarantine_status_check check (
    quarantine_status in ('quarantined','structurally_verified','rejected')
  );

alter table argus_private.media_upload_intents
  drop constraint media_upload_intents_status_check;
update argus_private.media_upload_intents
   set status='structural_validation' where status='scanning';
alter table argus_private.media_upload_intents
  add constraint media_upload_intents_status_check check (
    status in (
      'pending','uploaded','structural_validation','accepted','rejected','expired'
    )
  );

-- One reviewed registry owns SQL routing, payload compatibility, retry policy,
-- redacted dead-letter behavior, and schedule parity.
create table argus_private.job_event_registry (
  event_type text not null,
  payload_version smallint not null check (payload_version=1),
  topic text not null check (
    topic in ('argus_jobs','brokerage_refresh','brokerage_reconcile')
  ),
  handler_name text not null,
  effect_mode text not null check (effect_mode in ('internal','external_saga')),
  owner_kind text not null check (owner_kind in ('member','global')),
  subject_kind text not null check (
    subject_kind in (
      'briefing','media_upload','content_report','privacy_request','privacy_export_generation',
      'deletion_tombstone','brokerage_connection','brokerage_account',
      'provider_command'
    )
  ),
  max_attempts smallint not null check (max_attempts between 1 and 10),
  visibility_seconds smallint not null check (visibility_seconds between 15 and 55),
  retry_base_seconds smallint not null check (retry_base_seconds between 1 and 300),
  retry_cap_seconds smallint not null check (retry_cap_seconds between retry_base_seconds and 900),
  dead_letter_payload text not null check (dead_letter_payload='redacted'),
  enabled boolean not null default true,
  primary key (event_type,payload_version),
  unique (event_type,handler_name)
);

insert into argus_private.job_event_registry(
  event_type,payload_version,topic,handler_name,effect_mode,owner_kind,
  subject_kind,max_attempts,visibility_seconds,retry_base_seconds,
  retry_cap_seconds,dead_letter_payload
) values
  ('briefing.daily.requested',1,'argus_jobs','briefing-generation-coordinator','internal','member','briefing',5,45,15,900,'redacted'),
  ('briefing.weekly.requested',1,'argus_jobs','briefing-generation-coordinator','internal','member','briefing',5,45,15,900,'redacted'),
  ('briefing.moon_cycle.requested',1,'argus_jobs','briefing-generation-coordinator','internal','member','briefing',5,45,15,900,'redacted'),
  ('briefing.daily.generated',1,'argus_jobs','notification-record-writer','internal','member','briefing',5,45,15,900,'redacted'),
  ('briefing.weekly.generated',1,'argus_jobs','notification-record-writer','internal','member','briefing',5,45,15,900,'redacted'),
  ('briefing.moon_cycle.generated',1,'argus_jobs','notification-record-writer','internal','member','briefing',5,45,15,900,'redacted'),
  ('media.structural_validation.requested',1,'argus_jobs','media-structural-validation','external_saga','member','media_upload',5,45,15,900,'redacted'),
  ('media.quarantine.cleanup',1,'argus_jobs','media-cleanup','external_saga','member','media_upload',5,45,15,900,'redacted'),
  ('content-report.created',1,'argus_jobs','moderation-triage','internal','member','content_report',5,45,15,900,'redacted'),
  ('privacy.export.requested',1,'argus_jobs','privacy-export','external_saga','member','privacy_request',5,45,15,900,'redacted'),
  ('privacy.deletion.requested',1,'argus_jobs','privacy-purge','external_saga','global','deletion_tombstone',10,45,15,900,'redacted'),
  ('privacy.export.retention.requested',1,'argus_jobs','privacy-export-retention','external_saga','member','privacy_export_generation',5,45,15,900,'redacted'),
  ('webull.token.refresh.requested',1,'brokerage_refresh','webull-token-refresh','external_saga','member','brokerage_connection',5,45,15,900,'redacted'),
  ('webull.projection.refresh.requested',1,'brokerage_refresh','webull-projection-refresh','external_saga','member','brokerage_account',5,45,15,900,'redacted'),
  ('webull.command.reconciliation.requested',1,'brokerage_reconcile','webull-reconciliation','external_saga','member','provider_command',4,45,15,900,'redacted');

create table argus_private.job_schedule_registry (
  schedule_name text primary key,
  schedule_expression text not null,
  command text not null,
  coordinator_name text not null,
  max_batch_size smallint not null check (max_batch_size between 1 and 25),
  retained_run_days smallint not null check (retained_run_days between 1 and 30),
  check (command !~* '(pgmq\.|net\.|http|cron\.)')
);

insert into argus_private.job_schedule_registry(
  schedule_name,schedule_expression,command,coordinator_name,max_batch_size,
  retained_run_days
) values
  ('argus-durable-work-coordinate','* * * * *',
   'select argus_private.coordinate_argus_durable_work(25);',
   'coordinate_argus_durable_work',25,7),
  ('argus-worker-dispatch-enqueue','* * * * *',
   'select argus_private.enqueue_worker_dispatch();',
   'enqueue_worker_dispatch',1,7),
  ('argus-webull-recovery-coordinate','*/5 * * * *',
   'select argus_private.coordinate_webull_recovery(25);',
   'coordinate_webull_recovery',25,7);

create or replace function argus_private.reject_registry_mutation()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  raise exception 'job_registry_immutable' using errcode='23514';
end
$$;
alter function argus_private.reject_registry_mutation() owner to argus_jobs_owner;
revoke all on function argus_private.reject_registry_mutation()
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,postgres;

create trigger reject_job_event_registry_mutation
  before update or delete on argus_private.job_event_registry
  for each row execute function argus_private.reject_registry_mutation();
create trigger reject_job_schedule_registry_mutation
  before update or delete on argus_private.job_schedule_registry
  for each row execute function argus_private.reject_registry_mutation();

-- Bind every member-owned retained-work row to both tenant/lifecycle and
-- subject/lifecycle.  Global deletion events deliberately carry no member key.
alter table argus_app.privacy_requests
  add column tenant_id uuid,
  add column lifecycle_id uuid;
update argus_app.privacy_requests request
   set tenant_id=member.tenant_id,lifecycle_id=member.lifecycle_id
  from argus_app.members member where member.user_id=request.user_id;
alter table argus_app.privacy_requests
  alter column tenant_id set not null,
  alter column lifecycle_id set not null,
  add constraint privacy_requests_tenant_lifecycle_fk
    foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  add constraint privacy_requests_subject_lifecycle_fk
    foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict,
  add constraint privacy_requests_scope_unique
    unique (tenant_id,lifecycle_id,user_id,id);
create index privacy_requests_subject_lifecycle_idx
  on argus_app.privacy_requests(user_id,lifecycle_id);

alter table argus_private.outbox_events
  add column event_version smallint not null default 1,
  add column tenant_id uuid,
  add column lifecycle_id uuid;
update argus_private.outbox_events event
   set tenant_id=member.tenant_id,lifecycle_id=member.lifecycle_id
  from argus_app.members member where member.user_id=event.user_id;
update argus_private.outbox_events
   set event_type='media.structural_validation.requested',
       dedupe_key=replace(dedupe_key,'media-scan:','media-structural-validation:')
 where event_type='media.scan.requested';
alter table argus_private.outbox_events
  drop constraint if exists outbox_events_retained_event_type_check,
  drop constraint if exists outbox_events_check,
  add constraint outbox_events_registered_event_fk
    foreign key (event_type,event_version)
    references argus_private.job_event_registry(event_type,payload_version) on delete restrict,
  add constraint outbox_events_scope_check check (
    (user_id is null and tenant_id is null and lifecycle_id is null and deletion_epoch is null)
    or
    (user_id is not null and tenant_id is not null and lifecycle_id is not null)
  ),
  add constraint outbox_events_tenant_lifecycle_fk
    foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  add constraint outbox_events_subject_lifecycle_fk
    foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict,
  add constraint outbox_events_scope_unique
    unique (tenant_id,lifecycle_id,user_id,id);
create index outbox_events_scope_idx
  on argus_private.outbox_events(tenant_id,lifecycle_id,user_id,id);
create index outbox_events_subject_lifecycle_idx
  on argus_private.outbox_events(user_id,lifecycle_id);
create index outbox_events_registry_idx
  on argus_private.outbox_events(event_type,event_version);

create or replace function argus_private.enforce_registered_event_scope()
returns trigger language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
declare registration argus_private.job_event_registry%rowtype;
begin
  select registry.* into registration
    from argus_private.job_event_registry registry
   where registry.event_type=new.event_type
     and registry.payload_version=new.event_version
     and registry.enabled;
  if registration.event_type is null or new.topic<>registration.topic then
    raise exception 'event_registration_mismatch' using errcode='23514';
  end if;
  if registration.owner_kind='member' and (
    new.tenant_id is null or new.lifecycle_id is null or new.user_id is null
  ) then
    raise exception 'member_event_scope_required' using errcode='23514';
  end if;
  if registration.owner_kind='global' and (
    new.tenant_id is not null or new.lifecycle_id is not null or new.user_id is not null
      or new.deletion_epoch is not null
  ) then
    raise exception 'global_event_must_be_unscoped' using errcode='23514';
  end if;
  return new;
end
$$;
alter function argus_private.enforce_registered_event_scope() owner to argus_jobs_owner;
revoke all on function argus_private.enforce_registered_event_scope()
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;
do $$
begin
  if exists (
    select 1 from argus_private.outbox_events event
    join argus_private.job_event_registry registry
      on registry.event_type=event.event_type
     and registry.payload_version=event.event_version
   where event.topic<>registry.topic
      or (registry.owner_kind='member' and event.user_id is null)
      or (registry.owner_kind='global' and event.user_id is not null)
  ) then
    raise exception 'legacy_event_registry_scope_mismatch';
  end if;
end
$$;
create trigger enforce_registered_event_scope
  before insert or update of event_type,event_version,topic,tenant_id,lifecycle_id,user_id,deletion_epoch
  on argus_private.outbox_events
  for each row execute function argus_private.enforce_registered_event_scope();

alter table argus_private.job_runs
  add column tenant_id uuid,
  add column lifecycle_id uuid;
update argus_private.job_runs run
   set tenant_id=event.tenant_id,lifecycle_id=event.lifecycle_id
  from argus_private.outbox_events event where event.id=run.source_event_id;
alter table argus_private.job_runs
  add constraint job_runs_scope_check check (
    (user_id is null and tenant_id is null and lifecycle_id is null and deletion_epoch is null)
    or
    (user_id is not null and tenant_id is not null and lifecycle_id is not null)
  ),
  add constraint job_runs_tenant_lifecycle_fk
    foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  add constraint job_runs_subject_lifecycle_fk
    foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict;
create index job_runs_scope_idx
  on argus_private.job_runs(tenant_id,lifecycle_id,user_id,id);
create index job_runs_subject_lifecycle_idx
  on argus_private.job_runs(user_id,lifecycle_id);

alter table argus_private.consumer_receipts
  add column tenant_id uuid,
  add column lifecycle_id uuid;
-- The retained validator requires a worker-event GUC for ordinary writes.
-- This migration-only scope backfill is derived from the referenced event and
-- is revalidated by the composite foreign key immediately below.
alter table argus_private.consumer_receipts
  disable trigger consumer_receipts_validate;
update argus_private.consumer_receipts receipt
   set tenant_id=event.tenant_id,lifecycle_id=event.lifecycle_id
  from argus_private.outbox_events event where event.id=receipt.outbox_event_id;
alter table argus_private.consumer_receipts
  enable trigger consumer_receipts_validate;
alter table argus_private.consumer_receipts
  add constraint consumer_receipts_scope_check check (
    (user_id is null and tenant_id is null and lifecycle_id is null and deletion_epoch is null)
    or
    (user_id is not null and tenant_id is not null and lifecycle_id is not null)
  ),
  add constraint consumer_receipts_event_scope_fk
    foreign key (tenant_id,lifecycle_id,user_id,outbox_event_id)
    references argus_private.outbox_events(tenant_id,lifecycle_id,user_id,id) on delete cascade;
create index consumer_receipts_event_scope_idx
  on argus_private.consumer_receipts(tenant_id,lifecycle_id,user_id,outbox_event_id);

alter table argus_private.media_upload_intents
  add column tenant_id uuid,
  add column lifecycle_id uuid;
update argus_private.media_upload_intents intent
   set tenant_id=member.tenant_id,lifecycle_id=member.lifecycle_id
  from argus_app.members member where member.user_id=intent.user_id;
alter table argus_private.media_upload_intents
  alter column tenant_id set not null,
  alter column lifecycle_id set not null,
  add constraint media_upload_intents_tenant_lifecycle_fk
    foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  add constraint media_upload_intents_subject_lifecycle_fk
    foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict,
  add constraint media_upload_intents_scope_unique
    unique (tenant_id,lifecycle_id,user_id,id);
create index media_upload_intents_scope_idx
  on argus_private.media_upload_intents(tenant_id,lifecycle_id,user_id,id);
create index media_upload_intents_subject_lifecycle_idx
  on argus_private.media_upload_intents(user_id,lifecycle_id);

alter table argus_private.privacy_export_artifacts
  add column tenant_id uuid,
  add column lifecycle_id uuid;
update argus_private.privacy_export_artifacts artifact
   set tenant_id=member.tenant_id,lifecycle_id=member.lifecycle_id
  from argus_app.members member where member.user_id=artifact.user_id;
alter table argus_private.privacy_export_artifacts
  alter column tenant_id set not null,
  alter column lifecycle_id set not null,
  add constraint privacy_export_artifacts_tenant_lifecycle_fk
    foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  add constraint privacy_export_artifacts_subject_lifecycle_fk
    foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict;
create index privacy_export_artifacts_scope_idx
  on argus_private.privacy_export_artifacts(tenant_id,lifecycle_id,user_id,id);
create index privacy_export_artifacts_subject_lifecycle_idx
  on argus_private.privacy_export_artifacts(user_id,lifecycle_id);

-- Immutable managed object identities are authoritative.  Storage paths are
-- never reused; metadata records the truthful observation and cleanup states.
create table argus_private.managed_storage_objects (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  bucket_id text not null check (
    bucket_id in ('member-media','media-quarantine','privacy-exports')
  ),
  object_path text not null,
  object_kind text not null check (object_kind in ('member_media','privacy_export')),
  state text not null check (
    state in (
      'quarantined','structurally_verified','published','rejected',
      'tombstoned','deletion_pending','deleted','reconciliation'
    )
  ),
  expected_checksum text check (
    expected_checksum is null or expected_checksum ~ '^[a-f0-9]{64}$'
  ),
  observed_checksum text check (
    observed_checksum is null or observed_checksum ~ '^[a-f0-9]{64}$'
  ),
  byte_size bigint check (byte_size is null or byte_size between 1 and 1073741824),
  content_type text not null,
  structurally_verified_at timestamptz,
  published_at timestamptz,
  tombstoned_at timestamptz,
  deleted_at timestamptz,
  reconciliation_code text,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  unique (bucket_id,object_path),
  unique (tenant_id,lifecycle_id,user_id,id),
  foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict,
  -- Pre-U6 objects retain their immutable legacy identity.  New creation
  -- capabilities below require the lifecycle segment as well.
  check (object_path like user_id::text || '/%'),
  check (object_path not like '%..%' and pg_catalog.char_length(object_path)<=549),
  check ((state='published')=(published_at is not null and tombstoned_at is null)),
  check ((state='deleted')=(deleted_at is not null)),
  check (structurally_verified_at is null or object_kind='member_media')
);
create index managed_storage_objects_scope_idx
  on argus_private.managed_storage_objects(tenant_id,lifecycle_id,user_id,id);
create index managed_storage_objects_subject_lifecycle_idx
  on argus_private.managed_storage_objects(user_id,lifecycle_id);
create index managed_storage_objects_reconciliation_idx
  on argus_private.managed_storage_objects(state,updated_at,id)
  where state in ('deletion_pending','reconciliation');

alter table argus_private.media_upload_intents add column storage_object_id uuid;
insert into argus_private.managed_storage_objects(
  tenant_id,lifecycle_id,user_id,bucket_id,object_path,object_kind,state,
  expected_checksum,content_type,structurally_verified_at,published_at,
  created_at,updated_at
)
select intent.tenant_id,intent.lifecycle_id,intent.user_id,intent.bucket_id,
       intent.object_path,
       'member_media',
       case intent.status when 'accepted' then 'published'
         when 'rejected' then 'rejected' else 'quarantined' end,
       asset.checksum,intent.mime_type,
       case when intent.status='accepted' then intent.created_at else null end,
       case when intent.status='accepted' then intent.created_at else null end,
       intent.created_at,pg_catalog.clock_timestamp()
  from argus_private.media_upload_intents intent
  left join argus_app.media_assets asset
    on asset.storage_bucket=intent.bucket_id and asset.storage_path=intent.object_path;
update argus_private.media_upload_intents intent
   set storage_object_id=object.id
  from argus_private.managed_storage_objects object
 where object.tenant_id=intent.tenant_id and object.lifecycle_id=intent.lifecycle_id
   and object.user_id=intent.user_id
   and object.bucket_id=intent.bucket_id and object.object_path=intent.object_path;
alter table argus_private.media_upload_intents
  alter column storage_object_id set not null,
  add constraint media_upload_intents_storage_object_fk
    foreign key (tenant_id,lifecycle_id,user_id,storage_object_id)
    references argus_private.managed_storage_objects(tenant_id,lifecycle_id,user_id,id)
    on delete restrict;
create unique index media_upload_intents_storage_object_unique
  on argus_private.media_upload_intents(storage_object_id);
create index media_upload_intents_storage_scope_idx
  on argus_private.media_upload_intents(
    tenant_id,lifecycle_id,user_id,storage_object_id
  );

alter table argus_app.media_assets
  add column tenant_id uuid,
  add column lifecycle_id uuid,
  add column user_id uuid,
  add column storage_object_id uuid;
update argus_app.media_assets asset
   set tenant_id=object.tenant_id,
       lifecycle_id=object.lifecycle_id,
       user_id=object.user_id,
       storage_object_id=object.id,
       storage_bucket=object.bucket_id
  from argus_private.managed_storage_objects object
 where object.bucket_id=asset.storage_bucket and object.object_path=asset.storage_path
   and object.object_kind='member_media'
   and object.id in (select intent.storage_object_id from argus_private.media_upload_intents intent);
do $$
begin
  if exists (
    select 1 from argus_app.media_assets asset where asset.storage_object_id is null
  ) then
    raise exception 'legacy_media_asset_storage_identity_missing';
  end if;
end
$$;
alter table argus_app.media_assets
  alter column tenant_id set not null,
  alter column lifecycle_id set not null,
  alter column user_id set not null,
  alter column storage_object_id set not null,
  add constraint media_assets_storage_object_fk
    foreign key (tenant_id,lifecycle_id,user_id,storage_object_id)
    references argus_private.managed_storage_objects(tenant_id,lifecycle_id,user_id,id)
    on delete restrict;
create unique index media_assets_storage_object_unique
  on argus_app.media_assets(storage_object_id);
create index media_assets_storage_scope_idx
  on argus_app.media_assets(tenant_id,lifecycle_id,user_id,storage_object_id);

alter table argus_private.privacy_export_artifacts add column storage_object_id uuid;
insert into argus_private.managed_storage_objects(
  tenant_id,lifecycle_id,user_id,bucket_id,object_path,object_kind,state,
  expected_checksum,content_type,published_at,tombstoned_at,created_at,updated_at
)
select artifact.tenant_id,artifact.lifecycle_id,artifact.user_id,
       artifact.bucket_id,artifact.object_path,'privacy_export',
       case when artifact.revoked_at is null then 'published' else 'tombstoned' end,
       case when artifact.checksum ~ '^[a-f0-9]{64}$' then artifact.checksum else null end,
       'application/zip',
       case when artifact.revoked_at is null then artifact.created_at else null end,
       artifact.revoked_at,artifact.created_at,pg_catalog.clock_timestamp()
  from argus_private.privacy_export_artifacts artifact;
update argus_private.privacy_export_artifacts artifact
   set storage_object_id=object.id
  from argus_private.managed_storage_objects object
 where object.tenant_id=artifact.tenant_id and object.lifecycle_id=artifact.lifecycle_id
   and object.user_id=artifact.user_id and object.bucket_id=artifact.bucket_id
   and object.object_path=artifact.object_path;
alter table argus_private.privacy_export_artifacts
  alter column storage_object_id set not null,
  add constraint privacy_export_artifacts_storage_object_fk
    foreign key (tenant_id,lifecycle_id,user_id,storage_object_id)
    references argus_private.managed_storage_objects(tenant_id,lifecycle_id,user_id,id)
    on delete restrict;
create unique index privacy_export_artifacts_storage_object_unique
  on argus_private.privacy_export_artifacts(storage_object_id);
create index privacy_export_artifacts_storage_scope_idx
  on argus_private.privacy_export_artifacts(
    tenant_id,lifecycle_id,user_id,storage_object_id
  );

create table argus_private.external_effects (
  id uuid primary key default extensions.gen_random_uuid(),
  event_id uuid not null references argus_private.outbox_events(id) on delete cascade,
  tenant_id uuid,
  lifecycle_id uuid,
  user_id uuid,
  effect_kind text not null check (
    effect_kind in (
      'media_read','storage_delete','privacy_archive_put','auth_delete'
    )
  ),
  state text not null default 'prepared' check (
    state in ('prepared','effect_unknown','succeeded','failed','reconciliation')
  ),
  idempotency_key uuid not null default extensions.gen_random_uuid(),
  generation_id uuid,
  storage_object_id uuid,
  attempts smallint not null default 0 check (attempts between 0 and 10),
  result_hash text check (result_hash is null or result_hash ~ '^[a-f0-9]{64}$'),
  failure_code text,
  prepared_at timestamptz not null default pg_catalog.clock_timestamp(),
  effect_started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint external_effects_event_kind_generation_unique
    unique nulls not distinct (event_id,effect_kind,generation_id),
  unique (idempotency_key),
  foreign key (tenant_id,lifecycle_id,user_id,event_id)
    references argus_private.outbox_events(tenant_id,lifecycle_id,user_id,id) on delete cascade,
  foreign key (tenant_id,lifecycle_id,user_id,storage_object_id)
    references argus_private.managed_storage_objects(tenant_id,lifecycle_id,user_id,id)
    on delete restrict,
  check (
    (user_id is null and tenant_id is null and lifecycle_id is null)
    or (user_id is not null and tenant_id is not null and lifecycle_id is not null)
  )
);
create index external_effects_recovery_idx
  on argus_private.external_effects(state,updated_at,id)
  where state in ('effect_unknown','failed','reconciliation');
create index external_effects_event_scope_idx
  on argus_private.external_effects(tenant_id,lifecycle_id,user_id,event_id);
create index external_effects_storage_scope_idx
  on argus_private.external_effects(
    tenant_id,lifecycle_id,user_id,storage_object_id
  );
create index external_effects_generation_idx
  on argus_private.external_effects(generation_id);
create index external_effects_generation_scope_idx
  on argus_private.external_effects(tenant_id,lifecycle_id,user_id,generation_id);

create table argus_private.privacy_export_generations (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  request_id uuid not null,
  source_event_id uuid not null,
  generation_number integer not null check (generation_number>0),
  state text not null check (
    state in ('sealing','sealed','assembling','published','failed','retention_pending','deleted','reconciliation')
  ),
  cutoff_at timestamptz not null,
  seal_checksum text check (seal_checksum is null or seal_checksum ~ '^[a-f0-9]{64}$'),
  archive_manifest_checksum text check (
    archive_manifest_checksum is null or archive_manifest_checksum ~ '^[a-f0-9]{64}$'
  ),
  archive_checksum text check (archive_checksum is null or archive_checksum ~ '^[a-f0-9]{64}$'),
  archive_bytes bigint check (archive_bytes is null or archive_bytes>0),
  storage_object_id uuid not null,
  failure_code text,
  sealed_at timestamptz,
  published_at timestamptz,
  failed_at timestamptz,
  expires_at timestamptz not null,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  unique (request_id,generation_number),
  unique (source_event_id,generation_number),
  unique (tenant_id,lifecycle_id,user_id,id),
  foreign key (tenant_id,lifecycle_id,user_id,request_id)
    references argus_app.privacy_requests(tenant_id,lifecycle_id,user_id,id) on delete restrict,
  foreign key (tenant_id,lifecycle_id,user_id,source_event_id)
    references argus_private.outbox_events(tenant_id,lifecycle_id,user_id,id) on delete restrict,
  foreign key (tenant_id,lifecycle_id,user_id,storage_object_id)
    references argus_private.managed_storage_objects(tenant_id,lifecycle_id,user_id,id)
    on delete restrict,
  check ((state='sealing')=(seal_checksum is null)),
  check (state<>'published' or (archive_checksum is not null and published_at is not null))
);
create index privacy_export_generations_scope_idx
  on argus_private.privacy_export_generations(tenant_id,lifecycle_id,user_id,request_id,generation_number);
create index privacy_export_generations_storage_scope_idx
  on argus_private.privacy_export_generations(
    tenant_id,lifecycle_id,user_id,storage_object_id
  );
create index privacy_export_generations_source_event_scope_idx
  on argus_private.privacy_export_generations(
    tenant_id,lifecycle_id,user_id,source_event_id
  );
alter table argus_private.external_effects
  add constraint external_effects_generation_fk
    foreign key (tenant_id,lifecycle_id,user_id,generation_id)
    references argus_private.privacy_export_generations(tenant_id,lifecycle_id,user_id,id)
    on delete cascade;

create table argus_private.privacy_export_generation_rows (
  generation_id uuid not null,
  collection_name text not null,
  ordinal bigint not null check (ordinal>0),
  row_payload jsonb not null check (pg_catalog.jsonb_typeof(row_payload)='object'),
  row_checksum text not null check (row_checksum ~ '^[a-f0-9]{64}$'),
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  primary key (generation_id,collection_name,ordinal),
  foreign key (tenant_id,lifecycle_id,user_id,generation_id)
    references argus_private.privacy_export_generations(tenant_id,lifecycle_id,user_id,id)
    on delete cascade
);
create index privacy_export_generation_rows_page_idx
  on argus_private.privacy_export_generation_rows(generation_id,collection_name,ordinal)
  include (row_checksum);
create index privacy_export_generation_rows_scope_idx
  on argus_private.privacy_export_generation_rows(
    tenant_id,lifecycle_id,user_id,generation_id
  );

create table argus_private.privacy_export_generation_collections (
  generation_id uuid not null,
  collection_name text not null,
  row_count bigint not null check (row_count>=0),
  collection_checksum text not null check (collection_checksum ~ '^[a-f0-9]{64}$'),
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  primary key (generation_id,collection_name),
  foreign key (tenant_id,lifecycle_id,user_id,generation_id)
    references argus_private.privacy_export_generations(tenant_id,lifecycle_id,user_id,id)
    on delete cascade
);
create index privacy_export_generation_collections_scope_idx
  on argus_private.privacy_export_generation_collections(
    tenant_id,lifecycle_id,user_id,generation_id
  );

create table argus_private.privacy_export_generation_objects (
  generation_id uuid not null,
  storage_object_id uuid not null,
  bucket_id text not null,
  object_path text not null,
  content_checksum text not null check (content_checksum ~ '^[a-f0-9]{64}$'),
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  primary key (generation_id,storage_object_id),
  unique (generation_id,bucket_id,object_path),
  foreign key (tenant_id,lifecycle_id,user_id,generation_id)
    references argus_private.privacy_export_generations(tenant_id,lifecycle_id,user_id,id)
    on delete cascade,
  foreign key (tenant_id,lifecycle_id,user_id,storage_object_id)
    references argus_private.managed_storage_objects(tenant_id,lifecycle_id,user_id,id)
    on delete restrict
);
create index privacy_export_generation_objects_storage_idx
  on argus_private.privacy_export_generation_objects(storage_object_id);
create index privacy_export_generation_objects_generation_scope_idx
  on argus_private.privacy_export_generation_objects(
    tenant_id,lifecycle_id,user_id,generation_id
  );
create index privacy_export_generation_objects_storage_scope_idx
  on argus_private.privacy_export_generation_objects(
    tenant_id,lifecycle_id,user_id,storage_object_id
  );

create or replace function argus_private.bind_privacy_generation_child_scope()
returns trigger language plpgsql security invoker set search_path='' as $$
declare generation_record record;
begin
  select generation.tenant_id,generation.lifecycle_id,generation.user_id
    into generation_record
    from argus_private.privacy_export_generations generation
   where generation.id=new.generation_id;
  if generation_record.tenant_id is null then
    raise exception 'privacy_generation_not_found' using errcode='23503';
  end if;
  if (new.tenant_id is not null and new.tenant_id<>generation_record.tenant_id)
     or (new.lifecycle_id is not null and new.lifecycle_id<>generation_record.lifecycle_id)
     or (new.user_id is not null and new.user_id<>generation_record.user_id) then
    raise exception 'privacy_generation_scope_mismatch' using errcode='23514';
  end if;
  new.tenant_id:=generation_record.tenant_id;
  new.lifecycle_id:=generation_record.lifecycle_id;
  new.user_id:=generation_record.user_id;
  return new;
end
$$;
alter function argus_private.bind_privacy_generation_child_scope()
  owner to argus_jobs_owner;
revoke all on function argus_private.bind_privacy_generation_child_scope()
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,postgres;
create trigger bind_privacy_generation_row_scope
  before insert or update on argus_private.privacy_export_generation_rows
  for each row execute function argus_private.bind_privacy_generation_child_scope();
create trigger bind_privacy_generation_collection_scope
  before insert or update on argus_private.privacy_export_generation_collections
  for each row execute function argus_private.bind_privacy_generation_child_scope();
create trigger bind_privacy_generation_object_scope
  before insert or update on argus_private.privacy_export_generation_objects
  for each row execute function argus_private.bind_privacy_generation_child_scope();

create table argus_private.worker_dispatches (
  id uuid primary key default extensions.gen_random_uuid(),
  idempotency_key uuid not null unique default extensions.gen_random_uuid(),
  request_id bigint unique,
  state text not null check (state in ('prepared','enqueued','acknowledged','failed','reconciliation')),
  nonce_hash text not null unique check (nonce_hash ~ '^[a-f0-9]{64}$'),
  scheduled_for timestamptz not null unique,
  enqueued_at timestamptz,
  acknowledged_at timestamptz,
  failure_code text,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp()
);
create index worker_dispatches_recovery_idx
  on argus_private.worker_dispatches(state,updated_at,id)
  where state in ('prepared','failed','reconciliation');

-- All new private relations are FORCE RLS.  Callers receive routines, not
-- direct rows.  The NOLOGIN owner gets an explicit action matrix below.
do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'job_event_registry','job_schedule_registry','managed_storage_objects',
    'external_effects','privacy_export_generations',
    'privacy_export_generation_rows','privacy_export_generation_collections',
    'privacy_export_generation_objects','worker_dispatches'
  ] loop
    execute pg_catalog.format(
      'alter table argus_private.%I owner to argus_jobs_owner',relation_name
    );
    execute pg_catalog.format('alter table argus_private.%I enable row level security',relation_name);
    execute pg_catalog.format('alter table argus_private.%I force row level security',relation_name);
    execute pg_catalog.format(
      'revoke all on argus_private.%I from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker',
      relation_name
    );
  end loop;
end
$$;

-- Read-only registries.
create policy u6_jobs_owner_event_registry_read
  on argus_private.job_event_registry for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_schedule_registry_read
  on argus_private.job_schedule_registry for select to argus_jobs_owner using (true);
grant select on argus_private.job_event_registry,argus_private.job_schedule_registry
  to argus_jobs_owner;

-- Private saga state: exact actions used by reviewed owner routines.
create policy u6_jobs_owner_storage_read on argus_private.managed_storage_objects
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_storage_insert on argus_private.managed_storage_objects
  for insert to argus_jobs_owner with check (true);
create policy u6_jobs_owner_storage_update on argus_private.managed_storage_objects
  for update to argus_jobs_owner using (state<>'deleted') with check (true);
grant select,insert,update on argus_private.managed_storage_objects to argus_jobs_owner;

create policy u6_jobs_owner_effect_read on argus_private.external_effects
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_effect_insert on argus_private.external_effects
  for insert to argus_jobs_owner with check (true);
create policy u6_jobs_owner_effect_update on argus_private.external_effects
  for update to argus_jobs_owner using (state<>'succeeded') with check (true);
grant select,insert,update on argus_private.external_effects to argus_jobs_owner;

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'privacy_export_generations','privacy_export_generation_rows',
    'privacy_export_generation_collections','privacy_export_generation_objects'
  ] loop
    execute pg_catalog.format(
      'create policy u6_jobs_owner_%I_read on argus_private.%I for select to argus_jobs_owner using (true)',
      relation_name,relation_name
    );
    execute pg_catalog.format(
      'create policy u6_jobs_owner_%I_insert on argus_private.%I for insert to argus_jobs_owner with check (true)',
      relation_name,relation_name
    );
    execute pg_catalog.format(
      'grant select,insert on argus_private.%I to argus_jobs_owner',relation_name
    );
  end loop;
end
$$;
create policy u6_jobs_owner_generation_update on argus_private.privacy_export_generations
  for update to argus_jobs_owner using (state<>'deleted') with check (true);
grant update on argus_private.privacy_export_generations to argus_jobs_owner;

create policy u6_jobs_owner_dispatch_read on argus_private.worker_dispatches
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_dispatch_insert on argus_private.worker_dispatches
  for insert to argus_jobs_owner with check (true);
create policy u6_jobs_owner_dispatch_update on argus_private.worker_dispatches
  for update to argus_jobs_owner using (state<>'acknowledged') with check (true);
grant select,insert,update on argus_private.worker_dispatches to argus_jobs_owner;

-- Existing retained-work tables are still postgres-owned.  The composed owner
-- gets only the actions exercised by the U6 routines; workers lose table DML.
create policy u6_jobs_owner_outbox_read on argus_private.outbox_events
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_outbox_insert on argus_private.outbox_events
  for insert to argus_jobs_owner with check (true);
create policy u6_jobs_owner_outbox_update on argus_private.outbox_events
  for update to argus_jobs_owner using (published_at is null) with check (true);
grant select,insert,update on argus_private.outbox_events to argus_jobs_owner;

create policy u6_jobs_owner_job_runs_read on argus_private.job_runs
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_job_runs_insert on argus_private.job_runs
  for insert to argus_jobs_owner with check (true);
create policy u6_jobs_owner_job_runs_update on argus_private.job_runs
  for update to argus_jobs_owner using (status<>'succeeded') with check (true);
grant select,insert,update on argus_private.job_runs to argus_jobs_owner;

create policy u6_jobs_owner_attempt_read on argus_private.job_attempts
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_attempt_insert on argus_private.job_attempts
  for insert to argus_jobs_owner with check (true);
create policy u6_jobs_owner_attempt_update on argus_private.job_attempts
  for update to argus_jobs_owner using (outcome='started') with check (true);
grant select,insert,update on argus_private.job_attempts to argus_jobs_owner;

create policy u6_jobs_owner_dead_letter_read on argus_private.dead_letter_events
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_dead_letter_insert on argus_private.dead_letter_events
  for insert to argus_jobs_owner with check (true);
grant select,insert on argus_private.dead_letter_events to argus_jobs_owner;

create policy u6_jobs_owner_receipt_read on argus_private.consumer_receipts
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_receipt_insert on argus_private.consumer_receipts
  for insert to argus_jobs_owner with check (true);
grant select,insert on argus_private.consumer_receipts to argus_jobs_owner;

create policy u6_jobs_owner_media_intent_read on argus_private.media_upload_intents
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_media_intent_insert on argus_private.media_upload_intents
  for insert to argus_jobs_owner with check (true);
create policy u6_jobs_owner_media_intent_update on argus_private.media_upload_intents
  for update to argus_jobs_owner using (status<>'accepted') with check (true);
grant select,insert,update on argus_private.media_upload_intents to argus_jobs_owner;

create policy u6_jobs_owner_artifact_read on argus_private.privacy_export_artifacts
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_artifact_insert on argus_private.privacy_export_artifacts
  for insert to argus_jobs_owner with check (true);
create policy u6_jobs_owner_artifact_update on argus_private.privacy_export_artifacts
  for update to argus_jobs_owner using (revoked_at is null) with check (true);
grant select,insert,update on argus_private.privacy_export_artifacts to argus_jobs_owner;

create policy u6_jobs_owner_cron_lease_read on argus_private.cron_leases
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_cron_lease_insert on argus_private.cron_leases
  for insert to argus_jobs_owner with check (lease_name='argus-worker');
create policy u6_jobs_owner_cron_lease_update on argus_private.cron_leases
  for update to argus_jobs_owner using (lease_name='argus-worker') with check (lease_name='argus-worker');
grant select,insert,update on argus_private.cron_leases to argus_jobs_owner;

create policy u6_jobs_owner_nonce_read on argus_private.worker_invocation_nonces
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_nonce_insert on argus_private.worker_invocation_nonces
  for insert to argus_jobs_owner with check (true);
create policy u6_jobs_owner_nonce_delete on argus_private.worker_invocation_nonces
  for delete to argus_jobs_owner using (consumed_at<pg_catalog.clock_timestamp()-interval '10 minutes');
grant select,insert,delete on argus_private.worker_invocation_nonces to argus_jobs_owner;

grant select on argus_private.kill_switches to argus_jobs_owner;
grant select on argus_app.member_lifecycles,argus_app.members to argus_jobs_owner;
create policy u6_jobs_owner_lifecycle_read on argus_app.member_lifecycles
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_member_read on argus_app.members
  for select to argus_jobs_owner using (true);

-- pgmq is reachable only by this NOLOGIN adapter owner.  Worker and request
-- roles can execute the higher-level job capabilities below, never pgmq.
revoke all on schema pgmq
from public,anon,authenticated,argus_worker,argus_runtime,argus_member,argus_staff,argus_callback;
revoke all on all tables in schema pgmq
from public,anon,authenticated,argus_worker,argus_runtime,argus_member,argus_staff,argus_callback,argus_jobs_owner;
revoke all on all sequences in schema pgmq
from public,anon,authenticated,argus_worker,argus_runtime,argus_member,argus_staff,argus_callback,argus_jobs_owner;
revoke all on all functions in schema pgmq
from public,anon,authenticated,argus_worker,argus_runtime,argus_member,argus_staff,argus_callback,argus_jobs_owner;
grant usage on schema pgmq to argus_jobs_owner;
grant select,insert,update,delete on pgmq.q_argus_jobs to argus_jobs_owner;
grant select,insert on pgmq.a_argus_jobs to argus_jobs_owner;
grant usage on sequence pgmq.q_argus_jobs_msg_id_seq to argus_jobs_owner;
grant execute on function
  pgmq.format_table_name(text,text),
  pgmq.send(text,jsonb),
  pgmq.send(text,jsonb,jsonb,timestamptz),
  pgmq.read(text,integer,integer,jsonb),
  pgmq.archive(text,bigint),
  pgmq.delete(text,bigint),
  pgmq.set_vt(text,bigint,integer)
to argus_jobs_owner;

create or replace function argus_private.queue_adapter_send(p_event_id uuid)
returns bigint language plpgsql security definer
set search_path=pg_catalog,pgmq as $$
declare message_id bigint;
begin
  select pgmq.send(
    'argus_jobs',pg_catalog.jsonb_build_object('version',1,'event_id',p_event_id)
  ) into message_id;
  return message_id;
end
$$;

create or replace function argus_private.queue_adapter_read(p_visibility_seconds integer)
returns table(message_id bigint,read_count integer,message jsonb)
language sql volatile security definer set search_path=pg_catalog,pgmq as $$
  select queued.msg_id,queued.read_ct,queued.message
    from pgmq.read('argus_jobs',p_visibility_seconds,1) queued
$$;

create or replace function argus_private.queue_adapter_archive(p_message_id bigint)
returns boolean language sql volatile security definer set search_path=pg_catalog,pgmq as $$
  select pgmq.archive('argus_jobs',p_message_id)
$$;

create or replace function argus_private.queue_adapter_delete(p_message_id bigint)
returns boolean language sql volatile security definer set search_path=pg_catalog,pgmq as $$
  select pgmq.delete('argus_jobs',p_message_id)
$$;

create or replace function argus_private.queue_adapter_set_visibility(
  p_message_id bigint,p_visibility_seconds integer
)
returns void language plpgsql volatile security definer
set search_path=pg_catalog,pgmq as $$
begin
  if p_visibility_seconds<0 or p_visibility_seconds>900 then
    raise exception 'invalid_visibility_timeout';
  end if;
  perform pgmq.set_vt('argus_jobs',p_message_id,p_visibility_seconds);
end
$$;

create or replace function argus_private.queue_adapter_metrics()
returns table(queue_depth bigint,oldest_age_seconds bigint)
language sql stable security definer set search_path=pg_catalog,pgmq as $$
  select pg_catalog.count(*)::bigint,
    coalesce(extract(epoch from pg_catalog.clock_timestamp()-min(enqueued_at))::bigint,0)
    from pgmq.q_argus_jobs
$$;

do $$
declare function_signature regprocedure;
begin
  foreach function_signature in array array[
    'argus_private.queue_adapter_send(uuid)'::regprocedure,
    'argus_private.queue_adapter_read(integer)'::regprocedure,
    'argus_private.queue_adapter_archive(bigint)'::regprocedure,
    'argus_private.queue_adapter_delete(bigint)'::regprocedure,
    'argus_private.queue_adapter_set_visibility(bigint,integer)'::regprocedure,
    'argus_private.queue_adapter_metrics()'::regprocedure
  ] loop
    execute pg_catalog.format('alter function %s owner to argus_jobs_owner',function_signature);
    execute pg_catalog.format(
      'revoke all on function %s from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker',
      function_signature
    );
  end loop;
end
$$;

create or replace function argus_private.retained_job_handler(p_event_type text)
returns text language sql stable security definer set search_path=pg_catalog,argus_private as $$
  select registry.handler_name
    from argus_private.job_event_registry registry
   where registry.event_type=p_event_type and registry.payload_version=1 and registry.enabled
$$;

create or replace function argus_private.assert_worker_event_current(p_event_id uuid)
returns boolean language sql stable security definer
set search_path=pg_catalog,argus_private,argus_app as $$
  select case
    when event.event_type='privacy.deletion.requested' then exists (
      select 1 from argus_private.deletion_tombstones tombstone
       where tombstone.id=event.aggregate_id
         and tombstone.status in ('pending','purging','failed','purged')
    )
    when event.user_id is null then true
    else exists (
      select 1 from argus_app.member_lifecycles lifecycle
       where lifecycle.tenant_id=event.tenant_id
         and lifecycle.id=event.lifecycle_id
         and lifecycle.identity_subject_id=event.user_id
         and lifecycle.state='open'
    )
  end
  from argus_private.outbox_events event where event.id=p_event_id
$$;

drop function argus_private.set_worker_event_context(uuid,uuid,uuid);
create function argus_private.set_worker_event_context(
  p_event_id uuid,p_job_run_id uuid,p_lease_token uuid
)
returns table(
  event_type text,aggregate_id uuid,tenant_id uuid,lifecycle_id uuid,user_id uuid
)
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare event_record argus_private.outbox_events%rowtype;
begin
  select event.* into event_record
    from argus_private.outbox_events event
    join argus_private.job_runs run
      on run.source_event_id=event.id
     and run.tenant_id is not distinct from event.tenant_id
     and run.lifecycle_id is not distinct from event.lifecycle_id
     and run.user_id is not distinct from event.user_id
   where event.id=p_event_id and run.id=p_job_run_id
     and run.lease_token=p_lease_token and run.status='leased'
     and run.leased_until>pg_catalog.clock_timestamp()
     and run.handler_name=argus_private.retained_job_handler(event.event_type);
  if event_record.id is null then raise exception 'event_not_found'; end if;
  if not argus_private.assert_worker_event_current(event_record.id) then
    raise exception 'lifecycle_closed';
  end if;
  perform pg_catalog.set_config('argus.worker_event_id',event_record.id::text,true);
  perform pg_catalog.set_config('argus.worker_tenant_id',coalesce(event_record.tenant_id::text,''),true);
  perform pg_catalog.set_config('argus.worker_lifecycle_id',coalesce(event_record.lifecycle_id::text,''),true);
  perform pg_catalog.set_config('argus.worker_user_id',coalesce(event_record.user_id::text,''),true);
  perform pg_catalog.set_config('argus.worker_job_run_id',p_job_run_id::text,true);
  perform pg_catalog.set_config('argus.worker_lease_token',p_lease_token::text,true);
  return query select event_record.event_type,event_record.aggregate_id,
    event_record.tenant_id,event_record.lifecycle_id,event_record.user_id;
end
$$;

create or replace function argus_private.assert_worker_event_execution(p_event_id uuid)
returns boolean language plpgsql stable security definer
set search_path=pg_catalog,argus_private as $$
declare run_text text:=current_setting('argus.worker_job_run_id',true);
declare token_text text:=current_setting('argus.worker_lease_token',true);
begin
  if current_setting('argus.worker_event_id',true) is distinct from p_event_id::text
     or run_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or token_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    return false;
  end if;
  return exists (
    select 1 from argus_private.job_runs run
     where run.id=run_text::uuid and run.source_event_id=p_event_id
       and run.lease_token=token_text::uuid and run.status='leased'
       and run.leased_until>pg_catalog.clock_timestamp()
  );
end
$$;

alter function argus_private.retained_job_handler(text) owner to argus_jobs_owner;
alter function argus_private.assert_worker_event_current(uuid) owner to argus_jobs_owner;
alter function argus_private.set_worker_event_context(uuid,uuid,uuid) owner to argus_jobs_owner;
alter function argus_private.assert_worker_event_execution(uuid) owner to argus_jobs_owner;
revoke all on function argus_private.retained_job_handler(text),
  argus_private.assert_worker_event_current(uuid),
  argus_private.set_worker_event_context(uuid,uuid,uuid),
  argus_private.assert_worker_event_execution(uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback;
grant execute on function argus_private.retained_job_handler(text),
  argus_private.assert_worker_event_current(uuid),
  argus_private.set_worker_event_context(uuid,uuid,uuid)
to argus_worker;

create or replace function argus_private.relay_outbox(p_batch_size integer default 25)
returns integer language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
declare event_record argus_private.outbox_events%rowtype;
declare sent integer:=0;
begin
  if p_batch_size<1 or p_batch_size>25 then raise exception 'invalid_batch_size'; end if;
  if exists (
    select 1 from argus_private.kill_switches
     where name='background_workers' and enabled
  ) then return 0; end if;
  for event_record in
    select event.* from argus_private.outbox_events event
    join argus_private.job_event_registry registry
      on registry.event_type=event.event_type
     and registry.payload_version=event.event_version
     and registry.topic=event.topic and registry.enabled
   where event.published_at is null
     and event.available_at<=pg_catalog.clock_timestamp()
     and (event.topic='argus_jobs' or not exists (
       select 1 from argus_private.kill_switches
        where name='provider_egress' and enabled
     ))
   order by event.available_at,event.id for update of event skip locked
   limit p_batch_size
  loop
    perform argus_private.queue_adapter_send(event_record.id);
    update argus_private.outbox_events
       set published_at=pg_catalog.clock_timestamp(),
           publish_attempts=publish_attempts+1,last_error_code=null
     where id=event_record.id and published_at is null;
    sent:=sent+1;
  end loop;
  return sent;
end
$$;

create or replace function argus_private.dead_letter_queue_message(
  p_message_id bigint,p_event_id uuid,p_handler_name text,
  p_reason_code text,p_diagnostic_hash text
)
returns void language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
begin
  if p_reason_code not in (
    'lifecycle_closed','deletion_epoch_changed','dependency_unavailable','event_not_found',
    'handler_not_allowed','internal_failure','invalid_event_payload',
    'invalid_message_version','lease_expired','media_object_invalid',
    'privacy_export_assembly_failed','privacy_export_manifest_mismatch',
    'privacy_export_source_mismatch','storage_object_checksum_mismatch',
    'storage_object_conflict','storage_object_missing','member_deleted',
    'storage_unavailable','worker_killed'
  ) or p_diagnostic_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'invalid_dead_letter';
  end if;
  insert into argus_private.dead_letter_events(
    outbox_event_id,queue_message_id,handler_name,reason_code,diagnostic_hash
  ) values (p_event_id,p_message_id,p_handler_name,p_reason_code,p_diagnostic_hash);
  perform argus_private.queue_adapter_delete(p_message_id);
end
$$;

drop function argus_private.claim_next_argus_job(integer);
create function argus_private.claim_next_argus_job(p_visibility_seconds integer default 45)
returns table(
  job_run_id uuid,lease_token uuid,queue_message_id bigint,read_count integer,
  event_id uuid,event_type text,handler_name text,aggregate_id uuid,
  tenant_id uuid,lifecycle_id uuid,user_id uuid,deletion_epoch bigint
)
language plpgsql security definer
set search_path=pg_catalog,argus_private,extensions as $$
declare queued record;
declare event_record argus_private.outbox_events%rowtype;
declare registry_record argus_private.job_event_registry%rowtype;
declare parsed_event_id uuid;
declare token uuid;
declare run_id uuid;
declare attempt_number integer;
declare diagnostic text;
begin
  if p_visibility_seconds<15 or p_visibility_seconds>55 then
    raise exception 'invalid_visibility_timeout';
  end if;
  for queued in select * from argus_private.queue_adapter_read(p_visibility_seconds)
  loop
    diagnostic:=pg_catalog.encode(extensions.digest(queued.message::text,'sha256'),'hex');
    if pg_catalog.jsonb_typeof(queued.message)<>'object'
       or (select pg_catalog.count(*) from pg_catalog.jsonb_object_keys(queued.message))<>2
       or not (queued.message?'version' and queued.message?'event_id')
       or queued.message->>'version'<>'1'
       or queued.message->>'event_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
      perform argus_private.dead_letter_queue_message(
        queued.message_id,null,null,'invalid_event_payload',diagnostic
      );
      continue;
    end if;
    parsed_event_id:=(queued.message->>'event_id')::uuid;
    select event.* into event_record from argus_private.outbox_events event
     where event.id=parsed_event_id;
    select registry.* into registry_record
      from argus_private.job_event_registry registry
     where registry.event_type=event_record.event_type
       and registry.payload_version=event_record.event_version
       and registry.topic=event_record.topic and registry.enabled;
    if event_record.id is null or registry_record.event_type is null then
      perform argus_private.dead_letter_queue_message(
        queued.message_id,event_record.id,registry_record.handler_name,
        case when event_record.id is null then 'event_not_found' else 'handler_not_allowed' end,
        diagnostic
      );
      continue;
    end if;
    if exists (
      select 1 from argus_private.consumer_receipts receipt
       where receipt.outbox_event_id=event_record.id
         and receipt.handler_name=registry_record.handler_name
    ) then
      perform argus_private.queue_adapter_archive(queued.message_id);
      continue;
    end if;
    if not argus_private.assert_worker_event_current(event_record.id) then
      perform argus_private.queue_adapter_archive(queued.message_id);
      continue;
    end if;
    token:=extensions.gen_random_uuid();
    insert into argus_private.job_runs(
      tenant_id,lifecycle_id,user_id,deletion_epoch,job_type,source_event_id,
      status,attempts,lease_token,leased_until,queue_message_id,handler_name,
      max_attempts,next_attempt_at
    ) values (
      event_record.tenant_id,event_record.lifecycle_id,event_record.user_id,
      event_record.deletion_epoch,registry_record.handler_name,event_record.id,
      'leased',1,token,
      pg_catalog.clock_timestamp()+pg_catalog.make_interval(secs=>p_visibility_seconds),
      queued.message_id,registry_record.handler_name,registry_record.max_attempts,null
    ) on conflict (source_event_id) where source_event_id is not null do update
      set status='leased',attempts=job_runs.attempts+1,lease_token=excluded.lease_token,
          leased_until=excluded.leased_until,queue_message_id=excluded.queue_message_id,
          handler_name=excluded.handler_name,max_attempts=excluded.max_attempts,
          next_attempt_at=null,updated_at=pg_catalog.clock_timestamp()
      where job_runs.status in ('queued','leased','retry')
        and job_runs.attempts<job_runs.max_attempts
        and (job_runs.leased_until is null or job_runs.leased_until<=pg_catalog.clock_timestamp())
        and (job_runs.next_attempt_at is null or job_runs.next_attempt_at<=pg_catalog.clock_timestamp())
    returning id,attempts into run_id,attempt_number;
    if run_id is null then
      if exists (
        select 1 from argus_private.job_runs existing
         where existing.source_event_id=event_record.id
           and existing.status in ('succeeded','dead_lettered','cancelled')
      ) then
        perform argus_private.queue_adapter_archive(queued.message_id);
      else
        perform argus_private.queue_adapter_set_visibility(queued.message_id,10);
      end if;
      continue;
    end if;
    insert into argus_private.job_attempts(job_run_id,attempt_number,outcome)
    values (run_id,attempt_number,'started')
    on conflict on constraint job_attempts_job_run_id_attempt_number_key do update
      set outcome='started',failure_code=null,diagnostic_hash=null,
          started_at=pg_catalog.clock_timestamp(),completed_at=null;
    return query select run_id,token,queued.message_id,attempt_number,
      event_record.id,event_record.event_type,registry_record.handler_name,
      event_record.aggregate_id,event_record.tenant_id,event_record.lifecycle_id,
      event_record.user_id,event_record.deletion_epoch;
    return;
  end loop;
end
$$;

create or replace function argus_private.complete_argus_job(
  p_job_run_id uuid,p_lease_token uuid,p_effect_hash text
)
returns void language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
declare run_record argus_private.job_runs%rowtype;
begin
  if p_effect_hash !~ '^[a-f0-9]{64}$' then raise exception 'invalid_effect_hash'; end if;
  select run.* into run_record from argus_private.job_runs run
   where run.id=p_job_run_id and run.lease_token=p_lease_token
     and run.status='leased' for update;
  if run_record.id is null then raise exception 'job_lease_lost'; end if;
  if not argus_private.assert_worker_event_current(run_record.source_event_id) then
    raise exception 'lifecycle_closed';
  end if;
  insert into argus_private.consumer_receipts(
    outbox_event_id,handler_name,tenant_id,lifecycle_id,user_id,deletion_epoch,effect_hash
  ) values (
    run_record.source_event_id,run_record.handler_name,run_record.tenant_id,
    run_record.lifecycle_id,run_record.user_id,run_record.deletion_epoch,p_effect_hash
  ) on conflict (outbox_event_id,handler_name) do nothing;
  update argus_private.job_attempts
     set outcome='succeeded',completed_at=pg_catalog.clock_timestamp()
   where job_run_id=run_record.id and attempt_number=run_record.attempts;
  update argus_private.job_runs set status='succeeded',lease_token=null,
    leased_until=null,next_attempt_at=null,last_error_code=null,diagnostic_hash=null,
    updated_at=pg_catalog.clock_timestamp() where id=run_record.id;
  perform argus_private.queue_adapter_archive(run_record.queue_message_id);
end
$$;

create or replace function argus_private.fail_argus_job(
  p_job_run_id uuid,p_lease_token uuid,p_failure_code text,p_diagnostic_hash text
)
returns text language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
declare run_record argus_private.job_runs%rowtype;
declare registry_record argus_private.job_event_registry%rowtype;
declare delay_seconds integer;
begin
  if p_failure_code not in (
    'lifecycle_closed','deletion_epoch_changed','dependency_unavailable','event_not_found',
    'handler_not_allowed','internal_failure','invalid_event_payload',
    'invalid_message_version','lease_expired','media_object_invalid',
    'privacy_export_assembly_failed','privacy_export_manifest_mismatch',
    'privacy_export_source_mismatch','storage_object_checksum_mismatch',
    'storage_object_conflict','storage_object_missing','member_deleted',
    'storage_unavailable','worker_killed'
  ) or p_diagnostic_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'invalid_failure_record';
  end if;
  select run.* into run_record from argus_private.job_runs run
   where run.id=p_job_run_id and run.lease_token=p_lease_token
     and run.status='leased' for update;
  if run_record.id is null then raise exception 'job_lease_lost'; end if;
  select registry.* into registry_record
    from argus_private.outbox_events event
    join argus_private.job_event_registry registry
      on registry.event_type=event.event_type and registry.payload_version=event.event_version
   where event.id=run_record.source_event_id;
  if run_record.attempts>=run_record.max_attempts then
    update argus_private.job_attempts set outcome='dead_lettered',
      failure_code=p_failure_code,diagnostic_hash=p_diagnostic_hash,
      completed_at=pg_catalog.clock_timestamp()
     where job_run_id=run_record.id and attempt_number=run_record.attempts;
    update argus_private.job_runs set status='dead_lettered',lease_token=null,
      leased_until=null,next_attempt_at=null,last_error_code=p_failure_code,
      diagnostic_hash=p_diagnostic_hash,updated_at=pg_catalog.clock_timestamp()
     where id=run_record.id;
    perform argus_private.dead_letter_queue_message(
      run_record.queue_message_id,run_record.source_event_id,run_record.handler_name,
      p_failure_code,p_diagnostic_hash
    );
    return 'dead_lettered';
  end if;
  delay_seconds:=least(
    registry_record.retry_cap_seconds::integer,
    registry_record.retry_base_seconds::integer*(2^greatest(0,run_record.attempts-1))::integer
  );
  update argus_private.job_attempts set outcome='retry',failure_code=p_failure_code,
    diagnostic_hash=p_diagnostic_hash,completed_at=pg_catalog.clock_timestamp()
   where job_run_id=run_record.id and attempt_number=run_record.attempts;
  update argus_private.job_runs set status='retry',lease_token=null,leased_until=null,
    next_attempt_at=pg_catalog.clock_timestamp()+pg_catalog.make_interval(secs=>delay_seconds),
    last_error_code=p_failure_code,diagnostic_hash=p_diagnostic_hash,
    updated_at=pg_catalog.clock_timestamp() where id=run_record.id;
  perform argus_private.queue_adapter_set_visibility(run_record.queue_message_id,delay_seconds);
  return 'retry';
end
$$;

create or replace function argus_private.recover_expired_work(p_batch_size integer default 25)
returns integer language plpgsql security definer
set search_path=pg_catalog,argus_private,extensions as $$
declare run_record argus_private.job_runs%rowtype;
declare recovered integer:=0;
declare outcome text;
declare diagnostic text:=pg_catalog.encode(extensions.digest('lease_expired','sha256'),'hex');
begin
  if p_batch_size<1 or p_batch_size>25 then raise exception 'invalid_batch_size'; end if;
  for run_record in
    select run.* from argus_private.job_runs run
     where run.status='leased' and run.leased_until<pg_catalog.clock_timestamp()
     order by run.leased_until,run.id for update skip locked limit p_batch_size
  loop
    outcome:=argus_private.fail_argus_job(
      run_record.id,run_record.lease_token,'lease_expired',diagnostic
    );
    recovered:=recovered+1;
  end loop;
  return recovered;
end
$$;

create or replace function argus_private.validate_consumer_receipt()
returns trigger language plpgsql security definer
set search_path=pg_catalog,argus_private,extensions as $$
declare event_record argus_private.outbox_events%rowtype;
begin
  select event.* into event_record from argus_private.outbox_events event
   where event.id=new.outbox_event_id;
  if event_record.id is null
     or not argus_private.assert_worker_event_execution(new.outbox_event_id)
     or new.handler_name is distinct from argus_private.retained_job_handler(event_record.event_type)
     or new.tenant_id is distinct from event_record.tenant_id
     or new.lifecycle_id is distinct from event_record.lifecycle_id
     or new.user_id is distinct from event_record.user_id then
    raise exception 'invalid_consumer_receipt';
  end if;
  return new;
end
$$;

do $$
declare function_signature regprocedure;
begin
  foreach function_signature in array array[
    'argus_private.relay_outbox(integer)'::regprocedure,
    'argus_private.dead_letter_queue_message(bigint,uuid,text,text,text)'::regprocedure,
    'argus_private.claim_next_argus_job(integer)'::regprocedure,
    'argus_private.complete_argus_job(uuid,uuid,text)'::regprocedure,
    'argus_private.fail_argus_job(uuid,uuid,text,text)'::regprocedure,
    'argus_private.recover_expired_work(integer)'::regprocedure,
    'argus_private.validate_consumer_receipt()'::regprocedure
  ] loop
    execute pg_catalog.format('alter function %s owner to argus_jobs_owner',function_signature);
    execute pg_catalog.format(
      'revoke all on function %s from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback',
      function_signature
    );
  end loop;
end
$$;
grant execute on function argus_private.relay_outbox(integer),
  argus_private.claim_next_argus_job(integer),
  argus_private.complete_argus_job(uuid,uuid,text),
  argus_private.fail_argus_job(uuid,uuid,text,text),
  argus_private.recover_expired_work(integer)
to argus_worker;
revoke execute on function argus_private.dead_letter_queue_message(bigint,uuid,text,text,text)
from argus_worker;

create or replace function argus_private.list_privacy_export_generation_objects(
  p_generation_id uuid
)
returns table(bucket_id text,object_path text,content_checksum text)
language sql stable security definer set search_path=pg_catalog,argus_private as $$
  select object.bucket_id,object.object_path,object.content_checksum
    from argus_private.privacy_export_generation_objects object
    join argus_private.privacy_export_generations generation
      on generation.id=object.generation_id
   where object.generation_id=p_generation_id
     and generation.state in ('sealed','assembling','published')
     and argus_private.assert_worker_event_execution(generation.source_event_id)
   order by object.storage_object_id
$$;

create or replace function argus_private.read_privacy_export_generation_page(
  p_generation_id uuid,p_collection_name text,p_offset integer,p_limit integer
)
returns table(row_payload jsonb)
language plpgsql stable security definer
set search_path=pg_catalog,argus_private as $$
begin
  if p_offset<0 or p_limit<1 or p_limit>500 then
    raise exception 'invalid_privacy_export_page';
  end if;
  return query
    select row.row_payload
      from argus_private.privacy_export_generation_rows row
      join argus_private.privacy_export_generations generation
        on generation.id=row.generation_id
     where row.generation_id=p_generation_id
       and row.collection_name=p_collection_name
       and generation.state in ('sealed','assembling','published')
       and argus_private.assert_worker_event_execution(generation.source_event_id)
     order by row.ordinal offset p_offset limit p_limit;
end
$$;

create or replace function argus_private.complete_privacy_export_generation(
  p_generation_id uuid,p_seal_checksum text,p_archive_manifest_checksum text,
  p_archive_checksum text,p_archive_bytes bigint
)
returns void language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare generation_record argus_private.privacy_export_generations%rowtype;
declare object_record argus_private.managed_storage_objects%rowtype;
begin
  if p_seal_checksum !~ '^[a-f0-9]{64}$'
     or p_archive_manifest_checksum !~ '^[a-f0-9]{64}$'
     or p_archive_checksum !~ '^[a-f0-9]{64}$'
     or p_archive_bytes<1 or p_archive_bytes>52428800 then
    raise exception 'invalid_privacy_export_completion';
  end if;
  select generation.* into generation_record
    from argus_private.privacy_export_generations generation
   where generation.id=p_generation_id for update;
  if generation_record.id is null then raise exception 'privacy_generation_not_found'; end if;
  if not argus_private.assert_worker_event_execution(generation_record.source_event_id) then
    raise exception 'worker_execution_lost';
  end if;
  if generation_record.state='published' then
    if generation_record.seal_checksum is distinct from p_seal_checksum
       or generation_record.archive_checksum is distinct from p_archive_checksum
       or generation_record.archive_manifest_checksum is distinct from p_archive_manifest_checksum then
      raise exception 'privacy_export_completion_conflict';
    end if;
    return;
  end if;
  if generation_record.state<>'assembling'
     or generation_record.seal_checksum is distinct from p_seal_checksum
     or not argus_private.lock_open_member_lifecycle(
       generation_record.tenant_id,generation_record.lifecycle_id,generation_record.user_id
     ) then raise exception 'lifecycle_closed'; end if;
  select object.* into object_record from argus_private.managed_storage_objects object
   where object.id=generation_record.storage_object_id for update;
  if object_record.state='quarantined' then
    update argus_private.managed_storage_objects set
      state='published',expected_checksum=p_archive_checksum,
      observed_checksum=p_archive_checksum,byte_size=p_archive_bytes,
      published_at=pg_catalog.clock_timestamp(),reconciliation_code=null
     where id=object_record.id;
  elsif object_record.state<>'published'
     or coalesce(object_record.observed_checksum,object_record.expected_checksum)
        is distinct from p_archive_checksum then
    raise exception 'privacy_export_storage_conflict';
  end if;
  update argus_private.privacy_export_generations set state='published',
    archive_manifest_checksum=p_archive_manifest_checksum,
    archive_checksum=p_archive_checksum,archive_bytes=p_archive_bytes,
    published_at=pg_catalog.clock_timestamp(),failure_code=null
   where id=generation_record.id;
  insert into argus_private.privacy_export_artifacts(
    tenant_id,lifecycle_id,user_id,deletion_epoch,request_id,bucket_id,object_path,
    checksum,expires_at,storage_object_id
  ) select generation_record.tenant_id,generation_record.lifecycle_id,
    generation_record.user_id,request.deletion_epoch,generation_record.request_id,
    object_record.bucket_id,object_record.object_path,p_archive_checksum,
    generation_record.expires_at,object_record.id
    from argus_app.privacy_requests request where request.id=generation_record.request_id;
  update argus_app.privacy_requests set status='completed',
    completed_at=pg_catalog.clock_timestamp(),failure_code=null
   where id=generation_record.request_id;
  update argus_private.external_effects set state='succeeded',
    result_hash=p_archive_checksum,completed_at=pg_catalog.clock_timestamp(),failure_code=null
   where event_id=generation_record.source_event_id
     and effect_kind='privacy_archive_put'
     and generation_id=generation_record.id and state<>'succeeded';
end
$$;

create or replace function argus_private.fail_privacy_export_generation(
  p_generation_id uuid,p_failure_code text
)
returns void language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare generation_record argus_private.privacy_export_generations%rowtype;
begin
  if p_failure_code not in (
    'privacy_export_source_mismatch','privacy_export_manifest_mismatch',
    'privacy_export_assembly_failed','storage_object_conflict','storage_unavailable'
  ) then raise exception 'invalid_privacy_export_failure'; end if;
  select generation.* into generation_record
    from argus_private.privacy_export_generations generation
   where generation.id=p_generation_id for update;
  if generation_record.id is null then return; end if;
  if not argus_private.assert_worker_event_execution(generation_record.source_event_id) then
    raise exception 'worker_execution_lost';
  end if;
  if generation_record.state='published' then return; end if;
  update argus_private.privacy_export_generations set state='failed',
    failure_code=p_failure_code,failed_at=pg_catalog.clock_timestamp()
   where id=generation_record.id;
  update argus_private.managed_storage_objects set state='reconciliation',
    reconciliation_code=p_failure_code
   where id=generation_record.storage_object_id and state='quarantined';
  update argus_private.external_effects set state='failed',failure_code=p_failure_code
   where event_id=generation_record.source_event_id
     and effect_kind='privacy_archive_put'
     and generation_id=generation_record.id and state<>'succeeded';
  update argus_app.privacy_requests set status='failed',failure_code=p_failure_code
   where id=generation_record.request_id and status='processing';
end
$$;

create or replace function argus_private.prepare_privacy_export_retention(p_event_id uuid)
returns table(
  generation_id uuid,effect_id uuid,effect_state text,bucket_id text,object_path text
)
language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
declare event_record argus_private.outbox_events%rowtype;
declare generation_record argus_private.privacy_export_generations%rowtype;
declare object_record argus_private.managed_storage_objects%rowtype;
declare effect_record argus_private.external_effects%rowtype;
begin
  select event.* into event_record from argus_private.outbox_events event
   where event.id=p_event_id and event.event_type='privacy.export.retention.requested';
  if event_record.id is null
     or not argus_private.assert_worker_event_execution(p_event_id)
     or not argus_private.lock_open_member_lifecycle(
       event_record.tenant_id,event_record.lifecycle_id,event_record.user_id
     ) then raise exception 'lifecycle_closed'; end if;
  select generation.* into generation_record
    from argus_private.privacy_export_generations generation
   where generation.id=event_record.aggregate_id
     and generation.tenant_id=event_record.tenant_id
     and generation.lifecycle_id=event_record.lifecycle_id
     and generation.user_id=event_record.user_id for update;
  if generation_record.id is null then raise exception 'invalid_event_payload'; end if;
  select object.* into object_record from argus_private.managed_storage_objects object
   where object.id=generation_record.storage_object_id for update;
  if object_record.id is null then raise exception 'invalid_event_payload'; end if;
  if object_record.state='published' then
    update argus_private.managed_storage_objects set state='tombstoned',
      tombstoned_at=pg_catalog.clock_timestamp() where id=object_record.id;
  end if;
  update argus_private.managed_storage_objects set state='deletion_pending'
   where id=object_record.id and state in ('tombstoned','reconciliation');
  update argus_private.privacy_export_generations set state='retention_pending'
   where id=generation_record.id and state in ('published','reconciliation');
  insert into argus_private.external_effects(
    event_id,tenant_id,lifecycle_id,user_id,effect_kind,state,generation_id,storage_object_id,
    attempts,effect_started_at
  ) values (
    event_record.id,event_record.tenant_id,event_record.lifecycle_id,event_record.user_id,
    'storage_delete','effect_unknown',generation_record.id,object_record.id,1,pg_catalog.clock_timestamp()
  ) on conflict on constraint external_effects_event_kind_generation_unique
    do nothing returning * into effect_record;
  if effect_record.id is null then
    select effect.* into effect_record from argus_private.external_effects effect
     where effect.event_id=event_record.id and effect.effect_kind='storage_delete'
       and effect.generation_id=generation_record.id;
  end if;
  return query select generation_record.id,effect_record.id,
    case when object_record.state='deleted' then 'deleted' else effect_record.state end,
    object_record.bucket_id,object_record.object_path;
end
$$;

create or replace function argus_private.complete_privacy_export_retention(p_effect_id uuid)
returns void language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
declare effect_record argus_private.external_effects%rowtype;
begin
  select effect.* into effect_record from argus_private.external_effects effect
   where effect.id=p_effect_id and effect.effect_kind='storage_delete' for update;
  if effect_record.id is null then raise exception 'external_effect_not_found'; end if;
  if not argus_private.assert_worker_event_execution(effect_record.event_id) then
    raise exception 'worker_execution_lost';
  end if;
  update argus_private.managed_storage_objects set state='deleted',
    deleted_at=pg_catalog.clock_timestamp(),reconciliation_code=null
   where id=effect_record.storage_object_id
     and state in ('deletion_pending','reconciliation');
  update argus_private.privacy_export_generations set state='deleted'
   where storage_object_id=effect_record.storage_object_id
     and state in ('retention_pending','reconciliation');
  update argus_private.privacy_export_artifacts set revoked_at=pg_catalog.clock_timestamp()
   where storage_object_id=effect_record.storage_object_id and revoked_at is null;
  update argus_private.external_effects set state='succeeded',
    completed_at=pg_catalog.clock_timestamp(),failure_code=null
   where id=effect_record.id and state<>'succeeded';
end
$$;

create table argus_private.storage_access_leases (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  storage_object_id uuid not null,
  purpose text not null check (purpose='privacy_export_download'),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  unique (tenant_id,lifecycle_id,user_id,id),
  foreign key (tenant_id,lifecycle_id,user_id,storage_object_id)
    references argus_private.managed_storage_objects(tenant_id,lifecycle_id,user_id,id)
    on delete restrict,
  check (expires_at<=created_at+interval '60 seconds')
);
create index storage_access_leases_storage_scope_idx
  on argus_private.storage_access_leases(
    tenant_id,lifecycle_id,user_id,storage_object_id
  );
alter table argus_private.storage_access_leases owner to argus_jobs_owner;
alter table argus_private.storage_access_leases enable row level security;
alter table argus_private.storage_access_leases force row level security;
revoke all on argus_private.storage_access_leases
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;
create policy u6_jobs_owner_access_lease_read on argus_private.storage_access_leases
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_access_lease_insert on argus_private.storage_access_leases
  for insert to argus_jobs_owner with check (true);
create policy u6_jobs_owner_access_lease_update on argus_private.storage_access_leases
  for update to argus_jobs_owner using (consumed_at is null) with check (true);
grant select,insert,update on argus_private.storage_access_leases to argus_jobs_owner;

create or replace function argus_private.request_privacy_export(p_dedupe_key text)
returns uuid language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare context_record record;
declare member_epoch bigint;
declare existing_event argus_private.outbox_events%rowtype;
declare request_id uuid;
begin
  if p_dedupe_key !~ '^[!-~]{16,128}$' then raise exception 'invalid_dedupe_key'; end if;
  select * into context_record from argus_private.read_trusted_request_context();
  if context_record.user_id is null
     or not argus_private.lock_open_member_lifecycle(
       context_record.tenant_id,context_record.lifecycle_id,context_record.user_id
     ) then raise exception 'member_lifecycle_not_open'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_dedupe_key,0));
  select event.* into existing_event from argus_private.outbox_events event
   where event.tenant_id=context_record.tenant_id
     and event.lifecycle_id=context_record.lifecycle_id
     and event.user_id=context_record.user_id
     and event.topic='argus_jobs' and event.dedupe_key=p_dedupe_key;
  if existing_event.id is not null then
    if existing_event.event_type<>'privacy.export.requested' then
      raise exception 'idempotency_conflict';
    end if;
    return existing_event.aggregate_id;
  end if;
  select member.deletion_epoch into member_epoch from argus_app.members member
   where member.tenant_id=context_record.tenant_id
     and member.lifecycle_id=context_record.lifecycle_id
     and member.user_id=context_record.user_id;
  insert into argus_app.privacy_requests(
    tenant_id,lifecycle_id,user_id,deletion_epoch,request_type,status
  ) values (
    context_record.tenant_id,context_record.lifecycle_id,context_record.user_id,
    member_epoch,'export','requested'
  ) returning id into request_id;
  insert into argus_private.outbox_events(
    tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
    aggregate_id,dedupe_key
  ) values (
    context_record.tenant_id,context_record.lifecycle_id,context_record.user_id,
    member_epoch,'argus_jobs','privacy.export.requested',1,request_id,p_dedupe_key
  );
  return request_id;
end
$$;

create or replace function argus_private.list_member_privacy_requests()
returns setof argus_app.privacy_requests language sql stable security definer
set search_path=pg_catalog,argus_private,argus_app as $$
  select request.* from argus_app.privacy_requests request
  join argus_private.read_trusted_request_context() context
    on context.tenant_id=request.tenant_id
   and context.lifecycle_id=request.lifecycle_id
   and context.user_id=request.user_id
  order by request.requested_at desc,request.id desc
$$;

create or replace function argus_private.prepare_privacy_export_download(p_request_id uuid)
returns table(
  access_lease_id uuid,bucket_id text,object_path text,expires_in_seconds integer
)
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,extensions as $$
declare context_record record;
declare object_record argus_private.managed_storage_objects%rowtype;
declare lease_id uuid:=extensions.gen_random_uuid();
begin
  select * into context_record from argus_private.read_trusted_request_context();
  if context_record.user_id is null
     or not argus_private.lock_open_member_lifecycle(
       context_record.tenant_id,context_record.lifecycle_id,context_record.user_id
     ) then raise exception 'member_lifecycle_not_open'; end if;
  select object.* into object_record
    from argus_private.privacy_export_generations generation
    join argus_app.privacy_requests request on request.id=generation.request_id
    join argus_private.managed_storage_objects object
      on object.id=generation.storage_object_id
   where request.id=p_request_id
     and request.tenant_id=context_record.tenant_id
     and request.lifecycle_id=context_record.lifecycle_id
     and request.user_id=context_record.user_id
     and request.status='completed' and generation.state='published'
     and generation.expires_at>pg_catalog.clock_timestamp()
     and object.state='published'
   order by generation.generation_number desc limit 1;
  if object_record.id is null then raise exception 'privacy_export_not_available'; end if;
  insert into argus_private.storage_access_leases(
    id,tenant_id,lifecycle_id,user_id,storage_object_id,purpose,expires_at
  ) values (
    lease_id,context_record.tenant_id,context_record.lifecycle_id,
    context_record.user_id,object_record.id,'privacy_export_download',
    pg_catalog.clock_timestamp()+interval '30 seconds'
  );
  return query select lease_id,object_record.bucket_id,object_record.object_path,30;
end
$$;

create or replace function argus_private.confirm_privacy_export_download(p_access_lease_id uuid)
returns boolean language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
declare context_record record;
begin
  select * into context_record from argus_private.read_trusted_request_context();
  if context_record.user_id is null
     or not argus_private.lock_open_member_lifecycle(
       context_record.tenant_id,context_record.lifecycle_id,context_record.user_id
     ) then return false; end if;
  update argus_private.storage_access_leases lease set consumed_at=pg_catalog.clock_timestamp()
   where lease.id=p_access_lease_id
     and lease.tenant_id=context_record.tenant_id
     and lease.lifecycle_id=context_record.lifecycle_id
     and lease.user_id=context_record.user_id
     and lease.consumed_at is null and lease.expires_at>pg_catalog.clock_timestamp()
     and exists (
       select 1 from argus_private.managed_storage_objects object
        where object.id=lease.storage_object_id and object.state='published'
     );
  return found;
end
$$;

create or replace function argus_private.can_insert_managed_storage_object(
  p_bucket_id text,p_object_path text,p_user_id uuid
)
returns boolean language sql stable security definer
set search_path=pg_catalog,argus_private,argus_app as $$
  select exists (
    select 1 from argus_private.managed_storage_objects object
    join argus_private.media_upload_intents intent on intent.storage_object_id=object.id
    join argus_app.member_lifecycles lifecycle
      on lifecycle.tenant_id=object.tenant_id and lifecycle.id=object.lifecycle_id
     and lifecycle.identity_subject_id=object.user_id
   where object.bucket_id=p_bucket_id and object.object_path=p_object_path
     and object.user_id=p_user_id
     and object.state='quarantined' and intent.status='pending'
     and intent.expires_at>pg_catalog.clock_timestamp() and lifecycle.state='open'
  )
$$;

create or replace function argus_private.can_read_managed_storage_object(
  p_bucket_id text,p_object_path text,p_user_id uuid
)
returns boolean language sql stable security definer
set search_path=pg_catalog,argus_private,argus_app as $$
  select exists (
    select 1 from argus_private.managed_storage_objects object
    join argus_app.member_lifecycles lifecycle
      on lifecycle.tenant_id=object.tenant_id and lifecycle.id=object.lifecycle_id
     and lifecycle.identity_subject_id=object.user_id
   where object.bucket_id=p_bucket_id and object.object_path=p_object_path
     and object.user_id=p_user_id and object.object_kind='member_media'
     and object.state='published' and lifecycle.state='open'
  )
$$;

drop policy if exists argus_member_media_select on storage.objects;
drop policy if exists argus_member_media_insert on storage.objects;
drop policy if exists argus_member_media_update on storage.objects;
drop policy if exists argus_member_media_delete on storage.objects;
drop policy if exists argus_privacy_exports_select on storage.objects;
drop policy if exists argus_u6_managed_media_select on storage.objects;
drop policy if exists argus_u6_managed_media_insert on storage.objects;
create policy argus_u6_managed_media_select on storage.objects
  for select to authenticated using (
    (select argus_private.can_read_managed_storage_object(bucket_id,name,auth.uid()))
  );
create policy argus_u6_managed_media_insert on storage.objects
  for insert to authenticated with check (
    owner_id=(select auth.uid())::text
    and (select argus_private.can_insert_managed_storage_object(bucket_id,name,auth.uid()))
  );
-- The managed Storage API owns its table ACL. Argus confines mutation through
-- this exact RLS policy set instead of trying to rewrite Supabase-owned grants.

do $$
declare function_signature regprocedure;
begin
  foreach function_signature in array array[
    'argus_private.list_privacy_export_generation_objects(uuid)'::regprocedure,
    'argus_private.read_privacy_export_generation_page(uuid,text,integer,integer)'::regprocedure,
    'argus_private.complete_privacy_export_generation(uuid,text,text,text,bigint)'::regprocedure,
    'argus_private.fail_privacy_export_generation(uuid,text)'::regprocedure,
    'argus_private.prepare_privacy_export_retention(uuid)'::regprocedure,
    'argus_private.complete_privacy_export_retention(uuid)'::regprocedure,
    'argus_private.request_privacy_export(text)'::regprocedure,
    'argus_private.list_member_privacy_requests()'::regprocedure,
    'argus_private.prepare_privacy_export_download(uuid)'::regprocedure,
    'argus_private.confirm_privacy_export_download(uuid)'::regprocedure,
    'argus_private.can_insert_managed_storage_object(text,text,uuid)'::regprocedure,
    'argus_private.can_read_managed_storage_object(text,text,uuid)'::regprocedure
  ] loop
    execute pg_catalog.format('alter function %s owner to argus_jobs_owner',function_signature);
    execute pg_catalog.format(
      'revoke all on function %s from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker',
      function_signature
    );
  end loop;
end
$$;
grant execute on function
  argus_private.list_privacy_export_generation_objects(uuid),
  argus_private.read_privacy_export_generation_page(uuid,text,integer,integer),
  argus_private.complete_privacy_export_generation(uuid,text,text,text,bigint),
  argus_private.fail_privacy_export_generation(uuid,text),
  argus_private.prepare_privacy_export_retention(uuid),
  argus_private.complete_privacy_export_retention(uuid)
to argus_worker;
grant execute on function
  argus_private.request_privacy_export(text),
  argus_private.list_member_privacy_requests(),
  argus_private.prepare_privacy_export_download(uuid),
  argus_private.confirm_privacy_export_download(uuid)
to argus_member;
grant execute on function
  argus_private.can_insert_managed_storage_object(text,text,uuid),
  argus_private.can_read_managed_storage_object(text,text,uuid)
to authenticated;

alter table argus_private.deletion_tombstones
  add column tenant_id uuid,
  add column lifecycle_id uuid;
update argus_private.deletion_tombstones tombstone
   set tenant_id=member.tenant_id,lifecycle_id=member.lifecycle_id
  from argus_app.members member where member.user_id=tombstone.user_id;
alter table argus_private.deletion_tombstones
  alter column tenant_id set not null,
  alter column lifecycle_id set not null,
  add constraint deletion_tombstones_tenant_lifecycle_fk
    foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  add constraint deletion_tombstones_subject_lifecycle_fk
    foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict,
  add constraint deletion_tombstones_scope_unique
    unique (tenant_id,lifecycle_id,user_id,id);
create index deletion_tombstones_subject_lifecycle_idx
  on argus_private.deletion_tombstones(user_id,lifecycle_id);

create policy u6_jobs_owner_tombstone_read on argus_private.deletion_tombstones
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_tombstone_insert on argus_private.deletion_tombstones
  for insert to argus_jobs_owner with check (status='pending' and purge_phase='requested');
create policy u6_jobs_owner_tombstone_update on argus_private.deletion_tombstones
  for update to argus_jobs_owner using (status<>'purged') with check (true);
grant select,insert,update on argus_private.deletion_tombstones to argus_jobs_owner;

create policy u6_jobs_owner_step_up_read on argus_private.step_up_receipts
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_step_up_consume on argus_private.step_up_receipts
  for update to argus_jobs_owner using (consumed_at is null) with check (consumed_at is not null);
grant select on argus_private.step_up_receipts to argus_jobs_owner;
grant update(consumed_at) on argus_private.step_up_receipts to argus_jobs_owner;

create policy u6_jobs_owner_member_lifecycle_transition on argus_app.members
  for update to argus_jobs_owner
  using (status in ('active','deletion_pending','purging'))
  with check (status in ('deletion_pending','purging','purged'));
grant update(status,deletion_epoch,deletion_requested_at) on argus_app.members to argus_jobs_owner;

-- The single RLS policy avoids permissive-policy composition.  This trigger
-- preserves the exact state machine instead of accepting the policy's
-- unavoidable old/new Cartesian product.
create or replace function argus_private.protect_member_deletion_transition()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_user<>'argus_jobs_owner' then return new; end if;
  if old.status='active' and new.status='deletion_pending'
     and new.deletion_epoch=old.deletion_epoch+1
     and old.deletion_requested_at is null and new.deletion_requested_at is not null
     and (to_jsonb(new)-array['status','deletion_epoch','deletion_requested_at','updated_at'])
       =(to_jsonb(old)-array['status','deletion_epoch','deletion_requested_at','updated_at']) then
    return new;
  end if;
  if old.status='deletion_pending' and new.status='purging'
     and new.deletion_epoch=old.deletion_epoch
     and new.deletion_requested_at=old.deletion_requested_at
     and (to_jsonb(new)-array['status','updated_at'])
       =(to_jsonb(old)-array['status','updated_at']) then
    return new;
  end if;
  if old.status='purging' and new.status='purged'
     and new.deletion_epoch=old.deletion_epoch
     and new.deletion_requested_at=old.deletion_requested_at
     and (to_jsonb(new)-array['status','updated_at'])
       =(to_jsonb(old)-array['status','updated_at']) then
    return new;
  end if;
  raise exception 'invalid_member_deletion_transition' using errcode='23514';
end
$$;
grant create on schema argus_private to argus_app_owner;
alter function argus_private.protect_member_deletion_transition()
  owner to argus_app_owner;
revoke create on schema argus_private from argus_app_owner;
revoke all on function argus_private.protect_member_deletion_transition()
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,argus_jobs_owner,postgres;
create trigger protect_member_deletion_transition
  before update on argus_app.members
  for each row execute function argus_private.protect_member_deletion_transition();

-- Deletion preparation advances the member epoch before inserting the
-- matching deletion request.  Retain the global live-epoch fence while
-- admitting only that exact, scoped transition row.
create or replace function argus_private.enforce_live_member_epoch()
returns trigger language plpgsql security invoker
set search_path=pg_catalog,argus_app as $$
declare member_epoch bigint;
declare member_status text;
begin
  select deletion_epoch,status into member_epoch,member_status
    from argus_app.members where user_id=new.user_id;
  if member_epoch is not null and member_status='active'
     and new.deletion_epoch=member_epoch then return new; end if;
  if tg_op='INSERT' and tg_table_schema='argus_app'
     and tg_table_name='privacy_requests'
     and member_status='deletion_pending' and member_epoch=new.deletion_epoch
     and to_jsonb(new)->>'request_type'='deletion'
     and to_jsonb(new)->>'status'='queued'
     and to_jsonb(new)->>'tenant_id' is not null
     and to_jsonb(new)->>'lifecycle_id' is not null then
    return new;
  end if;
  if tg_op='UPDATE' and tg_table_schema='argus_brokerage'
     and tg_table_name='connections'
     and member_status in ('deletion_pending','purging')
     and member_epoch=old.deletion_epoch+1
     and new.user_id=old.user_id and new.deletion_epoch=old.deletion_epoch
     and to_jsonb(new)->>'status'='disconnected'
     and to_jsonb(old)->>'status'<>'disconnected'
     and to_jsonb(new)->>'egress_fenced_at' is not null
     and to_jsonb(new)->>'disconnected_at' is not null
     and (to_jsonb(new)-array[
       'status','egress_fenced_at','disconnected_at','last_error_code','updated_at'
     ])=(to_jsonb(old)-array[
       'status','egress_fenced_at','disconnected_at','last_error_code','updated_at'
     ]) then return new; end if;
  if tg_op='UPDATE' and tg_table_schema='argus_app'
     and tg_table_name='privacy_requests'
     and member_status in ('deletion_pending','purging')
     and member_epoch=new.deletion_epoch
     and new.user_id=old.user_id and new.deletion_epoch=old.deletion_epoch
     and to_jsonb(old)->>'request_type'='deletion'
     and to_jsonb(new)->>'request_type'='deletion'
     and to_jsonb(old)->>'status'='failed'
     and to_jsonb(new)->>'status'='queued'
     and to_jsonb(new)->>'failure_code' is null
     and to_jsonb(new)->>'completed_at' is null
     and (to_jsonb(new)-array['status','failure_code','completed_at'])
       =(to_jsonb(old)-array['status','failure_code','completed_at']) then
    return new;
  end if;
  raise exception 'member_deletion_epoch_mismatch';
end
$$;

create or replace function argus_private.begin_member_deletion(
  p_receipt_hash text,p_session_id uuid,p_dedupe_key text
)
returns uuid language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare context_record record;
declare member_record argus_app.members%rowtype;
declare request_id uuid;
declare tombstone_id uuid;
declare receipt_id uuid;
declare next_epoch bigint;
begin
  if p_receipt_hash !~ '^[a-f0-9]{64}$' or p_dedupe_key !~ '^[!-~]{16,128}$' then
    raise exception 'invalid_deletion_request';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('privacy.deletion.requested:' || p_dedupe_key,0)
  );
  select request.id into request_id
    from argus_private.step_up_receipts receipt
    join argus_private.deletion_tombstones tombstone
      on tombstone.user_id=receipt.user_id
     and tombstone.deletion_epoch=receipt.deletion_epoch+1
    join argus_private.outbox_events event
      on event.aggregate_id=tombstone.id
    join argus_app.privacy_requests request
      on request.tenant_id=tombstone.tenant_id
     and request.lifecycle_id=tombstone.lifecycle_id
     and request.user_id=tombstone.user_id and request.request_type='deletion'
   where receipt.receipt_hash=p_receipt_hash and receipt.session_id=p_session_id
     and receipt.action='argus_delete' and receipt.aal='aal2'
     and receipt.consumed_at is not null
     and event.event_type='privacy.deletion.requested' and event.dedupe_key=p_dedupe_key
     and request.deletion_epoch=tombstone.deletion_epoch;
  if request_id is not null then return request_id; end if;
  select * into context_record from argus_private.read_trusted_request_context();
  if context_record.user_id is null or context_record.session_id is distinct from p_session_id
     or context_record.aal<>'aal2' then
    raise exception 'step_up_required' using errcode='42501';
  end if;
  if not argus_private.lock_open_member_lifecycle(
    context_record.tenant_id,context_record.lifecycle_id,context_record.user_id
  ) then
    raise exception 'step_up_required' using errcode='42501';
  end if;
  select member.* into member_record from argus_app.members member
   where member.tenant_id=context_record.tenant_id
     and member.lifecycle_id=context_record.lifecycle_id
     and member.user_id=context_record.user_id and member.status='active' for update;
  if member_record.user_id is null then raise exception 'member_not_active'; end if;
  update argus_private.step_up_receipts receipt set consumed_at=pg_catalog.clock_timestamp()
   where receipt.receipt_hash=p_receipt_hash and receipt.user_id=member_record.user_id
     and receipt.session_id=p_session_id and receipt.deletion_epoch=member_record.deletion_epoch
     and receipt.action='argus_delete' and receipt.aal='aal2'
     and receipt.consumed_at is null and receipt.expires_at>pg_catalog.clock_timestamp()
  returning id into receipt_id;
  if receipt_id is null then raise exception 'step_up_required' using errcode='42501'; end if;
  next_epoch:=member_record.deletion_epoch+1;
  update argus_app.members set status='deletion_pending',deletion_epoch=next_epoch,
    deletion_requested_at=pg_catalog.clock_timestamp()
   where tenant_id=member_record.tenant_id and lifecycle_id=member_record.lifecycle_id
     and user_id=member_record.user_id;
  insert into argus_app.privacy_requests(
    tenant_id,lifecycle_id,user_id,deletion_epoch,request_type,status
  ) values (
    member_record.tenant_id,member_record.lifecycle_id,member_record.user_id,
    next_epoch,'deletion','queued'
  ) returning id into request_id;
  insert into argus_private.deletion_tombstones(
    tenant_id,lifecycle_id,user_id,deletion_epoch,status
  ) values (
    member_record.tenant_id,member_record.lifecycle_id,member_record.user_id,
    next_epoch,'pending'
  ) returning id into tombstone_id;
  insert into argus_private.outbox_events(
    tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
    aggregate_id,dedupe_key
  ) values (
    null,null,null,null,'argus_jobs','privacy.deletion.requested',1,
    tombstone_id,p_dedupe_key
  );
  return request_id;
end
$$;

create or replace function argus_private.get_member_deletion_tombstone()
returns setof argus_private.deletion_tombstones
language sql stable security definer set search_path=pg_catalog,argus_private as $$
  select tombstone.* from argus_private.deletion_tombstones tombstone
  join argus_private.read_trusted_request_context() context
    on context.tenant_id=tombstone.tenant_id
   and context.lifecycle_id=tombstone.lifecycle_id
   and context.user_id=tombstone.user_id
  order by tombstone.requested_at desc limit 1
$$;

alter function argus_private.begin_member_deletion(text,uuid,text) owner to argus_jobs_owner;
alter function argus_private.get_member_deletion_tombstone() owner to argus_jobs_owner;
revoke all on function argus_private.begin_member_deletion(text,uuid,text),
  argus_private.get_member_deletion_tombstone()
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;
grant execute on function argus_private.begin_member_deletion(text,uuid,text),
  argus_private.get_member_deletion_tombstone()
to argus_member;

revoke select,insert,update,delete on
  argus_private.outbox_events,argus_private.job_runs,argus_private.job_attempts,
  argus_private.dead_letter_events,argus_private.consumer_receipts,
  argus_private.media_upload_intents,argus_private.privacy_export_artifacts,
  argus_private.worker_invocation_nonces
from argus_worker;

create table argus_private.privacy_export_collection_registry (
  collection_name text primary key,
  ordinal smallint not null unique check (ordinal>0),
  source_relation regclass not null,
  payload_version smallint not null check (payload_version=1)
);
insert into argus_private.privacy_export_collection_registry values
  ('member',1,'argus_app.members',1),
  ('profile',2,'argus_app.profiles',1),
  ('preferences',3,'argus_app.preferences',1),
  ('astrology_profile',4,'argus_app.astrology_profiles',1),
  ('investor_profile',5,'argus_app.investor_profiles',1),
  ('onboarding',6,'argus_app.onboarding_states',1),
  ('consents',7,'argus_app.consent_records',1),
  ('notification_preferences',8,'argus_app.notification_preferences',1),
  ('ritual_assignments',9,'argus_app.daily_ritual_assignments',1),
  ('circles',10,'argus_app.circles',1),
  ('circle_assets',11,'argus_app.circle_assets',1),
  ('saved_items',12,'argus_app.member_saved_items',1),
  ('intentions',13,'argus_app.intentions',1),
  ('future_mirror_runs',14,'argus_app.future_mirror_runs',1),
  ('future_mirror_points',15,'argus_app.future_mirror_points',1),
  ('briefings',16,'argus_app.briefings',1),
  ('briefing_sections',17,'argus_app.briefing_sections',1),
  ('notifications',18,'argus_app.notifications',1),
  ('privacy_requests',19,'argus_app.privacy_requests',1),
  ('content_reports',20,'argus_app.content_reports',1),
  ('onboarding_step_completions',21,'argus_app.onboarding_step_completions',1),
  ('notification_quiet_hours',22,'argus_app.notification_quiet_hours',1),
  ('briefing_read_states',23,'argus_app.briefing_read_states',1),
  ('content_report_targets',24,'argus_app.content_report_targets',1),
  ('brokerage_connections',25,'argus_brokerage.connections',1),
  ('brokerage_accounts',26,'argus_brokerage.accounts',1),
  ('brokerage_active_account_selections',27,'argus_brokerage.active_account_selections',1),
  ('brokerage_account_capabilities',28,'argus_brokerage.account_capabilities',1),
  ('brokerage_projection_generations',29,'argus_brokerage.projection_generations',1),
  ('brokerage_projection_balance_facts',30,'argus_brokerage.projection_balance_facts',1),
  ('brokerage_projection_position_facts',31,'argus_brokerage.projection_position_facts',1),
  ('brokerage_projection_restriction_facts',32,'argus_brokerage.projection_restriction_facts',1),
  ('brokerage_projection_account_facts',33,'argus_brokerage.projection_account_facts',1),
  ('brokerage_order_projection_generations',34,'argus_brokerage.order_projection_generations',1);
alter table argus_private.privacy_export_collection_registry owner to argus_jobs_owner;
alter table argus_private.privacy_export_collection_registry enable row level security;
alter table argus_private.privacy_export_collection_registry force row level security;
revoke all on argus_private.privacy_export_collection_registry
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;
create policy u6_jobs_owner_privacy_collection_registry_read
  on argus_private.privacy_export_collection_registry
  for select to argus_jobs_owner using (true);
grant select on argus_private.privacy_export_collection_registry to argus_jobs_owner;
create trigger reject_privacy_collection_registry_mutation
  before update or delete on argus_private.privacy_export_collection_registry
  for each row execute function argus_private.reject_registry_mutation();

-- U5 owns brokerage facts. U6 receives one narrow, normalized export port;
-- it never receives table DML, raw snapshots, credentials, provider command
-- history, mappings, refresh leases, or reconciliation internals.
create or replace function argus_private.read_brokerage_privacy_export_rows(
  p_tenant_id uuid,p_lifecycle_id uuid,p_user_id uuid
)
returns table(collection_name text,ordinal bigint,row_payload jsonb)
language sql stable security definer set search_path='' as $$
  select row.collection_name,row.ordinal,row.row_payload from (
    select 'brokerage_connections'::text collection_name,
      pg_catalog.row_number() over(order by connection.id)::bigint ordinal,
      pg_catalog.jsonb_build_object(
        'id',connection.id,'status',connection.status,
        'capability_version',connection.capability_version,
        'authorized_at',connection.authorized_at,
        'disconnected_at',connection.disconnected_at,
        'created_at',connection.created_at
      ) row_payload,25 collection_ordinal
      from argus_brokerage.connections connection
     where connection.tenant_id=p_tenant_id
       and connection.lifecycle_id=p_lifecycle_id and connection.user_id=p_user_id
    union all
    select 'brokerage_accounts',
      pg_catalog.row_number() over(order by account.id)::bigint,
      pg_catalog.jsonb_build_object(
        'id',account.id,'connection_id',account.connection_id,
        'display_label',account.display_label,'base_currency',account.base_currency,
        'market_timezone',account.market_timezone,'status',account.status,
        'capability_version',account.capability_version,
        'provider_observed_at',account.provider_observed_at,
        'fetched_at',account.fetched_at,'expires_at',account.expires_at,
        'capability_normalization_state',account.capability_normalization_state
      ),26
      from argus_brokerage.accounts account
     where account.tenant_id=p_tenant_id
       and account.lifecycle_id=p_lifecycle_id and account.user_id=p_user_id
    union all
    select 'brokerage_active_account_selections',1::bigint,
      pg_catalog.jsonb_build_object(
        'connection_id',selection.connection_id,'account_id',selection.account_id,
        'selected_at',selection.selected_at
      ),27
      from argus_brokerage.active_account_selections selection
     where selection.tenant_id=p_tenant_id
       and selection.lifecycle_id=p_lifecycle_id and selection.user_id=p_user_id
    union all
    select 'brokerage_account_capabilities',
      pg_catalog.row_number() over(
        order by capability.account_id,capability.capability_code
      )::bigint,
      pg_catalog.jsonb_build_object(
        'connection_id',capability.connection_id,'account_id',capability.account_id,
        'capability_code',capability.capability_code,
        'provider_code',capability.provider_code,'available',capability.available,
        'capability_version',capability.capability_version
      ),28
      from argus_brokerage.account_capabilities capability
     where capability.tenant_id=p_tenant_id
       and capability.lifecycle_id=p_lifecycle_id and capability.user_id=p_user_id
    union all
    select 'brokerage_projection_generations',
      pg_catalog.row_number() over(
        order by generation.account_id,generation.resource_type,
          generation.generation,generation.id
      )::bigint,
      pg_catalog.jsonb_build_object(
        'id',generation.id,'connection_id',generation.connection_id,
        'account_id',generation.account_id,'resource_type',generation.resource_type,
        'generation',generation.generation,
        'provider_observed_at',generation.provider_observed_at,
        'fetched_at',generation.fetched_at,'expires_at',generation.expires_at,
        'availability',generation.availability,'created_at',generation.created_at
      ),29
      from argus_brokerage.projection_generations generation
     where generation.tenant_id=p_tenant_id
       and generation.lifecycle_id=p_lifecycle_id and generation.user_id=p_user_id
       and generation.normalization_state='ready'
    union all
    select 'brokerage_projection_balance_facts',
      pg_catalog.row_number() over(
        order by fact.account_id,fact.generation_id
      )::bigint,
      pg_catalog.jsonb_build_object(
        'connection_id',fact.connection_id,'account_id',fact.account_id,
        'generation_id',fact.generation_id,'currency',fact.currency,
        'cash',fact.cash::text,'buying_power',fact.buying_power::text,
        'market_value',fact.market_value::text,'total_equity',fact.total_equity::text
      ),30
      from argus_brokerage.projection_balance_facts fact
     where fact.tenant_id=p_tenant_id
       and fact.lifecycle_id=p_lifecycle_id and fact.user_id=p_user_id
    union all
    select 'brokerage_projection_position_facts',
      pg_catalog.row_number() over(
        order by fact.account_id,fact.generation_id,fact.ordinal
      )::bigint,
      pg_catalog.jsonb_build_object(
        'connection_id',fact.connection_id,'account_id',fact.account_id,
        'generation_id',fact.generation_id,'ordinal',fact.ordinal,
        'instrument_id',fact.instrument_id,'symbol',fact.symbol,
        'display_name',fact.display_name,'asset_kind',fact.asset_kind,
        'provider_asset_kind',fact.provider_asset_kind,'supported',fact.supported,
        'currency',fact.currency,'exchange',fact.exchange,
        'market_timezone',fact.market_timezone,'quantity',fact.quantity::text,
        'available_quantity',fact.available_quantity::text,
        'average_cost',fact.average_cost::text,'market_value',fact.market_value::text
      ),31
      from argus_brokerage.projection_position_facts fact
     where fact.tenant_id=p_tenant_id
       and fact.lifecycle_id=p_lifecycle_id and fact.user_id=p_user_id
    union all
    select 'brokerage_projection_restriction_facts',
      pg_catalog.row_number() over(
        order by fact.account_id,fact.generation_id,fact.ordinal
      )::bigint,
      pg_catalog.jsonb_build_object(
        'connection_id',fact.connection_id,'account_id',fact.account_id,
        'generation_id',fact.generation_id,'ordinal',fact.ordinal,
        'restriction_code',fact.restriction_code,'provider_code',fact.provider_code,
        'active',fact.active,'detail',fact.detail
      ),32
      from argus_brokerage.projection_restriction_facts fact
     where fact.tenant_id=p_tenant_id
       and fact.lifecycle_id=p_lifecycle_id and fact.user_id=p_user_id
    union all
    select 'brokerage_projection_account_facts',
      pg_catalog.row_number() over(
        order by fact.account_id,fact.generation_id
      )::bigint,
      pg_catalog.jsonb_build_object(
        'connection_id',fact.connection_id,'account_id',fact.account_id,
        'generation_id',fact.generation_id,'display_label',fact.display_label,
        'base_currency',fact.base_currency,'market_timezone',fact.market_timezone,
        'account_status',fact.account_status,
        'capability_version',fact.capability_version
      ),33
      from argus_brokerage.projection_account_facts fact
     where fact.tenant_id=p_tenant_id
       and fact.lifecycle_id=p_lifecycle_id and fact.user_id=p_user_id
    union all
    select 'brokerage_order_projection_generations',
      pg_catalog.row_number() over(
        order by generation.account_id,generation.order_id,
          generation.generation,generation.id
      )::bigint,
      pg_catalog.jsonb_build_object(
        'id',generation.id,'connection_id',generation.connection_id,
        'account_id',generation.account_id,'order_id',generation.order_id,
        'generation',generation.generation,'source',generation.source,
        'state',generation.state,'instrument_id',generation.instrument_id,
        'symbol',generation.symbol,'side',generation.side,
        'provider_side',generation.provider_side,
        'order_type',generation.order_type,
        'provider_order_type',generation.provider_order_type,
        'time_in_force',generation.time_in_force,
        'provider_time_in_force',generation.provider_time_in_force,
        'quantity',generation.quantity::text,
        'filled_quantity',generation.filled_quantity::text,
        'limit_price',generation.limit_price::text,
        'stop_price',generation.stop_price::text,
        'average_fill_price',generation.average_fill_price::text,
        'currency',generation.currency,'provider_state',generation.provider_state,
        'terminal',generation.terminal,
        'provider_observed_at',generation.provider_observed_at,
        'fetched_at',generation.fetched_at,'created_at',generation.created_at
      ),34
      from argus_brokerage.order_projection_generations generation
     where generation.tenant_id=p_tenant_id
       and generation.lifecycle_id=p_lifecycle_id and generation.user_id=p_user_id
       and generation.normalization_state='ready'
  ) row
  order by row.collection_ordinal,row.ordinal
$$;
do $membership$
begin
  execute pg_catalog.format(
    'grant argus_brokerage_owner to %1$I with inherit true,set true,admin false granted by %1$I',
    current_user
  );
end
$membership$;
grant create on schema argus_private to argus_brokerage_owner;
alter function argus_private.read_brokerage_privacy_export_rows(uuid,uuid,uuid)
  owner to argus_brokerage_owner;
revoke create on schema argus_private from argus_brokerage_owner;
revoke all on function argus_private.read_brokerage_privacy_export_rows(uuid,uuid,uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,postgres;
grant execute on function argus_private.read_brokerage_privacy_export_rows(uuid,uuid,uuid)
to argus_jobs_owner;
do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_brokerage_owner from %1$I granted by %1$I',current_user
  );
end
$membership$;

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'profiles','preferences','astrology_profiles','investor_profiles',
    'onboarding_states','consent_records','notification_preferences',
    'daily_ritual_assignments','circles','circle_assets','member_saved_items','intentions',
    'future_mirror_runs','future_mirror_points','briefing_sections',
    'onboarding_step_completions','notification_quiet_hours',
    'briefing_read_states','content_report_targets'
  ] loop
    execute pg_catalog.format(
      'create policy u6_jobs_owner_export_%I_read on argus_app.%I for select to argus_jobs_owner using (true)',
      relation_name,relation_name
    );
    execute pg_catalog.format('grant select on argus_app.%I to argus_jobs_owner',relation_name);
  end loop;
end
$$;

create or replace function argus_private.set_privacy_export_row_checksum()
returns trigger language plpgsql security definer
set search_path=pg_catalog,extensions as $$
begin
  new.row_checksum:=pg_catalog.encode(
    extensions.digest(new.row_payload::text,'sha256'),'hex'
  );
  return new;
end
$$;
alter function argus_private.set_privacy_export_row_checksum()
  owner to argus_jobs_owner;
revoke all on function argus_private.set_privacy_export_row_checksum()
  from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
       argus_callback,argus_worker;
create trigger set_privacy_export_row_checksum
  before insert on argus_private.privacy_export_generation_rows
  for each row execute function argus_private.set_privacy_export_row_checksum();

create or replace function argus_private.prepare_privacy_export_generation(p_event_id uuid)
returns table(
  generation_id uuid,generation_number integer,generation_state text,
  tenant_id uuid,lifecycle_id uuid,user_id uuid,request_id uuid,
  cutoff_at timestamptz,seal_checksum text,archive_checksum text,
  storage_object_id uuid,bucket_id text,object_path text
)
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,extensions as $$
declare event_record argus_private.outbox_events%rowtype;
declare request_record argus_app.privacy_requests%rowtype;
declare generation_record argus_private.privacy_export_generations%rowtype;
declare object_record argus_private.managed_storage_objects%rowtype;
declare new_generation_number integer;
declare new_generation_id uuid;
declare new_object_id uuid;
declare new_path text;
declare collection_record record;
begin
  if current_setting('transaction_isolation')<>'repeatable read' then
    raise exception 'privacy_export_requires_repeatable_read';
  end if;
  select event.* into event_record from argus_private.outbox_events event
   where event.id=p_event_id and event.event_type='privacy.export.requested';
  if event_record.id is null
     or not argus_private.assert_worker_event_execution(p_event_id)
     or not argus_private.lock_open_member_lifecycle(
       event_record.tenant_id,event_record.lifecycle_id,event_record.user_id
     ) then raise exception 'lifecycle_closed'; end if;
  select request.* into request_record from argus_app.privacy_requests request
   where request.tenant_id=event_record.tenant_id
     and request.lifecycle_id=event_record.lifecycle_id
     and request.user_id=event_record.user_id
     and request.id=event_record.aggregate_id and request.request_type='export'
   for update;
  if request_record.id is null then raise exception 'invalid_event_payload'; end if;
  select generation.* into generation_record
    from argus_private.privacy_export_generations generation
   where generation.source_event_id=event_record.id
     and generation.state in ('sealed','assembling','published')
   order by generation.generation_number desc limit 1 for update;
  if generation_record.id is not null then
    select object.* into object_record from argus_private.managed_storage_objects object
     where object.id=generation_record.storage_object_id;
    return query select generation_record.id,generation_record.generation_number,
      generation_record.state,generation_record.tenant_id,generation_record.lifecycle_id,
      generation_record.user_id,generation_record.request_id,generation_record.cutoff_at,
      generation_record.seal_checksum,generation_record.archive_checksum,
      object_record.id,object_record.bucket_id,object_record.object_path;
    return;
  end if;
  select coalesce(max(generation.generation_number),0)+1 into new_generation_number
    from argus_private.privacy_export_generations generation
   where generation.request_id=request_record.id;
  new_generation_id:=extensions.gen_random_uuid();
  new_object_id:=extensions.gen_random_uuid();
  new_path:=request_record.user_id::text || '/' || request_record.lifecycle_id::text ||
    '/privacy/' || request_record.id::text || '/' || new_generation_id::text || '.zip';
  insert into argus_private.managed_storage_objects(
    id,tenant_id,lifecycle_id,user_id,bucket_id,object_path,object_kind,state,content_type
  ) values (
    new_object_id,request_record.tenant_id,request_record.lifecycle_id,
    request_record.user_id,'privacy-exports',new_path,'privacy_export',
    'quarantined','application/zip'
  );
  insert into argus_private.privacy_export_generations(
    id,tenant_id,lifecycle_id,user_id,request_id,source_event_id,generation_number,
    state,cutoff_at,storage_object_id,expires_at
  ) values (
    new_generation_id,request_record.tenant_id,request_record.lifecycle_id,
    request_record.user_id,request_record.id,event_record.id,new_generation_number,
    'sealing',pg_catalog.statement_timestamp(),new_object_id,
    pg_catalog.statement_timestamp()+interval '7 days'
  );
  update argus_app.privacy_requests set status='processing',failure_code=null
   where id=request_record.id and status in ('requested','verified','queued','failed');

  insert into argus_private.privacy_export_generation_rows(
    generation_id,collection_name,ordinal,row_payload,row_checksum
  )
  select new_generation_id,'member',1,
    pg_catalog.jsonb_build_object('status',member.status,'created_at',member.created_at),''
    from argus_app.members member
   where member.tenant_id=request_record.tenant_id
     and member.lifecycle_id=request_record.lifecycle_id and member.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'profile',1,
    pg_catalog.jsonb_build_object('display_name',profile.display_name,'avatar_media_id',profile.avatar_media_id,'locale',profile.locale),''
    from argus_app.profiles profile
   where profile.tenant_id=request_record.tenant_id and profile.lifecycle_id=request_record.lifecycle_id and profile.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'preferences',1,
    pg_catalog.jsonb_build_object('theme_mode',preference.theme_mode,'ritual_mode',preference.ritual_mode,'timezone',preference.timezone,'locale',preference.locale,'version',preference.version),''
    from argus_app.preferences preference
   where preference.tenant_id=request_record.tenant_id and preference.lifecycle_id=request_record.lifecycle_id and preference.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'astrology_profile',1,
    pg_catalog.jsonb_build_object('birth_date',profile.birth_date,'derived_profile_code',profile.derived_profile_code,'algorithm_version',profile.algorithm_version,'enabled_at',profile.enabled_at),''
    from argus_app.astrology_profiles profile
   where profile.tenant_id=request_record.tenant_id and profile.lifecycle_id=request_record.lifecycle_id and profile.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'investor_profile',1,
    pg_catalog.jsonb_build_object('goal_type',profile.goal_type,'time_horizon',profile.time_horizon,'risk_comfort',profile.risk_comfort,'version',profile.version),''
    from argus_app.investor_profiles profile
   where profile.tenant_id=request_record.tenant_id and profile.lifecycle_id=request_record.lifecycle_id and profile.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'onboarding',1,
    pg_catalog.jsonb_build_object('current_step',state.current_step,'completed_at',state.completed_at,'version',state.version),''
    from argus_app.onboarding_states state
   where state.tenant_id=request_record.tenant_id and state.lifecycle_id=request_record.lifecycle_id and state.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'consents',
    row_number() over(order by consent.recorded_at,consent.id),
    pg_catalog.jsonb_build_object('policy_code',consent.policy_code,'policy_version',consent.policy_version,'decision',consent.decision,'recorded_at',consent.recorded_at),''
    from argus_app.consent_records consent
   where consent.tenant_id=request_record.tenant_id and consent.lifecycle_id=request_record.lifecycle_id and consent.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'notification_preferences',1,
    pg_catalog.jsonb_build_object('daily_ritual',preference.daily_ritual,'weekly_recap',preference.weekly_recap,'moon_cycle',preference.moon_cycle,'version',preference.version),''
    from argus_app.notification_preferences preference
   where preference.tenant_id=request_record.tenant_id and preference.lifecycle_id=request_record.lifecycle_id and preference.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'ritual_assignments',row_number() over(order by assignment.local_date,assignment.id),
    pg_catalog.jsonb_build_object('id',assignment.id,'local_date',assignment.local_date,'mode',assignment.mode,'state',assignment.state,'revealed_at',assignment.revealed_at,'completed_at',assignment.completed_at),''
    from argus_app.daily_ritual_assignments assignment
   where assignment.tenant_id=request_record.tenant_id and assignment.lifecycle_id=request_record.lifecycle_id and assignment.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'circles',row_number() over(order by circle.id),
    pg_catalog.jsonb_build_object('id',circle.id,'title',circle.title,'description',circle.description,'version',circle.version,'archived_at',circle.archived_at),''
    from argus_app.circles circle
   where circle.tenant_id=request_record.tenant_id and circle.lifecycle_id=request_record.lifecycle_id and circle.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'circle_assets',row_number() over(order by relation.circle_id,relation.ordinal,relation.id),
    pg_catalog.jsonb_build_object('id',relation.id,'circle_id',relation.circle_id,'asset_id',relation.asset_id,'ordinal',relation.ordinal,'weight_bps',relation.weight_bps,'note',relation.note),''
    from argus_app.circle_assets relation
   where relation.tenant_id=request_record.tenant_id and relation.lifecycle_id=request_record.lifecycle_id and relation.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'saved_items',row_number() over(order by saved.saved_at,saved.item_kind,saved.id),
    pg_catalog.jsonb_build_object(
      'id',saved.id,'item_kind',saved.item_kind,
      'item_id',coalesce(saved.asset_id,saved.grimoire_id,saved.circle_template_id,saved.coven_entry_id),
      'source_kind',saved.source_kind,
      'source_ritual_assignment_id',saved.source_ritual_assignment_id,
      'source_circle_id',saved.source_circle_id,
      'source_editorial_item_id',saved.source_editorial_item_id,
      'source_catalog_asset_id',saved.source_catalog_asset_id,
      'saved_at',saved.saved_at
    ),''
    from argus_app.member_saved_items saved
   where saved.tenant_id=request_record.tenant_id and saved.lifecycle_id=request_record.lifecycle_id and saved.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'intentions',row_number() over(order by intention.id),
    pg_catalog.jsonb_build_object('id',intention.id,'title',intention.title,'target_amount_minor',intention.target_amount_minor::text,'currency',intention.currency,'target_date',intention.target_date,'status',intention.status,'version',intention.version,'created_at',intention.created_at),''
    from argus_app.intentions intention
   where intention.tenant_id=request_record.tenant_id and intention.lifecycle_id=request_record.lifecycle_id and intention.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'future_mirror_runs',row_number() over(order by run.id),
    pg_catalog.jsonb_build_object(
      'id',run.id,'intention_id',run.intention_id,'input_hash',run.input_hash,
      'model_version',run.model_version,'assumption_version',run.assumption_version,
      'assumptions',run.assumptions,'status',run.status,'created_at',run.created_at,
      'completed_at',run.completed_at,
      'uncertainty_disclosure',run.uncertainty_disclosure
    ),''
    from argus_app.future_mirror_runs run
   where run.tenant_id=request_record.tenant_id and run.lifecycle_id=request_record.lifecycle_id and run.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'future_mirror_points',row_number() over(order by point.run_id,point.ordinal),
    pg_catalog.jsonb_build_object(
      'run_id',point.run_id,'ordinal',point.ordinal,
      'projected_date',point.projected_date,
      'low_amount_minor',point.low_amount_minor::text,
      'mid_amount_minor',point.mid_amount_minor::text,
      'high_amount_minor',point.high_amount_minor::text
    ),''
    from argus_app.future_mirror_points point
   where point.tenant_id=request_record.tenant_id and point.lifecycle_id=request_record.lifecycle_id and point.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'briefings',row_number() over(order by briefing.id),
    pg_catalog.jsonb_build_object('id',briefing.id,'briefing_type',briefing.briefing_type,'period_start',briefing.period_start,'period_end',briefing.period_end,'status',briefing.status,'generated_at',briefing.generated_at),''
    from argus_app.briefings briefing
   where briefing.tenant_id=request_record.tenant_id and briefing.lifecycle_id=request_record.lifecycle_id and briefing.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'briefing_sections',row_number() over(order by section.briefing_id,section.ordinal),
    pg_catalog.jsonb_build_object('id',section.id,'briefing_id',section.briefing_id,'section_type',section.section_type,'ordinal',section.ordinal,'payload',section.payload),''
    from argus_app.briefing_sections section
   where section.tenant_id=request_record.tenant_id and section.lifecycle_id=request_record.lifecycle_id and section.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'notifications',row_number() over(order by notification.id),
    pg_catalog.jsonb_build_object('id',notification.id,'kind',notification.kind,'title',notification.title,'body',notification.body,'read_at',notification.read_at,'created_at',notification.created_at),''
    from argus_app.notifications notification
   where notification.tenant_id=request_record.tenant_id and notification.lifecycle_id=request_record.lifecycle_id and notification.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'privacy_requests',row_number() over(order by request.id),
    pg_catalog.jsonb_build_object('id',request.id,'request_type',request.request_type,'status',request.status,'requested_at',request.requested_at,'completed_at',request.completed_at,'failure_code',request.failure_code),''
    from argus_app.privacy_requests request
   where request.tenant_id=request_record.tenant_id and request.lifecycle_id=request_record.lifecycle_id and request.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'content_reports',row_number() over(order by report.id),
    pg_catalog.jsonb_build_object('id',report.id,'reason_code',report.reason_code,'details',report.details,'status',report.status,'created_at',report.created_at),''
    from argus_app.content_reports report
   where report.tenant_id=request_record.tenant_id and report.lifecycle_id=request_record.lifecycle_id and report.user_id=request_record.user_id;

  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'onboarding_step_completions',
    row_number() over(order by completion.ordinal,completion.step_code),
    pg_catalog.jsonb_build_object(
      'step_code',completion.step_code,'ordinal',completion.ordinal,
      'completed_at',completion.completed_at
    ),''
    from argus_app.onboarding_step_completions completion
   where completion.tenant_id=request_record.tenant_id
     and completion.lifecycle_id=request_record.lifecycle_id
     and completion.onboarding_user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'notification_quiet_hours',1,
    pg_catalog.jsonb_build_object(
      'timezone_name',quiet.timezone_name,'starts_at',quiet.starts_at,
      'ends_at',quiet.ends_at
    ),''
    from argus_app.notification_quiet_hours quiet
   where quiet.tenant_id=request_record.tenant_id
     and quiet.lifecycle_id=request_record.lifecycle_id
     and quiet.preference_user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'briefing_read_states',
    row_number() over(order by state.briefing_id),
    pg_catalog.jsonb_build_object(
      'briefing_id',state.briefing_id,'read_at',state.read_at,
      'updated_at',state.updated_at
    ),''
    from argus_app.briefing_read_states state
   where state.tenant_id=request_record.tenant_id
     and state.lifecycle_id=request_record.lifecycle_id
     and state.user_id=request_record.user_id;
  insert into argus_private.privacy_export_generation_rows
  select new_generation_id,'content_report_targets',
    row_number() over(order by target.report_id),
    pg_catalog.jsonb_build_object(
      'report_id',target.report_id,'target_kind',target.target_kind,
      'editorial_item_id',target.editorial_item_id,'asset_id',target.asset_id,
      'grimoire_id',target.grimoire_id,
      'circle_template_id',target.circle_template_id,
      'coven_entry_id',target.coven_entry_id
    ),''
    from argus_app.content_report_targets target
   where target.tenant_id=request_record.tenant_id
     and target.lifecycle_id=request_record.lifecycle_id;

  insert into argus_private.privacy_export_generation_rows(
    generation_id,collection_name,ordinal,row_payload,row_checksum
  )
  select new_generation_id,row.collection_name,row.ordinal,row.row_payload,''
    from argus_private.read_brokerage_privacy_export_rows(
      request_record.tenant_id,request_record.lifecycle_id,request_record.user_id
    ) row;

  insert into argus_private.privacy_export_generation_collections(
    generation_id,collection_name,row_count,collection_checksum
  )
  select new_generation_id,registry.collection_name,pg_catalog.count(row.ordinal),
    pg_catalog.encode(extensions.digest(
      coalesce(pg_catalog.string_agg(row.row_checksum,':' order by row.ordinal),'empty'),
      'sha256'
    ),'hex')
    from argus_private.privacy_export_collection_registry registry
    left join argus_private.privacy_export_generation_rows row
      on row.generation_id=new_generation_id
     and row.collection_name=registry.collection_name
   group by registry.ordinal,registry.collection_name
   order by registry.ordinal;

  insert into argus_private.privacy_export_generation_objects(
    generation_id,storage_object_id,bucket_id,object_path,content_checksum
  )
  select new_generation_id,object.id,object.bucket_id,object.object_path,
         coalesce(object.observed_checksum,object.expected_checksum)
    from argus_private.managed_storage_objects object
   where object.tenant_id=request_record.tenant_id
     and object.lifecycle_id=request_record.lifecycle_id
     and object.user_id=request_record.user_id
     and object.state='published'
     and coalesce(object.observed_checksum,object.expected_checksum) is not null
     and object.object_kind='member_media'
   order by object.id;

  update argus_private.privacy_export_generations generation set
    seal_checksum=pg_catalog.encode(extensions.digest(
      pg_catalog.jsonb_build_object(
        'schema_version',1,'tenant_id',generation.tenant_id,
        'lifecycle_id',generation.lifecycle_id,'request_id',generation.request_id,
        'generation_number',generation.generation_number,'cutoff_at',generation.cutoff_at,
        'collections',(
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
            'name',collection.collection_name,'count',collection.row_count,
            'checksum',collection.collection_checksum
          ) order by registry.ordinal)
          from argus_private.privacy_export_generation_collections collection
          join argus_private.privacy_export_collection_registry registry using (collection_name)
          where collection.generation_id=generation.id
        ),
        'objects',coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
            'id',object.storage_object_id,'checksum',object.content_checksum
          ) order by object.storage_object_id)
          from argus_private.privacy_export_generation_objects object
          where object.generation_id=generation.id
        ),'[]'::jsonb)
      )::text,'sha256'
    ),'hex'),state='sealed',sealed_at=pg_catalog.clock_timestamp()
   where generation.id=new_generation_id and generation.state='sealing';
  update argus_private.privacy_export_generations
     set state='assembling' where id=new_generation_id and state='sealed';
  insert into argus_private.external_effects(
    event_id,tenant_id,lifecycle_id,user_id,effect_kind,state,generation_id,storage_object_id,
    attempts,effect_started_at
  ) values (
    event_record.id,event_record.tenant_id,event_record.lifecycle_id,event_record.user_id,
    'privacy_archive_put','effect_unknown',new_generation_id,new_object_id,1,
    pg_catalog.clock_timestamp()
  );
  select generation.* into generation_record
    from argus_private.privacy_export_generations generation
   where generation.id=new_generation_id;
  return query select generation_record.id,generation_record.generation_number,
    generation_record.state,generation_record.tenant_id,generation_record.lifecycle_id,
    generation_record.user_id,generation_record.request_id,generation_record.cutoff_at,
    generation_record.seal_checksum,generation_record.archive_checksum,
    new_object_id,'privacy-exports'::text,new_path;
end
$$;

grant execute on function argus_private.read_trusted_request_context(),
  argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)
to argus_jobs_owner;

create or replace function argus_private.protect_managed_storage_object()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if new.id is distinct from old.id
     or new.tenant_id is distinct from old.tenant_id
     or new.lifecycle_id is distinct from old.lifecycle_id
     or new.user_id is distinct from old.user_id
     or new.bucket_id is distinct from old.bucket_id
     or new.object_path is distinct from old.object_path
     or new.object_kind is distinct from old.object_kind
     or new.content_type is distinct from old.content_type
     or new.created_at is distinct from old.created_at then
    raise exception 'managed_storage_identity_immutable' using errcode='23514';
  end if;
  if old.state='deleted' then
    raise exception 'managed_storage_object_deleted' using errcode='23514';
  end if;
  if (old.state,new.state) not in (
    ('quarantined','quarantined'),('quarantined','structurally_verified'),
    ('quarantined','published'),('quarantined','rejected'),('quarantined','tombstoned'),
    ('quarantined','reconciliation'),
    ('structurally_verified','published'),('structurally_verified','rejected'),
    ('published','published'),('published','tombstoned'),
    ('rejected','rejected'),('rejected','tombstoned'),
    ('tombstoned','deletion_pending'),('deletion_pending','deletion_pending'),
    ('deletion_pending','deleted'),('deletion_pending','reconciliation'),
    ('reconciliation','deletion_pending'),('reconciliation','deleted'),
    ('reconciliation','reconciliation')
  ) then
    raise exception 'invalid_managed_storage_transition' using errcode='23514';
  end if;
  if old.state='quarantined' and new.state='published'
     and old.object_kind<>'privacy_export' then
    raise exception 'managed_storage_verification_required' using errcode='23514';
  end if;
  new.updated_at:=pg_catalog.clock_timestamp();
  return new;
end
$$;
alter function argus_private.protect_managed_storage_object()
  owner to argus_jobs_owner;
revoke all on function argus_private.protect_managed_storage_object()
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,postgres;
create trigger protect_managed_storage_object
  before update on argus_private.managed_storage_objects
  for each row execute function argus_private.protect_managed_storage_object();

create or replace function argus_private.protect_privacy_generation_payload()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if old.state<>'sealing' and (
    new.id is distinct from old.id
    or new.tenant_id is distinct from old.tenant_id
    or new.lifecycle_id is distinct from old.lifecycle_id
    or new.user_id is distinct from old.user_id
    or new.request_id is distinct from old.request_id
    or new.source_event_id is distinct from old.source_event_id
    or new.generation_number is distinct from old.generation_number
    or new.cutoff_at is distinct from old.cutoff_at
    or new.seal_checksum is distinct from old.seal_checksum
    or new.storage_object_id is distinct from old.storage_object_id
    or new.sealed_at is distinct from old.sealed_at
    or new.created_at is distinct from old.created_at
  ) then
    raise exception 'sealed_privacy_generation_immutable' using errcode='23514';
  end if;
  if old.state in ('published','deleted') and new is distinct from old then
    raise exception 'terminal_privacy_generation_immutable' using errcode='23514';
  end if;
  new.updated_at:=pg_catalog.clock_timestamp();
  return new;
end
$$;
alter function argus_private.protect_privacy_generation_payload()
  owner to argus_jobs_owner;
revoke all on function argus_private.protect_privacy_generation_payload()
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,postgres;
create trigger protect_privacy_generation_payload
  before update on argus_private.privacy_export_generations
  for each row execute function argus_private.protect_privacy_generation_payload();

create or replace function argus_private.reject_sealed_export_row_mutation()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if exists (
    select 1 from argus_private.privacy_export_generations generation
     where generation.id=case when tg_op='DELETE' then old.generation_id else new.generation_id end
       and generation.state<>'sealing'
  ) then
    raise exception 'sealed_privacy_generation_immutable' using errcode='23514';
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end
$$;
alter function argus_private.reject_sealed_export_row_mutation()
  owner to argus_jobs_owner;
revoke all on function argus_private.reject_sealed_export_row_mutation()
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,postgres;
create trigger protect_privacy_generation_rows
  before update or delete on argus_private.privacy_export_generation_rows
  for each row execute function argus_private.reject_sealed_export_row_mutation();
create trigger protect_privacy_generation_collections
  before update or delete on argus_private.privacy_export_generation_collections
  for each row execute function argus_private.reject_sealed_export_row_mutation();
create trigger protect_privacy_generation_objects
  before update or delete on argus_private.privacy_export_generation_objects
  for each row execute function argus_private.reject_sealed_export_row_mutation();

-- User-facing media commands are narrow capabilities.  Authenticated clients
-- may upload only the newly allocated quarantine identity, never upsert it.
create or replace function argus_private.create_media_upload_intent(
  p_mime_type text,p_max_bytes bigint,p_expires_at timestamptz
)
returns table(
  intent_id uuid,storage_object_id uuid,bucket_id text,object_path text,
  mime_type text,max_bytes bigint,expires_at timestamptz,status text
)
language plpgsql security definer
set search_path=pg_catalog,argus_private,extensions as $$
declare context_record record;
declare object_id uuid:=extensions.gen_random_uuid();
declare new_intent_id uuid:=extensions.gen_random_uuid();
declare new_path text;
begin
  select * into context_record from argus_private.read_trusted_request_context();
  if context_record.user_id is null
     or not argus_private.lock_open_member_lifecycle(
       context_record.tenant_id,context_record.lifecycle_id,context_record.user_id
     ) then raise exception 'member_lifecycle_not_open'; end if;
  if p_mime_type not in ('image/jpeg','image/png','image/webp')
     or p_max_bytes<1 or p_max_bytes>10485760
     or p_expires_at<=pg_catalog.clock_timestamp()
     or p_expires_at>pg_catalog.clock_timestamp()+interval '1 hour' then
    raise exception 'invalid_media_upload_intent';
  end if;
  new_path:=context_record.user_id::text || '/' || context_record.lifecycle_id::text ||
    '/' || object_id::text;
  insert into argus_private.managed_storage_objects(
    id,tenant_id,lifecycle_id,user_id,bucket_id,object_path,object_kind,state,content_type
  ) values (
    object_id,context_record.tenant_id,context_record.lifecycle_id,
    context_record.user_id,'member-media',new_path,'member_media',
    'quarantined',p_mime_type
  );
  insert into argus_private.media_upload_intents(
    id,tenant_id,lifecycle_id,user_id,deletion_epoch,bucket_id,object_path,
    mime_type,max_bytes,status,expires_at,storage_object_id
  ) select new_intent_id,context_record.tenant_id,context_record.lifecycle_id,
    context_record.user_id,member.deletion_epoch,'member-media',new_path,
    p_mime_type,p_max_bytes,'pending',p_expires_at,object_id
    from argus_app.members member
   where member.tenant_id=context_record.tenant_id
     and member.lifecycle_id=context_record.lifecycle_id
     and member.user_id=context_record.user_id;
  return query select new_intent_id,object_id,'member-media'::text,new_path,
    p_mime_type,p_max_bytes,p_expires_at,'pending'::text;
end
$$;

create or replace function argus_private.finalize_media_upload(
  p_intent_id uuid,p_byte_size bigint,p_checksum text
)
returns argus_app.media_assets language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,extensions as $$
declare context_record record;
declare intent_record argus_private.media_upload_intents%rowtype;
declare asset_record argus_app.media_assets%rowtype;
begin
  select * into context_record from argus_private.read_trusted_request_context();
  if context_record.user_id is null
     or not argus_private.lock_open_member_lifecycle(
       context_record.tenant_id,context_record.lifecycle_id,context_record.user_id
     ) then raise exception 'member_lifecycle_not_open'; end if;
  if p_checksum !~ '^[a-f0-9]{64}$' or p_byte_size<1 then
    raise exception 'invalid_media_observation';
  end if;
  select intent.* into intent_record from argus_private.media_upload_intents intent
   where intent.tenant_id=context_record.tenant_id
     and intent.lifecycle_id=context_record.lifecycle_id
     and intent.user_id=context_record.user_id and intent.id=p_intent_id
   for update;
  if intent_record.id is null or intent_record.status<>'pending'
     or intent_record.expires_at<=pg_catalog.clock_timestamp()
     or p_byte_size>intent_record.max_bytes then
    raise exception 'media_upload_intent_not_current';
  end if;
  update argus_private.managed_storage_objects set
    expected_checksum=p_checksum,byte_size=p_byte_size
   where id=intent_record.storage_object_id and state='quarantined';
  update argus_private.media_upload_intents set status='uploaded'
   where id=intent_record.id;
  insert into argus_app.media_assets(
    tenant_id,lifecycle_id,user_id,storage_bucket,storage_path,mime_type,
    byte_size,checksum,quarantine_status,status,storage_object_id
  ) values (
    intent_record.tenant_id,intent_record.lifecycle_id,intent_record.user_id,
    intent_record.bucket_id,intent_record.object_path,intent_record.mime_type,
    p_byte_size,p_checksum,'quarantined','uploading',intent_record.storage_object_id
  ) returning * into asset_record;
  insert into argus_private.outbox_events(
    tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
    aggregate_id,dedupe_key
  ) values (
    intent_record.tenant_id,intent_record.lifecycle_id,intent_record.user_id,
    intent_record.deletion_epoch,'argus_jobs','media.structural_validation.requested',1,
    intent_record.id,'media-structural-validation:' || intent_record.id::text
  ) on conflict (topic,dedupe_key) do nothing;
  return asset_record;
end
$$;

create or replace function argus_private.get_member_media_upload_intent(p_intent_id uuid)
returns setof argus_private.media_upload_intents
language sql stable security definer set search_path=pg_catalog,argus_private as $$
  select intent.* from argus_private.media_upload_intents intent
  join argus_private.read_trusted_request_context() context
    on context.tenant_id=intent.tenant_id
   and context.lifecycle_id=intent.lifecycle_id
   and context.user_id=intent.user_id
   where intent.id=p_intent_id
$$;

create or replace function argus_private.prepare_media_structural_validation(p_event_id uuid)
returns table(
  effect_id uuid,effect_state text,storage_object_id uuid,bucket_id text,
  object_path text,mime_type text,max_bytes bigint,expected_checksum text,
  user_id uuid,upload_intent_id uuid
)
language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
declare event_record argus_private.outbox_events%rowtype;
declare intent_record argus_private.media_upload_intents%rowtype;
declare object_record argus_private.managed_storage_objects%rowtype;
declare effect_record argus_private.external_effects%rowtype;
begin
  select event.* into event_record from argus_private.outbox_events event
   where event.id=p_event_id and event.event_type='media.structural_validation.requested';
  if event_record.id is null
     or not argus_private.assert_worker_event_execution(p_event_id)
     or not argus_private.lock_open_member_lifecycle(
       event_record.tenant_id,event_record.lifecycle_id,event_record.user_id
     ) then raise exception 'lifecycle_closed'; end if;
  select intent.* into intent_record from argus_private.media_upload_intents intent
   where intent.tenant_id=event_record.tenant_id
     and intent.lifecycle_id=event_record.lifecycle_id
     and intent.user_id=event_record.user_id
     and intent.id=event_record.aggregate_id for update;
  select object.* into object_record from argus_private.managed_storage_objects object
   where object.tenant_id=intent_record.tenant_id
     and object.lifecycle_id=intent_record.lifecycle_id
     and object.user_id=intent_record.user_id
     and object.id=intent_record.storage_object_id for update;
  if intent_record.id is null or object_record.id is null
     or object_record.expected_checksum is null
     or intent_record.status not in ('uploaded','structural_validation','accepted') then
    raise exception 'invalid_event_payload';
  end if;
  insert into argus_private.external_effects(
    event_id,tenant_id,lifecycle_id,user_id,effect_kind,state,storage_object_id,
    attempts,effect_started_at
  ) values (
    event_record.id,event_record.tenant_id,event_record.lifecycle_id,event_record.user_id,
    'media_read','effect_unknown',object_record.id,1,pg_catalog.clock_timestamp()
  ) on conflict on constraint external_effects_event_kind_generation_unique
    do nothing returning * into effect_record;
  if effect_record.id is null then
    select effect.* into effect_record from argus_private.external_effects effect
     where effect.event_id=event_record.id and effect.effect_kind='media_read'
       and effect.generation_id is null
     for update;
    if effect_record.state<>'succeeded' then
      if effect_record.attempts>=5 then raise exception 'media_validation_exhausted'; end if;
      update argus_private.external_effects set state='effect_unknown',
        attempts=attempts+1,effect_started_at=pg_catalog.clock_timestamp(),
        updated_at=pg_catalog.clock_timestamp()
       where id=effect_record.id returning * into effect_record;
    end if;
  end if;
  if intent_record.status='uploaded' then
    update argus_private.media_upload_intents
       set status='structural_validation' where id=intent_record.id;
  end if;
  return query select effect_record.id,effect_record.state,object_record.id,
    object_record.bucket_id,object_record.object_path,intent_record.mime_type,
    intent_record.max_bytes,object_record.expected_checksum,intent_record.user_id,
    intent_record.id;
end
$$;

create or replace function argus_private.complete_media_structural_validation(
  p_effect_id uuid,p_accepted boolean,p_checksum text,p_width integer,
  p_height integer,p_reason_code text
)
returns boolean language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare effect_record argus_private.external_effects%rowtype;
declare object_record argus_private.managed_storage_objects%rowtype;
begin
  if p_checksum !~ '^[a-f0-9]{64}$' or p_width<0 or p_height<0
     or (p_accepted and p_reason_code is not null)
     or (not p_accepted and (p_reason_code is null or pg_catalog.char_length(p_reason_code)>64)) then
    raise exception 'invalid_media_validation_result';
  end if;
  select effect.* into effect_record from argus_private.external_effects effect
   where effect.id=p_effect_id and effect.effect_kind='media_read' for update;
  if effect_record.id is null then raise exception 'external_effect_not_found'; end if;
  if not argus_private.assert_worker_event_execution(effect_record.event_id) then
    raise exception 'worker_execution_lost';
  end if;
  if effect_record.state='succeeded' then return true; end if;
  if not argus_private.lock_open_member_lifecycle(
    effect_record.tenant_id,effect_record.lifecycle_id,effect_record.user_id
  ) then raise exception 'lifecycle_closed'; end if;
  select object.* into object_record from argus_private.managed_storage_objects object
   where object.id=effect_record.storage_object_id for update;
  if object_record.expected_checksum is distinct from p_checksum then
    raise exception 'storage_object_checksum_mismatch';
  end if;
  if p_accepted then
    update argus_private.managed_storage_objects set
      state='structurally_verified',observed_checksum=p_checksum,
      structurally_verified_at=pg_catalog.clock_timestamp(),reconciliation_code=null
     where id=object_record.id and state='quarantined';
    update argus_private.managed_storage_objects set
      state='published',published_at=pg_catalog.clock_timestamp()
     where id=object_record.id and state='structurally_verified';
  else
    update argus_private.managed_storage_objects set state='rejected',
      observed_checksum=p_checksum,reconciliation_code=p_reason_code
     where id=object_record.id and state='quarantined';
  end if;
  update argus_private.media_upload_intents set
    status=case when p_accepted then 'accepted' else 'rejected' end
   where storage_object_id=object_record.id and status='structural_validation';
  update argus_app.media_assets set
    quarantine_status=case when p_accepted then 'structurally_verified' else 'rejected' end,
    status=case when p_accepted then 'active' else 'retired' end,
    checksum=p_checksum
   where storage_object_id=object_record.id;
  update argus_private.external_effects set state='succeeded',result_hash=p_checksum,
    completed_at=pg_catalog.clock_timestamp(),failure_code=null
   where id=effect_record.id;
  return true;
end
$$;

create or replace function argus_private.mark_media_structural_reconciliation(
  p_effect_id uuid,p_reason_code text
)
returns void language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
declare effect_record argus_private.external_effects%rowtype;
begin
  if p_reason_code not in ('object_missing','storage_unavailable','checksum_mismatch') then
    raise exception 'invalid_reconciliation_code';
  end if;
  select effect.* into effect_record from argus_private.external_effects effect
   where effect.id=p_effect_id and effect.effect_kind='media_read' for update;
  if effect_record.id is null
     or not argus_private.assert_worker_event_execution(effect_record.event_id) then
    raise exception 'worker_execution_lost';
  end if;
  update argus_private.managed_storage_objects set state='reconciliation',
    reconciliation_code=p_reason_code where id=effect_record.storage_object_id
    and state in ('quarantined','deletion_pending','reconciliation');
  update argus_private.external_effects set state='reconciliation',failure_code=p_reason_code
   where id=effect_record.id and state<>'succeeded';
end
$$;

create or replace function argus_private.prepare_media_cleanup(p_event_id uuid)
returns table(
  effect_id uuid,effect_state text,storage_object_id uuid,bucket_id text,object_path text
)
language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
declare event_record argus_private.outbox_events%rowtype;
declare object_record argus_private.managed_storage_objects%rowtype;
declare effect_record argus_private.external_effects%rowtype;
begin
  select event.* into event_record from argus_private.outbox_events event
   where event.id=p_event_id and event.event_type='media.quarantine.cleanup';
  if event_record.id is null
     or not argus_private.assert_worker_event_execution(p_event_id)
     or not argus_private.lock_open_member_lifecycle(
       event_record.tenant_id,event_record.lifecycle_id,event_record.user_id
     ) then raise exception 'lifecycle_closed'; end if;
  select object.* into object_record
    from argus_private.media_upload_intents intent
    join argus_private.managed_storage_objects object on object.id=intent.storage_object_id
   where intent.tenant_id=event_record.tenant_id
     and intent.lifecycle_id=event_record.lifecycle_id
     and intent.user_id=event_record.user_id and intent.id=event_record.aggregate_id
   for update of object;
  if object_record.id is null then raise exception 'invalid_event_payload'; end if;
  if object_record.state not in ('tombstoned','deletion_pending','deleted','reconciliation') then
    update argus_private.managed_storage_objects set state='tombstoned',
      tombstoned_at=pg_catalog.clock_timestamp() where id=object_record.id;
  end if;
  update argus_private.managed_storage_objects set state='deletion_pending'
   where id=object_record.id and state in ('tombstoned','reconciliation');
  insert into argus_private.external_effects(
    event_id,tenant_id,lifecycle_id,user_id,effect_kind,state,storage_object_id,
    attempts,effect_started_at
  ) values (
    event_record.id,event_record.tenant_id,event_record.lifecycle_id,event_record.user_id,
    'storage_delete','effect_unknown',object_record.id,1,pg_catalog.clock_timestamp()
  ) on conflict on constraint external_effects_event_kind_generation_unique
    do nothing returning * into effect_record;
  if effect_record.id is null then
    select effect.* into effect_record from argus_private.external_effects effect
     where effect.event_id=event_record.id and effect.effect_kind='storage_delete'
       and effect.generation_id is null
     for update;
    if effect_record.state<>'succeeded' then
      if effect_record.attempts>=5 then raise exception 'media_cleanup_exhausted'; end if;
      update argus_private.external_effects set state='effect_unknown',
        attempts=attempts+1,effect_started_at=pg_catalog.clock_timestamp(),
        updated_at=pg_catalog.clock_timestamp()
       where id=effect_record.id returning * into effect_record;
    end if;
  end if;
  select * into object_record from argus_private.managed_storage_objects
   where id=object_record.id;
  return query select effect_record.id,
    case when object_record.state='deleted' then 'deleted' else effect_record.state end,
    object_record.id,object_record.bucket_id,object_record.object_path;
end
$$;

create or replace function argus_private.complete_media_cleanup(p_effect_id uuid)
returns void language plpgsql security definer
set search_path=pg_catalog,argus_private as $$
declare effect_record argus_private.external_effects%rowtype;
begin
  select effect.* into effect_record from argus_private.external_effects effect
   where effect.id=p_effect_id and effect.effect_kind='storage_delete' for update;
  if effect_record.id is null then raise exception 'external_effect_not_found'; end if;
  if not argus_private.assert_worker_event_execution(effect_record.event_id) then
    raise exception 'worker_execution_lost';
  end if;
  update argus_private.managed_storage_objects set state='deleted',
    deleted_at=pg_catalog.clock_timestamp(),reconciliation_code=null
   where id=effect_record.storage_object_id
     and state in ('deletion_pending','reconciliation');
  update argus_private.external_effects set state='succeeded',
    completed_at=pg_catalog.clock_timestamp(),failure_code=null
   where id=effect_record.id and state<>'succeeded';
end
$$;

create table argus_private.briefing_generation_requests (
  briefing_id uuid primary key,
  source_event_id uuid not null unique,
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  state text not null check (state in ('awaiting_provider','generated','failed')),
  provider_generation_id text,
  failure_code text,
  coordinated_at timestamptz not null default pg_catalog.clock_timestamp(),
  completed_at timestamptz,
  foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict,
  foreign key (tenant_id,lifecycle_id,briefing_id)
    references argus_app.briefings(tenant_id,lifecycle_id,id) on delete cascade,
  foreign key (tenant_id,lifecycle_id,user_id,source_event_id)
    references argus_private.outbox_events(tenant_id,lifecycle_id,user_id,id)
    on delete cascade
);
create index briefing_generation_requests_tenant_lifecycle_idx
  on argus_private.briefing_generation_requests(tenant_id,lifecycle_id);
create index briefing_generation_requests_subject_lifecycle_idx
  on argus_private.briefing_generation_requests(user_id,lifecycle_id);
create index briefing_generation_requests_briefing_scope_idx
  on argus_private.briefing_generation_requests(tenant_id,lifecycle_id,briefing_id);
create index briefing_generation_requests_event_scope_idx
  on argus_private.briefing_generation_requests(
    tenant_id,lifecycle_id,user_id,source_event_id
  );
alter table argus_private.briefing_generation_requests owner to argus_jobs_owner;
alter table argus_private.briefing_generation_requests enable row level security;
alter table argus_private.briefing_generation_requests force row level security;
revoke all on argus_private.briefing_generation_requests
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;
create policy u6_jobs_owner_briefing_generation_read
  on argus_private.briefing_generation_requests for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_briefing_generation_insert
  on argus_private.briefing_generation_requests for insert to argus_jobs_owner with check (true);
grant select,insert on argus_private.briefing_generation_requests to argus_jobs_owner;

create unique index notifications_u6_scope_unique
  on argus_app.notifications(tenant_id,lifecycle_id,user_id,id);
create table argus_private.in_app_notification_receipts (
  source_event_id uuid primary key,
  notification_id uuid not null unique,
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  recorded_at timestamptz not null default pg_catalog.clock_timestamp(),
  foreign key (tenant_id,lifecycle_id,user_id,source_event_id)
    references argus_private.outbox_events(tenant_id,lifecycle_id,user_id,id)
    on delete cascade,
  foreign key (tenant_id,lifecycle_id,user_id,notification_id)
    references argus_app.notifications(tenant_id,lifecycle_id,user_id,id)
    on delete cascade
);
create index in_app_notification_receipts_event_scope_idx
  on argus_private.in_app_notification_receipts(
    tenant_id,lifecycle_id,user_id,source_event_id
  );
create index in_app_notification_receipts_notification_scope_idx
  on argus_private.in_app_notification_receipts(
    tenant_id,lifecycle_id,user_id,notification_id
  );
alter table argus_private.in_app_notification_receipts owner to argus_jobs_owner;
alter table argus_private.in_app_notification_receipts enable row level security;
alter table argus_private.in_app_notification_receipts force row level security;
revoke all on argus_private.in_app_notification_receipts
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;
create policy u6_jobs_owner_notification_receipt_read
  on argus_private.in_app_notification_receipts for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_notification_receipt_insert
  on argus_private.in_app_notification_receipts for insert to argus_jobs_owner with check (true);
grant select,insert on argus_private.in_app_notification_receipts to argus_jobs_owner;

-- Exact application-table dependencies for internal coordination and saga
-- completion.  No worker table privilege remains after this block.
create policy u6_jobs_owner_privacy_request_read on argus_app.privacy_requests
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_privacy_request_insert on argus_app.privacy_requests
  for insert to argus_jobs_owner with check (true);
create policy u6_jobs_owner_privacy_request_update on argus_app.privacy_requests
  for update to argus_jobs_owner using (status<>'completed') with check (true);
grant select,insert,update on argus_app.privacy_requests to argus_jobs_owner;

create policy u6_jobs_owner_media_asset_read on argus_app.media_assets
  for select to argus_jobs_owner using (storage_object_id is not null);
create policy u6_jobs_owner_media_asset_insert on argus_app.media_assets
  for insert to argus_jobs_owner with check (
    storage_object_id is not null
    and quarantine_status='quarantined' and status='uploading'
  );
create policy u6_jobs_owner_media_asset_update on argus_app.media_assets
  for update to argus_jobs_owner using (storage_object_id is not null) with check (storage_object_id is not null);
grant select,insert,update on argus_app.media_assets to argus_jobs_owner;

create policy u6_jobs_owner_briefing_read on argus_app.briefings
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_briefing_insert on argus_app.briefings
  for insert to argus_jobs_owner with check (status='queued');
grant select,insert on argus_app.briefings to argus_jobs_owner;

create policy u6_jobs_owner_notification_read on argus_app.notifications
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_notification_insert on argus_app.notifications
  for insert to argus_jobs_owner with check (kind like 'briefing_%');
grant select,insert on argus_app.notifications to argus_jobs_owner;

create policy u6_jobs_owner_content_report_read on argus_app.content_reports
  for select to argus_jobs_owner using (true);
grant select on argus_app.content_reports to argus_jobs_owner;
create policy u6_jobs_owner_moderation_case_read on argus_app.moderation_cases
  for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_moderation_case_insert on argus_app.moderation_cases
  for insert to argus_jobs_owner with check (status='open');
grant select,insert on argus_app.moderation_cases to argus_jobs_owner;

create or replace function argus_private.coordinate_briefing_generation(p_event_id uuid)
returns text language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare event_record argus_private.outbox_events%rowtype;
declare briefing_record argus_app.briefings%rowtype;
declare notification_id uuid;
begin
  select event.* into event_record from argus_private.outbox_events event
   where event.id=p_event_id
     and event.event_type in (
       'briefing.daily.requested','briefing.weekly.requested','briefing.moon_cycle.requested'
     );
  if event_record.id is null
     or not argus_private.assert_worker_event_execution(p_event_id)
     or not argus_private.lock_open_member_lifecycle(
       event_record.tenant_id,event_record.lifecycle_id,event_record.user_id
     ) then raise exception 'lifecycle_closed'; end if;
  select briefing.* into briefing_record from argus_app.briefings briefing
   where briefing.id=event_record.aggregate_id
     and briefing.tenant_id=event_record.tenant_id
     and briefing.lifecycle_id=event_record.lifecycle_id
     and briefing.user_id=event_record.user_id;
  if briefing_record.id is null then raise exception 'invalid_event_payload'; end if;
  insert into argus_private.briefing_generation_requests(
    briefing_id,source_event_id,tenant_id,lifecycle_id,user_id,state
  ) values (
    briefing_record.id,event_record.id,event_record.tenant_id,
    event_record.lifecycle_id,event_record.user_id,'awaiting_provider'
  ) on conflict (briefing_id) do nothing;
  -- No content is fabricated and no delivery is claimed.  A future provider
  -- adapter must explicitly complete this durable request.
  return 'generation-awaiting-provider';
end
$$;

create or replace function argus_private.record_in_app_notification(p_event_id uuid)
returns text language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare event_record argus_private.outbox_events%rowtype;
declare briefing_record argus_app.briefings%rowtype;
declare notification_id uuid;
begin
  select event.* into event_record from argus_private.outbox_events event
   where event.id=p_event_id
     and event.event_type in (
       'briefing.daily.generated','briefing.weekly.generated','briefing.moon_cycle.generated'
     );
  if event_record.id is null
     or not argus_private.assert_worker_event_execution(p_event_id)
     or not argus_private.lock_open_member_lifecycle(
       event_record.tenant_id,event_record.lifecycle_id,event_record.user_id
     ) then raise exception 'lifecycle_closed'; end if;
  select briefing.* into briefing_record from argus_app.briefings briefing
   where briefing.id=event_record.aggregate_id and briefing.status='ready'
     and briefing.tenant_id=event_record.tenant_id
     and briefing.lifecycle_id=event_record.lifecycle_id
     and briefing.user_id=event_record.user_id;
  if briefing_record.id is null then raise exception 'briefing_not_generated'; end if;
  if exists (
    select 1 from argus_private.in_app_notification_receipts receipt
     where receipt.source_event_id=event_record.id
  ) then return 'in-app-notification-recorded'; end if;
  insert into argus_app.notifications(
    tenant_id,lifecycle_id,user_id,deletion_epoch,kind,title,body
  ) values (
    event_record.tenant_id,event_record.lifecycle_id,event_record.user_id,
    event_record.deletion_epoch,'briefing_' || briefing_record.briefing_type,
    'Your Argus briefing is ready','Open Argus to read your briefing.'
  ) returning id into notification_id;
  insert into argus_private.in_app_notification_receipts(
    source_event_id,notification_id,tenant_id,lifecycle_id,user_id
  ) values (
    event_record.id,notification_id,event_record.tenant_id,
    event_record.lifecycle_id,event_record.user_id
  );
  return 'in-app-notification-recorded';
end
$$;

create or replace function argus_private.triage_content_report(p_event_id uuid)
returns text language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare event_record argus_private.outbox_events%rowtype;
begin
  select event.* into event_record from argus_private.outbox_events event
   where event.id=p_event_id and event.event_type='content-report.created';
  if event_record.id is null
     or not argus_private.assert_worker_event_execution(p_event_id)
     or not argus_private.lock_open_member_lifecycle(
       event_record.tenant_id,event_record.lifecycle_id,event_record.user_id
     ) then raise exception 'lifecycle_closed'; end if;
  insert into argus_app.moderation_cases(report_id)
  select report.id from argus_app.content_reports report
   where report.id=event_record.aggregate_id
     and report.tenant_id=event_record.tenant_id
     and report.lifecycle_id=event_record.lifecycle_id
     and report.user_id=event_record.user_id
  on conflict (report_id) do nothing;
  if not found and not exists (
    select 1 from argus_app.moderation_cases where report_id=event_record.aggregate_id
  ) then raise exception 'invalid_event_payload'; end if;
  return 'moderation:' || event_record.aggregate_id::text;
end
$$;

do $$
declare function_signature regprocedure;
begin
  foreach function_signature in array array[
    'argus_private.create_media_upload_intent(text,bigint,timestamp with time zone)'::regprocedure,
    'argus_private.finalize_media_upload(uuid,bigint,text)'::regprocedure,
    'argus_private.get_member_media_upload_intent(uuid)'::regprocedure,
    'argus_private.prepare_media_structural_validation(uuid)'::regprocedure,
    'argus_private.complete_media_structural_validation(uuid,boolean,text,integer,integer,text)'::regprocedure,
    'argus_private.mark_media_structural_reconciliation(uuid,text)'::regprocedure,
    'argus_private.prepare_media_cleanup(uuid)'::regprocedure,
    'argus_private.complete_media_cleanup(uuid)'::regprocedure,
    'argus_private.coordinate_briefing_generation(uuid)'::regprocedure,
    'argus_private.record_in_app_notification(uuid)'::regprocedure,
    'argus_private.triage_content_report(uuid)'::regprocedure
  ] loop
    execute pg_catalog.format('alter function %s owner to argus_jobs_owner',function_signature);
    execute pg_catalog.format(
      'revoke all on function %s from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker',
      function_signature
    );
  end loop;
end
$$;
grant execute on function
  argus_private.create_media_upload_intent(text,bigint,timestamptz),
  argus_private.finalize_media_upload(uuid,bigint,text),
  argus_private.get_member_media_upload_intent(uuid)
to argus_member;
grant execute on function
  argus_private.prepare_media_structural_validation(uuid),
  argus_private.complete_media_structural_validation(uuid,boolean,text,integer,integer,text),
  argus_private.mark_media_structural_reconciliation(uuid,text),
  argus_private.prepare_media_cleanup(uuid),
  argus_private.complete_media_cleanup(uuid),
  argus_private.coordinate_briefing_generation(uuid),
  argus_private.record_in_app_notification(uuid),
  argus_private.triage_content_report(uuid)
to argus_worker;

revoke select,insert,update,delete on
  argus_app.members,argus_app.profiles,argus_app.preferences,
  argus_app.astrology_profiles,argus_app.investor_profiles,
  argus_app.onboarding_states,argus_app.consent_records,
  argus_app.notification_preferences,argus_app.daily_ritual_assignments,
  argus_app.circles,argus_app.circle_assets,argus_app.saved_items,
  argus_app.member_saved_items,argus_app.onboarding_step_completions,
  argus_app.notification_quiet_hours,argus_app.briefing_read_states,
  argus_app.content_report_targets,
  argus_app.intentions,argus_app.future_mirror_runs,argus_app.future_mirror_points,
  argus_app.briefings,argus_app.briefing_sections,argus_app.notifications,
  argus_app.privacy_requests,argus_app.content_reports
from argus_worker;

create or replace function argus_private.enqueue_due_retained_jobs(
  p_batch_size integer default 25
)
returns integer language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare enqueued integer:=0;
begin
  if p_batch_size<1 or p_batch_size>25 then raise exception 'invalid_batch_size'; end if;
  if exists (
    select 1 from argus_private.kill_switches where name='background_workers' and enabled
  ) then return 0; end if;
  insert into argus_app.briefings(
    tenant_id,lifecycle_id,user_id,deletion_epoch,briefing_type,
    period_start,period_end,status
  )
  select candidate.tenant_id,candidate.lifecycle_id,candidate.user_id,
         candidate.deletion_epoch,candidate.briefing_type,
         candidate.period_start,candidate.period_end,'queued'
    from (
      select member.tenant_id,member.lifecycle_id,member.user_id,member.deletion_epoch,
             'daily'::text briefing_type,current_date period_start,current_date period_end
        from argus_app.members member
        join argus_app.member_lifecycles lifecycle
          on lifecycle.tenant_id=member.tenant_id and lifecycle.id=member.lifecycle_id
         and lifecycle.identity_subject_id=member.user_id and lifecycle.state='open'
        join argus_app.notification_preferences preference
          on preference.tenant_id=member.tenant_id
         and preference.lifecycle_id=member.lifecycle_id and preference.user_id=member.user_id
       where member.status='active' and preference.daily_ritual
      union all
      select member.tenant_id,member.lifecycle_id,member.user_id,member.deletion_epoch,
             'weekly',pg_catalog.date_trunc('week',current_date)::date,
             pg_catalog.date_trunc('week',current_date)::date+6
        from argus_app.members member
        join argus_app.member_lifecycles lifecycle
          on lifecycle.tenant_id=member.tenant_id and lifecycle.id=member.lifecycle_id
         and lifecycle.identity_subject_id=member.user_id and lifecycle.state='open'
        join argus_app.notification_preferences preference
          on preference.tenant_id=member.tenant_id
         and preference.lifecycle_id=member.lifecycle_id and preference.user_id=member.user_id
       where member.status='active' and preference.weekly_recap
         and extract(isodow from current_date)=1
      union all
      select member.tenant_id,member.lifecycle_id,member.user_id,member.deletion_epoch,
             'moon_cycle',
             case when extract(day from current_date)=1
               then pg_catalog.date_trunc('month',current_date)::date
               else pg_catalog.date_trunc('month',current_date)::date+14 end,
             case when extract(day from current_date)=1
               then pg_catalog.date_trunc('month',current_date)::date+13
               else (pg_catalog.date_trunc('month',current_date)+interval '1 month - 1 day')::date end
        from argus_app.members member
        join argus_app.member_lifecycles lifecycle
          on lifecycle.tenant_id=member.tenant_id and lifecycle.id=member.lifecycle_id
         and lifecycle.identity_subject_id=member.user_id and lifecycle.state='open'
        join argus_app.notification_preferences preference
          on preference.tenant_id=member.tenant_id
         and preference.lifecycle_id=member.lifecycle_id and preference.user_id=member.user_id
       where member.status='active' and preference.moon_cycle
         and extract(day from current_date) in (1,15)
    ) candidate
   where not exists (
     select 1 from argus_app.briefings existing
      where existing.user_id=candidate.user_id
        and existing.briefing_type=candidate.briefing_type
        and existing.period_start=candidate.period_start
        and existing.period_end=candidate.period_end
   )
   order by candidate.user_id,candidate.briefing_type limit p_batch_size
  on conflict (user_id,briefing_type,period_start,period_end) do nothing;

  update argus_private.media_upload_intents set status='expired'
   where status in ('pending','uploaded','rejected')
     and expires_at<=pg_catalog.clock_timestamp();

  with due as (
    select briefing.tenant_id,briefing.lifecycle_id,briefing.user_id,
      briefing.deletion_epoch,
      ('briefing.' || briefing.briefing_type || '.requested')::text event_type,
      briefing.id aggregate_id,'briefing:' || briefing.id::text dedupe_key
      from argus_app.briefings briefing where briefing.status='queued'
    union all
    select generation.tenant_id,generation.lifecycle_id,generation.user_id,
      request.deletion_epoch,'privacy.export.retention.requested',generation.id,
      'privacy-export-retention:' || generation.id::text
      from argus_private.privacy_export_generations generation
      join argus_app.privacy_requests request on request.id=generation.request_id
     where generation.state='published'
       and generation.expires_at<=pg_catalog.clock_timestamp()
    union all
    select intent.tenant_id,intent.lifecycle_id,intent.user_id,intent.deletion_epoch,
      'media.quarantine.cleanup',intent.id,'media-cleanup:' || intent.id::text
      from argus_private.media_upload_intents intent
     where intent.status='expired'
  ), bounded as (
    select * from due
     where not exists (
       select 1 from argus_private.outbox_events existing
        where existing.topic='argus_jobs' and existing.dedupe_key=due.dedupe_key
     )
     order by dedupe_key limit p_batch_size
  )
  insert into argus_private.outbox_events(
    tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
    aggregate_id,dedupe_key
  )
  select tenant_id,lifecycle_id,user_id,deletion_epoch,'argus_jobs',event_type,1,
    aggregate_id,dedupe_key from bounded
  on conflict (topic,dedupe_key) do nothing;
  get diagnostics enqueued=row_count;
  return enqueued;
end
$$;

create or replace function argus_private.coordinate_argus_durable_work(
  p_batch_size integer default 25
)
returns jsonb language plpgsql security definer
set search_path=pg_catalog,argus_private,cron as $$
declare enqueued integer;
declare relayed integer;
declare recovered integer;
declare pruned_cron_runs integer;
begin
  delete from cron.job_run_details details using cron.job job,
    argus_private.job_schedule_registry registry
   where details.jobid=job.jobid and job.jobname=registry.schedule_name
     and details.end_time<pg_catalog.clock_timestamp()
       -pg_catalog.make_interval(days=>registry.retained_run_days);
  get diagnostics pruned_cron_runs=row_count;
  enqueued:=argus_private.enqueue_due_retained_jobs(p_batch_size);
  recovered:=argus_private.recover_expired_work(p_batch_size);
  relayed:=argus_private.relay_outbox(p_batch_size);
  return pg_catalog.jsonb_build_object(
    'enqueued',enqueued,'recovered',recovered,'relayed',relayed,
    'pruned_cron_runs',pruned_cron_runs
  );
end
$$;

-- Webull remains U5's authority.  This U6 coordinator only schedules its
-- existing bounded recovery candidates with the now-required lifecycle keys.
create or replace function argus_private.coordinate_webull_recovery(
  p_batch_size integer default 25
)
returns integer language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,argus_brokerage as $$
declare enqueued integer:=0;
declare added integer:=0;
begin
  if p_batch_size<1 or p_batch_size>25 then raise exception 'invalid_batch_size'; end if;
  if exists (
    select 1 from argus_private.kill_switches
     where name in ('background_workers','provider_egress') and enabled
  ) then return 0; end if;
  insert into argus_private.outbox_events(
    tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
    aggregate_id,dedupe_key
  )
  select credential.tenant_id,credential.lifecycle_id,credential.user_id,
    credential.deletion_epoch,'brokerage_refresh','webull.token.refresh.requested',1,
    credential.connection_id,
    'webull-token:' || credential.connection_id::text || ':' || credential.token_version::text
   from argus_private.webull_credentials credential
   join argus_app.member_lifecycles lifecycle
     on lifecycle.tenant_id=credential.tenant_id and lifecycle.id=credential.lifecycle_id
    and lifecycle.identity_subject_id=credential.user_id and lifecycle.state='open'
   join argus_brokerage.connections connection
     on connection.tenant_id=credential.tenant_id
    and connection.lifecycle_id=credential.lifecycle_id
    and connection.user_id=credential.user_id and connection.id=credential.connection_id
  where credential.access_expires_at<=pg_catalog.clock_timestamp()+interval '5 minutes'
    and connection.status='connected' and connection.egress_fenced_at is null
    and not exists (
      select 1 from argus_private.outbox_events existing
       where existing.topic='brokerage_refresh'
         and existing.dedupe_key='webull-token:' || credential.connection_id::text ||
           ':' || credential.token_version::text
    )
  order by credential.access_expires_at,credential.connection_id limit p_batch_size
  on conflict (topic,dedupe_key) do nothing;
  get diagnostics added=row_count;
  enqueued:=enqueued+added;

  if enqueued<p_batch_size then
    insert into argus_private.outbox_events(
      tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
      aggregate_id,dedupe_key
    )
    select command.tenant_id,command.lifecycle_id,command.user_id,command.deletion_epoch,
      'brokerage_reconcile','webull.command.reconciliation.requested',1,command.id,
      'webull-reconcile:' || command.id::text
      from argus_private.provider_commands command
      join argus_private.reconciliation_records reconciliation
        on reconciliation.tenant_id=command.tenant_id
       and reconciliation.lifecycle_id=command.lifecycle_id
       and reconciliation.user_id=command.user_id
       and reconciliation.command_id=command.id
      join argus_app.member_lifecycles lifecycle
        on lifecycle.tenant_id=command.tenant_id and lifecycle.id=command.lifecycle_id
       and lifecycle.identity_subject_id=command.user_id and lifecycle.state='open'
     where command.state in ('ambiguous','reconciling')
       and reconciliation.status in ('pending','running')
       and reconciliation.attempts<4
       and reconciliation.next_attempt_at<=pg_catalog.clock_timestamp()
       and not exists (
         select 1 from argus_private.outbox_events existing
          where existing.topic='brokerage_reconcile'
            and existing.dedupe_key='webull-reconcile:' || command.id::text
       )
     order by reconciliation.next_attempt_at,command.id
     limit (p_batch_size-enqueued)
    on conflict (topic,dedupe_key) do nothing;
    get diagnostics added=row_count;
    enqueued:=enqueued+added;
  end if;
  if enqueued<p_batch_size then
    with candidates as (
      select extensions.gen_random_uuid() id,account.tenant_id,
        account.lifecycle_id,account.id account_id,account.connection_id,
        account.user_id,account.deletion_epoch,resource.resource_type
        from argus_brokerage.accounts account
        join argus_app.member_lifecycles lifecycle
          on lifecycle.tenant_id=account.tenant_id
         and lifecycle.id=account.lifecycle_id
         and lifecycle.identity_subject_id=account.user_id
         and lifecycle.state='open'
        join argus_brokerage.connections connection
          on connection.tenant_id=account.tenant_id
         and connection.lifecycle_id=account.lifecycle_id
         and connection.user_id=account.user_id
         and connection.id=account.connection_id
         and connection.status='connected'
         and connection.egress_fenced_at is null
        join argus_private.webull_credentials credential
          on credential.tenant_id=account.tenant_id
         and credential.lifecycle_id=account.lifecycle_id
         and credential.user_id=account.user_id
         and credential.connection_id=account.connection_id
        cross join (values
          ('account'::text),('balance'),('positions'),('restrictions')
        ) resource(resource_type)
       where credential.access_expires_at>pg_catalog.clock_timestamp()
         and coalesce((
           select latest.expires_at
             from argus_brokerage.projection_generations latest
            where latest.tenant_id=account.tenant_id
              and latest.lifecycle_id=account.lifecycle_id
              and latest.account_id=account.id
              and latest.resource_type=resource.resource_type
            order by latest.generation desc limit 1
         ),'-infinity'::timestamptz)<=pg_catalog.clock_timestamp()
         and not exists (
           select 1 from argus_private.projection_refresh_leases active_lease
            where active_lease.tenant_id=account.tenant_id
              and active_lease.lifecycle_id=account.lifecycle_id
              and active_lease.account_id=account.id
              and active_lease.resource_type=resource.resource_type
              and active_lease.leased_until>pg_catalog.clock_timestamp()
         )
       order by account.id,resource.resource_type
       limit (p_batch_size-enqueued)
    ), leased as (
      insert into argus_private.projection_refresh_leases(
        id,tenant_id,lifecycle_id,account_id,connection_id,user_id,
        deletion_epoch,resource_type,lease_token,leased_until,acquired_at
      ) select id,tenant_id,lifecycle_id,account_id,connection_id,user_id,
        deletion_epoch,resource_type,extensions.gen_random_uuid(),
        pg_catalog.clock_timestamp(),pg_catalog.clock_timestamp()
        from candidates
      on conflict (account_id,resource_type) do update set
        id=excluded.id,tenant_id=excluded.tenant_id,
        lifecycle_id=excluded.lifecycle_id,
        connection_id=excluded.connection_id,user_id=excluded.user_id,
        deletion_epoch=excluded.deletion_epoch,
        lease_token=excluded.lease_token,leased_until=excluded.leased_until,
        acquired_at=excluded.acquired_at
      where projection_refresh_leases.leased_until<=pg_catalog.clock_timestamp()
      returning id,tenant_id,lifecycle_id,user_id,deletion_epoch
    )
    insert into argus_private.outbox_events(
      tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
      aggregate_id,dedupe_key
    ) select tenant_id,lifecycle_id,user_id,deletion_epoch,'brokerage_refresh',
      'webull.projection.refresh.requested',1,id,'webull-projection:' || id::text
      from leased
    on conflict (topic,dedupe_key) do nothing;
    get diagnostics added=row_count;
    enqueued:=enqueued+added;
  end if;
  return enqueued;
end
$$;

create or replace function argus_private.enqueue_worker_dispatch()
returns bigint language plpgsql security definer
set search_path=pg_catalog,argus_private,net,extensions as $$
declare config record;
declare dispatch_id uuid;
declare external_request_id bigint;
declare issued_at_seconds bigint;
declare nonce text;
declare nonce_hash text;
declare proof text;
declare scheduled_minute timestamptz:=pg_catalog.date_trunc('minute',pg_catalog.clock_timestamp());
begin
  if exists (
    select 1 from argus_private.kill_switches where name='background_workers' and enabled
  ) then return null; end if;
  issued_at_seconds:=extract(epoch from pg_catalog.clock_timestamp())::bigint;
  nonce:=pg_catalog.encode(extensions.gen_random_bytes(16),'hex');
  nonce_hash:=pg_catalog.encode(extensions.digest(nonce,'sha256'),'hex');
  insert into argus_private.worker_dispatches(
    state,nonce_hash,scheduled_for
  ) values ('prepared',nonce_hash,scheduled_minute)
  on conflict (scheduled_for) do nothing returning id into dispatch_id;
  if dispatch_id is null then return null; end if;
  begin
    select * into config from argus_private.resolve_worker_invocation_config();
    proof:=pg_catalog.encode(extensions.hmac(
      issued_at_seconds::text || '.' || nonce,config.current_secret,'sha256'
    ),'hex');
    select net.http_post(
      url:=config.worker_url,
      headers:=pg_catalog.jsonb_build_object(
        'content-type','application/json','x-argus-worker-timestamp',issued_at_seconds::text,
        'x-argus-worker-nonce',nonce,'x-argus-worker-proof',proof
      ),body:=pg_catalog.jsonb_build_object('batch_size',25),timeout_milliseconds:=10000
    ) into external_request_id;
  exception when others then
    update argus_private.worker_dispatches set state='failed',
      failure_code='dispatch_enqueue_failed',updated_at=pg_catalog.clock_timestamp()
     where id=dispatch_id;
    return null;
  end;
  update argus_private.worker_dispatches set state='enqueued',
    request_id=external_request_id,enqueued_at=pg_catalog.clock_timestamp(),
    updated_at=pg_catalog.clock_timestamp() where id=dispatch_id;
  return external_request_id;
end
$$;

create or replace function argus_private.consume_worker_invocation(
  p_nonce text,p_issued_at_seconds bigint
)
returns boolean language plpgsql security definer
set search_path=pg_catalog,argus_private,extensions as $$
declare nonce_digest text;
begin
  if p_nonce !~ '^[a-f0-9]{32}$'
     or abs(extract(epoch from pg_catalog.clock_timestamp())::bigint-p_issued_at_seconds)>60 then
    return false;
  end if;
  nonce_digest:=pg_catalog.encode(extensions.digest(p_nonce,'sha256'),'hex');
  insert into argus_private.worker_invocation_nonces(nonce_hash,issued_at)
  values (nonce_digest,pg_catalog.to_timestamp(p_issued_at_seconds))
  on conflict do nothing;
  if not found then return false; end if;
  update argus_private.worker_dispatches set state='acknowledged',
    acknowledged_at=pg_catalog.clock_timestamp(),updated_at=pg_catalog.clock_timestamp()
   where nonce_hash=nonce_digest and state='enqueued';
  return found;
end
$$;

alter function argus_private.enqueue_due_retained_jobs(integer) owner to argus_jobs_owner;
alter function argus_private.coordinate_argus_durable_work(integer) owner to argus_jobs_owner;
alter function argus_private.enqueue_worker_dispatch() owner to argus_jobs_owner;
alter function argus_private.consume_worker_invocation(text,bigint) owner to argus_jobs_owner;
alter function argus_private.prepare_privacy_export_generation(uuid) owner to argus_jobs_owner;
revoke all on function argus_private.enqueue_due_retained_jobs(integer),
  argus_private.coordinate_argus_durable_work(integer),
  argus_private.enqueue_worker_dispatch(),
  argus_private.consume_worker_invocation(text,bigint),
  argus_private.prepare_privacy_export_generation(uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;
grant execute on function argus_private.consume_worker_invocation(text,bigint),
  argus_private.prepare_privacy_export_generation(uuid)
to argus_worker;
grant execute on function argus_private.coordinate_argus_durable_work(integer),
  argus_private.enqueue_worker_dispatch()
to postgres;

-- The Webull coordinator executes with the already-reviewed U5 owner and has
-- no queue or provider-effect capability.
do $membership$
begin
  execute pg_catalog.format(
    'grant argus_brokerage_owner to %1$I with inherit true,set true,admin false granted by %1$I',
    current_user
  );
end
$membership$;
grant create on schema argus_private to argus_brokerage_owner;
alter function argus_private.coordinate_webull_recovery(integer)
  owner to argus_brokerage_owner;
revoke create on schema argus_private from argus_brokerage_owner;
revoke all on function argus_private.coordinate_webull_recovery(integer)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;
grant execute on function argus_private.coordinate_webull_recovery(integer) to postgres;
do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_brokerage_owner from %1$I granted by %1$I',current_user
  );
end
$membership$;

-- Only the dispatch adapter can see Vault/pg_net.  The worker sees neither.
grant usage on schema vault,net to argus_jobs_owner;
grant usage on schema cron to argus_jobs_owner;
grant select on cron.job to argus_jobs_owner;
grant select,delete on cron.job_run_details to argus_jobs_owner;
grant select on vault.decrypted_secrets to argus_jobs_owner;
grant execute on function net.http_post(text,jsonb,jsonb,jsonb,integer)
to argus_jobs_owner;
alter function argus_private.resolve_worker_invocation_config() owner to argus_jobs_owner;
revoke all on function argus_private.resolve_worker_invocation_config()
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;
revoke all on schema vault,net
from public,anon,authenticated,argus_worker,argus_runtime,argus_member,argus_staff,argus_callback;

select cron.unschedule(jobid) from cron.job
 where jobname in (
   'argus-outbox-relay','argus-recovery-sweep','argus-worker-dispatch',
   'argus-retained-enqueue','argus-webull-recovery-enqueue',
   'argus-durable-work-coordinate','argus-worker-dispatch-enqueue',
   'argus-webull-recovery-coordinate'
 );
select cron.schedule(
  'argus-durable-work-coordinate','* * * * *',
  'select argus_private.coordinate_argus_durable_work(25);'
);
select cron.schedule(
  'argus-worker-dispatch-enqueue','* * * * *',
  'select argus_private.enqueue_worker_dispatch();'
);
select cron.schedule(
  'argus-webull-recovery-coordinate','*/5 * * * *',
  'select argus_private.coordinate_webull_recovery(25);'
);

-- Privacy purge composes the U6 owner instead of granting the retained
-- postgres orchestrator direct DML on job or managed-object relations.
create policy u6_jobs_owner_outbox_delete on argus_private.outbox_events
  for delete to argus_jobs_owner using (user_id is not null);
grant delete on argus_private.outbox_events to argus_jobs_owner;
create policy u6_jobs_owner_job_runs_delete on argus_private.job_runs
  for delete to argus_jobs_owner using (user_id is not null);
grant delete on argus_private.job_runs to argus_jobs_owner;
create policy u6_jobs_owner_generation_delete on argus_private.privacy_export_generations
  for delete to argus_jobs_owner using (true);
create policy u6_jobs_owner_generation_rows_delete on argus_private.privacy_export_generation_rows
  for delete to argus_jobs_owner using (true);
create policy u6_jobs_owner_generation_collections_delete on argus_private.privacy_export_generation_collections
  for delete to argus_jobs_owner using (true);
create policy u6_jobs_owner_generation_objects_delete on argus_private.privacy_export_generation_objects
  for delete to argus_jobs_owner using (true);
grant delete on argus_private.privacy_export_generations,
  argus_private.privacy_export_generation_rows,
  argus_private.privacy_export_generation_collections,
  argus_private.privacy_export_generation_objects to argus_jobs_owner;
create policy u6_jobs_owner_access_lease_delete on argus_private.storage_access_leases
  for delete to argus_jobs_owner using (true);
create policy u6_jobs_owner_artifact_delete on argus_private.privacy_export_artifacts
  for delete to argus_jobs_owner using (true);
create policy u6_jobs_owner_media_intent_delete on argus_private.media_upload_intents
  for delete to argus_jobs_owner using (true);
create policy u6_jobs_owner_storage_delete on argus_private.managed_storage_objects
  for delete to argus_jobs_owner using (state='deleted');
grant delete on argus_private.storage_access_leases,
  argus_private.privacy_export_artifacts,argus_private.media_upload_intents,
  argus_private.managed_storage_objects to argus_jobs_owner;
create policy u6_jobs_owner_briefing_generation_delete
  on argus_private.briefing_generation_requests for delete to argus_jobs_owner using (true);
create policy u6_jobs_owner_notification_receipt_delete
  on argus_private.in_app_notification_receipts for delete to argus_jobs_owner using (true);
grant delete on argus_private.briefing_generation_requests,
  argus_private.in_app_notification_receipts to argus_jobs_owner;
create policy u6_jobs_owner_media_asset_delete on argus_app.media_assets
  for delete to argus_jobs_owner using (storage_object_id is not null);
grant delete on argus_app.media_assets to argus_jobs_owner;

create policy u6_jobs_owner_deletion_object_receipt_read
  on argus_private.deletion_object_receipts for select to argus_jobs_owner using (true);
create policy u6_jobs_owner_deletion_object_receipt_insert
  on argus_private.deletion_object_receipts for insert to argus_jobs_owner with check (true);
grant select,insert on argus_private.deletion_object_receipts to argus_jobs_owner;

-- Every destructive purge phase is tied to the one currently leased deletion
-- event.  The event and its job run remain as the durable execution receipt
-- until the worker records completion; all other member jobs are cancelled.
create or replace function argus_private.assert_member_purge_execution(
  p_tombstone_id uuid
)
returns uuid language plpgsql stable security definer
set search_path=pg_catalog,argus_private as $$
declare event_text text:=current_setting('argus.worker_event_id',true);
declare active_event_id uuid;
begin
  if event_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    raise exception 'purge_execution_required' using errcode='42501';
  end if;
  select event.id into active_event_id
    from argus_private.outbox_events event
    join argus_private.deletion_tombstones tombstone
      on tombstone.id=p_tombstone_id
   where event.id=event_text::uuid
     and event.aggregate_id=p_tombstone_id
     and event.event_type='privacy.deletion.requested'
     and argus_private.assert_worker_event_execution(event.id);
  if active_event_id is null then
    raise exception 'purge_execution_required' using errcode='42501';
  end if;
  return active_event_id;
end
$$;

create or replace function argus_private.prepare_member_purge(p_tombstone_id uuid)
returns table(user_id uuid,deletion_epoch bigint,purge_phase text)
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare tombstone_record argus_private.deletion_tombstones%rowtype;
declare active_event_id uuid;
begin
  active_event_id:=argus_private.assert_member_purge_execution(p_tombstone_id);
  select tombstone.* into tombstone_record from argus_private.deletion_tombstones tombstone
   where tombstone.id=p_tombstone_id
     and tombstone.status in ('pending','purging','failed','purged') for update;
  if tombstone_record.id is null then raise exception 'tombstone_missing'; end if;
  if tombstone_record.purge_phase='complete' then
    return query select tombstone_record.user_id,tombstone_record.deletion_epoch,
      tombstone_record.purge_phase;
    return;
  end if;
  if tombstone_record.purge_phase='requested' and not exists (
    select 1 from argus_app.members member
     where member.tenant_id=tombstone_record.tenant_id
       and member.lifecycle_id=tombstone_record.lifecycle_id
       and member.user_id=tombstone_record.user_id
       and member.deletion_epoch=tombstone_record.deletion_epoch
       and member.status in ('deletion_pending','purging')
  ) then raise exception 'deletion_incarnation_changed'; end if;
  perform argus_private.lock_open_member_lifecycle(
    tombstone_record.tenant_id,tombstone_record.lifecycle_id,tombstone_record.user_id
  );
  update argus_app.members member set status='purging'
   where member.tenant_id=tombstone_record.tenant_id
     and member.lifecycle_id=tombstone_record.lifecycle_id
     and member.user_id=tombstone_record.user_id and member.status='deletion_pending';
  update argus_private.deletion_tombstones tombstone set status='purging',
    purge_phase=case when tombstone.purge_phase='requested'
      then 'neutralized' else tombstone.purge_phase end
   where tombstone.id=tombstone_record.id and tombstone.purge_phase<>'complete';
  update argus_private.job_runs run set status='cancelled',lease_token=null,
    leased_until=null,next_attempt_at=null,last_error_code='member_deleted',
    updated_at=pg_catalog.clock_timestamp()
   where run.tenant_id=tombstone_record.tenant_id
     and run.lifecycle_id=tombstone_record.lifecycle_id
     and run.user_id=tombstone_record.user_id
     and run.source_event_id<>active_event_id
     and run.status not in ('succeeded','dead_lettered','cancelled');
  update argus_private.managed_storage_objects object set state='tombstoned',
    tombstoned_at=pg_catalog.clock_timestamp()
   where object.tenant_id=tombstone_record.tenant_id
     and object.lifecycle_id=tombstone_record.lifecycle_id
     and object.user_id=tombstone_record.user_id
     and object.state in ('quarantined','structurally_verified','published','rejected');
  update argus_private.managed_storage_objects object set state='deletion_pending'
   where object.tenant_id=tombstone_record.tenant_id
     and object.lifecycle_id=tombstone_record.lifecycle_id
     and object.user_id=tombstone_record.user_id
     and object.state in ('tombstoned','reconciliation');
  select tombstone.* into tombstone_record from argus_private.deletion_tombstones tombstone
   where tombstone.id=p_tombstone_id;
  return query select tombstone_record.user_id,tombstone_record.deletion_epoch,
    tombstone_record.purge_phase;
end
$$;

create or replace function argus_private.list_member_purge_objects(p_tombstone_id uuid)
returns table(bucket_id text,object_path text)
language plpgsql stable security definer set search_path=pg_catalog,argus_private as $$
begin
  perform argus_private.assert_member_purge_execution(p_tombstone_id);
  return query select object.bucket_id,object.object_path
    from argus_private.deletion_tombstones tombstone
    join argus_private.managed_storage_objects object
      on object.tenant_id=tombstone.tenant_id
     and object.lifecycle_id=tombstone.lifecycle_id
     and object.user_id=tombstone.user_id
   where tombstone.id=p_tombstone_id
     and tombstone.purge_phase in ('neutralized','storage_purged')
     and object.state in ('deletion_pending','deleted','reconciliation')
   order by object.bucket_id,object.object_path;
end
$$;

create or replace function argus_private.mark_member_storage_purged(
  p_tombstone_id uuid,p_object_receipts jsonb
)
returns void language plpgsql security definer
set search_path=pg_catalog,argus_private,extensions as $$
declare tombstone_record argus_private.deletion_tombstones%rowtype;
declare entry record;
begin
  perform argus_private.assert_member_purge_execution(p_tombstone_id);
  select tombstone.* into tombstone_record from argus_private.deletion_tombstones tombstone
   where tombstone.id=p_tombstone_id for update;
  if tombstone_record.purge_phase in ('storage_purged','data_purged','complete') then return; end if;
  if tombstone_record.purge_phase<>'neutralized'
     or pg_catalog.jsonb_typeof(p_object_receipts)<>'array'
     or pg_catalog.jsonb_array_length(p_object_receipts)>1000 then
    raise exception 'invalid_object_receipts';
  end if;
  for entry in
    select value->>'bucket_id' bucket_id,value->>'path_hash' path_hash
      from pg_catalog.jsonb_array_elements(p_object_receipts)
  loop
    if entry.bucket_id not in ('member-media','media-quarantine','privacy-exports')
       or entry.path_hash !~ '^[a-f0-9]{64}$' then
      raise exception 'invalid_object_receipts';
    end if;
    insert into argus_private.deletion_object_receipts(
      tombstone_id,bucket_id,object_path_hash
    ) values (p_tombstone_id,entry.bucket_id,entry.path_hash) on conflict do nothing;
  end loop;
  if exists (
    select 1 from argus_private.managed_storage_objects object
     where object.tenant_id=tombstone_record.tenant_id
       and object.lifecycle_id=tombstone_record.lifecycle_id
       and object.user_id=tombstone_record.user_id
       and object.state in ('deletion_pending','reconciliation')
       and not exists (
         select 1 from argus_private.deletion_object_receipts receipt
          where receipt.tombstone_id=p_tombstone_id
            and receipt.bucket_id=object.bucket_id
            and receipt.object_path_hash=pg_catalog.encode(
              extensions.digest(object.object_path,'sha256'),'hex'
            )
       )
  ) then return; end if;
  update argus_private.managed_storage_objects set state='deleted',
    deleted_at=pg_catalog.clock_timestamp(),reconciliation_code=null
   where tenant_id=tombstone_record.tenant_id
     and lifecycle_id=tombstone_record.lifecycle_id
     and user_id=tombstone_record.user_id
     and state in ('deletion_pending','reconciliation');
  update argus_private.deletion_tombstones set purge_phase='storage_purged'
   where id=p_tombstone_id and purge_phase='neutralized';
  if not found then raise exception 'invalid_purge_phase'; end if;
end
$$;
alter function argus_private.reject_sealed_export_row_mutation()
  owner to argus_jobs_owner;
revoke all on function argus_private.reject_sealed_export_row_mutation()
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,postgres;

create or replace function argus_private.purge_member_job_data(p_tombstone_id uuid)
returns integer language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app as $$
declare tombstone_record argus_private.deletion_tombstones%rowtype;
declare purged_tables integer:=0;
declare active_event_id uuid;
begin
  active_event_id:=argus_private.assert_member_purge_execution(p_tombstone_id);
  select tombstone.* into tombstone_record from argus_private.deletion_tombstones tombstone
   where tombstone.id=p_tombstone_id and tombstone.status='purging'
     and tombstone.purge_phase='storage_purged';
  if tombstone_record.id is null then raise exception 'job_purge_scope_invalid'; end if;
  perform pg_catalog.set_config('argus.jobs_purge_authorized',p_tombstone_id::text,true);
  delete from argus_private.storage_access_leases lease
   where lease.tenant_id=tombstone_record.tenant_id
     and lease.lifecycle_id=tombstone_record.lifecycle_id and lease.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_private.privacy_export_artifacts artifact
   where artifact.tenant_id=tombstone_record.tenant_id
     and artifact.lifecycle_id=tombstone_record.lifecycle_id and artifact.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_private.privacy_export_generations generation
   where generation.tenant_id=tombstone_record.tenant_id
     and generation.lifecycle_id=tombstone_record.lifecycle_id and generation.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_private.media_upload_intents intent
   where intent.tenant_id=tombstone_record.tenant_id
     and intent.lifecycle_id=tombstone_record.lifecycle_id and intent.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_private.job_runs run
   where run.tenant_id=tombstone_record.tenant_id
     and run.lifecycle_id=tombstone_record.lifecycle_id and run.user_id=tombstone_record.user_id
     and run.source_event_id<>active_event_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_private.outbox_events event
   where event.tenant_id=tombstone_record.tenant_id
     and event.lifecycle_id=tombstone_record.lifecycle_id
     and event.user_id=tombstone_record.user_id
     and event.id<>active_event_id;
  if found then purged_tables:=purged_tables+1; end if;
  return purged_tables;
end
$$;

-- Sealed rows are ordinarily immutable.  The sole deletion exception is the
-- validated tombstone-scoped jobs-owner purge above.
create or replace function argus_private.reject_sealed_export_row_mutation()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if tg_op='DELETE' and current_user='argus_jobs_owner'
     and pg_catalog.current_setting('argus.jobs_purge_authorized',true)
       ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    return old;
  end if;
  if exists (
    select 1 from argus_private.privacy_export_generations generation
     where generation.id=case when tg_op='DELETE' then old.generation_id else new.generation_id end
       and generation.state<>'sealing'
  ) then raise exception 'sealed_privacy_generation_immutable' using errcode='23514'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end
$$;

alter function argus_private.assert_member_purge_execution(uuid) owner to argus_jobs_owner;
alter function argus_private.prepare_member_purge(uuid) owner to argus_jobs_owner;
alter function argus_private.list_member_purge_objects(uuid) owner to argus_jobs_owner;
alter function argus_private.mark_member_storage_purged(uuid,jsonb) owner to argus_jobs_owner;
alter function argus_private.purge_member_job_data(uuid) owner to argus_jobs_owner;
revoke all on function argus_private.assert_member_purge_execution(uuid),
  argus_private.prepare_member_purge(uuid),
  argus_private.list_member_purge_objects(uuid),
  argus_private.mark_member_storage_purged(uuid,jsonb),
  argus_private.purge_member_job_data(uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker,postgres;
grant execute on function argus_private.prepare_member_purge(uuid),
  argus_private.list_member_purge_objects(uuid),
  argus_private.mark_member_storage_purged(uuid,jsonb)
to argus_worker;
grant execute on function argus_private.purge_member_job_data(uuid) to postgres;
grant execute on function argus_private.assert_member_purge_execution(uuid) to postgres;

-- Explicit application purge port. Runtime deletion is deliberately not a
-- catalog loop: adding a member relation requires an inventory decision here.
create policy u6_app_owner_tombstone_purge_read
  on argus_private.deletion_tombstones for select to argus_app_owner
  using (status='purging' and purge_phase='storage_purged');
grant select on argus_private.deletion_tombstones to argus_app_owner;
do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'moderation_cases','content_report_targets','content_reports',
    'media_assets',
    'briefing_read_states','briefing_sections','briefings',
    'future_mirror_points','future_mirror_runs','intentions',
    'circle_assets','circles','onboarding_step_completions','onboarding_states',
    'notification_quiet_hours','notification_preferences','notifications',
    'member_saved_items','saved_items','daily_ritual_assignments','consent_records',
    'investor_profiles','astrology_profiles','preferences','profiles','privacy_requests'
  ] loop
    execute pg_catalog.format(
      'create policy u6_app_owner_purge_delete on argus_app.%I for delete to argus_app_owner using (true)',
      relation_name
    );
    execute pg_catalog.format(
      'create policy u6_app_owner_purge_read on argus_app.%I for select to argus_app_owner using (true)',
      relation_name
    );
    execute pg_catalog.format(
      'grant select,delete on argus_app.%I to argus_app_owner',relation_name
    );
  end loop;
end
$$;
create policy u6_app_owner_idempotency_purge_delete
  on argus_private.member_idempotency_records for delete to argus_app_owner using (true);
create policy u6_app_owner_idempotency_purge_read
  on argus_private.member_idempotency_records for select to argus_app_owner using (true);
grant select,delete on argus_private.member_idempotency_records to argus_app_owner;

create or replace function argus_private.purge_member_application_data(
  p_tombstone_id uuid
)
returns integer language plpgsql security definer set search_path='' as $$
declare tombstone_record argus_private.deletion_tombstones%rowtype;
declare purged_tables integer:=0;
begin
  select target.* into tombstone_record
    from argus_private.deletion_tombstones target
   where target.id=p_tombstone_id and target.status='purging'
     and target.purge_phase='storage_purged';
  if tombstone_record.id is null then
    raise exception 'application_purge_scope_invalid' using errcode='23514';
  end if;
  delete from argus_app.media_assets row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.moderation_cases moderation
   using argus_app.content_reports report
   where moderation.report_id=report.id
     and report.tenant_id=tombstone_record.tenant_id
     and report.lifecycle_id=tombstone_record.lifecycle_id
     and report.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.content_report_targets target
   using argus_app.content_reports report
   where target.report_id=report.id
     and report.tenant_id=tombstone_record.tenant_id
     and report.lifecycle_id=tombstone_record.lifecycle_id
     and report.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.content_reports row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.briefing_read_states row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.briefing_sections row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.briefings row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.future_mirror_points row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.future_mirror_runs row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.intentions row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.circle_assets row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.circles row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.onboarding_step_completions row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.onboarding_user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.onboarding_states row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.notification_quiet_hours row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.preference_user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.notifications row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.notification_preferences row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.member_saved_items row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.saved_items row
   where row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.daily_ritual_assignments row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.consent_records row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.investor_profiles row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.astrology_profiles row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.preferences row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.profiles row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.privacy_requests row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_private.member_idempotency_records row
   where row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  return purged_tables;
end
$$;
grant create on schema argus_private to argus_app_owner;
alter function argus_private.purge_member_application_data(uuid)
  owner to argus_app_owner;
revoke create on schema argus_private from argus_app_owner;
revoke all on function argus_private.purge_member_application_data(uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,postgres;
grant execute on function argus_private.purge_member_application_data(uuid)
to argus_jobs_owner;

-- Explicit identity/security purge port. Tombstones and their durable purge
-- receipts remain; ephemeral identity and staff-session material does not.
create policy u6_identity_owner_tombstone_purge_read
  on argus_private.deletion_tombstones for select to argus_identity_owner
  using (status='purging' and purge_phase='storage_purged');
grant select on argus_private.deletion_tombstones to argus_identity_owner;
do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'device_installations','security_events','staff_principals',
    'staff_step_up_receipts','step_up_receipts','admin_audit_events'
  ] loop
    execute pg_catalog.format(
      'create policy u6_identity_owner_purge_delete on argus_private.%I for delete to argus_identity_owner using (true)',
      relation_name
    );
    execute pg_catalog.format(
      'create policy u6_identity_owner_purge_read on argus_private.%I for select to argus_identity_owner using (true)',
      relation_name
    );
    execute pg_catalog.format(
      'grant select,delete on argus_private.%I to argus_identity_owner',relation_name
    );
  end loop;
end
$$;
create or replace function argus_private.purge_member_identity_data(
  p_tombstone_id uuid
)
returns integer language plpgsql security definer set search_path='' as $$
declare tombstone_record argus_private.deletion_tombstones%rowtype;
declare purged_tables integer:=0;
begin
  select target.* into tombstone_record
    from argus_private.deletion_tombstones target
   where target.id=p_tombstone_id and target.status='purging'
     and target.purge_phase='storage_purged';
  if tombstone_record.id is null then
    raise exception 'identity_purge_scope_invalid' using errcode='23514';
  end if;
  delete from argus_private.device_installations row
   where row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_private.staff_step_up_receipts row
   where row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_private.step_up_receipts row
   where row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_private.staff_principals row
   where row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_private.security_events row
   where row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_private.admin_audit_events row
   where row.actor_user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  return purged_tables;
end
$$;
grant create on schema argus_private to argus_identity_owner;
alter function argus_private.purge_member_identity_data(uuid)
  owner to argus_identity_owner;
revoke create on schema argus_private from argus_identity_owner;
revoke all on function argus_private.purge_member_identity_data(uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,postgres;
grant execute on function argus_private.purge_member_identity_data(uuid)
to argus_jobs_owner;

-- Replace the retained orchestrator with a jobs-owned composition root. Each
-- child capability validates the same tombstone and owns only its domain.
create or replace function argus_private.purge_member_argus_data(p_tombstone_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare tombstone argus_private.deletion_tombstones%rowtype;
declare purged_tables integer:=0;
begin
  perform argus_private.assert_member_purge_execution(p_tombstone_id);
  select target.* into tombstone from argus_private.deletion_tombstones target
   where target.id=p_tombstone_id and target.status='purging'
     and target.purge_phase in ('storage_purged','data_purged') for update;
  if tombstone.id is null then raise exception 'tombstone_missing'; end if;
  if tombstone.purge_phase='storage_purged' then
    purged_tables:=purged_tables+argus_private.purge_member_job_data(tombstone.id);
    purged_tables:=purged_tables+argus_private.purge_member_brokerage_data(tombstone.id);
    purged_tables:=purged_tables+argus_private.purge_member_application_data(tombstone.id);
    purged_tables:=purged_tables+argus_private.purge_member_identity_data(tombstone.id);
    delete from argus_private.managed_storage_objects object
     where object.tenant_id=tombstone.tenant_id
       and object.lifecycle_id=tombstone.lifecycle_id
       and object.user_id=tombstone.user_id
       and object.state='deleted';
    if found then purged_tables:=purged_tables+1; end if;
    update argus_private.deletion_tombstones set purge_phase='data_purged',
      purged_tables_count=purged_tables where id=tombstone.id;
  end if;
  return purged_tables;
end
$$;
alter function argus_private.purge_member_argus_data(uuid) owner to argus_jobs_owner;
revoke all on function argus_private.purge_member_argus_data(uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,postgres;
grant execute on function argus_private.purge_member_argus_data(uuid) to argus_worker;

do $membership$
begin
  execute pg_catalog.format(
    'grant argus_brokerage_owner to %1$I with inherit true,set true,admin false granted by %1$I',
    current_user
  );
end
$membership$;
set local role argus_brokerage_owner;
revoke execute on function argus_private.purge_member_brokerage_data(uuid) from postgres;
grant execute on function argus_private.purge_member_brokerage_data(uuid) to argus_jobs_owner;
set local role postgres;
do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_brokerage_owner from %1$I granted by %1$I',current_user
  );
end
$membership$;

create or replace function argus_private.close_purged_member_lifecycle(
  p_tenant_id uuid,p_lifecycle_id uuid,p_user_id uuid
)
returns void language plpgsql security definer set search_path='' as $$
begin
  update argus_app.member_lifecycles lifecycle set state='closed',
    closed_at=pg_catalog.clock_timestamp(),close_reason='privacy-purge-complete'
   where lifecycle.tenant_id=p_tenant_id and lifecycle.id=p_lifecycle_id
     and lifecycle.identity_subject_id=p_user_id and lifecycle.state='open';
  if not found and not exists (
    select 1 from argus_app.member_lifecycles lifecycle
     where lifecycle.tenant_id=p_tenant_id and lifecycle.id=p_lifecycle_id
       and lifecycle.identity_subject_id=p_user_id and lifecycle.state='closed'
  ) then raise exception 'member_lifecycle_not_found'; end if;
end
$$;
grant create on schema argus_private to argus_identity_owner;
alter function argus_private.close_purged_member_lifecycle(uuid,uuid,uuid)
  owner to argus_identity_owner;
revoke create on schema argus_private from argus_identity_owner;
revoke all on function argus_private.close_purged_member_lifecycle(uuid,uuid,uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker,argus_jobs_owner;
grant execute on function argus_private.close_purged_member_lifecycle(uuid,uuid,uuid)
to postgres;

create or replace function argus_private.complete_member_purge(p_tombstone_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare tombstone_record argus_private.deletion_tombstones%rowtype;
declare receipt_id uuid;
declare object_count integer;
begin
  perform argus_private.assert_member_purge_execution(p_tombstone_id);
  select tombstone.* into tombstone_record from argus_private.deletion_tombstones tombstone
   where tombstone.id=p_tombstone_id and tombstone.purge_phase in ('data_purged','complete')
   for update;
  if tombstone_record.id is null then raise exception 'tombstone_missing'; end if;
  if tombstone_record.purge_phase='complete' then
    return (select receipt.id from argus_private.purge_receipts receipt
      where receipt.tombstone_id=tombstone_record.id);
  end if;
  if tombstone_record.webull_fenced_at is null
     or tombstone_record.webull_credentials_destroyed_at is null then
    raise exception 'webull_purge_incomplete';
  end if;
  if exists (select 1 from auth.users identity where identity.id=tombstone_record.user_id) then
    raise exception 'auth_identity_still_present';
  end if;
  select pg_catalog.count(*) into object_count
    from argus_private.deletion_object_receipts receipt
   where receipt.tombstone_id=tombstone_record.id;
  update argus_app.members set status='purged'
   where tenant_id=tombstone_record.tenant_id
     and lifecycle_id=tombstone_record.lifecycle_id
     and user_id=tombstone_record.user_id and status='purging';
  perform argus_private.close_purged_member_lifecycle(
    tombstone_record.tenant_id,tombstone_record.lifecycle_id,tombstone_record.user_id
  );
  update argus_private.deletion_tombstones set status='purged',purge_phase='complete',
    auth_deleted_at=pg_catalog.clock_timestamp(),completed_at=pg_catalog.clock_timestamp()
   where id=tombstone_record.id;
  insert into argus_private.purge_receipts(tombstone_id,purged_tables,purged_objects)
  values (tombstone_record.id,tombstone_record.purged_tables_count,object_count)
  on conflict (tombstone_id) do update set purged_tables=excluded.purged_tables,
    purged_objects=excluded.purged_objects,completed_at=pg_catalog.clock_timestamp()
  returning id into receipt_id;
  return receipt_id;
end
$$;
revoke all on function argus_private.complete_member_purge(uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback;
grant execute on function argus_private.complete_member_purge(uuid) to argus_worker;

grant execute on function argus_private.has_staff_permission(text) to argus_jobs_owner;

-- Staff step-up remains the retained administration domain's capability.  It
-- is made a narrowly validated definer so the jobs owner can consume one
-- receipt without receiving table DML on staff identities or receipts.
create or replace function argus_private.consume_staff_step_up(
  p_receipt_hash text,
  p_session_id uuid,
  p_action text,
  p_target_id uuid
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare consumed_id uuid;
declare context_user_id uuid:=argus_private.trusted_request_user_id();
begin
  if pg_catalog.current_setting('request.jwt.claims',true)::jsonb->>'aal'<>'aal2'
     or not argus_private.has_live_staff_session(context_user_id,p_session_id)
     or not (
       case p_action
         when 'admin_job_retry' then argus_private.has_staff_permission('operations:write')
         when 'admin_privacy_retry' then argus_private.has_staff_permission('privacy:write')
         else false
       end
     ) then
    return false;
  end if;
  update argus_private.staff_step_up_receipts receipt
     set consumed_at=pg_catalog.clock_timestamp()
   where receipt.receipt_hash=p_receipt_hash
     and receipt.user_id=context_user_id
     and receipt.session_id=p_session_id
     and receipt.action=p_action
     and receipt.target_id=p_target_id
     and receipt.consumed_at is null
     and receipt.expires_at>pg_catalog.clock_timestamp()
  returning receipt.id into consumed_id;
  return consumed_id is not null;
end
$$;
revoke all on function argus_private.consume_staff_step_up(text,uuid,text,uuid)
from public,anon,authenticated,argus_member,argus_staff,argus_callback,argus_worker;
grant execute on function argus_private.consume_staff_step_up(text,uuid,text,uuid)
to argus_jobs_owner,argus_runtime;

create or replace function argus_private.list_job_diagnostics(p_limit integer)
returns table(
  correlation_id uuid,job_type text,status text,attempts integer,
  next_attempt_at timestamptz,last_error_code text,
  created_at timestamptz,updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not argus_private.has_staff_permission('operations:read') then
    raise exception 'staff_permission_required' using errcode='42501';
  end if;
  if p_limit<1 or p_limit>100 then
    raise exception 'invalid_diagnostic_limit' using errcode='22023';
  end if;
  return query
  select run.id,run.job_type,run.status,run.attempts,run.next_attempt_at,
    case when run.last_error_code is null then null
         when run.last_error_code~'^[a-z][a-z0-9_]{0,63}$' then run.last_error_code
         else 'job_failure_redacted' end,
    run.created_at,run.updated_at
    from argus_private.job_runs run
   order by run.created_at desc,run.id desc
   limit p_limit;
end
$$;

create or replace function argus_private.list_privacy_request_diagnostics(p_limit integer)
returns table(
  correlation_id uuid,request_type text,status text,requested_at timestamptz,
  completed_at timestamptz,reason_code text
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not argus_private.has_staff_permission('privacy:read') then
    raise exception 'staff_permission_required' using errcode='42501';
  end if;
  if p_limit<1 or p_limit>100 then
    raise exception 'invalid_diagnostic_limit' using errcode='22023';
  end if;
  return query
  select request.id,request.request_type,request.status,request.requested_at,
    request.completed_at,
    case when request.failure_code is null then null
         else 'privacy_failure_redacted' end
    from argus_app.privacy_requests request
   order by request.requested_at desc,request.id desc
   limit p_limit;
end
$$;

create or replace function argus_private.request_admin_job_retry(
  p_job_id uuid,p_dedupe_key text,p_receipt_hash text,p_session_id uuid
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare requested_job argus_private.job_runs%rowtype;
declare source_event argus_private.outbox_events%rowtype;
declare registered_handler text;
declare retry_event_id uuid;
begin
  if not argus_private.consume_staff_step_up(
    p_receipt_hash,p_session_id,'admin_job_retry',p_job_id
  ) then raise exception 'step_up_required' using errcode='42501'; end if;
  if p_dedupe_key!~'^[!-~]{16,128}$' then
    raise exception 'invalid_retry_dedupe_key' using errcode='22023';
  end if;
  select run.* into requested_job from argus_private.job_runs run
   where run.id=p_job_id and run.status='dead_lettered' for update;
  if requested_job.id is null or requested_job.source_event_id is null then
    raise exception 'job_not_retryable' using errcode='22023';
  end if;
  select event.* into source_event from argus_private.outbox_events event
   where event.id=requested_job.source_event_id;
  select registry.handler_name into registered_handler
    from argus_private.job_event_registry registry
   where registry.event_type=source_event.event_type
     and registry.payload_version=source_event.event_version
     and registry.topic=source_event.topic and registry.enabled;
  if source_event.id is null
     or registered_handler is distinct from requested_job.handler_name then
    raise exception 'job_not_retryable' using errcode='22023';
  end if;
  insert into argus_private.outbox_events(
    tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
    aggregate_id,dedupe_key
  ) values (
    source_event.tenant_id,source_event.lifecycle_id,source_event.user_id,
    source_event.deletion_epoch,source_event.topic,source_event.event_type,
    source_event.event_version,source_event.aggregate_id,p_dedupe_key
  ) on conflict(topic,dedupe_key) do nothing returning id into retry_event_id;
  if retry_event_id is null then
    select event.id into retry_event_id from argus_private.outbox_events event
     where event.topic=source_event.topic and event.dedupe_key=p_dedupe_key
       and event.tenant_id is not distinct from source_event.tenant_id
       and event.lifecycle_id is not distinct from source_event.lifecycle_id
       and event.user_id is not distinct from source_event.user_id
       and event.deletion_epoch is not distinct from source_event.deletion_epoch
       and event.event_type=source_event.event_type
       and event.event_version=source_event.event_version
       and event.aggregate_id=source_event.aggregate_id;
    if retry_event_id is null then
      raise exception 'retry_dedupe_conflict' using errcode='23505';
    end if;
  end if;
  return retry_event_id;
end
$$;

create or replace function argus_private.request_admin_privacy_retry(
  p_request_id uuid,p_dedupe_key text,p_receipt_hash text,p_session_id uuid
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare requested_privacy argus_app.privacy_requests%rowtype;
declare retained_event_type text;
declare retained_aggregate_id uuid;
declare retained_tenant_id uuid;
declare retained_lifecycle_id uuid;
declare retained_user_id uuid;
declare retained_deletion_epoch bigint;
declare retry_event_id uuid;
begin
  if not argus_private.consume_staff_step_up(
    p_receipt_hash,p_session_id,'admin_privacy_retry',p_request_id
  ) then raise exception 'step_up_required' using errcode='42501'; end if;
  if p_dedupe_key!~'^[!-~]{16,128}$' then
    raise exception 'invalid_retry_dedupe_key' using errcode='22023';
  end if;
  select request.* into requested_privacy from argus_app.privacy_requests request
   where request.id=p_request_id and request.status='failed' for update;
  if requested_privacy.id is null then
    raise exception 'privacy_request_not_retryable' using errcode='22023';
  end if;
  if requested_privacy.request_type='export' then
    retained_event_type:='privacy.export.requested';
    retained_aggregate_id:=requested_privacy.id;
    retained_tenant_id:=requested_privacy.tenant_id;
    retained_lifecycle_id:=requested_privacy.lifecycle_id;
    retained_user_id:=requested_privacy.user_id;
    retained_deletion_epoch:=requested_privacy.deletion_epoch;
  elsif requested_privacy.request_type='deletion' then
    select tombstone.id into retained_aggregate_id
      from argus_private.deletion_tombstones tombstone
     where tombstone.tenant_id=requested_privacy.tenant_id
       and tombstone.lifecycle_id=requested_privacy.lifecycle_id
       and tombstone.user_id=requested_privacy.user_id
       and tombstone.deletion_epoch=requested_privacy.deletion_epoch
       and tombstone.status in ('pending','purging','failed') for update;
    if retained_aggregate_id is null then
      raise exception 'privacy_request_not_retryable' using errcode='22023';
    end if;
    retained_event_type:='privacy.deletion.requested';
  else
    raise exception 'privacy_request_not_retryable' using errcode='22023';
  end if;
  if not exists (
    select 1 from argus_private.job_event_registry registry
     where registry.event_type=retained_event_type and registry.payload_version=1
       and registry.topic='argus_jobs' and registry.enabled
  ) then raise exception 'privacy_retry_handler_unavailable'; end if;
  insert into argus_private.outbox_events(
    tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
    aggregate_id,dedupe_key
  ) values (
    retained_tenant_id,retained_lifecycle_id,retained_user_id,
    retained_deletion_epoch,'argus_jobs',retained_event_type,1,
    retained_aggregate_id,p_dedupe_key
  ) on conflict(topic,dedupe_key) do nothing returning id into retry_event_id;
  if retry_event_id is null then
    select event.id into retry_event_id from argus_private.outbox_events event
     where event.topic='argus_jobs' and event.dedupe_key=p_dedupe_key
       and event.tenant_id is not distinct from retained_tenant_id
       and event.lifecycle_id is not distinct from retained_lifecycle_id
       and event.user_id is not distinct from retained_user_id
       and event.deletion_epoch is not distinct from retained_deletion_epoch
       and event.event_type=retained_event_type and event.event_version=1
       and event.aggregate_id=retained_aggregate_id;
    if retry_event_id is null then
      raise exception 'retry_dedupe_conflict' using errcode='23505';
    end if;
  end if;
  update argus_app.privacy_requests set status='queued',failure_code=null,
    completed_at=null where id=requested_privacy.id;
  return retry_event_id;
end
$$;

alter function argus_private.list_job_diagnostics(integer) owner to argus_jobs_owner;
alter function argus_private.list_privacy_request_diagnostics(integer) owner to argus_jobs_owner;
alter function argus_private.request_admin_job_retry(uuid,text,text,uuid) owner to argus_jobs_owner;
alter function argus_private.request_admin_privacy_retry(uuid,text,text,uuid) owner to argus_jobs_owner;
revoke all on function argus_private.list_job_diagnostics(integer),
  argus_private.list_privacy_request_diagnostics(integer),
  argus_private.request_admin_job_retry(uuid,text,text,uuid),
  argus_private.request_admin_privacy_retry(uuid,text,text,uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_callback,argus_worker;
grant execute on function argus_private.list_job_diagnostics(integer),
  argus_private.list_privacy_request_diagnostics(integer),
  argus_private.request_admin_job_retry(uuid,text,text,uuid),
  argus_private.request_admin_privacy_retry(uuid,text,text,uuid)
to argus_staff;
grant execute on function argus_private.consume_staff_step_up(text,uuid,text,uuid)
to argus_jobs_owner;

revoke select,insert,update,delete on argus_private.outbox_events,
  argus_private.job_runs,argus_private.job_attempts,argus_private.dead_letter_events,
  argus_private.consumer_receipts
from argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;
revoke select,insert,update,delete on argus_app.privacy_requests
from argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;

grant usage on schema cron to argus_jobs_owner;
grant select on cron.job,cron.job_run_details to argus_jobs_owner;

create or replace function argus_private.read_job_operational_signals()
returns table(signal_name text,signal_value bigint,observed_at timestamptz)
language plpgsql stable security definer
set search_path=pg_catalog,argus_private,pgmq,cron as $$
declare observed timestamptz:=pg_catalog.clock_timestamp();
declare queue_metrics record;
begin
  if not argus_private.has_staff_permission('operations:read') then
    raise exception 'staff_permission_required' using errcode='42501';
  end if;
  select * into queue_metrics from argus_private.queue_adapter_metrics();
  return query
  select 'queue_depth',queue_metrics.queue_depth,observed
  union all
  select 'queue_oldest_age_seconds',queue_metrics.oldest_age_seconds,observed
  union all
  select 'expired_job_leases',pg_catalog.count(*)::bigint,observed
    from argus_private.job_runs
   where status='leased' and leased_until<observed
  union all
  select 'attempts_last_hour',pg_catalog.count(*)::bigint,observed
    from argus_private.job_attempts where started_at>=observed-interval '1 hour'
  union all
  select 'dead_letters_last_day',pg_catalog.count(*)::bigint,observed
    from argus_private.dead_letter_events where occurred_at>=observed-interval '1 day'
  union all
  select 'cron_failures_last_day',pg_catalog.count(*)::bigint,observed
    from cron.job_run_details where status='failed' and start_time>=observed-interval '1 day'
  union all
  select 'dispatch_failures',pg_catalog.count(*)::bigint,observed
    from argus_private.worker_dispatches where state in ('failed','reconciliation')
  union all
  select 'external_effect_reconciliation',pg_catalog.count(*)::bigint,observed
    from argus_private.external_effects where state in ('effect_unknown','failed','reconciliation')
  union all
  select 'storage_reconciliation',pg_catalog.count(*)::bigint,observed
    from argus_private.managed_storage_objects where state='reconciliation'
  union all
  select 'database_lock_waits',pg_catalog.count(*)::bigint,observed
    from pg_catalog.pg_locks where not granted
  union all
  select 'worker_runtime_p95_ms',coalesce((pg_catalog.percentile_disc(0.95)
    within group (order by extract(epoch from (completed_at-started_at))*1000))::bigint,0),observed
    from argus_private.job_attempts
   where completed_at is not null and started_at>=observed-interval '1 day';
end
$$;
alter function argus_private.read_job_operational_signals() owner to argus_jobs_owner;
revoke all on function argus_private.read_job_operational_signals()
from public,anon,authenticated,argus_runtime,argus_member,argus_callback,argus_worker;
grant execute on function argus_private.read_job_operational_signals() to argus_staff;

comment on table argus_private.job_event_registry is
  'Versioned source of SQL routing, effect ownership, retry, visibility, and redacted dead-letter policy; parity-enforced with src/jobs/registry.ts.';
comment on table argus_private.managed_storage_objects is
  'Immutable Storage identities with truthful structural verification, publication, tombstone, deletion, and reconciliation states. No malware attestation is claimed.';
comment on table argus_private.privacy_export_generations is
  'One deterministic sealed source snapshot per export generation; retries after failure create a new generation.';

revoke create on schema argus_private from argus_jobs_owner;
do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_jobs_owner,argus_identity_owner,argus_app_owner from %1$I granted by %1$I',
    current_user
  );
end
$membership$;

commit;

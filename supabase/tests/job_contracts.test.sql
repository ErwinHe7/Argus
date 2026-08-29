begin;

do $membership$ begin
  execute pg_catalog.format(
    'grant argus_jobs_owner to %I with set true',current_user
  );
end $membership$;
grant usage on schema extensions to argus_jobs_owner;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(51);

select has_role('argus_jobs_owner','durable work has one dedicated capability owner');
select ok(
  not (select rolcanlogin from pg_roles where rolname='argus_jobs_owner'),
  'durable-work owner cannot log in'
);
select ok(
  not has_schema_privilege('argus_jobs_owner','argus_private','create'),
  'durable-work owner retains no schema creation capability after migration'
);
select set_eq(
  $$select table_name||':'||privilege_type
      from information_schema.role_table_grants
     where grantee='argus_jobs_owner' and table_schema='pgmq'$$,
  $$values ('q_argus_jobs:SELECT'),('q_argus_jobs:INSERT'),
    ('q_argus_jobs:UPDATE'),('q_argus_jobs:DELETE'),
    ('a_argus_jobs:SELECT'),('a_argus_jobs:INSERT')$$,
  'queue adapter owner has exact relation privileges for the Argus queue'
);
select set_eq(
  $$select routine.oid::regprocedure::text
      from pg_proc routine
      join pg_namespace namespace on namespace.oid=routine.pronamespace
      join lateral aclexplode(coalesce(routine.proacl,acldefault('f',routine.proowner))) acl
        on true
     where namespace.nspname='pgmq'
       and acl.grantee='argus_jobs_owner'::regrole and acl.privilege_type='EXECUTE'$$,
  $$values ('pgmq.format_table_name(text,text)'),('pgmq.send(text,jsonb)'),
    ('pgmq.send(text,jsonb,jsonb,timestamp with time zone)'),
    ('pgmq.read(text,integer,integer,jsonb)'),('pgmq.archive(text,bigint)'),
    ('pgmq.delete(text,bigint)'),('pgmq.set_vt(text,bigint,integer)')$$,
  'queue adapter owner has exact PGMQ function privileges'
);
select has_table('argus_private','job_event_registry','versioned job event registry exists');
select has_table('argus_private','job_schedule_registry','versioned job schedule registry exists');
select is(
  (select count(*)::bigint from argus_private.job_event_registry),15::bigint,
  'all retained event contracts are registered once'
);
select set_eq(
  $$select event_type from argus_private.job_event_registry$$,
  $$values
    ('briefing.daily.requested'),('briefing.weekly.requested'),
    ('briefing.moon_cycle.requested'),('briefing.daily.generated'),
    ('briefing.weekly.generated'),('briefing.moon_cycle.generated'),
    ('media.structural_validation.requested'),('media.quarantine.cleanup'),
    ('content-report.created'),('privacy.export.requested'),
    ('privacy.deletion.requested'),('privacy.export.retention.requested'),
    ('webull.token.refresh.requested'),('webull.projection.refresh.requested'),
    ('webull.command.reconciliation.requested')$$,
  'SQL event registry is the reviewed U6 set'
);
select is(
  (select count(*)::bigint from argus_private.job_event_registry
    where event_type='media.scan.requested'),0::bigint,
  'no event claims an unattested malware scan'
);
select ok(
  not exists(select 1 from argus_private.job_event_registry
    where payload_version<>1 or not enabled
       or visibility_seconds not between 15 and 55
       or max_attempts not between 1 and 10
       or retry_base_seconds<1 or retry_cap_seconds<retry_base_seconds
       or retry_cap_seconds>900 or dead_letter_payload<>'redacted'),
  'every registered event has bounded visibility, retry, and redacted dead-letter policy'
);

set local role argus_jobs_owner;
select throws_ok(
  $$insert into argus_private.outbox_events(
      topic,event_type,event_version,aggregate_id,dedupe_key
    ) values (
      'argus_jobs','briefing.daily.requested',1,
      '00000000-0000-4000-8000-000000000001','u6-unscoped-member-event'
    )$$,
  '23514','member_event_scope_required',
  'member-owned registry events require the full lifecycle scope'
);
select throws_ok(
  $$insert into argus_private.outbox_events(
      tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
      aggregate_id,dedupe_key
    ) values (
      '00000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000003',
      '00000000-0000-4000-8000-000000000004',1,
      'argus_jobs','privacy.deletion.requested',1,
      '00000000-0000-4000-8000-000000000005','u6-scoped-global-event'
    )$$,
  '23514','global_event_must_be_unscoped',
  'global registry events cannot carry a forged member scope'
);
select throws_ok(
  $$insert into argus_private.outbox_events(
      topic,event_type,event_version,aggregate_id,dedupe_key
    ) values (
      'brokerage_refresh','privacy.deletion.requested',1,
      '00000000-0000-4000-8000-000000000006','u6-topic-mismatch'
    )$$,
  '23514','event_registration_mismatch',
  'outbox topic must match the versioned event registration'
);
reset role;

select is(
  (select count(*)::bigint from argus_private.job_schedule_registry),3::bigint,
  'only three U6 coordination schedules are registered'
);
select set_eq(
  $$select schedule_name||':'||schedule_expression||':'||command
      from argus_private.job_schedule_registry$$,
  $$values
    ('argus-durable-work-coordinate:* * * * *:select argus_private.coordinate_argus_durable_work(25);'),
    ('argus-worker-dispatch-enqueue:* * * * *:select argus_private.enqueue_worker_dispatch();'),
    ('argus-webull-recovery-coordinate:*/5 * * * *:select argus_private.coordinate_webull_recovery(25);')$$,
  'schedule registry is exact and coordinator-only'
);
select ok(
  not exists(select 1 from argus_private.job_schedule_registry
    where command~* '(pgmq\.|net\.|http|cron\.|insert|update|delete)'),
  'Cron commands contain no queue, network, or direct DML operation'
);
select is(
  (select count(*)::bigint from argus_private.job_schedule_registry
    where retained_run_days=7),3::bigint,
  'every Argus schedule declares seven-day run-detail retention'
);
select set_eq(
  $$select job.jobname||':'||job.schedule||':'||job.command
      from cron.job job
      join argus_private.job_schedule_registry registry
        on registry.schedule_name=job.jobname$$,
  $$select schedule_name||':'||schedule_expression||':'||command
      from argus_private.job_schedule_registry$$,
  'deployed Cron catalog matches the reviewed registry'
);

select set_eq(
  $$select routine.proname
      from pg_proc routine
      join pg_namespace namespace on namespace.oid=routine.pronamespace
     where namespace.nspname='argus_private' and routine.prosrc like '%pgmq.%'$$,
  $$values ('queue_adapter_send'),('queue_adapter_read'),
    ('queue_adapter_archive'),('queue_adapter_delete'),
    ('queue_adapter_set_visibility'),('queue_adapter_metrics')$$,
  'pgmq is referenced only by the six queue-adapter operations'
);
select ok(
  not has_schema_privilege('argus_worker','pgmq','usage'),
  'worker cannot use the pgmq schema directly'
);
select ok(
  not exists(
    select 1 from pg_class relation
    join pg_namespace namespace on namespace.oid=relation.relnamespace
    where namespace.nspname='pgmq'
      and has_table_privilege('argus_worker',relation.oid,'select,insert,update,delete')
  ),
  'worker has no direct queue relation action'
);
select ok(
  not exists(
    select 1 from pg_policy policy
     where (select oid from pg_roles where rolname='argus_jobs_owner')=
       any(policy.polroles)
     group by policy.polrelid,policy.polcmd
    having count(*)>1
  ),
  'jobs owner has one reviewed policy per relation action'
);
select ok(
  not exists(
    select 1 from pg_proc routine
    join pg_namespace namespace on namespace.oid=routine.pronamespace
    where namespace.nspname='argus_private'
      and routine.proname like 'queue_adapter_%'
      and has_function_privilege('argus_worker',routine.oid,'execute')
  ),
  'worker cannot execute the pgmq adapter directly'
);
select set_eq(
  $$select routine.proname
      from pg_proc routine
      join pg_namespace namespace on namespace.oid=routine.pronamespace
     where namespace.nspname='argus_private'
       and routine.proname in (
         'relay_outbox','claim_next_argus_job','complete_argus_job',
         'fail_argus_job','recover_expired_work'
       ) and has_function_privilege('argus_worker',routine.oid,'execute')$$,
  $$values ('relay_outbox'),('claim_next_argus_job'),('complete_argus_job'),
    ('fail_argus_job'),('recover_expired_work')$$,
  'worker receives only the high-level queue lifecycle capabilities'
);
select ok(
  not has_function_privilege(
    'argus_member','argus_private.claim_next_argus_job(integer)','execute'
  ),
  'member cannot claim background work'
);
select ok(
  not has_function_privilege(
    'argus_worker','net.http_post(text,jsonb,jsonb,jsonb,integer)','execute'
  ) and not has_table_privilege(
    'argus_worker','vault.decrypted_secrets','select'
  ),
  'worker cannot call pg_net or read decrypted Vault secrets'
);
select ok(
  not exists(
    select 1 from information_schema.role_table_grants grant_row
     where grant_row.grantee='argus_worker'
       and grant_row.privilege_type in ('INSERT','UPDATE','DELETE')
       and (grant_row.table_schema,grant_row.table_name) in (
         ('argus_private','outbox_events'),('argus_private','job_runs'),
         ('argus_private','job_attempts'),('argus_private','consumer_receipts'),
         ('argus_private','managed_storage_objects'),
         ('argus_private','external_effects'),
         ('argus_private','privacy_export_generations'),
         ('argus_private','media_upload_intents'),
         ('argus_app','privacy_requests'),('argus_app','media_assets')
       )
  ),
  'worker mutates U6 state only through reviewed capabilities'
);
select ok(
  not exists(
    select 1 from information_schema.role_table_grants grant_row
     where grant_row.grantee='argus_member'
       and grant_row.privilege_type in ('INSERT','UPDATE','DELETE')
       and (grant_row.table_schema,grant_row.table_name) in (
         ('argus_private','outbox_events'),('argus_private','job_runs'),
         ('argus_private','managed_storage_objects'),
         ('argus_private','external_effects'),
         ('argus_private','privacy_export_generations'),
         ('argus_private','media_upload_intents'),
         ('argus_app','privacy_requests'),('argus_app','media_assets')
       )
  ),
  'member cannot directly mutate durable-work, export, or Storage authority'
);
select set_eq(
  $$select routine.proname
      from pg_proc routine
      join pg_namespace namespace on namespace.oid=routine.pronamespace
     where namespace.nspname='argus_private'
       and pg_get_userbyid(routine.proowner)='argus_jobs_owner'
       and has_function_privilege('argus_member',routine.oid,'execute')$$,
  $$values ('begin_member_deletion'),('get_member_deletion_tombstone'),
    ('request_privacy_export'),('list_member_privacy_requests'),
    ('prepare_privacy_export_download'),('confirm_privacy_export_download'),
    ('create_media_upload_intent'),('finalize_media_upload'),
    ('get_member_media_upload_intent')$$,
  'member receives the exact composed U6 command and read capabilities'
);
select is(
  (select count(*)::bigint from pg_proc routine
    join pg_namespace namespace on namespace.oid=routine.pronamespace
    where namespace.nspname='argus_private'
      and pg_get_userbyid(routine.proowner)='argus_jobs_owner'
      and has_function_privilege('argus_callback',routine.oid,'execute')),
  0::bigint,
  'callback receives no U6 owner capability'
);

select set_eq(
  $$select policyname||':'||cmd from pg_policies
     where schemaname='storage' and tablename='objects'
       and policyname like 'argus_%'$$,
  $$values ('argus_u6_managed_media_select:SELECT'),
    ('argus_u6_managed_media_insert:INSERT')$$,
  'Storage exposes only allocated immutable create and published read policies'
);
select ok(
  not exists(select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and roles::text~'authenticated' and cmd in ('UPDATE','DELETE')),
  'authenticated callers receive no Storage replace or delete policy'
);
select ok(
  (select relforcerowsecurity from pg_class relation
    where relation.oid='argus_private.managed_storage_objects'::regclass),
  'managed Storage authority forces RLS'
);
select ok(
  not exists(
    select 1 from pg_class relation
    where relation.oid=any(array[
      'argus_private.job_event_registry'::regclass,
      'argus_private.job_schedule_registry'::regclass,
      'argus_private.managed_storage_objects'::regclass,
      'argus_private.external_effects'::regclass,
      'argus_private.privacy_export_generations'::regclass,
      'argus_private.privacy_export_generation_rows'::regclass,
      'argus_private.privacy_export_generation_collections'::regclass,
      'argus_private.privacy_export_generation_objects'::regclass,
      'argus_private.worker_dispatches'::regclass,
      'argus_private.storage_access_leases'::regclass
    ]) and not relation.relforcerowsecurity
  ),
  'every new U6 private relation forces RLS'
);
select ok(
  exists(select 1 from pg_constraint constraint_row
    where constraint_row.conrelid='argus_private.external_effects'::regclass
      and constraint_row.contype='u'
      and pg_get_constraintdef(constraint_row.oid)=
        'UNIQUE NULLS NOT DISTINCT (event_id, effect_kind, generation_id)'),
  'one event generation has at most one checkpoint per external effect kind'
);
select has_index(
  'argus_private','external_effects','external_effects_recovery_idx',
  'external-effect reconciliation has a due-state index'
);
select is(
  (select count(*)::bigint
     from pg_constraint foreign_key
     join pg_class relation on relation.oid=foreign_key.conrelid
     join pg_namespace namespace on namespace.oid=relation.relnamespace
    where foreign_key.contype='f'
      and (namespace.nspname,relation.relname) in (
        ('argus_app','privacy_requests'),('argus_app','media_assets'),
        ('argus_private','outbox_events'),('argus_private','job_runs'),
        ('argus_private','consumer_receipts'),
        ('argus_private','media_upload_intents'),
        ('argus_private','privacy_export_artifacts'),
        ('argus_private','managed_storage_objects'),
        ('argus_private','external_effects'),
        ('argus_private','privacy_export_generations'),
        ('argus_private','privacy_export_generation_rows'),
        ('argus_private','privacy_export_generation_collections'),
        ('argus_private','privacy_export_generation_objects'),
        ('argus_private','storage_access_leases'),
        ('argus_private','deletion_tombstones'),
        ('argus_private','briefing_generation_requests'),
        ('argus_private','in_app_notification_receipts')
      ) and not exists (
        select 1 from pg_index candidate
         where candidate.indrelid=foreign_key.conrelid
           and candidate.indisvalid and candidate.indisready
           and candidate.indpred is null
           and (candidate.indkey::smallint[])
             [0:cardinality(foreign_key.conkey)-1]=foreign_key.conkey
      )),
  0::bigint,
  'every U6-owned foreign key has a matching leading-column index'
);
select ok(
  has_function_privilege(
    'argus_staff','argus_private.read_job_operational_signals()','execute'
  ) and not has_function_privilege(
    'argus_worker','argus_private.read_job_operational_signals()','execute'
  ),
  'only staff diagnostics can read bounded operational signals'
);
select has_function(
  'argus_private','list_job_diagnostics',array['integer'],
  'job diagnostics are exposed through one bounded capability'
);
select has_function(
  'argus_private','list_privacy_request_diagnostics',array['integer'],
  'privacy diagnostics are exposed through one bounded capability'
);
select set_eq(
  $$select routine.proname
      from pg_proc routine
      join pg_namespace namespace on namespace.oid=routine.pronamespace
     where namespace.nspname='argus_private'
       and pg_get_userbyid(routine.proowner)='argus_jobs_owner'
       and has_function_privilege('argus_staff',routine.oid,'execute')$$,
  $$values ('read_job_operational_signals'),('list_job_diagnostics'),
    ('list_privacy_request_diagnostics'),('request_admin_job_retry'),
    ('request_admin_privacy_retry')$$,
  'staff receives the exact reviewed U6 diagnostics and retry capabilities'
);
select ok(
  not exists(
    select 1 from information_schema.role_table_grants grant_row
     where grant_row.grantee in (
       'argus_runtime','argus_member','argus_staff','argus_callback','argus_worker'
     ) and grant_row.privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
       and (grant_row.table_schema,grant_row.table_name) in (
         ('argus_private','outbox_events'),('argus_private','job_runs'),
         ('argus_private','job_attempts'),('argus_private','dead_letter_events'),
         ('argus_private','consumer_receipts'),('argus_app','privacy_requests')
       )
  ),
  'request and worker roles have no direct job or privacy-request table capability'
);
select ok(
  pg_get_functiondef(
    'argus_private.request_admin_job_retry(uuid,text,text,uuid)'::regprocedure
  ) not like '%media.scan.requested%'
  and pg_get_functiondef(
    'argus_private.request_admin_privacy_retry(uuid,text,text,uuid)'::regprocedure
  ) like '%job_event_registry%',
  'administrative retry routing is registry-backed and contains no stale scan event'
);
select set_eq(
  $$select routine.proname
      from pg_proc routine
      join pg_namespace namespace on namespace.oid=routine.pronamespace
     where pg_get_userbyid(routine.proowner)<>'argus_jobs_owner'
       and namespace.nspname='argus_private'
       and has_function_privilege('argus_jobs_owner',routine.oid,'execute')$$,
  $$values ('read_trusted_request_context'),('lock_open_member_lifecycle'),
    ('has_staff_permission'),('consume_staff_step_up'),
    ('read_brokerage_privacy_export_rows'),('purge_member_brokerage_data'),
    ('purge_member_application_data'),('purge_member_identity_data')$$,
  'jobs owner composes only the eight reviewed cross-domain ports'
);
select ok(
  has_function_privilege(
    'postgres','argus_private.assert_member_purge_execution(uuid)','execute'
  ) and not has_function_privilege(
    'argus_worker','argus_private.assert_member_purge_execution(uuid)','execute'
  ),
  'retained purge orchestration receives only the deletion-event proof helper'
);
select is(
  (select count(*)::bigint from pg_proc routine
   where pg_get_userbyid(routine.proowner)='argus_jobs_owner'
     and case when routine.prokind in ('f','p')
       then pg_get_functiondef(routine.oid) else '' end~
       'trusted_request_(tenant|lifecycle|user)_id'),
  0::bigint,
  'jobs-owner routines compose trusted context once instead of scalar helpers'
);
select ok(
  not exists(
    select 1 from unnest(array[
      'queue_depth','queue_oldest_age_seconds','expired_job_leases',
      'attempts_last_hour','dead_letters_last_day','cron_failures_last_day',
      'dispatch_failures','external_effect_reconciliation',
      'storage_reconciliation','database_lock_waits','worker_runtime_p95_ms'
    ]) signal_name
    where pg_get_functiondef(
      'argus_private.read_job_operational_signals()'::regprocedure
    ) not like '%'||signal_name||'%'
  ),
  'staff diagnostics declare the complete bounded U6 signal inventory'
);

set local role argus_jobs_owner;
select results_eq(
  $$update argus_private.job_event_registry set enabled=false
     where event_type='content-report.created' returning event_type$$,
  $$select null::text where false$$,
  'registry owner has no mutable event-registry path'
);
select results_eq(
  $$delete from argus_private.job_schedule_registry
     where schedule_name='argus-durable-work-coordinate' returning schedule_name$$,
  $$select null::text where false$$,
  'registry owner has no mutable schedule-registry path'
);
reset role;

select ok(
  not exists(select 1 from pg_proc routine
    join pg_namespace namespace on namespace.oid=routine.pronamespace
    where namespace.nspname='argus_private'
      and pg_get_userbyid(routine.proowner)='argus_jobs_owner'
      and routine.prorettype<>'trigger'::regtype
      and not routine.prosecdef),
  'every jobs-owner entrypoint is SECURITY DEFINER'
);

select * from finish();
rollback;

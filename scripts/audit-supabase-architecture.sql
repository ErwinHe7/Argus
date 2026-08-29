-- U1 read-only Supabase/Postgres architecture inventory.
-- Run only against an explicitly selected target. This script never reads
-- secret values and makes no catalog, application, Auth, Storage, queue,
-- schedule, role, extension, or migration-ledger changes.

begin transaction isolation level repeatable read read only;
set local statement_timeout = '60s';
set local lock_timeout = '2s';
set local idle_in_transaction_session_timeout = '60s';

select 'target_identity' as inventory_section,
       jsonb_build_object(
         'database', current_database(),
         'database_oid', (select oid from pg_database where datname=current_database()),
         'server_version_num', current_setting('server_version_num'),
         'current_user', current_user,
         'captured_at', statement_timestamp()
       ) as inventory;

select 'migration_ledger' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'version', version,
         'statements_sha256', encode(extensions.digest(
           array_to_string(statements, E'\n'), 'sha256'
         ), 'hex')
       ) order by version), '[]'::jsonb) as inventory
  from supabase_migrations.schema_migrations;

select 'relations' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'schema', namespace.nspname,
         'name', relation.relname,
         'kind', relation.relkind,
         'owner', owner.rolname,
         'rls', relation.relrowsecurity,
         'force_rls', relation.relforcerowsecurity,
         'persistence', relation.relpersistence,
         'acl', coalesce(relation.relacl::text, '')
       ) order by namespace.nspname, relation.relname), '[]'::jsonb) as inventory
  from pg_class relation
  join pg_namespace namespace on namespace.oid=relation.relnamespace
  join pg_roles owner on owner.oid=relation.relowner
 where namespace.nspname in (
   'argus_app','argus_brokerage','argus_private','public','graphql_public'
 ) and relation.relkind in ('r','p','v','m','S');

select 'columns' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'relation', quote_ident(column_row.table_schema)||'.'||quote_ident(column_row.table_name),
         'ordinal', column_row.ordinal_position,
         'name', column_row.column_name,
         'type', column_row.udt_schema||'.'||column_row.udt_name,
         'nullable', column_row.is_nullable='YES',
         'default', column_row.column_default,
         'identity', column_row.is_identity='YES',
         'generated', column_row.is_generated
       ) order by column_row.table_schema,column_row.table_name,column_row.ordinal_position),
       '[]'::jsonb) as inventory
  from information_schema.columns column_row
 where column_row.table_schema in ('argus_app','argus_brokerage','argus_private');

select 'constraints' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'relation', namespace.nspname||'.'||relation.relname,
         'name', constraint_row.conname,
         'type', constraint_row.contype,
         'definition', pg_get_constraintdef(constraint_row.oid, true),
         'validated', constraint_row.convalidated,
         'deferrable', constraint_row.condeferrable,
         'deferred', constraint_row.condeferred
       ) order by namespace.nspname,relation.relname,constraint_row.conname),
       '[]'::jsonb) as inventory
  from pg_constraint constraint_row
  join pg_class relation on relation.oid=constraint_row.conrelid
  join pg_namespace namespace on namespace.oid=relation.relnamespace
 where namespace.nspname in ('argus_app','argus_brokerage','argus_private');

select 'foreign_key_index_review' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'relation', namespace.nspname||'.'||relation.relname,
         'constraint', foreign_key.conname,
         'columns', foreign_key.conkey,
         'has_referencing_index', exists (
           select 1 from pg_index candidate
            where candidate.indrelid=foreign_key.conrelid
              and candidate.indisvalid
              and candidate.indisready
              and candidate.indpred is null
              and candidate.indkey::smallint[] @> foreign_key.conkey
         )
       ) order by namespace.nspname,relation.relname,foreign_key.conname),
       '[]'::jsonb) as inventory
  from pg_constraint foreign_key
  join pg_class relation on relation.oid=foreign_key.conrelid
  join pg_namespace namespace on namespace.oid=relation.relnamespace
 where foreign_key.contype='f'
   and namespace.nspname in ('argus_app','argus_brokerage','argus_private');

select 'indexes' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'schema', schemaname,
         'relation', tablename,
         'name', indexname,
         'definition', indexdef
       ) order by schemaname,tablename,indexname), '[]'::jsonb) as inventory
  from pg_indexes
 where schemaname in ('argus_app','argus_brokerage','argus_private');

select 'policies' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'schema', schemaname,
         'relation', tablename,
         'name', policyname,
         'permissive', permissive,
         'roles', roles,
         'command', cmd,
         'using', qual,
         'check', with_check
       ) order by schemaname,tablename,policyname), '[]'::jsonb) as inventory
  from pg_policies
 where schemaname in (
   'argus_app','argus_brokerage','argus_private','storage','realtime'
 );

select 'table_grants' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'grantor', grantor,
         'grantee', grantee,
         'relation', table_schema||'.'||table_name,
         'privilege', privilege_type,
         'grantable', is_grantable='YES'
       ) order by table_schema,table_name,grantee,privilege_type), '[]'::jsonb) as inventory
  from information_schema.role_table_grants
 where table_schema in (
   'argus_app','argus_brokerage','argus_private','storage','pgmq','cron'
 );

select 'routines' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'signature', function_row.oid::regprocedure::text,
         'owner', owner.rolname,
         'language', language.lanname,
         'security_definer', function_row.prosecdef,
         'volatility', function_row.provolatile,
         'parallel', function_row.proparallel,
         'config', coalesce(function_row.proconfig, array[]::text[]),
         'acl', coalesce(function_row.proacl::text, ''),
         'definition_sha256', encode(extensions.digest(
           pg_get_functiondef(function_row.oid), 'sha256'
         ), 'hex')
       ) order by function_row.oid::regprocedure::text), '[]'::jsonb) as inventory
  from pg_proc function_row
  join pg_namespace namespace on namespace.oid=function_row.pronamespace
  join pg_roles owner on owner.oid=function_row.proowner
  join pg_language language on language.oid=function_row.prolang
 where namespace.nspname in ('argus_app','argus_brokerage','argus_private');

select 'routine_grants' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'grantor', grantor,
         'grantee', grantee,
         'routine', specific_schema||'.'||routine_name||'/'||specific_name,
         'privilege', privilege_type,
         'grantable', is_grantable='YES'
       ) order by specific_schema,routine_name,specific_name,grantee), '[]'::jsonb) as inventory
  from information_schema.role_routine_grants
 where specific_schema in ('argus_app','argus_brokerage','argus_private');

select 'triggers' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'relation', namespace.nspname||'.'||relation.relname,
         'name', trigger_row.tgname,
         'enabled', trigger_row.tgenabled,
         'definition', pg_get_triggerdef(trigger_row.oid, true)
       ) order by namespace.nspname,relation.relname,trigger_row.tgname),
       '[]'::jsonb) as inventory
  from pg_trigger trigger_row
  join pg_class relation on relation.oid=trigger_row.tgrelid
  join pg_namespace namespace on namespace.oid=relation.relnamespace
 where not trigger_row.tgisinternal
   and namespace.nspname in (
     'argus_app','argus_brokerage','argus_private','auth','storage'
   );

select 'roles' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'name', role_row.rolname,
         'login', role_row.rolcanlogin,
         'inherit', role_row.rolinherit,
         'superuser', role_row.rolsuper,
         'create_role', role_row.rolcreaterole,
         'create_db', role_row.rolcreatedb,
         'replication', role_row.rolreplication,
         'bypass_rls', role_row.rolbypassrls,
         'config', coalesce(role_row.rolconfig,array[]::text[])
       ) order by role_row.rolname), '[]'::jsonb) as inventory
  from pg_roles role_row
 where role_row.rolname in (
   'anon','authenticated','service_role','supabase_auth_admin','supabase_storage_admin',
   'argus_runtime','argus_worker','argus_waitlist',
   'argus_edge','argus_worker_edge','argus_waitlist_edge'
 );

select 'role_memberships' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'member', member.rolname,
         'role', parent.rolname,
         'admin', membership.admin_option,
         'inherit', to_jsonb(membership)->'inherit_option',
         'set', to_jsonb(membership)->'set_option'
       ) order by member.rolname,parent.rolname), '[]'::jsonb) as inventory
  from pg_auth_members membership
  join pg_roles member on member.oid=membership.member
  join pg_roles parent on parent.oid=membership.roleid
 where member.rolname like 'argus_%' or parent.rolname like 'argus_%';

select 'extensions' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'name', extension.extname,
         'version', extension.extversion,
         'schema', namespace.nspname,
         'relocatable', extension.extrelocatable
       ) order by extension.extname), '[]'::jsonb) as inventory
  from pg_extension extension
  join pg_namespace namespace on namespace.oid=extension.extnamespace;

select 'queues' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object('name',queue_name)
         order by queue_name), '[]'::jsonb) as inventory
  from pgmq.meta;

select 'cron' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'name', jobname,
         'schedule', schedule,
         'database', database,
         'username', username,
         'active', active,
         'command_sha256', encode(extensions.digest(command,'sha256'),'hex')
       ) order by jobname), '[]'::jsonb) as inventory
  from cron.job;

select 'storage_buckets' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'id', id,
         'public', public,
         'file_size_limit', file_size_limit,
         'allowed_mime_types', allowed_mime_types
       ) order by id), '[]'::jsonb) as inventory
  from storage.buckets
 where id in ('member-media','media-quarantine','privacy-exports');

select 'vault_names_only' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object('name',name) order by name),
         '[]'::jsonb) as inventory
  from vault.secrets
 where name like 'argus_%';

select 'state_counts' as inventory_section,
       jsonb_object_agg(state_class, row_count order by state_class) as inventory
  from (
    select 'auth.users' state_class, count(*)::bigint row_count from auth.users
    union all select 'argus_app.members',count(*) from argus_app.members
    union all select 'argus_private.staff_principals',count(*) from argus_private.staff_principals
    union all select 'storage.objects',count(*) from storage.objects
      where bucket_id in ('member-media','media-quarantine','privacy-exports')
    union all select 'outbox.unpublished',count(*) from argus_private.outbox_events
      where published_at is null
    union all select 'jobs.nonterminal',count(*) from argus_private.job_runs
      where status in ('queued','leased','running','retry')
    union all select 'commands.ambiguous',count(*) from argus_private.provider_commands
      where state in ('dispatching','ambiguous','reconciling','manual_review')
    union all select 'waitlist',count(*) from argus_private.waitlist_submissions
  ) counts;

select 'data_api_exposure' as inventory_section,
       coalesce(jsonb_agg(jsonb_build_object(
         'schema', namespace.nspname,
         'name', relation.relname,
         'kind', relation.relkind,
         'anon_select', has_table_privilege('anon',relation.oid,'select'),
         'authenticated_select', has_table_privilege('authenticated',relation.oid,'select')
       ) order by namespace.nspname,relation.relname), '[]'::jsonb) as inventory
  from pg_class relation
  join pg_namespace namespace on namespace.oid=relation.relnamespace
 where namespace.nspname in ('public','graphql_public')
   and relation.relkind in ('r','p','v','m');

select 'query_plan:owner_notifications' as inventory_section;
explain (format json)
select id,kind,title,body,read_at,created_at
  from argus_app.notifications
 where user_id='00000000-0000-0000-0000-000000000000'::uuid
 order by created_at desc,id desc limit 100;

select 'query_plan:editorial_publication' as inventory_section;
explain (format json)
select item.id,item.kind,item.slug,revision.id,revision.payload
  from argus_app.editorial_items item
  join argus_app.editorial_revisions revision
    on revision.id=item.current_published_revision_id
 where item.status='published'
 order by item.kind,item.slug,item.id limit 100;

select 'query_plan:discovery_search' as inventory_section;
explain (format json)
select id,slug,name from argus_app.catalog_assets
 where status='active' and lower(name) like '%argus%'
 order by lower(name),id limit 50;

select 'query_plan:outbox_claim' as inventory_section;
explain (format json)
select id from argus_private.outbox_events
 where published_at is null and available_at<=clock_timestamp()
 order by available_at,id for update skip locked limit 25;

select 'query_plan:job_claim' as inventory_section;
explain (format json)
select id from argus_private.job_runs
 where status in ('queued','retry')
   and coalesce(next_attempt_at,created_at)<=clock_timestamp()
 order by coalesce(next_attempt_at,created_at),id
 for update skip locked limit 25;

select 'query_plan:privacy_export' as inventory_section;
explain (format json)
select id,kind,title,body,read_at,created_at
  from argus_app.notifications
 where user_id='00000000-0000-0000-0000-000000000000'::uuid
   and (created_at,id) > ('epoch'::timestamptz,'00000000-0000-0000-0000-000000000000'::uuid)
 order by created_at,id limit 500;

select 'query_plan:privacy_purge' as inventory_section;
explain (format json)
select intent.bucket_id,intent.object_path
  from argus_private.deletion_tombstones tombstone
  join argus_private.media_upload_intents intent
    on intent.user_id=tombstone.user_id
 where tombstone.id='00000000-0000-0000-0000-000000000000'::uuid
   and tombstone.purge_phase in ('neutralized','storage_purged')
union all
select artifact.bucket_id,artifact.object_path
  from argus_private.deletion_tombstones tombstone
  join argus_private.privacy_export_artifacts artifact
    on artifact.user_id=tombstone.user_id
 where tombstone.id='00000000-0000-0000-0000-000000000000'::uuid
   and tombstone.purge_phase in ('neutralized','storage_purged');

select 'query_plan:brokerage_latest_projection' as inventory_section;
explain (format json)
select distinct on (resource_type)
       resource_type,availability,normalized_payload,provider_observed_at,fetched_at
  from argus_brokerage.projection_generations
 where user_id='00000000-0000-0000-0000-000000000000'::uuid
   and account_id='00000000-0000-0000-0000-000000000000'::uuid
 order by resource_type,generation desc;

select 'query_plan:webull_recovery' as inventory_section;
explain (format json)
select provider_command.id,provider_command.state,reconciliation.next_attempt_at
  from argus_private.provider_commands provider_command
  join argus_private.reconciliation_records reconciliation
    on reconciliation.command_id=provider_command.id
 where provider_command.state in ('dispatching','ambiguous','reconciling')
   and reconciliation.next_attempt_at<=clock_timestamp()
 order by reconciliation.next_attempt_at,provider_command.id
 for update of reconciliation skip locked limit 25;

rollback;

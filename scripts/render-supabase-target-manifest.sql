\set QUIET 1
begin transaction read only;
set local search_path = pg_catalog;

with manifest_rows as materialized (
  select 'schema|' || namespace.nspname || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'owner', owner.rolname,
      'acl', coalesce(namespace.nspacl::text, '')
    )::text, 'sha256'), 'hex') as row_text
  from pg_namespace namespace
  join pg_roles owner on owner.oid = namespace.nspowner
  where namespace.nspname in ('argus_app', 'argus_brokerage', 'argus_private')

  union all
  select 'relation|' || namespace.nspname || '.' || relation.relname || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'kind', relation.relkind,
      'persistence', relation.relpersistence,
      'owner', owner.rolname,
      'rls', relation.relrowsecurity,
      'force_rls', relation.relforcerowsecurity,
      'replica_identity', relation.relreplident,
      'acl', coalesce(relation.relacl::text, '')
    )::text, 'sha256'), 'hex')
  from pg_class relation
  join pg_namespace namespace on namespace.oid = relation.relnamespace
  join pg_roles owner on owner.oid = relation.relowner
  where namespace.nspname in ('argus_app', 'argus_brokerage', 'argus_private')
    and relation.relkind in ('r', 'p', 'v', 'm', 'S')

  union all
  select 'column|' || namespace.nspname || '.' || relation.relname || '.' || attribute.attname || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'position', attribute.attnum,
      'type', pg_catalog.format_type(attribute.atttypid, attribute.atttypmod),
      'not_null', attribute.attnotnull,
      'identity', attribute.attidentity,
      'generated', attribute.attgenerated,
      'default', pg_catalog.pg_get_expr(default_value.adbin, default_value.adrelid),
      'acl', coalesce(attribute.attacl::text, '')
    )::text, 'sha256'), 'hex')
  from pg_attribute attribute
  join pg_class relation on relation.oid = attribute.attrelid
  join pg_namespace namespace on namespace.oid = relation.relnamespace
  left join pg_attrdef default_value
    on default_value.adrelid = attribute.attrelid
   and default_value.adnum = attribute.attnum
  where namespace.nspname in ('argus_app', 'argus_brokerage', 'argus_private')
    and relation.relkind in ('r', 'p', 'v', 'm')
    and attribute.attnum > 0
    and not attribute.attisdropped

  union all
  select 'constraint|' || namespace.nspname || '.' || relation.relname || '.' || constraint_row.conname || '|' ||
    encode(extensions.digest(pg_catalog.pg_get_constraintdef(constraint_row.oid, true), 'sha256'), 'hex')
  from pg_constraint constraint_row
  join pg_class relation on relation.oid = constraint_row.conrelid
  join pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname in ('argus_app', 'argus_brokerage', 'argus_private')

  union all
  select 'index|' || namespace.nspname || '.' || relation.relname || '.' || index_relation.relname || '|' ||
    encode(extensions.digest(pg_catalog.pg_get_indexdef(index_relation.oid), 'sha256'), 'hex')
  from pg_index index_row
  join pg_class relation on relation.oid = index_row.indrelid
  join pg_class index_relation on index_relation.oid = index_row.indexrelid
  join pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname in ('argus_app', 'argus_brokerage', 'argus_private')

  union all
  select 'policy|' || schemaname || '.' || tablename || '.' || policyname || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'permissive', permissive,
      'roles', roles,
      'command', cmd,
      'using', qual,
      'check', with_check
    )::text, 'sha256'), 'hex')
  from pg_policies
  where schemaname in ('argus_app', 'argus_brokerage', 'argus_private')

  union all
  select 'function|' || namespace.nspname || '.' || function_row.proname ||
    '(' || pg_catalog.pg_get_function_identity_arguments(function_row.oid) || ')|' ||
    encode(extensions.digest(
      pg_catalog.pg_get_functiondef(function_row.oid) || '|' ||
      coalesce(function_row.proconfig::text, '') || '|' ||
      coalesce(function_row.proacl::text, ''),
      'sha256'
    ), 'hex')
  from pg_proc function_row
  join pg_namespace namespace on namespace.oid = function_row.pronamespace
  where namespace.nspname in ('argus_app', 'argus_brokerage', 'argus_private')

  union all
  select 'trigger|' || namespace.nspname || '.' || relation.relname || '.' || trigger_row.tgname || '|' ||
    encode(extensions.digest(pg_catalog.pg_get_triggerdef(trigger_row.oid, true), 'sha256'), 'hex')
  from pg_trigger trigger_row
  join pg_class relation on relation.oid = trigger_row.tgrelid
  join pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname in ('argus_app', 'argus_brokerage', 'argus_private')
    and not trigger_row.tgisinternal

  union all
  select 'view|' || namespace.nspname || '.' || relation.relname || '|' ||
    encode(extensions.digest(pg_catalog.pg_get_viewdef(relation.oid, true), 'sha256'), 'hex')
  from pg_class relation
  join pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname in ('argus_app', 'argus_brokerage', 'argus_private')
    and relation.relkind in ('v', 'm')

  union all
  select 'type|' || namespace.nspname || '.' || type_row.typname || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'kind', type_row.typtype,
      'category', type_row.typcategory,
      'owner', owner.rolname,
      'not_null', type_row.typnotnull,
      'base_type', case when type_row.typbasetype = 0 then null
        else pg_catalog.format_type(type_row.typbasetype, type_row.typtypmod) end,
      'default', type_row.typdefault,
      'acl', coalesce(type_row.typacl::text, ''),
      'enum_labels', coalesce((
        select jsonb_agg(enum_row.enumlabel order by enum_row.enumsortorder)
        from pg_enum enum_row
        where enum_row.enumtypid = type_row.oid
      ), '[]'::jsonb)
    )::text, 'sha256'), 'hex')
  from pg_type type_row
  join pg_namespace namespace on namespace.oid = type_row.typnamespace
  join pg_roles owner on owner.oid = type_row.typowner
  where namespace.nspname in ('argus_app', 'argus_brokerage', 'argus_private')
    and type_row.typrelid = 0

  union all
  select 'domain-constraint|' || namespace.nspname || '.' || type_row.typname || '.' ||
    constraint_row.conname || '|' ||
    encode(extensions.digest(pg_catalog.pg_get_constraintdef(constraint_row.oid, true), 'sha256'), 'hex')
  from pg_constraint constraint_row
  join pg_type type_row on type_row.oid = constraint_row.contypid
  join pg_namespace namespace on namespace.oid = type_row.typnamespace
  where namespace.nspname in ('argus_app', 'argus_brokerage', 'argus_private')

  union all
  select 'default-acl|' || owner.rolname || '|' || coalesce(namespace.nspname, '*') || '|' ||
    default_acl.defaclobjtype || '|' || encode(extensions.digest(default_acl.defaclacl::text, 'sha256'), 'hex')
  from pg_default_acl default_acl
  join pg_roles owner on owner.oid = default_acl.defaclrole
  left join pg_namespace namespace on namespace.oid = default_acl.defaclnamespace
  where namespace.nspname in ('argus_app', 'argus_brokerage', 'argus_private')

  union all
  select 'role|' || role_row.rolname || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'superuser', role_row.rolsuper,
      'inherit', role_row.rolinherit,
      'create_role', role_row.rolcreaterole,
      'create_db', role_row.rolcreatedb,
      'login', role_row.rolcanlogin,
      'replication', role_row.rolreplication,
      'bypass_rls', role_row.rolbypassrls,
      'connection_limit', role_row.rolconnlimit,
      'valid_until', role_row.rolvaliduntil
    )::text, 'sha256'), 'hex')
  from pg_roles role_row
  where role_row.rolname like 'argus\_%' escape '\'
     or role_row.rolname in (
       'anon', 'authenticated', 'service_role', 'authenticator',
       'postgres', 'supabase_admin'
     )

  union all
  select 'membership|' || member.rolname || '->' || granted.rolname || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'admin', membership.admin_option,
      'inherit', membership.inherit_option,
      'set', membership.set_option
    )::text, 'sha256'), 'hex')
  from pg_auth_members membership
  join pg_roles granted on granted.oid = membership.roleid
  join pg_roles member on member.oid = membership.member
  where member.rolname like 'argus\_%' escape '\'
     or granted.rolname like 'argus\_%' escape '\'

  union all
  select 'role-setting|' || role_row.rolname || '|' ||
    coalesce(database_row.datname, '*') || '|' ||
    encode(extensions.digest(setting.setconfig::text, 'sha256'), 'hex')
  from pg_db_role_setting setting
  join pg_roles role_row on role_row.oid = setting.setrole
  left join pg_database database_row on database_row.oid = setting.setdatabase
  where role_row.rolname like 'argus\_%' escape '\'

  union all
  select 'publication|' || publication.pubname || '|' ||
    table_row.schemaname || '.' || table_row.tablename || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'insert', publication.pubinsert,
      'update', publication.pubupdate,
      'delete', publication.pubdelete,
      'truncate', publication.pubtruncate,
      'row_filter', table_row.rowfilter,
      'columns', table_row.attnames
    )::text, 'sha256'), 'hex')
  from pg_publication publication
  join pg_publication_tables table_row on table_row.pubname = publication.pubname
  where table_row.schemaname in ('argus_app', 'argus_brokerage', 'argus_private')

  union all
  select 'extension|' || extension.extname || '|' ||
    namespace.nspname || '|' || extension.extversion
  from pg_extension extension
  join pg_namespace namespace on namespace.oid = extension.extnamespace
  where extension.extname in ('pgcrypto', 'pgmq', 'pg_cron', 'pg_net', 'supabase_vault')

  union all
  select 'migration|' || migration.version || '|' || coalesce(migration.name, '')
  from supabase_migrations.schema_migrations migration

  union all
  select 'reference|schema-contract|' || version
  from argus_private.schema_contract_versions

  union all
  select 'reference|kill-switch|' || name || '|' || enabled || '|' || coalesce(reason, '')
  from argus_private.kill_switches

  union all
  select 'reference|catalog-asset|' || id || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'slug', slug, 'symbol', symbol, 'name', name, 'type', asset_type,
      'currency', currency, 'exchange', exchange, 'status', status
    )::text, 'sha256'), 'hex')
  from argus_app.catalog_assets
  where id = '10000000-0000-4000-8000-000000000002'

  union all
  select 'reference|evidence-source|' || id || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'url', canonical_url, 'title', title, 'publisher', publisher,
      'published', published_at, 'retrieved', retrieved_at,
      'kind', source_kind, 'status', status
    )::text, 'sha256'), 'hex')
  from argus_app.evidence_sources
  where id = '10000000-0000-4000-8000-000000000003'

  union all
  select 'reference|evidence-claim|' || id || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'source', source_id, 'type', claim_type, 'summary', summary,
      'observed', observed_at, 'uncertainty', uncertainty, 'status', status
    )::text, 'sha256'), 'hex')
  from argus_app.evidence_claims
  where id = '10000000-0000-4000-8000-000000000004'

  union all
  select 'reference|editorial-item|' || id || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'kind', kind, 'slug', slug, 'status', status, 'created', created_at
    )::text, 'sha256'), 'hex')
  from argus_app.editorial_items
  where id = '10000000-0000-4000-8000-000000000001'

  union all
  select 'queue|' || queue_name
  from pgmq.meta
  where queue_name like 'argus\_%' escape '\'
     or queue_name like 'brokerage\_%' escape '\'

  union all
  select 'cron|' || jobname || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'schedule', schedule,
      'command', command,
      'database', database,
      'username', username,
      'active', active
    )::text, 'sha256'), 'hex')
  from cron.job
  where jobname like 'argus-%'

  union all
  select 'bucket|' || id || '|' ||
    encode(extensions.digest(jsonb_build_object(
      'name', name,
      'public', public,
      'file_size_limit', file_size_limit,
      'allowed_mime_types', allowed_mime_types
    )::text, 'sha256'), 'hex')
  from storage.buckets
  where id in ('member-media', 'media-quarantine', 'privacy-exports')

  union all
  select 'vault-name|' || name
  from vault.secrets
  where name is not null
), ordered_rows as materialized (
  select row_text from manifest_rows order by row_text
), fingerprint as (
  select encode(extensions.digest(
    coalesce(string_agg(row_text, E'\n' order by row_text), ''),
    'sha256'
  ), 'hex') as value
  from ordered_rows
)
select output
from (
  select 0 as section, 'contract_version: supabase-replay-target-v1' as output
  union all
  select 1, row_text from ordered_rows
  union all
  select 2, 'target_fingerprint|' || value from fingerprint
) rendered
order by section, output;

rollback;

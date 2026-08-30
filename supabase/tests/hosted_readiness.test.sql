begin;

do $membership$ begin
  execute pg_catalog.format(
    'grant argus_public_preview to %I with set true',current_user
  );
end $membership$;
grant usage on schema extensions to argus_public_preview;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(6);

select is(
  (select count(*)::bigint
     from argus_private.schema_contract_versions
    where version='webull-supabase-v1'),
  1::bigint,
  'the hosted target carries the reviewed private-schema contract'
);

select is(
  (select count(*)::bigint
     from pg_roles
    where rolname in (
      'argus_runtime','argus_member','argus_callback','argus_staff',
      'argus_public_preview'
    ) and (rolcanlogin or rolsuper or rolbypassrls or rolinherit)),
  0::bigint,
  'request capability roles are isolated NOLOGIN and non-BYPASSRLS roles'
);

select ok(
  not has_schema_privilege('anon','argus_app','usage')
    and not has_schema_privilege('authenticated','argus_app','usage')
    and not has_schema_privilege('anon','argus_brokerage','usage')
    and not has_schema_privilege('authenticated','argus_brokerage','usage')
    and not has_schema_privilege('anon','argus_private','usage')
    and not has_schema_privilege('authenticated','argus_private','usage')
    and not exists (
      select 1
        from information_schema.role_table_grants
       where grantee in ('anon','authenticated')
         and table_schema in ('argus_app','argus_brokerage','argus_private')
    )
    and not exists (
      select 1
        from pg_default_acl default_acl
        join pg_namespace namespace
          on namespace.oid=default_acl.defaclnamespace
        cross join lateral aclexplode(default_acl.defaclacl) privilege
        left join pg_roles grantee on grantee.oid=privilege.grantee
       where namespace.nspname in (
         'argus_app','argus_brokerage','argus_private'
       ) and (
         privilege.grantee=0
         or grantee.rolname in ('anon','authenticated')
       )
    ),
  'browser roles have neither current nor future Data API table authority'
);

select ok(
  not exists (
    select 1
      from pg_class relation
      join pg_namespace namespace on namespace.oid=relation.relnamespace
     where namespace.nspname in (
       'argus_app','argus_brokerage','argus_private'
     ) and relation.relkind in ('r','p')
       and (not relation.relrowsecurity or not relation.relforcerowsecurity)
  )
  and not exists (
    select 1
      from pg_index index_row
      join pg_class relation on relation.oid=index_row.indrelid
      join pg_namespace namespace on namespace.oid=relation.relnamespace
     where namespace.nspname in (
       'argus_app','argus_brokerage','argus_private'
     ) and (not index_row.indisvalid or not index_row.indisready)
  ),
  'hosted application relations force RLS and expose only ready valid indexes'
);

select is(
  (select array_agg(name order by name)
     from argus_private.kill_switches
    where enabled and name in (
      'background_workers','provider_egress','order_mutations'
    )),
  array['background_workers','order_mutations','provider_egress']::text[],
  'hosted acceptance runs while every external-effect fence is enabled'
);

set local role argus_public_preview;
select set_eq(
  $$select slug
      from argus_private.list_current_published_editorial_page(
        'ritual',10,null,null
      )
     where slug in ('local-reset-ritual','local-reset-astrology-ritual')$$,
  $$values ('local-reset-ritual'),('local-reset-astrology-ritual')$$,
  'required published beta ritual content is reachable through the bounded projection'
);
reset role;

select * from finish();
rollback;

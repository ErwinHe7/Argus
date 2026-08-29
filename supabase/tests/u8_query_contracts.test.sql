begin;

do $membership$ begin
  execute pg_catalog.format(
    'grant argus_app_owner,argus_edge,argus_identity_owner,argus_member,argus_staff,argus_public_preview to %I with set true',
    current_user
  );
end $membership$;
grant usage on schema extensions
  to argus_app_owner,argus_edge,argus_identity_owner,argus_member,argus_staff,
     argus_public_preview;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(54);

create or replace function pg_temp.u8_explain(p_sql text)
returns jsonb language plpgsql as $$
declare retained_plan jsonb;
begin
  execute 'explain (format json,costs off) '||p_sql into retained_plan;
  return retained_plan;
end
$$;

select has_table('argus_app','editorial_creators',
  'creator identity is normalized');
select has_column('argus_app','briefings','generation',
  'briefing generation is typed');
select has_column('argus_app','briefings','source_sequence',
  'briefing source sequence is typed');
select has_column('argus_app','briefing_sections','source_sequence',
  'section source sequence is typed');
select has_column('argus_app','briefing_sections','schema_version',
  'section schema version is typed');
select has_column('argus_app','briefing_sections','disclosure',
  'section disclosure is typed');
select has_column('argus_app','coven_qualifications','category',
  'Coven category is typed');
select has_column('argus_app','coven_qualifications','person_name',
  'Coven person name is typed');
select has_column('argus_app','coven_qualifications','effective_date',
  'Coven effective date is typed');
select has_column('argus_app','coven_qualifications','valid_to',
  'Coven validity end is typed');
select has_column('argus_app','coven_qualifications','verified_as_of',
  'Coven verification cutoff is typed');

select has_function('argus_private','list_member_briefings_page',
  array['integer','text','date','date','date','uuid'],
  'briefings expose one bounded keyset port');
select has_function('argus_private','list_member_briefing_sections',array['uuid'],
  'briefing sections expose typed rows');
select has_function('argus_private','list_member_circles_page',
  array['integer','boolean','boolean','timestamp with time zone','uuid'],
  'Circles expose one archive-aware keyset port');
select has_function('argus_private','list_published_assets_page',
  array['integer','text','text','text','uuid'],
  'published assets expose a keyset port');
select has_function('argus_private','list_published_grimoires_page',
  array['integer','text','text','uuid'],
  'published Grimoires expose a keyset port');
select has_function('argus_private','list_published_circle_templates_page',
  array['integer','text','text','uuid'],
  'published templates expose a creator-filtered keyset port');
select has_function('argus_private','list_published_creators_page',
  array['integer','text','uuid'],
  'published creators expose a keyset port');
select has_function('argus_private','list_published_coven_page',
  array['integer','text','date','text','uuid'],
  'published Coven exposes a typed filtered keyset port');
select has_function('argus_private','list_current_published_editorial_page',
  array['text','integer','text','uuid'],
  'generic editorial publication exposes a keyset port');
select has_function('argus_private','search_published_content_page',
  array['text','text[]','integer','integer','text','text','uuid'],
  'mixed search exposes one globally ordered keyset port');
select ok(
  not has_function_privilege(
    'argus_member','argus_private.ensure_editorial_creator(text,text)','execute'
  ) and not has_function_privilege(
    'argus_staff','argus_private.ensure_editorial_creator(text,text)','execute'
  ) and not has_function_privilege(
    'public','argus_private.bind_editorial_creator()','execute'
  ),
  'creator registry composition is trigger/owner-private'
);

select is(
  (select count(*)::bigint
     from pg_proc function_row
     join pg_namespace namespace on namespace.oid=function_row.pronamespace
    where namespace.nspname='argus_private'
      and function_row.proname in (
        'list_member_briefings_page','list_member_briefing_sections',
        'list_member_circles_page','list_published_assets_page',
        'list_published_grimoires_page','list_published_circle_templates_page',
        'list_published_creators_page','list_published_coven_page',
        'list_current_published_editorial_page','search_published_content_page'
      )
      and not function_row.prosecdef
      and 'search_path=""'=any(coalesce(function_row.proconfig,array[]::text[]))),
  10::bigint,
  'every U8 page port is SECURITY INVOKER with an empty search path'
);
select ok(
  (select relrowsecurity and relforcerowsecurity
     from pg_class where oid='argus_app.editorial_creators'::regclass),
  'creator identities force RLS'
);
select set_eq(
  $$select grantee||':'||privilege_type
      from information_schema.routine_privileges
     where specific_schema='argus_private'
       and routine_name='list_current_published_editorial_page'
       and grantee<>'argus_app_owner'$$,
  $$values ('argus_member:EXECUTE'),('argus_public_preview:EXECUTE')$$,
  'the generic published page has exactly member and public-preview execute'
);
select ok(
  not has_table_privilege('argus_public_preview','argus_app.briefings','select')
  and not has_table_privilege('argus_public_preview','argus_app.circles','select')
  and not has_table_privilege('argus_public_preview','argus_app.editorial_creators','select'),
  'public preview receives no member or creator-registry table privilege'
);
select is(
  (select count(*)::bigint from pg_indexes
    where schemaname='argus_app' and indexname in (
      'briefings_u8_owner_ready_page_idx','briefing_sections_u8_typed_order_idx',
      'circles_u8_owner_active_page_idx','circles_u8_owner_all_page_idx',
      'catalog_assets_u8_active_page_idx','catalog_assets_u8_active_search_fts_idx',
      'catalog_assets_u8_active_search_trgm_idx',
      'companies_u8_active_search_fts_idx','companies_u8_active_search_trgm_idx',
      'editorial_items_u8_published_page_idx',
      'editorial_items_u8_published_search_fts_idx',
      'editorial_items_u8_published_search_trgm_idx',
      'grimoires_u8_theme_page_idx','grimoires_u8_search_fts_idx',
      'grimoires_u8_search_trgm_idx','community_templates_u8_creator_page_idx',
      'community_templates_u8_search_fts_idx',
      'community_templates_u8_search_trgm_idx','editorial_creators_u8_page_idx',
      'coven_qualifications_u8_current_filter_idx'
    )),
  20::bigint,
  'the reviewed U8 query shapes have exactly their named supporting indexes'
);
select is(
  (select count(*)::bigint from pg_indexes
    where indexname in (
      'connections_u8_admin_diagnostics_idx',
      'provider_commands_u8_admin_diagnostics_idx',
      'reconciliation_records_u8_admin_diagnostics_idx'
    )),
  3::bigint,
  'each staff brokerage diagnostic stream has a deterministic recent-first index'
);
select is(
  (select count(*)::bigint from argus_app.editorial_creators),
  (select count(distinct creator_key)::bigint
     from argus_app.community_templates
    where creator_normalization_state='ready'),
  'logical legacy creator identities map bijectively to the registry'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000',
   '88000000-0000-4000-8000-000000000001','authenticated','authenticated',
   'u8-member@example.test','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000',
   '88000000-0000-4000-8000-000000000002','authenticated','authenticated',
   'u8-editor@example.test','',now(),'{}','{}',now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at) values
  ('88000000-0000-4000-8000-000000000011',
   '88000000-0000-4000-8000-000000000001',now(),now()),
  ('88000000-0000-4000-8000-000000000012',
   '88000000-0000-4000-8000-000000000002',now(),now());
insert into argus_private.staff_principals(
  user_id,status,permissions,display_label
) values (
  '88000000-0000-4000-8000-000000000002','active',
  array['editorial:read','editorial:write','editorial:review','editorial:publish'],
  'U8 editor'
);

set local role argus_edge;
select argus_private.install_request_context(
  '88000000-0000-4000-8000-000000000002',
  '88000000-0000-4000-8000-000000000012','aal2'
);
reset role;

insert into argus_app.companies(id,slug,name,status)
select ('88100000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       'u8-company-'||lpad(series::text,3,'0'),
       case when series>102 then 'U8 Equal Needle' else 'U8 Noise '||series end,
       'active'
  from generate_series(1,104) series;
insert into argus_app.editorial_items(id,kind,slug,status)
select ('88200000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       'coven','u8-coven-'||lpad(series::text,3,'0'),'draft'
  from generate_series(1,104) series;
insert into argus_app.editorial_revisions(
  id,item_id,revision_number,state,author_staff_id,content_hash,payload,created_at
)
select ('88300000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       ('88200000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       1,'published','88000000-0000-4000-8000-000000000002',
       pg_catalog.encode(extensions.digest(('u8-revision-'||series)::bytea,'sha256'),'hex'),
       '{}'::jsonb,'2026-08-01T00:00:00Z'::timestamptz+series*interval '1 minute'
  from generate_series(1,104) series;
update argus_app.editorial_items item
   set current_published_revision_id=revision.id,status='published'
  from argus_app.editorial_revisions revision
 where revision.item_id=item.id and item.slug like 'u8-coven-%';
insert into argus_app.coven_entries(
  id,editorial_item_id,company_id,qualification_payload
)
select ('88400000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       ('88200000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       ('88100000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       '[]'::jsonb
  from generate_series(1,104) series;
insert into argus_app.coven_qualifications(
  id,coven_entry_id,editorial_item_id,revision_id,ordinal,schema_version,
  criterion_code,claim,category,person_name,effective_date,valid_to,verified_as_of
)
select ('88500000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       ('88400000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       ('88200000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       ('88300000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       1,1,'leadership','Typed U8 qualification',
       case when series>102 then 'owner' else 'founder' end,
       'Example Person','2026-01-01',null,
       case when series=104 then '2026-08-20'::date else '2026-08-10'::date end
  from generate_series(1,104) series;
insert into argus_app.editorial_render_documents(item_id,revision_id,document)
select ('88200000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       ('88300000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       jsonb_build_object(
         'title','U8 presentation','category','founder',
         'focus','Typed search fixture','teaser','Presentation only'
       )
  from generate_series(1,104) series;

-- A published Grimoire and Circle template characterize their page ports and
-- the normalized creator write composition without requiring API fixtures.
insert into argus_app.editorial_items(id,kind,slug,status) values
  ('88600000-0000-4000-8000-000000000001','grimoire','u8-grimoire','draft'),
  ('88600000-0000-4000-8000-000000000002','circle_template','u8-template','draft');
insert into argus_app.editorial_revisions(
  id,item_id,revision_number,state,author_staff_id,content_hash,payload,created_at
) values
  ('88700000-0000-4000-8000-000000000001',
   '88600000-0000-4000-8000-000000000001',1,'published',
   '88000000-0000-4000-8000-000000000002',repeat('8',64),'{}','2026-08-28T10:00:00Z'),
  ('88700000-0000-4000-8000-000000000002',
   '88600000-0000-4000-8000-000000000002',1,'published',
   '88000000-0000-4000-8000-000000000002',repeat('9',64),'{}','2026-08-28T11:00:00Z');
update argus_app.editorial_items item set status='published',current_published_revision_id=
  case item.id
    when '88600000-0000-4000-8000-000000000001'::uuid
      then '88700000-0000-4000-8000-000000000001'::uuid
    else '88700000-0000-4000-8000-000000000002'::uuid end
where item.id in (
  '88600000-0000-4000-8000-000000000001',
  '88600000-0000-4000-8000-000000000002'
);
insert into argus_app.grimoires(id,editorial_item_id,theme_code) values (
  '88800000-0000-4000-8000-000000000001',
  '88600000-0000-4000-8000-000000000001','quality'
);
insert into argus_app.community_templates(
  id,editorial_item_id,creator_label,title,description
) values (
  '88800000-0000-4000-8000-000000000003',
  '88600000-0000-4000-8000-000000000002','U8 Creator',
  'U8 Needle Template','Typed template description.'
);
insert into argus_app.editorial_render_documents(item_id,revision_id,document) values
  ('88600000-0000-4000-8000-000000000001',
   '88700000-0000-4000-8000-000000000001',
   '{"title":"U8 Grimoire","description":"Presentation","theme":"quality","curator_label":"Argus"}'),
  ('88600000-0000-4000-8000-000000000002',
   '88700000-0000-4000-8000-000000000002',
   '{"theme":"quality"}');

-- One request context is immutable for a transaction. This rollback-only test
-- explicitly disposes its staff fixture context before installing the member
-- context used for black-box invoker/RLS assertions.
do $$
declare retained_context_relation text;
begin
  retained_context_relation:=pg_catalog.current_setting(
    'argus.request_context_relation',true
  );
  execute pg_catalog.format(
    'drop table if exists pg_temp.%I',retained_context_relation
  );
  perform pg_catalog.set_config('argus.request_context_relation','',true);
  perform pg_catalog.set_config('request.jwt.claims','',true);
end
$$;

set local role argus_edge;
select argus_private.install_request_context(
  '88000000-0000-4000-8000-000000000001',
  '88000000-0000-4000-8000-000000000011','aal1'
);
set local role argus_member;

insert into argus_app.briefings(
  id,user_id,deletion_epoch,briefing_type,period_start,period_end,status,
  generated_at,generation,source_sequence
) values
  ('88900000-0000-4000-8000-000000000001',
   '88000000-0000-4000-8000-000000000001',0,'daily',
   '2026-01-01','2026-01-03','ready','2026-01-03T10:00:00Z',2,21),
  ('88900000-0000-4000-8000-000000000002',
   '88000000-0000-4000-8000-000000000001',0,'daily',
   '2026-01-02','2026-01-03','ready','2026-01-03T11:00:00Z',3,22);
insert into argus_app.briefings(
  id,user_id,deletion_epoch,briefing_type,period_start,period_end,status,
  generated_at,generation,source_sequence
)
select ('88910000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       '88000000-0000-4000-8000-000000000001',0,'weekly',
       '2025-01-01'::date+series,'2025-01-01'::date+series,'ready',
       '2025-01-01T10:00:00Z'::timestamptz+series*interval '1 day',1,series
  from generate_series(1,120) series;
insert into argus_app.briefing_sections(
  id,user_id,deletion_epoch,briefing_id,section_type,ordinal,payload,
  source_sequence,schema_version,disclosure
) values (
  '88920000-0000-4000-8000-000000000001',
  '88000000-0000-4000-8000-000000000001',0,
  '88900000-0000-4000-8000-000000000001','summary',1,
  '{"source_sequence":999,"schema_version":999,"disclosure":"legacy wrong"}',
  21,2,'Typed disclosure'
);

insert into argus_app.circles(
  id,user_id,deletion_epoch,title,description,version,archived_at
) values
  ('88930000-0000-4000-8000-000000000001',
   '88000000-0000-4000-8000-000000000001',0,'Active A','',1,null),
  ('88930000-0000-4000-8000-000000000002',
   '88000000-0000-4000-8000-000000000001',0,'Active B','',1,null);
insert into argus_app.circles(
  id,user_id,deletion_epoch,title,description,version,archived_at
)
select ('88940000-0000-4000-8000-'||lpad(series::text,12,'0'))::uuid,
       '88000000-0000-4000-8000-000000000001',0,
       'Archived '||series,'',1,
       '2026-01-01T00:00:00Z'::timestamptz+series*interval '1 minute'
  from generate_series(1,120) series;

select is(
  (select to_jsonb(section) from argus_private.list_member_briefing_sections(
    '88900000-0000-4000-8000-000000000001'
  ) section),
  '{"ordinal":1,"section_type":"summary","source_sequence":21,"schema_version":2,"disclosure":"Typed disclosure"}'::jsonb,
  'briefing detail reads typed metadata rather than conflicting payload values'
);
select is(
  (select count(*)::bigint from argus_private.list_member_briefings_page(
    10,'daily',null,null,null,null
  )),2::bigint,
  'briefing type filtering happens before the limit despite 120 other rows'
);
select is(
  (select id from argus_private.list_member_briefings_page(
    1,'daily',null,null,null,null
  )),
  '88900000-0000-4000-8000-000000000002'::uuid,
  'briefing equal-sort values use id as a deterministic descending tie-breaker'
);
select is(
  (select id from argus_private.list_member_briefings_page(
    1,'daily',null,null,'2026-01-03','88900000-0000-4000-8000-000000000002'
  )),
  '88900000-0000-4000-8000-000000000001'::uuid,
  'briefing keyset continuation has no duplicate or omission'
);
select is(
  (select count(*)::bigint from argus_private.list_member_circles_page(
    101,false,null,null,null
  )),2::bigint,
  'Circle archived filtering happens before the bounded limit'
);
select ok(
  (select private and source_revision_id is null and jsonb_typeof(assets)='array'
     from argus_private.list_member_circles_page(1,false,null,null,null)),
  'Circle page preserves retained response fields without route fabrication'
);
select is(
  (select id from argus_private.list_member_circles_page(
    1,false,false,null,'88930000-0000-4000-8000-000000000001'
  )),
  '88930000-0000-4000-8000-000000000002'::uuid,
  'Circle keyset continuation uses the unique id tie-breaker'
);

select is(
  (select count(*)::bigint from argus_private.list_published_coven_page(
    101,'owner',null,null,null
  )),2::bigint,
  'Coven category filtering happens before the limit across more than 100 rows'
);
select is(
  (select category from argus_private.list_published_coven_page(
    1,'owner',null,null,null
  )),
  'owner',
  'Coven reads typed category despite a conflicting sealed presentation value'
);
select is(
  (select count(*)::bigint from argus_private.list_published_coven_page(
    101,'owner','2026-08-15',null,null
  )),1::bigint,
  'Coven verified-as-of filtering is typed and precedes the limit'
);
select is(
  (select count(*)::bigint from argus_private.search_published_content_page(
    'needle',array['coven'],101,null,null,null,null
  )),2::bigint,
  'mixed search filters globally before the limit across more than 100 candidates'
);
select is(
  (select id from argus_private.search_published_content_page(
    'needle',array['coven'],1,null,null,null,null
  )),
  '88400000-0000-4000-8000-000000000103'::uuid,
  'equal-rank and equal-label search uses kind and id as stable tie-breakers'
);
select is(
  (select id from argus_private.search_published_content_page(
    'needle',array['coven'],1,200,'U8 Equal Needle','coven',
    '88400000-0000-4000-8000-000000000103'
  )),
  '88400000-0000-4000-8000-000000000104'::uuid,
  'search keyset continuation has no duplicate or omission'
);
select is(
  (select count(*)::bigint from argus_private.search_published_content_page(
    'needle',array['grimoire'],101,null,null,null,null
  )),0::bigint,
  'search kind filtering occurs before the global limit'
);
select is(
  (select count(*)::bigint from argus_private.list_published_grimoires_page(
    101,'quality',null,null
  )),1::bigint,
  'Grimoire typed theme filtering precedes its page limit'
);
select is(
  (select count(*)::bigint from argus_private.list_published_circle_templates_page(
    101,'U8 Creator',null,null
  )),1::bigint,
  'template display-name filtering resolves through the creator registry before limit'
);
select is(
  (select observed_at from argus_private.list_published_creators_page(
    101,null,null
  ) where display_name='U8 Creator'),
  '2026-08-28T11:00:00Z'::timestamptz,
  'creator pages expose a deterministic published-revision observation time'
);
select is(
  (select count(*)::bigint from argus_private.list_current_published_editorial_page(
    'coven',101,null,null
  )),101::bigint,
  'generic editorial pages use bounded one-row overfetch'
);

reset role;
select throws_ok(
  $$insert into argus_app.coven_qualifications(
      coven_entry_id,editorial_item_id,revision_id,ordinal,
      criterion_code,claim,category,effective_date,verified_as_of
    ) values (
      '88400000-0000-4000-8000-000000000001',
      '88200000-0000-4000-8000-000000000001',
      '88300000-0000-4000-8000-000000000001',2,
      'invalid','invalid','celebrity','2026-01-01','2026-01-01'
    )$$,
  '23514',null,
  'invalid typed Coven categories are rejected'
);
select throws_ok(
  $$update argus_app.community_templates
       set creator_id='00000000-0000-4000-8000-000000000001'
     where editorial_item_id='88600000-0000-4000-8000-000000000002'$$,
  '23503',null,
  'template creator identity cannot diverge from its normalized key'
);

set local enable_seqscan=off;
set local enable_sort=off;
select ok(
  pg_temp.u8_explain($query$
    select id from argus_app.briefings
     where tenant_id='88000000-0000-4000-8000-000000000001'
       and lifecycle_id=(select lifecycle_id from argus_app.members
         where user_id='88000000-0000-4000-8000-000000000001')
       and user_id='88000000-0000-4000-8000-000000000001'
       and briefing_type='daily' and status='ready'
     order by period_end desc,id desc limit 10
  $query$)::text like '%briefings_u8_owner_ready_page_idx%',
  'briefing page shape plans through its owner/filter/order index'
);
select ok(
  pg_temp.u8_explain($query$
    select coven_entry_id from argus_app.coven_qualifications
     where category='owner' and verified_as_of<='2026-08-15'
     order by category,verified_as_of,coven_entry_id limit 10
  $query$)::text like '%coven_qualifications_u8_current_filter_idx%',
  'Coven typed filter shape plans through its composite index'
);

select is(
  (
    select count(*)::bigint
      from (
        select policy.schemaname,policy.tablename,command.name
          from pg_policies policy
          cross join (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE')) command(name)
         where policy.schemaname in ('argus_app','argus_private')
           and policy.roles @> array['argus_runtime'::name]
           and policy.cmd in ('ALL',command.name)
         group by policy.schemaname,policy.tablename,command.name
        having count(*)>1
      ) overlap
  ),
  0::bigint,
  'runtime RLS composes owner and staff predicates once per command'
);

set local role argus_public_preview;
select is(
  (select count(*)::bigint from argus_private.list_current_published_editorial_page(
    'coven',1,null,null
  )),1::bigint,
  'public preview can execute only the current published page projection'
);
select throws_ok(
  $$select * from argus_private.list_member_briefings_page(
      1,null,null,null,null,null
    )$$,
  '42501',null,
  'public preview cannot execute member-private page ports'
);

select * from finish();
rollback;

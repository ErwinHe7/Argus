begin;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(41);

select has_table('argus_app','onboarding_step_completions',
  'onboarding completion order is normalized');
select has_table('argus_app','notification_quiet_hours',
  'notification quiet hours are typed');
select has_table('argus_app','member_saved_items',
  'saved targets use one typed registry');
select has_table('argus_app','content_report_targets',
  'content reports have typed targets');
select has_table('argus_app','ritual_scenario_revision_assets',
  'ritual assets are ordered relations');
select has_table('argus_app','ritual_scenario_revision_evidence',
  'ritual evidence is an ordered relation');
select has_table('argus_app','grimoire_revision_assets',
  'Grimoire assets are revision-qualified');
select has_table('argus_app','community_template_revision_assets',
  'Circle-template assets are revision-qualified');
select has_table('argus_app','coven_qualifications',
  'Coven qualifications are typed and ordered');
select has_table('argus_app','asset_codex_revisions',
  'Asset Codex revisions have a typed root');
select has_table('argus_app','asset_codex_revision_evidence',
  'Asset Codex evidence is relational');
select has_table('argus_app','asset_codex_revision_metrics',
  'Asset Codex metrics are typed rows');

select is(
  (select count(*)::bigint
     from (values
       ('profiles'),('preferences'),('astrology_profiles'),('investor_profiles'),
       ('onboarding_states'),('consent_records'),('notification_preferences'),
       ('daily_ritual_assignments'),('circles'),('circle_assets'),('saved_items'),
       ('intentions'),('future_mirror_runs'),('future_mirror_points'),('briefings'),
       ('briefing_sections'),('briefing_read_states'),('notifications'),('content_reports')
     ) expected(relation_name)
    where exists (
      select 1 from information_schema.columns column_row
       where column_row.table_schema='argus_app'
         and column_row.table_name=expected.relation_name
         and column_row.column_name='tenant_id'
    ) and exists (
      select 1 from information_schema.columns column_row
       where column_row.table_schema='argus_app'
         and column_row.table_name=expected.relation_name
         and column_row.column_name='lifecycle_id'
    )),
  19::bigint,
  'every U4 member child carries tenant and lifecycle identity'
);

select is(
  (select count(*)::bigint
     from pg_constraint constraint_row
     join pg_class relation on relation.oid=constraint_row.conrelid
     join pg_namespace namespace on namespace.oid=relation.relnamespace
    where namespace.nspname='argus_app'
      and constraint_row.contype='f'
      and relation.relname in (
        'circle_assets','future_mirror_runs','future_mirror_points',
        'briefing_sections','briefing_read_states'
      )
      and pg_get_constraintdef(constraint_row.oid) like
        'FOREIGN KEY (tenant_id, lifecycle_id,%'),
  5::bigint,
  'U4 application children use parent-qualified composite foreign keys'
);

do $membership$ begin
  execute pg_catalog.format(
    'grant argus_edge,argus_member,argus_identity_owner to %I with set true',
    current_user
  );
end $membership$;
grant usage on schema extensions
  to argus_edge,argus_member,argus_identity_owner;

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','a4000000-0000-4000-8000-000000000001',
   'authenticated','authenticated','u4-member-a@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','b4000000-0000-4000-8000-000000000002',
   'authenticated','authenticated','u4-member-b@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now());

set local role argus_edge;
select argus_private.install_request_context(
  'a4000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000011','aal1'
);
reset role;

set local role argus_member;
select lives_ok(
  $$update argus_app.onboarding_states
       set completed_steps='["welcome","investing"]'::jsonb,
           completed_at='2026-08-29T12:00:00Z'
     where user_id='a4000000-0000-4000-8000-000000000001'$$,
  'legacy onboarding mutation atomically updates the typed authority'
);
select is(
  (select jsonb_agg(step_code order by ordinal)
     from argus_app.onboarding_step_completions),
  '["welcome","investing"]'::jsonb,
  'onboarding order is preserved exactly'
);
select throws_ok(
  $$update argus_app.onboarding_states
       set completed_steps='["welcome","welcome"]'::jsonb
     where user_id='a4000000-0000-4000-8000-000000000001'$$,
  '23514','invalid_onboarding_step_collection',
  'duplicate onboarding steps are rejected as one cohort'
);

select lives_ok(
  $$update argus_app.notification_preferences
       set quiet_hours='{"timezone":"America/New_York","start":"22:00","end":"06:00"}'::jsonb
     where user_id='a4000000-0000-4000-8000-000000000001'$$,
  'valid quiet hours atomically update the typed authority'
);
select is(
  (select jsonb_build_object(
      'timezone',timezone_name,'start',starts_at::text,'end',ends_at::text
    ) from argus_app.notification_quiet_hours),
  '{"timezone":"America/New_York","start":"22:00:00","end":"06:00:00"}'::jsonb,
  'typed quiet hours preserve the exact bounded compatibility value'
);
select throws_ok(
  $$update argus_app.notification_preferences
       set quiet_hours='{"timezone":"UTC","start":"22:00","end":"06:00","extra":true}'::jsonb
     where user_id='a4000000-0000-4000-8000-000000000001'$$,
  '23514','invalid_notification_quiet_hours',
  'quiet hours reject unknown keys instead of coercing them'
);
select throws_ok(
  $$insert into argus_app.onboarding_step_completions(
      tenant_id,lifecycle_id,onboarding_user_id,step_code,ordinal
    ) values (
      'a4000000-0000-4000-8000-000000000001',
      (select lifecycle_id from argus_app.members
        where user_id='a4000000-0000-4000-8000-000000000001'),
      'a4000000-0000-4000-8000-000000000001','ritual',3
    )$$,
  '42501',null,
  'member callers cannot mutate normalized onboarding rows independently'
);

select lives_ok(
  $$select * from argus_private.save_member_item(
      'asset','10000000-0000-4000-8000-000000000002','direct',null
    )$$,
  'a member can save one existing typed target'
);
select is(
  (select count(*)::bigint from argus_app.member_saved_items
    where asset_id='10000000-0000-4000-8000-000000000002'
      and item_kind='asset' and source_kind='direct'),
  1::bigint,
  'saved-item authority stores exactly one typed target and source'
);
reset role;
select is(
  (select count(*)::bigint from argus_app.saved_items legacy
    join argus_app.member_saved_items normalized
      on normalized.user_id=legacy.user_id
     and normalized.item_kind=legacy.item_kind
     and normalized.asset_id=legacy.item_id
     and normalized.saved_at=legacy.saved_at),
  1::bigint,
  'saved-item compatibility and normalized rows remain in parity'
);
set local role argus_member;
select throws_ok(
  $$select * from argus_private.save_member_item(
      'unknown','10000000-0000-4000-8000-000000000002','direct',null
    )$$,
  'P0002','resource_not_found',
  'unsupported saved target kinds fail without existence detail'
);
select throws_ok(
  $$select * from argus_private.save_member_item(
      'asset','a4000000-0000-4000-8000-000000000099','direct',null
    )$$,
  'P0002','resource_not_found',
  'missing saved targets use the same non-leaking failure'
);

select lives_ok(
  $$select argus_private.create_content_report(
      'asset','10000000-0000-4000-8000-000000000002','incorrect','bounded detail'
    )$$,
  'a member can report one existing typed target'
);
select is(
  (select count(*)::bigint from argus_app.content_report_targets
    where target_kind='asset'
      and asset_id='10000000-0000-4000-8000-000000000002'),
  1::bigint,
  'content-report authority stores exactly one typed target'
);
select is(
  (select count(*)::bigint from argus_app.content_reports legacy
    join argus_app.content_report_targets normalized
      on normalized.report_id=legacy.id
     and normalized.target_kind=legacy.target_kind
     and normalized.asset_id=legacy.target_id),
  1::bigint,
  'report compatibility and normalized targets remain in parity'
);
select throws_ok(
  $$select argus_private.create_content_report(
      'unknown','10000000-0000-4000-8000-000000000002','incorrect',null
    )$$,
  'P0002','resource_not_found',
  'unsupported report target kinds fail without existence detail'
);
select throws_ok(
  $$select argus_private.create_content_report(
      'asset','a4000000-0000-4000-8000-000000000099','incorrect',null
    )$$,
  'P0002','resource_not_found',
  'missing report targets use the same non-leaking failure'
);
select throws_ok(
  $$insert into argus_app.saved_items(
      user_id,deletion_epoch,item_kind,item_id,source_kind
    ) values (
      'a4000000-0000-4000-8000-000000000001',0,'asset',
      '10000000-0000-4000-8000-000000000002','direct'
    )$$,
  '42501',null,
  'member callers cannot mutate the legacy saved store independently'
);
reset role;

select is(
  (select count(*)::bigint from argus_private.outbox_events
    where event_type='content-report.created'
      and event_version=1
      and tenant_id='a4000000-0000-4000-8000-000000000001'
      and lifecycle_id=(select lifecycle_id from argus_app.members
        where user_id='a4000000-0000-4000-8000-000000000001')
      and user_id='a4000000-0000-4000-8000-000000000001'),
  1::bigint,
  'content reporting emits one lifecycle-scoped registered durable-work handoff'
);

set local role argus_identity_owner;
do $$
declare context_relation text:=current_setting('argus.request_context_relation');
begin
  execute format(
    'update pg_temp.%I set user_id=$1,tenant_id=$1,lifecycle_id=$2,installed_at=clock_timestamp()',
    context_relation
  ) using
    'b4000000-0000-4000-8000-000000000002'::uuid,
    (select lifecycle_id from argus_app.members
      where user_id='b4000000-0000-4000-8000-000000000002');
end $$;
reset role;

set local role argus_member;
select is((select count(*)::bigint from argus_app.member_saved_items),0::bigint,
  'another owner cannot observe saved items');
select is((select count(*)::bigint from argus_app.content_reports),0::bigint,
  'another owner cannot observe content reports');
select lives_ok(
  $$select * from argus_private.save_member_item(
      'asset','10000000-0000-4000-8000-000000000002','direct',null
    )$$,
  'the same target may be saved independently in another lifecycle'
);
reset role;

select is(
  (select count(*)::bigint from argus_app.member_saved_items
    where asset_id='10000000-0000-4000-8000-000000000002'),
  2::bigint,
  'typed saved-item uniqueness is lifecycle-qualified'
);

set local role argus_identity_owner;
do $$
declare context_relation text:=current_setting('argus.request_context_relation');
declare member_lifecycle uuid;
begin
  select lifecycle_id into member_lifecycle from argus_app.members
    where user_id='a4000000-0000-4000-8000-000000000001';
  execute format(
    'update pg_temp.%I set user_id=$1,tenant_id=$1,lifecycle_id=$2,installed_at=clock_timestamp()',
    context_relation
  ) using 'a4000000-0000-4000-8000-000000000001'::uuid,member_lifecycle;
  perform argus_private.close_member_lifecycle(member_lifecycle,'u4-domain-test');
end $$;
reset role;

set local role argus_member;
select is((select count(*)::bigint from argus_app.member_saved_items),0::bigint,
  'a closed lifecycle cannot read saved-item authority');
select throws_ok(
  $$select * from argus_private.save_member_item(
      'asset','10000000-0000-4000-8000-000000000002','direct',null
    )$$,
  'P0002','resource_not_found',
  'a closed lifecycle cannot invoke the saved-item command'
);
reset role;

select is(
  (select count(*)::bigint
     from pg_constraint constraint_record
    where constraint_record.conrelid='argus_app.member_saved_items'::regclass
      and constraint_record.contype='f'
      and pg_get_constraintdef(constraint_record.oid) in (
        'FOREIGN KEY (tenant_id, lifecycle_id) REFERENCES argus_app.member_lifecycles(tenant_id, id) ON DELETE RESTRICT',
        'FOREIGN KEY (user_id, lifecycle_id) REFERENCES argus_app.member_lifecycles(identity_subject_id, id) ON DELETE RESTRICT'
      )),
  2::bigint,
  'saved-item authority rejects cross-tenant and cross-owner lifecycle bindings declaratively'
);

select ok(
  to_regclass('argus_app.member_saved_items_owner_order_idx') is not null
    and to_regclass('argus_app.content_report_targets_lifecycle_idx') is not null
    and to_regclass('argus_app.briefing_sections_u4_briefing_idx') is not null
    and to_regclass('argus_app.notifications_u4_owner_order_idx') is not null
    and to_regclass('argus_app.briefings_u4_owner_ready_order_idx') is not null
    and to_regclass('argus_app.daily_ritual_assignments_u4_owner_order_idx') is not null
    and to_regclass('argus_app.circles_u4_owner_order_idx') is not null
    and to_regclass('argus_app.editorial_items_u4_published_order_idx') is not null,
  'member/editorial reads and parent-qualified children have leading indexes'
);

select * from finish();
rollback;

begin;

-- PostgreSQL 17 gives a non-superuser role creator ADMIN but not SET on
-- newly created roles. Enable role switching only for this test transaction;
-- the final rollback restores the hosted membership options.
grant argus_edge, argus_runtime, argus_staff, argus_worker, argus_waitlist
  to current_user with set true;
grant usage on schema extensions
  to argus_edge, argus_runtime, argus_staff, argus_worker, argus_waitlist;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(53);

select has_table(
  'argus_private','staff_step_up_receipts',
  'staff action receipts remain outside exposed schemas'
);
select has_column(
  'argus_app','editorial_revisions','edit_version',
  'editorial drafts carry an optimistic conflict version'
);
select has_function(
  'argus_private','consume_staff_step_up',array['text','uuid','text','uuid'],
  'step-up consumption is one atomic database operation'
);
select has_function(
  'argus_private','request_admin_privacy_retry',array['uuid','text','text','uuid'],
  'privacy retry has an action-bound database capability'
);
select ok(
  not has_function_privilege(
    'public','argus_private.has_live_staff_session(uuid,uuid)','execute'
  ),
  'the auth.sessions liveness helper is not public'
);
select ok(
  not has_function_privilege(
    'public','argus_private.admin_diagnostic_correlation(text,uuid)','execute'
  ),
  'diagnostic hashing is available only through its narrow private helper'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '11111111-1111-4111-8111-111111111111',
  'authenticated','authenticated','u11-staff@example.test','',now(),
  '{"provider":"email","providers":["email"]}','{}',now(),now()
);
insert into auth.sessions(id,user_id,created_at,updated_at) values
  ('11111111-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111',now(),now()),
  ('11111111-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111',now(),now());
insert into argus_private.staff_principals(
  user_id,status,permissions,display_label
) values (
  '11111111-1111-4111-8111-111111111111','active',
  array['editorial:read','editorial:write','editorial:review','editorial:publish',
        'operations:read','operations:write','privacy:read','privacy:write',
        'brokerage:read','audit:read'],
  'U11 staff'
);
insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '66666666-6666-4666-8666-666666666666',
  'authenticated','authenticated','u11-author@example.test','',now(),
  '{"provider":"email","providers":["email"]}','{}',now(),now()
);
insert into argus_private.staff_principals(
  user_id,status,permissions,display_label
) values (
  '66666666-6666-4666-8666-666666666666','active',
  array['editorial:write'],'Independent U11 author'
);

insert into argus_private.staff_step_up_receipts(
  user_id,session_id,action,target_id,receipt_hash,expires_at,created_at
) values
  ('11111111-1111-4111-8111-111111111111','11111111-0000-4000-8000-000000000001',
   'admin_job_retry','11111111-1000-4000-8000-000000000001',repeat('a',64),now()+interval '5 minutes',now()),
  ('11111111-1111-4111-8111-111111111111','11111111-0000-4000-8000-000000000001',
   'admin_job_retry','11111111-1000-4000-8000-000000000002',repeat('b',64),now()+interval '5 minutes',now()),
  ('11111111-1111-4111-8111-111111111111','11111111-0000-4000-8000-000000000001',
   'admin_privacy_retry','11111111-1000-4000-8000-000000000003',repeat('c',64),now()+interval '5 minutes',now()),
  ('11111111-1111-4111-8111-111111111111','11111111-0000-4000-8000-000000000001',
   'admin_job_retry','11111111-1000-4000-8000-000000000004',repeat('d',64),now()-interval '1 second',now()-interval '2 seconds'),
  ('11111111-1111-4111-8111-111111111111','11111111-0000-4000-8000-000000000001',
   'admin_job_retry','11111111-1000-4000-8000-000000000005',repeat('e',64),now()+interval '5 minutes',now()),
  ('11111111-1111-4111-8111-111111111111','11111111-0000-4000-8000-000000000001',
   'admin_job_retry','11111111-1000-4000-8000-000000000006',repeat('f',64),now()+interval '5 minutes',now()),
  ('11111111-1111-4111-8111-111111111111','11111111-0000-4000-8000-000000000002',
   'admin_job_retry','11111111-1000-4000-8000-000000000007',repeat('1',64),now()+interval '5 minutes',now()),
  ('11111111-1111-4111-8111-111111111111','11111111-0000-4000-8000-000000000002',
   'admin_job_retry','11111111-1000-4000-8000-000000000008',repeat('2',64),now()+interval '5 minutes',now());

set local role argus_edge;
select argus_private.install_request_context(
  '11111111-1111-4111-8111-111111111111',
  '11111111-0000-4000-8000-000000000001','aal2'
);
set local role argus_runtime;
select argus_private.set_request_context(
  '11111111-1111-4111-8111-111111111111',
  '11111111-0000-4000-8000-000000000001','aal2'
);
select ok(
  argus_private.has_staff_permission('operations:write'),
  'current active staff permission is read from the database'
);
select ok(
  argus_private.consume_staff_step_up(
    repeat('a',64),'11111111-0000-4000-8000-000000000001',
    'admin_job_retry','11111111-1000-4000-8000-000000000001'
  ),
  'a live AAL2 session can consume its exact action and target receipt'
);
select ok(
  (select consumed_at is not null from argus_private.staff_step_up_receipts
    where receipt_hash=repeat('a',64)),
  'successful consumption records immutable one-use state'
);
select isnt(
  argus_private.consume_staff_step_up(
    repeat('a',64),'11111111-0000-4000-8000-000000000001',
    'admin_job_retry','11111111-1000-4000-8000-000000000001'
  ),true,
  'receipt replay fails'
);
select isnt(
  argus_private.consume_staff_step_up(
    repeat('b',64),'11111111-0000-4000-8000-000000000002',
    'admin_job_retry','11111111-1000-4000-8000-000000000002'
  ),true,
  'receipt use from another live session fails'
);
select isnt(
  argus_private.consume_staff_step_up(
    repeat('c',64),'11111111-0000-4000-8000-000000000001',
    'admin_job_retry','11111111-1000-4000-8000-000000000003'
  ),true,
  'receipt use for the wrong action fails'
);
select isnt(
  argus_private.consume_staff_step_up(
    repeat('d',64),'11111111-0000-4000-8000-000000000001',
    'admin_job_retry','11111111-1000-4000-8000-000000000004'
  ),true,
  'expired receipts fail'
);
select argus_private.set_request_context(
  '11111111-1111-4111-8111-111111111111',
  '11111111-0000-4000-8000-000000000001','aal1'
);
select isnt(
  argus_private.consume_staff_step_up(
    repeat('e',64),'11111111-0000-4000-8000-000000000001',
    'admin_job_retry','11111111-1000-4000-8000-000000000005'
  ),true,
  'AAL1 cannot consume a privileged receipt'
);
reset role;

delete from auth.sessions where id='11111111-0000-4000-8000-000000000001';
set local role argus_runtime;
select argus_private.set_request_context(
  '11111111-1111-4111-8111-111111111111',
  '11111111-0000-4000-8000-000000000001','aal2'
);
select isnt(
  argus_private.consume_staff_step_up(
    repeat('f',64),'11111111-0000-4000-8000-000000000001',
    'admin_job_retry','11111111-1000-4000-8000-000000000006'
  ),true,
  'global logout or deleted Auth session fences a still-valid JWT'
);
reset role;

update argus_private.staff_principals
   set permissions=array['editorial:read']
 where user_id='11111111-1111-4111-8111-111111111111';
set local role argus_runtime;
select argus_private.set_request_context(
  '11111111-1111-4111-8111-111111111111',
  '11111111-0000-4000-8000-000000000002','aal2'
);
select isnt(
  argus_private.consume_staff_step_up(
    repeat('1',64),'11111111-0000-4000-8000-000000000002',
    'admin_job_retry','11111111-1000-4000-8000-000000000007'
  ),true,
  'permission downgrade takes effect on the next privileged request'
);
reset role;

update argus_private.staff_principals
   set status='revoked',revoked_at=now(),revocation_epoch=revocation_epoch+1,
       permissions=array['operations:write']
 where user_id='11111111-1111-4111-8111-111111111111';
set local role argus_runtime;
select argus_private.set_request_context(
  '11111111-1111-4111-8111-111111111111',
  '11111111-0000-4000-8000-000000000002','aal2'
);
select isnt(
  argus_private.consume_staff_step_up(
    repeat('2',64),'11111111-0000-4000-8000-000000000002',
    'admin_job_retry','11111111-1000-4000-8000-000000000008'
  ),true,
  'revoked staff cannot consume a receipt'
);
reset role;

update argus_private.staff_principals
   set status='active',revoked_at=null,permissions=array['editorial:write']
 where user_id='11111111-1111-4111-8111-111111111111';
insert into argus_app.editorial_items(id,kind,slug,status) values (
  '11111111-2000-4000-8000-000000000001','briefing_template','u11-editorial','draft'
);
insert into argus_app.editorial_revisions(
  id,item_id,revision_number,state,author_staff_id,content_hash,payload
) values (
  '11111111-3000-4000-8000-000000000001',
  '11111111-2000-4000-8000-000000000001',1,'draft',
  '66666666-6666-4666-8666-666666666666',repeat('3',64),'{"title":"draft"}'
);
select lives_ok(
  $$update argus_app.editorial_revisions
       set payload='{"title":"edited"}',content_hash=repeat('4',64),edit_version=2
     where id='11111111-3000-4000-8000-000000000001'$$,
  'draft payload changes increment the conflict version'
);
select is(
  (select edit_version from argus_app.editorial_revisions
    where id='11111111-3000-4000-8000-000000000001'),
  2,
  'the incremented edit version is retained'
);
select lives_ok(
  $$update argus_app.editorial_revisions set state='submitted'
     where id='11111111-3000-4000-8000-000000000001'$$,
  'draft submission is an allowed immutable transition'
);
select throws_ok(
  $$update argus_app.editorial_revisions
       set payload='{"title":"tampered"}',content_hash=repeat('5',64),edit_version=3
     where id='11111111-3000-4000-8000-000000000001'$$,
  '23514','invalid_editorial_transition',
  'submitted editorial payloads cannot be rewritten'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000',
   '22222222-2222-4222-8222-222222222222','authenticated','authenticated',
   'u11-reviewer@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000',
   '33333333-3333-4333-8333-333333333333','authenticated','authenticated',
   'u11-publisher@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000',
   '44444444-4444-4444-8444-444444444444','authenticated','authenticated',
   'u11-operations-target@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000',
   '55555555-5555-4555-8555-555555555555','authenticated','authenticated',
   'u11-deletion-target@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at) values
  ('22222222-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222',now(),now()),
  ('33333333-0000-4000-8000-000000000001','33333333-3333-4333-8333-333333333333',now(),now());
insert into argus_private.staff_principals(
  user_id,status,permissions,display_label
) values
  ('22222222-2222-4222-8222-222222222222','active',array['editorial:review'],'Reviewer only'),
  ('33333333-3333-4333-8333-333333333333','active',array['editorial:publish'],'Publisher only');
insert into argus_app.editorial_review_requests(
  id,revision_id,requested_by,high_trust,status
) values (
  '11111111-3100-4000-8000-000000000001',
  '11111111-3000-4000-8000-000000000001',
  '11111111-1111-4111-8111-111111111111',true,'open'
);

update argus_private.staff_principals
   set permissions=array['editorial:review']
 where user_id='11111111-1111-4111-8111-111111111111';
set local role argus_staff;
select lives_ok(
  $$insert into argus_app.editorial_review_decisions(
      request_id,reviewer_id,decision,reason
    ) values (
      '11111111-3100-4000-8000-000000000001',
      '11111111-1111-4111-8111-111111111111','approved','Independent evidence review.'
    )$$,
  'standalone editorial:review can record an independent high-trust decision'
);
select lives_ok(
  $$update argus_app.editorial_review_requests set status='closed'
     where id='11111111-3100-4000-8000-000000000001'$$,
  'standalone editorial:review can close only the reviewed request'
);
select lives_ok(
  $$update argus_app.editorial_revisions set state='approved'
     where id='11111111-3000-4000-8000-000000000001'$$,
  'standalone editorial:review can advance submitted content to approved'
);
select lives_ok(
  $$update argus_app.editorial_items set status='published',
       current_published_revision_id='11111111-3000-4000-8000-000000000001'
     where id='11111111-2000-4000-8000-000000000001'$$,
  'an unrelated publisher-only item update is safely filtered for a reviewer'
);
select is(
  (select status from argus_app.editorial_items
    where id='11111111-2000-4000-8000-000000000001'),
  'draft',
  'standalone reviewer permission cannot publish an editorial item'
);
reset role;

update argus_private.staff_principals
   set permissions=array['editorial:publish']
 where user_id='11111111-1111-4111-8111-111111111111';
set local role argus_staff;
select lives_ok(
  $$select argus_private.publish_editorial_revision(
      '11111111-2000-4000-8000-000000000001',
      '11111111-3000-4000-8000-000000000001','Approved publication.'
    )$$,
  'standalone editorial:publish atomically seals an approved revision'
);
select is(
  (select current_published_revision_id from argus_app.editorial_items
    where id='11111111-2000-4000-8000-000000000001'),
  '11111111-3000-4000-8000-000000000001'::uuid,
  'standalone editorial:publish advances the owning item pointer'
);
select is(
  (select count(*)::bigint from argus_app.publication_events
    where item_id='11111111-2000-4000-8000-000000000001'
      and revision_id='11111111-3000-4000-8000-000000000001'),
  1::bigint,
  'standalone editorial:publish appends one immutable publication event'
);
reset role;
select is(
  (select actor_id from argus_app.publication_events
    where item_id='11111111-2000-4000-8000-000000000001'),
  '11111111-1111-4111-8111-111111111111'::uuid,
  'publication evidence is bound to the current publisher'
);
reset role;

insert into argus_app.editorial_items(id,kind,slug,status) values
  ('22222222-2000-4000-8000-000000000001','grimoire','u11-high-trust-self','draft'),
  ('22222222-2000-4000-8000-000000000002','grimoire','u11-normal-self','draft');
insert into argus_app.editorial_revisions(
  id,item_id,revision_number,state,author_staff_id,content_hash,payload
) values
  ('22222222-3000-4000-8000-000000000001','22222222-2000-4000-8000-000000000001',1,'submitted',
   '11111111-1111-4111-8111-111111111111',repeat('a',64),'{"title":"high"}'),
  ('22222222-3000-4000-8000-000000000002','22222222-2000-4000-8000-000000000002',1,'submitted',
   '11111111-1111-4111-8111-111111111111',repeat('b',64),'{"title":"normal"}');
insert into argus_app.editorial_review_requests(
  id,revision_id,requested_by,high_trust,status
) values
  ('22222222-3100-4000-8000-000000000001','22222222-3000-4000-8000-000000000001',
   '22222222-2222-4222-8222-222222222222',true,'open'),
  ('22222222-3100-4000-8000-000000000002','22222222-3000-4000-8000-000000000002',
   '22222222-2222-4222-8222-222222222222',false,'open');
update argus_private.staff_principals
   set permissions=array['editorial:review']
 where user_id='11111111-1111-4111-8111-111111111111';
set local role argus_staff;
select throws_ok(
  $$insert into argus_app.editorial_review_decisions(
      request_id,reviewer_id,decision,reason
    ) values (
      '22222222-3100-4000-8000-000000000001',
      '11111111-1111-4111-8111-111111111111','approved','Self approval denied.'
    )$$,
  '42501','self_approval',
  'high-trust review preserves the distinct-actor requirement'
);
select lives_ok(
  $$insert into argus_app.editorial_review_decisions(
      request_id,reviewer_id,decision,reason
    ) values (
      '22222222-3100-4000-8000-000000000002',
      '11111111-1111-4111-8111-111111111111','approved','Ordinary editorial review.'
    )$$,
  'non-high-trust editorial preserves prior self-review semantics'
);
reset role;

insert into argus_app.catalog_assets(id,slug,symbol,name,asset_type,currency,status)
values
  ('11111111-5000-4000-8000-000000000001','u11-asset-one','ONE','One','equity','USD','active'),
  ('11111111-5000-4000-8000-000000000002','u11-asset-two','TWO','Two','equity','USD','active'),
  ('11111111-5000-4000-8000-000000000003','u11-asset-three','THR','Three','equity','USD','active');
insert into argus_app.evidence_sources(
  id,canonical_url,title,publisher,retrieved_at,source_kind,status
) values (
  '11111111-5100-4000-8000-000000000001','https://example.test/u11-evidence',
  'U11 evidence','Argus',now(),'test','active'
);
insert into argus_app.evidence_claims(
  id,source_id,claim_type,summary,observed_at,uncertainty,status
) values (
  '11111111-5200-4000-8000-000000000001',
  '11111111-5100-4000-8000-000000000001','observation','Synthetic U11 evidence',
  now(),'Synthetic fixture','active'
);
insert into argus_app.editorial_items(id,kind,slug,status) values
  ('11111111-5300-4000-8000-000000000001','ritual','u11-ritual-materialized','draft'),
  ('11111111-5300-4000-8000-000000000002','rowan','u11-rowan-materialized','draft'),
  ('11111111-5300-4000-8000-000000000003','grimoire','u11-grimoire-linked','draft');
insert into argus_app.editorial_revisions(
  id,item_id,revision_number,state,author_staff_id,content_hash,payload
) values
  ('11111111-5400-4000-8000-000000000001','11111111-5300-4000-8000-000000000001',1,'draft',
   '11111111-1111-4111-8111-111111111111',repeat('c',64),'{}'),
  ('11111111-5400-4000-8000-000000000002','11111111-5300-4000-8000-000000000002',1,'draft',
   '11111111-1111-4111-8111-111111111111',repeat('d',64),'{}'),
  ('11111111-5400-4000-8000-000000000003','11111111-5300-4000-8000-000000000003',1,'draft',
   '11111111-1111-4111-8111-111111111111',repeat('e',64),'{}');
update argus_private.staff_principals
   set permissions=array['editorial:write']
 where user_id='11111111-1111-4111-8111-111111111111';
set local role argus_staff;
select lives_ok(
  $$select argus_private.create_ritual_editorial_item(
      '11111111-5300-4000-8000-000000000001',
      '{"scenario_key":"u11","mode":"tarot","cadence":"daily"}')$$,
  'ritual creation writes its member-domain linkage row'
);
select lives_ok(
  $$select argus_private.sync_ritual_revision(
      '11111111-5400-4000-8000-000000000001',
      '{"title":"Ritual","interpretation":"Synthetic","guidance":"Review", "market_label":"Demo", "observation_at":"2026-08-28T00:00:00Z", "uncertainty":"Synthetic", "idea_asset_ids":["11111111-5000-4000-8000-000000000001","11111111-5000-4000-8000-000000000002","11111111-5000-4000-8000-000000000003"], "evidence_claim_ids":["11111111-5200-4000-8000-000000000001"]}')$$,
  'ritual review materializes a validated domain projection'
);
select lives_ok(
  $$select argus_private.create_rowan_editorial_item(
      '11111111-5300-4000-8000-000000000002',
      '{"script_key":"u11-rowan","surface":"daily_ritual"}')$$,
  'Rowan creation writes its member-domain linkage row'
);
select lives_ok(
  $$select argus_private.sync_rowan_revision(
      '11111111-5400-4000-8000-000000000002',
      '{"body_template":"Reflect on {{ritual}}.","allowed_tokens":["ritual"],"risk_footer":"Educational only."}')$$,
  'Rowan review materializes a constrained script projection'
);
select lives_ok(
  $sql$do $u4$
    begin
      perform argus_private.create_grimoire_editorial_item(
        '11111111-5300-4000-8000-000000000003','{"theme_code":"u11"}'
      );
      perform argus_private.sync_grimoire_revision(
        '11111111-5400-4000-8000-000000000003',
        '{"asset_ids":["11111111-5000-4000-8000-000000000001"]}'
      );
    end
  $u4$$sql$,
  'the Grimoire domain commands write linkage and normalized discovery assets'
);
select is(
  (select scenario_key from argus_app.ritual_scenarios
    where editorial_item_id='11111111-5300-4000-8000-000000000001'),
  'u11','materialized ritual is queryable by the retained ritual domain'
);
select is(
  (select body_template from argus_app.rowan_script_revisions
    where revision_id='11111111-5400-4000-8000-000000000002'),
  'Reflect on {{ritual}}.','materialized Rowan is queryable by the retained Rowan domain'
);
select is(
  (select theme_code from argus_app.grimoires
    where editorial_item_id='11111111-5300-4000-8000-000000000003'),
  'u11','generic linked content is queryable by the retained discovery domain'
);
reset role;

reset role;
update argus_private.staff_principals
   set status='active',revoked_at=null,
       permissions=array['operations:write','privacy:write']
 where user_id='11111111-1111-4111-8111-111111111111';

insert into argus_private.outbox_events(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
  aggregate_id,dedupe_key,published_at
)
select '11111111-4000-4000-8000-000000000001',member.tenant_id,
  member.lifecycle_id,member.user_id,member.deletion_epoch,
  'argus_jobs','briefing.daily.requested',1,
  '11111111-4100-4000-8000-000000000001','u11-original-event-0001',now()
from argus_app.members member
where member.user_id='44444444-4444-4444-8444-444444444444';
insert into argus_private.job_runs(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,job_type,source_event_id,status,attempts,
  queue_message_id,handler_name,max_attempts,diagnostic_hash
) select '11111111-4200-4000-8000-000000000001',
  member.tenant_id,member.lifecycle_id,member.user_id,member.deletion_epoch,
  'briefing-generation-coordinator',
  '11111111-4000-4000-8000-000000000001','dead_lettered',5,1001,
  'briefing-generation-coordinator',5,repeat('9',64)
from argus_app.members member
where member.user_id='44444444-4444-4444-8444-444444444444';
insert into argus_app.privacy_requests(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,request_type,status,failure_code
)
select '11111111-4300-4000-8000-000000000001',member.tenant_id,
  member.lifecycle_id,member.user_id,member.deletion_epoch,
  'export','failed','storage_unavailable'
from argus_app.members member
where member.user_id='44444444-4444-4444-8444-444444444444';
update argus_app.members
   set deletion_epoch=1
 where user_id='55555555-5555-4555-8555-555555555555';
insert into argus_app.privacy_requests(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,request_type,status,failure_code
)
select '11111111-4300-4000-8000-000000000002',member.tenant_id,
  member.lifecycle_id,member.user_id,member.deletion_epoch,
  'deletion','failed','worker_killed'
from argus_app.members member
where member.user_id='55555555-5555-4555-8555-555555555555';
update argus_app.members
   set status='deletion_pending',deletion_requested_at=clock_timestamp()
 where user_id='55555555-5555-4555-8555-555555555555'
   and deletion_epoch=1;
insert into argus_private.deletion_tombstones(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,status
)
select '11111111-4400-4000-8000-000000000001',member.tenant_id,
  member.lifecycle_id,member.user_id,member.deletion_epoch,'failed'
from argus_app.members member
where member.user_id='55555555-5555-4555-8555-555555555555';
insert into argus_private.staff_step_up_receipts(
  user_id,session_id,action,target_id,receipt_hash,expires_at
) values
  ('11111111-1111-4111-8111-111111111111','11111111-0000-4000-8000-000000000002',
   'admin_job_retry','11111111-4200-4000-8000-000000000001',repeat('6',64),now()+interval '5 minutes'),
  ('11111111-1111-4111-8111-111111111111','11111111-0000-4000-8000-000000000002',
   'admin_privacy_retry','11111111-4300-4000-8000-000000000001',repeat('7',64),now()+interval '5 minutes'),
  ('11111111-1111-4111-8111-111111111111','11111111-0000-4000-8000-000000000002',
   'admin_privacy_retry','11111111-4300-4000-8000-000000000002',repeat('8',64),now()+interval '5 minutes');

set local role argus_staff;
select throws_ok(
  $$insert into argus_private.outbox_events(
      user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
    ) values (
      '11111111-1111-4111-8111-111111111111',0,
      'argus_jobs','briefing.daily.requested',
      '11111111-4100-4000-8000-000000000099','u11-direct-staff-retry-0001'
    )$$,
  '42501',
  null,
  'staff runtime cannot directly insert even an allowlisted retained retry event'
);
select lives_ok(
  $$select argus_private.request_admin_job_retry(
      '11111111-4200-4000-8000-000000000001','u11-admin-job-retry-0001',
      repeat('6',64),'11111111-0000-4000-8000-000000000002')$$,
  'a dead-lettered job republishes its original retained source event'
);
reset role;
select is(
  (select event_type from argus_private.outbox_events
    where dedupe_key='u11-admin-job-retry-0001'),
  'briefing.daily.requested',
  'job retry does not invent an administrative event type'
);
reset role;
select is(
  (select argus_private.retained_job_handler(event_type)
     from argus_private.outbox_events
    where dedupe_key='u11-admin-job-retry-0001'),
  'briefing-generation-coordinator',
  'republished job retry resolves to the original retained handler'
);
select is(
  (select aggregate_id from argus_private.outbox_events
    where dedupe_key='u11-admin-job-retry-0001'),
  '11111111-4100-4000-8000-000000000001'::uuid,
  'republished job retry retains the original aggregate authority'
);
set local role argus_staff;
select lives_ok(
  $$select argus_private.request_admin_privacy_retry(
      '11111111-4300-4000-8000-000000000001','u11-privacy-export-retry-0001',
      repeat('7',64),'11111111-0000-4000-8000-000000000002')$$,
  'failed privacy export is re-enqueued through its retained source event'
);
reset role;
select is(
  (select event_type from argus_private.outbox_events
    where dedupe_key='u11-privacy-export-retry-0001'),
  'privacy.export.requested',
  'privacy export retry resolves to the export handler event'
);
set local role argus_staff;
select lives_ok(
  $$select argus_private.request_admin_privacy_retry(
      '11111111-4300-4000-8000-000000000002','u11-privacy-delete-retry-0001',
      repeat('8',64),'11111111-0000-4000-8000-000000000002')$$,
  'failed privacy deletion is re-enqueued through its retained tombstone event'
);
reset role;
select is(
  (select event_type from argus_private.outbox_events
    where dedupe_key='u11-privacy-delete-retry-0001'),
  'privacy.deletion.requested',
  'privacy deletion retry resolves to the purge handler event'
);
select is(
  (select aggregate_id from argus_private.outbox_events
    where dedupe_key='u11-privacy-delete-retry-0001'),
  '11111111-4400-4000-8000-000000000001'::uuid,
  'privacy deletion retry binds the existing private tombstone'
);
select ok(
  (select user_id is null and deletion_epoch is null
     from argus_private.outbox_events
    where dedupe_key='u11-privacy-delete-retry-0001'),
  'privacy deletion retry survives member deletion without exposing owner fields'
);
select is(
  (select count(*)::integer from argus_private.outbox_events
    where dedupe_key like 'u11-%-retry-%'
      and argus_private.retained_job_handler(event_type) is null),
  0,
  'every U11 retry event resolves to a retained worker handler'
);
select is(
  (select count(*)::integer from argus_private.outbox_events
    where dedupe_key like 'u11-%-retry-%' and event_type like 'admin.%'),
  0,
  'U11 emits no unhandled administrative retry event types'
);

select * from finish();
rollback;

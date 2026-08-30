begin;
set transaction isolation level repeatable read;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(51);

select has_table('argus_app','starpath_sessions',
  'Starpath sessions are lifecycle-bound application data');
select has_table('argus_app','starpath_progress_states',
  'Starpath progress is server-owned');
select has_table('argus_app','starpath_lesson_completions',
  'stable lesson completion is retained independently of revisions');
select has_table('argus_app','starpath_attempts',
  'exact knowledge-check attempts are retained');
select has_table('argus_app','starpath_recall_states',
  'recall state survives later sessions');
select has_table('argus_private','starpath_retention_snapshots',
  'retention reports are fixed non-identifying snapshots');

select has_column('argus_private','member_idempotency_records','tenant_id',
  'member idempotency is tenant-qualified');
select has_column('argus_private','member_idempotency_records','lifecycle_id',
  'member idempotency is lifecycle-qualified');
select has_column('argus_private','member_idempotency_records','result_type',
  'member idempotency receipts declare their result type');
select has_column('argus_private','member_idempotency_records','typed_result',
  'member idempotency receipts persist typed results');

select has_function('argus_private','start_or_resume_starpath_session',
  array['text','text','uuid','uuid','bigint'],
  'session start/resume is one server-authoritative command');
select has_function('argus_private','answer_starpath_question',
  array['text','text','uuid','uuid','uuid','uuid','uuid','bigint','text'],
  'answer acceptance is one server-authoritative command');
select has_function('argus_private','read_starpath_state',array['uuid','uuid'],
  'Starpath state is read through a bounded server port');
select has_function('argus_private','skip_starpath_recall',
  array['text','text','uuid','bigint'],
  'recall can be skipped without relocking progress');
select has_function('argus_private','capture_starpath_retention_snapshot',
  array['timestamp with time zone'],
  'retention evidence is captured at one fixed server instant');

select ok(
  exists(
    select 1 from pg_indexes
     where schemaname='argus_app'
       and tablename='starpath_sessions'
       and indexname='starpath_sessions_one_active_lifecycle_unique'
       and indexdef like '%WHERE (state = ''active''::text)%'
  ),
  'one partial unique index permits at most one active lifecycle session'
);

do $membership$ begin
  execute pg_catalog.format(
    'grant argus_app_owner,argus_edge,argus_member,argus_staff,argus_application_purge_owner to %I with set true',
    current_user
  );
end $membership$;
grant usage on schema extensions to
  argus_app_owner,argus_edge,argus_member,argus_staff,
  argus_application_purge_owner;
grant create on schema argus_app to argus_app_owner;

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000',
   '52000000-0000-4000-8000-000000000001','authenticated','authenticated',
   'starpath-state-staff@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000',
   '52000000-0000-4000-8000-000000000002','authenticated','authenticated',
   'starpath-state-member@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now());

insert into argus_private.staff_principals(
  user_id,status,permissions,display_label
) values (
  '52000000-0000-4000-8000-000000000001','active',
  array['editorial:write','editorial:publish','operations:read'],
  'Starpath state fixture owner'
),(
  '52000000-0000-4000-8000-000000000002','active',
  array['operations:read'],'Starpath retention fixture operator'
);

alter table argus_app.editorial_items disable row level security;
alter table argus_app.editorial_items disable trigger user;
alter table argus_app.editorial_revisions disable row level security;
alter table argus_app.editorial_revisions disable trigger user;
grant select,insert,update on argus_app.editorial_items,argus_app.editorial_revisions
  to argus_app_owner;
set local role argus_app_owner;
do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'starpath_policies','starpath_lessons','starpath_lesson_revisions',
    'starpath_knowledge_checks','starpath_knowledge_check_options',
    'starpath_session_themes','starpath_curriculum_manifests',
    'starpath_manifest_nodes','starpath_manifest_themes'
  ] loop
    execute pg_catalog.format('alter table argus_app.%I disable row level security',relation_name);
    execute pg_catalog.format('alter table argus_app.%I disable trigger user',relation_name);
  end loop;
end
$$;

insert into argus_app.starpath_policies(
  policy_version,status,policy_document_hash,approved_by,approved_at,
  effective_at,expires_at,supported_jurisdictions,production_approved
) values (
  'starpath-state-v1','approved',repeat('a',64),
  '52000000-0000-4000-8000-000000000001',now(),now()-interval '1 day',
  now()+interval '365 days',array['US'],true
);

insert into argus_app.editorial_items(id,kind,slug,status)
select (
    '52000000-2000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,'starpath_lesson','state-lesson-'||node,'published'
from pg_catalog.generate_series(1,8) node;

insert into argus_app.editorial_revisions(
  id,item_id,revision_number,state,author_staff_id,content_hash,payload
)
select (
    '52000000-3000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,(
    '52000000-2000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,1,'published','52000000-0000-4000-8000-000000000001',
  repeat('b',64),pg_catalog.jsonb_build_object('node',node)
from pg_catalog.generate_series(1,8) node;

update argus_app.editorial_items item
   set current_published_revision_id=(
     '52000000-3000-4000-8000-'||
     pg_catalog.right(item.id::text,12)
   )::uuid
 where item.id::text like '52000000-2000-4000-8000-%';

insert into argus_app.starpath_lessons(
  id,editorial_item_id,stable_key,pathway_ordinal,pathway_position
)
select (
    '52000000-4000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,(
    '52000000-2000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,'state-lesson-'||node,((node-1)/2)+1,((node-1)%2)+1
from pg_catalog.generate_series(1,8) node;

insert into argus_app.starpath_lesson_revisions(
  lesson_id,editorial_item_id,revision_id,policy_version,classification,
  title,tarot_key,tarot_accessible_label,mythic_mnemonic,factual_summary,
  material_limitations,risk_context,recall_prompt,rowan_explanation
)
select (
    '52000000-4000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,(
    '52000000-2000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,(
    '52000000-3000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,'starpath-state-v1','education_general','State lesson '||node,
  'guide-'||node,'Guide '||node||', used only as a mnemonic',
  'A mythic memory image separated from the financial fact.',
  'A reviewed factual lesson summary for node '||node||'.',
  'The example is limited and does not predict an outcome.',
  'Investment values can change and loss is possible.',
  'Recall the factual concept from lesson '||node||'.',
  'The guide is a mnemonic only; the lesson remains factual.'
from pg_catalog.generate_series(1,8) node;

insert into argus_app.starpath_knowledge_checks(
  id,lesson_id,revision_id,prompt,explanation
)
select (
    '52000000-6000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,(
    '52000000-4000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,(
    '52000000-3000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,'Which statement matches the factual lesson?',
  'The lesson checks factual comprehension only.'
from pg_catalog.generate_series(1,8) node;

insert into argus_app.starpath_knowledge_check_options(
  id,lesson_id,revision_id,question_id,ordinal,label,is_correct,explanation
)
select (
    option_prefix||'-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,(
    '52000000-4000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,(
    '52000000-3000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,(
    '52000000-6000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,option_ordinal,option_label,is_correct,option_explanation
from pg_catalog.generate_series(1,8) node
cross join (values
  ('52000000-7000',1,'The factual statement',true,'Correct factual feedback.'),
  ('52000000-8000',2,'A promised outcome',false,'Outcomes are not promised.')
) option(option_prefix,option_ordinal,option_label,is_correct,option_explanation);

insert into argus_app.starpath_session_themes(
  id,theme_key,policy_version,title,horoscope_frame,factual_focus,
  accessible_label,status
) values (
  '52000000-9000-4000-8000-000000000001','state-theme',
  'starpath-state-v1','Observe before concluding',
  'A celestial pause invites careful observation, not prediction.',
  'Today focuses on separating evidence from a claim.',
  'A non-predictive learning theme about evidence.','reviewed'
);

insert into argus_app.starpath_curriculum_manifests(
  id,manifest_version,policy_version,release_environment,
  supported_jurisdiction,state,published_at,published_by,publication_reason
) values (
  '52000000-a000-4000-8000-000000000001','starpath-state-manifest-v1',
  'starpath-state-v1','beta','US','published',now(),
  '52000000-0000-4000-8000-000000000001',
  'Reviewed test fixture for lifecycle behavior.'
);

insert into argus_app.starpath_manifest_nodes(
  manifest_id,node_ordinal,lesson_id,revision_id,pathway_ordinal,pathway_position
)
select '52000000-a000-4000-8000-000000000001',node,(
    '52000000-4000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,(
    '52000000-3000-4000-8000-'||pg_catalog.lpad(node::text,12,'0')
  )::uuid,((node-1)/2)+1,((node-1)%2)+1
from pg_catalog.generate_series(1,8) node;

insert into argus_app.starpath_manifest_themes(manifest_id,theme_id,ordinal)
values (
  '52000000-a000-4000-8000-000000000001',
  '52000000-9000-4000-8000-000000000001',1
);

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'starpath_policies','starpath_lessons','starpath_lesson_revisions',
    'starpath_knowledge_checks','starpath_knowledge_check_options',
    'starpath_session_themes','starpath_curriculum_manifests',
    'starpath_manifest_nodes','starpath_manifest_themes'
  ] loop
    execute pg_catalog.format('alter table argus_app.%I enable trigger user',relation_name);
    execute pg_catalog.format('alter table argus_app.%I enable row level security',relation_name);
    execute pg_catalog.format('alter table argus_app.%I force row level security',relation_name);
  end loop;
end
$$;
set constraints all immediate;
reset role;
alter table argus_app.editorial_items enable trigger user;
alter table argus_app.editorial_items enable row level security;
alter table argus_app.editorial_items force row level security;
alter table argus_app.editorial_revisions enable trigger user;
alter table argus_app.editorial_revisions enable row level security;
alter table argus_app.editorial_revisions force row level security;

set local role argus_edge;
select argus_private.install_request_context(
  '52000000-0000-4000-8000-000000000002',
  '52000000-1000-4000-8000-000000000002','aal1'
);
set local role argus_member;
select lives_ok(
  $$select argus_private.start_or_resume_starpath_session(
    'starpath-start-0001',repeat('1',64),
    '52000000-a000-4000-8000-000000000001',
    '52000000-9000-4000-8000-000000000001',1
  )$$,
  'an explicit online start creates the authoritative session'
);
reset role;

set local role argus_app_owner;
select is((select count(*)::bigint from argus_app.starpath_sessions),1::bigint,
  'the first command creates one session');
select ok((select explicit_start from argus_app.starpath_sessions limit 1),
  'the session is marked as a retention-qualifying explicit start');
create temporary table starpath_test_session on commit drop as
select id from argus_app.starpath_sessions where state='active';
grant select on starpath_test_session to argus_member;
reset role;

set local role argus_member;
select lives_ok(
  $$select argus_private.start_or_resume_starpath_session(
    'starpath-start-0001',repeat('1',64),
    '52000000-a000-4000-8000-000000000001',
    '52000000-9000-4000-8000-000000000001',1
  )$$,
  'an exact start retry returns a fresh snapshot'
);
reset role;
set local role argus_app_owner;
select is((select count(*)::bigint from argus_app.starpath_sessions),1::bigint,
  'an exact start retry creates no new effect');
reset role;

set local role argus_member;
select lives_ok(
  $$select argus_private.answer_starpath_question(
    'starpath-answer-001',repeat('2',64),(select id from starpath_test_session),
    '52000000-a000-4000-8000-000000000001',
    '52000000-3000-4000-8000-000000000001',
    '52000000-6000-4000-8000-000000000001',
    '52000000-8000-4000-8000-000000000001',1,'node'
  )$$,
  'a wrong factual answer is accepted without a penalty or delay'
);
reset role;
set local role argus_app_owner;
select is((select count(*)::bigint from argus_app.starpath_attempts),1::bigint,
  'the wrong answer is one exact retained attempt');
select is((select progress_version from argus_app.starpath_progress_states),1::bigint,
  'a wrong answer does not advance or version the learning path');
reset role;

set local role argus_member;
select lives_ok(
  $$select argus_private.answer_starpath_question(
    'starpath-answer-002',repeat('3',64),(select id from starpath_test_session),
    '52000000-a000-4000-8000-000000000001',
    '52000000-3000-4000-8000-000000000001',
    '52000000-6000-4000-8000-000000000001',
    '52000000-7000-4000-8000-000000000001',1,'node'
  )$$,
  'the server-derived correct answer completes the current lesson'
);
reset role;
set local role argus_app_owner;
select is((select count(*)::bigint from argus_app.starpath_lesson_completions),1::bigint,
  'correctness creates one stable lesson completion');
select is((select progress_version from argus_app.starpath_progress_states),2::bigint,
  'one correct answer conditionally advances the progress version');
select is((select status from argus_app.starpath_recall_states),'due',
  'completion schedules one non-blocking recall for a later session');
reset role;

set local role argus_member;
select lives_ok(
  $$select argus_private.answer_starpath_question(
    'starpath-answer-002',repeat('3',64),(select id from starpath_test_session),
    '52000000-a000-4000-8000-000000000001',
    '52000000-3000-4000-8000-000000000001',
    '52000000-6000-4000-8000-000000000001',
    '52000000-7000-4000-8000-000000000001',1,'node'
  )$$,
  'an exact answer retry succeeds even though its original version is now stale'
);
reset role;
set local role argus_app_owner;
select is((select count(*)::bigint from argus_app.starpath_attempts),2::bigint,
  'the exact correct-answer retry creates no duplicate attempt');
reset role;

set local role argus_member;
select throws_ok(
  $$select argus_private.answer_starpath_question(
    'starpath-answer-002',repeat('4',64),(select id from starpath_test_session),
    '52000000-a000-4000-8000-000000000001',
    '52000000-3000-4000-8000-000000000001',
    '52000000-6000-4000-8000-000000000001',
    '52000000-7000-4000-8000-000000000001',1,'node'
  )$$,
  '23514','idempotency_conflict',
  'reusing an answer key with another payload fails closed'
);
reset role;

set local role argus_app_owner;
update argus_app.starpath_sessions
   set started_at=pg_catalog.clock_timestamp()-interval '32 minutes',
       last_action_at=pg_catalog.clock_timestamp()-interval '31 minutes'
 where state='active';
reset role;
set local role argus_member;
select lives_ok(
  $$select argus_private.start_or_resume_starpath_session(
    'starpath-start-0002',repeat('5',64),
    '52000000-a000-4000-8000-000000000001',
    '52000000-9000-4000-8000-000000000001',1
  )$$,
  'a start after the inactivity window creates one distinct session'
);
reset role;
set local role argus_app_owner;
select is((select count(*)::bigint from argus_app.starpath_sessions),2::bigint,
  'the later start closes the old session and creates one new session');
select is((select count(*)::bigint from argus_app.starpath_sessions where state='active'),1::bigint,
  'the partial unique invariant leaves exactly one active session');
select is((select status from argus_app.starpath_recall_states),'presented',
  'the next distinct session presents at most one due recall');
select is((select current_node_ordinal from argus_app.starpath_progress_states),2,
  'recall presentation never relocks the newly available lesson');
reset role;

set local role argus_member;
select lives_ok(
  $$select argus_private.start_or_resume_starpath_session(
    'starpath-start-0003',repeat('6',64),
    '52000000-a000-4000-8000-000000000001',
    '52000000-9000-4000-8000-000000000001',1
  )$$,
  'a different command key inside the window resumes the same active session'
);
reset role;
set local role argus_app_owner;
select is((select count(*)::bigint from argus_app.starpath_sessions),2::bigint,
  'different start keys converge on the one active session');
select ok((
  select bool_and(
    result_type is not null and typed_result is not null
    and request_hash~'^[a-f0-9]{64}$'
  ) from argus_private.member_idempotency_records
   where operation like 'starpath.%'
), 'Starpath commands persist typed lifecycle-scoped receipts');
reset role;

select ok(
  pg_catalog.pg_get_functiondef(
    'argus_private.export_starpath_generation_rows()'::regprocedure
  ) not like '%request_hash%'
  and pg_catalog.pg_get_functiondef(
    'argus_private.export_starpath_generation_rows()'::regprocedure
  ) not like '%typed_result%',
  'Starpath export projections exclude internal request hashes and receipts'
);
select ok(
  not has_table_privilege('authenticated','argus_app.starpath_sessions','select'),
  'authenticated clients cannot bypass the generated API for member state'
);
select ok(
  pg_catalog.pg_get_functiondef(
    'argus_private.start_or_resume_starpath_session(text,text,uuid,uuid,bigint)'::regprocedure
  ) like '%<=active_session.last_action_at+interval ''30 minutes''%',
  'the authoritative boundary resumes at exactly 30 minutes'
);

set local role argus_app_owner;
create temporary table starpath_retention_as_of on commit drop as
select pg_catalog.clock_timestamp()-interval '1 second' as as_of;
grant select on starpath_retention_as_of to argus_staff;
with ordered as (
  select session.id,pg_catalog.row_number() over(
    order by session.started_at,session.id
  ) ordinal
  from argus_app.starpath_sessions session
), fixed as (
  select as_of from starpath_retention_as_of
)
update argus_app.starpath_sessions session set
  started_at=case ordered.ordinal
    when 1 then fixed.as_of-interval '8 days'
    else fixed.as_of-interval '1 day' end,
  last_action_at=case ordered.ordinal
    when 1 then fixed.as_of-interval '8 days'+interval '1 minute'
    else fixed.as_of-interval '1 day' end,
  ended_at=case ordered.ordinal
    when 1 then fixed.as_of-interval '8 days'+interval '31 minutes'
    else null end
from ordered,fixed where ordered.id=session.id;
reset role;

set local role argus_staff;
select lives_ok(
  $$select argus_private.capture_starpath_retention_snapshot(
    (select as_of from starpath_retention_as_of)
  )$$,
  'operations read captures a fixed repeatable-read retention snapshot'
);
reset role;
set local role argus_app_owner;
select is((
  select matured_denominator from argus_private.starpath_retention_snapshots
),1::bigint,'only the fully matured explicit-start cohort enters the denominator');
select is((
  select retained_count from argus_private.starpath_retention_snapshots
),1::bigint,'a second explicit session exactly 168 hours later is retained');
select ok((
  select snapshot_checksum~'^[a-f0-9]{64}$'
    and cohort_lower_bound=as_of-interval '14 days'
    and cohort_upper_bound=as_of-interval '7 days'
  from argus_private.starpath_retention_snapshots
), 'the snapshot fixes its UTC bounds and checksum');
select ok((
  select deletion_recomputation_note like '%Lawful member deletion%'
  from argus_private.starpath_retention_snapshots
), 'the aggregate documents deletion-time recomputation drift');
reset role;
select ok(
  not has_function_privilege(
    'argus_member',
    'argus_private.capture_starpath_retention_snapshot(timestamptz)',
    'execute'
  ),
  'members cannot read or capture the operations retention report'
);

alter table argus_private.deletion_tombstones disable row level security;
alter table argus_private.deletion_tombstones disable trigger user;
insert into argus_private.deletion_tombstones(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,status,purge_phase
)
select '52000000-b000-4000-8000-000000000001',
  member.tenant_id,member.lifecycle_id,member.user_id,1,
  'purging','storage_purged'
from argus_app.members member
where member.user_id='52000000-0000-4000-8000-000000000002';
alter table argus_private.deletion_tombstones enable trigger user;
alter table argus_private.deletion_tombstones enable row level security;
alter table argus_private.deletion_tombstones force row level security;

set local role argus_application_purge_owner;
select lives_ok(
  $$select argus_private.purge_member_application_data(
    '52000000-b000-4000-8000-000000000001'
  )$$,
  'the real application purge port deletes the Starpath inventory child-first'
);
select is((
  select count(*)::bigint from argus_app.starpath_sessions
  where user_id='52000000-0000-4000-8000-000000000002'
),0::bigint,'application purge removes every lifecycle-bound Starpath row');
select is((
  select count(*)::bigint from argus_private.member_idempotency_records
  where user_id='52000000-0000-4000-8000-000000000002'
    and operation like 'starpath.%'
),0::bigint,'application purge removes Starpath command receipts last');
reset role;

select * from finish();
rollback;

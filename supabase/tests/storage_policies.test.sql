begin;

do $membership$ begin
  execute pg_catalog.format(
    'grant argus_edge,argus_member,argus_worker,argus_jobs_owner to %I with set true',
    current_user
  );
end $membership$;
grant usage on schema extensions to authenticated,argus_member,argus_worker;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(26);

select is(
  (select public from storage.buckets where id='member-media'),false,
  'member media bucket is private'
);
select is(
  (select public from storage.buckets where id='privacy-exports'),false,
  'privacy export bucket is private'
);
select is(
  (select public from storage.buckets where id='media-quarantine'),false,
  'media quarantine bucket is private'
);
select is(
  (select file_size_limit from storage.buckets where id='member-media'),
  10485760::bigint,
  'member media has a bounded size'
);
select is(
  (select file_size_limit from storage.buckets where id='privacy-exports'),
  52428800::bigint,
  'privacy exports have a bounded size'
);
select set_eq(
  $$select policyname||':'||cmd from pg_policies
     where schemaname='storage' and tablename='objects'
       and policyname like 'argus_%'$$,
  $$values ('argus_u6_managed_media_select:SELECT'),
    ('argus_u6_managed_media_insert:INSERT')$$,
  'Storage policy surface is exact: allocated create and published read'
);
select ok(
  not exists(select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and roles::text~'authenticated' and cmd in ('UPDATE','DELETE')),
  'authenticated callers receive no replace or delete policy for immutable objects'
);
select is(
  (select count(*)::bigint from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname like 'argus_%' and roles@>array['anon']::name[]),
  0::bigint,
  'anon receives no Argus Storage policy'
);
select is(
  (select count(*)::bigint from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname like 'argus_%'
      and (coalesce(qual,'') like '%auth.role()%'
        or coalesce(with_check,'') like '%auth.role()%')),
  0::bigint,
  'Storage policies do not use deprecated auth.role()'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','authenticated','authenticated',
   'media-a@example.test','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','authenticated','authenticated',
   'media-b@example.test','',now(),'{}','{}',now(),now());

create temporary table media_contract_intent(
  intent_id uuid,storage_object_id uuid,bucket_id text,object_path text,
  mime_type text,max_bytes bigint,expires_at timestamptz,status text
) on commit drop;
grant select,insert on media_contract_intent
  to authenticated,argus_member,argus_worker,argus_jobs_owner;

set local role argus_edge;
select argus_private.install_request_context(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'aaaaaaaa-0000-4000-8000-000000000001','aal1'
);
reset role;
set local role argus_member;
insert into media_contract_intent
select * from argus_private.create_media_upload_intent(
  'image/webp',1024,pg_catalog.clock_timestamp()+interval '30 minutes'
);
reset role;
select ok(
  (select status='pending' and bucket_id='member-media'
     and object_path like
       'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/%/%'
   from media_contract_intent),
  'member command allocates one lifecycle-qualified quarantine identity'
);

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}',true
);
insert into storage.objects(id,bucket_id,name,owner_id)
select 'aaaaaaaa-8000-4000-8000-000000000001',bucket_id,object_path,
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
from media_contract_intent;
select is(
  (select count(*)::bigint from storage.objects
    where id='aaaaaaaa-8000-4000-8000-000000000001'),
  0::bigint,
  'allocated but unverified media is not readable'
);
select throws_ok(
  $$insert into storage.objects(id,bucket_id,name,owner_id)
    select 'aaaaaaaa-8000-4000-8000-000000000002',bucket_id,object_path,
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    from media_contract_intent$$,
  '23505',null,
  'immutable Storage identity cannot be inserted twice because the object name is unique'
);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}',true
);
select throws_ok(
  $$insert into storage.objects(id,bucket_id,name,owner_id)
    select 'bbbbbbbb-8000-4000-8000-000000000001',bucket_id,object_path,
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
    from media_contract_intent$$,
  '42501',null,
  'another user cannot upload into the allocated path'
);
reset role;

set local role argus_member;
select lives_ok(
  $$select argus_private.finalize_media_upload(
      (select intent_id from media_contract_intent),10,repeat('a',64)
    )$$,
  'member finalization records the immutable observed object and outbox handoff'
);
reset role;
select ok(
  exists(select 1 from argus_private.outbox_events event
    join argus_app.members member on member.user_id=event.user_id
    where event.event_type='media.structural_validation.requested'
      and event.aggregate_id=(select intent_id from media_contract_intent)
      and event.tenant_id=member.tenant_id
      and event.lifecycle_id=member.lifecycle_id),
  'validation event preserves the exact member lifecycle scope'
);

update argus_private.kill_switches set enabled=false,reason=null
 where name='background_workers';
set local role argus_worker;
select is(argus_private.relay_outbox(25),1,'validation event relays exactly once');
create temporary table media_contract_claim on commit drop as
select * from argus_private.claim_next_argus_job(45);
select argus_private.set_worker_event_context(event_id,job_run_id,lease_token)
  from media_contract_claim;
create temporary table media_contract_effect on commit drop as
select * from argus_private.prepare_media_structural_validation(
  (select event_id from media_contract_claim)
);
grant select on media_contract_effect to argus_jobs_owner;
select lives_ok(
  $$select argus_private.complete_media_structural_validation(
      (select effect_id from media_contract_effect),true,repeat('a',64),64,64,null
    )$$,
  'structural verification publishes only the observed immutable object'
);
select argus_private.complete_argus_job(
  (select job_run_id from media_contract_claim),
  (select lease_token from media_contract_claim),repeat('b',64)
);
reset role;

set local role argus_jobs_owner;
select ok(
  exists(select 1 from argus_private.managed_storage_objects object
    where object.id=(select storage_object_id from media_contract_intent)
      and object.state='published'
      and object.expected_checksum=repeat('a',64)
      and object.observed_checksum=repeat('a',64)
      and object.structurally_verified_at is not null
      and object.published_at is not null),
  'managed metadata truthfully records structural verification and publication'
);
select ok(
  exists(select 1 from argus_app.media_assets asset
    where asset.storage_object_id=(select storage_object_id from media_contract_intent)
      and asset.quarantine_status='structurally_verified' and asset.status='active'),
  'typed media authority activates only after structural verification'
);
select throws_ok(
  $$update argus_app.media_assets set quarantine_status='clear'
      where storage_object_id=(select storage_object_id from media_contract_intent)$$,
  '23514',null,
  'legacy clearance vocabulary cannot be written without attestation'
);
reset role;

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}',true
);
select is(
  (select count(*)::bigint from storage.objects
    where id='aaaaaaaa-8000-4000-8000-000000000001'),
  1::bigint,
  'owner can read the exact published object version'
);
select is(
  (select count(*)::bigint from storage.objects where bucket_id='privacy-exports'),
  0::bigint,
  'privacy exports remain signed-access only'
);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}',true
);
select is(
  (select count(*)::bigint from storage.objects
    where id='aaaaaaaa-8000-4000-8000-000000000001'),
  0::bigint,
  'another lifecycle cannot read the published object by identifier'
);
reset role;

select is(
  (select count(*)::bigint from argus_private.job_event_registry
    where event_type='media.scan.requested'),0::bigint,
  'the system makes no malware-scanning claim without attestation'
);
select ok(
  not exists(
    select 1 from pg_catalog.pg_constraint constraint_record
    where constraint_record.conname in (
      'media_assets_quarantine_status_check','media_upload_intents_status_check'
    ) and pg_catalog.pg_get_constraintdef(constraint_record.oid) ~
      '''(clear|scanning)'''
  ),
  'legacy scanning and clearance states are absent from enforced contracts'
);
select ok(
  not exists(select 1 from argus_private.managed_storage_objects
    where state='published'
      and (structurally_verified_at is null or expected_checksum<>observed_checksum)),
  'no object is publishable without matching structural evidence'
);

select * from finish();
rollback;

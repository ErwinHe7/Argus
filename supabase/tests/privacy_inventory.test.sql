begin;
set transaction isolation level repeatable read;

do $membership$ begin
  execute pg_catalog.format(
    'grant argus_edge,argus_member,argus_worker,argus_jobs_owner to %I with set true',
    current_user
  );
end $membership$;
grant usage on schema extensions
  to argus_edge,argus_member,argus_worker,argus_jobs_owner;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(40);

select has_table(
  'argus_private','privacy_export_generations',
  'privacy exports have explicit immutable generations'
);
select has_table(
  'argus_private','privacy_export_generation_rows',
  'sealed export rows are materialized before egress'
);
select has_table(
  'argus_private','privacy_export_generation_collections',
  'every export collection has an explicit disposition'
);
select has_table(
  'argus_private','privacy_export_generation_objects',
  'published source objects are bound into the sealed generation'
);
select has_table(
  'argus_private','managed_storage_objects',
  'Storage identities are modeled independently from product rows'
);
select has_column(
  'argus_private','privacy_export_generations','lifecycle_id',
  'export generations bind the immutable member lifecycle'
);
select ok(
  exists(select 1 from pg_constraint constraint_row
    where constraint_row.conrelid='argus_private.privacy_export_generations'::regclass
      and constraint_row.contype='u'
      and pg_get_constraintdef(constraint_row.oid)=
        'UNIQUE (request_id, generation_number)'),
  'generation numbers are unique within a request'
);
select is(
  (select count(*)::bigint
     from argus_private.privacy_export_collection_registry),39::bigint,
  'privacy inventory has 39 reviewed normalized collections'
);
select set_eq(
  $$select collection_name from argus_private.privacy_export_collection_registry$$,
  $$values
    ('member'),('profile'),('preferences'),('astrology_profile'),
    ('investor_profile'),('onboarding'),('consents'),
    ('notification_preferences'),('ritual_assignments'),('circles'),
    ('circle_assets'),('saved_items'),('intentions'),('future_mirror_runs'),
    ('future_mirror_points'),('briefings'),('briefing_sections'),
    ('notifications'),('privacy_requests'),('content_reports'),
    ('onboarding_step_completions'),('notification_quiet_hours'),
    ('briefing_read_states'),('content_report_targets'),
    ('starpath_sessions'),('starpath_progress'),('starpath_completions'),
    ('starpath_attempts'),('starpath_recall_states'),
    ('brokerage_connections'),('brokerage_accounts'),
    ('brokerage_active_account_selections'),
    ('brokerage_account_capabilities'),
    ('brokerage_projection_generations'),
    ('brokerage_projection_balance_facts'),
    ('brokerage_projection_position_facts'),
    ('brokerage_projection_restriction_facts'),
    ('brokerage_projection_account_facts'),
    ('brokerage_order_projection_generations')$$,
  'collection inventory is exact rather than a catch-all relation loop'
);
select ok(
  not exists(select 1 from argus_private.privacy_export_collection_registry
    where source_relation::text in ('argus_app.saved_items')
       or source_relation::text !~ '^argus_(app|brokerage)\.'),
  'export inventory uses normalized application or brokerage relations and no private source'
);
select ok(
  not has_table_privilege(
    'argus_member','argus_private.privacy_export_generations','select'
  ),
  'member cannot read private generation metadata directly'
);
select ok(
  not has_table_privilege(
    'argus_member','argus_private.privacy_export_generation_rows','select'
  ),
  'member cannot read sealed rows directly'
);
select has_index(
  'argus_private','privacy_export_generation_rows',
  'privacy_export_generation_rows_page_idx',
  'sealed page reads have a deterministic supporting index'
);
select ok(
  exists(select 1 from pg_trigger trigger_row
    where trigger_row.tgrelid='argus_private.privacy_export_generation_rows'::regclass
      and trigger_row.tgname='protect_privacy_generation_rows'
      and trigger_row.tgenabled='O'),
  'sealed export rows have an enabled mutation guard'
);
select ok(
  exists(select 1 from pg_constraint constraint_row
    where constraint_row.conrelid='argus_private.managed_storage_objects'::regclass
      and constraint_row.contype='u'
      and pg_get_constraintdef(constraint_row.oid)='UNIQUE (bucket_id, object_path)'),
  'managed Storage paths are immutable non-reused identities'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '66666666-6666-4666-8666-666666666666','authenticated','authenticated',
  'u6-privacy@example.test','',pg_catalog.clock_timestamp(),
  '{"provider":"email","providers":["email"]}','{}',
  pg_catalog.clock_timestamp(),pg_catalog.clock_timestamp()
);

set local role argus_edge;
select argus_private.install_request_context(
  '66666666-6666-4666-8666-666666666666',
  '66666666-0000-4000-8000-000000000001','aal1'
);
reset role;

set local role argus_member;
select lives_ok(
  $$select argus_private.request_privacy_export(
    'privacy-inventory-u6-0001'
  )$$,
  'member export command atomically creates the request and outbox handoff'
);
reset role;

select is(
  (select count(*)::bigint from argus_private.outbox_events event
    join argus_app.members member on member.user_id=event.user_id
    where event.event_type='privacy.export.requested'
      and event.user_id='66666666-6666-4666-8666-666666666666'
      and event.tenant_id=member.tenant_id
      and event.lifecycle_id=member.lifecycle_id),
  1::bigint,
  'export event carries the exact tenant, lifecycle, and identity subject'
);

set local role argus_jobs_owner;
update argus_private.outbox_events set available_at='infinity'::timestamptz
 where published_at is null
   and user_id is distinct from '66666666-6666-4666-8666-666666666666';
reset role;
update argus_private.kill_switches set enabled=false,reason=null
 where name='background_workers';

set local role argus_worker;
select is(
  argus_private.relay_outbox(25),1,
  'one reviewed export event crosses the private queue adapter'
);
create temporary table privacy_test_claim on commit drop as
select * from argus_private.claim_next_argus_job(55);
select is(
  (select count(*)::bigint from privacy_test_claim
    where event_type='privacy.export.requested'),1::bigint,
  'export event is claimed with a bounded durable lease'
);
select argus_private.set_worker_event_context(event_id,job_run_id,lease_token)
  from privacy_test_claim;
create temporary table privacy_test_generation on commit drop as
select * from argus_private.prepare_privacy_export_generation(
  (select event_id from privacy_test_claim)
);
grant select on privacy_test_claim,privacy_test_generation to argus_jobs_owner;
select ok(
  (select generation_state='assembling'
      and generation_number=1
      and seal_checksum~'^[a-f0-9]{64}$'
     from privacy_test_generation),
  'first generation is sealed before external assembly begins'
);
reset role;

set local role argus_jobs_owner;
select is(
  (select count(*)::bigint
     from argus_private.privacy_export_generation_collections collection
    where collection.generation_id=(
      select generation_id from privacy_test_generation
    )),39::bigint,
  'every registered collection is present even when it has zero rows'
);
select is(
  (select coalesce(sum(collection.row_count),0)::bigint
     from argus_private.privacy_export_generation_collections collection
    where collection.generation_id=(
      select generation_id from privacy_test_generation
    )),
  (select count(*)::bigint
     from argus_private.privacy_export_generation_rows row
    where row.generation_id=(
      select generation_id from privacy_test_generation
    )),
  'sealed collection counts equal the exact row inventory'
);
select is(
  (select generation.seal_checksum
     from argus_private.privacy_export_generations generation
    where generation.id=(select generation_id from privacy_test_generation)),
  (select pg_catalog.encode(extensions.digest(
    pg_catalog.jsonb_build_object(
      'schema_version',1,'tenant_id',generation.tenant_id,
      'lifecycle_id',generation.lifecycle_id,'request_id',generation.request_id,
      'generation_number',generation.generation_number,
      'cutoff_at',generation.cutoff_at,
      'collections',(
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'name',collection.collection_name,'count',collection.row_count,
          'checksum',collection.collection_checksum
        ) order by registry.ordinal)
        from argus_private.privacy_export_generation_collections collection
        join argus_private.privacy_export_collection_registry registry
          using (collection_name)
        where collection.generation_id=generation.id
      ),
      'objects',coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id',object.storage_object_id,'checksum',object.content_checksum
        ) order by object.storage_object_id)
        from argus_private.privacy_export_generation_objects object
        where object.generation_id=generation.id
      ),'[]'::jsonb)
    )::text,'sha256'),'hex')
    from argus_private.privacy_export_generations generation
    where generation.id=(select generation_id from privacy_test_generation)),
  'seal checksum proves cutoff, ordered counts, row fingerprints, and objects'
);
reset role;

set local role argus_worker;
select is(
  (select generation_id from argus_private.prepare_privacy_export_generation(
    (select event_id from privacy_test_claim)
  )),
  (select generation_id from privacy_test_generation),
  'crash-before-effect replay resumes the same sealed generation'
);
reset role;

set local role argus_jobs_owner;
select results_eq(
  format(
    'with attempted as (
       update argus_private.privacy_export_generation_rows
          set row_payload=%L::jsonb where generation_id=%L returning 1
     ) select count(*)::bigint from attempted',
    '{"tampered":true}',(select generation_id from privacy_test_generation)
  ),
  $$values (0::bigint)$$,
  'owner policy matrix exposes no sealed row for mutation'
);
reset role;

set local role argus_member;
update argus_app.profiles set display_name='Changed after seal';
reset role;
set local role argus_jobs_owner;
select is(
  (select row.row_payload->>'display_name'
     from argus_private.privacy_export_generation_rows row
    where row.generation_id=(select generation_id from privacy_test_generation)
      and row.collection_name='profile' and row.ordinal=1),
  'Argus member',
  'concurrent source mutation cannot change an already sealed generation'
);
select is(
  (select count(*)::bigint
     from argus_private.privacy_export_generation_rows row
    where row.generation_id=(select generation_id from privacy_test_generation)
      and row.row_payload::text~*
        'password|token|credential|ciphertext|raw_payload|idempotency_key'),
  0::bigint,
  'sealed rows contain no credential-shaped or raw-provider field'
);
reset role;

set local role argus_worker;
select lives_ok(
  format(
    'select argus_private.fail_privacy_export_generation(%L,%L)',
    (select generation_id from privacy_test_generation),
    'privacy_export_source_mismatch'
  ),
  'unavailable or mismatched content records a failed generation'
);
reset role;
set local role argus_jobs_owner;
select ok(
  (select generation.state='failed' and object.state='reconciliation'
      and effect.state='failed' and request.status='failed'
     from argus_private.privacy_export_generations generation
     join argus_private.managed_storage_objects object
       on object.id=generation.storage_object_id
     join argus_private.external_effects effect
       on effect.generation_id=generation.id
      and effect.effect_kind='privacy_archive_put'
     join argus_app.privacy_requests request on request.id=generation.request_id
    where generation.id=(select generation_id from privacy_test_generation)),
  'failed assembly atomically records generation, Storage, effect, and request disposition'
);
reset role;
set local role argus_worker;
create temporary table privacy_test_generation_retry on commit drop as
select * from argus_private.prepare_privacy_export_generation(
  (select event_id from privacy_test_claim)
);
grant select on privacy_test_generation_retry to argus_jobs_owner;
select is(
  (select generation_number from privacy_test_generation_retry),2,
  'retry receives a new generation number'
);
select isnt(
  (select storage_object_id from privacy_test_generation_retry),
  (select storage_object_id from privacy_test_generation),
  'retry receives a new immutable Storage object identity'
);
reset role;

set local role argus_jobs_owner;
select is(
  (select count(*)::bigint
     from argus_private.privacy_export_generation_collections collection
    where collection.generation_id=(
      select generation_id from privacy_test_generation_retry
    )),39::bigint,
  'retry generation independently seals every collection disposition'
);
reset role;

set local role argus_worker;
select lives_ok(
  format(
    'select argus_private.complete_privacy_export_generation(%L,%L,%L,%L,100)',
    (select generation_id from privacy_test_generation_retry),
    (select seal_checksum from privacy_test_generation_retry),
    repeat('b',64),repeat('c',64)
  ),
  'external assembly completes only against the exact sealed generation'
);
reset role;

set local role argus_jobs_owner;
select ok(
  (select generation.state='published' and request.status='completed'
      and generation.archive_manifest_checksum=repeat('b',64)
      and generation.archive_checksum=repeat('c',64)
     from argus_private.privacy_export_generations generation
     join argus_app.privacy_requests request on request.id=generation.request_id
    where generation.id=(select generation_id from privacy_test_generation_retry)),
  'publication and request completion are truthful and atomic'
);
select ok(
  exists(select 1 from argus_private.privacy_export_artifacts artifact
    join argus_private.privacy_export_generations generation
      on generation.request_id=artifact.request_id
     and generation.storage_object_id=artifact.storage_object_id
    where generation.id=(select generation_id from privacy_test_generation_retry)
      and artifact.checksum=repeat('c',64)),
  'published artifact references the exact immutable managed object'
);
reset role;

set local role argus_worker;
select lives_ok(
  format(
    'select argus_private.complete_privacy_export_generation(%L,%L,%L,%L,100)',
    (select generation_id from privacy_test_generation_retry),
    (select seal_checksum from privacy_test_generation_retry),
    repeat('b',64),repeat('c',64)
  ),
  'completion replay with identical evidence is idempotent'
);
select throws_ok(
  format(
    'select argus_private.complete_privacy_export_generation(%L,%L,%L,%L,100)',
    (select generation_id from privacy_test_generation_retry),
    (select seal_checksum from privacy_test_generation_retry),
    repeat('b',64),repeat('d',64)
  ),
  'P0001','privacy_export_completion_conflict',
  'completion replay with conflicting archive evidence fails closed'
);
reset role;

set local role argus_member;
select throws_ok(
  $$select count(*) from argus_private.privacy_export_generations$$,
  '42501',null,
  'member cannot inspect private generation history after publication'
);
create temporary table privacy_test_download on commit drop as
select * from argus_private.prepare_privacy_export_download(
  (select id from argus_private.list_member_privacy_requests()
    where request_type='export')
);
select ok(
  (select bucket_id='privacy-exports' and expires_in_seconds=30
     from privacy_test_download),
  'signed access preparation returns only the current published object with a 30-second residual URL lifetime'
);
select ok(
  argus_private.confirm_privacy_export_download(
    (select access_lease_id from privacy_test_download)
  ),
  'signed access is confirmed inside the still-open member lifecycle'
);
reset role;

select * from finish();
rollback;

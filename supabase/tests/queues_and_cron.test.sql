begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, pg_catalog, public;

select plan(43);

select has_extension('pgmq', 'Supabase Queues extension is enabled');
select has_extension('pg_cron', 'Supabase Cron extension is enabled');
select has_extension('pg_net', 'Supabase pg_net extension is enabled');
select has_table('pgmq', 'q_argus_jobs', 'logged Argus job queue exists');
select has_table('pgmq', 'a_argus_jobs', 'Argus success archive exists');
select hasnt_schema('pgmq_public', 'queues are not exposed through a Data API wrapper');
select ok(not has_schema_privilege('anon', 'pgmq', 'usage'), 'anon has no queue schema usage');
select ok(not has_schema_privilege('authenticated', 'pgmq', 'usage'), 'authenticated has no queue schema usage');
select ok(has_schema_privilege('argus_worker', 'pgmq', 'usage'), 'worker can use private queues');
select has_role('argus_worker_edge', 'dedicated worker Edge login exists');
select ok(
  exists (
    select 1 from pg_roles where rolname='argus_worker_edge'
      and not rolsuper and not rolbypassrls and not rolinherit
  ),
  'worker Edge login cannot inherit, bypass RLS, or become superuser'
);

select is(
  (select count(*)::bigint from cron.job
    where jobname in ('argus-retained-enqueue','argus-worker-dispatch')),
  2::bigint,
  'Cron declares only the retained enqueue and authenticated worker dispatch ticks'
);
select is(
  (select count(*)::bigint from cron.job
    where command ~* 'secret|apikey|authorization|bearer|vault'),
  0::bigint,
  'Cron definitions contain no credential or Vault read'
);
select has_index(
  'argus_private', 'worker_invocation_nonces', 'worker_invocation_nonces_expiry_idx',
  'one-use invocation nonces have an expiry-cleanup index'
);
select ok(
  (select relforcerowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='argus_private' and c.relname='consumer_receipts'),
  'consumer receipts force RLS'
);
select ok(
  not has_table_privilege('argus_worker','argus_private.consumer_receipts','insert'),
  'worker cannot forge a receipt outside complete_argus_job'
);
select is(
  (select count(*)::bigint
     from pg_policies
    where schemaname='argus_app'
      and tablename in ('onboarding_states','consent_records','notification_preferences')
      and policyname='worker_event_owner'
      and 'argus_worker'=any(roles)),
  3::bigint,
  'every privacy export owner table is fenced by the event owner and epoch policy'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'authenticated','authenticated','queue@example.test','',now(),
  '{"provider":"email","providers":["email"]}','{}',now(),now()
);
insert into argus_app.members(user_id)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') on conflict do nothing;

savepoint domain_tx;
insert into argus_app.notifications(id,user_id,deletion_epoch,kind,title,body)
values (
  'aaaaaaaa-6000-4000-8000-000000000001',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'briefing_ready','Title','Body'
);
insert into argus_private.outbox_events(
  id,user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
) values (
  'aaaaaaaa-7000-4000-8000-000000000001',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'argus_jobs',
  'briefing.daily.generated','aaaaaaaa-6000-4000-8000-000000000001','notification:rollback'
);
rollback to domain_tx;
select is(
  (select count(*)::bigint from argus_private.outbox_events
    where id='aaaaaaaa-7000-4000-8000-000000000001'),
  0::bigint,
  'rolled-back domain transaction leaves no outbox event'
);

insert into argus_private.outbox_events(
  id,user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
) values (
  'aaaaaaaa-7000-4000-8000-000000000002',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'argus_jobs',
  'briefing.daily.generated','aaaaaaaa-6000-4000-8000-000000000002','notification:opaque'
);
set local role argus_worker;
select is(argus_private.relay_outbox(10), 1, 'relay publishes one due retained event');
reset role;
select is(
  (select count(*)::bigint from pgmq.q_argus_jobs where message ? 'event_id'),
  1::bigint,
  'relay publishes one opaque versioned queue message'
);
select is(
  (select count(*)::bigint from pgmq.q_argus_jobs q,
    lateral jsonb_object_keys(q.message) key),
  2::bigint,
  'queue message has exactly two keys'
);
select is(
  (select count(*)::bigint from pgmq.q_argus_jobs
    where message ?| array['event_type','handler','consumer','user_id','email']),
  0::bigint,
  'queue message contains no routing, ownership, or identity field'
);
select ok(
  exists (select 1 from argus_private.outbox_events
    where id='aaaaaaaa-7000-4000-8000-000000000002' and published_at is not null),
  'relay records publication in the same database transaction'
);

select ok(
  not has_function_privilege('anon','argus_private.claim_next_argus_job(integer)','execute'),
  'anon cannot claim work'
);
select ok(
  not has_function_privilege('argus_runtime','argus_private.claim_next_argus_job(integer)','execute'),
  'member API runtime cannot claim work'
);
select ok(
  not has_function_privilege('argus_worker','argus_private.resolve_worker_invocation_config()','execute'),
  'worker cannot read Vault invocation configuration'
);
select throws_ok(
  $$select argus_private.dead_letter_queue_message(0,null,null,'email_canary','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')$$,
  'P0001','invalid_dead_letter',
  'dead-letter reasons are an exact database allowlist'
);
select is(
  argus_private.retained_job_handler('recurring-plan-delivery'),
  null,
  'recurring financial delivery has no retained handler'
);

select pgmq.archive('argus_jobs', msg_id)
  from pgmq.q_argus_jobs
 where message ->> 'event_id' = 'aaaaaaaa-7000-4000-8000-000000000002';
select pgmq.send(
  'argus_jobs',
  '{"version":2,"event_id":"aaaaaaaa-7000-4000-8000-000000000099","email":"canary@example.test","credential":"canary-secret"}'::jsonb
);
set local role argus_worker;
select is(
  (select count(*)::bigint from argus_private.claim_next_argus_job(45)),
  0::bigint,
  'poison injection is terminalized without becoming work'
);
reset role;
select is(
  (select count(*)::bigint from pgmq.q_argus_jobs
    where message::text like '%canary@example.test%'),
  0::bigint,
  'poison content is deleted from the live queue'
);
select is(
  (select count(*)::bigint from pgmq.a_argus_jobs
    where message::text ~* 'canary@example\.test|canary-secret'),
  0::bigint,
  'poison content is never copied into the queue archive'
);
select is(
  (select count(*)::bigint from argus_private.dead_letter_events
    where reason_code='invalid_event_payload'),
  1::bigint,
  'poison injection leaves one redacted dead-letter record'
);
select is(
  (select count(*)::bigint from argus_private.dead_letter_events
    where row_to_json(dead_letter_events)::text ~* 'canary|email|credential'),
  0::bigint,
  'dead-letter rows contain no poison identity or credential value'
);

insert into argus_private.outbox_events(
  id,user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
) values (
  'aaaaaaaa-7000-4000-8000-000000000003',null,null,'argus_jobs',
  'privacy.export.retention.requested','aaaaaaaa-6000-4000-8000-000000000003',
  'recovery-terminal-canary'
);
set local role argus_worker;
select is(argus_private.relay_outbox(10), 1, 'recovery fixture relays one valid opaque event');
select is(
  (select count(*)::bigint from argus_private.claim_next_argus_job(45)),
  1::bigint,
  'valid recovery fixture is leased once'
);
reset role;
update argus_private.job_runs
   set max_attempts=1, leased_until=clock_timestamp()-interval '1 second'
 where source_event_id='aaaaaaaa-7000-4000-8000-000000000003';
set local role argus_worker;
select is(argus_private.recover_expired_work(10), 1, 'expired final attempt is recovered once');
reset role;
select ok(
  exists(select 1 from argus_private.job_runs run
    join argus_private.job_attempts attempt on attempt.job_run_id=run.id
    where run.source_event_id='aaaaaaaa-7000-4000-8000-000000000003'
      and run.status='dead_lettered' and attempt.outcome='dead_lettered'
      and attempt.failure_code='lease_expired')
  and exists(select 1 from argus_private.dead_letter_events
    where outbox_event_id='aaaaaaaa-7000-4000-8000-000000000003'
      and reason_code='lease_expired'),
  'terminal recovery converges run, attempt, and redacted DLQ state'
);
select ok(
  not exists(select 1 from pgmq.q_argus_jobs
    where message->>'event_id'='aaaaaaaa-7000-4000-8000-000000000003')
  and exists(select 1 from pgmq.a_argus_jobs
    where message=jsonb_build_object(
      'version',1,'event_id','aaaaaaaa-7000-4000-8000-000000000003'
    )),
  'terminal recovery archives only the valid opaque envelope'
);
select pgmq.send(
  'argus_jobs',
  jsonb_build_object('version',1,'event_id','aaaaaaaa-7000-4000-8000-000000000003')
);
set local role argus_worker;
select is(
  (select count(*)::bigint from argus_private.claim_next_argus_job(45)),
  0::bigint,
  'duplicate delivery for a terminal job does not loop or become work'
);
reset role;
select ok(
  not exists(select 1 from pgmq.q_argus_jobs
    where message->>'event_id'='aaaaaaaa-7000-4000-8000-000000000003')
  and (select count(*) from pgmq.a_argus_jobs
    where message->>'event_id'='aaaaaaaa-7000-4000-8000-000000000003')=2,
  'terminal duplicate is archived exactly once and removed from the live queue'
);
select is(
  (select count(*)::bigint from cron.job
    where row_to_json(job)::text like '%canary-secret%'),
  0::bigint,
  'Cron catalog contains no plaintext credential canary'
);
select vault.create_secret(
  'https://project.supabase.co/functions/v1/worker',
  'argus_worker_url',
  'pgTAP worker URL'
);
select vault.create_secret(
  'canary-secret-that-is-at-least-thirty-two-characters',
  'argus_worker_secret_current',
  'pgTAP current worker secret'
);
select argus_private.invoke_worker();
select is(
  (select count(*)::bigint from net.http_request_queue
    where headers ?& array[
      'x-argus-worker-timestamp','x-argus-worker-nonce','x-argus-worker-proof'
    ]),
  1::bigint,
  'pg_net persists only a timestamp, nonce, and HMAC proof for worker auth'
);
select is(
  (select count(*)::bigint from net.http_request_queue
    where row_to_json(http_request_queue)::text like '%canary-secret-that-is-at-least-thirty-two-characters%'),
  0::bigint,
  'pg_net request records contain no plaintext credential canary'
);

select * from finish();
rollback;

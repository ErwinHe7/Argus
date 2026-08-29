begin;

grant argus_worker,argus_jobs_owner to current_user with set true;
grant usage on schema extensions to argus_worker;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(35);

select ok(
  (select enabled from argus_private.kill_switches where name='background_workers'),
  'a clean deployment starts with background workers fenced'
);
select has_extension('pgmq','Supabase Queues extension is enabled');
select has_extension('pg_cron','Supabase Cron extension is enabled');
select has_extension('pg_net','Supabase pg_net extension is enabled');
select has_table('pgmq','q_argus_jobs','logged Argus job queue exists');
select has_table('pgmq','a_argus_jobs','Argus success archive exists');
select hasnt_schema('pgmq_public','queues are not exposed through a Data API wrapper');
select ok(not has_schema_privilege('anon','pgmq','usage'),'anon has no queue schema usage');
select ok(
  not has_schema_privilege('authenticated','pgmq','usage'),
  'authenticated has no queue schema usage'
);
select ok(
  not has_schema_privilege('argus_worker','pgmq','usage'),
  'worker reaches Queues only through durable job capabilities'
);
select ok(
  has_schema_privilege('argus_jobs_owner','pgmq','usage'),
  'the NOLOGIN queue adapter owner alone can use pgmq'
);
select has_role('argus_worker_edge','dedicated worker Edge login exists');
select ok(
  exists(select 1 from pg_roles where rolname='argus_worker_edge'
    and not rolsuper and not rolbypassrls and not rolinherit),
  'worker Edge login cannot inherit, bypass RLS, or become superuser'
);
select is(
  (select count(*)::bigint from cron.job job
    join argus_private.job_schedule_registry registry
      on registry.schedule_name=job.jobname
     and registry.schedule_expression=job.schedule
     and registry.command=job.command),
  3::bigint,
  'Cron catalog exactly deploys the three registered coordination schedules'
);
select is(
  (select count(*)::bigint from cron.job
    where command~* 'secret|apikey|authorization|bearer|vault|pgmq\.|net\.|http'),
  0::bigint,
  'Cron definitions contain no credential, queue, or network operation'
);
select ok(
  not exists(select 1 from argus_private.job_schedule_registry
    where command~* '(insert|update|delete|pgmq\.|net\.|http)'),
  'registered Cron work is coordinator-only'
);
select has_index(
  'argus_private','worker_invocation_nonces','worker_invocation_nonces_expiry_idx',
  'one-use invocation nonces have an expiry-cleanup index'
);
select ok(
  (select relforcerowsecurity from pg_class
    where oid='argus_private.consumer_receipts'::regclass),
  'consumer receipts force RLS'
);
select ok(
  not has_table_privilege('argus_worker','argus_private.consumer_receipts','insert'),
  'worker cannot forge a receipt outside complete_argus_job'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','authenticated','authenticated',
  'queue-u6@example.test','',now(),'{}','{}',now(),now()
);
set local role argus_jobs_owner;
insert into argus_private.outbox_events(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
  aggregate_id,dedupe_key
) select
  'aaaaaaaa-7000-4000-8000-000000000001',member.tenant_id,member.lifecycle_id,
  member.user_id,member.deletion_epoch,'argus_jobs','content-report.created',1,
  'aaaaaaaa-6000-4000-8000-000000000001','queue-contract-u6-0001'
from argus_app.members member
where member.user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
reset role;
select ok(
  exists(select 1 from argus_private.outbox_events event
    join argus_app.members member on member.user_id=event.user_id
    where event.id='aaaaaaaa-7000-4000-8000-000000000001'
      and event.tenant_id=member.tenant_id
      and event.lifecycle_id=member.lifecycle_id),
  'member event persists its exact tenant, lifecycle, and identity scope'
);

update argus_private.kill_switches set enabled=false,reason=null
 where name='background_workers';
set local role argus_worker;
select is(argus_private.relay_outbox(25),1,'one due event relays through the queue adapter');
create temporary table queue_contract_claim on commit drop as
select * from argus_private.claim_next_argus_job(45);
grant select on queue_contract_claim to argus_jobs_owner;
select is(
  (select count(*)::bigint from queue_contract_claim
    where event_id='aaaaaaaa-7000-4000-8000-000000000001'),
  1::bigint,
  'opaque delivery resolves to one leased registered job'
);
select argus_private.set_worker_event_context(event_id,job_run_id,lease_token)
  from queue_contract_claim;
select argus_private.complete_argus_job(
  (select job_run_id from queue_contract_claim),
  (select lease_token from queue_contract_claim),repeat('a',64)
);
reset role;
set local role argus_jobs_owner;
select ok(
  not exists(select 1 from pgmq.q_argus_jobs
    where message->>'event_id'='aaaaaaaa-7000-4000-8000-000000000001')
  and exists(select 1 from pgmq.a_argus_jobs
    where message=jsonb_build_object(
      'version',1,'event_id','aaaaaaaa-7000-4000-8000-000000000001'
    )),
  'success archives exactly the opaque versioned envelope'
);
select ok(
  exists(select 1 from argus_private.consumer_receipts receipt
    where receipt.outbox_event_id='aaaaaaaa-7000-4000-8000-000000000001'
      and receipt.effect_hash=repeat('a',64)),
  'success commits one immutable consumer receipt'
);
reset role;
set local role argus_worker;
select is(argus_private.relay_outbox(25),0,'published outbox replay emits no duplicate message');
reset role;

set local role argus_jobs_owner;
select pgmq.send(
  'argus_jobs',
  '{"version":2,"event_id":"aaaaaaaa-7000-4000-8000-000000000099","email":"canary@example.test","credential":"canary-secret"}'::jsonb
);
reset role;
set local role argus_worker;
select is(
  (select count(*)::bigint from argus_private.claim_next_argus_job(45)),
  0::bigint,
  'poison delivery is terminalized without becoming work'
);
reset role;
set local role argus_jobs_owner;
select ok(
  not exists(select 1 from pgmq.q_argus_jobs
    where message::text like '%canary@example.test%'),
  'poison payload is removed from the live queue'
);
select ok(
  not exists(select 1 from pgmq.a_argus_jobs
    where message::text~* 'canary@example\.test|canary-secret'),
  'poison identity and credential content never enter the archive'
);
select ok(
  exists(select 1 from argus_private.dead_letter_events
    where reason_code='invalid_event_payload')
  and not exists(select 1 from argus_private.dead_letter_events
    where row_to_json(dead_letter_events)::text~* 'canary|email|credential'),
  'poison handling records only a redacted dead-letter fact'
);

insert into argus_private.outbox_events(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,topic,event_type,event_version,
  aggregate_id,dedupe_key
) select
  'aaaaaaaa-7000-4000-8000-000000000002',member.tenant_id,member.lifecycle_id,
  member.user_id,member.deletion_epoch,'argus_jobs','content-report.created',1,
  'aaaaaaaa-6000-4000-8000-000000000002','queue-contract-u6-0002'
from argus_app.members member
where member.user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
reset role;
set local role argus_worker;
select is(argus_private.relay_outbox(25),1,'recovery fixture relays exactly once');
create temporary table queue_recovery_claim on commit drop as
select * from argus_private.claim_next_argus_job(45);
grant select on queue_recovery_claim to argus_jobs_owner;
reset role;
set local role argus_jobs_owner;
update argus_private.job_runs set max_attempts=1,
  leased_until=pg_catalog.clock_timestamp()-interval '1 second'
 where id=(select job_run_id from queue_recovery_claim);
reset role;
set local role argus_worker;
select is(argus_private.recover_expired_work(25),1,'expired final attempt recovers once');
reset role;
set local role argus_jobs_owner;
select ok(
  exists(select 1 from argus_private.job_runs run
    join argus_private.job_attempts attempt on attempt.job_run_id=run.id
    where run.id=(select job_run_id from queue_recovery_claim)
      and run.status='dead_lettered' and attempt.outcome='dead_lettered'
      and attempt.failure_code='lease_expired')
  and exists(select 1 from argus_private.dead_letter_events
    where outbox_event_id='aaaaaaaa-7000-4000-8000-000000000002'
      and reason_code='lease_expired'),
  'terminal lease recovery converges the run, attempt, and redacted DLQ fact'
);
select ok(
  not exists(select 1 from pgmq.q_argus_jobs
    where message->>'event_id'='aaaaaaaa-7000-4000-8000-000000000002')
  and not exists(select 1 from pgmq.a_argus_jobs
    where message->>'event_id'='aaaaaaaa-7000-4000-8000-000000000002'),
  'terminal recovery deletes the opaque delivery after recording the redacted DLQ fact'
);
reset role;

select is(
  argus_private.retained_job_handler('recurring-plan-delivery'),null,
  'recurring financial delivery has no retained handler'
);
update argus_private.kill_switches set enabled=true,reason='pgTAP deployment fence'
 where name='background_workers';
select argus_private.invoke_worker();
select is(
  (select count(*)::bigint from net.http_request_queue),0::bigint,
  'background fence prevents worker network egress on a clean deployment'
);

select * from finish();
rollback;

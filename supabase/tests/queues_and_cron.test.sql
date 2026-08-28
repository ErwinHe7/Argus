begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, pg_catalog, public;

select plan(16);

select has_extension('pgmq', 'Supabase Queues extension is enabled');
select has_extension('pg_cron', 'Supabase Cron extension is enabled');
select has_table('pgmq', 'q_argus_jobs', 'logged Argus job queue exists');
select has_table('pgmq', 'a_argus_jobs', 'Argus job archive exists');
select has_table('pgmq', 'q_brokerage_refresh', 'logged brokerage refresh queue exists');
select has_table('pgmq', 'q_brokerage_reconcile', 'logged brokerage reconciliation queue exists');
select hasnt_schema('pgmq_public', 'queues are not exposed through the Data API wrapper schema');
select ok(not has_schema_privilege('anon', 'pgmq', 'usage'), 'anon has no queue schema usage');
select ok(not has_schema_privilege('authenticated', 'pgmq', 'usage'), 'authenticated has no queue schema usage');
select ok(has_schema_privilege('argus_worker', 'pgmq', 'usage'), 'worker can use private queues');

select is(
  (select count(*)::bigint from cron.job where jobname in ('argus-outbox-relay','argus-recovery-sweep')),
  2::bigint,
  'outbox relay and recovery sweep are declared in migrations'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'queue@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
);
insert into argus_app.members (user_id) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');

savepoint domain_tx;
insert into argus_app.notifications (id, user_id, deletion_epoch, kind, title, body)
values ('aaaaaaaa-6000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0, 'ritual', 'Title', 'Body');
insert into argus_private.outbox_events (
  id, user_id, deletion_epoch, topic, event_type, aggregate_id, dedupe_key
) values (
  'aaaaaaaa-7000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0,
  'argus_jobs', 'notification.created', 'aaaaaaaa-6000-4000-8000-000000000001', 'notification:1'
);
rollback to domain_tx;
select is(
  (select count(*)::bigint from argus_private.outbox_events where id = 'aaaaaaaa-7000-4000-8000-000000000001'),
  0::bigint,
  'rolled-back domain transaction leaves no orphaned outbox event'
);

insert into argus_private.outbox_events (
  id, user_id, deletion_epoch, topic, event_type, aggregate_id, dedupe_key
) values (
  'aaaaaaaa-7000-4000-8000-000000000002', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0,
  'argus_jobs', 'notification.created', 'aaaaaaaa-6000-4000-8000-000000000002', 'notification:2'
);
select is(argus_private.relay_outbox(10), 1, 'relay publishes one due outbox event');
select is(
  (select count(*)::bigint from pgmq.q_argus_jobs where message ? 'event_id'),
  1::bigint,
  'relay publishes an opaque versioned queue message'
);
select is(
  (select count(*)::bigint
     from pgmq.q_argus_jobs q,
          lateral jsonb_object_keys(q.message) k
    where k not in ('version','event_id','event_type')),
  0::bigint,
  'queue payload contains only allowlisted opaque keys'
);
select ok(
  exists (select 1 from argus_private.outbox_events where id = 'aaaaaaaa-7000-4000-8000-000000000002' and published_at is not null),
  'relay records publication after pgmq send'
);

select * from finish();
rollback;

begin;

-- PostgreSQL 17 gives a non-superuser role creator ADMIN but not SET on
-- newly created roles. Enable role switching only for this test transaction;
-- the final rollback restores the hosted membership options.
grant argus_runtime, argus_worker, argus_waitlist
  to current_user with set true;
grant usage on schema extensions
  to argus_runtime, argus_worker, argus_waitlist;

create extension if not exists pgtap with schema extensions;
grant usage on schema extensions to argus_runtime;
set local search_path = extensions, pg_catalog, public;

select plan(21);

select has_column('argus_app', 'future_mirror_points', 'low_amount_minor', 'Future Mirror stores an exact low band');
select has_column('argus_app', 'future_mirror_points', 'mid_amount_minor', 'Future Mirror stores an exact middle band');
select has_column('argus_app', 'future_mirror_points', 'high_amount_minor', 'Future Mirror stores an exact high band');
select has_column('argus_app', 'future_mirror_runs', 'assumption_version', 'reviewed assumption version is explicit');
select has_column('argus_app', 'future_mirror_runs', 'uncertainty_disclosure', 'hypothetical uncertainty disclosure is durable');
select has_index('argus_app', 'future_mirror_runs', 'future_mirror_runs_exact_input_unique', 'exact scenario input converges to one model run');

select is(
  (select count(*)::bigint
     from information_schema.role_table_grants
    where grantee in ('anon','authenticated')
      and table_schema = 'argus_app'
      and table_name in ('intentions','future_mirror_runs','future_mirror_points')),
  0::bigint,
  'client roles cannot bypass the retained Edge contract'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '91919191-9191-4191-8191-919191919191', 'authenticated', 'authenticated', 'scenario-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '92929292-9292-4292-8292-929292929292', 'authenticated', 'authenticated', 'scenario-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into argus_app.intentions (
  id, user_id, deletion_epoch, title, target_amount_minor, currency,
  target_date, status
) values (
  '91919191-1000-4000-8000-000000000001',
  '91919191-9191-4191-8191-919191919191', 0,
  'A member-entered intention', 250000, 'USD', '2028-08-28', 'active'
);

insert into argus_app.future_mirror_runs (
  id, user_id, deletion_epoch, intention_id, input_hash, model_version,
  assumption_version, assumptions, status, completed_at
) values (
  '91919191-2000-4000-8000-000000000001',
  '91919191-9191-4191-8191-919191919191', 0,
  '91919191-1000-4000-8000-000000000001', repeat('a',64),
  'argus-hypothetical-v1', 'member-reviewed-v1',
  '{"input":{"name":"Steady path","baseline":{"minor_units":"100000","currency":"USD"},"monthly_contribution":{"minor_units":"1000","currency":"USD"},"annual_return_bps":{"low":-1000,"mid":400,"high":1800},"as_of_date":"2026-08-28"},"intention_snapshot":{"target_date":"2028-08-28","currency":"USD"}}',
  'completed', now()
);

insert into argus_app.future_mirror_points (
  run_id, user_id, deletion_epoch, ordinal, projected_date,
  low_amount_minor, mid_amount_minor, high_amount_minor
) values (
  '91919191-2000-4000-8000-000000000001',
  '91919191-9191-4191-8191-919191919191', 0, 1, '2026-09-28',
  99900, 100400, 101800
);

set local role argus_runtime;
do $$ begin
  perform argus_private.set_request_context(
    '91919191-9191-4191-8191-919191919191',
    '91919191-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;
select is((select count(*)::bigint from argus_app.intentions), 1::bigint, 'owner reads their intention');
select is((select count(*)::bigint from argus_app.future_mirror_runs), 1::bigint, 'owner reads their hypothetical run');
select is((select count(*)::bigint from argus_app.future_mirror_points), 1::bigint, 'owner reads their exact projection points');

do $$ begin
  perform argus_private.set_request_context(
    '92929292-9292-4292-8292-929292929292',
    '92929292-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;
select is((select count(*)::bigint from argus_app.intentions), 0::bigint, 'another member cannot read the intention');
select is((select count(*)::bigint from argus_app.future_mirror_runs), 0::bigint, 'another member cannot read the run');
select is((select count(*)::bigint from argus_app.future_mirror_points), 0::bigint, 'another member cannot read projection points');
reset role;

select throws_ok(
  $$insert into argus_app.future_mirror_points(
      run_id,user_id,deletion_epoch,ordinal,projected_date,
      low_amount_minor,mid_amount_minor,high_amount_minor
    ) values (
      '91919191-2000-4000-8000-000000000001',
      '91919191-9191-4191-8191-919191919191',0,2,'2026-10-28',
      101,100,102
    )$$,
  '23514',
  null,
  'unordered exact bands fail closed'
);

select throws_ok(
  $$insert into argus_app.future_mirror_runs(
      id,user_id,deletion_epoch,intention_id,input_hash,model_version,
      assumptions,status,completed_at
    ) values (
      '91919191-2000-4000-8000-000000000002',
      '91919191-9191-4191-8191-919191919191',0,
      '91919191-1000-4000-8000-000000000001',repeat('a',64),
      'argus-hypothetical-v1','{}','completed',now()
    )$$,
  '23505',
  null,
  'duplicate exact input and model cannot create another run'
);

update argus_app.members
   set status = 'deletion_pending', deletion_epoch = deletion_epoch + 1,
       deletion_requested_at = now()
 where user_id = '91919191-9191-4191-8191-919191919191';

set local role argus_runtime;
do $$ begin
  perform argus_private.set_request_context(
    '91919191-9191-4191-8191-919191919191',
    '91919191-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;
select is((select count(*)::bigint from argus_app.intentions), 0::bigint, 'deletion fencing hides stale intentions');
select is((select count(*)::bigint from argus_app.future_mirror_runs), 0::bigint, 'deletion fencing hides stale hypothetical runs');
select is((select count(*)::bigint from argus_app.future_mirror_points), 0::bigint, 'deletion fencing hides stale projection points');
select throws_ok(
  $$insert into argus_app.intentions(
      id,user_id,deletion_epoch,title,target_amount_minor,currency,target_date
    ) values (
      '91919191-1000-4000-8000-000000000002',
      '91919191-9191-4191-8191-919191919191',0,
      'Late write',100,'USD','2028-08-28'
    )$$,
  '28000',
  'inactive_member_lifecycle',
  'deletion fencing rejects a late scenario write'
);
reset role;

select is(
  (select count(*)::bigint
     from information_schema.columns
    where table_schema = 'argus_app'
      and table_name in ('intentions','future_mirror_runs','future_mirror_points')
      and column_name ~ '(brokerage|balance|position|order|provider|credential|command|portfolio|ledger)'),
  0::bigint,
  'scenario persistence contains no brokerage or command fields'
);

select is(
  (select count(*)::bigint
     from pg_class relation
     join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'argus_app'
      and relation.relname in ('intentions','future_mirror_runs','future_mirror_points')
      and relation.relrowsecurity and relation.relforcerowsecurity),
  3::bigint,
  'all scenario tables keep forced RLS defense in depth'
);

select * from finish();
rollback;

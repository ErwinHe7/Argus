begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, pg_catalog, public;

select plan(26);

select has_role('argus_waitlist', 'dedicated waitlist capability role exists');
select has_role('argus_waitlist_edge', 'dedicated waitlist Edge login exists');
select ok(
  exists (
    select 1 from pg_roles where rolname = 'argus_waitlist'
      and not rolcanlogin and not rolinherit and not rolsuper
      and not rolcreatedb and not rolcreaterole and not rolbypassrls
  ),
  'waitlist capability cannot log in, inherit, administer, or bypass RLS'
);
select ok(
  exists (
    select 1 from pg_roles where rolname = 'argus_waitlist_edge'
      and rolcanlogin and not rolinherit and not rolsuper
      and not rolcreatedb and not rolcreaterole and not rolbypassrls
  ),
  'waitlist login cannot inherit, administer, or bypass RLS'
);
select ok(
  pg_has_role('argus_waitlist_edge', 'argus_waitlist', 'member')
  and not pg_has_role('argus_waitlist_edge', 'argus_runtime', 'member')
  and not pg_has_role('argus_waitlist_edge', 'argus_worker', 'member'),
  'waitlist login has only the dedicated capability membership'
);
select ok(
  has_schema_privilege('argus_waitlist', 'argus_private', 'usage')
  and not has_schema_privilege('argus_waitlist', 'argus_app', 'usage')
  and not has_schema_privilege('argus_waitlist', 'argus_brokerage', 'usage'),
  'waitlist capability can enter only the private capability schema'
);
select ok(
  has_table_privilege('argus_waitlist', 'argus_private.gateway_rate_limits', 'select')
  and has_table_privilege('argus_waitlist', 'argus_private.gateway_rate_limits', 'insert')
  and has_table_privilege('argus_waitlist', 'argus_private.gateway_rate_limits', 'update')
  and not has_table_privilege('argus_waitlist', 'argus_private.gateway_rate_limits', 'delete'),
  'waitlist capability has only the pseudonymous rate-window operations'
);
select ok(
  not has_table_privilege('argus_waitlist', 'argus_app.members', 'select')
  and not has_table_privilege('argus_waitlist', 'argus_brokerage.connections', 'select')
  and not has_table_privilege('argus_waitlist', 'argus_private.staff_principals', 'select')
  and not has_function_privilege(
    'argus_waitlist',
    'argus_private.set_request_context(uuid,uuid,text)',
    'execute'
  ),
  'waitlist capability cannot read member, brokerage, or admin state or install member claims'
);

select has_table(
  'argus_private', 'waitlist_submissions',
  'waitlist state is held in the private Supabase schema'
);
select ok(
  (select relrowsecurity and relforcerowsecurity
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'argus_private'
      and c.relname = 'waitlist_submissions'),
  'waitlist state enables and forces RLS'
);
select ok(
  not has_table_privilege('anon', 'argus_private.waitlist_submissions', 'select')
  and not has_table_privilege('authenticated', 'argus_private.waitlist_submissions', 'select')
  and not has_table_privilege('argus_waitlist', 'argus_private.waitlist_submissions', 'select'),
  'browser, member, and Edge capability roles cannot enumerate waitlist rows'
);
select ok(
  not has_table_privilege('argus_waitlist', 'argus_private.waitlist_submissions', 'insert')
  and not has_table_privilege('argus_waitlist', 'argus_private.waitlist_submissions', 'update')
  and not has_table_privilege('argus_waitlist', 'argus_private.waitlist_submissions', 'delete'),
  'Edge runtime cannot mutate waitlist state directly'
);
select ok(
  has_function_privilege(
    'argus_waitlist', 'argus_private.submit_waitlist(text,text)', 'execute'
  ) and not has_function_privilege(
    'argus_runtime', 'argus_private.submit_waitlist(text,text)', 'execute'
  ),
  'only the dedicated waitlist capability receives submission execution'
);
select ok(
  not has_function_privilege(
    'anon', 'argus_private.submit_waitlist(text,text)', 'execute'
  ) and not has_function_privilege(
    'authenticated', 'argus_private.submit_waitlist(text,text)', 'execute'
  ),
  'Data API roles cannot call the submission capability'
);
select ok(
  not has_function_privilege(
    'argus_waitlist',
    'argus_private.purge_expired_waitlist_submissions()',
    'execute'
  ),
  'Edge runtime cannot invoke retention maintenance'
);
select has_function(
  'argus_private', 'remove_waitlist_submission', array['text'],
  'mailbox-verified deletion has a bounded owner-only capability'
);
select ok(
  not has_function_privilege(
    'argus_waitlist', 'argus_private.remove_waitlist_submission(text)', 'execute'
  ) and not has_function_privilege(
    'authenticated', 'argus_private.remove_waitlist_submission(text)', 'execute'
  ),
  'browser and Edge runtime cannot invoke mailbox-verified deletion'
);

set local role argus_waitlist;
select lives_ok(
  $$select argus_private.submit_waitlist(
    'person.name+one@example.com', 'waitlist-v1-2026-08-25'
  )$$,
  'the bounded capability accepts an exact normalized consent record'
);
select lives_ok(
  $$select argus_private.submit_waitlist(
    'person.name+one@example.com', 'waitlist-v2-2027-01-01'
  )$$,
  'a duplicate receives the same generic database outcome'
);
select throws_ok(
  $$select argus_private.submit_waitlist(
    ' Person.Name+one@example.com ', 'waitlist-v1-2026-08-25'
  )$$,
  '22023', 'invalid_waitlist_submission',
  'the database rejects non-normalized input at its trust boundary'
);
select throws_ok(
  $$select argus_private.submit_waitlist(
    'other@example.com', 'future-notice'
  )$$,
  '22023', 'invalid_waitlist_submission',
  'the database rejects an unversioned consent record'
);
reset role;

select is(
  (select count(*)::bigint from argus_private.waitlist_submissions),
  1::bigint,
  'a duplicate does not create an enumerating second row'
);
select is(
  (select notice_version from argus_private.waitlist_submissions),
  'waitlist-v1-2026-08-25',
  'a duplicate cannot rewrite the immutable reviewed notice'
);
select is(
  (select count(*)::bigint from cron.job
    where jobname = 'argus-waitlist-retention'
      and schedule = '17 4 * * *'),
  1::bigint,
  'Supabase Cron owns the one daily waitlist retention tick'
);
select ok(
  (select command from cron.job where jobname = 'argus-waitlist-retention')
    = 'select argus_private.purge_expired_waitlist_submissions();',
  'the retention tick calls only the bounded database-owned purge'
);
select ok(
  (select command from cron.job where jobname = 'argus-waitlist-retention')
    !~* 'email|secret|token|http|net\.',
  'the Cron definition contains no email, credential, or egress surface'
);

select * from finish();
rollback;

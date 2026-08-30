begin;

-- PostgreSQL 17 preserves installer-created ADMIN-only memberships without
-- SET. This rollback-only grant enables exact role black-box checks and leaves
-- the persistent membership graph unchanged.
do $membership$ begin
  execute pg_catalog.format(
    'grant argus_jobs_owner to %I with set true',current_user
  );
end $membership$;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(14);

select has_role(
  'argus_application_purge_owner',
  'application purge has a dedicated capability owner'
);
select ok(
  (select not rolcanlogin and not rolinherit and not rolsuper
          and not rolcreatedb and not rolcreaterole and not rolreplication
          and not rolbypassrls
     from pg_roles where rolname='argus_application_purge_owner'),
  'application purge owner is NOLOGIN, NOINHERIT, and non-BYPASSRLS'
);
select set_eq(
  $$select namespace.nspname||':'||privilege.privilege_type
      from pg_namespace namespace
      cross join lateral aclexplode(namespace.nspacl) privilege
     where privilege.grantee='argus_application_purge_owner'::regrole$$,
  $$values ('argus_app:USAGE'),('argus_private:USAGE')$$,
  'application purge owner has exact schema usage and no creation capability'
);
select ok(
  (select pg_get_userbyid(routine.proowner)='argus_application_purge_owner'
          and routine.prosecdef
     from pg_proc routine
    where routine.oid=
      'argus_private.purge_member_application_data(uuid)'::regprocedure),
  'application purge port is a definer owned by the dedicated owner'
);
select set_eq(
  $$select grantee.rolname||':'||privilege.privilege_type
      from pg_proc routine
      cross join lateral aclexplode(
        coalesce(routine.proacl,acldefault('f',routine.proowner))
      ) privilege
      join pg_roles grantee on grantee.oid=privilege.grantee
     where routine.oid=
       'argus_private.purge_member_application_data(uuid)'::regprocedure$$,
  $$values ('argus_application_purge_owner:EXECUTE'),
    ('argus_jobs_owner:EXECUTE')$$,
  'only the NOLOGIN owner and jobs orchestration can execute application purge'
);
select is(
  (select count(*)::bigint
     from pg_policy policy
    where 'argus_app_owner'::regrole=any(policy.polroles)
      and policy.polname in (
        'u6_app_owner_tombstone_purge_read',
        'u6_app_owner_purge_delete','u6_app_owner_purge_read',
        'u6_app_owner_idempotency_purge_delete',
        'u6_app_owner_idempotency_purge_read'
      )),
  0::bigint,
  'U6 application-owner purge policies are retired'
);
select ok(
  not has_table_privilege(
    'argus_app_owner','argus_private.deletion_tombstones','SELECT'
  ) and has_table_privilege(
    'argus_app_owner','argus_private.member_idempotency_records','SELECT,INSERT,UPDATE'
  ) and not has_table_privilege(
    'argus_app_owner','argus_private.member_idempotency_records','DELETE'
  ),
  'application owner has scoped command receipts but no private purge grant'
);
select set_eq(
  $$select relation.relname||':'||privilege.privilege_type
     from pg_class relation
     join pg_namespace namespace on namespace.oid=relation.relnamespace
     cross join lateral aclexplode(relation.relacl) privilege
    where namespace.nspname='argus_app'
      and relation.relname=any(array[
        'moderation_cases','content_report_targets','content_reports',
        'media_assets','briefing_read_states','briefing_sections','briefings',
        'future_mirror_points','future_mirror_runs','intentions',
        'circle_assets','circles','onboarding_step_completions',
        'onboarding_states','notification_quiet_hours',
        'notification_preferences','notifications','member_saved_items',
        'saved_items','daily_ritual_assignments','consent_records',
        'investor_profiles','astrology_profiles','preferences','profiles',
        'privacy_requests'
      ])
      and relation.relowner<>'argus_app_owner'::regrole
      and privilege.grantee='argus_app_owner'::regrole
      and privilege.privilege_type in ('SELECT','DELETE')$$,
  $$values ('daily_ritual_assignments:SELECT'),('circles:SELECT'),
    ('saved_items:SELECT'),('saved_items:DELETE'),
    ('content_reports:SELECT')$$,
  'application owner retains only its pre-U6 command dependencies'
);
select set_eq(
  $$with expected_relations(schema_name,relation_name) as (
      values ('argus_private','deletion_tombstones')
      union all
      select 'argus_private','member_idempotency_records'
      union all
      select 'argus_app',relation_name
        from unnest(array[
          'moderation_cases','content_report_targets','content_reports',
          'media_assets','briefing_read_states','briefing_sections','briefings',
          'future_mirror_points','future_mirror_runs','intentions',
          'circle_assets','circles','onboarding_step_completions',
          'onboarding_states','notification_quiet_hours',
          'notification_preferences','notifications','member_saved_items',
          'saved_items','daily_ritual_assignments','consent_records',
          'investor_profiles','astrology_profiles','preferences','profiles',
          'privacy_requests','starpath_attempts','starpath_recall_states',
          'starpath_lesson_completions','starpath_progress_states',
          'starpath_sessions'
        ]) relation_name
    )
    select namespace.nspname||'.'||relation.relname||':'||policy.polcmd::text
      from pg_policy policy
      join pg_class relation on relation.oid=policy.polrelid
      join pg_namespace namespace on namespace.oid=relation.relnamespace
      join expected_relations expected
        on expected.schema_name=namespace.nspname
       and expected.relation_name=relation.relname
     where 'argus_application_purge_owner'::regrole=any(policy.polroles)$$,
  $$select 'argus_private.deletion_tombstones:r'
    union all
    select 'argus_private.member_idempotency_records:'||command
      from (values ('r'),('d')) action(command)
    union all
    select 'argus_app.'||relation_name||':'||command
      from unnest(array[
        'moderation_cases','content_report_targets','content_reports',
        'media_assets','briefing_read_states','briefing_sections','briefings',
        'future_mirror_points','future_mirror_runs','intentions',
        'circle_assets','circles','onboarding_step_completions',
        'onboarding_states','notification_quiet_hours',
        'notification_preferences','notifications','member_saved_items',
        'saved_items','daily_ritual_assignments','consent_records',
        'investor_profiles','astrology_profiles','preferences','profiles',
        'privacy_requests','starpath_attempts','starpath_recall_states',
        'starpath_lesson_completions','starpath_progress_states',
        'starpath_sessions'
      ]) relation_name
      cross join (values ('r'),('d')) action(command)$$,
  'application purge owner has one exact SELECT/DELETE policy matrix'
);
select ok(
  (select policy.polcmd='r'
          and pg_get_expr(policy.polqual,policy.polrelid)
                like '%status = ''purging''::text%'
          and pg_get_expr(policy.polqual,policy.polrelid)
                like '%purge_phase = ''storage_purged''::text%'
          and pg_get_expr(policy.polqual,policy.polrelid)<>'true'
     from pg_policy policy
    where policy.polrelid='argus_private.deletion_tombstones'::regclass
      and policy.polname='u6_application_purge_tombstone_read'
      and 'argus_application_purge_owner'::regrole=any(policy.polroles)),
  'purge owner can see only an eligible purging/storage-purged tombstone'
);
select set_eq(
  $$select namespace.nspname||'.'||relation.relname||':'||privilege.privilege_type
      from pg_class relation
      join pg_namespace namespace on namespace.oid=relation.relnamespace
      cross join lateral aclexplode(relation.relacl) privilege
     where privilege.grantee='argus_application_purge_owner'::regrole$$,
  $$select 'argus_private.deletion_tombstones:SELECT'
    union all
    select 'argus_private.member_idempotency_records:'||privilege_type
      from (values ('SELECT'),('DELETE')) action(privilege_type)
    union all
    select 'argus_app.'||relation_name||':'||privilege_type
      from unnest(array[
        'moderation_cases','content_report_targets','content_reports',
        'media_assets','briefing_read_states','briefing_sections','briefings',
        'future_mirror_points','future_mirror_runs','intentions',
        'circle_assets','circles','onboarding_step_completions',
        'onboarding_states','notification_quiet_hours',
        'notification_preferences','notifications','member_saved_items',
        'saved_items','daily_ritual_assignments','consent_records',
        'investor_profiles','astrology_profiles','preferences','profiles',
        'privacy_requests','starpath_attempts','starpath_recall_states',
        'starpath_lesson_completions','starpath_progress_states',
        'starpath_sessions'
      ]) relation_name
      cross join (values ('SELECT'),('DELETE')) action(privilege_type)$$,
  'application purge owner has the exact supporting relation privileges'
);
select is(
  (with policy_expressions as (
     select lower(regexp_replace(expression.expression_text,'[[:space:]]+',' ','g'))
              as expression_text
       from pg_policy policy
       cross join lateral unnest(array[
         pg_get_expr(policy.polqual,policy.polrelid),
         pg_get_expr(policy.polwithcheck,policy.polrelid)
       ]) expression(expression_text)
      where policy.polname='runtime_staff_step_up_owner'
        and expression.expression_text is not null
   )
   select count(*)::bigint from policy_expressions
    where regexp_count(expression_text,'argus_private\.request_user_id\(')
          <>regexp_count(
               expression_text,'select argus_private\.request_user_id\('
             )
       or regexp_count(expression_text,'argus_private\.has_staff_permission\(')
          <>regexp_count(
               expression_text,
               'select argus_private\.has_staff_permission\('
             )
       or regexp_count(expression_text,'pg_catalog\.current_setting\(')
          <>regexp_count(
               expression_text,
               'select pg_catalog\.current_setting\('
             )),
  0::bigint,
  'staff step-up policy helpers are scalar SELECT initplans'
);
select is(
  (select count(*)::bigint
     from pg_auth_members membership
    where membership.member='argus_application_purge_owner'::regrole
       or (
         membership.roleid='argus_application_purge_owner'::regrole
         and (membership.set_option or membership.inherit_option)
       )),
  0::bigint,
  'application purge owner has no usable membership or migration residue'
);

set local role argus_jobs_owner;
select throws_ok(
  $$select argus_private.purge_member_application_data(
      '00000000-0000-4000-8000-000000000000'
    )$$,
  '23514','application_purge_scope_invalid',
  'jobs orchestration cannot purge without the exact eligible tombstone'
);
reset role;

select * from finish();
rollback;

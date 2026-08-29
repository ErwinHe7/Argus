-- Follow-up to U6: isolate application-data purge authority from the normal
-- application domain owner and make the retained staff step-up policy
-- initplan-safe without changing its authorization semantics.

begin;

do $$
begin
  if not exists (
    select 1
      from pg_catalog.pg_roles
     where rolname='argus_application_purge_owner'
  ) then
    create role argus_application_purge_owner
      nologin noinherit nosuperuser nocreatedb nocreaterole
      noreplication nobypassrls;
  elsif exists (
    select 1
      from pg_catalog.pg_roles role
     where role.rolname='argus_application_purge_owner'
       and (
         role.rolcanlogin or role.rolinherit or role.rolsuper
         or role.rolcreatedb or role.rolcreaterole or role.rolreplication
         or role.rolbypassrls
       )
  ) then
    raise exception 'argus_application_purge_owner_attribute_drift'
      using errcode='42501';
  end if;
end
$$;

-- Policy DDL on application-owned relations and the function ownership
-- transfer require narrowly scoped authority during replay. Grantor-scoped
-- revocation preserves any installer-managed membership rows.
do $membership$
begin
  execute pg_catalog.format(
    'grant argus_app_owner,argus_application_purge_owner to %1$I with inherit true,set true,admin false granted by %1$I',
    current_user
  );
end
$membership$;

grant usage on schema argus_app,argus_private
  to argus_application_purge_owner;

drop policy if exists u6_app_owner_tombstone_purge_read
  on argus_private.deletion_tombstones;

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'moderation_cases','content_report_targets','content_reports',
    'media_assets',
    'briefing_read_states','briefing_sections','briefings',
    'future_mirror_points','future_mirror_runs','intentions',
    'circle_assets','circles','onboarding_step_completions','onboarding_states',
    'notification_quiet_hours','notification_preferences','notifications',
    'member_saved_items','saved_items','daily_ritual_assignments','consent_records',
    'investor_profiles','astrology_profiles','preferences','profiles','privacy_requests'
  ] loop
    execute pg_catalog.format(
      'drop policy if exists u6_app_owner_purge_delete on argus_app.%I',
      relation_name
    );
    execute pg_catalog.format(
      'drop policy if exists u6_app_owner_purge_read on argus_app.%I',
      relation_name
    );
    -- Self-ACLs on application-owned relations are part of domain ownership,
    -- not a separable purge grant. For retained postgres-owned relations,
    -- remove the merged U4/U6 ACL and restore U4's exact dependencies below.
    if exists (
      select 1
        from pg_catalog.pg_class relation
        join pg_catalog.pg_namespace namespace
          on namespace.oid=relation.relnamespace
       where namespace.nspname='argus_app'
         and relation.relname=relation_name
         and relation.relowner<>'argus_app_owner'::regrole
    ) then
      execute pg_catalog.format(
        'revoke select,delete on argus_app.%I from argus_app_owner',
        relation_name
      );
    end if;
  end loop;
end
$$;

-- Restore only the pre-U6 U4 command dependencies that share relations with
-- the application purge inventory. No ordinary application command receives
-- a new action through this follow-up.
grant select on
  argus_app.daily_ritual_assignments,argus_app.circles,
  argus_app.saved_items,argus_app.content_reports
to argus_app_owner;
grant delete on argus_app.saved_items to argus_app_owner;

drop policy if exists u6_app_owner_idempotency_purge_delete
  on argus_private.member_idempotency_records;
drop policy if exists u6_app_owner_idempotency_purge_read
  on argus_private.member_idempotency_records;

-- These were the only U6 purge grants on private relations. The application
-- owner remains the owner of its own domain relations, so its intrinsic table
-- privileges cannot (and need not) be represented as a purge capability.
revoke select on argus_private.deletion_tombstones from argus_app_owner;
revoke select,delete on argus_private.member_idempotency_records
  from argus_app_owner;

create policy u6_application_purge_tombstone_read
  on argus_private.deletion_tombstones
  for select to argus_application_purge_owner
  using (status='purging' and purge_phase='storage_purged');
grant select on argus_private.deletion_tombstones
  to argus_application_purge_owner;

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'moderation_cases','content_report_targets','content_reports',
    'media_assets',
    'briefing_read_states','briefing_sections','briefings',
    'future_mirror_points','future_mirror_runs','intentions',
    'circle_assets','circles','onboarding_step_completions','onboarding_states',
    'notification_quiet_hours','notification_preferences','notifications',
    'member_saved_items','saved_items','daily_ritual_assignments','consent_records',
    'investor_profiles','astrology_profiles','preferences','profiles','privacy_requests'
  ] loop
    execute pg_catalog.format(
      'create policy u6_application_purge_delete on argus_app.%I for delete to argus_application_purge_owner using (true)',
      relation_name
    );
    execute pg_catalog.format(
      'create policy u6_application_purge_read on argus_app.%I for select to argus_application_purge_owner using (true)',
      relation_name
    );
    execute pg_catalog.format(
      'grant select,delete on argus_app.%I to argus_application_purge_owner',
      relation_name
    );
  end loop;
end
$$;

create policy u6_application_purge_idempotency_delete
  on argus_private.member_idempotency_records
  for delete to argus_application_purge_owner
  using (true);
create policy u6_application_purge_idempotency_read
  on argus_private.member_idempotency_records
  for select to argus_application_purge_owner
  using (true);
grant select,delete on argus_private.member_idempotency_records
  to argus_application_purge_owner;

-- PostgreSQL requires the target owner to have CREATE on the containing
-- schema during ownership transfer. Remove it immediately afterward.
grant create on schema argus_private to argus_application_purge_owner;
alter function argus_private.purge_member_application_data(uuid)
  owner to argus_application_purge_owner;
revoke create on schema argus_private from argus_application_purge_owner;

revoke all on function argus_private.purge_member_application_data(uuid)
  from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
       argus_callback,argus_worker,postgres,argus_app_owner;
grant execute on function argus_private.purge_member_application_data(uuid)
  to argus_application_purge_owner,argus_jobs_owner;

comment on role argus_application_purge_owner is
  'NOLOGIN application-purge owner; usable only through the tombstone-scoped privacy purge port.';
comment on function argus_private.purge_member_application_data(uuid) is
  'Deletes the fixed application-data inventory only for a purging/storage-purged tombstone; callable only by jobs orchestration.';

-- Keep the legacy argus_runtime surface and action-specific authorization
-- intact. Scalar subqueries make each row-independent helper an initPlan.
drop policy if exists runtime_staff_step_up_owner
  on argus_private.staff_step_up_receipts;
create policy runtime_staff_step_up_owner
  on argus_private.staff_step_up_receipts for all to argus_runtime
  using (
    user_id=(select argus_private.request_user_id())
    and case action
          when 'admin_job_retry' then
            (select argus_private.has_staff_permission('operations:write'))
          when 'admin_privacy_retry' then
            (select argus_private.has_staff_permission('privacy:write'))
          else false
        end
  )
  with check (
    user_id=(select argus_private.request_user_id())
    and case action
          when 'admin_job_retry' then
            (select argus_private.has_staff_permission('operations:write'))
          when 'admin_privacy_retry' then
            (select argus_private.has_staff_permission('privacy:write'))
          else false
        end
    and (select pg_catalog.current_setting('request.jwt.claims',true))::jsonb
          ->>'aal'='aal2'
  );

do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_app_owner,argus_application_purge_owner from %1$I granted by %1$I',
    current_user
  );
end
$membership$;

commit;

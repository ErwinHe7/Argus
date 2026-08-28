alter table argus_app.daily_ritual_assignments
  add column version integer not null default 1 check (version > 0);

create or replace function argus_private.provision_argus_member()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, auth, argus_private
as $$
begin
  insert into argus_app.members (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into argus_app.profiles (
    user_id, deletion_epoch, display_name, locale
  ) values (
    new.id, 0, 'Argus member', 'en-US'
  ) on conflict (user_id) do nothing;

  insert into argus_app.preferences (user_id, deletion_epoch)
  values (new.id, 0)
  on conflict (user_id) do nothing;

  insert into argus_app.onboarding_states (
    user_id, deletion_epoch, current_step
  ) values (
    new.id, 0, 'welcome'
  ) on conflict (user_id) do nothing;

  insert into argus_app.notification_preferences (user_id, deletion_epoch)
  values (new.id, 0)
  on conflict (user_id) do nothing;

  return new;
end
$$;

revoke all on function argus_private.provision_argus_member() from public, anon, authenticated, argus_runtime, argus_worker;

drop trigger if exists provision_argus_member_after_auth_insert on auth.users;
create trigger provision_argus_member_after_auth_insert
  after insert on auth.users
  for each row execute function argus_private.provision_argus_member();

create policy runtime_staff_privacy_read on argus_app.privacy_requests
  for select to argus_runtime
  using (
    argus_private.has_staff_permission('privacy:read')
    or argus_private.has_staff_permission('privacy:write')
  );

create policy runtime_staff_privacy_update on argus_app.privacy_requests
  for update to argus_runtime
  using (argus_private.has_staff_permission('privacy:write'))
  with check (argus_private.has_staff_permission('privacy:write'));

create policy runtime_staff_job_read on argus_private.job_runs
  for select to argus_runtime
  using (
    argus_private.has_staff_permission('operations:read')
    or argus_private.has_staff_permission('operations:write')
  );

create policy runtime_staff_outbox_insert on argus_private.outbox_events
  for insert to argus_runtime
  with check (
    argus_private.has_staff_permission('operations:write')
    and topic = 'argus_jobs'
    and event_type in ('admin.job.retry_requested', 'admin.privacy.retry_requested')
  );

create policy runtime_staff_outbox_read on argus_private.outbox_events
  for select to argus_runtime
  using (
    argus_private.has_staff_permission('operations:read')
    or argus_private.has_staff_permission('operations:write')
  );

grant select on argus_private.job_runs to argus_runtime;

create or replace function argus_private.request_admin_job_retry(
  p_job_id uuid,
  p_dedupe_key text
)
returns uuid
language plpgsql
security invoker
set search_path = pg_catalog, auth, argus_private
as $$
declare
  requested_job argus_private.job_runs%rowtype;
  event_id uuid;
begin
  if not argus_private.has_staff_permission('operations:write') then
    raise exception 'staff_permission_required' using errcode = '42501';
  end if;

  select * into requested_job
    from argus_private.job_runs job
   where job.id = p_job_id
     and job.status in ('retry', 'dead_lettered');
  if requested_job.id is null then
    raise exception 'job_not_retryable';
  end if;

  insert into argus_private.outbox_events (
    user_id, deletion_epoch, topic, event_type, aggregate_id, dedupe_key
  ) values (
    requested_job.user_id,
    requested_job.deletion_epoch,
    'argus_jobs',
    'admin.job.retry_requested',
    requested_job.id,
    p_dedupe_key
  )
  returning id into event_id;

  return event_id;
end
$$;

revoke all on function argus_private.request_admin_job_retry(uuid,text) from public, anon, authenticated;
grant execute on function argus_private.request_admin_job_retry(uuid,text) to argus_runtime;

create policy runtime_member_active_evidence_source_read
  on argus_app.evidence_sources for select to argus_runtime
  using (
    status = 'active'
    and exists (
      select 1 from argus_app.members member
       where member.user_id = (select auth.uid()) and member.status = 'active'
    )
  );

create policy runtime_member_active_evidence_claim_read
  on argus_app.evidence_claims for select to argus_runtime
  using (
    status = 'active'
    and exists (
      select 1 from argus_app.evidence_sources source
       where source.id = evidence_claims.source_id and source.status = 'active'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id = (select auth.uid()) and member.status = 'active'
    )
  );

create policy runtime_member_published_company_read
  on argus_app.companies for select to argus_runtime
  using (
    status = 'active'
    and exists (
      select 1
        from argus_app.coven_entries coven
        join argus_app.editorial_items item on item.id = coven.editorial_item_id
        join argus_app.editorial_revisions revision
          on revision.id = item.current_published_revision_id
       where coven.company_id = companies.id
         and item.status = 'published' and revision.state = 'published'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id = (select auth.uid()) and member.status = 'active'
    )
  );

create policy runtime_member_published_coven_read
  on argus_app.coven_entries for select to argus_runtime
  using (
    exists (
      select 1
        from argus_app.editorial_items item
        join argus_app.editorial_revisions revision
          on revision.id = item.current_published_revision_id
       where item.id = coven_entries.editorial_item_id
         and item.status = 'published' and revision.state = 'published'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id = (select auth.uid()) and member.status = 'active'
    )
  );

create policy runtime_member_published_grimoire_read
  on argus_app.grimoires for select to argus_runtime
  using (
    exists (
      select 1
        from argus_app.editorial_items item
        join argus_app.editorial_revisions revision
          on revision.id = item.current_published_revision_id
       where item.id = grimoires.editorial_item_id
         and item.status = 'published' and revision.state = 'published'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id = (select auth.uid()) and member.status = 'active'
    )
  );

create policy runtime_member_published_template_read
  on argus_app.community_templates for select to argus_runtime
  using (
    exists (
      select 1
        from argus_app.editorial_items item
        join argus_app.editorial_revisions revision
          on revision.id = item.current_published_revision_id
       where item.id = community_templates.editorial_item_id
         and item.status = 'published' and revision.state = 'published'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id = (select auth.uid()) and member.status = 'active'
    )
  );

create policy runtime_member_published_ritual_scenario_read
  on argus_app.ritual_scenarios for select to argus_runtime
  using (
    exists (
      select 1
        from argus_app.editorial_items item
        join argus_app.editorial_revisions revision
          on revision.id = item.current_published_revision_id
       where item.id = ritual_scenarios.editorial_item_id
         and item.status = 'published' and revision.state = 'published'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id = (select auth.uid()) and member.status = 'active'
    )
  );

create policy runtime_member_published_ritual_revision_read
  on argus_app.ritual_scenario_revisions for select to argus_runtime
  using (
    exists (
      select 1
        from argus_app.ritual_scenarios scenario
        join argus_app.editorial_items item on item.id = scenario.editorial_item_id
        join argus_app.editorial_revisions revision
          on revision.id = item.current_published_revision_id
       where ritual_scenario_revisions.revision_id = revision.id
         and item.status = 'published' and revision.state = 'published'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id = (select auth.uid()) and member.status = 'active'
    )
  );

create policy runtime_member_published_rowan_script_read
  on argus_app.rowan_scripts for select to argus_runtime
  using (
    exists (
      select 1
        from argus_app.editorial_items item
        join argus_app.editorial_revisions revision
          on revision.id = item.current_published_revision_id
       where item.id = rowan_scripts.editorial_item_id
         and item.status = 'published' and revision.state = 'published'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id = (select auth.uid()) and member.status = 'active'
    )
  );

create policy runtime_member_published_rowan_revision_read
  on argus_app.rowan_script_revisions for select to argus_runtime
  using (
    exists (
      select 1
        from argus_app.rowan_scripts script
        join argus_app.editorial_items item on item.id = script.editorial_item_id
        join argus_app.editorial_revisions revision
          on revision.id = item.current_published_revision_id
       where rowan_script_revisions.revision_id = revision.id
         and item.status = 'published' and revision.state = 'published'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id = (select auth.uid()) and member.status = 'active'
    )
  );

create policy runtime_member_published_rowan_binding_read
  on argus_app.rowan_context_bindings for select to argus_runtime
  using (
    exists (
      select 1
        from argus_app.rowan_scripts script
        join argus_app.editorial_items item on item.id = script.editorial_item_id
        join argus_app.editorial_revisions revision
          on revision.id = item.current_published_revision_id
       where script.id = rowan_context_bindings.script_id
         and item.status = 'published' and revision.state = 'published'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id = (select auth.uid()) and member.status = 'active'
    )
  );

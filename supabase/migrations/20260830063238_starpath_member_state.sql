begin;

do $membership$
begin
  execute pg_catalog.format(
    'grant argus_app_owner,argus_jobs_owner,argus_application_purge_owner,argus_identity_owner to %I with set true',
    current_user
  );
end
$membership$;

-- Starpath member state is lifecycle data. Reviewed curriculum remains a
-- separate immutable authority; sessions pin exact manifest/theme/revision
-- identities and commands derive correctness on the server.

grant create on schema argus_app to argus_app_owner;
set local role argus_app_owner;
alter table argus_app.starpath_manifest_nodes
  add constraint starpath_manifest_nodes_exact_identity_unique
  unique(manifest_id,lesson_id,revision_id,node_ordinal);
reset role;

create table argus_app.starpath_sessions (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  deletion_epoch bigint not null,
  manifest_id uuid not null,
  theme_id uuid not null,
  state text not null default 'active'
    check (state in ('active','closed','replaced')),
  started_at timestamptz not null default pg_catalog.clock_timestamp(),
  last_action_at timestamptz not null default pg_catalog.clock_timestamp(),
  ended_at timestamptz,
  close_reason text,
  explicit_start boolean not null default true,
  capability_version_at_start bigint not null check (capability_version_at_start>0),
  replacement_of_session_id uuid,
  replaced_by_session_id uuid,
  unique(tenant_id,lifecycle_id,user_id,id),
  foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict,
  foreign key (manifest_id,theme_id)
    references argus_app.starpath_manifest_themes(manifest_id,theme_id)
    on delete restrict,
  check (last_action_at>=started_at),
  check (
    (state='active' and ended_at is null and close_reason is null)
    or (state<>'active' and ended_at is not null
      and pg_catalog.char_length(close_reason) between 1 and 128)
  ),
  check (replacement_of_session_id is null or replacement_of_session_id<>id),
  check (replaced_by_session_id is null or replaced_by_session_id<>id)
);
create unique index starpath_sessions_one_active_lifecycle_unique
  on argus_app.starpath_sessions(tenant_id,lifecycle_id,user_id)
  where state='active';
create index starpath_sessions_retention_cohort_idx
  on argus_app.starpath_sessions(explicit_start,started_at,tenant_id,lifecycle_id)
  where explicit_start;
create index starpath_sessions_member_history_idx
  on argus_app.starpath_sessions(tenant_id,lifecycle_id,started_at desc,id desc);
create index starpath_sessions_manifest_theme_fk_idx
  on argus_app.starpath_sessions(manifest_id,theme_id);

create table argus_app.starpath_progress_states (
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  deletion_epoch bigint not null,
  current_node_ordinal integer not null default 1
    check (current_node_ordinal between 1 and 9),
  progress_version bigint not null default 1 check (progress_version>0),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(tenant_id,lifecycle_id,user_id),
  foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict
);

create table argus_app.starpath_lesson_completions (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  deletion_epoch bigint not null,
  lesson_id uuid not null references argus_app.starpath_lessons(id) on delete restrict,
  manifest_id uuid not null,
  revision_id uuid not null,
  node_ordinal integer not null check (node_ordinal between 1 and 8),
  first_session_id uuid not null,
  completed_at timestamptz not null default pg_catalog.clock_timestamp(),
  first_attempt_correct boolean not null,
  unique(tenant_id,lifecycle_id,user_id,lesson_id),
  foreign key (tenant_id,lifecycle_id,user_id,first_session_id)
    references argus_app.starpath_sessions(tenant_id,lifecycle_id,user_id,id)
    on delete restrict,
  foreign key (manifest_id,lesson_id,revision_id,node_ordinal)
    references argus_app.starpath_manifest_nodes(
      manifest_id,lesson_id,revision_id,node_ordinal
    ) on delete restrict
);
create index starpath_completions_member_order_idx
  on argus_app.starpath_lesson_completions(
    tenant_id,lifecycle_id,completed_at desc,id desc
  );
create index starpath_completions_session_fk_idx
  on argus_app.starpath_lesson_completions(
    tenant_id,lifecycle_id,user_id,first_session_id
  );
create index starpath_completions_manifest_node_fk_idx
  on argus_app.starpath_lesson_completions(
    manifest_id,lesson_id,revision_id,node_ordinal
  );

create table argus_app.starpath_attempts (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  deletion_epoch bigint not null,
  session_id uuid not null,
  manifest_id uuid not null,
  lesson_id uuid not null,
  revision_id uuid not null,
  node_ordinal integer not null check (node_ordinal between 1 and 8),
  question_id uuid not null,
  selected_option_id uuid not null,
  attempt_kind text not null check (attempt_kind in ('node','recall')),
  is_correct boolean not null,
  attempted_at timestamptz not null default pg_catalog.clock_timestamp(),
  unique(
    tenant_id,lifecycle_id,session_id,revision_id,question_id,
    selected_option_id,attempt_kind
  ),
  foreign key (tenant_id,lifecycle_id,user_id,session_id)
    references argus_app.starpath_sessions(tenant_id,lifecycle_id,user_id,id)
    on delete restrict,
  foreign key (manifest_id,lesson_id,revision_id,node_ordinal)
    references argus_app.starpath_manifest_nodes(
      manifest_id,lesson_id,revision_id,node_ordinal
    ) on delete restrict,
  foreign key (lesson_id,revision_id,question_id,selected_option_id)
    references argus_app.starpath_knowledge_check_options(
      lesson_id,revision_id,question_id,id
    ) on delete restrict
);
create index starpath_attempts_member_order_idx
  on argus_app.starpath_attempts(
    tenant_id,lifecycle_id,attempted_at,id
  );
create index starpath_attempts_session_fk_idx
  on argus_app.starpath_attempts(tenant_id,lifecycle_id,user_id,session_id);
create index starpath_attempts_manifest_node_fk_idx
  on argus_app.starpath_attempts(manifest_id,lesson_id,revision_id,node_ordinal);
create index starpath_attempts_option_fk_idx
  on argus_app.starpath_attempts(
    lesson_id,revision_id,question_id,selected_option_id
  );

create table argus_app.starpath_recall_states (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  deletion_epoch bigint not null,
  lesson_id uuid not null references argus_app.starpath_lessons(id) on delete restrict,
  manifest_id uuid not null,
  revision_id uuid not null,
  node_ordinal integer not null check (node_ordinal between 1 and 8),
  question_id uuid not null,
  status text not null default 'due'
    check (status in ('due','presented','skipped','completed')),
  due_session_id uuid,
  due_at timestamptz not null default pg_catalog.clock_timestamp(),
  presented_at timestamptz,
  skipped_at timestamptz,
  completed_at timestamptz,
  unique(tenant_id,lifecycle_id,user_id,lesson_id),
  foreign key (tenant_id,lifecycle_id,user_id,due_session_id)
    references argus_app.starpath_sessions(tenant_id,lifecycle_id,user_id,id)
    on delete restrict,
  foreign key (manifest_id,lesson_id,revision_id,node_ordinal)
    references argus_app.starpath_manifest_nodes(
      manifest_id,lesson_id,revision_id,node_ordinal
    ) on delete restrict,
  foreign key (lesson_id,revision_id,question_id)
    references argus_app.starpath_knowledge_checks(lesson_id,revision_id,id)
    on delete restrict,
  check (
    (status='due' and due_session_id is null and presented_at is null
      and skipped_at is null and completed_at is null)
    or (status='presented' and due_session_id is not null and presented_at is not null
      and skipped_at is null and completed_at is null)
    or (status='skipped' and due_session_id is not null and presented_at is not null
      and skipped_at is not null and completed_at is null)
    or (status='completed' and due_session_id is not null and presented_at is not null
      and completed_at is not null and skipped_at is null)
  )
);
create index starpath_recall_due_idx
  on argus_app.starpath_recall_states(
    tenant_id,lifecycle_id,due_at desc,id desc
  ) where status='due';
create index starpath_recall_session_fk_idx
  on argus_app.starpath_recall_states(
    tenant_id,lifecycle_id,user_id,due_session_id
  );
create index starpath_recall_manifest_node_fk_idx
  on argus_app.starpath_recall_states(
    manifest_id,lesson_id,revision_id,node_ordinal
  );
create index starpath_recall_question_fk_idx
  on argus_app.starpath_recall_states(lesson_id,revision_id,question_id);

create table argus_private.starpath_retention_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  metric_code text not null check (metric_code='learning_retention_within_7d_v1'),
  definition_version text not null check (definition_version='v1'),
  as_of timestamptz not null,
  cohort_lower_bound timestamptz not null,
  cohort_upper_bound timestamptz not null,
  matured_denominator bigint not null check (matured_denominator>=0),
  retained_count bigint not null check (
    retained_count>=0 and retained_count<=matured_denominator
  ),
  snapshot_checksum text not null check (snapshot_checksum~'^[a-f0-9]{64}$'),
  deletion_recomputation_note text not null,
  captured_by uuid not null references argus_private.staff_principals(user_id)
    on delete restrict,
  captured_at timestamptz not null default pg_catalog.clock_timestamp(),
  unique(metric_code,as_of),
  check (cohort_lower_bound<cohort_upper_bound and cohort_upper_bound<=as_of)
);
create index starpath_retention_captured_by_fk_idx
  on argus_private.starpath_retention_snapshots(captured_by);

-- Existing onboarding and intention clients omit lifecycle columns. Bind them
-- in a BEFORE INSERT trigger, then enforce the lifecycle-qualified cutover.
alter table argus_private.member_idempotency_records
  add column tenant_id uuid,
  add column lifecycle_id uuid,
  add column result_type text,
  add column typed_result jsonb;

do $$
begin
  if exists (
    select 1 from argus_private.member_idempotency_records receipt
    left join argus_app.members member on member.user_id=receipt.user_id
   where member.user_id is null or member.deletion_epoch<>receipt.deletion_epoch
  ) then
    raise exception 'member_idempotency_lifecycle_backfill_invalid';
  end if;
end
$$;

update argus_private.member_idempotency_records receipt
   set tenant_id=member.tenant_id,lifecycle_id=member.lifecycle_id
  from argus_app.members member
 where member.user_id=receipt.user_id
   and member.deletion_epoch=receipt.deletion_epoch;

alter table argus_private.member_idempotency_records
  alter column tenant_id set not null,
  alter column lifecycle_id set not null,
  add constraint member_idempotency_tenant_lifecycle_fk
    foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  add constraint member_idempotency_subject_lifecycle_fk
    foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict,
  add constraint member_idempotency_lifecycle_key_unique
    unique(tenant_id,lifecycle_id,operation,idempotency_key),
  add constraint member_idempotency_result_type_check check (
    result_type is null or result_type~'^[a-z][a-z0-9._-]{2,127}$'
  ),
  add constraint member_idempotency_starpath_result_check check (
    operation not like 'starpath.%'
    or (
      result_type is not null and typed_result is not null
      and pg_catalog.jsonb_typeof(typed_result)='object'
      and response_status is not null
    )
  );
create index member_idempotency_subject_lifecycle_idx
  on argus_private.member_idempotency_records(user_id,lifecycle_id);

create trigger bind_member_idempotency_lifecycle
  before insert on argus_private.member_idempotency_records
  for each row execute function argus_private.bind_argus_app_member_lifecycle();

create or replace function argus_private.protect_member_idempotency_scope()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if new.tenant_id is distinct from old.tenant_id
     or new.lifecycle_id is distinct from old.lifecycle_id
     or new.user_id is distinct from old.user_id
     or new.deletion_epoch is distinct from old.deletion_epoch
     or new.operation is distinct from old.operation
     or new.idempotency_key is distinct from old.idempotency_key
     or new.request_hash is distinct from old.request_hash then
    raise exception 'member_idempotency_scope_immutable' using errcode='23514';
  end if;
  return new;
end
$$;
create trigger protect_member_idempotency_scope
  before update on argus_private.member_idempotency_records
  for each row execute function argus_private.protect_member_idempotency_scope();

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'starpath_sessions','starpath_progress_states',
    'starpath_lesson_completions','starpath_attempts','starpath_recall_states'
  ] loop
    execute pg_catalog.format(
      'create trigger bind_starpath_member_lifecycle before insert or update on argus_app.%I for each row execute function argus_private.bind_argus_app_member_lifecycle()',
      relation_name
    );
    execute pg_catalog.format('alter table argus_app.%I enable row level security',relation_name);
    execute pg_catalog.format('alter table argus_app.%I force row level security',relation_name);
    execute pg_catalog.format('revoke all on argus_app.%I from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker',relation_name);
    execute pg_catalog.format(
      'create policy starpath_member_owner_read on argus_app.%I for select to argus_app_owner using ((tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id())) or (select argus_private.has_staff_permission(''operations:read'')))',
      relation_name
    );
    execute pg_catalog.format(
      'create policy starpath_member_owner_insert on argus_app.%I for insert to argus_app_owner with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()))',
      relation_name
    );
    execute pg_catalog.format(
      'create policy starpath_member_owner_update on argus_app.%I for update to argus_app_owner using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id())) with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()))',
      relation_name
    );
    execute pg_catalog.format(
      'create policy starpath_privacy_export_read on argus_app.%I for select to argus_jobs_owner using (true)',
      relation_name
    );
    execute pg_catalog.format(
      'create policy starpath_application_purge_read on argus_app.%I for select to argus_application_purge_owner using (true)',
      relation_name
    );
    execute pg_catalog.format(
      'create policy starpath_application_purge_delete on argus_app.%I for delete to argus_application_purge_owner using (true)',
      relation_name
    );
    execute pg_catalog.format(
      'grant select on argus_app.%I to argus_jobs_owner',relation_name
    );
    execute pg_catalog.format(
      'grant select,delete on argus_app.%I to argus_application_purge_owner',
      relation_name
    );
    execute pg_catalog.format('alter table argus_app.%I owner to argus_app_owner',relation_name);
  end loop;
end
$$;
revoke create on schema argus_app from argus_app_owner;

create trigger starpath_attempts_immutable
  before update on argus_app.starpath_attempts
  for each row execute function argus_private.reject_starpath_immutable_change();
create trigger starpath_completions_immutable
  before update on argus_app.starpath_lesson_completions
  for each row execute function argus_private.reject_starpath_immutable_change();

alter table argus_private.starpath_retention_snapshots enable row level security;
alter table argus_private.starpath_retention_snapshots force row level security;
revoke all on argus_private.starpath_retention_snapshots
  from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
       argus_callback,argus_worker,argus_jobs_owner;
create policy starpath_retention_owner_read
  on argus_private.starpath_retention_snapshots for select to argus_app_owner
  using ((select argus_private.has_staff_permission('operations:read')));
create policy starpath_retention_owner_insert
  on argus_private.starpath_retention_snapshots for insert to argus_app_owner
  with check ((select argus_private.has_staff_permission('operations:read')));
create trigger starpath_retention_snapshots_immutable
  before update or delete on argus_private.starpath_retention_snapshots
  for each row execute function argus_private.reject_starpath_immutable_change();
grant create on schema argus_private to argus_app_owner;
alter table argus_private.starpath_retention_snapshots owner to argus_app_owner;

create policy starpath_owner_idempotency_read
  on argus_private.member_idempotency_records for select to argus_app_owner
  using (
    operation like 'starpath.%'
    and tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
    and user_id=(select argus_private.trusted_request_user_id())
  );
create policy starpath_owner_idempotency_insert
  on argus_private.member_idempotency_records for insert to argus_app_owner
  with check (
    operation like 'starpath.%'
    and tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
    and user_id=(select argus_private.trusted_request_user_id())
  );
create policy starpath_owner_idempotency_update
  on argus_private.member_idempotency_records for update to argus_app_owner
  using (
    operation like 'starpath.%'
    and tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
    and user_id=(select argus_private.trusted_request_user_id())
  )
  with check (
    operation like 'starpath.%'
    and tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
    and user_id=(select argus_private.trusted_request_user_id())
  );
grant select,insert,update on argus_private.member_idempotency_records
  to argus_app_owner;
set local role argus_identity_owner;
grant execute on function argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)
  to argus_app_owner;
reset role;

create or replace function argus_private.assert_starpath_manifest_theme(
  p_manifest_id uuid,p_theme_id uuid
)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if not exists (
    select 1
      from argus_app.starpath_curriculum_manifests manifest
      join argus_app.starpath_manifest_themes manifest_theme
        on manifest_theme.manifest_id=manifest.id
      join argus_app.starpath_session_themes theme
        on theme.id=manifest_theme.theme_id
     where manifest.id=p_manifest_id and manifest.state='published'
       and theme.id=p_theme_id and theme.status='reviewed'
  ) then
    raise exception 'starpath_manifest_unavailable' using errcode='23514';
  end if;
end
$$;

create or replace function argus_private.starpath_state_snapshot(p_session_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'availability','available',
    'session',pg_catalog.jsonb_build_object(
      'id',session.id,'manifestId',session.manifest_id,
      'themeId',session.theme_id,'state',session.state,
      'startedAt',session.started_at,'lastActionAt',session.last_action_at,
      'explicitStart',session.explicit_start,
      'replacementOfSessionId',session.replacement_of_session_id,
      'capabilityVersion',session.capability_version_at_start
    ),
    'progress',pg_catalog.jsonb_build_object(
      'currentNodeOrdinal',progress.current_node_ordinal,
      'version',progress.progress_version,'updatedAt',progress.updated_at
    ),
    'currentNode',(
      select pg_catalog.jsonb_build_object(
        'nodeOrdinal',node.node_ordinal,'lessonId',node.lesson_id,
        'revisionId',node.revision_id
      )
        from argus_app.starpath_manifest_nodes node
       where node.manifest_id=session.manifest_id
         and node.node_ordinal=progress.current_node_ordinal
    ),
    'recall',(
      select pg_catalog.jsonb_build_object(
        'id',recall.id,'lessonId',recall.lesson_id,
        'revisionId',recall.revision_id,'questionId',recall.question_id,
        'status',recall.status
      )
        from argus_app.starpath_recall_states recall
       where recall.tenant_id=session.tenant_id
         and recall.lifecycle_id=session.lifecycle_id
         and recall.user_id=session.user_id
         and recall.due_session_id=session.id and recall.status='presented'
       order by recall.presented_at desc,recall.id desc limit 1
    ),
    'completedLessonIds',coalesce((
      select pg_catalog.jsonb_agg(completion.lesson_id order by completion.completed_at)
        from argus_app.starpath_lesson_completions completion
       where completion.tenant_id=session.tenant_id
         and completion.lifecycle_id=session.lifecycle_id
         and completion.user_id=session.user_id
    ),'[]'::jsonb)
  )
    from argus_app.starpath_sessions session
    join argus_app.starpath_progress_states progress
      on progress.tenant_id=session.tenant_id
     and progress.lifecycle_id=session.lifecycle_id
     and progress.user_id=session.user_id
   where session.id=p_session_id
     and session.tenant_id=(select argus_private.trusted_request_tenant_id())
     and session.lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
     and session.user_id=(select argus_private.trusted_request_user_id())
$$;

create or replace function argus_private.create_starpath_session(
  p_manifest_id uuid,p_theme_id uuid,p_capability_version bigint,
  p_explicit_start boolean,p_replacement_of_session_id uuid
)
returns uuid language plpgsql security invoker set search_path='' as $$
declare context_record record;
declare member_epoch bigint;
declare new_session_id uuid:=extensions.gen_random_uuid();
declare next_node integer;
begin
  perform argus_private.assert_starpath_manifest_theme(p_manifest_id,p_theme_id);
  if p_capability_version<=0 then
    raise exception 'invalid_capability_version' using errcode='22023';
  end if;
  select * into context_record from argus_private.read_trusted_request_context();
  select member.deletion_epoch into member_epoch
    from argus_app.members member
   where member.tenant_id=context_record.tenant_id
     and member.lifecycle_id=context_record.lifecycle_id
     and member.user_id=context_record.user_id and member.status='active';
  if member_epoch is null then
    raise exception 'member_lifecycle_not_open' using errcode='28000';
  end if;
  insert into argus_app.starpath_progress_states(
    tenant_id,lifecycle_id,user_id,deletion_epoch
  ) values (
    context_record.tenant_id,context_record.lifecycle_id,
    context_record.user_id,member_epoch
  ) on conflict (tenant_id,lifecycle_id,user_id) do nothing;

  if p_replacement_of_session_id is not null then
    select coalesce(min(node.node_ordinal),9) into next_node
      from argus_app.starpath_manifest_nodes node
     where node.manifest_id=p_manifest_id
       and not exists (
         select 1 from argus_app.starpath_lesson_completions completion
          where completion.tenant_id=context_record.tenant_id
            and completion.lifecycle_id=context_record.lifecycle_id
            and completion.user_id=context_record.user_id
            and completion.lesson_id=node.lesson_id
       );
    update argus_app.starpath_progress_states progress
       set current_node_ordinal=next_node,
           progress_version=progress.progress_version+1,
           updated_at=pg_catalog.clock_timestamp()
     where progress.tenant_id=context_record.tenant_id
       and progress.lifecycle_id=context_record.lifecycle_id
       and progress.user_id=context_record.user_id;
  end if;

  insert into argus_app.starpath_sessions(
    id,tenant_id,lifecycle_id,user_id,deletion_epoch,manifest_id,theme_id,
    explicit_start,capability_version_at_start,replacement_of_session_id
  ) values (
    new_session_id,context_record.tenant_id,context_record.lifecycle_id,
    context_record.user_id,member_epoch,p_manifest_id,p_theme_id,
    p_explicit_start,p_capability_version,p_replacement_of_session_id
  );

  if p_explicit_start then
    update argus_app.starpath_recall_states recall
       set status='presented',due_session_id=new_session_id,
           presented_at=pg_catalog.clock_timestamp()
     where recall.id=(
       select due.id from argus_app.starpath_recall_states due
        where due.tenant_id=context_record.tenant_id
          and due.lifecycle_id=context_record.lifecycle_id
          and due.user_id=context_record.user_id and due.status='due'
        order by due.due_at desc,due.id desc limit 1
        for update skip locked
     );
  end if;
  return new_session_id;
end
$$;

create or replace function argus_private.replace_withdrawn_starpath_session(
  p_session_id uuid,p_manifest_id uuid,p_theme_id uuid,
  p_explicit_start boolean
)
returns uuid language plpgsql security invoker set search_path='' as $$
declare old_session argus_app.starpath_sessions%rowtype;
declare replacement_manifest_id uuid:=p_manifest_id;
declare replacement_theme_id uuid:=p_theme_id;
declare replacement_capability_version bigint;
declare new_session_id uuid;
begin
  select session.* into old_session
    from argus_app.starpath_sessions session
   where session.id=p_session_id and session.state='active'
     and session.tenant_id=(select argus_private.trusted_request_tenant_id())
     and session.lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
     and session.user_id=(select argus_private.trusted_request_user_id())
   for update;
  if old_session.id is null then
    raise exception 'starpath_session_not_active' using errcode='23514';
  end if;
  if not exists (
    select 1 from argus_app.starpath_curriculum_manifests manifest
     where manifest.id=old_session.manifest_id and manifest.state='withdrawn'
  ) then
    return old_session.id;
  end if;
  if replacement_manifest_id is null then
    select replacement.id into replacement_manifest_id
      from argus_app.starpath_curriculum_manifests old_manifest
      join argus_app.starpath_curriculum_manifests replacement
        on replacement.release_environment=old_manifest.release_environment
       and replacement.supported_jurisdiction=old_manifest.supported_jurisdiction
       and replacement.state='published'
     where old_manifest.id=old_session.manifest_id
     order by replacement.published_at desc,replacement.id desc limit 1;
  end if;
  if replacement_manifest_id is null then
    raise exception 'starpath_replacement_unavailable' using errcode='23514';
  end if;
  if not exists (
    select 1
      from argus_app.starpath_curriculum_manifests old_manifest
      join argus_app.starpath_curriculum_manifests replacement
        on replacement.release_environment=old_manifest.release_environment
       and replacement.supported_jurisdiction=old_manifest.supported_jurisdiction
     where old_manifest.id=old_session.manifest_id
       and replacement.id=replacement_manifest_id
       and replacement.state='published'
  ) then
    raise exception 'starpath_replacement_scope_invalid' using errcode='23514';
  end if;
  if replacement_theme_id is null then
    select manifest_theme.theme_id into replacement_theme_id
      from argus_app.starpath_manifest_themes manifest_theme
      join argus_app.starpath_session_themes theme
        on theme.id=manifest_theme.theme_id and theme.status='reviewed'
     where manifest_theme.manifest_id=replacement_manifest_id
     order by manifest_theme.ordinal limit 1;
  end if;
  perform argus_private.assert_starpath_manifest_theme(
    replacement_manifest_id,replacement_theme_id
  );
  replacement_capability_version:=old_session.capability_version_at_start;
  update argus_app.starpath_sessions
     set state='replaced',ended_at=pg_catalog.clock_timestamp(),
         close_reason='content_withdrawn'
   where id=old_session.id;
  new_session_id:=argus_private.create_starpath_session(
    replacement_manifest_id,replacement_theme_id,
    replacement_capability_version,p_explicit_start,old_session.id
  );
  update argus_app.starpath_sessions
     set replaced_by_session_id=new_session_id where id=old_session.id;
  return new_session_id;
end
$$;

create or replace function argus_private.start_or_resume_starpath_session(
  p_idempotency_key text,p_request_hash text,p_manifest_id uuid,
  p_theme_id uuid,p_capability_version bigint
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare context_record record;
declare member_epoch bigint;
declare active_session argus_app.starpath_sessions%rowtype;
declare existing_receipt argus_private.member_idempotency_records%rowtype;
declare session_id uuid;
declare response_status integer:=200;
declare effect text:='resumed';
begin
  if p_idempotency_key!~'^[!-~]{16,128}$' or p_request_hash!~'^[a-f0-9]{64}$' then
    raise exception 'invalid_idempotency_input' using errcode='22023';
  end if;
  select * into context_record from argus_private.read_trusted_request_context();
  if context_record.user_id is null or not argus_private.lock_open_member_lifecycle(
    context_record.tenant_id,context_record.lifecycle_id,context_record.user_id
  ) then raise exception 'member_lifecycle_not_open' using errcode='28000'; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(context_record.lifecycle_id::text,0)
  );
  select member.deletion_epoch into member_epoch from argus_app.members member
   where member.tenant_id=context_record.tenant_id
     and member.lifecycle_id=context_record.lifecycle_id
     and member.user_id=context_record.user_id and member.status='active';
  select session.* into active_session
    from argus_app.starpath_sessions session
   where session.tenant_id=context_record.tenant_id
     and session.lifecycle_id=context_record.lifecycle_id
     and session.user_id=context_record.user_id and session.state='active'
   for update;
  perform 1 from argus_app.starpath_progress_states progress
   where progress.tenant_id=context_record.tenant_id
     and progress.lifecycle_id=context_record.lifecycle_id
     and progress.user_id=context_record.user_id for update;
  select receipt.* into existing_receipt
    from argus_private.member_idempotency_records receipt
   where receipt.tenant_id=context_record.tenant_id
     and receipt.lifecycle_id=context_record.lifecycle_id
     and receipt.operation='starpath.start'
     and receipt.idempotency_key=p_idempotency_key
   for update;
  if existing_receipt.id is not null then
    if existing_receipt.user_id<>context_record.user_id
       or existing_receipt.deletion_epoch<>member_epoch
       or existing_receipt.request_hash<>p_request_hash then
      raise exception 'idempotency_conflict' using errcode='23514';
    end if;
    if active_session.id is not null then session_id:=active_session.id;
    else session_id:=existing_receipt.resource_id; end if;
    return argus_private.starpath_state_snapshot(session_id)
      || pg_catalog.jsonb_build_object('commandEffect','idempotent_replay');
  end if;

  if active_session.id is not null and exists (
    select 1 from argus_app.starpath_curriculum_manifests manifest
     where manifest.id=active_session.manifest_id and manifest.state='withdrawn'
  ) then
    session_id:=argus_private.replace_withdrawn_starpath_session(
      active_session.id,p_manifest_id,p_theme_id,true
    );
    effect:='content_replaced'; response_status:=201;
  elsif active_session.id is not null
    and pg_catalog.clock_timestamp()
      <=active_session.last_action_at+interval '30 minutes' then
    session_id:=active_session.id;
    update argus_app.starpath_sessions
       set last_action_at=pg_catalog.clock_timestamp() where id=session_id;
  else
    if active_session.id is not null then
      update argus_app.starpath_sessions
         set state='closed',ended_at=pg_catalog.clock_timestamp(),
             close_reason='inactivity_window_elapsed'
       where id=active_session.id;
    end if;
    session_id:=argus_private.create_starpath_session(
      p_manifest_id,p_theme_id,p_capability_version,true,null
    );
    effect:='started'; response_status:=201;
  end if;

  insert into argus_private.member_idempotency_records(
    tenant_id,lifecycle_id,user_id,deletion_epoch,operation,idempotency_key,
    request_hash,resource_id,response_status,result_type,typed_result
  ) values (
    context_record.tenant_id,context_record.lifecycle_id,context_record.user_id,
    member_epoch,'starpath.start',p_idempotency_key,p_request_hash,session_id,
    response_status,'starpath.session.v1',
    pg_catalog.jsonb_build_object('sessionId',session_id,'effect',effect)
  );
  return argus_private.starpath_state_snapshot(session_id)
    || pg_catalog.jsonb_build_object('commandEffect',effect);
end
$$;

create or replace function argus_private.read_starpath_state(
  p_replacement_manifest_id uuid,p_replacement_theme_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare context_record record;
declare active_session argus_app.starpath_sessions%rowtype;
declare session_id uuid;
begin
  select * into context_record from argus_private.read_trusted_request_context();
  if context_record.user_id is null or not argus_private.lock_open_member_lifecycle(
    context_record.tenant_id,context_record.lifecycle_id,context_record.user_id
  ) then raise exception 'member_lifecycle_not_open' using errcode='28000'; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(context_record.lifecycle_id::text,0)
  );
  select session.* into active_session from argus_app.starpath_sessions session
   where session.tenant_id=context_record.tenant_id
     and session.lifecycle_id=context_record.lifecycle_id
     and session.user_id=context_record.user_id and session.state='active'
   for update;
  if active_session.id is null then
    return pg_catalog.jsonb_build_object('availability','not_started');
  end if;
  perform 1 from argus_app.starpath_progress_states progress
   where progress.tenant_id=context_record.tenant_id
     and progress.lifecycle_id=context_record.lifecycle_id
     and progress.user_id=context_record.user_id for update;
  if exists (
    select 1 from argus_app.starpath_curriculum_manifests manifest
     where manifest.id=active_session.manifest_id and manifest.state='withdrawn'
  ) then
    session_id:=argus_private.replace_withdrawn_starpath_session(
      active_session.id,p_replacement_manifest_id,p_replacement_theme_id,false
    );
    return argus_private.starpath_state_snapshot(session_id)
      || pg_catalog.jsonb_build_object('commandEffect','content_replaced');
  end if;
  update argus_app.starpath_sessions set last_action_at=pg_catalog.clock_timestamp()
   where id=active_session.id;
  return argus_private.starpath_state_snapshot(active_session.id);
end
$$;

create or replace function argus_private.answer_starpath_question(
  p_idempotency_key text,p_request_hash text,p_session_id uuid,
  p_manifest_id uuid,p_revision_id uuid,p_question_id uuid,p_option_id uuid,
  p_expected_progress_version bigint,p_attempt_kind text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare context_record record;
declare member_epoch bigint;
declare requested_session argus_app.starpath_sessions%rowtype;
declare active_session_id uuid;
declare progress_record argus_app.starpath_progress_states%rowtype;
declare option_record record;
declare existing_receipt argus_private.member_idempotency_records%rowtype;
declare attempt_inserted boolean:=false;
declare completion_inserted boolean:=false;
declare replacement_session_id uuid;
declare attempt_count bigint;
declare effect text:='wrong_answer';
begin
  if p_idempotency_key!~'^[!-~]{16,128}$' or p_request_hash!~'^[a-f0-9]{64}$'
     or p_attempt_kind not in ('node','recall') then
    raise exception 'invalid_answer_input' using errcode='22023';
  end if;
  select * into context_record from argus_private.read_trusted_request_context();
  if context_record.user_id is null or not argus_private.lock_open_member_lifecycle(
    context_record.tenant_id,context_record.lifecycle_id,context_record.user_id
  ) then raise exception 'member_lifecycle_not_open' using errcode='28000'; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(context_record.lifecycle_id::text,0)
  );
  select member.deletion_epoch into member_epoch from argus_app.members member
   where member.tenant_id=context_record.tenant_id
     and member.lifecycle_id=context_record.lifecycle_id
     and member.user_id=context_record.user_id and member.status='active';
  select session.* into requested_session from argus_app.starpath_sessions session
   where session.id=p_session_id
     and session.tenant_id=context_record.tenant_id
     and session.lifecycle_id=context_record.lifecycle_id
     and session.user_id=context_record.user_id for update;
  if requested_session.id is null then
    raise exception 'starpath_session_not_found' using errcode='23514';
  end if;
  select progress.* into progress_record
    from argus_app.starpath_progress_states progress
   where progress.tenant_id=context_record.tenant_id
     and progress.lifecycle_id=context_record.lifecycle_id
     and progress.user_id=context_record.user_id for update;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    pg_catalog.concat_ws(':',p_session_id,p_revision_id,p_question_id,p_option_id,p_attempt_kind),0
  ));
  select receipt.* into existing_receipt
    from argus_private.member_idempotency_records receipt
   where receipt.tenant_id=context_record.tenant_id
     and receipt.lifecycle_id=context_record.lifecycle_id
     and receipt.operation='starpath.answer'
     and receipt.idempotency_key=p_idempotency_key for update;
  select session.id into active_session_id from argus_app.starpath_sessions session
   where session.tenant_id=context_record.tenant_id
     and session.lifecycle_id=context_record.lifecycle_id
     and session.user_id=context_record.user_id and session.state='active';
  if existing_receipt.id is not null then
    if existing_receipt.user_id<>context_record.user_id
       or existing_receipt.deletion_epoch<>member_epoch
       or existing_receipt.request_hash<>p_request_hash then
      raise exception 'idempotency_conflict' using errcode='23514';
    end if;
    return argus_private.starpath_state_snapshot(active_session_id)
      || pg_catalog.jsonb_build_object('commandEffect','idempotent_replay');
  end if;
  if requested_session.state='active' and exists (
    select 1 from argus_app.starpath_curriculum_manifests manifest
     where manifest.id=requested_session.manifest_id and manifest.state='withdrawn'
  ) then
    replacement_session_id:=argus_private.replace_withdrawn_starpath_session(
      requested_session.id,null,null,false
    );
    insert into argus_private.member_idempotency_records(
      tenant_id,lifecycle_id,user_id,deletion_epoch,operation,idempotency_key,
      request_hash,resource_id,response_status,result_type,typed_result
    ) values (
      context_record.tenant_id,context_record.lifecycle_id,context_record.user_id,
      member_epoch,'starpath.answer',p_idempotency_key,p_request_hash,
      replacement_session_id,200,'starpath.answer.v1',
      pg_catalog.jsonb_build_object(
        'sessionId',replacement_session_id,'effect','content_replaced'
      )
    );
    return argus_private.starpath_state_snapshot(replacement_session_id)
      || pg_catalog.jsonb_build_object('commandEffect','content_replaced');
  end if;
  if requested_session.state<>'active' or requested_session.manifest_id<>p_manifest_id then
    raise exception 'starpath_session_not_active' using errcode='23514';
  end if;
  if progress_record.progress_version<>p_expected_progress_version then
    raise exception 'starpath_progress_version_conflict' using errcode='40001';
  end if;
  select node.lesson_id,node.node_ordinal,option.is_correct,option.explanation
    into option_record
    from argus_app.starpath_manifest_nodes node
    join argus_app.starpath_knowledge_check_options option
      on option.lesson_id=node.lesson_id and option.revision_id=node.revision_id
   where node.manifest_id=p_manifest_id and node.revision_id=p_revision_id
     and option.question_id=p_question_id and option.id=p_option_id;
  if option_record.lesson_id is null then
    raise exception 'starpath_content_lineage_invalid' using errcode='23514';
  end if;
  if p_attempt_kind='node'
     and option_record.node_ordinal<>progress_record.current_node_ordinal then
    raise exception 'starpath_node_locked' using errcode='23514';
  end if;
  if p_attempt_kind='recall' and not exists (
    select 1 from argus_app.starpath_recall_states recall
     where recall.tenant_id=context_record.tenant_id
       and recall.lifecycle_id=context_record.lifecycle_id
       and recall.user_id=context_record.user_id
       and recall.lesson_id=option_record.lesson_id
       and recall.revision_id=p_revision_id and recall.question_id=p_question_id
       and recall.due_session_id=p_session_id and recall.status='presented'
  ) then
    raise exception 'starpath_recall_not_presented' using errcode='23514';
  end if;

  with inserted as (
    insert into argus_app.starpath_attempts(
      tenant_id,lifecycle_id,user_id,deletion_epoch,session_id,manifest_id,
      lesson_id,revision_id,node_ordinal,question_id,selected_option_id,
      attempt_kind,is_correct
    ) values (
      context_record.tenant_id,context_record.lifecycle_id,context_record.user_id,
      member_epoch,p_session_id,p_manifest_id,option_record.lesson_id,
      p_revision_id,option_record.node_ordinal,p_question_id,p_option_id,
      p_attempt_kind,option_record.is_correct
    ) on conflict do nothing returning id
  ) select exists(select 1 from inserted) into attempt_inserted;

  if attempt_inserted and option_record.is_correct and p_attempt_kind='node' then
    select count(*) into attempt_count from argus_app.starpath_attempts attempt
     where attempt.tenant_id=context_record.tenant_id
       and attempt.lifecycle_id=context_record.lifecycle_id
       and attempt.user_id=context_record.user_id
       and attempt.lesson_id=option_record.lesson_id
       and attempt.question_id=p_question_id and attempt.attempt_kind='node';
    with inserted as (
      insert into argus_app.starpath_lesson_completions(
        tenant_id,lifecycle_id,user_id,deletion_epoch,lesson_id,manifest_id,
        revision_id,node_ordinal,first_session_id,first_attempt_correct
      ) values (
        context_record.tenant_id,context_record.lifecycle_id,
        context_record.user_id,member_epoch,option_record.lesson_id,
        p_manifest_id,p_revision_id,option_record.node_ordinal,p_session_id,
        attempt_count=1
      ) on conflict (tenant_id,lifecycle_id,user_id,lesson_id) do nothing
      returning id
    ) select exists(select 1 from inserted) into completion_inserted;
    if completion_inserted then
      update argus_app.starpath_progress_states progress
         set current_node_ordinal=least(progress.current_node_ordinal+1,9),
             progress_version=progress.progress_version+1,
             updated_at=pg_catalog.clock_timestamp()
       where progress.tenant_id=context_record.tenant_id
         and progress.lifecycle_id=context_record.lifecycle_id
         and progress.user_id=context_record.user_id
         and progress.progress_version=p_expected_progress_version;
      insert into argus_app.starpath_recall_states(
        tenant_id,lifecycle_id,user_id,deletion_epoch,lesson_id,manifest_id,
        revision_id,node_ordinal,question_id
      ) values (
        context_record.tenant_id,context_record.lifecycle_id,
        context_record.user_id,member_epoch,option_record.lesson_id,
        p_manifest_id,p_revision_id,option_record.node_ordinal,p_question_id
      ) on conflict (tenant_id,lifecycle_id,user_id,lesson_id) do nothing;
      effect:='lesson_completed';
    else effect:='semantic_replay'; end if;
  elsif attempt_inserted and option_record.is_correct and p_attempt_kind='recall' then
    update argus_app.starpath_recall_states recall
       set status='completed',completed_at=pg_catalog.clock_timestamp()
     where recall.tenant_id=context_record.tenant_id
       and recall.lifecycle_id=context_record.lifecycle_id
       and recall.user_id=context_record.user_id
       and recall.lesson_id=option_record.lesson_id
       and recall.due_session_id=p_session_id and recall.status='presented';
    update argus_app.starpath_progress_states progress
       set progress_version=progress.progress_version+1,
           updated_at=pg_catalog.clock_timestamp()
     where progress.tenant_id=context_record.tenant_id
       and progress.lifecycle_id=context_record.lifecycle_id
       and progress.user_id=context_record.user_id
       and progress.progress_version=p_expected_progress_version;
    effect:='recall_completed';
  elsif not attempt_inserted then effect:='semantic_replay';
  end if;
  update argus_app.starpath_sessions set last_action_at=pg_catalog.clock_timestamp()
   where id=p_session_id;
  insert into argus_private.member_idempotency_records(
    tenant_id,lifecycle_id,user_id,deletion_epoch,operation,idempotency_key,
    request_hash,resource_id,response_status,result_type,typed_result
  ) values (
    context_record.tenant_id,context_record.lifecycle_id,context_record.user_id,
    member_epoch,'starpath.answer',p_idempotency_key,p_request_hash,p_session_id,
    200,'starpath.answer.v1',pg_catalog.jsonb_build_object(
      'sessionId',p_session_id,'effect',effect,'isCorrect',option_record.is_correct
    )
  );
  return argus_private.starpath_state_snapshot(p_session_id)
    || pg_catalog.jsonb_build_object(
      'commandEffect',effect,
      'answer',pg_catalog.jsonb_build_object(
        'isCorrect',option_record.is_correct,'explanation',option_record.explanation
      )
    );
end
$$;

create or replace function argus_private.skip_starpath_recall(
  p_idempotency_key text,p_request_hash text,p_session_id uuid,
  p_expected_progress_version bigint
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare context_record record;
declare member_epoch bigint;
declare session_record argus_app.starpath_sessions%rowtype;
declare progress_record argus_app.starpath_progress_states%rowtype;
declare existing_receipt argus_private.member_idempotency_records%rowtype;
begin
  if p_idempotency_key!~'^[!-~]{16,128}$' or p_request_hash!~'^[a-f0-9]{64}$' then
    raise exception 'invalid_idempotency_input' using errcode='22023';
  end if;
  select * into context_record from argus_private.read_trusted_request_context();
  if context_record.user_id is null or not argus_private.lock_open_member_lifecycle(
    context_record.tenant_id,context_record.lifecycle_id,context_record.user_id
  ) then raise exception 'member_lifecycle_not_open' using errcode='28000'; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(context_record.lifecycle_id::text,0)
  );
  select member.deletion_epoch into member_epoch from argus_app.members member
   where member.tenant_id=context_record.tenant_id
     and member.lifecycle_id=context_record.lifecycle_id
     and member.user_id=context_record.user_id and member.status='active';
  select session.* into session_record from argus_app.starpath_sessions session
   where session.id=p_session_id
     and session.tenant_id=context_record.tenant_id
     and session.lifecycle_id=context_record.lifecycle_id
     and session.user_id=context_record.user_id for update;
  select progress.* into progress_record from argus_app.starpath_progress_states progress
   where progress.tenant_id=context_record.tenant_id
     and progress.lifecycle_id=context_record.lifecycle_id
     and progress.user_id=context_record.user_id for update;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_session_id::text||':recall-skip',0)
  );
  select receipt.* into existing_receipt
    from argus_private.member_idempotency_records receipt
   where receipt.tenant_id=context_record.tenant_id
     and receipt.lifecycle_id=context_record.lifecycle_id
     and receipt.operation='starpath.recall.skip'
     and receipt.idempotency_key=p_idempotency_key for update;
  if existing_receipt.id is not null then
    if existing_receipt.deletion_epoch<>member_epoch
       or existing_receipt.request_hash<>p_request_hash then
      raise exception 'idempotency_conflict' using errcode='23514';
    end if;
    return argus_private.starpath_state_snapshot(p_session_id)
      || pg_catalog.jsonb_build_object('commandEffect','idempotent_replay');
  end if;
  if session_record.state<>'active' then
    raise exception 'starpath_session_not_active' using errcode='23514';
  end if;
  if progress_record.progress_version<>p_expected_progress_version then
    raise exception 'starpath_progress_version_conflict' using errcode='40001';
  end if;
  update argus_app.starpath_recall_states recall
     set status='skipped',skipped_at=pg_catalog.clock_timestamp()
   where recall.tenant_id=context_record.tenant_id
     and recall.lifecycle_id=context_record.lifecycle_id
     and recall.user_id=context_record.user_id
     and recall.due_session_id=p_session_id and recall.status='presented';
  if not found then raise exception 'starpath_recall_not_presented' using errcode='23514'; end if;
  update argus_app.starpath_progress_states progress
     set progress_version=progress.progress_version+1,
         updated_at=pg_catalog.clock_timestamp()
   where progress.tenant_id=context_record.tenant_id
     and progress.lifecycle_id=context_record.lifecycle_id
     and progress.user_id=context_record.user_id
     and progress.progress_version=p_expected_progress_version;
  update argus_app.starpath_sessions set last_action_at=pg_catalog.clock_timestamp()
   where id=p_session_id;
  insert into argus_private.member_idempotency_records(
    tenant_id,lifecycle_id,user_id,deletion_epoch,operation,idempotency_key,
    request_hash,resource_id,response_status,result_type,typed_result
  ) values (
    context_record.tenant_id,context_record.lifecycle_id,context_record.user_id,
    member_epoch,'starpath.recall.skip',p_idempotency_key,p_request_hash,
    p_session_id,200,'starpath.recall.v1',
    pg_catalog.jsonb_build_object('sessionId',p_session_id,'effect','recall_skipped')
  );
  return argus_private.starpath_state_snapshot(p_session_id)
    || pg_catalog.jsonb_build_object('commandEffect','recall_skipped');
end
$$;

create or replace function argus_private.capture_starpath_retention_snapshot(
  p_as_of timestamptz
)
returns argus_private.starpath_retention_snapshots
language plpgsql security definer set search_path='' as $$
declare snapshot_row argus_private.starpath_retention_snapshots%rowtype;
declare lower_bound timestamptz:=p_as_of-interval '14 days';
declare upper_bound timestamptz:=p_as_of-interval '7 days';
declare denominator bigint;
declare retained bigint;
declare checksum text;
declare actor_id uuid;
begin
  if pg_catalog.current_setting('transaction_isolation')<>'repeatable read' then
    raise exception 'starpath_retention_requires_repeatable_read' using errcode='25001';
  end if;
  if p_as_of is null or p_as_of>pg_catalog.statement_timestamp()
     or p_as_of<pg_catalog.statement_timestamp()-interval '5 seconds'
     or not (select argus_private.has_staff_permission('operations:read')) then
    raise exception 'starpath_retention_not_authorized' using errcode='42501';
  end if;
  actor_id:=(select argus_private.trusted_request_user_id());
  with first_explicit as (
    select distinct on (session.tenant_id,session.lifecycle_id)
      session.tenant_id,session.lifecycle_id,session.started_at,session.id
      from argus_app.starpath_sessions session
     where session.explicit_start
     order by session.tenant_id,session.lifecycle_id,session.started_at,session.id
  ), cohort as (
    select first_explicit.* from first_explicit
     where first_explicit.started_at>=lower_bound
       and first_explicit.started_at<=upper_bound
  ), measured as (
    select cohort.*,
      exists(
        select 1 from argus_app.starpath_sessions later
         where later.tenant_id=cohort.tenant_id
           and later.lifecycle_id=cohort.lifecycle_id and later.explicit_start
           and later.id<>cohort.id
           and later.started_at>cohort.started_at+interval '30 minutes'
           and later.started_at<=cohort.started_at+interval '168 hours'
           and later.started_at<=p_as_of
      ) retained
      from cohort
  )
  select count(*),count(*) filter (where measured.retained)
    into denominator,retained from measured;
  checksum:=pg_catalog.encode(extensions.digest(
    pg_catalog.jsonb_build_object(
      'metricCode','learning_retention_within_7d_v1',
      'definitionVersion','v1','asOf',p_as_of,
      'cohortLowerBound',lower_bound,'cohortUpperBound',upper_bound,
      'maturedDenominator',denominator,'retainedCount',retained
    )::text,'sha256'
  ),'hex');
  insert into argus_private.starpath_retention_snapshots(
    metric_code,definition_version,as_of,cohort_lower_bound,
    cohort_upper_bound,matured_denominator,retained_count,snapshot_checksum,
    deletion_recomputation_note,captured_by
  ) values (
    'learning_retention_within_7d_v1','v1',p_as_of,lower_bound,upper_bound,
    denominator,retained,checksum,
    'Lawful member deletion can make later live recomputation differ; this non-identifying fixed-as-of aggregate remains the recorded evidence.',
    actor_id
  ) returning * into snapshot_row;
  return snapshot_row;
end
$$;

-- Export every normalized member-owned Starpath relation exactly once. The
-- trigger runs immediately after generation creation and before the existing
-- sealing function computes collection counts and checksums.
set local role argus_jobs_owner;
drop trigger reject_privacy_collection_registry_mutation
  on argus_private.privacy_export_collection_registry;
alter table argus_private.privacy_export_collection_registry disable row level security;
update argus_private.privacy_export_collection_registry
   set ordinal=ordinal+100 where ordinal>=25;
update argus_private.privacy_export_collection_registry
   set ordinal=ordinal-95 where ordinal>=125;
insert into argus_private.privacy_export_collection_registry(
  collection_name,ordinal,source_relation,payload_version
) values
  ('starpath_sessions',25,'argus_app.starpath_sessions',1),
  ('starpath_progress',26,'argus_app.starpath_progress_states',1),
  ('starpath_completions',27,'argus_app.starpath_lesson_completions',1),
  ('starpath_attempts',28,'argus_app.starpath_attempts',1),
  ('starpath_recall_states',29,'argus_app.starpath_recall_states',1);
alter table argus_private.privacy_export_collection_registry enable row level security;
alter table argus_private.privacy_export_collection_registry force row level security;
create trigger reject_privacy_collection_registry_mutation
  before update or delete on argus_private.privacy_export_collection_registry
  for each row execute function argus_private.reject_registry_mutation();
reset role;

create or replace function argus_private.export_starpath_generation_rows()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into argus_private.privacy_export_generation_rows
  select new.id,'starpath_sessions',
    pg_catalog.row_number() over(order by session.started_at,session.id),
    pg_catalog.jsonb_build_object(
      'id',session.id,'manifest_id',session.manifest_id,'theme_id',session.theme_id,
      'state',session.state,'started_at',session.started_at,
      'last_action_at',session.last_action_at,'ended_at',session.ended_at,
      'close_reason',session.close_reason,'explicit_start',session.explicit_start,
      'capability_version',session.capability_version_at_start,
      'replacement_of_session_id',session.replacement_of_session_id,
      'replaced_by_session_id',session.replaced_by_session_id
    ),''
    from argus_app.starpath_sessions session
   where session.tenant_id=new.tenant_id and session.lifecycle_id=new.lifecycle_id
     and session.user_id=new.user_id and session.started_at<=new.cutoff_at;
  insert into argus_private.privacy_export_generation_rows
  select new.id,'starpath_progress',1,
    pg_catalog.jsonb_build_object(
      'current_node_ordinal',progress.current_node_ordinal,
      'progress_version',progress.progress_version,'updated_at',progress.updated_at
    ),''
    from argus_app.starpath_progress_states progress
   where progress.tenant_id=new.tenant_id and progress.lifecycle_id=new.lifecycle_id
     and progress.user_id=new.user_id and progress.updated_at<=new.cutoff_at;
  insert into argus_private.privacy_export_generation_rows
  select new.id,'starpath_completions',
    pg_catalog.row_number() over(order by completion.completed_at,completion.id),
    pg_catalog.jsonb_build_object(
      'lesson_id',completion.lesson_id,'manifest_id',completion.manifest_id,
      'revision_id',completion.revision_id,'node_ordinal',completion.node_ordinal,
      'first_session_id',completion.first_session_id,
      'completed_at',completion.completed_at,
      'first_attempt_correct',completion.first_attempt_correct
    ),''
    from argus_app.starpath_lesson_completions completion
   where completion.tenant_id=new.tenant_id
     and completion.lifecycle_id=new.lifecycle_id
     and completion.user_id=new.user_id and completion.completed_at<=new.cutoff_at;
  insert into argus_private.privacy_export_generation_rows
  select new.id,'starpath_attempts',
    pg_catalog.row_number() over(order by attempt.attempted_at,attempt.id),
    pg_catalog.jsonb_build_object(
      'session_id',attempt.session_id,'manifest_id',attempt.manifest_id,
      'lesson_id',attempt.lesson_id,'revision_id',attempt.revision_id,
      'node_ordinal',attempt.node_ordinal,'question_id',attempt.question_id,
      'selected_option_id',attempt.selected_option_id,
      'attempt_kind',attempt.attempt_kind,'is_correct',attempt.is_correct,
      'attempted_at',attempt.attempted_at
    ),''
    from argus_app.starpath_attempts attempt
   where attempt.tenant_id=new.tenant_id and attempt.lifecycle_id=new.lifecycle_id
     and attempt.user_id=new.user_id and attempt.attempted_at<=new.cutoff_at;
  insert into argus_private.privacy_export_generation_rows
  select new.id,'starpath_recall_states',
    pg_catalog.row_number() over(order by recall.due_at,recall.id),
    pg_catalog.jsonb_build_object(
      'lesson_id',recall.lesson_id,'manifest_id',recall.manifest_id,
      'revision_id',recall.revision_id,'node_ordinal',recall.node_ordinal,
      'question_id',recall.question_id,'status',recall.status,
      'due_session_id',recall.due_session_id,'due_at',recall.due_at,
      'presented_at',recall.presented_at,'skipped_at',recall.skipped_at,
      'completed_at',recall.completed_at
    ),''
    from argus_app.starpath_recall_states recall
   where recall.tenant_id=new.tenant_id and recall.lifecycle_id=new.lifecycle_id
     and recall.user_id=new.user_id and recall.due_at<=new.cutoff_at;
  return new;
end
$$;
create trigger export_starpath_generation_rows
  after insert on argus_private.privacy_export_generations
  for each row execute function argus_private.export_starpath_generation_rows();

-- Preserve the audited U6 purge body as a private helper and put the five
-- child-first Starpath deletions in front of it. Jobs can invoke only the new
-- complete wrapper.
grant create on schema argus_private to argus_application_purge_owner;
set local role argus_application_purge_owner;
alter function argus_private.purge_member_application_data(uuid)
  rename to purge_member_application_data_without_starpath;
revoke all on function
  argus_private.purge_member_application_data_without_starpath(uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
  argus_callback,argus_worker,argus_jobs_owner,postgres,argus_app_owner;
reset role;
revoke create on schema argus_private from argus_application_purge_owner;

create or replace function argus_private.purge_member_application_data(
  p_tombstone_id uuid
)
returns integer language plpgsql security definer set search_path='' as $$
declare tombstone_record argus_private.deletion_tombstones%rowtype;
declare purged_tables integer:=0;
begin
  select target.* into tombstone_record
    from argus_private.deletion_tombstones target
   where target.id=p_tombstone_id and target.status='purging'
     and target.purge_phase='storage_purged';
  if tombstone_record.id is null then
    raise exception 'application_purge_scope_invalid' using errcode='23514';
  end if;
  delete from argus_app.starpath_attempts row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.starpath_recall_states row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.starpath_lesson_completions row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.starpath_progress_states row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  delete from argus_app.starpath_sessions row
   where row.tenant_id=tombstone_record.tenant_id
     and row.lifecycle_id=tombstone_record.lifecycle_id
     and row.user_id=tombstone_record.user_id;
  if found then purged_tables:=purged_tables+1; end if;
  return purged_tables
    +argus_private.purge_member_application_data_without_starpath(p_tombstone_id);
end
$$;

grant create on schema argus_private to argus_app_owner;
alter function argus_private.protect_member_idempotency_scope() owner to argus_app_owner;
alter function argus_private.assert_starpath_manifest_theme(uuid,uuid) owner to argus_app_owner;
alter function argus_private.starpath_state_snapshot(uuid) owner to argus_app_owner;
alter function argus_private.create_starpath_session(uuid,uuid,bigint,boolean,uuid) owner to argus_app_owner;
alter function argus_private.replace_withdrawn_starpath_session(uuid,uuid,uuid,boolean) owner to argus_app_owner;
alter function argus_private.start_or_resume_starpath_session(text,text,uuid,uuid,bigint) owner to argus_app_owner;
alter function argus_private.read_starpath_state(uuid,uuid) owner to argus_app_owner;
alter function argus_private.answer_starpath_question(text,text,uuid,uuid,uuid,uuid,uuid,bigint,text) owner to argus_app_owner;
alter function argus_private.skip_starpath_recall(text,text,uuid,bigint) owner to argus_app_owner;
alter function argus_private.capture_starpath_retention_snapshot(timestamptz) owner to argus_app_owner;
revoke create on schema argus_private from argus_app_owner;

grant create on schema argus_private to argus_jobs_owner;
alter function argus_private.export_starpath_generation_rows() owner to argus_jobs_owner;
revoke create on schema argus_private from argus_jobs_owner;

grant create on schema argus_private to argus_application_purge_owner;
alter function argus_private.purge_member_application_data(uuid)
  owner to argus_application_purge_owner;
revoke create on schema argus_private from argus_application_purge_owner;

do $$
declare function_signature regprocedure;
begin
  foreach function_signature in array array[
    'argus_private.protect_member_idempotency_scope()'::regprocedure,
    'argus_private.assert_starpath_manifest_theme(uuid,uuid)'::regprocedure,
    'argus_private.starpath_state_snapshot(uuid)'::regprocedure,
    'argus_private.create_starpath_session(uuid,uuid,bigint,boolean,uuid)'::regprocedure,
    'argus_private.replace_withdrawn_starpath_session(uuid,uuid,uuid,boolean)'::regprocedure,
    'argus_private.start_or_resume_starpath_session(text,text,uuid,uuid,bigint)'::regprocedure,
    'argus_private.read_starpath_state(uuid,uuid)'::regprocedure,
    'argus_private.answer_starpath_question(text,text,uuid,uuid,uuid,uuid,uuid,bigint,text)'::regprocedure,
    'argus_private.skip_starpath_recall(text,text,uuid,bigint)'::regprocedure,
    'argus_private.capture_starpath_retention_snapshot(timestamptz)'::regprocedure,
    'argus_private.export_starpath_generation_rows()'::regprocedure,
    'argus_private.purge_member_application_data(uuid)'::regprocedure,
    'argus_private.purge_member_application_data_without_starpath(uuid)'::regprocedure
  ] loop
    execute pg_catalog.format(
      'revoke all on function %s from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker,argus_jobs_owner,postgres,argus_app_owner',
      function_signature
    );
  end loop;
end
$$;

grant execute on function
  argus_private.assert_starpath_manifest_theme(uuid,uuid),
  argus_private.starpath_state_snapshot(uuid),
  argus_private.create_starpath_session(uuid,uuid,bigint,boolean,uuid),
  argus_private.replace_withdrawn_starpath_session(uuid,uuid,uuid,boolean)
to argus_app_owner;
set local role argus_identity_owner;
grant execute on function
  argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)
to argus_app_owner;
reset role;
grant execute on function
  argus_private.start_or_resume_starpath_session(text,text,uuid,uuid,bigint),
  argus_private.read_starpath_state(uuid,uuid),
  argus_private.answer_starpath_question(text,text,uuid,uuid,uuid,uuid,uuid,bigint,text),
  argus_private.skip_starpath_recall(text,text,uuid,bigint)
to argus_member;
grant execute on function
  argus_private.capture_starpath_retention_snapshot(timestamptz)
to argus_staff;
grant execute on function
  argus_private.purge_member_application_data(uuid)
to argus_application_purge_owner,argus_jobs_owner;

comment on table argus_app.starpath_attempts is
  'Exact server-scored Starpath answer facts; free-form rationale is intentionally absent.';
comment on table argus_private.starpath_retention_snapshots is
  'Non-identifying fixed-as-of learning_retention_within_7d_v1 evidence; lawful deletion can change later live recomputation.';
comment on function argus_private.start_or_resume_starpath_session(text,text,uuid,uuid,bigint) is
  'Lifecycle-serialized online explicit Starpath start/resume; exactly 30 minutes resumes and later creates one new session.';
comment on function argus_private.answer_starpath_question(text,text,uuid,uuid,uuid,uuid,uuid,bigint,text) is
  'Idempotent server-scored Starpath answer command with canonical progress-version precondition.';
comment on function argus_private.purge_member_application_data(uuid) is
  'Deletes Starpath plus the complete fixed U6 application-data inventory for an eligible tombstone.';

do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_app_owner,argus_jobs_owner,argus_application_purge_owner,argus_identity_owner from %I',
    current_user
  );
end
$membership$;

commit;

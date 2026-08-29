begin;

-- U4 owns Argus application/editorial state only. Brokerage, callbacks,
-- queues, privacy artifacts, Storage and private durable-work relations remain
-- on the documented U5/U6 compatibility bridge.
do $$
begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname='argus_app_owner') then
    create role argus_app_owner
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_catalog.pg_roles where rolname='argus_publication_owner') then
    create role argus_publication_owner
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
end
$$;

grant usage on schema argus_app,argus_private,extensions to argus_app_owner;
grant usage on schema argus_app,argus_private to argus_publication_owner;

-- The U3 lifecycle parent is intentionally owned by the NOLOGIN identity
-- owner. Temporarily hand only REFERENCES to this migration session while U4
-- authors its child FKs, then revoke both the object privilege and role handoff.
grant argus_identity_owner to current_user with set true;
set local role argus_identity_owner;
grant select on table argus_app.member_lifecycles to argus_app_owner;
-- U6's retained worker writers invoke the U4 lifecycle-binding trigger for
-- briefings and other member-facing projections. They may resolve only open
-- lifecycle parents; the child relation's worker policy still constrains the
-- concrete event/user write.
grant select on table argus_app.member_lifecycles to argus_worker;
-- The app owner invokes the three scalar trusted-context helpers directly;
-- their SECURITY INVOKER implementation also calls the row-shaped reader.
-- The migration/session owner retains only the user-id path needed by the
-- separately owned staff authorization definers below.
grant execute on function
  argus_private.read_trusted_request_context(),
  argus_private.trusted_request_user_id(),
  argus_private.trusted_request_tenant_id(),
  argus_private.trusted_request_lifecycle_id()
to argus_app_owner;
do $$
begin
  execute pg_catalog.format(
    'grant execute on function argus_private.read_trusted_request_context(), argus_private.trusted_request_user_id() to %I',
    session_user
  );
end
$$;
create policy u4_app_owner_current_lifecycle
  on argus_app.member_lifecycles
  for select to argus_app_owner
  using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and id=(select argus_private.trusted_request_lifecycle_id())
    and identity_subject_id=(select argus_private.trusted_request_user_id())
    and state='open'
  );
create policy u4_worker_open_lifecycle_binding
  on argus_app.member_lifecycles
  for select to argus_worker
  using (state='open');
do $$
begin
  execute pg_catalog.format(
    'grant references on table argus_app.member_lifecycles to %I',
    session_user
  );
end
$$;
reset role;

create table argus_app.legacy_normalization_quarantine (
  id uuid primary key default extensions.gen_random_uuid(),
  source_relation text not null,
  source_identity text not null,
  cohort text not null,
  reason_code text not null,
  source_fingerprint text not null check (source_fingerprint ~ '^[a-f0-9]{64}$'),
  source_cardinality integer check (source_cardinality is null or source_cardinality >= 0),
  quarantined_at timestamptz not null default pg_catalog.clock_timestamp(),
  unique (source_relation,source_identity,cohort,reason_code)
);

create table argus_app.legacy_normalization_identity_map (
  source_relation text not null,
  source_identity text not null,
  target_relation text not null,
  target_identity text not null,
  source_fingerprint text not null check (source_fingerprint ~ '^[a-f0-9]{64}$'),
  source_cardinality integer not null check (source_cardinality >= 0),
  target_cardinality integer not null check (target_cardinality >= 0),
  mapped_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key (source_relation,source_identity,target_relation),
  unique (target_relation,target_identity),
  check (source_cardinality=target_cardinality)
);

-- Bind every U4-owned member child to the immutable U3 tenant+lifecycle
-- parent. deletion_epoch remains a derived, read-only compatibility column.
do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'profiles','preferences','astrology_profiles','investor_profiles',
    'onboarding_states','consent_records','notification_preferences',
    'daily_ritual_assignments','circles','circle_assets','saved_items',
    'intentions','future_mirror_runs','future_mirror_points','briefings',
    'briefing_sections','briefing_read_states','notifications','content_reports'
  ] loop
    execute pg_catalog.format(
      'alter table argus_app.%I add column tenant_id uuid, add column lifecycle_id uuid',
      relation_name
    );
    execute pg_catalog.format(
      'update argus_app.%I child set tenant_id=member.tenant_id,lifecycle_id=member.lifecycle_id from argus_app.members member where member.user_id=child.user_id',
      relation_name
    );
    execute pg_catalog.format(
      'alter table argus_app.%I alter column tenant_id set not null, alter column lifecycle_id set not null',
      relation_name
    );
    execute pg_catalog.format(
      'alter table argus_app.%I add constraint %I foreign key (tenant_id,lifecycle_id) references argus_app.member_lifecycles(tenant_id,id) on delete restrict, add constraint %I foreign key (user_id,lifecycle_id) references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict',
      relation_name,relation_name||'_u4_tenant_lifecycle_fk',
      relation_name||'_u4_subject_lifecycle_fk'
    );
    execute pg_catalog.format(
      'create index %I on argus_app.%I(tenant_id,lifecycle_id,user_id)',
      relation_name||'_u4_lifecycle_idx',relation_name
    );
    execute pg_catalog.format(
      'create index %I on argus_app.%I(user_id,lifecycle_id)',
      relation_name||'_u4_subject_lifecycle_idx',relation_name
    );
    execute pg_catalog.format(
      'drop trigger if exists enforce_live_member_epoch on argus_app.%I',
      relation_name
    );
  end loop;
end
$$;

create or replace function argus_private.bind_argus_app_member_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare retained_tenant_id uuid;
declare retained_lifecycle_id uuid;
declare retained_deletion_epoch bigint;
begin
  select member.tenant_id,member.lifecycle_id,member.deletion_epoch
    into retained_tenant_id,retained_lifecycle_id,retained_deletion_epoch
    from argus_app.members member
    join argus_app.member_lifecycles lifecycle
      on lifecycle.tenant_id=member.tenant_id
     and lifecycle.id=member.lifecycle_id
     and lifecycle.identity_subject_id=member.user_id
   where member.user_id=new.user_id
     and member.status='active' and lifecycle.state='open';

  if retained_lifecycle_id is null then
    raise exception 'inactive_member_lifecycle' using errcode='28000';
  end if;
  if new.tenant_id is not null and new.tenant_id<>retained_tenant_id
     or new.lifecycle_id is not null and new.lifecycle_id<>retained_lifecycle_id then
    raise exception 'member_lifecycle_mismatch' using errcode='42501';
  end if;
  if tg_op='UPDATE' and (
       old.tenant_id<>retained_tenant_id
       or old.lifecycle_id<>retained_lifecycle_id
       or old.user_id<>new.user_id
     ) then
    raise exception 'member_lifecycle_binding_immutable' using errcode='23514';
  end if;
  new.tenant_id:=retained_tenant_id;
  new.lifecycle_id:=retained_lifecycle_id;
  new.deletion_epoch:=retained_deletion_epoch;
  return new;
end
$$;

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'profiles','preferences','astrology_profiles','investor_profiles',
    'onboarding_states','consent_records','notification_preferences',
    'daily_ritual_assignments','circles','circle_assets','saved_items',
    'intentions','future_mirror_runs','future_mirror_points','briefings',
    'briefing_sections','briefing_read_states','notifications','content_reports'
  ] loop
    execute pg_catalog.format(
      'create trigger bind_argus_app_member_lifecycle before insert or update on argus_app.%I for each row execute function argus_private.bind_argus_app_member_lifecycle()',
      relation_name
    );
  end loop;
end
$$;

create unique index onboarding_states_u4_parent_unique
  on argus_app.onboarding_states(tenant_id,lifecycle_id,user_id);
create unique index notification_preferences_u4_parent_unique
  on argus_app.notification_preferences(tenant_id,lifecycle_id,user_id);
create unique index daily_ritual_assignments_u4_parent_unique
  on argus_app.daily_ritual_assignments(tenant_id,lifecycle_id,id);
create unique index circles_u4_parent_unique
  on argus_app.circles(tenant_id,lifecycle_id,id);
create unique index intentions_u4_parent_unique
  on argus_app.intentions(tenant_id,lifecycle_id,id);
create unique index future_mirror_runs_u4_parent_unique
  on argus_app.future_mirror_runs(tenant_id,lifecycle_id,id);
create unique index briefings_u4_parent_unique
  on argus_app.briefings(tenant_id,lifecycle_id,id);
create unique index content_reports_u4_parent_unique
  on argus_app.content_reports(tenant_id,lifecycle_id,id);
create index notifications_u4_owner_order_idx
  on argus_app.notifications(tenant_id,lifecycle_id,created_at desc,id desc);
create index briefings_u4_owner_ready_order_idx
  on argus_app.briefings(tenant_id,lifecycle_id,status,period_end desc,id desc);
create index daily_ritual_assignments_u4_owner_order_idx
  on argus_app.daily_ritual_assignments(
    tenant_id,lifecycle_id,local_date desc,id desc
  );
create index circles_u4_owner_order_idx
  on argus_app.circles(tenant_id,lifecycle_id,archived_at nulls first,id);
create index editorial_items_u4_published_order_idx
  on argus_app.editorial_items(kind,slug,id)
  where status='published';

alter table argus_app.circle_assets
  add constraint circle_assets_u4_parent_fk
    foreign key (tenant_id,lifecycle_id,circle_id)
    references argus_app.circles(tenant_id,lifecycle_id,id) on delete cascade;
alter table argus_app.future_mirror_runs
  add constraint future_mirror_runs_u4_intention_fk
    foreign key (tenant_id,lifecycle_id,intention_id)
    references argus_app.intentions(tenant_id,lifecycle_id,id) on delete cascade;
alter table argus_app.future_mirror_points
  add constraint future_mirror_points_u4_run_fk
    foreign key (tenant_id,lifecycle_id,run_id)
    references argus_app.future_mirror_runs(tenant_id,lifecycle_id,id) on delete cascade;
alter table argus_app.briefing_sections
  add constraint briefing_sections_u4_briefing_fk
    foreign key (tenant_id,lifecycle_id,briefing_id)
    references argus_app.briefings(tenant_id,lifecycle_id,id) on delete cascade;
alter table argus_app.briefing_read_states
  add constraint briefing_read_states_u4_briefing_fk
    foreign key (tenant_id,lifecycle_id,briefing_id)
    references argus_app.briefings(tenant_id,lifecycle_id,id) on delete cascade;
create index circle_assets_u4_parent_idx
  on argus_app.circle_assets(tenant_id,lifecycle_id,circle_id);
create index future_mirror_runs_u4_intention_idx
  on argus_app.future_mirror_runs(tenant_id,lifecycle_id,intention_id);
create index future_mirror_points_u4_run_idx
  on argus_app.future_mirror_points(tenant_id,lifecycle_id,run_id);
create index briefing_sections_u4_briefing_idx
  on argus_app.briefing_sections(tenant_id,lifecycle_id,briefing_id);
create index briefing_read_states_u4_briefing_idx
  on argus_app.briefing_read_states(tenant_id,lifecycle_id,briefing_id);

create table argus_app.onboarding_step_completions (
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  onboarding_user_id uuid not null,
  step_code text not null check (step_code in ('welcome','investing','ritual','astrology','consents','complete')),
  ordinal integer not null check (ordinal between 1 and 6),
  completed_at timestamptz,
  primary key (tenant_id,lifecycle_id,onboarding_user_id,step_code),
  unique (tenant_id,lifecycle_id,onboarding_user_id,ordinal),
  foreign key (tenant_id,lifecycle_id,onboarding_user_id)
    references argus_app.onboarding_states(tenant_id,lifecycle_id,user_id)
    on delete cascade
);

create table argus_app.notification_quiet_hours (
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  preference_user_id uuid not null,
  timezone_name text not null check (pg_catalog.char_length(timezone_name) between 1 and 64),
  starts_at time not null,
  ends_at time not null,
  primary key (tenant_id,lifecycle_id,preference_user_id),
  foreign key (tenant_id,lifecycle_id,preference_user_id)
    references argus_app.notification_preferences(tenant_id,lifecycle_id,user_id)
    on delete cascade,
  check (starts_at<>ends_at)
);

create table argus_app.member_saved_items (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  item_kind text not null check (item_kind in ('asset','grimoire','circle_template','coven')),
  asset_id uuid references argus_app.catalog_assets(id) on delete restrict,
  grimoire_id uuid references argus_app.grimoires(id) on delete restrict,
  circle_template_id uuid references argus_app.community_templates(id) on delete restrict,
  coven_entry_id uuid references argus_app.coven_entries(id) on delete restrict,
  source_kind text not null default 'direct'
    check (source_kind in ('direct','ritual','circle','discover','search')),
  source_ritual_assignment_id uuid,
  source_circle_id uuid,
  source_editorial_item_id uuid references argus_app.editorial_items(id) on delete set null,
  source_catalog_asset_id uuid references argus_app.catalog_assets(id) on delete set null,
  saved_at timestamptz not null default pg_catalog.clock_timestamp(),
  unique (tenant_id,lifecycle_id,id),
  foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict,
  foreign key (tenant_id,lifecycle_id,source_ritual_assignment_id)
    references argus_app.daily_ritual_assignments(tenant_id,lifecycle_id,id) on delete restrict,
  foreign key (tenant_id,lifecycle_id,source_circle_id)
    references argus_app.circles(tenant_id,lifecycle_id,id) on delete restrict,
  check (case item_kind
    when 'asset' then num_nonnulls(asset_id,grimoire_id,circle_template_id,coven_entry_id)=1 and asset_id is not null
    when 'grimoire' then num_nonnulls(asset_id,grimoire_id,circle_template_id,coven_entry_id)=1 and grimoire_id is not null
    when 'circle_template' then num_nonnulls(asset_id,grimoire_id,circle_template_id,coven_entry_id)=1 and circle_template_id is not null
    when 'coven' then num_nonnulls(asset_id,grimoire_id,circle_template_id,coven_entry_id)=1 and coven_entry_id is not null
    else false end),
  check (case source_kind
    when 'direct' then num_nonnulls(source_ritual_assignment_id,source_circle_id,source_editorial_item_id,source_catalog_asset_id)=0
    when 'ritual' then source_ritual_assignment_id is not null and num_nonnulls(source_ritual_assignment_id,source_circle_id,source_editorial_item_id,source_catalog_asset_id)=1
    when 'circle' then source_circle_id is not null and num_nonnulls(source_ritual_assignment_id,source_circle_id,source_editorial_item_id,source_catalog_asset_id)=1
    when 'discover' then source_editorial_item_id is not null and num_nonnulls(source_ritual_assignment_id,source_circle_id,source_editorial_item_id,source_catalog_asset_id)=1
    when 'search' then num_nonnulls(source_ritual_assignment_id,source_circle_id,source_editorial_item_id,source_catalog_asset_id)=1 and (source_editorial_item_id is not null or source_catalog_asset_id is not null)
    else false end)
);
create unique index member_saved_items_asset_unique
  on argus_app.member_saved_items(tenant_id,lifecycle_id,asset_id) where asset_id is not null;
create unique index member_saved_items_grimoire_unique
  on argus_app.member_saved_items(tenant_id,lifecycle_id,grimoire_id) where grimoire_id is not null;
create unique index member_saved_items_template_unique
  on argus_app.member_saved_items(tenant_id,lifecycle_id,circle_template_id) where circle_template_id is not null;
create unique index member_saved_items_coven_unique
  on argus_app.member_saved_items(tenant_id,lifecycle_id,coven_entry_id) where coven_entry_id is not null;
create index member_saved_items_owner_order_idx
  on argus_app.member_saved_items(tenant_id,lifecycle_id,saved_at desc,id desc);
create index member_saved_items_subject_lifecycle_idx
  on argus_app.member_saved_items(user_id,lifecycle_id);
create index member_saved_items_ritual_source_idx
  on argus_app.member_saved_items(tenant_id,lifecycle_id,source_ritual_assignment_id)
  where source_ritual_assignment_id is not null;
create index member_saved_items_circle_source_idx
  on argus_app.member_saved_items(tenant_id,lifecycle_id,source_circle_id)
  where source_circle_id is not null;
create index member_saved_items_editorial_source_idx
  on argus_app.member_saved_items(source_editorial_item_id)
  where source_editorial_item_id is not null;
create index member_saved_items_catalog_source_idx
  on argus_app.member_saved_items(source_catalog_asset_id)
  where source_catalog_asset_id is not null;
create index member_saved_items_asset_target_idx
  on argus_app.member_saved_items(asset_id) where asset_id is not null;
create index member_saved_items_grimoire_target_idx
  on argus_app.member_saved_items(grimoire_id) where grimoire_id is not null;
create index member_saved_items_template_target_idx
  on argus_app.member_saved_items(circle_template_id) where circle_template_id is not null;
create index member_saved_items_coven_target_idx
  on argus_app.member_saved_items(coven_entry_id) where coven_entry_id is not null;

set local role argus_identity_owner;
do $$
begin
  execute pg_catalog.format(
    'revoke references on table argus_app.member_lifecycles from %I',
    session_user
  );
end
$$;
reset role;
revoke argus_identity_owner from current_user;

create table argus_app.content_report_targets (
  report_id uuid primary key,
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  target_kind text not null check (target_kind in ('editorial','asset','grimoire','circle_template','coven')),
  editorial_item_id uuid references argus_app.editorial_items(id) on delete restrict,
  asset_id uuid references argus_app.catalog_assets(id) on delete restrict,
  grimoire_id uuid references argus_app.grimoires(id) on delete restrict,
  circle_template_id uuid references argus_app.community_templates(id) on delete restrict,
  coven_entry_id uuid references argus_app.coven_entries(id) on delete restrict,
  foreign key (tenant_id,lifecycle_id,report_id)
    references argus_app.content_reports(tenant_id,lifecycle_id,id) on delete cascade,
  check (case target_kind
    when 'editorial' then editorial_item_id is not null and num_nonnulls(editorial_item_id,asset_id,grimoire_id,circle_template_id,coven_entry_id)=1
    when 'asset' then asset_id is not null and num_nonnulls(editorial_item_id,asset_id,grimoire_id,circle_template_id,coven_entry_id)=1
    when 'grimoire' then grimoire_id is not null and num_nonnulls(editorial_item_id,asset_id,grimoire_id,circle_template_id,coven_entry_id)=1
    when 'circle_template' then circle_template_id is not null and num_nonnulls(editorial_item_id,asset_id,grimoire_id,circle_template_id,coven_entry_id)=1
    when 'coven' then coven_entry_id is not null and num_nonnulls(editorial_item_id,asset_id,grimoire_id,circle_template_id,coven_entry_id)=1
    else false end)
);
create index content_report_targets_lifecycle_idx
  on argus_app.content_report_targets(tenant_id,lifecycle_id,report_id);
create index content_report_targets_editorial_idx
  on argus_app.content_report_targets(editorial_item_id) where editorial_item_id is not null;
create index content_report_targets_asset_idx
  on argus_app.content_report_targets(asset_id) where asset_id is not null;
create index content_report_targets_grimoire_idx
  on argus_app.content_report_targets(grimoire_id) where grimoire_id is not null;
create index content_report_targets_template_idx
  on argus_app.content_report_targets(circle_template_id) where circle_template_id is not null;
create index content_report_targets_coven_idx
  on argus_app.content_report_targets(coven_entry_id) where coven_entry_id is not null;

-- Parent-qualified editorial identities make cross-item revision pointers
-- impossible at the constraint boundary.
alter table argus_app.editorial_revisions
  add constraint editorial_revisions_item_id_id_unique unique (item_id,id),
  add column payload_schema_version integer not null default 1
    check (payload_schema_version=1),
  add column payload_byte_size integer generated always as
    (pg_catalog.octet_length(payload::text)) stored,
  add column payload_canonical_hash text generated always as
    (pg_catalog.encode(extensions.digest(payload::text,'sha256'),'hex')) stored,
  add constraint editorial_revision_payload_size
    check (payload_byte_size between 2 and 1048576),
  add constraint editorial_revision_payload_hash
    check (payload_canonical_hash ~ '^[a-f0-9]{64}$');

alter table argus_app.editorial_items
  drop constraint editorial_current_revision_fk,
  add constraint editorial_current_revision_fk
    foreign key (id,current_published_revision_id)
    references argus_app.editorial_revisions(item_id,id)
    deferrable initially deferred;

alter table argus_app.publication_events
  drop constraint publication_events_revision_id_fkey,
  add constraint publication_events_item_revision_fk
    foreign key (item_id,revision_id)
    references argus_app.editorial_revisions(item_id,id) on delete restrict;
create index publication_events_revision_idx
  on argus_app.publication_events(item_id,revision_id,effective_at desc);

alter table argus_app.ritual_scenario_revisions
  add column editorial_item_id uuid;
update argus_app.ritual_scenario_revisions scenario
   set editorial_item_id=revision.item_id
  from argus_app.editorial_revisions revision
 where revision.id=scenario.revision_id;
alter table argus_app.ritual_scenario_revisions
  alter column editorial_item_id set not null,
  add constraint ritual_scenario_revisions_item_revision_fk
    foreign key (editorial_item_id,revision_id)
    references argus_app.editorial_revisions(item_id,id) on delete cascade,
  add constraint ritual_scenario_revisions_item_fk
    foreign key (editorial_item_id)
    references argus_app.ritual_scenarios(editorial_item_id) on delete cascade,
  add constraint ritual_scenario_revisions_item_revision_unique
    unique (editorial_item_id,revision_id);

create table argus_app.editorial_render_documents (
  item_id uuid not null,
  revision_id uuid primary key,
  schema_version integer not null default 1 check (schema_version=1),
  document jsonb not null check (jsonb_typeof(document)='object'),
  document_hash text generated always as
    (pg_catalog.encode(extensions.digest(document::text,'sha256'),'hex')) stored,
  byte_size integer generated always as (pg_catalog.octet_length(document::text)) stored,
  sealed_at timestamptz not null default pg_catalog.clock_timestamp(),
  foreign key (item_id,revision_id)
    references argus_app.editorial_revisions(item_id,id) on delete restrict,
  check (byte_size between 2 and 1048576),
  check (document_hash ~ '^[a-f0-9]{64}$')
);
create index editorial_render_documents_item_idx
  on argus_app.editorial_render_documents(item_id,revision_id);

create table argus_app.editorial_revision_assets (
  item_id uuid not null,
  revision_id uuid not null,
  asset_id uuid not null references argus_app.catalog_assets(id) on delete restrict,
  ordinal integer not null check (ordinal between 1 and 100),
  primary key (item_id,revision_id,asset_id),
  unique (item_id,revision_id,ordinal),
  foreign key (item_id,revision_id)
    references argus_app.editorial_revisions(item_id,id) on delete cascade
);
create index editorial_revision_assets_asset_idx
  on argus_app.editorial_revision_assets(asset_id,item_id,revision_id);

create unique index grimoires_u4_item_parent_unique
  on argus_app.grimoires(id,editorial_item_id);
create unique index community_templates_u4_item_parent_unique
  on argus_app.community_templates(id,editorial_item_id);
create unique index coven_entries_u4_item_parent_unique
  on argus_app.coven_entries(id,editorial_item_id);

create table argus_app.ritual_scenario_revision_assets (
  editorial_item_id uuid not null,
  revision_id uuid not null,
  asset_id uuid not null references argus_app.catalog_assets(id) on delete restrict,
  ordinal integer not null check (ordinal between 1 and 5),
  primary key (editorial_item_id,revision_id,asset_id),
  unique (editorial_item_id,revision_id,ordinal),
  foreign key (editorial_item_id,revision_id)
    references argus_app.ritual_scenario_revisions(editorial_item_id,revision_id)
    on delete cascade
);
create index ritual_scenario_revision_assets_asset_idx
  on argus_app.ritual_scenario_revision_assets(asset_id,editorial_item_id,revision_id);

create table argus_app.ritual_scenario_revision_evidence (
  editorial_item_id uuid not null,
  revision_id uuid not null,
  evidence_claim_id uuid not null references argus_app.evidence_claims(id) on delete restrict,
  ordinal integer not null check (ordinal between 1 and 100),
  primary key (editorial_item_id,revision_id,evidence_claim_id),
  unique (editorial_item_id,revision_id,ordinal),
  foreign key (editorial_item_id,revision_id)
    references argus_app.ritual_scenario_revisions(editorial_item_id,revision_id)
    on delete cascade
);
create index ritual_scenario_revision_evidence_claim_idx
  on argus_app.ritual_scenario_revision_evidence(evidence_claim_id,editorial_item_id,revision_id);

create table argus_app.grimoire_revision_assets (
  grimoire_id uuid not null,
  editorial_item_id uuid not null,
  revision_id uuid not null,
  asset_id uuid not null references argus_app.catalog_assets(id) on delete restrict,
  ordinal integer not null check (ordinal between 1 and 100),
  primary key (grimoire_id,revision_id,asset_id),
  unique (grimoire_id,revision_id,ordinal),
  foreign key (grimoire_id,editorial_item_id)
    references argus_app.grimoires(id,editorial_item_id) on delete cascade,
  foreign key (editorial_item_id,revision_id)
    references argus_app.editorial_revisions(item_id,id) on delete cascade
);
create index grimoire_revision_assets_revision_idx
  on argus_app.grimoire_revision_assets(editorial_item_id,revision_id,ordinal);
create index grimoire_revision_assets_parent_idx
  on argus_app.grimoire_revision_assets(grimoire_id,editorial_item_id);
create index grimoire_revision_assets_asset_idx
  on argus_app.grimoire_revision_assets(asset_id,editorial_item_id,revision_id);

create table argus_app.community_template_revision_assets (
  template_id uuid not null,
  editorial_item_id uuid not null,
  revision_id uuid not null,
  asset_id uuid not null references argus_app.catalog_assets(id) on delete restrict,
  ordinal integer not null check (ordinal between 1 and 50),
  primary key (template_id,revision_id,asset_id),
  unique (template_id,revision_id,ordinal),
  foreign key (template_id,editorial_item_id)
    references argus_app.community_templates(id,editorial_item_id) on delete cascade,
  foreign key (editorial_item_id,revision_id)
    references argus_app.editorial_revisions(item_id,id) on delete cascade
);
create index community_template_revision_assets_revision_idx
  on argus_app.community_template_revision_assets(editorial_item_id,revision_id,ordinal);
create index community_template_revision_assets_parent_idx
  on argus_app.community_template_revision_assets(template_id,editorial_item_id);
create index community_template_revision_assets_asset_idx
  on argus_app.community_template_revision_assets(asset_id,editorial_item_id,revision_id);

create table argus_app.coven_qualifications (
  id uuid primary key default extensions.gen_random_uuid(),
  coven_entry_id uuid not null,
  editorial_item_id uuid not null,
  revision_id uuid not null,
  ordinal integer not null check (ordinal between 1 and 20),
  schema_version integer not null default 1 check (schema_version=1),
  criterion_code text not null check (criterion_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  claim text not null check (pg_catalog.char_length(claim) between 1 and 2000),
  evidence_claim_id uuid references argus_app.evidence_claims(id) on delete restrict,
  unique (coven_entry_id,revision_id,ordinal),
  foreign key (coven_entry_id,editorial_item_id)
    references argus_app.coven_entries(id,editorial_item_id) on delete cascade,
  foreign key (editorial_item_id,revision_id)
    references argus_app.editorial_revisions(item_id,id) on delete cascade
);
create index coven_qualifications_revision_idx
  on argus_app.coven_qualifications(editorial_item_id,revision_id,ordinal);
create index coven_qualifications_evidence_idx
  on argus_app.coven_qualifications(evidence_claim_id) where evidence_claim_id is not null;
create index coven_qualifications_parent_idx
  on argus_app.coven_qualifications(coven_entry_id,editorial_item_id);

create table argus_app.asset_codex_revisions (
  editorial_item_id uuid not null,
  revision_id uuid primary key,
  asset_id uuid not null references argus_app.catalog_assets(id) on delete restrict,
  metrics_as_of timestamptz,
  unique (editorial_item_id,revision_id),
  foreign key (editorial_item_id,revision_id)
    references argus_app.editorial_revisions(item_id,id) on delete cascade
);
create index asset_codex_revisions_asset_idx
  on argus_app.asset_codex_revisions(asset_id,revision_id);

create table argus_app.asset_codex_revision_evidence (
  editorial_item_id uuid not null,
  revision_id uuid not null,
  evidence_claim_id uuid not null references argus_app.evidence_claims(id) on delete restrict,
  ordinal integer not null check (ordinal between 1 and 100),
  primary key (revision_id,evidence_claim_id),
  unique (revision_id,ordinal),
  foreign key (editorial_item_id,revision_id)
    references argus_app.asset_codex_revisions(editorial_item_id,revision_id)
    on delete cascade
);
create index asset_codex_revision_evidence_parent_idx
  on argus_app.asset_codex_revision_evidence(editorial_item_id,revision_id);
create index asset_codex_revision_evidence_claim_idx
  on argus_app.asset_codex_revision_evidence(evidence_claim_id,revision_id);

create table argus_app.asset_codex_revision_metrics (
  id uuid primary key default extensions.gen_random_uuid(),
  editorial_item_id uuid not null,
  revision_id uuid not null,
  ordinal integer not null check (ordinal between 1 and 90),
  observed_at timestamptz not null,
  price_minor bigint check (price_minor is null or price_minor>=0),
  change_bps integer,
  expense_ratio_bps integer check (expense_ratio_bps is null or expense_ratio_bps>=0),
  source_label text not null check (pg_catalog.char_length(source_label) between 1 and 160),
  unique (revision_id,ordinal),
  foreign key (editorial_item_id,revision_id)
    references argus_app.asset_codex_revisions(editorial_item_id,revision_id)
    on delete cascade,
  check (num_nonnulls(price_minor,change_bps,expense_ratio_bps)>=1)
);
create index asset_codex_revision_metrics_revision_idx
  on argus_app.asset_codex_revision_metrics(editorial_item_id,revision_id,ordinal);

-- Retained JSON documents are bounded/versioned and immutable at their owned
-- lifecycle boundary. They remain rendering/calculation evidence, never
-- relationship or authorization authority.
alter table argus_app.future_mirror_runs
  add column assumption_schema_version integer not null default 1 check (assumption_schema_version=1),
  add column assumption_byte_size integer generated always as
    (pg_catalog.octet_length(assumptions::text)) stored,
  add column assumption_hash text generated always as
    (pg_catalog.encode(extensions.digest(assumptions::text,'sha256'),'hex')) stored,
  add constraint future_mirror_assumption_size check (assumption_byte_size between 2 and 65536),
  add constraint future_mirror_assumption_hash check (assumption_hash ~ '^[a-f0-9]{64}$');

alter table argus_app.briefing_sections
  add column document_schema_version integer not null default 1 check (document_schema_version=1),
  add column document_byte_size integer generated always as
    (pg_catalog.octet_length(payload::text)) stored,
  add column document_hash text generated always as
    (pg_catalog.encode(extensions.digest(payload::text,'sha256'),'hex')) stored,
  add constraint briefing_section_document_size check (document_byte_size between 2 and 262144),
  add constraint briefing_section_document_hash check (document_hash ~ '^[a-f0-9]{64}$');

alter table argus_app.rowan_script_revisions
  add column token_schema_version integer not null default 1 check (token_schema_version=1),
  add column token_document_hash text generated always as
    (pg_catalog.encode(extensions.digest(allowed_tokens::text,'sha256'),'hex')) stored,
  add column token_document_byte_size integer generated always as
    (pg_catalog.octet_length(allowed_tokens::text)) stored,
  add constraint rowan_token_document_size check (token_document_byte_size between 2 and 16384),
  add constraint rowan_token_document_hash check (token_document_hash ~ '^[a-f0-9]{64}$');

alter table argus_app.moderation_cases
  add column decision_schema_version integer not null default 1 check (decision_schema_version=1),
  add column decision_document_hash text generated always as
    (case when decision_payload is null then null else pg_catalog.encode(extensions.digest(decision_payload::text,'sha256'),'hex') end) stored,
  add column decision_document_byte_size integer generated always as
    (case when decision_payload is null then null else pg_catalog.octet_length(decision_payload::text) end) stored,
  add constraint moderation_decision_document_size
    check (decision_document_byte_size is null or decision_document_byte_size between 2 and 65536),
  add constraint moderation_decision_document_state
    check ((status='open' and decision_payload is null) or (status in ('actioned','dismissed') and decision_payload is not null));

-- Set-based, restart-safe compatibility backfills. Unknown source attribution,
-- missing typed targets and malformed documents are quarantined as a whole
-- cohort rather than partially coerced.
insert into argus_app.onboarding_step_completions(
  tenant_id,lifecycle_id,onboarding_user_id,step_code,ordinal,completed_at
)
select state.tenant_id,state.lifecycle_id,state.user_id,entry.value,
       entry.ordinal::integer,state.completed_at
  from argus_app.onboarding_states state
  cross join lateral jsonb_array_elements_text(state.completed_steps)
    with ordinality entry(value,ordinal)
 where entry.value in ('welcome','investing','ritual','astrology','consents','complete')
   and not exists (
     select 1 from jsonb_array_elements_text(state.completed_steps) duplicate(value)
      group by duplicate.value having count(*)>1
   )
on conflict (tenant_id,lifecycle_id,onboarding_user_id,step_code) do update
  set ordinal=excluded.ordinal,completed_at=excluded.completed_at;

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,source_fingerprint,source_cardinality
)
select 'argus_app.onboarding_states',state.user_id::text,'completed_steps',
       'unknown-or-duplicate-step',
       pg_catalog.encode(extensions.digest(state.completed_steps::text,'sha256'),'hex'),
       jsonb_array_length(state.completed_steps)
  from argus_app.onboarding_states state
 where exists (
   select 1 from jsonb_array_elements_text(state.completed_steps) entry(value)
    where entry.value not in ('welcome','investing','ritual','astrology','consents','complete')
 ) or exists (
   select 1 from jsonb_array_elements_text(state.completed_steps) duplicate(value)
    group by duplicate.value having count(*)>1
 )
on conflict do nothing;

insert into argus_app.notification_quiet_hours(
  tenant_id,lifecycle_id,preference_user_id,timezone_name,starts_at,ends_at
)
select preference.tenant_id,preference.lifecycle_id,preference.user_id,
       preference.quiet_hours->>'timezone',
       (preference.quiet_hours->>'start')::time,
       (preference.quiet_hours->>'end')::time
 from argus_app.notification_preferences preference
 where preference.quiet_hours<>'{}'::jsonb
   and jsonb_typeof(preference.quiet_hours)='object'
   and preference.quiet_hours ?& array['timezone','start','end']
   and (((preference.quiet_hours-'timezone')-'start')-'end')='{}'::jsonb
   and preference.quiet_hours->>'start' ~ '^(?:[01][0-9]|2[0-3]):[0-5][0-9](?::[0-5][0-9])?$'
   and preference.quiet_hours->>'end' ~ '^(?:[01][0-9]|2[0-3]):[0-5][0-9](?::[0-5][0-9])?$'
on conflict (tenant_id,lifecycle_id,preference_user_id) do update
  set timezone_name=excluded.timezone_name,starts_at=excluded.starts_at,ends_at=excluded.ends_at;

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,source_fingerprint,source_cardinality
)
select 'argus_app.notification_preferences',preference.user_id::text,'quiet_hours',
       'malformed-quiet-hours',
       pg_catalog.encode(extensions.digest(preference.quiet_hours::text,'sha256'),'hex'),1
 from argus_app.notification_preferences preference
 where preference.quiet_hours<>'{}'::jsonb and not (
   jsonb_typeof(preference.quiet_hours)='object'
   and preference.quiet_hours ?& array['timezone','start','end']
   and (((preference.quiet_hours-'timezone')-'start')-'end')='{}'::jsonb
   and preference.quiet_hours->>'start' ~ '^(?:[01][0-9]|2[0-3]):[0-5][0-9](?::[0-5][0-9])?$'
   and preference.quiet_hours->>'end' ~ '^(?:[01][0-9]|2[0-3]):[0-5][0-9](?::[0-5][0-9])?$'
 )
on conflict do nothing;

insert into argus_app.member_saved_items(
  tenant_id,lifecycle_id,user_id,item_kind,asset_id,grimoire_id,
  circle_template_id,coven_entry_id,source_kind,saved_at
)
select saved.tenant_id,saved.lifecycle_id,saved.user_id,saved.item_kind,
       case when saved.item_kind='asset' then asset.id end,
       case when saved.item_kind='grimoire' then grimoire.id end,
       case when saved.item_kind='circle_template' then template.id end,
       case when saved.item_kind='coven' then coven.id end,
       'direct',saved.saved_at
  from argus_app.saved_items saved
  left join argus_app.catalog_assets asset
    on saved.item_kind='asset' and asset.id=saved.item_id and asset.status='active'
  left join argus_app.grimoires grimoire on saved.item_kind='grimoire' and grimoire.id=saved.item_id
  left join argus_app.community_templates template
    on saved.item_kind='circle_template' and template.id=saved.item_id
  left join argus_app.coven_entries coven on saved.item_kind='coven' and coven.id=saved.item_id
 where saved.source_kind='direct' and saved.source_id is null
   and num_nonnulls(asset.id,grimoire.id,template.id,coven.id)=1
on conflict do nothing;

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,source_fingerprint,source_cardinality
)
select 'argus_app.saved_items',
       saved.user_id::text||':'||saved.item_kind||':'||saved.item_id::text,
       'saved-target','unresolved-target-or-attribution',
       pg_catalog.encode(extensions.digest(to_jsonb(saved)::text,'sha256'),'hex'),1
  from argus_app.saved_items saved
 where not exists (
   select 1 from argus_app.member_saved_items normalized
    where normalized.tenant_id=saved.tenant_id
      and normalized.lifecycle_id=saved.lifecycle_id
      and normalized.item_kind=saved.item_kind
      and coalesce(normalized.asset_id,normalized.grimoire_id,
          normalized.circle_template_id,normalized.coven_entry_id)=saved.item_id
 )
on conflict do nothing;

insert into argus_app.content_report_targets(
  report_id,tenant_id,lifecycle_id,target_kind,editorial_item_id,asset_id,
  grimoire_id,circle_template_id,coven_entry_id
)
select report.id,report.tenant_id,report.lifecycle_id,report.target_kind,
       case when report.target_kind='editorial' then item.id end,
       case when report.target_kind='asset' then asset.id end,
       case when report.target_kind='grimoire' then grimoire.id end,
       case when report.target_kind='circle_template' then template.id end,
       case when report.target_kind='coven' then coven.id end
  from argus_app.content_reports report
  left join argus_app.editorial_items item
    on report.target_kind='editorial' and item.id=report.target_id and item.status='published'
  left join argus_app.catalog_assets asset
    on report.target_kind='asset' and asset.id=report.target_id and asset.status='active'
  left join argus_app.grimoires grimoire on report.target_kind='grimoire' and grimoire.id=report.target_id
  left join argus_app.community_templates template
    on report.target_kind='circle_template' and template.id=report.target_id
  left join argus_app.coven_entries coven on report.target_kind='coven' and coven.id=report.target_id
 where num_nonnulls(item.id,asset.id,grimoire.id,template.id,coven.id)=1
on conflict (report_id) do nothing;

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,source_fingerprint,source_cardinality
)
select 'argus_app.content_reports',report.id::text,'report-target','unsupported-or-missing-target',
       pg_catalog.encode(extensions.digest(to_jsonb(report)::text,'sha256'),'hex'),1
  from argus_app.content_reports report
 where not exists (select 1 from argus_app.content_report_targets target where target.report_id=report.id)
on conflict do nothing;

insert into argus_app.editorial_render_documents(item_id,revision_id,document)
select revision.item_id,revision.id,revision.payload
  from argus_app.editorial_revisions revision
 where revision.state in ('published','withdrawn')
on conflict (revision_id) do nothing;

-- Valid legacy ritual relations are copied only when cardinality, uniqueness
-- and target state all reconcile. Invalid revisions are quarantined whole.
insert into argus_app.ritual_scenario_revision_assets(
  editorial_item_id,revision_id,asset_id,ordinal
)
select scenario.editorial_item_id,scenario.revision_id,entry.asset_id,entry.ordinal::integer
  from argus_app.ritual_scenario_revisions scenario
  cross join lateral unnest(scenario.idea_asset_ids) with ordinality entry(asset_id,ordinal)
 where cardinality(scenario.idea_asset_ids) between 3 and 5
   and cardinality(scenario.idea_asset_ids)=(select count(distinct value) from unnest(scenario.idea_asset_ids) value)
   and cardinality(scenario.idea_asset_ids)=(select count(*) from argus_app.catalog_assets asset where asset.id=any(scenario.idea_asset_ids) and asset.status='active')
   and cardinality(scenario.evidence_claim_ids) between 1 and 100
   and cardinality(scenario.evidence_claim_ids)=(select count(distinct value) from unnest(scenario.evidence_claim_ids) value)
   and cardinality(scenario.evidence_claim_ids)=(select count(*) from argus_app.evidence_claims claim where claim.id=any(scenario.evidence_claim_ids) and claim.status='active')
on conflict do nothing;

insert into argus_app.ritual_scenario_revision_evidence(
  editorial_item_id,revision_id,evidence_claim_id,ordinal
)
select scenario.editorial_item_id,scenario.revision_id,entry.claim_id,entry.ordinal::integer
  from argus_app.ritual_scenario_revisions scenario
  cross join lateral unnest(scenario.evidence_claim_ids) with ordinality entry(claim_id,ordinal)
 where cardinality(scenario.evidence_claim_ids) between 1 and 100
   and cardinality(scenario.evidence_claim_ids)=(select count(distinct value) from unnest(scenario.evidence_claim_ids) value)
   and cardinality(scenario.evidence_claim_ids)=(select count(*) from argus_app.evidence_claims claim where claim.id=any(scenario.evidence_claim_ids) and claim.status='active')
   and cardinality(scenario.idea_asset_ids) between 3 and 5
   and cardinality(scenario.idea_asset_ids)=(select count(distinct value) from unnest(scenario.idea_asset_ids) value)
   and cardinality(scenario.idea_asset_ids)=(select count(*) from argus_app.catalog_assets asset where asset.id=any(scenario.idea_asset_ids) and asset.status='active')
on conflict do nothing;

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,source_fingerprint,source_cardinality
)
select 'argus_app.ritual_scenario_revisions',scenario.revision_id::text,
       'ritual-relationships','invalid-cardinality-duplicate-or-target',
       pg_catalog.encode(extensions.digest(jsonb_build_object(
         'idea_asset_ids',scenario.idea_asset_ids,
         'evidence_claim_ids',scenario.evidence_claim_ids
       )::text,'sha256'),'hex'),
       cardinality(scenario.idea_asset_ids)+cardinality(scenario.evidence_claim_ids)
  from argus_app.ritual_scenario_revisions scenario
 where not (
   cardinality(scenario.idea_asset_ids) between 3 and 5
   and cardinality(scenario.idea_asset_ids)=(select count(distinct value) from unnest(scenario.idea_asset_ids) value)
   and cardinality(scenario.idea_asset_ids)=(select count(*) from argus_app.catalog_assets asset where asset.id=any(scenario.idea_asset_ids) and asset.status='active')
   and cardinality(scenario.evidence_claim_ids) between 1 and 100
   and cardinality(scenario.evidence_claim_ids)=(select count(distinct value) from unnest(scenario.evidence_claim_ids) value)
   and cardinality(scenario.evidence_claim_ids)=(select count(*) from argus_app.evidence_claims claim where claim.id=any(scenario.evidence_claim_ids) and claim.status='active')
 )
on conflict do nothing;

insert into argus_app.grimoire_revision_assets(
  grimoire_id,editorial_item_id,revision_id,asset_id,ordinal
)
select grimoire.id,grimoire.editorial_item_id,revision.id,entry.asset_id,entry.ordinal::integer
  from argus_app.grimoires grimoire
  join lateral (
    select candidate.id from argus_app.editorial_revisions candidate
     where candidate.item_id=grimoire.editorial_item_id
     order by (candidate.id=(select current_published_revision_id from argus_app.editorial_items where id=grimoire.editorial_item_id)) desc,
              candidate.revision_number desc limit 1
  ) revision on true
  cross join lateral unnest(grimoire.asset_ids) with ordinality entry(asset_id,ordinal)
 where cardinality(grimoire.asset_ids)<=100
   and cardinality(grimoire.asset_ids)=(select count(distinct value) from unnest(grimoire.asset_ids) value)
   and cardinality(grimoire.asset_ids)=(select count(*) from argus_app.catalog_assets asset where asset.id=any(grimoire.asset_ids) and asset.status='active')
on conflict do nothing;

insert into argus_app.editorial_revision_assets(item_id,revision_id,asset_id,ordinal)
select grimoire.editorial_item_id,revision.id,entry.asset_id,entry.ordinal::integer
  from argus_app.grimoires grimoire
  join lateral (
    select candidate.id from argus_app.editorial_revisions candidate
     where candidate.item_id=grimoire.editorial_item_id
     order by (candidate.id=(select current_published_revision_id from argus_app.editorial_items where id=grimoire.editorial_item_id)) desc,
              candidate.revision_number desc limit 1
  ) revision on true
  cross join lateral unnest(grimoire.asset_ids) with ordinality entry(asset_id,ordinal)
 where cardinality(grimoire.asset_ids)<=100
   and cardinality(grimoire.asset_ids)=(select count(distinct value) from unnest(grimoire.asset_ids) value)
   and cardinality(grimoire.asset_ids)=(select count(*) from argus_app.catalog_assets asset where asset.id=any(grimoire.asset_ids) and asset.status='active')
on conflict do nothing;

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,source_fingerprint,source_cardinality
)
select 'argus_app.grimoires',grimoire.id::text,'asset-relationships',
       'invalid-cardinality-duplicate-target-or-revision',
       pg_catalog.encode(extensions.digest(to_jsonb(grimoire.asset_ids)::text,'sha256'),'hex'),
       cardinality(grimoire.asset_ids)
  from argus_app.grimoires grimoire
 where cardinality(grimoire.asset_ids)>100
    or cardinality(grimoire.asset_ids)<>(select count(distinct value) from unnest(grimoire.asset_ids) value)
    or cardinality(grimoire.asset_ids)<>(select count(*) from argus_app.catalog_assets asset where asset.id=any(grimoire.asset_ids) and asset.status='active')
    or not exists (select 1 from argus_app.editorial_revisions revision where revision.item_id=grimoire.editorial_item_id)
on conflict do nothing;

insert into argus_app.community_template_revision_assets(
  template_id,editorial_item_id,revision_id,asset_id,ordinal
)
select template.id,template.editorial_item_id,revision.id,entry.asset_id,entry.ordinal::integer
  from argus_app.community_templates template
  join lateral (
    select candidate.id from argus_app.editorial_revisions candidate
     where candidate.item_id=template.editorial_item_id
     order by (candidate.id=(select current_published_revision_id from argus_app.editorial_items where id=template.editorial_item_id)) desc,
              candidate.revision_number desc limit 1
  ) revision on true
  cross join lateral unnest(template.asset_ids) with ordinality entry(asset_id,ordinal)
 where cardinality(template.asset_ids)<=50
   and cardinality(template.asset_ids)=(select count(distinct value) from unnest(template.asset_ids) value)
   and cardinality(template.asset_ids)=(select count(*) from argus_app.catalog_assets asset where asset.id=any(template.asset_ids) and asset.status='active')
on conflict do nothing;

insert into argus_app.editorial_revision_assets(item_id,revision_id,asset_id,ordinal)
select template.editorial_item_id,revision.id,entry.asset_id,entry.ordinal::integer
  from argus_app.community_templates template
  join lateral (
    select candidate.id from argus_app.editorial_revisions candidate
     where candidate.item_id=template.editorial_item_id
     order by (candidate.id=(select current_published_revision_id from argus_app.editorial_items where id=template.editorial_item_id)) desc,
              candidate.revision_number desc limit 1
  ) revision on true
  cross join lateral unnest(template.asset_ids) with ordinality entry(asset_id,ordinal)
 where cardinality(template.asset_ids)<=50
   and cardinality(template.asset_ids)=(select count(distinct value) from unnest(template.asset_ids) value)
   and cardinality(template.asset_ids)=(select count(*) from argus_app.catalog_assets asset where asset.id=any(template.asset_ids) and asset.status='active')
on conflict do nothing;

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,source_fingerprint,source_cardinality
)
select 'argus_app.community_templates',template.id::text,'asset-relationships',
       'invalid-cardinality-duplicate-target-or-revision',
       pg_catalog.encode(extensions.digest(to_jsonb(template.asset_ids)::text,'sha256'),'hex'),
       cardinality(template.asset_ids)
  from argus_app.community_templates template
 where cardinality(template.asset_ids)>50
    or cardinality(template.asset_ids)<>(select count(distinct value) from unnest(template.asset_ids) value)
    or cardinality(template.asset_ids)<>(select count(*) from argus_app.catalog_assets asset where asset.id=any(template.asset_ids) and asset.status='active')
    or not exists (select 1 from argus_app.editorial_revisions revision where revision.item_id=template.editorial_item_id)
on conflict do nothing;

insert into argus_app.coven_qualifications(
  coven_entry_id,editorial_item_id,revision_id,ordinal,
  criterion_code,claim,evidence_claim_id
)
select coven.id,coven.editorial_item_id,revision.id,entry.ordinal::integer,
       coalesce(entry.value->>'criterion_code',entry.value->>'criterion'),
       coalesce(entry.value->>'claim',entry.value->>'summary'),
       nullif(entry.value->>'evidence_claim_id','')::uuid
  from argus_app.coven_entries coven
  join lateral (
    select candidate.id from argus_app.editorial_revisions candidate
     where candidate.item_id=coven.editorial_item_id
     order by (candidate.id=(select current_published_revision_id from argus_app.editorial_items where id=coven.editorial_item_id)) desc,
              candidate.revision_number desc limit 1
  ) revision on true
  cross join lateral jsonb_array_elements(coven.qualification_payload)
    with ordinality entry(value,ordinal)
 where jsonb_array_length(coven.qualification_payload)<=20
   and not exists (
     select 1 from jsonb_array_elements(coven.qualification_payload) candidate(value)
      where jsonb_typeof(candidate.value)<>'object'
         or coalesce(candidate.value->>'criterion_code',candidate.value->>'criterion','')
              !~ '^[a-z][a-z0-9_]{0,63}$'
         or pg_catalog.char_length(coalesce(candidate.value->>'claim',candidate.value->>'summary','')) not between 1 and 2000
         or (
           nullif(candidate.value->>'evidence_claim_id','') is not null
           and (
             candidate.value->>'evidence_claim_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
             or not exists (
               select 1 from argus_app.evidence_claims claim
                where claim.id=case
                  when candidate.value->>'evidence_claim_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
                  then (candidate.value->>'evidence_claim_id')::uuid
                end
                  and claim.status='active'
             )
           )
         )
   )
on conflict do nothing;

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,source_fingerprint,source_cardinality
)
select 'argus_app.coven_entries',coven.id::text,'qualification-relationships',
       'invalid-qualification-target-or-revision',
       pg_catalog.encode(extensions.digest(coven.qualification_payload::text,'sha256'),'hex'),
       jsonb_array_length(coven.qualification_payload)
  from argus_app.coven_entries coven
 where jsonb_array_length(coven.qualification_payload)>20
    or not exists (select 1 from argus_app.editorial_revisions revision where revision.item_id=coven.editorial_item_id)
    or exists (
      select 1 from jsonb_array_elements(coven.qualification_payload) candidate(value)
       where jsonb_typeof(candidate.value)<>'object'
          or coalesce(candidate.value->>'criterion_code',candidate.value->>'criterion','')
               !~ '^[a-z][a-z0-9_]{0,63}$'
          or pg_catalog.char_length(coalesce(candidate.value->>'claim',candidate.value->>'summary','')) not between 1 and 2000
          or (
            nullif(candidate.value->>'evidence_claim_id','') is not null
            and (
              candidate.value->>'evidence_claim_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
              or not exists (
                select 1 from argus_app.evidence_claims claim
                 where claim.id=case
                   when candidate.value->>'evidence_claim_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
                   then (candidate.value->>'evidence_claim_id')::uuid
                 end
                   and claim.status='active'
              )
            )
          )
    )
on conflict do nothing;

-- Asset Codex draft envelopes are decomposed as one revision header plus
-- ordered evidence and metric children. Any malformed member makes the whole
-- revision cohort ineligible, so a retry cannot leave a partial projection.
insert into argus_app.asset_codex_revisions(
  editorial_item_id,revision_id,asset_id,metrics_as_of
)
select item.id,revision.id,asset.id,
       case when nullif(revision.payload->>'metrics_as_of','') is null then null
            else (revision.payload->>'metrics_as_of')::timestamptz end
  from argus_app.editorial_revisions revision
  join argus_app.editorial_items item
    on item.id=revision.item_id and item.kind='asset_codex'
  join argus_app.catalog_assets asset on asset.status='active' and (
    asset.id=case
      when revision.payload->>'asset_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then (revision.payload->>'asset_id')::uuid
    end
    or (revision.payload->>'asset_id' is null and asset.slug=item.slug)
  )
 where jsonb_typeof(coalesce(revision.payload->'evidence_claim_ids','[]'::jsonb))='array'
   and jsonb_typeof(coalesce(revision.payload->'metrics','[]'::jsonb))='array'
   and jsonb_array_length(case
     when jsonb_typeof(revision.payload->'evidence_claim_ids')='array'
       then revision.payload->'evidence_claim_ids' else '[]'::jsonb end)<=100
   and jsonb_array_length(case
     when jsonb_typeof(revision.payload->'metrics')='array'
       then revision.payload->'metrics' else '[]'::jsonb end)<=90
   and (
     nullif(revision.payload->>'metrics_as_of','') is null
     or pg_catalog.pg_input_is_valid(revision.payload->>'metrics_as_of','timestamptz')
   )
   and jsonb_array_length(case
     when jsonb_typeof(revision.payload->'evidence_claim_ids')='array'
       then revision.payload->'evidence_claim_ids' else '[]'::jsonb end)=(
     select count(distinct entry.value)
       from jsonb_array_elements_text(case
         when jsonb_typeof(revision.payload->'evidence_claim_ids')='array'
           then revision.payload->'evidence_claim_ids' else '[]'::jsonb end) entry(value)
   )
   and not exists (
     select 1
       from jsonb_array_elements_text(case
         when jsonb_typeof(revision.payload->'evidence_claim_ids')='array'
           then revision.payload->'evidence_claim_ids' else '[]'::jsonb end) entry(value)
      where entry.value !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
         or not exists (
           select 1 from argus_app.evidence_claims claim
            where claim.id=case
              when entry.value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
              then entry.value::uuid
            end
              and claim.status='active'
         )
   )
   and not exists (
     select 1 from jsonb_array_elements(case
       when jsonb_typeof(revision.payload->'metrics')='array'
         then revision.payload->'metrics' else '[]'::jsonb end) entry(value)
      where jsonb_typeof(entry.value)<>'object'
         or not pg_catalog.pg_input_is_valid(entry.value->>'observed_at','timestamptz')
         or (nullif(entry.value->>'price_minor','') is not null and not pg_catalog.pg_input_is_valid(entry.value->>'price_minor','bigint'))
         or (nullif(entry.value->>'change_bps','') is not null and not pg_catalog.pg_input_is_valid(entry.value->>'change_bps','integer'))
         or (nullif(entry.value->>'expense_ratio_bps','') is not null and not pg_catalog.pg_input_is_valid(entry.value->>'expense_ratio_bps','integer'))
         or num_nonnulls(nullif(entry.value->>'price_minor',''),nullif(entry.value->>'change_bps',''),nullif(entry.value->>'expense_ratio_bps',''))<1
         or case when pg_catalog.pg_input_is_valid(entry.value->>'price_minor','bigint')
                 then (entry.value->>'price_minor')::bigint<0 else false end
         or case when pg_catalog.pg_input_is_valid(entry.value->>'expense_ratio_bps','integer')
                 then (entry.value->>'expense_ratio_bps')::integer<0 else false end
   )
on conflict (revision_id) do update set
  asset_id=excluded.asset_id,metrics_as_of=excluded.metrics_as_of;

insert into argus_app.asset_codex_revision_evidence(
  editorial_item_id,revision_id,evidence_claim_id,ordinal
)
select codex.editorial_item_id,codex.revision_id,entry.value::uuid,entry.ordinal::integer
  from argus_app.asset_codex_revisions codex
  join argus_app.editorial_revisions revision on revision.id=codex.revision_id
  cross join lateral jsonb_array_elements_text(coalesce(revision.payload->'evidence_claim_ids','[]'::jsonb))
    with ordinality entry(value,ordinal)
on conflict do nothing;

insert into argus_app.asset_codex_revision_metrics(
  editorial_item_id,revision_id,ordinal,observed_at,price_minor,change_bps,
  expense_ratio_bps,source_label
)
select codex.editorial_item_id,codex.revision_id,entry.ordinal::integer,
       (entry.value->>'observed_at')::timestamptz,
       nullif(entry.value->>'price_minor','')::bigint,
       nullif(entry.value->>'change_bps','')::integer,
       nullif(entry.value->>'expense_ratio_bps','')::integer,
       coalesce(nullif(entry.value->>'source_label',''),'Argus editorial')
  from argus_app.asset_codex_revisions codex
  join argus_app.editorial_revisions revision on revision.id=codex.revision_id
  cross join lateral jsonb_array_elements(coalesce(revision.payload->'metrics','[]'::jsonb))
    with ordinality entry(value,ordinal)
on conflict (revision_id,ordinal) do update set
  observed_at=excluded.observed_at,price_minor=excluded.price_minor,
  change_bps=excluded.change_bps,expense_ratio_bps=excluded.expense_ratio_bps,
  source_label=excluded.source_label;

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,source_fingerprint,source_cardinality
)
select 'argus_app.editorial_revisions',revision.id::text,'asset-codex-envelope',
       'invalid-asset-evidence-or-metric-envelope',
       pg_catalog.encode(extensions.digest(revision.payload::text,'sha256'),'hex'),
       case when jsonb_typeof(revision.payload->'evidence_claim_ids')='array'
         then jsonb_array_length(revision.payload->'evidence_claim_ids') else 0 end
         +case when jsonb_typeof(revision.payload->'metrics')='array'
           then jsonb_array_length(revision.payload->'metrics') else 0 end
         +1
  from argus_app.editorial_revisions revision
  join argus_app.editorial_items item
    on item.id=revision.item_id and item.kind='asset_codex'
 where not exists (
   select 1 from argus_app.asset_codex_revisions codex where codex.revision_id=revision.id
 )
on conflict do nothing;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.editorial_revisions',revision.id::text,
       'argus_app.editorial_render_documents',revision.id::text,
       pg_catalog.encode(extensions.digest(revision.payload::text,'sha256'),'hex'),1,1
  from argus_app.editorial_revisions revision
  join argus_app.editorial_render_documents document on document.revision_id=revision.id
on conflict (source_relation,source_identity,target_relation) do update
  set source_fingerprint=excluded.source_fingerprint,
      source_cardinality=excluded.source_cardinality,
      target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.onboarding_states',state.user_id::text,
       'argus_app.onboarding_step_completions',
       state.tenant_id::text||':'||state.lifecycle_id::text||':'||state.user_id::text,
       pg_catalog.encode(extensions.digest(state.completed_steps::text,'sha256'),'hex'),
       jsonb_array_length(state.completed_steps),count(completion.step_code)::integer
  from argus_app.onboarding_states state
  left join argus_app.onboarding_step_completions completion
    on completion.tenant_id=state.tenant_id
   and completion.lifecycle_id=state.lifecycle_id
   and completion.onboarding_user_id=state.user_id
 where not exists (
   select 1 from argus_app.legacy_normalization_quarantine quarantine
    where quarantine.source_relation='argus_app.onboarding_states'
      and quarantine.source_identity=state.user_id::text
      and quarantine.cohort='completed_steps'
 )
 group by state.tenant_id,state.lifecycle_id,state.user_id,state.completed_steps
having jsonb_array_length(state.completed_steps)=count(completion.step_code)
on conflict (source_relation,source_identity,target_relation) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.notification_preferences',preference.user_id::text,
       'argus_app.notification_quiet_hours',
       preference.tenant_id::text||':'||preference.lifecycle_id::text||':'||preference.user_id::text,
       pg_catalog.encode(extensions.digest(preference.quiet_hours::text,'sha256'),'hex'),
       case when preference.quiet_hours='{}'::jsonb then 0 else 1 end,
       count(quiet.preference_user_id)::integer
  from argus_app.notification_preferences preference
  left join argus_app.notification_quiet_hours quiet
    on quiet.tenant_id=preference.tenant_id
   and quiet.lifecycle_id=preference.lifecycle_id
   and quiet.preference_user_id=preference.user_id
 where not exists (
   select 1 from argus_app.legacy_normalization_quarantine quarantine
    where quarantine.source_relation='argus_app.notification_preferences'
      and quarantine.source_identity=preference.user_id::text
      and quarantine.cohort='quiet_hours'
 )
 group by preference.tenant_id,preference.lifecycle_id,preference.user_id,preference.quiet_hours
having case when preference.quiet_hours='{}'::jsonb then 0 else 1 end=count(quiet.preference_user_id)
on conflict (source_relation,source_identity,target_relation) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.saved_items',
       saved.user_id::text||':'||saved.item_kind||':'||saved.item_id::text,
       'argus_app.member_saved_items',normalized.id::text,
       pg_catalog.encode(extensions.digest(to_jsonb(saved)::text,'sha256'),'hex'),1,1
  from argus_app.saved_items saved
  join argus_app.member_saved_items normalized
    on normalized.tenant_id=saved.tenant_id
   and normalized.lifecycle_id=saved.lifecycle_id
   and normalized.item_kind=saved.item_kind
   and coalesce(normalized.asset_id,normalized.grimoire_id,
       normalized.circle_template_id,normalized.coven_entry_id)=saved.item_id
on conflict (source_relation,source_identity,target_relation) do update set
  target_identity=excluded.target_identity,
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.content_reports',report.id::text,
       'argus_app.content_report_targets',target.report_id::text,
       pg_catalog.encode(extensions.digest(to_jsonb(report)::text,'sha256'),'hex'),1,1
  from argus_app.content_reports report
  join argus_app.content_report_targets target on target.report_id=report.id
on conflict (source_relation,source_identity,target_relation) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.ritual_scenario_revisions',scenario.revision_id::text,
       'argus_app.ritual_scenario_revision_assets',
       scenario.editorial_item_id::text||':'||scenario.revision_id::text,
       pg_catalog.encode(extensions.digest(to_jsonb(scenario.idea_asset_ids)::text,'sha256'),'hex'),
       cardinality(scenario.idea_asset_ids),count(asset.asset_id)::integer
  from argus_app.ritual_scenario_revisions scenario
  left join argus_app.ritual_scenario_revision_assets asset
    on asset.editorial_item_id=scenario.editorial_item_id
   and asset.revision_id=scenario.revision_id
 where not exists (
   select 1 from argus_app.legacy_normalization_quarantine quarantine
    where quarantine.source_relation='argus_app.ritual_scenario_revisions'
      and quarantine.source_identity=scenario.revision_id::text
      and quarantine.cohort='ritual-relationships'
 )
 group by scenario.editorial_item_id,scenario.revision_id,scenario.idea_asset_ids
having cardinality(scenario.idea_asset_ids)=count(asset.asset_id)
on conflict (source_relation,source_identity,target_relation) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.ritual_scenario_revisions',scenario.revision_id::text,
       'argus_app.ritual_scenario_revision_evidence',
       scenario.editorial_item_id::text||':'||scenario.revision_id::text,
       pg_catalog.encode(extensions.digest(to_jsonb(scenario.evidence_claim_ids)::text,'sha256'),'hex'),
       cardinality(scenario.evidence_claim_ids),count(evidence.evidence_claim_id)::integer
  from argus_app.ritual_scenario_revisions scenario
  left join argus_app.ritual_scenario_revision_evidence evidence
    on evidence.editorial_item_id=scenario.editorial_item_id
   and evidence.revision_id=scenario.revision_id
 where not exists (
   select 1 from argus_app.legacy_normalization_quarantine quarantine
    where quarantine.source_relation='argus_app.ritual_scenario_revisions'
      and quarantine.source_identity=scenario.revision_id::text
      and quarantine.cohort='ritual-relationships'
 )
 group by scenario.editorial_item_id,scenario.revision_id,scenario.evidence_claim_ids
having cardinality(scenario.evidence_claim_ids)=count(evidence.evidence_claim_id)
on conflict (source_relation,source_identity,target_relation) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.grimoires',grimoire.id::text,
       'argus_app.grimoire_revision_assets',
       grimoire.id::text||':'||revision.id::text,
       pg_catalog.encode(extensions.digest(to_jsonb(grimoire.asset_ids)::text,'sha256'),'hex'),
       cardinality(grimoire.asset_ids),count(asset.asset_id)::integer
  from argus_app.grimoires grimoire
  join lateral (
    select candidate.id from argus_app.editorial_revisions candidate
     where candidate.item_id=grimoire.editorial_item_id
     order by (candidate.id=(select current_published_revision_id from argus_app.editorial_items where id=grimoire.editorial_item_id)) desc,
              candidate.revision_number desc limit 1
  ) revision on true
  left join argus_app.grimoire_revision_assets asset
    on asset.grimoire_id=grimoire.id and asset.revision_id=revision.id
 where not exists (
   select 1 from argus_app.legacy_normalization_quarantine quarantine
    where quarantine.source_relation='argus_app.grimoires'
      and quarantine.source_identity=grimoire.id::text
      and quarantine.cohort='asset-relationships'
 )
 group by grimoire.id,revision.id,grimoire.asset_ids
having cardinality(grimoire.asset_ids)=count(asset.asset_id)
on conflict (source_relation,source_identity,target_relation) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.community_templates',template.id::text,
       'argus_app.community_template_revision_assets',
       template.id::text||':'||revision.id::text,
       pg_catalog.encode(extensions.digest(to_jsonb(template.asset_ids)::text,'sha256'),'hex'),
       cardinality(template.asset_ids),count(asset.asset_id)::integer
  from argus_app.community_templates template
  join lateral (
    select candidate.id from argus_app.editorial_revisions candidate
     where candidate.item_id=template.editorial_item_id
     order by (candidate.id=(select current_published_revision_id from argus_app.editorial_items where id=template.editorial_item_id)) desc,
              candidate.revision_number desc limit 1
  ) revision on true
  left join argus_app.community_template_revision_assets asset
    on asset.template_id=template.id and asset.revision_id=revision.id
 where not exists (
   select 1 from argus_app.legacy_normalization_quarantine quarantine
    where quarantine.source_relation='argus_app.community_templates'
      and quarantine.source_identity=template.id::text
      and quarantine.cohort='asset-relationships'
 )
 group by template.id,revision.id,template.asset_ids
having cardinality(template.asset_ids)=count(asset.asset_id)
on conflict (source_relation,source_identity,target_relation) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.coven_entries',coven.id::text,
       'argus_app.coven_qualifications',coven.id::text||':'||revision.id::text,
       pg_catalog.encode(extensions.digest(coven.qualification_payload::text,'sha256'),'hex'),
       jsonb_array_length(coven.qualification_payload),count(qualification.id)::integer
  from argus_app.coven_entries coven
  join lateral (
    select candidate.id from argus_app.editorial_revisions candidate
     where candidate.item_id=coven.editorial_item_id
     order by (candidate.id=(select current_published_revision_id from argus_app.editorial_items where id=coven.editorial_item_id)) desc,
              candidate.revision_number desc limit 1
  ) revision on true
  left join argus_app.coven_qualifications qualification
    on qualification.coven_entry_id=coven.id and qualification.revision_id=revision.id
 where not exists (
   select 1 from argus_app.legacy_normalization_quarantine quarantine
    where quarantine.source_relation='argus_app.coven_entries'
      and quarantine.source_identity=coven.id::text
      and quarantine.cohort='qualification-relationships'
 )
 group by coven.id,revision.id,coven.qualification_payload
having jsonb_array_length(coven.qualification_payload)=count(qualification.id)
on conflict (source_relation,source_identity,target_relation) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.editorial_revisions',revision.id::text,
       'argus_app.asset_codex_revisions',codex.revision_id::text,
       pg_catalog.encode(extensions.digest(revision.payload::text,'sha256'),'hex'),1,1
  from argus_app.editorial_revisions revision
  join argus_app.asset_codex_revisions codex on codex.revision_id=revision.id
on conflict (source_relation,source_identity,target_relation) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.editorial_revisions',revision.id::text,
       'argus_app.asset_codex_revision_evidence',codex.revision_id::text,
       pg_catalog.encode(extensions.digest(coalesce(revision.payload->'evidence_claim_ids','[]'::jsonb)::text,'sha256'),'hex'),
       jsonb_array_length(coalesce(revision.payload->'evidence_claim_ids','[]'::jsonb)),
       count(evidence.evidence_claim_id)::integer
  from argus_app.editorial_revisions revision
  join argus_app.asset_codex_revisions codex on codex.revision_id=revision.id
  left join argus_app.asset_codex_revision_evidence evidence on evidence.revision_id=revision.id
 group by revision.id,revision.payload,codex.revision_id
having jsonb_array_length(coalesce(revision.payload->'evidence_claim_ids','[]'::jsonb))=count(evidence.evidence_claim_id)
on conflict (source_relation,source_identity,target_relation) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

insert into argus_app.legacy_normalization_identity_map(
  source_relation,source_identity,target_relation,target_identity,
  source_fingerprint,source_cardinality,target_cardinality
)
select 'argus_app.editorial_revisions',revision.id::text,
       'argus_app.asset_codex_revision_metrics',codex.revision_id::text,
       pg_catalog.encode(extensions.digest(coalesce(revision.payload->'metrics','[]'::jsonb)::text,'sha256'),'hex'),
       jsonb_array_length(coalesce(revision.payload->'metrics','[]'::jsonb)),
       count(metric.id)::integer
  from argus_app.editorial_revisions revision
  join argus_app.asset_codex_revisions codex on codex.revision_id=revision.id
  left join argus_app.asset_codex_revision_metrics metric on metric.revision_id=revision.id
 group by revision.id,revision.payload,codex.revision_id
having jsonb_array_length(coalesce(revision.payload->'metrics','[]'::jsonb))=count(metric.id)
on conflict (source_relation,source_identity,target_relation) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality,
  target_cardinality=excluded.target_cardinality;

create or replace function argus_private.sync_onboarding_step_completions()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if exists (
    select 1 from pg_catalog.jsonb_array_elements_text(new.completed_steps) entry(value)
     where entry.value not in ('welcome','investing','ritual','astrology','consents','complete')
  ) or exists (
    select 1 from pg_catalog.jsonb_array_elements_text(new.completed_steps) duplicate(value)
     group by duplicate.value having count(*)>1
  ) then
    raise exception 'invalid_onboarding_step_collection' using errcode='23514';
  end if;
  delete from argus_app.onboarding_step_completions completion
   where completion.tenant_id=new.tenant_id
     and completion.lifecycle_id=new.lifecycle_id
     and completion.onboarding_user_id=new.user_id;
  insert into argus_app.onboarding_step_completions(
    tenant_id,lifecycle_id,onboarding_user_id,step_code,ordinal,completed_at
  )
  select new.tenant_id,new.lifecycle_id,new.user_id,entry.value,
         entry.ordinal::integer,new.completed_at
    from pg_catalog.jsonb_array_elements_text(new.completed_steps)
      with ordinality entry(value,ordinal);
  return new;
end
$$;
create trigger sync_onboarding_step_completions
  after insert or update of completed_steps,completed_at
  on argus_app.onboarding_states
  for each row execute function argus_private.sync_onboarding_step_completions();

create or replace function argus_private.sync_notification_quiet_hours()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  delete from argus_app.notification_quiet_hours quiet
   where quiet.tenant_id=new.tenant_id
     and quiet.lifecycle_id=new.lifecycle_id
     and quiet.preference_user_id=new.user_id;
  if new.quiet_hours='{}'::jsonb then return new; end if;
  if jsonb_typeof(new.quiet_hours)<>'object'
     or not new.quiet_hours ?& array['timezone','start','end']
     or (((new.quiet_hours-'timezone')-'start')-'end')<>'{}'::jsonb
     or new.quiet_hours->>'start' !~ '^(?:[01][0-9]|2[0-3]):[0-5][0-9](?::[0-5][0-9])?$'
     or new.quiet_hours->>'end' !~ '^(?:[01][0-9]|2[0-3]):[0-5][0-9](?::[0-5][0-9])?$' then
    raise exception 'invalid_notification_quiet_hours' using errcode='23514';
  end if;
  insert into argus_app.notification_quiet_hours(
    tenant_id,lifecycle_id,preference_user_id,timezone_name,starts_at,ends_at
  ) values (
    new.tenant_id,new.lifecycle_id,new.user_id,new.quiet_hours->>'timezone',
    (new.quiet_hours->>'start')::time,(new.quiet_hours->>'end')::time
  );
  return new;
end
$$;
create trigger sync_notification_quiet_hours
  after insert or update of quiet_hours on argus_app.notification_preferences
  for each row execute function argus_private.sync_notification_quiet_hours();

create or replace function argus_private.reject_sealed_u4_document_change()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
begin
  raise exception 'sealed_document_immutable' using errcode='23514';
end
$$;
create trigger editorial_render_documents_immutable
  before update or delete on argus_app.editorial_render_documents
  for each row execute function argus_private.reject_sealed_u4_document_change();

create or replace function argus_private.protect_u4_legacy_relation()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
begin
  if current_user<>'argus_app_owner' then
    raise exception 'legacy_compatibility_surface_read_only' using errcode='42501';
  end if;
  return case when tg_op='DELETE' then old else new end;
end
$$;
create trigger protect_saved_items_compatibility
  before insert or update or delete on argus_app.saved_items
  for each row execute function argus_private.protect_u4_legacy_relation();
create trigger protect_content_reports_compatibility
  before insert or update of target_kind,target_id on argus_app.content_reports
  for each row execute function argus_private.protect_u4_legacy_relation();
create trigger protect_ritual_arrays_compatibility
  before update of idea_asset_ids,evidence_claim_ids on argus_app.ritual_scenario_revisions
  for each row execute function argus_private.protect_u4_legacy_relation();
create trigger protect_grimoire_assets_compatibility
  before update of asset_ids on argus_app.grimoires
  for each row execute function argus_private.protect_u4_legacy_relation();
create trigger protect_template_assets_compatibility
  before update of asset_ids on argus_app.community_templates
  for each row execute function argus_private.protect_u4_legacy_relation();
create trigger protect_coven_qualification_compatibility
  before update of qualification_payload on argus_app.coven_entries
  for each row execute function argus_private.protect_u4_legacy_relation();

create or replace function argus_private.protect_future_mirror_assumptions()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
begin
  if new.assumptions is distinct from old.assumptions
     or new.assumption_schema_version<>old.assumption_schema_version then
    raise exception 'future_mirror_input_immutable' using errcode='23514';
  end if;
  return new;
end
$$;
create trigger protect_future_mirror_assumptions
  before update on argus_app.future_mirror_runs
  for each row execute function argus_private.protect_future_mirror_assumptions();

create or replace function argus_private.create_ritual_editorial_item(
  p_item_id uuid,p_payload jsonb
)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not argus_private.has_staff_permission('editorial:write')
     or nullif(p_payload->>'scenario_key','') is null
     or p_payload->>'mode' not in ('tarot','astrology')
     or nullif(p_payload->>'cadence','') is null then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  insert into argus_app.ritual_scenarios(editorial_item_id,scenario_key,mode,cadence)
  values (p_item_id,p_payload->>'scenario_key',p_payload->>'mode',p_payload->>'cadence');
end $$;

create or replace function argus_private.create_rowan_editorial_item(
  p_item_id uuid,p_payload jsonb
)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not argus_private.has_staff_permission('editorial:write')
     or nullif(p_payload->>'script_key','') is null
     or nullif(p_payload->>'surface','') is null then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  insert into argus_app.rowan_scripts(editorial_item_id,script_key,surface)
  values (p_item_id,p_payload->>'script_key',p_payload->>'surface');
end $$;

create or replace function argus_private.create_coven_editorial_item(
  p_item_id uuid,p_payload jsonb
)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not argus_private.has_staff_permission('editorial:write')
     or coalesce(p_payload->>'company_id','')
       !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  insert into argus_app.coven_entries(editorial_item_id,company_id)
  values (p_item_id,(p_payload->>'company_id')::uuid);
end $$;

create or replace function argus_private.create_grimoire_editorial_item(
  p_item_id uuid,p_payload jsonb
)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not argus_private.has_staff_permission('editorial:write')
     or nullif(p_payload->>'theme_code','') is null then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  insert into argus_app.grimoires(editorial_item_id,theme_code)
  values (p_item_id,p_payload->>'theme_code');
end $$;

create or replace function argus_private.create_circle_template_editorial_item(
  p_item_id uuid,p_payload jsonb
)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not argus_private.has_staff_permission('editorial:write')
     or nullif(p_payload->>'creator_label','') is null
     or nullif(p_payload->>'title','') is null
     or nullif(p_payload->>'description','') is null then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  insert into argus_app.community_templates(
    editorial_item_id,creator_label,title,description
  ) values (
    p_item_id,p_payload->>'creator_label',p_payload->>'title',p_payload->>'description'
  );
end $$;

create or replace function argus_private.sync_ritual_revision(
  p_revision_id uuid,p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare retained_item_id uuid;
declare retained_assets uuid[];
declare retained_evidence uuid[];
begin
  if not argus_private.has_staff_permission('editorial:write')
     or jsonb_typeof(p_payload)<>'object'
     or nullif(p_payload->>'title','') is null
     or nullif(p_payload->>'interpretation','') is null
     or nullif(p_payload->>'guidance','') is null
     or nullif(p_payload->>'market_label','') is null
     or nullif(p_payload->>'uncertainty','') is null
     or jsonb_typeof(p_payload->'idea_asset_ids')<>'array'
     or jsonb_typeof(p_payload->'evidence_claim_ids')<>'array'
     or jsonb_array_length(p_payload->'idea_asset_ids') not between 3 and 5
     or jsonb_array_length(p_payload->'evidence_claim_ids') not between 1 and 100 then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  select revision.item_id into retained_item_id
    from argus_app.editorial_revisions revision
    join argus_app.editorial_items item on item.id=revision.item_id and item.kind='ritual'
   where revision.id=p_revision_id and revision.state='draft';
  if retained_item_id is null then
    raise exception 'resource_not_found' using errcode='P0002';
  end if;
  select array_agg(entry.value::uuid order by entry.ordinal)
    into retained_assets
    from jsonb_array_elements_text(p_payload->'idea_asset_ids')
      with ordinality entry(value,ordinal);
  select array_agg(entry.value::uuid order by entry.ordinal)
    into retained_evidence
    from jsonb_array_elements_text(p_payload->'evidence_claim_ids')
      with ordinality entry(value,ordinal);
  if cardinality(retained_assets)<>(select count(distinct value) from unnest(retained_assets) value)
     or cardinality(retained_evidence)<>(select count(distinct value) from unnest(retained_evidence) value)
     or cardinality(retained_assets)<>(select count(*) from argus_app.catalog_assets asset where asset.id=any(retained_assets) and asset.status='active')
     or cardinality(retained_evidence)<>(select count(*) from argus_app.evidence_claims claim where claim.id=any(retained_evidence) and claim.status='active') then
    raise exception 'invalid_editorial_evidence' using errcode='23514';
  end if;
  insert into argus_app.ritual_scenario_revisions(
    revision_id,editorial_item_id,title,interpretation,guidance,market_label,
    observation_at,uncertainty,idea_asset_ids,evidence_claim_ids
  ) values (
    p_revision_id,retained_item_id,p_payload->>'title',p_payload->>'interpretation',
    p_payload->>'guidance',p_payload->>'market_label',
    (p_payload->>'observation_at')::timestamptz,p_payload->>'uncertainty',
    retained_assets,retained_evidence
  ) on conflict (revision_id) do update set
    title=excluded.title,interpretation=excluded.interpretation,
    guidance=excluded.guidance,market_label=excluded.market_label,
    observation_at=excluded.observation_at,uncertainty=excluded.uncertainty,
    idea_asset_ids=excluded.idea_asset_ids,evidence_claim_ids=excluded.evidence_claim_ids;
  delete from argus_app.ritual_scenario_revision_assets where revision_id=p_revision_id;
  insert into argus_app.ritual_scenario_revision_assets(
    editorial_item_id,revision_id,asset_id,ordinal
  ) select retained_item_id,p_revision_id,entry.value::uuid,entry.ordinal::integer
      from jsonb_array_elements_text(p_payload->'idea_asset_ids')
        with ordinality entry(value,ordinal);
  delete from argus_app.ritual_scenario_revision_evidence where revision_id=p_revision_id;
  insert into argus_app.ritual_scenario_revision_evidence(
    editorial_item_id,revision_id,evidence_claim_id,ordinal
  ) select retained_item_id,p_revision_id,entry.value::uuid,entry.ordinal::integer
      from jsonb_array_elements_text(p_payload->'evidence_claim_ids')
        with ordinality entry(value,ordinal);
exception when invalid_text_representation or invalid_datetime_format then
  raise exception 'invalid_editorial_payload' using errcode='23514';
end
$$;

create or replace function argus_private.sync_asset_codex_revision(
  p_revision_id uuid,p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare retained_item_id uuid;
declare retained_asset_id uuid;
declare retained_evidence jsonb;
declare retained_metrics jsonb;
begin
  if not argus_private.has_staff_permission('editorial:write')
     or jsonb_typeof(p_payload)<>'object' then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  select revision.item_id into retained_item_id
    from argus_app.editorial_revisions revision
    join argus_app.editorial_items item on item.id=revision.item_id and item.kind='asset_codex'
   where revision.id=p_revision_id and revision.state='draft';
  select asset.id into retained_asset_id
    from argus_app.catalog_assets asset
    join argus_app.editorial_items item on item.id=retained_item_id
   where asset.status='active' and (
     (coalesce(p_payload->>'asset_id','') ~* '^[0-9a-f-]{36}$' and asset.id=(p_payload->>'asset_id')::uuid)
     or (p_payload->>'asset_id' is null and asset.slug=item.slug)
   ) limit 1;
  if retained_item_id is null or retained_asset_id is null then
    raise exception 'resource_not_found' using errcode='P0002';
  end if;
  retained_evidence:=coalesce(p_payload->'evidence_claim_ids','[]'::jsonb);
  retained_metrics:=coalesce(p_payload->'metrics','[]'::jsonb);
  if jsonb_typeof(retained_evidence)<>'array' or jsonb_typeof(retained_metrics)<>'array'
     or jsonb_array_length(retained_evidence)>100 or jsonb_array_length(retained_metrics)>90
     or jsonb_array_length(retained_evidence)<>(
       select count(distinct entry.value)
         from jsonb_array_elements_text(retained_evidence) entry(value)
     ) then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  insert into argus_app.asset_codex_revisions(
    editorial_item_id,revision_id,asset_id,metrics_as_of
  ) values (
    retained_item_id,p_revision_id,retained_asset_id,
    case when p_payload->>'metrics_as_of' is null then null else (p_payload->>'metrics_as_of')::timestamptz end
  ) on conflict (revision_id) do update set
    asset_id=excluded.asset_id,metrics_as_of=excluded.metrics_as_of;
  delete from argus_app.asset_codex_revision_evidence where revision_id=p_revision_id;
  insert into argus_app.asset_codex_revision_evidence(
    editorial_item_id,revision_id,evidence_claim_id,ordinal
  )
  select retained_item_id,p_revision_id,entry.value::uuid,entry.ordinal::integer
    from jsonb_array_elements_text(retained_evidence) with ordinality entry(value,ordinal)
    join argus_app.evidence_claims claim on claim.id=entry.value::uuid and claim.status='active';
  if (select count(*) from argus_app.asset_codex_revision_evidence where revision_id=p_revision_id)
     <>jsonb_array_length(retained_evidence) then
    raise exception 'invalid_editorial_evidence' using errcode='23514';
  end if;
  delete from argus_app.asset_codex_revision_metrics where revision_id=p_revision_id;
  insert into argus_app.asset_codex_revision_metrics(
    editorial_item_id,revision_id,ordinal,observed_at,price_minor,change_bps,
    expense_ratio_bps,source_label
  )
  select retained_item_id,p_revision_id,entry.ordinal::integer,
         (entry.value->>'observed_at')::timestamptz,
         nullif(entry.value->>'price_minor','')::bigint,
         nullif(entry.value->>'change_bps','')::integer,
         nullif(entry.value->>'expense_ratio_bps','')::integer,
         coalesce(nullif(entry.value->>'source_label',''),'Argus editorial')
    from jsonb_array_elements(retained_metrics) with ordinality entry(value,ordinal)
   where jsonb_typeof(entry.value)='object';
  if (select count(*) from argus_app.asset_codex_revision_metrics where revision_id=p_revision_id)
     <>jsonb_array_length(retained_metrics) then
    raise exception 'invalid_editorial_metric' using errcode='23514';
  end if;
exception when invalid_text_representation or invalid_datetime_format or numeric_value_out_of_range then
  raise exception 'invalid_editorial_payload' using errcode='23514';
end
$$;

create or replace function argus_private.sync_grimoire_revision(
  p_revision_id uuid,p_payload jsonb
)
returns void language plpgsql security definer set search_path='' as $$
declare retained_item_id uuid; declare retained_grimoire_id uuid; declare retained_assets uuid[];
begin
  if not argus_private.has_staff_permission('editorial:write')
     or jsonb_typeof(coalesce(p_payload->'asset_ids','[]'::jsonb))<>'array'
     or jsonb_array_length(coalesce(p_payload->'asset_ids','[]'::jsonb))>100 then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  select revision.item_id,grimoire.id into retained_item_id,retained_grimoire_id
    from argus_app.editorial_revisions revision
    join argus_app.editorial_items item on item.id=revision.item_id and item.kind='grimoire'
    join argus_app.grimoires grimoire on grimoire.editorial_item_id=item.id
   where revision.id=p_revision_id and revision.state='draft';
  if retained_item_id is null then raise exception 'resource_not_found' using errcode='P0002'; end if;
  select coalesce(array_agg(entry.value::uuid order by entry.ordinal),'{}'::uuid[])
    into retained_assets from jsonb_array_elements_text(coalesce(p_payload->'asset_ids','[]'::jsonb))
      with ordinality entry(value,ordinal);
  if cardinality(retained_assets)<>(select count(distinct value) from unnest(retained_assets) value)
     or cardinality(retained_assets)<>(select count(*) from argus_app.catalog_assets asset where asset.id=any(retained_assets) and asset.status='active') then
    raise exception 'invalid_editorial_evidence' using errcode='23514';
  end if;
  update argus_app.grimoires set asset_ids=retained_assets where id=retained_grimoire_id;
  delete from argus_app.grimoire_revision_assets where revision_id=p_revision_id;
  delete from argus_app.editorial_revision_assets where revision_id=p_revision_id;
  insert into argus_app.grimoire_revision_assets(
    grimoire_id,editorial_item_id,revision_id,asset_id,ordinal
  ) select retained_grimoire_id,retained_item_id,p_revision_id,entry.value::uuid,entry.ordinal::integer
      from jsonb_array_elements_text(coalesce(p_payload->'asset_ids','[]'::jsonb))
        with ordinality entry(value,ordinal);
  insert into argus_app.editorial_revision_assets(item_id,revision_id,asset_id,ordinal)
  select retained_item_id,p_revision_id,entry.value::uuid,entry.ordinal::integer
    from jsonb_array_elements_text(coalesce(p_payload->'asset_ids','[]'::jsonb))
      with ordinality entry(value,ordinal);
exception when invalid_text_representation then
  raise exception 'invalid_editorial_payload' using errcode='23514';
end $$;

create or replace function argus_private.sync_circle_template_revision(
  p_revision_id uuid,p_payload jsonb
)
returns void language plpgsql security definer set search_path='' as $$
declare retained_item_id uuid; declare retained_template_id uuid; declare retained_assets uuid[];
begin
  if not argus_private.has_staff_permission('editorial:write')
     or jsonb_typeof(coalesce(p_payload->'asset_ids','[]'::jsonb))<>'array'
     or jsonb_array_length(coalesce(p_payload->'asset_ids','[]'::jsonb))>50 then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  select revision.item_id,template.id into retained_item_id,retained_template_id
    from argus_app.editorial_revisions revision
    join argus_app.editorial_items item on item.id=revision.item_id and item.kind='circle_template'
    join argus_app.community_templates template on template.editorial_item_id=item.id
   where revision.id=p_revision_id and revision.state='draft';
  if retained_item_id is null then raise exception 'resource_not_found' using errcode='P0002'; end if;
  select coalesce(array_agg(entry.value::uuid order by entry.ordinal),'{}'::uuid[])
    into retained_assets from jsonb_array_elements_text(coalesce(p_payload->'asset_ids','[]'::jsonb))
      with ordinality entry(value,ordinal);
  if cardinality(retained_assets)<>(select count(distinct value) from unnest(retained_assets) value)
     or cardinality(retained_assets)<>(select count(*) from argus_app.catalog_assets asset where asset.id=any(retained_assets) and asset.status='active') then
    raise exception 'invalid_editorial_evidence' using errcode='23514';
  end if;
  update argus_app.community_templates set asset_ids=retained_assets where id=retained_template_id;
  delete from argus_app.community_template_revision_assets where revision_id=p_revision_id;
  delete from argus_app.editorial_revision_assets where revision_id=p_revision_id;
  insert into argus_app.community_template_revision_assets(
    template_id,editorial_item_id,revision_id,asset_id,ordinal
  ) select retained_template_id,retained_item_id,p_revision_id,entry.value::uuid,entry.ordinal::integer
      from jsonb_array_elements_text(coalesce(p_payload->'asset_ids','[]'::jsonb))
        with ordinality entry(value,ordinal);
  insert into argus_app.editorial_revision_assets(item_id,revision_id,asset_id,ordinal)
  select retained_item_id,p_revision_id,entry.value::uuid,entry.ordinal::integer
    from jsonb_array_elements_text(coalesce(p_payload->'asset_ids','[]'::jsonb))
      with ordinality entry(value,ordinal);
exception when invalid_text_representation then
  raise exception 'invalid_editorial_payload' using errcode='23514';
end $$;

create or replace function argus_private.sync_coven_revision(
  p_revision_id uuid,p_payload jsonb
)
returns void language plpgsql security definer set search_path='' as $$
declare retained_item_id uuid; declare retained_coven_id uuid; declare retained_qualifications jsonb;
begin
  if not argus_private.has_staff_permission('editorial:write') then
    raise exception 'staff_permission_required' using errcode='42501';
  end if;
  retained_qualifications:=coalesce(
    p_payload->'qualifications',p_payload->'qualification_payload','[]'::jsonb
  );
  if jsonb_typeof(retained_qualifications)<>'array'
     or jsonb_array_length(retained_qualifications)>20
     or exists (
       select 1 from jsonb_array_elements(retained_qualifications) entry(value)
        where jsonb_typeof(entry.value)<>'object'
          or coalesce(entry.value->>'criterion_code',entry.value->>'criterion','')
             !~ '^[a-z][a-z0-9_]{0,63}$'
          or nullif(coalesce(entry.value->>'claim',entry.value->>'summary'),'') is null
     ) then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  select revision.item_id,coven.id into retained_item_id,retained_coven_id
    from argus_app.editorial_revisions revision
    join argus_app.editorial_items item on item.id=revision.item_id and item.kind='coven'
    join argus_app.coven_entries coven on coven.editorial_item_id=item.id
   where revision.id=p_revision_id and revision.state='draft';
  if retained_item_id is null then raise exception 'resource_not_found' using errcode='P0002'; end if;
  if exists (
    select 1 from jsonb_array_elements(retained_qualifications) entry(value)
     where entry.value->>'evidence_claim_id' is not null
       and not exists (
         select 1 from argus_app.evidence_claims claim
          where claim.id=(entry.value->>'evidence_claim_id')::uuid and claim.status='active'
       )
  ) then raise exception 'invalid_editorial_evidence' using errcode='23514'; end if;
  update argus_app.coven_entries set qualification_payload=retained_qualifications
   where id=retained_coven_id;
  delete from argus_app.coven_qualifications where revision_id=p_revision_id;
  insert into argus_app.coven_qualifications(
    coven_entry_id,editorial_item_id,revision_id,ordinal,criterion_code,claim,evidence_claim_id
  )
  select retained_coven_id,retained_item_id,p_revision_id,entry.ordinal::integer,
         coalesce(entry.value->>'criterion_code',entry.value->>'criterion'),
         coalesce(entry.value->>'claim',entry.value->>'summary'),
         nullif(entry.value->>'evidence_claim_id','')::uuid
    from jsonb_array_elements(retained_qualifications) with ordinality entry(value,ordinal);
exception when invalid_text_representation then
  raise exception 'invalid_editorial_payload' using errcode='23514';
end $$;

create or replace function argus_private.sync_rowan_revision(
  p_revision_id uuid,p_payload jsonb
)
returns void language plpgsql security definer set search_path='' as $$
declare retained_item_id uuid;
begin
  if not argus_private.has_staff_permission('editorial:write')
     or nullif(p_payload->>'body_template','') is null
     or nullif(p_payload->>'risk_footer','') is null
     or jsonb_typeof(p_payload->'allowed_tokens')<>'array'
     or p_payload->>'body_template' ~* '(urgent|exclusive|only I|guarantee|must invest|act now|love you|jealous)'
     or exists (
       select 1 from jsonb_array_elements_text(p_payload->'allowed_tokens') duplicate(value)
        group by duplicate.value having count(*)>1
     ) then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  select revision.item_id into retained_item_id
    from argus_app.editorial_revisions revision
    join argus_app.editorial_items item on item.id=revision.item_id and item.kind='rowan'
   where revision.id=p_revision_id and revision.state='draft';
  if retained_item_id is null then raise exception 'resource_not_found' using errcode='P0002'; end if;
  insert into argus_app.rowan_script_revisions(
    revision_id,body_template,allowed_tokens,risk_footer
  ) values (
    p_revision_id,p_payload->>'body_template',p_payload->'allowed_tokens',p_payload->>'risk_footer'
  ) on conflict (revision_id) do update set
    body_template=excluded.body_template,allowed_tokens=excluded.allowed_tokens,
    risk_footer=excluded.risk_footer;
end $$;

create or replace function argus_private.publish_editorial_revision(
  p_item_id uuid,p_revision_id uuid,p_reason text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare retained_kind text; declare retained_payload jsonb;
begin
  if not argus_private.has_staff_permission('editorial:publish')
     or nullif(p_reason,'') is null then
    raise exception 'staff_permission_required' using errcode='42501';
  end if;
  select item.kind,revision.payload into retained_kind,retained_payload
    from argus_app.editorial_items item
    join argus_app.editorial_revisions revision
      on revision.item_id=item.id and revision.id=p_revision_id
   where item.id=p_item_id and revision.state='approved'
   for update of item,revision;
  if retained_kind is null then raise exception 'resource_not_found' using errcode='P0002'; end if;
  if retained_kind='ritual' and not exists (
       select 1 from argus_app.ritual_scenario_revisions where revision_id=p_revision_id
     ) or retained_kind='asset_codex' and not exists (
       select 1 from argus_app.asset_codex_revisions where revision_id=p_revision_id
     ) or retained_kind='grimoire' and not exists (
       select 1 from argus_app.grimoire_revision_assets where revision_id=p_revision_id
     ) and coalesce(jsonb_array_length(retained_payload->'asset_ids'),0)>0
     or retained_kind='circle_template' and not exists (
       select 1 from argus_app.community_template_revision_assets where revision_id=p_revision_id
     ) and coalesce(jsonb_array_length(retained_payload->'asset_ids'),0)>0
     or retained_kind='coven' and not exists (
       select 1 from argus_app.coven_qualifications where revision_id=p_revision_id
     ) and coalesce(jsonb_array_length(coalesce(retained_payload->'qualifications',retained_payload->'qualification_payload')),0)>0
     or retained_kind='rowan' and not exists (
       select 1 from argus_app.rowan_script_revisions where revision_id=p_revision_id
     ) then
    raise exception 'normalized_revision_required' using errcode='23514';
  end if;
  insert into argus_app.editorial_render_documents(item_id,revision_id,document)
  values (p_item_id,p_revision_id,retained_payload);
  update argus_app.editorial_revisions set state='published'
   where item_id=p_item_id and id=p_revision_id and state='approved';
  update argus_app.editorial_items
     set status='published',current_published_revision_id=p_revision_id
   where id=p_item_id;
  insert into argus_app.publication_events(
    item_id,revision_id,action,effective_at,actor_id,reason
  ) values (
    p_item_id,p_revision_id,'publish',pg_catalog.clock_timestamp(),
    argus_private.trusted_request_user_id(),p_reason
  );
end
$$;

-- Published editorial is a cohesive read boundary shared by authenticated
-- members and auth-free preview. These bounded projections avoid exposing
-- draft/history tables to the runtime role and keep current-pointer checks
-- inside one measured query instead of multiplying nested RLS subplans.
create or replace function argus_private.list_current_published_editorial(
  p_kind text,p_limit integer
)
returns table(
  id uuid,kind text,slug text,revision_id uuid,
  revision_number integer,document jsonb
)
language sql
stable
security definer
set search_path=''
rows 100
as $$
  select item.id,item.kind,item.slug,revision.id,revision.revision_number,
         render_document.document
    from argus_app.editorial_items item
    join argus_app.editorial_revisions revision
      on revision.item_id=item.id
     and revision.id=item.current_published_revision_id
    join argus_app.editorial_render_documents render_document
      on render_document.item_id=item.id
     and render_document.revision_id=revision.id
   where p_limit between 1 and 100
     and item.status='published' and revision.state='published'
     and item.kind=p_kind
   order by item.slug,item.id
   limit p_limit
$$;

create or replace function argus_private.get_current_published_editorial(
  p_slug text
)
returns table(
  id uuid,kind text,slug text,revision_id uuid,
  revision_number integer,document jsonb
)
language sql
stable
security definer
set search_path=''
rows 1
as $$
  select item.id,item.kind,item.slug,revision.id,revision.revision_number,
         render_document.document
    from argus_app.editorial_items item
    join argus_app.editorial_revisions revision
      on revision.item_id=item.id
     and revision.id=item.current_published_revision_id
    join argus_app.editorial_render_documents render_document
      on render_document.item_id=item.id
     and render_document.revision_id=revision.id
   where item.status='published' and revision.state='published'
     and item.slug=p_slug
$$;

create or replace function argus_private.save_member_item(
  p_item_kind text,p_item_id uuid,p_source_kind text default 'direct',p_source_id uuid default null
)
returns table(
  user_id uuid,deletion_epoch bigint,item_kind text,item_id uuid,
  source_kind text,source_id uuid,saved_at timestamptz
)
language plpgsql
security definer
set search_path=''
as $$
declare retained_user_id uuid; declare retained_tenant_id uuid; declare retained_lifecycle_id uuid;
declare retained_epoch bigint; declare retained_id uuid; declare retained_saved_at timestamptz;
declare target_asset uuid; declare target_grimoire uuid; declare target_template uuid; declare target_coven uuid;
declare source_ritual uuid; declare source_circle uuid; declare source_editorial uuid; declare source_asset uuid;
begin
  retained_user_id:=argus_private.trusted_request_user_id();
  retained_tenant_id:=argus_private.trusted_request_tenant_id();
  retained_lifecycle_id:=argus_private.trusted_request_lifecycle_id();
  select member.deletion_epoch into retained_epoch from argus_app.members member
   where member.user_id=retained_user_id and member.lifecycle_id=retained_lifecycle_id;
  if retained_epoch is null or p_item_kind not in ('asset','grimoire','circle_template','coven')
     or p_source_kind not in ('direct','ritual','circle','discover','search') then
    raise exception 'resource_not_found' using errcode='P0002';
  end if;
  if p_item_kind='asset' then
    select asset.id into target_asset from argus_app.catalog_assets asset
     where asset.id=p_item_id and asset.status='active';
  elsif p_item_kind='grimoire' then
    select grimoire.id into target_grimoire from argus_app.grimoires grimoire
    join argus_app.editorial_items item on item.id=grimoire.editorial_item_id
     where grimoire.id=p_item_id and item.status='published';
  elsif p_item_kind='circle_template' then
    select template.id into target_template from argus_app.community_templates template
    join argus_app.editorial_items item on item.id=template.editorial_item_id
     where template.id=p_item_id and item.status='published';
  else
    select coven.id into target_coven from argus_app.coven_entries coven
    join argus_app.editorial_items item on item.id=coven.editorial_item_id
     where coven.id=p_item_id and item.status='published';
  end if;
  if num_nonnulls(target_asset,target_grimoire,target_template,target_coven)<>1 then
    raise exception 'resource_not_found' using errcode='P0002';
  end if;
  if p_source_kind='direct' and p_source_id is not null then
    raise exception 'resource_not_found' using errcode='P0002';
  elsif p_source_kind='ritual' then
    select assignment.id into source_ritual from argus_app.daily_ritual_assignments assignment
     where assignment.tenant_id=retained_tenant_id and assignment.lifecycle_id=retained_lifecycle_id
       and assignment.id=p_source_id;
  elsif p_source_kind='circle' then
    select circle.id into source_circle from argus_app.circles circle
     where circle.tenant_id=retained_tenant_id and circle.lifecycle_id=retained_lifecycle_id
       and circle.id=p_source_id;
  elsif p_source_kind='discover' then
    select item.id into source_editorial from argus_app.editorial_items item
     where item.id=p_source_id and item.status='published';
  elsif p_source_kind='search' then
    select asset.id into source_asset from argus_app.catalog_assets asset
     where asset.id=p_source_id and asset.status='active';
    if source_asset is null then
      select item.id into source_editorial from argus_app.editorial_items item
       where item.id=p_source_id and item.status='published';
    end if;
  end if;
  if p_source_kind<>'direct'
     and num_nonnulls(source_ritual,source_circle,source_editorial,source_asset)<>1 then
    raise exception 'resource_not_found' using errcode='P0002';
  end if;
  select saved.id into retained_id from argus_app.member_saved_items saved
   where saved.tenant_id=retained_tenant_id and saved.lifecycle_id=retained_lifecycle_id
     and saved.item_kind=p_item_kind
     and coalesce(saved.asset_id,saved.grimoire_id,saved.circle_template_id,saved.coven_entry_id)=p_item_id;
  if retained_id is null then
    insert into argus_app.member_saved_items as inserted_saved(
      tenant_id,lifecycle_id,user_id,item_kind,asset_id,grimoire_id,
      circle_template_id,coven_entry_id,source_kind,source_ritual_assignment_id,
      source_circle_id,source_editorial_item_id,source_catalog_asset_id
    ) values (
      retained_tenant_id,retained_lifecycle_id,retained_user_id,p_item_kind,
      target_asset,target_grimoire,target_template,target_coven,p_source_kind,
      source_ritual,source_circle,source_editorial,source_asset
    ) returning inserted_saved.id,inserted_saved.saved_at
      into retained_id,retained_saved_at;
  else
    update argus_app.member_saved_items saved set
      source_kind=p_source_kind,source_ritual_assignment_id=source_ritual,
      source_circle_id=source_circle,source_editorial_item_id=source_editorial,
      source_catalog_asset_id=source_asset
     where saved.id=retained_id returning saved.saved_at into retained_saved_at;
  end if;
  insert into argus_app.saved_items(
    user_id,deletion_epoch,tenant_id,lifecycle_id,item_kind,item_id,
    source_kind,source_id,saved_at
  ) values (
    retained_user_id,retained_epoch,retained_tenant_id,retained_lifecycle_id,
    p_item_kind,p_item_id,p_source_kind,p_source_id,retained_saved_at
  ) on conflict on constraint saved_items_pkey do update set
    source_kind=excluded.source_kind,source_id=excluded.source_id,saved_at=excluded.saved_at;
  return query select retained_user_id,retained_epoch,p_item_kind,p_item_id,
    p_source_kind,p_source_id,retained_saved_at;
end
$$;

create or replace function argus_private.unsave_member_item(
  p_item_kind text,p_item_id uuid
)
returns boolean language plpgsql security definer set search_path='' as $$
declare retained_user_id uuid; declare retained_lifecycle_id uuid; declare removed boolean;
begin
  retained_user_id:=argus_private.trusted_request_user_id();
  retained_lifecycle_id:=argus_private.trusted_request_lifecycle_id();
  delete from argus_app.member_saved_items saved
   where saved.user_id=retained_user_id and saved.lifecycle_id=retained_lifecycle_id
     and saved.item_kind=p_item_kind
     and coalesce(saved.asset_id,saved.grimoire_id,saved.circle_template_id,saved.coven_entry_id)=p_item_id;
  removed:=found;
  delete from argus_app.saved_items saved where saved.user_id=retained_user_id
    and saved.item_kind=p_item_kind and saved.item_id=p_item_id;
  return removed;
end $$;

create or replace function argus_private.create_content_report(
  p_target_kind text,p_target_id uuid,p_reason_code text,p_details text
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare retained_user_id uuid; declare retained_tenant_id uuid; declare retained_lifecycle_id uuid;
declare retained_epoch bigint; declare retained_report_id uuid;
declare target_editorial uuid; declare target_asset uuid; declare target_grimoire uuid;
declare target_template uuid; declare target_coven uuid;
begin
  retained_user_id:=argus_private.trusted_request_user_id();
  retained_tenant_id:=argus_private.trusted_request_tenant_id();
  retained_lifecycle_id:=argus_private.trusted_request_lifecycle_id();
  select member.deletion_epoch into retained_epoch from argus_app.members member
   where member.user_id=retained_user_id and member.lifecycle_id=retained_lifecycle_id;
  if retained_epoch is null or p_target_kind not in (
    'editorial','asset','grimoire','circle_template','coven'
  ) or nullif(p_reason_code,'') is null then
    raise exception 'resource_not_found' using errcode='P0002';
  end if;
  if p_target_kind='editorial' then
    select item.id into target_editorial from argus_app.editorial_items item
     where item.id=p_target_id and item.status='published';
  elsif p_target_kind='asset' then
    select asset.id into target_asset from argus_app.catalog_assets asset
     where asset.id=p_target_id and asset.status='active';
  elsif p_target_kind='grimoire' then
    select grimoire.id into target_grimoire from argus_app.grimoires grimoire
    join argus_app.editorial_items item on item.id=grimoire.editorial_item_id
     where grimoire.id=p_target_id and item.status='published';
  elsif p_target_kind='circle_template' then
    select template.id into target_template from argus_app.community_templates template
    join argus_app.editorial_items item on item.id=template.editorial_item_id
     where template.id=p_target_id and item.status='published';
  else
    select coven.id into target_coven from argus_app.coven_entries coven
    join argus_app.editorial_items item on item.id=coven.editorial_item_id
     where coven.id=p_target_id and item.status='published';
  end if;
  if num_nonnulls(target_editorial,target_asset,target_grimoire,target_template,target_coven)<>1 then
    raise exception 'resource_not_found' using errcode='P0002';
  end if;
  insert into argus_app.content_reports(
    user_id,deletion_epoch,tenant_id,lifecycle_id,target_kind,target_id,
    reason_code,details
  ) values (
    retained_user_id,retained_epoch,retained_tenant_id,retained_lifecycle_id,
    p_target_kind,p_target_id,p_reason_code,p_details
  ) returning id into retained_report_id;
  insert into argus_app.content_report_targets(
    report_id,tenant_id,lifecycle_id,target_kind,editorial_item_id,asset_id,
    grimoire_id,circle_template_id,coven_entry_id
  ) values (
    retained_report_id,retained_tenant_id,retained_lifecycle_id,p_target_kind,
    target_editorial,target_asset,target_grimoire,target_template,target_coven
  );
  insert into argus_private.outbox_events(
    user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
  ) values (
    retained_user_id,retained_epoch,'argus_jobs','content-report.created',
    retained_report_id,'content-report:'||retained_report_id::text
  );
  return retained_report_id;
end
$$;

-- The old generic kind-switch routines are intentionally removed. The API
-- selects one exact domain command, while shared publication remains one
-- atomic editorial primitive.
revoke all on function argus_private.create_editorial_kind_link(text,uuid,jsonb)
  from public,anon,authenticated,argus_runtime,argus_worker,argus_waitlist,
       argus_member,argus_staff,argus_callback,argus_migration,argus_edge;
revoke all on function argus_private.materialize_editorial_revision(text,uuid,jsonb)
  from public,anon,authenticated,argus_runtime,argus_worker,argus_waitlist,
       argus_member,argus_staff,argus_callback,argus_migration,argus_edge;
drop function argus_private.create_editorial_kind_link(text,uuid,jsonb);
drop function argus_private.materialize_editorial_revision(text,uuid,jsonb);

-- Re-anchor staff authorization on the trusted U3 transaction context.
create or replace function argus_private.has_staff_permission(p_permission text)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists (
    select 1 from argus_private.staff_principals staff
     where staff.user_id=argus_private.trusted_request_user_id()
       and staff.status='active' and staff.revoked_at is null
       and (p_permission=any(staff.permissions) or '*'=any(staff.permissions))
  )
$$;

create or replace function argus_private.has_live_staff_session(
  p_user_id uuid,p_session_id uuid
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select p_user_id=argus_private.trusted_request_user_id()
     and exists (
       select 1 from auth.sessions session
        where session.id=p_session_id and session.user_id=p_user_id
     )
$$;

-- The retained review trigger previously compared its reviewer to the legacy
-- caller-owned GUC. U4 re-anchors that identity check on the trusted U3
-- transaction context while preserving the reviewed distinct-actor rule.
create or replace function argus_private.enforce_editorial_review_decision()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare request_high_trust boolean;
declare revision_author uuid;
declare request_status text;
begin
  select request.high_trust,revision.author_staff_id,request.status
    into request_high_trust,revision_author,request_status
    from argus_app.editorial_review_requests request
    join argus_app.editorial_revisions revision on revision.id=request.revision_id
   where request.id=new.request_id;
  if not argus_private.has_staff_permission('editorial:review')
     or new.reviewer_id<>argus_private.trusted_request_user_id()
     or request_status<>'open' then
    raise exception 'invalid_editorial_review_decision' using errcode='23514';
  end if;
  if request_high_trust and revision_author=new.reviewer_id then
    raise exception 'self_approval' using errcode='42501';
  end if;
  return new;
end
$$;

-- Every U4 relation forces RLS. Owner/member/staff policies are command
-- specific and lead with the same tenant+lifecycle keys as their indexes.
do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'legacy_normalization_quarantine','legacy_normalization_identity_map',
    'onboarding_step_completions','notification_quiet_hours','member_saved_items',
    'content_report_targets','editorial_render_documents','editorial_revision_assets',
    'ritual_scenario_revision_assets','ritual_scenario_revision_evidence',
    'grimoire_revision_assets','community_template_revision_assets',
    'coven_qualifications','asset_codex_revisions',
    'asset_codex_revision_evidence','asset_codex_revision_metrics'
  ] loop
    execute pg_catalog.format('alter table argus_app.%I enable row level security',relation_name);
    execute pg_catalog.format('alter table argus_app.%I force row level security',relation_name);
    execute pg_catalog.format('revoke all on argus_app.%I from public,anon,authenticated',relation_name);
  end loop;
end
$$;

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'profiles','preferences','astrology_profiles','investor_profiles',
    'onboarding_states','consent_records','notification_preferences',
    'daily_ritual_assignments','circles','circle_assets','intentions',
    'future_mirror_runs','future_mirror_points','briefings','briefing_sections',
    'briefing_read_states','notifications'
  ] loop
    if relation_name not in (
      'investor_profiles','astrology_profiles','onboarding_states','consent_records',
      'intentions','future_mirror_runs','future_mirror_points'
    ) then
      execute pg_catalog.format('drop policy if exists runtime_owner on argus_app.%I',relation_name);
    end if;
    execute pg_catalog.format(
      'create policy u4_member_select on argus_app.%I for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()))',
      relation_name
    );
    execute pg_catalog.format(
      'create policy u4_member_insert on argus_app.%I for insert to argus_member with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()))',
      relation_name
    );
    execute pg_catalog.format(
      'create policy u4_member_update on argus_app.%I for update to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())) with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()))',
      relation_name
    );
    execute pg_catalog.format(
      'create policy u4_member_delete on argus_app.%I for delete to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()))',
      relation_name
    );
  end loop;
end
$$;

create policy u4_member_saved_select on argus_app.member_saved_items
  for select to argus_member using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_member_report_select on argus_app.content_reports
  for select to argus_member using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_member_report_target_select on argus_app.content_report_targets
  for select to argus_member using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );

create policy u4_member_onboarding_steps_select on argus_app.onboarding_step_completions
  for select to argus_member using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_member_quiet_hours_select on argus_app.notification_quiet_hours
  for select to argus_member using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );

create policy u4_member_root_select on argus_app.members
  for select to argus_member using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
    and status='active'
  );

create policy u4_member_catalog_assets on argus_app.catalog_assets
  for select to argus_member using (
    status='active' and (select argus_private.trusted_request_lifecycle_id()) is not null
  );
create policy u4_member_evidence_sources on argus_app.evidence_sources
  for select to argus_member using (
    status='active' and (select argus_private.trusted_request_lifecycle_id()) is not null
  );
create policy u4_member_evidence_claims on argus_app.evidence_claims
  for select to argus_member using (
    status='active' and (select argus_private.trusted_request_lifecycle_id()) is not null
  );
create policy u4_member_editorial_items on argus_app.editorial_items
  for select to argus_member using (
    status='published' and (select argus_private.trusted_request_lifecycle_id()) is not null
  );
create policy u4_member_editorial_revisions on argus_app.editorial_revisions
  for select to argus_member using (
    state='published' and (select argus_private.trusted_request_lifecycle_id()) is not null
  );

create policy u4_member_companies on argus_app.companies
  for select to argus_member using (
    status='active' and (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.coven_entries coven
      join argus_app.editorial_items item on item.id=coven.editorial_item_id
      where coven.company_id=companies.id and item.status='published')
  );
create policy u4_member_coven on argus_app.coven_entries
  for select to argus_member using (
    (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.editorial_items item
      where item.id=coven_entries.editorial_item_id and item.status='published')
  );
create policy u4_member_grimoires on argus_app.grimoires
  for select to argus_member using (
    (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.editorial_items item
      where item.id=grimoires.editorial_item_id and item.status='published')
  );
create policy u4_member_templates on argus_app.community_templates
  for select to argus_member using (
    (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.editorial_items item
      where item.id=community_templates.editorial_item_id and item.status='published')
  );
create policy u4_member_ritual_scenarios on argus_app.ritual_scenarios
  for select to argus_member using (
    (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.editorial_items item
      where item.id=ritual_scenarios.editorial_item_id and item.status='published')
  );
create policy u4_member_ritual_revisions on argus_app.ritual_scenario_revisions
  for select to argus_member using (
    (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.editorial_items item
      join argus_app.editorial_revisions revision on revision.id=item.current_published_revision_id
      where item.id=ritual_scenario_revisions.editorial_item_id
        and revision.id=ritual_scenario_revisions.revision_id
        and item.status='published' and revision.state='published')
  );
create policy u4_member_ritual_schedules on argus_app.ritual_schedules
  for select to argus_member using (
    state='active' and (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.editorial_revisions revision
      where revision.id=ritual_schedules.revision_id and revision.state='published')
  );
create policy u4_member_rowan_scripts on argus_app.rowan_scripts
  for select to argus_member using (
    (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.editorial_items item
      where item.id=rowan_scripts.editorial_item_id and item.status='published')
  );
create policy u4_member_rowan_revisions on argus_app.rowan_script_revisions
  for select to argus_member using (
    (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.editorial_items item
      where item.current_published_revision_id=rowan_script_revisions.revision_id
        and item.status='published')
  );
create policy u4_member_rowan_bindings on argus_app.rowan_context_bindings
  for select to argus_member using (
    (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.rowan_scripts script
      join argus_app.editorial_items item on item.id=script.editorial_item_id
      where script.id=rowan_context_bindings.script_id and item.status='published')
  );

create policy u4_member_render_documents on argus_app.editorial_render_documents
  for select to argus_member using (
    (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.editorial_items item
      join argus_app.editorial_revisions revision on revision.id=item.current_published_revision_id
      where item.id=editorial_render_documents.item_id
        and revision.id=editorial_render_documents.revision_id
        and item.status='published' and revision.state='published')
  );
-- The NOLOGIN publication-function owner has only these three SELECT
-- dependencies. Its bounded definers enforce current-pointer and state checks;
-- no login or capability role can assume this role directly.
create policy u4_publication_owner_item_read on argus_app.editorial_items
  for select to argus_publication_owner using (true);
create policy u4_publication_owner_revision_read on argus_app.editorial_revisions
  for select to argus_publication_owner using (true);
create policy u4_publication_owner_render_read on argus_app.editorial_render_documents
  for select to argus_publication_owner using (true);
do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'ritual_scenario_revision_assets','ritual_scenario_revision_evidence','grimoire_revision_assets',
    'community_template_revision_assets','coven_qualifications',
    'asset_codex_revisions','asset_codex_revision_evidence',
    'asset_codex_revision_metrics'
  ] loop
    execute pg_catalog.format(
      'create policy u4_member_published_revision on argus_app.%I for select to argus_member using ((select argus_private.trusted_request_lifecycle_id()) is not null and exists (select 1 from argus_app.editorial_items item join argus_app.editorial_revisions revision on revision.id=item.current_published_revision_id where item.id=(to_jsonb(%I)->>''editorial_item_id'')::uuid and revision.id=(to_jsonb(%I)->>''revision_id'')::uuid and item.status=''published'' and revision.state=''published''))',
      relation_name,relation_name,relation_name
    );
  end loop;
end
$$;
create policy u4_member_editorial_revision_assets on argus_app.editorial_revision_assets
  for select to argus_member using (
    (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (select 1 from argus_app.editorial_items item
      join argus_app.editorial_revisions revision on revision.id=item.current_published_revision_id
      where item.id=editorial_revision_assets.item_id
        and revision.id=editorial_revision_assets.revision_id
        and item.status='published' and revision.state='published')
  );

-- Staff policies remain permission-specific.
do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'catalog_assets','evidence_sources','evidence_claims','media_assets',
    'editorial_items','editorial_revisions','editorial_review_requests',
    'editorial_review_decisions','publication_events','ritual_scenarios',
    'ritual_scenario_revisions','ritual_schedules','rowan_scripts',
    'rowan_script_revisions','rowan_context_bindings','companies','coven_entries',
    'grimoires','community_templates','moderation_cases',
    'editorial_render_documents','editorial_revision_assets',
    'ritual_scenario_revision_assets','ritual_scenario_revision_evidence',
    'grimoire_revision_assets','community_template_revision_assets',
    'coven_qualifications','asset_codex_revisions',
    'asset_codex_revision_evidence','asset_codex_revision_metrics',
    'legacy_normalization_quarantine','legacy_normalization_identity_map'
  ] loop
    execute pg_catalog.format(
      'create policy u4_staff_read on argus_app.%I for select to argus_staff using ((select argus_private.has_staff_permission(''editorial:read'')) or (select argus_private.has_staff_permission(''editorial:write'')) or (select argus_private.has_staff_permission(''editorial:review'')) or (select argus_private.has_staff_permission(''editorial:publish'')))',
      relation_name
    );
  end loop;
end
$$;

create policy u4_staff_item_insert on argus_app.editorial_items
  for insert to argus_staff with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_staff_item_update on argus_app.editorial_items
  for update to argus_staff
  using ((select argus_private.has_staff_permission('editorial:write')) or (select argus_private.has_staff_permission('editorial:publish')))
  with check ((select argus_private.has_staff_permission('editorial:write')) or (select argus_private.has_staff_permission('editorial:publish')));
create policy u4_staff_item_delete on argus_app.editorial_items
  for delete to argus_staff using ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_staff_revision_insert on argus_app.editorial_revisions
  for insert to argus_staff with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_staff_revision_update on argus_app.editorial_revisions
  for update to argus_staff
  using ((select argus_private.has_staff_permission('editorial:write')) or (select argus_private.has_staff_permission('editorial:review')) or (select argus_private.has_staff_permission('editorial:publish')))
  with check ((select argus_private.has_staff_permission('editorial:write')) or (select argus_private.has_staff_permission('editorial:review')) or (select argus_private.has_staff_permission('editorial:publish')));
create policy u4_staff_revision_delete on argus_app.editorial_revisions
  for delete to argus_staff using (state='draft' and (select argus_private.has_staff_permission('editorial:write')));
create policy u4_staff_review_request_insert on argus_app.editorial_review_requests
  for insert to argus_staff with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_staff_review_request_update on argus_app.editorial_review_requests
  for update to argus_staff using ((select argus_private.has_staff_permission('editorial:review')))
  with check ((select argus_private.has_staff_permission('editorial:review')));
create policy u4_staff_review_decision_insert on argus_app.editorial_review_decisions
  for insert to argus_staff with check ((select argus_private.has_staff_permission('editorial:review')));
create policy u4_staff_publication_event_insert on argus_app.publication_events
  for insert to argus_staff with check ((select argus_private.has_staff_permission('editorial:publish')));

-- Security-definer application commands receive only their demonstrated
-- relation/action dependencies. FORCE RLS keeps the NOLOGIN owner constrained
-- even though it owns U4's newly introduced relations.
create policy u4_app_owner_member_read on argus_app.members
  for select to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
    and user_id=(select argus_private.trusted_request_user_id())
    and status='active'
  );
create policy u4_app_owner_assignment_read on argus_app.daily_ritual_assignments
  for select to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_circle_read on argus_app.circles
  for select to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );

create policy u4_app_owner_catalog_read on argus_app.catalog_assets
  for select to argus_app_owner using (
    status='active' and (
      (select argus_private.trusted_request_lifecycle_id()) is not null
      or (select argus_private.has_staff_permission('editorial:write'))
      or (select argus_private.has_staff_permission('editorial:publish'))
    )
  );
create policy u4_app_owner_evidence_read on argus_app.evidence_claims
  for select to argus_app_owner using (
    status='active' and (select argus_private.has_staff_permission('editorial:write'))
  );
create policy u4_app_owner_item_read on argus_app.editorial_items
  for select to argus_app_owner using (
    ((select argus_private.trusted_request_lifecycle_id()) is not null and status='published')
    or (select argus_private.has_staff_permission('editorial:write'))
    or (select argus_private.has_staff_permission('editorial:publish'))
  );
create policy u4_app_owner_revision_read on argus_app.editorial_revisions
  for select to argus_app_owner using (
    (select argus_private.has_staff_permission('editorial:write'))
    or (select argus_private.has_staff_permission('editorial:publish'))
  );
create policy u4_app_owner_grimoire_read on argus_app.grimoires
  for select to argus_app_owner using (
    (select argus_private.has_staff_permission('editorial:write'))
    or exists (select 1 from argus_app.editorial_items item
      where item.id=grimoires.editorial_item_id and item.status='published')
  );
create policy u4_app_owner_template_read on argus_app.community_templates
  for select to argus_app_owner using (
    (select argus_private.has_staff_permission('editorial:write'))
    or exists (select 1 from argus_app.editorial_items item
      where item.id=community_templates.editorial_item_id and item.status='published')
  );
create policy u4_app_owner_coven_read on argus_app.coven_entries
  for select to argus_app_owner using (
    (select argus_private.has_staff_permission('editorial:write'))
    or exists (select 1 from argus_app.editorial_items item
      where item.id=coven_entries.editorial_item_id and item.status='published')
  );

create policy u4_app_owner_ritual_insert on argus_app.ritual_scenarios
  for insert to argus_app_owner with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_rowan_insert on argus_app.rowan_scripts
  for insert to argus_app_owner with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_coven_insert on argus_app.coven_entries
  for insert to argus_app_owner with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_grimoire_insert on argus_app.grimoires
  for insert to argus_app_owner with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_template_insert on argus_app.community_templates
  for insert to argus_app_owner with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_grimoire_compat_update on argus_app.grimoires
  for update to argus_app_owner using ((select argus_private.has_staff_permission('editorial:write')))
  with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_template_compat_update on argus_app.community_templates
  for update to argus_app_owner using ((select argus_private.has_staff_permission('editorial:write')))
  with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_coven_compat_update on argus_app.coven_entries
  for update to argus_app_owner using ((select argus_private.has_staff_permission('editorial:write')))
  with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_ritual_revision_read on argus_app.ritual_scenario_revisions
  for select to argus_app_owner using (
    (select argus_private.has_staff_permission('editorial:write'))
    or (select argus_private.has_staff_permission('editorial:publish'))
  );
create policy u4_app_owner_ritual_revision_insert on argus_app.ritual_scenario_revisions
  for insert to argus_app_owner with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_ritual_revision_update on argus_app.ritual_scenario_revisions
  for update to argus_app_owner using ((select argus_private.has_staff_permission('editorial:write')))
  with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_rowan_revision_read on argus_app.rowan_script_revisions
  for select to argus_app_owner using (
    (select argus_private.has_staff_permission('editorial:write'))
    or (select argus_private.has_staff_permission('editorial:publish'))
  );
create policy u4_app_owner_rowan_revision_insert on argus_app.rowan_script_revisions
  for insert to argus_app_owner with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_rowan_revision_update on argus_app.rowan_script_revisions
  for update to argus_app_owner using ((select argus_private.has_staff_permission('editorial:write')))
  with check ((select argus_private.has_staff_permission('editorial:write')));

do $$
declare relation_name text;
begin
  -- Publication reads only the normalized roots needed to prove that an
  -- approved rendering has an editable relational authority. The Asset
  -- Codex synchronizer also reads its children to verify input cardinality.
  foreach relation_name in array array[
    'grimoire_revision_assets','community_template_revision_assets',
    'coven_qualifications','asset_codex_revisions',
    'asset_codex_revision_evidence','asset_codex_revision_metrics'
  ] loop
    execute pg_catalog.format(
      'create policy u4_app_owner_normalized_read on argus_app.%I for select to argus_app_owner using ((select argus_private.has_staff_permission(''editorial:write'')) or (select argus_private.has_staff_permission(''editorial:publish'')))',
      relation_name
    );
  end loop;

  -- These ordered children are replaced atomically by the corresponding
  -- domain synchronizer. No application command updates individual rows.
  foreach relation_name in array array[
    'editorial_revision_assets','ritual_scenario_revision_assets','ritual_scenario_revision_evidence',
    'grimoire_revision_assets','community_template_revision_assets',
    'coven_qualifications','asset_codex_revision_evidence',
    'asset_codex_revision_metrics'
  ] loop
    execute pg_catalog.format(
      'create policy u4_app_owner_normalized_insert on argus_app.%I for insert to argus_app_owner with check ((select argus_private.has_staff_permission(''editorial:write'')))',
      relation_name
    );
    execute pg_catalog.format(
      'create policy u4_app_owner_normalized_delete on argus_app.%I for delete to argus_app_owner using ((select argus_private.has_staff_permission(''editorial:write'')))',
      relation_name
    );
  end loop;
end
$$;
create policy u4_app_owner_asset_codex_insert on argus_app.asset_codex_revisions
  for insert to argus_app_owner with check ((select argus_private.has_staff_permission('editorial:write')));
create policy u4_app_owner_asset_codex_update on argus_app.asset_codex_revisions
  for update to argus_app_owner using ((select argus_private.has_staff_permission('editorial:write')))
  with check ((select argus_private.has_staff_permission('editorial:write')));

create policy u4_app_owner_onboarding_sync_insert on argus_app.onboarding_step_completions
  for insert to argus_app_owner with check (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_onboarding_sync_delete on argus_app.onboarding_step_completions
  for delete to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_quiet_sync_insert on argus_app.notification_quiet_hours
  for insert to argus_app_owner with check (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_quiet_sync_delete on argus_app.notification_quiet_hours
  for delete to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );

create policy u4_app_owner_saved_read on argus_app.member_saved_items
  for select to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_saved_insert on argus_app.member_saved_items
  for insert to argus_app_owner with check (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_saved_update on argus_app.member_saved_items
  for update to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  ) with check (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_saved_delete on argus_app.member_saved_items
  for delete to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );

-- U6's private purge definer is owned by the NOLOGIN postgres role and
-- dispatches the reviewed user_id purge manifest. Keep only the exact DELETE
-- bridge it needs for U4's newly app-owner-owned saved authority.
create policy u4_u6_privacy_purge_saved_delete on argus_app.member_saved_items
  for delete to postgres using (true);
create policy u4_app_owner_saved_compat_read on argus_app.saved_items
  for select to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_saved_compat_insert on argus_app.saved_items
  for insert to argus_app_owner with check (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_saved_compat_update on argus_app.saved_items
  for update to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  ) with check (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_saved_compat_delete on argus_app.saved_items
  for delete to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );

create policy u4_app_owner_report_read on argus_app.content_reports
  for select to argus_app_owner using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_report_insert on argus_app.content_reports
  for insert to argus_app_owner with check (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_report_target_insert on argus_app.content_report_targets
  for insert to argus_app_owner with check (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
  );
create policy u4_app_owner_report_outbox on argus_private.outbox_events
  for insert to argus_app_owner with check (
    topic='argus_jobs' and event_type='content-report.created'
    and user_id=(select argus_private.trusted_request_user_id())
  );

create policy u4_app_owner_item_publish_update on argus_app.editorial_items
  for update to argus_app_owner using ((select argus_private.has_staff_permission('editorial:publish')))
  with check ((select argus_private.has_staff_permission('editorial:publish')));
create policy u4_app_owner_revision_publish_update on argus_app.editorial_revisions
  for update to argus_app_owner using ((select argus_private.has_staff_permission('editorial:publish')))
  with check ((select argus_private.has_staff_permission('editorial:publish')));
create policy u4_app_owner_render_insert on argus_app.editorial_render_documents
  for insert to argus_app_owner with check ((select argus_private.has_staff_permission('editorial:publish')));
create policy u4_app_owner_publication_insert on argus_app.publication_events
  for insert to argus_app_owner with check ((select argus_private.has_staff_permission('editorial:publish')));
create policy u4_staff_editorial_audit_insert on argus_private.admin_audit_events
  for insert to argus_staff with check (
    actor_user_id=(select argus_private.trusted_request_user_id())
    and action like 'editorial.%'
    and target_kind='editorial_item'
  );

-- U4 removes the legacy runtime policy families on relations whose member and
-- staff consumers now assume the exact U3 capabilities. Anonymous publication
-- reads use the two bounded projection functions above and therefore retain no
-- direct table policy or grant. U5/U6 policies are absent from this matrix.
do $$
declare policy_row record;
begin
  for policy_row in
    select * from (values
      ('catalog_assets','runtime_published_read'),
      ('catalog_assets','runtime_staff_write'),
      ('community_templates','runtime_editorial_read'),
      ('community_templates','runtime_editorial_write'),
      ('community_templates','runtime_member_published_template_read'),
      ('companies','runtime_editorial_read'),
      ('companies','runtime_editorial_write'),
      ('companies','runtime_member_published_company_read'),
      ('coven_entries','runtime_editorial_read'),
      ('coven_entries','runtime_editorial_write'),
      ('coven_entries','runtime_member_published_coven_read'),
      ('editorial_items','runtime_editorial_publish_item_update'),
      ('editorial_items','runtime_editorial_read'),
      ('editorial_items','runtime_editorial_review_publish_item_read'),
      ('editorial_items','runtime_editorial_write'),
      ('editorial_items','runtime_published_editorial'),
      ('editorial_review_decisions','runtime_editorial_read'),
      ('editorial_review_decisions','runtime_editorial_reviewer_decision_insert'),
      ('editorial_review_decisions','runtime_editorial_write'),
      ('editorial_review_requests','runtime_editorial_read'),
      ('editorial_review_requests','runtime_editorial_reviewer_request'),
      ('editorial_review_requests','runtime_editorial_reviewer_request_update'),
      ('editorial_review_requests','runtime_editorial_write'),
      ('editorial_revisions','runtime_editorial_read'),
      ('editorial_revisions','runtime_editorial_review_publish_revision_read'),
      ('editorial_revisions','runtime_editorial_review_publish_revision_update'),
      ('editorial_revisions','runtime_editorial_write'),
      ('editorial_revisions','runtime_published_revisions'),
      ('evidence_claims','runtime_editorial_read'),
      ('evidence_claims','runtime_editorial_write'),
      ('evidence_claims','runtime_member_active_evidence_claim_read'),
      ('evidence_sources','runtime_editorial_read'),
      ('evidence_sources','runtime_editorial_write'),
      ('evidence_sources','runtime_member_active_evidence_source_read'),
      ('grimoires','runtime_editorial_read'),
      ('grimoires','runtime_editorial_write'),
      ('grimoires','runtime_member_published_grimoire_read'),
      ('publication_events','runtime_editorial_publisher_event_insert'),
      ('publication_events','runtime_editorial_read'),
      ('publication_events','runtime_editorial_write'),
      ('ritual_scenario_revisions','runtime_editorial_read'),
      ('ritual_scenario_revisions','runtime_editorial_write'),
      ('ritual_scenario_revisions','runtime_member_published_ritual_revision_read'),
      ('ritual_scenarios','runtime_editorial_read'),
      ('ritual_scenarios','runtime_editorial_write'),
      ('ritual_scenarios','runtime_member_published_ritual_scenario_read'),
      ('ritual_schedules','runtime_active_ritual_schedules'),
      ('ritual_schedules','runtime_editorial_read'),
      ('ritual_schedules','runtime_editorial_write'),
      ('rowan_context_bindings','runtime_editorial_read'),
      ('rowan_context_bindings','runtime_editorial_write'),
      ('rowan_context_bindings','runtime_member_published_rowan_binding_read'),
      ('rowan_script_revisions','runtime_editorial_read'),
      ('rowan_script_revisions','runtime_editorial_write'),
      ('rowan_script_revisions','runtime_member_published_rowan_revision_read'),
      ('rowan_scripts','runtime_editorial_read'),
      ('rowan_scripts','runtime_editorial_write'),
      ('rowan_scripts','runtime_member_published_rowan_script_read')
    ) explicit_policy(relation_name,policy_name)
  loop
    execute pg_catalog.format(
      'drop policy if exists %I on argus_app.%I',
      policy_row.policy_name,policy_row.relation_name
    );
  end loop;
end
$$;

revoke all on
  argus_app.catalog_assets,argus_app.evidence_sources,argus_app.evidence_claims,
  argus_app.editorial_items,argus_app.editorial_revisions,
  argus_app.editorial_review_requests,argus_app.editorial_review_decisions,
  argus_app.publication_events,argus_app.ritual_scenarios,
  argus_app.ritual_scenario_revisions,argus_app.ritual_schedules,
  argus_app.rowan_scripts,argus_app.rowan_script_revisions,
  argus_app.rowan_context_bindings,argus_app.companies,argus_app.coven_entries,
  argus_app.grimoires,argus_app.community_templates
from argus_runtime;
grant select on
  argus_app.editorial_items,argus_app.editorial_revisions,
  argus_app.editorial_render_documents
to argus_publication_owner;

revoke all on
  argus_app.profiles,argus_app.preferences,argus_app.astrology_profiles,
  argus_app.investor_profiles,argus_app.onboarding_states,argus_app.consent_records,
  argus_app.notification_preferences,argus_app.daily_ritual_assignments,
  argus_app.circles,argus_app.circle_assets,argus_app.saved_items,
  argus_app.intentions,argus_app.future_mirror_runs,argus_app.future_mirror_points,
  argus_app.briefings,argus_app.briefing_sections,argus_app.briefing_read_states,
  argus_app.notifications,argus_app.content_reports
from argus_runtime;

-- U6's member idempotency ledger still shares a transaction with onboarding
-- finalization and scenario creation. These exact U4 relations retain their
-- runtime policy/grant until U6 replaces that private durable-work seam.
grant select,insert,update,delete on
  argus_app.investor_profiles,argus_app.astrology_profiles,
  argus_app.onboarding_states,argus_app.consent_records,argus_app.intentions,
  argus_app.future_mirror_runs,argus_app.future_mirror_points
to argus_runtime;

grant select on argus_app.members,
  argus_app.catalog_assets,argus_app.evidence_sources,argus_app.evidence_claims,
  argus_app.editorial_items,argus_app.editorial_revisions,argus_app.ritual_scenarios,
  argus_app.ritual_scenario_revisions,argus_app.ritual_schedules,argus_app.companies,
  argus_app.coven_entries,argus_app.grimoires,argus_app.community_templates,
  argus_app.rowan_scripts,argus_app.rowan_script_revisions,
  argus_app.rowan_context_bindings,argus_app.editorial_render_documents,
  argus_app.editorial_revision_assets,argus_app.ritual_scenario_revision_assets,
  argus_app.ritual_scenario_revision_evidence,argus_app.grimoire_revision_assets,
  argus_app.community_template_revision_assets,argus_app.coven_qualifications,
  argus_app.asset_codex_revisions,argus_app.asset_codex_revision_evidence,
  argus_app.asset_codex_revision_metrics,argus_app.onboarding_step_completions,
  argus_app.notification_quiet_hours,argus_app.member_saved_items,
  argus_app.content_report_targets
to argus_member;
grant select,insert,update,delete on
  argus_app.profiles,argus_app.preferences,argus_app.astrology_profiles,
  argus_app.investor_profiles,argus_app.onboarding_states,argus_app.consent_records,
  argus_app.notification_preferences,argus_app.daily_ritual_assignments,
  argus_app.circles,argus_app.circle_assets,argus_app.intentions,
  argus_app.future_mirror_runs,argus_app.future_mirror_points,argus_app.briefings,
  argus_app.briefing_sections,argus_app.briefing_read_states,argus_app.notifications
to argus_member;
grant select on argus_app.content_reports to argus_member;

grant select on
  argus_app.catalog_assets,argus_app.evidence_sources,argus_app.evidence_claims,
  argus_app.media_assets,argus_app.editorial_items,argus_app.editorial_revisions,
  argus_app.editorial_review_requests,argus_app.editorial_review_decisions,
  argus_app.publication_events,argus_app.ritual_scenarios,
  argus_app.ritual_scenario_revisions,argus_app.ritual_schedules,
  argus_app.rowan_scripts,argus_app.rowan_script_revisions,
  argus_app.rowan_context_bindings,argus_app.companies,argus_app.coven_entries,
  argus_app.grimoires,argus_app.community_templates,argus_app.moderation_cases
to argus_staff;
grant insert,update,delete on
  argus_app.editorial_items,argus_app.editorial_revisions
to argus_staff;
grant insert,update on argus_app.editorial_review_requests to argus_staff;
grant insert on
  argus_app.editorial_review_decisions,argus_app.publication_events
to argus_staff;
grant select on
  argus_app.editorial_render_documents,argus_app.editorial_revision_assets,
  argus_app.ritual_scenario_revision_assets,argus_app.ritual_scenario_revision_evidence,
  argus_app.grimoire_revision_assets,argus_app.community_template_revision_assets,
  argus_app.coven_qualifications,argus_app.asset_codex_revisions,
  argus_app.asset_codex_revision_evidence,argus_app.asset_codex_revision_metrics,
  argus_app.legacy_normalization_quarantine,argus_app.legacy_normalization_identity_map
to argus_staff;
grant insert on argus_private.admin_audit_events to argus_staff;

-- Exact dependencies of the U4 application commands. Relations introduced by
-- this migration are transferred to argus_app_owner below; their owner rights
-- remain constrained by FORCE RLS and the command-specific policies above.
grant select on
  argus_app.members,argus_app.catalog_assets,argus_app.evidence_claims,
  argus_app.editorial_items,argus_app.editorial_revisions,
  argus_app.ritual_scenario_revisions,argus_app.rowan_script_revisions,
  argus_app.coven_entries,argus_app.grimoires,argus_app.community_templates,
  argus_app.daily_ritual_assignments,argus_app.circles,argus_app.saved_items,
  argus_app.content_reports
to argus_app_owner;
grant insert on
  argus_app.publication_events,argus_app.ritual_scenarios,
  argus_app.ritual_scenario_revisions,argus_app.rowan_scripts,
  argus_app.rowan_script_revisions,argus_app.coven_entries,
  argus_app.grimoires,argus_app.community_templates,argus_app.saved_items,
  argus_app.content_reports
to argus_app_owner;
grant update on
  argus_app.editorial_items,argus_app.editorial_revisions,
  argus_app.ritual_scenario_revisions,argus_app.rowan_script_revisions,
  argus_app.coven_entries,argus_app.grimoires,argus_app.community_templates,
  argus_app.saved_items
to argus_app_owner;
grant delete on argus_app.saved_items to argus_app_owner;
grant insert on argus_private.outbox_events to argus_app_owner;

revoke all on function
  argus_private.bind_argus_app_member_lifecycle(),
  argus_private.sync_onboarding_step_completions(),
  argus_private.sync_notification_quiet_hours(),
  argus_private.reject_sealed_u4_document_change(),
  argus_private.protect_u4_legacy_relation(),
  argus_private.protect_future_mirror_assumptions(),
  argus_private.create_ritual_editorial_item(uuid,jsonb),
  argus_private.create_rowan_editorial_item(uuid,jsonb),
  argus_private.create_coven_editorial_item(uuid,jsonb),
  argus_private.create_grimoire_editorial_item(uuid,jsonb),
  argus_private.create_circle_template_editorial_item(uuid,jsonb),
  argus_private.sync_ritual_revision(uuid,jsonb),
  argus_private.sync_asset_codex_revision(uuid,jsonb),
  argus_private.sync_grimoire_revision(uuid,jsonb),
  argus_private.sync_circle_template_revision(uuid,jsonb),
  argus_private.sync_coven_revision(uuid,jsonb),
  argus_private.sync_rowan_revision(uuid,jsonb),
  argus_private.publish_editorial_revision(uuid,uuid,text),
  argus_private.list_current_published_editorial(text,integer),
  argus_private.get_current_published_editorial(text),
  argus_private.save_member_item(text,uuid,text,uuid),
  argus_private.unsave_member_item(text,uuid),
  argus_private.create_content_report(text,uuid,text,text)
from public,anon,authenticated,argus_runtime,argus_worker,argus_waitlist,
  argus_member,argus_staff,argus_callback,argus_migration,argus_edge;

grant execute on function
  argus_private.list_current_published_editorial(text,integer),
  argus_private.get_current_published_editorial(text)
to argus_runtime,argus_member;
grant execute on function
  argus_private.create_ritual_editorial_item(uuid,jsonb),
  argus_private.create_rowan_editorial_item(uuid,jsonb),
  argus_private.create_coven_editorial_item(uuid,jsonb),
  argus_private.create_grimoire_editorial_item(uuid,jsonb),
  argus_private.create_circle_template_editorial_item(uuid,jsonb),
  argus_private.sync_ritual_revision(uuid,jsonb),
  argus_private.sync_asset_codex_revision(uuid,jsonb),
  argus_private.sync_grimoire_revision(uuid,jsonb),
  argus_private.sync_circle_template_revision(uuid,jsonb),
  argus_private.sync_coven_revision(uuid,jsonb),
  argus_private.sync_rowan_revision(uuid,jsonb),
  argus_private.publish_editorial_revision(uuid,uuid,text)
to argus_staff;
grant execute on function
  argus_private.save_member_item(text,uuid,text,uuid),
  argus_private.unsave_member_item(text,uuid),
  argus_private.create_content_report(text,uuid,text,text)
to argus_member;
do $$
begin
  if exists (
    select 1
      from pg_catalog.pg_proc function_row
      join pg_catalog.pg_namespace namespace
        on namespace.oid=function_row.pronamespace
      join pg_catalog.pg_roles owner on owner.oid=function_row.proowner
     where namespace.nspname='argus_private'
       and function_row.proname in ('has_staff_permission','has_live_staff_session')
       and owner.rolname<>session_user
  ) then
    raise exception 'u4_staff_helper_owner_mismatch' using errcode='42501';
  end if;
end
$$;
grant execute on function
  argus_private.has_staff_permission(text),
  argus_private.has_live_staff_session(uuid,uuid)
to argus_staff;
grant execute on function
  argus_private.has_staff_permission(text)
to argus_app_owner;

comment on table argus_app.content_report_targets is
  'U4 typed published-content target. Unsupported and missing targets fail without existence detail.';
comment on function argus_private.list_current_published_editorial(text,integer) is
  'U4 bounded current-publication projection; callers receive no draft or historical relation privilege.';
comment on function argus_private.get_current_published_editorial(text) is
  'U4 exact current-publication lookup; unpublished slugs return no row without existence detail.';

grant argus_app_owner,argus_publication_owner to current_user with set true;
grant create on schema argus_app,argus_private to argus_app_owner;
grant create on schema argus_private to argus_publication_owner;

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'legacy_normalization_quarantine','legacy_normalization_identity_map',
    'onboarding_step_completions','notification_quiet_hours','member_saved_items',
    'content_report_targets','editorial_render_documents','editorial_revision_assets',
    'ritual_scenario_revision_assets','ritual_scenario_revision_evidence',
    'grimoire_revision_assets','community_template_revision_assets',
    'coven_qualifications','asset_codex_revisions',
    'asset_codex_revision_evidence','asset_codex_revision_metrics'
  ] loop
    execute pg_catalog.format('alter table argus_app.%I owner to argus_app_owner',relation_name);
  end loop;
end
$$;

-- ALTER OWNER discards an old owner's redundant self-grant, so author this
-- exact U6 purge ACL only after the normalized relation has its final owner.
set local role argus_app_owner;
grant delete on argus_app.member_saved_items to postgres;
reset role;

alter function argus_private.bind_argus_app_member_lifecycle() owner to argus_app_owner;
alter function argus_private.sync_onboarding_step_completions() owner to argus_app_owner;
alter function argus_private.sync_notification_quiet_hours() owner to argus_app_owner;
alter function argus_private.reject_sealed_u4_document_change() owner to argus_app_owner;
alter function argus_private.protect_u4_legacy_relation() owner to argus_app_owner;
alter function argus_private.protect_future_mirror_assumptions() owner to argus_app_owner;
alter function argus_private.create_ritual_editorial_item(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.create_rowan_editorial_item(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.create_coven_editorial_item(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.create_grimoire_editorial_item(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.create_circle_template_editorial_item(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.sync_ritual_revision(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.sync_asset_codex_revision(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.sync_grimoire_revision(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.sync_circle_template_revision(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.sync_coven_revision(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.sync_rowan_revision(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.publish_editorial_revision(uuid,uuid,text) owner to argus_app_owner;
alter function argus_private.save_member_item(text,uuid,text,uuid) owner to argus_app_owner;
alter function argus_private.unsave_member_item(text,uuid) owner to argus_app_owner;
alter function argus_private.create_content_report(text,uuid,text,text) owner to argus_app_owner;
alter function argus_private.list_current_published_editorial(text,integer)
  owner to argus_publication_owner;
alter function argus_private.get_current_published_editorial(text)
  owner to argus_publication_owner;

revoke create on schema argus_app,argus_private from argus_app_owner;
revoke create on schema argus_private from argus_publication_owner;
revoke argus_app_owner from current_user;
revoke argus_publication_owner from current_user;

comment on column argus_app.onboarding_states.completed_steps is
  'U4 read-only compatibility projection; onboarding_step_completions is editable authority through the synchronization trigger.';
comment on column argus_app.notification_preferences.quiet_hours is
  'U4 compatibility envelope; notification_quiet_hours is the typed authority and legacy mutation is atomically validated/synchronized.';
comment on column argus_app.ritual_scenario_revisions.idea_asset_ids is
  'U4 compatibility-only ordered array; ritual_scenario_revision_assets is authoritative.';
comment on column argus_app.ritual_scenario_revisions.evidence_claim_ids is
  'U4 compatibility-only ordered array; ritual_scenario_revision_evidence is authoritative.';
comment on column argus_app.grimoires.asset_ids is
  'U4 compatibility-only array retained through U9; grimoire_revision_assets is authoritative.';
comment on column argus_app.community_templates.asset_ids is
  'U4 compatibility-only array retained through U9; community_template_revision_assets is authoritative.';
comment on column argus_app.coven_entries.qualification_payload is
  'U4 sealed compatibility document retained through U9; coven_qualifications is authoritative.';
comment on table argus_app.saved_items is
  'U4 read-only compatibility table retained through U9; member_saved_items is the typed authority.';
comment on function argus_private.enforce_live_member_epoch() is
  'U5/U6 compatibility trigger only: brokerage, callbacks, queues, privacy, Storage and private operational relations remain for their owning units.';
comment on role argus_worker is
  'U6 compatibility capability: retained deletion_epoch grants/policies remain until queues, privacy, purge and briefing workers adopt lifecycle-bound durable context.';
comment on role argus_publication_owner is
  'U4 NOLOGIN owner for bounded current-publication read functions; exact SELECT on item, revision and sealed render only.';
comment on role argus_runtime is
  'U5/U6 compatibility plus auth-free published preview reads; U4 member/staff mutations use argus_member/argus_staff.';

commit;

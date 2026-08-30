begin;

-- Starpath is factual investment literacy wrapped in optional mythic mnemonic
-- language. The database keeps those two kinds of copy structurally separate
-- and requires two exact-revision attestations before an eight-node manifest
-- can become member-visible.

alter table argus_app.editorial_items
  drop constraint editorial_items_kind_check,
  add constraint editorial_items_kind_check check (
    kind in (
      'ritual','asset_codex','coven','grimoire','circle_template','rowan',
      'briefing_template','starpath_lesson'
    )
  );

alter table argus_app.editorial_review_requests
  add column discipline text not null default 'general',
  add column sealed_content_hash text,
  add column policy_version text;

update argus_app.editorial_review_requests request
   set discipline='general',
       sealed_content_hash=revision.payload_canonical_hash,
       policy_version='legacy-general-v1'
  from argus_app.editorial_revisions revision
 where revision.id=request.revision_id;

alter table argus_app.editorial_review_requests
  alter column policy_version set not null,
  alter column policy_version set default 'legacy-general-v1',
  add constraint editorial_review_requests_discipline_check
    check (discipline in ('general','factual','compliance')),
  add constraint editorial_review_requests_hash_check
    check (
      (discipline='general' and sealed_content_hash is null)
      or (discipline in ('factual','compliance') and sealed_content_hash ~ '^[a-f0-9]{64}$')
    ),
  add constraint editorial_review_requests_policy_check
    check (policy_version ~ '^[a-z0-9][a-z0-9._-]{2,127}$');

drop index argus_app.editorial_review_requests_open_unique;
create unique index editorial_review_requests_open_discipline_unique
  on argus_app.editorial_review_requests(revision_id,discipline)
  where status='open';

alter table argus_app.editorial_review_decisions
  add column discipline text not null default 'general',
  add column sealed_content_hash text,
  add column policy_version text;

update argus_app.editorial_review_decisions decision
   set discipline=request.discipline,
       sealed_content_hash=request.sealed_content_hash,
       policy_version=request.policy_version
  from argus_app.editorial_review_requests request
 where request.id=decision.request_id;

alter table argus_app.editorial_review_decisions
  alter column policy_version set not null,
  alter column policy_version set default 'legacy-general-v1',
  add constraint editorial_review_decisions_discipline_check
    check (discipline in ('general','factual','compliance')),
  add constraint editorial_review_decisions_hash_check
    check (
      (discipline='general' and sealed_content_hash is null)
      or (discipline in ('factual','compliance') and sealed_content_hash ~ '^[a-f0-9]{64}$')
    ),
  add constraint editorial_review_decisions_policy_check
    check (policy_version ~ '^[a-z0-9][a-z0-9._-]{2,127}$'),
  add constraint editorial_review_decisions_request_unique unique(request_id);

create table argus_app.starpath_policies (
  policy_version text primary key
    check (policy_version ~ '^[a-z0-9][a-z0-9._-]{2,127}$'),
  status text not null check (status in ('approved','superseded','invalidated')),
  policy_document_hash text not null
    check (policy_document_hash ~ '^[a-f0-9]{64}$'),
  approved_by uuid not null references argus_private.staff_principals(user_id)
    on delete restrict,
  approved_at timestamptz not null,
  effective_at timestamptz not null,
  expires_at timestamptz not null,
  supported_jurisdictions text[] not null,
  production_approved boolean not null default false,
  r20_trigger_snapshot text[] not null default '{}',
  supersedes_policy_version text references argus_app.starpath_policies(policy_version)
    on delete restrict,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  check (expires_at>effective_at),
  check (cardinality(supported_jurisdictions)>0),
  check (not production_approved or status='approved')
);

create unique index starpath_policies_one_current_unique
  on argus_app.starpath_policies((status)) where status='approved';
create index starpath_policies_approved_by_idx
  on argus_app.starpath_policies(approved_by);
create index starpath_policies_supersedes_idx
  on argus_app.starpath_policies(supersedes_policy_version);

create table argus_app.starpath_lessons (
  id uuid primary key default gen_random_uuid(),
  editorial_item_id uuid not null unique
    references argus_app.editorial_items(id) on delete restrict,
  stable_key text not null unique
    check (stable_key ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  pathway_ordinal integer not null check (pathway_ordinal between 1 and 4),
  pathway_position integer not null check (pathway_position between 1 and 2),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  unique(id,editorial_item_id),
  unique(id,pathway_ordinal,pathway_position),
  unique(pathway_ordinal,pathway_position)
);

create table argus_app.starpath_lesson_revisions (
  lesson_id uuid not null,
  editorial_item_id uuid not null,
  revision_id uuid primary key,
  policy_version text not null
    references argus_app.starpath_policies(policy_version) on delete restrict,
  classification text not null check (classification='education_general'),
  title text not null check (char_length(title) between 1 and 160),
  tarot_key text not null check (tarot_key ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  tarot_accessible_label text not null
    check (char_length(tarot_accessible_label) between 1 and 240),
  mythic_mnemonic text not null check (char_length(mythic_mnemonic) between 1 and 1200),
  factual_summary text not null check (char_length(factual_summary) between 1 and 2400),
  material_limitations text not null
    check (char_length(material_limitations) between 1 and 2400),
  risk_context text not null check (char_length(risk_context) between 1 and 2400),
  recall_prompt text not null check (char_length(recall_prompt) between 1 and 800),
  rowan_explanation text not null
    check (char_length(rowan_explanation) between 1 and 2400),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  foreign key (lesson_id,editorial_item_id)
    references argus_app.starpath_lessons(id,editorial_item_id) on delete restrict,
  foreign key (editorial_item_id,revision_id)
    references argus_app.editorial_revisions(item_id,id) on delete restrict,
  unique(lesson_id,revision_id),
  unique(editorial_item_id,revision_id)
);
create index starpath_lesson_revisions_lesson_item_idx
  on argus_app.starpath_lesson_revisions(lesson_id,editorial_item_id);
create index starpath_lesson_revisions_policy_idx
  on argus_app.starpath_lesson_revisions(policy_version);

create table argus_app.starpath_factual_sections (
  lesson_id uuid not null,
  revision_id uuid not null,
  ordinal integer not null check (ordinal between 1 and 12),
  section_kind text not null check (section_kind in ('fact','neutral_example')),
  heading text not null check (char_length(heading) between 1 and 160),
  body text not null check (char_length(body) between 1 and 4000),
  uncertainty text not null check (char_length(uncertainty) between 1 and 1200),
  observed_at timestamptz not null,
  primary key(revision_id,ordinal),
  unique(lesson_id,revision_id,ordinal),
  foreign key (lesson_id,revision_id)
    references argus_app.starpath_lesson_revisions(lesson_id,revision_id)
    on delete restrict
);

create table argus_app.starpath_knowledge_checks (
  id uuid not null default gen_random_uuid(),
  lesson_id uuid not null,
  revision_id uuid not null,
  prompt text not null check (char_length(prompt) between 1 and 1200),
  explanation text not null check (char_length(explanation) between 1 and 2400),
  primary key(revision_id,id),
  unique(revision_id),
  unique(lesson_id,revision_id,id),
  foreign key (lesson_id,revision_id)
    references argus_app.starpath_lesson_revisions(lesson_id,revision_id)
    on delete restrict
);

create table argus_app.starpath_knowledge_check_options (
  id uuid not null default gen_random_uuid(),
  lesson_id uuid not null,
  revision_id uuid not null,
  question_id uuid not null,
  ordinal integer not null check (ordinal between 1 and 5),
  label text not null check (char_length(label) between 1 and 600),
  is_correct boolean not null,
  explanation text not null check (char_length(explanation) between 1 and 1200),
  primary key(revision_id,question_id,id),
  unique(revision_id,question_id,ordinal),
  unique(lesson_id,revision_id,question_id,id),
  foreign key (lesson_id,revision_id,question_id)
    references argus_app.starpath_knowledge_checks(lesson_id,revision_id,id)
    on delete restrict
);

create table argus_app.starpath_evidence_bindings (
  id uuid not null default gen_random_uuid(),
  lesson_id uuid not null,
  revision_id uuid not null,
  section_ordinal integer not null,
  ordinal integer not null check (ordinal between 1 and 12),
  canonical_url text not null check (canonical_url ~ '^https://'),
  source_title text not null check (char_length(source_title) between 1 and 300),
  publisher text not null check (char_length(publisher) between 1 and 200),
  source_observed_at timestamptz not null,
  effective_at timestamptz,
  retrieved_at timestamptz not null,
  current_until timestamptz not null,
  claim_summary text not null check (char_length(claim_summary) between 1 and 1200),
  primary key(revision_id,section_ordinal,id),
  unique(revision_id,section_ordinal,ordinal),
  foreign key (lesson_id,revision_id,section_ordinal)
    references argus_app.starpath_factual_sections(lesson_id,revision_id,ordinal)
    on delete restrict,
  check (current_until>retrieved_at)
);
create index starpath_evidence_parent_idx
  on argus_app.starpath_evidence_bindings(lesson_id,revision_id,section_ordinal);

create table argus_app.starpath_session_themes (
  id uuid primary key default gen_random_uuid(),
  theme_key text not null unique
    check (theme_key ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  policy_version text not null
    references argus_app.starpath_policies(policy_version) on delete restrict,
  title text not null check (char_length(title) between 1 and 160),
  horoscope_frame text not null check (char_length(horoscope_frame) between 1 and 1200),
  factual_focus text not null check (char_length(factual_focus) between 1 and 1200),
  accessible_label text not null check (char_length(accessible_label) between 1 and 240),
  status text not null default 'reviewed' check (status in ('reviewed','withdrawn')),
  created_at timestamptz not null default pg_catalog.clock_timestamp()
);
create index starpath_session_themes_policy_idx
  on argus_app.starpath_session_themes(policy_version);

create table argus_app.starpath_curriculum_manifests (
  id uuid primary key default gen_random_uuid(),
  manifest_version text not null unique
    check (manifest_version ~ '^[a-z0-9][a-z0-9._-]{2,127}$'),
  policy_version text not null
    references argus_app.starpath_policies(policy_version) on delete restrict,
  release_environment text not null check (release_environment in ('beta','production')),
  supported_jurisdiction text not null,
  state text not null default 'draft'
    check (state in ('draft','published','superseded','withdrawn')),
  published_at timestamptz,
  published_by uuid references argus_private.staff_principals(user_id)
    on delete restrict,
  publication_reason text,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  check ((state='draft')=(published_at is null)),
  check ((state='draft')=(published_by is null)),
  check ((state='draft')=(publication_reason is null))
);

create unique index starpath_manifest_one_published_per_environment
  on argus_app.starpath_curriculum_manifests(release_environment,supported_jurisdiction)
  where state='published';
create index starpath_manifests_policy_idx
  on argus_app.starpath_curriculum_manifests(policy_version);
create index starpath_manifests_publisher_idx
  on argus_app.starpath_curriculum_manifests(published_by);

create table argus_app.starpath_manifest_nodes (
  manifest_id uuid not null references argus_app.starpath_curriculum_manifests(id)
    on delete restrict,
  node_ordinal integer not null check (node_ordinal between 1 and 8),
  lesson_id uuid not null,
  revision_id uuid not null,
  pathway_ordinal integer not null check (pathway_ordinal between 1 and 4),
  pathway_position integer not null check (pathway_position between 1 and 2),
  primary key(manifest_id,node_ordinal),
  unique(manifest_id,lesson_id),
  unique(manifest_id,revision_id),
  foreign key (lesson_id,revision_id)
    references argus_app.starpath_lesson_revisions(lesson_id,revision_id)
    on delete restrict,
  foreign key (lesson_id,pathway_ordinal,pathway_position)
    references argus_app.starpath_lessons(id,pathway_ordinal,pathway_position)
    on delete restrict,
  check (node_ordinal=((pathway_ordinal-1)*2)+pathway_position)
);
create index starpath_manifest_nodes_lesson_revision_idx
  on argus_app.starpath_manifest_nodes(lesson_id,revision_id);
create index starpath_manifest_nodes_pathway_idx
  on argus_app.starpath_manifest_nodes(lesson_id,pathway_ordinal,pathway_position);

create table argus_app.starpath_manifest_themes (
  manifest_id uuid not null references argus_app.starpath_curriculum_manifests(id)
    on delete restrict,
  theme_id uuid not null references argus_app.starpath_session_themes(id)
    on delete restrict,
  ordinal integer not null check (ordinal between 1 and 24),
  primary key(manifest_id,theme_id),
  unique(manifest_id,ordinal)
);

create table argus_app.starpath_manifest_events (
  id uuid primary key default gen_random_uuid(),
  manifest_id uuid not null references argus_app.starpath_curriculum_manifests(id)
    on delete restrict,
  action text not null check (action in ('publish','supersede','withdraw')),
  actor_id uuid not null references argus_private.staff_principals(user_id)
    on delete restrict,
  reason text not null check (char_length(reason) between 8 and 500),
  occurred_at timestamptz not null default pg_catalog.clock_timestamp()
);
create index starpath_manifest_events_manifest_idx
  on argus_app.starpath_manifest_events(manifest_id);
create index starpath_manifest_events_actor_idx
  on argus_app.starpath_manifest_events(actor_id);

create or replace function argus_private.reject_starpath_immutable_change()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
begin
  raise exception 'starpath_reviewed_content_immutable' using errcode='23514';
end
$$;

create or replace function argus_private.enforce_starpath_draft_content()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare retained_revision_id uuid;
declare retained_state text;
begin
  retained_revision_id=case when tg_op='DELETE' then old.revision_id else new.revision_id end;
  select state into retained_state from argus_app.editorial_revisions
   where id=retained_revision_id;
  if retained_state is distinct from 'draft' then
    raise exception 'starpath_reviewed_content_immutable' using errcode='23514';
  end if;
  return case when tg_op='DELETE' then old else new end;
end
$$;

create or replace function argus_private.enforce_starpath_manifest_draft()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare retained_manifest_id uuid;
begin
  retained_manifest_id=case when tg_op='DELETE' then old.manifest_id else new.manifest_id end;
  if not exists (
    select 1 from argus_app.starpath_curriculum_manifests
     where id=retained_manifest_id and state='draft'
  ) then
    raise exception 'starpath_manifest_immutable' using errcode='23514';
  end if;
  return case when tg_op='DELETE' then old else new end;
end
$$;

create or replace function argus_private.enforce_starpath_render_seal()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
begin
  if exists (
    select 1
      from argus_app.editorial_revisions revision
      join argus_app.editorial_items item on item.id=revision.item_id
     where revision.id=new.revision_id and item.kind='starpath_lesson'
       and revision.state<>'draft'
  ) then
    raise exception 'starpath_manifest_publication_required' using errcode='23514';
  end if;
  return new;
end
$$;

create trigger enforce_starpath_render_seal
  before insert on argus_app.editorial_render_documents
  for each row execute function argus_private.enforce_starpath_render_seal();

create trigger starpath_policy_immutable
  before update or delete on argus_app.starpath_policies
  for each row execute function argus_private.reject_starpath_immutable_change();
create trigger starpath_review_decision_immutable
  before update or delete on argus_app.editorial_review_decisions
  for each row execute function argus_private.reject_starpath_immutable_change();
create trigger starpath_lesson_identity_immutable
  before update or delete on argus_app.starpath_lessons
  for each row execute function argus_private.reject_starpath_immutable_change();
create trigger starpath_theme_immutable
  before update or delete on argus_app.starpath_session_themes
  for each row execute function argus_private.reject_starpath_immutable_change();
create trigger starpath_manifest_event_immutable
  before update or delete on argus_app.starpath_manifest_events
  for each row execute function argus_private.reject_starpath_immutable_change();

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'starpath_lesson_revisions','starpath_factual_sections',
    'starpath_knowledge_checks','starpath_knowledge_check_options',
    'starpath_evidence_bindings'
  ] loop
    execute pg_catalog.format(
      'create trigger starpath_draft_content before insert or update or delete on argus_app.%I for each row execute function argus_private.enforce_starpath_draft_content()',
      relation_name
    );
  end loop;
  foreach relation_name in array array[
    'starpath_manifest_nodes','starpath_manifest_themes'
  ] loop
    execute pg_catalog.format(
      'create trigger starpath_manifest_draft before insert or update or delete on argus_app.%I for each row execute function argus_private.enforce_starpath_manifest_draft()',
      relation_name
    );
  end loop;
end
$$;

create or replace function argus_private.validate_starpath_member_copy(p_copy text)
returns void
language plpgsql
immutable
security invoker
set search_path=''
as $$
begin
  if nullif(pg_catalog.btrim(p_copy),'') is null
     or p_copy ~* '\m(you should|we recommend|our pick|best (?:stock|etf|bond|investment)|guaranteed return|sure[- ]?thing|will outperform|price target)\M'
     or p_copy ~* '\m(buy|sell|hold)\s+(?:this|these|the)\s+(?:stock|shares?|etf|bond|security|investment)\M'
     or p_copy ~* '\m(?:perfect|right)\s+for\s+(?:your|you)\M' then
    raise exception 'prohibited_investment_guidance' using errcode='23514';
  end if;
end
$$;

create or replace function argus_private.create_starpath_editorial_item(
  p_item_id uuid,p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if not argus_private.has_staff_permission('editorial:write')
     or nullif(p_payload->>'stable_key','') is null
     or coalesce((p_payload->>'pathway_ordinal')::integer,0) not between 1 and 4
     or coalesce((p_payload->>'pathway_position')::integer,0) not between 1 and 2 then
    raise exception 'invalid_starpath_lesson' using errcode='23514';
  end if;
  insert into argus_app.starpath_lessons(
    editorial_item_id,stable_key,pathway_ordinal,pathway_position
  ) values (
    p_item_id,p_payload->>'stable_key',(p_payload->>'pathway_ordinal')::integer,
    (p_payload->>'pathway_position')::integer
  );
end
$$;

create or replace function argus_private.sync_starpath_revision(
  p_revision_id uuid,p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare retained_lesson argus_app.starpath_lessons%rowtype;
declare retained_item_id uuid;
declare retained_question_id uuid:=gen_random_uuid();
declare section_entry record;
declare evidence_entry record;
declare option_entry record;
declare retained_correct_count integer;
begin
  if not argus_private.has_staff_permission('editorial:write')
     or jsonb_typeof(p_payload)<>'object'
     or p_payload->>'classification'<>'education_general'
     or nullif(p_payload->>'policy_version','') is null
     or nullif(p_payload->>'title','') is null
     or nullif(p_payload->>'tarot_key','') is null
     or nullif(p_payload->>'tarot_accessible_label','') is null
     or nullif(p_payload->>'mythic_mnemonic','') is null
     or nullif(p_payload->>'factual_summary','') is null
     or nullif(p_payload->>'material_limitations','') is null
     or nullif(p_payload->>'risk_context','') is null
     or nullif(p_payload->>'recall_prompt','') is null
     or nullif(p_payload->>'rowan_explanation','') is null
     or jsonb_typeof(p_payload->'sections')<>'array'
     or jsonb_array_length(p_payload->'sections') not between 1 and 12
     or jsonb_typeof(p_payload->'check')<>'object'
     or jsonb_typeof(p_payload->'check'->'options')<>'array'
     or jsonb_array_length(p_payload->'check'->'options') not between 2 and 5 then
    raise exception 'invalid_starpath_lesson' using errcode='23514';
  end if;

  select revision.item_id into retained_item_id
    from argus_app.editorial_revisions revision
    join argus_app.editorial_items item
      on item.id=revision.item_id and item.kind='starpath_lesson'
   where revision.id=p_revision_id and revision.state='draft'
   for update of revision;
  if retained_item_id is null then
    raise exception 'resource_not_found' using errcode='P0002';
  end if;
  select * into retained_lesson from argus_app.starpath_lessons
   where editorial_item_id=retained_item_id;
  if retained_lesson.id is null
     or retained_lesson.stable_key<>p_payload->>'stable_key'
     or retained_lesson.pathway_ordinal<>(p_payload->>'pathway_ordinal')::integer
     or retained_lesson.pathway_position<>(p_payload->>'pathway_position')::integer
     or not exists (
       select 1 from argus_app.starpath_policies policy
        where policy.policy_version=p_payload->>'policy_version'
          and policy.status='approved'
          and policy.effective_at<=pg_catalog.clock_timestamp()
          and policy.expires_at>pg_catalog.clock_timestamp()
     ) then
    raise exception 'invalid_starpath_authority' using errcode='23514';
  end if;

  perform argus_private.validate_starpath_member_copy(p_payload->>'title');
  perform argus_private.validate_starpath_member_copy(p_payload->>'factual_summary');
  perform argus_private.validate_starpath_member_copy(p_payload->>'material_limitations');
  perform argus_private.validate_starpath_member_copy(p_payload->>'risk_context');
  perform argus_private.validate_starpath_member_copy(p_payload->>'recall_prompt');
  perform argus_private.validate_starpath_member_copy(p_payload->>'rowan_explanation');
  perform argus_private.validate_starpath_member_copy(p_payload->'check'->>'prompt');
  perform argus_private.validate_starpath_member_copy(p_payload->'check'->>'explanation');

  delete from argus_app.starpath_knowledge_check_options where revision_id=p_revision_id;
  delete from argus_app.starpath_evidence_bindings where revision_id=p_revision_id;
  delete from argus_app.starpath_knowledge_checks where revision_id=p_revision_id;
  delete from argus_app.starpath_factual_sections where revision_id=p_revision_id;
  delete from argus_app.starpath_lesson_revisions where revision_id=p_revision_id;
  insert into argus_app.starpath_lesson_revisions(
    lesson_id,editorial_item_id,revision_id,policy_version,classification,title,
    tarot_key,tarot_accessible_label,mythic_mnemonic,factual_summary,
    material_limitations,risk_context,recall_prompt,rowan_explanation
  ) values (
    retained_lesson.id,retained_item_id,p_revision_id,p_payload->>'policy_version',
    p_payload->>'classification',p_payload->>'title',p_payload->>'tarot_key',
    p_payload->>'tarot_accessible_label',p_payload->>'mythic_mnemonic',
    p_payload->>'factual_summary',p_payload->>'material_limitations',
    p_payload->>'risk_context',p_payload->>'recall_prompt',p_payload->>'rowan_explanation'
  );

  for section_entry in
    select value,ordinal from pg_catalog.jsonb_array_elements(p_payload->'sections')
      with ordinality section(value,ordinal)
  loop
    if section_entry.value->>'kind' not in ('fact','neutral_example')
       or nullif(section_entry.value->>'heading','') is null
       or nullif(section_entry.value->>'body','') is null
       or nullif(section_entry.value->>'uncertainty','') is null
       or nullif(section_entry.value->>'observed_at','') is null
       or jsonb_typeof(section_entry.value->'evidence')<>'array'
       or jsonb_array_length(section_entry.value->'evidence') not between 1 and 12 then
      raise exception 'invalid_starpath_factual_section' using errcode='23514';
    end if;
    perform argus_private.validate_starpath_member_copy(section_entry.value->>'heading');
    perform argus_private.validate_starpath_member_copy(section_entry.value->>'body');
    perform argus_private.validate_starpath_member_copy(section_entry.value->>'uncertainty');
    insert into argus_app.starpath_factual_sections(
      lesson_id,revision_id,ordinal,section_kind,heading,body,uncertainty,observed_at
    ) values (
      retained_lesson.id,p_revision_id,section_entry.ordinal,
      section_entry.value->>'kind',section_entry.value->>'heading',
      section_entry.value->>'body',section_entry.value->>'uncertainty',
      (section_entry.value->>'observed_at')::timestamptz
    );
    for evidence_entry in
      select value,ordinal
        from pg_catalog.jsonb_array_elements(section_entry.value->'evidence')
          with ordinality evidence(value,ordinal)
    loop
      if coalesce(evidence_entry.value->>'canonical_url','') !~ '^https://'
         or nullif(evidence_entry.value->>'source_title','') is null
         or nullif(evidence_entry.value->>'publisher','') is null
         or nullif(evidence_entry.value->>'source_observed_at','') is null
         or nullif(evidence_entry.value->>'retrieved_at','') is null
         or nullif(evidence_entry.value->>'current_until','') is null
         or nullif(evidence_entry.value->>'claim_summary','') is null then
        raise exception 'invalid_starpath_evidence' using errcode='23514';
      end if;
      perform argus_private.validate_starpath_member_copy(evidence_entry.value->>'claim_summary');
      insert into argus_app.starpath_evidence_bindings(
        lesson_id,revision_id,section_ordinal,ordinal,canonical_url,source_title,
        publisher,source_observed_at,effective_at,retrieved_at,current_until,claim_summary
      ) values (
        retained_lesson.id,p_revision_id,section_entry.ordinal,evidence_entry.ordinal,
        evidence_entry.value->>'canonical_url',evidence_entry.value->>'source_title',
        evidence_entry.value->>'publisher',
        (evidence_entry.value->>'source_observed_at')::timestamptz,
        nullif(evidence_entry.value->>'effective_at','')::timestamptz,
        (evidence_entry.value->>'retrieved_at')::timestamptz,
        (evidence_entry.value->>'current_until')::timestamptz,
        evidence_entry.value->>'claim_summary'
      );
    end loop;
  end loop;

  insert into argus_app.starpath_knowledge_checks(
    id,lesson_id,revision_id,prompt,explanation
  ) values (
    retained_question_id,retained_lesson.id,p_revision_id,
    p_payload->'check'->>'prompt',p_payload->'check'->>'explanation'
  );
  retained_correct_count=0;
  for option_entry in
    select value,ordinal
      from pg_catalog.jsonb_array_elements(p_payload->'check'->'options')
        with ordinality option_value(value,ordinal)
  loop
    if nullif(option_entry.value->>'label','') is null
       or nullif(option_entry.value->>'explanation','') is null
       or jsonb_typeof(option_entry.value->'is_correct')<>'boolean' then
      raise exception 'invalid_starpath_knowledge_check' using errcode='23514';
    end if;
    perform argus_private.validate_starpath_member_copy(option_entry.value->>'label');
    perform argus_private.validate_starpath_member_copy(option_entry.value->>'explanation');
    if (option_entry.value->>'is_correct')::boolean then
      retained_correct_count=retained_correct_count+1;
    end if;
    insert into argus_app.starpath_knowledge_check_options(
      lesson_id,revision_id,question_id,ordinal,label,is_correct,explanation
    ) values (
      retained_lesson.id,p_revision_id,retained_question_id,option_entry.ordinal,
      option_entry.value->>'label',(option_entry.value->>'is_correct')::boolean,
      option_entry.value->>'explanation'
    );
  end loop;
  if retained_correct_count<>1 then
    raise exception 'invalid_starpath_knowledge_check' using errcode='23514';
  end if;
end
$$;

create or replace function argus_private.submit_starpath_revision(
  p_revision_id uuid,p_policy_version text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare retained_revision argus_app.editorial_revisions%rowtype;
begin
  if not argus_private.has_staff_permission('editorial:write') then
    raise exception 'staff_permission_required' using errcode='42501';
  end if;
  select revision.* into retained_revision
    from argus_app.editorial_revisions revision
    join argus_app.editorial_items item
      on item.id=revision.item_id and item.kind='starpath_lesson'
    join argus_app.starpath_lesson_revisions lesson_revision
      on lesson_revision.editorial_item_id=revision.item_id
     and lesson_revision.revision_id=revision.id
     and lesson_revision.policy_version=p_policy_version
   where revision.id=p_revision_id and revision.state='draft'
   for update of revision;
  if retained_revision.id is null then
    raise exception 'invalid_starpath_revision' using errcode='23514';
  end if;
  if exists (
    select 1 from argus_app.starpath_evidence_bindings evidence
     where evidence.revision_id=p_revision_id
       and evidence.current_until<=pg_catalog.clock_timestamp()
  ) then
    raise exception 'stale_starpath_evidence' using errcode='23514';
  end if;
  insert into argus_app.editorial_render_documents(item_id,revision_id,document)
  values (retained_revision.item_id,p_revision_id,retained_revision.payload);
  perform pg_catalog.set_config('argus.starpath_editorial_command','submit',true);
  update argus_app.editorial_revisions set state='submitted' where id=p_revision_id;
  insert into argus_app.editorial_review_requests(
    revision_id,requested_by,high_trust,status,discipline,sealed_content_hash,policy_version
  )
  select p_revision_id,argus_private.trusted_request_user_id(),true,'open',discipline,
         retained_revision.payload_canonical_hash,p_policy_version
    from unnest(array['factual','compliance']) discipline;
end
$$;

create or replace function argus_private.decide_starpath_review(
  p_revision_id uuid,p_discipline text,p_decision text,p_reason text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare retained_request argus_app.editorial_review_requests%rowtype;
declare retained_author uuid;
declare retained_permission text;
begin
  retained_permission=case p_discipline
    when 'factual' then 'editorial:review:factual'
    when 'compliance' then 'editorial:review:compliance'
    else null
  end;
  if retained_permission is null
     or not argus_private.has_staff_permission(retained_permission)
     or p_decision not in ('approved','changes_requested','rejected')
     or char_length(pg_catalog.btrim(p_reason)) not between 8 and 500 then
    raise exception 'invalid_starpath_review' using errcode='42501';
  end if;
  select request.* into retained_request
    from argus_app.editorial_review_requests request
    join argus_app.editorial_revisions revision on revision.id=request.revision_id
   where request.revision_id=p_revision_id
     and request.discipline=p_discipline
     and request.status='open' and revision.state='submitted'
   for update of request,revision;
  if retained_request.id is null then
    raise exception 'invalid_starpath_review' using errcode='23514';
  end if;
  select author_staff_id into retained_author
    from argus_app.editorial_revisions where id=p_revision_id;
  if retained_author=argus_private.trusted_request_user_id() then
    raise exception 'self_approval' using errcode='42501';
  end if;
  insert into argus_app.editorial_review_decisions(
    request_id,reviewer_id,decision,reason,discipline,sealed_content_hash,policy_version
  ) values (
    retained_request.id,argus_private.trusted_request_user_id(),p_decision,p_reason,
    retained_request.discipline,retained_request.sealed_content_hash,
    retained_request.policy_version
  );
  update argus_app.editorial_review_requests set status='closed'
   where id=retained_request.id;
  perform pg_catalog.set_config('argus.starpath_editorial_command','review',true);
  if p_decision<>'approved' then
    update argus_app.editorial_review_requests set status='closed'
     where revision_id=p_revision_id and status='open';
    update argus_app.editorial_revisions set state='rejected' where id=p_revision_id;
  elsif (
    select count(*)=2
      from argus_app.editorial_review_decisions decision
      join argus_app.editorial_review_requests request on request.id=decision.request_id
     where request.revision_id=p_revision_id
       and decision.decision='approved'
       and decision.discipline in ('factual','compliance')
       and decision.sealed_content_hash=request.sealed_content_hash
       and decision.policy_version=request.policy_version
  ) then
    update argus_app.editorial_revisions set state='approved' where id=p_revision_id;
  end if;
end
$$;

create or replace function argus_private.enforce_starpath_revision_transition()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare retained_kind text;
declare retained_command text:=pg_catalog.current_setting('argus.starpath_editorial_command',true);
begin
  select kind into retained_kind from argus_app.editorial_items where id=new.item_id;
  if retained_kind<>'starpath_lesson' or new.state=old.state then return new; end if;
  if not (
    current_user='argus_app_owner'
    and ((old.state,new.state,retained_command) in (
      ('draft','submitted','submit'),
      ('submitted','approved','review'),
      ('submitted','rejected','review'),
      ('approved','published','manifest'),
      ('published','withdrawn','withdraw')
    ))
  ) then
    raise exception 'invalid_starpath_editorial_transition' using errcode='23514';
  end if;
  return new;
end
$$;

-- Preserve the generic editorial transition contract while allowing the
-- Starpath domain command to use its narrower review permissions. The
-- adjacent Starpath trigger still requires the exact sealed domain command,
-- so possessing either scope cannot turn the generic workflow into a bypass.
create or replace function argus_private.enforce_editorial_revision_transition()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare retained_kind text;
declare retained_command text:=pg_catalog.current_setting('argus.starpath_editorial_command',true);
begin
  select kind into retained_kind from argus_app.editorial_items where id=new.item_id;
  if old.state='draft' and new.state='draft' then
    if not argus_private.has_staff_permission('editorial:write') then
      raise exception 'staff_permission_required' using errcode='42501';
    end if;
  elsif old.state='draft' and new.state='submitted' then
    if not argus_private.has_staff_permission('editorial:write') then
      raise exception 'staff_permission_required' using errcode='42501';
    end if;
  elsif old.state='submitted' and new.state in ('approved','rejected') then
    if retained_kind='starpath_lesson' then
      if retained_command<>'review' or not (
        argus_private.has_staff_permission('editorial:review:factual')
        or argus_private.has_staff_permission('editorial:review:compliance')
      ) then
        raise exception 'staff_permission_required' using errcode='42501';
      end if;
    elsif not argus_private.has_staff_permission('editorial:review') then
      raise exception 'staff_permission_required' using errcode='42501';
    end if;
  elsif old.state='approved' and new.state='published'
     or old.state='published' and new.state='withdrawn' then
    if not argus_private.has_staff_permission('editorial:publish') then
      raise exception 'staff_permission_required' using errcode='42501';
    end if;
  end if;

  if new.id<>old.id or new.item_id<>old.item_id
     or new.revision_number<>old.revision_number
     or new.author_staff_id<>old.author_staff_id
     or new.created_at<>old.created_at then
    raise exception 'immutable_editorial_revision' using errcode='23514';
  end if;
  if old.state='draft' and new.state='draft' then
    if new.edit_version<>old.edit_version+1 then
      raise exception 'editorial_revision_conflict' using errcode='40001';
    end if;
    return new;
  end if;
  if (old.state,new.state) not in (
       ('draft','submitted'),('submitted','approved'),
       ('submitted','rejected'),('approved','published'),
       ('published','withdrawn')
     ) or new.payload<>old.payload or new.content_hash<>old.content_hash
       or new.edit_version<>old.edit_version then
    raise exception 'invalid_editorial_transition' using errcode='23514';
  end if;
  return new;
end
$$;

create trigger enforce_starpath_revision_transition
  before update of state on argus_app.editorial_revisions
  for each row execute function argus_private.enforce_starpath_revision_transition();

create or replace function argus_private.publish_starpath_manifest(
  p_manifest_id uuid,p_reason text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare retained_manifest argus_app.starpath_curriculum_manifests%rowtype;
declare retained_node record;
begin
  if not argus_private.has_staff_permission('editorial:publish')
     or char_length(pg_catalog.btrim(p_reason)) not between 8 and 500 then
    raise exception 'staff_permission_required' using errcode='42501';
  end if;
  select * into retained_manifest from argus_app.starpath_curriculum_manifests
   where id=p_manifest_id and state='draft' for update;
  if retained_manifest.id is null then
    raise exception 'invalid_starpath_manifest' using errcode='23514';
  end if;
  if not exists (
       select 1 from argus_app.starpath_policies policy
        where policy.policy_version=retained_manifest.policy_version
          and policy.status='approved'
          and policy.effective_at<=pg_catalog.clock_timestamp()
          and policy.expires_at>pg_catalog.clock_timestamp()
          and retained_manifest.supported_jurisdiction=any(policy.supported_jurisdictions)
          and (retained_manifest.release_environment='beta' or policy.production_approved)
     )
     or (select count(*) from argus_app.starpath_manifest_nodes
          where manifest_id=p_manifest_id)<>8
     or exists (
       select pathway_ordinal from argus_app.starpath_manifest_nodes
        where manifest_id=p_manifest_id group by pathway_ordinal having count(*)<>2
     )
     or (select count(*) from argus_app.starpath_manifest_themes
          where manifest_id=p_manifest_id)<1
     or exists (
       select 1
         from argus_app.starpath_manifest_nodes node
         join argus_app.starpath_lesson_revisions lesson_revision
           on lesson_revision.lesson_id=node.lesson_id
          and lesson_revision.revision_id=node.revision_id
         join argus_app.editorial_revisions revision on revision.id=node.revision_id
        where node.manifest_id=p_manifest_id
          and (revision.state<>'approved'
            or lesson_revision.policy_version<>retained_manifest.policy_version
            or lesson_revision.classification<>'education_general'
            or not exists (
              select 1 from argus_app.editorial_review_decisions decision
              join argus_app.editorial_review_requests request
                on request.id=decision.request_id
             where request.revision_id=node.revision_id
               and decision.decision='approved'
               and decision.discipline='factual'
               and decision.sealed_content_hash=revision.payload_canonical_hash
               and decision.policy_version=retained_manifest.policy_version
            )
            or not exists (
              select 1 from argus_app.editorial_review_decisions decision
              join argus_app.editorial_review_requests request
                on request.id=decision.request_id
             where request.revision_id=node.revision_id
               and decision.decision='approved'
               and decision.discipline='compliance'
               and decision.sealed_content_hash=revision.payload_canonical_hash
               and decision.policy_version=retained_manifest.policy_version
            )
            or exists (
              select 1 from argus_app.starpath_evidence_bindings evidence
               where evidence.revision_id=node.revision_id
                 and evidence.current_until<=pg_catalog.clock_timestamp()
            ))
     )
     or exists (
       select 1 from argus_app.starpath_manifest_themes manifest_theme
       join argus_app.starpath_session_themes theme on theme.id=manifest_theme.theme_id
       where manifest_theme.manifest_id=p_manifest_id
         and (theme.status<>'reviewed' or theme.policy_version<>retained_manifest.policy_version)
     ) then
    raise exception 'invalid_starpath_manifest' using errcode='23514';
  end if;

  update argus_app.starpath_curriculum_manifests
     set state='published',published_at=pg_catalog.clock_timestamp(),
         published_by=argus_private.trusted_request_user_id(),publication_reason=p_reason
   where id=p_manifest_id;
  perform pg_catalog.set_config('argus.starpath_editorial_command','manifest',true);
  for retained_node in
    select node.*,revision.item_id
      from argus_app.starpath_manifest_nodes node
      join argus_app.editorial_revisions revision on revision.id=node.revision_id
     where node.manifest_id=p_manifest_id order by node.node_ordinal
  loop
    update argus_app.editorial_revisions set state='published'
     where id=retained_node.revision_id and state='approved';
    update argus_app.editorial_items
       set status='published',current_published_revision_id=retained_node.revision_id
     where id=retained_node.item_id;
    insert into argus_app.publication_events(
      item_id,revision_id,action,effective_at,actor_id,reason
    ) values (
      retained_node.item_id,retained_node.revision_id,'publish',
      pg_catalog.clock_timestamp(),argus_private.trusted_request_user_id(),p_reason
    );
  end loop;
  insert into argus_app.starpath_manifest_events(manifest_id,action,actor_id,reason)
  values (p_manifest_id,'publish',argus_private.trusted_request_user_id(),p_reason);
end
$$;

create or replace function argus_private.enforce_editorial_review_request_update()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare retained_permission text;
begin
  retained_permission=case old.discipline
    when 'factual' then 'editorial:review:factual'
    when 'compliance' then 'editorial:review:compliance'
    else 'editorial:review'
  end;
  if not argus_private.has_staff_permission(retained_permission)
     or new.id<>old.id or new.revision_id<>old.revision_id
     or new.requested_by<>old.requested_by or new.requested_at<>old.requested_at
     or new.high_trust<>old.high_trust or new.discipline<>old.discipline
     or new.sealed_content_hash<>old.sealed_content_hash
     or new.policy_version<>old.policy_version
     or (old.status,new.status)<>('open','closed') then
    raise exception 'invalid_editorial_review_transition' using errcode='23514';
  end if;
  return new;
end
$$;

create or replace function argus_private.enforce_editorial_review_decision()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare retained_request argus_app.editorial_review_requests%rowtype;
declare retained_author uuid;
declare retained_permission text;
begin
  select request.* into retained_request
    from argus_app.editorial_review_requests request
    join argus_app.editorial_revisions revision on revision.id=request.revision_id
   where request.id=new.request_id;
  select author_staff_id into retained_author
    from argus_app.editorial_revisions where id=retained_request.revision_id;
  retained_permission=case retained_request.discipline
    when 'factual' then 'editorial:review:factual'
    when 'compliance' then 'editorial:review:compliance'
    else 'editorial:review'
  end;
  if not argus_private.has_staff_permission(retained_permission)
     or new.reviewer_id<>argus_private.trusted_request_user_id()
     or retained_request.status<>'open'
     or new.discipline<>retained_request.discipline
     or new.sealed_content_hash<>retained_request.sealed_content_hash
     or new.policy_version<>retained_request.policy_version then
    raise exception 'invalid_editorial_review_decision' using errcode='23514';
  end if;
  if retained_request.high_trust and retained_author=new.reviewer_id then
    raise exception 'self_approval' using errcode='42501';
  end if;
  return new;
end
$$;

do $membership$
begin
  execute pg_catalog.format(
    'grant argus_app_owner to %I with set true',current_user
  );
end
$membership$;
grant create on schema argus_app,argus_private to argus_app_owner;

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'starpath_policies','starpath_lessons','starpath_lesson_revisions',
    'starpath_factual_sections','starpath_knowledge_checks',
    'starpath_knowledge_check_options','starpath_evidence_bindings',
    'starpath_session_themes','starpath_curriculum_manifests',
    'starpath_manifest_nodes','starpath_manifest_themes','starpath_manifest_events'
  ] loop
    execute pg_catalog.format('alter table argus_app.%I enable row level security',relation_name);
    execute pg_catalog.format('alter table argus_app.%I force row level security',relation_name);
    execute pg_catalog.format(
      'create policy starpath_staff_read on argus_app.%I for select to argus_staff using ((select argus_private.has_staff_permission(''editorial:read'')) or (select argus_private.has_staff_permission(''editorial:write'')) or (select argus_private.has_staff_permission(''editorial:review:factual'')) or (select argus_private.has_staff_permission(''editorial:review:compliance'')) or (select argus_private.has_staff_permission(''editorial:publish'')))',
      relation_name
    );
    execute pg_catalog.format(
      'create policy starpath_owner_select on argus_app.%I for select to argus_app_owner using (true)',
      relation_name
    );
    execute pg_catalog.format('grant select on argus_app.%I to argus_staff',relation_name);
    execute pg_catalog.format('revoke all on argus_app.%I from public,anon,authenticated,argus_runtime',relation_name);
    execute pg_catalog.format('alter table argus_app.%I owner to argus_app_owner',relation_name);
  end loop;
end
$$;

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'starpath_lessons','starpath_lesson_revisions','starpath_factual_sections',
    'starpath_knowledge_checks','starpath_knowledge_check_options',
    'starpath_evidence_bindings','starpath_manifest_events'
  ] loop
    execute pg_catalog.format(
      'create policy starpath_owner_insert on argus_app.%I for insert to argus_app_owner with check (true)',
      relation_name
    );
  end loop;
  foreach relation_name in array array[
    'starpath_lesson_revisions','starpath_factual_sections',
    'starpath_knowledge_checks','starpath_knowledge_check_options',
    'starpath_evidence_bindings'
  ] loop
    execute pg_catalog.format(
      'create policy starpath_owner_delete on argus_app.%I for delete to argus_app_owner using (true)',
      relation_name
    );
  end loop;
end
$$;
create policy starpath_owner_manifest_update
  on argus_app.starpath_curriculum_manifests for update to argus_app_owner
  using (state='draft') with check (state='published');

alter table argus_app.editorial_review_requests owner to argus_app_owner;
alter table argus_app.editorial_review_decisions owner to argus_app_owner;
create policy starpath_owner_review_requests_select
  on argus_app.editorial_review_requests for select to argus_app_owner
  using (
    discipline='general'
    or (select argus_private.has_staff_permission('editorial:write'))
    or (select argus_private.has_staff_permission('editorial:publish'))
    or (discipline='factual' and (select argus_private.has_staff_permission('editorial:review:factual')))
    or (discipline='compliance' and (select argus_private.has_staff_permission('editorial:review:compliance')))
  );
create policy starpath_owner_review_requests_insert
  on argus_app.editorial_review_requests for insert to argus_app_owner
  with check (
    discipline='general'
    or (select argus_private.has_staff_permission('editorial:write'))
    or (select argus_private.has_staff_permission('editorial:publish'))
    or (discipline='factual' and (select argus_private.has_staff_permission('editorial:review:factual')))
    or (discipline='compliance' and (select argus_private.has_staff_permission('editorial:review:compliance')))
  );
create policy starpath_owner_review_requests_update
  on argus_app.editorial_review_requests for update to argus_app_owner
  using (
    discipline='general'
    or (discipline='factual' and (select argus_private.has_staff_permission('editorial:review:factual')))
    or (discipline='compliance' and (select argus_private.has_staff_permission('editorial:review:compliance')))
  )
  with check (
    discipline='general'
    or (discipline='factual' and (select argus_private.has_staff_permission('editorial:review:factual')))
    or (discipline='compliance' and (select argus_private.has_staff_permission('editorial:review:compliance')))
  );
create policy starpath_owner_review_decisions_select
  on argus_app.editorial_review_decisions for select to argus_app_owner
  using (
    discipline='general'
    or (discipline='factual' and (select argus_private.has_staff_permission('editorial:review:factual')))
    or (discipline='compliance' and (select argus_private.has_staff_permission('editorial:review:compliance')))
  );
create policy starpath_owner_review_decisions_insert
  on argus_app.editorial_review_decisions for insert to argus_app_owner
  with check (
    discipline='general'
    or (discipline='factual' and (select argus_private.has_staff_permission('editorial:review:factual')))
    or (discipline='compliance' and (select argus_private.has_staff_permission('editorial:review:compliance')))
  );

grant insert on argus_app.starpath_policies,argus_app.starpath_session_themes,
  argus_app.starpath_curriculum_manifests,argus_app.starpath_manifest_nodes,
  argus_app.starpath_manifest_themes to argus_staff;
grant update,delete on argus_app.starpath_curriculum_manifests,
  argus_app.starpath_manifest_nodes,argus_app.starpath_manifest_themes to argus_staff;

create policy starpath_policy_write on argus_app.starpath_policies
  for insert to argus_staff
  with check ((select argus_private.has_staff_permission('editorial:publish')));
create policy starpath_theme_write on argus_app.starpath_session_themes
  for insert to argus_staff
  with check ((select argus_private.has_staff_permission('editorial:write')));
create policy starpath_manifest_write on argus_app.starpath_curriculum_manifests
  for all to argus_staff
  using (state='draft' and (select argus_private.has_staff_permission('editorial:write')))
  with check (state='draft' and (select argus_private.has_staff_permission('editorial:write')));
create policy starpath_manifest_node_write on argus_app.starpath_manifest_nodes
  for all to argus_staff
  using ((select argus_private.has_staff_permission('editorial:write')))
  with check ((select argus_private.has_staff_permission('editorial:write')));
create policy starpath_manifest_theme_write on argus_app.starpath_manifest_themes
  for all to argus_staff
  using ((select argus_private.has_staff_permission('editorial:write')))
  with check ((select argus_private.has_staff_permission('editorial:write')));

revoke all on function argus_private.validate_starpath_member_copy(text),
  argus_private.create_starpath_editorial_item(uuid,jsonb),
  argus_private.sync_starpath_revision(uuid,jsonb),
  argus_private.submit_starpath_revision(uuid,text),
  argus_private.decide_starpath_review(uuid,text,text,text),
  argus_private.publish_starpath_manifest(uuid,text)
from public,anon,authenticated,argus_runtime;
revoke all on function
  argus_private.reject_starpath_immutable_change(),
  argus_private.enforce_starpath_draft_content(),
  argus_private.enforce_starpath_manifest_draft(),
  argus_private.enforce_starpath_render_seal(),
  argus_private.enforce_starpath_revision_transition()
from public,anon,authenticated,argus_runtime,argus_staff;
grant execute on function
  argus_private.create_starpath_editorial_item(uuid,jsonb),
  argus_private.sync_starpath_revision(uuid,jsonb),
  argus_private.submit_starpath_revision(uuid,text),
  argus_private.decide_starpath_review(uuid,text,text,text),
  argus_private.publish_starpath_manifest(uuid,text)
to argus_staff;

alter function argus_private.reject_starpath_immutable_change() owner to argus_app_owner;
alter function argus_private.enforce_starpath_draft_content() owner to argus_app_owner;
alter function argus_private.enforce_starpath_manifest_draft() owner to argus_app_owner;
alter function argus_private.enforce_starpath_render_seal() owner to argus_app_owner;
alter function argus_private.validate_starpath_member_copy(text) owner to argus_app_owner;
alter function argus_private.create_starpath_editorial_item(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.sync_starpath_revision(uuid,jsonb) owner to argus_app_owner;
alter function argus_private.submit_starpath_revision(uuid,text) owner to argus_app_owner;
alter function argus_private.decide_starpath_review(uuid,text,text,text) owner to argus_app_owner;
alter function argus_private.enforce_starpath_revision_transition() owner to argus_app_owner;
alter function argus_private.publish_starpath_manifest(uuid,text) owner to argus_app_owner;

comment on table argus_app.starpath_lesson_revisions is
  'Reviewed factual investment literacy. Tarot fields are mnemonic framing only and are never evidence.';
comment on function argus_private.validate_starpath_member_copy(text) is
  'Defense-in-depth lexical filter only; factual and compliance review remain mandatory.';
comment on table argus_app.starpath_curriculum_manifests is
  'Atomic eight-node Starpath release pinned to exact immutable lesson, policy, evidence, question, option, and theme revisions.';

revoke create on schema argus_app,argus_private from argus_app_owner;
do $membership$
begin
  execute pg_catalog.format('revoke argus_app_owner from %I',current_user);
end
$membership$;

commit;

-- Narrow member-facing Starpath curriculum projections. The member role never
-- receives direct access to editorial authority tables or correctness flags.

create or replace function argus_private.resolve_starpath_member_authority(
  p_environment text,
  p_jurisdiction text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare authority jsonb;
begin
  if p_environment not in ('beta','production')
     or p_jurisdiction!~'^[A-Z]{2,8}$' then
    raise exception 'starpath_capability_scope_invalid' using errcode='22023';
  end if;

  select pg_catalog.jsonb_build_object(
           'manifestId',manifest.id,
           'manifestVersion',manifest.manifest_version,
           'policyVersion',manifest.policy_version,
           'environment',manifest.release_environment,
           'jurisdiction',manifest.supported_jurisdiction,
           'themeId',selected_theme.theme_id
         )
    into authority
    from argus_app.starpath_curriculum_manifests manifest
    join argus_app.starpath_policies policy
      on policy.policy_version=manifest.policy_version
    cross join lateral (
      select manifest_theme.theme_id
        from argus_app.starpath_manifest_themes manifest_theme
        join argus_app.starpath_session_themes theme
          on theme.id=manifest_theme.theme_id
         and theme.policy_version=manifest.policy_version
         and theme.status='reviewed'
       where manifest_theme.manifest_id=manifest.id
       order by manifest_theme.ordinal,manifest_theme.theme_id
       limit 1
    ) selected_theme
   where manifest.release_environment=p_environment
     and manifest.supported_jurisdiction=p_jurisdiction
     and manifest.state='published'
     and policy.status='approved'
     and pg_catalog.clock_timestamp()>=policy.effective_at
     and pg_catalog.clock_timestamp()<policy.expires_at
     and p_jurisdiction=any(policy.supported_jurisdictions)
     and (p_environment<>'production' or policy.production_approved)
     and (
       select pg_catalog.count(*)
         from argus_app.starpath_manifest_nodes node
        where node.manifest_id=manifest.id
     )=8
     and not exists (
       select 1
         from argus_app.starpath_manifest_nodes node
         join argus_app.starpath_lesson_revisions revision
           on revision.lesson_id=node.lesson_id
          and revision.revision_id=node.revision_id
        where node.manifest_id=manifest.id
          and (
            revision.policy_version<>manifest.policy_version
            or revision.classification<>'education_general'
            or not exists (
              select 1
                from argus_app.starpath_factual_sections section
               where section.lesson_id=node.lesson_id
                 and section.revision_id=node.revision_id
            )
            or not exists (
              select 1
                from argus_app.starpath_knowledge_checks check_record
               where check_record.lesson_id=node.lesson_id
                 and check_record.revision_id=node.revision_id
            )
            or exists (
              select 1
                from argus_app.starpath_evidence_bindings evidence
               where evidence.lesson_id=node.lesson_id
                 and evidence.revision_id=node.revision_id
                 and evidence.current_until<=pg_catalog.clock_timestamp()
            )
          )
     )
   order by manifest.published_at desc,manifest.id desc
   limit 1;

  if authority is null then
    raise exception 'starpath_content_unavailable' using errcode='23514';
  end if;
  return authority;
end
$$;

create or replace function argus_private.read_starpath_curriculum_projection(
  p_manifest_id uuid,
  p_theme_id uuid,
  p_environment text,
  p_jurisdiction text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare projection jsonb;
begin
  if (select argus_private.trusted_request_user_id()) is null then
    raise exception 'member_lifecycle_not_open' using errcode='28000';
  end if;
  if p_environment not in ('beta','production')
     or p_jurisdiction!~'^[A-Z]{2,8}$' then
    raise exception 'starpath_capability_scope_invalid' using errcode='22023';
  end if;

  select pg_catalog.jsonb_build_object(
           'manifest',pg_catalog.jsonb_build_object(
             'id',manifest.id,
             'manifestVersion',manifest.manifest_version,
             'policyVersion',manifest.policy_version,
             'environment',manifest.release_environment,
             'jurisdiction',manifest.supported_jurisdiction
           ),
           'theme',pg_catalog.jsonb_build_object(
             'id',theme.id,
             'key',theme.theme_key,
             'title',theme.title,
             'horoscopeFrame',theme.horoscope_frame,
             'factualFocus',theme.factual_focus,
             'accessibleLabel',theme.accessible_label
           ),
           'nodes',(
             select pg_catalog.jsonb_agg(
               pg_catalog.jsonb_build_object(
                 'nodeOrdinal',node.node_ordinal,
                 'pathwayOrdinal',node.pathway_ordinal,
                 'pathwayPosition',node.pathway_position,
                 'lessonId',node.lesson_id,
                 'revisionId',node.revision_id,
                 'title',revision.title,
                 'tarotKey',revision.tarot_key,
                 'tarotAccessibleLabel',revision.tarot_accessible_label,
                 'mythicMnemonic',revision.mythic_mnemonic,
                 'factualSummary',revision.factual_summary,
                 'materialLimitations',revision.material_limitations,
                 'riskContext',revision.risk_context,
                 'recallPrompt',revision.recall_prompt,
                 'rowanExplanation',revision.rowan_explanation,
                 'factualSections',(
                   select pg_catalog.jsonb_agg(
                     pg_catalog.jsonb_build_object(
                       'ordinal',section.ordinal,
                       'kind',section.section_kind,
                       'heading',section.heading,
                       'body',section.body,
                       'uncertainty',section.uncertainty,
                       'observedAt',section.observed_at,
                       'evidence',(
                         select pg_catalog.jsonb_agg(
                           pg_catalog.jsonb_build_object(
                             'ordinal',evidence.ordinal,
                             'canonicalUrl',evidence.canonical_url,
                             'sourceTitle',evidence.source_title,
                             'publisher',evidence.publisher,
                             'sourceObservedAt',evidence.source_observed_at,
                             'effectiveAt',evidence.effective_at,
                             'retrievedAt',evidence.retrieved_at,
                             'currentUntil',evidence.current_until,
                             'claimSummary',evidence.claim_summary
                           ) order by evidence.ordinal
                         )
                           from argus_app.starpath_evidence_bindings evidence
                          where evidence.lesson_id=node.lesson_id
                            and evidence.revision_id=node.revision_id
                            and evidence.section_ordinal=section.ordinal
                       )
                     ) order by section.ordinal
                   )
                     from argus_app.starpath_factual_sections section
                    where section.lesson_id=node.lesson_id
                      and section.revision_id=node.revision_id
                 ),
                 'knowledgeCheck',(
                   select pg_catalog.jsonb_build_object(
                     'id',check_record.id,
                     'prompt',check_record.prompt,
                     'options',(
                       select pg_catalog.jsonb_agg(
                         pg_catalog.jsonb_build_object(
                           'id',option_record.id,
                           'ordinal',option_record.ordinal,
                           'label',option_record.label
                         ) order by option_record.ordinal
                       )
                         from argus_app.starpath_knowledge_check_options option_record
                        where option_record.lesson_id=node.lesson_id
                          and option_record.revision_id=node.revision_id
                          and option_record.question_id=check_record.id
                     )
                   )
                     from argus_app.starpath_knowledge_checks check_record
                    where check_record.lesson_id=node.lesson_id
                      and check_record.revision_id=node.revision_id
                 )
               ) order by node.node_ordinal
             )
               from argus_app.starpath_manifest_nodes node
               join argus_app.starpath_lesson_revisions revision
                 on revision.lesson_id=node.lesson_id
                and revision.revision_id=node.revision_id
              where node.manifest_id=manifest.id
           )
         )
    into projection
    from argus_app.starpath_curriculum_manifests manifest
    join argus_app.starpath_policies policy
      on policy.policy_version=manifest.policy_version
    join argus_app.starpath_manifest_themes manifest_theme
      on manifest_theme.manifest_id=manifest.id
     and manifest_theme.theme_id=p_theme_id
    join argus_app.starpath_session_themes theme
      on theme.id=manifest_theme.theme_id
     and theme.policy_version=manifest.policy_version
     and theme.status='reviewed'
   where manifest.id=p_manifest_id
     and manifest.release_environment=p_environment
     and manifest.supported_jurisdiction=p_jurisdiction
     and manifest.state in ('published','superseded')
     and policy.status in (
       case when p_environment='production' then 'approved' else 'approved' end,
       case when p_environment='production' then 'approved' else 'superseded' end
     )
     and pg_catalog.clock_timestamp()>=policy.effective_at
     and pg_catalog.clock_timestamp()<policy.expires_at
     and p_jurisdiction=any(policy.supported_jurisdictions)
     and (p_environment<>'production' or policy.production_approved)
     and (
       select pg_catalog.count(*)
         from argus_app.starpath_manifest_nodes node
        where node.manifest_id=manifest.id
     )=8
     and not exists (
       select 1
         from argus_app.starpath_manifest_nodes node
         join argus_app.starpath_evidence_bindings evidence
           on evidence.lesson_id=node.lesson_id
          and evidence.revision_id=node.revision_id
        where node.manifest_id=manifest.id
          and evidence.current_until<=pg_catalog.clock_timestamp()
     );

  if projection is null then
    raise exception 'starpath_content_unavailable' using errcode='23514';
  end if;
  return projection;
end
$$;

do $membership$
begin
  execute pg_catalog.format(
    'grant argus_app_owner to %I with set true',current_user
  );
end
$membership$;

grant create on schema argus_private to argus_app_owner;
alter function argus_private.resolve_starpath_member_authority(text,text)
  owner to argus_app_owner;
alter function argus_private.read_starpath_curriculum_projection(uuid,uuid,text,text)
  owner to argus_app_owner;
revoke create on schema argus_private from argus_app_owner;

revoke all on function
  argus_private.resolve_starpath_member_authority(text,text),
  argus_private.read_starpath_curriculum_projection(uuid,uuid,text,text)
from public,anon,authenticated,argus_runtime,argus_member,argus_staff,
     argus_callback,argus_worker,argus_jobs_owner,postgres,argus_app_owner;

grant execute on function
  argus_private.resolve_starpath_member_authority(text,text),
  argus_private.read_starpath_curriculum_projection(uuid,uuid,text,text)
to argus_member;

comment on function argus_private.resolve_starpath_member_authority(text,text) is
  'Returns the latest complete reviewed Starpath manifest and one non-personalized theme for a server-verified release-control scope.';
comment on function argus_private.read_starpath_curriculum_projection(uuid,uuid,text,text) is
  'Returns exact pinned reviewed Starpath member content without correctness flags or direct editorial table access.';

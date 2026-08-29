begin;

grant argus_worker to current_user with set true;
grant usage on schema extensions to argus_worker;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(18);

select is((select count(*)::bigint from pg_class relation
  join pg_namespace namespace on namespace.oid=relation.relnamespace
  where namespace.nspname='argus_app' and relation.relkind in ('r','p')),
  58::bigint,'the reviewed application relation inventory is complete');
select is((select count(*)::bigint from pg_class relation
  join pg_namespace namespace on namespace.oid=relation.relnamespace
  where namespace.nspname='argus_brokerage' and relation.relkind in ('r','p')),
  10::bigint,'the reviewed brokerage relation inventory is complete');
select is((select count(*)::bigint from pg_class relation
  join pg_namespace namespace on namespace.oid=relation.relnamespace
  where namespace.nspname='argus_private' and relation.relkind in ('r','p')),
  56::bigint,'the reviewed private relation inventory is complete');

select is(
  (select jsonb_agg(qualified_name order by qualified_name) from (
    select table_schema||'.'||table_name||'.'||column_name qualified_name
      from information_schema.columns
     where table_schema in ('argus_app','argus_brokerage','argus_private')
       and (data_type='ARRAY' or udt_name='jsonb')
  ) actual),
  (select jsonb_agg(qualified_name order by qualified_name) from (values
    ('argus_app.briefing_sections.payload'),
    ('argus_app.community_templates.asset_ids'),
    ('argus_app.coven_entries.qualification_payload'),
    ('argus_app.editorial_render_documents.document'),
    ('argus_app.editorial_revisions.payload'),
    ('argus_app.future_mirror_runs.assumptions'),
    ('argus_app.grimoires.asset_ids'),
    ('argus_app.moderation_cases.decision_payload'),
    ('argus_app.notification_preferences.quiet_hours'),
    ('argus_app.onboarding_states.completed_steps'),
    ('argus_app.ritual_scenario_revisions.evidence_claim_ids'),
    ('argus_app.ritual_scenario_revisions.idea_asset_ids'),
    ('argus_app.rowan_script_revisions.allowed_tokens'),
    ('argus_brokerage.accounts.capabilities'),
    ('argus_brokerage.order_projection_generations.normalized_payload'),
    ('argus_brokerage.projection_generations.normalized_payload'),
    ('argus_private.admin_audit_events.details'),
    ('argus_private.order_projection_generation_snapshots.snapshot_payload'),
    ('argus_private.order_previews.normalized_payload'),
    ('argus_private.projection_generation_snapshots.snapshot_payload'),
    ('argus_private.provider_commands.normalized_payload'),
    ('argus_private.privacy_export_generation_rows.row_payload'),
    ('argus_private.security_events.details'),
    ('argus_private.staff_principals.permissions')
  ) approved(qualified_name)),
  'every array and JSON column has one reviewed target-model disposition'
);

select is((select count(*)::bigint from pg_class relation
  join pg_namespace namespace on namespace.oid=relation.relnamespace
  where namespace.nspname in ('public','graphql_public')
    and relation.relname like 'argus_%'
    and relation.relkind in ('r','p','v','m')),0::bigint,
  'no Argus relation is exposed through the Data API schemas');

select is((select count(*)::bigint from pg_class relation
  join pg_namespace namespace on namespace.oid=relation.relnamespace
  where namespace.nspname in ('argus_app','argus_brokerage','argus_private')
    and relation.relkind in ('r','p')
    and (not relation.relrowsecurity or not relation.relforcerowsecurity)),
  0::bigint,'all registered relations force RLS');

select is((select count(distinct function_row.proname)::bigint
  from pg_proc function_row
  join pg_namespace namespace on namespace.oid=function_row.pronamespace
  where namespace.nspname in ('argus_app','argus_brokerage','argus_private')),
  201::bigint,'the reviewed routine-name inventory is complete');

select is((select count(*)::bigint from pg_proc function_row
  join pg_namespace namespace on namespace.oid=function_row.pronamespace
  where namespace.nspname in ('argus_app','argus_brokerage','argus_private')
    and has_function_privilege('public',function_row.oid,'execute')),
  0::bigint,'PUBLIC cannot execute any Argus routine');

select is((select count(*)::bigint from pg_proc function_row
  join pg_namespace namespace on namespace.oid=function_row.pronamespace
  join pg_roles owner on owner.oid=function_row.proowner
  where namespace.nspname in ('argus_app','argus_brokerage','argus_private')
    and owner.rolname in ('argus_runtime','argus_worker','argus_waitlist',
      'argus_edge','argus_worker_edge','argus_waitlist_edge')),
  0::bigint,'capability roles never own Argus routines');

set local role argus_worker;
select is(
  (select jsonb_object_agg(event_type,argus_private.retained_job_handler(event_type)
     order by event_type) from (values
    ('briefing.daily.requested'),('briefing.weekly.requested'),
    ('briefing.moon_cycle.requested'),('briefing.daily.generated'),
    ('briefing.weekly.generated'),('briefing.moon_cycle.generated'),
    ('media.structural_validation.requested'),('media.quarantine.cleanup'),
    ('content-report.created'),('privacy.export.requested'),
    ('privacy.deletion.requested'),('privacy.export.retention.requested'),
    ('webull.token.refresh.requested'),
    ('webull.projection.refresh.requested'),
    ('webull.command.reconciliation.requested')
  ) approved(event_type)),
  jsonb_build_object(
    'briefing.daily.requested','briefing-generation-coordinator',
    'briefing.weekly.requested','briefing-generation-coordinator',
    'briefing.moon_cycle.requested','briefing-generation-coordinator',
    'briefing.daily.generated','notification-record-writer',
    'briefing.weekly.generated','notification-record-writer',
    'briefing.moon_cycle.generated','notification-record-writer',
    'media.structural_validation.requested','media-structural-validation',
    'media.quarantine.cleanup','media-cleanup',
    'content-report.created','moderation-triage',
    'privacy.export.requested','privacy-export',
    'privacy.deletion.requested','privacy-purge',
    'privacy.export.retention.requested','privacy-export-retention',
    'webull.token.refresh.requested','webull-token-refresh',
    'webull.projection.refresh.requested','webull-projection-refresh',
    'webull.command.reconciliation.requested','webull-reconciliation'
  ),'SQL event types have the reviewed handler mapping');

select is(argus_private.retained_job_handler('unregistered.event'),null::text,
  'an unregistered event has no handler');
reset role;

select is((select array_agg(queue_name order by queue_name) from pgmq.meta
  where queue_name like 'argus_%' or queue_name like 'brokerage_%'),
  array['argus_jobs','brokerage_reconcile','brokerage_refresh']::character varying[],
  'the managed queue inventory is exact');

select is((select array_agg(jobname order by jobname) from cron.job
  where jobname like 'argus-%'),array[
    'argus-durable-work-coordinate','argus-waitlist-retention',
    'argus-webull-recovery-coordinate','argus-worker-dispatch-enqueue'
  ],'the managed Cron inventory is exact');

select is((select array_agg(id order by id) from storage.buckets
  where id in ('member-media','media-quarantine','privacy-exports')),
  array['media-quarantine','member-media','privacy-exports'],
  'the managed private Storage bucket inventory is exact');

select is((select count(*)::bigint
  from pg_constraint foreign_key
  join pg_class relation on relation.oid=foreign_key.conrelid
  join pg_namespace namespace on namespace.oid=relation.relnamespace
  where foreign_key.contype='f' and namespace.nspname='argus_app'
    and (
      foreign_key.conname like '%_u4_%'
      or relation.relname in (
        'onboarding_step_completions','notification_quiet_hours',
        'member_saved_items','content_report_targets',
        'editorial_render_documents','editorial_revision_assets',
        'ritual_scenario_revision_assets','ritual_scenario_revision_evidence',
        'grimoire_revision_assets','community_template_revision_assets',
        'coven_qualifications','asset_codex_revisions',
        'asset_codex_revision_evidence','asset_codex_revision_metrics'
      )
    )
    and not exists (
      select 1 from pg_index candidate
       where candidate.indrelid=foreign_key.conrelid
         and candidate.indisvalid and candidate.indisready
         and (candidate.indkey::smallint[])
               [0:cardinality(foreign_key.conkey)-1]=foreign_key.conkey
    )),0::bigint,
  'every U4 foreign key has a leading referencing-side index');

select todo_start('U4-U6 must add every missing referencing-side index after representative plan measurement');
select is((select count(*)::bigint from pg_constraint foreign_key
  join pg_class relation on relation.oid=foreign_key.conrelid
  join pg_namespace namespace on namespace.oid=relation.relnamespace
  where foreign_key.contype='f'
    and namespace.nspname in ('argus_app','argus_brokerage','argus_private')
    and not exists (
      select 1 from pg_index candidate
       where candidate.indrelid=foreign_key.conrelid
         and candidate.indisvalid and candidate.indisready
         and candidate.indpred is null
         and candidate.indkey::smallint[] @> foreign_key.conkey
    )),0::bigint,'every foreign key has a referencing-side index');
select todo_end();

select is((select count(*)::bigint from pg_policies
  where schemaname in ('argus_app','argus_brokerage','argus_private')
    and cmd in ('ALL','UPDATE') and qual is not null and with_check is null),
  0::bigint,'mutable policies never omit WITH CHECK');

select is((select count(*)::bigint from pg_proc function_row
  join pg_namespace namespace on namespace.oid=function_row.pronamespace
  where namespace.nspname in ('argus_app','argus_brokerage','argus_private')
    and function_row.prosecdef
    and not (
      'search_path=""'=any(coalesce(function_row.proconfig,array[]::text[]))
      or coalesce(function_row.proconfig,array[]::text[])::text
        like '%search_path=pg_catalog%'
    )),0::bigint,
  'every security-definer routine pins an approved trusted search path');

select * from finish();
rollback;

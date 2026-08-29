begin;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(3);

select is(
  (
    select array_agg(schedule.mode order by schedule.mode)
      from argus_app.ritual_schedules schedule
      join argus_app.editorial_revisions revision
        on revision.id=schedule.revision_id
      join argus_app.editorial_items item on item.id=revision.item_id
     where item.slug in ('local-reset-ritual','local-reset-astrology-ritual')
       and schedule.audience='member' and schedule.state='active'
       and schedule.local_date<=current_date
       and schedule.effective_at<=current_timestamp
  ),
  array['astrology','tarot']::text[],
  'the clean database exposes an active member schedule for both ritual modes'
);

select is(
  (
    select count(*)::bigint
      from argus_app.ritual_schedules schedule
      join argus_app.editorial_revisions revision
        on revision.id=schedule.revision_id and revision.state='published'
      join argus_app.editorial_items item
        on item.id=revision.item_id
       and item.current_published_revision_id=revision.id
       and item.status='published'
      join argus_app.editorial_render_documents document
        on document.item_id=item.id and document.revision_id=revision.id
     where item.slug in ('local-reset-ritual','local-reset-astrology-ritual')
       and schedule.audience='member' and schedule.state='active'
  ),
  2::bigint,
  'each seeded member schedule resolves to a published render document'
);

select is(
  (
    select count(*)::bigint
      from argus_app.ritual_scenarios scenario
      join argus_app.ritual_scenario_revisions revision
        on revision.editorial_item_id=scenario.editorial_item_id
     where scenario.scenario_key in (
       'local-reset-tarot','local-reset-astrology'
     )
       and cardinality(revision.idea_asset_ids) between 3 and 5
       and cardinality(revision.evidence_claim_ids)>=1
  ),
  2::bigint,
  'each seeded ritual carries the minimum ideas and evidence projection'
);

select * from finish();
rollback;

begin;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(54);

select has_table('argus_app','editorial_render_documents',
  'published rendering documents have an immutable table');
select has_table('argus_app','editorial_revision_assets',
  'generic editorial asset relationships are normalized');
select has_table('argus_app','legacy_normalization_quarantine',
  'untransformable legacy rows have an explicit quarantine');
select has_table('argus_app','legacy_normalization_identity_map',
  'source-to-target mappings are durable and bijective');
select has_function('argus_private','sync_ritual_revision',array['uuid','jsonb'],
  'ritual normalization has a domain-specific command');
select has_function('argus_private','sync_asset_codex_revision',array['uuid','jsonb'],
  'Asset Codex normalization has a domain-specific command');
select has_function('argus_private','publish_editorial_revision',
  array['uuid','uuid','text'],
  'publication seals normalized state and rendering in one command');
select has_function('argus_private','list_current_published_editorial',
  array['text','integer'],
  'published lists use one bounded current-pointer projection');
select has_function('argus_private','get_current_published_editorial',
  array['text'],
  'published lookups use one exact current-pointer projection');
select hasnt_function(
  'argus_private','materialize_editorial_revision',array['text','uuid','jsonb'],
  'the generic editorial materializer is no longer callable');

select is(
  (select count(*)::bigint
     from pg_class relation
     join pg_namespace namespace on namespace.oid=relation.relnamespace
    where namespace.nspname='argus_app'
      and relation.relname in (
        'editorial_render_documents','editorial_revision_assets',
        'ritual_scenario_revision_assets','ritual_scenario_revision_evidence',
        'grimoire_revision_assets','community_template_revision_assets',
        'coven_qualifications','asset_codex_revisions',
        'asset_codex_revision_evidence','asset_codex_revision_metrics'
      )
      and relation.relrowsecurity and relation.relforcerowsecurity),
  10::bigint,
  'every normalized editorial relation forces RLS'
);

grant argus_app_owner,argus_edge,argus_runtime,argus_staff to current_user with set true;
grant usage on schema extensions to argus_edge,argus_runtime,argus_staff;

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  'c4000000-0000-4000-8000-000000000001',
  'authenticated','authenticated','u4-editor@example.test','',now(),
  '{"provider":"email","providers":["email"]}','{}',now(),now()
);
insert into argus_private.staff_principals(
  user_id,status,permissions,display_label
) values (
  'c4000000-0000-4000-8000-000000000001','active',
  array['editorial:read','editorial:write','editorial:review','editorial:publish'],
  'U4 editor'
);

insert into argus_app.catalog_assets(
  id,slug,symbol,name,asset_type,currency,exchange,status
) values
  ('c4000000-1000-4000-8000-000000000001','u4-asset-two','U4B','U4 asset two','etf','USD','SYNTHETIC','active'),
  ('c4000000-1000-4000-8000-000000000002','u4-asset-three','U4C','U4 asset three','etf','USD','SYNTHETIC','active'),
  ('c4000000-1000-4000-8000-000000000003','u4-asset-four','U4D','U4 asset four','etf','USD','SYNTHETIC','active');

insert into argus_app.companies(id,slug,name,asset_id,status) values (
  'c4000000-1500-4000-8000-000000000001','u4-company','U4 Company',
  'c4000000-1000-4000-8000-000000000001','active'
);

insert into argus_app.editorial_items(id,kind,slug,status) values
  ('c4000000-2000-4000-8000-000000000001','ritual','u4-ritual','draft'),
  ('c4000000-2000-4000-8000-000000000002','ritual','u4-other-ritual','draft'),
  ('c4000000-2000-4000-8000-000000000004','grimoire','u4-grimoire','draft'),
  ('c4000000-2000-4000-8000-000000000005','circle_template','u4-template','draft'),
  ('c4000000-2000-4000-8000-000000000006','coven','u4-coven','draft'),
  ('c4000000-2000-4000-8000-000000000007','asset_codex','u4-asset-two','draft');
insert into argus_app.editorial_revisions(
  id,item_id,revision_number,state,author_staff_id,content_hash,payload
) values
  ('c4000000-3000-4000-8000-000000000001',
   'c4000000-2000-4000-8000-000000000001',1,'draft',
   'c4000000-0000-4000-8000-000000000001',repeat('a',64),
   '{"title":"U4 ritual","interpretation":"Observe","guidance":"Reflect","market_label":"Synthetic","observation_at":"2026-08-29T12:00:00Z","uncertainty":"Fixture","idea_asset_ids":["10000000-0000-4000-8000-000000000002","c4000000-1000-4000-8000-000000000001","c4000000-1000-4000-8000-000000000002"],"evidence_claim_ids":["10000000-0000-4000-8000-000000000004"]}'::jsonb),
  ('c4000000-3000-4000-8000-000000000002',
   'c4000000-2000-4000-8000-000000000002',1,'draft',
   'c4000000-0000-4000-8000-000000000001',repeat('b',64),'{}'::jsonb),
  ('c4000000-3000-4000-8000-000000000004',
   'c4000000-2000-4000-8000-000000000004',1,'draft',
   'c4000000-0000-4000-8000-000000000001',repeat('d',64),'{}'::jsonb),
  ('c4000000-3000-4000-8000-000000000005',
   'c4000000-2000-4000-8000-000000000005',1,'draft',
   'c4000000-0000-4000-8000-000000000001',repeat('e',64),'{}'::jsonb),
  ('c4000000-3000-4000-8000-000000000006',
   'c4000000-2000-4000-8000-000000000006',1,'draft',
   'c4000000-0000-4000-8000-000000000001',repeat('f',64),'{}'::jsonb),
  ('c4000000-3000-4000-8000-000000000007',
   'c4000000-2000-4000-8000-000000000007',1,'draft',
   'c4000000-0000-4000-8000-000000000001',repeat('7',64),'{}'::jsonb);

set local role argus_edge;
select argus_private.install_request_context(
  'c4000000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000011','aal2'
);
reset role;

set local role argus_staff;
select lives_ok(
  $$select argus_private.create_ritual_editorial_item(
      'c4000000-2000-4000-8000-000000000001',
      '{"scenario_key":"u4-ritual","mode":"tarot","cadence":"daily"}'::jsonb
    )$$,
  'the ritual domain owns its root creation command'
);
select lives_ok(
  $$select argus_private.sync_ritual_revision(
      'c4000000-3000-4000-8000-000000000001',
      '{"title":"U4 ritual","interpretation":"Observe","guidance":"Reflect","market_label":"Synthetic","observation_at":"2026-08-29T12:00:00Z","uncertainty":"Fixture","idea_asset_ids":["10000000-0000-4000-8000-000000000002","c4000000-1000-4000-8000-000000000001","c4000000-1000-4000-8000-000000000002"],"evidence_claim_ids":["10000000-0000-4000-8000-000000000004"]}'::jsonb
    )$$,
  'the ritual command accepts minimum valid asset and evidence cardinality'
);
select is(
  (select jsonb_agg(asset_id order by ordinal)
     from argus_app.ritual_scenario_revision_assets
    where revision_id='c4000000-3000-4000-8000-000000000001'),
  '["10000000-0000-4000-8000-000000000002","c4000000-1000-4000-8000-000000000001","c4000000-1000-4000-8000-000000000002"]'::jsonb,
  'ritual assets preserve source order without gaps'
);
select is(
  (select jsonb_agg(evidence_claim_id order by ordinal)
     from argus_app.ritual_scenario_revision_evidence
    where revision_id='c4000000-3000-4000-8000-000000000001'),
  '["10000000-0000-4000-8000-000000000004"]'::jsonb,
  'ritual evidence preserves source order and minimum cardinality'
);
select is(
  (select to_jsonb(idea_asset_ids) from argus_app.ritual_scenario_revisions
    where revision_id='c4000000-3000-4000-8000-000000000001'),
  (select jsonb_agg(asset_id order by ordinal)
     from argus_app.ritual_scenario_revision_assets
    where revision_id='c4000000-3000-4000-8000-000000000001'),
  'ritual asset compatibility remains equal to normalized authority'
);
select is(
  (select to_jsonb(evidence_claim_ids) from argus_app.ritual_scenario_revisions
    where revision_id='c4000000-3000-4000-8000-000000000001'),
  (select jsonb_agg(evidence_claim_id order by ordinal)
     from argus_app.ritual_scenario_revision_evidence
    where revision_id='c4000000-3000-4000-8000-000000000001'),
  'ritual evidence compatibility remains equal to normalized authority'
);
select throws_ok(
  $$select argus_private.sync_ritual_revision(
      'c4000000-3000-4000-8000-000000000001',
      '{"title":"x","interpretation":"x","guidance":"x","market_label":"x","observation_at":"2026-08-29T12:00:00Z","uncertainty":"x","idea_asset_ids":["10000000-0000-4000-8000-000000000002","c4000000-1000-4000-8000-000000000001"],"evidence_claim_ids":["10000000-0000-4000-8000-000000000004"]}'::jsonb
    )$$,
  '23514','invalid_editorial_payload','ritual assets enforce the minimum of three'
);
select throws_ok(
  $$select argus_private.sync_ritual_revision(
      'c4000000-3000-4000-8000-000000000001',
      '{"title":"x","interpretation":"x","guidance":"x","market_label":"x","observation_at":"2026-08-29T12:00:00Z","uncertainty":"x","idea_asset_ids":["10000000-0000-4000-8000-000000000002","c4000000-1000-4000-8000-000000000001","c4000000-1000-4000-8000-000000000002","c4000000-1000-4000-8000-000000000003","c4000000-1000-4000-8000-000000000004","c4000000-1000-4000-8000-000000000005"],"evidence_claim_ids":["10000000-0000-4000-8000-000000000004"]}'::jsonb
    )$$,
  '23514','invalid_editorial_payload','ritual assets enforce the maximum of five'
);
select throws_ok(
  $$select argus_private.sync_ritual_revision(
      'c4000000-3000-4000-8000-000000000001',
      '{"title":"x","interpretation":"x","guidance":"x","market_label":"x","observation_at":"2026-08-29T12:00:00Z","uncertainty":"x","idea_asset_ids":["10000000-0000-4000-8000-000000000002","c4000000-1000-4000-8000-000000000001","c4000000-1000-4000-8000-000000000002"],"evidence_claim_ids":[]}'::jsonb
    )$$,
  '23514','invalid_editorial_payload','ritual evidence rejects an empty required collection'
);
select throws_ok(
  $$select argus_private.sync_ritual_revision(
      'c4000000-3000-4000-8000-000000000001',
      '{"title":"x","interpretation":"x","guidance":"x","market_label":"x","observation_at":"2026-08-29T12:00:00Z","uncertainty":"x","idea_asset_ids":["10000000-0000-4000-8000-000000000002","c4000000-1000-4000-8000-000000000001","c4000000-1000-4000-8000-000000000099"],"evidence_claim_ids":["10000000-0000-4000-8000-000000000004"]}'::jsonb
    )$$,
  '23514','invalid_editorial_evidence','missing ritual assets are rejected without partial writes'
);
select throws_ok(
  $$select argus_private.sync_ritual_revision(
      'c4000000-3000-4000-8000-000000000001',
      '{"title":"x","interpretation":"x","guidance":"x","market_label":"x","observation_at":"2026-08-29T12:00:00Z","uncertainty":"x","idea_asset_ids":["10000000-0000-4000-8000-000000000002","10000000-0000-4000-8000-000000000002","c4000000-1000-4000-8000-000000000002"],"evidence_claim_ids":["10000000-0000-4000-8000-000000000004"]}'::jsonb
    )$$,
  '23514','invalid_editorial_evidence','duplicate ritual assets are rejected without partial writes'
);
select throws_ok(
  $$insert into argus_app.ritual_scenario_revision_assets(
      editorial_item_id,revision_id,asset_id,ordinal
    ) values (
      'c4000000-2000-4000-8000-000000000001',
      'c4000000-3000-4000-8000-000000000001',
      'c4000000-1000-4000-8000-000000000003',4
    )$$,
  '42501',null,
  'staff cannot bypass the domain synchronizer to create position gaps'
);
select lives_ok(
  $$select argus_private.create_grimoire_editorial_item(
      'c4000000-2000-4000-8000-000000000004','{"theme_code":"u4-theme"}'::jsonb
    )$$,
  'Grimoire root creation stays inside its domain command'
);
select lives_ok(
  $$select argus_private.sync_grimoire_revision(
      'c4000000-3000-4000-8000-000000000004','{"asset_ids":[]}'::jsonb
    )$$,
  'Grimoire accepts an empty optional asset collection'
);
select lives_ok(
  $$select argus_private.sync_grimoire_revision(
      'c4000000-3000-4000-8000-000000000004',
      '{"asset_ids":["c4000000-1000-4000-8000-000000000002","10000000-0000-4000-8000-000000000002"]}'::jsonb
    )$$,
  'Grimoire replaces its ordered asset authority atomically'
);
select ok(
  (select to_jsonb(grimoire.asset_ids)=(
            select jsonb_agg(asset.asset_id order by asset.ordinal)
              from argus_app.grimoire_revision_assets asset
             where asset.grimoire_id=grimoire.id
               and asset.revision_id='c4000000-3000-4000-8000-000000000004'
          ) and to_jsonb(grimoire.asset_ids)=(
            select jsonb_agg(asset.asset_id order by asset.ordinal)
              from argus_app.editorial_revision_assets asset
             where asset.item_id=grimoire.editorial_item_id
               and asset.revision_id='c4000000-3000-4000-8000-000000000004'
          )
     from argus_app.grimoires grimoire
    where grimoire.editorial_item_id='c4000000-2000-4000-8000-000000000004'),
  'Grimoire compatibility and editorial projections preserve normalized order'
);
select throws_ok(
  $$select argus_private.sync_grimoire_revision(
      'c4000000-3000-4000-8000-000000000004',
      '{"asset_ids":["10000000-0000-4000-8000-000000000002","10000000-0000-4000-8000-000000000002"]}'::jsonb
    )$$,
  '23514','invalid_editorial_evidence','Grimoire rejects duplicate asset relationships'
);
select lives_ok(
  $$select argus_private.create_circle_template_editorial_item(
      'c4000000-2000-4000-8000-000000000005',
      '{"creator_label":"U4","title":"U4 template","description":"Fixture"}'::jsonb
    )$$,
  'Circle template creation stays inside its community command'
);
select lives_ok(
  $$select argus_private.sync_circle_template_revision(
      'c4000000-3000-4000-8000-000000000005','{"asset_ids":[]}'::jsonb
    )$$,
  'Circle templates retain empty optional-asset semantics'
);
select throws_ok(
  $$select argus_private.sync_circle_template_revision(
      'c4000000-3000-4000-8000-000000000005',
      jsonb_build_object('asset_ids',(
        select jsonb_agg('10000000-0000-4000-8000-000000000002'::text)
          from generate_series(1,51)
      ))
    )$$,
  '23514','invalid_editorial_payload','Circle templates enforce the fifty-asset maximum'
);
select lives_ok(
  $$select argus_private.create_coven_editorial_item(
      'c4000000-2000-4000-8000-000000000006',
      '{"company_id":"c4000000-1500-4000-8000-000000000001"}'::jsonb
    )$$,
  'Coven root creation binds a typed company through its domain command'
);
select lives_ok(
  $$select argus_private.sync_coven_revision(
      'c4000000-3000-4000-8000-000000000006',
      '{"qualifications":[{"criterion_code":"founder","claim":"Founder qualifies","evidence_claim_id":"10000000-0000-4000-8000-000000000004"}]}'::jsonb
    )$$,
  'Coven qualification normalization accepts typed evidence'
);
select is(
  (select coven.qualification_payload from argus_app.coven_entries coven
    where coven.editorial_item_id='c4000000-2000-4000-8000-000000000006'),
  (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
            'criterion_code',qualification.criterion_code,
            'claim',qualification.claim,
            'evidence_claim_id',qualification.evidence_claim_id
          )) order by qualification.ordinal)
     from argus_app.coven_qualifications qualification
    where qualification.revision_id='c4000000-3000-4000-8000-000000000006'),
  'Coven sealed compatibility payload equals its typed qualification projection'
);
select throws_ok(
  $$select argus_private.sync_coven_revision(
      'c4000000-3000-4000-8000-000000000006',
      jsonb_build_object('qualifications',(
        select jsonb_agg(jsonb_build_object('criterion_code','founder','claim','x'))
          from generate_series(1,21)
      ))
    )$$,
  '23514','invalid_editorial_payload','Coven enforces the twenty-qualification maximum'
);
select lives_ok(
  $$select argus_private.sync_asset_codex_revision(
      'c4000000-3000-4000-8000-000000000007',
      '{"asset_id":"c4000000-1000-4000-8000-000000000001","evidence_claim_ids":[],"metrics":[]}'::jsonb
    )$$,
  'Asset Codex accepts empty optional evidence and metric collections'
);
select throws_ok(
  $$select argus_private.sync_asset_codex_revision(
      'c4000000-3000-4000-8000-000000000007',
      '{"asset_id":"c4000000-1000-4000-8000-000000000001","evidence_claim_ids":["10000000-0000-4000-8000-000000000004","10000000-0000-4000-8000-000000000004"],"metrics":[]}'::jsonb
    )$$,
  '23514','invalid_editorial_payload','Asset Codex rejects duplicate evidence relationships'
);
select throws_ok(
  $$select argus_private.publish_editorial_revision(
      'c4000000-2000-4000-8000-000000000001',
      'c4000000-3000-4000-8000-000000000001','not approved'
    )$$,
  'P0002','resource_not_found','publication rejects a non-approved revision'
);
select lives_ok(
  $$update argus_app.editorial_revisions set state='submitted'
     where id='c4000000-3000-4000-8000-000000000001'$$,
  'the draft can enter review after normalization'
);
select lives_ok(
  $$update argus_app.editorial_revisions set state='approved'
     where id='c4000000-3000-4000-8000-000000000001'$$,
  'the reviewed revision can enter the publishable state'
);
select throws_ok(
  $$select argus_private.publish_editorial_revision(
      'c4000000-2000-4000-8000-000000000002',
      'c4000000-3000-4000-8000-000000000001','wrong parent'
    )$$,
  'P0002','resource_not_found','publication rejects another item revision without leaking state'
);
select lives_ok(
  $$select argus_private.publish_editorial_revision(
      'c4000000-2000-4000-8000-000000000001',
      'c4000000-3000-4000-8000-000000000001','approved fixture'
    )$$,
  'publication atomically seals normalized state and rendering'
);
select ok(
  (select item.status='published' and revision.state='published'
      and item.current_published_revision_id=revision.id
     from argus_app.editorial_items item
     join argus_app.editorial_revisions revision
       on revision.id=item.current_published_revision_id
    where item.id='c4000000-2000-4000-8000-000000000001'),
  'publication advances item, revision, and owned pointer together'
);
select ok(
  (select document.document=revision.payload
      and document.document_hash=revision.payload_canonical_hash
      and document.byte_size=revision.payload_byte_size
     from argus_app.editorial_render_documents document
     join argus_app.editorial_revisions revision on revision.id=document.revision_id
    where document.revision_id='c4000000-3000-4000-8000-000000000001'),
  'sealed historical rendering is field-for-field and hash equivalent'
);
select is(
  (select count(*)::bigint from argus_app.publication_events
    where item_id='c4000000-2000-4000-8000-000000000001'
      and revision_id='c4000000-3000-4000-8000-000000000001'
      and action='publish'),
  1::bigint,
  'publication records one parent-qualified event'
);
select throws_ok(
  $$update argus_app.ritual_scenario_revisions
       set idea_asset_ids=array['c4000000-1000-4000-8000-000000000003'::uuid]
     where revision_id='c4000000-3000-4000-8000-000000000001'$$,
  '42501',null,
  'staff cannot mutate a legacy ritual array independently'
);
reset role;

set local role argus_runtime;
select ok(
  not has_table_privilege('argus_runtime','argus_app.editorial_items','select')
    and not has_table_privilege('argus_runtime','argus_app.editorial_revisions','select')
    and not has_table_privilege('argus_runtime','argus_app.editorial_render_documents','select')
    and has_function_privilege(
      'argus_runtime',
      'argus_private.list_current_published_editorial(text,integer)','execute'
    )
    and (select count(*) from argus_private.list_current_published_editorial('ritual',100))=1,
  'the public capability has only the bounded current sealed publication projection'
);
select is(
  (select count(*)::bigint
     from argus_private.get_current_published_editorial('u4-other-ritual')),
  0::bigint,
  'the exact public projection does not reveal an unpublished slug'
);
reset role;

set local role argus_app_owner;
select throws_ok(
  $$insert into argus_app.ritual_scenario_revision_assets(
      editorial_item_id,revision_id,asset_id,ordinal
    ) values (
      'c4000000-2000-4000-8000-000000000001',
      'c4000000-3000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002',4
    )$$,
  '23505',null,'normalized ritual assets reject duplicate targets'
);
select throws_ok(
  $$insert into argus_app.ritual_scenario_revision_assets(
      editorial_item_id,revision_id,asset_id,ordinal
    ) values (
      'c4000000-2000-4000-8000-000000000001',
      'c4000000-3000-4000-8000-000000000001',
      'c4000000-1000-4000-8000-000000000003',2
    )$$,
  '23505',null,'normalized ritual assets reject duplicate positions'
);
select throws_ok(
  $$insert into argus_app.ritual_scenario_revision_assets(
      editorial_item_id,revision_id,asset_id,ordinal
    ) values (
      'c4000000-2000-4000-8000-000000000002',
      'c4000000-3000-4000-8000-000000000001',
      'c4000000-1000-4000-8000-000000000003',4
    )$$,
  '23503',null,'normalized ritual assets reject a cross-parent revision pair'
);
reset role;

select has_trigger(
  'argus_app','editorial_render_documents','editorial_render_documents_immutable',
  'sealed rendering documents have an immutable update/delete trigger'
);
select is(
  (select trigger.tgenabled
     from pg_trigger trigger
     join pg_class relation on relation.oid=trigger.tgrelid
     join pg_namespace namespace on namespace.oid=relation.relnamespace
    where namespace.nspname='argus_app'
      and relation.relname='editorial_render_documents'
      and trigger.tgname='editorial_render_documents_immutable'),
  'O'::"char",
  'the sealed rendering guard is enabled in normal application sessions'
);
select is(
  (select array_agg(attribute.attname order by key.ordinality)
     from pg_constraint constraint_record
     cross join lateral unnest(constraint_record.conkey) with ordinality key(attnum,ordinality)
     join pg_attribute attribute
       on attribute.attrelid=constraint_record.conrelid and attribute.attnum=key.attnum
    where constraint_record.conrelid='argus_app.editorial_items'::regclass
      and constraint_record.conname='editorial_current_revision_fk'),
  array['id','current_published_revision_id']::name[],
  'publication pointers are constrained by the owning item and revision together'
);

select * from finish();
rollback;

begin;

-- A revision must retain an author even when it is bootstrap reference data.
-- This auth row has no password and is permanently banned, so it cannot
-- become an interactive identity. Its narrowly scoped staff permissions exist
-- only so FORCE-RLS publication tables can verify this migration's provenance.
insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at,banned_until,
  is_sso_user,is_anonymous
) values (
  '00000000-0000-0000-0000-000000000000',
  '10000000-0000-4000-8000-000000000098',
  'authenticated','authenticated','editorial-system@argus.invalid',null,null,
  '{"provider":"email","providers":["email"],"system_actor":true}'::jsonb,
  '{}'::jsonb,'2026-01-01T00:00:00Z','2026-01-01T00:00:00Z','infinity',
  false,false
) on conflict (id) do nothing;

insert into argus_private.staff_principals(
  user_id,status,permissions,display_label,revocation_epoch,revoked_at
) values (
  '10000000-0000-4000-8000-000000000098','active',
  array['editorial:write','editorial:publish'],
  'Argus editorial bootstrap',0,null
) on conflict (user_id) do nothing;

insert into argus_app.catalog_assets(
  id,slug,symbol,name,asset_type,currency,exchange,status
) values
  (
    '10000000-0000-4000-8000-000000000002','broad-market-example','ARGX',
    'Argus broad-market research example','etf','USD','SYNTHETIC','active'
  ),
  (
    '10000000-0000-4000-8000-000000000005','dividend-example','VIG',
    'Dividend durability research example','etf','USD','SYNTHETIC','active'
  ),
  (
    '10000000-0000-4000-8000-000000000006','health-care-example','XLV',
    'Health care resilience research example','etf','USD','SYNTHETIC','active'
  ),
  (
    '10000000-0000-4000-8000-000000000007','women-led-example','WOMN',
    'Women-led companies research example','etf','USD','SYNTHETIC','active'
  )
on conflict (id) do nothing;

insert into argus_app.evidence_sources(
  id,canonical_url,title,publisher,published_at,retrieved_at,source_kind,status
) values (
  '10000000-0000-4000-8000-000000000003',
  'https://example.invalid/argus-synthetic-research',
  'Synthetic research fixture','Argus local development',
  '2026-01-01T00:00:00Z','2026-01-01T00:00:00Z','synthetic_fixture','active'
) on conflict (id) do nothing;

insert into argus_app.evidence_claims(
  id,source_id,claim_type,summary,observed_at,uncertainty,status
) values (
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000003','fixture',
  'Synthetic evidence used only to prove the Daily Ritual research loop.',
  '2026-01-01T00:00:00Z',
  'Synthetic educational evidence is not current market data.','active'
) on conflict (id) do nothing;

-- Repair the earlier incomplete local-reset item only when it has never
-- acquired a revision. Any real publication history remains untouched.
delete from argus_app.editorial_items item
 where item.id='10000000-0000-4000-8000-000000000001'
   and item.slug='local-reset-ritual'
   and not exists (
     select 1 from argus_app.editorial_revisions revision
      where revision.item_id=item.id
   );

insert into argus_app.editorial_items(
  id,kind,slug,status,current_published_revision_id,created_at
) values
  (
    '10000000-0000-4000-8000-000000000001','ritual',
    'local-reset-ritual','draft',null,'2026-01-01T00:00:00Z'
  ),
  (
    '10000000-0000-4000-8000-000000000008','ritual',
    'local-reset-astrology-ritual','draft',null,'2026-01-01T00:00:00Z'
  )
on conflict (id) do nothing;

insert into argus_app.editorial_revisions(
  id,item_id,revision_number,state,author_staff_id,content_hash,payload,created_at
) values
  (
    '10000000-0000-4000-8000-000000000010',
    '10000000-0000-4000-8000-000000000001',1,'approved',
    '10000000-0000-4000-8000-000000000098',repeat('a',64),
    $json${
      "title":"The Compass",
      "art_key":"the_compass",
      "art_alt":"A compass card inviting deliberate research",
      "interpretation":"Direction matters more than urgency.",
      "guidance":"Compare the evidence and decide what deserves a closer look.",
      "market_label":"Market-informed Demo",
      "observation_at":"2026-01-01T00:00:00Z",
      "revision_number":1,
      "uncertainty":"Synthetic educational context can differ from current markets.",
      "idea_asset_ids":[
        "10000000-0000-4000-8000-000000000005",
        "10000000-0000-4000-8000-000000000006",
        "10000000-0000-4000-8000-000000000007"
      ],
      "evidence_claim_ids":["10000000-0000-4000-8000-000000000004"],
      "ideas":[
        {"asset_id":"10000000-0000-4000-8000-000000000005","symbol":"VIG","name":"Dividend durability","appearance_reason":"A steady quality lens for comparison.","risk_summary":"Dividend strategies can lag and lose value."},
        {"asset_id":"10000000-0000-4000-8000-000000000006","symbol":"XLV","name":"Health care resilience","appearance_reason":"A defensive sector lens for comparison.","risk_summary":"Sector concentration and policy changes can hurt returns."},
        {"asset_id":"10000000-0000-4000-8000-000000000007","symbol":"WOMN","name":"Women-led companies","appearance_reason":"A leadership lens for broader research.","risk_summary":"Thematic funds can be concentrated and volatile."}
      ],
      "evidence":[
        {"claim_id":"10000000-0000-4000-8000-000000000004","factor_label":"Synthetic fixture","observed_at":"2026-01-01T00:00:00Z","summary":"A deterministic evidence record keeps this research loop inspectable.","uncertainty":"This is not current market evidence."}
      ]
    }$json$::jsonb,'2026-01-01T00:00:00Z'
  ),
  (
    '10000000-0000-4000-8000-000000000011',
    '10000000-0000-4000-8000-000000000008',1,'approved',
    '10000000-0000-4000-8000-000000000098',repeat('b',64),
    $json${
      "title":"The Star Map",
      "art_key":"the_star",
      "art_alt":"A field of stars framing a patient research path",
      "interpretation":"Patterns can guide questions without predicting outcomes.",
      "guidance":"Use the signal as a prompt to inspect evidence and uncertainty.",
      "market_label":"Market-informed Demo",
      "observation_at":"2026-01-01T00:00:00Z",
      "revision_number":1,
      "uncertainty":"Synthetic educational context can differ from current markets.",
      "idea_asset_ids":[
        "10000000-0000-4000-8000-000000000005",
        "10000000-0000-4000-8000-000000000006",
        "10000000-0000-4000-8000-000000000007"
      ],
      "evidence_claim_ids":["10000000-0000-4000-8000-000000000004"],
      "ideas":[
        {"asset_id":"10000000-0000-4000-8000-000000000005","symbol":"VIG","name":"Dividend durability","appearance_reason":"A steady quality lens for comparison.","risk_summary":"Dividend strategies can lag and lose value."},
        {"asset_id":"10000000-0000-4000-8000-000000000006","symbol":"XLV","name":"Health care resilience","appearance_reason":"A defensive sector lens for comparison.","risk_summary":"Sector concentration and policy changes can hurt returns."},
        {"asset_id":"10000000-0000-4000-8000-000000000007","symbol":"WOMN","name":"Women-led companies","appearance_reason":"A leadership lens for broader research.","risk_summary":"Thematic funds can be concentrated and volatile."}
      ],
      "evidence":[
        {"claim_id":"10000000-0000-4000-8000-000000000004","factor_label":"Synthetic fixture","observed_at":"2026-01-01T00:00:00Z","summary":"A deterministic evidence record keeps this research loop inspectable.","uncertainty":"This is not current market evidence."}
      ]
    }$json$::jsonb,'2026-01-01T00:00:00Z'
  )
on conflict (id) do nothing;

insert into argus_app.ritual_scenarios(
  id,editorial_item_id,scenario_key,mode,cadence
) values
  (
    '10000000-0000-4000-8000-000000000012',
    '10000000-0000-4000-8000-000000000001',
    'local-reset-tarot','tarot','daily'
  ),
  (
    '10000000-0000-4000-8000-000000000013',
    '10000000-0000-4000-8000-000000000008',
    'local-reset-astrology','astrology','daily'
  )
on conflict (id) do nothing;

insert into argus_app.ritual_scenario_revisions(
  revision_id,title,interpretation,guidance,market_label,observation_at,
  uncertainty,idea_asset_ids,evidence_claim_ids,editorial_item_id
) values
  (
    '10000000-0000-4000-8000-000000000010','The Compass',
    'Direction matters more than urgency.',
    'Compare the evidence and decide what deserves a closer look.',
    'Market-informed Demo','2026-01-01T00:00:00Z',
    'Synthetic educational context can differ from current markets.',
    array[
      '10000000-0000-4000-8000-000000000005'::uuid,
      '10000000-0000-4000-8000-000000000006'::uuid,
      '10000000-0000-4000-8000-000000000007'::uuid
    ],
    array['10000000-0000-4000-8000-000000000004'::uuid],
    '10000000-0000-4000-8000-000000000001'
  ),
  (
    '10000000-0000-4000-8000-000000000011','The Star Map',
    'Patterns can guide questions without predicting outcomes.',
    'Use the signal as a prompt to inspect evidence and uncertainty.',
    'Market-informed Demo','2026-01-01T00:00:00Z',
    'Synthetic educational context can differ from current markets.',
    array[
      '10000000-0000-4000-8000-000000000005'::uuid,
      '10000000-0000-4000-8000-000000000006'::uuid,
      '10000000-0000-4000-8000-000000000007'::uuid
    ],
    array['10000000-0000-4000-8000-000000000004'::uuid],
    '10000000-0000-4000-8000-000000000008'
  )
on conflict (revision_id) do nothing;

do $membership$
begin
  execute pg_catalog.format(
    'grant argus_edge,argus_app_owner,argus_staff to %I with set true',
    current_user
  );
end
$membership$;

set local role argus_edge;
select argus_private.install_request_context(
  '10000000-0000-4000-8000-000000000098',
  '10000000-0000-4000-8000-000000000097','aal2'
);
reset role;

set local role argus_app_owner;

insert into argus_app.editorial_revision_assets(
  item_id,revision_id,asset_id,ordinal
)
select fixture.item_id,fixture.revision_id,fixture.asset_id,fixture.ordinal
  from (values
    ('10000000-0000-4000-8000-000000000001'::uuid,'10000000-0000-4000-8000-000000000010'::uuid,'10000000-0000-4000-8000-000000000005'::uuid,1),
    ('10000000-0000-4000-8000-000000000001'::uuid,'10000000-0000-4000-8000-000000000010'::uuid,'10000000-0000-4000-8000-000000000006'::uuid,2),
    ('10000000-0000-4000-8000-000000000001'::uuid,'10000000-0000-4000-8000-000000000010'::uuid,'10000000-0000-4000-8000-000000000007'::uuid,3),
    ('10000000-0000-4000-8000-000000000008'::uuid,'10000000-0000-4000-8000-000000000011'::uuid,'10000000-0000-4000-8000-000000000005'::uuid,1),
    ('10000000-0000-4000-8000-000000000008'::uuid,'10000000-0000-4000-8000-000000000011'::uuid,'10000000-0000-4000-8000-000000000006'::uuid,2),
    ('10000000-0000-4000-8000-000000000008'::uuid,'10000000-0000-4000-8000-000000000011'::uuid,'10000000-0000-4000-8000-000000000007'::uuid,3)
  ) fixture(item_id,revision_id,asset_id,ordinal)
on conflict do nothing;

insert into argus_app.ritual_scenario_revision_assets(
  editorial_item_id,revision_id,asset_id,ordinal
)
select asset.item_id,asset.revision_id,asset.asset_id,asset.ordinal
  from argus_app.editorial_revision_assets asset
 where asset.revision_id in (
   '10000000-0000-4000-8000-000000000010',
   '10000000-0000-4000-8000-000000000011'
 )
on conflict do nothing;

insert into argus_app.ritual_scenario_revision_evidence(
  editorial_item_id,revision_id,evidence_claim_id,ordinal
) values
  (
    '10000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000010',
    '10000000-0000-4000-8000-000000000004',1
  ),
  (
    '10000000-0000-4000-8000-000000000008',
    '10000000-0000-4000-8000-000000000011',
    '10000000-0000-4000-8000-000000000004',1
  )
on conflict do nothing;

reset role;

set local role argus_staff;
select argus_private.publish_editorial_revision(
         '10000000-0000-4000-8000-000000000001',
         '10000000-0000-4000-8000-000000000010',
         'Bootstrap deterministic Daily Ritual reference content.'
       )
 where exists (
   select 1 from argus_app.editorial_revisions revision
    where revision.id='10000000-0000-4000-8000-000000000010'
      and revision.state='approved'
 );
select argus_private.publish_editorial_revision(
         '10000000-0000-4000-8000-000000000008',
         '10000000-0000-4000-8000-000000000011',
         'Bootstrap deterministic astrology Ritual reference content.'
       )
 where exists (
   select 1 from argus_app.editorial_revisions revision
    where revision.id='10000000-0000-4000-8000-000000000011'
      and revision.state='approved'
 );
reset role;

do $membership$
begin
  execute pg_catalog.format(
    'grant argus_edge,argus_app_owner,argus_staff to %I with set false',
    current_user
  );
end
$membership$;

insert into argus_app.ritual_schedules(
  id,local_date,mode,revision_id,audience,state,effective_at
) values
  (
    '10000000-0000-4000-8000-000000000014','2026-01-01','tarot',
    '10000000-0000-4000-8000-000000000010','member','active',
    '2026-01-01T00:00:00Z'
  ),
  (
    '10000000-0000-4000-8000-000000000015','2026-01-01','astrology',
    '10000000-0000-4000-8000-000000000011','member','active',
    '2026-01-01T00:00:00Z'
  )
on conflict (id) do nothing;

commit;

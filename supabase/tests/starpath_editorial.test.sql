begin;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(38);

select has_column(
  'argus_app','editorial_review_requests','discipline',
  'review requests distinguish general, factual, and compliance work'
);
select has_column(
  'argus_app','editorial_review_requests','sealed_content_hash',
  'review requests bind the exact submitted content hash'
);
select has_column(
  'argus_app','editorial_review_decisions','policy_version',
  'review decisions bind the exact no-advice policy version'
);
select has_table('argus_app','starpath_policies',
  'Starpath policy approvals are durable and versioned');
select has_table('argus_app','starpath_lessons',
  'Starpath stable lessons are normalized');
select has_table('argus_app','starpath_lesson_revisions',
  'Starpath reviewed lesson revisions are normalized');
select has_table('argus_app','starpath_factual_sections',
  'mythic framing and factual sections are separate relations');
select has_table('argus_app','starpath_knowledge_check_options',
  'knowledge-check answers are normalized under their question');
select has_table('argus_app','starpath_evidence_bindings',
  'every factual section can bind dated evidence');
select has_table('argus_app','starpath_curriculum_manifests',
  'the eight-node curriculum is an immutable manifest');
select has_table('argus_app','starpath_manifest_nodes',
  'manifest nodes bind stable lessons to exact revisions');
select has_function(
  'argus_private','validate_starpath_member_copy',array['text'],
  'member copy has a defense-in-depth no-advice validator'
);
select has_function(
  'argus_private','sync_starpath_revision',array['uuid','jsonb'],
  'Starpath drafts materialize through a typed domain command'
);
select has_function(
  'argus_private','submit_starpath_revision',array['uuid','text'],
  'Starpath submission seals and opens two review disciplines'
);
select has_function(
  'argus_private','decide_starpath_review',array['uuid','text','text','text'],
  'Starpath decisions are discipline-specific attestations'
);
select has_function(
  'argus_private','publish_starpath_manifest',array['uuid','text'],
  'manifest publication validates the atomic eight-node curriculum'
);

do $membership$ begin
  execute pg_catalog.format(
    'grant argus_app_owner,argus_edge,argus_staff to %I with set true',
    current_user
  );
end $membership$;
grant usage on schema extensions to argus_app_owner,argus_edge,argus_staff;
set local role argus_app_owner;
select lives_ok(
  $$select argus_private.validate_starpath_member_copy(
      'Scammers may say "buy now"; that urgency is a warning sign.'
    )$$,
  'quoted scam-warning language remains valid educational context'
);
select throws_ok(
  $$select argus_private.validate_starpath_member_copy(
      'This is the best ETF for every beginner.'
    )$$,
  '23514','prohibited_investment_guidance',
  'best-investment claims fail the defense-in-depth validator'
);
select throws_ok(
  $$select argus_private.validate_starpath_member_copy(
      'Buy this stock before the market closes.'
    )$$,
  '23514','prohibited_investment_guidance',
  'actionable security instructions fail the defense-in-depth validator'
);
reset role;

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000',
   '51000000-0000-4000-8000-000000000001','authenticated','authenticated',
   'starpath-reviewer@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000',
   '51000000-0000-4000-8000-000000000002','authenticated','authenticated',
   'starpath-author@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now());

insert into argus_private.staff_principals(
  user_id,status,permissions,display_label
) values
  ('51000000-0000-4000-8000-000000000001','active',
   array['editorial:read','editorial:write','editorial:review:factual',
         'editorial:review:compliance','editorial:publish'],
   'Starpath dual reviewer'),
  ('51000000-0000-4000-8000-000000000002','active',
   array['editorial:write'],'Starpath author');

set local role argus_edge;
select argus_private.install_request_context(
  '51000000-0000-4000-8000-000000000001',
  '51000000-1000-4000-8000-000000000001','aal2'
);
set local role argus_staff;

insert into argus_app.starpath_policies(
  policy_version,status,policy_document_hash,approved_by,approved_at,
  effective_at,expires_at,supported_jurisdictions,production_approved,
  r20_trigger_snapshot
) values (
  'starpath-no-advice-v1','approved',repeat('a',64),
  '51000000-0000-4000-8000-000000000001',now(),now()-interval '1 day',
  now()+interval '365 days',array['US'],'true',
  array['no-personalization','no-security-ranking','no-investment-action-prompt']
);

insert into argus_app.editorial_items(id,kind,slug,status) values (
  '51000000-2000-4000-8000-000000000001','starpath_lesson',
  'how-markets-match-orders','draft'
);
select lives_ok(
  $$select argus_private.create_starpath_editorial_item(
      '51000000-2000-4000-8000-000000000001',
      '{"stable_key":"how-markets-match-orders","pathway_ordinal":1,"pathway_position":1}'::jsonb
    )$$,
  'a stable Starpath lesson is created only through its typed command'
);

insert into argus_app.editorial_revisions(
  id,item_id,revision_number,state,author_staff_id,content_hash,payload
) values (
  '51000000-3000-4000-8000-000000000001',
  '51000000-2000-4000-8000-000000000001',1,'draft',
  '51000000-0000-4000-8000-000000000002',repeat('b',64),
  $payload${
    "stable_key":"how-markets-match-orders",
    "pathway_ordinal":1,
    "pathway_position":1,
    "policy_version":"starpath-no-advice-v1",
    "classification":"education_general",
    "title":"How markets match orders",
    "tarot_key":"justice",
    "tarot_accessible_label":"Justice, used only as a balance mnemonic",
    "mythic_mnemonic":"Picture balanced scales as a memory cue for two sides meeting.",
    "factual_summary":"A market brings orders from buyers and sellers together under defined rules.",
    "material_limitations":"Execution prices and availability can differ because market conditions and order terms vary.",
    "risk_context":"Prices can change, and an order is not a promise of a particular outcome.",
    "recall_prompt":"What two sides does a market bring together?",
    "rowan_explanation":"The card is only a memory image. The fact is that market rules match compatible orders.",
    "sections":[{
      "kind":"fact",
      "heading":"Orders have terms",
      "body":"An order states instructions such as the instrument, quantity, and order type.",
      "uncertainty":"Available order types and handling rules vary by venue and broker.",
      "observed_at":"2026-08-30T00:00:00Z",
      "evidence":[{
        "canonical_url":"https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work/types-orders",
        "source_title":"Types of Orders",
        "publisher":"U.S. Securities and Exchange Commission",
        "source_observed_at":"2026-08-30T00:00:00Z",
        "effective_at":"2026-08-30T00:00:00Z",
        "retrieved_at":"2026-08-30T00:00:00Z",
        "current_until":"2027-08-30T00:00:00Z",
        "claim_summary":"Investor.gov describes common order instructions and their operation."
      }]
    }],
    "check":{
      "prompt":"What does an order communicate?",
      "explanation":"An order communicates execution instructions; it does not promise a result.",
      "options":[
        {"label":"Instructions such as instrument, quantity, and order type","is_correct":true,"explanation":"Correct. These are factual order terms."},
        {"label":"A guaranteed future return","is_correct":false,"explanation":"No. An order does not guarantee an investment result."}
      ]
    }
  }$payload$::jsonb
);

select lives_ok(
  $$select argus_private.sync_starpath_revision(
      '51000000-3000-4000-8000-000000000001',
      (select payload from argus_app.editorial_revisions
        where id='51000000-3000-4000-8000-000000000001')
    )$$,
  'a complete factual lesson materializes under the exact draft revision'
);
select is(
  (select count(*)::integer from argus_app.starpath_factual_sections
    where revision_id='51000000-3000-4000-8000-000000000001'),
  1,'the factual section stays separate from the mythic mnemonic'
);
select is(
  (select count(*)::integer from argus_app.starpath_evidence_bindings
    where revision_id='51000000-3000-4000-8000-000000000001'),
  1,'the factual section retains dated source evidence'
);
select is(
  (select count(*)::integer from argus_app.starpath_knowledge_check_options
    where revision_id='51000000-3000-4000-8000-000000000001'),
  2,'the comprehension check retains bounded revision-qualified options'
);

select lives_ok(
  $$select argus_private.submit_starpath_revision(
      '51000000-3000-4000-8000-000000000001','starpath-no-advice-v1'
    )$$,
  'submission seals one render document and opens both reviews'
);
select is(
  (select count(*)::integer from argus_app.editorial_review_requests
    where revision_id='51000000-3000-4000-8000-000000000001' and status='open'),
  2,'submission opens one factual and one compliance request'
);
select ok(
  (select count(distinct discipline)=2
      and bool_and(sealed_content_hash=revision.payload_canonical_hash)
      and bool_and(policy_version='starpath-no-advice-v1')
     from argus_app.editorial_review_requests request
     join argus_app.editorial_revisions revision on revision.id=request.revision_id
    where request.revision_id='51000000-3000-4000-8000-000000000001'),
  'both requests bind the exact sealed hash and policy version'
);

select lives_ok(
  $$select argus_private.decide_starpath_review(
      '51000000-3000-4000-8000-000000000001','factual','approved',
      'The lesson claims match the cited source and observation date.'
    )$$,
  'an authorized non-author can record the factual attestation'
);
select is(
  (select state from argus_app.editorial_revisions
    where id='51000000-3000-4000-8000-000000000001'),
  'submitted','one attestation alone cannot approve Starpath content'
);
select lives_ok(
  $$select argus_private.decide_starpath_review(
      '51000000-3000-4000-8000-000000000001','compliance','approved',
      'The lesson is factual, general, neutral, and contains no recommendation.'
    )$$,
  'the same non-author can attest compliance only with that separate scope'
);
select is(
  (select state from argus_app.editorial_revisions
    where id='51000000-3000-4000-8000-000000000001'),
  'approved','both exact-revision attestations approve the lesson'
);
select is(
  (select count(*)::integer from argus_app.editorial_review_decisions decision
    join argus_app.editorial_review_requests request on request.id=decision.request_id
    where request.revision_id='51000000-3000-4000-8000-000000000001'),
  2,'both immutable review decisions remain queryable'
);
select ok(
  (select count(distinct decision.discipline)=2
      and bool_and(decision.sealed_content_hash=revision.payload_canonical_hash)
      and bool_and(decision.policy_version='starpath-no-advice-v1')
     from argus_app.editorial_review_decisions decision
     join argus_app.editorial_review_requests request on request.id=decision.request_id
     join argus_app.editorial_revisions revision on revision.id=request.revision_id
    where request.revision_id='51000000-3000-4000-8000-000000000001'),
  'decision disciplines, hashes, and policy versions retain exact lineage'
);
select throws_ok(
  $$select argus_private.publish_editorial_revision(
      '51000000-2000-4000-8000-000000000001',
      '51000000-3000-4000-8000-000000000001',
      'Generic publication must not bypass the curriculum manifest.'
    )$$,
  '23514','starpath_manifest_publication_required',
  'generic editorial publication cannot publish a Starpath lesson'
);

select lives_ok(
  $$insert into argus_app.starpath_curriculum_manifests(
      id,manifest_version,policy_version,release_environment,supported_jurisdiction
    ) values (
      '51000000-4000-4000-8000-000000000001','starpath-empty-v1',
      'starpath-no-advice-v1','beta','US'
    )$$,
  'staff may prepare a draft manifest'
);
select throws_ok(
  $$select argus_private.publish_starpath_manifest(
      '51000000-4000-4000-8000-000000000001',
      'An incomplete curriculum must fail publication.'
    )$$,
  '23514','invalid_starpath_manifest',
  'a manifest without exactly eight ordered reviewed nodes fails atomically'
);

set local role argus_app_owner;
select results_eq(
  $$with changed as (
    update argus_app.starpath_factual_sections set body='Tampered fact'
     where revision_id='51000000-3000-4000-8000-000000000001'
    returning 1
  ) select count(*)::bigint from changed$$,
  $$values (0::bigint)$$,
  'reviewed normalized factual content cannot be mutated by its owner'
);
reset role;
select ok(
  not has_table_privilege(
    'authenticated','argus_app.starpath_lesson_revisions','select'
  ),
  'authenticated clients cannot query Starpath editorial authority directly'
);

select * from finish();
rollback;

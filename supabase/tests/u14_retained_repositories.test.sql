begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, pg_catalog, public;

select plan(30);

select has_column(
  'argus_app',
  'daily_ritual_assignments',
  'version',
  'ritual assignments expose a revision-conflict column'
);
select col_not_null(
  'argus_app',
  'daily_ritual_assignments',
  'version',
  'ritual assignment versions are mandatory'
);
select has_function(
  'argus_private',
  'provision_argus_member',
  array[]::text[],
  'Supabase Auth provisioning trigger function exists'
);
select trigger_is(
  'auth',
  'users',
  'provision_argus_member_after_auth_insert',
  'argus_private.provision_argus_member()',
  'auth.users invokes private Argus provisioning'
);
select ok(
  not has_function_privilege(
    'public',
    'argus_private.provision_argus_member()',
    'execute'
  ),
  'member provisioning is trigger-only and not public executable'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'authenticated', 'authenticated', 'owner-u14@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'authenticated', 'authenticated', 'staff-u14@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

select is(
  (select count(*)::bigint from argus_app.members where user_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
  1::bigint,
  'new Supabase Auth identity provisions the Argus member root'
);
select is(
  (select count(*)::bigint from argus_app.profiles where user_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd' and display_name = 'Argus member'),
  1::bigint,
  'new identity receives a non-authoritative profile default'
);
select is(
  (select count(*)::bigint from argus_app.preferences where user_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd' and version = 1),
  1::bigint,
  'new identity receives retained preference defaults'
);
select is(
  (select count(*)::bigint from argus_app.onboarding_states where user_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd' and current_step = 'welcome'),
  1::bigint,
  'new identity receives retained onboarding state without Demo authority'
);

insert into argus_private.staff_principals (
  user_id, permissions, display_label
) values (
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  array['editorial:read','privacy:read','privacy:write','operations:read','operations:write'],
  'U14 operator'
);
insert into argus_app.editorial_items (id, kind, slug, status) values
  ('dddddddd-1000-4000-8000-000000000001', 'ritual', 'u14-published', 'published'),
  ('dddddddd-1000-4000-8000-000000000002', 'ritual', 'u14-draft', 'draft');

set local role argus_runtime;
select is(
  (select count(*)::bigint from argus_app.editorial_items where slug = 'u14-published'),
  1::bigint,
  'anonymous runtime transaction can read published editorial state'
);
select is(
  (select count(*)::bigint from argus_app.editorial_items where slug = 'u14-draft'),
  0::bigint,
  'anonymous runtime transaction cannot read draft editorial state'
);
reset role;

insert into argus_app.evidence_sources (
  id, canonical_url, title, publisher, retrieved_at, source_kind, status
) values
  ('dddddddd-5000-4000-8000-000000000001', 'https://u14.example.test/active', 'Active evidence', 'U14', now(), 'filing', 'active'),
  ('dddddddd-5000-4000-8000-000000000002', 'https://u14.example.test/retired', 'Retired evidence', 'U14', now(), 'filing', 'retired');
insert into argus_app.evidence_claims (
  id, source_id, claim_type, summary, uncertainty, status
) values
  ('dddddddd-5100-4000-8000-000000000001', 'dddddddd-5000-4000-8000-000000000001', 'fact', 'Active claim', 'low', 'active'),
  ('dddddddd-5100-4000-8000-000000000002', 'dddddddd-5000-4000-8000-000000000002', 'fact', 'Withdrawn claim', 'low', 'withdrawn');

insert into argus_app.editorial_items (id, kind, slug, status) values
  ('dddddddd-5200-4000-8000-000000000001', 'coven', 'u14-coven-published', 'published'),
  ('dddddddd-5200-4000-8000-000000000002', 'coven', 'u14-coven-draft', 'draft'),
  ('dddddddd-5200-4000-8000-000000000003', 'grimoire', 'u14-grimoire-published', 'published'),
  ('dddddddd-5200-4000-8000-000000000004', 'grimoire', 'u14-grimoire-draft', 'draft'),
  ('dddddddd-5200-4000-8000-000000000005', 'circle_template', 'u14-template-published', 'published'),
  ('dddddddd-5200-4000-8000-000000000006', 'circle_template', 'u14-template-draft', 'draft'),
  ('dddddddd-5200-4000-8000-000000000007', 'ritual', 'u14-scenario-published', 'published'),
  ('dddddddd-5200-4000-8000-000000000008', 'ritual', 'u14-scenario-draft', 'draft'),
  ('dddddddd-5200-4000-8000-000000000009', 'rowan', 'u14-rowan-published', 'published'),
  ('dddddddd-5200-4000-8000-000000000010', 'rowan', 'u14-rowan-draft', 'draft');
insert into argus_app.editorial_revisions (
  id, item_id, revision_number, state, author_staff_id, content_hash, payload
) values
  ('dddddddd-5300-4000-8000-000000000001', 'dddddddd-5200-4000-8000-000000000001', 1, 'published', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'u14-coven-published', '{}'),
  ('dddddddd-5300-4000-8000-000000000002', 'dddddddd-5200-4000-8000-000000000002', 1, 'draft', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'u14-coven-draft', '{}'),
  ('dddddddd-5300-4000-8000-000000000003', 'dddddddd-5200-4000-8000-000000000003', 1, 'published', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'u14-grimoire-published', '{}'),
  ('dddddddd-5300-4000-8000-000000000004', 'dddddddd-5200-4000-8000-000000000004', 1, 'draft', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'u14-grimoire-draft', '{}'),
  ('dddddddd-5300-4000-8000-000000000005', 'dddddddd-5200-4000-8000-000000000005', 1, 'published', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'u14-template-published', '{}'),
  ('dddddddd-5300-4000-8000-000000000006', 'dddddddd-5200-4000-8000-000000000006', 1, 'draft', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'u14-template-draft', '{}'),
  ('dddddddd-5300-4000-8000-000000000007', 'dddddddd-5200-4000-8000-000000000007', 1, 'published', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'u14-scenario-published', '{}'),
  ('dddddddd-5300-4000-8000-000000000008', 'dddddddd-5200-4000-8000-000000000008', 1, 'draft', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'u14-scenario-draft', '{}'),
  ('dddddddd-5300-4000-8000-000000000009', 'dddddddd-5200-4000-8000-000000000009', 1, 'published', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'u14-rowan-published', '{}'),
  ('dddddddd-5300-4000-8000-000000000010', 'dddddddd-5200-4000-8000-000000000010', 1, 'draft', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'u14-rowan-draft', '{}');
update argus_app.editorial_items item
   set current_published_revision_id = revision.id
  from argus_app.editorial_revisions revision
 where revision.item_id = item.id
   and item.id::text like 'dddddddd-5200-%';

insert into argus_app.companies (id, slug, name, status) values
  ('dddddddd-5400-4000-8000-000000000001', 'u14-company-published', 'Published company', 'active'),
  ('dddddddd-5400-4000-8000-000000000002', 'u14-company-draft', 'Draft company', 'active');
insert into argus_app.coven_entries (id, editorial_item_id, company_id) values
  ('dddddddd-5500-4000-8000-000000000001', 'dddddddd-5200-4000-8000-000000000001', 'dddddddd-5400-4000-8000-000000000001'),
  ('dddddddd-5500-4000-8000-000000000002', 'dddddddd-5200-4000-8000-000000000002', 'dddddddd-5400-4000-8000-000000000002');
insert into argus_app.grimoires (id, editorial_item_id, theme_code) values
  ('dddddddd-5600-4000-8000-000000000001', 'dddddddd-5200-4000-8000-000000000003', 'published'),
  ('dddddddd-5600-4000-8000-000000000002', 'dddddddd-5200-4000-8000-000000000004', 'draft');
insert into argus_app.community_templates (
  id, editorial_item_id, creator_label, title, description
) values
  ('dddddddd-5700-4000-8000-000000000001', 'dddddddd-5200-4000-8000-000000000005', 'U14', 'Published template', 'Published'),
  ('dddddddd-5700-4000-8000-000000000002', 'dddddddd-5200-4000-8000-000000000006', 'U14', 'Draft template', 'Draft');
insert into argus_app.ritual_scenarios (
  id, editorial_item_id, scenario_key, mode, cadence
) values
  ('dddddddd-5800-4000-8000-000000000001', 'dddddddd-5200-4000-8000-000000000007', 'u14_published', 'tarot', 'daily'),
  ('dddddddd-5800-4000-8000-000000000002', 'dddddddd-5200-4000-8000-000000000008', 'u14_draft', 'tarot', 'daily');
insert into argus_app.ritual_scenario_revisions (
  revision_id, title, interpretation, guidance, market_label,
  observation_at, uncertainty
) values
  ('dddddddd-5300-4000-8000-000000000007', 'Published', 'Published', 'Published', 'Published', now(), 'low'),
  ('dddddddd-5300-4000-8000-000000000008', 'Draft', 'Draft', 'Draft', 'Draft', now(), 'low');
insert into argus_app.rowan_scripts (
  id, editorial_item_id, script_key, surface
) values
  ('dddddddd-5900-4000-8000-000000000001', 'dddddddd-5200-4000-8000-000000000009', 'u14_rowan_published', 'daily_ritual'),
  ('dddddddd-5900-4000-8000-000000000002', 'dddddddd-5200-4000-8000-000000000010', 'u14_rowan_draft', 'daily_ritual');
insert into argus_app.rowan_script_revisions (
  revision_id, body_template, risk_footer
) values
  ('dddddddd-5300-4000-8000-000000000009', 'Published Rowan', 'Published footer'),
  ('dddddddd-5300-4000-8000-000000000010', 'Draft Rowan', 'Draft footer');
insert into argus_app.rowan_context_bindings (
  id, surface, context_key, script_id, priority
) values
  ('dddddddd-5a00-4000-8000-000000000001', 'daily_ritual', 'daily', 'dddddddd-5900-4000-8000-000000000001', 1),
  ('dddddddd-5a00-4000-8000-000000000002', 'daily_ritual', 'draft', 'dddddddd-5900-4000-8000-000000000002', 1);

set local role argus_runtime;
do $$ begin
  perform argus_private.set_request_context(
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    'dddddddd-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;
select is(
  (select count(*)::bigint from argus_app.evidence_sources where id::text like 'dddddddd-5000-%'),
  1::bigint,
  'active members read active evidence sources but not retired sources'
);
select is(
  (select count(*)::bigint from argus_app.evidence_claims where id::text like 'dddddddd-5100-%'),
  1::bigint,
  'active members read active evidence claims but not withdrawn claims'
);
select is(
  (select count(*)::bigint from argus_app.companies where id::text like 'dddddddd-5400-%'),
  1::bigint,
  'active members read companies linked to published Coven only'
);
select is(
  (select count(*)::bigint from argus_app.coven_entries where id::text like 'dddddddd-5500-%'),
  1::bigint,
  'active members read published Coven entries but not draft entries'
);
select is(
  (select count(*)::bigint from argus_app.grimoires where id::text like 'dddddddd-5600-%'),
  1::bigint,
  'active members read published grimoires but not drafts'
);
select is(
  (select count(*)::bigint from argus_app.community_templates where id::text like 'dddddddd-5700-%'),
  1::bigint,
  'active members read published circle templates but not drafts'
);
select is(
  (select count(*)::bigint from argus_app.ritual_scenarios where id::text like 'dddddddd-5800-%'),
  1::bigint,
  'active members read published ritual scenarios but not drafts'
);
select is(
  (select count(*)::bigint from argus_app.ritual_scenario_revisions where revision_id::text in ('dddddddd-5300-4000-8000-000000000007','dddddddd-5300-4000-8000-000000000008')),
  1::bigint,
  'active members read published ritual revisions but not drafts'
);
select is(
  (select count(*)::bigint from argus_app.rowan_scripts where id::text like 'dddddddd-5900-%'),
  1::bigint,
  'active members read published Rowan scripts but not drafts'
);
select is(
  (select count(*)::bigint from argus_app.rowan_script_revisions where revision_id::text in ('dddddddd-5300-4000-8000-000000000009','dddddddd-5300-4000-8000-000000000010')),
  1::bigint,
  'active members read published Rowan revisions but not drafts'
);
select is(
  (select count(*)::bigint from argus_app.rowan_context_bindings where id::text like 'dddddddd-5a00-%'),
  1::bigint,
  'active members read published Rowan bindings but not draft bindings'
);
reset role;

insert into argus_app.privacy_requests (
  id, user_id, deletion_epoch, request_type, status
) values (
  'dddddddd-2000-4000-8000-000000000001',
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  0,
  'export',
  'failed'
);
insert into argus_private.job_runs (
  id, user_id, deletion_epoch, job_type, status
) values (
  'dddddddd-3000-4000-8000-000000000001',
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  0,
  'privacy-export',
  'dead_lettered'
);

set local role argus_runtime;
do $$ begin
  perform argus_private.set_request_context(
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    'eeeeeeee-0000-4000-8000-000000000001',
    'aal2'
  );
end $$;
select is(
  (select count(*)::bigint from argus_app.privacy_requests where id = 'dddddddd-2000-4000-8000-000000000001'),
  1::bigint,
  'active privacy staff can read cross-user privacy operations'
);
select is(
  (select count(*)::bigint from argus_private.job_runs where id = 'dddddddd-3000-4000-8000-000000000001'),
  1::bigint,
  'active operations staff can read cross-user job operations'
);
select ok(
  argus_private.request_admin_job_retry(
    'dddddddd-3000-4000-8000-000000000001',
    'u14-job-retry-1'
  ) is not null,
  'operations write permission atomically creates a retry request'
);
select is(
  (select count(*)::bigint from argus_private.outbox_events where dedupe_key = 'u14-job-retry-1'),
  1::bigint,
  'admin retry is represented by a durable outbox event'
);
reset role;

update argus_private.staff_principals
   set status = 'revoked', revoked_at = now(), revocation_epoch = revocation_epoch + 1
 where user_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';

set local role argus_runtime;
do $$ begin
  perform argus_private.set_request_context(
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    'eeeeeeee-0000-4000-8000-000000000001',
    'aal2'
  );
end $$;
select is(
  (select count(*)::bigint from argus_private.job_runs where id = 'dddddddd-3000-4000-8000-000000000001'),
  0::bigint,
  'revoked staff immediately loses cross-user job visibility'
);
select throws_ok(
  $$select argus_private.request_admin_job_retry(
      'dddddddd-3000-4000-8000-000000000001',
      'u14-job-retry-revoked'
    )$$,
  '42501',
  'staff_permission_required',
  'revoked staff cannot request a retry'
);
reset role;

insert into argus_app.editorial_items (id, kind, slug, status)
values ('dddddddd-4000-4000-8000-000000000001', 'ritual', 'u14-ritual', 'published');
insert into argus_app.editorial_revisions (
  id, item_id, revision_number, state, author_staff_id, content_hash, payload
) values (
  'dddddddd-4100-4000-8000-000000000001',
  'dddddddd-4000-4000-8000-000000000001',
  1,
  'published',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'u14-content-hash',
  '{"title":"U14"}'
);
update argus_app.editorial_items
   set current_published_revision_id = 'dddddddd-4100-4000-8000-000000000001'
 where id = 'dddddddd-4000-4000-8000-000000000001';
insert into argus_app.ritual_schedules (
  id, local_date, mode, revision_id, audience, state, effective_at
) values (
  'dddddddd-4200-4000-8000-000000000001',
  '2026-08-28',
  'tarot',
  'dddddddd-4100-4000-8000-000000000001',
  'member',
  'active',
  now()
);
insert into argus_app.daily_ritual_assignments (
  id, user_id, deletion_epoch, local_date, mode, schedule_id, revision_id,
  state
) values (
  'dddddddd-4300-4000-8000-000000000001',
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  0,
  '2026-08-28',
  'tarot',
  'dddddddd-4200-4000-8000-000000000001',
  'dddddddd-4100-4000-8000-000000000001',
  'assigned'
);

set local role argus_runtime;
do $$ begin
  perform argus_private.set_request_context(
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    'dddddddd-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;
select is(
  (with changed as (
    update argus_app.daily_ritual_assignments
       set state = 'revealed', version = version + 1
     where id = 'dddddddd-4300-4000-8000-000000000001' and version = 1
    returning id
  ) select count(*)::bigint from changed),
  1::bigint,
  'matching ritual revision mutates once'
);
select is(
  (with changed as (
    update argus_app.daily_ritual_assignments
       set state = 'completed', version = version + 1
     where id = 'dddddddd-4300-4000-8000-000000000001' and version = 1
    returning id
  ) select count(*)::bigint from changed),
  0::bigint,
  'stale ritual revision cannot overwrite the newer state'
);
reset role;

select * from finish();
rollback;

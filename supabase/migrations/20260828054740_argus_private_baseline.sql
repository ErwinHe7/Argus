begin;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pgmq;
create extension if not exists pg_cron;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'argus_runtime') then
    create role argus_runtime
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'argus_worker') then
    create role argus_worker
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
end
$$;

alter role argus_runtime set statement_timeout = '15s';
alter role argus_runtime set lock_timeout = '3s';
alter role argus_runtime set idle_in_transaction_session_timeout = '15s';
alter role argus_worker set statement_timeout = '45s';
alter role argus_worker set lock_timeout = '3s';
alter role argus_worker set idle_in_transaction_session_timeout = '15s';

create schema argus_app;
create schema argus_brokerage;
create schema argus_private;

revoke create on schema public from public;
revoke all on schema argus_app, argus_brokerage, argus_private from public, anon, authenticated;
grant usage on schema argus_app, argus_brokerage, argus_private to argus_runtime;
grant usage on schema argus_app, argus_brokerage, argus_private to argus_worker;

alter default privileges in schema argus_app revoke all on tables from public, anon, authenticated;
alter default privileges in schema argus_brokerage revoke all on tables from public, anon, authenticated;
alter default privileges in schema argus_private revoke all on tables from public, anon, authenticated;
alter default privileges in schema argus_app revoke execute on functions from public, anon, authenticated;
alter default privileges in schema argus_brokerage revoke execute on functions from public, anon, authenticated;
alter default privileges in schema argus_private revoke execute on functions from public, anon, authenticated;

create table argus_app.members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'active'
    check (status in ('active','suspended','deletion_pending','purging','purged')),
  deletion_epoch bigint not null default 0 check (deletion_epoch >= 0),
  deletion_requested_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, deletion_epoch),
  check ((status in ('deletion_pending','purging','purged')) = (deletion_requested_at is not null))
);

create table argus_app.profiles (
  user_id uuid primary key references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  display_name text not null check (char_length(display_name) between 1 and 80),
  avatar_media_id uuid,
  locale text not null default 'en-US' check (locale ~ '^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$'),
  updated_at timestamptz not null default now()
);

create table argus_app.preferences (
  user_id uuid primary key references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  theme_mode text not null default 'system' check (theme_mode in ('system','light','dark')),
  ritual_mode text not null default 'tarot' check (ritual_mode in ('tarot','astrology')),
  timezone text not null default 'UTC' check (char_length(timezone) between 1 and 64),
  locale text not null default 'en-US' check (locale ~ '^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$'),
  version integer not null default 1 check (version > 0)
);

create table argus_app.astrology_profiles (
  user_id uuid primary key references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  birth_date date not null,
  derived_profile_code text not null check (derived_profile_code in ('lunar_patient','solar_builder','rising_explorer')),
  algorithm_version text not null default 'v1' check (algorithm_version = 'v1'),
  enabled_at timestamptz not null default now()
);

create table argus_app.investor_profiles (
  user_id uuid primary key references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  goal_type text not null check (goal_type in ('calm_fund','long_term_growth','income','exploration')),
  time_horizon text not null check (time_horizon in ('short','medium','long')),
  risk_comfort text not null check (risk_comfort in ('low','moderate','high')),
  version integer not null default 1 check (version > 0)
);

create table argus_app.onboarding_states (
  user_id uuid primary key references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  current_step text not null,
  completed_steps jsonb not null default '[]'::jsonb check (jsonb_typeof(completed_steps) = 'array'),
  completed_at timestamptz,
  version integer not null default 1 check (version > 0)
);

create table argus_app.consent_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  policy_code text not null,
  policy_version text not null,
  decision text not null check (decision in ('accepted','declined','withdrawn')),
  recorded_at timestamptz not null default now(),
  unique (user_id, policy_code, policy_version, decision),
  unique (user_id, id)
);

create table argus_app.notification_preferences (
  user_id uuid primary key references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  daily_ritual boolean not null default true,
  weekly_recap boolean not null default true,
  moon_cycle boolean not null default true,
  quiet_hours jsonb not null default '{}'::jsonb check (jsonb_typeof(quiet_hours) = 'object'),
  version integer not null default 1 check (version > 0)
);

create table argus_app.catalog_assets (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  symbol text not null,
  name text not null,
  asset_type text not null check (asset_type in ('equity','etf','index','cash')),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  exchange text,
  status text not null default 'active' check (status in ('active','inactive')),
  unique (symbol, exchange)
);

create table argus_app.evidence_sources (
  id uuid primary key default gen_random_uuid(),
  canonical_url text not null unique check (canonical_url ~ '^https://'),
  title text not null,
  publisher text not null,
  published_at timestamptz,
  retrieved_at timestamptz not null,
  source_kind text not null,
  status text not null default 'active' check (status in ('active','retired'))
);

create table argus_app.evidence_claims (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references argus_app.evidence_sources(id),
  claim_type text not null,
  summary text not null,
  observed_at timestamptz,
  uncertainty text not null,
  status text not null default 'active' check (status in ('active','superseded','withdrawn'))
);

create table argus_app.media_assets (
  id uuid primary key default gen_random_uuid(),
  storage_bucket text not null check (storage_bucket in ('member-media','media-quarantine')),
  storage_path text not null unique,
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp')),
  byte_size bigint not null check (byte_size > 0 and byte_size <= 10485760),
  checksum text not null,
  quarantine_status text not null default 'pending' check (quarantine_status in ('pending','clear','rejected')),
  status text not null default 'uploading' check (status in ('uploading','active','retired')),
  created_at timestamptz not null default now()
);

create table argus_app.editorial_items (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('ritual','asset_codex','coven','grimoire','circle_template','rowan','briefing_template')),
  slug text not null unique check (slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  current_published_revision_id uuid,
  status text not null default 'draft' check (status in ('draft','published','withdrawn','retired')),
  created_at timestamptz not null default now()
);

create table argus_app.editorial_revisions (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references argus_app.editorial_items(id) on delete cascade,
  revision_number integer not null check (revision_number > 0),
  state text not null check (state in ('draft','submitted','approved','rejected','published','withdrawn')),
  author_staff_id uuid not null,
  content_hash text not null,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default now(),
  unique (item_id, revision_number)
);

alter table argus_app.editorial_items
  add constraint editorial_current_revision_fk
  foreign key (current_published_revision_id)
  references argus_app.editorial_revisions(id)
  deferrable initially deferred;

create table argus_app.editorial_review_requests (
  id uuid primary key default gen_random_uuid(),
  revision_id uuid not null references argus_app.editorial_revisions(id) on delete cascade,
  requested_by uuid not null,
  requested_at timestamptz not null default now(),
  high_trust boolean not null default false,
  status text not null default 'open' check (status in ('open','closed'))
);
create unique index editorial_review_requests_open_unique
  on argus_app.editorial_review_requests(revision_id) where status = 'open';

create table argus_app.editorial_review_decisions (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references argus_app.editorial_review_requests(id) on delete cascade,
  reviewer_id uuid not null,
  decision text not null check (decision in ('approved','changes_requested','rejected')),
  reason text not null,
  decided_at timestamptz not null default now()
);

create table argus_app.publication_events (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references argus_app.editorial_items(id),
  revision_id uuid not null references argus_app.editorial_revisions(id),
  action text not null check (action in ('publish','schedule','withdraw','supersede')),
  effective_at timestamptz not null,
  actor_id uuid not null,
  reason text not null
);

create table argus_app.ritual_scenarios (
  id uuid primary key default gen_random_uuid(),
  editorial_item_id uuid not null unique references argus_app.editorial_items(id),
  scenario_key text not null unique,
  mode text not null check (mode in ('tarot','astrology')),
  cadence text not null
);

create table argus_app.ritual_scenario_revisions (
  revision_id uuid primary key references argus_app.editorial_revisions(id),
  title text not null,
  interpretation text not null,
  guidance text not null,
  market_label text not null,
  observation_at timestamptz not null,
  uncertainty text not null,
  idea_asset_ids uuid[] not null default '{}',
  evidence_claim_ids uuid[] not null default '{}'
);

create table argus_app.ritual_schedules (
  id uuid primary key default gen_random_uuid(),
  local_date date not null,
  mode text not null check (mode in ('tarot','astrology')),
  revision_id uuid not null references argus_app.editorial_revisions(id),
  audience text not null check (audience in ('public','member')),
  state text not null check (state in ('draft','scheduled','active','withdrawn')),
  effective_at timestamptz not null,
  unique (local_date, mode, audience)
);

create table argus_app.rowan_scripts (
  id uuid primary key default gen_random_uuid(),
  editorial_item_id uuid not null unique references argus_app.editorial_items(id),
  script_key text not null unique,
  surface text not null
);

create table argus_app.rowan_script_revisions (
  revision_id uuid primary key references argus_app.editorial_revisions(id),
  body_template text not null,
  allowed_tokens jsonb not null default '[]'::jsonb check (jsonb_typeof(allowed_tokens) = 'array'),
  risk_footer text not null
);

create table argus_app.rowan_context_bindings (
  id uuid primary key default gen_random_uuid(),
  surface text not null,
  context_key text not null,
  script_id uuid not null references argus_app.rowan_scripts(id),
  priority integer not null,
  unique (surface, context_key, priority),
  check (context_key !~* '(brokerage|balance|position|credential|token|order_payload)')
);

create table argus_app.daily_ritual_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  local_date date not null,
  mode text not null check (mode in ('tarot','astrology')),
  schedule_id uuid not null references argus_app.ritual_schedules(id),
  revision_id uuid not null references argus_app.editorial_revisions(id),
  rowan_revision_id uuid references argus_app.rowan_script_revisions(revision_id),
  state text not null check (state in ('assigned','revealed','completed')),
  revealed_at timestamptz,
  completed_at timestamptz,
  unique (user_id, local_date, mode),
  unique (user_id, id)
);

create table argus_app.companies (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug = lower(slug)),
  name text not null,
  asset_id uuid references argus_app.catalog_assets(id),
  website_url text check (website_url is null or website_url ~ '^https://'),
  status text not null default 'active' check (status in ('active','inactive'))
);

create table argus_app.coven_entries (
  id uuid primary key default gen_random_uuid(),
  editorial_item_id uuid not null unique references argus_app.editorial_items(id),
  company_id uuid not null unique references argus_app.companies(id),
  qualification_payload jsonb not null default '[]'::jsonb check (jsonb_typeof(qualification_payload) = 'array')
);

create table argus_app.grimoires (
  id uuid primary key default gen_random_uuid(),
  editorial_item_id uuid not null unique references argus_app.editorial_items(id),
  theme_code text not null,
  asset_ids uuid[] not null default '{}'
);

create table argus_app.community_templates (
  id uuid primary key default gen_random_uuid(),
  editorial_item_id uuid not null unique references argus_app.editorial_items(id),
  creator_label text not null,
  title text not null,
  description text not null,
  asset_ids uuid[] not null default '{}'
);

create table argus_app.circles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  title text not null check (char_length(title) between 1 and 80),
  description text not null default '',
  source_template_id uuid references argus_app.community_templates(id),
  version integer not null default 1 check (version > 0),
  archived_at timestamptz,
  unique (user_id, id)
);

create table argus_app.circle_assets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  circle_id uuid not null,
  asset_id uuid not null references argus_app.catalog_assets(id),
  ordinal integer not null check (ordinal between 1 and 50),
  weight_bps integer check (weight_bps between 0 and 10000),
  note text,
  foreign key (user_id, circle_id) references argus_app.circles(user_id, id) on delete cascade,
  unique (user_id, circle_id, asset_id),
  unique (user_id, circle_id, ordinal)
);

create table argus_app.saved_items (
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  item_kind text not null check (item_kind in ('asset','grimoire','circle_template','coven')),
  item_id uuid not null,
  source_kind text not null default 'direct',
  source_id uuid,
  saved_at timestamptz not null default now(),
  primary key (user_id, item_kind, item_id)
);

create table argus_app.intentions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  title text not null check (char_length(title) between 1 and 120),
  target_amount_minor bigint check (target_amount_minor is null or target_amount_minor >= 0),
  currency text check (currency is null or currency ~ '^[A-Z]{3}$'),
  target_date date,
  status text not null default 'active' check (status in ('active','archived')),
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  unique (user_id, id)
);

create table argus_app.future_mirror_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  intention_id uuid not null,
  input_hash text not null,
  model_version text not null,
  assumptions jsonb not null check (jsonb_typeof(assumptions) = 'object'),
  status text not null check (status in ('queued','running','completed','failed')),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  foreign key (user_id, intention_id) references argus_app.intentions(user_id, id) on delete cascade,
  unique (user_id, id)
);

create table argus_app.future_mirror_points (
  run_id uuid not null,
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  ordinal integer not null check (ordinal > 0),
  projected_date date not null,
  amount_minor bigint not null check (amount_minor >= 0),
  foreign key (user_id, run_id) references argus_app.future_mirror_runs(user_id, id) on delete cascade,
  primary key (run_id, ordinal)
);

create table argus_app.briefings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  briefing_type text not null,
  period_start date not null,
  period_end date not null,
  status text not null check (status in ('queued','building','ready','failed')),
  generated_at timestamptz,
  unique (user_id, briefing_type, period_start, period_end),
  unique (user_id, id),
  check (period_end >= period_start)
);

create table argus_app.briefing_sections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  briefing_id uuid not null,
  section_type text not null,
  ordinal integer not null check (ordinal > 0),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  foreign key (user_id, briefing_id) references argus_app.briefings(user_id, id) on delete cascade,
  unique (briefing_id, ordinal)
);

create table argus_app.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  kind text not null,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, id)
);

create table argus_app.privacy_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  request_type text not null check (request_type in ('export','deletion')),
  status text not null check (status in ('requested','verified','queued','processing','completed','failed','cancelled')),
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  failure_code text,
  unique (user_id, id)
);
create unique index privacy_requests_active_type_unique
  on argus_app.privacy_requests(user_id, request_type)
  where status in ('requested','verified','queued','processing');

create table argus_app.content_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  target_kind text not null,
  target_id uuid not null,
  reason_code text not null,
  details text,
  status text not null default 'open' check (status in ('open','triaged','closed')),
  created_at timestamptz not null default now(),
  unique (user_id, id)
);

create table argus_app.moderation_cases (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null unique references argus_app.content_reports(id),
  status text not null default 'open' check (status in ('open','actioned','dismissed')),
  version integer not null default 1 check (version > 0),
  decision_payload jsonb,
  updated_at timestamptz not null default now()
);

create table argus_brokerage.connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  status text not null default 'pending'
    check (status in ('pending','connected','denied','failed','disconnected','temporarily_unavailable','reauthorization_required')),
  capability_version integer not null default 0 check (capability_version >= 0),
  authorized_at timestamptz,
  disconnected_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id)
);
create unique index one_live_webull_connection_per_user
  on argus_brokerage.connections(user_id)
  where status not in ('denied','failed','disconnected');

create table argus_brokerage.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  connection_id uuid not null,
  display_label text not null,
  base_currency text not null check (base_currency ~ '^[A-Z]{3}$'),
  status text not null default 'available' check (status in ('available','restricted','closed','unavailable')),
  capability_version integer not null check (capability_version >= 0),
  provider_observed_at timestamptz,
  fetched_at timestamptz,
  expires_at timestamptz,
  unique (user_id, id),
  foreign key (user_id, connection_id)
    references argus_brokerage.connections(user_id, id) on delete cascade,
  check (expires_at is null or fetched_at is not null),
  check (provider_observed_at is null or fetched_at is not null)
);

create table argus_brokerage.active_account_selections (
  user_id uuid primary key references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  connection_id uuid not null,
  account_id uuid not null,
  selected_at timestamptz not null default now(),
  foreign key (user_id, connection_id)
    references argus_brokerage.connections(user_id, id) on delete cascade,
  foreign key (user_id, account_id)
    references argus_brokerage.accounts(user_id, id) on delete cascade
);

create table argus_brokerage.projection_generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  connection_id uuid not null,
  account_id uuid not null,
  resource_type text not null check (resource_type in ('account','balance','positions','restrictions','orders')),
  generation bigint not null check (generation > 0),
  normalized_payload jsonb not null check (jsonb_typeof(normalized_payload) in ('object','array')),
  provider_observed_at timestamptz,
  fetched_at timestamptz not null,
  expires_at timestamptz not null,
  availability text not null check (availability in ('available','partial','stale','unavailable')),
  created_at timestamptz not null default now(),
  foreign key (user_id, connection_id)
    references argus_brokerage.connections(user_id, id) on delete cascade,
  foreign key (user_id, account_id)
    references argus_brokerage.accounts(user_id, id) on delete cascade,
  unique (account_id, resource_type, generation),
  unique (user_id, id),
  check (expires_at >= fetched_at),
  check (provider_observed_at is null or provider_observed_at <= fetched_at)
);
create index projection_generations_latest_idx
  on argus_brokerage.projection_generations(account_id, resource_type, generation desc);

create table argus_private.schema_contract_versions (
  version text primary key,
  installed_at timestamptz not null default now()
);

create table argus_private.staff_principals (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active','revoked')),
  permissions text[] not null default '{}',
  display_label text not null,
  revocation_epoch bigint not null default 0 check (revocation_epoch >= 0),
  revoked_at timestamptz,
  last_verified_at timestamptz,
  check ((status = 'revoked') = (revoked_at is not null))
);

alter table argus_app.editorial_revisions
  add constraint editorial_revisions_author_staff_fk
  foreign key (author_staff_id) references argus_private.staff_principals(user_id);
alter table argus_app.editorial_review_requests
  add constraint editorial_review_requests_staff_fk
  foreign key (requested_by) references argus_private.staff_principals(user_id);
alter table argus_app.editorial_review_decisions
  add constraint editorial_review_decisions_staff_fk
  foreign key (reviewer_id) references argus_private.staff_principals(user_id);
alter table argus_app.publication_events
  add constraint publication_events_staff_fk
  foreign key (actor_id) references argus_private.staff_principals(user_id);

create table argus_private.step_up_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  session_id uuid not null,
  deletion_epoch bigint not null,
  action text not null check (action in ('webull_disconnect','argus_delete','staff_sensitive_action')),
  receipt_hash text not null unique,
  aal text not null check (aal in ('aal1','aal2')),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

create table argus_private.member_idempotency_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  operation text not null,
  idempotency_key text not null check (idempotency_key ~ '^[!-~]{16,128}$'),
  request_hash text not null,
  resource_id uuid,
  response_status integer,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  unique (user_id, operation, idempotency_key)
);

create table argus_private.device_installations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  platform text not null check (platform in ('ios','android','web')),
  push_token_ciphertext bytea not null,
  push_token_hash text not null,
  status text not null default 'active' check (status in ('active','revoked')),
  last_seen_at timestamptz,
  unique (user_id, push_token_hash)
);

create table argus_private.oauth_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  session_id uuid not null,
  deletion_epoch bigint not null,
  state_hash text not null unique,
  pkce_verifier_ciphertext bytea,
  return_target text not null check (return_target ~ '^/[A-Za-z0-9/_-]*$'),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

create table argus_private.webull_credentials (
  connection_id uuid primary key references argus_brokerage.connections(id) on delete cascade,
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  token_version bigint not null check (token_version > 0),
  key_version integer not null check (key_version > 0),
  access_ciphertext bytea not null,
  access_nonce bytea not null,
  access_tag bytea not null,
  refresh_ciphertext bytea not null,
  refresh_nonce bytea not null,
  refresh_tag bytea not null,
  wrapped_data_key bytea not null,
  wrapped_key_nonce bytea not null,
  wrapped_key_tag bytea not null,
  associated_data_hash text not null,
  access_expires_at timestamptz not null,
  refresh_expires_at timestamptz not null,
  updated_at timestamptz not null default now(),
  foreign key (user_id, connection_id)
    references argus_brokerage.connections(user_id, id) on delete cascade,
  check (refresh_expires_at > access_expires_at)
);

create table argus_private.webull_account_mappings (
  account_id uuid primary key references argus_brokerage.accounts(id) on delete cascade,
  connection_id uuid not null references argus_brokerage.connections(id) on delete cascade,
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  provider_account_id_ciphertext bytea not null,
  provider_account_id_hash text not null,
  key_version integer not null check (key_version > 0),
  unique (connection_id, provider_account_id_hash),
  foreign key (user_id, account_id)
    references argus_brokerage.accounts(user_id, id) on delete cascade,
  foreign key (user_id, connection_id)
    references argus_brokerage.connections(user_id, id) on delete cascade
);

create table argus_private.refresh_leases (
  connection_id uuid primary key references argus_brokerage.connections(id) on delete cascade,
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  lease_token uuid not null,
  token_version bigint not null,
  leased_until timestamptz not null,
  acquired_at timestamptz not null default now(),
  foreign key (user_id, connection_id)
    references argus_brokerage.connections(user_id, id) on delete cascade
);

create table argus_private.projection_refresh_leases (
  account_id uuid not null references argus_brokerage.accounts(id) on delete cascade,
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  resource_type text not null check (resource_type in ('account','balance','positions','restrictions','orders')),
  lease_token uuid not null,
  leased_until timestamptz not null,
  primary key (account_id, resource_type),
  foreign key (user_id, account_id)
    references argus_brokerage.accounts(user_id, id) on delete cascade
);

create table argus_private.provider_rate_limits (
  scope_key text primary key,
  window_started_at timestamptz not null,
  consumed integer not null default 0 check (consumed >= 0),
  limit_value integer not null check (limit_value > 0),
  blocked_until timestamptz,
  updated_at timestamptz not null default now()
);

create table argus_private.order_previews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  connection_id uuid not null,
  account_id uuid not null,
  capability_version integer not null,
  restriction_generation bigint not null,
  reviewed_payload_hash text not null,
  normalized_payload jsonb not null check (jsonb_typeof(normalized_payload) = 'object'),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (user_id, connection_id)
    references argus_brokerage.connections(user_id, id) on delete cascade,
  foreign key (user_id, account_id)
    references argus_brokerage.accounts(user_id, id) on delete cascade,
  check (expires_at > created_at)
);

create table argus_private.provider_commands (
  id uuid primary key,
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  connection_id uuid not null,
  account_id uuid not null,
  operation text not null check (operation in ('place','modify','cancel')),
  client_order_id text not null check (char_length(client_order_id) between 8 and 80),
  idempotency_key text not null check (idempotency_key ~ '^[!-~]{16,128}$'),
  normalized_payload_hash text not null,
  reviewed_payload_hash text not null,
  capability_version integer not null check (capability_version >= 0),
  state text not null default 'pending'
    check (state in ('pending','dispatching','accepted','ambiguous','reconciling','resolved','failed','manual_review')),
  egress_started_at timestamptz,
  provider_order_ref_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (user_id, connection_id)
    references argus_brokerage.connections(user_id, id) on delete cascade,
  foreign key (user_id, account_id)
    references argus_brokerage.accounts(user_id, id) on delete cascade,
  unique (user_id, idempotency_key),
  unique (connection_id, client_order_id),
  unique (user_id, id)
);
create unique index one_ambiguous_command_per_account
  on argus_private.provider_commands(account_id)
  where state in ('dispatching','ambiguous','reconciling','manual_review');

create table argus_private.provider_command_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  command_id uuid not null,
  attempt_number integer not null check (attempt_number > 0),
  attempt_kind text not null check (attempt_kind in ('egress','detail_lookup','status_refresh')),
  outcome text not null check (outcome in ('started','accepted','not_found','retryable_failure','terminal_failure','ambiguous')),
  http_status integer,
  provider_error_code text,
  correlation_id uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now(),
  foreign key (user_id, command_id)
    references argus_private.provider_commands(user_id, id) on delete cascade,
  unique (command_id, attempt_number)
);

create table argus_private.reconciliation_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  command_id uuid not null,
  status text not null default 'pending' check (status in ('pending','running','resolved','manual_review','exhausted')),
  next_attempt_at timestamptz not null default now(),
  attempts integer not null default 0 check (attempts >= 0),
  last_error_code text,
  updated_at timestamptz not null default now(),
  foreign key (user_id, command_id)
    references argus_private.provider_commands(user_id, id) on delete cascade,
  unique (command_id)
);

create table argus_private.outbox_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint,
  topic text not null check (topic in ('argus_jobs','brokerage_refresh','brokerage_reconcile')),
  event_type text not null,
  aggregate_id uuid not null,
  dedupe_key text not null,
  available_at timestamptz not null default now(),
  published_at timestamptz,
  publish_attempts integer not null default 0 check (publish_attempts >= 0),
  last_error_code text,
  created_at timestamptz not null default now(),
  unique (topic, dedupe_key),
  check ((user_id is null) = (deletion_epoch is null))
);
create index outbox_events_due_idx
  on argus_private.outbox_events(available_at, id) where published_at is null;

create table argus_private.outbox_dispatch_failures (
  id uuid primary key default gen_random_uuid(),
  outbox_event_id uuid not null references argus_private.outbox_events(id) on delete cascade,
  attempt_number integer not null check (attempt_number > 0),
  error_code text not null,
  occurred_at timestamptz not null default now(),
  unique (outbox_event_id, attempt_number)
);

create table argus_private.job_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint,
  job_type text not null,
  source_event_id uuid,
  status text not null default 'queued'
    check (status in ('queued','leased','running','retry','succeeded','dead_lettered','cancelled')),
  attempts integer not null default 0 check (attempts >= 0),
  lease_token uuid,
  leased_until timestamptz,
  next_attempt_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((user_id is null) = (deletion_epoch is null))
);
create index job_runs_retry_idx
  on argus_private.job_runs(next_attempt_at, id) where status = 'retry';

create table argus_private.consumer_receipts (
  consumer_name text not null,
  message_id bigint not null,
  effect_key text not null,
  completed_at timestamptz not null default now(),
  primary key (consumer_name, message_id),
  unique (consumer_name, effect_key)
);

create table argus_private.aggregate_consumer_watermarks (
  consumer_name text not null,
  aggregate_kind text not null,
  aggregate_id uuid not null,
  aggregate_version bigint not null check (aggregate_version >= 0),
  updated_at timestamptz not null default now(),
  primary key (consumer_name, aggregate_kind, aggregate_id)
);

create table argus_private.media_upload_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  bucket_id text not null check (bucket_id in ('member-media','media-quarantine')),
  object_path text not null,
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp')),
  max_bytes bigint not null check (max_bytes between 1 and 10485760),
  status text not null default 'pending' check (status in ('pending','uploaded','scanning','accepted','rejected','expired')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (bucket_id, object_path)
);

create table argus_private.privacy_export_artifacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  request_id uuid not null unique references argus_app.privacy_requests(id) on delete cascade,
  bucket_id text not null default 'privacy-exports' check (bucket_id = 'privacy-exports'),
  object_path text not null unique,
  checksum text not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table argus_private.admin_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_kind text not null,
  target_id uuid,
  outcome text not null check (outcome in ('allowed','denied','failed')),
  reason_code text,
  correlation_id uuid not null default gen_random_uuid(),
  occurred_at timestamptz not null default now(),
  details jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object')
);

create table argus_private.security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  outcome text not null,
  reason_code text,
  correlation_id uuid not null default gen_random_uuid(),
  occurred_at timestamptz not null default now(),
  details jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object')
);

create table argus_private.deletion_tombstones (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  deletion_epoch bigint not null check (deletion_epoch > 0),
  status text not null default 'pending' check (status in ('pending','purging','purged','failed')),
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (user_id, deletion_epoch)
);

create table argus_private.deletion_journal_confirmations (
  id uuid primary key default gen_random_uuid(),
  tombstone_id uuid not null references argus_private.deletion_tombstones(id) on delete cascade,
  phase text not null,
  checksum text not null,
  confirmed_at timestamptz not null default now(),
  unique (tombstone_id, phase)
);

create table argus_private.deletion_object_receipts (
  id uuid primary key default gen_random_uuid(),
  tombstone_id uuid not null references argus_private.deletion_tombstones(id) on delete cascade,
  bucket_id text not null,
  object_path_hash text not null,
  deleted_at timestamptz not null default now(),
  unique (tombstone_id, bucket_id, object_path_hash)
);

create table argus_private.deletion_restore_checkpoints (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  deletion_epoch bigint not null,
  source text not null,
  confirmed_at timestamptz not null default now(),
  unique (user_id, deletion_epoch, source)
);

create table argus_private.purge_receipts (
  id uuid primary key default gen_random_uuid(),
  tombstone_id uuid not null unique references argus_private.deletion_tombstones(id) on delete cascade,
  purged_tables integer not null check (purged_tables >= 0),
  purged_objects integer not null check (purged_objects >= 0),
  completed_at timestamptz not null default now()
);

create table argus_private.kill_switches (
  name text primary key,
  enabled boolean not null default false,
  reason text,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table argus_private.cron_leases (
  lease_name text primary key,
  lease_token uuid,
  leased_until timestamptz,
  updated_at timestamptz not null default now()
);

insert into argus_private.schema_contract_versions(version)
values ('webull-supabase-v1');

insert into argus_private.kill_switches(name, enabled, reason) values
  ('provider_egress', true, 'disabled until Webull U5 contract gate passes'),
  ('order_mutations', true, 'disabled until Webull sandbox order gate passes'),
  ('background_workers', true, 'disabled until hosted acceptance passes');

create or replace function argus_private.request_user_id()
returns uuid
language sql
stable
security invoker
set search_path = pg_catalog
as $$
  select coalesce(
    nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub', ''),
    nullif(current_setting('request.jwt.claim.sub', true), '')
  )::uuid
$$;

revoke all on function argus_private.request_user_id()
  from public, anon, authenticated;
grant execute on function argus_private.request_user_id() to argus_runtime;

create or replace function argus_private.has_staff_permission(p_permission text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, argus_private
as $$
  select exists (
    select 1
      from argus_private.staff_principals staff
     where staff.user_id = argus_private.request_user_id()
       and staff.status = 'active'
       and staff.revoked_at is null
       and (p_permission = any(staff.permissions) or '*' = any(staff.permissions))
  )
$$;

revoke all on function argus_private.has_staff_permission(text) from public, anon, authenticated;
grant execute on function argus_private.has_staff_permission(text) to argus_runtime;

create or replace function argus_private.set_request_context(
  p_user_id uuid,
  p_session_id uuid,
  p_aal text
)
returns void
language plpgsql
security invoker
set search_path = pg_catalog
as $$
begin
  if current_user <> 'argus_runtime' then
    raise exception 'runtime_role_required' using errcode = '42501';
  end if;
  if p_aal not in ('aal1','aal2') then
    raise exception 'invalid_aal' using errcode = '22023';
  end if;
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', p_user_id::text,
      'session_id', p_session_id::text,
      'aal', p_aal,
      'role', 'authenticated'
    )::text,
    true
  );
end
$$;

revoke all on function argus_private.set_request_context(uuid,uuid,text) from public, anon, authenticated;
grant execute on function argus_private.set_request_context(uuid,uuid,text) to argus_runtime;

create or replace function argus_private.enforce_live_member_epoch()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, argus_app
as $$
declare
  member_epoch bigint;
  member_status text;
begin
  select deletion_epoch, status
    into member_epoch, member_status
    from argus_app.members
   where user_id = new.user_id;

  if member_epoch is null
     or member_status <> 'active'
     or new.deletion_epoch <> member_epoch then
    raise exception 'member_deletion_epoch_mismatch';
  end if;
  return new;
end
$$;

create or replace function argus_private.reject_immutable_change()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $$
begin
  raise exception 'immutable_record';
end
$$;

revoke all on function argus_private.enforce_live_member_epoch(),
  argus_private.reject_immutable_change() from public, anon, authenticated;

create or replace function argus_private.create_provider_command(
  p_id uuid,
  p_user_id uuid,
  p_deletion_epoch bigint,
  p_connection_id uuid,
  p_account_id uuid,
  p_operation text,
  p_client_order_id text,
  p_idempotency_key text,
  p_normalized_payload_hash text,
  p_reviewed_payload_hash text,
  p_capability_version integer
)
returns uuid
language plpgsql
security invoker
set search_path = pg_catalog, argus_private
as $$
declare
  existing argus_private.provider_commands%rowtype;
begin
  if argus_private.request_user_id() is distinct from p_user_id then
    raise exception 'owner_mismatch' using errcode = '42501';
  end if;

  insert into argus_private.provider_commands (
    id, user_id, deletion_epoch, connection_id, account_id, operation,
    client_order_id, idempotency_key, normalized_payload_hash,
    reviewed_payload_hash, capability_version
  ) values (
    p_id, p_user_id, p_deletion_epoch, p_connection_id, p_account_id, p_operation,
    p_client_order_id, p_idempotency_key, p_normalized_payload_hash,
    p_reviewed_payload_hash, p_capability_version
  )
  on conflict (user_id, idempotency_key) do nothing;

  select * into existing
    from argus_private.provider_commands command
   where command.user_id = p_user_id
     and command.idempotency_key = p_idempotency_key;

  if existing.id is null
     or existing.connection_id <> p_connection_id
     or existing.account_id <> p_account_id
     or existing.operation <> p_operation
     or existing.client_order_id <> p_client_order_id
     or existing.normalized_payload_hash <> p_normalized_payload_hash
     or existing.reviewed_payload_hash <> p_reviewed_payload_hash
     or existing.capability_version <> p_capability_version then
    raise exception 'idempotency_conflict';
  end if;

  return existing.id;
end
$$;

revoke all on function argus_private.create_provider_command(
  uuid,uuid,bigint,uuid,uuid,text,text,text,text,text,integer
) from public, anon, authenticated;
grant execute on function argus_private.create_provider_command(
  uuid,uuid,bigint,uuid,uuid,text,text,text,text,text,integer
) to argus_runtime;

do $$
declare
  schema_name text;
  table_name text;
begin
  for schema_name, table_name in
    select n.nspname, c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname in ('argus_app','argus_brokerage','argus_private')
       and c.relkind in ('r','p')
  loop
    execute format('alter table %I.%I enable row level security', schema_name, table_name);
    execute format('alter table %I.%I force row level security', schema_name, table_name);
  end loop;
end
$$;

create policy runtime_member_self on argus_app.members
  for all to argus_runtime
  using ((select argus_private.request_user_id()) = user_id)
  with check ((select argus_private.request_user_id()) = user_id);

do $$
declare
  schema_name text;
  table_name text;
begin
  for schema_name, table_name in
    select * from (values
      ('argus_app','profiles'),
      ('argus_app','preferences'),
      ('argus_app','astrology_profiles'),
      ('argus_app','investor_profiles'),
      ('argus_app','onboarding_states'),
      ('argus_app','consent_records'),
      ('argus_app','notification_preferences'),
      ('argus_app','daily_ritual_assignments'),
      ('argus_app','circles'),
      ('argus_app','circle_assets'),
      ('argus_app','saved_items'),
      ('argus_app','intentions'),
      ('argus_app','future_mirror_runs'),
      ('argus_app','future_mirror_points'),
      ('argus_app','briefings'),
      ('argus_app','briefing_sections'),
      ('argus_app','notifications'),
      ('argus_app','privacy_requests'),
      ('argus_app','content_reports'),
      ('argus_brokerage','connections'),
      ('argus_brokerage','accounts'),
      ('argus_brokerage','active_account_selections'),
      ('argus_brokerage','projection_generations'),
      ('argus_private','step_up_receipts'),
      ('argus_private','member_idempotency_records'),
      ('argus_private','device_installations'),
      ('argus_private','oauth_states'),
      ('argus_private','webull_credentials'),
      ('argus_private','webull_account_mappings'),
      ('argus_private','refresh_leases'),
      ('argus_private','projection_refresh_leases'),
      ('argus_private','order_previews'),
      ('argus_private','provider_commands'),
      ('argus_private','provider_command_attempts'),
      ('argus_private','reconciliation_records'),
      ('argus_private','media_upload_intents'),
      ('argus_private','privacy_export_artifacts')
    ) owner_tables(schema_name, table_name)
  loop
    execute format(
      'create policy runtime_owner on %I.%I for all to argus_runtime using ((select argus_private.request_user_id()) = user_id) with check ((select argus_private.request_user_id()) = user_id and exists (select 1 from argus_app.members member where member.user_id = %I.user_id and member.status = ''active'' and member.deletion_epoch = %I.deletion_epoch))',
      schema_name, table_name, table_name, table_name
    );
  end loop;
end
$$;

create policy runtime_published_read on argus_app.catalog_assets
  for select to argus_runtime
  using (status = 'active' or argus_private.has_staff_permission('editorial:read'));
create policy runtime_staff_write on argus_app.catalog_assets
  for all to argus_runtime
  using (argus_private.has_staff_permission('editorial:write'))
  with check (argus_private.has_staff_permission('editorial:write'));

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'evidence_sources','evidence_claims','media_assets','editorial_items',
    'editorial_revisions','editorial_review_requests','editorial_review_decisions',
    'publication_events','ritual_scenarios','ritual_scenario_revisions','ritual_schedules',
    'rowan_scripts','rowan_script_revisions','rowan_context_bindings','companies',
    'coven_entries','grimoires','community_templates','moderation_cases'
  ]
  loop
    execute format(
      'create policy runtime_editorial_read on argus_app.%I for select to argus_runtime using (argus_private.has_staff_permission(''editorial:read'') or argus_private.has_staff_permission(''editorial:write''))',
      table_name
    );
    execute format(
      'create policy runtime_editorial_write on argus_app.%I for all to argus_runtime using (argus_private.has_staff_permission(''editorial:write'')) with check (argus_private.has_staff_permission(''editorial:write''))',
      table_name
    );
  end loop;
end
$$;

create policy runtime_published_editorial on argus_app.editorial_items
  for select to argus_runtime using (status = 'published');
create policy runtime_published_revisions on argus_app.editorial_revisions
  for select to argus_runtime using (state = 'published');
create policy runtime_active_ritual_schedules on argus_app.ritual_schedules
  for select to argus_runtime using (state = 'active');

create policy runtime_staff_self on argus_private.staff_principals
  for select to argus_runtime
  using ((select argus_private.request_user_id()) = user_id);

create policy runtime_contract_read on argus_private.schema_contract_versions
  for select to argus_runtime using (true);
create policy worker_contract_read on argus_private.schema_contract_versions
  for select to argus_worker using (true);

create policy runtime_rate_limit on argus_private.provider_rate_limits
  for all to argus_runtime using (true) with check (true);

create policy runtime_outbox_owner on argus_private.outbox_events
  for all to argus_runtime
  using (user_id is not null and (select argus_private.request_user_id()) = user_id)
  with check (
    user_id is not null
    and (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = outbox_events.user_id
         and member.status = 'active'
         and member.deletion_epoch = outbox_events.deletion_epoch
    )
  );

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'outbox_events','outbox_dispatch_failures','job_runs','consumer_receipts',
    'aggregate_consumer_watermarks','deletion_tombstones','deletion_journal_confirmations',
    'deletion_object_receipts','deletion_restore_checkpoints','purge_receipts',
    'kill_switches','cron_leases'
  ]
  loop
    execute format(
      'create policy worker_internal on argus_private.%I for all to argus_worker using (true) with check (true)',
      table_name
    );
  end loop;
end
$$;

create policy runtime_deletion_owner on argus_private.deletion_tombstones
  for select to argus_runtime using ((select argus_private.request_user_id()) = user_id);
create policy runtime_deletion_create on argus_private.deletion_tombstones
  for insert to argus_runtime with check ((select argus_private.request_user_id()) = user_id);

create policy runtime_kill_switch_read on argus_private.kill_switches
  for select to argus_runtime using (true);

create policy runtime_admin_audit_read on argus_private.admin_audit_events
  for select to argus_runtime
  using (argus_private.has_staff_permission('audit:read'));
create policy runtime_admin_audit_insert on argus_private.admin_audit_events
  for insert to argus_runtime
  with check (actor_user_id is null or actor_user_id = (select argus_private.request_user_id()));
create policy worker_admin_audit_insert on argus_private.admin_audit_events
  for insert to argus_worker with check (true);

create policy runtime_security_event_read on argus_private.security_events
  for select to argus_runtime
  using (user_id = (select argus_private.request_user_id()) or argus_private.has_staff_permission('security:read'));
create policy runtime_security_event_insert on argus_private.security_events
  for insert to argus_runtime
  with check (user_id is null or user_id = (select argus_private.request_user_id()));
create policy worker_security_event_insert on argus_private.security_events
  for insert to argus_worker with check (true);

do $$
declare
  schema_name text;
  table_name text;
begin
  for schema_name, table_name in
    select * from (values
      ('argus_app','profiles'),('argus_app','preferences'),
      ('argus_app','astrology_profiles'),('argus_app','investor_profiles'),
      ('argus_app','onboarding_states'),('argus_app','consent_records'),
      ('argus_app','notification_preferences'),('argus_app','daily_ritual_assignments'),
      ('argus_app','circles'),('argus_app','circle_assets'),('argus_app','saved_items'),
      ('argus_app','intentions'),('argus_app','future_mirror_runs'),
      ('argus_app','future_mirror_points'),('argus_app','briefings'),
      ('argus_app','briefing_sections'),('argus_app','notifications'),
      ('argus_app','privacy_requests'),('argus_app','content_reports'),
      ('argus_brokerage','connections'),('argus_brokerage','accounts'),
      ('argus_brokerage','active_account_selections'),
      ('argus_brokerage','projection_generations'),
      ('argus_private','step_up_receipts'),('argus_private','member_idempotency_records'),
      ('argus_private','device_installations'),('argus_private','oauth_states'),
      ('argus_private','webull_credentials'),('argus_private','webull_account_mappings'),
      ('argus_private','refresh_leases'),('argus_private','projection_refresh_leases'),
      ('argus_private','order_previews'),('argus_private','provider_commands'),
      ('argus_private','provider_command_attempts'),('argus_private','reconciliation_records'),
      ('argus_private','media_upload_intents'),('argus_private','privacy_export_artifacts')
    ) fenced_tables(schema_name, table_name)
  loop
    execute format(
      'create trigger enforce_live_member_epoch before insert or update on %I.%I for each row execute function argus_private.enforce_live_member_epoch()',
      schema_name, table_name
    );
  end loop;
end
$$;

create trigger projection_generations_immutable
  before update or delete on argus_brokerage.projection_generations
  for each row execute function argus_private.reject_immutable_change();
create trigger provider_command_attempts_immutable
  before update or delete on argus_private.provider_command_attempts
  for each row execute function argus_private.reject_immutable_change();
create trigger admin_audit_events_immutable
  before update or delete on argus_private.admin_audit_events
  for each row execute function argus_private.reject_immutable_change();
create trigger security_events_immutable
  before update or delete on argus_private.security_events
  for each row execute function argus_private.reject_immutable_change();

grant select, insert, update, delete on all tables in schema argus_app to argus_runtime;
grant select, insert, update, delete on all tables in schema argus_brokerage to argus_runtime;
revoke update, delete on argus_brokerage.projection_generations from argus_runtime;
grant select on argus_private.schema_contract_versions, argus_private.staff_principals,
  argus_private.kill_switches to argus_runtime;
grant select, insert, update, delete on
  argus_private.step_up_receipts,
  argus_private.member_idempotency_records,
  argus_private.device_installations,
  argus_private.oauth_states,
  argus_private.webull_credentials,
  argus_private.webull_account_mappings,
  argus_private.refresh_leases,
  argus_private.projection_refresh_leases,
  argus_private.provider_rate_limits,
  argus_private.order_previews,
  argus_private.provider_commands,
  argus_private.reconciliation_records,
  argus_private.outbox_events,
  argus_private.media_upload_intents,
  argus_private.privacy_export_artifacts,
  argus_private.deletion_tombstones
to argus_runtime;
grant select, insert on argus_private.provider_command_attempts,
  argus_private.admin_audit_events,
  argus_private.security_events to argus_runtime;

grant select on argus_private.schema_contract_versions to argus_worker;
grant select, insert, update, delete on
  argus_private.outbox_events,
  argus_private.outbox_dispatch_failures,
  argus_private.job_runs,
  argus_private.consumer_receipts,
  argus_private.aggregate_consumer_watermarks,
  argus_private.deletion_tombstones,
  argus_private.deletion_journal_confirmations,
  argus_private.deletion_object_receipts,
  argus_private.deletion_restore_checkpoints,
  argus_private.purge_receipts,
  argus_private.kill_switches,
  argus_private.cron_leases
to argus_worker;
grant insert on argus_private.admin_audit_events, argus_private.security_events to argus_worker;

revoke all on all tables in schema argus_app, argus_brokerage, argus_private
  from public, anon, authenticated;
revoke all on all functions in schema argus_app, argus_brokerage, argus_private
  from public, anon, authenticated;
grant execute on function argus_private.request_user_id(),
  argus_private.has_staff_permission(text),
  argus_private.set_request_context(uuid,uuid,text),
  argus_private.create_provider_command(uuid,uuid,bigint,uuid,uuid,text,text,text,text,text,integer)
to argus_runtime;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('member-media','member-media',false,10485760,array['image/jpeg','image/png','image/webp']),
  ('media-quarantine','media-quarantine',false,10485760,array['image/jpeg','image/png','image/webp']),
  ('privacy-exports','privacy-exports',false,52428800,array['application/zip','application/json'])
on conflict (id) do update set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists argus_member_media_select on storage.objects;
drop policy if exists argus_member_media_insert on storage.objects;
drop policy if exists argus_member_media_update on storage.objects;
drop policy if exists argus_member_media_delete on storage.objects;
drop policy if exists argus_privacy_exports_select on storage.objects;

create policy argus_member_media_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'member-media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy argus_member_media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'member-media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and owner_id = (select auth.uid())::text
  );
create policy argus_member_media_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'member-media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and owner_id = (select auth.uid())::text
  )
  with check (
    bucket_id = 'member-media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and owner_id = (select auth.uid())::text
  );
create policy argus_member_media_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'member-media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and owner_id = (select auth.uid())::text
  );
create policy argus_privacy_exports_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'privacy-exports'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

grant select, insert, update, delete on storage.objects to authenticated;

drop schema if exists pgmq_public cascade;
select pgmq.create('argus_jobs');
select pgmq.create('brokerage_refresh');
select pgmq.create('brokerage_reconcile');

revoke all on schema pgmq from public, anon, authenticated;
revoke all on all tables in schema pgmq from public, anon, authenticated;
revoke all on all functions in schema pgmq from public, anon, authenticated;
grant usage on schema pgmq to argus_worker;
grant select, insert, update, delete on all tables in schema pgmq to argus_worker;
grant execute on all functions in schema pgmq to argus_worker;

create or replace function argus_private.relay_outbox(p_batch_size integer default 100)
returns integer
language plpgsql
security invoker
set search_path = pg_catalog, argus_private, pgmq
as $$
declare
  event_record argus_private.outbox_events%rowtype;
  sent integer := 0;
begin
  if p_batch_size < 1 or p_batch_size > 500 then
    raise exception 'invalid_batch_size';
  end if;

  if exists (
    select 1 from argus_private.kill_switches
     where name = 'background_workers' and enabled
  ) then
    return 0;
  end if;

  for event_record in
    select *
      from argus_private.outbox_events
     where published_at is null
       and available_at <= now()
     order by available_at, id
     for update skip locked
     limit p_batch_size
  loop
    perform pgmq.send(
      event_record.topic,
      jsonb_build_object(
        'version', 1,
        'event_id', event_record.id,
        'event_type', event_record.event_type
      )
    );
    update argus_private.outbox_events
       set published_at = now(), publish_attempts = publish_attempts + 1
     where id = event_record.id;
    sent := sent + 1;
  end loop;
  return sent;
end
$$;

create or replace function argus_private.recover_expired_work(p_batch_size integer default 100)
returns integer
language plpgsql
security invoker
set search_path = pg_catalog, argus_private
as $$
declare
  recovered integer;
begin
  if p_batch_size < 1 or p_batch_size > 500 then
    raise exception 'invalid_batch_size';
  end if;
  with due as (
    select id from argus_private.job_runs
     where status in ('leased','running') and leased_until < now()
     order by leased_until, id
     for update skip locked
     limit p_batch_size
  )
  update argus_private.job_runs job
     set status = 'retry',
         lease_token = null,
         leased_until = null,
         next_attempt_at = now(),
         updated_at = now(),
         last_error_code = 'lease_expired'
    from due
   where job.id = due.id;
  get diagnostics recovered = row_count;
  return recovered;
end
$$;

revoke all on function argus_private.relay_outbox(integer),
  argus_private.recover_expired_work(integer) from public, anon, authenticated, argus_runtime, argus_worker;

revoke all on schema cron from public, anon, authenticated;
revoke all on all tables in schema cron from public, anon, authenticated;
revoke all on all functions in schema cron from public, anon, authenticated;

select cron.schedule(
  'argus-outbox-relay',
  '* * * * *',
  'select argus_private.relay_outbox(100);'
);
select cron.schedule(
  'argus-recovery-sweep',
  '*/5 * * * *',
  'select argus_private.recover_expired_work(100);'
);

comment on schema argus_app is
  'Non-exposed Argus-owned member, editorial, ritual, community, and scenario state.';
comment on schema argus_brokerage is
  'Non-exposed normalized Webull-derived projection state; Webull remains authoritative.';
comment on schema argus_private is
  'Non-exposed provider custody, commands, deletion fences, jobs, and operational state.';
comment on table argus_brokerage.projection_generations is
  'Immutable per-resource generations; fetched_at never substitutes for unavailable provider_observed_at.';
comment on table argus_private.provider_commands is
  'Durable command intent persisted before provider egress; reconciliation never resubmits placement blindly.';

commit;

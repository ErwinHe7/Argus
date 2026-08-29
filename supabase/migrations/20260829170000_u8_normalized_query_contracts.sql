-- U8 normalizes every value used by member list/search predicates and gives
-- each cursor tuple one matching index. Compatibility JSON remains available
-- to retained readers through U10, but no U8 predicate or rank reads it.

begin;

create extension if not exists pg_trgm with schema extensions;

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_roles where rolname='argus_public_preview'
  ) then
    create role argus_public_preview
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  elsif exists (
    select 1 from pg_catalog.pg_roles
     where rolname='argus_public_preview'
       and (rolcanlogin or rolinherit or rolsuper or rolcreatedb
         or rolcreaterole or rolreplication or rolbypassrls)
  ) then
    raise exception 'argus_public_preview_role_drift' using errcode='42501';
  end if;
end
$$;
grant usage on schema argus_app,argus_private to argus_public_preview;
grant argus_public_preview to argus_edge with set true;

-- The U4 quarantine is FORCE RLS and owned by the NOLOGIN application owner.
-- Temporarily admit only this migration session and only U8 cohorts; the
-- policy and grants are removed after the parity assertions below.
do $membership$
begin
  execute pg_catalog.format(
    'grant argus_app_owner to %I with set true',current_user
  );
end
$membership$;
set local role argus_app_owner;
do $$
begin
  execute pg_catalog.format(
    'create policy u8_migration_quarantine_select on argus_app.legacy_normalization_quarantine for select to %I using (cohort like ''u8-%%'')',
    'postgres'
  );
  execute pg_catalog.format(
    'create policy u8_migration_quarantine_insert on argus_app.legacy_normalization_quarantine for insert to %I with check (cohort like ''u8-%%'')',
    'postgres'
  );
  execute pg_catalog.format(
    'create policy u8_migration_quarantine_update on argus_app.legacy_normalization_quarantine for update to %I using (cohort like ''u8-%%'') with check (cohort like ''u8-%%'')',
    'postgres'
  );
  execute pg_catalog.format(
    'grant select,insert,update on table argus_app.legacy_normalization_quarantine to %I',
    'postgres'
  );
end
$$;
set local role postgres;

alter table argus_app.briefings
  add column generation integer,
  add column source_sequence bigint;

update argus_app.briefings
   set generation=1,source_sequence=1
 where generation is null or source_sequence is null;

alter table argus_app.briefings
  alter column generation set default 1,
  alter column generation set not null,
  alter column source_sequence set default 1,
  alter column source_sequence set not null,
  add constraint briefings_u8_generation_positive check (generation>0),
  add constraint briefings_u8_source_sequence_positive check (source_sequence>0);

alter table argus_app.briefing_sections
  add column source_sequence bigint,
  add column schema_version integer,
  add column disclosure text;

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,
  source_fingerprint,source_cardinality
)
select 'argus_app.briefing_sections',section.id::text,
       'u8-typed-section-metadata',
       case
         when section.payload ? 'source_sequence'
          and (jsonb_typeof(section.payload->'source_sequence')<>'number'
            or section.payload->>'source_sequence' !~ '^[1-9][0-9]{0,17}$')
           then 'invalid_source_sequence'
         when section.payload ? 'schema_version'
          and (jsonb_typeof(section.payload->'schema_version')<>'number'
            or section.payload->>'schema_version' !~ '^[1-9][0-9]{0,8}$')
           then 'invalid_schema_version'
         else 'invalid_disclosure'
       end,
       pg_catalog.encode(extensions.digest(section.payload::text,'sha256'),'hex'),1
  from argus_app.briefing_sections section
 where (section.payload ? 'source_sequence' and (
          jsonb_typeof(section.payload->'source_sequence')<>'number'
          or section.payload->>'source_sequence' !~ '^[1-9][0-9]{0,17}$'))
    or (section.payload ? 'schema_version' and (
          jsonb_typeof(section.payload->'schema_version')<>'number'
          or section.payload->>'schema_version' !~ '^[1-9][0-9]{0,8}$'))
    or (section.payload ? 'disclosure' and (
          jsonb_typeof(section.payload->'disclosure')<>'string'
          or pg_catalog.char_length(section.payload->>'disclosure') not between 1 and 2000))
on conflict (source_relation,source_identity,cohort,reason_code) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality;

update argus_app.briefing_sections section
   set source_sequence=case
         when jsonb_typeof(section.payload->'source_sequence')='number'
          and section.payload->>'source_sequence' ~ '^[1-9][0-9]{0,17}$'
           then (section.payload->>'source_sequence')::bigint
         else briefing.source_sequence
       end,
       schema_version=case
         when jsonb_typeof(section.payload->'schema_version')='number'
          and section.payload->>'schema_version' ~ '^[1-9][0-9]{0,8}$'
           then (section.payload->>'schema_version')::integer
         else 1
       end,
       disclosure=case
         when jsonb_typeof(section.payload->'disclosure')='string'
          and pg_catalog.char_length(section.payload->>'disclosure') between 1 and 2000
           then section.payload->>'disclosure'
         when jsonb_typeof(section.payload->'summary')='string'
          and pg_catalog.char_length(section.payload->>'summary') between 1 and 2000
           then section.payload->>'summary'
         else 'Reviewed Argus briefing section.'
       end
  from argus_app.briefings briefing
 where briefing.id=section.briefing_id;

alter table argus_app.briefing_sections
  alter column source_sequence set default 1,
  alter column source_sequence set not null,
  alter column schema_version set default 1,
  alter column schema_version set not null,
  alter column disclosure set default 'Reviewed Argus briefing section.',
  alter column disclosure set not null,
  add constraint briefing_sections_u8_source_sequence_positive check (source_sequence>0),
  add constraint briefing_sections_u8_schema_version_positive check (schema_version>0),
  add constraint briefing_sections_u8_disclosure_bounded
    check (pg_catalog.char_length(disclosure) between 1 and 2000);

comment on column argus_app.briefings.generation is
  'Authoritative content generation. Member presentation must not synthesize this value.';
comment on column argus_app.briefings.source_sequence is
  'Authoritative upstream source sequence shared by the briefing and its sections.';
comment on column argus_app.briefing_sections.payload is
  'Compatibility envelope retained until the compatibility-removal contract proves zero readers; operational reads use typed columns only.';

create table argus_app.editorial_creators (
  id uuid primary key,
  normalized_key text not null unique
    check (normalized_key=pg_catalog.lower(pg_catalog.btrim(normalized_key))
      and pg_catalog.char_length(normalized_key) between 1 and 120),
  slug text not null unique
    check (slug=pg_catalog.lower(slug)
      and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  display_name text not null
    check (pg_catalog.char_length(display_name) between 1 and 120),
  bio text not null default 'Fictional Argus editorial creator.'
    check (pg_catalog.char_length(bio) between 1 and 1000),
  is_fictional boolean not null default true check (is_fictional),
  unique (id,normalized_key)
);

alter table argus_app.community_templates
  add column creator_id uuid,
  add column creator_key text generated always as
    (pg_catalog.lower(pg_catalog.btrim(creator_label))) stored,
  add column creator_normalization_state text not null default 'ready'
    check (creator_normalization_state in ('ready','quarantined'));

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,
  source_fingerprint,source_cardinality
)
select 'argus_app.community_templates',template.id::text,
       'u8-editorial-creator','invalid_creator_label',
       pg_catalog.encode(extensions.digest(to_jsonb(template.creator_label)::text,'sha256'),'hex'),1
  from argus_app.community_templates template
 where pg_catalog.char_length(pg_catalog.btrim(template.creator_label)) not between 1 and 120
on conflict (source_relation,source_identity,cohort,reason_code) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality;

insert into argus_app.editorial_creators(
  id,normalized_key,slug,display_name
)
select (
         pg_catalog.substr(key_hash,1,8)||'-'||
         pg_catalog.substr(key_hash,9,4)||'-4'||
         pg_catalog.substr(key_hash,14,3)||'-8'||
         pg_catalog.substr(key_hash,18,3)||'-'||
         pg_catalog.substr(key_hash,21,12)
       )::uuid,
       normalized_key,
       pg_catalog.left(
         coalesce(nullif(pg_catalog.regexp_replace(normalized_key,'[^a-z0-9]+','-','g'),''),'creator'),
         50
       )||'-'||pg_catalog.substr(key_hash,1,8),
       display_name
  from (
    select normalized_key,
           min(pg_catalog.btrim(template.creator_label)) as display_name,
           md5('argus-editorial-creator:'||normalized_key) as key_hash
      from argus_app.community_templates template
      cross join lateral (
        select pg_catalog.lower(pg_catalog.btrim(template.creator_label)) as normalized_key
      ) normalized
     where pg_catalog.char_length(pg_catalog.btrim(template.creator_label)) between 1 and 120
     group by normalized_key
  ) source;

update argus_app.community_templates template
   set creator_id=creator.id,
       creator_normalization_state='ready'
  from argus_app.editorial_creators creator
 where creator.normalized_key=template.creator_key;

update argus_app.community_templates
   set creator_normalization_state='quarantined'
 where creator_id is null;

alter table argus_app.community_templates
  add constraint community_templates_u8_creator_state_check check (
    (creator_normalization_state='ready' and creator_id is not null)
    or (creator_normalization_state='quarantined' and creator_id is null)
  ),
  add constraint community_templates_u8_creator_fk
    foreign key (creator_id,creator_key)
    references argus_app.editorial_creators(id,normalized_key) on delete restrict;

comment on column argus_app.community_templates.creator_label is
  'Compatibility label retained until the compatibility-removal contract proves zero readers; editorial_creators plus creator_id are authoritative.';

alter table argus_app.coven_qualifications
  add column category text,
  add column person_name text,
  add column effective_date date,
  add column valid_to date,
  add column verified_as_of date;

insert into argus_app.legacy_normalization_quarantine(
  source_relation,source_identity,cohort,reason_code,
  source_fingerprint,source_cardinality
)
select 'argus_app.coven_qualifications',qualification.id::text,
       'u8-coven-qualification-metadata',
       case
         when source.entry ? 'category'
          and source.entry->>'category' not in ('founder','owner','chief_executive')
           then 'invalid_category'
         when source.entry ? 'effective_date'
          and not pg_catalog.pg_input_is_valid(source.entry->>'effective_date','date')
           then 'invalid_effective_date'
         when source.entry ? 'valid_to'
          and not pg_catalog.pg_input_is_valid(source.entry->>'valid_to','date')
           then 'invalid_valid_to'
         when source.entry ? 'verified_as_of'
          and not pg_catalog.pg_input_is_valid(source.entry->>'verified_as_of','date')
           then 'invalid_verified_as_of'
         else 'invalid_person_name'
       end,
       pg_catalog.encode(extensions.digest(source.entry::text,'sha256'),'hex'),1
  from argus_app.coven_qualifications qualification
  join argus_app.coven_entries coven on coven.id=qualification.coven_entry_id
  cross join lateral (
    select coalesce(coven.qualification_payload->(qualification.ordinal-1),'{}'::jsonb) as entry
  ) source
 where (source.entry ? 'category'
          and source.entry->>'category' not in ('founder','owner','chief_executive'))
    or (source.entry ? 'effective_date'
          and not pg_catalog.pg_input_is_valid(source.entry->>'effective_date','date'))
    or (source.entry ? 'valid_to'
          and not pg_catalog.pg_input_is_valid(source.entry->>'valid_to','date'))
    or (source.entry ? 'verified_as_of'
          and not pg_catalog.pg_input_is_valid(source.entry->>'verified_as_of','date'))
    or (source.entry ? 'person_name' and (
          jsonb_typeof(source.entry->'person_name')<>'string'
          or pg_catalog.char_length(source.entry->>'person_name') not between 1 and 160))
on conflict (source_relation,source_identity,cohort,reason_code) do update set
  source_fingerprint=excluded.source_fingerprint,
  source_cardinality=excluded.source_cardinality;

with normalized as (
  select qualification.id,
         case when source.entry->>'category' in ('founder','owner','chief_executive')
              then source.entry->>'category' else 'founder' end as category,
         case when jsonb_typeof(source.entry->'person_name')='string'
                   and pg_catalog.char_length(source.entry->>'person_name') between 1 and 160
              then source.entry->>'person_name' end as person_name,
         case when pg_catalog.pg_input_is_valid(source.entry->>'effective_date','date')
              then (source.entry->>'effective_date')::date else revision.created_at::date end as effective_date,
         case when pg_catalog.pg_input_is_valid(source.entry->>'valid_to','date')
                   and (source.entry->>'valid_to')::date>=
                     case when pg_catalog.pg_input_is_valid(source.entry->>'effective_date','date')
                          then (source.entry->>'effective_date')::date else revision.created_at::date end
              then (source.entry->>'valid_to')::date end as valid_to,
         case when pg_catalog.pg_input_is_valid(source.entry->>'verified_as_of','date')
              then (source.entry->>'verified_as_of')::date else revision.created_at::date end as verified_as_of
    from argus_app.coven_qualifications qualification
    join argus_app.coven_entries coven on coven.id=qualification.coven_entry_id
    join argus_app.editorial_revisions revision on revision.id=qualification.revision_id
    cross join lateral (
      select coalesce(coven.qualification_payload->(qualification.ordinal-1),'{}'::jsonb) as entry
    ) source
)
update argus_app.coven_qualifications qualification
   set category=normalized.category,
       person_name=normalized.person_name,
       effective_date=normalized.effective_date,
       valid_to=normalized.valid_to,
       verified_as_of=normalized.verified_as_of
  from normalized
 where normalized.id=qualification.id;

alter table argus_app.coven_qualifications
  alter column category set not null,
  alter column effective_date set not null,
  alter column verified_as_of set not null,
  add constraint coven_qualifications_u8_category_check
    check (category in ('founder','owner','chief_executive')),
  add constraint coven_qualifications_u8_person_name_bounded
    check (person_name is null or pg_catalog.char_length(person_name) between 1 and 160),
  add constraint coven_qualifications_u8_validity_check
    check (valid_to is null or valid_to>=effective_date);

comment on column argus_app.coven_entries.qualification_payload is
  'Compatibility-only array retained until the compatibility-removal contract proves zero readers; Coven filters and reads use typed qualification rows.';

alter table argus_app.catalog_assets
  add column search_text text generated always as (
    pg_catalog.lower(slug||' '||symbol||' '||name)
  ) stored,
  add column search_vector tsvector generated always as (
    pg_catalog.to_tsvector('simple'::regconfig,slug||' '||symbol||' '||name)
  ) stored;

alter table argus_app.editorial_items
  add column search_text text generated always as (pg_catalog.lower(slug)) stored,
  add column search_vector tsvector generated always as (
    pg_catalog.to_tsvector('simple'::regconfig,slug)
  ) stored;

alter table argus_app.companies
  add column search_text text generated always as (
    pg_catalog.lower(slug||' '||name)
  ) stored,
  add column search_vector tsvector generated always as (
    pg_catalog.to_tsvector('simple'::regconfig,slug||' '||name)
  ) stored;

alter table argus_app.grimoires
  add column search_text text generated always as (
    pg_catalog.lower(theme_code)
  ) stored,
  add column search_vector tsvector generated always as (
    pg_catalog.to_tsvector('simple'::regconfig,theme_code)
  ) stored;

alter table argus_app.community_templates
  add column search_text text generated always as (
    pg_catalog.lower(creator_label||' '||title||' '||description)
  ) stored,
  add column search_vector tsvector generated always as (
    pg_catalog.to_tsvector('simple'::regconfig,creator_label||' '||title||' '||description)
  ) stored;

create index briefings_u8_owner_ready_page_idx
  on argus_app.briefings(
    tenant_id,lifecycle_id,user_id,briefing_type,period_end desc,id desc
  ) include (period_start,generated_at,generation,source_sequence)
  where status='ready';
create index briefing_sections_u8_typed_order_idx
  on argus_app.briefing_sections(
    tenant_id,lifecycle_id,user_id,briefing_id,ordinal,id
  ) include (section_type,source_sequence,schema_version,disclosure);

create index circles_u8_owner_active_page_idx
  on argus_app.circles(tenant_id,lifecycle_id,user_id,id)
  where archived_at is null;
create index circles_u8_owner_all_page_idx
  on argus_app.circles(
    tenant_id,lifecycle_id,user_id,
    (archived_at is not null),
    (coalesce(archived_at,'-infinity'::timestamptz)),id
  );

create index catalog_assets_u8_active_page_idx
  on argus_app.catalog_assets(asset_type,symbol,id)
  include (slug,name,currency,exchange)
  where status='active';
create index catalog_assets_u8_active_search_fts_idx
  on argus_app.catalog_assets using gin(search_vector)
  where status='active';
create index catalog_assets_u8_active_search_trgm_idx
  on argus_app.catalog_assets using gin(search_text extensions.gin_trgm_ops)
  where status='active';

create index companies_u8_active_search_fts_idx
  on argus_app.companies using gin(search_vector)
  where status='active';
create index companies_u8_active_search_trgm_idx
  on argus_app.companies using gin(search_text extensions.gin_trgm_ops)
  where status='active';

create index editorial_items_u8_published_page_idx
  on argus_app.editorial_items(kind,slug,id,current_published_revision_id)
  where status='published';
create index editorial_items_u8_published_search_fts_idx
  on argus_app.editorial_items using gin(search_vector)
  where status='published';
create index editorial_items_u8_published_search_trgm_idx
  on argus_app.editorial_items using gin(search_text extensions.gin_trgm_ops)
  where status='published';
create index grimoires_u8_theme_page_idx
  on argus_app.grimoires(theme_code,editorial_item_id,id);
create index grimoires_u8_search_fts_idx
  on argus_app.grimoires using gin(search_vector);
create index grimoires_u8_search_trgm_idx
  on argus_app.grimoires using gin(search_text extensions.gin_trgm_ops);
create index community_templates_u8_creator_page_idx
  on argus_app.community_templates(creator_id,editorial_item_id,id)
  where creator_normalization_state='ready';
create index community_templates_u8_search_fts_idx
  on argus_app.community_templates using gin(search_vector)
  where creator_normalization_state='ready';
create index community_templates_u8_search_trgm_idx
  on argus_app.community_templates using gin(search_text extensions.gin_trgm_ops)
  where creator_normalization_state='ready';
create index editorial_creators_u8_page_idx
  on argus_app.editorial_creators(display_name,id);
create index coven_qualifications_u8_current_filter_idx
  on argus_app.coven_qualifications(
    category,verified_as_of,coven_entry_id,editorial_item_id,revision_id,ordinal
  ) include (person_name,effective_date,valid_to,criterion_code,claim,evidence_claim_id);

-- Staff diagnostics merge three large operational streams. Each arm must be
-- independently index-bounded before the final three-way merge and limit.
do $membership$
begin
  execute pg_catalog.format(
    'grant argus_brokerage_owner to %I with set true',current_user
  );
end
$membership$;
grant create on schema argus_brokerage,argus_private
  to argus_brokerage_owner;
set local role argus_brokerage_owner;
create index connections_u8_admin_diagnostics_idx
  on argus_brokerage.connections(updated_at desc,id desc);
create index provider_commands_u8_admin_diagnostics_idx
  on argus_private.provider_commands(updated_at desc,id desc);
create index reconciliation_records_u8_admin_diagnostics_idx
  on argus_private.reconciliation_records(updated_at desc,id desc);
set local role postgres;
revoke create on schema argus_brokerage,argus_private
  from argus_brokerage_owner;
do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_brokerage_owner from %I',current_user
  );
end
$membership$;

-- Replace the retained staff commands so new writes maintain the typed U8
-- authorities in the same transaction as their compatibility projections.
create or replace function argus_private.ensure_editorial_creator(
  p_creator_label text,p_creator_bio text
)
returns uuid language plpgsql security definer set search_path='' as $$
declare retained_creator_id uuid;
declare retained_creator_key text;
declare retained_creator_hash text;
declare retained_creator_slug text;
begin
  retained_creator_key:=pg_catalog.lower(pg_catalog.btrim(p_creator_label));
  if pg_catalog.char_length(retained_creator_key) not between 1 and 120
     or (p_creator_bio is not null
       and pg_catalog.char_length(p_creator_bio) not between 1 and 1000) then
    raise exception 'invalid_editorial_creator' using errcode='23514';
  end if;
  retained_creator_hash:=md5('argus-editorial-creator:'||retained_creator_key);
  retained_creator_id:=(
    pg_catalog.substr(retained_creator_hash,1,8)||'-'||
    pg_catalog.substr(retained_creator_hash,9,4)||'-4'||
    pg_catalog.substr(retained_creator_hash,14,3)||'-8'||
    pg_catalog.substr(retained_creator_hash,18,3)||'-'||
    pg_catalog.substr(retained_creator_hash,21,12)
  )::uuid;
  retained_creator_slug:=pg_catalog.left(
    coalesce(nullif(pg_catalog.regexp_replace(retained_creator_key,'[^a-z0-9]+','-','g'),''),'creator'),
    50
  )||'-'||pg_catalog.substr(retained_creator_hash,1,8);

  insert into argus_app.editorial_creators(
    id,normalized_key,slug,display_name,bio,is_fictional
  ) values (
    retained_creator_id,retained_creator_key,retained_creator_slug,
    pg_catalog.btrim(p_creator_label),
    coalesce(nullif(p_creator_bio,''),'Fictional Argus editorial creator.'),
    true
  ) on conflict (normalized_key) do nothing;

  select creator.id into retained_creator_id
    from argus_app.editorial_creators creator
   where creator.normalized_key=retained_creator_key;
  if retained_creator_id is null then
    raise exception 'editorial_creator_binding_failed' using errcode='23514';
  end if;
  return retained_creator_id;
end $$;

create or replace function argus_private.bind_editorial_creator()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.creator_id is null then
    new.creator_id:=argus_private.ensure_editorial_creator(new.creator_label,null);
  end if;
  new.creator_normalization_state:='ready';
  return new;
end $$;
create trigger bind_editorial_creator
  before insert or update of creator_label,creator_id
  on argus_app.community_templates
  for each row execute function argus_private.bind_editorial_creator();

create or replace function argus_private.create_circle_template_editorial_item(
  p_item_id uuid,p_payload jsonb
)
returns void language plpgsql security definer set search_path='' as $$
declare retained_creator_id uuid;
declare retained_creator_key text;
begin
  retained_creator_key:=pg_catalog.lower(pg_catalog.btrim(p_payload->>'creator_label'));
  if not argus_private.has_staff_permission('editorial:write')
     or jsonb_typeof(p_payload)<>'object'
     or pg_catalog.char_length(retained_creator_key) not between 1 and 120
     or nullif(p_payload->>'title','') is null
     or nullif(p_payload->>'description','') is null
     or pg_catalog.char_length(p_payload->>'title')>200
     or pg_catalog.char_length(p_payload->>'description')>2000
     or (p_payload ? 'creator_bio'
       and pg_catalog.char_length(p_payload->>'creator_bio') not between 1 and 1000) then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  retained_creator_id:=argus_private.ensure_editorial_creator(
    p_payload->>'creator_label',nullif(p_payload->>'creator_bio','')
  );

  insert into argus_app.community_templates(
    editorial_item_id,creator_label,creator_id,creator_normalization_state,
    title,description
  ) values (
    p_item_id,p_payload->>'creator_label',retained_creator_id,'ready',
    p_payload->>'title',p_payload->>'description'
  );
end $$;

create or replace function argus_private.sync_coven_revision(
  p_revision_id uuid,p_payload jsonb
)
returns void language plpgsql security definer set search_path='' as $$
declare retained_item_id uuid;
declare retained_coven_id uuid;
declare retained_revision_date date;
declare retained_qualifications jsonb;
begin
  if not argus_private.has_staff_permission('editorial:write') then
    raise exception 'staff_permission_required' using errcode='42501';
  end if;
  retained_qualifications:=coalesce(
    p_payload->'qualifications',p_payload->'qualification_payload','[]'::jsonb
  );
  if jsonb_typeof(p_payload)<>'object'
     or jsonb_typeof(retained_qualifications)<>'array'
     or jsonb_array_length(retained_qualifications)>20
     or (p_payload ? 'category'
       and p_payload->>'category' not in ('founder','owner','chief_executive'))
     or (p_payload ? 'effective_date'
       and not pg_catalog.pg_input_is_valid(p_payload->>'effective_date','date'))
     or (p_payload ? 'valid_to'
       and not pg_catalog.pg_input_is_valid(p_payload->>'valid_to','date'))
     or (p_payload ? 'verified_as_of'
       and not pg_catalog.pg_input_is_valid(p_payload->>'verified_as_of','date'))
     or exists (
       select 1 from jsonb_array_elements(retained_qualifications) entry(value)
        where jsonb_typeof(entry.value)<>'object'
          or coalesce(entry.value->>'criterion_code',entry.value->>'criterion','')
             !~ '^[a-z][a-z0-9_]{0,63}$'
          or nullif(coalesce(entry.value->>'claim',entry.value->>'summary'),'') is null
          or pg_catalog.char_length(
               coalesce(entry.value->>'claim',entry.value->>'summary','')
             )>2000
          or coalesce(entry.value->>'category',p_payload->>'category','founder')
             not in ('founder','owner','chief_executive')
          or (entry.value ? 'person_name' and (
               jsonb_typeof(entry.value->'person_name')<>'string'
               or pg_catalog.char_length(entry.value->>'person_name') not between 1 and 160))
          or (entry.value ? 'effective_date'
               and not pg_catalog.pg_input_is_valid(entry.value->>'effective_date','date'))
          or (entry.value ? 'valid_to'
               and not pg_catalog.pg_input_is_valid(entry.value->>'valid_to','date'))
          or (entry.value ? 'verified_as_of'
               and not pg_catalog.pg_input_is_valid(entry.value->>'verified_as_of','date'))
     ) then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  select revision.item_id,coven.id,revision.created_at::date
    into retained_item_id,retained_coven_id,retained_revision_date
    from argus_app.editorial_revisions revision
    join argus_app.editorial_items item on item.id=revision.item_id and item.kind='coven'
    join argus_app.coven_entries coven on coven.editorial_item_id=item.id
   where revision.id=p_revision_id and revision.state='draft';
  if retained_item_id is null then
    raise exception 'resource_not_found' using errcode='P0002';
  end if;
  if exists (
    select 1 from jsonb_array_elements(retained_qualifications) entry(value)
     where entry.value->>'evidence_claim_id' is not null
       and not exists (
         select 1 from argus_app.evidence_claims claim
          where claim.id=(entry.value->>'evidence_claim_id')::uuid
            and claim.status='active'
       )
  ) or exists (
    select 1 from jsonb_array_elements(retained_qualifications) entry(value)
     where coalesce(
             nullif(entry.value->>'valid_to','')::date,
             nullif(p_payload->>'valid_to','')::date
           ) is not null
       and coalesce(
             nullif(entry.value->>'valid_to','')::date,
             nullif(p_payload->>'valid_to','')::date
           ) < coalesce(
             nullif(entry.value->>'effective_date','')::date,
             nullif(p_payload->>'effective_date','')::date,
             retained_revision_date
           )
  ) then
    raise exception 'invalid_editorial_evidence' using errcode='23514';
  end if;
  update argus_app.coven_entries
     set qualification_payload=retained_qualifications
   where id=retained_coven_id;
  delete from argus_app.coven_qualifications where revision_id=p_revision_id;
  insert into argus_app.coven_qualifications(
    coven_entry_id,editorial_item_id,revision_id,ordinal,
    criterion_code,claim,evidence_claim_id,
    category,person_name,effective_date,valid_to,verified_as_of
  )
  select retained_coven_id,retained_item_id,p_revision_id,entry.ordinal::integer,
         coalesce(entry.value->>'criterion_code',entry.value->>'criterion'),
         coalesce(entry.value->>'claim',entry.value->>'summary'),
         nullif(entry.value->>'evidence_claim_id','')::uuid,
         coalesce(entry.value->>'category',p_payload->>'category','founder'),
         nullif(coalesce(entry.value->>'person_name',p_payload->>'person_name'),'')::text,
         coalesce(
           nullif(entry.value->>'effective_date','')::date,
           nullif(p_payload->>'effective_date','')::date,
           retained_revision_date
         ),
         coalesce(
           nullif(entry.value->>'valid_to','')::date,
           nullif(p_payload->>'valid_to','')::date
         ),
         coalesce(
           nullif(entry.value->>'verified_as_of','')::date,
           nullif(p_payload->>'verified_as_of','')::date,
           retained_revision_date
         )
    from jsonb_array_elements(retained_qualifications)
      with ordinality entry(value,ordinal);
exception when invalid_text_representation then
  raise exception 'invalid_editorial_payload' using errcode='23514';
end $$;

create or replace function argus_private.list_member_briefings_page(
  p_limit integer,p_briefing_type text,p_period_start date,p_period_end date,
  p_after_period_end date,p_after_id uuid
)
returns table(
  id uuid,briefing_type text,period_start date,period_end date,
  generated_at timestamptz,generation integer,source_sequence bigint,
  read_at timestamptz
)
language sql stable security invoker set search_path='' rows 101 as $$
  select briefing.id,briefing.briefing_type,briefing.period_start,
         briefing.period_end,briefing.generated_at,briefing.generation,
         briefing.source_sequence,read_state.read_at
    from argus_app.briefings briefing
    left join argus_app.briefing_read_states read_state
      on read_state.tenant_id=briefing.tenant_id
     and read_state.lifecycle_id=briefing.lifecycle_id
     and read_state.user_id=briefing.user_id
     and read_state.briefing_id=briefing.id
   where p_limit between 1 and 101
     and ((p_after_period_end is null and p_after_id is null)
       or (p_after_period_end is not null and p_after_id is not null))
     and briefing.tenant_id=(select argus_private.trusted_request_tenant_id())
     and briefing.lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
     and briefing.user_id=(select argus_private.trusted_request_user_id())
     and briefing.status='ready'
     and (p_briefing_type is null or briefing.briefing_type=p_briefing_type)
     and (p_period_start is null or briefing.period_start>=p_period_start)
     and (p_period_end is null or briefing.period_end<=p_period_end)
     and (p_after_id is null
       or (briefing.period_end,briefing.id)<(p_after_period_end,p_after_id))
   order by briefing.period_end desc,briefing.id desc
   limit p_limit
$$;

create or replace function argus_private.list_member_briefing_sections(
  p_briefing_id uuid
)
returns table(
  ordinal integer,section_type text,source_sequence bigint,
  schema_version integer,disclosure text
)
language sql stable security invoker set search_path='' rows 100 as $$
  select section.ordinal,section.section_type,section.source_sequence,
         section.schema_version,section.disclosure
    from argus_app.briefing_sections section
    join argus_app.briefings briefing
      on briefing.tenant_id=section.tenant_id
     and briefing.lifecycle_id=section.lifecycle_id
     and briefing.user_id=section.user_id
     and briefing.id=section.briefing_id
   where section.tenant_id=(select argus_private.trusted_request_tenant_id())
     and section.lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
     and section.user_id=(select argus_private.trusted_request_user_id())
     and section.briefing_id=p_briefing_id
     and briefing.status='ready'
   order by section.ordinal,section.id
$$;

create or replace function argus_private.list_member_circles_page(
  p_limit integer,p_include_archived boolean,
  p_after_archived boolean,p_after_archived_at timestamptz,p_after_id uuid
)
returns table(
  id uuid,user_id uuid,deletion_epoch bigint,title text,description text,
  private boolean,source_template_id uuid,source_revision_id uuid,
  version integer,archived_at timestamptz,assets jsonb,
  archived_sort boolean,archived_cursor_at timestamptz
)
language sql stable security invoker set search_path='' rows 101 as $$
  select circle.id,circle.user_id,circle.deletion_epoch,circle.title,
         circle.description,true,circle.source_template_id,
         source_item.current_published_revision_id,circle.version,circle.archived_at,
         coalesce((
           select jsonb_agg(to_jsonb(asset) order by asset.ordinal,asset.id)
             from argus_app.circle_assets asset
            where asset.tenant_id=circle.tenant_id
              and asset.lifecycle_id=circle.lifecycle_id
              and asset.user_id=circle.user_id and asset.circle_id=circle.id
         ),'[]'::jsonb),
         circle.archived_at is not null,circle.archived_at
    from argus_app.circles circle
    left join argus_app.community_templates source_template
      on source_template.id=circle.source_template_id
    left join argus_app.editorial_items source_item
      on source_item.id=source_template.editorial_item_id
   where p_limit between 1 and 101
     and (
       (p_after_archived is null and p_after_archived_at is null and p_after_id is null)
       or (p_after_archived=false and p_after_archived_at is null and p_after_id is not null)
       or (p_after_archived=true and p_after_archived_at is not null and p_after_id is not null)
     )
     and circle.tenant_id=(select argus_private.trusted_request_tenant_id())
     and circle.lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
     and circle.user_id=(select argus_private.trusted_request_user_id())
     and (p_include_archived or circle.archived_at is null)
     and (p_after_id is null or
       (circle.archived_at is not null,
        coalesce(circle.archived_at,'-infinity'::timestamptz),circle.id)>
       (p_after_archived,
        coalesce(p_after_archived_at,'-infinity'::timestamptz),p_after_id))
   order by (circle.archived_at is not null),
            coalesce(circle.archived_at,'-infinity'::timestamptz),circle.id
   limit p_limit
$$;

create or replace function argus_private.list_published_assets_page(
  p_limit integer,p_asset_type text,p_symbol_prefix text,
  p_after_symbol text,p_after_id uuid
)
returns table(
  id uuid,slug text,symbol text,name text,asset_type text,currency text,
  exchange text,revision_id uuid,revision_created_at timestamptz,document jsonb
)
language sql stable security invoker set search_path='' rows 101 as $$
  select asset.id,asset.slug,asset.symbol,asset.name,asset.asset_type,
         asset.currency,asset.exchange,publication.revision_id,
         publication.revision_created_at,publication.document
    from argus_app.catalog_assets asset
    join lateral (
      select revision.id as revision_id,revision.created_at as revision_created_at,
             render_document.document
        from argus_app.asset_codex_revisions codex
        join argus_app.editorial_items item
          on item.id=codex.editorial_item_id
         and item.current_published_revision_id=codex.revision_id
         and item.kind='asset_codex' and item.status='published'
        join argus_app.editorial_revisions revision
          on revision.item_id=item.id and revision.id=codex.revision_id
         and revision.state='published'
        join argus_app.editorial_render_documents render_document
          on render_document.item_id=item.id
         and render_document.revision_id=revision.id
       where codex.asset_id=asset.id
       order by item.slug,item.id
       limit 1
    ) publication on true
   where p_limit between 1 and 101
     and ((p_after_symbol is null and p_after_id is null)
       or (p_after_symbol is not null and p_after_id is not null))
     and asset.status='active'
     and (p_asset_type is null or asset.asset_type=p_asset_type)
     and (p_symbol_prefix is null
       or asset.symbol ilike pg_catalog.replace(
            pg_catalog.replace(
              pg_catalog.replace(p_symbol_prefix,E'\\',E'\\\\'),
              '%',E'\\%'
            ),'_',E'\\_'
          )||'%' escape E'\\')
     and (p_after_id is null or (asset.symbol,asset.id)>(p_after_symbol,p_after_id))
   order by asset.symbol,asset.id
   limit p_limit
$$;

create or replace function argus_private.list_published_grimoires_page(
  p_limit integer,p_theme_code text,p_after_slug text,p_after_id uuid
)
returns table(
  id uuid,editorial_item_id uuid,slug text,theme_code text,
  revision_id uuid,revision_created_at timestamptz,document jsonb
)
language sql stable security invoker set search_path='' rows 101 as $$
  select grimoire.id,grimoire.editorial_item_id,item.slug,grimoire.theme_code,
         revision.id,revision.created_at,render_document.document
    from argus_app.grimoires grimoire
    join argus_app.editorial_items item
      on item.id=grimoire.editorial_item_id
    join argus_app.editorial_revisions revision
      on revision.item_id=item.id and revision.id=item.current_published_revision_id
    join argus_app.editorial_render_documents render_document
      on render_document.item_id=item.id and render_document.revision_id=revision.id
   where p_limit between 1 and 101
     and ((p_after_slug is null and p_after_id is null)
       or (p_after_slug is not null and p_after_id is not null))
     and item.kind='grimoire' and item.status='published'
     and revision.state='published'
     and (p_theme_code is null or grimoire.theme_code=p_theme_code)
     and (p_after_id is null or (item.slug,grimoire.id)>(p_after_slug,p_after_id))
   order by item.slug,grimoire.id
   limit p_limit
$$;

create or replace function argus_private.list_published_circle_templates_page(
  p_limit integer,p_creator text,p_after_slug text,p_after_id uuid
)
returns table(
  id uuid,editorial_item_id uuid,slug text,creator_id uuid,creator_slug text,
  creator_display_name text,creator_bio text,creator_is_fictional boolean,
  title text,description text,revision_id uuid,
  revision_created_at timestamptz,document jsonb
)
language sql stable security invoker set search_path='' rows 101 as $$
  select template.id,template.editorial_item_id,item.slug,creator.id,creator.slug,
         creator.display_name,creator.bio,creator.is_fictional,
         template.title,template.description,revision.id,revision.created_at,
         render_document.document
    from argus_app.community_templates template
    join argus_app.editorial_creators creator on creator.id=template.creator_id
    join argus_app.editorial_items item on item.id=template.editorial_item_id
    join argus_app.editorial_revisions revision
      on revision.item_id=item.id and revision.id=item.current_published_revision_id
    join argus_app.editorial_render_documents render_document
      on render_document.item_id=item.id and render_document.revision_id=revision.id
   where p_limit between 1 and 101
     and ((p_after_slug is null and p_after_id is null)
       or (p_after_slug is not null and p_after_id is not null))
     and template.creator_normalization_state='ready'
     and item.kind='circle_template' and item.status='published'
     and revision.state='published'
     and (p_creator is null
       or creator.slug=p_creator or creator.display_name=p_creator)
     and (p_after_id is null or (item.slug,template.id)>(p_after_slug,p_after_id))
   order by item.slug,template.id
   limit p_limit
$$;

create or replace function argus_private.list_published_creators_page(
  p_limit integer,p_after_display_name text,p_after_id uuid
)
returns table(
  id uuid,slug text,display_name text,bio text,is_fictional boolean,
  observed_at timestamptz
)
language sql stable security invoker set search_path='' rows 101 as $$
  select creator.id,creator.slug,creator.display_name,creator.bio,
         creator.is_fictional,publication.observed_at
    from argus_app.editorial_creators creator
    join lateral (
      select min(revision.created_at) as observed_at
        from argus_app.community_templates template
        join argus_app.editorial_items item
          on item.id=template.editorial_item_id
        join argus_app.editorial_revisions revision
          on revision.item_id=item.id
         and revision.id=item.current_published_revision_id
       where template.creator_id=creator.id
         and template.creator_normalization_state='ready'
         and item.kind='circle_template' and item.status='published'
         and revision.state='published'
      having count(*)>0
    ) publication on true
   where p_limit between 1 and 101
     and ((p_after_display_name is null and p_after_id is null)
       or (p_after_display_name is not null and p_after_id is not null))
     and (p_after_id is null
       or (creator.display_name,creator.id)>(p_after_display_name,p_after_id))
   order by creator.display_name,creator.id
   limit p_limit
$$;

create or replace function argus_private.list_published_coven_page(
  p_limit integer,p_category text,p_verified_as_of date,
  p_after_slug text,p_after_id uuid
)
returns table(
  id uuid,editorial_item_id uuid,slug text,company_id uuid,company_name text,
  symbol text,category text,person_name text,effective_date date,valid_to date,
  verified_as_of date,criterion_code text,claim text,evidence_claim_id uuid,
  revision_id uuid,revision_created_at timestamptz,document jsonb
)
language sql stable security invoker set search_path='' rows 101 as $$
  select coven.id,coven.editorial_item_id,item.slug,company.id,company.name,
         asset.symbol,qualification.category,qualification.person_name,
         qualification.effective_date,qualification.valid_to,
         qualification.verified_as_of,qualification.criterion_code,
         qualification.claim,qualification.evidence_claim_id,
         revision.id,revision.created_at,render_document.document
    from argus_app.coven_entries coven
    join argus_app.companies company
      on company.id=coven.company_id and company.status='active'
    left join argus_app.catalog_assets asset
      on asset.id=company.asset_id and asset.status='active'
    join argus_app.editorial_items item on item.id=coven.editorial_item_id
    join argus_app.editorial_revisions revision
      on revision.item_id=item.id and revision.id=item.current_published_revision_id
    join lateral (
      select typed.category,typed.person_name,typed.effective_date,typed.valid_to,
             typed.verified_as_of,typed.criterion_code,typed.claim,
             typed.evidence_claim_id,typed.ordinal
        from argus_app.coven_qualifications typed
       where typed.coven_entry_id=coven.id
         and typed.editorial_item_id=item.id
         and typed.revision_id=revision.id
         and (p_category is null or typed.category=p_category)
         and (p_verified_as_of is null or typed.verified_as_of<=p_verified_as_of)
       order by typed.ordinal,typed.id
       limit 1
    ) qualification on true
    join argus_app.editorial_render_documents render_document
      on render_document.item_id=item.id and render_document.revision_id=revision.id
   where p_limit between 1 and 101
     and (p_category is null
       or p_category in ('founder','owner','chief_executive'))
     and ((p_after_slug is null and p_after_id is null)
       or (p_after_slug is not null and p_after_id is not null))
     and item.kind='coven' and item.status='published'
     and revision.state='published'
     and (p_after_id is null or (item.slug,coven.id)>(p_after_slug,p_after_id))
   order by item.slug,coven.id
   limit p_limit
$$;

create or replace function argus_private.list_current_published_editorial_page(
  p_kind text,p_limit integer,p_after_slug text,p_after_id uuid
)
returns table(
  id uuid,kind text,slug text,revision_id uuid,
  revision_number integer,document jsonb
)
language sql stable security invoker set search_path='' rows 101 as $$
  select item.id,item.kind,item.slug,revision.id,revision.revision_number,
         render_document.document
    from argus_app.editorial_items item
    join argus_app.editorial_revisions revision
      on revision.item_id=item.id and revision.id=item.current_published_revision_id
    join argus_app.editorial_render_documents render_document
      on render_document.item_id=item.id and render_document.revision_id=revision.id
   where p_limit between 1 and 101
     and ((p_after_slug is null and p_after_id is null)
       or (p_after_slug is not null and p_after_id is not null))
     and item.status='published' and revision.state='published'
     and item.kind=p_kind
     and (p_after_id is null or (item.slug,item.id)>(p_after_slug,p_after_id))
   order by item.slug,item.id
   limit p_limit
$$;

create or replace function argus_private.search_published_content_page(
  p_query text,p_kinds text[],p_limit integer,
  p_after_rank integer,p_after_label text,p_after_kind text,p_after_id uuid
)
returns table(
  result_kind text,id uuid,slug text,label text,rank integer,
  revision_id uuid,summary jsonb
)
language sql stable security invoker set search_path='' rows 101 as $$
  with search_input as materialized (
    select pg_catalog.lower(pg_catalog.btrim(p_query)) as normalized_query,
           pg_catalog.websearch_to_tsquery('simple'::regconfig,p_query) as parsed_query
  ), candidates as (
    select 'asset'::text as result_kind,asset.id,asset.slug,asset.name as label,
           case
             when pg_catalog.lower(asset.name)=input.normalized_query
               or pg_catalog.lower(asset.symbol)=input.normalized_query then 400
             when pg_catalog.lower(asset.name) like input.normalized_query||'%'
               or pg_catalog.lower(asset.symbol) like input.normalized_query||'%' then 300
             when asset.search_vector@@input.parsed_query then 200
             else 100
           end as rank,
           publication.revision_id,
           jsonb_build_object(
             'id',asset.id,'slug',asset.slug,'symbol',asset.symbol,
             'name',asset.name,'asset_type',asset.asset_type,
             'currency',asset.currency,'exchange',asset.exchange,
             'revision_id',publication.revision_id,
             'revision_created_at',publication.revision_created_at,
             'payload',publication.document
           ) as summary
      from argus_app.catalog_assets asset
      cross join search_input input
      join lateral (
        select revision.id as revision_id,revision.created_at as revision_created_at,
               render_document.document
          from argus_app.asset_codex_revisions codex
          join argus_app.editorial_items item
            on item.id=codex.editorial_item_id
           and item.current_published_revision_id=codex.revision_id
           and item.kind='asset_codex' and item.status='published'
          join argus_app.editorial_revisions revision
            on revision.item_id=item.id and revision.id=codex.revision_id
           and revision.state='published'
          join argus_app.editorial_render_documents render_document
            on render_document.item_id=item.id
           and render_document.revision_id=revision.id
         where codex.asset_id=asset.id
         order by item.slug,item.id
         limit 1
      ) publication on true
     where 'asset'=any(p_kinds) and asset.status='active'
       and (asset.search_vector@@input.parsed_query
         or asset.search_text like '%'||input.normalized_query||'%')
    union all
    select 'coven',coven.id,item.slug,company.name,
           case
             when pg_catalog.lower(company.name)=input.normalized_query then 400
             when pg_catalog.lower(company.name) like input.normalized_query||'%' then 300
             when company.search_vector@@input.parsed_query
               or item.search_vector@@input.parsed_query then 200
             else 100
           end,
           revision.id,
           jsonb_build_object(
             'id',coven.id,'editorial_item_id',coven.editorial_item_id,
             'company_id',company.id,'company_name',company.name,
             'symbol',asset.symbol,'slug',item.slug,
             'revision_id',revision.id,'revision_created_at',revision.created_at,
             'category',primary_qualification.category,
             'person_name',primary_qualification.person_name,
             'effective_date',primary_qualification.effective_date,
             'valid_to',primary_qualification.valid_to,
             'verified_as_of',primary_qualification.verified_as_of,
             'criterion_code',primary_qualification.criterion_code,
             'claim',primary_qualification.claim,
             'evidence_claim_id',primary_qualification.evidence_claim_id,
             'payload',render_document.document
           )
      from argus_app.coven_entries coven
      join argus_app.companies company
        on company.id=coven.company_id and company.status='active'
      left join argus_app.catalog_assets asset
        on asset.id=company.asset_id and asset.status='active'
      join argus_app.editorial_items item
        on item.id=coven.editorial_item_id and item.kind='coven'
       and item.status='published'
      join argus_app.editorial_revisions revision
        on revision.item_id=item.id and revision.id=item.current_published_revision_id
       and revision.state='published'
      join lateral (
        select qualification.category,qualification.person_name,
               qualification.effective_date,qualification.valid_to,
               qualification.verified_as_of,qualification.criterion_code,
               qualification.claim,qualification.evidence_claim_id
          from argus_app.coven_qualifications qualification
         where qualification.coven_entry_id=coven.id
           and qualification.editorial_item_id=item.id
           and qualification.revision_id=revision.id
         order by qualification.ordinal,qualification.id
         limit 1
      ) primary_qualification on true
      join argus_app.editorial_render_documents render_document
        on render_document.item_id=item.id and render_document.revision_id=revision.id
      cross join search_input input
     where 'coven'=any(p_kinds)
       and (company.search_vector@@input.parsed_query
         or company.search_text like '%'||input.normalized_query||'%'
         or item.search_vector@@input.parsed_query
         or item.search_text like '%'||input.normalized_query||'%')
    union all
    select 'grimoire',grimoire.id,item.slug,item.slug,
           case
             when item.search_text=input.normalized_query then 400
             when item.search_text like input.normalized_query||'%' then 300
             when item.search_vector@@input.parsed_query
               or grimoire.search_vector@@input.parsed_query then 200
             else 100
           end,
           revision.id,
           jsonb_build_object(
             'id',grimoire.id,'editorial_item_id',grimoire.editorial_item_id,
             'slug',item.slug,'theme_code',grimoire.theme_code,
             'revision_id',revision.id,'revision_created_at',revision.created_at,
             'payload',render_document.document
           )
      from argus_app.grimoires grimoire
      join argus_app.editorial_items item
        on item.id=grimoire.editorial_item_id and item.kind='grimoire'
       and item.status='published'
      join argus_app.editorial_revisions revision
        on revision.item_id=item.id and revision.id=item.current_published_revision_id
       and revision.state='published'
      join argus_app.editorial_render_documents render_document
        on render_document.item_id=item.id and render_document.revision_id=revision.id
      cross join search_input input
     where 'grimoire'=any(p_kinds)
       and (grimoire.search_vector@@input.parsed_query
         or grimoire.search_text like '%'||input.normalized_query||'%'
         or item.search_vector@@input.parsed_query
         or item.search_text like '%'||input.normalized_query||'%')
    union all
    select 'circle_template',template.id,item.slug,template.title,
           case
             when pg_catalog.lower(template.title)=input.normalized_query then 400
             when pg_catalog.lower(template.title) like input.normalized_query||'%' then 300
             when template.search_vector@@input.parsed_query
               or item.search_vector@@input.parsed_query then 200
             else 100
           end,
           revision.id,
           jsonb_build_object(
             'id',template.id,'editorial_item_id',template.editorial_item_id,
             'slug',item.slug,'creator_id',creator.id,
             'creator_display_name',creator.display_name,'creator_slug',creator.slug,
             'creator_bio',creator.bio,'creator_is_fictional',creator.is_fictional,
             'title',template.title,'description',template.description,
             'revision_id',revision.id,'revision_created_at',revision.created_at,
             'payload',render_document.document
           )
      from argus_app.community_templates template
      join argus_app.editorial_creators creator on creator.id=template.creator_id
      join argus_app.editorial_items item
        on item.id=template.editorial_item_id and item.kind='circle_template'
       and item.status='published'
      join argus_app.editorial_revisions revision
        on revision.item_id=item.id and revision.id=item.current_published_revision_id
       and revision.state='published'
      join argus_app.editorial_render_documents render_document
        on render_document.item_id=item.id and render_document.revision_id=revision.id
      cross join search_input input
     where 'circle_template'=any(p_kinds)
       and template.creator_normalization_state='ready'
       and (template.search_vector@@input.parsed_query
         or template.search_text like '%'||input.normalized_query||'%'
         or item.search_vector@@input.parsed_query
         or item.search_text like '%'||input.normalized_query||'%')
  ), bounded as (
    select candidate.*
      from candidates candidate
     where p_limit between 1 and 101
       and pg_catalog.char_length(pg_catalog.btrim(p_query)) between 2 and 100
       and cardinality(p_kinds) between 1 and 4
       and p_kinds<@array['asset','coven','grimoire','circle_template']::text[]
       and cardinality(p_kinds)=(select count(distinct kind) from unnest(p_kinds) kind)
       and (
         (p_after_rank is null and p_after_label is null
           and p_after_kind is null and p_after_id is null)
         or (p_after_rank is not null and p_after_label is not null
           and p_after_kind is not null and p_after_id is not null)
       )
       and (p_after_id is null
         or candidate.rank<p_after_rank
         or (candidate.rank=p_after_rank
           and (candidate.label,candidate.result_kind,candidate.id)>
             (p_after_label,p_after_kind,p_after_id)))
  )
  select bounded.result_kind,bounded.id,bounded.slug,bounded.label,
         bounded.rank,bounded.revision_id,bounded.summary
    from bounded
   order by bounded.rank desc,bounded.label,bounded.result_kind,bounded.id
   limit p_limit
$$;

alter table argus_app.editorial_creators enable row level security;
alter table argus_app.editorial_creators force row level security;

create policy u8_member_published_creators
  on argus_app.editorial_creators
  for select to argus_member
  using (
    (select argus_private.trusted_request_lifecycle_id()) is not null
    and exists (
      select 1
        from argus_app.community_templates template
        join argus_app.editorial_items item
          on item.id=template.editorial_item_id
        join argus_app.editorial_revisions revision
          on revision.item_id=item.id
         and revision.id=item.current_published_revision_id
       where template.creator_id=editorial_creators.id
         and template.creator_normalization_state='ready'
         and item.kind='circle_template' and item.status='published'
         and revision.state='published'
    )
  );
create policy u8_staff_creator_read
  on argus_app.editorial_creators
  for select to argus_staff
  using (
    (select argus_private.has_staff_permission('editorial:read'))
    or (select argus_private.has_staff_permission('editorial:write'))
    or (select argus_private.has_staff_permission('editorial:review'))
    or (select argus_private.has_staff_permission('editorial:publish'))
  );
create policy u8_app_owner_creator_read
  on argus_app.editorial_creators
  for select to argus_app_owner
  using (true);
create policy u8_app_owner_creator_insert
  on argus_app.editorial_creators
  for insert to argus_app_owner
  with check (true);

create policy u8_public_preview_published_items
  on argus_app.editorial_items
  for select to argus_public_preview
  using (status='published');
create policy u8_public_preview_current_revisions
  on argus_app.editorial_revisions
  for select to argus_public_preview
  using (
    state='published' and exists (
      select 1 from argus_app.editorial_items item
       where item.id=editorial_revisions.item_id
         and item.current_published_revision_id=editorial_revisions.id
         and item.status='published'
    )
  );
create policy u8_public_preview_current_render_documents
  on argus_app.editorial_render_documents
  for select to argus_public_preview
  using (
    exists (
      select 1
        from argus_app.editorial_items item
        join argus_app.editorial_revisions revision
          on revision.item_id=item.id
         and revision.id=item.current_published_revision_id
       where item.id=editorial_render_documents.item_id
         and revision.id=editorial_render_documents.revision_id
         and item.status='published' and revision.state='published'
    )
  );

revoke all on table argus_app.editorial_creators
  from public,anon,authenticated,argus_runtime,argus_worker,argus_waitlist,
       argus_member,argus_staff,argus_callback,argus_migration,argus_edge;

do $membership$
begin
  execute pg_catalog.format(
    'grant argus_app_owner to %I with set true',current_user
  );
end
$membership$;
grant create on schema argus_private,argus_app to argus_app_owner;

alter table argus_app.editorial_creators owner to argus_app_owner;

alter function argus_private.ensure_editorial_creator(text,text)
  owner to argus_app_owner;
alter function argus_private.bind_editorial_creator()
  owner to argus_app_owner;
alter function argus_private.create_circle_template_editorial_item(uuid,jsonb)
  owner to argus_app_owner;
alter function argus_private.sync_coven_revision(uuid,jsonb)
  owner to argus_app_owner;
alter function argus_private.list_member_briefings_page(
  integer,text,date,date,date,uuid
) owner to argus_app_owner;
alter function argus_private.list_member_briefing_sections(uuid)
  owner to argus_app_owner;
alter function argus_private.list_member_circles_page(
  integer,boolean,boolean,timestamptz,uuid
) owner to argus_app_owner;
alter function argus_private.list_published_assets_page(
  integer,text,text,text,uuid
) owner to argus_app_owner;
alter function argus_private.list_published_grimoires_page(
  integer,text,text,uuid
) owner to argus_app_owner;
alter function argus_private.list_published_circle_templates_page(
  integer,text,text,uuid
) owner to argus_app_owner;
alter function argus_private.list_published_creators_page(
  integer,text,uuid
) owner to argus_app_owner;
alter function argus_private.list_published_coven_page(
  integer,text,date,text,uuid
) owner to argus_app_owner;
alter function argus_private.list_current_published_editorial_page(
  text,integer,text,uuid
) owner to argus_app_owner;
alter function argus_private.search_published_content_page(
  text,text[],integer,integer,text,text,uuid
) owner to argus_app_owner;

grant select on table argus_app.editorial_creators to argus_member,argus_staff;
grant select on table
  argus_app.editorial_items,argus_app.editorial_revisions,
  argus_app.editorial_render_documents
to argus_public_preview;

revoke all on function
  argus_private.ensure_editorial_creator(text,text),
  argus_private.bind_editorial_creator(),
  argus_private.list_member_briefings_page(integer,text,date,date,date,uuid),
  argus_private.list_member_briefing_sections(uuid),
  argus_private.list_member_circles_page(integer,boolean,boolean,timestamptz,uuid),
  argus_private.list_published_assets_page(integer,text,text,text,uuid),
  argus_private.list_published_grimoires_page(integer,text,text,uuid),
  argus_private.list_published_circle_templates_page(integer,text,text,uuid),
  argus_private.list_published_creators_page(integer,text,uuid),
  argus_private.list_published_coven_page(integer,text,date,text,uuid),
  argus_private.list_current_published_editorial_page(text,integer,text,uuid),
  argus_private.search_published_content_page(text,text[],integer,integer,text,text,uuid)
from public,anon,authenticated,argus_runtime,argus_worker,argus_waitlist,
     argus_member,argus_staff,argus_callback,argus_migration,argus_edge,
     argus_public_preview;

grant execute on function
  argus_private.list_member_briefings_page(integer,text,date,date,date,uuid),
  argus_private.list_member_briefing_sections(uuid),
  argus_private.list_member_circles_page(integer,boolean,boolean,timestamptz,uuid),
  argus_private.list_published_assets_page(integer,text,text,text,uuid),
  argus_private.list_published_grimoires_page(integer,text,text,uuid),
  argus_private.list_published_circle_templates_page(integer,text,text,uuid),
  argus_private.list_published_creators_page(integer,text,uuid),
  argus_private.list_published_coven_page(integer,text,date,text,uuid),
  argus_private.list_current_published_editorial_page(text,integer,text,uuid),
  argus_private.search_published_content_page(text,text[],integer,integer,text,text,uuid)
to argus_member;

grant execute on function
  argus_private.list_current_published_editorial_page(text,integer,text,uuid)
to argus_public_preview;

grant execute on function
  argus_private.list_published_assets_page(integer,text,text,text,uuid),
  argus_private.list_published_grimoires_page(integer,text,text,uuid),
  argus_private.list_published_circle_templates_page(integer,text,text,uuid),
  argus_private.list_published_creators_page(integer,text,uuid),
  argus_private.list_published_coven_page(integer,text,date,text,uuid),
  argus_private.search_published_content_page(text,text[],integer,integer,text,text,uuid)
to argus_staff;

comment on table argus_app.editorial_creators is
  'Authoritative editorial creator registry. Community templates bind creator identity through creator_id and creator_key.';
comment on function argus_private.search_published_content_page(
  text,text[],integer,integer,text,text,uuid
) is
  'Globally ranked normalized search. summary is a typed repository-row projection; sealed document fields are presentation-only and never searched.';
comment on function argus_private.list_published_coven_page(
  integer,text,date,text,uuid
) is
  'Current-publication Coven page; category and verified-as-of are typed predicates applied before the bounded limit.';

do $$
begin
  if exists (
    select 1 from argus_app.community_templates template
     where (template.creator_normalization_state='ready')<>(template.creator_id is not null)
       or (template.creator_normalization_state='quarantined' and not exists (
         select 1 from argus_app.legacy_normalization_quarantine quarantine
          where quarantine.source_relation='argus_app.community_templates'
            and quarantine.source_identity=template.id::text
            and quarantine.cohort='u8-editorial-creator'
       ))
  ) then
    raise exception 'u8_creator_backfill_parity_failed' using errcode='23514';
  end if;
  if (
    select count(*) from argus_app.editorial_creators
  )<>(
    select count(distinct template.creator_key)
      from argus_app.community_templates template
     where template.creator_normalization_state='ready'
  ) then
    raise exception 'u8_creator_registry_not_bijective' using errcode='23514';
  end if;
  if exists (
    select 1 from argus_app.coven_qualifications qualification
     where qualification.category is null
        or qualification.effective_date is null
        or qualification.verified_as_of is null
  ) then
    raise exception 'u8_coven_typed_backfill_incomplete' using errcode='23514';
  end if;
end
$$;

-- PostgreSQL does not create referencing-side indexes for foreign keys. Close
-- the remaining deletion/update scan gaps before the U9 production gate.
create index briefing_read_states_u8_fk_idx
  on argus_app.briefing_read_states(user_id,deletion_epoch,briefing_id);
create index circles_source_template_u8_fk_idx
  on argus_app.circles(source_template_id);
create index community_templates_creator_u8_fk_idx
  on argus_app.community_templates(creator_id,creator_key);
create index companies_asset_u8_fk_idx
  on argus_app.companies(asset_id);
create index daily_ritual_assignments_revision_u8_fk_idx
  on argus_app.daily_ritual_assignments(revision_id);
create index daily_ritual_assignments_rowan_u8_fk_idx
  on argus_app.daily_ritual_assignments(rowan_revision_id);
create index daily_ritual_assignments_schedule_u8_fk_idx
  on argus_app.daily_ritual_assignments(schedule_id);
create index editorial_items_current_revision_u8_fk_idx
  on argus_app.editorial_items(id,current_published_revision_id);
create index editorial_review_decisions_request_u8_fk_idx
  on argus_app.editorial_review_decisions(request_id);
create index editorial_review_decisions_reviewer_u8_fk_idx
  on argus_app.editorial_review_decisions(reviewer_id);
create index editorial_review_requests_revision_u8_fk_idx
  on argus_app.editorial_review_requests(revision_id);
create index editorial_review_requests_requester_u8_fk_idx
  on argus_app.editorial_review_requests(requested_by);
create index editorial_revisions_author_u8_fk_idx
  on argus_app.editorial_revisions(author_staff_id);
create index evidence_claims_source_u8_fk_idx
  on argus_app.evidence_claims(source_id);
create index future_mirror_points_run_u8_fk_idx
  on argus_app.future_mirror_points(user_id,run_id);
create index publication_events_actor_u8_fk_idx
  on argus_app.publication_events(actor_id);
create index ritual_schedules_revision_u8_fk_idx
  on argus_app.ritual_schedules(revision_id);
create index rowan_context_bindings_script_u8_fk_idx
  on argus_app.rowan_context_bindings(script_id);
create index admin_audit_events_actor_u8_fk_idx
  on argus_private.admin_audit_events(actor_user_id);
create index dead_letter_events_outbox_u8_fk_idx
  on argus_private.dead_letter_events(outbox_event_id);
create index kill_switches_updated_by_u8_fk_idx
  on argus_private.kill_switches(updated_by);
create index security_events_user_u8_fk_idx
  on argus_private.security_events(user_id);
create index staff_step_up_receipts_user_u8_fk_idx
  on argus_private.staff_step_up_receipts(user_id);
create index step_up_receipts_user_u8_fk_idx
  on argus_private.step_up_receipts(user_id);

-- A FOR ALL policy participates in every command. Keeping a second SELECT or
-- UPDATE policy beside it makes Postgres evaluate both permissive predicates
-- for every matching row. Preserve the existing owner/staff semantics while
-- giving each command one composed policy.
drop policy runtime_editorial_read on argus_app.media_assets;
drop policy runtime_editorial_write on argus_app.media_assets;
create policy runtime_editorial_select on argus_app.media_assets
  for select to argus_runtime using (
    argus_private.has_staff_permission('editorial:read')
    or argus_private.has_staff_permission('editorial:write')
  );
create policy runtime_editorial_insert on argus_app.media_assets
  for insert to argus_runtime with check (
    argus_private.has_staff_permission('editorial:write')
  );
create policy runtime_editorial_update on argus_app.media_assets
  for update to argus_runtime
  using (argus_private.has_staff_permission('editorial:write'))
  with check (argus_private.has_staff_permission('editorial:write'));
create policy runtime_editorial_delete on argus_app.media_assets
  for delete to argus_runtime using (
    argus_private.has_staff_permission('editorial:write')
  );

drop policy runtime_editorial_read on argus_app.moderation_cases;
drop policy runtime_editorial_write on argus_app.moderation_cases;
create policy runtime_editorial_select on argus_app.moderation_cases
  for select to argus_runtime using (
    argus_private.has_staff_permission('editorial:read')
    or argus_private.has_staff_permission('editorial:write')
  );
create policy runtime_editorial_insert on argus_app.moderation_cases
  for insert to argus_runtime with check (
    argus_private.has_staff_permission('editorial:write')
  );
create policy runtime_editorial_update on argus_app.moderation_cases
  for update to argus_runtime
  using (argus_private.has_staff_permission('editorial:write'))
  with check (argus_private.has_staff_permission('editorial:write'));
create policy runtime_editorial_delete on argus_app.moderation_cases
  for delete to argus_runtime using (
    argus_private.has_staff_permission('editorial:write')
  );

drop policy runtime_owner on argus_app.privacy_requests;
drop policy runtime_staff_privacy_read on argus_app.privacy_requests;
drop policy runtime_staff_privacy_update on argus_app.privacy_requests;
create policy runtime_privacy_select on argus_app.privacy_requests
  for select to argus_runtime using (
    (select argus_private.request_user_id())=user_id
    or argus_private.has_staff_permission('privacy:read')
    or argus_private.has_staff_permission('privacy:write')
  );
create policy runtime_privacy_insert on argus_app.privacy_requests
  for insert to argus_runtime with check (
    (select argus_private.request_user_id())=user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id=privacy_requests.user_id
         and member.status='active'
         and member.deletion_epoch=privacy_requests.deletion_epoch
    )
  );
create policy runtime_privacy_update on argus_app.privacy_requests
  for update to argus_runtime using (
    (select argus_private.request_user_id())=user_id
    or argus_private.has_staff_permission('privacy:write')
  ) with check (
    (
      (select argus_private.request_user_id())=user_id
      and exists (
        select 1 from argus_app.members member
         where member.user_id=privacy_requests.user_id
           and member.status='active'
           and member.deletion_epoch=privacy_requests.deletion_epoch
      )
    )
    or argus_private.has_staff_permission('privacy:write')
  );
create policy runtime_privacy_delete on argus_app.privacy_requests
  for delete to argus_runtime using (
    (select argus_private.request_user_id())=user_id
  );

drop policy runtime_outbox_owner on argus_private.outbox_events;
drop policy runtime_staff_outbox_read on argus_private.outbox_events;
create policy runtime_outbox_select on argus_private.outbox_events
  for select to argus_runtime using (
    (user_id is not null and argus_private.request_user_id()=user_id)
    or argus_private.has_staff_permission('operations:read')
    or argus_private.has_staff_permission('operations:write')
  );
create policy runtime_outbox_insert on argus_private.outbox_events
  for insert to argus_runtime with check (
    user_id is not null
    and argus_private.request_user_id()=user_id
    and not exists (
      select 1 from argus_private.staff_principals staff
       where staff.user_id=argus_private.request_user_id()
         and staff.status='active'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id=outbox_events.user_id
         and member.status='active'
         and member.deletion_epoch=outbox_events.deletion_epoch
    )
  );
create policy runtime_outbox_update on argus_private.outbox_events
  for update to argus_runtime using (
    user_id is not null and argus_private.request_user_id()=user_id
  ) with check (
    user_id is not null
    and argus_private.request_user_id()=user_id
    and not exists (
      select 1 from argus_private.staff_principals staff
       where staff.user_id=argus_private.request_user_id()
         and staff.status='active'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id=outbox_events.user_id
         and member.status='active'
         and member.deletion_epoch=outbox_events.deletion_epoch
    )
  );
create policy runtime_outbox_delete on argus_private.outbox_events
  for delete to argus_runtime using (
    user_id is not null and argus_private.request_user_id()=user_id
  );

set local role argus_app_owner;
create index report_targets_asset_u8_fk_idx
  on argus_app.content_report_targets(asset_id);
create index report_targets_template_u8_fk_idx
  on argus_app.content_report_targets(circle_template_id);
create index report_targets_coven_u8_fk_idx
  on argus_app.content_report_targets(coven_entry_id);
create index report_targets_editorial_u8_fk_idx
  on argus_app.content_report_targets(editorial_item_id);
create index report_targets_grimoire_u8_fk_idx
  on argus_app.content_report_targets(grimoire_id);
create index saved_items_asset_u8_fk_idx
  on argus_app.member_saved_items(asset_id);
create index saved_items_template_u8_fk_idx
  on argus_app.member_saved_items(circle_template_id);
create index saved_items_coven_u8_fk_idx
  on argus_app.member_saved_items(coven_entry_id);
create index saved_items_grimoire_u8_fk_idx
  on argus_app.member_saved_items(grimoire_id);
create index saved_items_source_asset_u8_fk_idx
  on argus_app.member_saved_items(source_catalog_asset_id);
create index saved_items_source_editorial_u8_fk_idx
  on argus_app.member_saved_items(source_editorial_item_id);
create index saved_items_source_circle_u8_fk_idx
  on argus_app.member_saved_items(tenant_id,lifecycle_id,source_circle_id);
create index saved_items_source_ritual_u8_fk_idx
  on argus_app.member_saved_items(
    tenant_id,lifecycle_id,source_ritual_assignment_id
  );
drop policy u8_migration_quarantine_select
  on argus_app.legacy_normalization_quarantine;
drop policy u8_migration_quarantine_insert
  on argus_app.legacy_normalization_quarantine;
drop policy u8_migration_quarantine_update
  on argus_app.legacy_normalization_quarantine;
do $$
begin
  execute pg_catalog.format(
    'revoke select,insert,update on table argus_app.legacy_normalization_quarantine from %I',
    'postgres'
  );
end
$$;
set local role postgres;
revoke create on schema argus_private,argus_app from argus_app_owner;
do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_app_owner from %I',current_user
  );
end
$membership$;

commit;

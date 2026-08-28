-- U11: Supabase staff authorization and action-bound privileged operations.

begin;

alter table argus_app.editorial_revisions
  add column edit_version integer not null default 1 check (edit_version > 0);

create or replace function argus_private.enforce_editorial_revision_transition()
returns trigger
language plpgsql
security invoker
set search_path=pg_catalog,argus_private
as $$
begin
  if old.state='draft' and new.state='draft' then
    if not argus_private.has_staff_permission('editorial:write') then
      raise exception 'staff_permission_required' using errcode='42501';
    end if;
  elsif old.state='draft' and new.state='submitted' then
    if not argus_private.has_staff_permission('editorial:write') then
      raise exception 'staff_permission_required' using errcode='42501';
    end if;
  elsif old.state='submitted' and new.state in ('approved','rejected') then
    if not argus_private.has_staff_permission('editorial:review') then
      raise exception 'staff_permission_required' using errcode='42501';
    end if;
  elsif old.state='approved' and new.state='published'
     or old.state='published' and new.state='withdrawn' then
    if not argus_private.has_staff_permission('editorial:publish') then
      raise exception 'staff_permission_required' using errcode='42501';
    end if;
  end if;

  if new.id <> old.id
     or new.item_id <> old.item_id
     or new.revision_number <> old.revision_number
     or new.author_staff_id <> old.author_staff_id
     or new.created_at <> old.created_at then
    raise exception 'immutable_editorial_revision' using errcode='23514';
  end if;

  if old.state = 'draft' and new.state = 'draft' then
    if new.edit_version <> old.edit_version + 1 then
      raise exception 'editorial_revision_conflict' using errcode='40001';
    end if;
    return new;
  end if;

  if (old.state,new.state) not in (
       ('draft','submitted'),('submitted','approved'),
       ('submitted','rejected'),('approved','published'),
       ('published','withdrawn')
     )
     or new.payload <> old.payload
     or new.content_hash <> old.content_hash
     or new.edit_version <> old.edit_version then
    raise exception 'invalid_editorial_transition' using errcode='23514';
  end if;
  return new;
end
$$;

revoke all on function argus_private.enforce_editorial_revision_transition()
  from public,anon,authenticated;

create trigger enforce_editorial_revision_transition
  before update on argus_app.editorial_revisions
  for each row execute function argus_private.enforce_editorial_revision_transition();

create or replace function argus_private.enforce_editorial_item_transition()
returns trigger
language plpgsql
security invoker
set search_path=pg_catalog,argus_private
as $$
begin
  if new.id<>old.id or new.kind<>old.kind or new.slug<>old.slug
     or new.created_at<>old.created_at then
    raise exception 'immutable_editorial_item' using errcode='23514';
  end if;
  if not argus_private.has_staff_permission('editorial:publish')
     or (old.status,new.status) not in (
       ('draft','published'),('published','withdrawn')
     )
     or (new.status='published' and new.current_published_revision_id is null)
     or (new.status='withdrawn' and
         new.current_published_revision_id is distinct from old.current_published_revision_id) then
    raise exception 'invalid_editorial_item_transition' using errcode='23514';
  end if;
  return new;
end
$$;
revoke all on function argus_private.enforce_editorial_item_transition()
  from public,anon,authenticated;
create trigger enforce_editorial_item_transition
  before update on argus_app.editorial_items
  for each row execute function argus_private.enforce_editorial_item_transition();

create or replace function argus_private.enforce_editorial_review_request_update()
returns trigger
language plpgsql
security invoker
set search_path=pg_catalog,argus_private
as $$
begin
  if not argus_private.has_staff_permission('editorial:review')
     or new.id<>old.id or new.revision_id<>old.revision_id
     or new.requested_by<>old.requested_by
     or new.requested_at<>old.requested_at
     or new.high_trust<>old.high_trust
     or (old.status,new.status)<>('open','closed') then
    raise exception 'invalid_editorial_review_transition' using errcode='23514';
  end if;
  return new;
end
$$;
revoke all on function argus_private.enforce_editorial_review_request_update()
  from public,anon,authenticated;
create trigger enforce_editorial_review_request_update
  before update on argus_app.editorial_review_requests
  for each row execute function argus_private.enforce_editorial_review_request_update();

create or replace function argus_private.enforce_editorial_review_decision()
returns trigger
language plpgsql
security invoker
set search_path=pg_catalog,argus_private
as $$
declare
  request_high_trust boolean;
  revision_author uuid;
  request_status text;
begin
  select request.high_trust,revision.author_staff_id,request.status
    into request_high_trust,revision_author,request_status
    from argus_app.editorial_review_requests request
    join argus_app.editorial_revisions revision on revision.id=request.revision_id
   where request.id=new.request_id;
  if not argus_private.has_staff_permission('editorial:review')
     or new.reviewer_id<>argus_private.request_user_id()
     or request_status<>'open' then
    raise exception 'invalid_editorial_review_decision' using errcode='23514';
  end if;
  if request_high_trust and revision_author=new.reviewer_id then
    raise exception 'self_approval' using errcode='42501';
  end if;
  return new;
end
$$;
revoke all on function argus_private.enforce_editorial_review_decision()
  from public,anon,authenticated;
create trigger enforce_editorial_review_decision
  before insert on argus_app.editorial_review_decisions
  for each row execute function argus_private.enforce_editorial_review_decision();

create policy runtime_editorial_review_publish_item_read
  on argus_app.editorial_items for select to argus_runtime
  using (
    argus_private.has_staff_permission('editorial:review')
    or argus_private.has_staff_permission('editorial:publish')
  );
create policy runtime_editorial_publish_item_update
  on argus_app.editorial_items for update to argus_runtime
  using (argus_private.has_staff_permission('editorial:publish'))
  with check (argus_private.has_staff_permission('editorial:publish'));
create policy runtime_editorial_review_publish_revision_read
  on argus_app.editorial_revisions for select to argus_runtime
  using (
    argus_private.has_staff_permission('editorial:review')
    or argus_private.has_staff_permission('editorial:publish')
  );
create policy runtime_editorial_review_publish_revision_update
  on argus_app.editorial_revisions for update to argus_runtime
  using (
    argus_private.has_staff_permission('editorial:review')
    or argus_private.has_staff_permission('editorial:publish')
  )
  with check (
    argus_private.has_staff_permission('editorial:review')
    or argus_private.has_staff_permission('editorial:publish')
  );
create policy runtime_editorial_reviewer_request
  on argus_app.editorial_review_requests for select to argus_runtime
  using (argus_private.has_staff_permission('editorial:review'));
create policy runtime_editorial_reviewer_request_update
  on argus_app.editorial_review_requests for update to argus_runtime
  using (argus_private.has_staff_permission('editorial:review'))
  with check (argus_private.has_staff_permission('editorial:review'));
create policy runtime_editorial_reviewer_decision_insert
  on argus_app.editorial_review_decisions for insert to argus_runtime
  with check (
    argus_private.has_staff_permission('editorial:review')
    and reviewer_id=argus_private.request_user_id()
  );
create policy runtime_editorial_publisher_event_insert
  on argus_app.publication_events for insert to argus_runtime
  with check (
    argus_private.has_staff_permission('editorial:publish')
    and actor_id=argus_private.request_user_id()
  );

create or replace function argus_private.create_editorial_kind_link(
  p_kind text,
  p_item_id uuid,
  p_payload jsonb
)
returns void
language plpgsql
security invoker
set search_path=pg_catalog,argus_private
as $$
begin
  if not argus_private.has_staff_permission('editorial:write')
     or jsonb_typeof(p_payload)<>'object' then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  if p_kind='ritual' then
    if p_payload->>'scenario_key' is null
       or p_payload->>'mode' not in ('tarot','astrology')
       or nullif(p_payload->>'cadence','') is null then
      raise exception 'invalid_editorial_payload' using errcode='23514';
    end if;
    insert into argus_app.ritual_scenarios(
      editorial_item_id,scenario_key,mode,cadence
    ) values (
      p_item_id,p_payload->>'scenario_key',p_payload->>'mode',p_payload->>'cadence'
    );
  elsif p_kind='rowan' then
    if nullif(p_payload->>'script_key','') is null
       or nullif(p_payload->>'surface','') is null then
      raise exception 'invalid_editorial_payload' using errcode='23514';
    end if;
    insert into argus_app.rowan_scripts(editorial_item_id,script_key,surface)
    values (p_item_id,p_payload->>'script_key',p_payload->>'surface');
  elsif p_kind='coven' then
    if coalesce(p_payload->>'company_id','')
       !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
      raise exception 'invalid_editorial_payload' using errcode='23514';
    end if;
    insert into argus_app.coven_entries(editorial_item_id,company_id)
    values (p_item_id,(p_payload->>'company_id')::uuid);
  elsif p_kind='grimoire' then
    if nullif(p_payload->>'theme_code','') is null then
      raise exception 'invalid_editorial_payload' using errcode='23514';
    end if;
    insert into argus_app.grimoires(editorial_item_id,theme_code,asset_ids)
    select p_item_id,p_payload->>'theme_code',
      coalesce(array_agg(value::uuid order by ordinal) filter (where value is not null),'{}'::uuid[])
      from jsonb_array_elements_text(coalesce(p_payload->'asset_ids','[]'::jsonb))
           with ordinality asset(value,ordinal);
  elsif p_kind='circle_template' then
    if nullif(p_payload->>'creator_label','') is null
       or nullif(p_payload->>'title','') is null
       or nullif(p_payload->>'description','') is null then
      raise exception 'invalid_editorial_payload' using errcode='23514';
    end if;
    insert into argus_app.community_templates(
      editorial_item_id,creator_label,title,description,asset_ids
    )
    select p_item_id,p_payload->>'creator_label',p_payload->>'title',
      p_payload->>'description',
      coalesce(array_agg(value::uuid order by ordinal) filter (where value is not null),'{}'::uuid[])
      from jsonb_array_elements_text(coalesce(p_payload->'asset_ids','[]'::jsonb))
           with ordinality asset(value,ordinal);
  elsif p_kind in ('asset_codex','briefing_template') then
    if nullif(p_payload->>'title','') is null then
      raise exception 'invalid_editorial_payload' using errcode='23514';
    end if;
  else
    raise exception 'invalid_editorial_kind' using errcode='23514';
  end if;
end
$$;
revoke all on function argus_private.create_editorial_kind_link(text,uuid,jsonb)
  from public,anon,authenticated;
grant execute on function argus_private.create_editorial_kind_link(text,uuid,jsonb)
  to argus_runtime;

create or replace function argus_private.materialize_editorial_revision(
  p_kind text,
  p_revision_id uuid,
  p_payload jsonb
)
returns void
language plpgsql
security invoker
set search_path=pg_catalog,argus_private
as $$
declare
  idea_ids uuid[];
  evidence_ids uuid[];
begin
  if not argus_private.has_staff_permission('editorial:write')
     or jsonb_typeof(p_payload)<>'object' then
    raise exception 'invalid_editorial_payload' using errcode='23514';
  end if;
  if p_kind='ritual' then
    if nullif(p_payload->>'title','') is null
       or nullif(p_payload->>'interpretation','') is null
       or nullif(p_payload->>'guidance','') is null
       or nullif(p_payload->>'market_label','') is null
       or nullif(p_payload->>'uncertainty','') is null
       or coalesce(jsonb_typeof(p_payload->'idea_asset_ids'),'null')<>'array'
       or coalesce(jsonb_typeof(p_payload->'evidence_claim_ids'),'null')<>'array'
       or jsonb_array_length(p_payload->'idea_asset_ids') not between 3 and 5
       or jsonb_array_length(p_payload->'evidence_claim_ids')<1 then
      raise exception 'invalid_editorial_payload' using errcode='23514';
    end if;
    select array_agg(value::uuid order by ordinal) into idea_ids
      from jsonb_array_elements_text(p_payload->'idea_asset_ids')
           with ordinality idea(value,ordinal);
    select array_agg(value::uuid order by ordinal) into evidence_ids
      from jsonb_array_elements_text(p_payload->'evidence_claim_ids')
           with ordinality evidence(value,ordinal);
    if (select count(*) from argus_app.catalog_assets asset
         where asset.id=any(idea_ids) and asset.status='active')
         <> cardinality(idea_ids)
       or (select count(*) from argus_app.evidence_claims claim
            where claim.id=any(evidence_ids) and claim.status='active')
         <> cardinality(evidence_ids) then
      raise exception 'invalid_editorial_evidence' using errcode='23514';
    end if;
    insert into argus_app.ritual_scenario_revisions(
      revision_id,title,interpretation,guidance,market_label,observation_at,
      uncertainty,idea_asset_ids,evidence_claim_ids
    ) values (
      p_revision_id,p_payload->>'title',p_payload->>'interpretation',
      p_payload->>'guidance',p_payload->>'market_label',
      (p_payload->>'observation_at')::timestamptz,p_payload->>'uncertainty',
      idea_ids,evidence_ids
    );
  elsif p_kind='rowan' then
    if nullif(p_payload->>'body_template','') is null
       or nullif(p_payload->>'risk_footer','') is null
       or coalesce(jsonb_typeof(p_payload->'allowed_tokens'),'null')<>'array'
       or p_payload->>'body_template' ~* '(urgent|exclusive|only I|guarantee|must invest|act now|love you|jealous)' then
      raise exception 'invalid_editorial_payload' using errcode='23514';
    end if;
    insert into argus_app.rowan_script_revisions(
      revision_id,body_template,allowed_tokens,risk_footer
    ) values (
      p_revision_id,p_payload->>'body_template',p_payload->'allowed_tokens',
      p_payload->>'risk_footer'
    );
  elsif p_kind not in (
    'asset_codex','coven','grimoire','circle_template','briefing_template'
  ) then
    raise exception 'invalid_editorial_kind' using errcode='23514';
  end if;
end
$$;
revoke all on function argus_private.materialize_editorial_revision(text,uuid,jsonb)
  from public,anon,authenticated;
grant execute on function argus_private.materialize_editorial_revision(text,uuid,jsonb)
  to argus_runtime;

create table argus_private.staff_step_up_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null,
  action text not null check (action in ('admin_job_retry','admin_privacy_retry')),
  target_id uuid not null,
  receipt_hash text not null unique check (receipt_hash ~ '^[a-f0-9]{64}$'),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

alter table argus_private.staff_step_up_receipts enable row level security;
alter table argus_private.staff_step_up_receipts force row level security;
create policy runtime_staff_step_up_owner
  on argus_private.staff_step_up_receipts for all to argus_runtime
  using (
    user_id=argus_private.request_user_id()
    and case action
          when 'admin_job_retry' then argus_private.has_staff_permission('operations:write')
          when 'admin_privacy_retry' then argus_private.has_staff_permission('privacy:write')
          else false
        end
  )
  with check (
    user_id=argus_private.request_user_id()
    and case action
          when 'admin_job_retry' then argus_private.has_staff_permission('operations:write')
          when 'admin_privacy_retry' then argus_private.has_staff_permission('privacy:write')
          else false
        end
    and current_setting('request.jwt.claims',true)::jsonb->>'aal'='aal2'
  );
grant select,insert,update on argus_private.staff_step_up_receipts to argus_runtime;
revoke all on argus_private.staff_step_up_receipts from public,anon,authenticated;

create or replace function argus_private.has_live_staff_session(
  p_user_id uuid,
  p_session_id uuid
)
returns boolean
language sql
stable
security definer
set search_path=pg_catalog,argus_private
as $$
  select p_user_id=argus_private.request_user_id()
     and auth.uid()=p_user_id
     and exists (
       select 1 from auth.sessions session
        where session.id=p_session_id and session.user_id=p_user_id
     )
$$;
revoke all on function argus_private.has_live_staff_session(uuid,uuid)
  from public,anon,authenticated;
grant execute on function argus_private.has_live_staff_session(uuid,uuid)
  to argus_runtime;

create or replace function argus_private.consume_staff_step_up(
  p_receipt_hash text,
  p_session_id uuid,
  p_action text,
  p_target_id uuid
)
returns boolean
language plpgsql
security invoker
set search_path=pg_catalog,argus_private
as $$
declare consumed_id uuid;
begin
  if current_setting('request.jwt.claims',true)::jsonb->>'aal' <> 'aal2'
     or not argus_private.has_live_staff_session(
       argus_private.request_user_id(),p_session_id
     )
     or not case p_action
       when 'admin_job_retry' then argus_private.has_staff_permission('operations:write')
       when 'admin_privacy_retry' then argus_private.has_staff_permission('privacy:write')
       else false
     end then
    return false;
  end if;
  update argus_private.staff_step_up_receipts receipt
     set consumed_at=clock_timestamp()
   where receipt.receipt_hash=p_receipt_hash
     and receipt.user_id=argus_private.request_user_id()
     and receipt.session_id=p_session_id
     and receipt.action=p_action
     and receipt.target_id=p_target_id
     and receipt.consumed_at is null
     and receipt.expires_at > clock_timestamp()
  returning receipt.id into consumed_id;
  return consumed_id is not null;
end
$$;

revoke all on function argus_private.consume_staff_step_up(text,uuid,text,uuid)
  from public,anon,authenticated;
grant execute on function argus_private.consume_staff_step_up(text,uuid,text,uuid)
  to argus_runtime;

drop policy if exists runtime_staff_outbox_insert
  on argus_private.outbox_events;
drop function if exists argus_private.request_admin_job_retry(uuid,text);

-- Staff identities never receive direct outbox insertion authority. Member
-- event creation remains owner-scoped for non-staff sessions; sensitive staff
-- retries can cross this boundary only through the two validated functions
-- below.
drop policy if exists runtime_outbox_owner on argus_private.outbox_events;
create policy runtime_outbox_owner on argus_private.outbox_events
  for all to argus_runtime
  using (
    user_id is not null
    and argus_private.request_user_id()=user_id
  )
  with check (
    user_id is not null
    and argus_private.request_user_id()=user_id
    and not exists (
      select 1 from argus_private.staff_principals staff
       where staff.user_id=argus_private.request_user_id()
         and staff.status='active'
    )
    and exists (
      select 1 from argus_app.members member
       where member.user_id=argus_private.outbox_events.user_id
         and member.status='active'
         and member.deletion_epoch=argus_private.outbox_events.deletion_epoch
    )
  );

create or replace function argus_private.request_admin_job_retry(
  p_job_id uuid,
  p_dedupe_key text,
  p_receipt_hash text,
  p_session_id uuid
)
returns uuid
language plpgsql
security definer
set search_path=pg_catalog,argus_private
as $$
declare
  source_event argus_private.outbox_events%rowtype;
  requested_job argus_private.job_runs%rowtype;
  event_id uuid;
begin
  if not argus_private.consume_staff_step_up(
    p_receipt_hash,p_session_id,'admin_job_retry',p_job_id
  ) then
    raise exception 'step_up_required' using errcode='42501';
  end if;

  if p_dedupe_key !~ '^[!-~]{16,128}$' then
    raise exception 'invalid_retry_dedupe_key';
  end if;

  select job.* into requested_job
    from argus_private.job_runs job
   where job.id=p_job_id and job.status='dead_lettered'
   for update;
  if requested_job.id is null or requested_job.source_event_id is null then
    raise exception 'job_not_retryable';
  end if;

  select event.* into source_event
    from argus_private.outbox_events event
   where event.id=requested_job.source_event_id
     and argus_private.retained_job_handler(event.event_type)=requested_job.handler_name
     and (
       (event.topic='argus_jobs' and event.event_type in (
         'briefing.daily.requested','briefing.weekly.requested',
         'briefing.moon_cycle.requested','briefing.daily.generated',
         'briefing.weekly.generated','briefing.moon_cycle.generated',
         'media.scan.requested','media.quarantine.cleanup',
         'content-report.created','privacy.export.requested',
         'privacy.deletion.requested','privacy.export.retention.requested'
       )) or
       (event.topic='brokerage_refresh' and event.event_type in (
         'webull.token.refresh.requested','webull.projection.refresh.requested'
       )) or
       (event.topic='brokerage_reconcile'
         and event.event_type='webull.command.reconciliation.requested')
     );
  if source_event.id is null then
    raise exception 'job_not_retryable';
  end if;

  -- A terminal PGMQ message is already archived/deleted. Republishing the
  -- original retained source event under a new outbox identity gives the
  -- existing handler one bounded fresh run without inventing financial
  -- authority or reviving an in-flight queue lease.
  insert into argus_private.outbox_events(
    user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
  ) values (
    source_event.user_id,source_event.deletion_epoch,source_event.topic,
    source_event.event_type,source_event.aggregate_id,p_dedupe_key
  ) returning id into event_id;
  return event_id;
end
$$;
alter function argus_private.request_admin_job_retry(uuid,text,text,uuid)
  owner to postgres;
revoke all on function argus_private.request_admin_job_retry(uuid,text,text,uuid)
  from public,anon,authenticated;
grant execute on function argus_private.request_admin_job_retry(uuid,text,text,uuid)
  to argus_runtime;

create or replace function argus_private.request_admin_privacy_retry(
  p_request_id uuid,
  p_dedupe_key text,
  p_receipt_hash text,
  p_session_id uuid
)
returns uuid
language plpgsql
security definer
set search_path=pg_catalog,argus_private
as $$
declare
  requested_privacy argus_app.privacy_requests%rowtype;
  tombstone_id uuid;
  retained_event_type text;
  retained_aggregate_id uuid;
  retained_user_id uuid;
  retained_deletion_epoch bigint;
  event_id uuid;
begin
  if not argus_private.consume_staff_step_up(
    p_receipt_hash,p_session_id,'admin_privacy_retry',p_request_id
  ) then
    raise exception 'step_up_required' using errcode='42501';
  end if;

  select * into requested_privacy
    from argus_app.privacy_requests request
   where request.id=p_request_id and request.status='failed'
   for update;
  if requested_privacy.id is null then
    raise exception 'privacy_request_not_retryable';
  end if;

  if p_dedupe_key !~ '^[!-~]{16,128}$' then
    raise exception 'invalid_retry_dedupe_key';
  end if;

  if requested_privacy.request_type='export' then
    retained_event_type := 'privacy.export.requested';
    retained_aggregate_id := requested_privacy.id;
    retained_user_id := requested_privacy.user_id;
    retained_deletion_epoch := requested_privacy.deletion_epoch;
  elsif requested_privacy.request_type='deletion' then
    select tombstone.id into tombstone_id
      from argus_private.deletion_tombstones tombstone
     where tombstone.user_id=requested_privacy.user_id
       and tombstone.deletion_epoch=requested_privacy.deletion_epoch
       and tombstone.status in ('pending','purging','failed')
     for update;
    if tombstone_id is null then
      raise exception 'privacy_request_not_retryable';
    end if;
    retained_event_type := 'privacy.deletion.requested';
    retained_aggregate_id := tombstone_id;
    -- Deletion work survives member/auth deletion and is owner-fenced through
    -- the private tombstone, exactly like the original deletion event.
    retained_user_id := null;
    retained_deletion_epoch := null;
  else
    raise exception 'privacy_request_not_retryable';
  end if;

  if argus_private.retained_job_handler(retained_event_type) is null then
    raise exception 'privacy_retry_handler_unavailable';
  end if;

  update argus_app.privacy_requests
     set status='queued',failure_code=null,completed_at=null
   where id=p_request_id;
  insert into argus_private.outbox_events(
    user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
  ) values (
    retained_user_id,retained_deletion_epoch,'argus_jobs',retained_event_type,
    retained_aggregate_id,p_dedupe_key
  ) returning id into event_id;
  return event_id;
end
$$;
alter function argus_private.request_admin_privacy_retry(uuid,text,text,uuid)
  owner to postgres;
revoke all on function argus_private.request_admin_privacy_retry(uuid,text,text,uuid)
  from public,anon,authenticated;
grant execute on function argus_private.request_admin_privacy_retry(uuid,text,text,uuid)
  to argus_runtime;

create policy runtime_staff_connection_diagnostics
  on argus_brokerage.connections for select to argus_runtime
  using (argus_private.has_staff_permission('brokerage:read'));
create policy runtime_staff_command_diagnostics
  on argus_private.provider_commands for select to argus_runtime
  using (argus_private.has_staff_permission('brokerage:read'));
create policy runtime_staff_reconciliation_diagnostics
  on argus_private.reconciliation_records for select to argus_runtime
  using (argus_private.has_staff_permission('brokerage:read'));

create or replace function argus_private.admin_diagnostic_correlation(
  p_kind text,
  p_id uuid
)
returns text
language plpgsql
immutable
security definer
set search_path=pg_catalog,extensions
as $$
begin
  if p_kind not in ('connection_health','provider_command','reconciliation') then
    raise exception 'invalid_diagnostic_kind' using errcode='22023';
  end if;
  return 'diag_' || left(
    encode(extensions.digest(p_kind || ':' || p_id::text,'sha256'),'hex'),24
  );
end
$$;
alter function argus_private.admin_diagnostic_correlation(text,uuid)
  owner to postgres;
revoke all on function argus_private.admin_diagnostic_correlation(text,uuid)
  from public,anon,authenticated;
grant execute on function argus_private.admin_diagnostic_correlation(text,uuid)
  to argus_runtime;

comment on table argus_private.staff_step_up_receipts is
  'One-use Supabase AAL2 staff receipts bound to the current user, session, action, and target.';

commit;

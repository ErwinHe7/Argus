-- Isolated paper-strategy state. No brokerage credentials, grants, or order API.
create table argus_app.strategy_records (
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  kind text not null check (kind in ('configuration','deployment','device','research_run','evidence','control','pairing','idempotency','device_credential','explanation')),
  id uuid not null,
  body jsonb not null check (jsonb_typeof(body)='object' and body->>'id'=id::text),
  created_at timestamptz not null default clock_timestamp(),
  primary key(owner_user_id,kind,id)
);
create index strategy_records_owner on argus_app.strategy_records(owner_user_id,created_at,id);
create index strategy_records_recent_kind on argus_app.strategy_records(owner_user_id,kind,created_at desc,id desc);
create index strategy_current_mandates on argus_app.strategy_records(owner_user_id) where kind='deployment' and (body->>'state'<>'retired' or body->>'retiredAcknowledgedAt' is null);
create index strategy_control_revision on argus_app.strategy_records(owner_user_id,(body->>'deploymentId'),(body->>'mandateVersion')) where kind='control';
create index strategy_latest_health on argus_app.strategy_records(owner_user_id,(body->>'deploymentId'),(body->>'kind'),created_at desc,id desc) where kind='evidence';
create unique index strategy_evidence_sequence on argus_app.strategy_records(owner_user_id,(body->>'deploymentId'),(body->>'sequence')) where kind='evidence';
create unique index strategy_pair_token on argus_app.strategy_records((body->>'tokenHash')) where kind='pairing';
create unique index strategy_device_identifier on argus_app.strategy_records(id) where kind='device_credential';
create unique index strategy_account_deployment on argus_app.strategy_records(owner_user_id,(body->>'accountId')) where kind='deployment' and (body->>'state'<>'retired' or body->>'retiredAcknowledgedAt' is null);
alter table argus_app.strategy_records enable row level security;
alter table argus_app.strategy_records force row level security;
revoke all on argus_app.strategy_records from public,anon,authenticated,argus_runtime,argus_callback,argus_public_preview,argus_edge;
grant select,insert,update on argus_app.strategy_records to argus_member;
create policy strategy_member_records on argus_app.strategy_records to argus_member
using (kind<>'device_credential' and owner_user_id=(select argus_private.trusted_request_user_id()) and tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()))
with check (kind<>'device_credential' and owner_user_id=(select argus_private.trusted_request_user_id()) and tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()));

-- Signed but revoked browser sessions must not retain strategy control.
create function argus_private.strategy_has_live_session() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from argus_private.read_trusted_request_context() c
 join auth.sessions s on s.id=c.session_id and s.user_id=c.user_id
 join argus_app.members m on m.user_id=c.user_id and m.lifecycle_id=c.lifecycle_id
 where m.status='active' and (s.not_after is null or s.not_after>now()))
$$;
revoke all on function argus_private.strategy_has_live_session() from public,anon,authenticated;
grant execute on function argus_private.strategy_has_live_session() to argus_member;

create function argus_private.strategy_immutable_evidence() returns trigger
language plpgsql set search_path='' as $$
begin
 if old.kind in ('configuration','evidence','idempotency','explanation') and old.body is distinct from new.body then
  raise exception 'immutable_strategy_record' using errcode='23000';
 end if;
 if old.owner_user_id<>new.owner_user_id or old.tenant_id<>new.tenant_id or old.lifecycle_id<>new.lifecycle_id or old.id<>new.id or old.kind<>new.kind then
  raise exception 'immutable_strategy_identity' using errcode='23000';
 end if;
 return new;
end $$;
create trigger strategy_immutable_evidence before update on argus_app.strategy_records
for each row execute function argus_private.strategy_immutable_evidence();
revoke all on function argus_private.strategy_immutable_evidence() from public,anon,authenticated;

-- Capability lookup is deliberately private and executable only by the Edge login.
-- Before a member context exists, the 256-bit hashed one-use pairing token is the
-- authority. The lookup verifies its bound active lifecycle and live Auth session.
create function argus_private.strategy_redeem_pairing(p_hash text,p_device uuid,p_token_hash text,p_name text,p_platform text,p_now timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare pairing argus_app.strategy_records%rowtype; device jsonb; credential jsonb; stamp timestamptz:=clock_timestamp();
begin
 if p_hash !~ '^[a-f0-9]{64}$' or p_token_hash !~ '^[a-f0-9]{64}$' or length(p_name) not between 1 and 80 or p_platform not in ('windows','macos','linux') then return null; end if;
 select r.* into pairing from argus_app.strategy_records r
 where r.kind='pairing' and r.body->>'tokenHash'=p_hash;
 if pairing.id is null then return null; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('strategy:' || pairing.owner_user_id::text,0));
 select r.* into pairing from argus_app.strategy_records r
 where r.kind='pairing' and r.body->>'tokenHash'=p_hash for update;
 if pairing.id is null or pairing.body->>'consumedAt' is not null or (pairing.body->>'expiresAt')::timestamptz<=stamp then return null; end if;
 if not exists(select 1 from auth.sessions s join argus_app.members m on m.user_id=s.user_id
 join argus_app.member_lifecycles l on l.id=m.lifecycle_id and l.tenant_id=m.tenant_id
 where s.id=(pairing.body->>'sessionId')::uuid and s.user_id=pairing.owner_user_id
 and m.lifecycle_id=pairing.lifecycle_id and m.tenant_id=pairing.tenant_id and m.status='active' and l.state='open'
 and (s.not_after is null or s.not_after>stamp)) then return null; end if;
 if (select count(*) from argus_app.strategy_records where owner_user_id=pairing.owner_user_id and kind='device')>=20 then return null; end if;
 device:=jsonb_build_object('schemaVersion','leo.connector-device.v1','id',p_device,'name',p_name,'platform',p_platform,'accounts','[]'::jsonb,'createdAt',stamp,'lastSeenAt',null,'revokedAt',null,'lastSequence',0,'instanceId',null);
 credential:=jsonb_build_object('id',p_device,'tokenHash',p_token_hash,'sessionId',pairing.body->>'sessionId','aal',pairing.body->>'aal','expiresAt',stamp+interval '30 days');
 insert into argus_app.strategy_records(owner_user_id,tenant_id,lifecycle_id,kind,id,body) values
 (pairing.owner_user_id,pairing.tenant_id,pairing.lifecycle_id,'device',p_device,device),
 (pairing.owner_user_id,pairing.tenant_id,pairing.lifecycle_id,'device_credential',p_device,credential);
 update argus_app.strategy_records set body=jsonb_set(body,'{consumedAt}',to_jsonb(stamp)) where owner_user_id=pairing.owner_user_id and kind='pairing' and id=pairing.id;
 return device;
end $$;
revoke all on function argus_private.strategy_redeem_pairing(text,uuid,text,text,text,timestamptz) from public,anon,authenticated,argus_member,argus_runtime;
grant execute on function argus_private.strategy_redeem_pairing(text,uuid,text,text,text,timestamptz) to argus_edge;

create function argus_private.strategy_device_principal(p_id uuid,p_hash text)
returns table(user_id uuid,session_id uuid,aal text) language sql stable security definer set search_path='' as $$
 select c.owner_user_id,(c.body->>'sessionId')::uuid,c.body->>'aal'
 from argus_app.strategy_records c
 join argus_app.strategy_records d on d.owner_user_id=c.owner_user_id and d.kind='device' and d.id=c.id
 join auth.sessions s on s.id=(c.body->>'sessionId')::uuid and s.user_id=c.owner_user_id
 join argus_app.members m on m.user_id=c.owner_user_id and m.tenant_id=c.tenant_id and m.lifecycle_id=c.lifecycle_id
 join argus_app.member_lifecycles l on l.id=c.lifecycle_id and l.tenant_id=c.tenant_id
 where c.kind='device_credential' and c.id=p_id and p_hash ~ '^[a-f0-9]{64}$' and c.body->>'tokenHash'=p_hash
 and (c.body->>'expiresAt')::timestamptz>now() and d.body->>'revokedAt' is null
 and m.status='active' and l.state='open' and (s.not_after is null or s.not_after>now())
$$;
revoke all on function argus_private.strategy_device_principal(uuid,text) from public,anon,authenticated,argus_member,argus_runtime;
grant execute on function argus_private.strategy_device_principal(uuid,text) to argus_edge;
comment on table argus_app.strategy_records is 'Private owner/lifecycle-scoped paper strategy records. Browser Data API access is prohibited; quantitative calculations and brokerage execution remain in the local Rust connector.';

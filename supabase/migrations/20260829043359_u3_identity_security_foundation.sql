begin;

-- U3 adds the identity/security foundation without binding the U4-U6 domain
-- relations prematurely. The retained argus_runtime/argus_worker grants and
-- enforce_live_member_epoch triggers remain compatibility surfaces until each
-- owning domain replaces its deletion_epoch columns with lifecycle FKs.

do $$
begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname='argus_identity_owner') then
    create role argus_identity_owner
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_catalog.pg_roles where rolname='argus_member') then
    create role argus_member
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_catalog.pg_roles where rolname='argus_staff') then
    create role argus_staff
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_catalog.pg_roles where rolname='argus_callback') then
    create role argus_callback
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_catalog.pg_roles where rolname='argus_migration') then
    create role argus_migration
      nologin noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
end
$$;

alter role argus_member set statement_timeout='15s';
alter role argus_member set lock_timeout='3s';
alter role argus_member set idle_in_transaction_session_timeout='15s';
alter role argus_staff set statement_timeout='15s';
alter role argus_staff set lock_timeout='3s';
alter role argus_staff set idle_in_transaction_session_timeout='15s';
alter role argus_callback set statement_timeout='15s';
alter role argus_callback set lock_timeout='3s';
alter role argus_callback set idle_in_transaction_session_timeout='15s';

grant argus_member,argus_staff to argus_edge;

grant usage on schema argus_app,argus_private to argus_member,argus_staff;
grant usage on schema argus_private to argus_callback;
grant usage on schema argus_app,argus_private,extensions to argus_identity_owner;
grant usage on schema argus_private to argus_edge;

-- Migrations run as the project migration owner, so its defaults are the only
-- defaults this artifact may change. The NOLOGIN identity owner never creates
-- objects directly; every owner transfer below is explicit and signature-bound.
alter default privileges in schema argus_app
  revoke all on tables from public,anon,authenticated;
alter default privileges in schema argus_private
  revoke all on tables from public,anon,authenticated;
alter default privileges in schema argus_app
  revoke execute on functions from public,anon,authenticated;
alter default privileges in schema argus_brokerage
  revoke execute on functions from public,anon,authenticated;
alter default privileges in schema argus_private
  revoke execute on functions from public,anon,authenticated;

create table argus_app.member_lifecycles (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  identity_subject_id uuid not null unique,
  state text not null default 'open' check (state in ('open','closed')),
  opened_at timestamptz not null default pg_catalog.clock_timestamp(),
  closed_at timestamptz,
  close_reason text,
  unique (tenant_id,id),
  unique (identity_subject_id,id),
  check (
    (state='open' and closed_at is null and close_reason is null)
    or (state='closed' and closed_at is not null
      and close_reason is not null and pg_catalog.char_length(close_reason) between 1 and 128)
  )
);

alter table argus_app.member_lifecycles enable row level security;
alter table argus_app.member_lifecycles force row level security;
revoke all on argus_app.member_lifecycles from public,anon,authenticated;

insert into argus_app.member_lifecycles(
  id,tenant_id,identity_subject_id,state,opened_at,closed_at,close_reason
)
select
  extensions.gen_random_uuid(),member.user_id,member.user_id,
  case when member.status in ('deletion_pending','purging','purged')
    then 'closed' else 'open' end,
  member.created_at,
  case when member.status in ('deletion_pending','purging','purged')
    then coalesce(member.deletion_requested_at,member.updated_at)
    else null end,
  case when member.status in ('deletion_pending','purging','purged')
    then 'legacy-deletion-state' else null end
from argus_app.members member;

alter table argus_app.members
  add column tenant_id uuid,
  add column lifecycle_id uuid;

update argus_app.members member
   set tenant_id=lifecycle.tenant_id,
       lifecycle_id=lifecycle.id
  from argus_app.member_lifecycles lifecycle
 where lifecycle.identity_subject_id=member.user_id;

alter table argus_app.members
  alter column tenant_id set not null,
  alter column lifecycle_id set not null,
  add constraint members_tenant_lifecycle_unique unique (tenant_id,lifecycle_id),
  add constraint members_subject_lifecycle_unique unique (user_id,lifecycle_id),
  add constraint members_tenant_lifecycle_fk
    foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  add constraint members_subject_lifecycle_fk
    foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict;

create or replace function argus_private.protect_member_lifecycle_binding()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
begin
  if new.tenant_id is distinct from old.tenant_id
     or new.lifecycle_id is distinct from old.lifecycle_id
     or new.user_id is distinct from old.user_id then
    raise exception 'member_lifecycle_binding_immutable' using errcode='23514';
  end if;
  return new;
end
$$;

create trigger protect_member_lifecycle_binding
  before update on argus_app.members
  for each row execute function argus_private.protect_member_lifecycle_binding();

create or replace function argus_private.bind_member_lifecycle_on_insert()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
begin
  if new.tenant_id is null or new.lifecycle_id is null then
    select lifecycle.tenant_id,lifecycle.id
      into new.tenant_id,new.lifecycle_id
      from argus_app.member_lifecycles lifecycle
     where lifecycle.identity_subject_id=new.user_id
       and lifecycle.state='open';
  end if;
  if new.tenant_id is null or new.lifecycle_id is null then
    raise exception 'member_lifecycle_required' using errcode='23503';
  end if;
  return new;
end
$$;

create trigger bind_member_lifecycle_on_insert
  before insert on argus_app.members
  for each row execute function argus_private.bind_member_lifecycle_on_insert();

create or replace function argus_private.protect_member_lifecycle_immutable()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
begin
  if new.id is distinct from old.id
     or new.tenant_id is distinct from old.tenant_id
     or new.identity_subject_id is distinct from old.identity_subject_id
     or new.opened_at is distinct from old.opened_at then
    raise exception 'member_lifecycle_identity_immutable' using errcode='23514';
  end if;
  if old.state='closed' and new is distinct from old then
    raise exception 'member_lifecycle_already_closed' using errcode='23514';
  end if;
  if old.state='open' and new.state='open'
     and (new.closed_at is not null or new.close_reason is not null) then
    raise exception 'invalid_member_lifecycle_transition' using errcode='23514';
  end if;
  return new;
end
$$;

create trigger protect_member_lifecycle_immutable
  before update on argus_app.member_lifecycles
  for each row execute function argus_private.protect_member_lifecycle_immutable();

create policy identity_lifecycle_read on argus_app.member_lifecycles
  for select to argus_identity_owner using (true);
create policy identity_lifecycle_insert on argus_app.member_lifecycles
  for insert to argus_identity_owner
  with check (tenant_id=identity_subject_id and state='open');
create policy identity_lifecycle_close on argus_app.member_lifecycles
  for update to argus_identity_owner
  using (state='open')
  with check (state='closed' and closed_at is not null and close_reason is not null);

create policy identity_member_read on argus_app.members
  for select to argus_identity_owner using (true);
create policy identity_member_insert on argus_app.members
  for insert to argus_identity_owner
  with check (
    tenant_id=user_id and exists (
      select 1 from argus_app.member_lifecycles lifecycle
       where lifecycle.id=members.lifecycle_id
         and lifecycle.tenant_id=members.tenant_id
         and lifecycle.identity_subject_id=members.user_id
         and lifecycle.state='open'
    )
  );

grant select,insert on argus_app.members to argus_identity_owner;

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'profiles','preferences','onboarding_states','notification_preferences'
  ] loop
    execute pg_catalog.format(
      'create policy identity_provision_insert on argus_app.%I for insert to argus_identity_owner with check (exists (select 1 from argus_app.members member where member.user_id=%I.user_id and member.status=''active''))',
      relation_name,relation_name
    );
    execute pg_catalog.format(
      'create policy identity_provision_read on argus_app.%I for select to argus_identity_owner using (true)',
      relation_name
    );
  end loop;
end
$$;

grant select,insert on
  argus_app.profiles,
  argus_app.preferences,
  argus_app.onboarding_states,
  argus_app.notification_preferences
to argus_identity_owner;

create or replace function argus_private.close_member_lifecycle(
  p_lifecycle_id uuid,
  p_reason text
)
returns void
language plpgsql
security invoker
set search_path=''
as $$
begin
  if p_reason is null or pg_catalog.char_length(p_reason) not between 1 and 128 then
    raise exception 'invalid_lifecycle_close_reason' using errcode='22023';
  end if;

  update argus_app.member_lifecycles lifecycle
     set state='closed',closed_at=pg_catalog.clock_timestamp(),close_reason=p_reason
   where lifecycle.id=p_lifecycle_id and lifecycle.state='open';

  if not found and not exists (
    select 1 from argus_app.member_lifecycles lifecycle
     where lifecycle.id=p_lifecycle_id and lifecycle.state='closed'
  ) then
    raise exception 'member_lifecycle_not_found' using errcode='P0002';
  end if;
end
$$;

create or replace function argus_private.close_member_lifecycle_on_member_delete()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  perform argus_private.close_member_lifecycle(
    old.lifecycle_id,'member-root-deleted'
  );
  return old;
end
$$;

create trigger close_member_lifecycle_after_member_delete
  after delete on argus_app.members
  for each row execute function argus_private.close_member_lifecycle_on_member_delete();

create or replace function argus_private.install_request_context(
  p_user_id uuid,
  p_session_id uuid,
  p_aal text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  context_relation text;
  retained_tenant_id uuid;
  retained_lifecycle_id uuid;
begin
  if p_aal not in ('aal1','aal2') then
    raise exception 'invalid_aal' using errcode='22023';
  end if;
  if coalesce(
    pg_catalog.current_setting('argus.request_context_relation',true),'')<>'' then
    raise exception 'request_context_already_installed' using errcode='25001';
  end if;

  select member.tenant_id,member.lifecycle_id
    into retained_tenant_id,retained_lifecycle_id
    from argus_app.members member
    join argus_app.member_lifecycles member_lifecycle
      on member_lifecycle.id=member.lifecycle_id
     and member_lifecycle.tenant_id=member.tenant_id
     and member_lifecycle.identity_subject_id=member.user_id
   where member.user_id=p_user_id
     and member.status='active'
     and member_lifecycle.state='open'
   for key share of member_lifecycle;

  if retained_lifecycle_id is null then
    raise exception 'inactive_member_lifecycle' using errcode='28000';
  end if;

  context_relation := 'argus_request_context_' ||
    pg_catalog.encode(extensions.gen_random_bytes(16),'hex');
  execute pg_catalog.format(
    'create temporary table pg_temp.%I (' ||
    'user_id pg_catalog.uuid not null,' ||
    'tenant_id pg_catalog.uuid not null,' ||
    'lifecycle_id pg_catalog.uuid not null,' ||
    'session_id pg_catalog.uuid not null,' ||
    'aal pg_catalog.text not null,' ||
    'transaction_id pg_catalog.text not null,' ||
    'backend_pid pg_catalog.int4 not null,' ||
    'installed_at timestamp with time zone not null' ||
    ') on commit drop',
    context_relation
  );
  execute pg_catalog.format(
    'insert into pg_temp.%I (' ||
    'user_id,tenant_id,lifecycle_id,session_id,aal,transaction_id,backend_pid,installed_at' ||
    ') values ($1,$2,$3,$4,$5,$6,$7,$8)',
    context_relation
  ) using
    p_user_id,retained_tenant_id,retained_lifecycle_id,p_session_id,p_aal,
    pg_catalog.pg_current_xact_id()::text,pg_catalog.pg_backend_pid(),
    pg_catalog.clock_timestamp();

  perform pg_catalog.set_config(
    'argus.request_context_relation',context_relation,true
  );
  -- Compatibility only: retained U4-U6 policies still read the legacy claims
  -- GUC. Trusted foundation policies never authorize from this value.
  perform pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub',p_user_id::text,
      'session_id',p_session_id::text,
      'aal',p_aal,
      'role','authenticated'
    )::text,
    true
  );
end
$$;

create or replace function argus_private.read_trusted_request_context()
returns table(
  user_id uuid,
  tenant_id uuid,
  lifecycle_id uuid,
  session_id uuid,
  aal text
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  context_relation text;
  stored_user_id uuid;
  stored_tenant_id uuid;
  stored_lifecycle_id uuid;
  stored_session_id uuid;
  stored_aal text;
  stored_transaction_id text;
  stored_backend_pid integer;
  stored_installed_at timestamptz;
begin
  context_relation := pg_catalog.current_setting(
    'argus.request_context_relation',true
  );
  if context_relation is null
     or context_relation !~ '^argus_request_context_[a-f0-9]{32}$' then
    return;
  end if;

  if not exists (
    select 1
      from pg_catalog.pg_class relation
     where relation.relnamespace=pg_catalog.pg_my_temp_schema()
       and relation.relname=context_relation
       and relation.relpersistence='t'
       and relation.relowner=(
         select role.oid from pg_catalog.pg_roles role
          where role.rolname='argus_identity_owner'
       )
  ) then
    return;
  end if;

  execute pg_catalog.format(
    'select context.user_id,context.tenant_id,context.lifecycle_id,' ||
    'context.session_id,context.aal,context.transaction_id,' ||
    'context.backend_pid,context.installed_at from pg_temp.%I context',
    context_relation
  ) into strict
    stored_user_id,stored_tenant_id,stored_lifecycle_id,stored_session_id,
    stored_aal,stored_transaction_id,stored_backend_pid,stored_installed_at;

  if stored_transaction_id<>pg_catalog.pg_current_xact_id()::text
     or stored_backend_pid<>pg_catalog.pg_backend_pid()
     or stored_installed_at<pg_catalog.statement_timestamp()-interval '1 minute'
     or stored_installed_at>pg_catalog.statement_timestamp()+interval '5 seconds'
     or stored_aal not in ('aal1','aal2') then
    return;
  end if;

  return query
  select stored_user_id,stored_tenant_id,stored_lifecycle_id,
         stored_session_id,stored_aal
   where exists (
    select 1
      from argus_app.members member
      join argus_app.member_lifecycles lifecycle
        on lifecycle.id=member.lifecycle_id
       and lifecycle.tenant_id=member.tenant_id
       and lifecycle.identity_subject_id=member.user_id
     where member.user_id=stored_user_id
       and member.tenant_id=stored_tenant_id
       and member.lifecycle_id=stored_lifecycle_id
       and member.status='active'
       and lifecycle.state='open'
  );
exception
  when no_data_found or too_many_rows or invalid_text_representation
    or undefined_table or insufficient_privilege then
    return;
end
$$;

create or replace function argus_private.trusted_request_user_id()
returns uuid
language sql
stable
security invoker
set search_path=''
as $$
  select context.user_id
    from argus_private.read_trusted_request_context() context
$$;

create or replace function argus_private.trusted_request_tenant_id()
returns uuid
language sql
stable
security invoker
set search_path=''
as $$
  select context.tenant_id
    from argus_private.read_trusted_request_context() context
$$;

create or replace function argus_private.trusted_request_lifecycle_id()
returns uuid
language sql
stable
security invoker
set search_path=''
as $$
  select context.lifecycle_id
    from argus_private.read_trusted_request_context() context
$$;

create policy capability_current_lifecycle on argus_app.member_lifecycles
  for select to argus_runtime,argus_member,argus_staff
  using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and id=(select argus_private.trusted_request_lifecycle_id())
    and state='open'
  );

grant select on argus_app.member_lifecycles
  to argus_runtime,argus_member,argus_staff;

create or replace function argus_private.provision_argus_member()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare retained_lifecycle_id uuid;
begin
  insert into argus_app.member_lifecycles(
    tenant_id,identity_subject_id
  ) values (new.id,new.id)
  on conflict (identity_subject_id) do nothing;

  select lifecycle.id into retained_lifecycle_id
    from argus_app.member_lifecycles lifecycle
   where lifecycle.identity_subject_id=new.id and lifecycle.state='open';
  if retained_lifecycle_id is null then
    raise exception 'member_lifecycle_not_open' using errcode='23514';
  end if;

  insert into argus_app.members(user_id,tenant_id,lifecycle_id)
  values (new.id,new.id,retained_lifecycle_id)
  on conflict (user_id) do nothing;

  insert into argus_app.profiles(
    user_id,deletion_epoch,display_name,locale
  ) values (new.id,0,'Argus member','en-US')
  on conflict (user_id) do nothing;

  insert into argus_app.preferences(user_id,deletion_epoch)
  values (new.id,0)
  on conflict (user_id) do nothing;

  insert into argus_app.onboarding_states(
    user_id,deletion_epoch,current_step
  ) values (new.id,0,'welcome')
  on conflict (user_id) do nothing;

  insert into argus_app.notification_preferences(user_id,deletion_epoch)
  values (new.id,0)
  on conflict (user_id) do nothing;

  return new;
end
$$;

revoke all on function
  argus_private.protect_member_lifecycle_binding(),
  argus_private.bind_member_lifecycle_on_insert(),
  argus_private.protect_member_lifecycle_immutable(),
  argus_private.close_member_lifecycle(uuid,text),
  argus_private.close_member_lifecycle_on_member_delete(),
  argus_private.install_request_context(uuid,uuid,text),
  argus_private.read_trusted_request_context(),
  argus_private.trusted_request_user_id(),
  argus_private.trusted_request_tenant_id(),
  argus_private.trusted_request_lifecycle_id(),
  argus_private.provision_argus_member()
from public,anon,authenticated,argus_runtime,argus_worker,argus_waitlist,
  argus_member,argus_staff,argus_callback,argus_migration,argus_edge;

grant execute on function argus_private.install_request_context(uuid,uuid,text)
  to argus_edge;
grant execute on function
  argus_private.read_trusted_request_context(),
  argus_private.trusted_request_user_id(),
  argus_private.trusted_request_tenant_id(),
  argus_private.trusted_request_lifecycle_id()
to argus_runtime,argus_member,argus_staff;

comment on table argus_app.member_lifecycles is
  'U3 immutable identity lifecycle parent; U4-U6 own dependent relation cutovers.';
comment on function argus_private.install_request_context(uuid,uuid,text) is
  'Trusted login-only transaction-local context installer; tenant/lifecycle are derived.';
comment on function argus_private.enforce_live_member_epoch() is
  'Compatibility trigger retained until U4-U6 bind every dependent relation to member_lifecycles.';

-- PostgreSQL 17 requires transient SET authority to transfer ownership. Keep
-- it only for these explicit objects and remove it before the migration ends.
grant argus_identity_owner to current_user with set true;
grant create on schema argus_app,argus_private to argus_identity_owner;

alter table argus_app.member_lifecycles owner to argus_identity_owner;
alter function argus_private.protect_member_lifecycle_binding()
  owner to argus_identity_owner;
alter function argus_private.bind_member_lifecycle_on_insert()
  owner to argus_identity_owner;
alter function argus_private.protect_member_lifecycle_immutable()
  owner to argus_identity_owner;
alter function argus_private.close_member_lifecycle(uuid,text)
  owner to argus_identity_owner;
alter function argus_private.close_member_lifecycle_on_member_delete()
  owner to argus_identity_owner;
alter function argus_private.install_request_context(uuid,uuid,text)
  owner to argus_identity_owner;
alter function argus_private.read_trusted_request_context()
  owner to argus_identity_owner;
alter function argus_private.trusted_request_user_id()
  owner to argus_identity_owner;
alter function argus_private.trusted_request_tenant_id()
  owner to argus_identity_owner;
alter function argus_private.trusted_request_lifecycle_id()
  owner to argus_identity_owner;
alter function argus_private.provision_argus_member()
  owner to argus_identity_owner;

revoke create on schema argus_app,argus_private from argus_identity_owner;
revoke argus_identity_owner from current_user;

commit;

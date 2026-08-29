begin;

-- U3 request context must take the same lifecycle lock as U5 brokerage work.
-- Resolve the active binding first, then let the identity-owned helper acquire
-- FOR SHARE and recheck the open state under the row lock. This makes either
-- lock order converge: an installed request delays close, while a close that
-- owns the row first makes installation fail after the wait.
-- PostgreSQL 17 requires SET authority to replace an identity-owned routine.
-- Attribute this temporary, non-inheriting membership to the migration role
-- so the matching grantor-scoped revoke preserves Supabase's admin-only row.
do $membership$
begin
  execute pg_catalog.format(
    'grant argus_identity_owner to %1$I with inherit false,set true,admin false granted by %1$I',
    current_user
  );
end
$membership$;
grant create on schema argus_private to argus_identity_owner;
set local role argus_identity_owner;

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
     and member_lifecycle.state='open';

  if not argus_private.lock_open_member_lifecycle(
    retained_tenant_id,retained_lifecycle_id,p_user_id
  ) then
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
  -- Compatibility only: retained U6 policies still read the legacy claims
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

revoke all on function argus_private.install_request_context(uuid,uuid,text)
  from public,anon,authenticated,service_role,argus_runtime,argus_worker,
       argus_waitlist,argus_member,argus_staff,argus_callback,argus_migration,
       argus_app_owner,argus_publication_owner,argus_brokerage_owner,
       argus_edge;
grant execute on function argus_private.install_request_context(uuid,uuid,text)
  to argus_edge;

comment on function argus_private.install_request_context(uuid,uuid,text) is
  'Trusted login-only context installer; derives lifecycle and holds the shared lifecycle lock until transaction completion.';

set local role postgres;
revoke create on schema argus_private from argus_identity_owner;
do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_identity_owner from %1$I granted by %1$I',current_user
  );
end
$membership$;

commit;

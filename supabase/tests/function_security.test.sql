begin;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(15);

select ok(
  exists(select 1 from pg_roles where rolname='argus_identity_owner'
    and not rolcanlogin and not rolsuper and not rolbypassrls),
  'identity routines have a narrow non-login, non-BYPASSRLS owner'
);

select is(
  (select count(*)::bigint
     from pg_proc routine
     join pg_namespace namespace on namespace.oid=routine.pronamespace
     join pg_roles owner on owner.oid=routine.proowner
    where routine.oid in (
      'argus_private.provision_argus_member()'::regprocedure,
      'argus_private.install_request_context(uuid,uuid,text)'::regprocedure,
      'argus_private.read_trusted_request_context()'::regprocedure,
      'argus_private.close_member_lifecycle_on_member_delete()'::regprocedure
    ) and (namespace.nspname<>'argus_private'
      or owner.rolname<>'argus_identity_owner' or not routine.prosecdef)),
  0::bigint,
  'foundation definers are private and owned only by identity'
);

select is(
  (select count(*)::bigint
     from pg_proc routine
    where routine.oid in (
      'argus_private.provision_argus_member()'::regprocedure,
      'argus_private.install_request_context(uuid,uuid,text)'::regprocedure,
      'argus_private.read_trusted_request_context()'::regprocedure,
      'argus_private.close_member_lifecycle_on_member_delete()'::regprocedure
    ) and not ('search_path=""'=any(coalesce(routine.proconfig,array[]::text[])))),
  0::bigint,
  'every foundation definer uses an empty search path'
);

select is(
  (select count(*)::bigint
     from pg_proc routine
    where routine.oid in (
      'argus_private.provision_argus_member()'::regprocedure,
      'argus_private.install_request_context(uuid,uuid,text)'::regprocedure,
      'argus_private.read_trusted_request_context()'::regprocedure,
      'argus_private.close_member_lifecycle_on_member_delete()'::regprocedure
    ) and has_function_privilege('public',routine.oid,'execute')),
  0::bigint,
  'PUBLIC cannot execute any foundation definer'
);

select is(
  (select count(*)::bigint from pg_proc routine
    join pg_namespace namespace on namespace.oid=routine.pronamespace
   where namespace.nspname='argus_private'
     and routine.proname='install_request_context'),
  1::bigint,
  'no stale request-context installer overload survives'
);

select ok(
  has_function_privilege(
    'argus_edge','argus_private.install_request_context(uuid,uuid,text)','execute'
  ) and not has_function_privilege(
    'public','argus_private.install_request_context(uuid,uuid,text)','execute'
  ) and not has_function_privilege(
    'argus_runtime','argus_private.install_request_context(uuid,uuid,text)','execute'
  ) and not has_function_privilege(
    'service_role','argus_private.install_request_context(uuid,uuid,text)','execute'
  ),
  'installer execution is granted by exact signature to the trusted login'
);

select ok(
  not has_function_privilege(
    'argus_runtime','argus_private.close_member_lifecycle(uuid,text)','execute'
  ) and not has_function_privilege(
    'argus_worker','argus_private.close_member_lifecycle(uuid,text)','execute'
  ) and not has_function_privilege(
    'argus_callback','argus_private.close_member_lifecycle(uuid,text)','execute'
  ),
  'the closure primitive has no exposed capability grant before domain binding'
);

select is(
  (select count(*)::bigint
     from pg_proc routine
    where routine.oid in (
      'argus_private.close_member_lifecycle(uuid,text)'::regprocedure,
      'argus_private.bind_member_lifecycle_on_insert()'::regprocedure,
      'argus_private.protect_member_lifecycle_binding()'::regprocedure,
      'argus_private.protect_member_lifecycle_immutable()'::regprocedure,
      'argus_private.trusted_request_user_id()'::regprocedure,
      'argus_private.trusted_request_tenant_id()'::regprocedure,
      'argus_private.trusted_request_lifecycle_id()'::regprocedure
    ) and routine.prosecdef),
  0::bigint,
  'row-local and policy helpers remain security invokers'
);

select ok(
  (select prosrc like '%on commit drop%'
     from pg_proc
    where oid='argus_private.install_request_context(uuid,uuid,text)'::regprocedure),
  'request context storage is transaction-scoped and dropped at completion'
);

select ok(
  (select prosrc like '%relation.relowner%'
       and prosrc like '%argus_identity_owner%'
     from pg_proc
    where oid='argus_private.read_trusted_request_context()'::regprocedure),
  'context reader rejects caller-owned temporary relation spoofing'
);

select ok(
  (select prosrc like '%pg_current_xact_id()%'
       and prosrc like '%pg_backend_pid()%'
       and prosrc like '%interval ''1 minute''%'
     from pg_proc
    where oid='argus_private.read_trusted_request_context()'::regprocedure),
  'context reader binds context to one transaction, backend, and bounded age'
);

select ok(
  (select prosrc like '%for key share%'
     from pg_proc
    where oid='argus_private.install_request_context(uuid,uuid,text)'::regprocedure),
  'context installation locks the open lifecycle through transaction completion'
);

select is(
  (select count(*)::bigint
     from pg_proc routine
    where routine.oid in (
      'argus_private.provision_argus_member()'::regprocedure,
      'argus_private.install_request_context(uuid,uuid,text)'::regprocedure,
      'argus_private.read_trusted_request_context()'::regprocedure,
      'argus_private.close_member_lifecycle_on_member_delete()'::regprocedure
    ) and routine.prosrc ~ '(^|[^.[:alnum:]_])(members|member_lifecycles)([^[:alnum:]_]|$)'
      and routine.prosrc !~ 'argus_app\.(members|member_lifecycles)'),
  0::bigint,
  'foundation definers qualify identity relations explicitly'
);

select ok(
  not has_function_privilege(
    'anon','argus_private.trusted_request_user_id()','execute'
  ) and not has_function_privilege(
    'authenticated','argus_private.trusted_request_user_id()','execute'
  ) and not has_function_privilege(
    'service_role','argus_private.trusted_request_user_id()','execute'
  ),
  'Data API roles cannot call trusted context helpers'
);

select is(
  (select count(*)::bigint from information_schema.role_routine_grants
    where grantee in ('argus_callback','argus_migration')
      and specific_schema in ('argus_app','argus_brokerage','argus_private')),
  0::bigint,
  'unbound capability roles receive no implicit routine execution'
);

select * from finish();
rollback;

begin;

do $membership$ begin
  execute pg_catalog.format(
    'grant argus_edge,argus_member,argus_callback,argus_staff,argus_worker,argus_brokerage_owner,argus_identity_owner to %I with set true',
    current_user
  );
end $membership$;
grant usage on schema extensions to argus_edge,argus_member,argus_staff;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(86);

select has_role('argus_brokerage_owner','brokerage capabilities have a dedicated NOLOGIN owner');
select ok(
  not (select rolcanlogin from pg_roles where rolname='argus_brokerage_owner'),
  'brokerage owner cannot log in'
);
select has_column('argus_brokerage','connections','lifecycle_id','connections bind the immutable member lifecycle');
select has_column('argus_brokerage','accounts','lifecycle_id','accounts bind the immutable member lifecycle');
select has_column('argus_private','provider_command_attempts','account_id','attempts carry their account-qualified command identity');
select has_column('argus_private','reconciliation_records','account_id','reconciliation carries its account-qualified command identity');
select has_table('argus_brokerage','account_capabilities','account capabilities are normalized');
select has_table('argus_brokerage','projection_balance_facts','balance facts are typed');
select has_table('argus_brokerage','projection_position_facts','position facts are typed');
select has_table('argus_brokerage','projection_restriction_facts','restriction facts are typed');
select has_table('argus_brokerage','projection_account_facts','account facts are typed');
select has_table('argus_private','projection_generation_snapshots','provider projection snapshots are private');
select has_table('argus_private','order_projection_generation_snapshots','order snapshots are private');
select has_column('argus_brokerage','accounts','capability_normalization_state','legacy capability disposition is explicit');
select has_column('argus_brokerage','order_projection_generations','instrument_id','order projection facts are typed');

select ok(
  exists (
    select 1 from pg_constraint constraint_row
     where constraint_row.conrelid='argus_brokerage.connections'::regclass
       and constraint_row.conname='connections_u5_tenant_lifecycle_fk'
  ),
  'connection proves its tenant lifecycle'
);
select ok(
  exists (
    select 1 from pg_constraint constraint_row
     where constraint_row.conrelid='argus_brokerage.connections'::regclass
       and constraint_row.conname='connections_u5_subject_lifecycle_fk'
  ),
  'connection independently proves the identity subject lifecycle'
);

select ok(
  exists (
    select 1 from pg_constraint constraint_row
     where constraint_row.conrelid='argus_brokerage.accounts'::regclass
       and constraint_row.contype='f'
       and pg_get_constraintdef(constraint_row.oid) like
         'FOREIGN KEY (tenant_id, lifecycle_id, user_id, connection_id)%'
  ),
  'account ownership is one parent-qualified relationship'
);

select ok(
  exists (
    select 1 from pg_constraint constraint_row
     where constraint_row.conrelid='argus_private.provider_command_attempts'::regclass
       and constraint_row.contype='f'
       and pg_get_constraintdef(constraint_row.oid) like
         'FOREIGN KEY (tenant_id, lifecycle_id, user_id, connection_id, account_id, command_id)%'
  ),
  'attempt ownership is one command-qualified relationship'
);

select ok(
  not exists (
    select 1
      from pg_constraint constraint_row
      join pg_class relation on relation.oid=constraint_row.conrelid
      join pg_namespace namespace on namespace.oid=relation.relnamespace
     where constraint_row.contype='f'
       and constraint_row.conrelid=any(array[
         'argus_brokerage.connections'::regclass,
         'argus_brokerage.accounts'::regclass,
         'argus_brokerage.active_account_selections'::regclass,
         'argus_brokerage.projection_generations'::regclass,
         'argus_brokerage.order_projection_generations'::regclass,
         'argus_brokerage.account_capabilities'::regclass,
         'argus_brokerage.projection_balance_facts'::regclass,
         'argus_brokerage.projection_position_facts'::regclass,
         'argus_brokerage.projection_restriction_facts'::regclass,
         'argus_brokerage.projection_account_facts'::regclass,
         'argus_private.projection_generation_snapshots'::regclass,
         'argus_private.order_projection_generation_snapshots'::regclass,
         'argus_private.oauth_states'::regclass,
         'argus_private.webull_completion_handles'::regclass,
         'argus_private.webull_credentials'::regclass,
         'argus_private.webull_account_mappings'::regclass,
         'argus_private.refresh_leases'::regclass,
         'argus_private.projection_refresh_leases'::regclass,
         'argus_private.webull_asset_mappings'::regclass,
         'argus_private.order_previews'::regclass,
         'argus_private.provider_commands'::regclass,
         'argus_private.provider_command_attempts'::regclass,
         'argus_private.reconciliation_records'::regclass,
         'argus_private.webull_order_mappings'::regclass
       ])
       and not exists (
         select 1
           from pg_index index_row
          where index_row.indrelid=constraint_row.conrelid
            and index_row.indisvalid
            and index_row.indisready
            and not exists (
              select 1
                from unnest(constraint_row.conkey) with ordinality
                     as key_column(attnum,position)
               where (index_row.indkey::smallint[])[key_column.position-1]
                     is distinct from key_column.attnum
            )
       )
  ),
  'every brokerage foreign key has a matching leading-column index'
);

select ok(
  not has_function_privilege(
    'argus_worker',
    'argus_private.prepare_provider_order_command(uuid,uuid,uuid,bigint,uuid,uuid,text,uuid,text,text,jsonb,text,text,timestamptz)',
    'execute'
  ),
  'generic worker cannot prepare a financial command'
);

select ok(
  has_function_privilege(
    'argus_worker',
    'argus_private.claim_webull_command_reconciliation(uuid,uuid)',
    'execute'
  ),
  'worker retains lookup-only reconciliation claim authority'
);

select ok(
  not has_table_privilege(
    'argus_worker','argus_private.provider_commands','insert'
  ),
  'worker cannot insert provider commands directly'
);
select set_eq(
  $$select policy.schemaname||'.'||policy.tablename||':'||policy.cmd
      from pg_policies policy
     where 'argus_brokerage_owner'=any(policy.roles)$$,
  $$values
    ('argus_app.member_lifecycles:SELECT'),('argus_app.members:SELECT'),
    ('argus_private.deletion_tombstones:SELECT'),
    ('argus_private.deletion_tombstones:UPDATE'),
    ('argus_brokerage.connections:SELECT'),('argus_brokerage.connections:UPDATE'),
    ('argus_brokerage.connections:DELETE'),
    ('argus_brokerage.accounts:SELECT'),('argus_brokerage.accounts:UPDATE'),
    ('argus_brokerage.accounts:DELETE'),
    ('argus_brokerage.active_account_selections:DELETE'),
    ('argus_brokerage.projection_generations:SELECT'),
    ('argus_brokerage.projection_generations:INSERT'),
    ('argus_brokerage.order_projection_generations:SELECT'),
    ('argus_brokerage.order_projection_generations:INSERT'),
    ('argus_brokerage.account_capabilities:SELECT'),
    ('argus_brokerage.account_capabilities:INSERT'),
    ('argus_brokerage.account_capabilities:DELETE'),
    ('argus_brokerage.projection_balance_facts:SELECT'),
    ('argus_brokerage.projection_balance_facts:INSERT'),
    ('argus_brokerage.projection_position_facts:SELECT'),
    ('argus_brokerage.projection_position_facts:INSERT'),
    ('argus_brokerage.projection_restriction_facts:SELECT'),
    ('argus_brokerage.projection_restriction_facts:INSERT'),
    ('argus_brokerage.projection_account_facts:SELECT'),
    ('argus_brokerage.projection_account_facts:INSERT'),
    ('argus_private.projection_generation_snapshots:SELECT'),
    ('argus_private.projection_generation_snapshots:INSERT'),
    ('argus_private.order_projection_generation_snapshots:INSERT'),
    ('argus_private.brokerage_normalization_quarantine:SELECT'),
    ('argus_private.brokerage_normalization_quarantine:INSERT'),
    ('argus_private.oauth_states:SELECT'),('argus_private.oauth_states:UPDATE'),
    ('argus_private.oauth_states:DELETE'),
    ('argus_private.webull_completion_handles:DELETE'),
    ('argus_private.webull_credentials:SELECT'),
    ('argus_private.webull_credentials:UPDATE'),
    ('argus_private.webull_credentials:DELETE'),
    ('argus_private.webull_account_mappings:SELECT'),
    ('argus_private.webull_account_mappings:DELETE'),
    ('argus_private.refresh_leases:SELECT'),
    ('argus_private.refresh_leases:INSERT'),
    ('argus_private.refresh_leases:UPDATE'),
    ('argus_private.refresh_leases:DELETE'),
    ('argus_private.projection_refresh_leases:SELECT'),
    ('argus_private.projection_refresh_leases:INSERT'),
    ('argus_private.projection_refresh_leases:UPDATE'),
    ('argus_private.projection_refresh_leases:DELETE'),
    ('argus_private.webull_asset_mappings:SELECT'),
    ('argus_private.webull_asset_mappings:INSERT'),
    ('argus_private.webull_asset_mappings:UPDATE'),
    ('argus_private.order_previews:SELECT'),
    ('argus_private.order_previews:UPDATE'),
    ('argus_private.provider_commands:SELECT'),
    ('argus_private.provider_commands:INSERT'),
    ('argus_private.provider_commands:UPDATE'),
    ('argus_private.provider_commands:DELETE'),
    ('argus_private.provider_command_attempts:SELECT'),
    ('argus_private.provider_command_attempts:INSERT'),
    ('argus_private.provider_command_attempts:DELETE'),
    ('argus_private.reconciliation_records:SELECT'),
    ('argus_private.reconciliation_records:INSERT'),
    ('argus_private.reconciliation_records:UPDATE'),
    ('argus_private.reconciliation_records:DELETE'),
    ('argus_private.webull_order_mappings:SELECT'),
    ('argus_private.webull_order_mappings:INSERT'),
    ('argus_private.kill_switches:SELECT'),
    ('argus_private.outbox_events:SELECT'),
    ('argus_private.outbox_events:INSERT'),
    ('argus_private.outbox_events:DELETE'),
    ('argus_private.job_runs:SELECT'),('argus_private.job_runs:UPDATE'),
    ('argus_private.step_up_receipts:SELECT'),
    ('argus_private.step_up_receipts:UPDATE')$$,
  'NOLOGIN brokerage owner has only the reviewed relation-action matrix'
);
select set_eq(
  $$select grantee.rolname||':'||privilege.privilege_type
      from pg_proc function_row
      cross join lateral aclexplode(function_row.proacl) privilege
      join pg_roles grantee on grantee.oid=privilege.grantee
     where function_row.oid=
       'argus_private.purge_member_brokerage_data(uuid)'::regprocedure$$,
  $$values ('argus_jobs_owner:EXECUTE')$$,
  'durable jobs orchestration receives only the brokerage purge capability'
);
select ok(
  not exists (
    select 1
      from pg_class relation
      cross join lateral aclexplode(relation.relacl) privilege
     where relation.oid=any(array[
       'argus_brokerage.connections'::regclass,
       'argus_private.provider_commands'::regclass,
       'argus_private.provider_command_attempts'::regclass,
       'argus_private.reconciliation_records'::regclass
     ])
       and privilege.grantee=(select oid from pg_roles where rolname='postgres')
       and privilege.privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
  ),
  'retained privacy orchestration has no direct brokerage table DML'
);
select set_eq(
  $$select policy.schemaname||'.'||policy.tablename||':'||policy.cmd
      from pg_policies policy
     where 'argus_member'=any(policy.roles)
       and (policy.schemaname='argus_brokerage' or policy.tablename in (
         'oauth_states','webull_completion_handles','webull_credentials',
         'webull_account_mappings','refresh_leases',
         'projection_refresh_leases','webull_asset_mappings','order_previews',
         'provider_commands','provider_command_attempts',
         'reconciliation_records','webull_order_mappings'
       ))$$,
  $$values
    ('argus_brokerage.connections:SELECT'),('argus_brokerage.connections:INSERT'),
    ('argus_brokerage.connections:UPDATE'),('argus_brokerage.accounts:SELECT'),
    ('argus_brokerage.active_account_selections:SELECT'),
    ('argus_brokerage.active_account_selections:INSERT'),
    ('argus_brokerage.active_account_selections:UPDATE'),
    ('argus_brokerage.active_account_selections:DELETE'),
    ('argus_brokerage.projection_generations:SELECT'),
    ('argus_brokerage.order_projection_generations:SELECT'),
    ('argus_brokerage.account_capabilities:SELECT'),
    ('argus_brokerage.projection_balance_facts:SELECT'),
    ('argus_brokerage.projection_position_facts:SELECT'),
    ('argus_brokerage.projection_restriction_facts:SELECT'),
    ('argus_brokerage.projection_account_facts:SELECT'),
    ('argus_private.oauth_states:SELECT'),('argus_private.oauth_states:INSERT'),
    ('argus_private.oauth_states:UPDATE'),
    ('argus_private.webull_completion_handles:SELECT'),
    ('argus_private.webull_completion_handles:UPDATE'),
    ('argus_private.webull_credentials:SELECT'),
    ('argus_private.webull_account_mappings:SELECT'),
    ('argus_private.webull_asset_mappings:SELECT'),
    ('argus_private.order_previews:SELECT'),
    ('argus_private.order_previews:INSERT'),
    ('argus_private.provider_commands:SELECT'),
    ('argus_private.webull_order_mappings:SELECT')$$,
  'member policies match only SQL issued by reviewed brokerage adapters'
);
select set_eq(
  $$select policy.schemaname||'.'||policy.tablename||':'||policy.cmd
      from pg_policies policy
     where 'argus_callback'=any(policy.roles)
       and (policy.schemaname='argus_brokerage'
         or policy.tablename in (
           'members','member_lifecycles','oauth_states',
           'webull_completion_handles','webull_credentials',
           'webull_account_mappings'
         ))$$,
  $$values
    ('argus_app.members:SELECT'),('argus_app.member_lifecycles:SELECT'),
    ('argus_brokerage.connections:SELECT'),
    ('argus_brokerage.connections:UPDATE'),
    ('argus_brokerage.accounts:INSERT'),
    ('argus_private.oauth_states:SELECT'),
    ('argus_private.webull_completion_handles:INSERT'),
    ('argus_private.webull_credentials:INSERT'),
    ('argus_private.webull_account_mappings:INSERT')$$,
  'callback policies expose only state validation and completion writes'
);
select ok(
  not has_table_privilege('argus_member','argus_private.webull_credentials','update')
  and not has_table_privilege('argus_member','argus_private.webull_credentials','delete')
  and not has_table_privilege('argus_member','argus_private.provider_command_attempts','update')
  and not has_table_privilege('argus_member','argus_private.provider_command_attempts','delete')
  and not has_table_privilege('argus_member','argus_private.reconciliation_records','update')
  and not has_table_privilege('argus_member','argus_private.reconciliation_records','delete'),
  'member cannot mutate credentials, command attempts or reconciliation directly'
);
select ok(
  not has_table_privilege('argus_callback','argus_brokerage.connections','delete')
  and not has_table_privilege('argus_callback','argus_brokerage.accounts','delete')
  and not has_table_privilege('argus_callback','argus_private.webull_credentials','delete'),
  'callback cannot delete connections, accounts or credentials directly'
);
select ok(
  not has_function_privilege(
    'argus_member','argus_private.claim_webull_command_reconciliation(uuid,uuid)',
    'execute'
  ) and not has_function_privilege(
    'argus_callback','argus_private.claim_webull_command_reconciliation(uuid,uuid)',
    'execute'
  ),
  'member and callback cannot execute worker recovery entrypoints'
);
select ok(
  has_function_privilege(
    'argus_member',
    'argus_private.prepare_provider_order_command(uuid,uuid,uuid,bigint,uuid,uuid,text,uuid,text,text,jsonb,text,text,timestamptz)',
    'execute'
  ),
  'member API retains the narrow financial prepare capability'
);
select ok(
  has_function_privilege(
    'argus_callback',
    'argus_private.consume_webull_oauth_state(text,timestamptz)',
    'execute'
  ),
  'callback role has only the OAuth consume entrypoint needed before context installation'
);
select ok(
  not has_table_privilege(
    'argus_member','argus_private.projection_generation_snapshots','select'
  ) and not has_column_privilege(
    'argus_member','argus_brokerage.projection_generations',
    'normalized_payload','select'
  ),
  'member role cannot read private projection snapshots'
);
select ok(
  not has_table_privilege(
    'argus_member','argus_private.order_projection_generation_snapshots','select'
  ) and not has_column_privilege(
    'argus_member','argus_brokerage.order_projection_generations',
    'normalized_payload','select'
  ),
  'member role cannot read private order snapshots'
);
select ok(
  has_column_privilege(
    'argus_member','argus_private.webull_credentials',
    'provider_environment','select'
  ) and not has_column_privilege(
    'argus_member','argus_private.webull_credentials',
    'access_ciphertext','select'
  ) and not has_column_privilege(
    'argus_member','argus_private.webull_credentials',
    'wrapped_data_key','select'
  ),
  'member sees provider environment but never credential ciphertext or keys'
);
select set_eq(
  $$select privilege.column_name
      from information_schema.column_privileges privilege
     where privilege.table_schema='argus_brokerage'
       and privilege.table_name='connections'
       and privilege.grantee='argus_member'
       and privilege.privilege_type='INSERT'$$,
  $$values ('id'),('user_id'),('deletion_epoch'),('status')$$,
  'member connection creation has an exact four-column insert capability'
);
select ok(
  not has_table_privilege('argus_member','argus_brokerage.accounts','update')
  and not has_table_privilege(
    'argus_member','argus_brokerage.projection_generations','insert'
  )
  and not has_table_privilege(
    'argus_member','argus_brokerage.order_projection_generations','insert'
  )
  and not has_table_privilege(
    'argus_member','argus_private.projection_refresh_leases','insert'
  )
  and not has_table_privilege(
    'argus_member','argus_private.webull_asset_mappings','insert'
  )
  and not has_table_privilege(
    'argus_member','argus_private.webull_order_mappings','insert'
  ),
  'member projection, account, asset, lease, and order mapping writes use scoped capabilities'
);
select ok(
  not has_table_privilege(
    'argus_callback','argus_private.projection_generation_snapshots','select'
  ) and not has_table_privilege(
    'argus_worker','argus_private.projection_generation_snapshots','select'
  ) and not has_table_privilege(
    'argus_callback','argus_private.order_projection_generation_snapshots','select'
  ) and not has_table_privilege(
    'argus_worker','argus_private.order_projection_generation_snapshots','select'
  ),
  'private provider snapshots are denied to callback and worker roles'
);
select ok(
  has_function_privilege(
    'argus_member',
    'argus_private.begin_brokerage_order_list_ingestion(uuid,uuid,bigint)',
    'execute'
  ) and has_function_privilege(
    'argus_member',
    'argus_private.append_brokerage_order_list_observation(uuid,uuid,bigint,bigint,uuid,bytea,text,integer,uuid,text,numeric,jsonb,timestamptz,timestamptz)',
    'execute'
  ) and has_function_privilege(
    'argus_member',
    'argus_private.complete_brokerage_order_list_ingestion(uuid,uuid,bigint,bigint,jsonb,timestamptz,timestamptz,timestamptz,text,text)',
    'execute'
  ),
  'member order-list ingestion composes only through scoped entrypoints'
);
select ok(
  has_function_privilege(
    'argus_staff','argus_private.get_brokerage_normalization_summary()','execute'
  ) and not has_function_privilege(
    'argus_member','argus_private.get_brokerage_normalization_summary()','execute'
  ) and not has_function_privilege(
    'argus_callback','argus_private.get_brokerage_normalization_summary()','execute'
  ) and not has_function_privilege(
    'argus_worker','argus_private.get_brokerage_normalization_summary()','execute'
  ) and has_function_privilege(
    'argus_brokerage_owner','argus_private.has_staff_permission(text)','execute'
  ) and not has_function_privilege(
    'argus_brokerage_owner',
    'argus_private.has_live_staff_session(uuid,uuid)','execute'
  ),
  'staff diagnostics compose only the reviewed permission predicate'
);
select set_eq(
  $$select dependency.signature
      from (values
        ('argus_private.read_trusted_request_context()'),
        ('argus_private.trusted_request_lifecycle_id()'),
        ('argus_private.trusted_request_tenant_id()'),
        ('argus_private.trusted_request_user_id()')
      ) dependency(signature)
     where has_function_privilege(
       'argus_brokerage_owner',dependency.signature,'execute'
     )$$,
  $$values
    ('argus_private.read_trusted_request_context()')$$,
  'brokerage definers have only the composite trusted identity-context dependency'
);
select is(
  (
    select pg_catalog.count(*)::bigint
      from pg_proc routine
      join pg_namespace namespace on namespace.oid=routine.pronamespace
     where routine.proowner=(
       select oid from pg_roles where rolname='argus_brokerage_owner'
     )
       and namespace.nspname in ('argus_brokerage','argus_private')
       and pg_catalog.pg_get_functiondef(routine.oid) ~
         'argus_private[.]trusted_request_(user|tenant|lifecycle)_id[(][)]'
  ),
  0::bigint,
  'brokerage-owned routines do not bypass the composite request-context reader'
);
select is(
  argus_private.brokerage_account_capabilities_reason('{}'::jsonb),
  'capabilities_not_array',
  'non-array legacy capability documents have an explicit disposition'
);
select is(
  argus_private.brokerage_account_capabilities_reason('[1]'::jsonb),
  'capability_entry_invalid',
  'malformed legacy capability entries have an explicit disposition'
);
select is(
  argus_private.brokerage_account_capabilities_reason(
    '[{"capability":"orders_read","provider_code":"DUP","available":true},{"capability":"orders_read","provider_code":"DUP2","available":true}]'::jsonb
  ),
  'capability_entry_duplicate',
  'duplicate normalized capability entries are quarantined whole'
);
select is(
  argus_private.brokerage_account_capabilities_reason(
    (select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'capability','provider_cap_'||ordinality::text,
      'provider_code','CAP_'||ordinality::text,'available',true
    )) from pg_catalog.generate_series(1,65) as series(ordinality))
  ),
  'capabilities_oversized',
  'oversized legacy capability documents have an explicit disposition'
);
select is(
  argus_private.brokerage_account_capabilities_reason(
    '[{"capability":"new_provider_capability","provider_code":"NEW_CAP","available":true}]'::jsonb
  ),
  null::text,
  'unknown well-formed provider capabilities remain valid and fail closed when typed'
);
select has_function(
  'argus_private','lock_brokerage_scope',
  array['uuid','uuid','uuid','uuid','uuid'],
  'worker and callback routines share one lifecycle-to-account lock guard'
);
select ok(
  (select pg_get_userbyid(routine.proowner)='argus_identity_owner'
     from pg_proc routine
    where routine.oid=
      'argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)'::regprocedure)
  and has_function_privilege(
    'argus_brokerage_owner',
    'argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)','execute'
  )
  and not has_function_privilege(
    'argus_member',
    'argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)','execute'
  )
  and not has_function_privilege(
    'argus_callback',
    'argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)','execute'
  )
  and not has_function_privilege(
    'argus_worker',
    'argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)','execute'
  )
  and not has_function_privilege(
    'argus_runtime',
    'argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)','execute'
  )
  and not has_schema_privilege(
    'argus_identity_owner','argus_private','create'
  ),
  'identity owner exposes lifecycle row locking only to the brokerage owner'
);
select ok(
  (select routine.prosrc ~ 'argus_private\.lock_brokerage_scope\('
     from pg_proc routine
     join pg_namespace namespace on namespace.oid=routine.pronamespace
    where namespace.nspname='argus_private'
      and routine.proname='claim_webull_token_refresh')
  and (select routine.prosrc ~ 'argus_private\.lock_brokerage_scope\('
     from pg_proc routine
     join pg_namespace namespace on namespace.oid=routine.pronamespace
    where namespace.nspname='argus_private'
      and routine.proname='claim_webull_projection_refresh')
  and (select routine.prosrc ~
         'argus_private\.claim_brokerage_reconciliation_attempt\('
     from pg_proc routine
     join pg_namespace namespace on namespace.oid=routine.pronamespace
    where namespace.nspname='argus_private'
      and routine.proname='claim_webull_command_reconciliation'),
  'token, projection, and command recovery enter the shared scoped lock path'
);
select is(
  (
    select count(*)::bigint
      from pg_proc routine
      join pg_namespace namespace on namespace.oid=routine.pronamespace
     where namespace.nspname='argus_private'
       and routine.proname in (
         'prepare_provider_order_command','append_order_projection',
         'record_provider_order_acknowledgement',
         'claim_provider_command_reconciliation',
         'record_provider_command_not_found',
         'record_provider_command_lookup_ambiguous',
         'record_provider_order_reconciliation','disconnect_webull_connection'
       )
       and routine.prosrc ~ 'argus_private\\.request_user_id\\(\\)'
  ),
  0::bigint,
  'U5 member routines contain no legacy request identity helper'
);
select ok(
  pg_get_function_result(
    'argus_private.claim_provider_command_reconciliation(uuid)'::regprocedure
  ) like 'TABLE(claim_outcome text, command_id uuid,%'
  and pg_get_function_result(
    'argus_private.claim_provider_command_reconciliation(uuid)'::regprocedure
  ) like '%egress_started_at timestamp with time zone)',
  'member reconciliation claim publishes the reviewed outcome-first result shape'
);
select ok(
  pg_get_function_result(
    'argus_private.claim_webull_command_reconciliation(uuid,uuid)'::regprocedure
  ) not like '%normalized_payload%'
  and pg_get_function_result(
    'argus_private.claim_webull_command_reconciliation(uuid,uuid)'::regprocedure
  ) not like '%reviewed_payload%',
  'worker reconciliation claim cannot return a financial execute payload'
);
select is(
  (select pg_catalog.count(*)::bigint
     from argus_private.brokerage_normalization_quarantine),
  0::bigint,
  'normalization diagnostics start empty on a clean replay'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000',
   '51515151-5151-4515-8515-515151515151','authenticated','authenticated',
   'u5-a@example.test','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000',
   '52525252-5252-4525-8525-525252525252','authenticated','authenticated',
   'u5-b@example.test','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000',
   '53535353-5353-4535-8535-535353535353','authenticated','authenticated',
   'u5-staff@example.test','',now(),'{}','{}',now(),now());

insert into argus_private.staff_principals(
  user_id,permissions,display_label
) values (
  '53535353-5353-4535-8535-535353535353',
  array['brokerage:data_quality'],'U5 data quality staff'
);

set local role argus_brokerage_owner;
create policy u5_test_owner_account_insert
  on argus_brokerage.accounts
  for insert to argus_brokerage_owner with check (true);
select throws_ok(
  $$insert into argus_brokerage.connections(
      id,tenant_id,lifecycle_id,user_id,deletion_epoch,status
    )
    select '51515151-1000-4000-8000-000000000099',
           owner.tenant_id,owner.lifecycle_id,other.user_id,
           other.deletion_epoch,'pending'
      from argus_app.members owner
      join argus_app.members other on other.user_id=
        '52525252-5252-4525-8525-525252525252'
     where owner.user_id='51515151-5151-4515-8515-515151515151'$$,
  '42501','brokerage_lifecycle_mismatch',
  'cross-user connection binding is rejected even with a real tenant and lifecycle'
);
reset role;

insert into argus_brokerage.connections(
  id,user_id,deletion_epoch,status
)
select '51515151-1000-4000-8000-000000000001',member.user_id,
       member.deletion_epoch,'connected'
  from argus_app.members member
 where member.user_id='51515151-5151-4515-8515-515151515151';
select is(
  (
    select count(*)::bigint from argus_brokerage.connections connection
     where connection.id='51515151-1000-4000-8000-000000000001'
       and connection.tenant_id=(
         select member.tenant_id from argus_app.members member
          where member.user_id='51515151-5151-4515-8515-515151515151'
       )
  ),
  1::bigint,
  'valid connection derives the complete lifecycle identity'
);

update argus_brokerage.connections set status='pending'
 where id='51515151-1000-4000-8000-000000000001';
set local role argus_edge;
select argus_private.install_request_context(
  '51515151-5151-4515-8515-515151515151',
  '51515151-0000-4000-8000-000000000011','aal1'
);
reset role;
set local role argus_member;
select throws_ok(
  $$update argus_brokerage.connections set status='connected'
     where id='51515151-1000-4000-8000-000000000001'$$,
  '42501','brokerage_connection_transition_forbidden',
  'member cannot self-authorize a pending brokerage connection'
);
reset role;
update argus_brokerage.connections set status='connected'
 where id='51515151-1000-4000-8000-000000000001';

select throws_ok(
  $$insert into argus_brokerage.accounts(
      id,user_id,deletion_epoch,connection_id,display_label,base_currency,
      status,capability_version
    )
    select '52525252-2000-4000-8000-000000000001',member.user_id,
           member.deletion_epoch,'51515151-1000-4000-8000-000000000001',
           'Cross account','USD','available',1
      from argus_app.members member
     where member.user_id='52525252-5252-4525-8525-525252525252'$$,
  '23503',null,
  'cross-user account cannot attach to another lifecycle connection'
);

insert into argus_brokerage.accounts(
  id,user_id,deletion_epoch,connection_id,display_label,base_currency,status,
  capability_version,capabilities,fetched_at,expires_at
)
select '51515151-2000-4000-8000-000000000001',member.user_id,
       member.deletion_epoch,'51515151-1000-4000-8000-000000000001',
       'Typed account','USD','available',3,
       '[{"capability":"orders_read","provider_code":"ORDERS_READ","available":true},{"capability":"manual_orders","provider_code":"MANUAL_ORDERS","available":true}]'::jsonb,
       now(),now()+interval '5 minutes'
 from argus_app.members member
 where member.user_id='51515151-5151-4515-8515-515151515151';
reset role;
select is(
  (
    select count(*)::bigint
      from argus_brokerage.account_capabilities capability
     where capability.account_id='51515151-2000-4000-8000-000000000001'
       and capability.available
  ),
  2::bigint,
  'account capability JSON is materialized into typed authoritative rows'
);

set local role argus_member;
select is(
  argus_private.invalidate_brokerage_account_scoped(
    '51515151-2000-4000-8000-000000000001'
  ),
  '51515151-1000-4000-8000-000000000001'::uuid,
  'member account invalidation can only degrade typed provider authority'
);
select throws_ok(
  $$update argus_brokerage.accounts
       set status='available',expires_at=now()+interval '1 hour'
     where id='51515151-2000-4000-8000-000000000001'$$,
  '42501','permission denied for table accounts',
  'member cannot restore unavailable provider authority with direct DML'
);
reset role;

insert into argus_private.projection_refresh_leases(
  account_id,user_id,deletion_epoch,resource_type,lease_token,leased_until,
  connection_id
) values (
  '51515151-2000-4000-8000-000000000001',
  '51515151-5151-4515-8515-515151515151',0,'account',
  '51515151-4000-4000-8000-000000000001',now()+interval '5 minutes',
  '51515151-1000-4000-8000-000000000001'
);
set local role argus_member;
select lives_ok(
  $$select * from argus_private.append_brokerage_projection_generation(
      '51515151-2000-4000-8000-000000000001',
      '51515151-1000-4000-8000-000000000001',0,'account',
      '51515151-4000-4000-8000-000000000001','{}'::jsonb,
      now(),now(),now()+interval '5 minutes','available',null,
      now()+interval '30 days'
    )$$,
  'allowed provider schema drift is retained as a quarantined observation'
);
reset role;
select is(
  (select generation.normalization_state
     from argus_brokerage.projection_generations generation
    where generation.account_id='51515151-2000-4000-8000-000000000001'
      and generation.resource_type='account' and generation.generation=1),
  'quarantined',
  'unparseable provider observation is explicitly non-ready'
);
select is(
  (select pg_catalog.count(*)::bigint
     from argus_private.projection_generation_snapshots snapshot
     join argus_brokerage.projection_generations generation
       on generation.tenant_id=snapshot.tenant_id
      and generation.lifecycle_id=snapshot.lifecycle_id
      and generation.id=snapshot.generation_id
    where generation.account_id='51515151-2000-4000-8000-000000000001'
      and generation.resource_type='account' and generation.generation=1),
  1::bigint,
  'quarantined observation retains exactly one bounded private envelope'
);
select is(
  (select pg_catalog.count(*)::bigint
     from argus_brokerage.projection_account_facts fact
     join argus_brokerage.projection_generations generation
       on generation.tenant_id=fact.tenant_id
      and generation.lifecycle_id=fact.lifecycle_id
      and generation.id=fact.generation_id
    where generation.account_id='51515151-2000-4000-8000-000000000001'
      and generation.resource_type='account' and generation.generation=1),
  0::bigint,
  'quarantined provider observations never enter typed projection reads'
);

set local role argus_identity_owner;
do $$
declare context_relation text:=current_setting('argus.request_context_relation');
begin
  execute pg_catalog.format(
    'update pg_temp.%I set user_id=$1,tenant_id=$2,lifecycle_id=$3,aal=''aal2'',installed_at=clock_timestamp()',
    context_relation
  ) using
    '53535353-5353-4535-8535-535353535353'::uuid,
    (select member.tenant_id from argus_app.members member
      where member.user_id='53535353-5353-4535-8535-535353535353'),
    (select member.lifecycle_id from argus_app.members member
      where member.user_id='53535353-5353-4535-8535-535353535353');
end $$;
reset role;
set local role argus_staff;
select is(
  (select summary.quarantined_count
     from argus_private.get_brokerage_normalization_summary() summary
    where summary.source_relation='argus_brokerage.projection_generations'
      and summary.reason_code='provider_schema_unrecognized'),
  1::bigint,
  'authorized staff diagnostics report dirty fixture counts without payloads'
);
reset role;
set local role argus_identity_owner;
do $$
declare context_relation text:=current_setting('argus.request_context_relation');
begin
  execute pg_catalog.format(
    'update pg_temp.%I set user_id=$1,tenant_id=$2,lifecycle_id=$3,aal=''aal1'',installed_at=clock_timestamp()',
    context_relation
  ) using
    '51515151-5151-4515-8515-515151515151'::uuid,
    (select member.tenant_id from argus_app.members member
      where member.user_id='51515151-5151-4515-8515-515151515151'),
    (select member.lifecycle_id from argus_app.members member
      where member.user_id='51515151-5151-4515-8515-515151515151');
end $$;
reset role;

insert into argus_private.webull_credentials(
  connection_id,user_id,deletion_epoch,token_version,key_version,
  access_ciphertext,access_nonce,access_tag,refresh_ciphertext,refresh_nonce,
  refresh_tag,wrapped_data_key,wrapped_key_nonce,wrapped_key_tag,
  associated_data_hash,access_expires_at,refresh_expires_at,
  provider_environment
) values (
  '51515151-1000-4000-8000-000000000001',
  '51515151-5151-4515-8515-515151515151',0,1,1,
  decode(repeat('11',32),'hex'),decode(repeat('12',12),'hex'),
  decode(repeat('13',16),'hex'),decode(repeat('14',32),'hex'),
  decode(repeat('15',12),'hex'),decode(repeat('16',16),'hex'),
  decode(repeat('17',32),'hex'),decode(repeat('18',12),'hex'),
  decode(repeat('19',16),'hex'),repeat('a',64),
  now()+interval '1 hour',now()+interval '1 day','sandbox'
);
insert into argus_private.webull_asset_mappings(
  instrument_id,account_id,connection_id,user_id,deletion_epoch,
  provider_environment,provider_asset_id_ciphertext,provider_asset_id_hash,
  key_version,asset_kind,provider_asset_kind
) values (
  '51515151-5000-4000-8000-000000000001',
  '51515151-2000-4000-8000-000000000001',
  '51515151-1000-4000-8000-000000000001',
  '51515151-5151-4515-8515-515151515151',0,'sandbox',
  decode(repeat('21',32),'hex'),repeat('c',64),1,'equity','EQUITY'
);

set local role argus_member;
select lives_ok(
  $$select * from argus_private.resolve_webull_asset_mapping_scoped(
      '51515151-5000-4000-8000-000000000001',
      '51515151-2000-4000-8000-000000000001',
      '51515151-1000-4000-8000-000000000001',0,'sandbox',
      decode(repeat('22',32),'hex'),repeat('c',64),2,'etf','ETF'
    )$$,
  'a reviewed asset mapping cannot be arbitrarily reclassified'
);
reset role;
select ok(
  (select mapping.asset_kind='equity'
          and mapping.provider_asset_kind='EQUITY'
          and mapping.key_version=1
     from argus_private.webull_asset_mappings mapping
    where mapping.instrument_id='51515151-5000-4000-8000-000000000001'),
  'asset classification changes only from unsupported legacy state'
);

set local role argus_member;
select is(
  (select scope.result_list_generation
     from argus_private.begin_brokerage_order_list_ingestion(
       '51515151-2000-4000-8000-000000000001',
       '51515151-1000-4000-8000-000000000001',0
     ) scope),
  1::bigint,
  'nonempty order-list ingestion reserves the next scoped generation'
);
select is(
  argus_private.append_brokerage_order_list_observation(
    '51515151-2000-4000-8000-000000000001',
    '51515151-1000-4000-8000-000000000001',0,1,
    '51515151-6000-4000-8000-000000000001',
    decode(repeat('31',32),'hex'),repeat('d',64),1,
    '51515151-5000-4000-8000-000000000001','pending',0,
    '{"id":"51515151-6000-4000-8000-000000000001","instrument_id":"51515151-5000-4000-8000-000000000001","symbol":"AAPL","side":"buy","provider_side":"BUY","order_type":"market","provider_order_type":"MARKET","time_in_force":"day","provider_time_in_force":"DAY","quantity":"1","limit_price":null,"stop_price":null,"filled_quantity":"0","average_fill_price":null,"currency":"USD","state":"pending","provider_state":"PENDING","terminal":false}'::jsonb,
    now(),now()
  ),
  1::bigint,
  'order-list observation atomically binds mapping and typed order evidence'
);
select is(
  argus_private.complete_brokerage_order_list_ingestion(
    '51515151-2000-4000-8000-000000000001',
    '51515151-1000-4000-8000-000000000001',0,1,
    '[{"id":"51515151-6000-4000-8000-000000000001","instrument_id":"51515151-5000-4000-8000-000000000001","symbol":"AAPL","side":"buy","provider_side":"BUY","order_type":"market","provider_order_type":"MARKET","time_in_force":"day","provider_time_in_force":"DAY","quantity":"1","limit_price":null,"stop_price":null,"filled_quantity":"0","average_fill_price":null,"currency":"USD","state":"pending","provider_state":"PENDING","terminal":false}]'::jsonb,
    now(),now(),now()+interval '5 minutes','available',null
  ),
  1::bigint,
  'nonempty order-list completion persists one typed list watermark'
);
select throws_ok(
  $$select argus_private.append_brokerage_order_list_observation(
      '51515151-2000-4000-8000-000000000001',
      '51515151-1000-4000-8000-000000000001',0,2,
      '51515151-6000-4000-8000-000000000001',
      decode(repeat('31',32),'hex'),repeat('d',64),1,
      '51515151-5000-4000-8000-000000000001','unknown',0,
      '{"id":"51515151-6000-4000-8000-000000000001","instrument_id":"51515151-5000-4000-8000-000000000001","symbol":"AAPL","side":"buy","provider_side":"BUY","order_type":"market","provider_order_type":"MARKET","time_in_force":"day","provider_time_in_force":"DAY","quantity":"1","limit_price":null,"stop_price":null,"filled_quantity":"0","average_fill_price":null,"currency":"USD","state":"unknown","provider_state":"UNKNOWN","terminal":false}'::jsonb,
      now(),now()
    )$$,
  'P0001','non_monotonic_order_projection',
  'typed order evidence cannot regress within a provider list'
);
select is(
  (select scope.result_list_generation
     from argus_private.begin_brokerage_order_list_ingestion(
       '51515151-2000-4000-8000-000000000001',
       '51515151-1000-4000-8000-000000000001',0
     ) scope),
  2::bigint,
  'empty order-list ingestion advances the same scoped generation sequence'
);
select is(
  argus_private.complete_brokerage_order_list_ingestion(
    '51515151-2000-4000-8000-000000000001',
    '51515151-1000-4000-8000-000000000001',0,2,'[]'::jsonb,
    now(),now(),now()+interval '5 minutes','available',null
  ),
  2::bigint,
  'empty order-list completion is a valid typed watermark'
);
select throws_ok(
  $$select argus_private.complete_brokerage_order_list_ingestion(
      '51515151-2000-4000-8000-000000000001',
      '51515151-1000-4000-8000-000000000001',0,3,
      '[{"id":"51515151-6000-4000-8000-000000000099"}]'::jsonb,
      now(),now(),now()+interval '5 minutes','available',null
    )$$,
  '23514','order_list_generation_mismatch',
  'list completion rejects a header that is not bound to typed order facts'
);
reset role;
select throws_ok(
  $$update argus_brokerage.order_projection_generations
       set provider_state='MUTATED'
     where order_id='51515151-6000-4000-8000-000000000001'$$,
  'P0001','immutable_record',
  'typed order projection evidence is immutable'
);
select is(
  (select pg_catalog.count(*)::bigint
     from argus_private.projection_generation_snapshots snapshot
     join argus_brokerage.projection_generations generation
       on generation.tenant_id=snapshot.tenant_id
      and generation.lifecycle_id=snapshot.lifecycle_id
      and generation.id=snapshot.generation_id
    where generation.account_id='51515151-2000-4000-8000-000000000001'
      and generation.resource_type='orders'),
  2::bigint,
  'order-list headers retain one private envelope per typed watermark'
);

insert into argus_brokerage.connections(
  id,user_id,deletion_epoch,status
)
select '51515151-1000-4000-8000-000000000002',member.user_id,
       member.deletion_epoch,'denied'
  from argus_app.members member
 where member.user_id='51515151-5151-4515-8515-515151515151';
select throws_ok(
  $$insert into argus_brokerage.active_account_selections(
      user_id,deletion_epoch,connection_id,account_id
    ) values (
      '51515151-5151-4515-8515-515151515151',0,
      '51515151-1000-4000-8000-000000000002',
      '51515151-2000-4000-8000-000000000001'
    )$$,
  '23503',null,
  'active selection cannot combine one member account with another connection'
);
select throws_ok(
  $$insert into argus_brokerage.projection_generations(
      user_id,deletion_epoch,connection_id,account_id,resource_type,generation,
      normalized_payload,provider_observed_at,fetched_at,expires_at,availability
    ) values (
      '51515151-5151-4515-8515-515151515151',0,
      '51515151-1000-4000-8000-000000000002',
      '51515151-2000-4000-8000-000000000001','balance',99,
      '{"currency":"USD","cash":"1","buying_power":null,"market_value":"1","total_equity":"2"}',
      now(),now(),now()+interval '5 minutes','available'
    )$$,
  '23503',null,
  'projection generation cannot combine an account with another connection'
);

insert into argus_brokerage.projection_generations(
  id,user_id,deletion_epoch,connection_id,account_id,resource_type,generation,
  normalized_payload,provider_observed_at,fetched_at,expires_at,availability
)
select '51515151-3000-4000-8000-000000000001',member.user_id,
       member.deletion_epoch,'51515151-1000-4000-8000-000000000001',
       '51515151-2000-4000-8000-000000000001','balance',1,
       '{"currency":"USD","cash":"10","buying_power":null,"market_value":"12.5","total_equity":"22.5"}'::jsonb,
       now(),now(),now()+interval '5 minutes','available'
  from argus_app.members member
 where member.user_id='51515151-5151-4515-8515-515151515151';
select is(
  (
    select fact.total_equity::text
      from argus_brokerage.projection_balance_facts fact
     where fact.generation_id='51515151-3000-4000-8000-000000000001'
  ),
  '22.500000000000000000'::text,
  'balance projection is materialized as typed numeric facts'
);
select is(
  argus_private.read_brokerage_projection_payload(
    '51515151-3000-4000-8000-000000000001'
  )->>'cash',
  '10.000000000000000000'::text,
  'public projection adapter reconstructs data only from typed facts'
);
select ok(
  (
    select snapshot.snapshot_hash=encode(
      digest(convert_to(snapshot.snapshot_payload::text,'UTF8'),'sha256'),
      'hex'
    ) and snapshot.snapshot_bytes=octet_length(
      convert_to(snapshot.snapshot_payload::text,'UTF8')
    )
      from argus_private.projection_generation_snapshots snapshot
     where snapshot.generation_id='51515151-3000-4000-8000-000000000001'
  ),
  'snapshot envelope is versioned, hashed and byte-counted'
);
select throws_ok(
  $$insert into argus_brokerage.projection_generations(
      user_id,deletion_epoch,connection_id,account_id,resource_type,generation,
      normalized_payload,provider_observed_at,fetched_at,expires_at,availability
    )
    select member.user_id,member.deletion_epoch,
           '51515151-1000-4000-8000-000000000001',
           '51515151-2000-4000-8000-000000000001','balance',2,
           '{"access_token":"never-store"}'::jsonb,now(),now(),
           now()+interval '5 minutes','available'
      from argus_app.members member
     where member.user_id='51515151-5151-4515-8515-515151515151'$$,
  '22023','invalid_projection_snapshot',
  'credential-shaped provider snapshot is rejected before storage'
);

insert into argus_private.provider_commands(
  id,user_id,deletion_epoch,connection_id,account_id,operation,
  client_order_id,idempotency_key,normalized_payload_hash,
  reviewed_payload_hash,capability_version,state,egress_started_at,
  provider_order_ref_hash,normalized_payload,order_id
) values (
  '51515151-7000-4000-8000-000000000001',
  '51515151-5151-4515-8515-515151515151',0,
  '51515151-1000-4000-8000-000000000001',
  '51515151-2000-4000-8000-000000000001','place',
  'argus_u5_terminal_command_00000001','u5-terminal-command-idempotency-0001',
  repeat('e',64),repeat('f',64),3,'accepted',now(),repeat('d',64),
  '{"instrument_id":"51515151-5000-4000-8000-000000000001","side":"buy","order_type":"market","time_in_force":"day","quantity":"1"}'::jsonb,
  '51515151-6000-4000-8000-000000000001'
);
insert into argus_private.provider_command_attempts(
  user_id,deletion_epoch,command_id,attempt_number,attempt_kind,outcome
) values (
  '51515151-5151-4515-8515-515151515151',0,
  '51515151-7000-4000-8000-000000000001',1,'egress','accepted'
);
set local role argus_member;
select ok(
  argus_private.clear_webull_connection_materialization(
    '51515151-1000-4000-8000-000000000001'
  ),
  'terminal command history does not prevent cryptographic material cleanup'
);
reset role;
select ok(
  not exists (
    select 1 from argus_private.webull_credentials credential
     where credential.connection_id='51515151-1000-4000-8000-000000000001'
  ) and exists (
    select 1 from argus_brokerage.accounts account
     where account.id='51515151-2000-4000-8000-000000000001'
       and account.status='unavailable'
  ) and exists (
    select 1 from argus_private.provider_commands command
     where command.id='51515151-7000-4000-8000-000000000001'
       and command.state='accepted'
  ) and exists (
    select 1 from argus_private.webull_order_mappings mapping
     where mapping.order_id='51515151-6000-4000-8000-000000000001'
  ) and exists (
    select 1 from argus_brokerage.order_projection_generations generation
     where generation.order_id='51515151-6000-4000-8000-000000000001'
  ),
  'cleanup destroys credentials while retaining terminal command and typed order evidence'
);

select * from finish();
rollback;

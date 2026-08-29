do $$
declare
  argus_schema_count integer;
  fence_name text;
  fenced_count integer;
begin
  if to_regclass('argus_private.kill_switches') is null then
    select count(*) into argus_schema_count
      from pg_namespace
     where nspname in ('argus_app','argus_brokerage','argus_private');
    if argus_schema_count <> 0 then
      raise exception 'partial_argus_schema_without_kill_switches';
    end if;
    raise notice 'clean Supabase project: baseline migration will create enabled fences';
    return;
  end if;

  lock table argus_private.kill_switches in share row exclusive mode;

  foreach fence_name in array array[
    'background_workers',
    'provider_egress',
    'order_mutations'
  ]
  loop
    update argus_private.kill_switches
       set enabled = true,
           reason = 'protected U9 remediation: ' || fence_name || ' fenced',
           updated_at = clock_timestamp()
     where name = fence_name
       and (
         enabled is distinct from true
         or reason is distinct from
           'protected U9 remediation: ' || fence_name || ' fenced'
       );

    select count(*) into fenced_count
      from argus_private.kill_switches
     where name = fence_name
       and enabled
       and reason = 'protected U9 remediation: ' || fence_name || ' fenced';
    if fenced_count <> 1 then
      raise exception 'missing_deployment_kill_switch:%', fence_name;
    end if;
  end loop;

  select count(*) into fenced_count
    from argus_private.kill_switches
   where name in ('background_workers','provider_egress','order_mutations')
     and enabled;
  if fenced_count <> 3 then
    raise exception 'incomplete_deployment_kill_switch_inventory';
  end if;
end
$$;

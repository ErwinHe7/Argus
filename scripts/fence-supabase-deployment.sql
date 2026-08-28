do $$
declare
  argus_schema_count integer;
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

  update argus_private.kill_switches
     set enabled = true,
         reason = 'hosted development deployment',
         updated_at = clock_timestamp()
   where name in ('background_workers','provider_egress','order_mutations');
  get diagnostics fenced_count = row_count;
  if fenced_count <> 3 then
    raise exception 'incomplete_deployment_kill_switch_inventory';
  end if;
end
$$;

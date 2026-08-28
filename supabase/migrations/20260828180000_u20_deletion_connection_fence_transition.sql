-- The generic live-epoch trigger normally rejects every mutation once member
-- deletion starts. Permit only the exact old-epoch Webull connection
-- transition used by the tombstone fence: connected state to disconnected,
-- with no business fields changed.

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

  if member_epoch is not null
     and member_status = 'active'
     and new.deletion_epoch = member_epoch then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and tg_table_schema = 'argus_brokerage'
     and tg_table_name = 'connections'
     and member_status in ('deletion_pending','purging')
     and member_epoch = old.deletion_epoch + 1
     and new.user_id = old.user_id
     and new.deletion_epoch = old.deletion_epoch
     and to_jsonb(new)->>'status' = 'disconnected'
     and to_jsonb(old)->>'status' <> 'disconnected'
     and to_jsonb(new)->>'egress_fenced_at' is not null
     and to_jsonb(new)->>'disconnected_at' is not null
     and (to_jsonb(new) - array[
       'status','egress_fenced_at','disconnected_at','last_error_code','updated_at'
     ]) = (to_jsonb(old) - array[
       'status','egress_fenced_at','disconnected_at','last_error_code','updated_at'
     ]) then
    return new;
  end if;

  raise exception 'member_deletion_epoch_mismatch';
end
$$;

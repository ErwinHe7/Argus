-- Preserve the live-epoch fence while allowing the receipt-gated admin retry
-- function to move a failed deletion request back to the purge queue.

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

  if tg_op = 'UPDATE'
     and tg_table_schema = 'argus_app'
     and tg_table_name = 'privacy_requests'
     and member_status in ('deletion_pending','purging')
     and member_epoch = new.deletion_epoch
     and new.user_id = old.user_id
     and new.deletion_epoch = old.deletion_epoch
     and to_jsonb(old)->>'request_type' = 'deletion'
     and to_jsonb(new)->>'request_type' = 'deletion'
     and to_jsonb(old)->>'status' = 'failed'
     and to_jsonb(new)->>'status' = 'queued'
     and to_jsonb(new)->>'failure_code' is null
     and to_jsonb(new)->>'completed_at' is null
     and (to_jsonb(new) - array['status','failure_code','completed_at'])
       = (to_jsonb(old) - array['status','failure_code','completed_at']) then
    return new;
  end if;

  raise exception 'member_deletion_epoch_mismatch';
end
$$;

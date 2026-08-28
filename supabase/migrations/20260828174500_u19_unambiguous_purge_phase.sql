-- Qualify purge-phase references because the table-returning function exposes
-- purge_phase as a PL/pgSQL output variable on hosted PostgreSQL 17.

create or replace function argus_private.prepare_member_purge(p_tombstone_id uuid)
returns table(user_id uuid, deletion_epoch bigint, purge_phase text)
language plpgsql security definer
set search_path = pg_catalog, argus_private, argus_app
as $$
declare tombstone argus_private.deletion_tombstones%rowtype;
begin
  perform argus_private.fence_webull_member_for_deletion(p_tombstone_id);
  select * into tombstone from argus_private.deletion_tombstones
   where id = p_tombstone_id and status in ('pending','purging','failed','purged') for update;
  if tombstone.id is null then raise exception 'tombstone_missing'; end if;
  if tombstone.webull_fenced_at is null or tombstone.webull_credentials_destroyed_at is null then
    raise exception 'webull_fence_incomplete';
  end if;
  if tombstone.purge_phase = 'requested' and not exists (
    select 1 from argus_app.members member where member.user_id = tombstone.user_id
      and member.deletion_epoch = tombstone.deletion_epoch
      and member.status in ('deletion_pending','purging')
  ) then raise exception 'deletion_epoch_changed'; end if;
  update argus_app.members set status = 'purging'
   where members.user_id = tombstone.user_id;
  update argus_private.deletion_tombstones target set status = 'purging',
    purge_phase = case when target.purge_phase = 'requested' then 'neutralized'
                       else target.purge_phase end
   where target.id = tombstone.id and target.purge_phase <> 'complete';
  update argus_private.job_runs set status = 'cancelled', lease_token = null,
    leased_until = null, last_error_code = 'member_deleted', updated_at = clock_timestamp()
   where job_runs.user_id = tombstone.user_id
     and job_runs.deletion_epoch < tombstone.deletion_epoch
     and status not in ('succeeded','dead_lettered','cancelled');
  delete from argus_private.outbox_events where outbox_events.user_id = tombstone.user_id;
  select * into tombstone from argus_private.deletion_tombstones where id = p_tombstone_id;
  return query select tombstone.user_id, tombstone.deletion_epoch, tombstone.purge_phase;
end
$$;

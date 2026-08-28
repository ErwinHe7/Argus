-- Keep the epoch-fenced privacy request insert while active, then enter the
-- deletion-pending state before the tombstone's immediate Webull fence fires.

create or replace function argus_private.begin_member_deletion(
  p_receipt_hash text,
  p_session_id uuid,
  p_dedupe_key text
)
returns uuid
language plpgsql security definer
set search_path = pg_catalog, argus_private, argus_app
as $$
declare
  member_record argus_app.members%rowtype;
  request_id uuid;
  tombstone_id uuid;
  consumed_receipt_id uuid;
  next_epoch bigint;
  existing_owner_id uuid;
begin
  if p_receipt_hash !~ '^[a-f0-9]{64}$' or p_dedupe_key !~ '^[!-~]{16,128}$' then
    raise exception 'invalid_deletion_request';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('privacy.deletion.requested:' || p_dedupe_key, 0)
  );
  select request.id, tombstone.user_id into request_id, existing_owner_id
    from argus_private.outbox_events event
    join argus_private.deletion_tombstones tombstone on tombstone.id = event.aggregate_id
    join argus_app.privacy_requests request
      on request.user_id = tombstone.user_id
     and request.deletion_epoch = tombstone.deletion_epoch
     and request.request_type = 'deletion'
   where event.topic = 'argus_jobs'
     and event.event_type = 'privacy.deletion.requested'
     and event.dedupe_key = p_dedupe_key;
  if existing_owner_id is not null
     and existing_owner_id is distinct from argus_private.request_user_id() then
    raise exception 'step_up_required' using errcode = '42501';
  end if;
  if request_id is not null then return request_id; end if;
  select * into member_record from argus_app.members member
   where member.user_id = argus_private.request_user_id()
     and member.status = 'active' for update;
  if member_record.user_id is null then
    select request.id into request_id
      from argus_private.outbox_events event
      join argus_private.deletion_tombstones tombstone on tombstone.id = event.aggregate_id
      join argus_app.privacy_requests request
        on request.user_id = tombstone.user_id
       and request.deletion_epoch = tombstone.deletion_epoch
       and request.request_type = 'deletion'
     where event.topic = 'argus_jobs'
       and event.event_type = 'privacy.deletion.requested'
       and event.dedupe_key = p_dedupe_key
       and tombstone.user_id = argus_private.request_user_id();
    if request_id is not null then return request_id; end if;
    raise exception 'member_not_active';
  end if;
  update argus_private.step_up_receipts receipt
     set consumed_at = clock_timestamp()
   where receipt.receipt_hash = p_receipt_hash
     and receipt.user_id = member_record.user_id
     and receipt.session_id = p_session_id
     and receipt.deletion_epoch = member_record.deletion_epoch
     and receipt.action = 'argus_delete'
     and receipt.aal = 'aal2'
     and receipt.consumed_at is null
     and receipt.expires_at > clock_timestamp()
  returning id into consumed_receipt_id;
  if consumed_receipt_id is null then
    raise exception 'step_up_required' using errcode = '42501';
  end if;
  next_epoch := member_record.deletion_epoch + 1;
  update argus_app.members
     set deletion_epoch = next_epoch
   where user_id = member_record.user_id;
  insert into argus_app.privacy_requests(
    user_id, deletion_epoch, request_type, status
  ) values (member_record.user_id, next_epoch, 'deletion', 'queued')
  returning id into request_id;
  update argus_app.members
     set status = 'deletion_pending',
         deletion_requested_at = clock_timestamp()
   where user_id = member_record.user_id
     and deletion_epoch = next_epoch
     and status = 'active';
  if not found then
    raise exception 'deletion_epoch_changed';
  end if;
  insert into argus_private.deletion_tombstones(
    user_id, deletion_epoch, status
  ) values (member_record.user_id, next_epoch, 'pending')
  returning id into tombstone_id;
  insert into argus_private.outbox_events(
    user_id, deletion_epoch, topic, event_type, aggregate_id, dedupe_key
  ) values (
    null, null, 'argus_jobs', 'privacy.deletion.requested', tombstone_id,
    p_dedupe_key
  );
  return request_id;
end
$$;

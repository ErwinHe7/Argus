-- PostgreSQL resolves RETURNS TABLE column names as PL/pgSQL variables. Use
-- the named unique constraint so job_run_id cannot be mistaken for the output
-- parameter while recording a claimed attempt.

create or replace function argus_private.claim_next_argus_job(p_visibility_seconds integer default 45)
returns table(
  job_run_id uuid,
  lease_token uuid,
  queue_message_id bigint,
  read_count integer,
  event_id uuid,
  event_type text,
  handler_name text,
  aggregate_id uuid,
  user_id uuid,
  deletion_epoch bigint
)
language plpgsql security invoker
set search_path = pg_catalog, argus_private, argus_app, pgmq, extensions
as $$
declare
  queued record;
  event_record argus_private.outbox_events%rowtype;
  parsed_event_id uuid;
  parsed_handler text;
  token uuid;
  run_id uuid;
  diagnostic text;
begin
  if p_visibility_seconds < 15 or p_visibility_seconds > 55 then
    raise exception 'invalid_visibility_timeout';
  end if;
  for queued in select * from pgmq.read('argus_jobs', p_visibility_seconds, 1)
  loop
    diagnostic := encode(extensions.digest(queued.message::text, 'sha256'), 'hex');
    if jsonb_typeof(queued.message) <> 'object'
       or (select count(*) from jsonb_object_keys(queued.message)) <> 2
       or not (queued.message ? 'version' and queued.message ? 'event_id')
       or queued.message ->> 'version' <> '1'
       or queued.message ->> 'event_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
      perform argus_private.dead_letter_queue_message(
        queued.msg_id, null, null, 'invalid_event_payload', diagnostic
      );
      continue;
    end if;

    parsed_event_id := (queued.message ->> 'event_id')::uuid;
    select * into event_record from argus_private.outbox_events event
     where event.id = parsed_event_id and event.topic = 'argus_jobs';
    parsed_handler := argus_private.retained_job_handler(event_record.event_type);
    if event_record.id is null or parsed_handler is null then
      perform argus_private.dead_letter_queue_message(
        queued.msg_id, event_record.id, parsed_handler,
        case when event_record.id is null then 'event_not_found' else 'handler_not_allowed' end,
        diagnostic
      );
      continue;
    end if;

    if exists (
      select 1 from argus_private.consumer_receipts receipt
       where receipt.outbox_event_id = event_record.id
         and receipt.handler_name = parsed_handler
    ) then
      perform pgmq.archive('argus_jobs', queued.msg_id);
      continue;
    end if;

    if event_record.user_id is not null and not argus_private.assert_worker_event_current(event_record.id) then
      perform pgmq.archive('argus_jobs', queued.msg_id);
      continue;
    end if;

    token := gen_random_uuid();
    insert into argus_private.job_runs(
      user_id, deletion_epoch, job_type, source_event_id, status, attempts,
      lease_token, leased_until, queue_message_id, handler_name
    ) values (
      event_record.user_id, event_record.deletion_epoch, parsed_handler,
      event_record.id, 'leased', queued.read_ct, token,
      clock_timestamp() + make_interval(secs => p_visibility_seconds),
      queued.msg_id, parsed_handler
    )
    on conflict (source_event_id) where source_event_id is not null do update
      set status = 'leased', attempts = excluded.attempts,
          lease_token = excluded.lease_token, leased_until = excluded.leased_until,
          queue_message_id = excluded.queue_message_id,
          handler_name = excluded.handler_name, updated_at = clock_timestamp()
      where job_runs.status in ('queued','leased','retry')
        and (job_runs.leased_until is null or job_runs.leased_until <= clock_timestamp())
    returning id into run_id;
    if run_id is null then
      if exists (
        select 1 from argus_private.job_runs existing
         where existing.source_event_id = event_record.id
           and existing.status in ('succeeded','dead_lettered','cancelled')
      ) then
        perform pgmq.archive('argus_jobs', queued.msg_id);
      else
        perform pgmq.set_vt('argus_jobs', queued.msg_id, 10);
      end if;
      continue;
    end if;

    insert into argus_private.job_attempts(
      job_run_id, attempt_number, outcome
    ) values (run_id, queued.read_ct, 'started')
    on conflict on constraint job_attempts_job_run_id_attempt_number_key do update
      set outcome = 'started', failure_code = null, diagnostic_hash = null,
          started_at = clock_timestamp(), completed_at = null;

    return query select run_id, token, queued.msg_id, queued.read_ct,
      event_record.id, event_record.event_type, parsed_handler,
      event_record.aggregate_id, event_record.user_id, event_record.deletion_epoch;
    return;
  end loop;
end
$$;

begin;

drop function argus_private.prepare_privacy_export_download(uuid);

create function argus_private.prepare_privacy_export_download(p_request_id uuid)
returns table(
  access_lease_id uuid,
  bucket_id text,
  object_path text,
  expires_in_seconds integer,
  content_checksum text,
  byte_size bigint
)
language plpgsql security definer
set search_path=pg_catalog,argus_private,argus_app,extensions as $$
declare context_record record;
declare object_record argus_private.managed_storage_objects%rowtype;
declare generation_record argus_private.privacy_export_generations%rowtype;
declare lease_id uuid:=extensions.gen_random_uuid();
begin
  select * into context_record from argus_private.read_trusted_request_context();
  if context_record.user_id is null
     or not argus_private.lock_open_member_lifecycle(
       context_record.tenant_id,context_record.lifecycle_id,context_record.user_id
     ) then raise exception 'member_lifecycle_not_open'; end if;
  select object,generation into object_record,generation_record
    from argus_private.privacy_export_generations generation
    join argus_app.privacy_requests request on request.id=generation.request_id
    join argus_private.managed_storage_objects object
      on object.id=generation.storage_object_id
   where request.id=p_request_id
     and request.tenant_id=context_record.tenant_id
     and request.lifecycle_id=context_record.lifecycle_id
     and request.user_id=context_record.user_id
     and request.status='completed' and generation.state='published'
     and generation.expires_at>pg_catalog.clock_timestamp()
     and generation.archive_checksum is not null
     and generation.archive_bytes is not null
     and object.state='published'
   order by generation.generation_number desc limit 1;
  if object_record.id is null then raise exception 'privacy_export_not_available'; end if;
  insert into argus_private.storage_access_leases(
    id,tenant_id,lifecycle_id,user_id,storage_object_id,purpose,expires_at
  ) values (
    lease_id,context_record.tenant_id,context_record.lifecycle_id,
    context_record.user_id,object_record.id,'privacy_export_download',
    pg_catalog.clock_timestamp()+interval '30 seconds'
  );
  return query select
    lease_id,
    object_record.bucket_id,
    object_record.object_path,
    30,
    generation_record.archive_checksum,
    generation_record.archive_bytes;
end
$$;

alter function argus_private.prepare_privacy_export_download(uuid)
  owner to argus_jobs_owner;
revoke all on function argus_private.prepare_privacy_export_download(uuid)
  from public,anon,authenticated,argus_runtime,argus_member,argus_staff,argus_callback,argus_worker;
grant execute on function argus_private.prepare_privacy_export_download(uuid)
  to argus_member;

commit;

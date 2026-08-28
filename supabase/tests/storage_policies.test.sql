begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, pg_catalog, public;

select plan(14);

select is((select public from storage.buckets where id = 'member-media'), false, 'member media bucket is private');
select is((select public from storage.buckets where id = 'privacy-exports'), false, 'privacy export bucket is private');
select is((select public from storage.buckets where id = 'media-quarantine'), false, 'media quarantine bucket is private');
select is((select file_size_limit from storage.buckets where id = 'member-media'), 10485760::bigint, 'member media has a bounded size');
select is((select file_size_limit from storage.buckets where id = 'privacy-exports'), 52428800::bigint, 'privacy exports have a bounded size');

select is(
  (select count(*)::bigint from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'argus_member_media_%'),
  4::bigint,
  'member media has explicit select, insert, update, and delete policies'
);
select is(
  (select count(*)::bigint from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'argus_privacy_exports_%'),
  1::bigint,
  'privacy exports are download-only for members'
);
select is(
  (select count(*)::bigint from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'argus_media_quarantine_%'),
  0::bigint,
  'quarantine has no client policy'
);
select is(
  (select count(*)::bigint from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'argus_%' and roles @> array['anon']::name[]),
  0::bigint,
  'anon receives no Argus Storage policy'
);

insert into storage.objects (id, bucket_id, name, owner_id)
values (
  'aaaaaaaa-8000-4000-8000-000000000001', 'member-media',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/avatar.webp',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
);

set local role authenticated;
do $$ begin
  perform set_config(
    'request.jwt.claims',
    '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}',
    true
  );
end $$;
select is(
  (select count(*)::bigint from storage.objects where bucket_id = 'member-media'),
  0::bigint,
  'user B cannot read user A media object by identifier'
);

select throws_ok(
  $$insert into storage.objects (id, bucket_id, name, owner_id)
    values (
      'bbbbbbbb-8000-4000-8000-000000000001', 'member-media',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/stolen.webp',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
    )$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'user B cannot upload into user A path'
);

do $$ begin
  perform set_config(
    'request.jwt.claims',
    '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}',
    true
  );
end $$;
select is(
  (select count(*)::bigint from storage.objects where bucket_id = 'member-media'),
  1::bigint,
  'user A can read the owned media object'
);
reset role;

select is(
  (select count(*)::bigint from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'argus_%'
      and coalesce(qual, '') like '%auth.role()%'),
  0::bigint,
  'Storage policies do not use deprecated auth.role()'
);
select is(
  (select count(*)::bigint from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'argus_%'
      and coalesce(with_check, '') like '%auth.role()%'),
  0::bigint,
  'Storage WITH CHECK policies do not use deprecated auth.role()'
);

select * from finish();
rollback;

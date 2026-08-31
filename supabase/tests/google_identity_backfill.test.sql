begin;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(6);

select is(
  (
    select count(*)::bigint
      from auth.users auth_user
     where auth_user.deleted_at is null
       and exists (
         select 1 from auth.identities identity
          where identity.user_id=auth_user.id
            and identity.provider='google'
       )
       and not exists (
         select 1 from argus_app.member_lifecycles lifecycle
          where lifecycle.identity_subject_id=auth_user.id
            and lifecycle.tenant_id=auth_user.id
            and lifecycle.state='open'
       )
  ),
  0::bigint,
  'every live Google identity owns one open Argus lifecycle'
);

select is(
  (
    select count(*)::bigint
      from auth.users auth_user
     where auth_user.deleted_at is null
       and exists (
         select 1 from auth.identities identity
          where identity.user_id=auth_user.id
            and identity.provider='google'
       )
       and not exists (
         select 1
           from argus_app.members member
           join argus_app.member_lifecycles lifecycle
             on lifecycle.id=member.lifecycle_id
            and lifecycle.tenant_id=member.tenant_id
            and lifecycle.identity_subject_id=member.user_id
          where member.user_id=auth_user.id
            and member.tenant_id=auth_user.id
            and member.status='active'
            and lifecycle.state='open'
       )
  ),
  0::bigint,
  'every live Google identity owns one active Argus member root'
);

select is(
  (
    select count(*)::bigint
      from auth.users auth_user
      join argus_app.members member on member.user_id=auth_user.id
     where auth_user.deleted_at is null
       and exists (
         select 1 from auth.identities identity
          where identity.user_id=auth_user.id
            and identity.provider='google'
       )
       and not exists (
         select 1 from argus_app.profiles profile
          where profile.user_id=member.user_id
            and profile.tenant_id=member.tenant_id
            and profile.lifecycle_id=member.lifecycle_id
            and profile.deletion_epoch=member.deletion_epoch
       )
  ),
  0::bigint,
  'Google members have an ownership-bound profile'
);

select is(
  (
    select count(*)::bigint
      from auth.users auth_user
      join argus_app.members member on member.user_id=auth_user.id
     where auth_user.deleted_at is null
       and exists (
         select 1 from auth.identities identity
          where identity.user_id=auth_user.id
            and identity.provider='google'
       )
       and not exists (
         select 1 from argus_app.preferences preference
          where preference.user_id=member.user_id
            and preference.tenant_id=member.tenant_id
            and preference.lifecycle_id=member.lifecycle_id
            and preference.deletion_epoch=member.deletion_epoch
       )
  ),
  0::bigint,
  'Google members have ownership-bound preferences'
);

select is(
  (
    select count(*)::bigint
      from auth.users auth_user
      join argus_app.members member on member.user_id=auth_user.id
     where auth_user.deleted_at is null
       and exists (
         select 1 from auth.identities identity
          where identity.user_id=auth_user.id
            and identity.provider='google'
       )
       and not exists (
         select 1 from argus_app.onboarding_states onboarding
          where onboarding.user_id=member.user_id
            and onboarding.tenant_id=member.tenant_id
            and onboarding.lifecycle_id=member.lifecycle_id
            and onboarding.deletion_epoch=member.deletion_epoch
       )
  ),
  0::bigint,
  'Google members have ownership-bound onboarding state'
);

select is(
  (
    select count(*)::bigint
      from auth.users auth_user
      join argus_app.members member on member.user_id=auth_user.id
     where auth_user.deleted_at is null
       and exists (
         select 1 from auth.identities identity
          where identity.user_id=auth_user.id
            and identity.provider='google'
       )
       and not exists (
         select 1 from argus_app.notification_preferences notification
          where notification.user_id=member.user_id
            and notification.tenant_id=member.tenant_id
            and notification.lifecycle_id=member.lifecycle_id
            and notification.deletion_epoch=member.deletion_epoch
       )
  ),
  0::bigint,
  'Google members have ownership-bound notification preferences'
);

select * from finish();
rollback;

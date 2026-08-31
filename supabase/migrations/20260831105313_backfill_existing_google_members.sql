begin;

-- The target project already owns its Supabase Auth users.  Existing users do
-- not fire the Argus AFTER INSERT provisioning trigger when these schemas are
-- installed, so take a transaction-local snapshot of only live Google-backed
-- identities and provision the same private member roots as the trigger.
-- auth.identities has no soft-delete column: unlinking removes the identity,
-- while auth.users.deleted_at is the authoritative soft-deletion fence.
create temporary table argus_google_member_backfill_candidates (
  user_id uuid primary key
) on commit drop;

insert into pg_temp.argus_google_member_backfill_candidates(user_id)
select auth_user.id
  from auth.users auth_user
 where auth_user.deleted_at is null
   and exists (
     select 1
       from auth.identities identity
      where identity.user_id=auth_user.id
        and identity.provider='google'
   );

-- Keep all Argus writes under the existing identity owner and its forced-RLS
-- policies.  The temporary membership is grantor-scoped and is removed before
-- commit; a failure rolls the grant and every backfill row back atomically.
do $membership$
begin
  execute pg_catalog.format(
    'grant argus_identity_owner to %1$I with inherit false,set true,admin false granted by %1$I',
    current_user
  );
end
$membership$;

grant select on table pg_temp.argus_google_member_backfill_candidates
  to argus_identity_owner;

set local role argus_identity_owner;

insert into argus_app.member_lifecycles(tenant_id,identity_subject_id)
select candidate.user_id,candidate.user_id
  from pg_temp.argus_google_member_backfill_candidates candidate
on conflict (identity_subject_id) do nothing;

do $lifecycle_contract$
begin
  if exists (
    select 1
      from pg_temp.argus_google_member_backfill_candidates candidate
      left join argus_app.member_lifecycles lifecycle
        on lifecycle.identity_subject_id=candidate.user_id
     where lifecycle.id is null
        or lifecycle.tenant_id<>candidate.user_id
        or lifecycle.state<>'open'
  ) then
    raise exception 'google_member_backfill_lifecycle_conflict'
      using errcode='23514';
  end if;
end
$lifecycle_contract$;

insert into argus_app.members(user_id,tenant_id,lifecycle_id)
select candidate.user_id,candidate.user_id,lifecycle.id
  from pg_temp.argus_google_member_backfill_candidates candidate
  join argus_app.member_lifecycles lifecycle
    on lifecycle.identity_subject_id=candidate.user_id
   and lifecycle.tenant_id=candidate.user_id
   and lifecycle.state='open'
on conflict (user_id) do nothing;

-- These inserts intentionally match provision_argus_member().  The existing
-- bind_argus_app_member_lifecycle triggers derive and enforce tenant_id,
-- lifecycle_id, and the current deletion_epoch.  ON CONFLICT preserves any
-- profile or preference data already owned by the account.
insert into argus_app.profiles(
  user_id,deletion_epoch,display_name,locale
)
select member.user_id,member.deletion_epoch,'Argus member','en-US'
  from pg_temp.argus_google_member_backfill_candidates candidate
  join argus_app.members member on member.user_id=candidate.user_id
 where member.status='active'
on conflict (user_id) do nothing;

insert into argus_app.preferences(user_id,deletion_epoch)
select member.user_id,member.deletion_epoch
  from pg_temp.argus_google_member_backfill_candidates candidate
  join argus_app.members member on member.user_id=candidate.user_id
 where member.status='active'
on conflict (user_id) do nothing;

insert into argus_app.onboarding_states(
  user_id,deletion_epoch,current_step
)
select member.user_id,member.deletion_epoch,'welcome'
  from pg_temp.argus_google_member_backfill_candidates candidate
  join argus_app.members member on member.user_id=candidate.user_id
 where member.status='active'
on conflict (user_id) do nothing;

insert into argus_app.notification_preferences(user_id,deletion_epoch)
select member.user_id,member.deletion_epoch
  from pg_temp.argus_google_member_backfill_candidates candidate
  join argus_app.members member on member.user_id=candidate.user_id
 where member.status='active'
on conflict (user_id) do nothing;

-- Fail closed instead of reviving a suspended/deleting member or rebinding an
-- account to another tenant.  This also makes a rerun an idempotency check.
do $bootstrap_contract$
begin
  if exists (
    select 1
      from pg_temp.argus_google_member_backfill_candidates candidate
      left join argus_app.member_lifecycles lifecycle
        on lifecycle.identity_subject_id=candidate.user_id
      left join argus_app.members member
        on member.user_id=candidate.user_id
      left join argus_app.profiles profile
        on profile.user_id=candidate.user_id
      left join argus_app.preferences preference
        on preference.user_id=candidate.user_id
      left join argus_app.onboarding_states onboarding
        on onboarding.user_id=candidate.user_id
      left join argus_app.notification_preferences notification
        on notification.user_id=candidate.user_id
     where lifecycle.id is null
        or lifecycle.tenant_id<>candidate.user_id
        or lifecycle.state<>'open'
        or member.user_id is null
        or member.tenant_id<>candidate.user_id
        or member.lifecycle_id<>lifecycle.id
        or member.status<>'active'
        or profile.user_id is null
        or profile.tenant_id<>member.tenant_id
        or profile.lifecycle_id<>member.lifecycle_id
        or profile.deletion_epoch<>member.deletion_epoch
        or preference.user_id is null
        or preference.tenant_id<>member.tenant_id
        or preference.lifecycle_id<>member.lifecycle_id
        or preference.deletion_epoch<>member.deletion_epoch
        or onboarding.user_id is null
        or onboarding.tenant_id<>member.tenant_id
        or onboarding.lifecycle_id<>member.lifecycle_id
        or onboarding.deletion_epoch<>member.deletion_epoch
        or notification.user_id is null
        or notification.tenant_id<>member.tenant_id
        or notification.lifecycle_id<>member.lifecycle_id
        or notification.deletion_epoch<>member.deletion_epoch
  ) then
    raise exception 'google_member_backfill_contract_failed'
      using errcode='23514';
  end if;
end
$bootstrap_contract$;

reset role;

do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_identity_owner from %1$I granted by %1$I',current_user
  );
end
$membership$;

commit;

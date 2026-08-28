-- U9B keeps member scenarios in Argus-owned tables. These relations remain in
-- the private Edge-function data path and are never exposed to the Data API.

alter table argus_app.future_mirror_runs
  add column assumption_version text not null default 'member-reviewed-v1',
  add column uncertainty_disclosure text not null default
    'This is a hypothetical scenario based only on the assumptions you entered. It is not advice, a forecast, or a view of any brokerage account.';

alter table argus_app.future_mirror_runs
  add constraint future_mirror_runs_assumption_version_check
    check (assumption_version ~ '^[a-z][a-z0-9.-]{0,63}$'),
  add constraint future_mirror_runs_uncertainty_disclosure_check
    check (char_length(uncertainty_disclosure) between 40 and 400),
  add constraint future_mirror_runs_exact_input_unique
    unique (user_id, deletion_epoch, intention_id, input_hash, model_version);

alter table argus_app.future_mirror_points
  add column low_amount_minor bigint,
  add column mid_amount_minor bigint,
  add column high_amount_minor bigint;

update argus_app.future_mirror_points
   set low_amount_minor = amount_minor,
       mid_amount_minor = amount_minor,
       high_amount_minor = amount_minor;

alter table argus_app.future_mirror_points
  alter column low_amount_minor set not null,
  alter column mid_amount_minor set not null,
  alter column high_amount_minor set not null,
  add constraint future_mirror_points_low_amount_check
    check (low_amount_minor >= 0),
  add constraint future_mirror_points_mid_amount_check
    check (mid_amount_minor >= low_amount_minor),
  add constraint future_mirror_points_high_amount_check
    check (high_amount_minor >= mid_amount_minor),
  drop column amount_minor;

create index intentions_owner_status_created_idx
  on argus_app.intentions (user_id, deletion_epoch, status, created_at desc, id);

create index future_mirror_runs_owner_latest_idx
  on argus_app.future_mirror_runs
    (user_id, deletion_epoch, intention_id, created_at desc, id)
  where status = 'completed';

-- Scenario reads are fenced to the member's current live deletion epoch, not
-- merely their stable user UUID. This prevents a recreated member session from
-- observing pre-deletion scenario rows while asynchronous purging completes.
drop policy runtime_owner on argus_app.intentions;
create policy runtime_owner on argus_app.intentions
  for all to argus_runtime
  using (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = intentions.user_id
         and member.status = 'active'
         and member.deletion_epoch = intentions.deletion_epoch
    )
  )
  with check (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = intentions.user_id
         and member.status = 'active'
         and member.deletion_epoch = intentions.deletion_epoch
    )
  );

drop policy runtime_owner on argus_app.future_mirror_runs;
create policy runtime_owner on argus_app.future_mirror_runs
  for all to argus_runtime
  using (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = future_mirror_runs.user_id
         and member.status = 'active'
         and member.deletion_epoch = future_mirror_runs.deletion_epoch
    )
  )
  with check (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = future_mirror_runs.user_id
         and member.status = 'active'
         and member.deletion_epoch = future_mirror_runs.deletion_epoch
    )
  );

drop policy runtime_owner on argus_app.future_mirror_points;
create policy runtime_owner on argus_app.future_mirror_points
  for all to argus_runtime
  using (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = future_mirror_points.user_id
         and member.status = 'active'
         and member.deletion_epoch = future_mirror_points.deletion_epoch
    )
  )
  with check (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = future_mirror_points.user_id
         and member.status = 'active'
         and member.deletion_epoch = future_mirror_points.deletion_epoch
    )
  );

-- The baseline already forces RLS, installs deletion-epoch fencing triggers,
-- and grants only argus_runtime access. Reassert the intentional boundary so
-- a future default-privilege change cannot expose these private app tables.
revoke all on argus_app.intentions,
  argus_app.future_mirror_runs,
  argus_app.future_mirror_points
from public, anon, authenticated;

grant select, insert, update, delete on argus_app.intentions,
  argus_app.future_mirror_runs,
  argus_app.future_mirror_points
to argus_runtime;

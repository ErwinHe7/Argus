begin;

-- Briefings are immutable generated artifacts. Member read state is mutable and
-- therefore lives in its own owner/epoch-fenced relation rather than changing
-- the generated briefing row.
create unique index if not exists briefings_owner_epoch_id_unique
  on argus_app.briefings(user_id, deletion_epoch, id);

create table argus_app.briefing_read_states (
  user_id uuid not null,
  deletion_epoch bigint not null,
  briefing_id uuid not null,
  read_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, briefing_id),
  foreign key (user_id, deletion_epoch, briefing_id)
    references argus_app.briefings(user_id, deletion_epoch, id)
    on delete cascade
);

alter table argus_app.briefing_read_states enable row level security;
alter table argus_app.briefing_read_states force row level security;

-- Replace the broad baseline briefing policies so reads as well as writes are
-- fenced to the member's current active deletion epoch.
drop policy runtime_owner on argus_app.briefings;
create policy runtime_owner on argus_app.briefings
  for all to argus_runtime
  using (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = briefings.user_id
         and member.status = 'active'
         and member.deletion_epoch = briefings.deletion_epoch
    )
  )
  with check (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = briefings.user_id
         and member.status = 'active'
         and member.deletion_epoch = briefings.deletion_epoch
    )
  );

drop policy runtime_owner on argus_app.briefing_sections;
create policy runtime_owner on argus_app.briefing_sections
  for all to argus_runtime
  using (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = briefing_sections.user_id
         and member.status = 'active'
         and member.deletion_epoch = briefing_sections.deletion_epoch
    )
  )
  with check (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = briefing_sections.user_id
         and member.status = 'active'
         and member.deletion_epoch = briefing_sections.deletion_epoch
    )
  );

create policy runtime_owner on argus_app.briefing_read_states
  for all to argus_runtime
  using (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id = briefing_read_states.user_id
         and member.status = 'active'
         and member.deletion_epoch = briefing_read_states.deletion_epoch
    )
  )
  with check (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1
        from argus_app.members member
       where member.user_id = briefing_read_states.user_id
         and member.status = 'active'
         and member.deletion_epoch = briefing_read_states.deletion_epoch
    )
  );

create trigger enforce_live_member_epoch
  before insert or update on argus_app.briefing_read_states
  for each row execute function argus_private.enforce_live_member_epoch();

grant select, insert, update, delete
  on argus_app.briefing_read_states to argus_runtime;
revoke all on argus_app.briefing_read_states from public, anon, authenticated;

commit;

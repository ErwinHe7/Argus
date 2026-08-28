-- Keep Supabase's RLS event-trigger helper owner-only and make the private
-- waitlist table's deliberate deny-all posture explicit to the hosted linter.

do $migration$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute
      'revoke execute on function public.rls_auto_enable() '
      'from public, anon, authenticated';
  end if;
end
$migration$;

create policy waitlist_submissions_deny_direct_access
  on argus_private.waitlist_submissions
  as restrictive
  for all
  to public
  using (false)
  with check (false);

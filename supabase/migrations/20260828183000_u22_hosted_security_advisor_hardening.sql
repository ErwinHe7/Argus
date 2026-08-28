-- Keep Supabase's RLS event-trigger helper owner-only and make the private
-- waitlist table's deliberate deny-all posture explicit to the hosted linter.

revoke execute on function public.rls_auto_enable()
  from public, anon, authenticated;

create policy waitlist_submissions_deny_direct_access
  on argus_private.waitlist_submissions
  as restrictive
  for all
  to public
  using (false)
  with check (false);

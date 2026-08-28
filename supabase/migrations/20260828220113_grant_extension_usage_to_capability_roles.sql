-- Security-invoker worker, API, and waitlist helpers call pgcrypto routines
-- from Supabase's non-public extensions schema. USAGE permits name resolution
-- only; the roles retain no CREATE privilege on that schema.

grant usage on schema extensions
  to argus_runtime, argus_worker, argus_waitlist;

# Cloudflare Pages runbook

Cloudflare is a static publication boundary only. The four Pages projects serve
the landing and Demo artifacts from `ritual-investing-site/dist/*`. Their
Wrangler files may contain only a project name, compatibility date, and
`pages_build_output_dir`.

Before promotion, run the site typecheck/tests, build the static assets, and run
`npm run pages:config:check` plus `scripts/check-legacy-backend-removal.sh`.
Reject any artifact or configuration containing a Pages Function, `_worker.js`,
Worker entrypoint, route, variable, Queue, R2, D1, service binding, Durable
Object, cron trigger, authentication secret, or database credential.

The browser waitlist calls the narrow Supabase `waitlist` Edge Function. The
Demo remains fixture-backed and does not call Supabase, Webull, or any
Cloudflare compute. Preview deployments ship with waitlist writes disabled.

Cloudflare rollback means promoting the prior immutable static artifact. It
never restores an API Worker, Auth0 authority, Neon database, Queue, R2 bucket,
or any other legacy backend. Keep domain/DNS changes separate and verify unknown
routes remain static 404 responses after every promotion.

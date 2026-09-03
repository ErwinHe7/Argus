# Cloudflare static publication runbook

Cloudflare is a static publication boundary only. The public member beta is an
asset-only Worker named `ritual-investing-member`; it has no script, binding,
secret, database, queue, object-storage, Auth, provider, or scheduled-compute
authority. The landing and Demo artifacts remain independently assembled and
scanned.

Before preview upload, build Flutter web without a service worker, source maps,
remote web resources, or a WASM dry run. Assemble `dist/member-staging`, verify its
manifest and provider scan, and run Wrangler's dry-run validation. The bundle
may connect only to the exact logical staging Supabase origin. The provider's
legacy physical branch label `beta` is retained only as the external identity
for staging project ref `zbgjjufjkhfhirbuuolv`.

The protected release workflow uploads one immutable version with stable alias
`staging`. Its exact origin is stored in `STAGING_MEMBER_PREVIEW_ORIGIN` as
`https://staging-ritual-investing-member.<account-subdomain>.workers.dev`; Edge
CORS and Supabase Auth must use that same exact origin. Generic Workers preview
origins and wildcards remain blocked.

Promotion deploys the accepted version at 100 percent without rebuilding.
Frontend rollback restores the recorded landing Worker version. Reattaching a
different Worker or a retained Pages domain is a separate propagation-sensitive
domain rollback. Neither action changes or restores Supabase data, Auth, Edge,
Storage, or background work. Follow `deployment-handoff.md` for the exact
landing soak, apex override smoke, observation, and recovery sequence.

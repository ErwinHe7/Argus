# Production domain publication

The verified application is currently served by the Cloudflare Worker `leo` at
`https://leo.axio7.workers.dev`. The requested custom domain is
`https://leoinvesting.com`. Adding a hostname does not require a VPS or a rebuild
of the native models.

## September 10, 2026 preflight

The existing Wrangler OAuth session is authenticated to the requested owner's
Cloudflare account. Its zone list is empty, including an exact query for
`leoinvesting.com`. Its Worker custom-domain list and Pages project list are also
empty.

Public DNS and HTTPS independently show that the domain already exists and serves
the earlier Flutter `Ritual Investing Beta` application. `www` redirects to the
apex. The authoritative nameservers are `gerald.ns.cloudflare.com` and
`susan.ns.cloudflare.com`; Cloudflare email-routing MX records are present. This
is an account-access or zone-visibility prerequisite, not a reason to register
the domain again or replace its nameservers.

The current application deployment is
`b057b8d6-3e95-4c2a-847c-4d8040a951f6` at 100%. Its JavaScript and CSS hashes match
the reviewed event-radar release. The homepage, pricing, strategy callback and
event feed respond successfully on the Worker hostname. The custom domain still
returns the older HTML document even for the new JavaScript and data paths, so
HTTP 200 alone does not prove a successful cutover.

The public preflight receipt is in the workspace at
`release-work/leo-domain-20260910/preflight.json`. No production domain, DNS,
mail-routing or Worker settings were changed during this preflight.

## Cutover after zone access is available

1. Verify the active owning zone and inspect its current DNS, Worker routes,
   custom domains, Pages bindings and redirects. Record the current web target
   for rollback; preserve mail and unrelated subdomains.
2. Attach the apex to the reviewed `leo` Worker using a Worker Custom Domain.
   An existing CNAME or Pages domain association must be handled deliberately;
   never add a second zone as a workaround. If the zone belongs to a different
   account, resolve that account relationship before attempting the attachment.
3. Persist the final verified mapping in `wrangler.jsonc` using an exact hostname
   with `custom_domain: true` and keep `workers_dev: true`. Preserve existing
   Worker routes and service bindings. Continue using the retained static-overlay
   release; do not build or deploy the dirty Next.js application wholesale.
4. Preserve the existing `www` redirect if it still resolves correctly. Add a
   separate exact `www` mapping only if needed by the established redirect setup.
5. Add the exact application origin and dedicated callback to the Strategy API
   and Supabase authentication configuration. Keep the existing member API origin
   policy intact. Review billing return URLs through their existing configuration.
6. Verify TLS, exact asset bytes and content types, all preserved routes, both
   same-origin data feeds, the strategy callback and anonymous-access rejection.
   Verify that the event assistant and chart-to-plan workflow render in a browser.
   Do not treat a serving homepage as evidence of successful paid checkout or
   broker execution.

Browser-local plans remain scoped to their original hostname. Keep the Worker
hostname available so existing visitors can export their records before using the
custom domain. The cutover must not silently copy authentication state or local
records between origins.

Cloudflare manages DNS and certificates for Worker Custom Domains. See the
[official custom-domain documentation](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)
and [domain attachment API](https://developers.cloudflare.com/api/resources/workers/subresources/domains/methods/update/).

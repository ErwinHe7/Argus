# Supabase operations runbook

Supabase is the only backend authority for Ritual Investing. Postgres, Auth,
Storage, Edge Functions, Cron, and Queues are deployed from `supabase/`.
Cloudflare hosts static Pages artifacts only; it has no API, authentication,
database, queue, object-storage, or scheduled-compute authority.

## Pull-request workflow

Pull requests and forks use no hosted credentials. CI starts a disposable local
Supabase stack, runs `supabase db reset`, executes `supabase test db`, repeats
the reset to prove replay safety, and checks/tests every Edge Function with
Deno. Flutter, generated-client, API, admin, Demo, and static Pages checks run
against local fixtures or the local stack. A PR must never receive
`SUPABASE_ACCESS_TOKEN`, a database password, a secret key, or a hosted member
token.

Supabase branching is deliberately not part of this workflow. The account does
not have the required Pro subscription. Each branch gets a fresh local stack;
the same ordered migrations are promoted later to one hosted development
project.

## Hosted-development promotion

Only a protected `main` push or an approved manual run may enter the
`ritual-supabase-development` GitHub environment. Promotions are serialized and
never cancel an in-flight deployment.

Before any remote mutation, `scripts/check-supabase-deploy-target.ts` verifies:

- the exact repository and `refs/heads/main` ref;
- the exact hosted project ref;
- a direct database hostname derived from that ref, or an explicitly
  allowlisted transaction-pooler hostname; and
- a matching `postgres` / `postgres.<project-ref>` owner username, direct port
  `5432` or transaction-pooler port `6543`, and required TLS mode.

The deployment then enables `background_workers`, `provider_egress`, and
`order_mutations` kill switches, applies migrations, records the Git revision,
reasserts every fence, runs `supabase test db --linked` against the newly
applied hosted schema, and deploys callback, worker, waitlist, then API
functions. The executable hosted acceptance hook then verifies Auth health,
exact queue and private Storage inventory, schema contract, role limits,
deployment fences, and the Edge revision. Background work is resumed only
after every check passes.
Provider egress and order mutations remain enabled (blocked) until the Webull
launch gate is separately satisfied.

If the target guard, kill-switch write, migration, function deployment, or
revision handshake fails, stop. Keep all fences enabled. Do not point clients at
an older backend, a second auth system, or a legacy database as rollback. Fix
forward from the last reviewed migration or restore the Supabase project using
the approved backup/recovery procedure.

## Hosted secrets

Hosted secrets live only in the protected GitHub environment or Supabase secret
store. Never commit them, expose them to pull requests/forks, pass them as test
fixtures, or print them. Rotate Edge database logins, worker HMAC keys, Webull
credential-encryption keys, and Supabase secret keys using their versioned
overlap procedures. A lost or ambiguous Webull refresh response is fenced to
reauthorization; it is never blindly retried.

## Cutover inventory

The required deployed inventory is four Edge Functions (`api`, `worker`,
`webull-callback`, `waitlist`), the migrations and pgTAP tests under
`supabase/`, Supabase Auth, private Storage, Cron, and PGMQ. The prohibited
inventory is any API Cloudflare Worker, Neon database or role, Auth0 tenant used
by the app, Cloudflare Queue/R2 binding, Pages Function, `_worker.js`, or
simulation command endpoint.

After revoking legacy credentials and routes, run
`scripts/check-legacy-backend-removal.sh`. Record negative probes showing the
old API host and bindings cannot serve requests before removing the final
provider-side resources.

# Ritual Investing beta environment

Status date: 2026-08-24

## Live isolation

| Layer | Beta resource |
| --- | --- |
| API | `https://api-beta.just-build-this.app` |
| Worker | `ritual-investing-api-beta` |
| Neon branch | `beta` (`br-rapid-queen-ayjfyawl`) |
| Queue | `ritual-beta-jobs` |
| Dead-letter queue | `ritual-beta-jobs-dlq` |
| Quarantine bucket | `ritual-beta-media-quarantine` |
| Public media bucket | `ritual-beta-media-public` |
| Privacy export bucket | `ritual-beta-privacy-exports` |
| Deletion-deny bucket | `ritual-beta-deletion-deny` |
| Rate-limit namespaces | `2001` through `2011` |

The Worker uses `ENVIRONMENT=staging`, has `workers.dev` and preview URLs
disabled, and has every operational kill switch set to `on`. Production Queues,
buckets, rate-limit namespaces, database connections, and secrets are not shared.

## Beta ingress

The hostname `api-beta.just-build-this.app` is publicly reachable. At operator
direction on 2026-08-24, the host-scoped IP allowlist rule was removed from the
zone-level custom WAF entry point. No production hostname or unrelated zone rule
was changed. IPv4 and IPv6 requests were both verified to return `200` from
`/health` after removal.

The beta boundary now relies on application authentication and authorization,
rate limits, isolated beta bindings, and the operational kill switches. Keep
`workers.dev` and preview URLs disabled. Reintroduce a hostname-scoped ingress
rule before any testing that requires network-private beta access.

## Install beta-only database credentials

The beta branch contains all 11 reviewed migrations and currently has no Ritual
login roles. In Neon's **Connect** dialog for `RitualInvesting` → `beta`, enable
the pooled connection and copy only its hostname (the portion after `@` and
before `/`). Do not copy an owner password into a command. Generate the private
key-value store and populated SQL file locally:

```sh
cd ritual-investing-api
npm run beta:secrets:generate -- --neon-host <beta-pooled-hostname>
npm run beta:secrets:sql
```

The commands create these local files with `0600` permissions under the private
`~/.config/ritual-investing` directory:

- `beta-secrets.json`: nine role passwords, nine pooled role URLs, and the two
  independent Worker keys.
- `provision-beta-runtime-roles.sql`: the populated SQL to paste into Neon.

The scripts refuse to replace either file unless `--force` is explicitly added.
In the Neon SQL Editor, select `RitualInvesting` → `beta` → `neondb` as
`neondb_owner`, paste `provision-beta-runtime-roles.sql`, execute it once, and
discard the SQL file after the roles have been verified. Do not execute it
against `main` and do not reuse production passwords.

The generator constructs each beta pooled connection URL from the supplied host,
the matching SQL role, and its generated password. The deploy wrapper installs
the following Cloudflare Worker secrets:

- `IDENTITY_DATABASE_URL`
- `BOOTSTRAP_DATABASE_URL`
- `STAFF_DATABASE_URL`
- `PUBLIC_DATABASE_URL`
- `RUNTIME_DATABASE_URL`
- `SCHEDULER_DATABASE_URL`
- `PRIVACY_DATABASE_URL`
- `MEDIA_DATABASE_URL`
- `AUDIT_DATABASE_URL`
- `CURSOR_SIGNING_KEY`
- `PUSH_TOKEN_ENCRYPTION_KEY`

After authenticating Wrangler with `npx wrangler login` (or setting a scoped
`CLOUDFLARE_API_TOKEN` in the process environment), deploy the eleven required
Worker secrets directly from the protected store:

```sh
npm run beta:secrets:deploy -- --yes
```

The wrapper always targets `ritual-investing-api-beta`, passes its payload to
`wrangler secret bulk` over stdin, and never uploads the nine raw `*_PASSWORD`
keys. Do not place the Cloudflare API token in `beta-secrets.json`.

Use the same role-to-secret mapping and key formats documented in
[`deployment-handoff.md`](deployment-handoff.md), but every URL and key must be a
beta value. The direct `neondb_owner` connection remains migration-only.

Until all 11 secrets exist, a request that reaches the Worker receives the redacted
`503 runtime_configuration_unavailable` response.

## Beta Auth0 and Flutter builds

Use separate beta Auth0 applications and API audience
`https://api-beta.just-build-this.app`. Replace only the placeholder Auth0 and
Cloudflare Access variables in `wrangler.beta.jsonc`; do not put secrets there.

Member build:

```sh
cd ritual-investing-app
flutter build <target> --release \
  --dart-define=RITUAL_API_BASE_URL=https://api-beta.just-build-this.app \
  --dart-define=AUTH0_DOMAIN=dev-pxee7db52tqc4xoe.us.auth0.com \
  --dart-define=AUTH0_CLIENT_ID=VIFuQLVxk6baW27jS9TzQ22pIV8lAqHz \
  --dart-define=AUTH0_AUDIENCE=https://api-beta.just-build-this.app
```

Admin build:

```sh
cd ritual-investing-admin
flutter build web --release \
  --dart-define=ADMIN_API_BASE_URL=https://api-beta.just-build-this.app \
  --dart-define=AUTH0_DOMAIN=dev-pxee7db52tqc4xoe.us.auth0.com \
  --dart-define=AUTH0_ADMIN_CLIENT_ID=<beta-admin-client-id> \
  --dart-define=AUTH0_AUDIENCE=https://api-beta.just-build-this.app
```

## Cron limitation

Beta cron triggers are intentionally absent. The account is already at the
Workers Free limit of five cron triggers, and the production triggers were left
untouched. Queue-driven beta flows remain isolated and available. Copy the
reviewed schedule list from `wrangler.jsonc` into `wrangler.beta.jsonc` only after
upgrading the Workers plan or removing an obsolete non-beta trigger.

## Activation

1. Install beta database roles, secrets, and Auth0 values.
2. Confirm `/health` returns `200` over both IPv4 and IPv6, and confirm protected
   member and staff routes still fail closed without valid credentials.
3. Keep all kill switches `on` while testing reads and authentication.
4. Turn Queue, export, and purge switches `off` one at a time when their tests
   begin. Notifications and media stay paused until real provider Workers exist.
5. Promote reviewed code and migrations independently; never point production at
   beta URLs, Queues, or buckets.

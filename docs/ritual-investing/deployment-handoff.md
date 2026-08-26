# Ritual Investing production deployment handoff

Status date: 2026-08-24

## Deployed infrastructure

- API hostname: `https://api.just-build-this.app`
- Cloudflare Worker: `ritual-investing-api`
- Worker deployment: `7b34e3dc997c444e9939e781d3de11a9`
- Queue: `ritual-jobs`, with `ritual-investing-api` as consumer
- Dead-letter queue: `ritual-jobs-dlq`
- R2 buckets: `ritual-media-quarantine`, `ritual-media-public`,
  `ritual-privacy-exports`, and `ritual-deletion-deny`
- Neon project: `RitualInvesting` (`rapid-credit-79004505`)
- Neon main branch: `br-proud-mountain-aylhnxnc`
- Neon database: `neondb`
- Database migrations: all reviewed migrations `0001` through `0011`

The Worker is intentionally deployed with every operational kill switch set to
`on`. Until the required secrets below are installed, every HTTP request returns
a redacted `503 runtime_configuration_unavailable`; scheduled and Queue handlers
perform no work. This is the expected safe handoff state.

## 1. Create least-privilege Neon login roles

Use the Neon SQL Editor while connected to `RitualInvesting` → `main` →
`neondb` as `neondb_owner`. Copy
[`ops/provision-runtime-roles.sql.example`](../../ritual-investing-api/ops/provision-runtime-roles.sql.example),
replace its password placeholders only in the private SQL Editor, execute it,
and discard the populated copy.

Create these roles through SQL, not the Neon Console, CLI, or API. Neon grants
`neon_superuser` membership to roles created through those control-plane paths;
SQL-created roles instead start with ordinary PostgreSQL privileges. See Neon's
[Postgres compatibility documentation](https://neon.com/docs/reference/compatibility).

Open the Neon **Connect** dialog for each SQL-created role and copy its **pooled**
connection string for `neondb`. The Worker uses the Neon serverless driver and
pooled URLs. Keep the direct `neondb_owner` URL only for migrations; never add it
to Cloudflare.

| Cloudflare secret | Neon login role |
| --- | --- |
| `IDENTITY_DATABASE_URL` | `ritual_identity_login` |
| `BOOTSTRAP_DATABASE_URL` | `ritual_bootstrap_login` |
| `STAFF_DATABASE_URL` | `ritual_staff_login` |
| `PUBLIC_DATABASE_URL` | `ritual_public_login` |
| `RUNTIME_DATABASE_URL` | `ritual_runtime_login` |
| `SCHEDULER_DATABASE_URL` | `ritual_scheduler_login` |
| `PRIVACY_DATABASE_URL` | `ritual_privacy_login` |
| `MEDIA_DATABASE_URL` | `ritual_media_login` |
| `AUDIT_DATABASE_URL` | `ritual_audit_login` |

## 2. Install Worker secrets

In Cloudflare, open **Workers & Pages** → **ritual-investing-api** → **Settings**
→ **Variables and Secrets**. Add each of the nine database URLs above as type
**Secret**, plus:

- `CURSOR_SIGNING_KEY`: an independent high-entropy HMAC secret, 32–512
  characters. One local generation option is `openssl rand -base64 48`.
- `PUSH_TOKEN_ENCRYPTION_KEY`: exactly 32 random bytes encoded as unpadded
  base64url. One local generation option is
  `openssl rand -base64 32 | tr '+/' '-_' | tr -d '='`.

Do not paste either value into `wrangler.jsonc`, a Dart define, CI output, or a
tracked `.env` file. If Wrangler CLI deployment is later preferred, keep the
Cloudflare API token in the local process environment or CI secret named
`CLOUDFLARE_API_TOKEN`; application secrets can be installed with
`npx wrangler secret put NAME`.

After the eleven Worker secrets are present, `GET /health` should return `200`.
Auth-required endpoints remain unavailable until Auth0 is configured.

## 3. Replace Auth0 placeholders

Create one Auth0 API with audience `https://api.just-build-this.app`, one native
application for the member app, and one SPA application for the admin dashboard.
The Flutter applications do not use client secrets.

Replace these non-secret Worker variables in `wrangler.jsonc` and in the deployed
Worker settings:

- `AUTH0_ISSUER=https://<tenant-domain>/`
- `AUTH0_JWKS_URL=https://<tenant-domain>/.well-known/jwks.json`
- `AUTH0_AUDIENCE=https://api.just-build-this.app`
- `AUTH0_ADMIN_CLIENT_IDS=<admin-spa-client-id>`; comma-separate future IDs

Follow [`auth0-setup.md`](auth0-setup.md) for PKCE, refresh rotation, permissions,
MFA, and the recent-authentication claim.

## 4. Enable Cloudflare Access for admin routes

Cloudflare Access is not yet enabled on this account. In **Zero Trust**, enable
Access, create a self-hosted application protecting
`api.just-build-this.app/v1/admin/*`, and require the intended staff identity
policy. Copy its team domain and application audience into:

- `CF_ACCESS_ISSUER=https://<team-name>.cloudflareaccess.com`
- `CF_ACCESS_JWKS_URL=https://<team-name>.cloudflareaccess.com/cdn-cgi/access/certs`
- `CF_ACCESS_AUDIENCE=<access-application-aud>`

The API requires both the Access assertion and a valid Auth0 admin access token.
For each staff operator, insert a row into `staff_principals` directly in the
Neon SQL Editor using the verified Auth0 `sub`, lower-cased Access email, and
admin SPA client ID. Never put those identity values in source control.

```sql
INSERT INTO staff_principals (
  auth0_subject,
  access_identity,
  allowed_client_id,
  status,
  display_label
) VALUES (
  '<verified-auth0-sub>',
  '<lowercase-access-email>',
  '<admin-spa-client-id>',
  'active',
  '<operator-label>'
);
```

## 5. Build the Flutter clients

Both clients now default to `https://api.just-build-this.app`. Supply Auth0
identifiers at build time:

```sh
cd ritual-investing-app
flutter build <target> --release \
  --dart-define=RITUAL_API_BASE_URL=https://api.just-build-this.app \
  --dart-define=AUTH0_DOMAIN=<tenant-domain> \
  --dart-define=AUTH0_CLIENT_ID=<member-native-client-id> \
  --dart-define=AUTH0_AUDIENCE=https://api.just-build-this.app
```

```sh
cd ritual-investing-admin
flutter build web --release \
  --dart-define=ADMIN_API_BASE_URL=https://api.just-build-this.app \
  --dart-define=AUTH0_DOMAIN=<tenant-domain> \
  --dart-define=AUTH0_ADMIN_CLIENT_ID=<admin-spa-client-id> \
  --dart-define=AUTH0_AUDIENCE=https://api.just-build-this.app
```

The admin web assets are intentionally not published until those real Auth0
identifiers and Access policy exist. When ready, serve the build at
`https://admin.just-build-this.app`, keep `ADMIN_ORIGIN` set to that origin, and
keep admin API calls on `https://api.just-build-this.app`.

## 6. Controlled activation

Keep all kill switches `on` during smoke tests. Then turn features `off` (enabled)
in this order, verifying metrics and audit evidence between steps:

1. Queue and scheduled work.
2. Exports and purge.
3. Notifications only after a real `PUSH_PROVIDER` service binding exists.
4. Media only after real `MEDIA_SCANNER` and `MEDIA_PROCESSOR` service bindings
   exist.

Never replace the three managed provider bindings with pass-through or dummy
Workers in production.

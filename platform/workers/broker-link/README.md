# moomoo read-only account link

This isolated Worker lets a signed-in Leo user authorize a broker-hosted moomoo
connection and see masked account metadata. It does not retrieve balances,
positions, quotes or P&L, submit orders, create paper accounts, or authorize the
local paper runner. No VPS or local OpenD installation is needed for this link.

## HTTP contract

The fixed host is `https://leo-broker-link.axio7.workers.dev`. The only browser
origin allowed is `https://leo.axio7.workers.dev`. Custom domains and preview
origins are not enabled.

- `GET /health`: public readiness; `configured` means the public client ID and
  encryption key are installed. It does not mean a broker account is connected.
- `GET /status`: exact Leo Origin and a Google Supabase bearer token. The Worker
  verifies identity through Supabase `/auth/v1/user`; guest and anonymous users
  cannot access connection state. It refreshes tokens when required, then calls
  the broker account-list API before returning `connected`.
- `POST /oauth/moomoo/start`: explicit top-level browser form submission from
  Leo; form field `access_token` carries the current Supabase token in the body.
  No URL token, transferable start ticket, browser-stored broker credential, or
  client-selected owner/account is accepted. Successful verification sets an
  HttpOnly browser-binding cookie and returns a 303 to moomoo consent.
- `GET /oauth/moomoo/callback`: fixed registered OAuth callback. Returns a 303
  to `/#/brokers?moomoo=linked|denied|failed|readonly_required`. The result marker
  is informational; only authenticated `/status` establishes current state.
- `POST /disconnect`: exact Leo Origin, Google bearer token and `{}` body.
  Deletes Leo's token material, clears account snapshots, invalidates pending
  callbacks and returns disconnected. It does **not** revoke the broker grant.

Authenticated status example (illustrative, not a connected-account receipt):

```json
{
  "schemaVersion": "broker-link/v1",
  "provider": "moomoo",
  "configured": true,
  "state": "disconnected",
  "checkedAt": null,
  "accounts": [],
  "readonly": true,
  "executionEnabled": false,
  "message": "No broker account is linked."
}
```

States are `disconnected`, `connected`, `reauthorization_required`, and
`unavailable`. Accounts contain only `label` (four bullets and the last four card
digits), `securityFirm`, `accountType` (`cash` or `margin`), and numeric `markets`.
Broker errors retain the previous masked account snapshot and its original
`checkedAt`, while removing the connected claim. A 401/403 or unsafe refresh
requires new consent. A normal broker outage returns unavailable with HTTP 503.

## Security and vendor boundary

The only broker resource route is
`GET https://webapi.moomoo.com/api/v1.0/accounts/authorized_trd_accs`.
The only broker POST is the OAuth token endpoint. Resource responses are bounded,
schema checked, and tied to explicit account IDs in the returned grant. No
arbitrary path, account identifier, proxy, order or simulator endpoint exists.

OAuth uses public-client PKCE S256, a random 256-bit state and an independent
256-bit browser binding. The session lasts five minutes and is consumed atomically
only when state, cookie and expiry match. Wrong-cookie attempts do not consume
the real user's session. PKCE verifiers and token bundles use AES-256-GCM with
random IVs and owner/generation-bound authenticated data in private D1 storage.
Only hashes of state and browser bindings are stored.

The documented consent URL does not specify a `scope` request parameter. The
user must choose read-only access and specific accounts on moomoo's page. Leo
requires `trade:read` and explicit numeric `accid:<id>` grants, permits optional
`quote:read`, and rejects write scopes, `accid:*`, and unknown scopes before any
account query or token persistence. Registration's broad default scope is not
accepted as a read-only grant.

The documented refresh flow retains the original refresh token. A durable D1
lock prevents concurrent refresh submissions; a missing response, changed scope,
unexpected refresh-token rotation or interrupted lock requires new consent.
Generation-conditional writes prevent an in-flight callback, refresh or account
query from restoring a disconnected link or overwriting a newer connection.
An old access token's failed query also cannot invalidate a newer encrypted token
revision.

Account response validation currently recognizes the documented security firms
`FUTUSECURITIES`, `FUTUSG`, `FUTUINC`, and `FUTUCA`. Unknown firms, account types,
unscoped accounts and unrecognized account-card formats fail closed. Cash/margin
is never interpreted as a paper/live flag. Regional account and consent behavior
still requires an actual user-authorized end-to-end verification.

The simulator account-list API is intentionally absent: its first call creates
paper accounts, and the collected documentation does not establish OAuth access
to that login-session API. A revocation URL appears in moomoo's MCP discovery
metadata, but its REST revocation method/request contract was not established;
disconnect therefore makes no broker-revocation claim.

No broker passwords, full account numbers, tokens or scopes are returned to the
browser. Worker observability is disabled because OAuth callback URLs contain
authorization codes. Do not enable request URL logs, analytics body capture, or
wrangler tail during actual consent. Upstream redirects are rejected, all
responses are no-store, and OAuth redirects use `Referrer-Policy: no-referrer`.

## Configuration and recovery

`wrangler.jsonc` contains the actual public client ID and D1 binding. The secret
`BROKER_TOKEN_ENCRYPTION_KEY` must contain base64 of exactly 32 random bytes;
configure through secret stdin or the Cloudflare dashboard. Never write the key
to a repo file, terminal output, browser bundle or test fixture. This key is
separate from Supabase tokens and broker authorization.

The root deployment owner applies `migrations/0001_broker_link.sql`, installs the
secret and deploys this Worker separately from the static site. `entry.ts` exports
only the default handler. No frozen application backend is rebuilt.

After deployment, check `/health`, anonymous rejection, exact-origin rejection,
and authenticated disconnected state. The user then signs into moomoo, selects
read-only permissions and a specific account, and approves consent. Verify
masked account data through `/status` and exercise disconnect. An actual
broker-backed link is not established by the mocked test suite.

If consent or an exchange fails, start a new flow; the old code is never retried.
If refresh becomes uncertain, reconnect. If the encryption key is lost or
rotated without migrating ciphertext, stored tokens cannot be decrypted and
users must reconnect. To remove the broker grant itself, users must review and
remove Leo in moomoo's connected-app authorization controls.

## Verification

Run from `platform`:

```powershell
.\node_modules\.bin\tsx.cmd --test workers/broker-link/broker-link.test.ts
.\node_modules\.bin\tsc.cmd --project workers/broker-link/tsconfig.json
```

2026-09-11: **18 tests passed**, scoped TypeScript check passed. The suite uses
in-memory SQLite behind a D1-compatible statement adapter and mocked fixed broker
endpoints. It covers identity and owner isolation, scope rejection, masked
responses, encrypted owner binding, state expiry/replay, browser binding,
upstream errors, nonrotating refresh, refresh ambiguity/concurrency, callback and
refresh disconnect races, old/new callback races, and stale-token invalidation.
Node's SQLite experimental-feature warning is expected. These are software
tests; they do not certify vendor consent compatibility or a real account link.

Official documentation was retained under the project release evidence directory
`release-work/leo-broker-link-20260911/source/`, including
`integration-contract.json`, `getting-started.txt`, `authorized-accounts.txt`,
`sim-account-list.txt`, source manifest and TLS evidence. Public OAuth client
registration is recorded separately in `registration-receipt.json`.

Official references: [OAuth and token refresh](https://open.moomoo.com/api/overview/getting-started),
[authorized account response](https://open.moomoo.com/api/trading/account/get-accounts).

## Published verification — 2026-09-11

Deployed API version `3be42427-3b2d-43fc-a762-99d51b4383d0` at the fixed host above.
The new D1 migration and encryption secret are configured. Eleven unprivileged
production HTTP checks passed; see [live-checks-20260911.json](live-checks-20260911.json).
The actual signed-in Leo browser successfully retrieved disconnected status and
submitted the top-level form, reaching `https://passport.moomoo.com` for broker
login. No password was entered or broker consent completed by this verification.
An account link and any paper execution remain unverified until their own flows
complete. No real or simulated orders were submitted.

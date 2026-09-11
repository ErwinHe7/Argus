# moomoo OAuth contract groundwork

This folder contains pure, server-only request builders and response validation.
It does not register an app, call moomoo, store credentials, connect an account,
expose a callback route, or enable trading. No current runtime imports it.

The documented public-client flow registers `redirect_uris`,
`token_endpoint_auth_method: "none"`, authorization-code/refresh-token grants,
the `code` response type, and a client name at `/oauth2/register`. Registration
must use the actual app identity and reviewed callback; it has not been performed.
The helper takes that registered client ID and exact callback as trusted server
configuration. The authorization URL uses PKCE S256 and state. Users select
permissions on moomoo; no undocumented scope query field is invented here.

Token requests use form encoding at the fixed moomoo HTTPS host. Refresh retains
the original refresh token. A changed refresh token fails closed pending a
contract review. Access expiry comes from the response; no refresh expiry is
invented. Returned scopes describe the grant, not verified account capabilities.
[Official OAuth guide](https://open.moomoo.com/api/overview/getting-started)

Before connecting this to the application:

1. Register the real client and callback; confirm eligibility for intended users
   and account regions. U.S. instruments are listed, but coverage alone does not
   prove that every regional account can trade them.
   [Market coverage](https://open.moomoo.com/api/overview/)
2. Add authenticated start and callback handlers. Persist only the state hash;
   encrypt the verifier with user, session, connection, deletion epoch and client
   binding. Atomically consume pending state once before exchange, including on
   denial; pure callback validation does not implement replay protection.
3. Implement provider-specific encrypted credential custody, protected account
   mapping, refresh concurrency, disconnect and reauthorization. Existing Webull
   custody assumes refresh rotation and a known refresh expiry, so it cannot be
   reused unchanged. Never log these records, request bodies, or raw responses.
4. Keep the catalog gate closed until tested account enumeration, account/market
   entitlements and simulated trading evidence exist. The helpers contain no
   sandbox/live account selector and cannot establish either account mode.
5. Implement reviewed read and manual-order adapters separately. Verify market
   data permissions and commercial display rights; account quote access alone
   is not evidence of redistribution rights.
   [Quote permissions](https://openapi.moomoo.com/moomoo-api-doc/en/intro/authority.html)

The five-minute pending lifetime, strict callback representation, rejected
unknown callback fields, and optional HTTP loopback allowance are local policies.
HTTP loopback is for explicit local development only. There is no user-supplied
provider host or redirect override. Any future sender must retain `redirect:
"error"`, `cache: "no-store"`, and credential redaction. Confidential OAuth
clients are not implemented by this public-client contract.

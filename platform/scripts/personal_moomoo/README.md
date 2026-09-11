# Personal moomoo gateway

This opt-in desktop boundary connects the local Leo webpage to the owner's
moomoo OpenD. It uses the official Python SDK and supports manual U.S. stock and
ETF DAY limit orders during regular trading hours. It does not read model
signals or alter the Rust automated execution gates.

Run from `platform/` with the launcher supplied for the personal webpage, or:

```powershell
$env:LEO_PERSONAL_GATEWAY_TOKEN = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
python -m scripts.personal_moomoo
```

Use the same token only in the local server proxy. The Python boundary is fixed
to `127.0.0.1` (port 8766 by default); OpenD is fixed to `127.0.0.1:11111` using
`SecurityFirm.FUTUINC`. Startup is lazy: the status endpoint works while OpenD
or the SDK is unavailable. The recommended stable SDK is `moomoo-api==10.9.6908`;
the documented 10.10.7008 interface is also recognized. Status reports the
installed version. The default order cap is $500; startup
`--max-order-notional` accepts a positive amount up to $1,000,000.

Real account reads are available after account selection. Real order previews,
unlocking, and confirmations require an explicit `--allow-live` process start.
The default never submits a real order. The owner signs in to OpenD and, when
needed, unlocks through OpenD or supplies the trade password to `/unlock`.
The broker-required password hash is sent only to the SDK. Passwords and hashes
are never journaled or logged, the SDK's automatic reconnect-unlock credential
cache is cleared, and request references are cleared after use. SDK file and
console logging is disabled in this isolated process. Python cannot guarantee
erasure of immutable strings from process memory.

Every HTTP call requires `Authorization: Bearer <local token>` and
`X-Leo-Session: <32–128 URL-safe characters>`. The browser receives neither
header value from this boundary. The Next local proxy supplies them after its
own loopback Host, Origin, and browser-session checks. Requests with an Origin
header are rejected by this boundary; it does not enable CORS. One opaque owner
session controls the process at a time. The personal launcher maps authenticated
browser sessions to the same local Windows owner using its persistent protected
key, so cookie renewal does not orphan order commands. `/disconnect` releases
the connection and revokes its outstanding previews. The webpage stores only
the pending preview ID locally for read-only recovery after reopening it.

| Endpoint | Behavior |
| --- | --- |
| `GET /status` | SDK/OpenD availability, verified connection/account, live startup flag, known unlock status |
| `GET /accounts` | Broker accounts with exact string IDs, environment, status, and markets |
| `POST /connect` | Pin `{account_id,mode}` only when the exact account is ACTIVE and US-entitled |
| `POST /disconnect` | Clear the pinned connection and revoke previews |
| `GET /snapshot` | Fresh broker account, positions, and orders; unavailable amounts remain null |
| `POST /unlock` | Forward `{password}` to official SDK when live mode is explicitly enabled |
| `POST /previews` | Validate exact `{symbol,side,quantity,limit_price}`; create a 60-second immutable intent |
| `POST /confirm` | Submit exactly one previously reviewed preview with `{preview_id,confirmed:true}` |
| `GET /commands/{id}` | Read/reconcile a command by its original SDK remark; never place an order |
| `GET /previews/{id}/command` | Recover `{command:...}` after a lost confirmation response, or null if no claim exists |
| `POST /previews/{id}/discard` | Atomically revoke an unclaimed preview, or return its existing command; prevents a delayed confirmation |

Amounts, quantities, and account IDs cross the browser boundary as strings.
If the SDK omits currency for a single-market account, USD is inferred only
when freshly verified account permissions contain exactly `US`; the snapshot
labels this as `currency_source: single_us_market_account`. Missing currency
on a universal/multimarket account or an explicit non-USD currency fails closed.
There is no price rounding, market-order conversion, short-sale route, or
out-of-hours flag. The account, live flag, available shares, and buying power
are rechecked at confirmation. The estimated notional excludes broker fees and
is not a broker fee quote. Broker buying power is approximate; the broker still
decides whether to accept the order.

The SQLite journal defaults to the ignored local
`.quant-runtime/personal-moomoo/orders.sqlite3`. SQLite `synchronous=FULL` and
`BEGIN IMMEDIATE` persist a unique command claim **before** the SDK call.
Duplicate and concurrent confirmations reuse that command. A crash or unclear
SDK response leaves status `unknown`; subsequent confirmation requests never
call the broker again. Unknown submissions block new previews for that account
until read-only reconciliation finds the exact matching broker order.

An absent broker order is not proof that submission failed. The broker's open
order endpoint includes open orders and recently filled/cancelled orders, so a
missing historical order remains unknown. Resolve such a case against moomoo's
own order history before undertaking any new trading; this MVP provides no
manual override or automatic resubmission. The local journal must be retained.

All tests inject fake broker responses and never authenticate, unlock, or send
orders to a real or paper account:

```powershell
python -m unittest scripts.personal_moomoo.test_personal_moomoo -v
```

Official contracts verified September 5, 2026:

- [Account identities, status, and market access](https://openapi.moomoo.com/moomoo-api-doc/en/trade/get-acc-list.html)
- [Place order; remark and order parameters](https://openapi.moomoo.com/moomoo-api-doc/en/trade/place-order.html)
- [Order lookup and refresh limits](https://openapi.moomoo.com/moomoo-api-doc/en/trade/get-order-list.html)
- [Account funds and approximate buying power](https://openapi.moomoo.com/moomoo-api-doc/en/trade/get-funds.html)
- [OpenD unlocking](https://openapi.moomoo.com/moomoo-api-doc/en/trade/unlock.html)

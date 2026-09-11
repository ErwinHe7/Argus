# IBKR local connector: paper execution and read-only inspection

This development integration has two independent transports. Neither accepts a
live account or a brokerage password from the website. The strategy rules,
mandates, software stops and cash/position accounting remain in the Rust runner.

| Transport | Implemented capability | Current acceptance status |
| --- | --- | --- |
| `ibkr_gateway.py` | Client Portal Gateway paper account discovery, reconciliation, quotes, paper entry/exit and owned-order cancellation | Offline injected tests pass. An authenticated broker entry/hold/exit and recovery cycle has **not** been completed. |
| `ibkr_sdk.py` | Optional official TWS SDK read-only account, orders, positions, quotes and adjusted daily-history inspection | Offline injected tests pass. No executable accounts; no native TWS paper-environment attestation inferred from account names or ports. |

The unified sidecar selects Client Portal with `--broker ibkr-gateway`. TWS and
Client Portal sessions are never combined to claim permission to execute. The
Client Portal adapter uses Python's standard HTTPS client, not a redistributed
IBKR TWS SDK. Public commercial broker integration approval is a separate
prerequisite; downloading a gateway or choosing a paper account does not supply
that approval.

## Client Portal installation and authentication

1. Follow IBKR's [official gateway installation and authentication tutorial](https://www.interactivebrokers.com/campus/trading-lessons/launching-and-authenticating-the-gateway/).
   Install the vendor gateway and its supported Java runtime on the user's own
   computer. Keep the gateway and its authentication local. Do not publish its
   port, reverse-proxy it through Leo, or upload its configuration/session files.
2. Bind and restrict access to localhost. Configure a per-installation TLS
   certificate whose subject alternative names include `localhost`. Trust it
   explicitly with `--ca-file`, or supply its independently verified DER
   certificate SHA-256 with `--certificate-sha256`. The adapter supports neither
   `verify=false` nor arbitrary remote gateway hosts. Pin verification occurs
   before HTTP request bytes are sent. Renewing/replacing a certificate requires
   a deliberate local trust update.
3. Open `https://localhost:5000` in a browser and authenticate directly with IBKR
   in the paper environment. Follow any broker reauthentication prompts there.
   The adapter does not fill credentials, automate two-factor authentication,
   switch accounts, reauthenticate, answer order warnings, or suppress warnings.
4. Select the intended paper account in the broker session. The adapter requires
   `authenticated=true`, `connected=true`, `competing=false`, and an actual
   boolean `isPaper=true` from that same gateway session. The selected account
   must be a member of the returned account list and match the locally bound
   `IBKR:DU...` account. A changed session identifier requires reconnect and
   reconciliation. USD base currency and broker trading access are checked.

The default adapter is readiness-only. For source-based diagnostics, use the
existing connector Python environment with its pinned calendar dependencies:

```powershell
python .\ibkr_gateway.py --self-check
'{"operation":"readiness"}' | python .\ibkr_gateway.py --ca-file 'C:\absolute\path\localhost.pem'
```

`--self-check` is offline and never connects to IBKR. `readiness` performs broker
read operations and returns no trading authorization. Before login an unavailable
or unauthenticated result is expected. Normal error output contains safe error
codes, not raw broker responses, session identifiers or credentials.

## Pairing and paper execution boundary

Use the packaged pairing script's IBKR options or configure the existing Rust
runner to launch this sidecar. For the Windows native package:

```powershell
$app = Join-Path $env:LOCALAPPDATA 'Programs\LeoStrategyConnectorDev'
& "$app\scripts\pair.ps1" -Broker ibkr-gateway -EnableIbkrPaper -Account 'IBKR:DU1234567' -GatewayCaFile 'C:\absolute\path\localhost.pem' -HistoryDirectory 'C:\absolute\private\history'
& "$app\scripts\start.ps1" -Broker ibkr-gateway
```

For the MSI installation set `$app` to `Programs\LeoStrategyConnectorMsiDev`
instead. The pairing token is entered in the hidden prompt, not a command
argument. Use `-GatewayCertificateSha256 'VERIFIED_64_HEX_DIGIT_FINGERPRINT'`
instead of `-GatewayCaFile` if explicitly pinning the local certificate. The
IBKR profile has a separate default state directory and persistent transport
journal. Set `-ApiBase` only when using a different configured Strategy API.
`start.ps1` runs an actual mandate-enabled connector and can submit paper orders;
it is not an offline diagnostic. Start only after reviewing the account,
reconciliation, strategy and simulated risk settings in the website.

The equivalent sidecar arguments are:

```text
--broker ibkr-gateway
--enable-paper-execution
--account IBKR:DU1234567
--journal /absolute/persistent/private/path/ibkr-dispatch.sqlite
--ca-file /absolute/path/localhost.pem
--history-directory /absolute/private/path/history
```

`DU1234567` is an example, not an available account. `--certificate-sha256` can
replace `--ca-file`; do not supply both. The default gateway port is 5000; an
explicit local `--port` is supported. Paper opt-in requires both an exact account
binding and a persistent journal. Without opt-in, `accounts` is an empty list.

Pairing a computer does not create or resume a strategy mandate. The Rust
runner still verifies the owner, device/account lease, instrument, strategy
revision, quantities and management authority. Run only one connector instance
for an account. All restarts/processes in an installation must use the same
journal path. An OS account lock serializes preflight through submission across
those processes; the cloud/Rust account lease covers competing installations.
Do not copy or reset a journal while there is exposure or an unresolved request.

The paper adapter exposes only `accounts`, `readiness`, `snapshot`, `market`,
`place`, and `cancel` through local NDJSON stdin/stdout. It is not a web order
endpoint. Supported orders are whole-share U.S. USD stocks/ETFs using DAY, regular
session orders: limit entries and limit/market exits. Live accounts, options,
shorting, fractional shares, margin-funded entries and market entries are blocked.
Entries require settled cash, a fresh consolidated bid/ask, the strategy entry
window and the runner's current entry lease. Only journal-owned Leo orders can be
cancelled. Broker approval messages require direct user review; there is no
automatic `/reply`, suppression, account switching or global-cancel capability.

## Quotes and daily history

Quotes come from the user's entitled Client Portal session. The adapter requires
the documented real-time consolidated order-book availability marker, a broker
timestamp no older than five seconds, positive bid/ask sizes and an uncrossed
bid/ask. Delayed, frozen, unentitled, nonconsolidated or incomplete snapshots stop
execution. TradingView embeds are not the trading data feed.

The current WebAPI historical endpoint does not document an adjustment proof
sufficient for this strategy contract. Its bars are therefore not silently
treated as verified adjusted history. Supply independently validated daily data
in `--history-directory/SYMBOL.json`; without it the `market` response contains
`evaluation: null`, an explicit limitation, and no executable entry evaluation.
Position reconciliation and available exit management do not depend on that file.

Each file has this envelope:

```json
{
  "symbol": "SPY",
  "evaluation": {
    "history_mode": "current_observed_snapshot",
    "bars": [],
    "evidence": {
      "source": "VALIDATED_FILE_IMPORT",
      "classification": "observed",
      "adjustment_verified": true,
      "coverage_verified": true,
      "availability_verified": false,
      "calendar_source": "exchange_calendars/XNYS",
      "dataset_sha256": "SHA256_OF_CANONICAL_BARS"
    }
  }
}
```

The empty `bars` above illustrates the shape and intentionally fails validation.
Provide 220–1000 consecutive exchange sessions through the latest completed
session. Each bar contains `session_date`, timezone-aware `open_at`, `close_at`,
`available_at`, decimal-string `open`, `high`, `low`, `close`, and whole nonnegative
`volume`. Session opens/closes must match `exchange_calendars/XNYS`, and each
availability timestamp must be after its close and no later than collection.
The dataset hash is SHA-256 of Python's
`json.dumps(bars, sort_keys=True, separators=(",", ":")).encode()`.

The importer must establish the adjustment/source facts before writing their
verification flags; setting flags is not evidence. Retain the original provider
file, source manifest and validation receipt locally. Current adjusted history is
an observation made now and is explicitly **not** historical point-in-time
availability evidence. `IBKR_TWS_ADJUSTED_LAST_RTH` is also accepted when produced
by the separate read-only inspector from entitled `ADJUSTED_LAST`, regular-session
TWS history. This is data provenance only and conveys no TWS account execution
permission. Atomically replace each validated file after the next completed
session. Missing or outdated files pause entries rather than reusing old signals.

## Submission, reconciliation and recovery

- The immutable Leo client ID is sent as IBKR `cOID`. The local journal persists
  it before transmission. Acknowledgment records the broker order ID, then queries
  actual cumulative quantity/average-price observations; it never invents a zero
  fill from an acknowledgment. Modeled fees remain outside these broker facts.
- Network timeouts after transmission begins, malformed acknowledgments, warning
  replies and unavailable order status remain unresolved. They block another
  submission. Reconciliation uses the exact account, `order_ref`/`cOID`, and broker
  order ID. It does not automatically create a replacement order.
- A transport error proven to occur before any HTTP request transmission is
  recorded as not sent. The client ID remains in the journal for audit. A definitely
  unsent cancellation releases its cancel latch; an uncertain DELETE does not.
- Current/session orders are not a complete historical audit trail. Every snapshot
  returns `history_complete: false`. Missing end/preflight state is unavailable,
  not an empty account. Known nonterminal broker IDs are queried individually when
  absent from the current orders list. Missing older history can require manual
  broker review and prevents automatic resolution of an unknown outcome.
- Working sells reserve their remaining quantity. Orders are collected before
  balances and positions so a fill during collection does not release a reservation
  against an older share count. The REST API is not an atomic account snapshot;
  broker/local differences still require the Rust runner to pause and reconcile.
- Preserve both the Rust execution database and the adapter journal across
  restarts. After an outage, sign in locally if needed, restart, inspect the broker
  account and reconciliation result, and resume only through the authenticated
  website control after incidents are resolved. Never delete an unknown record to
  make a warning disappear.
- Software stops require the computer, runner, gateway and fresh quotes to remain
  available. Pausing entries does not cancel orders or close positions. The adapter
  provides no native OCO guarantee and never fabricates a stop crossing during an
  outage. Inspect broker exposure directly when protection is unavailable.

## Optional TWS read-only inspector

`ibkr_sdk.py` is separate source tooling. Install the official SDK only after
reviewing the [current IBKR API download/license page](https://interactivebrokers.github.io/).
Use a separate Python environment if its protobuf requirements differ from the
moomoo dependency pins; do not replace the native connector's pinned runtime.
The official SDK is not bundled with Leo. The TWS API license's noncommercial
permission does not authorize a paid public integration; obtain the applicable
IBKR agreement independently.

Enable the broker's read-only API setting in locally authenticated paper TWS or
IB Gateway. Bind to loopback and use a dedicated nonzero API client ID. Ports 7497
or 4002 are accepted as installation defaults, **not** paper-account proof.

```powershell
python .\ibkr_sdk.py --self-check
'{"operation":"readiness"}' | python .\ibkr_sdk.py --port 7497 --client-id 73
```

The inspector supports `readiness`, `inspect` and `inspect_market`. The latter
two require `account_id: "IBKR:DU..."` selected from that session's qualified
candidate list; `inspect_market` also takes `symbol`. Candidates are marked
`UNVERIFIED`, have no executable `SIMULATE` identity, and `accounts` is always `[]`.
`place`, `cancel`, `snapshot` and `market` execution operations are rejected.
Read-only quotes use timestamped tick-by-tick bid/ask callbacks. Missing callback
completion, delayed data, ambiguous contracts, execution corrections or incomplete
history fail closed. `reqAllOpenOrders` is used without binding manual orders.

## Verification record and outstanding broker acceptance

As of 2026-09-11, 27 injected Client Portal tests and 18 injected TWS tests pass on
Windows in the isolated Python 3.13 environment. These cover paper identity and
session changes, exact decimals, partial fills, unknown outcomes/restarts, duplicate
client IDs, cancellation races, cross-account data, stale/delayed quotes, local
TLS verification, same-journal concurrent adapters, a fill between collection
reads, historical manifest validation and safe errors. Fake fixtures/calendars
are explicitly test data. They establish neither actual broker operation nor
profitability. Run from the adapter directory:

```text
python -m unittest test_paper_sdk.py test_ibkr_sdk.py test_ibkr_gateway.py test_broker_sdk.py -v
```

A real readiness-only check against the locally installed HTTPS gateway reached
the unauthenticated gateway and returned `ibkr_gateway_http_unavailable` with
`execution_authorized: false` and `submission_attempted: false`. No account
authentication, broker account retrieval, order submission or cancellation was
performed by that check. Before declaring broker acceptance, record an explicitly
authorized paper entry/hold/exit cycle, restart/reconnect, canceled/partial orders,
stale quotes and deliberate mismatches using actual broker evidence. Native
macOS/Linux runtime verification, public signing and public commercial access
approval remain separate release prerequisites.

## Official interface references

- [Authenticated session state](https://www.interactivebrokers.com/docs/web-api/v1/endpoints/session/authentication-status) and [paper/account/session fields](https://www.interactivebrokers.com/docs/web-api/v1/endpoints/accounts/receive-brokerage-accounts).
- [Ledger](https://www.interactivebrokers.com/docs/web-api/v1/endpoints/portfolio/portfolio-ledger), [positions](https://www.interactivebrokers.com/docs/web-api/v1/endpoints/portfolio/positions), [current orders](https://www.interactivebrokers.com/docs/web-api/v1/endpoints/order-monitoring/live-orders), and [individual order status](https://www.interactivebrokers.com/docs/web-api/v1/endpoints/order-monitoring/order-status).
- [Place orders](https://www.interactivebrokers.com/docs/web-api/v1/endpoints/orders/place-order), [cancel orders](https://www.interactivebrokers.com/docs/web-api/v1/endpoints/orders/cancel-order), and [pacing limits](https://www.interactivebrokers.com/docs/web-api/v1/pacing-limitations).
- [Quote fields](https://www.interactivebrokers.com/docs/web-api/v1/endpoints/market-data/market-data-fields), [market data availability markers](https://www.interactivebrokers.com/docs/web-api/v1/endpoints/market-data/market-data-availability), and [historical market data](https://www.interactivebrokers.com/docs/web-api/v1/endpoints/market-data/historical-market-data).
- [General WebAPI and third-party integration documentation](https://www.interactivebrokers.com/campus/ibkr-api-page/webapi-doc/) and [TWS historical adjustment semantics](https://interactivebrokers.github.io/tws-api/historical_bars.html).

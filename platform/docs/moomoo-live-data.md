# Moomoo OpenD live market-data bridge

## Verified K1M timestamp semantics

The official bridge was observed at the 2026-07-21 regular-session open. Moomoo
labels the forming 09:30-09:31 one-minute bucket as `09:31:00`; the label is the
bucket **end**, not its start. The Rust adapter therefore normalizes it to
`bar_start=09:30:00`, `bar_end=09:31:00`, records the actual SDK receive time as
the observation event time, and retains the raw callback JSONL unchanged.

The bar cannot be finalized before its bucket end. This prevents the first
forming K1M push from being treated as a completed future minute.

## What is implemented

AXIO7 treats Moomoo as a quote-only, loopback data provider. The control and
prediction runtime remains Rust. The configurable Python boundary uses the
official Moomoo Quote SDK 10.9.6908 and subscribes to US `Basic`, `Ticker`, and
`K_1M` callbacks. It imports no Trade API and reserves stdout exclusively for
validated JSONL events. The earlier native C++ bridge remains available for
reproducibility, but its symbol list is fixed; the Python boundary receives
the exact host, port, and symbol universe from the Rust supervisor. On
2026-07-21 the native bridge was verified against the local OpenD with
callbacks for SPY, QQQ, IWM, and SOXX. GOOG, MU, and SNDK require a fresh
protocol-verification receipt from the configurable boundary before their
stream is considered live. Next.js displays state only; it is not in the
market-data or decision hot path.

Data path:

```text
Moomoo OpenD (127.0.0.1:11111)
  -> official quote-only Python boundary
  -> Rust mutable-minute buffer
  -> finalized 1m bars + explicit gaps
  -> point-in-time features
  -> 5/15/30/60 minute forecast distributions
  -> NO_TRADE / shadow decision
  -> append-only prediction and settlement ledgers
  -> read-only Next.js dashboard
```

The connector configuration is in
`quant_engine_rs/configs/production.yaml`. It enables `QUOTE`, `K_1M`, and
`TICKER`; `ORDER_BOOK` is off by default. The Trade API is prohibited.

That prohibition still applies to the quote bridge. Trading is implemented as
a separate loopback process with independent authentication, caps, an
authoritative broker snapshot, and a durable Rust OMS. It defaults to Moomoo
`SIMULATE`; see `docs/moomoo-execution-runbook.md`. Enabling that gateway never
turns an unpromoted forecast into an executable order.

## Required local setup

1. Install the official US Moomoo OpenD desktop package. The current Windows
   archive is `moomoo_OpenD_10.9.6908_Windows.7z`. Its internal executable and
   some configuration files retain the vendor's legacy `Futu_OpenD` /
   `FutuOpenD.xml` names; that internal filename does not mean the Futu-branded
   regional download was installed.
2. Launch OpenD and sign in through its GUI.
3. Keep its API listener on `127.0.0.1:11111`.
4. Confirm that the account has the required US quote rights.
5. Never expose port 11111 to a LAN or public interface.

The repository has no broker credentials and does not automate login.

## Operator commands

Run these from `quant_engine_rs`:

```powershell
..\scripts\quantctl.ps1 live moomoo-check
..\scripts\quantctl.ps1 live moomoo-capabilities
..\scripts\quantctl.ps1 live moomoo-stream --shadow `
  --bridge ..\scripts\moomoo_quote_bridge.py
..\scripts\quantctl.ps1 live moomoo-status
..\scripts\quantctl.ps1 predictor settle-pending
```

To validate minute finalization without claiming live evidence:

```powershell
..\scripts\quantctl.ps1 live moomoo-replay `
  --input tests/fixtures/moomoo_k1m_updates.jsonl
```

Replay outputs are labeled `DETERMINISTIC_REPLAY` and are excluded from the
verified forward-shadow count.

## Dashboard and API

Start the local services:

```powershell
npm run quant:dev
```

Open `http://127.0.0.1:3000/quant/intraday`.

The Rust service exposes:

- `GET /api/v1/live/status`
- `GET /api/v1/live/capabilities`
- `GET /api/v1/live/bars`
- `GET /api/v1/live/gaps`
- `GET /api/v1/predictor/forecast`
- `GET /api/v1/predictor/shadow`
- `GET /api/v1/predictor/settlements`

## Evidence and market-coverage limits

- Moomoo US equity coverage is labeled
  `NASDAQ_BASIC_TOTALVIEW_PLUS_ARCABOOK`; it is not consolidated SIP NBBO.
- `US.SPY` is an underlying proxy for the target `SPX_PROXY`. It is not the
  SPX cash index.
- This feed does not unblock a historical SPXW option backtest.
- A signal is computed only from a finalized minute. The currently forming
  minute is mutable and cannot enter inference.
- Missing minutes remain explicit gaps. Future bars cannot repair past state.
- Forecasts and decisions are different records. A distribution may exist
  while the decision remains `NO_TRADE`.
- Real option execution remains blocked until licensed SPXW OPRA/NBBO data is
  available and validated.

## Runtime and blocker semantics

If `/api/v1/live/status` reports `DISCONNECTED`, there is no live evidence.
Start and log in to OpenD, verify quote rights, and then run
`moomoo-stream --shadow`. A successful TCP probe alone is not a live connector:
the official Quote SDK handshake and subscriptions must also succeed. The
first callback upgrades status to `CONNECTED_QUOTE_PROTOCOL_VERIFIED`; the
first one-minute callback separately verifies `K_1M`. The system must remain
`NO_TRADE` until those checks pass and a sufficient
append-only forward sample has settled and passed the promotion policy.

If the OpenD console reports `Login failed, Password does not match`, correct
the login locally in OpenD. Do not place credentials in this repository, a CLI
argument, a chat message, or the quote bridge. The bridge cannot and must not
automate the authentication dialog.

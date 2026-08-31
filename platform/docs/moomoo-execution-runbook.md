# Moomoo execution and autonomous forecast routing

AXIO7 now has separate market-data and trading trust boundaries:

```text
Moomoo Quote SDK -> finalized bars -> prediction/shadow ledger
                                      |
                                      v
promotion registry -> allocation -> execution risk -> durable OMS
                                                        |
Moomoo Trade SDK gateway <- authenticated loopback HTTP <-+
        |
        +-> authoritative account / positions / orders / fills
        +-> Rust reconciliation -> portfolio risk / kill switch
```

The quote bridge remains quote-only. `scripts/moomoo_trade_gateway.py` is the
only component that creates a Moomoo trade context. It accepts US `DAY` limit
orders only, applies its own symbol and notional caps, and writes SDK callbacks
to an append-only JSONL file. The Rust OMS independently persists intent before
submission and reconciles account, position, order, and fill state afterward.

## Current safety state

`quant_engine_rs/configs/production.yaml` enables the execution connection in
`simulate` mode with these initial canary limits:

- symbol allowlist: `US.SPY`
- long-only
- maximum order notional: `$500`
- maximum position notional: `$1,000`
- maximum gross exposure: `1%`
- maximum daily loss before blocking: `0.25%`
- 30-second maximum signal age
- five-basis-point limit-price collar

These caps do not create permission to trade. The model must still have a
pinned, unexpired promotion registry; a fresh ledger-backed prediction; an
eligible allocation; a fresh broker portfolio; an independent portfolio-risk
approval; a running execution supervisor; and a clear kill switch. The current
model and pattern candidates are not promoted, so the expected result is
`NO_TRADE`.

## Install and start simulation

Use the same official Python SDK version as OpenD:

```powershell
python -m pip install --upgrade moomoo-api==10.9.6908
```

Start Moomoo OpenD, sign in, and keep it on `127.0.0.1:11111`. In the same
PowerShell session used to start the gateway and Rust services, create a local
token:

```powershell
$env:AXIO_BROKER_GATEWAY_TOKEN = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
./scripts/start-moomoo-trade-gateway.ps1
```

Then start the existing quote/prediction service and inspect the connection:

```powershell
npm run quant:dev
./scripts/quantctl.ps1 broker doctor
./scripts/quantctl.ps1 broker reconcile
```

`GET /api/v1/broker/status` reports whether the Rust runtime currently owns a
fresh authoritative broker portfolio. A TCP connection alone is insufficient.

## Dry-run and autonomous simulation

The order router reads the independently gated allocation from the local Rust
control plane. Without `--execute`, it persists and prints an approved intent
but sends nothing to Moomoo:

```powershell
./scripts/quantctl.ps1 broker execute-once
```

After reviewing an eligible intent, simulated routing can be enabled:

```powershell
./scripts/quantctl.ps1 broker execute-once --execute
./scripts/quantctl.ps1 broker run --execute
```

Repeated evaluation cannot duplicate an order: the client order ID is derived
from the prediction and target, the Rust OMS rejects identity collisions, and
the gateway checks the same ID in Moomoo before placing an order. When the kill
switch is active, reconciliation cancels open AXIO orders and removes the
authoritative portfolio from allocation if cancellation or reconciliation
fails.

## Real-mode ceremony

Do not switch to real mode until simulation has accumulated sufficient forward
evidence and execution reconciliation has been reviewed. Real mode requires all
of the following at once:

1. Change `execution.mode` to `real`, set the exact `account_id`, and set
   `allow_real_orders: true`.
2. Set `AXIO_LIVE_TRADING_ENABLED=I_UNDERSTAND_REAL_ORDERS` for that process.
3. Set a separate random `AXIO_LIVE_ARMING_TOKEN` of at least 32 characters.
4. Provide `MOOMOO_TRADE_PASSWORD_MD5` or a session-only trade password.
5. Start the gateway with `-Mode real -AccountId <exact-id>`.
6. Route with both `--execute` and `--confirm-live-account <exact-id>`.

The site and browser never receive any of these secrets. Real and simulated
gateways cannot share the same running process, and the gateway refuses any
non-loopback bind address.

## Recovery

The durable OMS is `quant_engine_rs/data/state/execution_oms.sqlite3`; official
SDK callbacks are appended under `quant_engine_rs/data/execution/`. On restart,
run `broker reconcile` before resuming risk. If broker state is stale,
incomplete, or inconsistent, the system fails closed and creates no new order.

Stop the isolated gateway with:

```powershell
./scripts/stop-moomoo-trade-gateway.ps1
```

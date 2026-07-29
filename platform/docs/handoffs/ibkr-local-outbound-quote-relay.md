# IBKR local outbound quote relay handoff

## Outcome and boundary

The repository now contains the narrow pieces for this topology:

```text
Windows browser + Client Portal Gateway (127.0.0.1:5000)
  -> scripts/ibkr_quote_relay.py (quote-only process)
  -> outbound HTTPS POST /api/market/ibkr/relay
  -> Next server-only token translation
  -> Rust POST /api/v1/live/ibkr/quotes
  -> freshness / entitlement / coverage validation
  -> append-only data/live/ibkr_quote_batches.jsonl + latest receipt
```

The relay never opens an inbound port on Windows. It never uploads the IBKR
cookie, account identifier, positions, orders, or any trading method. The
wire schema is `#[serde(deny_unknown_fields)]`, so adding those fields causes
the entire batch to fail.

This is a Level-1 quote ingress and owner-only research-display source. It is
not a one-minute OHLCV source yet and therefore must not be presented as if it
already unblocks the minute-bar model. A separately validated bar finalizer is
required before Rust inference may consume it.

## Remaining two source-file wiring edits

The Windows `apply_patch` helper could add new files during this work but could
not refresh/update any pre-existing file. Apply these two narrow edits before
building:

1. Export the module from `quant_engine_rs/src/data/mod.rs`:

```rust
pub mod dbn_decode;
pub mod ibkr_relay;
pub mod manifest;
```

2. In `quant_engine_rs/src/api.rs`, add this route beside the existing live
   routes:

```rust
.route(
    "/api/v1/live/ibkr/quotes",
    get(ibkr_relay_quotes).post(ibkr_relay_ingest),
)
```

Then add these handlers after `live_events` (they deliberately reuse the
existing `live_root`, `read_jsonl_tail`, `ApiError`, and research-token
middleware):

```rust
fn ibkr_relay_enabled() -> bool {
    std::env::var("IBKR_QUOTE_RELAY_ENABLED").is_ok_and(|value| value == "true")
}

async fn ibkr_relay_ingest(
    State(state): State<AppState>,
    Json(batch): Json<crate::data::ibkr_relay::IbkrQuoteBatch>,
) -> Result<Json<crate::data::ibkr_relay::IbkrRelayStatus>, ApiError> {
    if !ibkr_relay_enabled() {
        return Err(ApiError::service_unavailable("IBKR quote relay is disabled"));
    }
    let received_at = Utc::now();
    let policy = crate::data::ibkr_relay::policy_from_symbols(
        &state.config.live.symbols,
        state.config.live.stale_after_ms,
        state.config.live.max_context_skew_ms,
    );
    let receipt =
        crate::data::ibkr_relay::validate_quote_batch(&batch, received_at, &policy)
            .map_err(ApiError::unprocessable)?;
    let status =
        crate::data::ibkr_relay::persist_quote_batch(&live_root(&state), batch, receipt)
            .map_err(ApiError::internal)?;
    Ok(Json(status))
}

async fn ibkr_relay_quotes(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    if !ibkr_relay_enabled() {
        return Ok(Json(json!({
            "status":"DISABLED",
            "provider":"IBKR_CLIENT_PORTAL",
            "quote_only":true,
            "execution_enabled":false
        })));
    }
    let root = live_root(&state);
    let status =
        crate::data::ibkr_relay::read_status(&root.join("ibkr_relay_status.json"))
            .map_err(ApiError::internal)?;
    let batches = read_jsonl_tail(&root.join("ibkr_quote_batches.jsonl"), 10)?;
    Ok(Json(json!({
        "status":status,
        "batches":batches,
        "quote_only":true,
        "execution_enabled":false
    })))
}
```

## Server configuration

Generate a new random 32+ character `IBKR_QUOTE_RELAY_TOKEN`. Do not reuse the
Databento key, IBKR password, or Rust research token.

- Web container: `IBKR_QUOTE_RELAY_TOKEN=<new random secret>`
- Rust container: `IBKR_QUOTE_RELAY_ENABLED=true`
- Windows relay process: `IBKR_QUOTE_RELAY_TOKEN=<same relay-only secret>`

The web route converts the relay-only bearer token into the private
`INTRADAY_QUANT_TOKEN` on the server. The Windows machine therefore does not
receive a general quant control-plane credential.

## Windows operation

1. Run the official Client Portal Gateway on Windows bound to
   `127.0.0.1:5000`.
2. Open `https://localhost:5000`, complete IBKR login and 2FA, and leave the
   Gateway running.
3. In PowerShell, set the relay-only token in the process environment and run:

```powershell
python scripts/ibkr_quote_relay.py `
  --gateway-url https://127.0.0.1:5000/v1/api `
  --allow-insecure-loopback-gateway `
  --ingest-url https://axio7.com/api/market/ibkr/relay
```

Use `--once` for a single readiness receipt. The continuous loop calls
`/tickle` roughly once per minute, but IBKR still requires periodic interactive
reauthentication.

## Fail-closed gates

Rust accepts a batch only when all of the following hold:

- schema and bridge version are recognized;
- UUID batch identity is valid;
- Client Portal session is reported authenticated;
- every configured live symbol is present exactly once and no extra symbol is
  present;
- every conid is non-zero;
- IBKR field `6509` begins with `R`; delayed, frozen, unavailable, and unknown
  values fail;
- provider `_updated`, bridge capture, and AWS receipt timestamps pass the
  configured age and future-skew bounds;
- every quote has positive bid/ask, ask is at least bid, and optional sizes and
  last are in-domain;
- payload hash, observation cutoff, availability time, freshness, coverage,
  provider, and caveats are recorded.

The default production freshness gate is ten seconds. Outside an active
entitled market session, old `_updated` timestamps are expected to be rejected;
the bridge must not relabel a Sunday/after-hours close as realtime.

## Checks

```powershell
python -m unittest scripts/test_ibkr_quote_relay.py -v
node --test scripts/ibkr-quote-relay-contract.test.mjs
Push-Location quant_engine_rs
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
Pop-Location
```

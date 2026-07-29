# Alva context feed boundary

## What the named routes prove (and what they do not)

`macro-and-economics`, `stocks/kline`, and `stock market-metrics` are Alva
product routes. They identify the service and transformation path, but they do
not identify the upstream exchange/vendor, consolidation method, entitlement,
latency, correction policy, or timestamp semantics. A value returned by one of
these routes is therefore **Alva-aggregated context** until those properties are
present in the response or contract.

The official Alva developer material advertises public market data, 250+
financial skills, data pipelines, and backtesting. It does not publicly map the
three route names above to a specific upstream tape. Do not relabel them as SIP,
Nasdaq Basic, Cboe CGIF, or NBBO without provider evidence.

## Role inside AXIO7

| Layer | Current source | Permitted role |
|---|---|---|
| Historical minute truth | Massive one-minute SPY/cross-asset bars | Training, causal feature construction, walk-forward testing |
| Live minute truth | Official Moomoo C++ Quote SDK/OpenD | Finalized live bars and forward-shadow forecasts |
| Macro/daily context | Alva normalized context contract | Regime research and lagged features after point-in-time audit |
| Execution price | Future licensed NBBO / broker quote | Fill simulation and execution; never Alva daily metrics |

For SPY/QQQ daily RSI and moving averages, AXIO7 should normally recompute the
indicator from its own immutable Massive history. That guarantees one formula,
one adjustment convention, and reproducible point-in-time values. Alva can be a
cross-check. `^SPX` and `^VIX` can become useful additional regime features only
after their historical point-in-time series is archived and tested.

ARKK and XBI are not automatically accepted because they are available. They
must win a purged walk-forward ablation and stability test before entering a
promoted feature set.

## Normalized observation contract

The Rust engine accepts a JSON array or JSONL file. Every row must contain:

```json
{
  "symbol": "^VIX",
  "field": "close",
  "value": 17.9,
  "event_time": "2026-07-20T20:00:00Z",
  "available_time": "2026-07-20T20:00:03Z",
  "received_time": "2026-07-20T20:00:04Z",
  "provider": "alva",
  "route": "macro-and-economics",
  "upstream_vendor": "VENDOR_FROM_ALVA_RESPONSE_OR_CONTRACT",
  "frequency": "daily",
  "units": "index_points",
  "adjusted": null,
  "revision_id": "OPTIONAL_VENDOR_REVISION"
}
```

This is a schema example, not a market observation shipped with the repository.
The engine never fills `upstream_vendor` by guessing.

## Causal rules

1. The join uses `available_time <= forecast_cutoff`, not the date printed on a
   chart.
2. A same-day final RSI/SMA is unavailable before its daily bar closes.
3. A current snapshot cannot be backfilled across history.
4. Each field needs at least 120 distinct historical event dates by default.
5. Undisclosed upstream provenance blocks production-feature eligibility by
   default.
6. Even an eligible field remains a challenger until purged walk-forward
   ablation shows stable out-of-sample improvement.
7. Context values never become executable bid/ask or NBBO.

## Audit command

From `quant_engine_rs`:

```powershell
cargo run --release --bin quantctl -- data context-audit `
  --input data/context/alva_observations.jsonl `
  --cutoff 2026-07-21T13:30:00Z
```

The result is written to `data/quality/context_audit_latest.json` and reports
accepted/rejected rows, observations not yet available at the cutoff, history
coverage per field, provenance, feature eligibility, and rejection reasons.

The feed remains disabled in `configs/production.yaml` until an actual Alva API
key/export and route mapping are supplied. Disabling it does not stop the
Massive + Moomoo prediction engine.

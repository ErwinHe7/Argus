# Research Desk observation artifact

`desk-data.json` is generated offline by `intraday_quant/desk_export.py`.
`schema.ts` is the corresponding UI type contract. The frontend renders these
numbers; it does not calculate market indicators or reinterpret them as forecasts.

From the `Leo Roar` workspace root:

```powershell
python Argus/platform/intraday_quant/src/intraday_quant/desk_export.py --market-data deliverables/leo-iv-research/market-data.json --iv-artifact Argus/platform/lib/iv-lab/artifacts/iv-lab.json --proxies deliverables/leo-research-desk/raw-ibkr-proxies.json --output Argus/platform/features/research-desk/data/desk-data.json
python Argus/platform/features/research-desk/data/test_desk_export.py
```

The retained six-symbol source was retrieved on September 6, 2026. SPY and QQQ
were separately retrieved through read-only IBKR history/snapshot calls on
September 7 at 10:01:18 UTC. All latest observed market prices are from September
4; this is a historical snapshot. Each symbol preserves its own retrieval and
observation timestamps. The raw proxy responses, including contract-resolution
evidence, are retained in `deliverables/leo-research-desk/raw-ibkr-proxies.json`.
No account data, orders, alerts, or watchlists were accessed or changed.

The exporter checks the IV Lab artifact's canonical source hash and reproduces
its retained daily indicators from the same raw OHLCV. It reuses
`iv_lab.technical_indicators`; SMA50 and the observed high/low range are added in
Python. Latest daily change is completed-session close-to-close, distinct from
the potentially after-hours spot reference. All percentage fields, including IV
and its 52-week percentile, are expressed as percent values. Independent IV
observation timestamps remain null.

Invalid source OHLC rows are not repaired. The continuous valid suffix after
the final bad row is retained and described in `coverage`: DXYZ 101 observations,
NVDA 68, SPY 212, QQQ 74; the other four symbols retain 260. Charts expose at most
the final 120 observations without resetting indicator warm-up. Calendar
completeness and corporate-action adjustment remain unverified. High20/low20 are
the observed range of the past 20 valid observations, never price targets.

SPY and QQQ are ETF market proxies, not index quotations. DXYZ is a closed-end
fund. Missing proxy responses produce an explicit unavailable context rather
than replacement observations. The artifact contains no probabilities, backtest
returns, win rates, forecasts or executable instructions.

# SPY five-minute replay demo

This Vite application renders the validated static artifacts produced by the
offline Python demo builder. The normal development command reads only from
`public/generated`; it does not fall back to the committed UI fixture.

## Build artifacts and run the app

From the repository root:

```bash
cd axio7-model-review
python3 -m venv .venv-spy-demo
source .venv-spy-demo/bin/activate
python -m pip install -e "source/intraday_quant[dev]"
python -m intraday_quant.demo.cli build --input source/intraday_quant/data/normalized/databento_SPY_ohlcv-1m_2024-07-18_2026-07-25_rth.parquet --output apps/spy-price-demo/public/generated
cd apps/spy-price-demo
npm install
npm run dev
```

The Python command requires the ignored normalized Databento input named above.
Generated browser artifacts remain ignored and must be rebuilt locally.

## Explicit fixture mode

The committed deterministic fixture is for UI development and automated tests,
not market analysis. Start it explicitly from `apps/spy-price-demo`:

```bash
npm run dev:fixture
```

Fixture mode reads only the committed sample bundle and is visibly labeled
`UI_FIXTURE` in the page header. It is non-market fixture data and must not be
treated as a quote, forecast, recommendation, or production artifact.

## Design references

- [Saved graph-first visual reference](docs/reference/spy-graph-first.html)
- [Approved SPY price demo design specification](../../../docs/superpowers/specs/2026-08-19-spy-price-demo-design.md)

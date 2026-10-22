# Model atlas

`/#/models` on Astra's Pick shows the nine frozen candidate models (SPX, QQQ,
NVDA, AAPL, MU, SOXX, NBIS, BE, IGV) as an inspectable product: the pipeline
each one runs, its HMM regimes, how regimes hand off, why its state count was
chosen, the same-regime kernel settings, and the exact artifact behind every
number. `?symbol=NVDA` deep-links one model.

It shows frozen parameters, not live readings. No current regime, price,
forecast, calibrated probability, expected return, or trade is published. Every
model is `CANDIDATE_NOT_PROMOTED` with calibration `UNAVAILABLE_FAIL_CLOSED`.

## Data flow

| Step | Owner |
| --- | --- |
| Read `quant_engine_rs/data/models/universe/registry.json` and each `*.frozen.json`; verify registry/artifact hashes, versions, cutoffs, feature schema, and promotion status; compute basis-point units, mean regime stay, OU half-life, and time share | `intraday_quant/src/intraday_quant/model_atlas.py` |
| Retained display artifact (`astra-model-atlas.v1`) | `features/research-desk/data/model-atlas.json` |
| Strict schema, consistency checks, no prediction/execution flags | `models/contract.ts` |
| Reject a stale export whose registry or artifact bytes changed | `scripts/research-desk-build.mjs` |
| Render only; chart geometry, no model arithmetic | `models/ModelAtlas.tsx` |

The exporter fails if an artifact is promoted, gains a calibration, changes its
feature schema, or disagrees with the registry, because the page copy states that
all models are unpromoted candidates. Update the contract and copy deliberately
before publishing such a change. A malformed or failed load shows an error and no
charts.

Two time steps appear on the page: the HMM observes one completed 5-minute
bucket per step (`predictor.rs`, `minute_in_5m_bucket == 4`), so its transition
matrix and mean stay use 5-minute steps; the shadow SDE/OU layer uses 1-minute
steps. Regimes are numbered by ascending HMM variance within one model only.

## Rebuild

From `platform`:

```powershell
$env:PYTHONPATH = 'intraday_quant/src'
python -m intraday_quant.model_atlas          # only when frozen artifacts change
node scripts/grid-research-build.mjs
node --import tsx scripts/research-desk-build.mjs
```

## Checks

```powershell
$env:PYTHONPATH = 'intraday_quant/src'
python -m unittest discover -s intraday_quant/tests -p test_model_atlas.py
node --import tsx --test features/research-desk/models/contract.test.ts
node node_modules/typescript/bin/tsc --noEmit -p features/research-desk/tsconfig.json
```

## Release

The page ships with the existing Astra's Pick static overlay; no Worker routing,
binding, or Next.js rebuild changes. Copy the rebuilt `public/app/research-desk/`
over `.open-next/assets/app/research-desk/` in a copy of the current frozen
release stage, run `npx wrangler deploy --dry-run` there, then `npx wrangler
deploy`. The page is then served at https://leo.axio7.workers.dev/#/models.

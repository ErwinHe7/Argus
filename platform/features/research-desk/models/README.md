# Model atlas

`/#/models` on LEO shows the nine frozen candidate models (SPX, QQQ,
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

The page ships through the retained LEO static overlay. Use the **current**
release as the baseline; an older September stage would regress the October
homepage, branding, and custom-domain configuration. The staging helper verifies
saved manifests and current live hashes, preserves every backend file, and allows
only `desk.js`, `desk.css`, and `data/model-atlas.json` to change. Keep the retained
index, public configuration, Jev assets, Worker routing, bindings, and domains.

```powershell
python scripts/model-atlas-stage.py --base '<current-release>' --stage '<new-release>' --build public/app/research-desk
# From the new release, using the installed Wrangler:
wrangler deploy --dry-run --outdir .dry-run
wrangler deploy --keep-vars --message 'Argus model atlas'
```

The page is served at https://leo.axio7.workers.dev/#/models. Verify the deployed
asset hashes, retained routes, and atlas interactions; save the new version and
the previous version for rollback. Deployment evidence for October 22 lives in
`docs/model-atlas-delivery-20261022.md`.

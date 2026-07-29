# Argus live-platform handoff

## Source of truth

- Repository: `ErwinHe7/Argus`
- Integration branch: `codex/live-model-integration`
- Engineering issue: https://github.com/ErwinHe7/Argus/issues/5
- Complete application root: `platform/`
- Preserved historical review package: `axio7-model-review/` (do not deploy)

The repository formerly called Axio7 has been renamed Trashone. Do not use it
for new development or production deployment.

## Engineer workflow

```bash
git fetch origin
git switch codex/live-model-integration
git switch -c allan/website-integration
cd platform
npm ci
npm run typecheck
npm run build
```

Keep website changes on the engineer-owned branch and open a pull request back
to `codex/live-model-integration`. Do not force-push or rewrite another
contributor's branch.

## Runtime ownership

- `platform/quant_engine_rs/` owns production inference, market-data
  validation, freshness/coverage checks, model loading, and evidence envelopes.
- `platform/intraday_quant/` owns offline research, training, validation,
  calibration, and artifact export.
- `platform/quant_core_cpp/` contains native research components.
- `platform/app/`, `platform/components/`, and `platform/lib/` own the website,
  authentication, billing, query parsing, orchestration, and server-side
  proxies. They must not recompute predictions.

Website market queries must call Rust `quantd`. A failed or stale Rust response
must fail closed; it must not fall back to Yahoo, synthetic values, an LLM
guess, or the preserved review stubs.

## Model artifacts

The current transfer contains exactly nine symbol artifacts:

`SPX`, `QQQ`, `NVDA`, `AAPL`, `MU`, `SOXX`, `NBIS`, `BE`, and `IGV`.

They are current candidate artifacts, not promoted calibrated models. The UI
may display an explicitly labeled uncalibrated research direction when the
live-data contract passes, but it must withhold calibrated probability,
expected return/move, ranking, and execution language until a separately
validated immutable calibration/promotion artifact exists.

## Secrets and deployment

AWS, Databento, Supabase, Paddle, database, and internal research credentials
are intentionally absent from Git. Use protected server environment variables
or a secret manager. Never paste production values into `.env.example`, issues,
commits, Docker images, browser bundles, or logs.

Prepare and verify a server from the complete application:

```bash
cd platform/infra/single-vm
bash prepare-runtime.sh
# Fill the generated, ignored .env.server through the secure deployment channel.
bash prepare-runtime.sh --check-env
docker compose --env-file .env.server up -d --build
bash verify-runtime.sh
```

Do not change DNS or customer traffic until verification reports:

```text
web_to_quantd: CONNECTED
model_runtime: LOADED
requested_artifacts: 9
loaded_artifacts: 9
failed_artifacts: 0
execution: DISABLED
```

Automatic order execution must remain disabled.

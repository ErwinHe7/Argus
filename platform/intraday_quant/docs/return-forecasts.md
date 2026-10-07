# Chronological return forecasts

The logistic/Ridge and histogram gradient boosting research challengers now
export a point forecast, a frozen return interval, and independent validation
diagnostics for each configured 5/15/30/60-minute horizon. Forecast returns are
signed by the candidate's direction, in decimal return units; these are not
price bounds or an instruction to trade.

## Fit, calibrate, assess, then forecast

Each walk-forward fold uses these stages in chronological order:

1. Fit classifiers, return/MFE/MAE regressors, imputers, and scalers on training
   sessions only.
2. Fit probability calibration and the absolute-return-residual interval on
   the first half of observed validation sessions.
3. Assess both on the later validation sessions, without refitting. Purge
   immature forward labels at the boundary and embargo the assessment start.
4. Freeze the artifact and predict later observations. Test outcomes are not
   needed by `predict_from_artifact` and never fit any estimator or interval.

Whole-session splitting uses timestamps and session dates, without inspecting
outcomes to choose the boundary. Start-stamped minute bars require a gap of at
least `horizon_minutes + 1`; a larger configured purge is retained. Repeated
test sessions, invalid timestamps, insufficient calibration evidence, and
observations at or before the frozen artifact cutoff are rejected.

`validation_brier`, log loss, and return RMSE now refer to the separate later
assessment. Brier skill compares with the early-calibration win frequency;
`validation_zero_return_rmse` provides a cash/zero-return reference. A positive
Brier skill is an offline diagnostic, not a promotion decision. Old and new
validation scores have different scopes and should not be compared as if they
were produced by the same procedure.

## Return interval

Set `model.return_interval_coverage` before running an experiment. The default
is `0.90`. For `n` early-calibration observations, the radius is the
`ceil((n + 1) * coverage)`-th smallest absolute prediction error. The interval
is `[point - radius, point + radius]`; it does not interpolate quantiles or
assume Gaussian residuals. An unavailable finite order statistic fails closed
instead of being capped to a misleading finite interval.

This follows the split-conformal residual construction described by
[Angelopoulos and Bates](https://arxiv.org/abs/2107.07511).
Its requested level is explicitly **nominal**. Intraday observations overlap,
returns are dependent, and market regimes change. Exchangeability has not been
established, so this implementation does not claim guaranteed market coverage.
See [Oliveira et al.](https://arxiv.org/abs/2203.15885) for the assumptions and
additional analysis needed for non-exchangeable data.

Prediction exports contain `return_lower`, `return_upper`,
`return_interval_nominal_coverage`, and `return_interval_method`.
`fold_diagnostics.csv` reports the empirical later-session coverage and average
width, alongside point and probability errors. Width and coverage must be
reviewed together. `uncertainty` remains the frozen early-calibration RMSE used
by the existing candidate score; the interval does not change that scoring rule.

## Use a frozen artifact on new observations

Run the existing offline pipeline from `platform/intraday_quant`:

```powershell
python -m intraday_quant.cli run-all --config configs/default.yaml
```

The default configuration is synthetic software validation. For market
research, configure a supported licensed historical input and its actual source
metadata. No market-data adapter is substituted by this feature.

After training, load an artifact you trust and provide candidate observations
with timezone-aware timestamps, candidate IDs, and the artifact's feature
columns. The following is an offline Python example; `new_candidates.parquet`
must be built through the existing causal feature/candidate pipeline:

```python
import joblib
import pandas as pd

from intraday_quant.models.walk_forward import predict_from_artifact

artifact = joblib.load("data/models/horizon_15m_fold_0_logistic.joblib")
observations = pd.read_parquet("new_candidates.parquet")
forecasts = predict_from_artifact(artifact, observations)
forecasts.to_parquet("new_forecasts.parquet", index=False)
```

No forward-return labels are required. The artifact freezes its input columns,
horizon, interval, probability calibrator, uncertainty scale, validation receipt,
and `forecast_available_after` cutoff. That cutoff includes all validation
evidence and its label-maturity gap. The caller must still ensure that new
features use only information available at observation time, have adequate
source coverage, and describe the same symbol/feature contract used to train.
Older artifacts without this contract must be retrained. Existing joblib files
are Python objects and must only be loaded from trusted sources.

Every forecast is `CANDIDATE_NOT_PROMOTED` with `promotion_eligible = false`.
This offline change provides no new live-data entitlement, production model
promotion, Rust serving parity, or order-execution authority.

## Verification

```powershell
python -m pytest tests/test_return_forecasts.py tests/test_core.py tests/test_pipeline.py tests/test_analog_downgrade.py --basetemp .pytest-tmp -p no:cacheprovider
```

Tests cover the corrected order statistic, invalid evidence and failed refits,
chronological purge/embargo, separate assessment scores, label-free inference,
joblib reloads, cutoff rejection, and the end-to-end synthetic pipeline. Changing
test outcomes or later-assessment outcomes cannot change frozen predictions or
intervals. These tests verify software behavior; predictive improvement requires
licensed point-in-time data, untouched holdouts, and forward-shadow evidence.

# Overfitting controls

- Chronological train, independent validation/calibration and frozen test.
- Purge any training label whose response overlaps the next split; apply embargo.
- Select hyperparameters inside walk-forward training/validation only.
- Block analog observations and bootstrap resamples by trading day.
- Hash data, features, parameters, random seed and outputs.
- Record rejected and inspected experiments, not only winners.
- Reject a model whose cost-adjusted bootstrap interval crosses zero, calibration is unstable, effective sample size is small, or performance depends on a small episode.

The current historical interval has already been inspected by the old models. Native results on it are exploratory OOS diagnostics, not a frozen final claim. A new future interval is required for promotion.

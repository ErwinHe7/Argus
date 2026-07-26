# Model artifacts

This directory contains the exact candidate artifacts associated with the
review snapshot.

## Universe candidates

`universe/` contains the registry and nine exact-symbol candidate artifacts:

- AAPL
- BE
- IGV
- MU
- NBIS
- NVDA
- QQQ
- SOXX
- SPX

All nine are unpromoted. Each selected the current tested state-count boundary
`K=8`; this does not establish that eight states are optimal. No matching
promoted calibration artifact is available.

## Legacy reference

`legacy/` contains the prior standalone frozen predictor and its candidate
receipt. It is included only for routing and regression comparison. It must not
override exact-symbol universe routing.

## Data and editing boundary

The JSON files contain model parameters, configuration, hashes, training
lineage, and analog training-row indices. They do not contain raw historical
or real-time market observations. Do not edit generated parameters or hashes
by hand; modify the training/model source, rerun validation, and export a new
immutable candidate.

These files are not evidence of production promotion, calibration, vendor
entitlement, or live-data readiness.


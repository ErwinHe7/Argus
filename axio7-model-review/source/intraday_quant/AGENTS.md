# Intraday quantitative research instructions

Read `../../PROJECT_CONTRACT.md` and the repository-level `AGENTS.md` before modifying this package.

- Use official XNYS trading sessions, not weekday approximations.
- Build causal windows only; no feature, label, or transform may observe information unavailable at the observation cutoff.
- Fit transformations and models on training data only.
- Use embargoed chronological splits and report untouched test results separately.
- Validate inputs and serialized artifact contracts with Pydantic.
- Use deterministic hashing for artifacts and metadata.
- Add and run tests covering causality and serialization for relevant changes.

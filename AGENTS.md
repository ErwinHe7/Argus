# Repository instructions

Read `axio7-model-review/PROJECT_CONTRACT.md` before changing code in this repository.

- Preserve any unrelated dirty-worktree changes; do not reset, discard, or reformat files outside the task scope.
- Keep all quantitative calculations in the research/runtime layers. TypeScript may render validated artifact data but must not calculate probabilities, Greeks, GEX, expected return, risk, or arbitrage economics.
- Organize new work in feature-owned folders rather than shared catch-all modules.
- Run the narrowest relevant checks for every change and report the commands and outcomes.
- Keep secrets out of client bundles, logs, fixtures, and commits. Missing, stale, incomplete, or non-causal data must fail closed.

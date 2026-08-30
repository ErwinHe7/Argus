# Repository instructions

Read `axio7-model-review/PROJECT_CONTRACT.md` before changing code in this repository.

- Preserve any unrelated dirty-worktree changes; do not reset, discard, or reformat files outside the task scope.
- Keep all quantitative calculations in the research/runtime layers. TypeScript may render validated artifact data but must not calculate probabilities, Greeks, GEX, expected return, risk, or arbitrage economics.
- Organize new work in feature-owned folders rather than shared catch-all modules.
- Run the narrowest relevant checks for every change and report the commands and outcomes.
- Keep secrets out of client bundles, logs, fixtures, and commits. Missing, stale, incomplete, or non-causal data must fail closed.

## Plan small and avoid over-engineering

- Treat this principle as the default for every task. Depart from it only when the user explicitly requests an over-engineered or hyper-engineered solution.
- For non-trivial work, make the narrowest plan that can safely complete the task before editing.
- Identify in the plan:
  - files to inspect;
  - files likely to change;
  - checks to run;
  - pass/fail criteria;
  - important non-goals.
- Create a planning document only when useful or explicitly requested.
- Reuse existing patterns before introducing new abstractions.
- Choose the simplest solution that:
  - fully solves the current requirement;
  - fits the existing architecture;
  - handles real and likely edge cases;
  - remains understandable and maintainable.
- Unless the task clearly requires it, do not:
  - add dependencies;
  - restructure folders;
  - introduce infrastructure, configuration, extra layers, or duplicate systems;
  - build unrelated features;
  - perform broad cleanup or refactors;
  - future-proof for hypothetical requirements.

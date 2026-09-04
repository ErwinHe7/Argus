# Main branch integration — 2026-09-04

Base: `2607286` (`origin/main`). `git pull --ff-only origin main` found the
branch current. Integration was performed in a clean worktree; the owner's
uncommitted audio, infrastructure, and other work in the original checkout was
preserved.

## Included

- `origin/fix/p0-numerics` (`48c93f6`), including
  `origin/agent/sync-current-model-source` (`cd036f6`): restored Rust market-data
  sources, Python reports, and M1–M3 numerics fixes. Documentation conflicts
  retain the English entry points and the current production evidence gate.
- `origin/allan/website-integration` (`a62299c`): historical replay and named
  liquid-equity research candidates. Resolutions preserve the current homepage,
  active model registry, production feature contract, five-second prediction
  budget, and current causal live initialization/finalization. The frontend
  renders runtime horizon results without averaging expected returns or
  deriving an aggregate directional call. See the platform execution log.
- `a3ef42c` from `origin/claude/research-website-design-hsc85q`: removes the
  retired mixed Ritual workflow, retaining its existing fast/evidence lanes.
- The verified `leoinvesting.com` callback, beta profile, CORS, waitlist-origin
  changes and [deployment record](ritual-investing/leoinvesting-domain-migration.md).

All local branch tips were already ancestors of the base `origin/main`.

## Held out

`16cc0b5` (`feat(quant): add the ZIG-ZAG setup card`) remains unmerged. Its
`platform/lib/quant/setup-card.ts` computes volatility and projected price
levels in TypeScript, contrary to the repository contract requiring numerical
work in research/runtime layers. Its API also assembles the result from daily
bars rather than rendering a validated runtime artifact. This feature requires
a separate runtime implementation before it can be integrated under the
current instructions. The source branch is preserved.

## Validation

- Canonical Rust: `cargo fmt --check` and
  `cargo test --locked --offline --lib --no-fail-fast`: **306 passed**.
- Platform Rust: `cargo fmt --check`;
  `TMPDIR=/private/tmp CARGO_INCREMENTAL=0 CARGO_PROFILE_DEV_DEBUG=0 CARGO_PROFILE_TEST_DEBUG=0 cargo test --locked --offline -j 1 --lib`:
  **503 passed**; `cargo check --locked --offline -j 1 --bins`: passed.
  The canonical temporary directory avoids macOS's symlinked default temp path
  being correctly rejected by training-lineage tests.
- Platform: `npm run typecheck` and `npm run test:quant-conversation`:
  passed, **25 contracts**. The merged CSS also parses with PostCSS.
- Canonical Python: `python -m pytest --basetemp ... -p no:cacheprovider`:
  **92 passed, 6 skipped, 2 pre-existing failures**. Both failures are the
  documented `NotImplementedError` ingestion/cleaning stubs in `data/`.
  The targeted analog bridge suite had **1 passed, 1 skipped** because its
  external `quantctl` executable was not on the Python test's PATH.
- Supabase: exact-origin environment tests **6 passed**, waitlist tests
  **11 passed**, and API `deno task check` passed.
- Flutter: `flutter test test/runtime_config_test.dart test/member_auth_test.dart`:
  **13 passed**.
- Site: `node node_modules/vitest/vitest.mjs run test/ci-workflow.test.ts`:
  **6 passed**.
- Scoped `git diff --check`: passed.

This integration is not a model promotion or a new production deployment.
No current live-data readiness receipt was produced. The domain deployment
was separately verified as recorded in its migration log.

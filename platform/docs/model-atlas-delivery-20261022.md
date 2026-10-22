# Model atlas release · October 22, 2026

The atlas presents nine retained Argus candidate models at `/#/models`: a model
picker, linked regime chart and table, transition heatmap and matrix, state-count
selection scores, pipeline disclosure, kernel settings, and exact artifact
lineage. It inherits the current LEO brand and Market overview default route.

The export is frozen research evidence with July 2026 cutoffs. No live regime,
calibration, forecast, account integration, or execution is enabled. This is a
static display release; it does not promote an inference model or establish
live-data readiness. The nine artifact files and registry match the existing
local Argus bytes.

## Changes and verification

Continues draft PR #24, adding transition-row normalization rejection in Python
and the browser contract, and resetting chart hover on symbol changes so switching
from a 12-state model to IGV's 11 states cannot retain an out-of-range index.
The pipeline is disclosed on request to bring the charts forward.

The atlas Python tests pass (6 tests and 11 mutation subtests); the broader Python
suite passed 178 tests with 7 skips and 77 subtests before the added transition
case. Atlas contracts pass 4 tests; affected research-desk contracts, its scoped
TypeScript check, and the static production bundle pass. Desktop and 390px phone
inspection found no horizontal overflow or console errors. Model switching,
keyboard regime selection, and pipeline/matrix disclosures were exercised.

Rust Clippy passes; serial Rust tests pass 587 tests with one licensed-data
benchmark ignored. The initial parallel test compile exhausted Windows paging
memory; `cargo test --locked -j1` completed successfully. Full root TypeScript and Next build retain pre-existing
errors, starting with `app/api/account/deletion-request/route.ts:14` (`notes` on
`{}`). Rust formatting retains pre-existing differences in `src/api.rs`.
The available CMake is 3.20; the native project requires 3.24. These gates are
not represented as passing, and the retained backend is not rebuilt or promoted.

## Release evidence

The baseline is `leo-axio7-domain-20261010`, version
`3f8460b6-07c4-4fff-b763-ec3d3f89570d`. The prepared stage is
`release-work/leo-model-atlas-20261022` under the local Leo Roar workspace.
Its receipts bind 2,583 unchanged backend files, unchanged routing,
273 unchanged assets, two changed assets (`desk.js`, `desk.css`), and one added
atlas JSON. Custom domains and four existing service bindings are preserved.
Wrangler dry-run passes with the retained backend's existing negative-zero warning.
The retained config omitted `workers_dev`, which Wrangler disabled on deployment.
An immediate trigger update explicitly restored `workers_dev: true` and disabled
unused preview URLs. Existing domains, services and all other settings remain.

Initial version: `2f5cf09e-7037-42f4-9934-ea099f7b1115`. Final version after the
two accessibility corrections: `9900f2f6-b0c9-46dc-aafa-5e211d3bbdac`.
The final stage is `release-work/leo-model-atlas-accessible-20261022`.
The reviewer scored the native candidate-score table and full identifier
disclosure resolved, with disposition **ship** at that bounded scope.
Live verification passed
24 asset hashes and 27 route checks across workers.dev, axio7.com and
www.axio7.com. The live browser renders and switches models without console errors.
`model-atlas-live-verification.json`, `deployment-receipt.json`,
`atlas-live.png` in the final stage retain the evidence. Original desktop/phone
and accessibility review captures remain in the first stage.
Rollback targets the baseline version above through Wrangler rollback; retain
the explicit workers.dev setting when reapplying triggers.

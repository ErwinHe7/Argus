# Chapter practice delivery · October 22, 2026

`/#/learn` adds a learning companion for all seven Green Book chapters to LEO.
Seven interactive labs complement 58 original exercises, each with progressive
hints and worked reasoning. The owner's preference is a balanced learning/timed
mix: labs are untimed and chapter practice offers a manually started 90-second
clock that can be switched off. All chapters remain open.

Mistakes and help-assisted answers enter a review queue. Completion records
practice activity, not certified knowledge. Progress survives reloads in this
browser and can be exported/imported independently of LEO identity. The app is
an original educational supplement; it does not reproduce the book.

## Verification

- 10 Python tests independently verify all 41 numeric reference answers,
  counting/conditioning enumeration, variance, replication pricing, Markov
  equations and numerical-method conventions.
- 16 feature TypeScript tests cover content rejection, game state/invariants,
  accessible payoff samples, numeric entry, progress import/merge and review.
  Six retained atlas/desk checks also pass.
- Scoped research-desk TypeScript and static production build pass.
- Browser completion of all seven labs passes. Numeric rejection, wrong/hint/
  correct feedback, review, timer start/stop, reload persistence, export and
  import merge were exercised. Desktop 1280px and phone 390px checks found no
  page overflow or console errors. Payoffs include a native values table and
  descriptive accessible names. Full-page captures are unsupported by this
  browser; viewport captures are retained.
- The mechanical design detector reported no findings. Independent finish
  review and its evidence are recorded in the feature surface brief.

No Rust, research-inference, native, auth, billing, account or service code is
changed. This static learning release does not promote any quantitative model
or certify live-data readiness. The existing broader repository build/type and
native-toolchain limitations remain recorded in the preceding atlas delivery;
they are not represented as resolved by this feature.

## Release and rollback

Baseline version: `9900f2f6-b0c9-46dc-aafa-5e211d3bbdac`, retained as
`release-work/leo-model-atlas-accessible-20261022`. The prepared stage is
`release-work/leo-quant-practice-20261022` in the Leo Roar workspace.
Its staging helper binds all 2,583 backend files, model JSON and unrelated
assets, Worker routing/configuration, workers.dev setting, custom domains and
four service bindings. Only the desk JavaScript and CSS may change.

The stage retains deployment version, manifest, browser captures and live
verification JSON. Rollback uses the baseline version above without changing
routes or configuration.

Published version: `91931216-e197-4328-baf1-a4e17573fcab` at
[LEO Quant practice](https://leo.axio7.workers.dev/#/learn).
Wrangler dry-run and deployment pass. The frozen backend emits its pre-existing
negative-zero comparison warning. Exactly two assets changed, 274 unrelated
assets and all 2,583 backend files match the baseline, and routing/configuration
remain identical. The existing model atlas data is retained byte-for-byte.

Post-deployment verification passes eight asset hashes and nine retained routes
on each of workers.dev, axio7.com and www.axio7.com: 51 checks in total, with no
failures. Private API responses retain their no-store and rejection behavior.
The live Learn route presents all seven chapters, the playable chameleon lab,
and practice with the optional, manually started timer. Production progress was
not populated by the QA run. The existing nine-model atlas still renders. Live
phone checks show all seven chapter options, no page overflow and no console
errors. The independent interface finish verdict is **ship**
for its inspected source and captured states, with evidence scope and actual
capture dimensions recorded in `features/quant-practice/SURFACE.md`.

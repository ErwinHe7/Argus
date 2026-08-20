# Handoff Document

Read this document in full before taking over this repository.

**Last updated**: 2026-07-26
**Corresponding branch**: `fix/handoff-buildable` (10 commits, based on the `agent/axio7-model-review` tip `8d18b73`)

---

## 0. Current Status in One Sentence

The handoff package on `main` **does not compile and its tests cannot run**. The root cause is that directory-name rules in `.gitignore` swallowed three source packages. `fix/handoff-buildable` restores the build, but the **real code that was swallowed still exists only in the repository owner's working tree** — everything added on the branch is a diagnostic stub containing `unimplemented!()`.

Before changing any model code, complete the two tasks in Section 3.

---

## 1. ⚠️ Most Important: The Repository Currently Contains Placeholder Code

`fix/handoff-buildable` added **stubs** at the following three locations. They compile and pass type checks, but **every call will panic or raise**:

| Path | Language | Status |
|---|---|---|
| `axio7-model-review/source/quant_engine_rs/src/data/` | Rust | All 10 submodules contain `unimplemented!()` |
| `axio7-model-review/source/intraday_quant/src/intraday_quant/data/` | Python | All functions raise `NotImplementedError` |
| `axio7-model-review/source/intraday_quant/src/intraday_quant/reports/` | Python | All functions raise `NotImplementedError` |

Every file has a `STUB` marker and an explanation at the top.

**When restoring the original implementations, first delete each stub directory in full, then add the real code.** Do not overwrite the files one by one — the stubs contain type names that may not have existed in the original modules (see Section 4). Leaving any of them behind can create hard-to-debug duplicate definitions or semantic drift.

```bash
rm -rf axio7-model-review/source/quant_engine_rs/src/data
rm -rf axio7-model-review/source/intraday_quant/src/intraday_quant/data
rm -rf axio7-model-review/source/intraday_quant/src/intraday_quant/reports
# Then add the real implementations
```

---

## 2. Issues Already Fixed (10 Commits)

| Commit | Change | Verification |
|---|---|---|
| `4778a9e` | Fixed the root cause in `.gitignore`; added a guard script and CI | `scripts/check-no-ignored-sources.sh` verified in both directions: restoring the old rules correctly detects 9 source files, while the new rules produce no false positives |
| `6ea987c` | C++ `SQLite3::SQLite3` → `SQLite::SQLite3` | GCC 13 with `-Werror -Wconversion -Wshadow`: zero warnings; 11/11 tests passed |
| `a92259e` | Declared torch as the optional extra `neural` | — |
| `d2721ca` | Added subprocess supervision, removed the guaranteed-to-fail `COPY data`, and added `railway.json` plus deployment documentation | — |
| `fe98dea` | Python diagnostic stubs (2 packages, 7 files) | 23 passed / 5 skipped / 3 failed (all 3 failures are caused by stubs) |
| `92fa1a3` | Rust diagnostic stubs (10 submodules, 620 lines) | See below |
| `3df6111` | Documented that `OPTION_CHAIN_SCHEMA_VERSION` is unrecoverable | — |
| `b3eb5eb` | **Correction**: restored the entry-point script's default host to loopback | See Section 6 |
| `e231369` | Complete remediation plan from the multi-agent review | — |
| `77aace6` | Grafana GUI (all configuration is file-provisioned) | End-to-end verification; see `axio7-model-review/tools/README.md` |

### Verified Results After the Fix (Rust 1.97.1 x86_64-pc-windows-gnu)

```
cargo fmt --check                          passed
cargo clippy --all-targets -- -D warnings  zero warnings
cargo test --lib                           256 passed / 0 failed
cargo test --bin quantctl                    8 passed / 0 failed
cargo test --test core                      11 passed / 1 failed
```

Python: `23 passed / 5 skipped / 3 failed`
C++: `11 / 11 passed`

**Every failure is caused solely by reaching a stub; none reflects a defect in real code.**

- The only Rust failure, `csv_requires_offset_deduplicates_and_rejects_bad_rows`, panics in `MarketBarCsvImporter::import`
- The 3 Python failures are in `clean_bars` / `ingest` / `theory_performance_audit`
- All 5 Python skips come from `test_cuda_challenger.py` being unable to find torch

Compared with the README's claimed `286 lib / 8 CLI / 12 integration`: **the 8 CLI and 12 integration tests match exactly**, while the library suite is short by 30 tests — those 30 unit tests were in the deleted `src/data/` directory and were lost with it.

---

## 3. First Two Tasks After Handoff

### 3.1 Restore the Three Source Packages

They exist only in the repository owner's complete working tree. After restoring them:

```bash
bash scripts/check-no-ignored-sources.sh   # Confirm that gitignore no longer swallows the restored code
cd axio7-model-review/source/quant_engine_rs && cargo test
cd ../intraday_quant && python -m pytest --basetemp .pytest-tmp -p no:cacheprovider
```

The Rust library test count should return from 256 to 286. If it does not, additional files are still missing.

### 3.2 Get CI Running

`.github/workflows/ci.yml` is ready but has never run in a real CI environment. It builds all three source trees from a clean checkout and builds the Docker image — this is the only structural safeguard against “works locally but not from the repository.”

---

## 4. Sources of Stub Signatures (Reference for Restoring the Code)

The signatures fall into two categories, documented in comments above each type:

**Exact reconstructions** (supported by complete struct literals, so the field sets are reliable):

| Type | Source |
|---|---|
| `RealtimeStockTapeEvent` (26 fields) | Complete literal in the test at `src/engine/l1_order_flow.rs:283-310` |
| `DataCapabilityReport` (22 fields) | Complete literal in the test at `src/predictor.rs:2890-2912` |
| `MaterializeRequest` (13 fields) | Complete literal at `src/bin/quantctl.rs:1681-1694` |
| `FileImportReport` | Assertions in `tests/core.rs:160-163` |

**Inferred from call sites** (the original types were probably broader, and most type names are guesses): everything else. In particular, the following names were invented and almost certainly differ from the original module names: `CapabilityAudit`, `DataDoctorReport`, `ArtifactEntry`, `FusionSnapshot`, `ContextAuditReport`, `CostEstimate`, `DownloadReceipt`, `MaterializeReceipt`, `StoreCoverage`, `MassiveStatus`, `MassiveSyncReceipt`, `FiveDaySamplePlan`, `OptionChainCoverage`, `RealtimeEntitlementReport`.

### Known Hazards

**The string value of `OPTION_CHAIN_SCHEMA_VERSION` is unrecoverable.** It is only compared and never printed, and the package includes no sample artifact. Until the original value is restored, every real chain artifact will be rejected by the schema gates at `api.rs:1489`, `market_query.rs:1070`, and `quantctl.rs:586` with `OPTION_CHAIN_SCHEMA_INCOMPATIBLE`. This fails closed and will not produce incorrect results, but it can easily be misdiagnosed as a data problem.

**The original `reports/` package was broader than the imported surface.** `service.py:147` reads `reports/hypothesis_event_audit.csv`, but no module in the repository produces it. The stub reconstructs only the imported portion.

**`artifact_path` in `registry.json` uses Windows backslashes** (`data/models/universe\SPX.frozen.json`), so the file will not be found in a Linux container.

**The artifact ZIP uses backslashes as path separators**, which violates ZIP specification APPNOTE 4.4.17.1. On Linux/macOS, `unzip` extracts literal filenames containing backslashes rather than a directory tree, so they do not match the forward-slash paths in `SHA256SUMS.txt`.

---

## 5. Dead Ends Not to Repeat

**The `TimeDelta` type error at `l1_order_flow.rs:179` is cascading, not an independent bug.**

`cutoff - latest.event_at <= max_age` reports `expected DateTime, found TimeDelta`. The sequence is: `RealtimeStockTapeEvent` fails to resolve → the `Quote<'a>` struct becomes contaminated → field access degrades into an error type → the compiler chooses the wrong one of the two `Sub` implementations for `DateTime`. Once the stub is restored, the error disappears automatically; **that line of code is correct**.

Two independent approaches (a probe experiment and independent contract inference) reproduced this conclusion. “Fixing” the line before restoring `data` will introduce a real bug.

---

## 6. Deployment: One Previously Misdiagnosed Conclusion

**By design, this service must not be exposed externally until TLS/mTLS is implemented.**

`config.rs:659-663`:

```rust
if !server_ip.is_loopback() {
    bail!("quant control plane must remain loopback-only until TLS/mTLS is implemented");
}
```

`quantd.rs:32-38` calls `validate()` immediately after applying the `--host` override. Therefore, passing `0.0.0.0` does not mean “the service cannot be reached”; it means **the process cannot start**.

This branch temporarily changed the entry-point script's default to `0.0.0.0` in commit `d2721ca`. That was **incorrect** and was fixed in `b3eb5eb`. This is a deliberate security gate: the control plane includes a kill switch and paper-trading controls, while authentication consists only of a static header token.

Railway edge routing, however, requires the container to listen on a non-loopback address — **the two requirements conflict directly**. The three options and their tradeoffs are documented in `axio7-model-review/source/quant_engine_rs/DEPLOY.railway.md`. The “in-container reverse proxy” option would silently bypass a deliberate security control; it requires an explicit owner decision and must not be adopted by default.

Other deployment blockers in the same document: the ephemeral filesystem erases the ledger on every redeploy; a single `massive-check` gate covers both equity and options entitlements; `numReplicas` must remain 1 (a correctness constraint because the ledger has no idempotency key); and both default paths for `massive-model` are under `data/` but absent from the image, which will cause a crash loop when combined with subprocess supervision.

---

## 7. Outstanding Model Work

Full report: `axio7-model-review/review-package/REMEDIATION-PLAN.zh-CN.md`

**Coverage statement**: The multi-agent review produced **109 findings**, of which **48 received adversarial verification** (38 confirmed, 10 disproven); **the remaining 61 were not verified** because the workflow capped each verification track at 8 findings. The report includes only verified findings. The unverified 61 are not presumed absent; they simply have not been validated.

Three independent P0 issues:

**M1 — HMM emission probabilities are computed in linear space and hard-clamped to `1e-300`** (`engine/regime.rs:214-223`)
The per-timestep log-likelihood is trapped in `[-690.776, +14.746]`, with a finite lower bound and a positive upper bound. Correct log-space reference implementations exist in the same repository (`regime_competition.rs:223-245`, `tvtp_regime.rs:399-406`).

**M2 — The state count is selected by raw argmax of holdout log-likelihood, with no complexity penalty or occupancy constraint** (the same rule is duplicated **four times**: `regime_competition.rs:399-424`, `predictor.rs:820-846`, `quantctl.rs:3121-3143`, `quantctl.rs:773`)
This mechanically explains why all 9 artifacts landed at K=8. **Before fixing the selection rule, consolidate all four copies into one function**; otherwise one will inevitably be missed, especially the copy at `quantctl.rs:773` on the walk-forward fold path.

Two common misdiagnoses should be ruled out: the `1e-12` tolerance is not the cause (the actual gaps are ten orders of magnitude larger), and switching to BIC will not solve the problem either (with 30,000 samples, the penalty is overwhelmed). The remedy is a minimum occupancy constraint plus an expanded candidate grid.

**M3 — The Rust and Python analog kernels are two different estimators**
They differ across all eight dimensions: standardization, metric, feature set, bandwidth, weighting, neighbor selection, k value, and `median_return` weighting. **The only quantitative backtest evidence in this handoff package does not evaluate the model that would be deployed.**

### Boundary Note

`predictor.rs:2193` unconditionally pushes `RESEARCH_ONLY_NO_TRADE` for every forecast, and `:2185` adds a separate OOS calibration gate. The defects above **currently cannot drive any real order**; they undermine the credibility of the decision about whether the model should be promoted.

---

## 8. Architecture Convergence

Fix the three source trees into the following **one-way pipeline** and codify it in `PROJECT_CONTRACT.md`:

```
Python research/training ──► frozen artifact ──► Rust production inference/realtime ──► evidence envelope ──► TypeScript presentation
```

- Python must not contain inference implementations that could be treated as “production model evidence”
- Rust must not contain research-reporting logic outside the training loop (`regime_competition.rs` should move behind the `research` feature gate)
- The artifact is the only cross-language interface
- **Retire C++ without deleting it**: first run the CI cpp job successfully once for the record, then move the entire tree to `reference-docs/legacy-cpp/` and mark it “not part of the build”
- **A cross-language golden test is the only structural remedy for M3**; the three-layer implementation plan is in Section 5.3 of the remediation plan
- **The TypeScript boundary is the evidence envelope**: prohibit all numeric calculations, threshold decisions, and derivation of no-trade reasons. In particular, the frontend must never filter out `RESEARCH_ONLY_NO_TRADE` in any form

---

## 9. Environment

The following environment is required to reproduce this branch's verification results:

| Tool | Version | Notes |
|---|---|---|
| Rust | 1.97.1 | This verification used `x86_64-pc-windows-gnu`; use the GNU toolchain when MSVC is unavailable on Windows |
| Python | 3.13.7 | `pyproject.toml` requires `>=3.11` |
| CMake | 3.29 | Available on Windows through Strawberry Perl |
| C compiler | GCC 13.2 | Both the `bundled` feature of `rusqlite` and `ring` require it |
| SQLite3 dev | 3.53.4 | On Windows, download the amalgamation from sqlite.org and build a static library |
| OpenSSL | 3.3.0 | Included with Strawberry Perl |

On Windows, `ctest` may report `0xc0000139` (`STATUS_ENTRYPOINT_NOT_FOUND`) because the MinGW runtime DLLs are not on PATH, not because of a code defect. Add `C:\Strawberry\c\bin` to PATH and run the test binary directly.

---

## 10. GUI

`axio7-model-review/tools/` contains a Grafana setup whose configuration is entirely file-provisioned.

The decisive constraint behind this choice is **CORS**: `api.rs` never installs `CorsLayer` (the CORS feature of `tower-http` is enabled at `Cargo.toml:42`, but is unused throughout the repository), so any GUI that sends requests directly from the browser will be blocked by the same-origin policy. The Infinity data source fetches data server-side and does not pass through the browser.

`tools/fixture-api/server.py` **is not quantd** — the real quantd cannot run because `src/data/` is missing. The fixture reads the universe registry from the repository's real artifact ZIP, and each object in its response includes a `_source` field distinguishing `artifact` from `synthetic`. **No `synthetic` field may be treated as evidence of system behavior.**

See `axio7-model-review/tools/README.md` for the verified and unfinished items. In short: all 8 read-only panels passed end-to-end verification; the 4 POST buttons render but their submissions do not take effect (the `elements` schema of `volkovlabs-form-panel` differs from the handwritten configuration), while the POST endpoints themselves have been verified directly.

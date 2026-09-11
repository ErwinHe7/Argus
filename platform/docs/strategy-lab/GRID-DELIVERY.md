# Grid research delivery — September 7, 2026

GRID-R1 is implemented inside **Strategies → Open grid research**. It is a
fixed-range, cash-start research variant for whole shares. It supports arithmetic
and geometric spacing, editable bounds/costs/loss thresholds, local JSON imports,
three explicitly fictional demonstrations, and frozen request/result exports.
The strategy and cash-and-position ledger run in canonical Rust; the browser
executes the same source locally through WebAssembly. No historical dataset is
uploaded by the feature.

The source research, precise rules, fill assumptions, input format, and startup
commands are in [GRID-R1.md](GRID-R1.md). The current result is a daily-close,
next-observed-open approximation. It is not an exchange's standing-order bot.
Historical quotes, queue position, partial fills, actual grid broker operation,
external cash flows, and profitability have not been validated.

## What changed

| Area | Source |
|---|---|
| Canonical levels, slot lifecycle, decimal ledger, risk and replay | `quant_engine_rs/src/strategy_lab/grid/` |
| Distinct native JSON dispatch | `quant_engine_rs/src/bin/strategy-lab.rs` (`grid_replay`) |
| Minimal browser build and bounded byte-buffer ABI | `quant_engine_rs/grid_wasm/` |
| Local worker, import validation, forms, results and disclosures | `features/strategy-lab/grid/` |
| Entry in the existing workspace; preserved auth/monitor/Pause | `features/strategy-lab/StrategyWorkspace.tsx` |
| Optional Python orchestration of Rust, without duplicate strategy logic | `intraday_quant/src/intraday_quant/strategy_lab/grid.py` |
| Reproducible WASM build and stale-source/hash checks | `scripts/grid-research-build.mjs`, `scripts/grid-research-assets.mjs` |

Results lead with total marked P&L and remaining inventory. The report separately
shows completed-cycle profit, loss exits, unrealized P&L, fees, close-sampled
drawdown, occupied slots, range breaches, cash/buy-and-hold comparisons, and the
full journal. A decline fixture deliberately demonstrates positive closed-cycle
profit alongside a loss in total account value. These invented prices are
teaching fixtures, not a market backtest or evidence of expected returns.

MR-v1/MOM-v1 deployment contracts and the local paper connector retain their
existing allowlist. GRID-R1 cannot create a trading mandate. Grid execution
requires durable per-slot broker fill allocation, reservations, reconciliation,
competing-exit tests, and broker lifecycle evidence before a later release.
Existing installer packages were not repackaged or relabeled as grid-capable.

## Verification

| Check | Result and scope |
|---|---|
| Native strategy regressions | 33 passed: 17 retained MR/MOM and 16 grid tests |
| Minimal crate | 17 passed: the same 16 grid tests plus the WASM JSON boundary test |
| Rust lint | Strict all-targets Clippy passed for the minimal crate |
| TypeScript and browser contracts | 30 passed, including five grid/WASM tests and retained route/auth/storage/widget tests |
| Python | 10 retained research tests and three grid-orchestration tests passed |
| Native/WASM equivalence | Exact full-report equality for range, decline, rally, and geometric fixtures |
| Python/native equivalence | Exact decline-report equality through the actual native CLI |
| Type checking | Full platform, scoped workspace, and separate worker checks passed |
| Browser workflow | 16 checks passed; no page errors or current failures in the final receipt |

The native engine tests cover exact levels and thresholds, tick collapse, zero
volume, insufficient capital, next-open eligibility/expiry, repeated cycles,
multi-slot cash/fee conservation, future-data invariance, ignored intraday paths,
range escape, latched gap losses, terminal pending liquidation, and unsupported
inputs. An independent source review found a geometric pre-rounding bug; the fix
floors directly to ticks and has an exact regression test.

Browser checks exercise the actual worker and WASM binary, all three fixtures,
parameter changes and new run hashes, local imports/exports, malformed data,
WASM failure/recovery, keyboard result focus, and navigation back to connector
setup. Authentication, archive outages, and retained Pause are tested with
explicitly injected fixtures; these are not real member or broker evidence.
The first functional pass's focus race was corrected with a post-commit effect.
The independent visual review's mobile comparison finding is resolved: approach,
equity, and return now fit together at 390px and 320px. The wide slot ledger keeps
its own scrolling region. Full mobile workflow acceptance used 390px; a separate
4px page overflow at 320px remains recorded and is not a whole-page pass at that
width. The scoped follow-up verdict is ship. Desktop/mobile captures and review
records are kept separately from the financial engine receipts.

A fresh generic Impeccable documenter merged the built extension into the feature's
DESIGN.md, matching sidecar, and surface brief after the scoped review closed.
The existing visual identity and paper controls are preserved. The known 320px
page overflow and synthetic results were not made design or performance claims.

Evidence paths, relative to `platform`:

- `.quant-runtime/grid/verification-receipt.json`
- `.quant-runtime/grid/build-receipt.json`
- `.quant-runtime/grid/native/receipt.json` and complete native request/results
- `.quant-runtime/grid/engine-review.md`
- `.quant-runtime/grid/reports/` for WASM-generated teaching reports
- `.impeccable/review/grid/browser-checks.json` and final desktop/mobile captures
- `.impeccable/review/grid/finish-review.md` and `verdict.md`

## Release and remaining boundaries

The combined Grid/TradingView static overlay is prepared at
`C:/Users/Hj/Desktop/Leo Roar/release-work/leo-grid-tradingview-20260907`, based on
the preceding Strategy Lab stage. It preserves the current Worker configuration,
hostname, backend, and unrelated assets. It adds only the desk bundle/styles and
grid assets under `/app/research-desk/`. See the stage's receipt and manifests for
the exact final hashes. This work prepares the release; it does not publish it.

The final preservation check confirms 2,583 identical frozen backend files,
unchanged unrelated assets and Worker configuration, eight changed desk-owned
assets, no removals, and an exact match with current public desk files. Wrangler
4.127.1 completed a deploy dry run with 358 assets and no deployment. Its existing
frozen-backend `=== -0` warning is retained. `RELEASE.md` and `dry-run.log` in the
stage record that result.

The browser preview remains at `http://127.0.0.1:3117/#/strategies`. Hosting,
production strategy authentication/configuration, historical-data entitlements,
and the previous paper connector's platform/signing/broker prerequisites retain
their existing external status. Grid research itself requires no brokerage
credentials. Real-money and options execution remain disabled.

TradingView's hosted chart integration is documented separately in
[tradingview-delivery.md](../tradingview-delivery.md). Provider charts do not
supply raw data to this grid engine or the connector, and their displayed
exchange delay/availability status remains authoritative for that display.

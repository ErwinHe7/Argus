# Axio Quant OS architecture

This is a resident, event-driven local service. The web application and CLI are control and inspection surfaces; they do not own market state, model state, risk state, orders, or positions.

```text
Massive historical bars / Nasdaq QBBO capture / future OPRA NBBO
                              |
                    Rust MarketDataAdapter
                              |
          ordered point-in-time event log + lineage hashes
                              |
             deterministic replay / incremental features
                              |
 baseline | calibrated GBDT | HMM | robust day-block analog kernel
                              |
        calibrated distributions + cost/tail/uncertainty penalties
                              |
                Rust RiskEngine -> Paper OMS -> Fill
                              |
             append-only SQLite double-entry ledger
                              |
      CLI / Next.js query surface / optional Perl EOD reconciliation
```

## Runtime ownership

- **Rust is the production system of record.** `quantd` owns the resident event loop, risk checks, OMS state, deterministic replay, model inference, and the sole ledger writer. `quantctl` is its research and operations interface.
- **C++ is a bounded performance module.** `quant_core_cpp` contains the Nasdaq QBBO decoder, a parity harness, and experimental native implementations. A component moves into the Rust process through FFI only after event-by-event parity, profiling evidence, fuzzing, sanitizers, and rollback tests. The current C++ `axiod` is a laboratory harness, not the production daemon.
- **Perl is optional.** The scripts under `perl/` reconcile the shared append-only database and export daily reports. They are not on the signal, risk, order, or accounting write path.
- **Next.js is not the backend.** It reads reports and invokes control-plane operations. No trade depends on an HTTP request to the UI.

## Time and causality

All stored event times are UTC. Exchange-session logic converts to `America/New_York` using timezone rules. A minute bar becomes usable only after it is finalized. A signal generated after minute `t` can first execute on an observable event after `t`; current-bar close fills are forbidden.

The five-minute feature contract separates the active partial bucket from the last fully closed bucket. The HMM emits **filtered** state probabilities conditioned on observations through the present, never retrospectively smoothed probabilities. Analog neighbors must come from earlier sessions with fully completed outcome windows, and only the nearest observation from each historical day can contribute.

## Promotion boundary

No model can enter paper or live execution because it has a high headline win rate. Promotion requires a registered data manifest, frozen features and labels, whole-day purged walk-forward folds, untouched final history, calibrated probabilities, net positive lower confidence bound after costs, episode/day concentration limits, replay determinism, and risk/ledger tests. The currently inspected 2024-07-18 through 2026-07-17 history is exploratory and cannot be reused as a pristine final holdout.

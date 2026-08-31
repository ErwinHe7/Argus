# Behavioral, Sentiment, and Market-Regime Research Decision ??? 2026-07-25

Status: implemented contract hardening plus research roadmap; no production model promotion
Canonical production runtime: `quant_engine_rs`
Offline training and challengers: `intraday_quant`

## Decision

AXIO7 should model observable aggregate behavior and market response, not claim to read minds. The joint research target is:

```text
P(future return, realized volatility, continuation/reversal | causal HMM posterior,
  price/volume behavior, order flow/liquidity, news/attention, option tail state,
  hedging-feedback scenarios, clock time)
```

This is a distribution of future market outcomes. It is not the fraction of people who will buy, a participant headcount, or proof that retail, institutions, or dealers caused the state.

The production model remains unchanged: frozen causal HMM plus same-regime historical analogues. The behavioral layer is descriptive, uncalibrated, excluded from the frozen distance, and `affects_decision=false`.

## Current truthful capability

| Capability | Current state after this change |
|---|---|
| Neural networks / deep learning | CUDA-trained causal TCN and regime-gated challengers exist offline; they are not promoted and have no Rust production runtime. |
| Structural market regime | Causal HMM filtered posterior, entropy, transition context, and same-regime analogues are implemented. No future-smoothed posterior is allowed online. |
| Observable group-behavior proxy | Implemented as market-derived downside stress, upside chase, crowding, attention intensity, deleveraging-like, and rebound/squeeze-like indices. |
| Explicit psychology | Not directly observed. Fear/FOMO/herding language is retained only as an interpretation hypothesis attached to observable proxies. |
| Actor attribution | Removed from the behavioral contract. OHLCV cannot identify retail, institutions, CTA, vol-control, short sellers, or dealers. |
| News/social sentiment | Typed as missing. Current feeds do not yet provide a complete point-in-time, licensed, revisioned history suitable for model training. |
| OFI | A causal L1 top-of-book research extractor is implemented, but it is explicitly not the L1???L10 Deep OFI input and is not in the frozen model. Current capability receipts do not authorize production D1 order-flow use. |
| Combined behavioral-sentiment regime | Blocked until causal external histories, a trained immutable artifact, purged walk-forward tests, and forward shadow are complete. |
| Production decision use | None. Automatic execution stays disabled. |

## Paper-by-paper integration decision

### 1. HMM???SVM/MKL high-frequency regime classification

The 2025 peer-reviewed paper uses Reuters 2017 trade/top-of-book data for 40 FTSE 100 stocks, fits three-state HMMs, extracts state/transition/emission and Fisher-information embeddings, then feeds them to SVM or multiple-kernel learning. The paper's reported classification performance is not SPY/SPX 5???60 minute executable alpha. Its state-space construction also uses smoothed probabilities in parts of the study; AXIO7 online inference must use only filtered probabilities.

Decision:

- keep the full causal HMM posterior, entropy, persistence, and transitions rather than only a hard label;
- add Fisher/state/transition embeddings and MKL only as an offline challenger after causal TAQ replay exists;
- do not reproduce paper metrics as AXIO7 evidence;
- do not assign psychological meanings to HMM state numbers.

Source: [Koukorinis, Peters, and Germano, Methodology and Computing in Applied Probability (2025)](https://link.springer.com/article/10.1007/s11009-025-10148-8).

### 2. Deep Order Flow Imbalance

The paper uses LOBSTER event data for 115 Nasdaq stocks, top ten non-empty levels, and the most recent 100 book updates. Stationary order-flow inputs often outperform raw order-book states. Its useful horizon is approximately two stock-specific average price changes, normally far shorter than AXIO7's 5???60 minute targets.

Decision:

- implement causal bid flow, ask flow, normalized OFI, depth imbalance, microprice deviation, spread, event rate, sequence-gap and freshness checks;
- preserve SPY and ES as source-specific proxies; SPX has no native order book;
- never synthesize OFI from OHLCV;
- treat the new L1 extractor as an engineering precursor only; true Deep OFI remains blocked on entitled, ordered L2 data and venue-coverage evidence;
- test 5???60 minute aggregation, persistence, reversal count, decay, and interaction with liquidity as new AXIO7 hypotheses.

Source: [Kolm, Turiel, and Westray, Mathematical Finance (2023)](https://onlinelibrary.wiley.com/doi/abs/10.1111/mafi.12413).

### 3. Sequential Predictive Conformal Inference

SPCI wraps a scalar point model, models conditional quantiles of recent residuals, and chooses a narrow asymmetric interval. Under dependent time series its guarantee is asymptotic under assumptions, not an unconditional finite-sample promise for arbitrary financial data.

Decision:

- maintain separate settled residual streams for 5, 15, 30, and 60 minutes;
- condition and audit both pooled and regime-specific coverage;
- never add a residual before its horizon matures;
- output target coverage, realized rolling coverage, sample count, cutoff, and artifact version;
- fail closed or use a predeclared pooled fallback when a regime lacks samples;
- implement only after the current point predictor and forward ledger produce sufficient uncontaminated residual history.

A future `NO_TRADE` rule when an after-cost interval crosses zero is an AXIO7 policy, not a theorem from the paper.

Source: [Xu and Xie, ICML/PMLR (2023)](https://proceedings.mlr.press/v202/xu23r.html).

### 4. Learnable Matrix Profile (L-MAP)

L-MAP combines FFT/LSH candidate construction, graph neural embeddings, triplet learning, clustering, and distributional motif distance. It was evaluated on multivariate benchmark and industrial datasets, not financial return prediction.

Decision:

- use only as an offline analogue-retrieval challenger;
- train encoder, normalization, clustering, and thresholds on training history only;
- query only fully completed pre-cutoff windows with overlap exclusion;
- retain dated analogue IDs and raw subsequent outcomes for auditability;
- keep the exact normalized-Euclidean matrix-profile implementation as the reference baseline;
- never call raw analogue frequency a probability without separate calibration.

Source: [Lin et al., AAAI (2026)](https://ojs.aaai.org/index.php/AAAI/article/view/38550).

### 5. 0DTE gamma risk and volatility propagation

The working paper studies estimated market-maker inventory gamma and participant flow. Its main result is not ???high OI ?? gamma always suppresses or amplifies volatility.??? Estimated positive and negative dealer gamma are associated with different reversal/momentum behavior, but the dealer inventory estimate depends on participant-type open/close flow and reconstruction assumptions that AXIO7 currently lacks.

Decision:

- keep unsigned gamma concentration and explicitly named long/short-dealer scenarios separate;
- publish estimated dealer sign only if participant-type flow and inventory reconstruction are available, with uncertainty;
- model hedging-feedback regime separately from human sentiment;
- never infer dealer identity or position sign from OI or volume alone.

Source: [Dim, Eraker, and Vilkov, SSRN working paper, revised 2025](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4692190).

### 6. Local expansions for 0DTE pricing

The 2025 peer-reviewed article calibrates local Edgeworth/Gram???Charlier and jump specifications to short samples of actual SPX, DAX, and Euro Stoxx 50 0DTE cross-sections. Non-Gaussian jump specifications improve tail fitting, but this is option-surface calibration, not direction or psychology.

Decision:

- add NIG/local-expansion as a separate option-pricer challenger against Bates/SVI/other baselines;
- expose risk-neutral skew, kurtosis, jump, vol-of-vol, leverage, and surface-fit diagnostics as `option_tail_state`;
- require synchronized NBBO, forward, rates, dividends, expiry seconds, quote width/size, and date-out validation;
- do not treat risk-neutral skew as directly observed fear.

Source: [Finance Research Open (2025)](https://www.sciencedirect.com/science/article/pii/S3050700625000532).

### 7. Empirical time evolution of SPX option prices

This preprint uses daily OptionMetrics SPX puts from 1996???2022 and excludes maturities below one month. Its small neural network is a useful long-dated daily baseline, not evidence for intraday 0DTE or 5???60 minute direction.

Decision:

- use BSM/structural anchors, expanding-versus-rolling stability checks, moneyness buckets, and explicit shape tests as baseline ideas;
- do not describe the model as guaranteed arbitrage-free;
- do not use it as 0DTE validation.

Source: [Almeida and Freire, arXiv (2025)](https://arxiv.org/abs/2506.17511).

### 8. Differential ML for 0DTE options

The July 2026 preprint trains a Bates-based neural pricer with price/Greek supervision, a separate jump operator, PIDE residual, maturity gating, and no-arbitrage penalties. Its main evidence is simulated or synthetic; it does not establish market alpha or executable hedging performance.

Decision:

- use only as an offline option-pricer/Greeks challenger;
- retain maturity gating, Greek supervision, separate jump-operator supervision, robust gamma loss, and explicit static-arbitrage validation;
- validate on real synchronized OPRA NBBO and realized hedge/P&L before any promotion;
- do not mix the pricer with the underlying direction model.

Source: [Differential Machine Learning for 0DTE Options, arXiv v5 (2026)](https://arxiv.org/abs/2603.07600v5).

## Psychology and sentiment feature policy

Behavioral-finance research supports using sentiment and attention as distinct observable proxies, while warning against treating them as direct mind-reading:

- broad sentiment can affect assets that are hard to value or arbitrage, but the classic evidence is not intraday SPX proof: [Baker and Wurgler, Journal of Economic Perspectives](https://www.aeaweb.org/articles?id=10.1257%2Fjep.21.2.129);
- media pessimism can relate to temporary price pressure and volume, but the original evidence is daily: [Tetlock, Journal of Finance](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1540-6261.2007.01232.x);
- search volume is a retail-attention proxy, distinct from tone, and the original evidence is also lower frequency: [Da, Engelberg, and Gao, Journal of Finance](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1540-6261.2011.01679.x).

Required point-in-time feature families are therefore:

| Latent interpretation | Observable inputs | Honest output name |
|---|---|---|
| fear / risk reduction | downside return, breadth, VIX/VVIX, skew, credit/funding, put demand, negative tone | `downside_stress_proxy`; fear is an interpretation hypothesis |
| greed / FOMO | upside chase, relative volume, call demand, positive tone, attention | `upside_chase_proxy`; FOMO is an interpretation hypothesis |
| herding | CSAD, correlation, breadth alignment, persistent OFI, synchronized cross-asset movement | `directional_crowding_proxy` |
| attention | news velocity, disagreement, search/social activity, event/trade intensity | separate `tone` and `attention_intensity`; never merge by default |
| loss aversion / forced selling | asymmetric downside response, leverage/funding stress, closing imbalance, flow persistence | `deleveraging_like_proxy`; loss aversion is not directly identified |
| squeeze / covering | borrow/lending, short interest, opening/closing flow, rebound OFI, option demand | `rebound_squeeze_like_proxy`; actor identity remains unavailable |

Each external observation must retain event time, first availability time, receive/record time, source record ID, revision chain, license scope, content hash, age limit, and coverage. Missing, stale, future, unentitled, or unverified values remain missing rather than zero.

## Implementation receipt in this change

- Upgraded the behavioral contract to `axio.behavioral-state.v2` with a versioned feature schema and hash.
- Replaced fear/FOMO and actor claims with observable market-proxy names plus explicit interpretation hypotheses.
- Removed retail/institution/CTA/vol-control/dealer attribution, dominant actor, static capital weights, and pseudo net-flow pressure from the contract.
- Added raw behavioral-response regime scores (`STRESS_LIKE`, `CHASE_LIKE`, `CROWDING_LIKE`, `ATTENTION_SHOCK_LIKE`, `REBOUND_SQUEEZE_LIKE`, `MIXED_OR_CONFLICTED`). They are compatibility scores, not probabilities or participant counts.
- Added typed missing external features for OFI, volatility risk, options demand, breadth, funding, CSAD/correlation, news tone, attention, and positioning.
- Added explicit cross-asset completeness and coverage to `MarketState`; a missing VXX or other required member can no longer masquerade as an observed neutral zero in behavioral state or market memory.
- Added verified live-provider availability attachment for the behavioral layer; offline `MarketState` no longer invents `latest_input_available_at=bar_end`.
- Added `axio.l1-order-flow-proxy.v1` with causal timestamp, entitlement, lineage, freshness, sequence-gap, spread, depth, microprice, and OFI validation. It remains research-only and `deep_ofi_compatible=false`.
- Existing forecasts, analogues, calibrated-probability eligibility, and execution policy are unchanged.

## Promotion gates

A combined price???behavior???sentiment model may be promoted only after:

1. causal historical materialization of every used feature;
2. immutable training data, feature schema, code, and model hashes;
3. horizon-specific targets for 5/15/30/60 minutes;
4. purged repeated walk-forward evaluation with costs and negative controls;
5. ablations against price/HMM-only, price/HMM+OFI, and price/HMM+sentiment baselines;
6. calibration and coverage audits overall and within each structural/behavioral regime;
7. untouched out-of-sample evaluation;
8. 60???90 settled trading days of forward shadow;
9. Rust runtime parity and fail-closed live-data readiness;
10. reviewed immutable promotion. Until then, all outputs remain research-only and `NO_TRADE`.

## 2026-07-26 publication and UI receipt

- `axio.behavioral-state.v3` adds the separately versioned
  `axio.market-emotion-proxy.v1` publication object. It does not add a new
  psychology model or change the frozen forecast feature schema.
- The public value is a 0–100 raw compatibility index for an aggregate
  market-response pattern. It is explicitly not a probability, participant
  share, actor count, or direct observation of fear, greed, loss aversion, or
  intent.
- A label and value are published only when provider availability is aligned
  with the finalized one-minute cutoff, the price/volume/cross-asset feature
  set is complete, every component is finite, the top raw pattern has at least
  five index points of separation, no behavioral probability is injected, and
  the layer remains decision-neutral.
- Missing coverage, unverified or misaligned availability, low pattern
  separation, malformed components, or any decision/probability claim yields
  `WITHHELD` with null label and index. Missing values are not converted into a
  neutral 50.
- The Rust live-artifact validator binds the displayed pattern, raw index,
  score margin, coverage, source, and timestamp back to the underlying
  behavioral layer. A browser cannot promote or reconstruct the value.
- `/quant/intraday` now places the proxy beside the conditional forecast and
  shows its source time, partial/full-domain coverage, top raw pattern scores,
  and caveat. The UI does not call it strategy confidence and does not insert
  the proxy into expected return, calibrated direction probability, HMM
  posterior, analog distance, or execution policy.
- Behavioral analog integration remains blocked pending a new immutable
  feature artifact, point-in-time history, purged walk-forward comparison, and
  settled forward shadow.

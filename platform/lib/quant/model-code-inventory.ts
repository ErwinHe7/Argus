import type { ModelCodeInventoryItem } from '@/lib/forecast-chat-types';

const REPOSITORY = 'https://github.com/ErwinHe7/Argus';

const DEFINITIONS: Array<
  Omit<ModelCodeInventoryItem, 'sourceUrl'>
> = [
  {
    id: 'spx-next-session-regime-analog',
    name: 'SPX next-session regime analog',
    layer: 'production_rust',
    status: 'active',
    algorithm:
      'Causal trend/volatility/breadth regime map plus same-regime standardized-Euclidean nearest neighbors and purged expanding walk-forward validation.',
    sourcePath: 'platform/quant_engine_rs/src/daily_regime.rs',
  },
  {
    id: 'gaussian-hmm-regime',
    name: 'Gaussian hidden Markov regime model',
    layer: 'production_rust',
    status: 'frozen_candidate',
    algorithm:
      'Causally filtered Gaussian HMM with occupancy-gated state-count selection, Viterbi diagnostics, entropy, and horizon transition probabilities.',
    sourcePath: 'platform/quant_engine_rs/src/engine/regime.rs',
  },
  {
    id: 'same-regime-kernel-analogs',
    name: 'Same-regime kernel analog engine',
    layer: 'production_rust',
    status: 'frozen_candidate',
    algorithm:
      'Shrinkage Mahalanobis, standardized Euclidean, correlation, DTW, and regularized metric-learning retrieval with Gaussian kernels, OOD, and sensitivity diagnostics.',
    sourcePath: 'platform/quant_engine_rs/src/analog_engine/mod.rs',
  },
  {
    id: 'regime-short-horizon-sde',
    name: 'Regime-conditioned short-horizon stochastic model',
    layer: 'production_rust',
    status: 'research_only',
    algorithm:
      'Markov-switching diffusion, VWAP-residual Ornstein-Uhlenbeck process, jump diagnostics, and regime-conditioned momentum head.',
    sourcePath: 'platform/quant_engine_rs/src/engine/short_horizon.rs',
  },
  {
    id: 'tvtp-regime',
    name: 'Time-varying transition probability regime challenger',
    layer: 'production_rust',
    status: 'research_only',
    algorithm:
      'Non-homogeneous HMM challenger with time-varying transition probabilities.',
    sourcePath: 'platform/quant_engine_rs/src/engine/tvtp_regime.rs',
  },
  {
    id: 'regime-model-competition',
    name: 'Regime model competition',
    layer: 'production_rust',
    status: 'validation_gate',
    algorithm:
      'Chronological model-family comparison, occupancy eligibility, and validation log-likelihood selection.',
    sourcePath: 'platform/quant_engine_rs/src/engine/regime_competition.rs',
  },
  {
    id: 'nonlinear-challengers',
    name: 'Nonlinear model challengers',
    layer: 'production_rust',
    status: 'research_only',
    algorithm:
      'Nonlinear candidate-family comparisons under chronological validation.',
    sourcePath: 'platform/quant_engine_rs/src/nonlinear_models.rs',
  },
  {
    id: 'cross-asset-lead-lag',
    name: 'Cross-asset lead/lag audit',
    layer: 'production_rust',
    status: 'research_only',
    algorithm:
      'Causal cross-asset alignment and lead/lag evidence audit.',
    sourcePath: 'platform/quant_engine_rs/src/cross_asset.rs',
  },
  {
    id: 'probability-calibration',
    name: 'Probability calibration and promotion gate',
    layer: 'production_rust',
    status: 'validation_gate',
    algorithm:
      'Separately validated calibration artifacts and publication eligibility checks.',
    sourcePath: 'platform/quant_engine_rs/src/probability_calibration.rs',
  },
  {
    id: 'market-memory',
    name: 'Point-in-time market memory',
    layer: 'production_rust',
    status: 'validation_gate',
    algorithm:
      'Causal snapshot storage, next-session forward labels, and availability-time lineage.',
    sourcePath: 'platform/quant_engine_rs/src/market_memory/mod.rs',
  },
  {
    id: 'pattern-motif-anomaly',
    name: 'Pattern, motif, and anomaly research',
    layer: 'production_rust',
    status: 'research_only',
    algorithm:
      'Deterministic pattern factory, motif discovery, weak-signal, and anomaly research components.',
    sourcePath: 'platform/quant_engine_rs/src/pattern_factory.rs',
  },
  {
    id: 'factor-rank-risk',
    name: 'Cross-sectional factor rank and portfolio risk',
    layer: 'production_rust',
    status: 'research_only',
    algorithm:
      'Price-volume factor ranking, allocation research, and portfolio-risk diagnostics with execution disabled.',
    sourcePath: 'platform/quant_engine_rs/src/factor_rank.rs',
  },
  {
    id: 'python-analog-kernel',
    name: 'Offline analog-kernel research',
    layer: 'offline_python',
    status: 'research_only',
    algorithm:
      'Offline analog retrieval, bandwidth research, and artifact export experiments.',
    sourcePath:
      'platform/intraday_quant/src/intraday_quant/models/analog_kernel.py',
  },
  {
    id: 'causal-tcn',
    name: 'Causal temporal convolutional network',
    layer: 'offline_python',
    status: 'research_only',
    algorithm:
      'Causal TCN challenger for direction and return-distribution research.',
    sourcePath:
      'platform/intraday_quant/src/intraday_quant/models/causal_tcn.py',
  },
  {
    id: 'cuda-challenger',
    name: 'CUDA regime-gated challenger',
    layer: 'offline_python',
    status: 'research_only',
    algorithm:
      'GPU causal-attention regime-gated mixture-of-experts training workflow.',
    sourcePath:
      'platform/intraday_quant/src/intraday_quant/training/cuda_challenger.py',
  },
  {
    id: 'walk-forward-calibration',
    name: 'Purged walk-forward and calibration',
    layer: 'offline_python',
    status: 'validation_gate',
    algorithm:
      'Chronological splits, embargo, untouched out-of-sample evaluation, and validation-only calibration.',
    sourcePath:
      'platform/intraday_quant/src/intraday_quant/models/walk_forward.py',
  },
  {
    id: 'native-quant-os',
    name: 'Native C++ quant research components',
    layer: 'native_cpp',
    status: 'research_only',
    algorithm:
      'Regularized logistic models, Platt scaling, Gaussian and robust day-block analog kernels, and HMM components.',
    sourcePath: 'platform/quant_core_cpp/src/quant_os.cpp',
  },
];

export function modelCodeInventory(): ModelCodeInventoryItem[] {
  const revision =
    process.env.AXIO7_SOURCE_COMMIT ||
    process.env.GIT_COMMIT ||
    'codex/live-model-integration';
  return DEFINITIONS.map((item) => ({
    ...item,
    sourceUrl: `${REPOSITORY}/blob/${encodeURIComponent(revision)}/${item.sourcePath}`,
  }));
}
